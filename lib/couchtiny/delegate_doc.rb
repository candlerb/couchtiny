module CouchTiny
  # A class which delegates to a Hash
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
    def respond_to?(m)
      orig_respond_to?(m) || @doc.respond_to?(m)
    end

    def method_missing(m, *args, &block)
      if @doc.respond_to?(m)
        @doc.__send__(m, *args, &block)
      else
        super(m, *args, &block)
      end
    end
  end
end
