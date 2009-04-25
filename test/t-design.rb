require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny'
require 'couchtiny/design'

class TestDesign < Test::Unit::TestCase
  setup do
    @server = CouchTiny::Server.new :url=>SERVER_URL
    @database = CouchTiny::Database.new @server, DATABASE_NAME
    @database.recreate_database!
    @doc1={"_id"=>"fred", "friend"=>"bluebottle"}
    @doc2={"_id"=>"jim", "friend"=>"eccles"}
    @doc3={"_id"=>"trunky", "friend"=>"moriarty"}
    @database.bulk_docs [@doc1, @doc2, @doc3]
  end
                                              
  should "default to javascript" do
    des = CouchTiny::Design.new
    assert_equal "javascript", des.doc['language']
  end
  
  should "recalculate id" do
    des = CouchTiny::Design.new
    id1 = des.id

    des.define_view "foo", "abc"
    id2 = des.id
    assert_not_equal id1, id2

    des.define_view "foo", "abc", "def"
    id3 = des.id
    assert_not_equal id2, id3

    des.define_view "bar", "ghi"
    id4 = des.id
    assert_not_equal id3, id4
  end

  should "add a map view" do
    des = CouchTiny::Design.new
    des.define_view "friends", "function(doc) { if (doc.friend) emit(doc.friend, null); }"
    res = des.view_on @database, "friends", :key=>"eccles"
    assert_equal "jim", res['rows'][0]['id']
    assert_equal 4, @database.all_docs['rows'].size
  end

  context "map/reduce view with default options" do
    setup do
      @des = CouchTiny::Design.new
      @des.define_view "friends", <<MAP, CouchTiny::Design::REDUCE_COUNT, :reduce=>false
function(doc) {
  if (doc.friend) {
    emit(doc.friend, null);
  }
}
MAP
    end

    should "read view using default options" do
      res = @des.view_on @database, "friends"
      assert_equal 3, res['rows'].size, "expect 3 rows"
    end

    should "yield view using default options" do
      res = []
      @des.view_on(@database, "friends") { |r| res << r }
      assert_equal 3, res.size, "expect 3 rows"
    end

    should "override defaults" do
      res = @des.view_on @database, "friends", :reduce=>true
      assert_equal({"rows"=>["key"=>nil,"value"=>3]}, res)
    end

    should "reduce large dataset" do
      docs = []
      150.times do |i|
        docs << {"friend"=>"bluebottle"}
        docs << {"friend"=>"eccles"}
        docs << {"friend"=>"bluebottle"}
        docs << {"friend"=>"moriarty"}
      end
      @database.bulk_docs docs
      res = @des.view_on @database, "friends", :reduce=>true, :group=>true
      assert_equal 3, res['rows'].size
      counts = {}
      res['rows'].each { |r| counts[r['key']] = r['value'] }
      assert_equal({
        "bluebottle" => 301,
        "eccles" => 151,
        "moriarty" => 151,
      }, counts)
    end
  end

  context "map/reduce view with low cardinality" do
    setup do
      @des = CouchTiny::Design.new
      @des.define_view "friends", <<MAP, CouchTiny::Design::REDUCE_LOW_CARDINALITY
function(doc) {
  if (doc.friend) {
    emit(doc.friend, null);
  }
}
MAP
    end

    should "reduce small dataset" do
      res = @des.view_on @database, "friends"
      assert_equal 1, res['rows'].size
      assert_equal({
        "bluebottle" => 1,
        "eccles" => 1,
        "moriarty" => 1,
      }, res['rows'].first['value'])
    end

    should "reduce large dataset" do
      docs = []
      150.times do |i|
        docs << {"friend"=>"bluebottle"}
        docs << {"friend"=>"eccles"}
        docs << {"friend"=>"bluebottle"}
        docs << {"friend"=>"moriarty"}
      end
      @database.bulk_docs docs
      res = @des.view_on @database, "friends"
      assert_equal 1, res['rows'].size
      assert_equal({
        "bluebottle" => 301,
        "eccles" => 151,
        "moriarty" => 151,
      }, res['rows'].first['value'])
    end
  end
end
