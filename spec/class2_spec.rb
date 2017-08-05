# coding: utf-8
require "minitest/autorun"
require "class2"

describe Class2 do
  before do
    @classes = %w[User Address Country]

    Class2.new(
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
    @classes.each do |klass|
      Object.const_defined?(klass) && Object.send(:remove_const, klass)
    end
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
