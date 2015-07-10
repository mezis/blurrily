#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/errno.h>
#include <unistd.h>
#include <sys/stat.h>
#include <uuid/uuid.h>

#ifdef PLATFORM_LINUX
  #include <linux/limits.h>
  #define MERGESORT fake_mergesort
#else
  #include <limits.h>
  #define MERGESORT mergesort
#endif

#ifndef PATH_MAX
  /* safe default ... */
  #define PATH_MAX 1024
#endif

#include "storage.h"
#include "search_tree.h"

/******************************************************************************/

#define PAGE_SIZE                   4096
#define TRIGRAM_COUNT               (TRIGRAM_BASE * TRIGRAM_BASE * TRIGRAM_BASE)
#define TRIGRAM_ENTRIES_START_SIZE  PAGE_SIZE/sizeof(trigram_entry_t)

/******************************************************************************/

/* one trigram entry -- client reference and sorting weight */
struct BR_PACKED_STRUCT trigram_entry_t
{
  uuid_t  reference;
  uint32_t weight;
};
typedef struct trigram_entry_t trigram_entry_t;


/* collection of entries for a given trigram */
/* <entries> points to an array of <buckets> entries */
/* of which <used> are filled */
struct BR_PACKED_STRUCT trigram_entries_t
{
  uint32_t         buckets;
  uint32_t         used;

  trigram_entry_t* entries;         /* set when the structure is in memory */
  off_t            entries_offset;  /* set when the structure is on disk */

  uint8_t          dirty;           /* not optimised (presorted) yet */
};
typedef struct trigram_entries_t trigram_entries_t;


/* hash map of all possible trigrams to collection of entries */
/* there are 28^3 = 19,683 possible trigrams */
struct BR_PACKED_STRUCT trigram_map_t
{
  char              magic[6];           /* the string "trigra" */
  uint8_t           big_endian;
  uint8_t           pointer_size;

  uint32_t          total_references;
  uint32_t          total_trigrams;
  size_t            mapped_size;        /* when mapped from disk, the number of bytes mapped */
  blurrily_refs_t*  refs;

  trigram_entries_t map[TRIGRAM_COUNT]; /* this whole structure is ~500KB */
};
typedef struct trigram_map_t trigram_map_t;

/******************************************************************************/

#ifdef PLATFORM_LINUX
/* fake version of mergesort(3) implemented with qsort(3) as Linux lacks */
/* the specific variants */
static int fake_mergesort(void *base, size_t nel, size_t width, int (*compar)(const void *, const void *))
{
  qsort(base, nel, width, compar);
  return 0;
}
#endif

/******************************************************************************/

#define SMALLOC(_NELEM,_TYPE) (_TYPE*) smalloc(_NELEM, sizeof(_TYPE))

static void* smalloc(size_t nelem, size_t length)
{
  void* result = malloc(nelem * length);
  if (result) memset(result, 0xAA, nelem * length);
  return result;
}

/******************************************************************************/

/* 1 -> little endian, 2 -> big endian */
static uint8_t get_big_endian()
{
  uint32_t magic = 0xAA0000BB;
  uint8_t  head  = *((uint8_t*) &magic);

  return (head == 0xBB) ? 1 : 2;
}

/******************************************************************************/

/* 4  or 8 (bytes) */
static uint8_t get_pointer_size()
{
  return (uint8_t) sizeof(void*);
}

/******************************************************************************/

static int compare_entries(const void* left_p, const void* right_p)
{
  trigram_entry_t* left  = (trigram_entry_t*)left_p;
  trigram_entry_t* right = (trigram_entry_t*)right_p;
  return uuid_compare(left->reference, right->reference);
}

/* compares matches on #matches (descending) then weight (ascending) */
static int compare_matches(const void* left_p, const void* right_p)
{
  trigram_match_t* left  = (trigram_match_t*)left_p;
  trigram_match_t* right = (trigram_match_t*)right_p;
  /* int delta = (int)left->matches - (int)right->matches; */
  int delta = (int)right->matches - (int)left->matches;

  return (delta != 0) ? delta : ((int)left->weight - (int)right->weight);

}

