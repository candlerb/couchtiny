module CouchTiny
  # Object which keeps track of uuids for allocation
  class UUIDS
    def initialize(server, batch_size)
      @path = "/_uuids?count=#{batch_size}"
      @http = server.http
      @uuids = []
    end

    # Generate a uuid in a thread-safe way    
    def call
      3.times do
        res = @uuids.pop
        return res if res
        more = @http.get(@path)["uuids"]
        @uuids.concat(more) if more
      end
      raise "Failed to obtain uuid"
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
