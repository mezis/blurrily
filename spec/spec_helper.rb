require 'blurrily'
require 'socket'
 
TCP_NEW = TCPSocket.method(:new) unless defined? TCP_NEW
 
#
# Example:
#   mock_tcp_next_request("<xml>junk</xml>")
#
class FakeTCPSocket
 
  def put(some_text = nil); end
  
  def get
    @canned_response[0..@canned_response.size]
  end
 
  def set_canned(response)
    @canned_response = response
  end
 
end
 
def mock_tcp_next_request(string, client_expectation = nil) 
  TCPSocket.stub!(:new).and_return {
    cm = FakeTCPSocket.new
    cm.set_canned(string)
    cm.should_receive(:put).with(client_expectation) unless client_expectation.nil?
    cm
  }
end

def unmock_tcp
  TCPSocket.stub!(:new).and_return { TCP_NEW.call }
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
