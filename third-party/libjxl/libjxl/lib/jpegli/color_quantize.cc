// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/color_quantize.h"

#include <cmath>
#include <limits>
#include <unordered_map>

#include "lib/jpegli/decode_internal.h"
#include "lib/jpegli/error.h"

namespace jpegli {

namespace {

static constexpr int kNumColorCellBits[kMaxComponents] = {3, 4, 3, 3};
static constexpr int kCompW[kMaxComponents] = {2, 3, 1, 1};

int Pow(int a, int b) {
  int r = 1;
  for (int i = 0; i < b; ++i) {
    r *= a;
  }
  return r;
}

int ComponentOrder(j_decompress_ptr cinfo, int i) {
  if (cinfo->out_color_components == 3) {
    return i < 2 ? 1 - i : i;
  }
  return i;
}

int GetColorComponent(int i, int N) {
  return (i * 255 + (N - 1) / 2) / (N - 1);
}

}  // namespace

void ChooseColorMap1Pass(j_decompress_ptr cinfo) {
  jpeg_decomp_master* m = cinfo->master;
  int components = cinfo->out_color_components;
  int desired = std::min(cinfo->desired_number_of_colors, 256);
  int num = 1;
  while (Pow(num + 1, components) <= desired) {
    ++num;
  }
  if (num == 1) {
    JPEGLI_ERROR("Too few colors (%d) in requested colormap", desired);
  }
  int actual = Pow(num, components);
  for (int i = 0; i < components; ++i) {
    m->num_colors_[i] = num;
  }
  while (actual < desired) {
    int total = actual;
    for (int i = 0; i < components; ++i) {
      int c = ComponentOrder(cinfo, i);
      int new_total = (actual / m->num_colors_[c]) * (m->num_colors_[c] + 1);
      if (new_total <= desired) {
        ++m->num_colors_[c];
        actual = new_total;
      }
    }
    if (actual == total) {
      break;
    }
  }
  cinfo->actual_number_of_colors = actual;
  cinfo->colormap = (*cinfo->mem->alloc_sarray)(
      reinterpret_cast<j_common_ptr>(cinfo), JPOOL_IMAGE, actual, components);
  int next_color[kMaxComponents] = {0};
  for (int i = 0; i < actual; ++i) {
    for (int c = 0; c < components; ++c) {
      cinfo->colormap[c][i] =
          GetColorComponent(next_color[c], m->num_colors_[c]);
    }
    int c = components - 1;
    while (c > 0 && next_color[c] + 1 == m->num_colors_[c]) {
      next_color[c--] = 0;
    }
    ++next_color[c];
  }
  if (!m->colormap_lut_) {
    m->colormap_lut_ = Allocate<uint8_t>(cinfo, components * 256, JPOOL_IMAGE);
  }
  int stride = actual;
  for (int c = 0; c < components; ++c) {
    int N = m->num_colors_[c];
    stride /= N;
    for (int i = 0; i < 256; ++i) {
      int index = ((2 * i - 1) * (N - 1) + 254) / 510;
      m->colormap_lut_[c * 256 + i] = index * stride;
    }
  }
}

namespace {

// 2^13 priority levels for the PQ seems to be a good compromise between
// accuracy, running time and stack space usage.
static const int kMaxPriority = 1 << 13;
static const int kMaxLevel = 3;

// This function is used in the multi-resolution grid to be able to compute
// the keys for the different resolutions by just shifting the first key.
inline int InterlaceBitsRGB(uint8_t r, uint8_t g, uint8_t b) {
  int z = 0;
  for (int i = 0; i < 7; ++i) {
    z += (r >> 5) & 4;
    z += (g >> 6) & 2;
    z += (b >> 7);
    z <<= 3;
    r <<= 1;
    g <<= 1;
    b <<= 1;
  }
  z += (r >> 5) & 4;
  z += (g >> 6) & 2;
  z += (b >> 7);
  return z;
}

// This function will compute the actual priorities of the colors based on
// the current distance from the palette, the population count and the signals
// from the multi-resolution grid.
inline int Priority(int d, int n, const int* density, const int* radius) {
  int p = d * n;
  for (int level = 0; level < kMaxLevel; ++level) {
    if (d > radius[level]) {
      p += density[level] * (d - radius[level]);
    }
  }
  return std::min(kMaxPriority - 1, p >> 4);
}

inline int ColorIntQuadDistanceRGB(uint8_t r1, uint8_t g1, uint8_t b1,
                                   uint8_t r2, uint8_t g2, uint8_t b2) {
  // weights for the intensity calculation
  static constexpr int ired = 2;
  static constexpr int igreen = 5;
  static constexpr int iblue = 1;
  // normalization factor for the intensity calculation (2^ishift)
  static constexpr int ishift = 3;
  const int rd = r1 - r2;
  const int gd = g1 - g2;
  const int bd = b1 - b2;
  const int id = ired * rd + igreen * gd + iblue * bd;
  return rd * rd + gd * gd + bd * bd + ((id * id) >> (2 * ishift));
}

inline int ScaleQuadDistanceRGB(int d) {
  return static_cast<int>(sqrt(d * 0.25) + 0.5);
}

// The function updates the minimal distances, the clustering and the
// quantization error after the insertion of the new color into the palette.
void AddToRGBPalette(const uint8_t* red, const uint8_t* green,
                     const uint8_t* blue,
                     const int* count,  // histogram of colors
                     const int index,   // index of color to be added
                     const int k,       // size of current palette
                     const int n,       // number of colors
                     int* dist,         // array of distances from palette
                     int* cluster,      // mapping of color indices to palette
                     int* center,       // the inverse mapping
                     int64_t* error) {  // measure of the quantization error
  center[k] = index;
  cluster[index] = k;
  *error -=
      static_cast<int64_t>(dist[index]) * static_cast<int64_t>(count[index]);
  dist[index] = 0;
  for (int j = 0; j < n; ++j) {
    if (dist[j] > 0) {
      const int d = ColorIntQuadDistanceRGB(
          red[index], green[index], blue[index], red[j], green[j], blue[j]);
      if (d < dist[j]) {
        *error += static_cast<int64_t>((d - dist[j])) *
                  static_cast<int64_t>(count[j]);
        dist[j] = d;
        cluster[j] = k;
      }
    }
  }
}

struct RGBPixelHasher {
  // A quick but good-enough hash to get 24 bits of RGB into the lower 12 bits.
  size_t operator()(uint32_t a) const { return (a ^ (a >> 12)) * 0x9e3779b9; }
};

struct WangHasher {
  // Thomas Wang's Hash.  Nearly perfect and still quite fast.  Above (for
  // pixels) we use a simpler hash because the number of hash calls is
  // proportional to the number of pixels and that hash dominates; we want the
  // cost to be minimal and we start with a large table.  We can use a better
  // hash for the histogram since the number of hash calls is proportional to
  // the number of unique colors in the image, which is hopefully much smaller.
  // Note that the difference is slight; e.g. replacing RGBPixelHasher with
  // WangHasher only slows things down by 5% on an Opteron.
  size_t operator()(uint32_t a) const {
    a = (a ^ 61) ^ (a >> 16);
    a = a + (a << 3);
    a = a ^ (a >> 4);
    a = a * 0x27d4eb2d;
    a = a ^ (a >> 15);
    return a;
  }
};

// Build an index of all the different colors in the input
// image. To do this we map the 24 bit RGB representation of the colors
// to a unique integer index assigned to the different colors in order of
// appearence in the image.  Return the number of unique colors found.
// The colors are pre-quantized to 3 * 6 bits precision.
static int BuildRGBColorIndex(const uint8_t* const image, int const num_pixels,
                              int* const count, uint8_t* const red,
                              uint8_t* const green, uint8_t* const blue) {
  // Impossible because rgb are in the low 24 bits, and the upper 8 bits is 0.
  const uint32_t impossible_pixel_value = 0x10000000;
  std::unordered_map<uint32_t, int, RGBPixelHasher> index_map(1 << 12);
  std::unordered_map<uint32_t, int, RGBPixelHasher>::iterator index_map_lookup;
  const uint8_t* imagep = &image[0];
  uint32_t prev_pixel = impossible_pixel_value;
  int index = 0;
  int n = 0;
  for (int i = 0; i < num_pixels; ++i) {
    uint8_t r = ((*imagep++) & 0xfc) + 2;
    uint8_t g = ((*imagep++) & 0xfc) + 2;
    uint8_t b = ((*imagep++) & 0xfc) + 2;
    uint32_t pixel = (b << 16) | (g << 8) | r;
    if (pixel != prev_pixel) {
      prev_pixel = pixel;
      index_map_lookup = index_map.find(pixel);
      if (index_map_lookup != index_map.end()) {
        index = index_map_lookup->second;
      } else {
        index_map[pixel] = index = n++;
        red[index] = r;
        green[index] = g;
        blue[index] = b;
      }
    }
    ++count[index];
  }
  return n;
}

}  // namespace

void ChooseColorMap2Pass(j_decompress_ptr cinfo) {
  if (cinfo->out_color_space != JCS_RGB) {
    JPEGLI_ERROR("Two-pass quantizer must use RGB output color space.");
  }
  jpeg_decomp_master* m = cinfo->master;
  const size_t num_pixels = cinfo->output_width * cinfo->output_height;
  const int max_color_count = std::max<size_t>(num_pixels, 1u << 18);
  const int max_palette_size = cinfo->desired_number_of_colors;
  std::unique_ptr<uint8_t[]> red(new uint8_t[max_color_count]);
  std::unique_ptr<uint8_t[]> green(new uint8_t[max_color_count]);
  std::unique_ptr<uint8_t[]> blue(new uint8_t[max_color_count]);
  std::vector<int> count(max_color_count, 0);
  // number of colors
  int n = BuildRGBColorIndex(m->pixels_, num_pixels, &count[0], &red[0],
                             &green[0], &blue[0]);

  std::vector<int> dist(n, std::numeric_limits<int>::max());
  std::vector<int> cluster(n);
  std::vector<bool> in_palette(n, false);
  int center[256];
  int k = 0;  // palette size
  const int count_threshold = (num_pixels * 4) / max_palette_size;
  static constexpr int kAveragePixelErrorThreshold = 1;
  const int64_t error_threshold = num_pixels * kAveragePixelErrorThreshold;
  int64_t error = 0;  // quantization error

  int max_count = 0;
  int winner = 0;
  for (int i = 0; i < n; ++i) {
    if (count[i] > max_count) {
      max_count = count[i];
      winner = i;
    }
    if (!in_palette[i] && count[i] > count_threshold) {
      AddToRGBPalette(&red[0], &green[0], &blue[0], &count[0], i, k++, n,
                      &dist[0], &cluster[0], &center[0], &error);
      in_palette[i] = true;
    }
  }
  if (k == 0) {
    AddToRGBPalette(&red[0], &green[0], &blue[0], &count[0], winner, k++, n,
                    &dist[0], &cluster[0], &center[0], &error);
    in_palette[winner] = true;
  }

  // Calculation of the multi-resolution density grid.
  std::vector<int> density(n * kMaxLevel);
  std::vector<int> radius(n * kMaxLevel);
  std::unordered_map<uint32_t, int, WangHasher> histogram[kMaxLevel];
  for (int level = 0; level < kMaxLevel; ++level) {
    // This value is never used because key = InterlaceBitsRGB(...) >> 6
  }

  for (int i = 0; i < n; ++i) {
    if (!in_palette[i]) {
      const int key = InterlaceBitsRGB(red[i], green[i], blue[i]) >> 6;
      for (int level = 0; level < kMaxLevel; ++level) {
        histogram[level][key >> (3 * level)] += count[i];
      }
    }
  }
  for (int i = 0; i < n; ++i) {
    if (!in_palette[i]) {
      for (int level = 0; level < kMaxLevel; ++level) {
        const int mask = (4 << level) - 1;
        const int rd = std::max(red[i] & mask, mask - (red[i] & mask));
        const int gd = std::max(green[i] & mask, mask - (green[i] & mask));
        const int bd = std::max(blue[i] & mask, mask - (blue[i] & mask));
        radius[i * kMaxLevel + level] =
            ScaleQuadDistanceRGB(ColorIntQuadDistanceRGB(0, 0, 0, rd, gd, bd));
      }
      const int key = InterlaceBitsRGB(red[i], green[i], blue[i]) >> 6;
      if (kMaxLevel > 0) {
        density[i * kMaxLevel] = histogram[0][key] - count[i];
      }
      for (int level = 1; level < kMaxLevel; ++level) {
        density[i * kMaxLevel + level] =
            (histogram[level][key >> (3 * level)] -
             histogram[level - 1][key >> (3 * level - 3)]);
      }
    }
  }

  // Calculate the initial error now that the palette has been initialized.
  error = 0;
  for (int i = 0; i < n; ++i) {
    error += static_cast<int64_t>(dist[i]) * static_cast<int64_t>(count[i]);
  }

  std::unique_ptr<std::vector<int>[]> bucket_array(
      new std::vector<int>[kMaxPriority]);
  int top_priority = -1;
  for (int i = 0; i < n; ++i) {
    if (!in_palette[i]) {
      int priority = Priority(ScaleQuadDistanceRGB(dist[i]), count[i],
                              &density[i * kMaxLevel], &radius[i * kMaxLevel]);
      bucket_array[priority].push_back(i);
      top_priority = std::max(priority, top_priority);
    }
  }
  double error_accum = 0;
  while (top_priority >= 0 && k < max_palette_size) {
    if (error < error_threshold) {
      error_accum += std::min(error_threshold, error_threshold - error);
      if (error_accum >= 10 * error_threshold) {
        break;
      }
    }
    int i = bucket_array[top_priority].back();
    int priority = Priority(ScaleQuadDistanceRGB(dist[i]), count[i],
                            &density[i * kMaxLevel], &radius[i * kMaxLevel]);
    if (priority < top_priority) {
      bucket_array[priority].push_back(i);
    } else {
      AddToRGBPalette(&red[0], &green[0], &blue[0], &count[0], i, k++, n,
                      &dist[0], &cluster[0], &center[0], &error);
    }
    bucket_array[top_priority].pop_back();
    while (top_priority >= 0 && bucket_array[top_priority].empty()) {
      --top_priority;
    }
  }

  cinfo->actual_number_of_colors = k;
  cinfo->colormap = (*cinfo->mem->alloc_sarray)(
      reinterpret_cast<j_common_ptr>(cinfo), JPOOL_IMAGE, k, 3);
  for (int i = 0; i < k; ++i) {
    int index = center[i];
    cinfo->colormap[0][i] = red[index];
    cinfo->colormap[1][i] = green[index];
    cinfo->colormap[2][i] = blue[index];
  }
}

namespace {

void FindCandidatesForCell(j_decompress_ptr cinfo, int ncomp, int cell[],
                           std::vector<uint8_t>* candidates) {
  int cell_min[kMaxComponents];
  int cell_max[kMaxComponents];
  int cell_center[kMaxComponents];
  for (int c = 0; c < ncomp; ++c) {
    cell_min[c] = cell[c] << (8 - kNumColorCellBits[c]);
    cell_max[c] = cell_min[c] + (1 << (8 - kNumColorCellBits[c])) - 1;
    cell_center[c] = (cell_min[c] + cell_max[c]) >> 1;
  }
  int min_maxdist = std::numeric_limits<int>::max();
  int mindist[256];
  for (int i = 0; i < cinfo->actual_number_of_colors; ++i) {
    int dmin = 0;
    int dmax = 0;
    for (int c = 0; c < ncomp; ++c) {
      int palette_c = cinfo->colormap[c][i];
      int dminc = 0, dmaxc;
      if (palette_c < cell_min[c]) {
        dminc = cell_min[c] - palette_c;
        dmaxc = cell_max[c] - palette_c;
      } else if (palette_c > cell_max[c]) {
        dminc = palette_c - cell_max[c];
        dmaxc = palette_c - cell_min[c];
      } else if (palette_c > cell_center[c]) {
        dmaxc = palette_c - cell_min[c];
      } else {
        dmaxc = cell_max[c] - palette_c;
      }
      dminc *= kCompW[c];
      dmaxc *= kCompW[c];
      dmin += dminc * dminc;
      dmax += dmaxc * dmaxc;
    }
    mindist[i] = dmin;
    min_maxdist = std::min(dmax, min_maxdist);
  }
  for (int i = 0; i < cinfo->actual_number_of_colors; ++i) {
    if (mindist[i] < min_maxdist) {
      candidates->push_back(i);
    }
  }
}

}  // namespace

void CreateInverseColorMap(j_decompress_ptr cinfo) {
  jpeg_decomp_master* m = cinfo->master;
  int ncomp = cinfo->out_color_components;
  int num_cells = 1;
  for (int c = 0; c < ncomp; ++c) {
    num_cells *= (1 << kNumColorCellBits[c]);
  }
  m->candidate_lists_.resize(num_cells);

  int next_cell[kMaxComponents] = {0};
  for (int i = 0; i < num_cells; ++i) {
    m->candidate_lists_[i].clear();
    FindCandidatesForCell(cinfo, ncomp, next_cell, &m->candidate_lists_[i]);
    int c = ncomp - 1;
    while (c > 0 && next_cell[c] + 1 == (1 << kNumColorCellBits[c])) {
      next_cell[c--] = 0;
    }
    ++next_cell[c];
  }
  m->regenerate_inverse_colormap_ = false;
}

int LookupColorIndex(j_decompress_ptr cinfo, JSAMPLE* pixel) {
  jpeg_decomp_master* m = cinfo->master;
  int num_channels = cinfo->out_color_components;
  int index = 0;
  if (m->quant_mode_ == 1) {
    for (int c = 0; c < num_channels; ++c) {
      index += m->colormap_lut_[c * 256 + pixel[c]];
    }
  } else {
    size_t cell_idx = 0;
    size_t stride = 1;
    for (int c = num_channels - 1; c >= 0; --c) {
      cell_idx += (pixel[c] >> (8 - kNumColorCellBits[c])) * stride;
      stride <<= kNumColorCellBits[c];
    }
    JXL_ASSERT(cell_idx < m->candidate_lists_.size());
    int mindist = std::numeric_limits<int>::max();
    const auto& candidates = m->candidate_lists_[cell_idx];
    for (uint8_t i : candidates) {
      int dist = 0;
      for (int c = 0; c < num_channels; ++c) {
        int d = (cinfo->colormap[c][i] - pixel[c]) * kCompW[c];
        dist += d * d;
      }
      if (dist < mindist) {
        mindist = dist;
        index = i;
      }
    }
  }
  JXL_ASSERT(index < cinfo->actual_number_of_colors);
  return index;
}

void CreateOrderedDitherTables(j_decompress_ptr cinfo) {
  jpeg_decomp_master* m = cinfo->master;
  static constexpr size_t kDitherSize = 4;
  static constexpr size_t kDitherMask = kDitherSize - 1;
  static constexpr float kBaseDitherMatrix[] = {
      0,  8,  2,  10,  //
      12, 4,  14, 6,   //
      3,  11, 1,  9,   //
      15, 7,  13, 5,   //
  };
  m->dither_size_ = kDitherSize;
  m->dither_mask_ = kDitherMask;
  size_t ncells = m->dither_size_ * m->dither_size_;
  for (int c = 0; c < cinfo->out_color_components; ++c) {
    float spread = 1.0f / (m->num_colors_[c] - 1);
    float mul = spread / ncells;
    float offset = 0.5f * spread;
    if (m->dither_[c] == nullptr) {
      m->dither_[c] = Allocate<float>(cinfo, ncells, JPOOL_IMAGE_ALIGNED);
    }
    for (size_t idx = 0; idx < ncells; ++idx) {
      m->dither_[c][idx] = kBaseDitherMatrix[idx] * mul - offset;
    }
  }
}

void InitFSDitherState(j_decompress_ptr cinfo) {
  jpeg_decomp_master* m = cinfo->master;
  for (int c = 0; c < cinfo->out_color_components; ++c) {
    if (m->error_row_[c] == nullptr) {
      m->error_row_[c] =
          Allocate<float>(cinfo, cinfo->output_width, JPOOL_IMAGE_ALIGNED);
      m->error_row_[c + kMaxComponents] =
          Allocate<float>(cinfo, cinfo->output_width, JPOOL_IMAGE_ALIGNED);
    }
    memset(m->error_row_[c], 0.0, cinfo->output_width * sizeof(float));
    memset(m->error_row_[c + kMaxComponents], 0.0,
           cinfo->output_width * sizeof(float));
  }
}

}  // namespace jpegli
