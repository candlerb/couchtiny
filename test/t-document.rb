require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny'
require 'couchtiny/document'
require 'jsobject'

class Foo < CouchTiny::Document
  use_database CouchTiny::Database.new(CouchTiny::Server.new(:url=>SERVER_URL), DATABASE_NAME)
  define_view "test_by_tag", <<-MAP
    function(doc) {
      if (doc.tag) {
        emit(doc.tag, null);
      }
    }
  MAP
end

class Bar < Foo
end

class CB < Foo
  @@log = []
  def self.log; @@log; end

  def before_save;    @@log << :before_save; end
  def after_save;     @@log << :after_save; end
  def before_create;  self.id = self["idattr"]; @@log << :before_create; end
  def after_create;   @@log << :after_create; end
  def before_update;  @@log << :before_update; end
  def after_update;   @@log << :after_update; end
  def before_destroy; @@log << :before_destroy; end
  def after_destroy;  @@log << :after_destroy; end
end

class AA < Foo
  auto_accessor
end

class Unattached < CouchTiny::Document
  # no use_database here
end

class TestDocument < Test::Unit::TestCase
  context "save and load" do
    setup do
      Foo.database.recreate_database!
      @d = CouchTiny::Document.new("tag"=>"a")   # type not set
      @f = Foo.new("tag"=>"b")
      @g = Foo.new("tag"=>"b2")
      @b = Bar.new("tag"=>"c")
      @z = {"type"=>"Zog", "tag"=>"d"}           # type unrecognised
      @u = Unattached.on(:dummy).new("tag"=>"e")
    end

    should "be new_record" do
      assert @f.new_record?
    end

    should "set type" do
      assert !@d.has_key?('type')
      assert_equal "Foo", @f['type']
      assert_equal "Foo", @g['type']
      assert_equal "Bar", @b['type']
      assert_equal "Zog", @z['type']
      assert_equal "Unattached", @u['type']
    end

    should "set database" do
      assert_nil @d.database
      assert_equal Foo.database, @f.database
      assert_equal Foo.database, @g.database
      assert_equal Foo.database, @b.database
      assert_equal :dummy, @u.database
    end

    context "saved individually" do
      setup do
        @d.database = Foo.database
        assert @d.save!
        assert @f.save!
        assert @g.save!
        assert @b.save!
        assert Foo.database.put(@z)['ok']
        @u.database = Foo.database
        assert @u.save!
      end

      should "not be new_record" do
        assert !@f.new_record?
      end

      should "set database, id and rev" do
        assert @d.database.instance_of?(CouchTiny::Database)
        assert @d.id
        assert @d.rev
      end
      
      should "load respecting type_attr" do
        d = Foo.get @d.id
        f = Foo.get @f.id
        g = Foo.get @g.id
        b = Foo.get @b.id
        z = Foo.get @z['_id']
        u = Foo.get @u.id

        assert d.instance_of?(CouchTiny::Document)
        assert f.instance_of?(Foo)
        assert g.instance_of?(Foo)
        assert b.instance_of?(Bar)
        assert z.instance_of?(CouchTiny::Document)
        assert u.instance_of?(Unattached)
        
        assert_equal "a", d["tag"]
        assert_equal "b", f["tag"]
        assert_equal "b2", g["tag"]
        assert_equal "c", b["tag"]
        assert_equal "d", z["tag"]
        assert_equal "e", u["tag"]
      end

      should "save update" do
        old_id = @f.id
        old_rev = @f.rev
        @f["tag"] = "wibble"
        assert @f.save!
        assert_equal old_id, @f.id
        assert_not_equal old_rev, @f.rev
      end

      should "destroy" do
        @f.destroy
        assert_raises(RestClient::ResourceNotFound) {
          Foo.get(@f.id)
        }
      end
      
      context "attachments" do
        should "save and retrieve attachment" do
          @f.put_attachment "wibble", "foobar"
          assert_equal "foobar", @f.get_attachment("wibble")
        end
        
        should "save content type" do
          @f.put_attachment "wibble", "foobar", "application/x-foo"
          f = Foo.get @f.id
          assert_equal "application/x-foo", f['_attachments']['wibble']['content_type']
        end
        
        should "destroy attachment" do
          @f.put_attachment "wibble", "foobar"
          @f.delete_attachment "wibble"
          assert_raises(RestClient::ResourceNotFound) {
            @f.get_attachment "wibble"
          }
        end
      end

      context "on unattached class" do
        should "raise if no database given" do
          assert_raises(RuntimeError) {
            Unattached.get @u.id
          }
        end
        
        should "load on database" do
          b = Unattached.on(Foo.database).get @u.id
          assert b.instance_of?(Unattached)
          assert_equal Foo.database, b.database
        end
      end

      context "user defined view" do
        should "return rows" do
          res = Foo.view "test_by_tag"
          assert_equal 6, res.size
          assert_equal ["id","key","value"], res.first.keys.sort
          assert_equal ["a","b","b2","c","d","e"], res.collect {|r| r['key'] }
        end

        should "yield rows" do
          res = []
          Foo.view("test_by_tag") { |r| res << r }
          assert_equal 6, res.size
          assert_equal ["id","key","value"], res.first.keys.sort
          assert_equal ["a","b","b2","c","d","e"], res.collect {|r| r['key'] }
        end
        
        should "return docs" do
          res = Foo.view "test_by_tag", :include_docs=>true
          assert_equal 6, res.size
          assert_equal ["a","b","b2","c","d","e"], res.collect {|r| r['tag'] }
          assert_equal [
            CouchTiny::Document,
            Foo,
            Foo,
            Bar,
            CouchTiny::Document,
            Unattached,
          ], res.collect {|r| r.class}
        end

        should "yield docs" do
          res = []
          Foo.view("test_by_tag", :include_docs=>true) { |r| res << r }
          assert_equal 6, res.size
          assert res.first.is_a?(CouchTiny::Document)
          assert_equal ["a","b","b2","c","d","e"], res.collect {|r| r['tag'] }
        end

        should "return raw" do
          res = Foo.view "test_by_tag", :include_docs=>true, :raw=>true
          assert_equal 6, res.size
          assert_equal ["doc","id","key","value"], res.first.keys.sort
        end

        should "yield raw" do
          res = []
          Foo.view("test_by_tag", :include_docs=>true, :raw=>true) { |r| res << r }
          assert_equal 6, res.size
          assert_equal ["doc","id","key","value"], res.first.keys.sort
        end

        should "set database on returned docs" do
          res = Unattached.on(Foo.database).view "test_by_tag", :include_docs=>true, :key=>"a"
          assert_equal 1, res.size
          assert_equal Foo.database, res.first.database
        end

        should "set database on yielded docs" do
          res = []
          Unattached.on(Foo.database).view("test_by_tag", :include_docs=>true, :key=>"a") { |r| res << r }
          assert_equal 1, res.size
          assert_equal Foo.database, res.first.database
        end

        should "return docs matching key" do
          res = Foo.view "test_by_tag", :key=>"c", :include_docs=>true
          assert_equal 1, res.size
          assert_equal "c", res.first['tag']
          assert_equal Bar, res.first.class
        end

        should "have Finder method" do
          res = Foo.view_test_by_tag
          assert_equal 6, res.size
        end
      end
      
      context "all view" do
        should "count" do
          assert_equal 2, Foo.count
          assert_equal 1, Bar.count
          assert_equal 1, CouchTiny::Document.on(Foo.database).count # type=nil
        end
        
        should "count with options" do
          assert_equal 4, Foo.count(:startkey=>"e")  # gives Foo x 2, Unattached, Zog
        end
        
        should "all" do
          fs = Foo.all
          assert_equal [Foo, Foo], fs.collect {|r| r.class}
          assert_equal ["b", "b2"], fs.collect {|r| r['tag']}.sort  # otherwise sorted by _id

          ds = CouchTiny::Document.on(Foo.database).all
          assert_equal 1, ds.size
          assert ds.first.is_a?(CouchTiny::Document)
          assert_equal "a", ds.first['tag']
        end
        
        should "all with options" do
          fs = Foo.all(:startkey=>"e")
          assert_equal [Foo, Foo, Unattached, CouchTiny::Document], fs.collect { |r| r.class }
        end

        # Perhaps we should have a helper function for this?
        should "count grouped" do
          res = Foo.view "all", :reduce=>true, :group=>true
          counts = {}
          res.each { |r| counts[r['key']] = r['value'] }
          assert_equal({nil=>1, 'Bar'=>1, 'Foo'=>2, 'Zog'=>1, 'Unattached'=>1}, counts)
        end
        
        should "work on specified database" do
          assert_equal 1, Unattached.on(Foo.database).count
          assert_equal 1, Unattached.on(Foo.database).all.size
        end
      end
    end
    
    context "bulk save" do
      setup do
        # Note that this works for documents not yet associated with
        # a database, documents associated with a database, and plain hashes
        @res = Foo.bulk_save [@d, @f, @g, @b, @z, @u]
      end

      should "give status" do
        assert_equal 6, @res.size
        @res.each do |r|
          assert r['id']
          assert r['rev']
          assert !r['error']
        end
      end

      should "set database, id and rev" do
        [:@d, :@f, :@g, :@b, :@u].each do |n|
          v = instance_variable_get(n)
          assert_equal Foo.database, v.database
          assert v.id
          assert v.rev
        end

        # This one is just a plain hash, no database accessor
        assert @z['_id']
        assert @z['_rev']
      end

      should "load respecting type attr" do
        d = Foo.get @d.id
        f = Foo.get @f.id
        g = Foo.get @g.id
        b = Foo.get @b.id
        z = Foo.get @z['_id']
        u = Foo.get @u.id

        assert d.instance_of?(CouchTiny::Document)
        assert f.instance_of?(Foo)
        assert g.instance_of?(Foo)
        assert b.instance_of?(Bar)
        assert z.instance_of?(CouchTiny::Document)
        assert u.instance_of?(Unattached)
        
        assert_equal "a", d["tag"]
        assert_equal "b", f["tag"]
        assert_equal "b2", g["tag"]
        assert_equal "c", b["tag"]
        assert_equal "d", z["tag"]
        assert_equal "e", u["tag"]
      end

      should "save update" do
        old_id = @f.id
        old_rev = @f.rev
        @f["tag"] = "wibble"
        Foo.bulk_save [@f]
        assert_equal old_id, @f.id
        assert_not_equal old_rev, @f.rev
      end
    end
  end

  context "class accessors" do
    should "have defaults" do
      assert Foo.database.instance_of?(CouchTiny::Database)
      assert Foo.design_doc.instance_of?(CouchTiny::Design)
      assert_equal '', Foo.design_doc.slug_prefix
      assert_equal 'type', Foo.type_attr
      assert_equal 'Foo', Foo.type_name
    end
    
    should "have write accessors" do
      begin
        db = Foo.class_eval { instance_variable_get :@database }
        
        Foo.use_database :dummy1
        Foo.use_design_doc CouchTiny::Design.new('Foo-')
        Foo.use_type_attr 'my-type'
        Foo.use_type_name 'zog'
        assert_equal :dummy1, Foo.database
        assert_equal :dummy1, Bar.database
        assert_equal 'Foo-', Foo.design_doc.slug_prefix
        assert_equal 'Foo-', Bar.design_doc.slug_prefix
        assert_equal 'my-type', Foo.type_attr
        assert_equal 'my-type', Bar.type_attr
        assert_equal 'zog', Foo.type_name
        assert_equal 'Bar', Bar.type_name  # not inherited!
      ensure
        Foo.class_eval {
          instance_variable_set :@database, db
          remove_instance_variable :@design_doc
          remove_instance_variable :@type_attr
          instance_variable_set :@type_name, "Foo"
        }
      end
    end
    
    should "override in subclass only" do
      begin
        Bar.use_database :dummy1
        Bar.use_design_doc CouchTiny::Design.new('Bar-')
        Bar.use_type_attr 'my-type'
        Bar.use_type_name 'zog'
        assert Foo.database.instance_of?(CouchTiny::Database)
        assert_equal :dummy1, Bar.database
        assert_equal '', Foo.design_doc.slug_prefix
        assert_equal 'Bar-', Bar.design_doc.slug_prefix
        assert_equal 'type', Foo.type_attr
        assert_equal 'my-type', Bar.type_attr
        assert_equal 'Foo', Foo.type_name
        assert_equal 'zog', Bar.type_name
      ensure
        Bar.class_eval {
          remove_instance_variable :@database
          remove_instance_variable :@design_doc
          remove_instance_variable :@type_attr
          instance_variable_set :@type_name, "Bar"
        }
      end
    end
  end

  context "Rails compatibility" do
    should "have to_param" do
      f = Foo.new
      f.id = "123"
      assert_equal "123", f.to_param
    end
  end

  context "Callbacks" do
    setup do
      Foo.database.recreate_database!
    end
    
    should "invoke callbacks" do
      CB.log.clear
      @foo = CB.new("hello"=>"world","idattr"=>"12345")
      @foo.save!
      assert_equal "12345", @foo.id
      assert_equal [:before_save, :before_create, :after_create, :after_save], CB.log

      CB.log.clear
      @foo.save!
      assert_equal [:before_save, :before_update, :after_update, :after_save], CB.log

      CB.log.clear
      @foo.destroy
      assert_equal [:before_destroy, :after_destroy], CB.log
    end
  end
  
  should "have auto accessor" do
    f = AA.new
    f.hello = "world"
    assert_equal "world", f.hello
    assert_equal "world", f["hello"]
  end
end
