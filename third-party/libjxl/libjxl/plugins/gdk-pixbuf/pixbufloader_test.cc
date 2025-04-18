// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gdk/gdk.h>
#include <glib.h>
#include <stdlib.h>

int main(int argc, char* argv[]) {
  if (argc != 3) {
    fprintf(stderr, "Usage: %s <loaders.cache> <image.jxl>\n", argv[0]);
    return 1;
  }

  const char* loaders_cache = argv[1];
  const char* filename = argv[2];
  setenv("GDK_PIXBUF_MODULE_FILE", loaders_cache, true);

  // XDG_DATA_HOME is the path where we look for the mime cache.
  // XDG_DATA_DIRS directories are used in addition to XDG_DATA_HOME.
  setenv("XDG_DATA_HOME", ".", true);
  setenv("XDG_DATA_DIRS", "", true);

  if (!gdk_init_check(nullptr, nullptr)) {
    fprintf(stderr, "This test requires a DISPLAY\n");
    // Signals ctest that we should mark this test as skipped.
    return 254;
  }
  GError* error = nullptr;
  GdkPixbuf* pb = gdk_pixbuf_new_from_file(filename, &error);
  if (pb != nullptr) {
    g_object_unref(pb);
    return 0;
  } else {
    fprintf(stderr, "Error loading file: %s\n", filename);
    g_assert_no_error(error);
    return 1;
  }
}
