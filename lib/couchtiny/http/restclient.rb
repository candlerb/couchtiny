require 'restclient'
require 'couchtiny/curl_streamer'

module CouchTiny
  module HTTP
    # A simple HTTP adapter using the rest-client library. Options:
    #    :parser::
    #      (Required) The object which performs serialisation (unparse)
    #      and deserialisation (parse). e.g. :parser=>JSON
    #    :headers::
    #      (Optional) Headers to add to each request
    class RestClient
      include CouchTiny::CurlStreamer
      attr_reader :url, :parser
      
      def initialize(url, parser, opt={})
        @url = url
        @parser = parser || (raise "parser not specified")
        @headers = opt[:headers] || {}
      end
      
      def get(path, raw=false)
        wrap_exception do
          res = ::RestClient.get("#{@url}#{path}", @headers)
          res = parse(res) unless raw
          res
        end
      end
      
      def put(path, doc=nil, raw=false, content_type=nil)
        wrap_exception do
          doc = unparse(doc) if doc && !raw
          parse(::RestClient.put("#{@url}#{path}", doc,
            content_type ? @headers.merge(:content_type=>content_type) : @headers))
        end
      end
      
      def post(path, doc=nil)
        wrap_exception do
          doc = unparse(doc) if doc
          parse(::RestClient.post("#{@url}#{path}", doc, @headers))
        end
      end
      
      def delete(path)
        wrap_exception do
          parse(::RestClient.delete("#{@url}#{path}"))
        end
      end
      
      def copy(path, destination)
        wrap_exception do
          parse(::RestClient::Request.execute(
            :method => :copy,
            :url => "#{@url}#{path}",
            :headers => @headers.merge('Destination'=>destination)
          ))
        end
      end
      
      def parse(str)
        @parser.parse(str)
      end
      
      def unparse(obj)
        @parser.unparse(obj)
      end

      private
      # RestClient's exception hierarchy splits out 401 and 404, but
      # not other ones we care about with CouchDB like 409 and 412.
      # Maybe implement a new hierarchy some time.
      def wrap_exception
        yield
      rescue ::RestClient::ExceptionWithResponse => e
        resp = e.response
        msg = "#{resp.code} "
        begin
          err = parse(resp.body)
          msg << (err['error'] or raise "No error")
          msg << " (#{err['reason']})" if err['reason']
        rescue
          msg << resp.message.to_s
        end
        class << e; self; end.class_eval { define_method(:message) { msg } }
        raise
      end
    end
  end
end
