require 'pathname'
require 'blurrily/map'

module Blurrily
  class MapGroup

    def initialize(directory)
      @directory = Pathname.new(directory)
      @maps = {}
    end

    def map(name)
      @maps[name] ||= load_map(name) || Map.new
    end

    def save
      @directory.mkpath
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
      File.join(@directory, "#{name}.trigrams")
    end
  end
end