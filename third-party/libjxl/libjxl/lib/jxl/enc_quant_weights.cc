// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_quant_weights.h"

#include <stdio.h>
#include <stdlib.h>

#include <algorithm>
#include <cmath>
#include <limits>
#include <utility>

#include "lib/jxl/base/bits.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/common.h"
#include "lib/jxl/dct_scales.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_bit_writer.h"
#include "lib/jxl/enc_modular.h"
#include "lib/jxl/fields.h"
#include "lib/jxl/image.h"
#include "lib/jxl/modular/encoding/encoding.h"
#include "lib/jxl/modular/options.h"

namespace jxl {

struct AuxOut;

namespace {

Status EncodeDctParams(const DctQuantWeightParams& params, BitWriter* writer) {
  JXL_ASSERT(params.num_distance_bands >= 1);
  writer->Write(DctQuantWeightParams::kLog2MaxDistanceBands,
                params.num_distance_bands - 1);
  for (size_t c = 0; c < 3; c++) {
    for (size_t i = 0; i < params.num_distance_bands; i++) {
      JXL_RETURN_IF_ERROR(F16Coder::Write(
          params.distance_bands[c][i] * (i == 0 ? (1 / 64.0f) : 1.0f), writer));
    }
  }
  return true;
}

Status EncodeQuant(const QuantEncoding& encoding, size_t idx, size_t size_x,
                   size_t size_y, BitWriter* writer,
                   ModularFrameEncoder* modular_frame_encoder) {
  writer->Write(kLog2NumQuantModes, encoding.mode);
  size_x *= kBlockDim;
  size_y *= kBlockDim;
  switch (encoding.mode) {
    case QuantEncoding::kQuantModeLibrary: {
      writer->Write(kCeilLog2NumPredefinedTables, encoding.predefined);
      break;
    }
    case QuantEncoding::kQuantModeID: {
      for (size_t c = 0; c < 3; c++) {
        for (size_t i = 0; i < 3; i++) {
          JXL_RETURN_IF_ERROR(
              F16Coder::Write(encoding.idweights[c][i] * (1.0f / 64), writer));
        }
      }
      break;
    }
    case QuantEncoding::kQuantModeDCT2: {
      for (size_t c = 0; c < 3; c++) {
        for (size_t i = 0; i < 6; i++) {
          JXL_RETURN_IF_ERROR(F16Coder::Write(
              encoding.dct2weights[c][i] * (1.0f / 64), writer));
        }
      }
      break;
    }
    case QuantEncoding::kQuantModeDCT4X8: {
      for (size_t c = 0; c < 3; c++) {
        JXL_RETURN_IF_ERROR(
            F16Coder::Write(encoding.dct4x8multipliers[c], writer));
      }
      JXL_RETURN_IF_ERROR(EncodeDctParams(encoding.dct_params, writer));
      break;
    }
    case QuantEncoding::kQuantModeDCT4: {
      for (size_t c = 0; c < 3; c++) {
        for (size_t i = 0; i < 2; i++) {
          JXL_RETURN_IF_ERROR(
              F16Coder::Write(encoding.dct4multipliers[c][i], writer));
        }
      }
      JXL_RETURN_IF_ERROR(EncodeDctParams(encoding.dct_params, writer));
      break;
    }
    case QuantEncoding::kQuantModeDCT: {
      JXL_RETURN_IF_ERROR(EncodeDctParams(encoding.dct_params, writer));
      break;
    }
    case QuantEncoding::kQuantModeRAW: {
      ModularFrameEncoder::EncodeQuantTable(size_x, size_y, writer, encoding,
                                            idx, modular_frame_encoder);
      break;
    }
    case QuantEncoding::kQuantModeAFV: {
      for (size_t c = 0; c < 3; c++) {
        for (size_t i = 0; i < 9; i++) {
          JXL_RETURN_IF_ERROR(F16Coder::Write(
              encoding.afv_weights[c][i] * (i < 6 ? 1.0f / 64 : 1.0f), writer));
        }
      }
      JXL_RETURN_IF_ERROR(EncodeDctParams(encoding.dct_params, writer));
      JXL_RETURN_IF_ERROR(EncodeDctParams(encoding.dct_params_afv_4x4, writer));
      break;
    }
  }
  return true;
}

}  // namespace

Status DequantMatricesEncode(const DequantMatrices* matrices, BitWriter* writer,
                             size_t layer, AuxOut* aux_out,
                             ModularFrameEncoder* modular_frame_encoder) {
  bool all_default = true;
  const std::vector<QuantEncoding>& encodings = matrices->encodings();

  for (size_t i = 0; i < encodings.size(); i++) {
    if (encodings[i].mode != QuantEncoding::kQuantModeLibrary ||
        encodings[i].predefined != 0) {
      all_default = false;
    }
  }
  // TODO(janwas): better bound
  BitWriter::Allotment allotment(writer, 512 * 1024);
  writer->Write(1, all_default);
  if (!all_default) {
    for (size_t i = 0; i < encodings.size(); i++) {
      JXL_RETURN_IF_ERROR(EncodeQuant(
          encodings[i], i, DequantMatrices::required_size_x[i],
          DequantMatrices::required_size_y[i], writer, modular_frame_encoder));
    }
  }
  allotment.ReclaimAndCharge(writer, layer, aux_out);
  return true;
}

Status DequantMatricesEncodeDC(const DequantMatrices* matrices,
                               BitWriter* writer, size_t layer,
                               AuxOut* aux_out) {
  bool all_default = true;
  const float* dc_quant = matrices->DCQuants();
  for (size_t c = 0; c < 3; c++) {
    if (dc_quant[c] != kDCQuant[c]) {
      all_default = false;
    }
  }
  BitWriter::Allotment allotment(writer, 1 + sizeof(float) * kBitsPerByte * 3);
  writer->Write(1, all_default);
  if (!all_default) {
    for (size_t c = 0; c < 3; c++) {
      JXL_RETURN_IF_ERROR(F16Coder::Write(dc_quant[c] * 128.0f, writer));
    }
  }
  allotment.ReclaimAndCharge(writer, layer, aux_out);
  return true;
}

void DequantMatricesSetCustomDC(DequantMatrices* matrices, const float* dc) {
  matrices->SetDCQuant(dc);
  // Roundtrip encode/decode DC to ensure same values as decoder.
  BitWriter writer;
  JXL_CHECK(DequantMatricesEncodeDC(matrices, &writer, 0, nullptr));
  writer.ZeroPadToByte();
  BitReader br(writer.GetSpan());
  // Called only in the encoder: should fail only for programmer errors.
  JXL_CHECK(matrices->DecodeDC(&br));
  JXL_CHECK(br.Close());
}

void DequantMatricesScaleDC(DequantMatrices* matrices, const float scale) {
  float dc[3];
  for (size_t c = 0; c < 3; ++c) {
    dc[c] = matrices->InvDCQuant(c) * (1.0f / scale);
  }
  DequantMatricesSetCustomDC(matrices, dc);
}

void DequantMatricesRoundtrip(DequantMatrices* matrices) {
  // Do not pass modular en/decoder, as they only change entropy and not
  // values.
  BitWriter writer;
  JXL_CHECK(DequantMatricesEncode(matrices, &writer, 0, nullptr));
  writer.ZeroPadToByte();
  BitReader br(writer.GetSpan());
  // Called only in the encoder: should fail only for programmer errors.
  JXL_CHECK(matrices->Decode(&br));
  JXL_CHECK(br.Close());
}

void DequantMatricesSetCustom(DequantMatrices* matrices,
                              const std::vector<QuantEncoding>& encodings,
                              ModularFrameEncoder* encoder) {
  JXL_ASSERT(encodings.size() == DequantMatrices::kNum);
  matrices->SetEncodings(encodings);
  for (size_t i = 0; i < encodings.size(); i++) {
    if (encodings[i].mode == QuantEncodingInternal::kQuantModeRAW) {
      encoder->AddQuantTable(DequantMatrices::required_size_x[i] * kBlockDim,
                             DequantMatrices::required_size_y[i] * kBlockDim,
                             encodings[i], i);
    }
  }
  DequantMatricesRoundtrip(matrices);
}

}  // namespace jxl
