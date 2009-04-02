require 'json'

module JSObjectMixin
  def method_missing(meth,*rest,&blk)
    key = meth.to_s
    if key[-1] == ?=
      self[key[0..-2]] = rest.first
    else
      self[key]
    end
  end
end

# This class is like a Hash but with the semantics of a Javascript object:
# me.foo is the same as me['foo']
class JSObject < Hash
  include JSObjectMixin
end

#module CouchTiny
#  # This parser requires a patched version of the json library
#  module JSObjectParser
#    def parse(src)
#      ::JSON.parse(src, :object_class => JSObject)
#    end
#    module_function :parse
#
#    def unparse(src)
#      ::JSON.unparse(src)
#    end
#    module_function :unparse
#  end
#end

module CouchTiny
  module JSObjectParser
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
