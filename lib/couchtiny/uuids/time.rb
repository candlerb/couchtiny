module CouchTiny end
module CouchTiny::UUIDS
  # Time-based uuids are very useful because:
  # * views with equal keys sort in a natural order
  # * all_docs sorts in a natural order
  # * 'first' and 'last' are meaningful
  # * no need for separate 'created_at' attribute
  #
  # This implementation uses the top 48 bits for the time in milliseconds
  # after 1 Jan 1970, 16 bits for the PID, and the bottom 64 bits for a
  # pseudo-random ID. This ID will increment if you use the 'bulk' API
  class Time
    # Return one uuid
    def call
      Seq.new.call
    end

    # Return an object which returns consecutive uuids. This is intended
    # for bulk inserts so that the insertion order can be retained.
    # (The returned object is not thread-safe)
    def bulk
      Seq.new
    end

    class Seq #:nodoc:
      RAND_SIZE = (1<<80) - (1<<32)  #:nodoc:

      def initialize
        @ms = (::Time.now.to_f * 1000.0).to_i   # compatible with Javascript Date
        @pid = (Process.pid rescue rand(65536)) & 0xffff
        @seq = nil
      end

      def call
        @seq = @seq ? (@seq+1) : rand(RAND_SIZE)
        sprintf("%012x%04x%016x", @ms, @pid, @seq)
      end
    end
  end
end
