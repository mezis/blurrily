# encoding: utf-8

require 'socket'
require 'ipaddr'
require 'blurrily/defaults'

module Blurrily
  class Client
    Error = Class.new(RuntimeError)

    # Initialize a new {Blurrily::Client} connection to {Blurrily::Server}.
    #
    # @param host IP Address or FQDN of the Blurrily::Server.
    #           Defaults to Blurrily::DEFAULT_HOST.
    # @param port Port Blurrily::Server is listening on.
    #           Defaults to Blurrily::DEFAULT_PORT.
    # @param db_name Name of the data store being targeted.
    #           Defaults to Blurrily::DEFAULT_DATABASE.
    #
    # Examples
    #
    # ```
    # Blurrily::Client.new('127.0.0.1', 12021, 'location_en')
    # # => #<Blurrily::Client:0x007fcd0d33e708 @host="127.0.0.1", @port=12021, @db_name="location_en">
    # ```
    #
    # @returns the instance of {Blurrily::Client}
    def initialize(options = {})
      @host    = options.fetch(:host,     DEFAULT_HOST)
      @port    = options.fetch(:port,     DEFAULT_PORT)
      @db_name = options.fetch(:db_name,  DEFAULT_DATABASE)
    end

    # Find record references based on a given string (needle)
    #
    # @param needle The string you're searching for matches on.
    #          Must not contain tabs.
    #          Required
    # @param limit  Limit the number of results retruned (default: 10).
    #          Must be numeric.
    #          Optional
    #
    # Examples
    #
    # ```
    # @client.find('London')
    # # => [[123,6,3],[124,5,3]...]
    # ```
    #
    # @returns an Array of matching [`ref`,`score`,`weight`] ordered by score. `ref` is the identifying value of the original record.
    # Note that unless modified, `weight` is simply the string length.
    def find(needle, limit = nil)
      limit ||= LIMIT_DEFAULT
      check_valid_needle(needle)
      raise(ArgumentError, "LIMIT value must be in #{LIMIT_RANGE}") unless LIMIT_RANGE.include?(limit)

      cmd = ["FIND", @db_name, needle, limit]
      send_cmd_and_get_results(cmd).each_slice(3).to_a.each do |a|
        a[1] = a[1].to_i if Integer(a[1])
        a[2] = a[2].to_i if Integer(a[1])
      end
    end

    # Index a given record.
    #
    # @param db_name The name of the data store being targeted. Required
    # @param needle The string you wish to index. Must not contain tabs. Required
    # @param ref The indentifying value of the record being indexed. Must be numeric. Required
    # @param weight Weight of this particular reference. Default 0. Don't change unless you know what you're doing. Optional.
    #
    # Examples
    #
    # ```
    # @client.put('location_en', 'London', 123, 0)
    # # => OK
    # ```
    #
    # @returns something to let you know that all is well.
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
      raise(ArgumentError, "REF value must be uuid") unless valid_uuid?(ref)
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

    def valid_uuid? s
      !(s =~ /[A-F1-9][A-F0-9]{7}-[A-F0-9]{4}-4[A-F0-9]{3}-[89AB][A-F0-9]{3}-[A-F0-9]{12}/i).nil?
    end

  end
end
