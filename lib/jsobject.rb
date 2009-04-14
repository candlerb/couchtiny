# Extend a Hash with this module to get semantics of a Javascript object:
# me.foo is the same as me['foo']
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
