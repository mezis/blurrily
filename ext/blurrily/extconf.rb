require 'mkmf'

SHARED_FLAGS = "-DPLATFORM_#{`uname`.strip.upcase} --std=c99 -Wall -Wextra -Werror"

# production
$CFLAGS += " #{SHARED_FLAGS} -O3 -fno-fast-math"

# development
# $CFLAGS += " #{SHARED_FLAGS} -DNDEBUG -O0 -g"

create_makefile('blurrily/map')
