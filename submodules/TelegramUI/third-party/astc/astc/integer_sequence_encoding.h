#ifndef ASTC_INTEGER_SEQUENCE_ENCODING_H_
#define ASTC_INTEGER_SEQUENCE_ENCODING_H_

#include <cstddef>
#include <cstdint>

#include "bitmanip.h"
#include "dcheck.h"
#include "tables_integer_sequence_encoding.h"
#include "range.h"

/**
 * Table that describes the number of trits or quints along with bits required
 * for storing each range.
 */
const uint8_t bits_trits_quints_table[RANGE_MAX][3] = {
    {1, 0, 0},  // RANGE_2
    {0, 1, 0},  // RANGE_3
    {2, 0, 0},  // RANGE_4
    {0, 0, 1},  // RANGE_5
    {1, 1, 0},  // RANGE_6
    {3, 0, 0},  // RANGE_8
    {1, 0, 1},  // RANGE_10
    {2, 1, 0},  // RANGE_12
    {4, 0, 0},  // RANGE_16
    {2, 0, 1},  // RANGE_20
    {3, 1, 0},  // RANGE_24
    {5, 0, 0},  // RANGE_32
    {3, 0, 1},  // RANGE_40
    {4, 1, 0},  // RANGE_48
    {6, 0, 0},  // RANGE_64
    {4, 0, 1},  // RANGE_80
    {5, 1, 0},  // RANGE_96
    {7, 0, 0},  // RANGE_128
    {5, 0, 1},  // RANGE_160
    {6, 1, 0},  // RANGE_192
    {8, 0, 0}   // RANGE_256
};

/**
 * Encode a group of 5 numbers using trits and bits.
 */
inline void encode_trits(size_t bits,
                         uint8_t b0,
                         uint8_t b1,
                         uint8_t b2,
                         uint8_t b3,
                         uint8_t b4,
                         bitwriter& writer) {
  uint8_t t0, t1, t2, t3, t4;
  uint8_t m0, m1, m2, m3, m4;

  split_high_low(b0, bits, t0, m0);
  split_high_low(b1, bits, t1, m1);
  split_high_low(b2, bits, t2, m2);
  split_high_low(b3, bits, t3, m3);
  split_high_low(b4, bits, t4, m4);

  DCHECK(t0 < 3);
  DCHECK(t1 < 3);
  DCHECK(t2 < 3);
  DCHECK(t3 < 3);
  DCHECK(t4 < 3);

  uint8_t packed = integer_from_trits[t4][t3][t2][t1][t0];

  writer.write8(m0, bits);
  writer.write8(getbits(packed, 1, 0), 2);
  writer.write8(m1, bits);
  writer.write8(getbits(packed, 3, 2), 2);
  writer.write8(m2, bits);
  writer.write8(getbits(packed, 4, 4), 1);
  writer.write8(m3, bits);
  writer.write8(getbits(packed, 6, 5), 2);
  writer.write8(m4, bits);
  writer.write8(getbits(packed, 7, 7), 1);
}

/**
 * Encode a group of 3 numbers using quints and bits.
 */
inline void encode_quints(size_t bits,
                          uint8_t b0,
                          uint8_t b1,
                          uint8_t b2,
                          bitwriter& writer) {
  uint8_t q0, q1, q2;
  uint8_t m0, m1, m2;

  split_high_low(b0, bits, q0, m0);
  split_high_low(b1, bits, q1, m1);
  split_high_low(b2, bits, q2, m2);

  DCHECK(q0 < 5);
  DCHECK(q1 < 5);
  DCHECK(q2 < 5);

  uint8_t packed = integer_from_quints[q2][q1][q0];

  writer.write8(m0, bits);
  writer.write8(getbits(packed, 2, 0), 3);
  writer.write8(m1, bits);
  writer.write8(getbits(packed, 4, 3), 2);
  writer.write8(m2, bits);
  writer.write8(getbits(packed, 6, 5), 2);
}

/**
 * Encode a sequence of numbers using using one trit and a custom number of
 * bits per number.
 */
inline void encode_trits(const uint8_t* numbers,
                         size_t count,
                         bitwriter& writer,
                         size_t bits) {
  for (size_t i = 0; i < count; i += 5) {
    uint8_t b0 = numbers[i + 0];
    uint8_t b1 = i + 1 >= count ? 0 : numbers[i + 1];
    uint8_t b2 = i + 2 >= count ? 0 : numbers[i + 2];
    uint8_t b3 = i + 3 >= count ? 0 : numbers[i + 3];
    uint8_t b4 = i + 4 >= count ? 0 : numbers[i + 4];

    encode_trits(bits, b0, b1, b2, b3, b4, writer);
  }
}

/**
 * Encode a sequence of numbers using one quint and the custom number of bits
 * per number.
 */
inline void encode_quints(const uint8_t* numbers,
                          size_t count,
                          bitwriter& writer,
                          size_t bits) {
  for (size_t i = 0; i < count; i += 3) {
    uint8_t b0 = numbers[i + 0];
    uint8_t b1 = i + 1 >= count ? 0 : numbers[i + 1];
    uint8_t b2 = i + 2 >= count ? 0 : numbers[i + 2];
    encode_quints(bits, b0, b1, b2, writer);
  }
}

/**
 * Encode a sequence of numbers using binary representation with the selected
 * bit count.
 */
inline void encode_binary(const uint8_t* numbers,
                          size_t count,
                          bitwriter& writer,
                          size_t bits) {
  DCHECK(count > 0);
  for (size_t i = 0; i < count; ++i) {
    writer.write8(numbers[i], bits);
  }
}

/**
 * Encode a sequence of numbers in a specific range using the binary integer
 * sequence encoding. The numbers are assumed to be in the correct range and
 * the memory we are writing to is assumed to be zero-initialized.
 */
inline void integer_sequence_encode(const uint8_t* numbers,
                                    size_t count,
                                    range_t range,
                                    bitwriter writer) {
#ifndef NDEBUG
  for (size_t i = 0; i < count; ++i) {
    DCHECK(numbers[i] <= range_max_table[range]);
  }
#endif

  size_t bits = bits_trits_quints_table[range][0];
  size_t trits = bits_trits_quints_table[range][1];
  size_t quints = bits_trits_quints_table[range][2];

  if (trits == 1) {
    encode_trits(numbers, count, writer, bits);
  } else if (quints == 1) {
    encode_quints(numbers, count, writer, bits);
  } else {
    encode_binary(numbers, count, writer, bits);
  }
}

inline void integer_sequence_encode(const uint8_t* numbers,
                                    size_t count,
                                    range_t range,
                                    uint8_t* output) {
  integer_sequence_encode(numbers, count, range, bitwriter(output));
}

/**
 * Compute the number of bits required to store a number of items in a specific
 * range using the binary integer sequence encoding.
 */
inline size_t compute_ise_bitcount(size_t items, range_t range) {
  size_t bits = bits_trits_quints_table[range][0];
  size_t trits = bits_trits_quints_table[range][1];
  size_t quints = bits_trits_quints_table[range][2];

  if (trits) {
    return ((8 + 5 * bits) * items + 4) / 5;
  }

  if (quints) {
    return ((7 + 3 * bits) * items + 2) / 3;
  }

  return items * bits;
}

#endif  // ASTC_INTEGER_SEQUENCE_ENCODING_H_
