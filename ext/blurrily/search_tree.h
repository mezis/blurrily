/*

  search_tree.h --

  List of all references that's fast to query for existence.

*/
#include <inttypes.h>


typedef struct blurrily_refs_t blurrily_refs_t;


/* Allocate a search tree */
int blurrily_refs_new(blurrily_refs_t** refs_ptr);

/* Destroy a search tree */
void blurrily_refs_free(blurrily_refs_t** refs_ptr);

/* Mark with Ruby's GC */
void blurrily_refs_mark(blurrily_refs_t* refs);

/* Add a reference */
void blurrily_refs_add(blurrily_refs_t* refs, uuid_t ref);

/* Remove a reference */
void blurrily_refs_remove(blurrily_refs_t* refs, uuid_t ref);

/* Test for a reference (1 = present, 0 = absent) */
int blurrily_refs_test(blurrily_refs_t* refs, uuid_t ref);
