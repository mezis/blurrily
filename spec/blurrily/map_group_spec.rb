# encoding: utf-8

require 'spec_helper'
require 'pathname'

describe Blurrily::MapGroup do

  context "initialization" do
    subject { described_class }

    it "saves the given directory" do
      subject.new("test_dir").instance_variable_get('@dir').should == "test_dir"
    end

  end

  context "creating, loading and returning a db" do
    subject { described_class.new }

    it "should return an instance of Map for a given DB" do
      subject.map("location_en").should be_a(Blurrily::Map)
    end

    it "should create a Map if the given DB does not already exist"

  end

end