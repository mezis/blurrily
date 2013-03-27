require 'fileutils'

module Blurrily
  class MapGroup

    def initialize(options = {})
      @maps = {}
      @directory = options[:directory] || '.'
    end

    def map(name)
      @maps[name] ||= load_map(name) || Map.new
    end

    def save
      FileUtils.makedirs(@directory) unless File.directory?(@directory)
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