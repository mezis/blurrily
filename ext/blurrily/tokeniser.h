/*
  
  tokeniser.h --

  Split a string into an array of trigrams.

  The input string should be only lowercase latin letters and spaces
  (convert using iconv).

  Each trigram is a three-symbol tuple consisting of latters and the
  "epsilon" character used to represent spaces and beginning-of-word/end-of-
  word anchors.

  Each trigram is represented by a 16-bit integer.

*/
#include <inttypes.h>

#define TRIGRAM_BASE 28

typedef uint16_t trigram_t;

/* 
  Parse the <input> string and store the result in <ouput>.
  <output> must be allocated by the caller and provide at least as many slots
  as characters in <input>, plus one.
  (not all will be necessarily be filled)

  Returns the number of trigrams on success, a negative number on failure.
*/
int blurrily_tokeniser_parse_string(const char* input, trigram_t* output);


/*
  Given an <input> returns a string representation of the trigram in <output>.
  <output> must be allocated by caller and will always be exactly 3
  <characters plus NULL.

  Returns positive on success, negative on failure.
*/
int blurrily_tokeniser_trigram(trigram_t input, char* output);
