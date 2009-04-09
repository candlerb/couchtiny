require 'restclient'
require 'couchtiny/curl_streamer'

module CouchTiny
  module HTTP
    # A simple HTTP adapter using the rest-client library. Options:
    #    :parser::
    #      (Required) The object which performs JSON serialisation (unparse)
    #      and deserialisation (parse)
    #    :headers::
    #      (Optional) headers to add to each request
    class RestClient
      include CouchTiny::CurlStreamer
      attr_reader :url, :parser
            
      def initialize(url, parser, opt={})
        @url = url
        @parser = parser || (raise "parser not specified")
        @headers = opt[:headers] || {}
      end
      
      def get(path)
        parse(::RestClient.get("#{@url}#{path}", @headers))
      end
      
      def put(path, doc=nil)
        doc = unparse(doc) if doc
        parse(::RestClient.put("#{@url}#{path}", doc, @headers))
      end
      
      def post(path, doc=nil)
        doc = unparse(doc) if doc
        parse(::RestClient.post("#{@url}#{path}", doc, @headers))
      end
      
      def delete(path)
        parse(::RestClient.delete("#{@url}#{path}"))
      end
      
      def copy(path, destination)
        parse(::RestClient::Request.execute(
          :method => :copy,
          :url => "#{@url}#{path}",
          :headers => @headers.merge('Destination'=>destination)
        ))
      end

      def parse(str)
        @parser.parse(str)
      end
      
      def unparse(obj)
        @parser.unparse(obj)
      end
    end
  end
end
