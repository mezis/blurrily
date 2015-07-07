# encoding: utf-8

require 'spec_helper'
require 'blurrily/map_group'

describe Blurrily::MapGroup do
  subject { described_class.new('.') }

  context "creating, loading and returning a db" do

    it "returns an instance of Map for a given DB" do
      expect(subject.map("location_en")).to be_a(Blurrily::Map)
    end

    it "returns the correct map, given the db name" do
      map1 = subject.map('location_en')
      map2 = subject.map('location_fr')
      expect(subject.map("location_en").object_id).to     eq(map1.object_id)
      expect(subject.map("location_en").object_id).not_to eq(map2.object_id)
    end

    it "loads from file if exists rather than creating a new db" do
      map1 = subject.map('location_en')
      map1.put('aaa','10000000-0000-4000-A000-000000000001',0)
      subject.save
      loaded_map = described_class.new('.').map('location_en')
      expect(loaded_map.find('aaa').first.first).to eq('10000000-0000-4000-A000-000000000001')
    end
  end

  context "saving the map to file" do
    it "saves all maps" do
      subject.map('location_en')
      subject.map('location_fr')
      subject.save
      expect(Pathname('location_en.trigrams')).to exist
      expect(Pathname('location_fr.trigrams')).to exist
    end

    it 'saves in chosen directory' do
      map_group = described_class.new('tmp')
      map_group.map('test')
      map_group.save
      expect(Pathname('tmp/test.trigrams')).to exist
    end

    after(:each) do
      FileUtils.rm Dir.glob('tmp/test.trigrams')
    end
  end

  after(:each) do
    FileUtils.rm Dir.glob('location*.trigrams')
  end
end
