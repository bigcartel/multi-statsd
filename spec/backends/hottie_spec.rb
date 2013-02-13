# encoding: UTF-8
require File.expand_path('../spec_helper.rb', File.dirname(__FILE__))
require 'multi-statsd/backends/hottie'

module EventMachine
  def self.add_periodic_timer(interval)
    # Don't flush anything automatically
  end
end

describe MultiStatsd::Backend::Hottie do
  let(:backend) { MultiStatsd::Backend::Hottie.new('hottie') }

  describe "post init" do
    it "should have a connection to redis" do
      backend.instance_variable_get(:@db).should be_kind_of Redis
    end

    it "should have a default @seconds_to_retain" do
      backend.seconds_to_retain.should == 60
    end

    it "should have a default @seconds_to_retain" do
      backend = MultiStatsd::Backend::Hottie.new('hottie', 'seconds_to_retain' => 80)
      backend.seconds_to_retain.should == 80
    end

    it "should have an appropriate set of samples to retain" do
      backend.samples_to_retain.should == 4
    end

    it "should have a default @seconds_to_retain" do
      backend = MultiStatsd::Backend::Hottie.new('hottie', 'seconds_to_retain' => 80, 'flush_interval' => 10)
      backend.samples_to_retain.should == 8
    end
  end
  
  describe "flush" do
    describe "gauges" do
      before(:all) {
        @db = backend.instance_variable_get(:@db)
        @db.flushdb
        backend.record "cpu:0.15|g"
        backend.flush
      }
      
      it "should add the name to the set" do
        @db.sismember("gauges", "cpu").should be_true
      end

      it "should have a sample" do
        samples = @db.lrange "gauge_samples", 0, -1
        samples.size.should == 1
        @db.hlen(samples.first).should == 1
        @db.hget(samples.first, 'cpu').should == "0.15"
      end
      
      it "should roll over on flush if there are too many samples" do
        backend.samples_to_retain.times do |i|
          @db.lpush "gauge_samples", "gauge:#{i}"
        end
        @db.llen("gauge_samples").should == (backend.samples_to_retain + 1)
        backend.flush
        @db.llen("gauge_samples").should == backend.samples_to_retain
      end
    end

    describe "counters" do
      before(:all) {
        @db = backend.instance_variable_get(:@db)
        @db.flushdb
        backend.record "bytes:1200|c"
        backend.flush
      }
      
      it "should add the name to the set" do
        @db.sismember("counters", "bytes").should be_true
      end

      it "should have a sample" do
        samples = @db.lrange "counter_samples", 0, -1
        samples.size.should == 1
        @db.hlen(samples.first).should == 1
        (@db.hget(samples.first, 'bytes')).to_i.should == (1200 / backend.flush_interval)
      end
      
      it "should roll over on flush if there are too many samples" do
        backend.samples_to_retain.times do |i|
          @db.lpush "counter_samples", "counter:#{i}"
        end
        @db.llen("counter_samples").should == (backend.samples_to_retain + 1)
        backend.flush
        @db.llen("counter_samples").should == backend.samples_to_retain
      end
    end

    describe "timers" do
      before(:all) {
        @db = backend.instance_variable_get(:@db)
        @db.flushdb
        backend.record "api:15.5|ms"
        backend.flush
      }
      
      it "should add the name to the set" do
        @db.sismember("timers", "api").should be_true
      end

      it "should have a rounded sample" do
        samples = @db.lrange "timer_samples", 0, -1
        samples.size.should == 1
        @db.hlen(samples.first).should == 1
        Marshal.load(@db.hget(samples.first, 'api')).should == [[16, 1]]
      end
      
      it "should roll over on flush if there are too many samples" do
        backend.samples_to_retain.times do |i|
          @db.lpush "timer_samples", "timer:#{i}"
        end
        @db.llen("timer_samples").should == (backend.samples_to_retain + 1)
        backend.flush
        @db.llen("timer_samples").should == backend.samples_to_retain
      end
    end
  end
end
