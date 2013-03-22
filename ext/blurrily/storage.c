#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <limits.h>

#include "storage.h"

#include "log.h"

/******************************************************************************/

#define PAGE_SIZE                   4096
#define TRIGRAM_COUNT               (TRIGRAM_BASE * TRIGRAM_BASE * TRIGRAM_BASE)
#define TRIGRAM_ENTRIES_START_SIZE  PAGE_SIZE/8

/******************************************************************************/

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
  uint8_t          dirty;           // not optimised (presorted) yet

  trigram_entry_t* entries;         // set when the structure is in memory
  size_t           entries_offset;  // set when the structure is on disk
};
typedef struct trigram_entries_t trigram_entries_t;


// hash map of all possible trigrams to collection of entries
// there are 28^3 = 19,683 possible trigrams
struct trigram_map_t
{
  char              magic[6]; // the string "trigra"
  uint8_t           big_endian;
  uint8_t           pointer_size;

  uint32_t          total_entries;
  uint32_t          mapped_size;
  
  trigram_entries_t map[TRIGRAM_COUNT]; // this whole structure is ~500KB
};
typedef struct trigram_map_t trigram_map_t;

/******************************************************************************/

// 1 if big endian 0 otherwise
static uint8_t get_big_endian()
{
  uint32_t magic = 0xAA0000BB;
  uint8_t  head  = *((uint8_t*) &magic);

  return (head == 0xBB) ? 1 : 0;
}

/******************************************************************************/

// 4  or 8 (bytes)
static uint8_t get_pointer_size()
{
  return (uint8_t) sizeof(void*);
}

/******************************************************************************/

static int compare_entries(const void* left_p, const void* right_p)
{
  trigram_entry_t* left  = (trigram_entry_t*)left_p;
  trigram_entry_t* right = (trigram_entry_t*)right_p;
  return (int)left->reference - (int)right->reference;
}

// compares matches on #matches (descending) then weight (ascending)
static int compare_matches(const void* left_p, const void* right_p)
{
  trigram_match_t* left  = (trigram_match_t*)left_p;
  trigram_match_t* right = (trigram_match_t*)right_p;
  // int delta = (int)left->matches - (int)right->matches;
  int delta = (int)right->matches - (int)left->matches;

  return (delta != 0) ? delta : ((int)left->weight - (int)right->weight);

}

/******************************************************************************/

static void sort_map_if_dirty(trigram_entries_t* map)
{ 
  int res = -1;
  if (! map->dirty) return;

  res = mergesort(map->entries, map->used, sizeof(trigram_entry_t), &compare_entries);
  assert(res >= 0);
  map->dirty = 0;
}

/******************************************************************************/

int blurrily_storage_new(trigram_map* haystack_ptr)
{
  trigram_map         haystack = (trigram_map)NULL;
  trigram_entries_t*  ptr      = NULL;
  int                 k        = 0;

  fprintf(stderr, "blurrily_storage_new\n");
  haystack = (trigram_map) malloc(sizeof(trigram_map_t));

  memset(haystack, 0x00, sizeof(trigram_map_t));

  memcpy(haystack->magic, "trigra", 6);
  haystack->big_endian   = get_big_endian();
  haystack->pointer_size = get_pointer_size();

  haystack->mapped_size = 0; // not mapped, as we just created it in memory
  haystack->total_entries = 0;
  for(k = 0, ptr = haystack->map ; k < TRIGRAM_COUNT ; ++k, ++ptr) {
    ptr->buckets = 0;
    ptr->used    = 0;
    ptr->dirty   = 0;
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
  int                 res      = -1;

  fprintf(stderr, "blurrily_storage_close\n");

  if (haystack->mapped_size) {
    res = munmap(haystack, haystack->mapped_size);
    assert(res >= 0);

  } else {
    trigram_entries_t*  ptr = haystack->map;
    for(int k = 0 ; k < TRIGRAM_COUNT ; ++k) {
      free(ptr->entries);
      ++ptr;
    }
    free(haystack);
  }

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
  char    path_tmp[PATH_MAX];

  // path for temporary file
  snprintf(path_tmp, PATH_MAX, "%s.tmp", path);

  // compute storage space required
  total_size += round_to_page(sizeof(trigram_map_t));

  for (int k = 0; k < TRIGRAM_COUNT; ++k) {
    total_size += round_to_page(get_map_size(haystack, k));
  }

  // open and map file
  fd = open(path_tmp, O_RDWR | O_CREAT | O_TRUNC, 0644);
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
    sort_map_if_dirty(haystack->map + k);

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

  // commit by renaming the file
  res = rename(path_tmp, path);
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
    map->dirty = 1;
    haystack->total_entries++;
  }

  free((void*)trigrams);
  return 0;
}

