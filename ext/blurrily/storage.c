#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "storage.h"

#include "log.h"

/******************************************************************************/

#define PAGE_SIZE                   4096
#define TRIGRAM_COUNT               (TRIGRAM_BASE * TRIGRAM_BASE * TRIGRAM_BASE)
#define TRIGRAM_ENTRIES_START_SIZE  PAGE_SIZE/8

/******************************************************************************/

// one trigram entry -- client reference and sorting weight
// (note that keeping this 64bit wide helps)
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

  trigram_entry_t* entries;         // set when the structure is in memory
  size_t           entries_offset;  // set when the structure is on disk
};
typedef struct trigram_entries_t trigram_entries_t;


// hash map of all possible trigrams to collection of entries
// there are 28^3 = 19,683 possible trigrams
struct trigram_map_t
{
  uint32_t          total_entries;
  trigram_entries_t map[TRIGRAM_COUNT];
};
typedef struct trigram_map_t trigram_map_t;

/******************************************************************************/

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

/******************************************************************************/

int blurrily_storage_load(trigram_map* haystack, const char* path)
{
  return blurrily_storage_new(haystack);
}

/******************************************************************************/

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

/******************************************************************************/

static size_t round_to_page(size_t value)
{
  if (value % PAGE_SIZE == 0) return value;
  return (value / PAGE_SIZE + 1) * PAGE_SIZE;
}

static size_t get_map_size(trigram_map haystack, int index)
{
  return haystack->map[index].buckets * sizeof(trigram_entry_t);
}

/******************************************************************************/

int blurrily_storage_save(trigram_map haystack, const char* path)
{
  int     fd          = -1;
  int     res         = -1;
  void*   ptr         = (void*)NULL;
  size_t  total_size  = 0;
  size_t  offset      = 0;
  trigram_map header  = NULL;

  // compute storage space required
  total_size += round_to_page(sizeof(trigram_map_t));

  for (int k = 0; k < TRIGRAM_COUNT; ++k) {
    total_size += round_to_page(get_map_size(haystack, k));
  }

  // open and map file
  fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0644);
  assert(fd >= 0);

  res = ftruncate(fd, total_size);
  assert(res >= 0);

  ptr = mmap(NULL, total_size, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
  assert(ptr != NULL);

  // flush data
  memset(ptr, 0x00, total_size);

  // copy header
  memcpy(ptr, (void*)haystack, sizeof(trigram_map_t));
  offset += round_to_page(sizeof(trigram_map_t));
  header = (trigram_map)ptr;

  // copy each map, set offset in header
  for (int k = 0; k < TRIGRAM_COUNT; ++k) {
    size_t block_size = get_map_size(haystack, k);

    if (block_size > 0) {
      memcpy(ptr+offset, haystack->map[k].entries, block_size);

      header->map[k].entries        = NULL;
      header->map[k].entries_offset = offset;

      offset += round_to_page(block_size);
    } else {
      header->map[k].entries        = NULL;
      header->map[k].entries_offset = 0;
    }
  }

  res = munmap(ptr, total_size);
  assert(res >= 0);

  res = close(fd);
  assert(res >= 0);

  return 0;
}

/******************************************************************************/

int blurrily_storage_put(trigram_map haystack, const char* needle, uint32_t reference, uint32_t weight)
{
  int        nb_trigrams  = -1;
  int        length       = strlen(needle);
  trigram_t* trigrams     = (trigram_t*)NULL;

  trigrams = (trigram_t*)malloc((length+1) * sizeof(trigram_t));
  nb_trigrams = blurrily_tokeniser_parse_string(needle, trigrams);

  if (weight <= 0) weight = length;

  for (int k = 0; k < nb_trigrams; ++k) {
    trigram_t          t       = trigrams[k];
    trigram_entries_t* map     = &haystack->map[t];
    trigram_entry_t    entry   = { reference, weight };

    assert(t < TRIGRAM_COUNT);
    assert(map-> used <= map-> buckets);

    // allocate more space as needed (exponential growth)
    if (map->buckets == 0) {
      LOG("- alloc for %d\n", t);
      size_t bytes = -1;

      map->buckets = TRIGRAM_ENTRIES_START_SIZE;
      bytes        = map->buckets * sizeof(trigram_entry_t);
      map->entries = (trigram_entry_t*) malloc(bytes);
      memset(map->entries, 0x00, bytes);
    }
    if (map->used == map->buckets) {
      LOG("- realloc for %d\n", t);
      uint32_t new_buckets = map->buckets * 4/3;
      trigram_entry_t* new_entries = NULL;

      // copy old data, free old pointer, zero extra space
      new_entries = malloc(new_buckets * sizeof(trigram_entry_t));
      assert(new_entries != NULL);
      memcpy(new_entries, map->entries, map->buckets * sizeof(trigram_entry_t));
      free(map->entries);
      memset(new_entries + map->buckets, 0x00, (new_buckets - map->buckets) * sizeof(trigram_entry_t));
      // swap fields
      map->buckets = new_buckets;
      map->entries = new_entries;
    }
    map->entries[map->used] = entry;
    
    map->used++;
    haystack->total_entries++;
    LOG("- total %d entries\n", haystack->total_entries);
  }

  free((void*)trigrams);
  return 0;
}

/******************************************************************************/

int blurrily_storage_find(trigram_map haystack, const char* needle, uint16_t limit, trigram_result results)
{
  return 0;
}
