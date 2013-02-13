require 'benchmark'
require 'thread'

module MultiStatsd
  # Various backends should be defined in this module
  module Backend
    # Error class for MultiStatsd-generated errors
    class Error < StandardError; end

    # @abstract Subclass and override {#flush} to implement a custom Backend class.
    class Base
      attr_reader :counters, :timers, :gauges, :name
      
      def initialize(name, options = {})
        @name, @options = name, options
        @timers, @gauges, @counters = {}, {}, Hash.new(0)
        @semaphore = Mutex.new
        
        @options['flush_interval'] ||= 15

        post_init

        EventMachine::add_periodic_timer(@options['flush_interval']) do
          EM.defer { flush }
        end
      end
  
      # @return [Integer] the flush interval
      def flush_interval
        @options['flush_interval']
      end
      
      # Override in subclasses to execute code after initialization (eg. database connection setup)
      def post_init
      end
      
      # Each backend must implement this method to flush its data
      def flush
        raise NotImplementedError
      end
      
      # Reset and return the generated data in a mutex to ensure none are lost
      # @return [Array] An array consisting of [counters, timers, gauges]
      def reset_stats
        @semaphore.synchronize do
          counters = @counters.dup
          timers = @timers.dup
          gauges = @gauges.dup
          @counters.clear
          @timers.clear
          [counters, timers, gauges]
        end
      end
  
      # Record data in statsd format
      #   Gauges - cpu:0.15|g
      #   Timers - api:12|ms
      #   Counters - bytes:123|c
      #   Counters with sampling - bytes:123|c|@0.1
      #   Multiple values - api:12|ms:15|ms:8|ms
      # @param [String] msg string of data in statsd format
      # @return [true]
      def record(msg)
        msg.each_line do |row|
          # Fetch our key and records
          key, *records = row.split(":")
          
          # Clean up the key formatting
          key = format_key(key)

          # Iterate through each record and store the data
          records.each do |record|
            value, type, sample_rate = record.split('|')
            next unless value and type and value =~ /^(?:[\d\.-]+)$/

            if type == "ms"
              @timers[key] ||= []
              @timers[key].push(value.to_f)
            elsif type == "c"
              if sample_rate
                sample_rate = sample_rate.gsub(/[^\d\.]/, '').to_f
                sample_rate = 1 if sample_rate <= 0
                @counters[key] += value.to_f * (1.0 / sample_rate)
              else
                @counters[key] += value.to_f
              end
            elsif type == "g"
              @gauges[key] = value.to_f
            end
          end
        end
        
        true
      end
      
      # Format a given key
      # @param [String] key from the statsd record
      # @return [String] formatted key
      def format_key(key)
        key.gsub(/\s+/, '_').gsub(/\//, '-').gsub(/[^a-zA-Z_\-0-9\.]/, '')
      end
    end
  end
end
