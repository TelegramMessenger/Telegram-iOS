// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/common.h"

#include "lib/jpegli/decode_internal.h"
#include "lib/jpegli/encode_internal.h"
#include "lib/jpegli/memory_manager.h"

void jpegli_abort(j_common_ptr cinfo) {
  if (cinfo->mem == nullptr) return;
  for (int pool_id = 0; pool_id < JPOOL_NUMPOOLS; ++pool_id) {
    if (pool_id == JPOOL_PERMANENT) continue;
    (*cinfo->mem->free_pool)(cinfo, pool_id);
  }
  if (cinfo->is_decompressor) {
    cinfo->global_state = jpegli::kDecStart;
  } else {
    cinfo->global_state = jpegli::kEncStart;
  }
}

void jpegli_destroy(j_common_ptr cinfo) {
  if (cinfo->mem == nullptr) return;
  (*cinfo->mem->self_destruct)(cinfo);
  if (cinfo->is_decompressor) {
    cinfo->global_state = jpegli::kDecNull;
    delete reinterpret_cast<j_decompress_ptr>(cinfo)->master;
  } else {
    cinfo->global_state = jpegli::kEncNull;
  }
}

JQUANT_TBL* jpegli_alloc_quant_table(j_common_ptr cinfo) {
  JQUANT_TBL* table = jpegli::Allocate<JQUANT_TBL>(cinfo, 1);
  table->sent_table = FALSE;
  return table;
}

JHUFF_TBL* jpegli_alloc_huff_table(j_common_ptr cinfo) {
  JHUFF_TBL* table = jpegli::Allocate<JHUFF_TBL>(cinfo, 1);
  table->sent_table = FALSE;
  return table;
}

int jpegli_bytes_per_sample(JpegliDataType data_type) {
  switch (data_type) {
    case JPEGLI_TYPE_UINT8:
      return 1;
    case JPEGLI_TYPE_UINT16:
      return 2;
    case JPEGLI_TYPE_FLOAT:
      return 4;
    default:
      return 0;
  }
}
