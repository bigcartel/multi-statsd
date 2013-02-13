require 'redis'

# Hottie backend
# Hottie is a redis-based short-term backend to enable real-time visibility into application behavior.
# It is specifically designed to enable real-time heatmap/histogram visualizations from timer data.
class MultiStatsd::Backend::Hottie < MultiStatsd::Backend::Base
  attr_reader :seconds_to_retain, :samples_to_retain

  # Initialize a connection to redis and configure our samples to retain
  def post_init
    @db = Redis.new(
      :host => (@options['host'] || '127.0.0.1'),
      :port => (@options['port'] || 6379),
      :database => (@options['database'] || 1)
    )
    @seconds_to_retain = @options['seconds_to_retain'] || 60
    @samples_to_retain = (@seconds_to_retain / @options['flush_interval']).floor
  end
  
  # Flush the data to redis in the format required for Hottie
  # @return [Float] The number of seconds it took to aggregate/flush the data to redis
  def flush
    counters, timers, gauges = reset_stats
    ts = Time.new.to_i
    time = ::Benchmark.realtime do
      @db.pipelined do
        if !gauges.empty?
          @db.hmset "gauges:#{ts}", *(gauges.map { |stat, gauge|  [stat, gauge] }.flatten)
          @db.expire "gauges:#{ts}", @seconds_to_retain + 5 # Retain a few extra seconds to avoid reporting race
          @db.sadd "gauges", gauges.keys
        end
        @db.lpush "gauge_samples", "gauges:#{ts}"
        @db.ltrim "gauge_samples", 0, @samples_to_retain - 1

        if !counters.empty?
          @db.hmset "counters:#{ts}", *(counters.map { |stat, counter|[stat, counter / @options['flush_interval']] }.flatten)
          @db.expire "counters:#{ts}", @seconds_to_retain + 5 # Retain a few extra seconds to avoid reporting race
          @db.sadd "counters", counters.keys
        end
        @db.lpush "counter_samples", "counters:#{ts}"
        @db.ltrim "counter_samples", 0, @samples_to_retain - 1

        if !timers.empty?
          timer_hash = Hash.new(0)
          @db.hmset "timers:#{ts}", *(timers.map { |stat, data|
            timer_hash.clear
            data.each { |d| timer_hash[d.round] += 1 }
            [stat, Marshal.dump(timer_hash)]
          })
          @db.expire "timers:#{ts}", @seconds_to_retain + 5 # Retain a few extra seconds to avoid reporting race
          @db.sadd "timers", timers.keys
        end
        @db.lpush "timer_samples", "timers:#{ts}"
        @db.ltrim "timer_samples", 0, @samples_to_retain - 1
      end
    end
    MultiStatsd.logger.debug "Hottie flushing took #{"%.3f" % (time * 1000)}ms"
    time
  rescue Redis::CannotConnectError
    MultiStatsd.logger.warning "Unable to connect to redis, skipping flush"
  end
end