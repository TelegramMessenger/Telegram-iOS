#ifndef ASTC_ENDPOINTS_QUANTIZE_H_
#define ASTC_ENDPOINTS_QUANTIZE_H_

#include <cstdint>

#include "dcheck.h"
#include "range.h"
#include "tables_color_quantization.h"
#include "vector.h"

uint8_t quantize_color(range_t quant, int c) {
  DCHECK(c >= 0 && c <= 255);
  return color_quantize_table[quant][c];
}

vec3i_t quantize_color(range_t quant, vec3i_t c) {
  vec3i_t result;
  result.r = color_quantize_table[quant][c.r];
  result.g = color_quantize_table[quant][c.g];
  result.b = color_quantize_table[quant][c.b];
  return result;
}

uint8_t unquantize_color(range_t quant, int c) {
  DCHECK(c >= 0 && c <= 255);
  return color_unquantize_table[quant][c];
}

vec3i_t unquantize_color(range_t quant, vec3i_t c) {
  vec3i_t result;
  result.r = color_unquantize_table[quant][c.r];
  result.g = color_unquantize_table[quant][c.g];
  result.b = color_unquantize_table[quant][c.b];
  return result;
}

#endif  // ASTC_ENDPOINTS_QUANTIZE_H_
