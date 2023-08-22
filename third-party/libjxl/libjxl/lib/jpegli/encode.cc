// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/encode.h"

#include <cmath>
#include <initializer_list>
#include <vector>

#include "lib/jpegli/adaptive_quantization.h"
#include "lib/jpegli/bit_writer.h"
#include "lib/jpegli/bitstream.h"
#include "lib/jpegli/color_transform.h"
#include "lib/jpegli/downsample.h"
#include "lib/jpegli/encode_finish.h"
#include "lib/jpegli/encode_internal.h"
#include "lib/jpegli/encode_streaming.h"
#include "lib/jpegli/entropy_coding.h"
#include "lib/jpegli/error.h"
#include "lib/jpegli/huffman.h"
#include "lib/jpegli/input.h"
#include "lib/jpegli/memory_manager.h"
#include "lib/jpegli/quant.h"

namespace jpegli {

constexpr size_t kMaxBytesInMarker = 65533;

void CheckState(j_compress_ptr cinfo, int state) {
  if (cinfo->global_state != state) {
    JPEGLI_ERROR("Unexpected global state %d [expected %d]",
                 cinfo->global_state, state);
  }
}

void CheckState(j_compress_ptr cinfo, int state1, int state2) {
  if (cinfo->global_state != state1 && cinfo->global_state != state2) {
    JPEGLI_ERROR("Unexpected global state %d [expected %d or %d]",
                 cinfo->global_state, state1, state2);
  }
}

//
// Parameter setup
//

// Initialize cinfo fields that are not dependent on input image. This is shared
// between jpegli_CreateCompress() and jpegli_set_defaults()
void InitializeCompressParams(j_compress_ptr cinfo) {
  cinfo->data_precision = 8;
  cinfo->num_scans = 0;
  cinfo->scan_info = nullptr;
  cinfo->raw_data_in = FALSE;
  cinfo->arith_code = FALSE;
  cinfo->optimize_coding = FALSE;
  cinfo->CCIR601_sampling = FALSE;
  cinfo->smoothing_factor = 0;
  cinfo->dct_method = JDCT_FLOAT;
  cinfo->restart_interval = 0;
  cinfo->restart_in_rows = 0;
  cinfo->write_JFIF_header = FALSE;
  cinfo->JFIF_major_version = 1;
  cinfo->JFIF_minor_version = 1;
  cinfo->density_unit = 0;
  cinfo->X_density = 1;
  cinfo->Y_density = 1;
#if JPEG_LIB_VERSION >= 70
  cinfo->scale_num = 1;
  cinfo->scale_denom = 1;
  cinfo->do_fancy_downsampling = FALSE;
  cinfo->min_DCT_h_scaled_size = DCTSIZE;
  cinfo->min_DCT_v_scaled_size = DCTSIZE;
#endif
  cinfo->master->psnr_target = 0.0f;
  cinfo->master->psnr_tolerance = 0.01f;
  cinfo->master->min_distance = 0.1f;
  cinfo->master->max_distance = 25.0f;
}

float LinearQualityToDistance(int scale_factor) {
  scale_factor = std::min(5000, std::max(0, scale_factor));
  int quality =
      scale_factor < 100 ? 100 - scale_factor / 2 : 5000 / scale_factor;
  return jpegli_quality_to_distance(quality);
}

template <typename T>
void SetSentTableFlag(T** table_ptrs, size_t num, boolean val) {
  for (size_t i = 0; i < num; ++i) {
    if (table_ptrs[i]) table_ptrs[i]->sent_table = val;
  }
}

//
// Compressor initialization
//

struct ProgressiveScan {
  int Ss, Se, Ah, Al;
  bool interleaved;
};

void SetDefaultScanScript(j_compress_ptr cinfo) {
  int level = cinfo->master->progressive_level;
  std::vector<ProgressiveScan> progressive_mode;
  bool interleave_dc =
      (cinfo->max_h_samp_factor == 1 && cinfo->max_v_samp_factor == 1);
  if (level == 0) {
    progressive_mode.push_back({0, 63, 0, 0, true});
  } else if (level == 1) {
    progressive_mode.push_back({0, 0, 0, 0, interleave_dc});
    progressive_mode.push_back({1, 63, 0, 1, false});
    progressive_mode.push_back({1, 63, 1, 0, false});
  } else {
    progressive_mode.push_back({0, 0, 0, 0, interleave_dc});
    progressive_mode.push_back({1, 2, 0, 0, false});
    progressive_mode.push_back({3, 63, 0, 2, false});
    progressive_mode.push_back({3, 63, 2, 1, false});
    progressive_mode.push_back({3, 63, 1, 0, false});
  }

  cinfo->script_space_size = 0;
  for (const auto& scan : progressive_mode) {
    int comps = scan.interleaved ? MAX_COMPS_IN_SCAN : 1;
    cinfo->script_space_size += DivCeil(cinfo->num_components, comps);
  }
  cinfo->script_space =
      Allocate<jpeg_scan_info>(cinfo, cinfo->script_space_size);

  jpeg_scan_info* next_scan = cinfo->script_space;
  for (const auto& scan : progressive_mode) {
    int comps = scan.interleaved ? MAX_COMPS_IN_SCAN : 1;
    for (int c = 0; c < cinfo->num_components; c += comps) {
      next_scan->Ss = scan.Ss;
      next_scan->Se = scan.Se;
      next_scan->Ah = scan.Ah;
      next_scan->Al = scan.Al;
      next_scan->comps_in_scan = std::min(comps, cinfo->num_components - c);
      for (int j = 0; j < next_scan->comps_in_scan; ++j) {
        next_scan->component_index[j] = c + j;
      }
      ++next_scan;
    }
  }
  JXL_ASSERT(next_scan - cinfo->script_space == cinfo->script_space_size);
  cinfo->scan_info = cinfo->script_space;
  cinfo->num_scans = cinfo->script_space_size;
}

void ValidateScanScript(j_compress_ptr cinfo) {
  // Mask of coefficient bits defined by the scan script, for each component
  // and coefficient index.
  uint16_t comp_mask[kMaxComponents][DCTSIZE2] = {};
  static constexpr int kMaxRefinementBit = 10;

  for (int i = 0; i < cinfo->num_scans; ++i) {
    const jpeg_scan_info& si = cinfo->scan_info[i];
    if (si.comps_in_scan < 1 || si.comps_in_scan > MAX_COMPS_IN_SCAN) {
      JPEGLI_ERROR("Invalid number of components in scan %d", si.comps_in_scan);
    }
    int last_ci = -1;
    for (int j = 0; j < si.comps_in_scan; ++j) {
      int ci = si.component_index[j];
      if (ci < 0 || ci >= cinfo->num_components) {
        JPEGLI_ERROR("Invalid component index %d in scan", ci);
      } else if (ci == last_ci) {
        JPEGLI_ERROR("Duplicate component index %d in scan", ci);
      } else if (ci < last_ci) {
        JPEGLI_ERROR("Out of order component index %d in scan", ci);
      }
      last_ci = ci;
    }
    if (si.Ss < 0 || si.Se < si.Ss || si.Se >= DCTSIZE2) {
      JPEGLI_ERROR("Invalid spectral range %d .. %d in scan", si.Ss, si.Se);
    }
    if (si.Ah < 0 || si.Al < 0 || si.Al > kMaxRefinementBit) {
      JPEGLI_ERROR("Invalid refinement bits %d/%d", si.Ah, si.Al);
    }
    if (!cinfo->progressive_mode) {
      if (si.Ss != 0 || si.Se != DCTSIZE2 - 1 || si.Ah != 0 || si.Al != 0) {
        JPEGLI_ERROR("Invalid scan for sequential mode");
      }
    } else {
      if (si.Ss == 0 && si.Se != 0) {
        JPEGLI_ERROR("DC and AC together in progressive scan");
      }
    }
    if (si.Ss != 0 && si.comps_in_scan != 1) {
      JPEGLI_ERROR("Interleaved AC only scan.");
    }
    for (int j = 0; j < si.comps_in_scan; ++j) {
      int ci = si.component_index[j];
      if (si.Ss != 0 && comp_mask[ci][0] == 0) {
        JPEGLI_ERROR("AC before DC in component %d of scan", ci);
      }
      for (int k = si.Ss; k <= si.Se; ++k) {
        if (comp_mask[ci][k] == 0) {
          if (si.Ah != 0) {
            JPEGLI_ERROR("Invalid first scan refinement bit");
          }
          comp_mask[ci][k] = ((0xffff << si.Al) & 0xffff);
        } else {
          if (comp_mask[ci][k] != ((0xffff << si.Ah) & 0xffff) ||
              si.Al != si.Ah - 1) {
            JPEGLI_ERROR("Invalid refinement bit progression.");
          }
          comp_mask[ci][k] |= 1 << si.Al;
        }
      }
    }
    if (si.comps_in_scan > 1) {
      size_t mcu_size = 0;
      for (int j = 0; j < si.comps_in_scan; ++j) {
        int ci = si.component_index[j];
        jpeg_component_info* comp = &cinfo->comp_info[ci];
        mcu_size += comp->h_samp_factor * comp->v_samp_factor;
      }
      if (mcu_size > C_MAX_BLOCKS_IN_MCU) {
        JPEGLI_ERROR("MCU size too big");
      }
    }
  }
  for (int c = 0; c < cinfo->num_components; ++c) {
    for (int k = 0; k < DCTSIZE2; ++k) {
      if (comp_mask[c][k] != 0xffff) {
        JPEGLI_ERROR("Incomplete scan of component %d and frequency %d", c, k);
      }
    }
  }
}

void ProcessCompressionParams(j_compress_ptr cinfo) {
  if (cinfo->dest == nullptr) {
    JPEGLI_ERROR("Missing destination.");
  }
  if (cinfo->image_width < 1 || cinfo->image_height < 1 ||
      cinfo->input_components < 1) {
    JPEGLI_ERROR("Empty input image.");
  }
  if (cinfo->image_width > static_cast<int>(JPEG_MAX_DIMENSION) ||
      cinfo->image_height > static_cast<int>(JPEG_MAX_DIMENSION) ||
      cinfo->input_components > static_cast<int>(kMaxComponents)) {
    JPEGLI_ERROR("Input image too big.");
  }
  if (cinfo->num_components < 1 ||
      cinfo->num_components > static_cast<int>(kMaxComponents)) {
    JPEGLI_ERROR("Invalid number of components.");
  }
  if (cinfo->data_precision != kJpegPrecision) {
    JPEGLI_ERROR("Invalid data precision");
  }
  if (cinfo->arith_code) {
    JPEGLI_ERROR("Arithmetic coding is not implemented.");
  }
  if (cinfo->CCIR601_sampling) {
    JPEGLI_ERROR("CCIR601 sampling is not implemented.");
  }
  if (cinfo->restart_interval > 65535u) {
    JPEGLI_ERROR("Restart interval too big");
  }
  if (cinfo->smoothing_factor < 0 || cinfo->smoothing_factor > 100) {
    JPEGLI_ERROR("Invalid smoothing factor %d", cinfo->smoothing_factor);
  }
  jpeg_comp_master* m = cinfo->master;
  cinfo->max_h_samp_factor = cinfo->max_v_samp_factor = 1;
  for (int c = 0; c < cinfo->num_components; ++c) {
    jpeg_component_info* comp = &cinfo->comp_info[c];
    if (comp->component_index != c) {
      JPEGLI_ERROR("Invalid component index");
    }
    for (int j = 0; j < c; ++j) {
      if (cinfo->comp_info[j].component_id == comp->component_id) {
        JPEGLI_ERROR("Duplicate component id %d", comp->component_id);
      }
    }
    if (comp->h_samp_factor <= 0 || comp->v_samp_factor <= 0 ||
        comp->h_samp_factor > MAX_SAMP_FACTOR ||
        comp->v_samp_factor > MAX_SAMP_FACTOR) {
      JPEGLI_ERROR("Invalid sampling factor %d x %d", comp->h_samp_factor,
                   comp->v_samp_factor);
    }
    cinfo->max_h_samp_factor =
        std::max(comp->h_samp_factor, cinfo->max_h_samp_factor);
    cinfo->max_v_samp_factor =
        std::max(comp->v_samp_factor, cinfo->max_v_samp_factor);
  }
  if (cinfo->num_components == 1 &&
      (cinfo->max_h_samp_factor != 1 || cinfo->max_v_samp_factor != 1)) {
    JPEGLI_ERROR("Sampling is not supported for simgle component image.");
  }
  size_t iMCU_width = DCTSIZE * cinfo->max_h_samp_factor;
  size_t iMCU_height = DCTSIZE * cinfo->max_v_samp_factor;
  size_t total_iMCU_cols = DivCeil(cinfo->image_width, iMCU_width);
  cinfo->total_iMCU_rows = DivCeil(cinfo->image_height, iMCU_height);
  m->xsize_blocks = total_iMCU_cols * cinfo->max_h_samp_factor;
  m->ysize_blocks = cinfo->total_iMCU_rows * cinfo->max_v_samp_factor;

  size_t blocks_per_iMCU = 0;
  for (int c = 0; c < cinfo->num_components; ++c) {
    jpeg_component_info* comp = &cinfo->comp_info[c];
    if (cinfo->max_h_samp_factor % comp->h_samp_factor != 0 ||
        cinfo->max_v_samp_factor % comp->v_samp_factor != 0) {
      JPEGLI_ERROR("Non-integral sampling ratios are not supported.");
    }
    m->h_factor[c] = cinfo->max_h_samp_factor / comp->h_samp_factor;
    m->v_factor[c] = cinfo->max_v_samp_factor / comp->v_samp_factor;
    comp->downsampled_width = DivCeil(cinfo->image_width, m->h_factor[c]);
    comp->downsampled_height = DivCeil(cinfo->image_height, m->v_factor[c]);
    comp->width_in_blocks = DivCeil(comp->downsampled_width, DCTSIZE);
    comp->height_in_blocks = DivCeil(comp->downsampled_height, DCTSIZE);
    blocks_per_iMCU += comp->h_samp_factor * comp->v_samp_factor;
  }
  m->blocks_per_iMCU_row = total_iMCU_cols * blocks_per_iMCU;
  // Disable adaptive quantization for subsampled luma channel.
  int y_channel = cinfo->jpeg_color_space == JCS_RGB ? 1 : 0;
  jpeg_component_info* y_comp = &cinfo->comp_info[y_channel];
  if (y_comp->h_samp_factor != cinfo->max_h_samp_factor ||
      y_comp->v_samp_factor != cinfo->max_v_samp_factor) {
    m->use_adaptive_quantization = false;
  }
  if (cinfo->scan_info == nullptr) {
    SetDefaultScanScript(cinfo);
  }
  cinfo->progressive_mode =
      cinfo->scan_info->Ss != 0 || cinfo->scan_info->Se != DCTSIZE2 - 1;
  ValidateScanScript(cinfo);
  m->scan_token_info =
      Allocate<ScanTokenInfo>(cinfo, cinfo->num_scans, JPOOL_IMAGE);
  memset(m->scan_token_info, 0, cinfo->num_scans * sizeof(ScanTokenInfo));
  m->ac_ctx_offset = Allocate<uint8_t>(cinfo, cinfo->num_scans, JPOOL_IMAGE);
  size_t num_ac_contexts = 0;
  for (int i = 0; i < cinfo->num_scans; ++i) {
    const jpeg_scan_info* scan_info = &cinfo->scan_info[i];
    m->ac_ctx_offset[i] = 4 + num_ac_contexts;
    if (scan_info->Se > 0) {
      num_ac_contexts += scan_info->comps_in_scan;
    }
    if (num_ac_contexts > 252) {
      JPEGLI_ERROR("Too many AC scans in image");
    }
    ScanTokenInfo* sti = &m->scan_token_info[i];
    if (scan_info->comps_in_scan == 1) {
      int comp_idx = scan_info->component_index[0];
      jpeg_component_info* comp = &cinfo->comp_info[comp_idx];
      sti->MCUs_per_row = comp->width_in_blocks;
      sti->MCU_rows_in_scan = comp->height_in_blocks;
      sti->blocks_in_MCU = 1;
    } else {
      sti->MCUs_per_row =
          DivCeil(cinfo->image_width, DCTSIZE * cinfo->max_h_samp_factor);
      sti->MCU_rows_in_scan =
          DivCeil(cinfo->image_height, DCTSIZE * cinfo->max_v_samp_factor);
      sti->blocks_in_MCU = 0;
      for (int j = 0; j < scan_info->comps_in_scan; ++j) {
        int comp_idx = scan_info->component_index[j];
        jpeg_component_info* comp = &cinfo->comp_info[comp_idx];
        sti->blocks_in_MCU += comp->h_samp_factor * comp->v_samp_factor;
      }
    }
    size_t num_MCUs = sti->MCU_rows_in_scan * sti->MCUs_per_row;
    sti->num_blocks = num_MCUs * sti->blocks_in_MCU;
    if (cinfo->restart_in_rows <= 0) {
      sti->restart_interval = cinfo->restart_interval;
    } else {
      sti->restart_interval =
          std::min<size_t>(sti->MCUs_per_row * cinfo->restart_in_rows, 65535u);
    }
    sti->num_restarts = sti->restart_interval > 0
                            ? DivCeil(num_MCUs, sti->restart_interval)
                            : 1;
    sti->restarts = Allocate<size_t>(cinfo, sti->num_restarts, JPOOL_IMAGE);
  }
  m->num_contexts = 4 + num_ac_contexts;
}

bool IsStreamingSupported(j_compress_ptr cinfo) {
  if (cinfo->global_state == kEncWriteCoeffs) {
    return false;
  }
  // TODO(szabadka) Remove this restriction.
  if (cinfo->restart_interval > 0 || cinfo->restart_in_rows > 0) {
    return false;
  }
  if (cinfo->num_scans > 1) {
    return false;
  }
  if (cinfo->master->psnr_target > 0) {
    return false;
  }
  return true;
}

void AllocateBuffers(j_compress_ptr cinfo) {
  jpeg_comp_master* m = cinfo->master;
  memset(m->last_dc_coeff, 0, sizeof(m->last_dc_coeff));
  if (!IsStreamingSupported(cinfo) || cinfo->optimize_coding) {
    int ysize_blocks = DivCeil(cinfo->image_height, DCTSIZE);
    int num_arrays = cinfo->num_scans * ysize_blocks;
    m->token_arrays = Allocate<TokenArray>(cinfo, num_arrays, JPOOL_IMAGE);
    m->cur_token_array = 0;
    memset(m->token_arrays, 0, num_arrays * sizeof(TokenArray));
    m->num_tokens = 0;
    m->total_num_tokens = 0;
  }
  if (cinfo->global_state == kEncWriteCoeffs) {
    return;
  }
  size_t iMCU_width = DCTSIZE * cinfo->max_h_samp_factor;
  size_t iMCU_height = DCTSIZE * cinfo->max_v_samp_factor;
  size_t total_iMCU_cols = DivCeil(cinfo->image_width, iMCU_width);
  size_t xsize_full = total_iMCU_cols * iMCU_width;
  size_t ysize_full = 3 * iMCU_height;
  if (!cinfo->raw_data_in) {
    int num_all_components =
        std::max(cinfo->input_components, cinfo->num_components);
    for (int c = 0; c < num_all_components; ++c) {
      m->input_buffer[c].Allocate(cinfo, ysize_full, xsize_full);
    }
  }
  for (int c = 0; c < cinfo->num_components; ++c) {
    jpeg_component_info* comp = &cinfo->comp_info[c];
    size_t xsize = total_iMCU_cols * comp->h_samp_factor * DCTSIZE;
    size_t ysize = 3 * comp->v_samp_factor * DCTSIZE;
    if (cinfo->raw_data_in) {
      m->input_buffer[c].Allocate(cinfo, ysize, xsize);
    }
    m->smooth_input[c] = &m->input_buffer[c];
    if (!cinfo->raw_data_in && cinfo->smoothing_factor) {
      m->smooth_input[c] = Allocate<RowBuffer<float>>(cinfo, 1, JPOOL_IMAGE);
      m->smooth_input[c]->Allocate(cinfo, ysize_full, xsize_full);
    }
    m->raw_data[c] = m->smooth_input[c];
    if (!cinfo->raw_data_in && (m->h_factor[c] > 1 || m->v_factor[c] > 1)) {
      m->raw_data[c] = Allocate<RowBuffer<float>>(cinfo, 1, JPOOL_IMAGE);
      m->raw_data[c]->Allocate(cinfo, ysize, xsize);
    }
    m->quant_mul[c] = Allocate<float>(cinfo, DCTSIZE2, JPOOL_IMAGE_ALIGNED);
  }
  m->dct_buffer = Allocate<float>(cinfo, 2 * DCTSIZE2, JPOOL_IMAGE_ALIGNED);
  m->block_tmp = Allocate<int32_t>(cinfo, DCTSIZE2 * 4, JPOOL_IMAGE_ALIGNED);
  if (!IsStreamingSupported(cinfo)) {
    m->coeff_buffers =
        Allocate<jvirt_barray_ptr>(cinfo, cinfo->num_components, JPOOL_IMAGE);
    for (int c = 0; c < cinfo->num_components; ++c) {
      jpeg_component_info* comp = &cinfo->comp_info[c];
      const size_t xsize_blocks = comp->width_in_blocks;
      const size_t ysize_blocks = comp->height_in_blocks;
      m->coeff_buffers[c] = (*cinfo->mem->request_virt_barray)(
          reinterpret_cast<j_common_ptr>(cinfo), JPOOL_IMAGE,
          /*pre_zero=*/false, xsize_blocks, ysize_blocks, comp->v_samp_factor);
    }
  }
  if (m->use_adaptive_quantization) {
    int y_channel = cinfo->jpeg_color_space == JCS_RGB ? 1 : 0;
    jpeg_component_info* y_comp = &cinfo->comp_info[y_channel];
    const size_t xsize_blocks = y_comp->width_in_blocks;
    const size_t vecsize = VectorSize();
    const size_t xsize_padded = DivCeil(2 * xsize_blocks, vecsize) * vecsize;
    m->diff_buffer =
        Allocate<float>(cinfo, xsize_blocks * DCTSIZE + 8, JPOOL_IMAGE_ALIGNED);
    m->fuzzy_erosion_tmp.Allocate(cinfo, 2, xsize_padded);
    m->pre_erosion.Allocate(cinfo, 6 * cinfo->max_v_samp_factor, xsize_padded);
    size_t qf_height = cinfo->max_v_samp_factor;
    if (m->psnr_target > 0) {
      qf_height *= cinfo->total_iMCU_rows;
    }
    m->quant_field.Allocate(cinfo, qf_height, xsize_blocks);
  } else {
    m->quant_field.Allocate(cinfo, 1, m->xsize_blocks);
    m->quant_field.FillRow(0, 0, m->xsize_blocks);
  }
  for (int c = 0; c < cinfo->num_components; ++c) {
    m->zero_bias_offset[c] =
        Allocate<float>(cinfo, DCTSIZE2, JPOOL_IMAGE_ALIGNED);
    m->zero_bias_mul[c] = Allocate<float>(cinfo, DCTSIZE2, JPOOL_IMAGE_ALIGNED);
    memset(m->zero_bias_mul[c], 0, DCTSIZE2 * sizeof(float));
    memset(m->zero_bias_offset[c], 0, DCTSIZE2 * sizeof(float));
  }
}

void InitProgressMonitor(j_compress_ptr cinfo) {
  if (cinfo->progress == nullptr) {
    return;
  }
  if (IsStreamingSupported(cinfo)) {
    // We have only one input pass.
    cinfo->progress->total_passes = 1;
  } else {
    // We have one input pass, a histogram pass for each scan, and an encode
    // pass for each scan.
    cinfo->progress->total_passes = 1 + 2 * cinfo->num_scans;
  }
}

// Common setup code between streaming and transcoding code paths. Called in
// both jpegli_start_compress() and jpegli_write_coefficients().
void InitCompress(j_compress_ptr cinfo, boolean write_all_tables) {
  jpeg_comp_master* m = cinfo->master;
  (*cinfo->err->reset_error_mgr)(reinterpret_cast<j_common_ptr>(cinfo));
  ProcessCompressionParams(cinfo);
  InitProgressMonitor(cinfo);
  AllocateBuffers(cinfo);
  if (cinfo->global_state != kEncWriteCoeffs) {
    ChooseInputMethod(cinfo);
    if (!cinfo->raw_data_in) {
      ChooseColorTransform(cinfo);
      ChooseDownsampleMethods(cinfo);
    }
    QuantPass pass = m->psnr_target > 0 ? QuantPass::SEARCH_FIRST_PASS
                                        : QuantPass::NO_SEARCH;
    InitQuantizer(cinfo, pass);
  }
  if (write_all_tables) {
    jpegli_suppress_tables(cinfo, FALSE);
  }
  if (!cinfo->optimize_coding && !cinfo->progressive_mode) {
    CopyHuffmanTables(cinfo);
    InitEntropyCoder(cinfo);
  }
  (*cinfo->dest->init_destination)(cinfo);
  WriteFileHeader(cinfo);
  JpegBitWriterInit(cinfo);
  m->next_iMCU_row = 0;
  m->last_restart_interval = 0;
  m->next_dht_index = 0;
}

//
// Input streaming
//

void ProgressMonitorInputPass(j_compress_ptr cinfo) {
  if (cinfo->progress == nullptr) {
    return;
  }
  cinfo->progress->completed_passes = 0;
  cinfo->progress->pass_counter = cinfo->next_scanline;
  cinfo->progress->pass_limit = cinfo->image_height;
  (*cinfo->progress->progress_monitor)(reinterpret_cast<j_common_ptr>(cinfo));
}

void ReadInputRow(j_compress_ptr cinfo, const uint8_t* scanline,
                  float* row[kMaxComponents]) {
  jpeg_comp_master* m = cinfo->master;
  int num_all_components =
      std::max(cinfo->input_components, cinfo->num_components);
  for (int c = 0; c < num_all_components; ++c) {
    row[c] = m->input_buffer[c].Row(m->next_input_row);
  }
  ++m->next_input_row;
  if (scanline == nullptr) {
    for (int c = 0; c < cinfo->input_components; ++c) {
      memset(row[c], 0, cinfo->image_width * sizeof(row[c][0]));
    }
    return;
  }
  (*m->input_method)(scanline, cinfo->image_width, row);
}

void PadInputBuffer(j_compress_ptr cinfo, float* row[kMaxComponents]) {
  jpeg_comp_master* m = cinfo->master;
  const size_t len0 = cinfo->image_width;
  const size_t len1 = m->xsize_blocks * DCTSIZE;
  for (int c = 0; c < cinfo->num_components; ++c) {
    // Pad row to a multiple of the iMCU width, plus create a border of 1
    // repeated pixel for adaptive quant field calculation.
    float last_val = row[c][len0 - 1];
    for (size_t x = len0; x <= len1; ++x) {
      row[c][x] = last_val;
    }
    row[c][-1] = row[c][0];
  }
  if (m->next_input_row == cinfo->image_height) {
    size_t num_rows = m->ysize_blocks * DCTSIZE - cinfo->image_height;
    for (size_t i = 0; i < num_rows; ++i) {
      for (int c = 0; c < cinfo->num_components; ++c) {
        float* dest = m->input_buffer[c].Row(m->next_input_row) - 1;
        memcpy(dest, row[c] - 1, (len1 + 2) * sizeof(dest[0]));
      }
      ++m->next_input_row;
    }
  }
}

void ProcessiMCURow(j_compress_ptr cinfo) {
  JXL_ASSERT(cinfo->master->next_iMCU_row < cinfo->total_iMCU_rows);
  if (!cinfo->raw_data_in) {
    ApplyInputSmoothing(cinfo);
    DownsampleInputBuffer(cinfo);
  }
  ComputeAdaptiveQuantField(cinfo);
  if (IsStreamingSupported(cinfo)) {
    if (cinfo->optimize_coding) {
      ComputeTokensForiMCURow(cinfo);
    } else {
      WriteiMCURow(cinfo);
    }
  } else {
    ComputeCoefficientsForiMCURow(cinfo);
  }
  ++cinfo->master->next_iMCU_row;
}

void ProcessiMCURows(j_compress_ptr cinfo) {
  jpeg_comp_master* m = cinfo->master;
  size_t iMCU_height = DCTSIZE * cinfo->max_v_samp_factor;
  // To have context rows both above and below the current iMCU row, we delay
  // processing the first iMCU row and process two iMCU rows after we receive
  // the last input row.
  if (m->next_input_row % iMCU_height == 0 && m->next_input_row > iMCU_height) {
    ProcessiMCURow(cinfo);
  }
  if (m->next_input_row >= cinfo->image_height) {
    ProcessiMCURow(cinfo);
  }
}

//
// Non-streaming part
//

void ZigZagShuffleBlocks(j_compress_ptr cinfo) {
  JCOEF tmp[DCTSIZE2];
  for (int c = 0; c < cinfo->num_components; ++c) {
    jpeg_component_info* comp = &cinfo->comp_info[c];
    for (JDIMENSION by = 0; by < comp->height_in_blocks; ++by) {
      JBLOCKARRAY ba = GetBlockRow(cinfo, c, by);
      for (JDIMENSION bx = 0; bx < comp->width_in_blocks; ++bx) {
        JCOEF* block = &ba[0][bx][0];
        for (int k = 0; k < DCTSIZE2; ++k) {
          tmp[k] = block[kJPEGNaturalOrder[k]];
        }
        memcpy(block, tmp, sizeof(tmp));
      }
    }
  }
}

}  // namespace jpegli

