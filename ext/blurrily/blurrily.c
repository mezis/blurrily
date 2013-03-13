#include <ruby.h>
#include "storage.h"

/* our new native method; it just returns
 * the string "bonjour!" */
static VALUE blurrily_bonjour(VALUE self) {
  return rb_str_new2("bonjour!");
}

/* ruby calls this to load the extension */
void Init_blurrily(void) {
  /* assume we haven't yet defined blurrily */
  VALUE module = rb_define_module("Blurrily");

  /* the blurrily_bonjour function can be called
   * from ruby as "blurrily.bonjour" */
  rb_define_singleton_method(module,
      "bonjour", blurrily_bonjour, 0);
}