// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/memory_manager_internal.h"

#include <stdlib.h>

namespace jxl {

void* MemoryManagerDefaultAlloc(void* opaque, size_t size) {
  return malloc(size);
}

void MemoryManagerDefaultFree(void* opaque, void* address) { free(address); }

}  // namespace jxl
