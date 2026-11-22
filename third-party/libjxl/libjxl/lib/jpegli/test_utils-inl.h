// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This template file is included in both the libjpeg_test_util.cc and the
// test_utils.cc files with different JPEG_API_FN macros and possibly different
// include paths for the jpeg headers.

// Sequential non-interleaved.
static constexpr jpeg_scan_info kScript1[] = {
    {1, {0}, 0, 63, 0, 0},
    {1, {1}, 0, 63, 0, 0},
    {1, {2}, 0, 63, 0, 0},
};
// Sequential partially interleaved, chroma first.
static constexpr jpeg_scan_info kScript2[] = {
    {2, {1, 2}, 0, 63, 0, 0},
    {1, {0}, 0, 63, 0, 0},
};

// Rest of the scan scripts are progressive.

static constexpr jpeg_scan_info kScript3[] = {
    // Interleaved full DC.
    {3, {0, 1, 2}, 0, 0, 0, 0},
    // Full AC scans.
    {1, {0}, 1, 63, 0, 0},
    {1, {1}, 1, 63, 0, 0},
    {1, {2}, 1, 63, 0, 0},
};
static constexpr jpeg_scan_info kScript4[] = {
    // Non-interleaved full DC.
    {1, {0}, 0, 0, 0, 0},
    {1, {1}, 0, 0, 0, 0},
    {1, {2}, 0, 0, 0, 0},
    // Full AC scans.
    {1, {0}, 1, 63, 0, 0},
    {1, {1}, 1, 63, 0, 0},
    {1, {2}, 1, 63, 0, 0},
};
static constexpr jpeg_scan_info kScript5[] = {
    // Partially interleaved full DC, chroma first.
    {2, {1, 2}, 0, 0, 0, 0},
    {1, {0}, 0, 0, 0, 0},
    // AC shifted by 1 bit.
    {1, {0}, 1, 63, 0, 1},
    {1, {1}, 1, 63, 0, 1},
    {1, {2}, 1, 63, 0, 1},
    // AC refinement scan.
    {1, {0}, 1, 63, 1, 0},
    {1, {1}, 1, 63, 1, 0},
    {1, {2}, 1, 63, 1, 0},
};
static constexpr jpeg_scan_info kScript6[] = {
    // Interleaved DC shifted by 2 bits.
    {3, {0, 1, 2}, 0, 0, 0, 2},
    // Interleaved DC refinement scans.
    {3, {0, 1, 2}, 0, 0, 2, 1},
    {3, {0, 1, 2}, 0, 0, 1, 0},
    // Full AC scans.
    {1, {0}, 1, 63, 0, 0},
    {1, {1}, 1, 63, 0, 0},
    {1, {2}, 1, 63, 0, 0},
};

static constexpr jpeg_scan_info kScript7[] = {
    // Non-interleaved DC shifted by 2 bits.
    {1, {0}, 0, 0, 0, 2},
    {1, {1}, 0, 0, 0, 2},
    {1, {2}, 0, 0, 0, 2},
    // Non-interleaved DC first refinement scans.
    {1, {0}, 0, 0, 2, 1},
    {1, {1}, 0, 0, 2, 1},
    {1, {2}, 0, 0, 2, 1},
    // Non-interleaved DC second refinement scans.
    {1, {0}, 0, 0, 1, 0},
    {1, {1}, 0, 0, 1, 0},
    {1, {2}, 0, 0, 1, 0},
    // Full AC scans.
    {1, {0}, 1, 63, 0, 0},
    {1, {1}, 1, 63, 0, 0},
    {1, {2}, 1, 63, 0, 0},
};

static constexpr jpeg_scan_info kScript8[] = {
    // Partially interleaved DC shifted by 2 bits, chroma first
    {2, {1, 2}, 0, 0, 0, 2},
    {1, {0}, 0, 0, 0, 2},
    // Partially interleaved DC first refinement scans.
    {2, {0, 2}, 0, 0, 2, 1},
    {1, {1}, 0, 0, 2, 1},
    // Partially interleaved DC first refinement scans, chroma first.
    {2, {1, 2}, 0, 0, 1, 0},
    {1, {0}, 0, 0, 1, 0},
    // Full AC scans.
    {1, {0}, 1, 63, 0, 0},
    {1, {1}, 1, 63, 0, 0},
    {1, {2}, 1, 63, 0, 0},
};

