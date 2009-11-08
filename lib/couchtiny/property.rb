require 'time'

module CouchTiny
  module Property
    def self.included(klass)
      klass.extend ClassMethods
    end

    module ClassMethods
      # Map type name to builder lambda
      BUILDER_MAP = {} #:nodoc:

      # Define a new type mapping for properties. e.g.
      #    property_builder(Integer, :integer) do |klass, name, opts|
      #      klass.class_eval {
      #        define_method(name) { self[name].to_i }
      #        define_method("#{name}=") { |val| self[name] = Integer(val) }
      #      }
      #    end

      def self.property_builder(*names, &blk)
        names.each do |name|
          BUILDER_MAP[name] = blk
        end
      end

      property_builder(nil, :generic) do |klass, name, opts|
        klass.class_eval {
          define_method(name) { self[name] }
          define_method("#{name}=") { |val| self[name] = val }
        }
      end
          
      property_builder(String, :string) do |klass, name, opts|
        klass.class_eval {
          define_method(name) { self[name].to_s }
          define_method("#{name}=") { |val| self[name] = val.to_s }
        }
      end

      property_builder(Integer, :integer) do |klass, name, opts|
        klass.class_eval {
          define_method(name) { self[name].to_i }
          define_method("#{name}=") { |val| self[name] = Integer(val) }
        }
      end

      property_builder(Float, :float) do |klass, name, opts|
        klass.class_eval {
          define_method(name) { self[name].to_f }
          define_method("#{name}=") { |val| self[name] = Float(val) }
        }
      end

      property_builder(Time, :time, :time_as_utc_text) do |klass, name, opts|
        klass.class_eval {
          define_method(name) { Time.parse(self[name]) }
          define_method("#{name}=") { |val| self[name] = val.getutc.strftime("%Y/%m/%d %H:%M:%S +0000") }
        }
      end

      property_builder(:time_as_iso8601_extended) do |klass, name, opts|
        klass.class_eval {
          define_method(name) { Time.parse(self[name]) }
          define_method("#{name}=") { |val| self[name] = val.getutc.strftime("%Y-%m-%dT%H:%M:%SZ") }
        }
      end

      property_builder(:time_as_iso8601_basic) do |klass, name, opts|
        klass.class_eval {
          define_method(name) { Time.parse(self[name]) }
          define_method("#{name}=") { |val| self[name] = val.getutc.strftime("%Y%m%dT%H%M%SZ") }
        }
      end

      # Define a property, and associate it with a type mapping. This
      # can be specified as a Ruby type, in which case the obvious
      # underlying JSON type will be used:
      #
      #    property :foo                    # or :type=>:generic
      #    property :foo, :type=>String     # or :type=>:string
      #    property :foo, :type=>Integer    # or :type=>:integer
      #    property :foo, :type=>Float      # or :type=>:float
      #
      # Or it can be any class which is a CouchTiny::Document (or indeed
      # any object which has a to_hash method, and whose initialize
      # method takes a single Hash)
      #
      #    property :foo, :type=>Bar
      
      def property(name, opts={})
        type = opts[:type]
        if builder = BUILDER_MAP[type]
          builder.call(self, name, opts)
        else
          # some arbitrary object
          define_method(name) { type.new(self[name] ||= {}) }
          define_method("#{name}=") { |val|
            case val
            when nil
              self[name] = nil
            when type
              self[name] = val.to_hash
            else
              raise ArgumentError, "Expected #{type}, got #{val.class}"
            end
          }
        end
      end
    end
  end
end
