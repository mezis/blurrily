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

    def save
      self.class.maps.each do |db_name, map|
        map.save(File.join(@dir, db_name))
      end
    end
  end
end