//
// Parameter setup
//

void jpegli_CreateCompress(j_compress_ptr cinfo, int version,
                           size_t structsize) {
  cinfo->mem = nullptr;
  if (structsize != sizeof(*cinfo)) {
    JPEGLI_ERROR("jpegli_compress_struct has wrong size.");
  }
  jpegli::InitMemoryManager(reinterpret_cast<j_common_ptr>(cinfo));
  cinfo->progress = nullptr;
  cinfo->is_decompressor = FALSE;
  cinfo->global_state = jpegli::kEncStart;
  cinfo->dest = nullptr;
  cinfo->image_width = 0;
  cinfo->image_height = 0;
  cinfo->input_components = 0;
  cinfo->in_color_space = JCS_UNKNOWN;
  cinfo->input_gamma = 1.0f;
  cinfo->num_components = 0;
  cinfo->jpeg_color_space = JCS_UNKNOWN;
  cinfo->comp_info = nullptr;
  for (int i = 0; i < NUM_QUANT_TBLS; ++i) {
    cinfo->quant_tbl_ptrs[i] = nullptr;
  }
  for (int i = 0; i < NUM_HUFF_TBLS; ++i) {
    cinfo->dc_huff_tbl_ptrs[i] = nullptr;
    cinfo->ac_huff_tbl_ptrs[i] = nullptr;
  }
  memset(cinfo->arith_dc_L, 0, sizeof(cinfo->arith_dc_L));
  memset(cinfo->arith_dc_U, 0, sizeof(cinfo->arith_dc_U));
  memset(cinfo->arith_ac_K, 0, sizeof(cinfo->arith_ac_K));
  cinfo->write_Adobe_marker = false;
  cinfo->master = jpegli::Allocate<jpeg_comp_master>(cinfo, 1);
  jpegli::InitializeCompressParams(cinfo);
  cinfo->master->force_baseline = true;
  cinfo->master->xyb_mode = false;
  cinfo->master->cicp_transfer_function = 2;  // unknown transfer function code
  cinfo->master->use_std_tables = false;
  cinfo->master->use_adaptive_quantization = true;
  cinfo->master->progressive_level = jpegli::kDefaultProgressiveLevel;
  cinfo->master->data_type = JPEGLI_TYPE_UINT8;
  cinfo->master->endianness = JPEGLI_NATIVE_ENDIAN;
  cinfo->master->coeff_buffers = nullptr;
}

