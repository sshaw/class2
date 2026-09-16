# frozen_string_literal: true

require "dry/inflector"

class Class2
  #
  # String inflection used to convert attribute names into class names, method
  # names, and JSON keys.
  #
  # dry-inflector provides the rule engine, but it is loaded with ActiveSupport
  # 6.1's rules and case conversion so that the names Class2 generates are the
  # same as when ActiveSupport provided the inflector. dry-inflector's rules,
  # acronyms (API, JSON, HTTP, ...), and uncountables differ from ActiveSupport's
  # and would change class names and plural attribute detection.
  #
  module Inflector
    extend self

    # ActiveSupport's uncountables.
    UNCOUNTABLE = %w[
      equipment information rice money species series fish sheep jeans police
    ].freeze

    #
    # Rules are prepended, so the last one added is the first one applied and
    # they are added here in ActiveSupport's order so they have its precedence.
    #
    INFLECTOR = Dry::Inflector.new do |inflections|
      inflections.plural(/$/, "s")
      inflections.plural(/s$/i, "s")
      inflections.plural(/^(ax|test)is$/i, '\1es')
      inflections.plural(/(octop|vir)us$/i, '\1i')
      inflections.plural(/(octop|vir)i$/i, '\1i')
      inflections.plural(/(alias|status)$/i, '\1es')
      inflections.plural(/(bu)s$/i, '\1ses')
      inflections.plural(/(buffal|tomat)o$/i, '\1oes')
      inflections.plural(/([ti])um$/i, '\1a')
      inflections.plural(/([ti])a$/i, '\1a')
      inflections.plural(/sis$/i, "ses")
      inflections.plural(/(?:([^f])fe|([lr])f)$/i, '\1\2ves')
      inflections.plural(/(hive)$/i, '\1s')
      inflections.plural(/([^aeiouy]|qu)y$/i, '\1ies')
      inflections.plural(/(x|ch|ss|sh)$/i, '\1es')
      inflections.plural(/(matr|vert|ind)(?:ix|ex)$/i, '\1ices')
      inflections.plural(/^(m|l)ouse$/i, '\1ice')
      inflections.plural(/^(m|l)ice$/i, '\1ice')
      inflections.plural(/^(ox)$/i, '\1en')
      inflections.plural(/^(oxen)$/i, '\1')
      inflections.plural(/(quiz)$/i, '\1zes')

      # ActiveSupport leaves a word alone when none of its rules match. These
      # rules have a higher precedence than dry-inflector's defaults, which have
      # irregulars ActiveSupport doesn't (foot/feet, tooth/teeth, goose/geese),
      # so this rule -- the one with the lowest precedence -- matches everything
      # and leaves it alone.
      inflections.singular(/$/, '\0')
      inflections.singular(/s$/i, "")
      inflections.singular(/(ss)$/i, '\1')
      inflections.singular(/(n)ews$/i, '\1ews')
      inflections.singular(/([ti])a$/i, '\1um')
      inflections.singular(/((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)(sis|ses)$/i, '\1sis')
      inflections.singular(/(^analy)(sis|ses)$/i, '\1sis')
      inflections.singular(/([^f])ves$/i, '\1fe')
      inflections.singular(/(hive)s$/i, '\1')
      inflections.singular(/(tive)s$/i, '\1')
      inflections.singular(/([lr])ves$/i, '\1f')
      inflections.singular(/([^aeiouy]|qu)ies$/i, '\1y')
      inflections.singular(/(s)eries$/i, '\1eries')
      inflections.singular(/(m)ovies$/i, '\1ovie')
      inflections.singular(/(x|ch|ss|sh)es$/i, '\1')
      inflections.singular(/^(m|l)ice$/i, '\1ouse')
      inflections.singular(/(bus)(es)?$/i, '\1')
      inflections.singular(/(o)es$/i, '\1')
      inflections.singular(/(shoe)s$/i, '\1')
      inflections.singular(/(cris|test)(is|es)$/i, '\1is')
      inflections.singular(/^(a)x[ie]s$/i, '\1xis')
      inflections.singular(/(octop|vir)(us|i)$/i, '\1us')
      inflections.singular(/(alias|status)(es)?$/i, '\1')
      inflections.singular(/^(ox)en/i, '\1')
      inflections.singular(/(vert|ind)ices$/i, '\1ex')
      inflections.singular(/(matr)ices$/i, '\1ix')
      inflections.singular(/(quiz)zes$/i, '\1')
      inflections.singular(/(database)s$/i, '\1')

      # ActiveSupport adds a rule for both forms of an irregular, so that the
      # plural pluralizes to itself ("people" => "people"). Every word here has
      # the same first letter in both forms, which is all ActiveSupport's rules
      # for this case need.
      {
        "person" => "people",
        "man" => "men",
        "child" => "children",
        "sex" => "sexes",
        "move" => "moves",
        "zombie" => "zombies"
      }.each do |singular, plural|
        s0, srest = singular[0], singular[1..-1]
        p0, prest = plural[0], plural[1..-1]

        inflections.plural(/(#{s0})#{srest}$/i, "\\1#{prest}")
        inflections.plural(/(#{p0})#{prest}$/i, "\\1#{prest}")

        inflections.singular(/(#{s0})#{srest}$/i, "\\1#{srest}")
        inflections.singular(/(#{p0})#{prest}$/i, "\\1#{srest}")
      end

      # dry-inflector considers a word uncountable if any of its
      # underscore-separated segments is ("user_money"), and its list has words
      # ActiveSupport's doesn't (moose, deer, ...). Drop it and use #uncountable?
      # below instead.
      inflections.uncountables.clear
    end

    def pluralize(word)
      word = word.to_s
      uncountable?(word) ? word : INFLECTOR.pluralize(word)
    end

    def singularize(word)
      word = word.to_s
      uncountable?(word) ? word : INFLECTOR.singularize(word)
    end

    #
    # Convert a table, attribute, or method name into a class name.
    # "user_statuses" => "UserStatus", "admin/user" => "Admin::User".
    #
    def classify(word)
      camelize(singularize(word.to_s.sub(/.*\./, "")))
    end

    #
    # "some_value" => "SomeValue", "some_value", true => "someValue".
    # "/" becomes "::".
    #
    # Unlike ActiveSupport::Inflector#camelize this has no acronym support, so
    # there's no need to pass a symbol to get "lower" camel case.
    #
    def camelize(word, lower = false)
      word = word.to_s.dup

      if lower
        word.sub!(/^\w/) { |c| c.downcase }
      else
        word.sub!(/^[a-z\d]*/) { |c| c.capitalize }
      end

      word.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
      word.gsub!("/", "::")
      word
    end

    #
    # "SomeValue" => "some_value", "APIClient" => "api_client",
    # "Admin::User" => "admin/user".
    #
    def underscore(word)
      word = word.to_s.dup
      return word unless word =~ /[A-Z-]|::/

      word.gsub!("::", "/")
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end

    private

    # ActiveSupport only considers the whole word, e.g. "police" is uncountable
    # but "military_police" is not.
    def uncountable?(word)
      UNCOUNTABLE.any? { |uncountable| /\b#{Regexp.escape(uncountable)}\Z/i =~ word }
    end
  end
end
