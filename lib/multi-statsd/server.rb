module MultiStatsd
  # Eventmachine connection which receives UDP data and writes it to various backends
  class Server < EventMachine::Connection
    # Initialize the server with one or more backends
    # @param [MultiStatsd::Backend] backends One or more backends that will receive data
    def initialize(backends = [], *args)
      @backends = [backends].flatten
      super
    end
    
    # Write out statsd data to each registered backend
    # @param [String] data Data in statsd format
    # @return [nil]
    def receive_data(data)
      @backends.each do |backend|
        backend.record(data)
      end
      
      nil
    end    
  end    
end