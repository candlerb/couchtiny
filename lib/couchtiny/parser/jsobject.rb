require 'json'
require 'jsobject'

module CouchTiny
  module Parser
    # This parser requires json-1.1.6 or later
    module JSObject
      def parse(src)
        ::JSON.parse(src, :object_class => ::JSObject)
      end
      module_function :parse

      def unparse(src)
        src.to_json
      end
      module_function :unparse
    end
  end
end
