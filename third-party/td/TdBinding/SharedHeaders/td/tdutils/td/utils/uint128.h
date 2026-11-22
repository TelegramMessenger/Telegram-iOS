//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/bits.h"
#include "td/utils/common.h"

#include <limits>
#include <type_traits>

namespace td {

class uint128_emulated {
 public:
  using uint128 = uint128_emulated;
  uint128_emulated(uint64 hi, uint64 lo) : hi_(hi), lo_(lo) {
  }
  template <class T, typename = std::enable_if_t<std::is_unsigned<T>::value>>
  uint128_emulated(T lo) : uint128_emulated(0, lo) {
  }
  uint128_emulated() = default;

  uint64 hi() const {
    return hi_;
  }
  uint64 lo() const {
    return lo_;
  }
  uint64 rounded_hi() const {
    return hi_ + (lo_ >> 63);
  }
  static uint128 from_signed(int64 x) {
    if (x >= 0) {
      return uint128(0, x);
    }
    return uint128(std::numeric_limits<uint64>::max(), static_cast<uint64>(x));
  }
  static uint128 from_unsigned(uint64 x) {
    return uint128(0, x);
  }

  uint128 add(uint128 other) const {
    uint128 res(other.hi() + hi(), other.lo() + lo());
    if (res.lo() < lo()) {
      res.hi_++;
    }
    return res;
  }

  uint128 shl(int cnt) const {
    if (cnt == 0) {
      return *this;
    }
    if (cnt < 64) {
      return uint128((hi() << cnt) | (lo() >> (64 - cnt)), lo() << cnt);
    }
    if (cnt < 128) {
      return uint128(lo() << (cnt - 64), 0);
    }
    return uint128();
  }
  uint128 shr(int cnt) const {
    if (cnt == 0) {
      return *this;
    }
    if (cnt < 64) {
      return uint128(hi() >> cnt, (lo() >> cnt) | (hi() << (64 - cnt)));
    }
    if (cnt < 128) {
      return uint128(0, hi() >> (cnt - 64));
    }
    return uint128();
  }

  uint128 mult(uint128 other) const {
    uint64 a_lo = lo() & 0xffffffff;
    uint64 a_hi = lo() >> 32;
    uint64 b_lo = other.lo() & 0xffffffff;
    uint64 b_hi = other.lo() >> 32;
    uint128 res(lo() * other.hi() + hi() * other.lo() + a_hi * b_hi, a_lo * b_lo);
    uint128 add1(0, a_lo * b_hi);
    uint128 add2(0, a_hi * b_lo);
    return res.add(add1.shl(32)).add(add2.shl(32));
  }
  uint128 mult(uint64 other) const {
    return mult(uint128(0, other));
  }
  uint128 mult_signed(int64 other) const {
    return mult(uint128::from_signed(other));
  }
  bool is_zero() const {
    return lo() == 0 && hi() == 0;
  }
  uint128 sub(uint128 other) const {
    uint32 carry = 0;
    if (other.lo() > lo()) {
      carry = 1;
    }
    return uint128(hi() - other.hi() - carry, lo() - other.lo());
  }
  void divmod(uint128 other, uint128 *div_res, uint128 *mod_res) const {
    CHECK(!other.is_zero());

    auto from = *this;
    auto ctz = from.count_leading_zeroes();
    auto other_ctz = other.count_leading_zeroes();
    if (ctz > other_ctz) {
      *div_res = uint128();
      *mod_res = from;
      return;
    }
    auto shift = other_ctz - ctz;
    auto res = uint128();
    for (int i = shift; i >= 0; i--) {
      auto sub = other.shl(i);
      res = res.shl(1);
      if (from.greater_or_equal(sub)) {
        from = from.sub(sub);
        res = res.set_lower_bit();
      }
    }

    *div_res = res;
    *mod_res = from;
  }
  uint128 div(uint128 other) const {
    uint128 a;
    uint128 b;
    divmod(other, &a, &b);
    return a;
  }
  uint128 mod(uint128 other) const {
    uint128 a;
    uint128 b;
    divmod(other, &a, &b);
    return b;
  }

