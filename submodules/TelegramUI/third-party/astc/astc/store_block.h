#ifndef ASTC_STORE_BLOCK_H_
#define ASTC_STORE_BLOCK_H_

#include <cstddef>
#include <cstdint>

#include "bitmanip.h"
#include "colors.h"
#include "constants.h"
#include "dcheck.h"
#include "endpoints.h"
#include "integer_sequence_encoding.h"
#include "range.h"

struct PhysicalBlock {
  uint8_t data[BLOCK_BYTES];
};

inline void void_extent_to_physical(unorm16_t color, PhysicalBlock* pb) {
  pb->data[0] = 0xFC;
  pb->data[1] = 0xFD;
  pb->data[2] = 0xFF;
  pb->data[3] = 0xFF;
  pb->data[4] = 0xFF;
  pb->data[5] = 0xFF;
  pb->data[6] = 0xFF;
  pb->data[7] = 0xFF;

  setbytes2(pb->data, 8, color.channels.r);
  setbytes2(pb->data, 10, color.channels.g);
  setbytes2(pb->data, 12, color.channels.b);
  setbytes2(pb->data, 14, color.channels.a);
}

inline void symbolic_to_physical(
    color_endpoint_mode_t color_endpoint_mode,
    range_t endpoint_quant,
    range_t weight_quant,

    size_t partition_count,
    size_t partition_index,

    const uint8_t endpoint_ise[MAXIMUM_ENCODED_COLOR_ENDPOINT_BYTES],

    // FIXME: +1 needed here because orbits_8ptr breaks when the offset reaches
    // the last byte which always happens if the weight mode is RANGE_32.
    const uint8_t weights_ise[MAXIMUM_ENCODED_WEIGHT_BYTES + 1],

    PhysicalBlock* pb) {
  DCHECK(weight_quant <= RANGE_32);
  DCHECK(endpoint_quant < RANGE_MAX);
  DCHECK(color_endpoint_mode < CEM_MAX);
  DCHECK(partition_count == 1 || partition_index < 1024);
  DCHECK(partition_count >= 1 && partition_count <= 4);
  DCHECK(compute_ise_bitcount(BLOCK_TEXEL_COUNT, weight_quant) <
         MAXIMUM_ENCODED_WEIGHT_BITS);

  size_t n = BLOCK_WIDTH;
  size_t m = BLOCK_HEIGHT;

  static const bool h_table[RANGE_32 + 1] = {0, 0, 0, 0, 0, 0,
                                             1, 1, 1, 1, 1, 1};

  static const uint8_t r_table[RANGE_32 + 1] = {0x2, 0x3, 0x4, 0x5, 0x6, 0x7,
                                                0x2, 0x3, 0x4, 0x5, 0x6, 0x7};

  bool h = h_table[weight_quant];
  size_t r = r_table[weight_quant];

  // Use the first row of Table 11 in the ASTC specification. Beware that
  // this has to be changed if another block-size is used.
  size_t a = m - 2;
  size_t b = n - 4;

  bool d = 0;  // TODO: dual plane

  bool multi_part = partition_count > 1;

  size_t part_value = partition_count - 1;
  size_t part_index = multi_part ? partition_index : 0;

  size_t cem_offset = multi_part ? 23 : 13;
  size_t ced_offset = multi_part ? 29 : 17;

  size_t cem_bits = multi_part ? 6 : 4;
  size_t cem = color_endpoint_mode;
  cem = multi_part ? cem << 2 : cem;

  // Block mode
  orbits8_ptr(pb->data, 0, getbit(r, 1), 1);
  orbits8_ptr(pb->data, 1, getbit(r, 2), 1);
  orbits8_ptr(pb->data, 2, 0, 1);
  orbits8_ptr(pb->data, 3, 0, 1);
  orbits8_ptr(pb->data, 4, getbit(r, 0), 1);
  orbits8_ptr(pb->data, 5, a, 2);
  orbits8_ptr(pb->data, 7, b, 2);
  orbits8_ptr(pb->data, 9, h, 1);
  orbits8_ptr(pb->data, 10, d, 1);

  // Partitions
  orbits8_ptr(pb->data, 11, part_value, 2);
  orbits16_ptr(pb->data, 13, part_index, 10);

  // CEM
  orbits8_ptr(pb->data, cem_offset, cem, cem_bits);

  copy_bytes(endpoint_ise, MAXIMUM_ENCODED_COLOR_ENDPOINT_BYTES, pb->data,
             ced_offset);

  reverse_bytes(weights_ise, MAXIMUM_ENCODED_WEIGHT_BYTES, pb->data + 15);
}

#endif  // ASTC_STORE_BLOCK_H_
