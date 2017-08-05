# coding: utf-8

require "class2/version"
require "active_support/core_ext/string"

class Class2
  def self.new(spec)
    spec = [spec] unless spec.respond_to?(:each)
    spec.each { |klass, attributes| make_class(klass, attributes) }
    nil
  end

  class << self
    private

    def make_class(name, attributes)
      attributes = [attributes] unless attributes.is_a?(Array)

      nested, simple = attributes.compact.partition { |e| e.is_a?(Hash) }
      nested.each do |object|
        object.each { |klass, _attributes| make_class(klass, _attributes) }
      end

      klass = Class.new do
        def initialize(attributes = nil)
          assign_attributes(attributes || {})
        end

        def assign_attributes(attributes)
          attributes.each do |key, value|
            if value.is_a?(Hash) || value.is_a?(Array)
              klass = self.class.const_get(key.to_s.classify)
              value = value.is_a?(Hash) ? klass.new(value) : value.map { |v| klass.new(v) }
            end

            public_send("#{key}=", value)
          end
        end

        simple.each { |method| attr_accessor method }

        nested.map { |n| n.keys.first }.each do |method, _|
          # TODO: Type checking on assign??
          attr_writer method

          method = method.to_s
          retval = method == method.pluralize ? "[]" : "#{method.classify}.new"
          class_eval <<-CODE
          def #{method}
            @#{method} ||= #{retval}
          end
        CODE
        end
      end

      Object.const_set(name.to_s.classify, klass)
    end
  end
end
