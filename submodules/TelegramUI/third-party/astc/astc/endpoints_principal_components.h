#ifndef ASTC_ENDPOINTS_PRINCIPAL_COMPONENTS_H_
#define ASTC_ENDPOINTS_PRINCIPAL_COMPONENTS_H_

#include <cstddef>

#include "colors.h"
#include "constants.h"
#include "vector.h"

void principal_component_analysis(const unorm8_t texels[BLOCK_TEXEL_COUNT],
                                  size_t count,
                                  vec3f_t& line_k,
                                  vec3f_t& line_m);

inline void principal_component_analysis_block(
    const unorm8_t texels[BLOCK_TEXEL_COUNT],
    vec3f_t& line_k,
    vec3f_t& line_m) {
  principal_component_analysis(texels, BLOCK_TEXEL_COUNT, line_k, line_m);
}

#endif  // ASTC_ENDPOINTS_PRINCIPAL_COMPONENTS_H_