void jpegli_set_xyb_mode(j_compress_ptr cinfo) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->master->xyb_mode = true;
}

void jpegli_set_cicp_transfer_function(j_compress_ptr cinfo, int code) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->master->cicp_transfer_function = code;
}

void jpegli_set_defaults(j_compress_ptr cinfo) {
  CheckState(cinfo, jpegli::kEncStart);
  jpegli::InitializeCompressParams(cinfo);
  jpegli_default_colorspace(cinfo);
  jpegli_set_quality(cinfo, 90, TRUE);
  jpegli_set_progressive_level(cinfo, jpegli::kDefaultProgressiveLevel);
  jpegli::AddStandardHuffmanTables(reinterpret_cast<j_common_ptr>(cinfo),
                                   /*is_dc=*/false);
  jpegli::AddStandardHuffmanTables(reinterpret_cast<j_common_ptr>(cinfo),
                                   /*is_dc=*/true);
}

void jpegli_default_colorspace(j_compress_ptr cinfo) {
  CheckState(cinfo, jpegli::kEncStart);
  switch (cinfo->in_color_space) {
    case JCS_GRAYSCALE:
      jpegli_set_colorspace(cinfo, JCS_GRAYSCALE);
      break;
    case JCS_RGB: {
      if (cinfo->master->xyb_mode) {
        jpegli_set_colorspace(cinfo, JCS_RGB);
      } else {
        jpegli_set_colorspace(cinfo, JCS_YCbCr);
      }
      break;
    }
    case JCS_YCbCr:
      jpegli_set_colorspace(cinfo, JCS_YCbCr);
      break;
    case JCS_CMYK:
      jpegli_set_colorspace(cinfo, JCS_CMYK);
      break;
    case JCS_YCCK:
      jpegli_set_colorspace(cinfo, JCS_YCCK);
      break;
    case JCS_UNKNOWN:
      jpegli_set_colorspace(cinfo, JCS_UNKNOWN);
      break;
    default:
      JPEGLI_ERROR("Unsupported input colorspace %d", cinfo->in_color_space);
  }
}

