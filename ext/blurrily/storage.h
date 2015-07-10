/*

  storage.h --

  Trigram map creation, persistence, and qurying.

*/
#ifndef __STORAGE_H__
#define __STORAGE_H__

#include <inttypes.h>
#include "tokeniser.h"
#include "blurrily.h"

struct trigram_map_t;
typedef struct trigram_map_t* trigram_map;

struct BR_PACKED_STRUCT trigram_match_t {
  uuid_t reference;
  uint32_t matches;
  uint32_t weight;
};
typedef struct trigram_match_t trigram_match_t;
typedef struct trigram_match_t* trigram_match;

typedef struct trigram_stat_t {
  uint32_t references;
  uint32_t trigrams;

} trigram_stat_t;


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
  Mark resources managed by Ruby GC.
*/
void blurrily_storage_mark(trigram_map haystack);


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
int blurrily_storage_put(trigram_map haystack, const char* needle, uuid_t reference, uint32_t weight);

/*
  Check the map for an existing <reference>.

  Returns < 0 on error, 0 if the reference is not found, the number of trigrams
  for that reference otherwise.

  If <weight> is not NULL, will be set to the weight value passed to the put
  method on return (is the reference is found).

  If <trigrams> is not NULL, it should point an array <nb_trigrams> long,
  and up to <nb_trigrams> will be copied into it matching the <needle>
  originally passed to the put method.

  Not that this is a O(n) method: the whole map will be read.
*/
// int blurrily_storage_get(trigram_map haystack, uint32_t reference, uint32_t* weight, int nb_trigrams, trigram_t* trigrams);

/*
  Remove a <reference> from the map.

  Note that this is very innefective.

  Returns positive on success, negative on failure.
*/
int blurrily_storage_delete(trigram_map haystack, uuid_t reference);

/*
  Return at most <limit> entries matching <needle> from the <haystack>.

  Results are written to <results>. The first results are the ones entries
  sharing the most trigrams with the <needle>. Amongst entries with the same
  number of matches, the lightest ones (lowest <weight>) will be returned
  first.

  <results> should be allocated by the caller.

  Returns number of matches on success, negative on failure.
*/
int blurrily_storage_find(trigram_map haystack, const char* needle, uint16_t limit, trigram_match results);

/*
  Copies metadata into <stats>

  Returns positive on success, negative on failure.
*/
int blurrily_storage_stats(trigram_map haystack, trigram_stat_t* stats);

#endif
