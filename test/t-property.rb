require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny'
require 'couchtiny/document'
require 'couchtiny/property'

# QUESTION: do we allow nil for properties? Should we delete the property?
# QUESTION: how do we usefully collect errors and associate them with the property?
# (perhaps an InvalidValue object?)
# We should override update and merge! (recursively??) -- and have
# protected attributes

class TestAttribute < Test::Unit::TestCase
  class Simple < CouchTiny::Document
    include CouchTiny::Property
    property :foo
  end

  class Bar < CouchTiny::Document
  end
  class Baz < Bar
  end

  context "inside class" do
    should "generic property" do
      a = Simple.new
      a.foo = "bar"
      assert_equal "bar", a.foo
    end
  end
  
  should "generic property" do
    klass = Class.new(CouchTiny::Document)
    klass.class_eval do
      include CouchTiny::Property
      property :generic
    end

    a = klass.new
    a.generic = "hello"
    assert_equal "hello", a.generic
    a.generic = 123
    assert_equal 123, a.generic
  end

  should "String property" do
    klass = Class.new(CouchTiny::Document)
    klass.class_eval do
      include CouchTiny::Property
      property :str, :type=>String
    end

    a = klass.new
    a.str = "hello"
    assert_equal "hello", a.str
    a.str = 123
    assert_equal "123", a.str
  end
  
  should "Integer property" do
    klass = Class.new(CouchTiny::Document)
    klass.class_eval do
      include CouchTiny::Property
      property :num, :type=>Integer
    end

    a = klass.new
    a.num = 123
    assert_equal 123, a.num
    a.num = "456"
    assert_equal 456, a.num
    assert_raises(ArgumentError) {
      a.num = "1234.5"
    }
  end

  should "Float property" do
    klass = Class.new(CouchTiny::Document)
    klass.class_eval do
      include CouchTiny::Property
      property :num, :type=>Float
    end

    a = klass.new
    a.num = 123
    assert_equal 123.0, a.num
    assert_equal Float, a.num.class
    a.num = 1234.5
    assert_equal 1234.5, a.num
    a.num = "9876.5"
    assert_equal 9876.5, a.num
    assert_raises(ArgumentError) {
      a.num = "abc"
    }
  end

  context "Time" do
    setup do
      @t = Time.at(1245927600)
    end
    
    should "as Javascript-style UTC string" do
      klass = Class.new(CouchTiny::Document)
      klass.class_eval do
        include CouchTiny::Property
        property :t, :type=>:time_as_utc_text
      end

      a = klass.new
      a.t = @t
      assert_equal "2009/06/25 11:00:00 +0000", a["t"]
      assert_equal Time.at(1245927600), a.t
    end

    should "as iso8601 extended" do
      klass = Class.new(CouchTiny::Document)
      klass.class_eval do
        include CouchTiny::Property
        property :t, :type=>:time_as_iso8601_extended
      end

      a = klass.new
      a.t = @t
      assert_equal "2009-06-25T11:00:00Z", a["t"]
      assert_equal Time.at(1245927600), a.t
    end

    should "as iso8601 basic" do
      klass = Class.new(CouchTiny::Document)
      klass.class_eval do
        include CouchTiny::Property
        property :t, :type=>:time_as_iso8601_basic
      end

      a = klass.new
      a.t = @t
      assert_equal "20090625T110000Z", a["t"]
      assert_equal Time.at(1245927600), a.t
    end
  end
  
  class Bar < CouchTiny::Document
  end
  class Baz < Bar
  end

  context "document property" do
    setup do
      @klass = Class.new(CouchTiny::Document)
      @klass.class_eval do
        include CouchTiny::Property
        property :subdoc, :type=>Bar
      end
    end

    should "bring a non-existent property into existence" do
      a = @klass.new
      b = a.subdoc
      assert_equal Bar, b.class
      b["hello"] = "world"
      assert_equal "world", a["subdoc"]["hello"]
    end

    should "assign object of correct class" do
      a = @klass.new
      b = Bar.new("hello"=>"world")
      a.subdoc = b
      assert_equal "world", a.subdoc["hello"]      # via proxy
      assert_equal "world", a["subdoc"]["hello"]   # directly via top object
      assert_equal Hash, a["subdoc"].class         # which has the underlying Hash
    end
    
    should "assign object of a subclass" do
      a = @klass.new
      b = Baz.new("hello"=>"again")
      a.subdoc = b
      assert_equal "again", a["subdoc"]["hello"]
      assert_equal Hash, a["subdoc"].class
    end
    
    should "refuse object of wrong class" do
      a = @klass.new
      b = CouchTiny::Document.new("hello"=>"again")
      assert_raises(ArgumentError) {
        a.subdoc = b
      }
    end
  end
end
