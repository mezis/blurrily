# encoding: utf-8

require 'spec_helper'
require 'pathname'
require "blurrily/map"

describe Blurrily::Map do
  subject { described_class.new }
  let(:path) { Pathname.new('map.test') }

  after do
    path.delete_if_exists
  end

  describe '#stats' do
    let(:result) { subject.stats }

    it 'has :references' do
      expect(result[:references]).to be_a_kind_of(Integer)
    end

    it 'has :trigrams' do
      expect(result[:trigrams]).to be_a_kind_of(Integer)
    end

  end

  describe '#put' do
    let(:references) { subject.stats[:references] }
    let(:trigrams)   { subject.stats[:trigrams] }

    it 'stores references' do
      subject.put 'foobar', '10000000-0000-4000-A000-000000000123', 0
      expect(references).to eq(1)
      expect(trigrams).to   eq(7)
    end

    it 'returns number of added trigrams' do
      expect(subject.put('foobar', '10000000-0000-4000-A000-000000000123')).to eq(7)
      expect(subject.put('foobar', '10000000-0000-4000-A000-000000000123')).to eq(0)
    end

    it 'does not store duplicate references' do
      2.times { subject.put 'foobar', '10000000-0000-4000-A000-000000000123', 0 }
      expect(references).to eq(1)
      expect(trigrams).to eq(7)
    end

    it 'accepts empty strings' do
      subject.put '', '10000000-0000-4000-A000-000000000123', 0
      expect(references).to eq(1)
      expect(trigrams).to eq(1)
    end

    it 'accepts non-letter characters' do
      subject.put '@€%é', '10000000-0000-4000-A000-000000000123', 0
      expect(references).to eq(1)
      expect(trigrams).to eq(2)
    end

    it 'ignores dupes after save/load cycle' do
      subject.put 'london', '10000000-0000-4000-A000-000000000123'
      subject.save path.to_s
      map = described_class.load path.to_s
      map.put 'paris', '10000000-0000-4000-A000-000000000123'
      expect(map.find('paris')).to be_empty
    end

    it 'makes map dirty' do
      subject.save path.to_s
      path.delete_if_exists
      subject.put 'london', '10000000-0000-4000-A000-000000000123'
      subject.save path.to_s
      expect(path).to exist
    end
  end

  describe '#delete' do
    it 'removes references' do
      subject.put 'london', '10000000-0000-4000-A000-000000000123', 0
      subject.delete '10000000-0000-4000-A000-000000000123'
      expect(subject.stats[:trigrams]).to eq(0)
      expect(subject.stats[:references]).to eq(0)
    end

    it 'makes map dirty' do
      subject.put 'london', '10000000-0000-4000-A000-000000000123', 0
      subject.save path.to_s
      path.delete_if_exists
      subject.delete '10000000-0000-4000-A000-000000000123'
      subject.save path.to_s
      expect(path).to exist
    end

    context 'with duplicate references' do
      it 'removes duplicates' do
        3.times { subject.put 'london', '10000000-0000-4000-A000-000000000123', 0 }
        subject.delete '10000000-0000-4000-A000-000000000123'
        expect(subject.stats[:trigrams]).to eq(0)
        expect(subject.stats[:references]).to eq(0)
      end
    end

    it 'ignores missing references' do
      subject.delete '10000000-0000-4000-A000-000000000123'
      expect(subject.stats[:trigrams]).to eq(0)
    end

    it 'permits re-adds' do
      subject.put 'london', '10000000-0000-4000-A000-000000001337'
      subject.delete '10000000-0000-4000-A000-000000001337'
      subject.put 'paris', '10000000-0000-4000-A000-000000001337'
      expect(subject.find('paris')).not_to be_empty
    end

  end

  describe '#find' do
    let(:needle) { 'london' }
    let(:limit)  { 10 }
    let(:result) { subject.find needle, limit }

    context 'with an empty map' do
      it 'returns no results' do
        expect(result).to be_empty
      end
    end

    context 'with an empty string' do
      it 'returns no results' do
        needle.replace ''
        expect(result).to be_empty
      end
    end

    context 'with a limit option' do
      let(:limit) { 2 }
      it 'returns fewer results' do
        5.times { |idx| subject.put 'london', "10000000-0000-4000-A000-00000000100#{idx}", 0 }
        expect(result.length).to eq(2)
      end
    end

    it 'works with duplicated references' do
      subject.put needle, '10000000-0000-4000-A000-000000000123'
      subject.put 'london2', '10000000-0000-4000-A000-000000000123'
      expect(result.length).to eq(1)
      expect(result.first.first).to eq('10000000-0000-4000-A000-000000000123')
    end

    it 'works with duplicated needles and references' do
      subject.put needle, '10000000-0000-4000-A000-000000000123'
      subject.put needle, '10000000-0000-4000-A000-000000000123'
      expect(result.length).to eq(1)
      expect(result.first.first).to eq('10000000-0000-4000-A000-000000000123')
    end

    it 'returns perfect matches' do
      subject.put 'london', '10000000-0000-4000-A000-000000000123', 0
      expect(result.first).to eq(['10000000-0000-4000-A000-000000000123', 7, 6])
    end

    it 'favours exact matches' do
      subject.put 'lon',                 '10000000-0000-4000-A000-000000000125', 0
      subject.put 'london city airport', '10000000-0000-4000-A000-000000000124', 0
      subject.put 'london',              '10000000-0000-4000-A000-000000000123', 0
      expect(result.first.first).to eq('10000000-0000-4000-A000-000000000123')
    end

    it 'ignores duplicate references' do
      subject.put 'london', '10000000-0000-4000-A000-000000000123'
      subject.put 'paris',  '10000000-0000-4000-A000-000000000123'
      expect(result).not_to be_empty
    end

    context 'when needle is mis-spelt' do
      before { subject.put 'london', '10000000-0000-4000-A000-000000000123', 0 }

      it 'tolerates insertions' do
        needle.replace 'lonXdon'
        expect(result).not_to be_empty
      end

      it 'tolerates deletions' do
        needle.replace 'lodon'
        expect(result).not_to be_empty
      end

      it 'tolerates substitutions' do
        needle.replace 'lodnon'
        expect(result).not_to be_empty
      end
    end

    it 'sorts by descending matchiness' do
      subject.put 'New York',   '10000000-0000-4000-A000-000000001001', 0
      subject.put 'Yorkshire',  '10000000-0000-4000-A000-000000001002', 0
      subject.put 'York',       '10000000-0000-4000-A000-000000001003', 0
      subject.put 'Yorkisthan', '10000000-0000-4000-A000-000000001004', 0
      needle.replace 'York'
      expect(result.map(&:first)).to eq([
        '10000000-0000-4000-A000-000000001003',
        '10000000-0000-4000-A000-000000001001',
        '10000000-0000-4000-A000-000000001002',
        '10000000-0000-4000-A000-000000001004'
      ])
    end

    it 'favours the lighter of two matches' do
      subject.put 'london', '10000000-0000-4000-A000-000000000103', 103
      subject.put 'london', '10000000-0000-4000-A000-000000000101', 101
      subject.put 'london', '10000000-0000-4000-A000-000000000102', 102
      expect(result.map(&:first)).to eq([
        '10000000-0000-4000-A000-000000000101',
        '10000000-0000-4000-A000-000000000102',
        '10000000-0000-4000-A000-000000000103'
      ])
    end
  end


  describe '#save' do

    def perform
      subject.save path.to_s
    end

    let(:wordsize_byte) do
      case ['foo'].pack('p').size # size of pointer to string
      when 8 then "\x08"
      when 4 then "\x04"
      else raise 'unknown platform'
      end
    end

    let(:big_endian_byte) do
      bytes = [0xAABB].pack('S').bytes.to_a
      if bytes == [0xBB, 0xAA]
        "\x01"
      elsif bytes == [0xAA, 0xBB]
        "\x02"
      else
        raise 'unknown platform'
      end
    end

    before do
      path.delete_if_exists

      subject.put 'london',  '10000000-0000-4000-A000-000000000010', 0
      subject.put 'paris',   '10000000-0000-4000-A000-000000000011', 0
      subject.put 'monaco',  '10000000-0000-4000-A000-000000000012', 0
    end

    it 'creates a file on disk' do
      perform
      expect(path).to exist
    end

    it 'raises exception when directory does not exist' do
      expect {
        subject.save '/var/nonexistent/foo'
      }.to raise_exception(Errno::ENOENT)
    end

    it 'uses a magic header' do
      perform
      header = path.read(8)
      expect(header[0,6]).to eq("trigra")
      expect(header[6,1]).to eq(big_endian_byte)
      expect(header[7,1]).to eq(wordsize_byte)
    end

    it 'is idempotent' do
      hashes = (1..3).map { perform ; path.md5sum }
      expect(hashes[0]).to eq(hashes[1])
      expect(hashes[0]).to eq(hashes[2])
    end

    it 'makes map clean' do
      perform
      path.delete_if_exists
      perform
      expect(path).not_to exist
    end

  end


  describe '.load' do
    subject { described_class.load path.to_s }
    let(:alt_path) { Pathname.new('map2.test') }

    before do
      path.delete_if_exists
      Blurrily::Map.new.tap do |map|
        map.put 'london',  '10000000-0000-4000-A000-000000000010', 0
        map.put 'paris',   '10000000-0000-4000-A000-000000000011', 0
        map.put 'monaco',  '10000000-0000-4000-A000-000000000012', 0
        map.save path.to_s
      end
    end

    after do
      alt_path.delete_if_exists
    end

    it 'results in a searchable map' do
      expect(subject.find('london')).not_to be_empty
    end

    it 'then saves to an identical file' do
      subject.save alt_path.to_s
      expect(path.md5sum).to eq(alt_path.md5sum)
    end

    it 'raises an exception when the file does not exist' do
      path.delete_if_exists
      expect { subject }.to raise_exception(Errno::ENOENT)
    end

    it 'raises an exception if the file is incorrect' do
      path.delete_if_exists
      path.open('w') { |io| io.write 'foo' }
      expect { subject }.to raise_exception(Errno::EPROTO)
    end

    it 'raises an exception if the file is corrupt' do
      path.truncate(128) # leave the magic in, but make it the wrong size
      expect { subject }.to raise_exception(Errno::EPROTO)
    end

    it 'loads clean map' do
      subject
      path.delete_if_exists
      subject.save path.to_s
      expect(path).not_to exist
    end
  end

  describe '#close' do
    let(:closed_error) { described_class::ClosedError }
    context 'after calling #close' do
      before { subject.close }

      it '#close fails' do
        expect { subject.close }.to raise_exception(closed_error)
      end

      it '#put fails' do
        expect { subject.put('london', '10000000-0000-4000-A000-000000000123') }.to raise_exception(closed_error)
      end

      it '#find fails' do
        expect { subject.find('london') }.to raise_exception(closed_error)
      end

      it '#save fails' do
        expect { subject.save('foo') }.to raise_exception(closed_error)
      end
    end
  end

  describe 'stress check' do
    let(:path) { Pathname.new "tmp/#{$$}.trigrams" }

    after { path.delete if path.exist? }

    context 'with 1k iterations' do
      let(:count) { 1024 } # enough cycles to force reallocations

      it 'puts' do
        count.times { |index| subject.put 'Port-au-Prince', "10000000-0000-4000-A000-00000001#{'%04d' % index}" }
        expect(subject.stats[:references]).to eq(count)
        expect(subject.find('Port-au-Prince')).not_to be_empty
      end

      it 'put/delete/find' do
        count.times do |index|
          subject.put 'Port-au-Prince', "10000000-0000-4000-A000-00000002#{'%04d' % index}"
          subject.delete "10000000-0000-4000-A000-00000002#{'%04d' % index}"
          expect(subject.stats).to eq({ :references => 0, :trigrams => 0 })
          expect(subject.find('Port-au-Prince')).to be_empty
        end
      end

      it 'put/find/delete' do
        count.times do |index|
          subject.put 'Port-au-Prince', "10000000-0000-4000-A000-00000003#{'%04d' % index}"
          expect(subject.stats[:references]).to eq(1)
          expect(subject.find('Port-au-Prince').first.first).to eq("10000000-0000-4000-A000-00000003#{'%04d' % index}")
          subject.delete "10000000-0000-4000-A000-00000003#{'%04d' % index}"
        end
      end

      it 'puts, many deletes' do
        count.times { |index| subject.put 'Port-au-Prince', "10000000-0000-4000-A000-00000004#{'%04d' % index}" }
        count.times { |index| subject.delete "10000000-0000-4000-A000-00000004#{'%04d' % index}" }
        expect(subject.stats).to eq({ :references => 0, :trigrams => 0 })
        expect(subject.find('Port-au-Prince')).to be_empty
      end

      it 'puts, reload, many deletes' do
        count.times { |index| subject.put 'Port-au-Prince', "10000000-0000-4000-A000-00000005#{'%04d' % index}" }

        subject.save(path.to_s)
        subject = described_class.load(path.to_s)

        count.times { |index| subject.delete "10000000-0000-4000-A000-00000005#{'%04d' % index}" }
        expect(subject.stats).to eq({ :references => 0, :trigrams => 0 })
        expect(subject.find('Port-au-Prince')).to be_empty
      end
    end

    context 'with 100 iterations' do
      let(:count) { 100 }
      it 'cold loads' do
        count.times { |index| subject.put 'Port-au-Prince', "10000000-0000-4000-A000-00000006#{'%04d' % index}" }
        subject.save(path.to_s)

        count.times do
          described_class.load(path.to_s)
        end
      end

      it 'put/save/load/delete' do
        map = subject
        count.times do |index|
          map.put 'Port-au-Prince', "10000000-0000-4000-A000-00000007#{'%04d' % index}"
          map.save(path.to_s)
          map = described_class.load(path.to_s)
          map.delete("10000000-0000-4000-A000-00000007#{'%04d' % index}")
          expect(map.stats[:references]).to eq(0)
        end
      end

      it 'put/save/load' do
        map = subject
        count.times do |index|
          map.put 'Port-au-Prince', "10000000-0000-4000-A000-00000008#{'%04d' % index}"
          map.save(path.to_s)
          map = described_class.load(path.to_s)
          expect(map.stats[:references]).to eq(index+1) # index starts from 0
        end
      end
    end
  end

end
