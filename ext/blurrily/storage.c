#include <stdlib.h>
#include <stdio.h>
#include "storage.h"

// one trigram entry -- client reference and sorting weight
typedef struct
{
  uint32_t reference;
  uint32_t weight;
} trigram_entry_t;


// collection of entries for a given trigram
// <entries> points to an array of <buckets> entries
// of which <used> are filled
typedef struct
{
  uint32_t         buckets;
  uint32_t         used;
  trigram_entry_t* entries;
} trigram_entries_t;


// hash map of all possible trigrams to collection of entries
// there are 27^3 = 19,683 possible trigrams
struct
{
  uint32_t          total_entries;
  trigram_entries_t map[19683];
} trigram_map_t;


int blurrily_storage_new(trigram_map* haystack)
{
  fprintf(stderr, "blurrily_storage_new\n");
  *haystack = (trigram_map) malloc(sizeof(trigram_map_t));
  return 0;
}

int blurrily_storage_load(trigram_map* haystack, char* path)
{
  *haystack = (trigram_map) malloc(sizeof(trigram_map_t));
  return 0;
}

int blurrily_storage_close(trigram_map* haystack)
{
  fprintf(stderr, "blurrily_storage_close\n");
  free(*haystack);
  *haystack = NULL;
  return 0;
}

int blurrily_storage_save(trigram_map haystack, char* path)
{
  return 0;
}

int blurrily_storage_put(trigram_map haystack, char* needle, uint32_t reference, uint32_t weight)
{
  return 0;
}

int blurrily_storage_find(trigram_map haystack, char* needle, uint16_t limit, trigram_result_t* results)
{
  return 0;
}
