require 'logger'
require 'eventmachine'
require 'em-logger'

require "multi-statsd/version"
require 'multi-statsd/backends/base'
require 'multi-statsd/server'

# MultiStatsd namespace
module MultiStatsd
  # Assign a logger
  # @param [Logger] logger
  def self.logger=(logger)
    @logger = logger.kind_of?(EM::Logger) ? logger : EM::Logger.new(logger)
  end
  
  # Return the logger
  # @return [Logger]
  def self.logger
    return @logger if defined?(@logger)
    log = Logger.new(STDOUT)
    log.level = 2
    @logger = EM::Logger.new(log)
  end
  
  # Start up the Eventmachine reactor loop in a separate thread give a set of options.
  #   This is a test
  #   This is another test
  # @param [Hash] options Set of options
  # @return [thread] Thread which is running the eventmachine loop
  def self.start(options)
    thread = Thread.new do
      EM.run do
        backends = []
        options['backends'].each_pair do |name, options|
          backend = options.delete('backend')
          begin
            require "multi-statsd/backends/#{backend.downcase}"
          rescue LoadError
            raise MultiStatsd::Backend::Error, "Cannot load file multi-statsd/backends/#{backend.downcase}"
          end
          if !MultiStatsd::Backend.const_defined?(backend)
            raise MultiStatsd::Backend::Error, "No such back end: MultiStatsd::Backend::#{backend}"
          else
            logger.info "Adding backend #{backend} :: #{name}"
            backends << MultiStatsd::Backend.const_get(backend).new(name, options)
          end
        end

        EM::open_datagram_socket(
          (options['host'] || '127.0.0.1'),
          (options['port'] || 8125),
          MultiStatsd::Server,
          backends
        )
        logger.info "multi-statsd starting up on #{options['host']}:#{options['port']}"
      end
    end
    
    thread.abort_on_exception = true
    thread
  end

  # Stop the Eventmachine reactor loop
  def self.stop
    logger.info "multi-statsd shutting down"
    EM.next_tick { EM.stop }
  end
end