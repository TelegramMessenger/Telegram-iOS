//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#if TD_MSVC
#include <intrin.h>
#endif

#ifdef bswap32
#undef bswap32
#endif

#ifdef bswap64
#undef bswap64
#endif

namespace td {

int32 count_leading_zeroes32(uint32 x);
int32 count_leading_zeroes64(uint64 x);
int32 count_trailing_zeroes32(uint32 x);
int32 count_trailing_zeroes64(uint64 x);
uint32 bswap32(uint32 x);
uint64 bswap64(uint64 x);
int32 count_bits32(uint32 x);
int32 count_bits64(uint64 x);

inline uint32 bits_negate32(uint32 x) {
  return ~x + 1;
}

inline uint64 bits_negate64(uint64 x) {
  return ~x + 1;
}

inline uint32 lower_bit32(uint32 x) {
  return x & bits_negate32(x);
}

inline uint64 lower_bit64(uint64 x) {
  return x & bits_negate64(x);
}

inline uint64 host_to_big_endian64(uint64 x) {
  // NB: works only for little-endian systems
  return bswap64(x);
}
inline uint64 big_endian_to_host64(uint64 x) {
  // NB: works only for little-endian systems
  return bswap64(x);
}

//TODO: optimize
inline int32 count_leading_zeroes_non_zero32(uint32 x) {
  DCHECK(x != 0);
  return count_leading_zeroes32(x);
}
inline int32 count_leading_zeroes_non_zero64(uint64 x) {
  DCHECK(x != 0);
  return count_leading_zeroes64(x);
}
inline int32 count_trailing_zeroes_non_zero32(uint32 x) {
  DCHECK(x != 0);
  return count_trailing_zeroes32(x);
}
inline int32 count_trailing_zeroes_non_zero64(uint64 x) {
  DCHECK(x != 0);
  return count_trailing_zeroes64(x);
}

//
// Platform specific implementation
//
#if TD_MSVC

inline int32 count_leading_zeroes32(uint32 x) {
  unsigned long res = 0;
  if (_BitScanReverse(&res, x)) {
    return 31 - res;
  }
  return 32;
}

inline int32 count_leading_zeroes64(uint64 x) {
#if defined(_M_X64)
  unsigned long res = 0;
  if (_BitScanReverse64(&res, x)) {
    return 63 - res;
  }
  return 64;
#else
  if ((x >> 32) == 0) {
    return count_leading_zeroes32(static_cast<uint32>(x)) + 32;
  } else {
    return count_leading_zeroes32(static_cast<uint32>(x >> 32));
  }
#endif
}

inline int32 count_trailing_zeroes32(uint32 x) {
  unsigned long res = 0;
  if (_BitScanForward(&res, x)) {
    return res;
  }
  return 32;
}

inline int32 count_trailing_zeroes64(uint64 x) {
#if defined(_M_X64)
  unsigned long res = 0;
  if (_BitScanForward64(&res, x)) {
    return res;
  }
  return 64;
#else
  if (static_cast<uint32>(x) == 0) {
    return count_trailing_zeroes32(static_cast<uint32>(x >> 32)) + 32;
  } else {
    return count_trailing_zeroes32(static_cast<uint32>(x));
  }
#endif
}

inline uint32 bswap32(uint32 x) {
  return _byteswap_ulong(x);
}

inline uint64 bswap64(uint64 x) {
  return _byteswap_uint64(x);
}

inline int32 count_bits32(uint32 x) {
  // Do not use __popcnt because it will fail on some platforms.
  x -= (x >> 1) & 0x55555555;
  x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
  x = (x + (x >> 4)) & 0x0F0F0F0F;
  x += x >> 8;
  return (x + (x >> 16)) & 0x3F;
}

inline int32 count_bits64(uint64 x) {
#if defined(_M_X64)
  return static_cast<int32>(__popcnt64(x));
#else
  return count_bits32(static_cast<uint32>(x >> 32)) + count_bits32(static_cast<uint32>(x));
#endif
}

#elif TD_INTEL

inline int32 count_leading_zeroes32(uint32 x) {
  unsigned __int32 res = 0;
  if (_BitScanReverse(&res, x)) {
    return 31 - res;
  }
  return 32;
}

inline int32 count_leading_zeroes64(uint64 x) {
#if defined(_M_X64) || defined(__x86_64__)
  unsigned __int32 res = 0;
  if (_BitScanReverse64(&res, x)) {
    return 63 - res;
  }
  return 64;
#else
  if ((x >> 32) == 0) {
    return count_leading_zeroes32(static_cast<uint32>(x)) + 32;
  } else {
    return count_leading_zeroes32(static_cast<uint32>(x >> 32));
  }
#endif
}

inline int32 count_trailing_zeroes32(uint32 x) {
  unsigned __int32 res = 0;
  if (_BitScanForward(&res, x)) {
    return res;
  }
  return 32;
}

inline int32 count_trailing_zeroes64(uint64 x) {
#if defined(_M_X64) || defined(__x86_64__)
  unsigned __int32 res = 0;
  if (_BitScanForward64(&res, x)) {
    return res;
  }
  return 64;
#else
  if (static_cast<uint32>(x) == 0) {
    return count_trailing_zeroes32(static_cast<uint32>(x >> 32)) + 32;
  } else {
    return count_trailing_zeroes32(static_cast<uint32>(x));
  }
#endif
}

inline uint32 bswap32(uint32 x) {
  return _bswap(static_cast<int>(x));
}

inline uint64 bswap64(uint64 x) {
  return _bswap64(static_cast<__int64>(x));
}

inline int32 count_bits32(uint32 x) {
  x -= (x >> 1) & 0x55555555;
  x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
  x = (x + (x >> 4)) & 0x0F0F0F0F;
  x += x >> 8;
  return (x + (x >> 16)) & 0x3F;
}

inline int32 count_bits64(uint64 x) {
  return count_bits32(static_cast<uint32>(x >> 32)) + count_bits32(static_cast<uint32>(x));
}

#else

inline int32 count_leading_zeroes32(uint32 x) {
  if (x == 0) {
    return 32;
  }
  return __builtin_clz(x);
}

inline int32 count_leading_zeroes64(uint64 x) {
  if (x == 0) {
    return 64;
  }
  return __builtin_clzll(x);
}

inline int32 count_trailing_zeroes32(uint32 x) {
  if (x == 0) {
    return 32;
  }
  return __builtin_ctz(x);
}

inline int32 count_trailing_zeroes64(uint64 x) {
  if (x == 0) {
    return 64;
  }
  return __builtin_ctzll(x);
}

inline uint32 bswap32(uint32 x) {
  return __builtin_bswap32(x);
}

inline uint64 bswap64(uint64 x) {
  return __builtin_bswap64(x);
}

inline int32 count_bits32(uint32 x) {
  return __builtin_popcount(x);
}

inline int32 count_bits64(uint64 x) {
  return __builtin_popcountll(x);
}

#endif

struct BitsRange {
  explicit BitsRange(uint64 bits = 0) : bits{bits}, pos{-1} {
  }

  BitsRange begin() const {
    return *this;
  }

  BitsRange end() const {
    return BitsRange{};
  }

  int32 operator*() const {
    if (pos == -1) {
      pos = count_trailing_zeroes64(bits);
    }
    return pos;
  }

  bool operator!=(const BitsRange &other) const {
    return bits != other.bits;
  }

  BitsRange &operator++() {
    auto i = **this;
    if (i != 64) {
      bits ^= 1ull << i;
    }
    pos = -1;
    return *this;
  }

 private:
  uint64 bits{0};
  mutable int32 pos{-1};
};

}  // namespace td
