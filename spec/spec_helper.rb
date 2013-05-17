require 'blurrily'
require 'socket'
require 'timeout'
require 'coveralls'

Coveralls.wear!
 
#
# Example:
#   mock_tcp_next_request("<xml>junk</xml>")
#
class FakeTCPSocket
  def initialize(canned_response)
    @canned_response = canned_response
  end

  def puts(ignored = nil)
  end
  
  def gets
    "#{@canned_response}\n"
  end
end
 
def mock_tcp_next_request(string, client_expectation=nil) 
  TCPSocket.stub!(:new).and_return do
    FakeTCPSocket.new(string).tap do |fake_socket|
      if client_expectation
        fake_socket.should_receive(:puts).with(client_expectation)
      end

      TCPSocket.unstub!(:new)
    end
  end
end


def is_port_open?(host, port)
  Timeout::timeout(1.0) do
    TCPSocket.new(host, port).close
    return true
  end
rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
  return false
end

def find_free_port()
  while true
    port = 1024 + rand(32768 - 1024)
    is_port_open?('localhost', port) and next
    break port
  end
end

def wait_for_socket(host, port, timeout=10.0)
  Timeout::timeout(timeout) do
    sleep 50e-3 while !is_port_open?(host, port)
  end
end

def wait_for_file(path, timeout=10.0)
  Timeout::timeout(timeout) do
    sleep 50e-3 until path.exist?
  end
end


RSpec.configure do |config|
  config.before(:each) do
  end

  config.after(:each) do
  end
end


Pathname.class_eval do
  def md5sum
    Digest::MD5.file(self.to_s)
  end

  def delete_if_exists
    delete if exist?
  end
end
