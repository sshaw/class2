# frozen_string_literal: true

require "active_support/inflector"

class Class2
  #
  # String inflection used to convert attribute names into class names, method
  # names, and JSON keys.
  #
  # A lightweight wrapper around ActiveSupport::Inflector. Class2 calls this
  # instead of ActiveSupport's String and Module extensions so that the
  # inflection library can be replaced without changing the rest of Class2.
  #
  module Inflector
    extend self

    def pluralize(word)
      ActiveSupport::Inflector.pluralize(word.to_s)
    end

    def singularize(word)
      ActiveSupport::Inflector.singularize(word.to_s)
    end

    #
    # Convert a table, attribute, or method name into a class name.
    # "user_statuses" => "UserStatus", "admin/user" => "Admin::User".
    #
    def classify(word)
      ActiveSupport::Inflector.classify(word.to_s)
    end

    #
    # "some_value" => "SomeValue", "some_value", true => "someValue".
    # "/" becomes "::".
    #
    # ActiveSupport's second argument is the opposite of `lower`: it is true
    # when the first letter should be upper cased.
    #
    def camelize(word, lower = false)
      ActiveSupport::Inflector.camelize(word.to_s, !lower)
    end

    #
    # "SomeValue" => "some_value", "Admin::User" => "admin/user".
    #
    def underscore(word)
      ActiveSupport::Inflector.underscore(word.to_s)
    end
  end
end