static constexpr jpeg_scan_info kScript9[] = {
    // Interleaved full DC.
    {3, {0, 1, 2}, 0, 0, 0, 0},
    // AC scans for component 0
    // shifted by 1 bit, two spectral ranges
    {1, {0}, 1, 6, 0, 1},
    {1, {0}, 7, 63, 0, 1},
    // refinement scan, full
    {1, {0}, 1, 63, 1, 0},
    // AC scans for component 1
    // shifted by 1 bit, full
    {1, {1}, 1, 63, 0, 1},
    // refinement scan, two spectral ranges
    {1, {1}, 1, 6, 1, 0},
    {1, {1}, 7, 63, 1, 0},
    // AC scans for component 2
    // shifted by 1 bit, two spectral ranges
    {1, {2}, 1, 6, 0, 1},
    {1, {2}, 7, 63, 0, 1},
    // refinement scan, two spectral ranges (but different from above)
    {1, {2}, 1, 16, 1, 0},
    {1, {2}, 17, 63, 1, 0},
};

static constexpr jpeg_scan_info kScript10[] = {
    // Interleaved full DC.
    {3, {0, 1, 2}, 0, 0, 0, 0},
    // AC scans for spectral range 1..16
    // shifted by 1
    {1, {0}, 1, 16, 0, 1},
    {1, {1}, 1, 16, 0, 1},
    {1, {2}, 1, 16, 0, 1},
    // refinement scans, two sub-ranges
    {1, {0}, 1, 8, 1, 0},
    {1, {0}, 9, 16, 1, 0},
    {1, {1}, 1, 8, 1, 0},
    {1, {1}, 9, 16, 1, 0},
    {1, {2}, 1, 8, 1, 0},
    {1, {2}, 9, 16, 1, 0},
    // AC scans for spectral range 17..63
    {1, {0}, 17, 63, 0, 1},
    {1, {1}, 17, 63, 0, 1},
    {1, {2}, 17, 63, 0, 1},
    // refinement scans, two sub-ranges
    {1, {0}, 17, 28, 1, 0},
    {1, {0}, 29, 63, 1, 0},
    {1, {1}, 17, 28, 1, 0},
    {1, {1}, 29, 63, 1, 0},
    {1, {2}, 17, 28, 1, 0},
    {1, {2}, 29, 63, 1, 0},
};

struct ScanScript {
  int num_scans;
  const jpeg_scan_info* scans;
};

static constexpr ScanScript kTestScript[] = {
    {ARRAY_SIZE(kScript1), kScript1}, {ARRAY_SIZE(kScript2), kScript2},
    {ARRAY_SIZE(kScript3), kScript3}, {ARRAY_SIZE(kScript4), kScript4},
    {ARRAY_SIZE(kScript5), kScript5}, {ARRAY_SIZE(kScript6), kScript6},
    {ARRAY_SIZE(kScript7), kScript7}, {ARRAY_SIZE(kScript8), kScript8},
    {ARRAY_SIZE(kScript9), kScript9}, {ARRAY_SIZE(kScript10), kScript10},
};
static constexpr int kNumTestScripts = ARRAY_SIZE(kTestScript);

