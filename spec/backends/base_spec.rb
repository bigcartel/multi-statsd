# encoding: UTF-8
require File.expand_path('../spec_helper.rb', File.dirname(__FILE__))

module EventMachine
  def self.add_periodic_timer(interval)
    # Don't flush anything automatically
  end
end

describe MultiStatsd::Backend::Base do
  let(:backend) { MultiStatsd::Backend::Base.new('base') }

  describe "default initialization" do
    it "should have a name" do
      backend.name.should == 'base'
    end

    it "should have a default flush_interval" do
      backend.instance_variable_get(:@options)['flush_interval'].should == 15
    end

    it "should have a hash of counters, timers, and gauges" do
      backend.counters.should be_kind_of(Hash)
      backend.timers.should be_kind_of(Hash)
      backend.gauges.should be_kind_of(Hash)
    end
  end
  
  describe "custom initialization" do
    let(:backend) { MultiStatsd::Backend::Base.new('base', 'flush_interval' => 20) }

    it "should have a default flush_interval" do
      backend.instance_variable_get(:@options)['flush_interval'].should == 20
    end
  end
  
  describe "flush" do
    it "should raise an error" do
      lambda { backend.flush }.should raise_error NotImplementedError
    end
  end
  
  describe "reset_stats" do
    let(:timers) { {'api' => [22, 15] } }

    it "should return an array of hashes" do
      stats = backend.reset_stats
      stats.should be_kind_of Array
      stats.each { |stat|
        stat.should be_kind_of Hash
      }
    end
    
    describe "counters" do
      let(:counters) { {'bytes' => 15 } }

      before(:each) {
        backend.instance_variable_set(:@counters, counters.dup)
        @stats = backend.reset_stats[0]
      }

      it "should return the data" do
        @stats.should == counters
      end
      
      it "should be a duplicated object" do
        @stats.object_id.should_not == backend.counters.object_id
      end

      it "should clear the instance variable" do
        backend.counters.should be_empty
      end
    end

    describe "timers" do
      let(:timers) { {'api' => [9, 5] } }

      before(:each) {
        backend.instance_variable_set(:@timers, timers.dup)
        @stats = backend.reset_stats[1]
      }

      it "should return the data" do
        @stats.should == timers
      end
      
      it "should be a duplicated object" do
        @stats.object_id.should_not == backend.timers.object_id
      end

      it "should clear the instance variable" do
        backend.timers.should be_empty
      end
    end

    describe "gauges" do
      let(:gauges) { {'cpu' => 0.15 } }

      before(:each) {
        backend.instance_variable_set(:@gauges, gauges.dup)
        @stats = backend.reset_stats[2]
      }

      it "should return the data" do
        @stats.should == gauges
      end
      
      it "should be a duplicated object" do
        @stats.object_id.should_not == backend.gauges.object_id
      end

      it "should not clear the instance variable" do
        backend.gauges.should_not be_empty
      end
    end
  end
  
  describe "write" do
    describe "crap" do
      it "should ignore garbage" do
        backend.write "blah:123|foo"
        backend.write "blah:snord|ms"
        backend.counters.should be_empty
        backend.gauges.should be_empty
        backend.timers.should be_empty
      end
    end
    
    describe "timers" do
      describe "single" do
        let(:record) { "api:3|ms" }
        before(:each) { backend.write record }

        it "should record from scratch" do
          backend.timers.should == {'api' => [3]}
        end

        it "should append a time" do
          backend.write "api:4|ms"
          backend.timers.should == {'api' => [3, 4]}
        end
      end

      describe "multiple" do
        let(:record) { "api:3|ms:4|ms" }
        before(:each) { backend.write record }

        it "should record both values" do
          backend.timers.should == {'api' => [3,4]}
        end
      end
    end

    describe "gauges" do
      describe "single" do
        let(:record) { "cpu:0.15|g" }
        before(:each) { backend.write record }

        it "should record from scratch" do
          backend.gauges.should == {'cpu' => 0.15}
        end

        it "should update existing gauge" do
          backend.write "cpu:0.17|g"
          backend.gauges.should == {'cpu' => 0.17}
        end
      end

      describe "multiple" do
        let(:record) { "cpu:0.15|g:0.17|g" }
        before(:each) { backend.write record }

        it "should use the last value" do
          backend.gauges.should == {'cpu' => 0.17}
        end
      end
    end
    
    describe "counters" do
      describe "single without sample rate" do
        let(:record) { "bytes:15.2|c" }
        before(:each) { backend.write record }

        it "should record from scratch" do
          backend.counters.should == {'bytes' => 15.2}
        end

        it "should add existing record" do
          backend.write record
          backend.counters.should == {'bytes' => 30.4}
        end
      end

      describe "single with sample rate" do
        let(:record) { "bytes:15.2|c|@0.5" }
        before(:each) { backend.write record }

        it "should record from scratch" do
          backend.counters.should == {'bytes' => 30.4}
        end

        it "should add existing record" do
          backend.write record
          backend.counters.should == {'bytes' => 60.8}
        end
      end

      describe "multiple without sample rate" do
        let(:record) { "bytes:15.5|c:20.2|c" }
        before(:each) { backend.write record }

        it "should record from scratch" do
          backend.counters.should == {'bytes' => 35.7}
        end

        it "should add existing record" do
          backend.write record
          backend.counters.should == {'bytes' => 71.4}
        end
      end

      describe "multiple with sample rate" do
        let(:record) { "bytes:7.75|c|@0.5:10.1|c|@0.5" }
        before(:each) { backend.write record }

        it "should record from scratch" do
          backend.counters.should == {'bytes' => 35.7}
        end

        it "should add existing record" do
          backend.write record
          backend.counters.should == {'bytes' => 71.4}
        end
      end
    end
  end

  describe "format_key" do
    it "should turn spaces into underscores" do
      backend.format_key("blah foo").should == "blah_foo"
    end

    it "should turn slashes into hyphens" do
      backend.format_key("blah/foo").should == "blah-foo"
    end

    it "should filter out non-alpha and a few selected special chars" do
      backend.format_key("blahüfoo*!@&#^%}").should == "blahfoo"
    end
  end
end