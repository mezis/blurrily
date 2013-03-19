#include <ruby.h>
#include <assert.h>
#include "storage.h"

/******************************************************************************/

static VALUE cWrapper = (VALUE)NULL;

/******************************************************************************/

static void blurrily_free_map(void* haystack)
{
  int res = -1;

  res = blurrily_storage_close((trigram_map*) &haystack);
  assert(res >= 0);
}

/******************************************************************************/

static VALUE blurrily_initialize(VALUE self) {
  trigram_map haystack = (trigram_map)NULL;
  int         res      = -1;
  VALUE       wrapper  = (VALUE)NULL;

  res = blurrily_storage_new(&haystack);
  assert(res >= 0);

  wrapper = Data_Wrap_Struct(cWrapper, 0, blurrily_free_map, (void*)haystack);
  rb_ivar_set(self, rb_intern("@wrapper"), wrapper);

  return Qtrue;
}

/******************************************************************************/

static VALUE blurrily_put(VALUE self, VALUE rb_needle, VALUE rb_reference, VALUE rb_weight) {
  trigram_map  haystack  = (trigram_map)NULL;
  int          res       = -1;
  VALUE        wrapper   = (VALUE)NULL;
  char*        needle    = StringValuePtr(rb_needle);
  uint32_t     reference = NUM2UINT(rb_reference);
  uint32_t     weight    = NUM2UINT(rb_weight);

  wrapper = rb_ivar_get(self, rb_intern("@wrapper"));
  Data_Get_Struct(wrapper, struct trigram_map_t, haystack);

  res = blurrily_storage_put(haystack, needle, reference, weight);
  assert(res >= 0);

  return Qnil;
}

/******************************************************************************/

static VALUE blurrily_save(VALUE self, VALUE rb_path) {
  trigram_map  haystack  = (trigram_map)NULL;
  int          res       = -1;
  VALUE        wrapper   = (VALUE)NULL;
  const char*  path      = StringValuePtr(rb_path);

  wrapper = rb_ivar_get(self, rb_intern("@wrapper"));
  Data_Get_Struct(wrapper, struct trigram_map_t, haystack);

  res = blurrily_storage_save(haystack, path);
  assert(res >= 0);

  return Qnil;
}

/******************************************************************************/

void Init_blurrily(void) {
  /* assume we haven't yet defined blurrily */
  VALUE module = rb_define_module("Blurrily");
  assert(module != (VALUE)NULL);

  VALUE klass = rb_define_class_under(module, "Map", rb_cObject);
  assert(klass != (VALUE)NULL);

  cWrapper = rb_define_class_under(module, "Wrapper", rb_cObject);
  assert(cWrapper != (VALUE)NULL);

  rb_define_method(klass, "initialize", blurrily_initialize, 0);
  rb_define_method(klass, "put",        blurrily_put,        3);
  rb_define_method(klass, "save",       blurrily_save,       1);
  return;
}
