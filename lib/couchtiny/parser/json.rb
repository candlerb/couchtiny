require 'json'

module CouchTiny
  module Parser

    # A parser which allows an alternative generate method to be called,
    # and options to be passed to the parser. Example:
    #
    #   parser = CouchTiny::Parser::JSON(:to_json, {:max_nesting => false}, {:except=>"foo"})

    class JSON
      def initialize(gen_method = :to_json, parse_opt = {:max_nesting => false}, *gen_opt)
        @gen_method = gen_method
        @parse_opt = parse_opt
        @gen_opt = gen_opt
      end
      
      def parse(body)
        ::JSON.parse(body, @parse_opt)
      end
      
      def unparse(obj)
        obj.send(@gen_method, *@gen_opt)
      end
    end
  end
end
