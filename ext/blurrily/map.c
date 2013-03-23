#include <ruby.h>
#include <assert.h>
#include "storage.h"
#include "blurrily.h"

/******************************************************************************/

static void blurrily_free(void* haystack)
{
  int res = -1;

  res = blurrily_storage_close((trigram_map*) &haystack);
  assert(res >= 0);
}

/******************************************************************************/

static VALUE blurrily_new(VALUE class) {
  VALUE       wrapper  = Qnil;
  trigram_map haystack = (trigram_map)NULL;
  int         res      = -1;

  res = blurrily_storage_new(&haystack);
  assert(res >= 0);

  wrapper = Data_Wrap_Struct(class, 0, blurrily_free, (void*)haystack);
  rb_obj_call_init(wrapper, 0, NULL);
  return wrapper;
}

/******************************************************************************/

static VALUE blurrily_load(VALUE class, VALUE rb_path) {
  char*       path     = StringValuePtr(rb_path);
  VALUE       wrapper  = Qnil;
  trigram_map haystack = (trigram_map)NULL;
  int         res      = -1;

  res = blurrily_storage_load(&haystack, path);
  assert(res >= 0);

  wrapper = Data_Wrap_Struct(class, 0, blurrily_free, (void*)haystack);
  rb_obj_call_init(wrapper, 0, NULL);
  return wrapper;
}

/******************************************************************************/

static VALUE blurrily_initialize(VALUE UNUSED(self)) {
  return Qtrue;
}

/******************************************************************************/

static VALUE blurrily_put(VALUE self, VALUE rb_needle, VALUE rb_reference, VALUE rb_weight) {
  trigram_map  haystack  = (trigram_map)NULL;
  int          res       = -1;
  char*        needle    = StringValuePtr(rb_needle);
  uint32_t     reference = NUM2UINT(rb_reference);
  uint32_t     weight    = NUM2UINT(rb_weight);

  Data_Get_Struct(self, struct trigram_map_t, haystack);

  res = blurrily_storage_put(haystack, needle, reference, weight);
  assert(res >= 0);

  return Qnil;
}

/******************************************************************************/

static VALUE blurrily_delete(VALUE self, VALUE rb_reference) {
  trigram_map  haystack  = (trigram_map)NULL;
  uint32_t     reference = NUM2UINT(rb_reference);
  int          res       = -1;

  Data_Get_Struct(self, struct trigram_map_t, haystack);

  res = blurrily_storage_delete(haystack, reference);
  assert(res >= 0);

  return INT2NUM(res);
}

/******************************************************************************/

static VALUE blurrily_save(VALUE self, VALUE rb_path) {
  trigram_map  haystack  = (trigram_map)NULL;
  int          res       = -1;
  const char*  path      = StringValuePtr(rb_path);

  Data_Get_Struct(self, struct trigram_map_t, haystack);

  res = blurrily_storage_save(haystack, path);
  assert(res >= 0);

  return Qnil;
}

/******************************************************************************/

static VALUE blurrily_find(VALUE self, VALUE rb_needle, VALUE rb_limit) {
  trigram_map   haystack   = (trigram_map)NULL;
  int           res        = -1;
  const char*   needle     = StringValuePtr(rb_needle);
  int           limit      = NUM2UINT(rb_limit);
  trigram_match matches    = NULL;
  VALUE         rb_matches = Qnil;

  if (limit <= 0) { limit = 10 ; }
  matches = (trigram_match) malloc(limit * sizeof(trigram_match_t));

  Data_Get_Struct(self, struct trigram_map_t, haystack);

  res = blurrily_storage_find(haystack, needle, limit, matches);
  assert(res >= 0);

  // wrap the matches into a Ruby array
  rb_matches = rb_ary_new();
  for (int k = 0; k < res; ++k) {
    VALUE rb_match = rb_ary_new();
    rb_ary_push(rb_match, rb_uint_new(matches[k].reference));
    rb_ary_push(rb_match, rb_uint_new(matches[k].matches));
    rb_ary_push(rb_match, rb_uint_new(matches[k].weight));
    rb_ary_push(rb_matches, rb_match);
  }
  return rb_matches;
}

/******************************************************************************/

void Init_map(void) {
  /* assume we haven't yet defined blurrily */
  VALUE module = rb_define_module("Blurrily");
  assert(module != Qnil);

  VALUE klass = rb_define_class_under(module, "Map", rb_cObject);
  assert(klass != Qnil);

  rb_define_singleton_method(klass, "new",  blurrily_new,  0);
  rb_define_singleton_method(klass, "load", blurrily_load, 1);

  rb_define_method(klass, "initialize", blurrily_initialize, 0);
  rb_define_method(klass, "put",        blurrily_put,        3);
  rb_define_method(klass, "delete",     blurrily_delete,     1);
  rb_define_method(klass, "save",       blurrily_save,       1);
  rb_define_method(klass, "find",       blurrily_find,       2);
  return;
}
