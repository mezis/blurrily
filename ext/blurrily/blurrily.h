/*

  blurrily.h --

  Helper macros

*/

#ifndef __BLURRILY_H__
#define __BLURRILY_H__ 1

#define BR_PACKED_STRUCT __attribute__ ((__packed__))
#define UNUSED(_IDENT) _IDENT __attribute__ ((unused))

#ifdef DEBUG
  #define LOG(...) fprintf(stderr, __VA_ARGS__)
#else
  #define LOG(...)
#endif

#endif
