// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_icc_codec.h"

#include <stdint.h>

#include <map>
#include <string>
#include <vector>

#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/common.h"
#include "lib/jxl/enc_ans.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/fields.h"
#include "lib/jxl/icc_codec_common.h"

namespace jxl {
namespace {

// Unshuffles or de-interleaves bytes, for example with width 2, turns
// "AaBbCcDc" into "ABCDabcd", this for example de-interleaves UTF-16 bytes into
// first all the high order bytes, then all the low order bytes.
// Transposes a matrix of width columns and ceil(size / width) rows. There are
// size elements, size may be < width * height, if so the
// last elements of the bottom row are missing, the missing spots are
// transposed along with the filled spots, and the result has the missing
// elements at the bottom of the rightmost column. The input is the input matrix
// in scanline order, the output is the result matrix in scanline order, with
// missing elements skipped over (this may occur at multiple positions).
void Unshuffle(uint8_t* data, size_t size, size_t width) {
  size_t height = (size + width - 1) / width;  // amount of rows of input
  PaddedBytes result(size);
  // i = input index, j output index
  size_t s = 0, j = 0;
  for (size_t i = 0; i < size; i++) {
    result[j] = data[i];
    j += height;
    if (j >= size) j = ++s;
  }

  for (size_t i = 0; i < size; i++) {
    data[i] = result[i];
  }
}

// This is performed by the encoder, the encoder must be able to encode any
// random byte stream (not just byte streams that are a valid ICC profile), so
// an error returned by this function is an implementation error.
Status PredictAndShuffle(size_t stride, size_t width, int order, size_t num,
                         const uint8_t* data, size_t size, size_t* pos,
                         PaddedBytes* result) {
  JXL_RETURN_IF_ERROR(CheckOutOfBounds(*pos, num, size));
  // Required by the specification, see decoder. stride * 4 must be < *pos.
  if (!*pos || ((*pos - 1u) >> 2u) < stride) {
    return JXL_FAILURE("Invalid stride");
  }
  if (*pos < stride * 4) return JXL_FAILURE("Too large stride");
  size_t start = result->size();
  for (size_t i = 0; i < num; i++) {
    uint8_t predicted =
        LinearPredictICCValue(data, *pos, i, stride, width, order);
    result->push_back(data[*pos + i] - predicted);
  }
  *pos += num;
  if (width > 1) Unshuffle(result->data() + start, num, width);
  return true;
}
}  // namespace

// Outputs a transformed form of the given icc profile. The result itself is
// not particularly smaller than the input data in bytes, but it will be in a
// form that is easier to compress (more zeroes, ...) and will compress better
// with brotli.
Status PredictICC(const uint8_t* icc, size_t size, PaddedBytes* result) {
  PaddedBytes commands;
  PaddedBytes data;

  EncodeVarInt(size, result);

  // Header
  PaddedBytes header = ICCInitialHeaderPrediction();
  EncodeUint32(0, size, &header);
  for (size_t i = 0; i < kICCHeaderSize && i < size; i++) {
    ICCPredictHeader(icc, size, header.data(), i);
    data.push_back(icc[i] - header[i]);
  }
  if (size <= kICCHeaderSize) {
    EncodeVarInt(0, result);  // 0 commands
    for (size_t i = 0; i < data.size(); i++) {
      result->push_back(data[i]);
    }
    return true;
  }

  std::vector<Tag> tags;
  std::vector<size_t> tagstarts;
  std::vector<size_t> tagsizes;
  std::map<size_t, size_t> tagmap;

  // Tag list
  size_t pos = kICCHeaderSize;
  if (pos + 4 <= size) {
    uint64_t numtags = DecodeUint32(icc, size, pos);
    pos += 4;
    EncodeVarInt(numtags + 1, &commands);
    uint64_t prevtagstart = kICCHeaderSize + numtags * 12;
    uint32_t prevtagsize = 0;
    for (size_t i = 0; i < numtags; i++) {
      if (pos + 12 > size) break;

      Tag tag = DecodeKeyword(icc, size, pos + 0);
      uint32_t tagstart = DecodeUint32(icc, size, pos + 4);
      uint32_t tagsize = DecodeUint32(icc, size, pos + 8);
      pos += 12;

      tags.push_back(tag);
      tagstarts.push_back(tagstart);
      tagsizes.push_back(tagsize);
      tagmap[tagstart] = tags.size() - 1;

      uint8_t tagcode = kCommandTagUnknown;
      for (size_t j = 0; j < kNumTagStrings; j++) {
        if (tag == *kTagStrings[j]) {
          tagcode = j + kCommandTagStringFirst;
          break;
        }
      }

      if (tag == kRtrcTag && pos + 24 < size) {
        bool ok = true;
        ok &= DecodeKeyword(icc, size, pos + 0) == kGtrcTag;
        ok &= DecodeKeyword(icc, size, pos + 12) == kBtrcTag;
        if (ok) {
          for (size_t kk = 0; kk < 8; kk++) {
            if (icc[pos - 8 + kk] != icc[pos + 4 + kk]) ok = false;
            if (icc[pos - 8 + kk] != icc[pos + 16 + kk]) ok = false;
          }
        }
        if (ok) {
          tagcode = kCommandTagTRC;
          pos += 24;
          i += 2;
        }
      }

      if (tag == kRxyzTag && pos + 24 < size) {
        bool ok = true;
        ok &= DecodeKeyword(icc, size, pos + 0) == kGxyzTag;
        ok &= DecodeKeyword(icc, size, pos + 12) == kBxyzTag;
        uint32_t offsetr = tagstart;
        uint32_t offsetg = DecodeUint32(icc, size, pos + 4);
        uint32_t offsetb = DecodeUint32(icc, size, pos + 16);
        uint32_t sizer = tagsize;
        uint32_t sizeg = DecodeUint32(icc, size, pos + 8);
        uint32_t sizeb = DecodeUint32(icc, size, pos + 20);
        ok &= sizer == 20;
        ok &= sizeg == 20;
        ok &= sizeb == 20;
        ok &= (offsetg == offsetr + 20);
        ok &= (offsetb == offsetr + 40);
        if (ok) {
          tagcode = kCommandTagXYZ;
          pos += 24;
          i += 2;
        }
      }

      uint8_t command = tagcode;
      uint64_t predicted_tagstart = prevtagstart + prevtagsize;
      if (predicted_tagstart != tagstart) command |= kFlagBitOffset;
      size_t predicted_tagsize = prevtagsize;
      if (tag == kRxyzTag || tag == kGxyzTag || tag == kBxyzTag ||
          tag == kKxyzTag || tag == kWtptTag || tag == kBkptTag ||
          tag == kLumiTag) {
        predicted_tagsize = 20;
      }
      if (predicted_tagsize != tagsize) command |= kFlagBitSize;
      commands.push_back(command);
      if (tagcode == 1) {
        AppendKeyword(tag, &data);
      }
      if (command & kFlagBitOffset) EncodeVarInt(tagstart, &commands);
      if (command & kFlagBitSize) EncodeVarInt(tagsize, &commands);

      prevtagstart = tagstart;
      prevtagsize = tagsize;
    }
  }
  // Indicate end of tag list or varint indicating there's none
  commands.push_back(0);

  // Main content
  // The main content in a valid ICC profile contains tagged elements, with the
  // tag types (4 letter names) given by the tag list above, and the tag list
  // pointing to the start and indicating the size of each tagged element. It is
  // allowed for tagged elements to overlap, e.g. the curve for R, G and B could
  // all point to the same one.
  Tag tag;
  size_t tagstart = 0, tagsize = 0, clutstart = 0;

  size_t last0 = pos;
  // This loop appends commands to the output, processing some sub-section of a
  // current tagged element each time. We need to keep track of the tagtype of
  // the current element, and update it when we encounter the boundary of a
  // next one.
  // It is not required that the input data is a valid ICC profile, if the
  // encoder does not recognize the data it will still be able to output bytes
  // but will not predict as well.
  while (pos <= size) {
    size_t last1 = pos;
    PaddedBytes commands_add;
    PaddedBytes data_add;

    // This means the loop brought the position beyond the tag end.
    if (pos > tagstart + tagsize) {
      tag = {{0, 0, 0, 0}};  // nonsensical value
    }

    if (commands_add.empty() && data_add.empty() && tagmap.count(pos) &&
        pos + 4 <= size) {
      size_t index = tagmap[pos];
      tag = DecodeKeyword(icc, size, pos);
      tagstart = tagstarts[index];
      tagsize = tagsizes[index];

      if (tag == kMlucTag && pos + tagsize <= size && tagsize > 8 &&
          icc[pos + 4] == 0 && icc[pos + 5] == 0 && icc[pos + 6] == 0 &&
          icc[pos + 7] == 0) {
        size_t num = tagsize - 8;
        commands_add.push_back(kCommandTypeStartFirst + 3);
        pos += 8;
        commands_add.push_back(kCommandShuffle2);
        EncodeVarInt(num, &commands_add);
        size_t start = data_add.size();
        for (size_t i = 0; i < num; i++) {
          data_add.push_back(icc[pos]);
          pos++;
        }
        Unshuffle(data_add.data() + start, num, 2);
      }

      if (tag == kCurvTag && pos + tagsize <= size && tagsize > 8 &&
          icc[pos + 4] == 0 && icc[pos + 5] == 0 && icc[pos + 6] == 0 &&
          icc[pos + 7] == 0) {
        size_t num = tagsize - 8;
        if (num > 16 && num < (1 << 28) && pos + num <= size && pos > 0) {
          commands_add.push_back(kCommandTypeStartFirst + 5);
          pos += 8;
          commands_add.push_back(kCommandPredict);
          int order = 1, width = 2, stride = width;
          commands_add.push_back((order << 2) | (width - 1));
          EncodeVarInt(num, &commands_add);
          JXL_RETURN_IF_ERROR(PredictAndShuffle(stride, width, order, num, icc,
                                                size, &pos, &data_add));
        }
      }
    }

    if (tag == kMab_Tag || tag == kMba_Tag) {
      Tag subTag = DecodeKeyword(icc, size, pos);
      if (pos + 12 < size && (subTag == kCurvTag || subTag == kVcgtTag) &&
          DecodeUint32(icc, size, pos + 4) == 0) {
        uint32_t num = DecodeUint32(icc, size, pos + 8) * 2;
        if (num > 16 && num < (1 << 28) && pos + 12 + num <= size) {
          pos += 12;
          last1 = pos;
          commands_add.push_back(kCommandPredict);
          int order = 1, width = 2, stride = width;
          commands_add.push_back((order << 2) | (width - 1));
          EncodeVarInt(num, &commands_add);
          JXL_RETURN_IF_ERROR(PredictAndShuffle(stride, width, order, num, icc,
                                                size, &pos, &data_add));
        }
      }

      if (pos == tagstart + 24 && pos + 4 < size) {
        // Note that this value can be remembered for next iterations of the
        // loop, so the "pos == clutstart" if below can trigger during a later
        // iteration.
        clutstart = tagstart + DecodeUint32(icc, size, pos);
      }

      if (pos == clutstart && clutstart + 16 < size) {
        size_t numi = icc[tagstart + 8];
        size_t numo = icc[tagstart + 9];
        size_t width = icc[clutstart + 16];
        size_t stride = width * numo;
        size_t num = width * numo;
        for (size_t i = 0; i < numi && clutstart + i < size; i++) {
          num *= icc[clutstart + i];
        }
        if ((width == 1 || width == 2) && num > 64 && num < (1 << 28) &&
            pos + num <= size && pos > stride * 4) {
          commands_add.push_back(kCommandPredict);
          int order = 1;
          uint8_t flags =
              (order << 2) | (width - 1) | (stride == width ? 0 : 16);
          commands_add.push_back(flags);
          if (flags & 16) EncodeVarInt(stride, &commands_add);
          EncodeVarInt(num, &commands_add);
          JXL_RETURN_IF_ERROR(PredictAndShuffle(stride, width, order, num, icc,
                                                size, &pos, &data_add));
        }
      }
    }

    if (commands_add.empty() && data_add.empty() && tag == kGbd_Tag &&
        pos == tagstart + 8 && pos + tagsize - 8 <= size && pos > 16 &&
        tagsize > 8) {
      size_t width = 4, order = 0, stride = width;
      size_t num = tagsize - 8;
      uint8_t flags = (order << 2) | (width - 1) | (stride == width ? 0 : 16);
      commands_add.push_back(kCommandPredict);
      commands_add.push_back(flags);
      if (flags & 16) EncodeVarInt(stride, &commands_add);
      EncodeVarInt(num, &commands_add);
      JXL_RETURN_IF_ERROR(PredictAndShuffle(stride, width, order, num, icc,
                                            size, &pos, &data_add));
    }

    if (commands_add.empty() && data_add.empty() && pos + 20 <= size) {
      Tag subTag = DecodeKeyword(icc, size, pos);
      if (subTag == kXyz_Tag && DecodeUint32(icc, size, pos + 4) == 0) {
        commands_add.push_back(kCommandXYZ);
        pos += 8;
        for (size_t j = 0; j < 12; j++) data_add.push_back(icc[pos++]);
      }
    }

    if (commands_add.empty() && data_add.empty() && pos + 8 <= size) {
      if (DecodeUint32(icc, size, pos + 4) == 0) {
        Tag subTag = DecodeKeyword(icc, size, pos);
        for (size_t i = 0; i < kNumTypeStrings; i++) {
          if (subTag == *kTypeStrings[i]) {
            commands_add.push_back(kCommandTypeStartFirst + i);
            pos += 8;
            break;
          }
        }
      }
    }

    if (!(commands_add.empty() && data_add.empty()) || pos == size) {
      if (last0 < last1) {
        commands.push_back(kCommandInsert);
        EncodeVarInt(last1 - last0, &commands);
        while (last0 < last1) {
          data.push_back(icc[last0++]);
        }
      }
      for (size_t i = 0; i < commands_add.size(); i++) {
        commands.push_back(commands_add[i]);
      }
      for (size_t i = 0; i < data_add.size(); i++) {
        data.push_back(data_add[i]);
      }
      last0 = pos;
    }
    if (commands_add.empty() && data_add.empty()) {
      pos++;
    }
  }

  EncodeVarInt(commands.size(), result);
  for (size_t i = 0; i < commands.size(); i++) {
    result->push_back(commands[i]);
  }
  for (size_t i = 0; i < data.size(); i++) {
    result->push_back(data[i]);
  }

  return true;
}

Status WriteICC(const PaddedBytes& icc, BitWriter* JXL_RESTRICT writer,
                size_t layer, AuxOut* JXL_RESTRICT aux_out) {
  if (icc.empty()) return JXL_FAILURE("ICC must be non-empty");
  PaddedBytes enc;
  JXL_RETURN_IF_ERROR(PredictICC(icc.data(), icc.size(), &enc));
  std::vector<std::vector<Token>> tokens(1);
  BitWriter::Allotment allotment(writer, 128);
  JXL_RETURN_IF_ERROR(U64Coder::Write(enc.size(), writer));
  allotment.ReclaimAndCharge(writer, layer, aux_out);

  for (size_t i = 0; i < enc.size(); i++) {
    tokens[0].emplace_back(
        ICCANSContext(i, i > 0 ? enc[i - 1] : 0, i > 1 ? enc[i - 2] : 0),
        enc[i]);
  }
  HistogramParams params;
  params.lz77_method = enc.size() < 4096 ? HistogramParams::LZ77Method::kOptimal
                                         : HistogramParams::LZ77Method::kLZ77;
  EntropyEncodingData code;
  std::vector<uint8_t> context_map;
  params.force_huffman = true;
  BuildAndEncodeHistograms(params, kNumICCContexts, tokens, &code, &context_map,
                           writer, layer, aux_out);
  WriteTokens(tokens[0], code, context_map, writer, layer, aux_out);
  return true;
}

}  // namespace jxl
