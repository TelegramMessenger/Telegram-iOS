#ifndef ASTC_ENDPOINTS_ENCODE_H_
#define ASTC_ENDPOINTS_ENCODE_H_

#include <cstdint>

#include "endpoints_quantize.h"
#include "range.h"
#include "vector.h"

int color_channel_sum(vec3i_t color) {
  return color.r + color.g + color.b;
}

void encode_luminance_direct(range_t endpoint_quant,
                             int v0,
                             int v1,
                             uint8_t endpoint_unquantized[2],
                             uint8_t endpoint_quantized[2]) {
  endpoint_quantized[0] = quantize_color(endpoint_quant, v0);
  endpoint_quantized[1] = quantize_color(endpoint_quant, v1);
  endpoint_unquantized[0] =
      unquantize_color(endpoint_quant, endpoint_quantized[0]);
  endpoint_unquantized[1] =
      unquantize_color(endpoint_quant, endpoint_quantized[1]);
}

void encode_rgb_direct(range_t endpoint_quant,
                       vec3i_t e0,
                       vec3i_t e1,
                       uint8_t endpoint_quantized[6],
                       vec3i_t endpoint_unquantized[2]) {
  vec3i_t e0q = quantize_color(endpoint_quant, e0);
  vec3i_t e1q = quantize_color(endpoint_quant, e1);
  vec3i_t e0u = unquantize_color(endpoint_quant, e0q);
  vec3i_t e1u = unquantize_color(endpoint_quant, e1q);

  // ASTC uses a different blue contraction encoding when the sum of values for
  // the first endpoint is larger than the sum of values in the second
  // endpoint. Sort the endpoints to ensure that the normal encoding is used.
  if (color_channel_sum(e0u) > color_channel_sum(e1u)) {
    endpoint_quantized[0] = static_cast<uint8_t>(e1q.r);
    endpoint_quantized[1] = static_cast<uint8_t>(e0q.r);
    endpoint_quantized[2] = static_cast<uint8_t>(e1q.g);
    endpoint_quantized[3] = static_cast<uint8_t>(e0q.g);
    endpoint_quantized[4] = static_cast<uint8_t>(e1q.b);
    endpoint_quantized[5] = static_cast<uint8_t>(e0q.b);

    endpoint_unquantized[0] = e1u;
    endpoint_unquantized[1] = e0u;
  } else {
    endpoint_quantized[0] = static_cast<uint8_t>(e0q.r);
    endpoint_quantized[1] = static_cast<uint8_t>(e1q.r);
    endpoint_quantized[2] = static_cast<uint8_t>(e0q.g);
    endpoint_quantized[3] = static_cast<uint8_t>(e1q.g);
    endpoint_quantized[4] = static_cast<uint8_t>(e0q.b);
    endpoint_quantized[5] = static_cast<uint8_t>(e1q.b);

    endpoint_unquantized[0] = e0u;
    endpoint_unquantized[1] = e1u;
  }
}

#endif  // ASTC_ENDPOINTS_ENCODE_H_
