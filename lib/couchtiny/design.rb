require 'digest/md5'
require 'couchtiny/delegate_doc'
require 'couchtiny/utils'

module CouchTiny
  # This class wraps a hash containing a Design document. It calculates
  # an id based on the contents, so that if the design doc changes, it is
  # stored under a new name.
  #
  # TODO: allow other uses of design doc, like update validation

  class Design < DelegateDoc
    attr_accessor :default_view_opts, :slug_prefix
    include CouchTiny::Utils

    def self.default_doc
      {'language'=>'javascript'}
    end
    
    def initialize(slug_prefix = "", doc = self.class.default_doc)
      super(doc)
      @slug_prefix = slug_prefix
      @default_view_opts = {}
      changed
    end

    # Force recalculation of the slug
    def changed
      @slug = nil
    end

    def slug
      @slug ||= (
        md5 = Digest::MD5.new
        doc['views'].sort.each do |k,v|
          md5 << "#{k}/#{v['map']}#{v['reduce']}"
        end if doc['views']
        "#{@slug_prefix}#{md5.hexdigest}"
      )
    end

    def id
      "_design/#{slug}"
    end
    
    # Define a view:
    #   define_view "name", "map fn", [default opts]
    #   define_view "name", "map fn", "reduce fn", [default opts]
    # Any default options provided are used when invoking the view.
    # For example, you can define a reduce function but apply :reduce=>false
    # as an option, so that the reduce is only invoked when explicitly requested.
    def define_view(name, map, *args)
      name = name.to_s
      opt = args.pop if args.last.instance_of?(Hash)
      default_view_opts[name] = opt || {}
      doc['views'] ||= {}
      doc['views'][name] ||= {}
      doc['views'][name]['map'] = map
      doc['views'][name].delete('reduce')
      doc['views'][name]['reduce'] = args.shift unless args.empty?
      changed
    end
    
    # Fetch a view using this design document on a specific database
    # instance. Creates the design document if it does not exist.
    def view_on(db, name, opt={}, &blk) #:yields: row
      opt = default_view_opts[name.to_s].merge(opt)
      db.view(slug, name, opt, &blk)
    rescue  # TODO: only "resource not found" type errors
      db._put id, doc
      db.view(slug, name, opt, &blk)
    end

    # A useful generic reduce function for counting objects
    REDUCE_COUNT = <<REDUCE.freeze
function(ks, vs, co) {
  if (co) {
    return sum(vs);
  } else {
    return vs.length;
  }
}
REDUCE
  end
end
