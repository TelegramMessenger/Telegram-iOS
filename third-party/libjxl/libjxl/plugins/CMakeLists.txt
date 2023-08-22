# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

if(NOT MSVC)
  option(JPEGXL_ENABLE_PLUGIN_GDKPIXBUF "Enable plugin for GdkPixbuf image loading library" ON)
  if(JPEGXL_ENABLE_PLUGIN_GDKPIXBUF)
    add_subdirectory(gdk-pixbuf)
  endif()
endif()

option(JPEGXL_ENABLE_PLUGIN_GIMP210 "Enable plugin for GIMP 2.10.x series" ON)
if(JPEGXL_ENABLE_PLUGIN_GIMP210)
  add_subdirectory(gimp)
endif()

option(JPEGXL_ENABLE_PLUGIN_MIME "Enable image/jxl declaration for shared-mime-info" ON)
if(JPEGXL_ENABLE_PLUGIN_MIME)
  add_subdirectory(mime)
endif()
