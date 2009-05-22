require 'couchtiny/delegate_doc'
require 'couchtiny/design'

# This document class implements the following functionality:
# - document is associated with a database: +doc.database = db+
# - class is optionally associated with a database: +Foo.use_database db+
# - instantiation of objects respects a definable 'type' attribute
# - class queries can be directed to any other database: +Foo.on(db)...+
# - a design doc, by default shared between all classes
# - a default view "all" to locate and count objects by type
#
#--
# TODO: casual view builder: Foo_by_bar_and_baz (inc testing of 'type' attr)
#++

module CouchTiny
  class Document < DelegateDoc
    attr_accessor :database
    
    def initialize(h = {}, database = self.class.database)
      super(h)
      @database = database
      if t = self.class.type_name
        doc[self.class.type_attr] = t
      end
      yield self if block_given?
      after_initialize
    end

    def inspect
      res = "#<#{self.class}:#{doc.inspect}"
      res << " on #{database.url}" if database
      res << ">"
    rescue
      super
    end
    
    def id;		doc['_id']; end
    def id=(x);		doc['_id'] = x; end
    def rev;		doc['_rev']; end
    def rev=(x);	doc['_rev'] = x; end
    def new_record?;	!doc['_rev']; end
    def to_param;	id; end

  private
    # Only very simple callback handling, useful for allocating ids.
    def before_create;	end
    def after_create;	end
    def before_update;	end
    def after_update;	end
    def before_save;	end
    def after_save;	end
    def before_destroy;	end
    def after_destroy;	end
    def after_find;	end
    def after_initialize; end

  public
    # Should always return true, since all errors should become exceptions.
    def save!
      new = new_record?
      before_save
      new ? before_create : before_update
      result = database.put(doc)['ok']
      new ? after_create : after_update
      after_save
      result
    end

    def destroy
      before_destroy
      database.delete(doc)['ok']
      after_destroy
    end

    def get_attachment(attach_name, opt={})
      database.get_attachment(doc, attach_name, opt)
    end

    def put_attachment(attach_name, data, content_type=nil)
      database.put_attachment(doc, attach_name, data, content_type)['ok']
    end

    def delete_attachment(attach_name)
      database.delete_attachment(doc, attach_name)['ok']
    end

    class << self
      def inherited(subclass)
        unless subclass.const_defined?(:Finder)
          subclass.const_set(:Finder, Class.new(self::Finder))
          type_to_class[subclass.name] = subclass
        end
      end

      # Mapping of permitted type names to classes. This prevents database
      # users from being able to create objects of arbitrary class.
      def type_to_class; @@type_to_class; end

      # Create an object of the class defined in its type attribute.
      # If no type attribute is present or value unknown, fallback to Document.
      # (ActiveRecord falls back to the model class, but this probably doesn't
      # make sense for CouchDB where there is only one 'table')
      def instantiate(doc = {}, db = database)
        klass = type_to_class[doc[type_attr]] || Document # ||self? ||raise?
        klass.new(doc, db) { |o| o.send(:after_find) }
      end
      
      # Set the default database for finder actions.
      #   class Foo
      #     use_database(db)
      #   end
      def use_database(db)
        @database=db
      end

      def database
        defined?(@database) ? @database : superclass.database
      end

      # Set the design doc. This must be called before
      # you define any views in this class. This can be used to put
      # certain classes in their own design documents.
      #   class Foo
      #     use_design_doc Design.new("Foo-", true)
      #   end
      #
      # To define a prefix for the whole application:
      #   CouchTiny::Document.use_design_doc Design.new("MyAppName-", true)
      def use_design_doc(x)
        @design_doc = x
      end

      def design_doc
        defined?(@design_doc) ? @design_doc : superclass.design_doc
      end

      # Set the attribute used for storing the type (default: 'type'). e.g.
      #  CouchTiny::Document.use_type_attr "couchrest-type"
      def use_type_attr(x)
        @type_attr = x.to_s
        define_view_all
      end

      def type_attr
        defined?(@type_attr) ? @type_attr : superclass.type_attr
      end

      # Set the type name stored in the database for this class.
      # Defaults to the class name.
      def use_type_name(x)
        x = x.to_s unless x.nil?
        type_to_class[x] = self
        @type_name = x
      end
      
      def type_name
        defined?(@type_name) ? @type_name : self.name
      end

      # Define a view using map and reduce functions. Note that it is
      # up to you to apply a class filter. e.g.
      #
      #   class Foo
      #     define_view "by_bar", <<-MAP
      #       function(doc) {
      #         if(doc['#{type_attr}'] == 'Foo' && doc.bar) {
      #           emit(doc.bar, null);
      #         }
      #       }
      #     MAP
      #   end
      #
      #   Foo.view_by_bar :key=>123
      #
      # The view is called "Foo_by_bar"
      def define_view(vname, map, *args)
        design_doc.define_view("#{name}_#{vname}", map, *args)
        self::Finder.class_eval "def view_#{vname}(opt={},&blk) view('#{name}_#{vname}',opt,&blk); end"
      end

      def define_view_all(map = nil, reduce = nil, opt = {:reduce=>false})
        if map.nil?
          map = <<-MAP
          function(doc) {
            emit(doc['#{type_attr}'] || null, null);
          }
          MAP
          reduce = Design::REDUCE_LOW_CARDINALITY if reduce.nil?
        else
          reduce = Design::REDUCE_COUNT if reduce.nil?
        end
        design_doc.define_view "all", map, reduce, opt
      end
      
      # Direct queries to a different database instance. e.g.
      #   Foo.on(db).view_by_bar :startkey=>123
      def on(database)
        self::Finder.new(database, self)
      end

      def method_missing(meth, *args, &blk)
        finder = self::Finder.new(database, self)
        if finder.respond_to?(meth)
          raise "Database not set - try use_database" unless finder.database
          finder.send(meth, *args, &blk)
        else
          super
        end
      end
      
      # Use method_missing to make dynamic accessor-like methods
      def auto_accessor
        include AutoAccessor
      end
    end

    @@type_to_class = {nil => self}
    @database = nil
    @design_doc = Design.new
    @type_attr = 'type'
    @type_name = nil
    define_view_all
    
    # This class implements the class-level finder methods on a
    # chosen database instance. Each Document subclass also gets its own
    # Finder subclass.
    class Finder
      attr_reader :database, :klass
      
      def initialize(database, klass)
        @database = database
        @klass = klass
      end

      def get(id, opt={})
        @klass.instantiate(@database.get(id, opt), @database)
      end

      # TODO:
      # - callbacks
      # - raise exception on error(s)? Unfortunately it's hard to know how
      #   to handle - there are no longer any transactions.
      def bulk_save(docs, opt={})
        docs.each do |doc|
          doc.database = @database if doc.respond_to?(:database=)
        end
        @database.bulk_docs(docs, opt)
      end

      def bulk_destroy(docs, opt={})
        req = docs.collect do |doc|
          {"_id"=>doc["_id"], "_rev"=>doc["_rev"], "_deleted"=>true}
        end
        @database.bulk_docs(req, opt)
      end

      # Return a view. Note that this dereferences the ['rows'] for you,
      # unlike CouchTiny::Database#view which gives the raw result.
      def view(vname, opt={}, &blk)
        raw = opt.delete(:raw) || opt[:reduce]
        if block_given?
          @klass.design_doc.view_on(@database, vname, opt) do |r|
            yield((!raw && r['doc']) ? @klass.instantiate(r['doc'], @database) : r)
          end
        else
          res = @klass.design_doc.view_on(@database, vname, opt)
          return res['rows'] if raw  # do we need the stats?
          res['rows'].collect { |r| r['doc'] ? @klass.instantiate(r['doc'], @database) : r }
        end
      end

      # Get multiple documents by ID, e.g. bulk_get(:keys=>["xxx","yyy"])
      def bulk_get(opt={}, &blk)
        opt[:include_docs] = true unless opt.has_key?(:include_docs)
        raw = opt.delete(:raw) || opt[:reduce]
        if block_given?
          @database.all_docs(opt) do |r|
            yield((!raw && r['doc']) ? @klass.instantiate(r['doc'], @database) : r)
          end
        else
          res = @database.all_docs(opt)
          return res['rows'] if raw  # do we need the stats?
          res['rows'].collect { |r| r['doc'] ? @klass.instantiate(r['doc'], @database) : r }
        end
      end

      # Get all docs (by default of this class only) using the global 'all' view
      def all(opt = {}, &blk)
        opt[:include_docs] = true unless opt.has_key?(:include_docs) || opt[:reduce]
        opt[:key] = @klass.type_name unless opt.delete(:all_classes) || [:key, :keys, :startkey, :endkey].find { |k| opt.has_key?(k) }
        view("all", opt, &blk)
      end

      def count(opt = {})
        if opt.empty?
          res = view('all', :reduce=>true)
          (res.first['value'][@klass.type_name || 'null'] || 0) rescue 0
        else
          res = all({:reduce=>true}.merge(opt))
          res.inject(0) { |total,r|
            total + r['value'].inject(0) { |subtot,(k,v)| subtot+v }
          }
        end
      end

      def new(h={}, &blk)
        @klass.new(h, @database, &blk)
      end

      def create!(*args, &blk)
        obj = new(*args, &blk)
        obj.save!
        obj
      end

      # Delete out-of-date design docs. Don't do this until all your model
      # classes have been loaded, or you may lose your current view data
      def cleanup_design_docs!
        return unless @klass.design_doc.with_slug
        prefix = "_design/#{@klass.design_doc.name_prefix}"
        current_id = @klass.design_doc.id
        dds_to_delete = []
        @database.all_docs(:startkey => prefix, :endkey => prefix+"~") do |d|
          next if d["id"] == current_id || d["id"] !~ /\A_design\/./
          dds_to_delete << {"_id"=>d["id"], "_rev"=>d["value"]["rev"], "_deleted"=>true}
        end
        @database.bulk_docs(dds_to_delete) unless dds_to_delete.empty?
      end
    end
    
    module AutoAccessor #:nodoc:
      def method_missing(meth,*rest,&blk)
        key = meth.to_s
        if key[-1] == ?=
          doc[key[0..-2]] = rest.first
        else
          doc[key]
        end
      end
    end
  end
end
