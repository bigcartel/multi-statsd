# encoding: UTF-8
require File.expand_path('spec_helper.rb', File.dirname(__FILE__))
require 'multi-statsd/backends/stdout'

describe MultiStatsd do
  it "should start and stop the reactor" do
    MultiStatsd.start({'host' => 'localhost', 'port' => 33333, 'backends' => {'stdout' => {'backend' => 'Stdout'}}})
    sleep 0.2
    EM.reactor_running?.should be_true
    MultiStatsd.stop
    sleep 0.2
    EM.reactor_running?.should be_false
  end

  it "should raise an error on an unknown backend" do
    lambda {
      MultiStatsd.start({'host' => 'localhost', 'port' => 33333, 'backends' => {'stdout' => {'backend' => 'Broken'}}})
      sleep 1
      
    }.should raise_error(MultiStatsd::Backend::Error)
  end
end
