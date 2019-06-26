#ifndef ASTC_ENDPOINTS_MIN_MAX_H_
#define ASTC_ENDPOINTS_MIN_MAX_H_

#include <algorithm>
#include <cstddef>

#include "colors.h"
#include "constants.h"
#include "dcheck.h"
#include "misc.h"
#include "vector.h"

void find_min_max(const unorm8_t texels[BLOCK_TEXEL_COUNT],
                  size_t count,
                  vec3f_t line_k,
                  vec3f_t line_m,
                  vec3f_t& e0,
                  vec3f_t& e1) {
  DCHECK(count <= BLOCK_TEXEL_COUNT);
  DCHECK(approx_equal(quadrance(line_k), 1.0, 0.0001f));

  float a, b;
  {
    float t = dot(to_vec3f(texels[0]) - line_m, line_k);
    a = t;
    b = t;
  }

  for (size_t i = 1; i < count; ++i) {
    float t = dot(to_vec3f(texels[i]) - line_m, line_k);
    a = std::min(a, t);
    b = std::max(b, t);
  }

  e0 = clamp_rgb(line_k * a + line_m);
  e1 = clamp_rgb(line_k * b + line_m);
}

void find_min_max_block(const unorm8_t texels[BLOCK_TEXEL_COUNT],
                        vec3f_t line_k,
                        vec3f_t line_m,
                        vec3f_t& e0,
                        vec3f_t& e1) {
  find_min_max(texels, BLOCK_TEXEL_COUNT, line_k, line_m, e0, e1);
}

#endif  // ASTC_ENDPOINTS_MIN_MAX_H_
