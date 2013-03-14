#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "storage.h"

#define TRIGRAM_COUNT               19683
#define TRIGRAM_ENTRIES_START_SIZE  128

// one trigram entry -- client reference and sorting weight
struct trigram_entry_t
{
  uint32_t reference;
  uint32_t weight;
};
typedef struct trigram_entry_t trigram_entry_t;


// collection of entries for a given trigram
// <entries> points to an array of <buckets> entries
// of which <used> are filled
struct trigram_entries_t
{
  uint32_t         buckets;
  uint32_t         used;
  trigram_entry_t* entries;
};
typedef struct trigram_entries_t trigram_entries_t;


// hash map of all possible trigrams to collection of entries
// there are 27^3 = 19,683 possible trigrams
struct trigram_map_t
{
  uint32_t          total_entries;
  trigram_entries_t map[TRIGRAM_COUNT];
};
typedef struct trigram_map_t trigram_map_t;



int blurrily_storage_new(trigram_map* haystack_ptr)
{
  trigram_map         haystack = (trigram_map)NULL;
  trigram_entries_t*  ptr      = NULL;
  int                 k        = 0;

  fprintf(stderr, "blurrily_storage_new\n");
  haystack = (trigram_map) malloc(sizeof(trigram_map_t));

  haystack->total_entries = 0;
  for(k = 0, ptr = haystack->map ; k < TRIGRAM_COUNT ; ++k, ++ptr) {
    ptr->buckets = 0;
    ptr->used    = 0;
    ptr->entries = (trigram_entry_t*)NULL;
  }

  *haystack_ptr = haystack;
  return 0;
}

int blurrily_storage_load(trigram_map* haystack, char* path)
{
  return blurrily_storage_new(haystack);
}

int blurrily_storage_close(trigram_map* haystack_ptr)
{
  trigram_map         haystack = *haystack_ptr;
  trigram_entries_t*  ptr      = NULL;
  int                 k        = 0;

  fprintf(stderr, "blurrily_storage_close\n");

  for(k = 0, ptr = haystack->map ; k < TRIGRAM_COUNT ; ++k, ++ptr) {
    free(ptr->entries);
  }

  free(haystack);
  *haystack_ptr = NULL;
  return 0;
}

int blurrily_storage_save(trigram_map haystack, char* path)
{
  return 0;
}

int blurrily_storage_put(trigram_map haystack, char* needle, uint32_t reference, uint32_t weight)
{
  int        nb_trigrams  = -1;
  int        length       = strlen(needle);
  trigram_t* trigrams     = (trigram_t*)NULL;

  trigrams = (trigram_t*)malloc((length+1) * sizeof(trigram_t));
  nb_trigrams = blurrily_tokeniser_parse_string(needle, trigrams);

  if (weight <= 0) weight = length;

  for (int k = 0; k < nb_trigrams; ++k) {
    trigram_t          t       = trigrams[k];
    trigram_entries_t* entries = &haystack->map[t];
    trigram_entry_t    entry   = { reference, weight };

    // allocate more space as needed (exponential growth)
    if (entries->buckets == 0) {
      entries->buckets = TRIGRAM_ENTRIES_START_SIZE;
      entries->entries = (trigram_entry_t*) malloc(entries->buckets * sizeof(trigram_entry_t));
    }
    if (entries->used >= entries->buckets) {
      entries->buckets *= 2;
      entries->entries = realloc(
        entries->entries,
        entries->buckets * sizeof(trigram_entry_t)
      );
    }
    entries->entries[entries->used] = entry;
    
    entries->used++;
    haystack->total_entries++;
  }

  free((void*)trigrams);
  return 0;
}

int blurrily_storage_find(trigram_map haystack, char* needle, uint16_t limit, trigram_result results)
{
  return 0;
}
