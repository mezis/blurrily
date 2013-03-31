require "blurrily/map_ext"
require "blurrily/map"
require "blurrily/version"
require "blurrily/server"
require 'blurrily/map_group'
require 'blurrily/command_processor'
require "blurrily/client"

module Blurrily
  DEFAULT_HOST     = 'localhost'
  DEFAULT_PORT     = 12021
  DEFAULT_DATABASE = 'words'

  LIMIT_DEFAULT = 10
  LIMIT_RANGE   = 1..1024
  REF_RANGE     = 1..(1<<31)
  WEIGHT_RANGE  = 0..(1<<31)
end
