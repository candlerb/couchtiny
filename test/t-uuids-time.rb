require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny'
require 'couchtiny/uuids/time'

class TestUUIDSTime < Test::Unit::TestCase
  context "Time-based UUID generator" do
    setup do
      @uuids = CouchTiny::UUIDS::Time.new
    end
    
    should "allocate unique uuids" do
      u1 = @uuids.call
      u2 = @uuids.call
      u3 = @uuids.call
      assert_equal 3, [u1,u2,u3].uniq.size
    end
    
    should "have time in top 48 bits" do
      u = @uuids.call
      t1 = Time.now.to_f * 1000.0
      t2 = u[0,12].to_i(16)
      assert (t1 - t2).abs < 2000
    end

    should "allocate bulk uuids in sequence" do
      gen = @uuids.bulk
      u1 = gen.call
      u2 = gen.call
      u3 = gen.call
      assert_equal 1, u2.to_i(16) - u1.to_i(16)
      assert_equal 1, u3.to_i(16) - u2.to_i(16)
    end
  end
end
