require 'delegate'
require 'active_support/all'

module Blurrily
  class String < SimpleDelegator
    def normalize
      __getobj__.
        mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/,'').downcase.to_s.
        gsub(/[^a-z]/,' ').
        gsub(/\s+/,' ').
        strip
    end
  end
end