/******************************************************************************/

static void sort_map_if_dirty(trigram_entries_t* map)
{
  int res = -1;
  if (! map->dirty) return;

  res = MERGESORT(map->entries, map->used, sizeof(trigram_entry_t), &compare_entries);
  assert(res >= 0);
  map->dirty = 0;
}

/******************************************************************************/

static size_t round_to_page(size_t value)
{
  if (value % PAGE_SIZE == 0) return value;
  return (value / PAGE_SIZE + 1) * PAGE_SIZE;
}

/******************************************************************************/

static size_t get_map_size(trigram_map haystack, int index)
{
  return haystack->map[index].buckets * sizeof(trigram_entry_t);
}

/******************************************************************************/

static void free_if(void* ptr)
{
  if (ptr == NULL) return;
  free(ptr);
  return;
}

/******************************************************************************/

int blurrily_storage_new(trigram_map* haystack_ptr)
{
  trigram_map         haystack = (trigram_map)NULL;
  trigram_entries_t*  ptr      = NULL;
  int                 k        = 0;

  LOG("blurrily_storage_new\n");
  haystack = SMALLOC(1, trigram_map_t);
  if (haystack == NULL) return -1;

  memcpy(haystack->magic, "trigra", 6);
  haystack->big_endian   = get_big_endian();
  haystack->pointer_size = get_pointer_size();

  haystack->mapped_size      = 0; /* not mapped, as we just created it in memory */
  haystack->total_references = 0;
  haystack->total_trigrams   = 0;
  haystack->refs             = NULL;
  for(k = 0, ptr = haystack->map ; k < TRIGRAM_COUNT ; ++k, ++ptr) {
    ptr->buckets = 0;
    ptr->used    = 0;
    ptr->dirty   = 0;
    ptr->entries = (trigram_entry_t*)NULL;
    ptr->entries_offset = 0;
  }

  *haystack_ptr = haystack;
  return 0;
}

/******************************************************************************/

int blurrily_storage_load(trigram_map* haystack, const char* path)
{
  int         fd          = -1;
  int         res         = -1;
  trigram_map header      = NULL;
  uint8_t*    origin      = NULL;
  struct stat metadata;

  /* open and map file */
  res = fd = open(path, O_RDONLY);
  if (res < 0) goto cleanup;

  res = fstat(fd, &metadata);
  if (res < 0) goto cleanup;

  /* check this file is at least lng enough to have a header */
  if (metadata.st_size < (off_t) sizeof(trigram_map_t)) {
    errno = EPROTO;
    res = -1;
    goto cleanup;
  }

  header = (trigram_map) mmap(NULL, metadata.st_size, PROT_READ|PROT_WRITE, MAP_PRIVATE, fd, 0);
  if (header == MAP_FAILED) {
    res = -1;
    header = NULL;
    goto cleanup;
  }

  /* fd not needed once mapping established */
  res = close(fd);
  if (res < 0) goto cleanup;
  fd = -1;

  /* check magic */
  res = memcmp(header->magic, "trigra", 6);
  if (res != 0 || header->big_endian != get_big_endian() || header->pointer_size != get_pointer_size()) {
    errno = EPROTO;
    res = -1;
    goto cleanup;
  }

  /* fix header data */
  header->mapped_size = metadata.st_size;
  origin = (uint8_t*)header;
  for (int k = 0; k < TRIGRAM_COUNT; ++k) {
    trigram_entries_t* map = header->map + k;
    if (map->entries_offset == 0) continue;
    map->entries = (trigram_entry_t*) (origin + map->entries_offset);
  }
  *haystack = header;

cleanup:
  if (fd > 0) (void) close(fd);
  if (res < 0 && header != NULL) (void) munmap(header, metadata.st_size);
  return res;
}

