require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny/jsobject'

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

  context "JSObjectParser" do
    setup do
      @json = CouchTiny::JSObjectParser
    end
    
    should "unparse" do
      assert_equal '{"a":1}', @json.unparse("a"=>1)
    end
    
    should "parse and extend" do
      res = @json.parse('{"foo":{"bar":[{"baz":123}]}}')
      assert_equal 123, res.foo.bar.first.baz
      assert_equal 123, res['foo']['bar'][0]['baz']
    end
  end
end
