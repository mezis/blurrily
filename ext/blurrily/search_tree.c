#include <stdlib.h>
#include <inttypes.h>
#include "blurrily.h"
#include "ruby.h"
#include <uuid/uuid.h>

/******************************************************************************/

typedef struct blurrily_refs_t {
  VALUE hash;
} blurrily_refs_t;

/******************************************************************************/

int blurrily_refs_new(blurrily_refs_t** refs_ptr)
{
  blurrily_refs_t* refs = NULL;

  refs = (blurrily_refs_t*) malloc(sizeof(blurrily_refs_t));
  if (!refs) return -1;

  refs->hash = rb_hash_new();
  *refs_ptr = refs;
  return 0;
}

/******************************************************************************/

void blurrily_refs_mark(blurrily_refs_t* refs)
{
  rb_gc_mark(refs->hash);
  return;
}

/******************************************************************************/

void blurrily_refs_free(blurrily_refs_t** refs_ptr)
{
  blurrily_refs_t* refs = *refs_ptr;

  refs->hash = Qnil;
  free(refs);
  *refs_ptr = NULL;
  return;
}

/******************************************************************************/

void blurrily_refs_add(blurrily_refs_t* refs, uuid_t ref)
{
  char ref_str[37] = "";
  uuid_unparse(ref, ref_str);
  (void) rb_hash_aset(refs->hash, rb_str_new2(ref_str), Qtrue);
  return;
}

/******************************************************************************/

void blurrily_refs_remove(blurrily_refs_t* refs, uuid_t ref)
{
  char ref_str[37] = "";
  uuid_unparse(ref, ref_str);
  (void) rb_hash_aset(refs->hash, rb_str_new2(ref_str), Qnil);
}

/******************************************************************************/

int blurrily_refs_test(blurrily_refs_t* refs, uuid_t ref)
{
  char ref_str[37] = "";
  uuid_unparse(ref, ref_str);
  return rb_hash_aref(refs->hash, rb_str_new2(ref_str)) == Qtrue ? 1 : 0;
}