void SetScanDecompressParams(const DecompressParams& dparams,
                             j_decompress_ptr cinfo, int scan_number) {
  const ScanDecompressParams* sparams = nullptr;
  for (const auto& sp : dparams.scan_params) {
    if (scan_number <= sp.max_scan_number) {
      sparams = &sp;
      break;
    }
  }
  if (sparams == nullptr) {
    return;
  }
  if (dparams.quantize_colors) {
    cinfo->dither_mode = (J_DITHER_MODE)sparams->dither_mode;
    if (sparams->color_quant_mode == CQUANT_1PASS) {
      cinfo->two_pass_quantize = FALSE;
      cinfo->colormap = nullptr;
    } else if (sparams->color_quant_mode == CQUANT_2PASS) {
      JXL_CHECK(cinfo->out_color_space == JCS_RGB);
      cinfo->two_pass_quantize = TRUE;
      cinfo->colormap = nullptr;
    } else if (sparams->color_quant_mode == CQUANT_EXTERNAL) {
      JXL_CHECK(cinfo->out_color_space == JCS_RGB);
      cinfo->two_pass_quantize = FALSE;
      bool have_colormap = cinfo->colormap != nullptr;
      cinfo->actual_number_of_colors = kTestColorMapNumColors;
      cinfo->colormap = (*cinfo->mem->alloc_sarray)(
          reinterpret_cast<j_common_ptr>(cinfo), JPOOL_IMAGE,
          cinfo->actual_number_of_colors, 3);
      jxl::msan::UnpoisonMemory(cinfo->colormap, 3 * sizeof(JSAMPROW));
      for (int i = 0; i < kTestColorMapNumColors; ++i) {
        cinfo->colormap[0][i] = (kTestColorMap[i] >> 16) & 0xff;
        cinfo->colormap[1][i] = (kTestColorMap[i] >> 8) & 0xff;
        cinfo->colormap[2][i] = (kTestColorMap[i] >> 0) & 0xff;
      }
      if (have_colormap) {
        JPEG_API_FN(new_colormap)(cinfo);
      }
    } else if (sparams->color_quant_mode == CQUANT_REUSE) {
      JXL_CHECK(cinfo->out_color_space == JCS_RGB);
      JXL_CHECK(cinfo->colormap);
    }
  }
}

void SetDecompressParams(const DecompressParams& dparams,
                         j_decompress_ptr cinfo) {
  cinfo->do_block_smoothing = dparams.do_block_smoothing;
  cinfo->do_fancy_upsampling = dparams.do_fancy_upsampling;
  if (dparams.output_mode == RAW_DATA) {
    cinfo->raw_data_out = TRUE;
  }
  if (dparams.set_out_color_space) {
    cinfo->out_color_space = (J_COLOR_SPACE)dparams.out_color_space;
    if (dparams.out_color_space == JCS_UNKNOWN) {
      cinfo->jpeg_color_space = JCS_UNKNOWN;
    }
  }
  cinfo->scale_num = dparams.scale_num;
  cinfo->scale_denom = dparams.scale_denom;
  cinfo->quantize_colors = dparams.quantize_colors;
  cinfo->desired_number_of_colors = dparams.desired_number_of_colors;
  if (!dparams.scan_params.empty()) {
    if (cinfo->buffered_image) {
      for (const auto& sparams : dparams.scan_params) {
        if (sparams.color_quant_mode == CQUANT_1PASS) {
          cinfo->enable_1pass_quant = TRUE;
        } else if (sparams.color_quant_mode == CQUANT_2PASS) {
          cinfo->enable_2pass_quant = TRUE;
        } else if (sparams.color_quant_mode == CQUANT_EXTERNAL) {
          cinfo->enable_external_quant = TRUE;
        }
      }
      SetScanDecompressParams(dparams, cinfo, 1);
    } else {
      SetScanDecompressParams(dparams, cinfo, kLastScan);
    }
  }
}

void CheckMarkerPresent(j_decompress_ptr cinfo, uint8_t marker_type) {
  bool marker_found = false;
  for (jpeg_saved_marker_ptr marker = cinfo->marker_list; marker != nullptr;
       marker = marker->next) {
    jxl::msan::UnpoisonMemory(marker, sizeof(*marker));
    jxl::msan::UnpoisonMemory(marker->data, marker->data_length);
    if (marker->marker == marker_type &&
        marker->data_length == sizeof(kMarkerData) &&
        memcmp(marker->data, kMarkerData, sizeof(kMarkerData)) == 0) {
      marker_found = true;
    }
  }
  JXL_CHECK(marker_found);
}

