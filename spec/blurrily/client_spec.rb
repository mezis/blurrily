# encoding: utf-8

require 'spec_helper'
require "blurrily/client"
require 'pathname'

describe Blurrily::Client do
  
  let(:config) { { :host => '0.0.0.0', :port => 12021, :db_name => 'location_en' } }

  subject { described_class.new(config) }

  context "find" do

    it "fails if no needle is passed" do
      expect{ subject.find() }.to raise_error(ArgumentError)
    end

    it "fails if the needle has a tab char" do
      expect{ subject.find("needle\twith\ttabs") }.to raise_error(ArgumentError)
    end

    it "fails if limit is not numeric" do
      expect{ subject.find("london", "blah") }.to raise_error(ArgumentError)
    end

    it "returns records" do
      mock_tcp_next_request("OK\t1337", "FIND\tlocation_en\tlondon\t10")
      subject.find("london").should == [1337]
    end

    it "handles no records found correctly" do
      mock_tcp_next_request("OK")
      subject.find("blah").should be_empty
    end

    it "handles errors correctly" do
      mock_tcp_next_request("ERROR")
      expect { subject.find("blah") }.to raise_exception(described_class::Error)
    end
  end

  context "put" do
    it "fails if no needle is passed" do
      expect { subject.put() }.to raise_error(ArgumentError)
    end

    it "fails if needle contains a tab" do
      expect { subject.put("South\tLondon", 123, 0) }.to raise_error(ArgumentError)
    end

    it "fails if no ref is passed" do
      expect { subject.put('London') }.to raise_error(ArgumentError)
    end

    it "fails if ref is not numeric" do
      expect { subject.put('London', 'abc', 0) }.to raise_error(ArgumentError)
    end

    it "fails if weight is not numeric" do
      expect { subject.put('London', 123, 'a') }.to raise_error(ArgumentError)
    end

    it "created a well formed request command string" do
      mock_tcp_next_request("OK", "PUT\tlocation_en\tLondon\t123\t0")
      subject.put("London", 123, 0).should be_nil
    end
  end
end
