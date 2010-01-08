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
  #
  # Usage examples:
  #
  #   require 'couchtiny'
  #   require 'couchtiny/uuids/time'
  #   CouchTiny::Server.options[:uuid_generator] = CouchTiny::UUIDS::Time.new
  #
  #   class CouchTiny::Document
  #     def created_time
  #       Time.at(id[0,12].to_i(16) / 1000.0) rescue nil
  #     end
  #   end
  #
  # Note: this is *not* the same as you get with
  #    [uuids]
  #    algorithm = utc_random
  # in more recent couchdb. In that, the time increments (by 1us) for each
  # document. I want to be able to bulk_save documents with identical timestamps.

  class Time
    # Return one uuid
    def call
      Seq.new.call
    end

    # Return an object which returns consecutive uuids. This is intended
    # for bulk inserts so that the insertion order can be retained.
    # (The returned object is not thread-safe)
    #
    # To allow a batch which both creates and updates records to have
    # exactly matching timestamps, you can pass in the time as option :time.
    def bulk(opt={})
      Seq.new(opt[:time])
    end

    class Seq #:nodoc:
      RAND_SIZE = (1<<64) - (1<<32)  #:nodoc:

      def initialize(time = nil)
        time ||= ::Time.now
        @ms = ((time.tv_sec * 1000) + (time.tv_usec / 1000)).to_i   # compatible with Javascript Date
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
