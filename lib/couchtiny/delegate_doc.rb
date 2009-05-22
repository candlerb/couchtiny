module CouchTiny
  # A class which delegates a small subset of methods to a Hash (to keep
  # the space as clear as possible for accessor names)
  class DelegateDoc
    attr_accessor :doc

    def initialize(doc = {})
      @doc = doc.to_hash
    end

    def to_hash
      @doc
    end

    def ==(other)
      @doc == other # .to_hash is done by Hash#==
    end

    def to_json(*args)
      @doc.to_json(*args)
    end

    alias :orig_respond_to? :respond_to?
    def respond_to?(*m)
      orig_respond_to?(*m) || @doc.respond_to?(*m)
    end

    def [](k)
      @doc[k.to_s]
    end
    
    def []=(k,v)
      @doc[k.to_s] = v
    end
    
    def key?(k)
      @doc.key?(k)
    end
    
    def has_key?(k)
      @doc.has_key?(k)
    end

    def delete(k)
      @doc.delete(k)
    end

    def merge!(h)
      @doc.merge!(h)
    end

    def update(h)
      @doc.update(h)
    end

    #def method_missing(m, *args, &block)
    #  @doc.__send__(m, *args, &block)
    #end
  end
end
