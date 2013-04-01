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
        Process.wait
      end
    end

    after do
      FileUtils.rm_rf(directory)
    end

    it 'responds' do
      socket.puts 'Who is most beautiful in the world?'
      socket.gets.should =~ /^ERROR\tUnknown command/
    end

    it 'does not close the connection' do
      3.times { socket.puts 'Bad command' }
      3.times { socket.gets.should =~ /^ERROR/ }
    end

    it 'saves when quitting' do
      socket = TCPSocket.new('localhost', @port)
      socket.puts("PUT\twords\tmerveilleux\t1")
      socket.gets
      socket.close

      Process.kill('TERM', @pid)
      Process.wait(@pid)
      @pid = nil
      Pathname.new(directory).join('words.trigrams').should exist
    end
  end

  def try_to_start_server(directory)
    result = 10.times do
      port = (1024 + rand(32768-1024))
      pid = fork do
        described_class.new(:port => port, :directory => directory).start
        Kernel.exit 0
      end
      started = 10.times do |i|
        sleep 50e-3
        begin
          TCPSocket.new(host, port).close
          break true
        rescue Errno::ECONNREFUSED
          next
        end
      end
      return [port, pid] if started == true
      Process.kill('KILL', pid)
      Process.detach(pid)
    end
    raise 'Could not start server'
  end
end
