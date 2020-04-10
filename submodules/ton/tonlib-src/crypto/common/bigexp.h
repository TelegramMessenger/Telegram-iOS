/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "common/refint.h"

namespace td {

class NegExpBinTable {
  int precision, maxpw2, minpw2;
  std::vector<td::BigInt256> exp_pw2_table;      // table of 2^precision * exp(- 2^k) for k = max_pw2-1 .. min_pw2
  std::vector<td::RefInt256> exp_pw2_ref_table;  // same data
  td::BigInt256 One;

 public:
  NegExpBinTable(int _precision, int _maxpw2, int _minpw2) : precision(255), maxpw2(_maxpw2), minpw2(_minpw2) {
    (_precision > 0 && _precision < 256 && _minpw2 <= 0 && _maxpw2 > 0 && _maxpw2 <= 256 && _minpw2 >= -256 && init() &&
     adjust_precision(_precision)) ||
        invalidate();
  }
  bool is_valid() const {
    return minpw2 < maxpw2;
  }
  int get_precision() const {
    return precision;
  }
  int get_exponent_precision() const {
    return -minpw2;
  }
  int get_exponent_max_log2() const {
    return maxpw2;
  }
  const td::BigInt256* exp_pw2(int k) const {  // returns 2^precision * exp(-2^k) or null
    return (k >= minpw2 && k < maxpw2) ? &exp_pw2_table[k - minpw2] : nullptr;
  }
  td::RefInt256 exp_pw2_ref(int k) const {
    if (k >= minpw2 && k < maxpw2) {
      return exp_pw2_ref_table[k - minpw2];
    } else {
      return {};
    }
  }
  bool nexpf(td::BigInt256& res, long long x, int k) const;  // res := 2^precision * exp(-x * 2^k)
  td::RefInt256 nexpf(long long x, int k) const;

 private:
  bool init();
  bool init_one();
  bool adjust_precision(int new_precision, int rmode = 0);
  bool invalidate() {
    minpw2 = maxpw2 = 0;
    return false;
  }
  td::BigInt256 series_exp(int k) const;  // returns 2^precision * exp(-2^(-k)), k >= 0
};

struct SuperFloat {
  struct SetZero {};
  struct SetOne {};
  struct SetNan {};
  td::uint128 m;
  int s;
  SuperFloat() = default;
  SuperFloat(SetZero) : m(0, 0), s(0) {
  }
  SuperFloat(SetOne) : m(0, 1), s(0) {
  }
  SuperFloat(SetNan) : m(0, 0), s(std::numeric_limits<int>::min()) {
  }
  SuperFloat(td::uint128 _m, int _s = 0) : m(_m), s(_s) {
  }
  SuperFloat(td::uint64 _m, int _s = 0) : m(0, _m), s(_s) {
  }
  explicit SuperFloat(BigInt256 x);
  static SuperFloat Zero() {
    return SetZero{};
  }
  static SuperFloat One() {
    return SetOne{};
  }
  static SuperFloat NaN() {
    return SetNan{};
  }
  void set_zero() {
    m = td::uint128(0, 0);
    s = 0;
  }
  void set_one() {
    m = td::uint128(0, 1);
    s = 0;
  }
  void set_nan() {
    s = std::numeric_limits<int>::min();
  }
  bool is_nan() const {
    return s == std::numeric_limits<int>::min();
  }
  bool is_zero() const {
    return m.is_zero();
  }
  bool normalize();
  td::uint64 top() const {
    return m.rounded_hi();
  }
  static td::uint128 as_uint128(const td::BigInt256& x);
  static td::uint64 as_uint64(const td::BigInt256& x);
};

class NegExpInt64Table {
  enum { max_exp = 45 };
  unsigned char table0_shift[max_exp + 1];
  td::uint64 table0[max_exp + 1], table1[256], table2[256];

 public:
  NegExpInt64Table();
  // compute x * exp(-k / 2^16);
  // more precisely: computes 0 <= y <= x for 0 <= x < 2^60, s.that |y - x * exp(-k / 2^16)| < 1
  // two different implementations of this functions would return values differing by at most one
  td::uint64 umulnexps32(td::uint64 x, unsigned k, bool trunc = false) const;
  td::int64 mulnexps32(td::int64 x, unsigned k, bool trunc = false) const;
  static const NegExpInt64Table& table();

 private:
};

td::uint64 umulnexps32(td::uint64 x, unsigned k, bool trunc = false);  // compute x * exp(-k / 2^16)
td::int64 mulnexps32(td::int64 x, unsigned k, bool trunc = false);

}  // namespace td
