require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny'
require 'couchtiny/parser/jsobject'

class TestServer < Test::Unit::TestCase
  class MockBulkGen
    def initialize(arr)
      @arr = arr
    end
    def bulk
      lambda { @arr.shift }
    end
  end

  should "create from server and name" do
    server = CouchTiny::Server.new :url=>"http://192.0.2.1"
    database = CouchTiny::Database.new server, "foo"
    assert_equal "http://192.0.2.1/foo", database.url
  end

  should "escape slash in database name" do
    server = CouchTiny::Server.new :url=>"http://192.0.2.1"
    database = CouchTiny::Database.new server, "foo/bar"
    assert_equal "http://192.0.2.1/foo%2Fbar", database.url
  end

  should "create from url" do
    database = CouchTiny::Database.url("http://192.0.2.1/foo")
    assert_equal "foo", database.name
    assert_equal "http://192.0.2.1/foo", database.url
    assert_equal "http://192.0.2.1", database.server.url
  end
    
  should "create from url with slash and options" do
    database = CouchTiny::Database.url("http://192.0.2.1/foo/bar", :uuid_generator=>:dummy)
    assert_equal "foo/bar", database.name
    assert_equal "http://192.0.2.1/foo%2Fbar", database.url
    assert_equal "http://192.0.2.1", database.server.url
    assert_equal :dummy, database.server.uuid_generator
  end
    
  context "basic database tests" do
    setup do
      @server = CouchTiny::Server.new :url=>SERVER_URL
      @database = CouchTiny::Database.new @server, DATABASE_NAME
      @database.recreate_database!
    end

    should "have accessors" do
      assert_equal @server, @database.server
      assert_equal DATABASE_NAME, @database.name
      assert_not_nil @database.url
      assert_not_nil @database.http
    end

    should "get info" do
      res = @database.info
      assert_equal 0, res['doc_count']
    end
    
    should "delete" do
      @database.delete_database!
      begin
        @database.info
        assert nil, "info on non-existent database should raise"
      rescue
      end
    end    

    should "create" do
      @database.delete_database!
      @database.create_database!
      begin
        @database.create_database!
        assert nil, "create on pre-existing database should raise"
      rescue
      end
    end

    should "refuse get with empty id" do
      assert_raises(RuntimeError) {
        @database.get nil
      }
      assert_raises(RuntimeError) {
        @database.get ""
      }
    end

    should "put and get (fixed id)" do
      doc = {'foo'=>456, '_id'=>'testid'}
      res = @database.put doc
      assert_equal true, res['ok']
      assert_equal 'testid', doc['_id']
      assert_not_nil doc['_rev']

      doc2 = @database.get 'testid'
      assert_equal doc, doc2
    end

    should "put and get (with uuid)" do
      doc = {"foo"=>123}
      res = @database.put doc
      assert_equal true, res['ok']
      assert_not_nil doc['_id']
      assert_not_nil doc['_rev']

      doc2 = @database.get doc['_id']
      assert_equal doc, doc2
    end
    
    should "put and get (id with slash)" do
      doc = {'foo'=>456, '_id'=>'foo/bar'}
      res = @database.put doc
      assert_equal true, res['ok']
      assert_equal 'foo/bar', doc['_id']
      assert_not_nil doc['_rev']

      doc2 = @database.get 'foo/bar'
      assert_equal doc, doc2
    end
    
    should "_put without updating _id or _rev" do
      doc = {"foo"=>123}
      res = @database._put nil, doc
      assert_equal 1, @database.info['doc_count']
      assert_equal true, res['ok']
      assert_nil doc['_id']
      assert_nil doc['_rev']
    end

    should "_put with concurrency control" do
      doc = {"foo"=>123}
      res = @database._put "testdoc", doc
      
      doc = {"foo"=>456}
      assert_raises(RestClient::RequestFailed) {
        @database._put "testdoc", doc
      }
      
      assert_nothing_raised{ 
        @database._put "testdoc", doc.merge('_rev' => res['rev'])
      }
      # Note: couchdb 0.9.1 ignores PUT ...?rev=1-23456. However it does
      # honour If-Match: 1-23456
    end

    should "delete" do
      doc = {"foo"=>123}
      @database.put doc
      assert_equal 1, @database.info['doc_count']
      r1 = doc['_rev']

      @database.delete doc
      assert_equal 0, @database.info['doc_count']
      r2 = doc['_rev']

      assert_not_nil r1
      assert_not_nil r2
      assert_not_equal r1, r2, "_rev should change after delete"
    end

    should "bulk_docs" do
      d1 = {'foo'=>111, '_id'=>'test1'}
      d2 = {'bar'=>222}
      res = @database.bulk_docs [d1,d2]
      assert_nil res[0]['error']
      assert_nil res[1]['error']
      
      # doc attributes should be updated in place
      assert_not_nil d1['_rev']
      assert_not_nil d2['_rev']
      assert_equal 'test1',d1['_id']
      assert_not_nil d2['_id']

      assert_equal 2, @database.info['doc_count']
    end

    should "bulk_docs with error" do
      d1 = {'foo'=>111, '_id'=>'test1'}
      res = @database.bulk_docs [d1]
      assert_nil res[0]['error']

      d1 = {'foo'=>111, '_id'=>'test1'}
      res = @database.bulk_docs [d1]
      assert_equal 'conflict', res[0]['error']
    end
    
    should "bulk_docs with custom UUID generator" do
      @server.uuid_generator = MockBulkGen.new(["aaa","bbb"])
      d1 = {'foo'=>111}
      d2 = {'bar'=>222}
      res = @database.bulk_docs [d1, d2]
      assert_equal "aaa", d1['_id']
      assert_equal "bbb", d2['_id']

      assert_equal 2, @database.info['doc_count']
      assert_equal 111, @database.get('aaa')['foo']
      assert_equal 222, @database.get('bbb')['bar']
    end

    should "_bulk_docs without updating _id or _rev" do
      d1 = {'foo'=>111, '_id'=>'test1'}
      d2 = {'bar'=>222}
      res = @database._bulk_docs [d1,d2]
      assert_equal 'test1', res[0]['id']
      assert_not_nil res[0]['rev']
      assert_nil res[0]['error']
      assert_not_nil res[1]['id']
      assert_not_nil res[1]['rev']
      assert_nil res[1]['error']
      
      assert_nil d1['_rev']
      assert_nil d2['_rev']
      assert_equal 'test1',d1['_id']
      assert_nil d2['_id']

      assert_equal 2, @database.info['doc_count']
    end

    should "copy to new doc" do
      d1 = {"foo"=>123,"_id"=>"a"}
      @database.put d1
      assert_equal 1, @database.info['doc_count']
      
      @database.copy "a", "b"
      assert_equal 2, @database.info['doc_count']
      assert_equal 123, @database.get("b")["foo"]
    end

    should "copy and overwrite" do
      d1 = {"foo"=>123,"_id"=>"a"}
      @database.put d1
      d2 = {"bar"=>456,"_id"=>"b"}
      @database.put d2
      assert_equal 2, @database.info['doc_count']
      
      @database.copy "a", "b", d2['_rev']
      assert_equal 2, @database.info['doc_count']
      assert_equal 123, @database.get("b")["foo"]
    end

    should "copy where docids include slash" do
      d1 = {"foo"=>123,"_id"=>"foo/bar"}
      @database.put d1
      assert_equal 1, @database.info['doc_count']
      
      @database.copy "foo/bar", "foo/baz"
      assert_equal 2, @database.info['doc_count']
      assert_equal 123, @database.get("foo/baz")["foo"]
    end

    should "compact" do
      d1 = {"foo"=>123}
      d2 = {"bar"=>456}
      d3 = {"baz"=>789}
      20.times {
        @database.bulk_docs [d1,d2,d3]
      }
      size1 = @database.info['disk_size']
      @database.delete(d2)
      @database.compact!
      while true
        break unless @database.info['compact_running']
        sleep 0.5
      end
      size2 = @database.info['disk_size']
      assert size2<size1, "Reduced database size after compaction"
      assert_equal 2, @database.info['doc_count']
    end

    should "changes" do
      d1 = {"foo"=>123}
      @database.put d1
      res = @database.changes
      assert_equal Array, res['results'].class
      assert_equal Fixnum, res['last_seq'].class
    end

    should "show 400 exception" do
      e = assert_raises(RestClient::RequestFailed) {
        @database.all_docs(:reduce=>"flurble")
      }
      assert_equal '400 query_parse_error (Invalid value for boolean paramter: "flurble")', e.message
    end

    # 401: RestClient::Unauthorized

    should "show 404 exception" do
      e = assert_raises(RestClient::ResourceNotFound) {
        @database.get 'testid'
      }
      assert_equal '404 not_found (missing)', e.message
    end

    should "show 409 exception" do
      doc = {'foo'=>456}
      @database._put 'testid', doc
      e = assert_raises(RestClient::RequestFailed) {
        @database._put 'testid', doc
      }
      assert_equal '409 conflict (Document update conflict.)', e.message
    end

    # Currently this gives a 405 with no JSON body, may change in future
    should "show exception with no body" do
      e = assert_raises(RestClient::RequestFailed) {
        @database.http.put "/#{DATABASE_NAME}/_bulk_docs", "[]", :content_type=>"application/octet-stream"
      }
      assert_equal '405 Method Not Allowed', e.message
    end

    context "all_or_nothing and conflicting revs" do
      setup do
        doc = {"name"=>"fred"}
        @database.put doc
        @id = doc['_id']

        doc["name"] = "jim"
        @database._bulk_docs [doc], :all_or_nothing=>true

        doc["name"] = "trunky"
        @database._bulk_docs [doc], :all_or_nothing=>true
      end
      
      should "fetch one version by default" do
        res = @database.get @id
        assert ["jim","trunky"].include?(res['name'])
      end
      
      should "fetch list of conflicts" do
        res = @database.get @id, :conflicts=>"true"
        assert_equal 1, res['_conflicts'].size
      end
      
      should "fetch conflicting versions" do
        res = @database.get @id, :conflicts=>"true"
        res2 = @database.get @id, :rev=>res['_conflicts'].first
        
        assert_equal ["jim","trunky"], [res['name'],res2['name']].sort
      end
    end
  end

  context "attachments" do
    setup do
      @server = CouchTiny::Server.new :url=>SERVER_URL
      @database = CouchTiny::Database.new @server, DATABASE_NAME
      @database.recreate_database!
      @doc = {"foo"=>123}
      @database.put @doc
    end
    
    should "create and retrieve attachment (high level)" do
      @database.put_attachment @doc, "wibble", "foobar"

      res = @database.get_attachment @doc, "wibble"
      assert_equal "foobar", res

      res = @database.get @doc['_id']
      assert_equal "application/octet-stream", res['_attachments']['wibble']['content_type']
    end

    should "create and retrieve attachment (low level)" do
      @database._put_attachment @doc['_id'], @doc['_rev'], "wibble", "foobar"

      res = @database._get_attachment @doc['_id'], "wibble"
      assert_equal "foobar", res

      res = @database.get @doc['_id']
      assert_equal "application/octet-stream", res['_attachments']['wibble']['content_type']
    end

    should "save attachment content_type" do
      @database.put_attachment @doc, "wibble", "foobar", "application/x-foo"

      res = @database.get @doc['_id']
      assert_equal "application/x-foo", res['_attachments']['wibble']['content_type']
    end

    should "delete attachment" do
      @database.put_attachment @doc, "wibble", "foobar"
      
      @database.delete_attachment @doc, "wibble"
      
      assert_raises(TEST_HTTP_NOT_FOUND) {
        @database.get_attachment @doc, "wibble"
      }
    end
  end

  context "views" do
    setup do
      @server = CouchTiny::Server.new :url=>SERVER_URL
      @database = CouchTiny::Database.new @server, DATABASE_NAME
      @database.recreate_database!
      @doc1={"_id"=>"fred", "friend"=>"bluebottle"}
      @doc2={"_id"=>"jim", "friend"=>"eccles"}
      @doc3={"_id"=>"trunky", "friend"=>"moriarty"}
      @database.bulk_docs [@doc1, @doc2, @doc3]
    end
    
    should "get all_docs" do
      res = @database.all_docs
      assert_equal 3, res['rows'].size, "expect 3 rows"
      assert_equal 3, res['total_rows']
    end
    
    should "get all_docs with key range" do
      res = @database.all_docs :startkey=>"a",:endkey=>"m"
      assert_equal 2, res['rows'].size, "expect 2 rows"
      assert_equal 3, res['total_rows']
    end

    should "get all_docs with specific keys" do
      res = @database.all_docs :keys=>["trunky","zog","fred"]
      assert_equal "trunky", res['rows'][0]['id']
      assert_equal "not_found", res['rows'][1]['error']
      assert_equal "fred", res['rows'][2]['id']
    end
    
    should "get all_docs with include_docs" do
      res = @database.all_docs :keys=>["trunky"], :include_docs=>true
      assert_equal "trunky", res['rows'][0]['id']
      assert_equal "moriarty", res['rows'][0]['doc']['friend']
    end

    should "get all_docs with block" do
      docs = []
      @database.all_docs { |doc| docs << doc }
      assert_equal ["fred","jim","trunky"], docs.collect { |doc| doc['id'] }
    end
    
    should "get all_docs with specific keys with block" do
      docs = []
      @database.all_docs(:keys=>["trunky","zog","fred"]) { |doc| docs << doc }
      assert_equal "trunky", docs[0]['id']
      assert_equal "not_found", docs[1]['error']
      assert_equal "fred", docs[2]['id']
    end

    should "get all_docs with include_docs with block" do
      docs = []
      @database.all_docs(:keys=>["trunky"], :include_docs=>true) { |doc| docs << doc }
      assert_equal 1, docs.size
      assert_equal "trunky", docs[0]['id']
      assert_equal "moriarty", docs[0]['doc']['friend']
    end

    should "get all_docs_by_seq" do
      res = @database.all_docs_by_seq
      assert_equal [1,2,3], res['rows'].collect { |r| r['key'] }
      assert_equal 3, res['total_rows']
    end
    
    should "generate temporary view" do
      res = @database.temp_view(<<MAP, :descending=>true)
