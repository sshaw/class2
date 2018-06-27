# frozen_string_literal: true

require "date"
require "json"
require "active_support/core_ext/module"
require "active_support/inflector"

require "class2/version"

no_export = ENV["CLASS2_NO_EXPORT"]

unless no_export == "1"
  unless no_export == "Class2"
    def Class2(*args, &block)
      Class2.new(*args, &block)
    end
  end

  unless no_export == "class2"
    def class2(*args, &block)
      Class2.new(*args, &block)
    end
  end
end

class Class2
  CONVERSIONS = {
    Array     => lambda { |v| "Array(#{v})" },
    Date      => lambda { |v| "#{v} && Date.parse(#{v})" },
    DateTime  => lambda { |v| "#{v} && DateTime.parse(#{v})" },
    Float     => lambda { |v| "#{v} && Float(#{v})" },
    Hash      => lambda { |v| sprintf "%s.respond_to?(:to_h) ? %s.to_h : %s", v, v, v },
    Integer   => lambda { |v| "#{v} && Integer(#{v})" },
    String    => lambda { |v| "#{v} && String(#{v})" },
    TrueClass => lambda do |v|
      sprintf '["1", 1, 1.0, true].freeze.include?(%s.is_a?(String) ? %s.strip : %s)', v, v, v
    end
  }

  CONVERSIONS[FalseClass] = CONVERSIONS[TrueClass]
  CONVERSIONS[Fixnum] = CONVERSIONS[Integer] if defined?(Fixnum)
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

    def autoload(namespace = Object) # :nodoc:
      failure = lambda { |message|  abort "class2: cannot autoload class definitions: #{message}" }
      failure["cannot find the right caller"] unless caller.find do |line|
        # Ignore our autoload file and require()
        line.index("/class2/autoload.rb:").nil? && line.index("/kernel_require.rb:").nil? && line =~ /(.+):\d+:in\s+`\S/
      end

      # Give this precedence over global DATA constant
      data = String.new
      File.open($1) do |io|
        while line = io.gets
          if line == "__END__\n"
            data << line while line = io.gets
          end
        end
      end

      # Fallback to global constant if nothing found
      data = ::DATA.read if data.empty? && defined?(::DATA)
      failure["no data section found"] if data.empty?

      spec = JSON.parse(data)
      Class2.new(namespace, spec)
    rescue IOError, SystemCallError, JSON::ParserError => e
      failure[e.message]
    end

    private

    def create_namespace(str)
      str.split("::").inject(Object) do |parent, child|
        # empty? to handle "::Namespace"
        child.empty? ? parent : parent.const_defined?(child) ?
                                  # With 2.1 we can just say Object.const_defined?(str) but keep this around for now.
                                  parent.const_get(child) : parent.const_set(child, Module.new)
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
            v = v.class unless v.is_a?(Class) || v.is_a?(Module)
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

      name = name.to_s.classify
      return if namespace.const_defined?(name, false)

      make_method_name = lambda { |x| x.to_s.gsub(/[^\w]+/, "_") } # good enough

      klass = Class.new do
        def initialize(attributes = nil)
          __initialize(attributes)
        end

        class_eval <<-CODE, __FILE__, __LINE__
          def hash
            to_h.hash
          end

          def ==(other)
            return false unless other.instance_of?(self.class)
            to_h == other.to_h
          end

          alias eql? ==

          def to_h
            hash = {}
            self.class.__attributes.each do |name|
              hash[name] = v = public_send(name)
              # Don't turn nil into a Hash
              next if v.nil? || !v.respond_to?(:to_h)
              # Don't turn empty Arrays into a Hash
              next if v.is_a?(Array) && v.empty?

              errors = [ ArgumentError, TypeError ]
              # Seems needlessly complicated, why doesn't Hash() do some of this?
              begin
                hash[name] = v.to_h
                # to_h is dependent on its contents
              rescue *errors
                next unless v.is_a?(Enumerable)
                hash[name] = v.map do |e|
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

          def self.__nested_attributes
            #{nested.map { |n| n.keys.first.to_sym }}.freeze
          end

          def self.__attributes
            (#{simple.map { |n| n.keys.first.to_sym }} + __nested_attributes).freeze
          end
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

          class_eval <<-CODE, __FILE__, __LINE__
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

          retval = method == method.pluralize ? "[]" : "#{namespace}::#{method.classify}.new"
          class_eval <<-CODE
            def #{method}
              @#{method} ||= #{retval}
            end
          CODE
        end

        # Do this last to allow for overriding the methods we define
        class_eval(&block) unless block.nil?

        protected

        def __initialize(attributes)
          return unless attributes.is_a?(Hash)
          assign_attributes(attributes)
        end

        private

        def assign_attributes(attributes)
          attributes.each do |key, value|
            if self.class.__nested_attributes.include?(key.respond_to?(:to_sym) ? key.to_sym : key) &&
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

      namespace.const_set(name, klass)
    end
  end

  #
  # By default unknown arguments are ignored. <code>include<code>ing this will
  # cause an ArgumentError to be raised if an attribute is unknown.
  #
  module StrictConstructor
    def self.included(klass)
      klass.class_eval do
        def initialize(attributes = nil)
          return unless __initialize(attributes)
          attributes.each do |name, _|
            next if self.class.__attributes.include?(name.respond_to?(:to_sym) ? name.to_sym : name)
            raise ArgumentError, "unknown attribute: #{name}"
          end
        end
      end
    end
  end

  #
  # Support +CamelCase+ attributes. See Class2::SnakeCase.
  #
  module UpperCamelCase
    module Attributes
      def self.included(klass)
        Util.convert_attributes(klass) { |v| v.camelize }
      end
    end

    module JSON
      def as_json(*)
        Util.as_json(self, :camelize)
      end

      def to_json(*argz)
        as_json.to_json(*argz)
      end
    end
  end

  #
  # Support +camelCase+ attributes. See Class2::SnakeCase .
  #
  module LowerCamelCase
    module Attributes
      def self.included(klass)
        Util.convert_attributes(klass) { |v| v.camelize(:lower) }
      end
    end

    module JSON
      def as_json(*)
        Util.as_json(self, :camelize, :lower)
      end

      def to_json(*argz)
        as_json.to_json(*argz)
      end
    end
  end

  #
  # Use this when the class was not defined using a Hash with +snake_case+ keys
  # but +snake_case+ is a desired access or serialization mechanism.
  #
  module SnakeCase
    #
    # Support +snake_case+ attributes.
    # This will accept them in the constructor and return them via #to_h.
    #
    # The key format used to define the class will still be accepted and its accessors will
    # remain.
    #
    module Attributes
      def self.included(klass)
        Util.convert_attributes(klass) { |v| v.underscore }
      end
    end

    #
    # Create JSON documents that have +snake_case+ properties.
    # This will add #as_json and #to_json methods.
    #
    module JSON
      def as_json(*)
        Util.as_json(self, :underscore)
      end

      def to_json(*argz)
        as_json.to_json(*argz)
      end
    end
  end

  module Util
    def self.as_json(klass, *argz)
      hash = {}
      klass.to_h.each do |k, v|
        if v.is_a?(Hash)
          v = as_json(v, *argz)
        elsif v.is_a?(Array)
          v = v.map { |e| as_json(e, *argz) }
        elsif v.respond_to?(:as_json)
          v = v.as_json
        end

        hash[k.to_s.public_send(*argz)] = v
      end

      hash
    end

    def self.convert_attributes(klass)
      klass.class_eval do
        new_nested = []
        new_attributes = []

        __attributes.map do |old_name|
          new_name = yield(old_name.to_s)
          alias_method new_name, old_name
          alias_method "#{new_name}=", "#{old_name}="

          new_attributes << new_name.to_sym
          new_nested << new_attributes.last if __nested_attributes.include?(old_name)
        end

        class_eval <<-CODE
          def self.__attributes
            #{new_attributes}.freeze
          end

          # We need both styles nere to support proper assignment of nested attributes... :(
          def self.__nested_attributes
            #{new_nested + __nested_attributes}.freeze
          end
        CODE
      end
    end
  end

  private_constant :Util

end
