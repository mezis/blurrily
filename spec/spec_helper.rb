require 'blurrily'
require 'socket'
 
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
