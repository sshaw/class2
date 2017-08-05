# Class2

Create class hierarchies, easily.

## Usage

```rb
Class2.new(
  :user => [
    :name, :age,
    :addresses => [
      :city, :state, :zip,
      :country => [ :name, :code ]
    ]
  ]
)
```

This creates 3 classes (`User`, `Address` and `Country`) with the
specified accessors and constructors capable of accepting an attribute
`Hash`:

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

p user.name					 # "sshaw"
p user.addresses.size        # 3
p user.addresses.first.city  # "LA"

country = Country.new(:name => "America", :code => "US")
address = Address.new(:city => "Da Bay", :state => "CA", :country => country)
user.addresses << address
```