function(doc) {
  if (doc.friend) {
    emit(doc.friend, null);
  }
}
MAP
      assert_equal ["moriarty","eccles","bluebottle"], res['rows'].collect { |r| r['key'] }
    end

    should "generate temporary view with reduce" do
      res = @database.temp_view(<<MAP, <<REDUCE, :startkey=>"d")
function(doc) {
  if (doc.friend) {
    emit(doc.friend, null);
  }
}
MAP
function(ks, vs, co) {
  if (co) {
    return sum(vs);
  } else {
    return vs.length;
  }
}
REDUCE
      assert_equal 2, res['rows'].first['value']
    end

    should "generate temporary view with block" do
      docs = []
      res = @database.temp_view(<<MAP, :startkey=>"d") { |doc| docs << doc }
function(doc) {
  if (doc.friend) {
    emit(doc.friend, null);
  }
}
MAP
      assert_equal ["eccles","moriarty"], docs.collect { |r| r['key'] }
    end

    should "fetch_view (low level API)" do
      res = @database.fetch_view("/#{DATABASE_NAME}/_all_docs", :startkey=>"a", :endkey=>"m")
      assert_equal 2, res['rows'].size, "expect 2 rows"
      assert_equal 3, res['total_rows']
    end
    
    # We don't need to do much testing here, since all_docs exercises
    # all the interesting stuff
    context "named view" do
      setup do
        @design = {
          "_id" => "_design/sample",
          "views" => {
            "testview" => {
              "map" => <<MAP,
function(doc) {
  if (doc.friend) {
    emit(doc.friend, null);
  }
}              
MAP
              "reduce" => <<REDUCE,
function(ks, vs, co) {
  if (co) {
    return sum(vs);
  } else {
    return vs.length;
  }
}
REDUCE
            },
          }
        }
        @database.put @design
      end

      should "read reduced view" do
        res = @database.view "sample", "testview"
        assert_equal({"rows"=>["key"=>nil,"value"=>3]}, res)
      end

      should "read reduced view with key range" do
        res = @database.view "sample", "testview", :startkey=>"d"
        assert_equal({"rows"=>["key"=>nil,"value"=>2]}, res)
      end

      should "read non-reduced view" do
        res = @database.view "sample", "testview", :reduce=>false
        assert_equal 3, res['rows'].size, "expect 3 rows"
      end

      should "read non-reduced view with block" do
        docs = []
        @database.view("sample", "testview", :reduce=>false) { |doc| docs << doc }
        assert_equal 3, docs.size, "expect 3 rows"
      end

      should "read non-reduced view with specific keys" do
        res = @database.view "sample", "testview", :keys=>["eccles"], :reduce=>false, :include_docs=>true
        assert_equal 1, res['rows'].size, "expect 1 rows"
        assert_equal "eccles", res['rows'][0]['key']
        assert_equal "jim", res['rows'][0]['id']
        assert_equal "jim", res['rows'][0]['doc']['_id']
      end
    end
  end

  context "custom parser" do
    setup do
      @server = CouchTiny::Server.new :url=>SERVER_URL, :parser=>CouchTiny::Parser::JSObject
      @database = CouchTiny::Database.new @server, DATABASE_NAME
      @database.recreate_database!
      @doc1={"_id"=>"fred", "friend"=>"bluebottle"}
      @database.put @doc1
    end

    should "parse to extended hash" do
      res = @database.get "fred"
      assert_equal "fred", res._id
      assert_equal "bluebottle", res.friend
      assert_equal "bluebottle", res['friend']
    end
  end
end
