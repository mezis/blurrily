require 'mkmf'

PLATFORM = `uname`.strip.upcase
SHARED_FLAGS = "-DPLATFORM_#{PLATFORM} --std=c99 -Wall -Wextra"

case PLATFORM
when 'LINUX'
  # make sure ftruncate is available
  SHARED_FLAGS << ' -D_XOPEN_SOURCE=700'
  SHARED_FLAGS << ' -D_GNU_SOURCE=1'
  # make sure off_t is 64 bit long
  SHARED_FLAGS << ' -D_FILE_OFFSET_BITS=64'
end

# production
$CFLAGS += " #{SHARED_FLAGS} -Os"

# development
# $CFLAGS += " #{SHARED_FLAGS} -O0 -g"

create_makefile('blurrily/map_ext')
