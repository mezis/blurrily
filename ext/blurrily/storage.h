/*
  
  storage.h --

  Trigram map creation, persistence, and qurying.

*/
#include <inttypes.h>
#include "tokeniser.h"

struct trigram_map_t;
typedef struct trigram_map_t* trigram_map;

struct trigram_result_t {
  uint32_t reference;
  uint32_t matches;
  uint32_t weight;
};
typedef struct trigram_result_t* trigram_result;


/* 
  Create a new trigram map, resident in memory.
*/
int blurrily_storage_new(trigram_map* haystack);

/* 
  Load an existing trigram map from disk.
*/
int blurrily_storage_load(trigram_map* haystack, const char* path);

/* 
  Release resources claimed by <new> or <open>.
*/
int blurrily_storage_close(trigram_map* haystack);

/* 
  Persist to disk what <blurrily_storage_new> or <blurrily_storage_open>
  gave you.
*/
int blurrily_storage_save(trigram_map haystack, const char* path);

/*
  Add a new string to the map. <reference> is your identifier for that
  string, <weight> will be using to discriminate entries that match "as
  well" when searching.

  If <weight> is zero, it will be replaced by the number of characters in
  the <needle>.

  Returns positive on success, negative on failure.
*/
int blurrily_storage_put(trigram_map haystack, const char* needle, uint32_t reference, uint32_t weight);

/*
  Return at most <limit> entries matching <needle> from the <haystack>.

  Results are written to <results>. The first results are the ones entries
  sharing the most trigrams with the <needle>. Amongst entries with the same
  number of matches, the lightest ones (lowest <weight>) will be returned
  first.

  <results> should be allocated by the caller.

  Returns number of matches on success, negative on failure.
*/
int blurrily_storage_find(trigram_map haystack, const char* needle, uint16_t limit, trigram_result results);
