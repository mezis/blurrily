require 'blurrily/map_ext'
require 'active_support/core_ext/module/aliasing' # alias_method_chain
require 'active_support/core_ext/string/multibyte' # mb_chars

module Blurrily
  Map.class_eval do

    def put_with_string_normalize(needle, reference, weight=nil)
      weight ||= 0
      needle = normalize_string needle
      put_without_string_normalize(needle, reference, weight)
    end

    alias_method_chain :put, :string_normalize

    def find_with_string_normalize(needle, limit=10)
      needle = normalize_string needle
      find_without_string_normalize(needle, limit)
    end

    alias_method_chain :find, :string_normalize

    def dirty?
      @dirty
    end

    def put_with_make_dirty(*args)
      @dirty = true
      put_without_make_dirty(*args)
    end

    alias_method_chain :put, :make_dirty

    def delete_with_make_dirty(*args)
      @dirty = true
      delete_without_make_dirty(*args)
    end

    alias_method_chain :delete, :make_dirty

    def save_with_clean_dirty(*args)
      @dirty = nil
      save_without_clean_dirty(*args)
    end

    alias_method_chain :save, :clean_dirty

    private

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