void jpegli_set_colorspace(j_compress_ptr cinfo, J_COLOR_SPACE colorspace) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->jpeg_color_space = colorspace;
  switch (colorspace) {
    case JCS_GRAYSCALE:
      cinfo->num_components = 1;
      break;
    case JCS_RGB:
    case JCS_YCbCr:
      cinfo->num_components = 3;
      break;
    case JCS_CMYK:
    case JCS_YCCK:
      cinfo->num_components = 4;
      break;
    case JCS_UNKNOWN:
      cinfo->num_components =
          std::min<int>(jpegli::kMaxComponents, cinfo->input_components);
      break;
    default:
      JPEGLI_ERROR("Unsupported jpeg colorspace %d", colorspace);
  }
  // Adobe marker is only needed to distinguish CMYK and YCCK JPEGs.
  cinfo->write_Adobe_marker = (cinfo->jpeg_color_space == JCS_YCCK);
  if (cinfo->comp_info == nullptr) {
    cinfo->comp_info =
        jpegli::Allocate<jpeg_component_info>(cinfo, MAX_COMPONENTS);
  }
  memset(cinfo->comp_info, 0,
         jpegli::kMaxComponents * sizeof(jpeg_component_info));
  for (int c = 0; c < cinfo->num_components; ++c) {
    jpeg_component_info* comp = &cinfo->comp_info[c];
    comp->component_index = c;
    comp->component_id = c + 1;
    comp->h_samp_factor = 1;
    comp->v_samp_factor = 1;
    comp->quant_tbl_no = 0;
    comp->dc_tbl_no = 0;
    comp->ac_tbl_no = 0;
  }
  if (colorspace == JCS_RGB) {
    cinfo->comp_info[0].component_id = 'R';
    cinfo->comp_info[1].component_id = 'G';
    cinfo->comp_info[2].component_id = 'B';
    if (cinfo->master->xyb_mode) {
      // Subsample blue channel.
      cinfo->comp_info[0].h_samp_factor = cinfo->comp_info[0].v_samp_factor = 2;
      cinfo->comp_info[1].h_samp_factor = cinfo->comp_info[1].v_samp_factor = 2;
      cinfo->comp_info[2].h_samp_factor = cinfo->comp_info[2].v_samp_factor = 1;
      // Use separate quantization tables for each component
      cinfo->comp_info[1].quant_tbl_no = 1;
      cinfo->comp_info[2].quant_tbl_no = 2;
    }
  } else if (colorspace == JCS_CMYK) {
    cinfo->comp_info[0].component_id = 'C';
    cinfo->comp_info[1].component_id = 'M';
    cinfo->comp_info[2].component_id = 'Y';
    cinfo->comp_info[3].component_id = 'K';
  } else if (colorspace == JCS_YCbCr || colorspace == JCS_YCCK) {
    // Use separate quantization and Huffman tables for luma and chroma
    cinfo->comp_info[1].quant_tbl_no = 1;
    cinfo->comp_info[2].quant_tbl_no = 1;
    cinfo->comp_info[1].dc_tbl_no = cinfo->comp_info[1].ac_tbl_no = 1;
    cinfo->comp_info[2].dc_tbl_no = cinfo->comp_info[2].ac_tbl_no = 1;
  }
}

