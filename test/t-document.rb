require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny'
require 'couchtiny/document'

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
  attr_reader :log
  def initialize(h={}, db=self.class.database)
    @log = []
    super
  end

private
  def after_find;     @log << :after_find; end
  def after_initialize; @log << :after_initialize; end
  def before_save;    @log << :before_save; end
  def after_save;     @log << :after_save; end
  def before_create;  self.id = self["idattr"] if self["idattr"]; @log << :before_create; end
  def after_create;   @log << :after_create; end
  def before_update;  @log << :before_update; end
  def after_update;   @log << :after_update; end
  def before_destroy; @log << :before_destroy; end
  def after_destroy;  @log << :after_destroy; end
end

class AA < Foo
  auto_accessor
end

class Unattached < CouchTiny::Document
  # no use_database here
end

class TestDocument < Test::Unit::TestCase
  should "have name method in Finder" do
    assert_equal "Unattached", Unattached.on(:dummy).name
  end

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
        assert_equal true, @d.save!
        assert_equal true, @f.save!
        assert_equal true, @g.save!
        assert_equal true, @b.save!
        assert Foo.database.put(@z)['ok']
        @u.database = Foo.database
        assert_equal true, @u.save!
      end

      should "set type" do
        assert !@d.has_key?('type')
        assert_equal "Foo", @f['type']
        assert_equal "Foo", @g['type']
        assert_equal "Bar", @b['type']
        assert_equal "Zog", @z['type']
        assert_equal "Unattached", @u['type']
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

      should "load in bulk" do
        res = Foo.bulk_get :keys=>[@d.id, @f.id, @g.id, @b.id]
        assert_equal 4, res.size
        assert_equal ["a","b","b2","c"], res.collect { |r| r['tag'] }
        assert_equal [CouchTiny::Document, Foo, Foo, Bar], res.collect { |r| r.class }
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
        assert_raises(TEST_HTTP_NOT_FOUND) {
          Foo.get(@f.id)
        }
      end
      
      context "attachments" do
        should "save and retrieve attachment" do
          @f.put_attachment "wibble", "foobar"
          assert_equal "foobar", @f.get_attachment("wibble")
        end
        
        should "retrieve attachment info" do
          @f.put_attachment "wibble", "abc"
          f = Foo.get @f.id
          assert f.has_attachment?("wibble")
          assert !f.has_attachment?("bibble")
          assert_equal 3, f.attachment_info("wibble")["length"]
        end
        
        should "save content type" do
          @f.put_attachment "wibble", "foobar", "application/x-foo"
          f = Foo.get @f.id
          assert_equal "application/x-foo", f['_attachments']['wibble']['content_type']
        end
        
        should "destroy attachment" do
          @f.put_attachment "wibble", "foobar"
          @f.delete_attachment "wibble"
          assert_raises(TEST_HTTP_NOT_FOUND) {
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
        should "have class in actual view name" do
          res = Foo.view "Foo_test_by_tag"
          assert_equal 6, res.size
        end

        should "return rows" do
          res = Foo.view_test_by_tag
          assert_equal 6, res.size
          assert_equal ["id","key","value"], res.first.keys.sort
          assert_equal ["a","b","b2","c","d","e"], res.collect {|r| r['key'] }
        end

        should "yield rows" do
          res = []
          Foo.view_test_by_tag { |r| res << r }
          assert_equal 6, res.size
          assert_equal ["id","key","value"], res.first.keys.sort
          assert_equal ["a","b","b2","c","d","e"], res.collect {|r| r['key'] }
        end
        
        should "return docs" do
          res = Foo.view_test_by_tag :include_docs=>true
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
          Foo.view_test_by_tag(:include_docs=>true) { |r| res << r }
          assert_equal 6, res.size
          assert res.first.is_a?(CouchTiny::Document)
          assert_equal ["a","b","b2","c","d","e"], res.collect {|r| r['tag'] }
        end

        should "return raw" do
          res = Foo.view_test_by_tag :include_docs=>true, :raw=>true
          assert_equal 6, res.size
          assert_equal ["doc","id","key","value"], res.first.keys.sort
        end

        should "yield raw" do
          res = []
          Foo.view_test_by_tag(:include_docs=>true, :raw=>true) { |r| res << r }
          assert_equal 6, res.size
          assert_equal ["doc","id","key","value"], res.first.keys.sort
        end

        should "set database on returned docs" do
          res = Unattached.on(Foo.database).view "Foo_test_by_tag", :include_docs=>true, :key=>"a"
          assert_equal 1, res.size
          assert_equal Foo.database, res.first.database
        end

        should "set database on yielded docs" do
          res = []
          Unattached.on(Foo.database).view("Foo_test_by_tag", :include_docs=>true, :key=>"a") { |r| res << r }
          assert_equal 1, res.size
          assert_equal Foo.database, res.first.database
        end

        should "return docs matching key" do
          res = Foo.view_test_by_tag :key=>"c", :include_docs=>true
          assert_equal 1, res.size
          assert_equal "c", res.first['tag']
          assert_equal Bar, res.first.class
        end

        should "return docs matching keys" do
          res = Foo.view_test_by_tag :keys=>["c","d"], :include_docs=>true
          assert_equal 2, res.size
          assert_equal "c", res[0]['tag']
          assert_equal "d", res[1]['tag']
        end
      end
      
      context "all view" do
        should "count" do
          assert_equal 2, Foo.count
          assert_equal 1, Bar.count
          assert_equal 1, CouchTiny::Document.on(Foo.database).count # type=nil
        end
        
        # Note: these are quite inefficient as they force a re-reduce across
        # the database. Better just to read the overall reduced value (see
        # "count grouped" below) and add the elements required.
        should "count with options" do
          assert_equal 4, Foo.count(:startkey=>"e")  # gives Foo x 2, Unattached, Zog
          assert_equal 3, Foo.count(:keys=>["Foo","Bar"], :group=>true)
        end
        
        should "count all_classes" do
          assert_equal 6, Foo.count(:all_classes=>true)
        end
        
        should "all" do
          fs = Foo.all
          assert_equal [Foo, Foo], fs.collect {|r| r.class}
          assert_equal ["b", "b2"], fs.collect {|r| r['tag']}.sort  # otherwise sorted by _id

          ds = CouchTiny::Document.on(Foo.database).all
          assert_equal 1, ds.size
          assert ds.first.is_a?(CouchTiny::Document)
          assert_equal "a", ds.first['tag']

          ds = Foo.all(:key=>nil)   # another way of doing the same thing
          assert_equal 1, ds.size
        end

        should "all with :all_classes" do
          assert_equal 6, Foo.all(:all_classes=>true).size
        end

        should "all with :include_docs=>false" do
          fs = Foo.all(:include_docs=>false)
          assert_equal 2, fs.size
          assert_equal ["id","key","value"], fs.first.keys.sort
        end

        should "all with options" do
          fs = Foo.all(:startkey=>"e")
          assert_equal [Foo, Foo, Unattached, CouchTiny::Document], fs.collect { |r| r.class }

          res = Foo.all(:keys=>["Foo","Bar"])
          assert_equal [Foo,Foo,Bar], res.collect {|r| r.class}
        end

        should "first and last" do
          first = Foo.first
          last = Foo.last
          assert_equal [Foo, Foo], [first.class, last.class]
          assert first.id < last.id
        end

        # Perhaps we should have a helper function for this?
        should "count grouped" do
          counts = Foo.all(:all_classes=>true, :reduce=>true).first['value']
          assert_equal({'null'=>1, 'Bar'=>1, 'Foo'=>2, 'Zog'=>1, 'Unattached'=>1}, counts)
        end
        
        should "work on specified database" do
          assert_equal 1, Unattached.on(Foo.database).count
          assert_equal 1, Unattached.on(Foo.database).all.size
        end
      end
    end
    
    should "create!" do
      res = Foo.create!('_id' => 'hello')
      assert_equal Foo, res.class
      assert_equal 'hello', res.id
      Foo.get('hello')
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

      should "set type" do
        assert !@d.has_key?('type')
        assert_equal "Foo", @f['type']
        assert_equal "Foo", @g['type']
        assert_equal "Bar", @b['type']
        assert_equal "Zog", @z['type']
        assert_equal "Unattached", @u['type']
      end

      should "set finder's default type for non-document objects" do
        n = {"hello"=>"world"}
        Foo.bulk_save [n]
        assert n['_id']
        assert_equal "Foo", n['type']
        
        m = Bar.get n['_id']
        assert_equal Foo, m.class
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
      
      should "bulk_destroy" do
        assert_equal 6, Foo.count(:all_classes => true)
        res = Foo.bulk_destroy [@b, @z]
        assert_equal 2, res.size
        res.each do |r|
          assert r['id']
          assert r['rev']
          assert !r['error']
        end

        assert_equal 4, Foo.count(:all_classes => true)
      end
    end
  end

  context "class accessors" do
    should "have defaults" do
      assert Foo.database.instance_of?(CouchTiny::Database)
      assert Foo.design_doc.instance_of?(CouchTiny::Design)
      assert_equal '', Foo.design_doc.name_prefix
      assert_equal 'type', Foo.type_attr
      assert_equal 'Foo', Foo.type_name
    end
    
    should "have write accessors" do
      begin
        db = Foo.class_eval { instance_variable_get :@database }
        
        Foo.use_database :dummy1
        Foo.use_design_doc CouchTiny::Design.new('Foo-', true)
        Foo.use_type_attr 'my-type'
        Foo.use_type_name 'zog'
        assert_equal :dummy1, Foo.database
        assert_equal :dummy1, Bar.database
        assert_equal 'Foo-', Foo.design_doc.name_prefix
        assert_equal 'Foo-', Bar.design_doc.name_prefix
        assert Foo.design_doc.with_slug
        assert Bar.design_doc.with_slug
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
        Bar.use_design_doc CouchTiny::Design.new('Bar')
        Bar.use_type_attr 'my-type'
        Bar.use_type_name 'zog'
        assert Foo.database.instance_of?(CouchTiny::Database)
        assert_equal :dummy1, Bar.database
        assert_equal '', Foo.design_doc.name_prefix
        assert_equal 'Bar', Bar.design_doc.name_prefix
        assert Foo.design_doc.with_slug
        assert !Bar.design_doc.with_slug
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

  context "multiple design doc versions" do
    setup do
      @klass = Class.new(CouchTiny::Document)
      @klass.use_database Foo.database
      @klass.database.recreate_database!
    end
    
    should "cleanup_design_docs!" do
      id1 = @klass.design_doc.id

      @klass.define_view "view1", "function(doc){}"
      id2 = @klass.design_doc.id
      @klass.view_view1

      @klass.define_view "view2", "function(doc){emit(null,null);}"
      id3 = @klass.design_doc.id
      @klass.view_view2
      
      assert_equal 3, [id1, id2, id3].uniq.size
      assert_equal [id2, id3].sort,
                   @klass.database.all_docs['rows'].map { |d| d['id'] }.sort
      
      @klass.cleanup_design_docs!
      
      assert_equal [id3], @klass.database.all_docs['rows'].map { |d| d['id'] }
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
      @foo = CB.new("hello"=>"world","idattr"=>"12345")
      assert_equal [:after_initialize], @foo.log
      
      @foo.log.clear
      @foo.save!
      assert_equal "12345", @foo.id
      assert_equal [:before_save, :before_create, :after_create, :after_save], @foo.log

      @foo.log.clear
      @foo.save!
      assert_equal [:before_save, :before_update, :after_update, :after_save], @foo.log

      res = CB.get "12345"
      assert_equal [:after_find, :after_initialize], res.log
      
      @foo.log.clear
      @foo.destroy
      assert_equal [:before_destroy, :after_destroy], @foo.log
    end
  end
  
  context "Callbacks with bulk_save" do
    setup do
      Foo.database.recreate_database!
      @c1 = CB.new("val"=>1)
      @c2 = CB.create!("val"=>2, "idattr"=>"b")
      @c3 = CB.create!("val"=>3)
      @c4 = CB.new("val"=>4, "idattr"=>"d")
      [@c1, @c2, @c3, @c4].each { |c| c.log.clear }
    end

    should "invoke callbacks on successful save" do
      assert_equal [2,3], CB.all.collect { |c| c['val'] }.sort
      res = Foo.bulk_save [@c1, @c2, @c3, @c4]
      res.each { |r| assert r['rev']; assert r['id'] }
      [@c1, @c2, @c3, @c4].each { |c| assert c['_id'] }
      assert_equal [:before_save, :before_create, :after_create, :after_save], @c1.log
      assert_equal [:before_save, :before_update, :after_update, :after_save], @c2.log
      assert_equal [:before_save, :before_update, :after_update, :after_save], @c3.log
      assert_equal [:before_save, :before_create, :after_create, :after_save], @c4.log
      assert_equal [1,2,3,4], CB.all.collect { |c| c['val'] }.sort
    end

    should "skip callbacks on failed update" do
      @c3['_rev'] = "0-00000"
      res = Foo.bulk_save [@c1, @c2, @c3, @c4]
      assert_equal [true, true, false, true], res.collect { |r| r.has_key?('rev') }
      assert_equal [:before_save, :before_create, :after_create, :after_save], @c1.log
      assert_equal [:before_save, :before_update, :after_update, :after_save], @c2.log
      assert_equal [:before_save, :before_update], @c3.log
      assert_equal [:before_save, :before_create, :after_create, :after_save], @c4.log
      assert_match /conflict/i, res[2]['error']
      assert_equal "d", res[3]['id']
    end

    should "catch exceptions in callbacks" do
      @c1['val'] = 91
      @c2['val'] = 92
      @c3['val'] = 93
      @c4['val'] = 94
      def @c1.before_save
        raise "err1"
      end
      def @c2.before_update
        raise "err2"
      end
      def @c3.after_update
        raise "err3"
      end
      def @c4.after_save
        raise "err4"
      end
      res = Foo.bulk_save [@c1, @c2, @c3, @c4]
      assert_equal [], @c1.log
      assert_equal [:before_save], @c2.log
      assert_equal [:before_save, :before_update], @c3.log
      assert_equal [:before_save, :before_create, :after_create], @c4.log
      assert_equal ["err1","err2","err3","err4"], res.collect {|r| r['reason']}
      res.each { |r| assert_equal "RuntimeError", r['error'] }

      # Only c3 and c4 saved successfully. c2 was already on disk but
      # not updated.
      assert_equal [2,93,94], CB.all.collect { |c| c['val'] }.sort
    end
  end
  
  should "have auto accessor" do
    f = AA.new
    f.hello = "world"
    assert_equal "world", f.hello
    assert_equal "world", f["hello"]
  end

  # Ensure we're working when Rails reloads model classes
  should "create objects after class has been redefined" do
    class ::Flurble < CouchTiny::Document; end
    klass1 = ::Flurble
    ::Flurble.on(Foo.database).create!('_id' => 'test')

    Object.send(:remove_const, :Flurble)
    class ::Flurble < CouchTiny::Document; end
    klass2 = ::Flurble
    
    assert klass1 != klass2, "I expect a new Flurble class object"
    
    res = CouchTiny::Document.on(Foo.database).get('test')
    assert ::Flurble === res, "The loaded object should be of the new #{klass2} class (#{klass2.object_id}), but it was #{res.class} (#{res.class.object_id})"
  end
end
