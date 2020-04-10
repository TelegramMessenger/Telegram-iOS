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
#include "bigexp.h"
#include "td/utils/bits.h"
#include "td/utils/as.h"
#include "td/utils/misc.h"

namespace td {

bool NegExpBinTable::init() {
  init_one();
  int k;
  for (k = minpw2; k <= 0; k++) {
    exp_pw2_table.emplace_back(series_exp(-k));
    exp_pw2_ref_table.emplace_back(true, exp_pw2_table.back());
  }
  for (; k < maxpw2; k++) {
    td::BigIntG<257 * 2> tmp{0};
    auto& x = exp_pw2_table.back();
    tmp.add_mul(x, x).rshift(precision, 0).normalize();
    exp_pw2_table.emplace_back(tmp);
    exp_pw2_ref_table.emplace_back(true, exp_pw2_table.back());
  }
  return true;
}

bool NegExpBinTable::adjust_precision(int new_precision, int rmode) {
  if (new_precision <= 0 || new_precision > precision) {
    return false;
  }
  if (new_precision == precision) {
    return true;
  }
  int s = precision - new_precision;
  for (auto& x : exp_pw2_table) {
    x.rshift(s, rmode).normalize();
  }
  for (auto& x : exp_pw2_ref_table) {
    x.write().rshift(s, rmode).normalize();
  }
  precision = new_precision;
  return init_one();
}

bool NegExpBinTable::init_one() {
  One.set_pow2(precision);
  return true;
}

bool NegExpBinTable::nexpf(td::BigInt256& res, long long x, int k) const {  // res := 2^precision * exp(-x * 2^k)
  if (!x) {
    res.set_pow2(precision);
    return true;
  }
  if (x < 0) {
    return false;
  }
  int s = td::count_trailing_zeroes64(x);
  x >>= s;
  k -= s;
  if (k + minpw2 > 0) {
    return false;
  }
  int t = 63 - td::count_leading_zeroes64(x);
  if (t - k >= maxpw2) {
    return false;
  }
  res.set_pow2(precision);
  while (true) {
    td::BigIntG<257 * 2> tmp{0};
    tmp.add_mul(res, exp_pw2_table.at(t - k - minpw2)).rshift(precision, 0).normalize();
    res = tmp;
    x -= (1LL << t);
    if (!x) {
      return true;
    }
    t = 63 - td::count_leading_zeroes64(x);
  }
}

td::RefInt256 NegExpBinTable::nexpf(long long x, int k) const {
  td::RefInt256 res{true};
  if (nexpf(res.unique_write(), x, k)) {
    return res;
  } else {
    return {};
  }
}

td::BigInt256 NegExpBinTable::series_exp(int k) const {  // returns 2^precision * exp(-2^(-k)), k >= 0
  td::BigIntG<257 * 2> s{0}, q;
  const int prec = 52 * 6;
  q.set_pow2(prec);
  int i = 0;
  do {
    s += q;
    --i;
    q.rshift(k).add_tiny(i / 2).divmod_short(i);
    q.normalize();
  } while (q.sgn());
  s.rshift(prec - precision).normalize();
  return s;
}

NegExpInt64Table::NegExpInt64Table() {
  NegExpBinTable t{252, 8, -32};
  CHECK(t.is_valid());
  table0[0] = 0;
  table0_shift[0] = 0;
  for (int i = 1; i <= max_exp; i++) {
    SuperFloat v(*t.nexpf(i, 0));  // compute exp(-i)
    CHECK(!v.is_nan());
    if (v.is_zero()) {
      table0[i] = 0;
      table0_shift[i] = 0;
    } else {
      CHECK(v.normalize());
      int k = v.s + 64 - 252;
      CHECK(k <= -64);
      if (k > -128) {
        table0[i] = v.top();
        table0_shift[i] = td::narrow_cast<unsigned char>(-k - 1);
      } else {
        table0[i] = 0;
        table0_shift[i] = 0;
      }
    }
    // std::cerr << "table0[" << i << "] = exp(-" << i << ") : " << table0[i] << " / 2^" << table0_shift[i] + 1 << std::endl;
  }
  td::BigInt256 One;
  One.set_pow2(252);
  for (int i = 0; i < 256; i++) {
    td::BigInt256 x;
    CHECK(t.nexpf(x, i, 8));
    (x.negate() += One).rshift(252 - 64, 0).normalize();
    table1[i] = SuperFloat::as_uint64(x);
    // std::cerr << "table1[" << i << "] = 1 - exp(-" << i << "/256) : " << table1[i] << " / 2^64" << std::endl;
  }
  for (int i = 0; i < 256; i++) {
    td::BigInt256 x;
    CHECK(t.nexpf(x, i, 16));
    (x.negate() += One).rshift(252 - 64 - 8, 0).normalize();
    table2[i] = SuperFloat::as_uint64(x);
    // std::cerr << "table2[" << i << "] = 1 - exp(-" << i << "/2^16) : " << table2[i] << " / 2^72" << std::endl;
  }
}

td::uint64 NegExpInt64Table::umulnexps32(td::uint64 x, unsigned k, bool trunc) const {  // compute x * exp(-k / 2^16)
  if (!k || !x) {
    return x;
  }
  unsigned k0 = (k >> 16);
  if (k0 > max_exp) {
    return 0;
  }
  unsigned s = td::count_leading_zeroes_non_zero64(x);
  x <<= s;
  unsigned k1 = (k >> 8) & 0xff;
  unsigned k2 = k & 0xff;
  if (k2) {
    x -= ((td::uint128::from_unsigned(x).mult(table2[k2]).rounded_hi() + 0x80) >> 8);
  }
  if (k1) {
    x -= td::uint128::from_unsigned(x).mult(table1[k1]).rounded_hi();
  }
  if (k0) {
    if (trunc) {
      return td::uint128::from_unsigned(x).mult(table0[k0]).shr(table0_shift[k0] + s + 1).lo();
    } else {
      return (td::uint128::from_unsigned(x).mult(table0[k0]).shr(table0_shift[k0] + s).lo() + 1) >> 1;
    }
  }
  if (!s) {
    return x;
  } else if (trunc) {
    return x >> s;
  } else {
    return ((x >> (s - 1)) + 1) >> 1;
  }
}

td::int64 NegExpInt64Table::mulnexps32(td::int64 x, unsigned k, bool trunc) const {
  return x >= 0 ? umulnexps32(x, k, trunc) : -umulnexps32(-x, k, trunc);
}

const NegExpInt64Table& NegExpInt64Table::table() {
  static NegExpInt64Table tab;
  return tab;
}

td::uint64 umulnexps32(td::uint64 x, unsigned k, bool trunc) {  // compute x * exp(-k / 2^16)
  return NegExpInt64Table::table().umulnexps32(x, k, trunc);
}

td::int64 mulnexps32(td::int64 x, unsigned k, bool trunc) {
  return NegExpInt64Table::table().mulnexps32(x, k, trunc);
}

td::uint128 SuperFloat::as_uint128(const td::BigInt256& x) {
  td::uint64 t[2];
  if (!x.export_bytes_lsb((unsigned char*)(void*)t, sizeof(t), false)) {
    return {std::numeric_limits<uint64>::max(), 0};
  } else {
    return {t[1], t[0]};
  }
}

td::uint64 SuperFloat::as_uint64(const td::BigInt256& x) {
  td::uint64 t;
  if (!x.export_bytes_lsb((unsigned char*)&t, sizeof(t), false)) {
    return std::numeric_limits<uint64>::max();
  } else {
    return t;
  }
}

SuperFloat::SuperFloat(td::BigInt256 x) {
  if (x.unsigned_fits_bits(128)) {
    m = as_uint128(x);
    s = 0;
  } else if (x.sgn() == 1) {
    s = x.bit_size(false) - 128;
    x.rshift(s, 0).normalize();
    m = as_uint128(x);
  } else {
    set_nan();
  }
}

bool SuperFloat::normalize() {
  if (is_nan()) {
    return false;
  }
  if (is_zero()) {
    s = 0;
    return true;
  }
  auto hi = m.hi();
  int t = (hi ? td::count_leading_zeroes_non_zero64(hi) : 64 + td::count_leading_zeroes_non_zero64(m.lo()));
  m.shl(t);
  s -= t;
  return true;
}

}  // namespace td