void jpegli_set_distance(j_compress_ptr cinfo, float distance,
                         boolean force_baseline) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->master->force_baseline = force_baseline;
  float distances[NUM_QUANT_TBLS] = {distance, distance, distance};
  jpegli::SetQuantMatrices(cinfo, distances, /*add_two_chroma_tables=*/true);
}

float jpegli_quality_to_distance(int quality) {
  return (quality >= 100  ? 0.01f
          : quality >= 30 ? 0.1f + (100 - quality) * 0.09f
                          : 53.0f / 3000.0f * quality * quality -
                                23.0f / 20.0f * quality + 25.0f);
}

void jpegli_set_psnr(j_compress_ptr cinfo, float psnr, float tolerance,
                     float min_distance, float max_distance) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->master->psnr_target = psnr;
  cinfo->master->psnr_tolerance = tolerance;
  cinfo->master->min_distance = min_distance;
  cinfo->master->max_distance = max_distance;
}

void jpegli_set_quality(j_compress_ptr cinfo, int quality,
                        boolean force_baseline) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->master->force_baseline = force_baseline;
  float distance = jpegli_quality_to_distance(quality);
  float distances[NUM_QUANT_TBLS] = {distance, distance, distance};
  jpegli::SetQuantMatrices(cinfo, distances, /*add_two_chroma_tables=*/false);
}

