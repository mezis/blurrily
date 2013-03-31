require 'blurrily'
require 'socket'
 
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
  TCPSocket.stub!(:new).and_return do
    FakeTCPSocket.new.tap do |fake_socket|
      fake_socket.set_canned(string)
      fake_socket.
        should_receive(:put).
        with(client_expectation) unless client_expectation.nil?
    end
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
