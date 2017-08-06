# coding: utf-8

require "class2/version"
require "active_support/core_ext/module"
require "active_support/core_ext/string"

def Class2(*args)
  Class2.new(*args)
end

class Class2
  class << self
    def new(*argz)
      specs = argz
      namespace = Object

      if specs[0].is_a?(String) || specs[0].is_a?(Module)
        namespace = specs[0].is_a?(String) ? create_namespace(specs.shift) : specs.shift
      end

      specs.each do |spec|
        spec.each { |klass, attributes| make_class(namespace, klass, attributes) }
      end

      nil
    end

    private

    def create_namespace(str)
      str.split("::").inject(Object) do |parent, child|
        # empty? to handle "::Namespace"
        child.empty? ? parent : parent.const_set(child, Module.new)
      end
    end

    def make_class(namespace, name, attributes)
      attributes = [attributes] unless attributes.is_a?(Array)

      nested, simple = attributes.compact.partition { |e| e.is_a?(Hash) }
      nested.each do |object|
        object.each { |klass, attrs| make_class(namespace, klass, attrs) }
      end

      klass = Class.new do
        def initialize(attributes = nil)
          assign_attributes(attributes || {})
        end

        class_eval <<-CODE
          def hash
            to_h.hash
          end

          def ==(other)
            return false unless other.instance_of?(self.class)
            to_h == other.to_h
          end

          alias :eql? :==

          def to_h
            hash = {}
            (#{simple + nested.map { |n| n.keys.first }}).each do |name|
              hash[name] = public_send(name)
              hash[name] = hash[name].to_h if hash[name].respond_to?(:to_h)
            end

            hash
          end
        CODE

        simple.each { |method| attr_accessor method }

        nested.map { |n| n.keys.first }.each do |method, _|
          attr_writer method

          method = method.to_s
          retval = method == method.pluralize ? "[]" : "#{method.classify}.new"
          class_eval <<-CODE
            def #{method}
              @#{method} ||= #{retval}
            end
          CODE
        end

        private

        def assign_attributes(attributes)
          attributes.each do |key, value|
            if value.is_a?(Hash) || value.is_a?(Array)
              name  = key.to_s.classify
              klass = Object.const_defined?(name) ? Object.const_get(name) : self.class.parent.const_get(name)
              value = value.is_a?(Hash) ? klass.new(value) : value.map { |v| klass.new(v) }
            end

            public_send("#{key}=", value)
          end
        end
      end

      namespace.const_set(name.to_s.classify, klass)
    end
  end
end
