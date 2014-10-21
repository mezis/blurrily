# encoding: utf-8

require 'spec_helper'
require 'pathname'
require 'fileutils'
require 'blurrily/client'
require 'blurrily/map'

describe 'client/server integration' do
  let(:data_dir) { Pathname.new 'tmp/data' }
  let(:data_file) { data_dir.join('foobar.trigrams') }

  before { data_dir.rmtree if data_dir.exist? }
  after  { data_dir.rmtree if data_dir.exist? }

  around do |example|
    @port = find_free_port
    @pid = fork { exec "bin/blurrily -d #{data_dir} -p #{@port}" }
    wait_for_socket 'localhost', @port # until server started

    @client = Blurrily::Client.new(:port => @port, :db_name => 'foobar')

    # puts 'calling example'
    example.call
    # puts 'finished example'

    Process.kill('KILL', @pid)
    Process.detach(@pid)
  end

  it 'does single find' do
    @client.put 'paris', 123
    expect(@client.find('paris')).to match([[123, 6, 5]])
    expect(@client.find('pariis')).to match([[123, 5, 5]])
  end

  it 'does put/find cycles' do
    @client.put 'paris', 123
    @client.put 'paris', 456
    expect(@client.find('paris').map(&:first)).to match([123, 456])
    expect(@client.find('pariis').map(&:first)).to match([123, 456])
  end

  it 'does put/delete/find cycles' do
    @client.put 'paris', 123
    @client.put 'paris', 456
    @client.delete 456
    expect(@client.find('paris').map(&:first)).to match([123])
  end

  it 'handles multiple databases' do
    @other_client = Blurrily::Client.new(:port => @port, :db_name => 'qux')
    @client.put 'rome', 1
    @other_client.put 'venice', 2

    expect(@client.find('rome').map(&:first)).to eq([1])
    expect(@client.find('venice')).to be_empty
    expect(@other_client.find('venice').map(&:first)).to eq([2])
    expect(@other_client.find('rome')).to be_empty
  end

  it 'saves files on SIGURS1' do
    @client.put 'rome', 1
    Process.kill('USR1', @pid)
    wait_for_file(data_file)
  end

  it 'uses existing maps' do
    map = Blurrily::Map.new
    map.put('london', 1337)
    data_dir.mkpath
    map.save(data_file.to_s)

    expect(@client.find('london').map(&:first)).to eq([1337])
  end

end
