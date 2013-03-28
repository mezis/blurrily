require 'spec_helper'

describe Blurrily::CommandProcessor do

  let(:directory) { '.' }
  subject { described_class.new(directory) }

  describe '#process_command' do
    # Accepts input strings:
    # CLEAR-><db>
    # FIND -><db>-><needle>->[limit]
    # PUT-><db>-><needle>-><ref>->[weight]

    it 'PUT and FIND finds something' do
      subject.process_command("PUT\tlocations_en\tgreat london\t12").should be_nil
      subject.process_command("PUT\tlocations_en\tgreater masovian\t13").should be_nil
      subject.process_command("FIND\tlocations_en\tgreat").should == "FOUND\t12\t13"
    end

    it 'FIND returns "FOUND" if nothing found' do
      subject.process_command("FIND\tlocations_en\tgreat london").should == "FOUND"
    end


    it 'returns ERROR for bad input data' do
      subject.process_command('Some stuff').should =~ /^ERROR\tUnknown command/
    end

    it 'returns ERROR for bad db name' do
      subject.process_command("FIND\tbad db name\tWhatever string").should =~ /^ERROR\tInvalid db name/
    end

    it 'returns ERROR for not numeric limit' do
      subject.process_command("FIND\tdb\tWhatever string\tlimit").should =~ /^ERROR\tLimit must be a number/
    end

    it 'returns ERROR for not numeric ref' do
      subject.process_command("PUT\tdb\tWhatever string\t12\tweight").should =~ /^ERROR\tWeight must be a number/
    end

    it 'returns ERROR for not numeric weight' do
      subject.process_command("PUT\tdb\tWhatever string\tref").should =~ /^ERROR\tRef must be a number/
    end

    it 'returns ERROR for too many aruments' do
      subject.process_command("PUT\tdb\tWhatever string\tref\tweight\targument too much").should =~ /^ERROR\twrong number /
    end

    it 'does not return ERROR for good PUT string' do
      subject.process_command("PUT\tdb\tWhatever string\t12\t1").should be_nil
    end

    it 'does not return ERROR for limit' do
      subject.process_command("FIND\tdb\tWhatever string\t2").should == "FOUND"
    end

    it 'CLEAR tries to clear given DB' do
      subject.send(:map_group).should_receive(:clear).with('locations_en')
      subject.process_command("CLEAR\tlocations_en")
    end
  end
end