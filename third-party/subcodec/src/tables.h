#pragma once

#include <cstdint>

namespace subcodec::tables {

// Table 9-4(b): CBP to exp-golomb codeNum for Inter prediction
// Indexed by [cbp_chroma * 16 + cbp_luma]
inline constexpr uint8_t cbp_to_code_inter[48] = {
    // cbp_chroma = 0
     0,  2,  3,  7,  4,  8, 17, 13,  5, 18,  9, 14, 10, 15, 16, 11,
    // cbp_chroma = 1
     1, 32, 33, 36, 34, 37, 44, 40, 35, 45, 38, 41, 39, 42, 43, 19,
    // cbp_chroma = 2
     6, 24, 25, 20, 26, 21, 46, 28, 27, 47, 22, 29, 23, 30, 31, 12,
};

// Table 9-4(a): CBP to exp-golomb codeNum for Intra prediction
// Indexed by [cbp_chroma * 16 + cbp_luma]
inline constexpr uint8_t cbp_to_code_intra[48] = {
    // cbp_chroma = 0
     3, 29, 30, 17, 31, 18, 37,  8, 32, 38, 19,  9, 20, 10, 11,  2,
    // cbp_chroma = 1
    16, 33, 34, 21, 35, 22, 39,  4, 36, 40, 23,  5, 24,  6,  7,  1,
    // cbp_chroma = 2
    41, 42, 43, 25, 44, 26, 46, 12, 45, 47, 27, 13, 28, 14, 15,  0,
};

// H.264 Table 6-9: 4x4 block scan order within a macroblock
// 8x8 block N contains 4x4 blocks N*4..N*4+3
inline constexpr int luma_block_order[16] = {
    0, 1, 2, 3,    // 8x8 block 0
    4, 5, 6, 7,    // 8x8 block 1
    8, 9, 10, 11,  // 8x8 block 2
    12, 13, 14, 15 // 8x8 block 3
};

// Map 4x4 block index to its 8x8 parent block
inline constexpr int block_to_8x8[16] = {
    0, 0, 0, 0, 1, 1, 1, 1,
    2, 2, 2, 2, 3, 3, 3, 3
};

} // namespace subcodec::tables
