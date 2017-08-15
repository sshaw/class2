# coding: utf-8

require "date"
require "active_support/core_ext/module"
require "active_support/core_ext/string"

require "class2/version"

def Class2(*args, &block)
  Class2.new(*args, &block)
end

class Class2
  CONVERSIONS = {
    Array     => lambda { |v| "Array(#{v})" },
    Date      => lambda { |v| "Date.parse(#{v})" },
    DateTime  => lambda { |v| "DateTime.parse(#{v})" },
    Float     => lambda { |v| "Float(#{v})" },
    Hash      => lambda { |v| sprintf "%s.respond_to?(:to_h) ? %s.to_h : %s", v, v, v },
    Integer   => lambda { |v| "Integer(#{v})" },
    String    => lambda { |v| "String(#{v})" },
    TrueClass => lambda do |v|
      sprintf '["1", 1, 1.0, true].freeze.include?(%s.is_a?(String) ? %s.strip : %s)', v, v, v
    end
  }

  CONVERSIONS[FalseClass] = CONVERSIONS[TrueClass]
  CONVERSIONS[Fixnum] = CONVERSIONS[Integer]
  CONVERSIONS.default = lambda { |v| v }

  class << self
    def new(*argz, &block)
      specs = argz
      namespace = Object

      if specs[0].is_a?(String) || specs[0].is_a?(Module)
        namespace = specs[0].is_a?(String) ? create_namespace(specs.shift) : specs.shift
      end

      specs.each do |spec|
        spec = [spec] unless spec.respond_to?(:each)
        spec.each { |klass, attributes| make_class(namespace, klass, attributes, block) }
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

    def split_and_normalize_attributes(attributes)
      nested = []
      simple = []

      attributes = [attributes] unless attributes.is_a?(Array)
      attributes.compact.each do |attr|
        # Just an attribute name, no type
        if !attr.is_a?(Hash)
          simple << { attr => nil }
          next
        end

        attr.each do |k, v|
          if v.is_a?(Hash) || v.is_a?(Array)
            if v.empty?
              # If it's empty it's not a nested spec, the attributes type is a Hash or Array
              simple << { k => v.class }
            else
              nested << { k => v }
            end
          else
            # Type can be a class name or an instance
            # If it's an instance, use its type
            v = v.class unless v.is_a?(Class)
            simple << { k => v }
          end
        end
      end

      [ nested, simple ]
    end

    def make_class(namespace, name, attributes, block)
      nested, simple = split_and_normalize_attributes(attributes)
      nested.each do |object|
        object.each { |klass, attrs| make_class(namespace, klass, attrs, block) }
      end

      make_method_name = lambda { |x| x.to_s.gsub(/[^\w]+/, "_") } # good enough

      klass = Class.new do
        def initialize(attributes = nil)
          return unless attributes.is_a?(Hash)
          assign_attributes(attributes)
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
            (#{simple.map { |n| n.keys.first } + nested.map { |n| n.keys.first }}).each do |name|
              hash[name] = public_send(name)
              next unless hash[name].respond_to?(:to_h)

              errors = [ ArgumentError, TypeError ]
              # Seems needlessly complicated, why doesn't Hash() do some of this?
              begin
                hash[name] = hash[name].to_h
                # to_h is dependent on its contents
              rescue *errors
                next unless hash[name].is_a?(Enumerable)
                hash[name] = hash[name].map do |e|
                  begin
                    e.respond_to?(:to_h) ? e.to_h : e
                  rescue *errors
                    e
                  end
                end
              end
            end

            hash
          end

          def __nested_attributes
            #{nested.map { |n| n.keys.first.to_sym }}.freeze
          end

          private :__nested_attributes
        CODE

        simple.each do |cfg|
          method, type = cfg.first
          method = make_method_name[method]

          # Use Enum somehow?
          retval = if type == Array || type.is_a?(Array)
                     "[]"
                   elsif type == Hash || type.is_a?(Hash)
                     "{}"
                   else
                     "nil"
                   end

          class_eval <<-CODE
            def #{method}
              @#{method} = #{retval} unless defined? @#{method}
              @#{method}
            end

            def #{method}=(v)
              @#{method} = #{CONVERSIONS[type]["v"]}
            end
          CODE
        end

        nested.map { |n| n.keys.first }.each do |method, _|
          method = make_method_name[method]
          attr_writer method

          retval = method == method.pluralize ? "[]" : "#{method.classify}.new"
          class_eval <<-CODE
            def #{method}
              @#{method} ||= #{retval}
            end
          CODE
        end

        # Do this last to allow for overriding the methods we define
        class_eval(&block) unless block.nil?

        private

        def assign_attributes(attributes)
          attributes.each do |key, value|
            if __nested_attributes.include?(key.respond_to?(:to_sym) ? key.to_sym : key) &&
               (value.is_a?(Hash) || value.is_a?(Array))

              name = key.to_s.classify

              # Only look in our namespace to prevent unwanted lookup
              next unless self.class.parent.const_defined?(name)

              klass = self.class.parent.const_get(name)
              value = value.is_a?(Hash) ? klass.new(value) : value.map { |v| klass.new(v) }
            end

            method = "#{key}="
            public_send(method, value) if respond_to?(method)
          end
        end
      end

      namespace.const_set(name.to_s.classify, klass)
    end
  end

  #
  # By default unknown arguments are ignored. <code>include<code>ing this will
  # cause an ArgumentError to be raised if an attribute is unknown:
  #
  module StrictConstructor
    def self.included(klass)
      klass.class_eval do
        def initialize(attributes = nil)
          return unless attributes.is_a?(Hash)
          assign_attributes(attributes)

          accepted = to_h.keys
          attributes.each do |name, _|
            next if accepted.include?(name.respond_to?(:to_sym) ? name.to_sym : name)
            raise ArgumentError, "unknown attribute: #{name}"
          end
        end
      end
    end
  end
end
