# encoding: utf-8

require 'spec_helper'
require 'pathname'
require 'eventmachine'
require 'socket'

describe Blurrily::Server do
  context 'running server' do
    before :all do
      @host = '0.0.0.0'
      @directory = '.'
      @server, @port, @thread = try_to_start_server(@host, @directory)
    end

    after :all do
      @thread.kill if @thread
    end

    it 'responds and closes connection' do
      Timeout::timeout(1) do
        socket = TCPSocket.new(@host, @port)
        socket.puts 'Who is most beautiful in the world?'
        socket.gets.should =~ /ERROR\tUnknown command/
      end
    end
  end

  def random_port
    (10000 + rand * 54000).to_i
  end

  def try_to_start_server(host, directory)
    result = 5.times do
      port = random_port
      server = described_class.new({ :host => host, :port => port, :directory => directory })
      thread = Thread.new { server.start }
      started = 3.times do |i|
        sleep 0.01 * 14 ** i
        next unless thread.alive?
        connection = begin
          TCPSocket.new(host, port)
        rescue Errno::ECONNREFUSED
          nil
        end
        if connection
          connection.close
          break true
        end
      end
      break [server, port, thread] if started == true
    end
    raise 'Could not start server' if result.is_a?(Fixnum)
    result
  end
end
