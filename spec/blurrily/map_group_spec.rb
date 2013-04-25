# encoding: utf-8

require 'spec_helper'
require 'blurrily/map_group'

describe Blurrily::MapGroup do
  subject { described_class.new('.') }

  context "creating, loading and returning a db" do

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
      loaded_map = described_class.new('.').map('location_en')
      loaded_map.find('aaa').first.first.should == 123
    end
  end

  context "saving the map to file" do
    it "saves all maps" do
      subject.map('location_en')
      subject.map('location_fr')
      subject.save
      File.exists?(File.join('.','location_en.trigrams')).should be_true
      File.exists?(File.join('.','location_fr.trigrams')).should be_true
    end

    it 'saves in chosen directory' do
      map_group = described_class.new('tmp')
      map_group.map('test')
      map_group.save
      File.exists?(File.join('tmp','test.trigrams')).should be_true
    end

    after(:each) do
      FileUtils.rm Dir.glob('tmp/test.trigrams')
    end
  end

  after(:each) do
    FileUtils.rm Dir.glob('location*.trigrams')
  end
end