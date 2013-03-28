require 'eventmachine'

module Blurrily
  class Server

    def initialize(options)
      @host, @port, @directory = options[:host], options[:port], options[:directory]
      raise ArgumentError if [@host, @port, @directory].any?(&:nil?)
      @command_processor = CommandProcessor.new(@directory)
    end

    def start
      EventMachine.run do
        # hit Control + C to stop
        Signal.trap("INT")  { EventMachine.stop }
        Signal.trap("TERM") { EventMachine.stop }

        EventMachine.start_server @host, @port, Handler, @command_processor
      end
    end

    module Handler
      def initialize(processor)
        @processor = processor
      end

      def receive_data(data)
        data.split("\n").each do |line|
          send_data("#{@processor.process_command(line.strip)}\n")
        end
      end
    end
  end
end