  void divmod_signed(int64 y, int64 *quot, int64 *rem) const {
    CHECK(y != 0);
    auto x = *this;
    int x_sgn = x.is_negative();
    int y_sgn = y < 0;
    if (x_sgn) {
      x = x.negate();
    }
    uint128 uy = from_signed(y);
    if (uy.is_negative()) {
      uy = uy.negate();
    }

    uint128 t_quot;
    uint128 t_mod;
    x.divmod(uy, &t_quot, &t_mod);
    *quot = t_quot.lo();
    *rem = t_mod.lo();
    if (x_sgn != y_sgn) {
      *quot = -*quot;
    }
    if (x_sgn) {
      *rem = -*rem;
    }
  }

 private:
  uint64 hi_{0};
  uint64 lo_{0};

  bool is_negative() const {
    return (hi_ >> 63) == 1;
  }

  int32 count_leading_zeroes() const {
    if (hi() == 0) {
      return 64 + count_leading_zeroes64(lo());
    }
    return count_leading_zeroes64(hi());
  }
  uint128 set_lower_bit() const {
    return uint128(hi(), lo() | 1);
  }
  bool greater_or_equal(uint128 other) const {
    return hi() > other.hi() || (hi() == other.hi() && lo() >= other.lo());
  }
  uint128 negate() const {
    uint128 res(~hi(), ~lo() + 1);
    if (res.lo() == 0) {
      return uint128(res.hi() + 1, 0);
    }
    return res;
  }
};

#if TD_HAVE_INT128
class uint128_intrinsic {
 public:
  using ValueT = unsigned __int128;
  using uint128 = uint128_intrinsic;
  explicit uint128_intrinsic(ValueT value) : value_(value) {
  }
  uint128_intrinsic(uint64 hi, uint64 lo) : value_((ValueT(hi) << 64) | lo) {
  }
  uint128_intrinsic() = default;

  static uint128 from_signed(int64 x) {
    return uint128(static_cast<ValueT>(x));
  }
  static uint128 from_unsigned(uint64 x) {
    return uint128(static_cast<ValueT>(x));
  }
  uint64 hi() const {
    return uint64(value() >> 64);
  }
  uint64 lo() const {
    return uint64(value() & std::numeric_limits<uint64>::max());
  }
  uint64 rounded_hi() const {
    return uint64((value() + (1ULL << 63)) >> 64);
  }
  uint128 add(uint128 other) const {
    return uint128(value() + other.value());
  }
  uint128 sub(uint128 other) const {
    return uint128(value() - other.value());
  }

  uint128 shl(int cnt) const {
    if (cnt >= 128) {
      return uint128();
    }
    return uint128(value() << cnt);
  }

  uint128 shr(int cnt) const {
    if (cnt >= 128) {
      return uint128();
    }
    return uint128(value() >> cnt);
  }

  uint128 mult(uint128 other) const {
    return uint128(value() * other.value());
  }
  uint128 mult(uint64 other) const {
    return uint128(value() * other);
  }
  uint128 mult_signed(int64 other) const {
    return uint128(value() * other);
  }
  bool is_zero() const {
    return value() == 0;
  }
  void divmod(uint128 other, uint128 *div_res, uint128 *mod_res) const {
    CHECK(!other.is_zero());
    *div_res = uint128(value() / other.value());
    *mod_res = uint128(value() % other.value());
  }
  uint128 div(uint128 other) const {
    CHECK(!other.is_zero());
    return uint128(value() / other.value());
  }
  uint128 mod(uint128 other) const {
    CHECK(!other.is_zero());
    return uint128(value() % other.value());
  }
  void divmod_signed(int64 y, int64 *quot, int64 *rem) const {
    CHECK(y != 0);
    *quot = static_cast<int64>(signed_value() / y);
    *rem = static_cast<int64>(signed_value() % y);
  }

 private:
  unsigned __int128 value_{0};
  ValueT value() const {
    return value_;
  }
  __int128 signed_value() const {
    return static_cast<__int128>(value());
  }
};
#endif

#if TD_HAVE_INT128
using uint128 = uint128_intrinsic;
#else
using uint128 = uint128_emulated;
#endif

}  // namespace td
