require 'mkmf'

$CFLAGS += " -DPLATFORM_#{`uname`.strip.upcase} --std=c99"


create_makefile('blurrily/blurrily')
