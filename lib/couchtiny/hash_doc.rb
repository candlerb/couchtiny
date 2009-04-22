module CouchTiny
  class HashDoc < Hash
    def initialize(h = nil)
      replace(h) if h
    end
    
    def doc
      self
    end
    
    def doc=(h)
      replace(h)
    end
  end
end
