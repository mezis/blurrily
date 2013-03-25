module Blurrily
  class MapGroup

    class << self
      attr_accessor :maps
    end

    @maps = {}

    def initialize(dir = '.')
      @dir = dir
    end

    def map(db)
      self.class.maps[db] ||= Map.new
    end
  end
end