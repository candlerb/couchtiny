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
    end

    def id;		doc['_id']; end
    def id=(x);		doc['_id'] = x; end
    def rev;		doc['_rev']; end
    def rev=(x);	doc['_rev'] = x; end
    def to_param;	id; end

    # Should always return true, since all errors should become exceptions
    def save
      database.put(doc)['ok']
    end

    def destroy
      database.delete(doc)['ok']
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
          type_to_class[subclass.to_s] = subclass
        end
      end

      # Mapping of permitted type names to classes. This prevents database
      # users from being able to create objects of arbitrary class.
      def type_to_class; @@type_to_class; end

      # Create an object of the class defined in its type attribute.
      # If no type attribute is present or value unknown, fallback to Document.
      def instantiate(doc = {}, db = database)
        klass = type_to_class[doc[type_attr]] || Document # ||self? ||raise?
        klass.new(doc, db)
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
      #     use_design_doc Design.new("Foo-")
      #   end
      #
      # To define a prefix for the whole application:
      #   CouchTiny::Document.use_design_doc Design.new("MyAppName-")
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
        defined?(@type_name) ? @type_name : self.to_s
      end

      # Define a view using map and reduce functions. Note that it is
      # up to you to apply a class filter. e.g.
      #
      #   class Foo
      #     define_view "Foo_by_bar", <<-MAP
      #       function(doc) {
      #         if(doc.type == 'Foo' && doc.bar) {
      #           emit(doc.bar, null);
      #         }
      #       }
      #     MAP
      #   end
      #
      #   Foo.view_foo_by_bar :key=>123
      def define_view(name, map, *args)
        design_doc.define_view(name, map, *args)
        self::Finder.class_eval "def view_#{name.downcase}(opt={},&blk) view('#{name}',opt,&blk); end"
      end

      def define_view_all
        design_doc.define_view "all", <<-MAP, Design::REDUCE_COUNT, :reduce=>false
        function(doc) {
          emit(doc['#{type_attr}'] || null, null);
        }
        MAP
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

      def bulk_save(docs, opt={})
        docs.each do |doc|
          doc.database = @database if doc.respond_to?(:database=)
        end
        @database.bulk_docs(docs, opt)
      end
      
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

      def all(opt = {}, &blk)
        opt[:include_docs] = true unless opt.has_key?(:include_docs) || opt[:reduce]
        opt[:key] = @klass.type_name unless opt[:key] || opt[:keys] || opt[:startkey] || opt[:endkey]
        view("all", opt, &blk)
      end

      def count(opt = {})
        res = all({:reduce=>true}.merge(opt))
        case res.size
        when 0;	0
        when 1; res.first['value']
        else raise "Unexpected count result: #{res.inpect}"
        end
      end

      def new(h={}, &blk)
        @klass.new(h, @database, &blk)
      end
    end
  end
end
