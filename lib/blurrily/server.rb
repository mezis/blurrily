require 'eventmachine'
require 'blurrily/defaults'
require 'blurrily/command_processor'
require 'blurrily/map_group'

module Blurrily
  class Server

    def initialize(options)
      @host      = options.fetch(:host,      '0.0.0.0')
      @port      = options.fetch(:port,      Blurrily::DEFAULT_PORT)
      directory  = options.fetch(:directory, Dir.pwd)

      @map_group = MapGroup.new(directory)
      @command_processor = CommandProcessor.new(@map_group)
    end

    def start
      EventMachine.run do
        # hit Control + C to stop
        Signal.trap("INT")  { EventMachine.stop }
        Signal.trap("TERM") { EventMachine.stop }

        saver = proc { @map_group.save }
        EventMachine.add_periodic_timer(60, &saver)
        EventMachine.add_shutdown_hook(&saver)
        Signal.trap("USR1", &saver)

        EventMachine.start_server(@host, @port, Handler, @command_processor)
      end
    end

    private

    module Handler
      def initialize(processor)
        @processor = processor
      end

      def receive_data(data)
        #puts data.inspect
        data.split("\n").each do |line|
          output = @processor.process_command(line.strip)
          output << "\n"
          send_data(output)
        end
      end
    end
  end
end
