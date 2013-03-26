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
      command, map_name, *args = data.split(/\t/)
      return error('Unknown command') unless %w{FIND PUT CLEAR}.include? command
      return error('Invalid db name') unless map_name =~ /^[a-z_]+$/
      send(command.downcase, map_name, *args)

    rescue ArgumentError => e
      error(e.message)
    end

    def put(map_name, needle, ref, weight = nil)
      return error('Ref must be a number') if ref !~ /\d+/
      return error('Weight must be a number') if weight && weight !~ /\d+/
      map_group.map(map_name).put(*[needle, ref.to_i, weight && weight.to_i].compact)
      return ok
    end

    def find(map_name, needle, limit = 10)
      return error('Limit must be a number') if limit && limit.to_s !~ /\d+/
      results = map_group.map(map_name).find(*[needle, limit && limit.to_i].compact)
      return 'NOT FOUND' if results.length == 0
      return "FOUND\t#{results.map{ |result| result.first }.join("\t")}"
    end

    def clear(map_name)
      map_group.clear(map_name) ? ok : error
    end

    private

    def map_group
      @map_group ||= MapGroup.new(@dir)
    end

    def ok
      'OK'
    end

    def error(message = nil)
      "ERROR\t#{message}"
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