void VerifyHeader(const CompressParams& jparams, j_decompress_ptr cinfo) {
  if (jparams.set_jpeg_colorspace) {
    JXL_CHECK(cinfo->jpeg_color_space == jparams.jpeg_color_space);
  }
  if (jparams.override_JFIF >= 0) {
    JXL_CHECK(cinfo->saw_JFIF_marker == jparams.override_JFIF);
  }
  if (jparams.override_Adobe >= 0) {
    JXL_CHECK(cinfo->saw_Adobe_marker == jparams.override_Adobe);
  }
  if (jparams.add_marker) {
    CheckMarkerPresent(cinfo, kSpecialMarker0);
    CheckMarkerPresent(cinfo, kSpecialMarker1);
  }
  jxl::msan::UnpoisonMemory(
      cinfo->comp_info, cinfo->num_components * sizeof(cinfo->comp_info[0]));
  int max_h_samp_factor = 1;
  int max_v_samp_factor = 1;
  for (int i = 0; i < cinfo->num_components; ++i) {
    jpeg_component_info* comp = &cinfo->comp_info[i];
    if (!jparams.comp_ids.empty()) {
      JXL_CHECK(comp->component_id == jparams.comp_ids[i]);
    }
    if (!jparams.h_sampling.empty()) {
      JXL_CHECK(comp->h_samp_factor == jparams.h_sampling[i]);
    }
    if (!jparams.v_sampling.empty()) {
      JXL_CHECK(comp->v_samp_factor == jparams.v_sampling[i]);
    }
    if (!jparams.quant_indexes.empty()) {
      JXL_CHECK(comp->quant_tbl_no == jparams.quant_indexes[i]);
    }
    max_h_samp_factor = std::max(max_h_samp_factor, comp->h_samp_factor);
    max_v_samp_factor = std::max(max_v_samp_factor, comp->v_samp_factor);
  }
  JXL_CHECK(max_h_samp_factor == cinfo->max_h_samp_factor);
  JXL_CHECK(max_v_samp_factor == cinfo->max_v_samp_factor);
  int referenced_tables[NUM_QUANT_TBLS] = {};
  for (int i = 0; i < cinfo->num_components; ++i) {
    jpeg_component_info* comp = &cinfo->comp_info[i];
    JXL_CHECK(comp->width_in_blocks ==
              DivCeil(cinfo->image_width * comp->h_samp_factor,
                      max_h_samp_factor * DCTSIZE));
    JXL_CHECK(comp->height_in_blocks ==
              DivCeil(cinfo->image_height * comp->v_samp_factor,
                      max_v_samp_factor * DCTSIZE));
    referenced_tables[comp->quant_tbl_no] = 1;
  }
  for (const auto& table : jparams.quant_tables) {
    JQUANT_TBL* quant_table = cinfo->quant_tbl_ptrs[table.slot_idx];
    if (!referenced_tables[table.slot_idx]) {
      JXL_CHECK(quant_table == nullptr);
      continue;
    }
    JXL_CHECK(quant_table != nullptr);
    jxl::msan::UnpoisonMemory(quant_table, sizeof(*quant_table));
    for (int k = 0; k < DCTSIZE2; ++k) {
      JXL_CHECK(quant_table->quantval[k] == table.quantval[k]);
    }
  }
}

