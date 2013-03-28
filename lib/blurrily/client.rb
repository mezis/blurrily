# encoding: utf-8

require 'socket'

module Blurrily
  class Client

    IP_REGEX = /(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/
    PORT_REGEX = LIMIT_REGEX = REF_REGEX = WEIGHT_REGEX = /[\d]+/
    NEEDLE_REGEX = /[\t]+/

    # Public: Initialize a new Blurrily::Client connection to Blurrily::Server.
    #
    # host    - IP Address of the Blurrily::Server.
    #           MUST be a valid IP Address.
    #           Required.
    # port    - Port Blurrily::Server is listening on.
    #           MUST be numeric.
    #           Required.
    # db_name - Name of the data store being targeted.
    #           Required.
    #
    # Examples
    #
    #  Blurrily::Client.new('127.0.0.1', 12021, 'location_en')
    #  # => #<Blurrily::Client:0x007fcd0d33e708 @host="127.0.0.1", @port=12021, @db_name="location_en", @client=#<TCPSocket:fd 5>>
    #
    # Returns the instance of Blurrily::Client
    def initialize(options)
      raise(ArgumentError, "HOST value given was not a valid IP address.") unless (options[:host] && options[:host].match(IP_REGEX))
      raise(ArgumentError, "PORT value given was not a valid port value.") unless (options[:port].to_s && options[:port].to_s.match(PORT_REGEX))
      raise(ArgumentError, "DB_NAME value must be given")                  if (options[:db_name].nil? || options[:db_name].empty?)

      @host    = options[:host]
      @port    = options[:port]
      @db_name = options[:db_name]
    end

    # Public: Find record references based on a given string (needle)
    #
    # needle - The string you're searching for matches on.
    #          Must not contain tabs.
    #          Required
    # limit  - Limit the number of results retruned (default: 20).
    #          MUST be numeric.
    #          Optional
    #
    # Examples
    #
    #  @client.find('London')
    #  # => [[123,6,3],[124,5,3]...]
    #
    # Returns an Array of matching [REF,SCORE,WEIGHT] ordered by score. REF is the identifying value of the original record.
    def find(needle, limit = 0)
      raise(ArgumentError, "NEEDLE value must be given")                   if (needle.nil? || needle.empty?)
      raise(ArgumentError, "NEEDLE value must not contain tab characters") if needle.match(NEEDLE_REGEX)
      raise(ArgumentError, "LIMIT value must be numberic")                 unless limit.to_s.match(LIMIT_REGEX)

      cmd = ["FIND", @db_name, needle, limit].join("\t")
      return send_cmd_and_get_results(cmd)
    end

    # Public: Index a given record.
    #
    # db_name - The name of the data store being targeted. Required
    # needle  - The string you wish to index. Must not contain tabs. Required
    # ref     - The indentifying value of the record being indexed. Must be numeric. Required
    # weight  - Limit the number of results retruned, default is 0. Must be numeric. Optional
    #
    # Examples
    #
    #  @client.put('location_en', 'London', 123, 0)
    #  # => OK
    #
    # Returns something to let you know that all is well.
    def put(db_name, needle, ref, weight = 0)
      raise(ArgumentError, "DB_NAME value must be given")                  if (db_name.nil? || db_name.empty?)
      raise(ArgumentError, "NEEDLE value must be given")                   if needle.match(NEEDLE_REGEX)
      raise(ArgumentError, "NEEDLE value must not contain tab characters") if needle.match(NEEDLE_REGEX)
      raise(ArgumentError, "REF value must be given")                      if (db_name.nil? || db_name.empty?)
      raise(ArgumentError, "REF value must be numberic")                   unless ref.to_s.match(REF_REGEX)
      raise(ArgumentError, "WEIGHT value must be numberic")                unless ref.to_s.match(WEIGHT_REGEX)

      cmd = ["PUT",db_name,needle,ref,weight].join("\t")
      return send_cmd_and_get_results(cmd)
    end

    def clear
      raise(NotImplementedError)
    end

    private

    def send_cmd_and_get_results(cmd)
      @client = TCPSocket.new @host, @port
      @client.put(cmd)
      results = @client.get
      return results
    end

  end
end