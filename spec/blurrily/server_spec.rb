# encoding: utf-8

require 'spec_helper'
require 'pathname'
require 'eventmachine'
require 'socket'

describe Blurrily::Server do
  subject { described_class.new(host, port, dir) }
  let(:host) { '0.0.0.0' }
  let(:port) { 12345 }
  let(:dir)  { '.' }
  let(:subject_thread) {Thread.new { subject.start } }
  let(:socket) { TCPSocket.new(host, port) }

  it 'takes host, port dir when initializing' do
    subject.instance_variable_get('@host').should == host
    subject.instance_variable_get('@port').should == port
    subject.instance_variable_get('@dir').should == dir
  end

  describe '#process' do
    it 'returns formatted result for good input' do

    end

    it 'returns nil for bad input data' do
      subject.process('Some stuff').should be_nil
    end
  end

  context 'running server' do
    before :each do
      subject_thread.should be_alive
    end

    after :each do
      subject_thread.kill
    end

    it 'responds and closes connection' do
      Timeout::timeout(1) do
        subject.stub(:process => 'Me!')
        socket.puts 'Who is most beautiful in the world?'
        socket.gets.should == 'Me!'
        socket.gets.should be_nil
      end
    end
  end
end
