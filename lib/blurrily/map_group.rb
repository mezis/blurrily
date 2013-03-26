module Blurrily
  class MapGroup

    attr_reader :maps

    def initialize(dir)
      @maps = {}
      @dir = dir
    end

    def map(name)
      @maps[name] ||= load_map(name) || Map.new
    end

    def save
      @maps.each do |name, map|
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