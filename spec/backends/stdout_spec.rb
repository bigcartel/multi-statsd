# encoding: UTF-8
require File.expand_path('../spec_helper.rb', File.dirname(__FILE__))
require 'multi-statsd/backends/stdout'

module EventMachine
  def self.add_periodic_timer(interval)
    # Don't flush anything automatically
  end
end

describe MultiStatsd::Backend::Stdout do
  let(:backend) { MultiStatsd::Backend::Stdout.new('stdout') }

  describe "flush behavior" do
    it "should print to stdout" do
      $stdout.should_receive(:puts)
      backend.flush
    end
  end
end