void jpegli_set_linear_quality(j_compress_ptr cinfo, int scale_factor,
                               boolean force_baseline) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->master->force_baseline = force_baseline;
  float distance = jpegli::LinearQualityToDistance(scale_factor);
  float distances[NUM_QUANT_TBLS] = {distance, distance, distance};
  jpegli::SetQuantMatrices(cinfo, distances, /*add_two_chroma_tables=*/false);
}

#if JPEG_LIB_VERSION >= 70
void jpegli_default_qtables(j_compress_ptr cinfo, boolean force_baseline) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->master->force_baseline = force_baseline;
  float distances[NUM_QUANT_TBLS];
  for (int i = 0; i < NUM_QUANT_TBLS; ++i) {
    distances[i] = jpegli::LinearQualityToDistance(cinfo->q_scale_factor[i]);
  }
  jpegli::SetQuantMatrices(cinfo, distances, /*add_two_chroma_tables=*/false);
}
#endif

int jpegli_quality_scaling(int quality) {
  quality = std::min(100, std::max(1, quality));
  return quality < 50 ? 5000 / quality : 200 - 2 * quality;
}

void jpegli_use_standard_quant_tables(j_compress_ptr cinfo) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->master->use_std_tables = true;
}

void jpegli_add_quant_table(j_compress_ptr cinfo, int which_tbl,
                            const unsigned int* basic_table, int scale_factor,
                            boolean force_baseline) {
  CheckState(cinfo, jpegli::kEncStart);
  if (which_tbl < 0 || which_tbl > NUM_QUANT_TBLS) {
    JPEGLI_ERROR("Invalid quant table index %d", which_tbl);
  }
  if (cinfo->quant_tbl_ptrs[which_tbl] == nullptr) {
    cinfo->quant_tbl_ptrs[which_tbl] =
        jpegli_alloc_quant_table(reinterpret_cast<j_common_ptr>(cinfo));
  }
  int max_qval = force_baseline ? 255 : 32767U;
  JQUANT_TBL* quant_table = cinfo->quant_tbl_ptrs[which_tbl];
  for (int k = 0; k < DCTSIZE2; ++k) {
    int qval = (basic_table[k] * scale_factor + 50) / 100;
    qval = std::max(1, std::min(qval, max_qval));
    quant_table->quantval[k] = qval;
  }
  quant_table->sent_table = FALSE;
}

void jpegli_enable_adaptive_quantization(j_compress_ptr cinfo, boolean value) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->master->use_adaptive_quantization = value;
}

void jpegli_simple_progression(j_compress_ptr cinfo) {
  CheckState(cinfo, jpegli::kEncStart);
  jpegli_set_progressive_level(cinfo, 2);
}

void jpegli_set_progressive_level(j_compress_ptr cinfo, int level) {
  CheckState(cinfo, jpegli::kEncStart);
  if (level < 0) {
    JPEGLI_ERROR("Invalid progressive level %d", level);
  }
  cinfo->master->progressive_level = level;
}

void jpegli_set_input_format(j_compress_ptr cinfo, JpegliDataType data_type,
                             JpegliEndianness endianness) {
  CheckState(cinfo, jpegli::kEncStart);
  switch (data_type) {
    case JPEGLI_TYPE_UINT8:
    case JPEGLI_TYPE_UINT16:
    case JPEGLI_TYPE_FLOAT:
      cinfo->master->data_type = data_type;
      break;
    default:
      JPEGLI_ERROR("Unsupported data type %d", data_type);
  }
  switch (endianness) {
    case JPEGLI_NATIVE_ENDIAN:
    case JPEGLI_LITTLE_ENDIAN:
    case JPEGLI_BIG_ENDIAN:
      cinfo->master->endianness = endianness;
      break;
    default:
      JPEGLI_ERROR("Unsupported endianness %d", endianness);
  }
}

#if JPEG_LIB_VERSION >= 70
void jpegli_calc_jpeg_dimensions(j_compress_ptr cinfo) {
  // Since input scaling is not supported, we just copy the image dimensions.
  cinfo->jpeg_width = cinfo->image_width;
  cinfo->jpeg_height = cinfo->image_height;
}
#endif

