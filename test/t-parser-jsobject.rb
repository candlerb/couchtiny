require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny/parser/jsobject'

class TestParserJSObject < Test::Unit::TestCase
  context "Parser::JSObject" do
    setup do
      @json = CouchTiny::Parser::JSObject
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
