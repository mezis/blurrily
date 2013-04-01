require 'spec_helper'
require 'blurrily/command_processor'
require 'blurrily/map_group'

describe Blurrily::CommandProcessor do

  subject { described_class.new(Blurrily::MapGroup.new) }

  describe '#process_command' do
    # Accepts input strings:
    # CLEAR-><db>
    # FIND -><db>-><needle>->[limit]
    # PUT-><db>-><needle>-><ref>->[weight]

    it 'PUT and FIND finds something' do
      subject.process_command("PUT\tlocations_en\tgreat london\t12").should == 'OK'
      subject.process_command("PUT\tlocations_en\tgreater masovian\t13").should == 'OK'
      subject.process_command("FIND\tlocations_en\tgreat").should == "OK\t12\t13"
    end

    it 'FIND returns "OK" if nothing found' do
      subject.process_command("FIND\tlocations_en\tgreat london").should == "OK"
    end


    it 'returns ERROR for bad input data' do
      subject.process_command('Some stuff').should =~ /^ERROR\tUnknown command/
    end

    it 'returns ERROR for bad db name' do
      subject.process_command("FIND\tbad db name\tWhatever string").should =~ /^ERROR\tInvalid database name/
    end

    it 'returns ERROR for not numeric limit' do
      subject.process_command("FIND\tdb\tWhatever string\tlimit").should =~ /^ERROR\tLimit must be a number/
    end

    it 'returns ERROR for not numeric ref' do
      subject.process_command("PUT\tdb\tWhatever string\t12\tweight").should =~ /^ERROR\tInvalid weight/
    end

    it 'returns ERROR for not numeric weight' do
      subject.process_command("PUT\tdb\tWhatever string\tref").should =~ /^ERROR\tInvalid reference/
    end

    it 'returns ERROR for too many aruments' do
      subject.process_command("PUT\tdb\tWhatever string\tref\tweight\targument too much").should =~ /^ERROR\twrong number /
    end

    it 'does not return ERROR for good PUT string' do
      subject.process_command("PUT\tdb\tWhatever string\t12\t1").should == 'OK'
    end

    it 'does not return ERROR for limit' do
      subject.process_command("FIND\tdb\tWhatever string\t2").should == "OK"
    end

    # it 'CLEAR tries to clear given DB' do
    #   subject.send(:map_group).should_receive(:clear).with('locations_en')
    #   subject.process_command("CLEAR\tlocations_en")
    # end
  end
end