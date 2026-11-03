// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_file.h"

#include <stddef.h>

#include <type_traits>
#include <utility>
#include <vector>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/coeff_order_fwd.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_bit_writer.h"
#include "lib/jxl/enc_cache.h"
#include "lib/jxl/enc_fields.h"
#include "lib/jxl/enc_frame.h"
#include "lib/jxl/enc_icc_codec.h"
#include "lib/jxl/frame_header.h"
#include "lib/jxl/headers.h"
#include "lib/jxl/image_bundle.h"

namespace jxl {

namespace {

Status PrepareCodecMetadataFromIO(const CompressParams& cparams,
                                  const CodecInOut* io,
                                  CodecMetadata* metadata) {
  *metadata = io->metadata;
  size_t ups = 1;
  if (cparams.already_downsampled) ups = cparams.resampling;

  JXL_RETURN_IF_ERROR(metadata->size.Set(io->xsize() * ups, io->ysize() * ups));

  // Keep ICC profile in lossless modes because a reconstructed profile may be
  // slightly different (quantization).
  // Also keep ICC in JPEG reconstruction mode as we need byte-exact profiles.
  if (!cparams.IsLossless() && !io->Main().IsJPEG() && cparams.cms_set) {
    metadata->m.color_encoding.DecideIfWantICC(cparams.cms);
  }

  metadata->m.xyb_encoded =
      cparams.color_transform == ColorTransform::kXYB ? true : false;

  // TODO(firsching): move this EncodeFile to test_utils / re-implement this
  // using API functions
  return true;
}

}  // namespace

Status EncodePreview(const CompressParams& cparams, const ImageBundle& ib,
                     const CodecMetadata* metadata, const JxlCmsInterface& cms,
                     ThreadPool* pool, BitWriter* JXL_RESTRICT writer) {
  BitWriter preview_writer;
  // TODO(janwas): also support generating preview by downsampling
  if (ib.HasColor()) {
    AuxOut aux_out;
    PassesEncoderState passes_enc_state;
    // TODO(lode): check if we want all extra channels and matching xyb_encoded
    // for the preview, such that using the main ImageMetadata object for
    // encoding this frame is warrented.
    FrameInfo frame_info;
    frame_info.is_preview = true;
    JXL_RETURN_IF_ERROR(EncodeFrame(cparams, frame_info, metadata, ib,
                                    &passes_enc_state, cms, pool,
                                    &preview_writer, &aux_out));
    preview_writer.ZeroPadToByte();
  }

  if (preview_writer.BitsWritten() != 0) {
    writer->ZeroPadToByte();
    writer->AppendByteAligned(preview_writer);
  }

  return true;
}

Status EncodeFile(const CompressParams& params, const CodecInOut* io,
                  PassesEncoderState* passes_enc_state, PaddedBytes* compressed,
                  const JxlCmsInterface& cms, AuxOut* aux_out,
                  ThreadPool* pool) {
  io->CheckMetadata();
  BitWriter writer;

  CompressParams cparams = params;
  if (io->Main().color_transform != ColorTransform::kNone) {
    // Set the color transform to YCbCr or XYB if the original image is such.
    cparams.color_transform = io->Main().color_transform;
  }

  JXL_RETURN_IF_ERROR(ParamsPostInit(&cparams));

  std::unique_ptr<CodecMetadata> metadata = jxl::make_unique<CodecMetadata>();
  JXL_RETURN_IF_ERROR(PrepareCodecMetadataFromIO(cparams, io, metadata.get()));
  JXL_RETURN_IF_ERROR(WriteCodestreamHeaders(metadata.get(), &writer, aux_out));

  // Only send ICC (at least several hundred bytes) if fields aren't enough.
  if (metadata->m.color_encoding.WantICC()) {
    JXL_RETURN_IF_ERROR(WriteICC(metadata->m.color_encoding.ICC(), &writer,
                                 kLayerHeader, aux_out));
  }

  if (metadata->m.have_preview) {
    JXL_RETURN_IF_ERROR(EncodePreview(cparams, io->preview_frame,
                                      metadata.get(), cms, pool, &writer));
  }

  // Each frame should start on byte boundaries.
  BitWriter::Allotment allotment(&writer, 8);
  writer.ZeroPadToByte();
  allotment.ReclaimAndCharge(&writer, kLayerHeader, aux_out);

  for (size_t i = 0; i < io->frames.size(); i++) {
    FrameInfo info;
    info.is_last = i == io->frames.size() - 1;
    if (io->frames[i].use_for_next_frame) {
      info.save_as_reference = 1;
    }
    JXL_RETURN_IF_ERROR(EncodeFrame(cparams, info, metadata.get(),
                                    io->frames[i], passes_enc_state, cms, pool,
                                    &writer, aux_out));
  }

  // Clean up passes_enc_state in case it gets reused.
  for (size_t i = 0; i < 4; i++) {
    passes_enc_state->shared.dc_frames[i] = Image3F();
    passes_enc_state->shared.reference_frames[i].frame = ImageBundle();
  }

  *compressed = std::move(writer).TakeBytes();
  return true;
}

}  // namespace jxl
