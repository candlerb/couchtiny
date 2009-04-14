require 'json'

module CouchTiny
  module Parser

    # A parser which allows an alternative generate method to be called,
    # and options to be passed to the parser. Example:
    #
    #   parser = CouchTiny::Parser::JSON(:pretty_generate, :max_nesting => false)

    class JSON
      def initialize(gen_method = :unparse, parse_opt = {:max_nesting => false})
        @gen_method = gen_method
        @parse_opt = parse_opt
      end
      
      def parse(body)
        ::JSON.parse(body, @parse_opt)
      end
      
      def unparse(obj)
        ::JSON.send(@gen_method, obj)
      end
    end
  end
end
