/*

  blurrily.h --

  Helper macros

*/

#define PACKED_STRUCT __attribute__ ((__packed__))
#define UNUSED(_IDENT) _IDENT __attribute__ ((unused))

#ifdef DEBUG
  #define LOG(...) fprintf(stderr, __VA_ARGS__)
#else
  #define LOG(...)
#endif