/******************************************************************************/

int blurrily_storage_close(trigram_map* haystack_ptr)
{
  trigram_map         haystack = *haystack_ptr;
  int                 res      = 0;
  trigram_entries_t*  ptr = haystack->map;

  LOG("blurrily_storage_close\n");

  for(int k = 0 ; k < TRIGRAM_COUNT ; ++k) {
    if (ptr->entries_offset == 0) free(ptr->entries);
    ++ptr;
  }

  if (haystack->refs) blurrily_refs_free(&haystack->refs);

  if (haystack->mapped_size) {
    res = munmap(haystack, haystack->mapped_size);
    if (res < 0) goto cleanup;
  } else {
    free(haystack);
  }

cleanup:
  *haystack_ptr = NULL;
  return res;
}

/******************************************************************************/

int blurrily_storage_save(trigram_map haystack, const char* path)
{
  int         fd          = -1;
  int         res         = 0;
  uint8_t*    ptr         = (uint8_t*)NULL;
  size_t      total_size  = 0;
  size_t      offset      = 0;
  trigram_map header      = NULL;
  char        path_tmp[PATH_MAX];

  /* cleanup maps in memory */
  for (int k = 0; k < TRIGRAM_COUNT; ++k) {
    sort_map_if_dirty(haystack->map + k);
  }

  /* path for temporary file */
  snprintf(path_tmp, PATH_MAX, "%s.tmp.%ld", path, random());

  /* compute storage space required */
  total_size += round_to_page(sizeof(trigram_map_t));

  for (int k = 0; k < TRIGRAM_COUNT; ++k) {
    total_size += round_to_page(get_map_size(haystack, k));
  }

  /* open and map file */
  fd = open(path_tmp, O_RDWR | O_CREAT | O_TRUNC, 0644);
  if (fd < 0) goto cleanup;

  res = ftruncate(fd, total_size);
  if (res < 0) goto cleanup;

  ptr = mmap(NULL, total_size, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
  if (ptr == MAP_FAILED) { res = -1 ; goto cleanup ; }

  (void) close(fd);
  fd = -1;

  /* flush data */
  memset(ptr, 0xFF, total_size);

  /* copy header & clean copy */
  memcpy(ptr, (void*)haystack, sizeof(trigram_map_t));
  offset += round_to_page(sizeof(trigram_map_t));
  header = (trigram_map)ptr;

  header->mapped_size = 0;
  header->refs        = NULL;

  /* copy each map, set offset in header */
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
  assert(offset == total_size);

cleanup:
  if (ptr != NULL && total_size > 0) {
    res = munmap(ptr, total_size);
  }

  /* commit by renaming the file */
  if (res >= 0 && path) {
    res = rename(path_tmp, path);
  }

  return res;
}

/******************************************************************************/

void add_all_refs(trigram_map haystack)
{
  assert(haystack->refs != NULL);

  for (int k = 0; k < TRIGRAM_COUNT; ++k) {
    trigram_entries_t* map = haystack->map + k;
    trigram_entry_t*   ptr = map->entries;
    assert(map->used <= map->buckets);
    for (uint32_t j = 0; j < map->used; ++j, ++ptr) {
      uuid_t ref;
      uuid_copy(ref, ptr->reference);

      blurrily_refs_add(haystack->refs, ref);
    }
  }
}

/******************************************************************************/

int blurrily_storage_put(trigram_map haystack, const char* needle, uuid_t reference, uint32_t weight)
{
  int        nb_trigrams  = -1;
  size_t     length       = strlen(needle);
  trigram_t* trigrams     = (trigram_t*)NULL;

  if (!haystack->refs) {
    blurrily_refs_new(&haystack->refs);
    add_all_refs(haystack);
  }
  if (blurrily_refs_test(haystack->refs, reference)) return 0;
  if (weight <= 0) weight = (uint32_t) length;

  trigrams = SMALLOC(length+1, trigram_t);
  nb_trigrams = blurrily_tokeniser_parse_string(needle, trigrams);

  for (int k = 0; k < nb_trigrams; ++k) {
    trigram_t          t       = trigrams[k];
    trigram_entries_t* map     = &haystack->map[t];
    trigram_entry_t    entry;
    entry.weight = weight;
    uuid_copy(entry.reference, reference);

    assert(t < TRIGRAM_COUNT);
    assert(map-> used <= map-> buckets);

    /* allocate more space as needed (exponential growth) */
    if (map->buckets == 0) {
      LOG("- alloc for %d\n", t);

      map->buckets = TRIGRAM_ENTRIES_START_SIZE;
      map->entries = SMALLOC(map->buckets, trigram_entry_t);
    }
    else if (map->used == map->buckets) {
      uint32_t         new_buckets = map->buckets * 4/3;
      trigram_entry_t* new_entries = NULL;
      LOG("- realloc for %d\n", t);

      /* copy old data, free old pointer, zero extra space */
      new_entries = SMALLOC(new_buckets, trigram_entry_t);
      assert(new_entries != NULL);
      memcpy(new_entries, map->entries, map->buckets * sizeof(trigram_entry_t));
      /* scribble the rest of the map*/
      // memset(new_entries + map->buckets, 0xFF, (new_buckets - map->buckets) * sizeof(trigram_entry_t));

      #ifndef NDEBUG
        /* scribble old data */
        memset(map->entries, 0xFF, map->buckets * sizeof(trigram_entry_t));
      #endif

      if (map->entries_offset) {
        /* old data was on disk, just mark it as no longer on disk */
        map->entries_offset = 0;
      } else {
        /* free old data */
        free(map->entries);
      }

      /* swap fields */
      map->buckets = new_buckets;
      map->entries = new_entries;
    }

    /* insert new entry */
    assert(map->used < map->buckets);
    map->entries[map->used] = entry;
    map->used += 1;
    map->dirty = 1;
  }
  haystack->total_trigrams   += nb_trigrams;
  haystack->total_references += 1;

  blurrily_refs_add(haystack->refs, reference);

  free((void*)trigrams);
  return nb_trigrams;
}

/******************************************************************************/

int blurrily_storage_find(trigram_map haystack, const char* needle, uint16_t limit, trigram_match results)
{
  int              nb_trigrams = -1;
  size_t           length      = strlen(needle);
  trigram_t*       trigrams    = (trigram_t*)NULL;
  int              nb_entries  = -1;
  trigram_entry_t* entries     = NULL;
  trigram_entry_t* entry_ptr   = NULL;
  int              nb_matches  = -1;
  trigram_match_t* matches     = NULL;
  trigram_match_t* match_ptr   = NULL;
  uuid_t           last_ref;
  int              nb_results  = 0;

  trigrams = SMALLOC(length+1, trigram_t);
  nb_trigrams = blurrily_tokeniser_parse_string(needle, trigrams);
  if (nb_trigrams == 0) goto cleanup;
  assert(nb_trigrams > 0);

  LOG("%d trigrams in '%s'\n", nb_trigrams, needle);

  /* measure size required for sorting */
  nb_entries = 0;
  for (int k = 0; k < nb_trigrams; ++k) {
    trigram_t t = trigrams[k];
    nb_entries += haystack->map[t].used;
  }
  if (nb_entries == 0) goto cleanup;

  /* allocate sorting memory */
  entries = SMALLOC(nb_entries, trigram_entry_t);
  assert(entries != NULL);
  LOG("allocated space for %zd trigrams entries\n", nb_entries);

  /* copy data for sorting */
  entry_ptr = entries;
  for (int k = 0; k < nb_trigrams; ++k) {
    trigram_t t       = trigrams[k];
    size_t    buckets = haystack->map[t].used;

    sort_map_if_dirty(haystack->map + t);
    memcpy(entry_ptr, haystack->map[t].entries, buckets * sizeof(trigram_entry_t));
    entry_ptr += buckets;
  }
  assert(entry_ptr == entries + nb_entries);

  /* sort data */
  MERGESORT(entries, nb_entries, sizeof(trigram_entry_t), &compare_entries);
  LOG("sorting entries\n");

  /* count distinct matches */
  entry_ptr  = entries;
  uuid_clear(last_ref);
  nb_matches = 0;
  for (int k = 0; k < nb_entries; ++k) {
    if (uuid_compare(entry_ptr->reference, last_ref) != 0) {
      uuid_copy(last_ref, entry_ptr->reference);
      ++nb_matches;
    }
    ++entry_ptr;
  }
  assert(entry_ptr == entries + nb_entries);
  LOG("total %zd distinct matches\n", nb_matches);

  /* allocate matches result */
  matches = SMALLOC(nb_matches, trigram_match_t);
  assert(matches != NULL);

  /* reduction, counting matches per reference */
  entry_ptr = entries;
  match_ptr = matches;
  match_ptr->matches   = 0;
  uuid_copy(match_ptr->reference, entry_ptr->reference); /* setup the first match to */
  match_ptr->weight    = entry_ptr->weight;    /* simplify the loop */


  for (int k = 0; k < nb_entries; ++k) {
    if (uuid_compare(entry_ptr->reference, match_ptr->reference) != 0) {
      ++match_ptr;
      uuid_copy(match_ptr->reference, entry_ptr->reference);
      match_ptr->weight    = entry_ptr->weight;
      match_ptr->matches   = 1;
    } else {
      match_ptr->matches  += 1;
    }
    assert((int) match_ptr->matches <= nb_trigrams);
    ++entry_ptr;
  }
  assert(match_ptr == matches + nb_matches - 1);
  assert(entry_ptr == entries + nb_entries);

  /* sort by weight (qsort) */
  qsort(matches, nb_matches, sizeof(trigram_match_t), &compare_matches);

  /* output results */
  nb_results = (limit < nb_matches) ? limit : nb_matches;
  for (int k = 0; k < nb_results; ++k) {
    results[k] = matches[k];
    LOG("match %d: reference %d, matchiness %d, weight %d\n", k, matches[k].reference, matches[k].matches, matches[k].weight);
  }

cleanup:
  free_if(entries);
  free_if(matches);
  free_if(trigrams);
  return nb_results;
}

/******************************************************************************/

int blurrily_storage_delete(trigram_map haystack, uuid_t reference)
{
  int trigrams_deleted = 0;

  for (int k = 0; k < TRIGRAM_COUNT; ++k) {
    trigram_entries_t* map       = haystack->map + k;
    trigram_entry_t*   entry     = NULL;

    for (unsigned int j = 0; j < map->used; ++j) {
      entry = map->entries + j;
      if (uuid_compare(entry->reference, reference)!=0) continue;

      /* swap with the last entry */
      *entry = map->entries[map->used - 1];
      memset(map->entries + map->used - 1, 0xFF, sizeof(trigram_entry_t));

      map->used -= 1;

      ++trigrams_deleted;
      --j;
    }
  }
  haystack->total_trigrams -= trigrams_deleted;
  if (trigrams_deleted > 0) haystack->total_references -= 1;

  if (haystack->refs) blurrily_refs_remove(haystack->refs, reference);

  return trigrams_deleted;
}

/******************************************************************************/

int blurrily_storage_stats(trigram_map haystack, trigram_stat_t* stats)
{
  stats->references = haystack->total_references;
  stats->trigrams   = haystack->total_trigrams;
  return 0;
}

/******************************************************************************/

void blurrily_storage_mark(trigram_map haystack)
{
  if (haystack->refs) blurrily_refs_mark(haystack->refs);
  return;
}
