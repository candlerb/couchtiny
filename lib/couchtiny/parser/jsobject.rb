require 'json'
require 'jsobject'

module CouchTiny
  module Parser
    module JSObject
      def parse(src)
        tree = ::JSON.parse(src)
        extend_jsobject(tree)
      end
      module_function :parse

      # Walk a JSON object tree, extending all Hashes found with JSObjectMixin
      def extend_jsobject(tree)
        case tree
        when Hash
          tree.extend JSObjectMixin
          tree.each do |k,v|
            extend_jsobject(v)
          end
        when Array
          tree.each do |v|
            extend_jsobject(v)
          end
        end
      end
      module_function :extend_jsobject
      
      def unparse(src)
        ::JSON.unparse(src)
      end
      module_function :unparse
    end
  end
end

#module CouchTiny
#  module Parser
#    # This parser requires a patched version of the json library
#    # but is more efficient
#    module JSObject
#      def parse(src)
#        ::JSON.parse(src, :object_class => ::JSObject)
#      end
#      module_function :parse
#
#      def unparse(src)
#        ::JSON.unparse(src)
#      end
#      module_function :unparse
#    end
#  end
#end
