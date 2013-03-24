require 'mkmf'

PLATFORM = `uname`.strip.upcase
SHARED_FLAGS = "-DPLATFORM_#{PLATFORM} --std=c99 -Wall -Wextra -Werror"

case PLATFORM
when 'LINUX'
  SHARED_FLAGS += ' -D_XOPEN_SOURCE=500' # for ftruncate to be present
end

# production
$CFLAGS += " #{SHARED_FLAGS} -O3 -fno-fast-math"

# development
# $CFLAGS += " #{SHARED_FLAGS} -O0 -g"

create_makefile('blurrily/map_ext')
