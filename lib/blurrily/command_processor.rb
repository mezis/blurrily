# encoding: utf-8
require 'blurrily/defaults'

module Blurrily
  class CommandProcessor
    ProtocolError = Class.new(StandardError)

    def initialize(map_group)
      @map_group = map_group
    end

    def process_command(line)
      command, map_name, *args = line.split(/\t/)
      raise ProtocolError, 'Unknown command' unless COMMANDS.include? command
      raise ProtocolError, 'Invalid database name' unless map_name =~ /^[a-z_]+$/
      result = send("on_#{command}", map_name, *args)
      ['OK', *result].compact.join("\t")
    rescue ArgumentError, ProtocolError => e
      ['ERROR', e.message].join("\t")
    end

    private

    COMMANDS = %w(FIND PUT DELETE CLEAR)

    def on_PUT(map_name, needle, ref, weight = nil)
      raise ProtocolError, 'Invalid reference' unless ref =~ /^\d+$/ && REF_RANGE.include?(ref.to_i)
      raise ProtocolError, 'Invalid weight'    unless weight.nil? || (weight =~ /^\d+$/ && WEIGHT_RANGE.include?(weight.to_i))

      @map_group.map(map_name).put(*[needle, ref.to_i, weight.to_i].compact)
      return
    end

    def on_DELETE(map_name, ref)
      raise ProtocolError, 'Invalid reference' unless ref =~ /^\d+$/ && REF_RANGE.include?(ref.to_i)

      @map_group.map(map_name).delete(ref.to_i)
      return
    end

    def on_FIND(map_name, needle, limit = nil)
      raise ProtocolError, 'Limit must be a number' if limit && !LIMIT_RANGE.include?(limit.to_i)

      results = @map_group.map(map_name).find(*[needle, limit && limit.to_i].compact)
      refs = results.map{ |result| result.first }
      return refs
    end

    def on_CLEAR(map_name)
      @map_group.clear(map_name)
      return
    end
  end
end
