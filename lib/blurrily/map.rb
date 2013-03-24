require 'blurrily/map_ext'
require 'active_support/all' # fixme: we only need enough to get mb_chars and alias_method_chain in

module Blurrily
  Map.class_eval do

    def put_with_string_normalize(needle, reference, weight=0)
      needle = needle.downcase
      unless needle =~ /^([a-z ])+$/
        needle = needle.mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/,'').to_s.gsub(/[^a-z]/,' ')
      end
      needle.gsub!(/\s+/,' ')
      needle.strip!
      put_without_string_normalize(needle, reference, weight)
    end

    alias_method_chain :put, :string_normalize
  end
end