void jpegli_copy_critical_parameters(j_decompress_ptr srcinfo,
                                     j_compress_ptr dstinfo) {
  CheckState(dstinfo, jpegli::kEncStart);
  // Image parameters.
  dstinfo->image_width = srcinfo->image_width;
  dstinfo->image_height = srcinfo->image_height;
  dstinfo->input_components = srcinfo->num_components;
  dstinfo->in_color_space = srcinfo->jpeg_color_space;
  dstinfo->input_gamma = srcinfo->output_gamma;
  // Compression parameters.
  jpegli_set_defaults(dstinfo);
  jpegli_set_colorspace(dstinfo, srcinfo->jpeg_color_space);
  if (dstinfo->num_components != srcinfo->num_components) {
    const auto& cinfo = dstinfo;
    return JPEGLI_ERROR("Mismatch between src colorspace and components");
  }
  dstinfo->data_precision = srcinfo->data_precision;
  dstinfo->CCIR601_sampling = srcinfo->CCIR601_sampling;
  dstinfo->JFIF_major_version = srcinfo->JFIF_major_version;
  dstinfo->JFIF_minor_version = srcinfo->JFIF_minor_version;
  dstinfo->density_unit = srcinfo->density_unit;
  dstinfo->X_density = srcinfo->X_density;
  dstinfo->Y_density = srcinfo->Y_density;
  for (int c = 0; c < dstinfo->num_components; ++c) {
    jpeg_component_info* srccomp = &srcinfo->comp_info[c];
    jpeg_component_info* dstcomp = &dstinfo->comp_info[c];
    dstcomp->component_id = srccomp->component_id;
    dstcomp->h_samp_factor = srccomp->h_samp_factor;
    dstcomp->v_samp_factor = srccomp->v_samp_factor;
    dstcomp->quant_tbl_no = srccomp->quant_tbl_no;
  }
  for (int i = 0; i < NUM_QUANT_TBLS; ++i) {
    if (!srcinfo->quant_tbl_ptrs[i]) continue;
    if (dstinfo->quant_tbl_ptrs[i] == nullptr) {
      dstinfo->quant_tbl_ptrs[i] = jpegli::Allocate<JQUANT_TBL>(dstinfo, 1);
    }
    memcpy(dstinfo->quant_tbl_ptrs[i], srcinfo->quant_tbl_ptrs[i],
           sizeof(JQUANT_TBL));
    dstinfo->quant_tbl_ptrs[i]->sent_table = FALSE;
  }
}

void jpegli_suppress_tables(j_compress_ptr cinfo, boolean suppress) {
  jpegli::SetSentTableFlag(cinfo->quant_tbl_ptrs, NUM_QUANT_TBLS, suppress);
  jpegli::SetSentTableFlag(cinfo->dc_huff_tbl_ptrs, NUM_HUFF_TBLS, suppress);
  jpegli::SetSentTableFlag(cinfo->ac_huff_tbl_ptrs, NUM_HUFF_TBLS, suppress);
}

//
// Compressor initialization
//

void jpegli_start_compress(j_compress_ptr cinfo, boolean write_all_tables) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->global_state = jpegli::kEncHeader;
  jpegli::InitCompress(cinfo, write_all_tables);
  cinfo->next_scanline = 0;
  cinfo->master->next_input_row = 0;
}

void jpegli_write_coefficients(j_compress_ptr cinfo,
                               jvirt_barray_ptr* coef_arrays) {
  CheckState(cinfo, jpegli::kEncStart);
  cinfo->global_state = jpegli::kEncWriteCoeffs;
  jpegli::InitCompress(cinfo, /*write_all_tables=*/true);
  cinfo->master->coeff_buffers = coef_arrays;
  cinfo->next_scanline = cinfo->image_height;
  cinfo->master->next_input_row = cinfo->image_height;
}

void jpegli_write_tables(j_compress_ptr cinfo) {
  CheckState(cinfo, jpegli::kEncStart);
  if (cinfo->dest == nullptr) {
    JPEGLI_ERROR("Missing destination.");
  }
  jpeg_comp_master* m = cinfo->master;
  (*cinfo->err->reset_error_mgr)(reinterpret_cast<j_common_ptr>(cinfo));
  (*cinfo->dest->init_destination)(cinfo);
  jpegli::WriteOutput(cinfo, {0xFF, 0xD8});  // SOI
  jpegli::EncodeDQT(cinfo, /*write_all_tables=*/true);
  jpegli::CopyHuffmanTables(cinfo);
  jpegli::EncodeDHT(cinfo, 0, m->num_huffman_tables);
  jpegli::WriteOutput(cinfo, {0xFF, 0xD9});  // EOI
  (*cinfo->dest->term_destination)(cinfo);
  jpegli_suppress_tables(cinfo, TRUE);
}

//
// Marker writing
//

void jpegli_write_m_header(j_compress_ptr cinfo, int marker,
                           unsigned int datalen) {
  CheckState(cinfo, jpegli::kEncHeader, jpegli::kEncWriteCoeffs);
  if (datalen > jpegli::kMaxBytesInMarker) {
    JPEGLI_ERROR("Invalid marker length %u", datalen);
  }
  if (marker != 0xfe && (marker < 0xe0 || marker > 0xef)) {
    JPEGLI_ERROR(
        "jpegli_write_m_header: Only APP and COM markers are supported.");
  }
  std::vector<uint8_t> marker_data(4 + datalen);
  marker_data[0] = 0xff;
  marker_data[1] = marker;
  marker_data[2] = (datalen + 2) >> 8;
  marker_data[3] = (datalen + 2) & 0xff;
  jpegli::WriteOutput(cinfo, &marker_data[0], 4);
}

void jpegli_write_m_byte(j_compress_ptr cinfo, int val) {
  uint8_t data = val;
  jpegli::WriteOutput(cinfo, &data, 1);
}

void jpegli_write_marker(j_compress_ptr cinfo, int marker,
                         const JOCTET* dataptr, unsigned int datalen) {
  jpegli_write_m_header(cinfo, marker, datalen);
  jpegli::WriteOutput(cinfo, dataptr, datalen);
}

void jpegli_write_icc_profile(j_compress_ptr cinfo, const JOCTET* icc_data_ptr,
                              unsigned int icc_data_len) {
  constexpr size_t kMaxIccBytesInMarker =
      jpegli::kMaxBytesInMarker - sizeof jpegli::kICCSignature - 2;
  const int num_markers =
      static_cast<int>(jpegli::DivCeil(icc_data_len, kMaxIccBytesInMarker));
  size_t begin = 0;
  for (int current_marker = 0; current_marker < num_markers; ++current_marker) {
    const size_t length = std::min(kMaxIccBytesInMarker, icc_data_len - begin);
    jpegli_write_m_header(
        cinfo, jpegli::kICCMarker,
        static_cast<unsigned int>(length + sizeof jpegli::kICCSignature + 2));
    for (const unsigned char c : jpegli::kICCSignature) {
      jpegli_write_m_byte(cinfo, c);
    }
    jpegli_write_m_byte(cinfo, current_marker + 1);
    jpegli_write_m_byte(cinfo, num_markers);
    for (size_t i = 0; i < length; ++i) {
      jpegli_write_m_byte(cinfo, icc_data_ptr[begin]);
      ++begin;
    }
  }
}

