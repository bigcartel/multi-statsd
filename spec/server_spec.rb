# encoding: UTF-8
require File.expand_path('spec_helper.rb', File.dirname(__FILE__))
require 'multi-statsd/backends/stdout'

class MockBackend
  def write(data); end
end

describe MultiStatsd::Server do
  def send_message(message, server='localhost', port=33333)
    UDPSocket.new.send(message, 0, server, port)
  end

  let(:message) { 'test:1|c' }

  describe "recording data to backends" do
    it "Should record data to a single backend" do
      mock_backend = MockBackend.new
      mock_backend.should_receive(:write).with(message)
      EM.run do
        EM::open_datagram_socket 'localhost', 33333, MultiStatsd::Server, mock_backend
        send_message message
        EM.next_tick { EM.stop }
      end
    end

    it "should record data to multiple backends" do
      backends = 3.times.map do
        backend = MockBackend.new
        backend.should_receive(:write).with(message)
        backend
      end

      EM.run do
        EM::open_datagram_socket 'localhost', 33333, MultiStatsd::Server, backends
        send_message message
        EM.next_tick { EM.stop }
      end
    end
  end
end
