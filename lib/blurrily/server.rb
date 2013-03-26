require 'eventmachine'

module Blurrily
  class Server

    def initialize(host, port, dir)
      @host, @port, @dir = host, port, dir
    end

    def start
      EventMachine.run do
        EventMachine.start_server @host, @port, Handler, self
      end
    end

    def process(data)
      'some output.'
    end


    module Handler
      def initialize(server)
        @server = server
      end

      def receive_data(data)
        send_data(@server.process(data))
        close_connection_after_writing
      end
    end
  end
end