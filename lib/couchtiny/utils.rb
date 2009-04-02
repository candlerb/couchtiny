module CouchTiny
  module Utils
    # Performs URI escaping so that you can construct proper
    # query strings faster.  Use this rather than the cgi.rb
    # version since it's faster.  (Stolen from Rack/Camping).
    def escape(s)
      s.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) {
        '%'+$1.unpack('H2'*$1.size).join('%').upcase
      }.tr(' ', '+')
    end
    module_function :escape

    # Unescapes a URI escaped string. (Stolen from Rack/Camping).
    def unescape(s)
      s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
        [$1.delete('%')].pack('H*')
      }
    end
    module_function :unescape

    def escape_docid(id)
      /\A_design\/(.*)/ =~ id ? "_design/#{CouchTiny::Utils.escape($1)}" : CouchTiny::Utils.escape(id)
    end
    module_function :escape_docid
  end
end
