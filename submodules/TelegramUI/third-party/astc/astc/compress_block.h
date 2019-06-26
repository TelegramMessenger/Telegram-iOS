#ifndef ASTC_COMPRESS_BLOCK_H_
#define ASTC_COMPRESS_BLOCK_H_

#include "constants.h"

union unorm8_t;
struct PhysicalBlock;

void compress_block(const unorm8_t texels[BLOCK_TEXEL_COUNT],
                    PhysicalBlock* physical_block);

#endif  // ASTC_COMPRESS_BLOCK_H_