/******************************************************************************/

int blurrily_storage_find(trigram_map haystack, const char* needle, uint16_t limit, trigram_match results)
{
  int              nb_trigrams = -1;
  int              length      = strlen(needle);
  trigram_t*       trigrams    = (trigram_t*)NULL;
  size_t           nb_entries  = 0;
  trigram_entry_t* entries     = NULL;
  trigram_entry_t* entry_ptr   = NULL;
  size_t           nb_matches  = 0;
  trigram_match_t* matches     = NULL;
  trigram_match_t* match_ptr   = NULL;
  uint32_t         last_ref    = (uint32_t)-1;
  int              nb_results  = -1;

  trigrams = (trigram_t*)malloc((length+1) * sizeof(trigram_t));
  nb_trigrams = blurrily_tokeniser_parse_string(needle, trigrams);

  LOG("%d trigrams in '%s'\n", nb_trigrams, needle);

  // measure size required for sorting
  for (int k = 0; k < nb_trigrams; ++k) {
    trigram_t t = trigrams[k];
    nb_entries += haystack->map[t].used;
  }

  // allocate sorting memory
  entries = (trigram_entry_t*) malloc(nb_entries * sizeof(trigram_entry_t));
  assert(entries != NULL);
  LOG("allocated space for %zd trigrams entries\n", nb_entries);

  // copy data for sorting
  entry_ptr = entries;
  for (int k = 0; k < nb_trigrams; ++k) {
    trigram_t t       = trigrams[k];
    size_t    buckets = haystack->map[t].used;

    sort_map_if_dirty(haystack->map + t);
    memcpy(entry_ptr, haystack->map[t].entries, buckets * sizeof(trigram_entry_t));
    entry_ptr += buckets;
  }

  // sort data
  mergesort(entries, nb_entries, sizeof(trigram_entry_t), &compare_entries);
  LOG("sorting entries\n");

  // count distinct matches
  entry_ptr = entries;
  for (int k = 0; k < nb_entries; ++k) {
    if (entry_ptr->reference != last_ref) {
      last_ref = entry_ptr->reference;
      ++nb_matches;
    }
    ++entry_ptr;    
  }
  LOG("total %zd distinct matches\n", nb_matches);

  // allocate maches result
  matches = (trigram_match_t*) calloc(nb_matches, sizeof(trigram_match_t));
  assert(matches != NULL);

  // reduction, counting matches per reference
  entry_ptr = entries;
  match_ptr = matches;
  match_ptr->reference = entry_ptr->reference; // setup the first match to
  match_ptr->weight    = entry_ptr->weight;    // simplify the loop
  for (int k = 0; k < nb_entries; ++k) {
    if (entry_ptr->reference != match_ptr->reference) {
      ++match_ptr;
      match_ptr->reference = entry_ptr->reference;
      match_ptr->weight    = entry_ptr->weight;
      match_ptr->matches   = 1;
    } else {
      match_ptr->matches  += 1;
    }
    ++entry_ptr;    
  }

  // sort by weight (qsort)
  qsort(matches, nb_matches, sizeof(trigram_match_t), &compare_matches);

  // output results
  nb_results = (limit < nb_matches) ? limit : nb_matches;
  for (int k = 0; k < nb_results; ++k) {
    results[k] = matches[k];
    LOG("match %d: reference %d, matchiness %d, weight %d\n", k, matches[k].reference, matches[k].matches, matches[k].weight);
  }

  free(entries);
  free(matches);
  free(trigrams);
  return nb_results;
}
