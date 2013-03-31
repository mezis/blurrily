require 'eventmachine'

module Blurrily
  class Server

    def initialize(options)
      @host      = options.fetch(:host,      '0.0.0.0')
      @port      = options.fetch(:port,      Blurrily::DEFAULT_PORT)
      directory  = options.fetch(:directory, Dir.pwd)
      @command_processor = CommandProcessor.new(directory)
    end

    def start
      EventMachine.run do
        # hit Control + C to stop
        Signal.trap("INT")  { EventMachine.stop }
        Signal.trap("TERM") { EventMachine.stop }

        EventMachine.start_server(@host, @port, Handler, @command_processor)
      end
    end

    module Handler
      def initialize(processor)
        @processor = processor
      end

      def receive_data(data)
        data.split("\n").each do |line|
          output = @processor.process_command(line.strip)
          output << "\n"
          send_data(output)
        end
      end
    end
  end
end