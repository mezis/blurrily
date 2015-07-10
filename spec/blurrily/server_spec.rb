# encoding: utf-8

require 'spec_helper'
require 'pathname'
require 'eventmachine'
require 'socket'
require "blurrily/server"

describe Blurrily::Server do
  context 'running server' do
    let(:socket) { TCPSocket.new(host, @port) }
    let(:directory) { 'tmp/data' }
    let(:host) { 'localhost' }

    before do
      @port, @pid = try_to_start_server(directory)
    end

    after do
      if @pid
        Process.kill('KILL', @pid)
        Process.wait(@pid)
      end
    end

    after do
      FileUtils.rm_rf(directory)
    end

    it 'responds' do
      socket.puts 'Who is most beautiful in the world?'
      expect(socket.gets).to match(/^ERROR\tUnknown command/)
    end

    it 'does not close the connection' do
      3.times { socket.puts 'Bad command' }
      3.times do
        expect(socket.gets).to match(/^ERROR/)
      end
    end

    it 'saves when quitting' do
      socket = TCPSocket.new('localhost', @port)
      socket.puts("PUT\twords\tsomething\t10000000-0000-4000-A000-000000000000")
      socket.gets
      socket.close

      Process.kill('TERM', @pid)
      Process.wait(@pid)
      @pid = nil
      path = Pathname.new(directory).join('words.trigrams')
      expect(path).to exist
    end
  end

  def try_to_start_server(directory)
    port = find_free_port
    pid = fork do
      described_class.new(:port => port, :directory => directory).start
      Kernel.exit 0
    end
    wait_for_socket('localhost', port)
    return [port, pid]
  end
end
