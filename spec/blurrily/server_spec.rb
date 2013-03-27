# encoding: utf-8

require 'spec_helper'
require 'pathname'
require 'eventmachine'
require 'socket'

describe Blurrily::Server do
  subject { described_class.new({:host => host, :port => port, :directory => directory}) }
  let(:host) { '0.0.0.0' }
  let(:port) { 12345 }
  let(:directory)  { '.' }
  let(:subject_thread) {Thread.new { subject.start } }
  let(:socket) { TCPSocket.new(host, port) }

  describe '#process_command_line' do

    # Accepts input strings:
    # CLEAR-><db>
    # FIND -><db>-><needle>->[limit]
    # PUT-><db>-><needle>-><ref>->[weight]

    it 'PUT and FIND finds something' do
      subject.process_command_line("PUT\tlocations_en\tgreat london\t12").should be_nil
      subject.process_command_line("PUT\tlocations_en\tgreater masovian\t13").should be_nil
      subject.process_command_line("FIND\tlocations_en\tgreat").should == "FOUND\t12\t13"
    end

    it 'FIND returns "FOUND" if nothing found' do
      subject.process_command_line("FIND\tlocations_en\tgreat london").should == "FOUND"
    end


    it 'returns ERROR for bad input data' do
      subject.process_command_line('Some stuff').should =~ /^ERROR\tUnknown command/
    end

    it 'returns ERROR for bad db name' do
      subject.process_command_line("FIND\tbad db name\tWhatever string").should =~ /^ERROR\tInvalid db name/
    end

    it 'returns ERROR for not numeric limit' do
      subject.process_command_line("FIND\tdb\tWhatever string\tlimit").should =~ /^ERROR\tLimit must be a number/
    end

    it 'returns ERROR for not numeric ref' do
      subject.process_command_line("PUT\tdb\tWhatever string\t12\tweight").should =~ /^ERROR\tWeight must be a number/
    end

    it 'returns ERROR for not numeric weight' do
      subject.process_command_line("PUT\tdb\tWhatever string\tref").should =~ /^ERROR\tRef must be a number/
    end

    it 'returns ERROR for too many aruments' do
      subject.process_command_line("PUT\tdb\tWhatever string\tref\tweight\targument too much").should =~ /^ERROR\twrong number /
    end

    it 'does not return ERROR for good PUT string' do
      subject.process_command_line("PUT\tdb\tWhatever string\t12\t1").should be_nil
    end

    it 'does not return ERROR for limit' do
      subject.process_command_line("FIND\tdb\tWhatever string\t2").should == "FOUND"
    end

    it 'CLEAR tries to clear given DB' do
      subject.send(:map_group).should_receive(:clear).with('locations_en')
      subject.process_command_line("CLEAR\tlocations_en")
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
        socket.puts 'Who is most beautiful in the world?'
        socket.gets.should =~ /ERROR\tUnknown command/
      end
    end
  end
end
