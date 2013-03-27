# encoding: utf-8

require 'spec_helper'
require 'pathname'

describe Blurrily::Client do
  
  before(:each) do
    @config = {
      :host => '0.0.0.0',
      :port => 12021,
      :db_name => 'location_en'
    }
  end

  it "opens a connection to a defined server and db" do
    TCPSocket.should_receive(:new).with('0.0.0.0', 12021)
    subject { described_class.new('0.0.0.0', 12021, 'location_en') }
    subject.get_instance_variable(:@host).should == '0.0.0.0'
    subject.get_instance_variable(:@port).should == 12021
    subject.get_instance_variable(:@db_name).should == 'location_en'
  end

  %w(host, port, db_name).each do |req|
    it "fails if no #{req} passed" do
      TCPSocket.should_not_receive(:new)
      @config.reject{ |k,v| k == req.to_sym }
      expect{ described_class.new(config.values) }.to raise_error(ArgumentError)
    end
  end

  context "find" do
    
    subject { described_class.new(@config.values) }

    it "fails if no needle is passed" do
      expect{ subject.find() }.to raise_error(ArgumentError)
    end

    it "fails if the needle has a tab char" do
      expect{ subject.find("needle\twith\ttabs") }.to raise_error(ArgumentError)
    end

    it "fails if limit is not numberic" do
      expect{ subject.find("london", "blah") }.to raise_error(ArgumentError)
    end

    it "creates a well formed request command string" do
      client = TCPSocket.new @config.reject{ |k,v| k == :db_name }.values
      client.should_receive(:write).with("FIND\tlocation_en\tlondon")
      subject.find("london")
    end

    it "returns records" do
      results = subject.find("london")
      results.should match(/^FOUND.*$/)
    end

    it "respects the record limit given" do
      client = TCPSocket.new @config.reject{ |k,v| k == :db_name }.values
      client.should_receive(:write).with("FIND\tlocation_en\tlondon\t5")
      results = subject.find("london", 5)
      results.split("\t").length.should == 6 #including the "FOUND\t" start of string
    end

    it "handles no records found correctly" do
      results = subject.find("blah")
      results.should match(/^NOT FOUND.*$/)
    end

    it "handles errors correctly" do
      results = subject.find("blah")
      results.should match(/^ERROR$/)
    end
  end

  context "put" do
    it "fails if no db_name is passed"
    it "fails if no ref is passed"
    it "fails if ref is not numberic"
    it "fails if weight is not numberic"
    it "created a well formed request command string"
    it "adds a given string to the db"
  end

end