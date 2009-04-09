require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny'

class TestServer < Test::Unit::TestCase
  should "have default URL" do
    s = CouchTiny::Server.new
    assert_equal 'http://127.0.0.1:5984', s.url
  end

  should "fetch uuid batches" do
    s = CouchTiny::Server.new :url=>SERVER_URL, :uuid_batch_size=>3
    u1 = s.next_uuid
    u2 = s.next_uuid
    u3 = s.next_uuid
    assert_equal 0, s.uuids.size
    u4 = s.next_uuid
    assert_equal 2, s.uuids.size
    assert_equal 4, [u1,u2,u3,u4].sort.uniq.size
  end
    
  should "create with options" do
    s = CouchTiny::Server.new :url=>"http://192.0.2.1", :uuids=>:dummy
    assert_equal 'http://192.0.2.1', s.url
    assert_equal :dummy, s.uuids
  end

  context "basic server tests" do
    setup do
      @server = CouchTiny::Server.new :url=>SERVER_URL
    end
    
    should "have accessors" do
      assert_equal SERVER_URL, @server.url
      assert_not_nil @server.http
      assert_not_nil @server.uuids
    end
    
    should "invoke database" do
      db = @server.database(DATABASE_NAME)
      assert_equal DATABASE_NAME, db.name
    end

    should "default to 100 uuids" do
      @server.next_uuid
      assert_equal 99, @server.uuids.size
    end
    
    should "get server info" do
      res = @server.info
      assert_not_nil res['version']
    end
    
    should "get all_dbs" do
      res = @server.all_dbs
      assert res.is_a?(Array)
    end
    
    should "get active_tasks" do
      res = @server.active_tasks
      assert res.is_a?(Array)
    end
    
    should "get config" do
      res = @server.config
      assert_not_nil res['httpd_global_handlers']
    end
    
    should "get stats" do
      res = @server.stats
      assert_not_nil res['httpd']
    end
    
    should "restart" do
      res = @server.restart!
      assert_equal true, res['ok']
    end

    should "replicate" do
      db = @server.database(DATABASE_NAME)
      db.recreate_database!
      db2 = @server.database(DATABASE2_NAME)
      db2.recreate_database!

      db.put "foo"=>"bar", "_id"=>"abcxyz"
      res = @server.replicate! DATABASE_NAME, DATABASE2_NAME
      assert_equal true, res['ok']
      assert_not_nil res['history']

      doc = db2.get "abcxyz"
      assert_equal "bar", doc["foo"]
      
      db2.delete_database!
    end
  end
end