//
// Input streaming
//

JDIMENSION jpegli_write_scanlines(j_compress_ptr cinfo, JSAMPARRAY scanlines,
                                  JDIMENSION num_lines) {
  CheckState(cinfo, jpegli::kEncHeader, jpegli::kEncReadImage);
  if (cinfo->raw_data_in) {
    JPEGLI_ERROR("jpegli_write_raw_data() must be called for raw data mode.");
  }
  jpegli::ProgressMonitorInputPass(cinfo);
  if (cinfo->global_state == jpegli::kEncHeader &&
      jpegli::IsStreamingSupported(cinfo) && !cinfo->optimize_coding) {
    jpegli::WriteFrameHeader(cinfo);
    jpegli::WriteScanHeader(cinfo, 0);
  }
  cinfo->global_state = jpegli::kEncReadImage;
  jpeg_comp_master* m = cinfo->master;
  if (num_lines + cinfo->next_scanline > cinfo->image_height) {
    num_lines = cinfo->image_height - cinfo->next_scanline;
  }
  JDIMENSION prev_scanline = cinfo->next_scanline;
  size_t input_lag = (std::min<size_t>(cinfo->image_height, m->next_input_row) -
                      cinfo->next_scanline);
  if (input_lag > num_lines) {
    JPEGLI_ERROR("Need at least %u lines to continue", input_lag);
  }
  if (input_lag > 0) {
    if (!jpegli::EmptyBitWriterBuffer(&m->bw)) {
      return 0;
    }
    cinfo->next_scanline += input_lag;
  }
  float* rows[jpegli::kMaxComponents];
  for (size_t i = input_lag; i < num_lines; ++i) {
    jpegli::ReadInputRow(cinfo, scanlines[i], rows);
    (*m->color_transform)(rows, cinfo->image_width);
    jpegli::PadInputBuffer(cinfo, rows);
    jpegli::ProcessiMCURows(cinfo);
    if (!jpegli::EmptyBitWriterBuffer(&m->bw)) {
      break;
    }
    ++cinfo->next_scanline;
  }
  return cinfo->next_scanline - prev_scanline;
}

JDIMENSION jpegli_write_raw_data(j_compress_ptr cinfo, JSAMPIMAGE data,
                                 JDIMENSION num_lines) {
  CheckState(cinfo, jpegli::kEncHeader, jpegli::kEncReadImage);
  if (!cinfo->raw_data_in) {
    JPEGLI_ERROR("jpegli_write_raw_data(): raw data mode was not set");
  }
  jpegli::ProgressMonitorInputPass(cinfo);
  if (cinfo->global_state == jpegli::kEncHeader &&
      jpegli::IsStreamingSupported(cinfo) && !cinfo->optimize_coding) {
    jpegli::WriteFrameHeader(cinfo);
    jpegli::WriteScanHeader(cinfo, 0);
  }
  cinfo->global_state = jpegli::kEncReadImage;
  jpeg_comp_master* m = cinfo->master;
  if (cinfo->next_scanline >= cinfo->image_height) {
    return 0;
  }
  size_t iMCU_height = DCTSIZE * cinfo->max_v_samp_factor;
  if (num_lines < iMCU_height) {
    JPEGLI_ERROR("Missing input lines, minimum is %u", iMCU_height);
  }
  if (cinfo->next_scanline < m->next_input_row) {
    JXL_ASSERT(m->next_input_row - cinfo->next_scanline == iMCU_height);
    if (!jpegli::EmptyBitWriterBuffer(&m->bw)) {
      return 0;
    }
    cinfo->next_scanline = m->next_input_row;
    return iMCU_height;
  }
  size_t iMCU_y = m->next_input_row / iMCU_height;
  float* rows[jpegli::kMaxComponents];
  for (int c = 0; c < cinfo->num_components; ++c) {
    JSAMPARRAY plane = data[c];
    jpeg_component_info* comp = &cinfo->comp_info[c];
    size_t xsize = comp->width_in_blocks * DCTSIZE;
    size_t ysize = comp->v_samp_factor * DCTSIZE;
    size_t y0 = iMCU_y * ysize;
    auto& buffer = m->input_buffer[c];
    for (size_t i = 0; i < ysize; ++i) {
      rows[0] = buffer.Row(y0 + i);
      if (plane[i] == nullptr) {
        memset(rows[0], 0, xsize * sizeof(rows[0][0]));
      } else {
        (*m->input_method)(plane[i], xsize, rows);
      }
      // We need a border of 1 repeated pixel for adaptive quant field.
      buffer.PadRow(y0 + i, xsize, /*border=*/1);
    }
  }
  m->next_input_row += iMCU_height;
  jpegli::ProcessiMCURows(cinfo);
  if (!jpegli::EmptyBitWriterBuffer(&m->bw)) {
    return 0;
  }
  cinfo->next_scanline += iMCU_height;
  return iMCU_height;
}

//
// Non-streaming part
//

void jpegli_finish_compress(j_compress_ptr cinfo) {
  CheckState(cinfo, jpegli::kEncReadImage, jpegli::kEncWriteCoeffs);
  jpeg_comp_master* m = cinfo->master;
  if (cinfo->next_scanline < cinfo->image_height) {
    JPEGLI_ERROR("Incomplete image, expected %d rows, got %d",
                 cinfo->image_height, cinfo->next_scanline);
  }

  if (cinfo->global_state == jpegli::kEncWriteCoeffs) {
    // Zig-zag shuffle all the blocks. For non-transcoding case it was already
    // done in EncodeiMCURow().
    jpegli::ZigZagShuffleBlocks(cinfo);
  }

  if (m->psnr_target > 0) {
    jpegli::QuantizetoPSNR(cinfo);
  }

  const bool tokens_done = jpegli::IsStreamingSupported(cinfo);
  const bool bitstream_done = tokens_done && !cinfo->optimize_coding;

  if (!tokens_done) {
    jpegli::TokenizeJpeg(cinfo);
  }

  if (cinfo->optimize_coding || cinfo->progressive_mode) {
    jpegli::OptimizeHuffmanCodes(cinfo);
    jpegli::InitEntropyCoder(cinfo);
  }

  if (!bitstream_done) {
    jpegli::WriteFrameHeader(cinfo);
    for (int i = 0; i < cinfo->num_scans; ++i) {
      jpegli::WriteScanHeader(cinfo, i);
      jpegli::WriteScanData(cinfo, i);
    }
  } else {
    JumpToByteBoundary(&m->bw);
    if (!EmptyBitWriterBuffer(&m->bw)) {
      JPEGLI_ERROR("Output suspension is not supported in finish_compress");
    }
  }

  jpegli::WriteOutput(cinfo, {0xFF, 0xD9});  // EOI
  (*cinfo->dest->term_destination)(cinfo);

  // Release memory and reset global state.
  jpegli_abort_compress(cinfo);
}

void jpegli_abort_compress(j_compress_ptr cinfo) {
  jpegli_abort(reinterpret_cast<j_common_ptr>(cinfo));
}

void jpegli_destroy_compress(j_compress_ptr cinfo) {
  jpegli_destroy(reinterpret_cast<j_common_ptr>(cinfo));
}
