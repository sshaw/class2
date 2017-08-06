# Class2

Easily create hierarchies of classes that support nested attributes, equality, and more.

[![Build Status](https://travis-ci.org/sshaw/class2.svg?branch=master)](https://travis-ci.org/sshaw/class2)

## Usage

```rb
Class2(
  :user => [
    :name, :age,
    :addresses => [
      :city, :state, :zip,
      :country => [ :name, :code ]
    ]
  ]
)
```

This creates 3 classes: `User`, `Address`, and `Country` with the following attribute accessors:

* `User`: name, age, addresses
* `Address`: city, state, zip, country
* `Country`: name, code

Each of these classes also contain [several additional methods](#methods).

Example:

```rb
user = User.new(
  :name => "sshaw",
  :age  => 99,
  :addresses => [
    { :city => "LA",
      :country => { :code => "US" } },
    { :city => "NY Sizzle",
      :country => { :code => "US" } },
    { :city => "São José dos Campos",
      :country => { :code => "BR" } }
  ]
)

p user.name                  # "sshaw"
p user.addresses.size        # 3
p user.addresses.first.city  # "LA"

# Keys can be strings too
country = Country.new("name" => "America", "code" => "US")
address = Address.new(:city => "Da Bay", :state => "CA", :country => country)
user.addresses << address

p User.new(:name => "sshaw") == User.new(:name => "sshaw")  # true

Class2(:foo, :bar => :baz)
Foo.new
Bar.new(:baz => 123)
```

### Namespaces

`Class2` can use an exiting namespace or create a new one:

```rb
Class2(
  My::Namespace,
  :user => %i[name age]
)

My::Namespace::User.new(:name => "sshaw")

Class2(
  "New::Namespace",
  :user => %i[name age]
)

New::Namespace::User.new(:name => "sshaw")
```

### Naming

`Class2` uses
[`String#classify`](http://api.rubyonrails.org/classes/String.html#method-i-classify)
to turn keys into class names. `:foo` will be `Foo`, `:foo_bars` will
be `FooBar`.  It also uses it to turn plural attribute names into
singular classes. An `:addresses` attribute will result in a class named
`Address` being created.

Plurality is determined by [`String#pluralize`](http://api.rubyonrails.org/classes/String.html#method-i-pluralize).

### Methods

Classes created by `Class2` will have:

* A constructor that accepts a nested attribute hash
* Attribute readers and writers
* `#to_h`
* `#eql?` and `#==`
* `#hash`

#### Custom Methods

Just open up the class and write them:

```rb
Class2(:user => :name)

class User
  def first_initial
    name[0] if name
  end
end

User.new(:name => "sshaw").first_initial
```

## See Also

The Perl module that served as the inspiration: [`MooseX::NestedAttributesConstructor`](https://github.com/sshaw/MooseX-NestedAttributesConstructor).

## Author

Skye Shaw [sshaw AT gmail.com]

## License

Released under the MIT License: www.opensource.org/licenses/MIT
