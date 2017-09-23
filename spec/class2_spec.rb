# coding: utf-8
require "minitest/autorun"
require "set"
require "class2"

describe Class2 do
  def delete_constant(name)
    Object.const_defined?(name) && Object.send(:remove_const, name)
  end

  describe "defining classes without type conversions" do
    before do
      @classes = %w[User Address Country]

      Class2(
        :user => [
          :id, :name,
          :addresses => [
            :city, :state, :zip,
            :country => [ :name, :code ]
          ]
        ]
      )
    end

    after do
      @classes.each { |klass| delete_constant(klass) }
    end

    it "creates the classes" do
      @classes.each do |klass|
        Object.const_defined?(klass).must_equal true
        Object.const_get(klass).must_be_instance_of Class
      end
    end

    it "creates a read write accessor for each attribute" do
      user = User.new
      user.must_respond_to(:id)
      user.must_respond_to(:id=)

      user.must_respond_to(:name)
      user.must_respond_to(:name=)

      user.must_respond_to(:addresses)
      user.must_respond_to(:addresses=)

      user.id = 1
      user.id.must_equal 1

      user.name = "sshaw"
      user.name.must_equal "sshaw"

      a = [ Address.new ]
      user.addresses = a
      user.addresses.must_equal a
    end

    it "creates equality methods" do
      user1 = User.new(:id => 1)
      user2 = User.new(:id => 1)
      user1.must_equal user2

      user1.id = 99
      user1.wont_equal user2
      user1.wont_equal "foo"
    end

    it "creates a to_h method" do
      user = User.new(:id => 1, :name => "sshaw", :addresses => [ :city => "NYC" ])
      user.to_h.must_equal({
        :id => 1,
        :name => "sshaw",
        :addresses => [
          :city => "NYC",
          :state => nil,
          :zip => nil,
          :country => {
            :name => nil,
            :code => nil
          }
        ]
      })

      user.name = user.addresses = nil
      user.to_h.must_equal({
        :id => 1,
        :name => nil,
        :addresses => []
      })
    end

    describe "attributes that accept an Array" do
      it "returns an Array by default" do
        User.new.addresses.must_equal []
      end
    end

    describe "constructors" do
      it "accepts the class' attributes" do
        user = User.new(:id => 1, :name => "fofinho")
        user.id.must_equal 1
        user.name.must_equal "fofinho"

        country = Country.new(:name => "America", :code => "US")
        country.name.must_equal "America"
        country.code.must_equal "US"

        address = Address.new(:city => "Da Bay", :state => "CA", :country => country)
        address.city.must_equal "Da Bay"
        address.state.must_equal "CA"
        address.country.must_equal country
      end

      it "accepts know and unknown attributes" do
        user = User.new(:id => 1, :what_what_what => 999)
        user.id.must_equal 1
        user.respond_to?(:what_what_what).must_equal false
      end

      it "does not require any arguments" do
        User.new
      end

      it "silently ignores arguments that are not a Hash" do
        User.new "foo"
        User.new nil
      end

      it "accepts attributes for the entire class hierarchy" do
        user = User.new(
          :id  => 1,
          :name => "sshaw",
          :addresses => [
            { :city => "LA",
              :country => { :code => "US" } },
            { :city => "São José dos Campos",
              :country => { :code => "BR" } }
          ]
        )

        user.id.must_equal 1
        user.name.must_equal "sshaw"
        user.addresses.size.must_equal 2
        user.addresses[0].city.must_equal "LA"
        user.addresses[0].country.code.must_equal "US"
        user.addresses[1].city.must_equal "São José dos Campos"
        user.addresses[1].country.code.must_equal "BR"
      end
    end
  end

  describe "namespaces" do
    after { delete_constant("A") }

    it "creates a namespaced class from a string" do
      namespace = "A"
      Class2(
        namespace,
        :user => :id
      )

      klass = "#{namespace}::User"
      Object.const_defined?(klass).must_equal true
      Object.const_get(klass).must_be_instance_of Class
    end

    it "creates a namespaced class from module" do
      module A end

      Class2(
        A,
        :user => :id
      )

      klass = "A::User"
      Object.const_defined?(klass).must_equal true
      Object.const_get(klass).must_be_instance_of Class
    end

    it "instantiates classes within the namespace using an attribute key" do
      module A end

      Class2(
        A,
        :user => { :foo => [:bar] }
      )

      user = A::User.new(:foo => { :bar => 123 })
      user.foo.bar.must_equal 123
    end
  end

  describe "defining classes with type conversions" do
    describe "using classes for types" do
      before do
        Class2(:all => {
                 :array => Array,
                 :boolean => TrueClass,
                 :boolean2 => FalseClass,
                 :date => Date,
                 :datetime => DateTime,
                 :fixnum => Fixnum,
                 :float => Float,
                 :hash => Hash,
                 :integer => Integer,
                 :string => String,
               },

               :mixed => [
                 :default,
                 :float => Float
               ],

               :nested => {
                 :float => Float, :child => { :id => Fixnum }
               }
              )
      end

      after do
        delete_constant("All")
        delete_constant("Mixed")
        delete_constant("Nested")
        delete_constant("Child")
      end

      it "converts on assignment" do
        all = All.new

        all.integer = "123"
        all.integer.must_equal 123
      end

      it "converts in the constructor" do
        all = All.new(:integer => "123")
        all.integer.must_equal 123
      end

      it "converts nested types" do
        nested = Nested.new(:float => "1", :child => { :id => "1" })
        nested.float.must_equal 1.0
        nested.child.id.must_equal 1
      end

      it "does not convert attributes without types" do
        mixed = Mixed.new(:default => /foo/, :float => 1)
        mixed.float.must_equal 1.0
        mixed.default.must_equal(/foo/)
      end

      it "converts to Array" do
        all = All.new(:array => Set.new([1,2]))
        all.array.must_equal [1,2]
      end

      it "converts to boolean" do
        all = All.new
        ["1", "    1 ", 1, 1.0, true].each do |value|
          all.boolean = value
          all.boolean.must_equal true
        end

        ["0", "    0 ", 0, false, "sshaw", Class].each do |value|
          all.boolean = value
          all.boolean.must_equal false
        end
      end

      it "converts to Date" do
        date = "2017-01-01"
        all = All.new(:date => date)
        all.date.must_equal Date.parse("2017-01-01")
      end

      it "converts to DateTime" do
        time = "2017-01-01T01:02:03"
        all = All.new(:datetime => time)
        all.datetime.must_equal DateTime.parse(time)
      end

      it "converts to Float" do
        all = All.new(:float => 10)
        all.float.must_equal 10.0

        all.float = "10.5"
        all.float.must_equal 10.5
      end

      it "converts to Hash" do
        all = All.new(:hash => [%w[a 1], %w[b 2]])
        all.hash.must_equal "a" => "1", "b" => "2"
      end

      it "converts to Fixnum" do
        all = All.new(:fixnum => "123")
        all.fixnum.must_equal 123
      end

      it "converts to String" do
        all = All.new(:string => 123)
        all.string.must_equal "123"
      end

      it "defaults to an empty Array for array types" do
        All.new.array.must_equal []
      end

      it "defaults to an empty Hash for hash types" do
        All.new.hash.must_equal Hash.new
      end
    end

    describe "using instances for types" do
      before do
        @classes = %w[User Address]

        Class2(
          :user => {
            :id => 1,
            :name => "sshaw",
            :foo => {},
            :bar => [],
            :addresses => [
              { :city => "LA",  :lat => 75.12345 },
              { :city => "NYC", :lat => 75.12345 }
            ]
          }
        )
      end

      after do
        @classes.each { |name| delete_constant(name) }
      end

      it "creates the classes" do
        @classes.each do |klass|
          Object.const_defined?(klass).must_equal true
          Object.const_get(klass).must_be_instance_of Class
        end
      end

      it "creates a read write accessor for each attribute" do
        user = User.new
        user.must_respond_to(:id)
        user.must_respond_to(:id=)

        user.must_respond_to(:name)
        user.must_respond_to(:name=)

        address = Address.new
        address.must_respond_to(:city)
        address.must_respond_to(:city=)

        address.must_respond_to(:lat)
        address.must_respond_to(:lat=)
      end

      it "converts types based on the instance's type" do
        user = User.new(:id => "1", :name => 123, :addresses => [ :lat => 75 ])
        user.id.must_equal 1
        user.name.must_equal "123"
        user.addresses.first.must_be_instance_of(Address)
        user.addresses.first.lat.must_equal 75.0
      end

      it "defaults to an empty Array for array types" do
        User.new.foo.must_equal Hash.new
      end

      it "defaults to an empty Hash for hash types" do
        User.new.bar.must_equal []
      end
    end
  end

  describe "when Class2::StrictConstructor is included" do
    before do
      Class2(:foo => :bar) do
        include Class2::StrictConstructor
      end
    end

    after { delete_constant("Foo") }

    it "creates a constructor that accepts know attributes" do
      Foo.new(:bar => 123).bar.must_equal 123
      Foo.new("bar" => 123).bar.must_equal 123
    end

    it "creates a constructor that raises an ArgumentError for unknown attributes" do
      lambda { Foo.new(:baz => 123) }.must_raise ArgumentError, "unknown attribute: baz"
    end
  end
end
