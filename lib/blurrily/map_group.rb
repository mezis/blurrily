require 'pathname'
require 'blurrily/map'

module Blurrily
  class MapGroup

    def initialize(directory = nil)
      @directory = Pathname.new(directory || Dir.pwd)
      @maps = {}
    end

    def map(name)
      @maps[name] ||= load_map(name) || Map.new
    end

    def save
      @directory.mkpath
      @maps.each do |name, map|
        map.save(path_for(name).to_s) if map.dirty?
      end
    end

    def clear(name)
      @maps[name] = Map.new
    end

    private

    def load_map(name)
      Map.load(path_for(name).to_s)
    rescue Errno::ENOENT
      nil
    end

    def path_for(name)
      @directory.join("#{name}.trigrams")
    end
  end
end