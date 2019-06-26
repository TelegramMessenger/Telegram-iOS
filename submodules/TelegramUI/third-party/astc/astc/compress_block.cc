#include "compress_block.h"

#include <algorithm>
#include <cstddef>
#include <cstdint>

#include "colors.h"
#include "constants.h"
#include "data_size.h"
#include "endpoints.h"
#include "endpoints_encode.h"
#include "endpoints_min_max.h"
#include "endpoints_principal_components.h"
#include "integer_sequence_encoding.h"
#include "misc.h"
#include "range.h"
#include "store_block.h"
#include "vector.h"
#include "weights_quantize.h"

/**
 * Write void extent block bits for LDR mode and unused extent coordinates.
 */
void encode_void_extent(vec3i_t color, PhysicalBlock* physical_block) {
  void_extent_to_physical(unorm8_to_unorm16(to_unorm8(color)), physical_block);
}

void encode_luminance(const uint8_t texels[BLOCK_TEXEL_COUNT],
                      PhysicalBlock* physical_block) {
  size_t partition_count = 1;
  size_t partition_index = 0;

  color_endpoint_mode_t color_endpoint_mode = CEM_LDR_LUMINANCE_DIRECT;
  range_t weight_quant = RANGE_32;
  range_t endpoint_quant =
      endpoint_quantization(partition_count, weight_quant, color_endpoint_mode);

  uint8_t l0 = 255;
  uint8_t l1 = 0;
  for (size_t i = 0; i < BLOCK_TEXEL_COUNT; ++i) {
    l0 = std::min(l0, texels[i]);
    l1 = std::max(l1, texels[i]);
  }

  uint8_t endpoint_unquantized[2];
  uint8_t endpoint_quantized[2];
  encode_luminance_direct(endpoint_quant, l0, l1, endpoint_quantized,
                          endpoint_unquantized);

  uint8_t weights_quantized[BLOCK_TEXEL_COUNT];
  calculate_quantized_weights_luminance(
      texels, weight_quant, endpoint_unquantized[0], endpoint_unquantized[1],
      weights_quantized);

  uint8_t endpoint_ise[MAXIMUM_ENCODED_COLOR_ENDPOINT_BYTES] = {0};
  integer_sequence_encode(endpoint_quantized, 2, RANGE_256, endpoint_ise);

  uint8_t weights_ise[MAXIMUM_ENCODED_WEIGHT_BYTES + 1] = {0};
  integer_sequence_encode(weights_quantized, BLOCK_TEXEL_COUNT, RANGE_32,
                          weights_ise);

  symbolic_to_physical(color_endpoint_mode, endpoint_quant, weight_quant,
                       partition_count, partition_index, endpoint_ise,
                       weights_ise, physical_block);
}

void encode_rgb_single_partition(const unorm8_t texels[BLOCK_TEXEL_COUNT],
                                 vec3f_t e0,
                                 vec3f_t e1,
                                 PhysicalBlock* physical_block) {
  size_t partition_index = 0;
  size_t partition_count = 1;

  color_endpoint_mode_t color_endpoint_mode = CEM_LDR_RGB_DIRECT;
  range_t weight_quant = RANGE_12;
  range_t endpoint_quant =
      endpoint_quantization(partition_count, weight_quant, color_endpoint_mode);

  vec3i_t endpoint_unquantized[2];
  uint8_t endpoint_quantized[6];
  encode_rgb_direct(endpoint_quant, round(e0), round(e1), endpoint_quantized,
                    endpoint_unquantized);

  uint8_t weights_quantized[BLOCK_TEXEL_COUNT];
  calculate_quantized_weights_rgb(texels, weight_quant, endpoint_unquantized[0],
                                  endpoint_unquantized[1], weights_quantized);

  uint8_t endpoint_ise[MAXIMUM_ENCODED_COLOR_ENDPOINT_BYTES] = {0};
  integer_sequence_encode(endpoint_quantized, 6, endpoint_quant, endpoint_ise);

  uint8_t weights_ise[MAXIMUM_ENCODED_WEIGHT_BYTES + 1] = {0};
  integer_sequence_encode(weights_quantized, BLOCK_TEXEL_COUNT, weight_quant,
                          weights_ise);

  symbolic_to_physical(color_endpoint_mode, endpoint_quant, weight_quant,
                       partition_count, partition_index, endpoint_ise,
                       weights_ise, physical_block);
}

bool is_solid(const unorm8_t texels[BLOCK_TEXEL_COUNT],
              size_t count,
              unorm8_t* color) {
  for (size_t i = 0; i < count; ++i) {
    if (!approx_equal(to_vec3i(texels[i]), to_vec3i(texels[0]))) {
      return false;
    }
  }

  // TODO: Calculate average color?
  *color = texels[0];
  return true;
}

bool is_greyscale(const unorm8_t texels[BLOCK_TEXEL_COUNT],
                  size_t count,
                  uint8_t luminances[BLOCK_TEXEL_COUNT]) {
  for (size_t i = 0; i < count; ++i) {
    vec3i_t color = to_vec3i(texels[i]);
    luminances[i] = static_cast<uint8_t>(luminance(color));
    vec3i_t lum(luminances[i], luminances[i], luminances[i]);
    if (!approx_equal(color, lum)) {
      return false;
    }
  }

  return true;
}

void compress_block(const unorm8_t texels[BLOCK_TEXEL_COUNT],
                    PhysicalBlock* physical_block) {
  {
    unorm8_t color;
    if (is_solid(texels, BLOCK_TEXEL_COUNT, &color)) {
      encode_void_extent(to_vec3i(color), physical_block);
      /* encode_void_extent(vec3i_t(0, 0, 0), physical_block); */
      return;
    }
  }

  {
    uint8_t luminances[BLOCK_TEXEL_COUNT];
    if (is_greyscale(texels, BLOCK_TEXEL_COUNT, luminances)) {
      encode_luminance(luminances, physical_block);
      /* encode_void_extent(vec3i_t(255, 0, 0), physical_block); */
      return;
    }
  }

  vec3f_t k, m;
  principal_component_analysis_block(texels, k, m);
  vec3f_t e0, e1;
  find_min_max_block(texels, k, m, e0, e1);
  encode_rgb_single_partition(texels, e0, e1, physical_block);
  /* encode_void_extent(vec3i_t(0, 255, 0), physical_block); */
}
