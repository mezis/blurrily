# encoding: utf-8
require 'blurrily/map_group'
require 'blurrily/defaults'

module Blurrily
  class CommandProcessor
    ProtocolError = Class.new(StandardError)

    def initialize(directory)
      @map_group = MapGroup.new(directory)
    end

    def process_command(line)
      command, map_name, *args = line.split(/\t/)
      raise ProtocolError, 'Unknown command' unless COMMANDS.include? command
      raise ProtocolError, 'Invalid database name' unless map_name =~ /^[a-z_]+$/
      send("on_#{command}", map_name, *args)

    rescue ArgumentError, ProtocolError => e
      "ERROR\t#{e.message}"
    end

    private

    COMMANDS = %w(FIND PUT CLEAR)

    def on_PUT(map_name, needle, ref, weight = nil)
      raise ProtocolError, 'Invalid reference' unless ref =~ /^\d+$/ && REF_RANGE.include?(ref.to_i)
      raise ProtocolError, 'Invalid weight'    unless weight.nil? || (weight =~ /^\d+$/ && WEIGHT_RANGE.include?(weight.to_i))

      @map_group.map(map_name).put(*[needle, ref.to_i, weight.to_i].compact)
      return nil
    end

    def on_FIND(map_name, needle, limit = nil)
      raise ProtocolError, 'Limit must be a number' if limit && !LIMIT_RANGE.include?(limit.to_i)

      results = @map_group.map(map_name).find(*[needle, limit && limit.to_i].compact)
      refs = results.map{ |result| result.first }
      return ['FOUND', *refs].join("\t")
    end

    def on_CLEAR(map_name)
      @map_group.clear(map_name)
      return nil
    end
  end
end