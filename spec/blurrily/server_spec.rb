# encoding: utf-8

require 'spec_helper'
require 'pathname'
require 'eventmachine'
require 'socket'

describe Blurrily::Server do

  context "a new connection" do
    subject { described_class.new } do
      let(:host) { 0.0.0.0 }
      let(:port) { 12021 }
      let(:dir)  { '.' }

      it "takes host, port and directory as args to starting up" do
        threads = []
        threads << Thread.new { described_class.new(host, port, dir) }
        threads << Thread.new {
          s = TCPSocket.new host, port
          s.write "PUT\tlocation_en\taaa\t123\t0"
          while line = s.gets
        }
        sleep(1)
        line.should == "?"
        threads.each { |thr| thr.kill }
      end

      %w(host port dir).each do |req|
        it "raises as error if #{req} is not given" do
          described_class.new(host, port, dir)
        end
      end

    end
  end
end

