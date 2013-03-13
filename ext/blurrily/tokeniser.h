/*
  
  tokeniser.h --

  Split a string into an array of trigrams.

  The string is converted into lowercase, diacritics are stripped, and any
  non-letter character ignored (this uses iconv).

  Each trigram is a three-symbol tuple consisting of latters and the
  "epsilon" character used to represent spaces and beginning-of-word/end-of-
  word anchors.

  Each trigram is represented by a 16-bit integer.

*/
#include <inttypes.h>

typedef uint16_t trigram;

/* 
  Parse the <input> string and store the result in <ouput>.
  <output> must be allocated by the caller and provide at least as many slots
  as characters in <input>.

  Returns the number of trigrams on success, a negative number on failure.
*/
int blurrily_tokeniser_parse_string(char* input, trigram* output);


/*
  Given an <input> returns a string representation of the trigram in <output>.
  <output> must be allocated by caller and will always be exactly 3
  <characters plus NULL.

  Returns positive on success, negative on failure.
*/
int blurrily_tokeniser_trigram(trigram input, char* output);
