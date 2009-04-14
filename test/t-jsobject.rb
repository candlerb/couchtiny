require File.join(File.dirname(__FILE__),'test_helper')
require 'jsobject'

class TestJSObject < Test::Unit::TestCase
  setup do
    @h = JSObject.new
    @h['foo'] = 'bar'
  end
  
  should "have normal readers" do
    assert_equal 'bar', @h['foo']
    assert_equal nil, @h['baz']
  end
  
  should "have javascript readers" do
    assert_equal 'bar', @h.foo
    assert_equal nil, @h.baz
  end
  
  should "have normal writers" do
    @h['foo'] = 123
    assert_equal 123, @h['foo']
    assert_equal 123, @h.foo
  end
  
  should "have javascript writers" do
    @h.foo = 456
    assert_equal 456, @h['foo']
    assert_equal 456, @h.foo
  end
end
