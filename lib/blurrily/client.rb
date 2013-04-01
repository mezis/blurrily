# encoding: utf-8

require 'socket'
require 'ipaddr'
require 'blurrily/defaults'

module Blurrily
  class Client
    Error = Class.new(RuntimeError)

    # Public: Initialize a new Blurrily::Client connection to Blurrily::Server.
    #
    # host    - IP Address or FQDN of the Blurrily::Server.
    #           Defaults to Blurrily::DEFAULT_HOST.
    # port    - Port Blurrily::Server is listening on.
    #           Defaults to Blurrily::DEFAULT_PORT.
    # db_name - Name of the data store being targeted.
    #           Defaults to Blurrily::DEFAULT_DATABASE.
    #
    # Examples
    #
    #  Blurrily::Client.new('127.0.0.1', 12021, 'location_en')
    #  # => #<Blurrily::Client:0x007fcd0d33e708 @host="127.0.0.1", @port=12021, @db_name="location_en">
    #
    # Returns the instance of Blurrily::Client
    def initialize(options = {})
      @host    = options.fetch(:host,     DEFAULT_HOST)
      @port    = options.fetch(:port,     DEFAULT_PORT)
      @db_name = options.fetch(:db_name,  DEFAULT_DATABASE)
    end

    # Public: Find record references based on a given string (needle)
    #
    # needle - The string you're searching for matches on.
    #          Must not contain tabs.
    #          Required
    # limit  - Limit the number of results retruned (default: 10).
    #          MUST be numeric.
    #          Optional
    #
    # Examples
    #
    #  @client.find('London')
    #  # => [[123,6,3],[124,5,3]...]
    #
    # Returns an Array of matching [REF,SCORE,WEIGHT] ordered by score. REF is the identifying value of the original record.
    def find(needle, limit = nil)
      limit ||= LIMIT_DEFAULT
      check_valid_needle(needle)
      raise(ArgumentError, "LIMIT value must be in #{LIMIT_RANGE}") unless LIMIT_RANGE.include?(limit)

      cmd = ["FIND", @db_name, needle, limit]
      send_cmd_and_get_results(cmd).map(&:to_i)
    end

    # Public: Index a given record.
    #
    # db_name - The name of the data store being targeted. Required
    # needle  - The string you wish to index. Must not contain tabs. Required
    # ref     - The indentifying value of the record being indexed. Must be numeric. Required
    # weight  - Weight of this particular reference. Default 0. Don't change unless you know what you're doing. Optional.
    #
    # Examples
    #
    #  @client.put('location_en', 'London', 123, 0)
    #  # => OK
    #
    # Returns something to let you know that all is well.
    def put(needle, ref, weight = 0)
      check_valid_needle(needle)
      check_valid_ref(ref)
      raise(ArgumentError, "WEIGHT value must be in #{WEIGHT_RANGE}") unless WEIGHT_RANGE.include?(weight)

      cmd = ["PUT", @db_name, needle, ref, weight]
      send_cmd_and_get_results(cmd)
      return
    end

    def delete(ref)
      check_valid_ref(ref)
      cmd = ['DELETE', @db_name, ref]
      send_cmd_and_get_results(cmd)
      return
    end

    def clear()
      send_cmd_and_get_results(['CLEAR', @db_name])
      return
    end


    private


    PORT_RANGE = 1025..32768

    def check_valid_needle(needle)
      raise(ArgumentError, "bad needle") if !needle.kind_of?(String) || needle.empty? || needle.include?("\t")
    end

    def check_valid_ref(ref)
      raise(ArgumentError, "REF value must be in #{REF_RANGE}") unless REF_RANGE.include?(ref)
    end


    def connection
      @connection ||= TCPSocket.new(@host, @port)
    end

    def send_cmd_and_get_results(argv)
      output = argv.join("\t")
      connection.puts output
      input = connection.gets
      case input
      when "OK\n"
        return []
      when /^OK\t(.*)\n/
        return $1.split("\t")
      when /^ERROR\t(.*)\n/
        raise Error, $1
      when nil
        raise Error, 'Server disconnected'
      else
        raise Error, 'Server did not respect protocol'
      end
    end

  end
end