void VerifyScanHeader(const CompressParams& jparams, j_decompress_ptr cinfo) {
  JXL_CHECK(cinfo->input_scan_number > 0);
  if (cinfo->progressive_mode) {
    JXL_CHECK(cinfo->Ss != 0 || cinfo->Se != 63);
  } else {
    JXL_CHECK(cinfo->Ss == 0 && cinfo->Se == 63);
  }
  if (jparams.progressive_mode > 2) {
    JXL_CHECK(jparams.progressive_mode < 3 + kNumTestScripts);
    const ScanScript& script = kTestScript[jparams.progressive_mode - 3];
    JXL_CHECK(cinfo->input_scan_number <= script.num_scans);
    const jpeg_scan_info& scan = script.scans[cinfo->input_scan_number - 1];
    JXL_CHECK(cinfo->comps_in_scan == scan.comps_in_scan);
    for (int i = 0; i < cinfo->comps_in_scan; ++i) {
      JXL_CHECK(cinfo->cur_comp_info[i]->component_index ==
                scan.component_index[i]);
    }
    JXL_CHECK(cinfo->Ss == scan.Ss);
    JXL_CHECK(cinfo->Se == scan.Se);
    JXL_CHECK(cinfo->Ah == scan.Ah);
    JXL_CHECK(cinfo->Al == scan.Al);
  }
  if (jparams.restart_interval > 0) {
    JXL_CHECK(cinfo->restart_interval == jparams.restart_interval);
  } else if (jparams.restart_in_rows > 0) {
    JXL_CHECK(cinfo->restart_interval ==
              jparams.restart_in_rows * cinfo->MCUs_per_row);
  }
  if (jparams.progressive_mode == 0 && jparams.optimize_coding == 0) {
    if (cinfo->jpeg_color_space == JCS_RGB) {
      JXL_CHECK(cinfo->comp_info[0].dc_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[1].dc_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[2].dc_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[0].ac_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[1].ac_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[2].ac_tbl_no == 0);
    } else if (cinfo->jpeg_color_space == JCS_YCbCr) {
      JXL_CHECK(cinfo->comp_info[0].dc_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[1].dc_tbl_no == 1);
      JXL_CHECK(cinfo->comp_info[2].dc_tbl_no == 1);
      JXL_CHECK(cinfo->comp_info[0].ac_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[1].ac_tbl_no == 1);
      JXL_CHECK(cinfo->comp_info[2].ac_tbl_no == 1);
    } else if (cinfo->jpeg_color_space == JCS_CMYK) {
      JXL_CHECK(cinfo->comp_info[0].dc_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[1].dc_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[2].dc_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[3].dc_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[0].ac_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[1].ac_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[2].ac_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[3].ac_tbl_no == 0);
    } else if (cinfo->jpeg_color_space == JCS_YCCK) {
      JXL_CHECK(cinfo->comp_info[0].dc_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[1].dc_tbl_no == 1);
      JXL_CHECK(cinfo->comp_info[2].dc_tbl_no == 1);
      JXL_CHECK(cinfo->comp_info[3].dc_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[0].ac_tbl_no == 0);
      JXL_CHECK(cinfo->comp_info[1].ac_tbl_no == 1);
      JXL_CHECK(cinfo->comp_info[2].ac_tbl_no == 1);
      JXL_CHECK(cinfo->comp_info[3].ac_tbl_no == 0);
    }
    if (jparams.use_flat_dc_luma_code) {
      JHUFF_TBL* tbl = cinfo->dc_huff_tbl_ptrs[0];
      jxl::msan::UnpoisonMemory(tbl, sizeof(*tbl));
      for (int i = 0; i < 15; ++i) {
        JXL_CHECK(tbl->huffval[i] == i);
      }
    }
  }
}

void UnmapColors(uint8_t* row, size_t xsize, int components,
                 JSAMPARRAY colormap, size_t num_colors) {
  JXL_CHECK(colormap != nullptr);
  std::vector<uint8_t> tmp(xsize * components);
  for (size_t x = 0; x < xsize; ++x) {
    JXL_CHECK(row[x] < num_colors);
    for (int c = 0; c < components; ++c) {
      tmp[x * components + c] = colormap[c][row[x]];
    }
  }
  memcpy(row, tmp.data(), tmp.size());
}

void CopyCoefficients(j_decompress_ptr cinfo, jvirt_barray_ptr* coef_arrays,
                      TestImage* output) {
  output->xsize = cinfo->image_width;
  output->ysize = cinfo->image_height;
  output->components = cinfo->num_components;
  output->color_space = cinfo->out_color_space;
  j_common_ptr comptr = reinterpret_cast<j_common_ptr>(cinfo);
  for (int c = 0; c < cinfo->num_components; ++c) {
    jpeg_component_info* comp = &cinfo->comp_info[c];
    std::vector<JCOEF> coeffs(comp->width_in_blocks * comp->height_in_blocks *
                              DCTSIZE2);
    for (size_t by = 0; by < comp->height_in_blocks; ++by) {
      JBLOCKARRAY ba = (*cinfo->mem->access_virt_barray)(comptr, coef_arrays[c],
                                                         by, 1, true);
      size_t stride = comp->width_in_blocks * sizeof(JBLOCK);
      size_t offset = by * comp->width_in_blocks * DCTSIZE2;
      memcpy(&coeffs[offset], ba[0], stride);
    }
    output->coeffs.emplace_back(std::move(coeffs));
  }
}
