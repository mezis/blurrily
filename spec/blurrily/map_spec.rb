require 'spec_helper'
require 'pathname'

describe Blurrily::Map do
  subject { described_class.new }

  describe '#stats' do
    let(:result) { subject.stats }
    
    its(:references) { result[:references].should be_a_kind_of(Integer) }
    its(:trigrams)   { result[:trigrams].should be_a_kind_of(Integer) }

  end

  describe '#put' do
    let(:references) { subject.stats[:references] }
    let(:trigrams)   { subject.stats[:trigrams] }

    it 'stores references' do
      subject.put 'foobar', 123, 0
      references.should == 1
      trigrams.should   == 7
    end

    it 'stores duplicate references' do
      2.times { subject.put 'foobar', 123, 0 }
      references.should == 2
      trigrams.should   == 14
    end

    it 'accepts empty strings' do
      subject.put '', 123, 0
      references.should == 1
      trigrams.should   == 1
    end

    it 'accepts non-letter characters' do
      subject.put '@€%é', 123, 0
      references.should == 1
      trigrams.should   == 2
    end
  end

  describe '#delete' do
    it 'removes references' do
      subject.put 'london', 123, 0
      subject.delete 123
      subject.stats[:trigrams].should == 0
      subject.stats[:references].should == 0
    end

    context 'with duplicate references' do
      it 'removes duplicates' do
        3.times { subject.put 'london', 123, 0 }
        subject.delete 123
        subject.stats[:trigrams].should == 0
      end

      it 'breaks reference counter' do
        3.times { subject.put 'london', 123, 0 }
        subject.delete 123
        subject.stats[:references].should == 2
      end
    end

    it 'ignores missing references' do
      subject.delete 123
      subject.stats[:trigrams].should == 0
    end

  end

  describe '#find' do
    let(:needle) { 'london' }
    let(:limit)  { 10 }
    let(:result) { subject.find needle, limit }

    context 'with an empty map' do
      it 'returns no results' do
        result.should be_empty
      end
    end

    context 'with a limit option' do
      let(:limit) { 2 }
      it 'returns fewer results' do
        5.times { |idx| subject.put 'london', idx, 0 }
        result.length.should == 2
      end
    end

    it 'returns perfect matches' do
      subject.put 'london', 123, 0
      result.first.should == [123, 7, 6]
    end

    it 'favours exact matches' do
      subject.put 'lon',                 125, 0
      subject.put 'london city airport', 124, 0
      subject.put 'london',              123, 0
      result.first.first.should == 123
    end

    context 'when needle is mis-spelt' do
      before { subject.put 'london', 123, 0 }

      it 'tolerates insertions' do
        needle.replace 'lonXdon'
        result.should_not be_empty
      end

      it 'tolerates deletions' do
        needle.replace 'lodon'
        result.should_not be_empty
      end

      it 'tolerates substitutions' do
        needle.replace 'lodnon'
        result.should_not be_empty
      end
    end

    it 'sorts by descending matchiness' do
      subject.put 'New York',   1001, 0
      subject.put 'Yorkshire',  1002, 0
      subject.put 'York',       1003, 0
      subject.put 'Yorkisthan', 1004, 0
      needle.replace 'York'
      result.map(&:first).should == [1003, 1001, 1002, 1004]
    end

    it 'favours the lighter of two matches' do
      subject.put 'london', 103, 103
      subject.put 'london', 101, 101
      subject.put 'london', 102, 102
      result.map(&:first).should == [101, 102, 103]
    end
  end


  describe '#save' do
    let(:path) { Pathname.new('map.test') }
    
    def perform
      subject.save path.to_s
    end

    let(:wordsize_byte) do
      case RUBY_PLATFORM
      when /x86_64/   then "\u0008"
      when /i[345]86/ then "\u0004"
      else raise 'unknown platform'
      end
    end

    let(:big_endian_byte) do
      case RUBY_PLATFORM
      when /x86|i[345]86/ then "\u0001"
      when /ppc|arm/      then "\u0002"
      else raise 'unknown platform'
      end
    end

    before do
      path.delete if path.exist?

      subject.put 'london',  10, 0
      subject.put 'paris',   11, 0
      subject.put 'monaco',  12, 0
    end

    after do
      path.delete if path.exist?
    end

    it 'creates a file on disk' do
      perform
      path.should exist
    end

    it 'uses a magic header' do
      perform
      header = path.read(8)
      header[0,6].should == "trigra"
      header[6].should == big_endian_byte
      header[7].should == wordsize_byte
    end

    it 'is idempotent' do
      hashes = (1..3).map { perform ; path.md5sum }
      hashes[0].should == hashes[1]
      hashes[0].should == hashes[2]
    end
  end


  describe '.load' do
    it 'then saves to an identical file'
    it 'creates a searchable map'
    it 'raises an exception when the file does not exist'
  end

end