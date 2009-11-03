module CouchTiny
  class Document < DelegateDoc
    # This class implements the class-level finder methods on a
    # chosen database instance. Each Document subclass also gets its own
    # Finder subclass.
    class Finder
      attr_reader :database, :klass
      
      def initialize(database, klass)
        @database = database
        @klass = klass
      end

      # Retrieve a document by id. If the :open_revs option is supplied
      # then you will get an array of documents instead.
      def get(id, opt={})
        res = @database.get(id, opt)
        if opt[:open_revs]
          res.select { |r| r['ok'] && !r['ok']['_deleted'] }.map { |r| @klass.instantiate(r['ok'], @database) }
        else
          @klass.instantiate(res, @database)
        end
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

      def first(opt = {})
        all({:limit=>1}.merge(opt)).first
      end

      def last(opt = {})
        all({:limit=>1, :descending=>true}.merge(opt)).first
      end

      def new(h={}, &blk)
        @klass.new(h, @database, &blk)
      end

      def create!(*args, &blk)
        obj = new(*args, &blk)
        obj.save!
        obj
      end

      def name
        @klass.name
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

      # Bulk save documents - returns an array of result hashes. The callbacks
      # are invoked; any exceptions in them are returned in the result array.
      # This is so that moving to validate_doc_update in the CouchDB backend
      # should behave in a similar way. The record is not saved if any
      # exception occurs in the "before" callbacks, and the "after" callbacks
      # are only invoked if the record was successfully saved.
      def bulk_save(docs, opt={})
        result  = Array.new(docs.size)
        dbdocs  = []
        dbnew   = []
        dbindex = []
        type_attr = @klass.type_attr
        type_name = @klass.type_name
        docs.each_with_index do |doc,i|
          new_record = !doc['_rev']
          begin
            doc.instance_eval {
              before_save if respond_to?(:before_save, true)
              m = new_record ? :before_create : :before_update
              send(m) if respond_to?(m, true)
              begin
                doc[self.class.type_attr] ||= self.class.type_name if self.class.type_name
              rescue NoMethodError
                doc[type_attr] ||= type_name if type_name
              end
            }
          rescue RuntimeError, ArgumentError => e
            result[i] = {'id'=>doc['_id'], 'error'=>e.class.to_s, 'reason'=>(e.message rescue nil), 'exception'=>e}
          else
            dbdocs  << doc
            dbnew   << new_record
            dbindex << i
          end
        end
        
        unless dbdocs.empty?
          dbres = @database.bulk_docs(dbdocs, opt)
          dbdocs.each_with_index do |doc,i|
            result[dbindex[i]] = stat = dbres[i]
            next unless stat['rev']
            begin
              doc.database = @database if doc.respond_to?(:database=)
              doc.instance_eval {
                self.database = @database if respond_to?(:database=)
                m = dbnew[i] ? :after_create : :after_update
                send(m) if respond_to?(m, true)
                after_save if respond_to?(:after_save, true)
              }
            rescue RuntimeError, ArgumentError => e
              stat.replace('id'=>doc['_id'], 'error'=>e.class.to_s, 'reason'=>(e.message rescue nil), 'exception'=>e)
            end
          end
        end

        return result
      end

      # TODO: callbacks
      def bulk_destroy(docs, opt={})
        req = docs.collect do |doc|
          {"_id"=>doc["_id"], "_rev"=>doc["_rev"], "_deleted"=>true}
        end
        @database.bulk_docs(req, opt)
      end
    end
  end
end
