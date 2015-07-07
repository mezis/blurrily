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
      raise ProtocolError, 'Invalid reference' unless valid_uuid?(ref)
      raise ProtocolError, 'Invalid weight'    unless weight.nil? || (weight =~ /^\d+$/ && WEIGHT_RANGE.include?(weight.to_i))

      @map_group.map(map_name).put(*[needle, ref, weight.to_i].compact)
      return
    end

    def on_DELETE(map_name, ref)
      raise ProtocolError, 'Invalid reference' unless valid_uuid?(ref)

      @map_group.map(map_name).delete(ref)
      return
    end

    def on_FIND(map_name, needle, limit = nil)
      raise ProtocolError, 'Limit must be a number' if limit && !LIMIT_RANGE.include?(limit.to_i)

      results = @map_group.map(map_name).find(*[needle, limit && limit.to_i].compact)
      return results.flatten
    end

    def on_CLEAR(map_name)
      @map_group.clear(map_name)
      return
    end

    def valid_uuid? s
      !(s =~ /[A-F1-9][A-F0-9]{7}-[A-F0-9]{4}-4[A-F0-9]{3}-[89AB][A-F0-9]{3}-[A-F0-9]{12}/i).nil?
    end
  end
end
