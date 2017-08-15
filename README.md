# Class2

Easily create hierarchies of classes that support nested attributes, type conversion, equality, and more.

[![Build Status](https://travis-ci.org/sshaw/class2.svg?branch=master)](https://travis-ci.org/sshaw/class2)

## Usage

```rb
Class2 :user => [
         :name, :age,
         :addresses => [
           :city, :state, :zip,
           :country => [ :name, :code ]
         ]
       ]
```

This creates 3 classes: `User`, `Address`, and `Country` with the following attribute accessors:

* `User`: name, age, addresses
* `Address`: city, state, zip, country
* `Country`: name, code

Each of these classes are created with [several additional methods](#methods).

You can also specify types:

```rb
Class2 :user => {
         :name => String,
         :age  => Fixnum,
         :addresses => [
           :city, :state, :zip,  # No explicit types for these
           :country => {
             :name => String,
             :code => String
           }
         ]
       }
```
An attempt is made to convert the attribute's type when a value is passed to the constructor
or set via its accessor. Attributes without types are treated as is.

After calling either one of the above you can do the following:

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

user.name                  # "sshaw"
user.addresses.size        # 3
user.addresses.first.city  # "LA"
user.to_h                  # {:name => "sshaw", :age => 99, :addresses => [ { ... } ]}

# keys can be strings too
country = Country.new("name" => "America", "code" => "US")
address = Address.new(:city => "Da Bay", :state => "CA", :country => country)
user.addresses << address

User.new(:name => "sshaw") == User.new(:name => "sshaw")  # true
```

`Class2` can create classes with typed attributes from example hashes.
This makes it possible to build classes for things like API responses, using the API response
itself as the specification:

```rb
# From JSON.parse
# of https://api.github.com/repos/sshaw/selfie_formatter/commits
response = [
  {
    "sha" => "f52f1ed9144e1f73346176ab79a61af78df1b6bd",
    "commit" => {
      "author"=> {
        "name"=>"sshaw",
        "email"=>"skye.shaw@gmail.com",
        "date"=>"2016-06-30T03:51:00Z"
      }
    },
    "comment_count": 0

    # snip full response
  }
]

Class2 :commit => response.first

commit = Commit.new(response.first)
commit.author.name    # "sshaw"
commit.comment_count  # 0
```

### Conversions

You can use any of these classes or their instances in your class definitions:

* `Array`
* `Date`
* `DateTime`
* `Float`
* `Hash`
* `Integer`/`Fixnum` - either one will cause a `Fixnum` conversion
* `TrueClass`/`FalseClass` - either one will cause a boolean conversion

Custom conversions are possible, just add the conversion to
[`Class2::CONVERSIONS`](https://github.com/sshaw/class2/blob/517239afc76a4d80677e169958a1dc7836726659/lib/class2.rb#L14-L29)

### Namespaces

`Class2` can use an exiting namespace or create a new one:

```rb
Class2 My::Namespace, :user => %i[name age]

My::Namespace::User.new(:name => "sshaw")

Class2 "New::Namespace", :user => %i[name age]

New::Namespace::User.new(:name => "sshaw")
```

### Naming

`Class2` uses
[`String#classify`](http://api.rubyonrails.org/classes/String.html#method-i-classify)
to turn keys into class names: `:foo` will be `Foo`, `:foo_bars` will
be `FooBar`.

Plural keys with an array value are always assumed to be accessors for
a collection and will default to returning an `Array`. `#classify` is
used to derive the class names from the plural attribute names. An
`:addresses` key with an `Array` value will result in a class named
`Address` being created.

Plurality is determined by [`String#pluralize`](http://api.rubyonrails.org/classes/String.html#method-i-pluralize).

### Methods

Classes created by `Class2` will have:

* A constructor that accepts a nested attribute hash
* Attribute readers and writers
* `#to_h`
* `#eql?` and `#==`
* `#hash`

### Constructor

The default constructor ignores unknown attributes.
If you prefer to raise an exception include `Class2::StrictConstructor`:

```rb
Class2 :user => %w[id name age] do
  include Class2::StrictConstructor
end
```

Now an `ArgumentError` will be raised if anything but `id`, `name`, or
`age` are passed in.

Also see [Customizations](#customizations).

### Customizations

To add methods or include Modules just open up the class and write or include them:

```rb
Class2 :user => :name

class User
  include SomeModule

  def first_initial
    name[0] if name
  end
end

User.new(:name => "sshaw").first_initial
```

`Class2` does accept a block whose contents will be added to
*every* class defined within the call:

```rb
Class2 :user => :name, :address => :city do
  include ActiveModel::Conversion
  extend ActiveModel::Naming
end

User.new.model_name.route_key
Address.new.model_name.route_key
```

## See Also

The Perl modules that served as the inspiration:

* [`MooseX::NestedAttributesConstructor`](https://github.com/sshaw/MooseX-NestedAttributesConstructor)
* [`Class::Tiny`](https://metacpan.org/pod/Class::Tiny)
* [`Moose`](https://metacpan.org/pod/Moose) and [`Moo`](https://metacpan.org/pod/Moo)
* [`Type::Tiny`](https://metacpan.org/pod/Type::Tiny)

Surely others I cannot remember...

## Author

Skye Shaw [sshaw AT gmail.com]

## License

Released under the MIT License: www.opensource.org/licenses/MIT
