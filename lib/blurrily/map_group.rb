module Blurrily
  class MapGroup

    class << self
      attr_accessor :maps
    end

    @maps = {}

    def initialize(dir)
      @dir = dir
    end

    def map(name)
      self.class.maps[name] ||= load_map(name) || Map.new
    end

    def save
      self.class.maps.each do |name, map|
        map.save(map_path(name))
      end
    end

    private

    def load_map(name)
      Map.load(map_path(name))
    rescue Errno::ENOENT
      nil
    end

    def map_path(name)
      File.join(@dir, "#{name}.dat")
    end
  end
end