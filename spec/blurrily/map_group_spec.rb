# encoding: utf-8

require 'spec_helper'
require 'pathname'

describe Blurrily::MapGroup do

  context "initialization" do
    subject { described_class }

    it "saves the given directory" do
      subject.new("test_dir").instance_variable_get('@dir').should == "test_dir"
    end

    it "saves the current dir if no directory name is given" do
      subject.new().instance_variable_get('@dir').should == "."
    end

  end

  context "creating, loading and returning a db" do
    subject { described_class.new }

    it "returns an instance of Map for a given DB" do
      subject.map("location_en").should be_a(Blurrily::Map)
    end

    it "returns the correct map, given the db name" do
      map1 = subject.map('location_en')
      map2 = subject.map('location_fr')
      subject.map("location_en").object_id.should == map1.object_id
      subject.map("location_en").object_id.should_not == map2.object_id
    end

    it "loads from file if exists rather than creating a new db" do
      map1 = subject.map('location_en')
      map1.put('aaa',123,0)
      subject.save

      loaded_map = described_class.new.map('location_en')
      loaded_map.find('aaa').first.first.should == 123
    end

  end

  context "saving the map to file" do
    subject { described_class.new }

    its "saves all maps" do
      subject.map('location_en')
      subject.map('location_fr')

      subject.save

      File.exists?(File.join('.','location_en.dat')).should be_true
      File.exists?(File.join('.','location_fr.dat')).should be_true
    end

    after(:each) do
      FileUtils.rm Dir.glob('location*.dat')
    end
  end

end