require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny/parser/json'

class TestParserJSON < Test::Unit::TestCase
  context "Parser::JSON" do
    setup do
      @json = CouchTiny::Parser::JSON.new
    end
    
    should "unparse" do
      assert_equal '{"a":1}', @json.unparse("a"=>1)
    end
    
    should "parse" do
      res = @json.parse('{"foo":{"bar":[{"baz":123}]}}')
      assert_equal 123, res['foo']['bar'][0]['baz']
    end
  end

  context "Parser::JSON with parse options" do
    setup do
      @json = CouchTiny::Parser::JSON.new(:to_json, :max_nesting=>2)
    end
    
    should "unparse" do
      assert_equal '{"a":1,"b":2}', @json.unparse("a"=>1, "b"=>2)
    end
    
    should "enforce parsing limits" do
      assert_raises(JSON::NestingError) {
        @json.parse('{"foo":{"bar":[{"baz":123}]}}')
      }
    end
  end

if defined? ActiveSupport
  context "Parser::JSON with generate options" do
    setup do
      @json = CouchTiny::Parser::JSON.new(:to_json, {:max_nesting=>2}, {:except=>"a"})
    end
    
    should "unparse" do
      assert_equal '{"b":2}', @json.unparse("a"=>1, "b"=>2)
    end
  end
end
end
