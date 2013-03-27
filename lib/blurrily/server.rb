require 'eventmachine'

module Blurrily
  class Server

    class ProtocolError < StandardError; end

    COMMANDS = %{FIND PUT CLEAR}

    def initialize(options)
      @host, @port, @directory = options[:host], options[:port], options[:directory]
      raise ArgumentError if [@host, @port, @directory].any?(&:nil?)
    end

    def start
      EventMachine.run do
        # hit Control + C to stop
        Signal.trap("INT")  { EventMachine.stop }
        Signal.trap("TERM") { EventMachine.stop }

        EventMachine.start_server @host, @port, Handler, self
      end
    end

    def process_command_line(line)
      command, map_name, *args = line.split(/\t/)
      raise ProtocolError, 'Unknown command' unless COMMANDS.include? command
      raise ProtocolError, 'Invalid db name' unless map_name =~ /^[a-z_]+$/
      send("on_#{command.downcase}", map_name, *args)

    rescue ArgumentError, ProtocolError => e
      error(e.message)
    end

    private

    def on_put(map_name, needle, ref, weight = nil)
      raise ProtocolError, 'Ref must be a number' if ref !~ /\d+/
      raise ProtocolError, 'Weight must be a number' if weight && weight !~ /\d+/
      map_group.map(map_name).put(*[needle, ref.to_i, weight && weight.to_i].compact)
    end

    def on_find(map_name, needle, limit = 10)
      raise ProtocolError, 'Limit must be a number' if limit && limit.to_s !~ /\d+/
      results = map_group.map(map_name).find(*[needle, limit && limit.to_i].compact)
      return "FOUND\t#{results.map{ |result| result.first }.join("\t")}".strip
    end

    def on_clear(map_name)
      map_group.clear(map_name)
    end

    def map_group
      @map_group ||= MapGroup.new(@directory)
    end

    def error(message = nil)
      "ERROR\t#{message}"
    end

    module Handler
      def initialize(server)
        @server = server
      end

      def receive_data(data)
        data.split("\n").each do |line|
          send_data("#{@server.process_command_line(line.strip)}\n")
        end
      end
    end
  end
end