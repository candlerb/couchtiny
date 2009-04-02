require 'restclient'
require 'couchtiny/curl_streamer'

module CouchTiny
  module HTTP
    # A simple HTTP adapter using the rest-client library. Options:
    #    :parser::
    #      The object which performs JSON serialisation (unparse) and
    #      deserialisation (parse)
    class RestClient
      include CouchTiny::CurlStreamer
      
      CONTENT_TYPE = 'application/json'.freeze
      HEADERS_GET = {:accept=>CONTENT_TYPE}.freeze
      
      # Note that POST to _temp_view fails if we don't send
      # Content-Type: application/json
      HEADERS_PUT = {:accept=>CONTENT_TYPE, :content_type=>CONTENT_TYPE}.freeze
      
      def initialize(opt)
        @parser = opt[:parser] || (require 'json'; ::JSON)
      end
      
      def get(url)
        parse(::RestClient.get(url, :accept=>CONTENT_TYPE))
      end
      
      def put(url, doc=nil)
        doc = unparse(doc) if doc
        parse(::RestClient.put(url, doc, doc ? HEADERS_PUT : HEADERS_GET))
      end
      
      def post(url, doc=nil)
        doc = unparse(doc) if doc
        parse(::RestClient.post(url, doc, doc ? HEADERS_PUT : HEADERS_GET))
      end
      
      def delete(url)
        parse(::RestClient.delete(url))
      end
      
      def copy(url, destination)
        parse(::RestClient::Request.execute(
          :method => :copy,
          :url => url,
          :headers => {:accept=>CONTENT_TYPE, 'Destination'=>destination}
        ))
      end

      def parse(*args)
        @parser.parse(*args)
      end
      
      def unparse(*args)
        @parser.unparse(*args)
      end
    end
  end
end
