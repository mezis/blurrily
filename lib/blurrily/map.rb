require 'blurrily/map_ext'
require 'active_support/core_ext/module/aliasing' # alias_method_chain
require 'active_support/core_ext/string/multibyte' # mb_chars

module Blurrily
  class Map < CMap

    def initialize
      @dirty = true
      super
    end

    def put(needle, reference, weight=nil)
      weight ||= 0
      needle = normalize_string needle
      @dirty = true
      super(needle, reference, weight)
    end

    def find(needle, limit=10)
      needle = normalize_string needle
      super(needle, limit)
    end

    def delete(*args)
      @dirty = true
      super(*args)
    end

    def save(*args)
      if @dirty
        saved = super(*args)
        @dirty = false
        saved
      end
    end

    private

    def dirty?
      @dirty
    end

    def normalize_string(needle)
      result = needle.downcase
      unless result =~ /^([a-z ])+$/
        result = ActiveSupport::Multibyte::Chars.new(result).mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/,'').to_s.gsub(/[^a-z]/,' ')
        # result = result.mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/,'').to_s.gsub(/[^a-z]/,' ')
      end
      result.gsub(/\s+/,' ').strip
    end
  end
end
