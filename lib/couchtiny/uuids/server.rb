module CouchTiny end
module CouchTiny::UUIDS
  # Allocate uuids from the server, keeping a local pool for efficiency
  class Server
    def initialize(server, batch_size)
      @path = "/_uuids?count=#{batch_size}"
      @http = server.http
      @uuids = []
    end

    # Pick a uuid in a thread-safe way    
    def call
      3.times do
        res = @uuids.pop
        return res if res
        more = @http.get(@path)["uuids"]
        @uuids.concat(more) if more
      end
      raise "Failed to obtain uuid"
    end

    # For this class, bulk uuid generation is the same as normal generation
    def bulk
      self
    end

    # Yield a number of uuids
    def generate_with_index(n=1) #:yields: uuid
      n.times { |i| yield call, i }
    end

    def size
      @uuids.size
    end

    # We don't want to see a large splurge of uuids
    def inspect
      "#<#{self.class}:#{object_id} (#{@uuids.size})>"
    end
  end
end
