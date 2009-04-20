module CouchTiny

  # Based on code from CouchRest
  #
  # This is a frig to allow multi-million line views to be read without
  # reading them all into RAM first. It relies on CouchDB putting newlines
  # in appropriate places.
  #
  # Written as a mixin so that it can be used in any HTTP driver which
  # requires it.
  #
  #--
  # TODO: rewrite using Net::HTTP (but that gives us chunks rather than lines)
  #++

  module CurlStreamer
    # When called with nil body: issue a GET
    #
    # When called with non-nil body: issue a POST
    #
    # In both cases, the response['rows'] is broken up into separate objects
    # and yielded individually
    def stream(path, body=nil) #:yields: row
      if body
        # Note: _temp_view in 0.9.0 insists on correct Content-Type
        args = ["curl -X POST -T - -H 'Content-Type: application/json' --silent '#{@url}#{path}'","r+"]
      else
        args = ["curl --silent '#{@url}#{path}'"]
      end
      first = nil
      IO.popen(*args) do |view|
        stream_body(view, body)
        first = view.gets
        while line = view.gets
          row = stream_parse_line(line)
          yield row if row
        end
      end
      stream_parse_first(first)
    end

    private

    def stream_body(io, body)
      if body
        io.write(unparse(body))
        io.close_write
      end
    end

    def stream_parse_line(line)
      return nil unless line
      if /\A(\{.*\})/.match(line.chomp)
        parse($1)
      end
    end

    def stream_parse_first(first)
      return nil unless first
      line = first.sub(/,[^,]*\z/,'')
      parse("#{line}}")
    rescue
      nil
    end
  end
end
