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

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once
#include <vector>
#include <string>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <ostream>
#include <sstream>
#include <cassert>
#include "common/bitstring.h"

#include "td/utils/bits.h"
#include "td/utils/Span.h"
#include "td/utils/uint128.h"

/**************************************
 *
 *     BIGINT256
 *
 **************************************
**/

namespace td {

struct BigIntInfo {
  typedef long long word_t;
  typedef unsigned long long uword_t;
  enum { word_bits = 64, word_shift = 52, words_for_256bit = 1 + 256 / word_shift, max_pow10_exp = 18 };
  static const word_t Base = (1LL << word_shift);
  static const word_t Half = (1LL << (word_shift - 1));
  static const word_t MaxDenorm = (1LL << (word_bits - word_shift - 1));
  static const word_t max_pow10 = 1000000000000000000LL;
  static constexpr double InvBase = 1.0 / (double)Base;

  static void set_mul(word_t* hi, word_t* lo, word_t x, word_t y);
  static void add_mul(word_t* hi, word_t* lo, word_t x, word_t y);
  static void sub_mul(word_t* hi, word_t* lo, word_t x, word_t y);
  static void dbl_divmod(word_t* quot, word_t* rem, word_t hi, word_t lo, word_t y);
};

inline void BigIntInfo::set_mul(word_t* hi, word_t* lo, word_t x, word_t y) {
  auto z = uint128::from_signed(x).mult_signed(y);
  *lo = static_cast<word_t>(z.lo()) & (Base - 1);
  *hi = static_cast<word_t>(z.shr(word_shift).lo());
}

inline void BigIntInfo::add_mul(word_t* hi, word_t* lo, word_t x, word_t y) {
  auto z = uint128::from_signed(x).mult_signed(y);
  *lo += static_cast<word_t>(z.lo()) & (Base - 1);
  *hi += static_cast<word_t>(z.shr(word_shift).lo());
}

inline void BigIntInfo::sub_mul(word_t* hi, word_t* lo, word_t x, word_t y) {
  auto z = uint128::from_signed(x).mult_signed(y);
  *lo -= static_cast<word_t>(z.lo()) & (Base - 1);
  *hi -= static_cast<word_t>(z.shr(word_shift).lo());
}

inline void BigIntInfo::dbl_divmod(word_t* quot, word_t* rem, word_t hi, word_t lo, word_t y) {
  auto x = uint128::from_signed(hi).shl(word_shift).add(uint128::from_signed(lo));
  int64 a, b;
  x.divmod_signed(y, &a, &b);
  *quot = a;
  *rem = b;
}

namespace {

template <typename T>
struct LogOpAnd {
  static T op(T x, T y) {
    return x & y;
  }
  static const T neutral = -1;
  static const T zero = 0;
  static const bool has_zero = true;
};

template <typename T>
struct LogOpOr {
  static T op(T x, T y) {
    return x | y;
  }
  static const T neutral = 0;
  static const T zero = -1;
  static const bool has_zero = true;
};

template <typename T>
struct LogOpXor {
  static T op(T x, T y) {
    return x ^ y;
  }
  static const T neutral = 0;
  static const T zero = -1;
  static const bool has_zero = false;
};

template <typename T>
struct TransformId {
  static T eval(T x) {
    return x;
  }
};

template <typename T>
struct TransformNegate {
  static T eval(T x) {
    return -x;
  }
};

template <typename T, int factor>
struct TransformMul {
  static T eval(T x) {
    return x * factor;
  }
};

}  // namespace

struct IntOverflow {};

template <class T>
class PropagateConstSpan {
 public:
  PropagateConstSpan() = default;
  PropagateConstSpan(T* ptr, size_t size) : ptr_(ptr), size_(size) {
  }

  T& operator[](size_t i) {
    DCHECK(i < size_);
    return ptr_[i];
  }
  const T& operator[](size_t i) const {
    DCHECK(i < size_);
    return ptr_[i];
  }
  T* data() {
    return ptr_;
  }
  const T* data() const {
    return ptr_;
  }
  size_t size() const {
    return size_;
  }

 private:
  T* ptr_{nullptr};
  size_t size_{0};
};

template <class Tr = BigIntInfo>
class AnyIntView {
 public:
  enum { word_bits = Tr::word_bits, word_shift = Tr::word_shift };
  typedef typename Tr::word_t word_t;
  int& n_;
  PropagateConstSpan<word_t> digits;

  int max_size() const {
    return static_cast<int>(digits.size());
  }
  int size() const {
    return n_;
  }
  void set_size(int new_size) {
    n_ = new_size;
  }
  int inc_size() {
    return n_++;
  }
  void dec_size() {
    n_--;
  }

  bool is_valid() const {
    return size() > 0;
  }
  void enforce_valid() const {
    enforce(is_valid());
  }
  void invalidate() {
    set_size(0);
  }
  bool invalidate_bool() {
    set_size(0);
    return false;
  }
  void enforce(bool f) const {
    if (!f) {
      throw IntOverflow();
    }
  }
  void operator=(word_t y) {
    set_size(1);
    digits[0] = y;
  }

  bool normalize_bool_any();
  bool set_pow2_any(int exponent);
  bool set_any(const AnyIntView& yp);
  bool add_pow2_any(int exponent, int factor);
  bool add_any(const AnyIntView& yp);
  bool sub_any(const AnyIntView& yp);

  template <class LogOp>
  bool log_op_any(const AnyIntView& yp);

  int cmp_any(const AnyIntView& yp) const;
  int cmp_any(word_t y) const;

  template <class T = TransformId<word_t>>
  int cmp_un_any(const AnyIntView& yp) const;

  void negate_any();

  int sgn_un_any() const;
  bool get_bit_any(unsigned bit) const;
  bool eq_any(const AnyIntView& yp) const;
  bool eq_any(word_t y) const;
  void mul_tiny_any(int y);
  int divmod_tiny_any(int y);
  word_t divmod_short_any(word_t y);
  bool mul_add_short_any(word_t y, word_t z);
  bool add_mul_any(const AnyIntView& yp, const AnyIntView& zp);
  void add_mul_trunc_any(const AnyIntView& yp, const AnyIntView& zp);
  bool mod_div_any(const AnyIntView& yp, AnyIntView& quot, int round_mode);
  bool mod_pow2_any(int exponent);
  bool mod_pow2_any(int exponent, int round_mode);
  bool rshift_any(int exponent, int round_mode = -1);
  bool lshift_any(int exponent);
  bool unsigned_fits_bits_any(int nbits) const;
  bool signed_fits_bits_any(int nbits) const;
  int bit_size_any(bool sgnd = true) const;
  bool export_bytes_any(unsigned char* buff, std::size_t size, bool sgnd = true) const;
  bool export_bytes_lsb_any(unsigned char* buff, std::size_t size, bool sgnd = true) const;
  bool import_bytes_any(const unsigned char* buff, std::size_t size, bool sgnd = true);
  bool import_bytes_lsb_any(const unsigned char* buff, std::size_t size, bool sgnd = true);
  bool export_bits_any(unsigned char* buff, int offs, unsigned bits, bool sgnd = true) const;
  bool import_bits_any(const unsigned char* buff, int offs, unsigned bits, bool sgnd = true);
  word_t top_word() const {
    return digits[size() - 1];
  }
  double top_double() const {
    return size() > 1 ? (double)digits[size() - 1] + (double)digits[size() - 2] * (1.0 / Tr::Base)
                      : (double)digits[size() - 1];
  }
  word_t to_long_any() const;
  int parse_hex_any(const char* str, int str_len, int* frac = nullptr);
  int parse_binary_any(const char* str, int str_len, int* frac = nullptr);
  std::string to_dec_string_destroy_any();
  std::string to_dec_string_slow_destroy_any();
  std::string to_hex_string_any(bool upcase = false) const;
  std::string to_hex_string_slow_destroy_any();
  std::string to_binary_string_any() const;

  int sgn() const {
    return is_valid() ? (top_word() > 0 ? 1 : (top_word() < 0 ? -1 : 0)) : 0x80000000;
  }
};

template <int len, class Tr = BigIntInfo>
class BigIntG {
 public:
  enum { word_bits = Tr::word_bits, word_shift = Tr::word_shift, max_bits = len, word_cnt = len / word_shift + 1 };
  typedef typename Tr::word_t word_t;
  typedef Tr Traits;
  typedef BigIntG<len * 2, Tr> DoubleInt;

  AnyIntView<Tr> as_any_int() {
    return AnyIntView<Tr>{n, PropagateConstSpan<word_t>(digits, word_cnt)};
  }

  const AnyIntView<Tr> as_any_int() const {
    return AnyIntView<Tr>{const_cast<int&>(n), PropagateConstSpan<word_t>(const_cast<word_t*>(digits), word_cnt)};
  }

 private:
  template <int bits2, class Tr2>
  friend class BigIntG;

  int n;
  word_t digits[word_cnt];

 public:
  BigIntG() : n(0) {
  }
  explicit BigIntG(word_t x) : n(1) {
    digits[0] = x;
  }
  BigIntG(const BigIntG& x) : n(x.n) {
    std::memcpy(digits, x.digits, n * sizeof(word_t));
    ///std::cout << "(BiCC " << (const void*)&x << "->" << (void*)this << ")";
  }
  template <int len2>
  BigIntG(const BigIntG<len2, Tr>& y) : n(0) {
    *this = y;
  }
  void enforce(bool f) const {
    if (!f) {
      throw IntOverflow();
    }
  }
  void ignore(bool f) const {
  }
  bool is_valid() const {
    return n > 0;
  }
  void enforce_valid() const {
    enforce(is_valid());
  }
  BigIntG& invalidate() {
    n = 0;
    return *this;
  }
  bool invalidate_bool() {
    n = 0;
    return false;
  }
  BigIntG& invalidate_unless(bool f) {
    if (!f) {
      n = 0;
    }
    return *this;
  }
  bool normalize_bool() {
    return as_any_int().normalize_bool_any();
  }
  BigIntG& normalize() {
    ignore(normalize_bool());
    return *this;
  }
  BigIntG& denormalize();
  int sgn() const {
    return is_valid() ? (top_word() > 0 ? 1 : (top_word() < 0 ? -1 : 0)) : 0x80000000;
  }
  int sgn_un() const {
    return as_any_int().sgn_un_any();
  }
  bool get_bit(unsigned bit) const {
    return as_any_int().get_bit_any(bit);
  }
  BigIntG& negate() {
    as_any_int().negate_any();
    return *this;
  }
  BigIntG& logical_not();

  BigIntG& operator=(const BigIntG& y) {
    n = y.n;
    std::memcpy(digits, y.digits, n * sizeof(word_t));
    ///std::cout << "(BiC=)";
    return *this;
  }

  template <int len2>
  BigIntG& operator=(const BigIntG<len2, Tr>& y) {
    return invalidate_unless(as_any_int().set_any(y.as_any_int()));
  }

  template <int len2>
  BigIntG& operator+=(const BigIntG<len2, Tr>& y) {
    ignore(as_any_int().add_any(y.as_any_int()));
    return *this;
  }

  template <int len2>
  BigIntG& operator-=(const BigIntG<len2, Tr>& y) {
    ignore(as_any_int().sub_any(y.as_any_int()));
    return *this;
  }

  template <int len2>
  BigIntG& operator&=(const BigIntG<len2, Tr>& y) {
    ignore(as_any_int().template log_op_any<LogOpAnd<word_t>>(y.as_any_int()));
    return *this;
  }

  template <int len2>
  BigIntG& operator|=(const BigIntG<len2, Tr>& y) {
    ignore(as_any_int().template log_op_any<LogOpOr<word_t>>(y.as_any_int()));
    return *this;
  }

  template <int len2>
  BigIntG& operator^=(const BigIntG<len2, Tr>& y) {
    ignore(as_any_int().template log_op_any<LogOpXor<word_t>>(y.as_any_int()));
    return *this;
  }

  BigIntG& operator>>=(int shift) {
    as_any_int().rshift_any(shift);
    return *this;
  }

  BigIntG& operator<<=(int shift) {
    as_any_int().lshift_any(shift);
    return *this;
  }

  BigIntG& rshift(int shift, int round_mode = -1) {
    as_any_int().rshift_any(shift, round_mode);
    return *this;
  }

  template <int len2>
  int cmp(const BigIntG<len2, Tr>& y) const {
    return as_any_int().cmp_any(y.as_any_int());
  }

  template <int len2>
  int cmp_un(const BigIntG<len2, Tr>& y) const {
    return as_any_int().template cmp_un_any<TransformId<word_t>>(y.as_any_int());
  }

  template <int len2>
  bool operator==(const BigIntG<len2, Tr>& y) const {
    return as_any_int().eq_any(y.as_any_int());
  }

  template <int len2>
  bool operator!=(const BigIntG<len2, Tr>& y) const {
    return !(*this == y);
  }

  int cmp(word_t y) const {
    return as_any_int().cmp_any(y);
  }

  bool operator==(word_t y) const {
    return as_any_int().eq_any(y);
  }

  bool operator!=(word_t y) const {
    return !(*this == y);
  }
  bool mul_add_short_bool(word_t y, word_t z) {
    return as_any_int().mul_add_short_any(y, z);
  }

  template <int len2, int len3>
  bool add_mul_bool(const BigIntG<len2, Tr>& y, const BigIntG<len3, Tr>& z) {
    return as_any_int().add_mul_any(y.as_any_int(), z.as_any_int());
  }

  template <int len2, int len3>
  BigIntG& add_mul(const BigIntG<len2, Tr>& y, const BigIntG<len3, Tr>& z) {
    ignore(add_mul_bool(y, z));
    return *this;
  }

  template <int len2, int len3>
  void add_mul_trunc(const BigIntG<len2, Tr>& y, const BigIntG<len3, Tr>& z) {
    as_any_int().add_mul_trunc_any(y.as_any_int(), z.as_any_int());
  }

  BigIntG& mul_short(word_t y) {
    return invalidate_unless(mul_add_short_bool(y, 0));
  }

  BigIntG& mul_tiny(int y) {
    as_any_int().mul_tiny_any(y);
    return *this;
  }

  BigIntG& add_tiny(word_t y) {
    digits[0] += y;
    return *this;
  }

  BigIntG& sub_tiny(word_t y) {
    digits[0] -= y;
    return *this;
  }

  BigIntG& mul_short_opt(word_t y) {
    if (y <= Tr::MaxDenorm && y >= -Tr::MaxDenorm) {
      return mul_tiny(static_cast<int>(y));
    } else {
      return mul_short(y);
    }
  }

  template <int len2, int len3>
  bool mod_div_bool(const BigIntG<len2, Tr>& y, BigIntG<len3, Tr>& quot, int round_mode = -1) {
    auto q = quot.as_any_int();
    return as_any_int().mod_div_any(y.as_any_int(), q, round_mode);
  }

  template <int len2, int len3>
  BigIntG& mod_div(const BigIntG<len2, Tr>& y, BigIntG<len3, Tr>& quot, int round_mode = -1) {
    return invalidate_unless(mod_div_bool(y, quot, round_mode));
  }

  int divmod_tiny(int y) {
    return as_any_int().divmod_tiny_any(y);
  }

  word_t divmod_short(word_t y) {
    return as_any_int().divmod_short_any(y);
  }

  BigIntG& operator=(word_t y) {
    n = 1;
    digits[0] = y;
    return *this;
  }

  BigIntG& set_zero() {
    n = 1;
    digits[0] = 0;
    return *this;
  }

  BigIntG& set_pow2(int exponent) {
    return invalidate_unless(as_any_int().set_pow2_any(exponent));
  }

  bool set_pow2_bool(int exponent) {
    return as_any_int().set_pow2_any(exponent);
  }

  BigIntG& mod_pow2(int exponent) {
    return invalidate_unless(as_any_int().mod_pow2_any(exponent));
  }

  BigIntG& mod_pow2(int exponent, int round_mode) {
    return invalidate_unless(as_any_int().mod_pow2_any(exponent, round_mode));
  }

  BigIntG& add_pow2(int exponent) {
    return invalidate_unless(as_any_int().add_pow2_any(exponent, 1));
  }

  BigIntG& sub_pow2(int exponent) {
    return invalidate_unless(as_any_int().add_pow2_any(exponent, -1));
  }

  bool unsigned_fits_bits(int nbits) const {
    return as_any_int().unsigned_fits_bits_any(nbits);
  }

  bool signed_fits_bits(int nbits) const {
    return as_any_int().signed_fits_bits_any(nbits);
  }

  bool fits_bits(int nbits, bool sgnd = true) const {
    return sgnd ? signed_fits_bits(nbits) : unsigned_fits_bits(nbits);
  }

  int bit_size(bool sgnd = true) const {
    return as_any_int().bit_size_any(sgnd);
  }

  bool export_bytes(unsigned char* buff, std::size_t size, bool sgnd = true) const {
    return as_any_int().export_bytes_any(buff, size, sgnd);
  }

  bool export_bytes_lsb(unsigned char* buff, std::size_t size, bool sgnd = true) const {
    return as_any_int().export_bytes_lsb_any(buff, size, sgnd);
  }

  bool import_bytes(const unsigned char* buff, std::size_t size, bool sgnd = true) {
    return as_any_int().import_bytes_any(buff, size, sgnd);
  }

  bool import_bytes_lsb(const unsigned char* buff, std::size_t size, bool sgnd = true) {
    return as_any_int().import_bytes_lsb_any(buff, size, sgnd);
  }

  bool export_bits(unsigned char* buff, int offs, unsigned bits, bool sgnd = true) const {
    return as_any_int().export_bits_any(buff, offs, bits, sgnd);
  }

  bool export_bits(td::BitPtr bp, unsigned bits, bool sgnd = true) const {
    return as_any_int().export_bits_any(bp.ptr, bp.offs, bits, sgnd);
  }

  template <typename T>
  bool export_bits(T& bs, bool sgnd = true) const {
    return export_bits(bs.bits(), bs.size(), sgnd);
  }

  bool export_bits(const BitSliceWrite& bs, bool sgnd = true) const {
    return export_bits(bs.bits(), bs.size(), sgnd);
  }

  bool import_bits(const unsigned char* buff, int offs, unsigned bits, bool sgnd = true) {
    return as_any_int().import_bits_any(buff, offs, bits, sgnd);
  }

  bool import_bits(td::ConstBitPtr bp, unsigned bits, bool sgnd = true) {
    return as_any_int().import_bits_any(bp.ptr, bp.offs, bits, sgnd);
  }

  template <typename T>
  bool import_bits(const T& bs, bool sgnd = true) {
    return import_bits(bs.bits(), bs.size(), sgnd);
  }

  std::ostream& dump(std::ostream& os, bool nl = true) const;
  std::string dump() const;
  int parse_dec(const char* str, int str_len, int* frac = nullptr);
  int parse_dec(const std::string str, int* frac = nullptr) {
    return parse_dec(str.c_str(), (int)str.size(), frac);
  }
  int parse_dec_slow(const char* str, int str_len);
  int parse_dec_slow(const std::string str) {
    return parse_dec_slow(str.c_str(), (int)str.size());
  }
  int parse_hex(const char* str, int str_len, int* frac = nullptr) {
    return as_any_int().parse_hex_any(str, str_len, frac);
  }
  int parse_hex(const std::string str, int* frac = nullptr) {
    return parse_hex(str.c_str(), (int)str.size(), frac);
  }
  int parse_binary(const char* str, int str_len, int* frac = nullptr) {
    return as_any_int().parse_binary_any(str, str_len, frac);
  }
  int parse_binary(const std::string str, int* frac = nullptr) {
    return parse_binary(str.c_str(), (int)str.size(), frac);
  }
  std::string to_dec_string() const;
  std::string to_dec_string_destroy();
  std::string to_dec_string_slow() const;
  std::string to_hex_string_slow() const;
  std::string to_hex_string(bool upcase = false) const;
  std::string to_binary_string() const;
  double to_double() const {
    return is_valid() ? ldexp(top_double(), (n - 1) * word_shift) : NAN;
  }
  word_t to_long() const {
    return as_any_int().to_long_any();
  }

 private:
  word_t top_word() const {
    return digits[n - 1];
  }
  double top_double() const {
    return n > 1 ? (double)digits[n - 1] + (double)digits[n - 2] * (1.0 / Tr::Base) : (double)digits[n - 1];
  }
};

template <class Tr>
bool AnyIntView<Tr>::normalize_bool_any() {
  word_t val = 0;
  int i;
  if (!is_valid()) {
    return false;
  }
  for (i = 0; i < size() && digits[i] < Tr::Half && digits[i] >= -Tr::Half; i++) {
  }
  for (; i < size(); i++) {
    val += digits[i] + Tr::Half;
    digits[i] = (val & (Tr::Base - 1)) - Tr::Half;
    val >>= word_shift;
  }
  if (val) {
    do {
      if (size() == max_size()) {
        return invalidate_bool();
      }
      val += Tr::Half;
      digits[inc_size()] = (val & (Tr::Base - 1)) - Tr::Half;
      val >>= word_shift;
    } while (val);
  }
  while (size() > 1 && !digits[size() - 1]) {
    dec_size();
  }
  return true;
}

template <class Tr>
bool AnyIntView<Tr>::set_pow2_any(int exponent) {
  if (exponent < 0 || exponent >= max_size() * word_shift) {
    invalidate();
    return false;
  }
  auto dm = std::div(exponent, word_shift);
  int k = dm.quot;
  std::memset(digits.data(), 0, k * sizeof(word_t));
  if (dm.rem == word_shift - 1 && k + 1 < max_size()) {
    digits[k] = -Tr::Half;
    digits[k + 1] = 1;
    set_size(k + 2);
    return true;
  }
  digits[k] = ((word_t)1 << dm.rem);
  set_size(k + 1);
  return true;
}

template <class Tr>
bool AnyIntView<Tr>::set_any(const AnyIntView<Tr>& yp) {
  if (yp.size() <= max_size()) {
    set_size(yp.size());
    std::memcpy(digits.data(), yp.digits.data(), size() * sizeof(word_t));
    return true;
  } else {
    set_size(max_size());
    std::memcpy(digits.data(), yp.digits.data(), size() * sizeof(word_t));
    return false;
  }
}

template <class Tr>
bool AnyIntView<Tr>::add_pow2_any(int exponent, int factor) {
  if (exponent < 0 || exponent >= max_size() * word_shift) {
    invalidate();
    return false;
  }
  if (!is_valid()) {
    return false;
  }
  auto dm = std::div(exponent, word_shift);
  int k = dm.quot;
  while (size() <= k) {
    digits[inc_size()] = 0;
  }
  digits[k] += (factor << dm.rem);
  return true;
}

template <class Tr>
bool AnyIntView<Tr>::add_any(const AnyIntView<Tr>& yp) {
  if (yp.size() <= size()) {
    if (!yp.is_valid()) {
      return invalidate_bool();
    }
    for (int i = 0; i < yp.size(); i++) {
      digits[i] += yp.digits[i];
    }
    return true;
  } else {
    if (!is_valid()) {
      return false;
    }
    if (yp.size() > max_size()) {
      return invalidate_bool();
    }
    for (int i = 0; i < size(); i++) {
      digits[i] += yp.digits[i];
    }
    for (int i = size(); i < yp.size(); i++) {
      digits[i] = yp.digits[i];
    }
    set_size(yp.size());
    return true;
  }
}

template <class Tr>
bool AnyIntView<Tr>::sub_any(const AnyIntView<Tr>& yp) {
  if (yp.size() <= size()) {
    if (!yp.is_valid()) {
      return invalidate_bool();
    }
    for (int i = 0; i < yp.size(); i++) {
      digits[i] -= yp.digits[i];
    }
    return true;
  } else {
    if (!is_valid()) {
      return false;
    }
    if (yp.size() > max_size()) {
      return invalidate_bool();
    }
    for (int i = 0; i < size(); i++) {
      digits[i] -= yp.digits[i];
    }
    for (int i = size(); i < yp.size(); i++) {
      digits[i] = -yp.digits[i];
    }
    set_size(yp.size());
    return true;
  }
}

template <class Tr>
template <class LogOp>
bool AnyIntView<Tr>::log_op_any(const AnyIntView<Tr>& yp) {
  word_t cx = 0, cy = 0, cz = 0;
  int i = 0;
  const int shift = Tr::word_shift;
  if (size() == 1) {
    if (LogOp::has_zero && digits[0] == LogOp::zero) {
      return true;
    } else if (digits[0] == LogOp::neutral) {
      if (yp.size() <= max_size()) {
        set_size(yp.size());
        std::memcpy(digits.data(), yp.digits.data(), size() * sizeof(word_t));
        return true;
      } else {
        return invalidate_bool();
      }
    }
  }
  if (yp.size() == 1) {
    if (LogOp::has_zero && yp.digits[0] == LogOp::zero) {
      set_size(1);
      digits[0] = LogOp::zero;
      return true;
    } else if (yp.digits[0] == LogOp::neutral) {
      return true;
    }
  }
  if (yp.size() <= size()) {
    if (!yp.is_valid()) {
      return invalidate_bool();
    }
    for (; i < yp.size(); i++) {
      cx += digits[i];
      cy += yp.digits[i];
      cz += (LogOp::op(cx, cy) & (Tr::Base - 1)) + Tr::Half;
      cx >>= shift;
      cy >>= shift;
      digits[i] = (cz & (Tr::Base - 1)) - Tr::Half;
      cz >>= shift;
    }
    for (; i < size(); i++) {
      cx += digits[i];
      cz += (LogOp::op(cx, cy) & (Tr::Base - 1)) + Tr::Half;
      cx >>= shift;
      cy >>= shift;
      digits[i] = (cz & (Tr::Base - 1)) - Tr::Half;
      cz >>= shift;
    }
    cz += LogOp::op(cx, cy);
    if (cz) {
      if (size() >= max_size()) {
        return invalidate_bool();
      }
      digits[inc_size()] = cz;
    } else {
      while (size() > 1 && !digits[size() - 1]) {
        dec_size();
      }
    }
    return true;
  } else {
    if (!is_valid()) {
      return false;
    }
    for (; i < size(); i++) {
      cx += digits[i];
      cy += yp.digits[i];
      cz += (LogOp::op(cx, cy) & (Tr::Base - 1)) + Tr::Half;
      cx >>= shift;
      cy >>= shift;
      digits[i] = (cz & (Tr::Base - 1)) - Tr::Half;
      cz >>= shift;
    }
    set_size(std::min(yp.size(), max_size()));
    for (; i < size(); i++) {
      cy += yp.digits[i];
      cz += (LogOp::op(cx, cy) & (Tr::Base - 1)) + Tr::Half;
      cx >>= shift;
      cy >>= shift;
      digits[i] = (cz & (Tr::Base - 1)) - Tr::Half;
      cz >>= shift;
    }
    if (yp.size() > size()) {
      for (; i < yp.size(); i++) {
        cy += yp.digits[i];
        cz += (LogOp::op(cx, cy) & (Tr::Base - 1));
        cx >>= shift;
        cy >>= shift;
        if ((cz & (Tr::Base - 1)) != 0) {
          return invalidate_bool();
        }
        cz >>= shift;
      }
    }
    cz += LogOp::op(cx, cy);
    if (cz) {
      return invalidate_bool();
    }
    while (size() > 1 && !digits[size() - 1]) {
      dec_size();
    }
    return true;
  }
}

template <class Tr>
bool AnyIntView<Tr>::add_mul_any(const AnyIntView<Tr>& yp, const AnyIntView<Tr>& zp) {
  int yn = yp.size(), zn = zp.size(), rn = yn + zn;
  if (!yp.is_valid() || !zp.is_valid() || !is_valid()) {
    return invalidate_bool();
  }
  if (rn > max_size() + 1) {
    return invalidate_bool();
  } else if (rn < max_size() + 1) {
    while (size() < rn) {
      digits[inc_size()] = 0;
    }
    for (int i = 0; i < yn; i++) {
      word_t yv = yp.digits[i];
      for (int j = 0; j < zn; j++) {
        Tr::add_mul(&digits[i + j + 1], &digits[i + j], yv, zp.digits[j]);
      }
    }
  } else {
    while (size() < rn - 1) {
      digits[inc_size()] = 0;
    }
    int i;
    for (i = 0; i < yn - 1; i++) {
      word_t yv = yp.digits[i];
      for (int j = 0; j < zn; j++) {
        Tr::add_mul(&digits[i + j + 1], &digits[i + j], yv, zp.digits[j]);
      }
    }
    word_t yv = yp.digits[i];
    int j;
    for (j = 0; j < zn - 1; j++) {
      Tr::add_mul(&digits[i + j + 1], &digits[i + j], yv, zp.digits[j]);
    }
    word_t hi = 0;
    Tr::add_mul(&hi, &digits[i + j], yv, zp.digits[j]);
    if (hi && hi != -1) {
      return invalidate_bool();
    }
    digits[size() - 1] += (hi << word_shift);
  }
  return true;
}

template <class Tr>
void AnyIntView<Tr>::add_mul_trunc_any(const AnyIntView<Tr>& yp, const AnyIntView<Tr>& zp) {
  int yn = yp.size(), zn = zp.size();
  if (!yp.is_valid() || !zp.is_valid() || !is_valid()) {
    invalidate();
    return;
  }
  int xn = std::min(yn + zn, max_size());
  while (size() < xn) {
    digits[inc_size()] = 0;
  }
  xn = size();
  for (int i = 0; i < yn && i < xn; i++) {
    word_t yv = yp.digits[i];
    for (int j = 0; j < zn; j++) {
      if (i + j + 1 < xn) {
        Tr::add_mul(&digits[i + j + 1], &digits[i + j], yv, zp.digits[j]);
      } else {
        word_t hi = 0;
        Tr::add_mul(&hi, &digits[i + j], yv, zp.digits[j]);
        break;
      }
    }
  }
}

template <class Tr>
int AnyIntView<Tr>::sgn_un_any() const {
  if (!is_valid()) {
    return 0;
  }
  word_t v = digits[size() - 1];
  if (size() >= 2) {
    if (v >= Tr::MaxDenorm) {
      return 1;
    } else if (v <= -Tr::MaxDenorm) {
      return -1;
    }
    int i = size() - 2;
    do {
      v <<= word_shift;
      word_t w = digits[i];
      if (w >= -v + Tr::MaxDenorm) {
        return 1;
      } else if (w <= -v - Tr::MaxDenorm) {
        return -1;
      }
      v += w;
    } while (--i >= 0);
  }
  return (v > 0 ? 1 : (v < 0 ? -1 : 0));
}

template <class Tr>
bool AnyIntView<Tr>::get_bit_any(unsigned bit) const {
  if (!is_valid()) {
    return 0;
  }
  if (bit >= (unsigned)size() * word_shift) {
    return sgn() < 0;
  }
  if (bit < word_shift) {
    return (digits[0] >> bit) & 1;
  }
  auto q = std::div(bit, word_shift);
  int i = q.quot;
  word_t x = digits[i];
  while (--i >= 0) {
    if (digits[i] < 0) {
      --x;
      break;
    } else if (digits[i] > 0) {
      break;
    }
  }
  return (x >> q.rem) & 1;
}

template <class Tr>
typename Tr::word_t AnyIntView<Tr>::to_long_any() const {
  if (!is_valid()) {
    return (~0ULL << 63);
  } else if (size() == 1) {
    return digits[0];
  } else {
    word_t v = digits[0] + (digits[1] << word_shift);  // approximation mod 2^64
    word_t w = (v & (Tr::Base - 1)) - digits[0];
    w >>= word_shift;
    w += (v >> word_shift);  // excess of approximation divided by Tr::Base
    int n = size() - 1;
    for (int i = 1; i < n; i++) {
      w -= digits[i];
      if (w & (Tr::Base - 1)) {
        return (~0ULL << 63);
      }
      w >>= word_shift;
    }
    return w != digits[n] ? (~0ULL << 63) : v;
  }
}

template <class Tr>
int AnyIntView<Tr>::cmp_any(const AnyIntView<Tr>& yp) const {
  if (yp.size() < size()) {
    return top_word() < 0 ? -1 : 1;
  } else if (yp.size() > size()) {
    return yp.top_word() > 0 ? -1 : 1;
  }
  for (int i = size() - 1; i >= 0; i--) {
    if (digits[i] < yp.digits[i]) {
      return -1;
    } else if (digits[i] > yp.digits[i]) {
      return 1;
    }
  }
  return 0;
}

template <class Tr>
int AnyIntView<Tr>::cmp_any(word_t y) const {
  if (size() > 1) {
    return top_word() < 0 ? -1 : 1;
  } else if (size() == 1) {
    return digits[0] < y ? -1 : (digits[0] > y ? 1 : 0);
  } else {
    return 0x80000000;
  }
}

template <class Tr>
template <class T>
int AnyIntView<Tr>::cmp_un_any(const AnyIntView<Tr>& yp) const {
  int xn = size(), yn = yp.size();
  word_t v;
  if (yn < xn) {
    v = T::eval(digits[--xn]);
    if (v >= Tr::MaxDenorm) {
      return 1;
    } else if (v <= -Tr::MaxDenorm) {
      return -1;
    }
    while (xn > yn) {
      v <<= word_shift;
      word_t w = T::eval(digits[--xn]);
      if (w >= -v + Tr::MaxDenorm) {
        return 1;
      } else if (w <= -v + Tr::MaxDenorm) {
        return -1;
      }
      v += w;
    }
  } else if (yn > xn) {
    v = -yp.digits[--yn];
    if (v >= Tr::MaxDenorm) {
      return 1;
    } else if (v <= -Tr::MaxDenorm) {
      return -1;
    }
    while (yn > xn) {
      v <<= word_shift;
      word_t w = yp.digits[--yn];
      if (w <= v - Tr::MaxDenorm) {
        return 1;
      } else if (w >= v + Tr::MaxDenorm) {
        return -1;
      }
      v -= w;
    }
  } else {
    v = 0;
  }
  while (--xn >= 0) {
    v <<= word_shift;
    word_t w = T::eval(digits[xn]) - yp.digits[xn];
    if (w >= -v + Tr::MaxDenorm) {
      return 1;
    } else if (w <= -v - Tr::MaxDenorm) {
      return -1;
    }
    v += w;
  }
  return (v > 0 ? 1 : (v < 0 ? -1 : 0));
}

template <class Tr>
bool AnyIntView<Tr>::eq_any(const AnyIntView<Tr>& yp) const {
  if (yp.size() != size()) {
    return false;
  }
  return !std::memcmp(digits.data(), yp.digits.data(), size() * sizeof(word_t));
}

template <class Tr>
bool AnyIntView<Tr>::eq_any(word_t y) const {
  return (size() == 1 && digits[0] == y);
}

template <class Tr>
void AnyIntView<Tr>::negate_any() {
  for (int i = 0; i < size(); i++) {
    digits[i] = -digits[i];
  }
}

template <class Tr>
void AnyIntView<Tr>::mul_tiny_any(int y) {
  for (int i = 0; i < size(); i++) {
    digits[i] *= y;
  }
}

template <class Tr>
int AnyIntView<Tr>::divmod_tiny_any(int y) {
  if (!y) {
    invalidate();
    return 0;
  }
  int rem = 0;
  for (int i = size() - 1; i >= 0; i--) {
    auto divmod = std::div(digits[i] + ((word_t)rem << word_shift), (word_t)y);
    digits[i] = divmod.quot;
    rem = (int)divmod.rem;
    if ((rem ^ y) < 0 && rem) {
      rem += y;
      digits[i]--;
    }
  }
  while (size() > 1 && !digits[size() - 1]) {
    dec_size();
  }
  return rem;
}

template <class Tr>
typename Tr::word_t AnyIntView<Tr>::divmod_short_any(word_t y) {
  if (!y || !is_valid()) {
    invalidate();
    throw IntOverflow{};
  }
  word_t rem = 0;
  int i = size() - 1;
  if (!i) {
    auto divmod = std::div(digits[0], y);
    digits[0] = divmod.quot;
    rem = divmod.rem;
    if ((rem ^ y) < 0 && rem) {
      rem += y;
      digits[0]--;
    }
    return rem;
  }
  if (std::abs(digits[i]) * 2 < std::abs(y)) {
    rem = digits[i--];
    dec_size();
  }
  do {
    Tr::dbl_divmod(&digits[i], &rem, rem, digits[i], y);
  } while (--i >= 0);
  if ((rem ^ y) < 0 && rem) {
    rem += y;
    digits[0]--;
  }
  while (size() > 1 && !digits[size() - 1]) {
    dec_size();
  }
  return rem;
}

template <class Tr>
bool AnyIntView<Tr>::mul_add_short_any(word_t y, word_t z) {
  if (!is_valid()) {
    return false;
  }
  for (int i = 0; i < size(); i++) {
    word_t newc;
    Tr::set_mul(&newc, digits.data() + i, y, digits[i]);
    digits[i] += z;
    z = newc;
  }
  if (!z) {
    return true;
  }
  if (size() < max_size()) {
    digits[inc_size()] = z;
    return true;
  }
  z += (digits[size() - 1] >> word_shift);
  digits[size() - 1] &= Tr::Base - 1;
  if (!z || z == -1) {
    digits[size() - 1] += (z << word_shift);
    return true;
  } else {
    return false;
  }
}

template <class Tr>
bool AnyIntView<Tr>::mod_div_any(const AnyIntView<Tr>& yp, AnyIntView<Tr>& quot, int round_mode) {
  quot.invalidate();
  if (!is_valid()) {
    return false;
  }
  if (yp.size() == 1) {
    word_t yv = yp.digits[0];
    if (!yv) {
      return false;
    }
    word_t rem = divmod_short_any(yv);
    if (!round_mode) {
      if ((yv > 0 && rem * 2 >= yv) || (yv < 0 && rem * 2 <= yv)) {
        rem -= yv;
        digits[0]++;
      }
    } else if (round_mode > 0 && rem) {
      rem -= yv;
      digits[0]++;
    }
    if (!normalize_bool_any()) {
      return false;
    }
    if (size() > quot.max_size()) {
      return false;
    }
    quot.set_size(size());
    std::memcpy(quot.digits.data(), digits.data(), size() * sizeof(word_t));
    *this = rem;
    return true;
  }
  if (!yp.is_valid()) {
    return invalidate_bool();
  }

  double y_top = yp.top_double();
  if (y_top == 0) {
    // division by zero
    return invalidate_bool();
  }
  double y_inv = (double)Tr::Base / y_top;

  int k = size() - yp.size();
  if (k >= 0) {
    if (std::abs(top_word()) * 2 <= std::abs(yp.top_word())) {
      if (k > quot.max_size()) {
        return invalidate_bool();
      }
      quot.set_size(k);
    } else {
      if (k >= quot.max_size()) {
        return invalidate_bool();
      }
      quot.set_size(k + 1);
      double x_top = top_double();
      word_t q = std::llrint(x_top * y_inv * Tr::InvBase);
      quot.digits[k] = q;
      int i = yp.size() - 1;
      word_t hi = 0;
      Tr::sub_mul(&hi, &digits[k + i], q, yp.digits[i]);
      while (--i >= 0) {
        Tr::sub_mul(&digits[k + i + 1], &digits[k + i], q, yp.digits[i]);
      }
      digits[size() - 1] += (hi << word_shift);
    }
  } else {
    quot.set_size(1);
    quot.digits[0] = 0;
  }
  while (--k >= 0) {
    double x_top = top_double();
    word_t q = std::llrint(x_top * y_inv);
    quot.digits[k] = q;
    for (int i = yp.size() - 1; i >= 0; --i) {
      Tr::sub_mul(&digits[k + i + 1], &digits[k + i], q, yp.digits[i]);
    }
    dec_size();
    digits[size() - 1] += (digits[size()] << word_shift);
  }
  if (size() >= yp.size()) {
    assert(size() == yp.size());
    double x_top = top_double();
    double t = x_top * y_inv * Tr::InvBase;
    if (round_mode >= 0) {
      t += (round_mode ? 1 : 0.5);
    }
    word_t q = std::llrint(std::floor(t));
    if (q) {
      for (int i = 0; i < size(); i++) {
        digits[i] -= q * yp.digits[i];
      }
      quot.digits[0] += q;
    }
  }

  int q_adj = 0, sy = (y_inv > 0 ? 1 : -1);
  if (round_mode < 0) {
    // floor: must have 0 <= rem < y or 0 >= rem > y
    int sr = sgn_un_any();
    if (sr * sy < 0) {
      q_adj = -1;
    } else {
      sr = cmp_un_any<TransformId<word_t>>(yp);
      if (sr * sy >= 0) {
        q_adj = 1;
      }
    }
  } else if (round_mode > 0) {
    // ceil: must have -y < rem <= 0 or -y > rem >= 0
    int sr = sgn_un_any();
    if (sr * sy > 0) {
      q_adj = 1;
    } else {
      sr = cmp_un_any<TransformNegate<word_t>>(yp);  // -rem ?? y
      if (sr * sy >= 0) {
        q_adj = -1;
      }
    }
  } else {
    // round: must have -y <= 2*rem < y or -y >= 2*rem > y
    int sr = sgn_un_any();
    if (sr * sy > 0) {
      // y and rem same sign, check 2*rem < y or 2*rem > y
      sr = cmp_un_any<TransformMul<word_t, 2>>(yp);
      if (sr * sy >= 0) {
        q_adj = 1;
      }
    } else {
      // y and rem different sign, check 2*rem >= -y or 2*rem <= -y
      sr = cmp_un_any<TransformMul<word_t, -2>>(yp);
      if (sr * sy > 0) {
        q_adj = -1;
      }
    }
  }
  if (q_adj) {
    quot.digits[0] += q_adj;
    if (q_adj < 0 ? !add_any(yp) : !sub_any(yp)) {
      return invalidate_bool();
    }
  }
  return normalize_bool_any();
}

template <class Tr>
bool AnyIntView<Tr>::mod_pow2_any(int exponent) {
  if (!is_valid()) {
    return false;
  }
  if (exponent <= 0) {
    *this = 0;
    return true;
  }
  int q = exponent - (size() - 1) * word_shift;
  if (q >= word_bits) {
    if (sgn() >= 0) {
      return true;
    }
    if (exponent >= max_size() * word_shift) {
      return invalidate_bool();
    }
    while (q >= word_shift) {
      digits[inc_size()] = 0;
      q -= word_shift;
    }
    if (q == word_shift - 1 && size() < max_size()) {
      digits[size() - 1] = -Tr::Half;
      digits[inc_size()] = 1;
    } else {
      digits[size() - 1] = ((word_t)1 << q);
    }
    return true;
  }
  while (q < 0) {
    dec_size();
    q += word_shift;
  }
  word_t pow = ((word_t)1 << q);
  word_t v = digits[size() - 1] & (pow - 1);
  if (!v) {
    int k = size() - 1;
    while (k > 0 && !digits[k - 1]) {
      --k;
    }
    if (!k) {
      *this = 0;
      return true;
    }
    if (digits[k - 1] > 0) {
      set_size(k);
      return true;
    }
    if (exponent >= max_size() * word_shift) {
      return invalidate_bool();
    }
    if (q - word_shift >= 0) {
      digits[size() - 1] = 0;
      digits[inc_size()] = ((word_t)1 << (q - word_shift));
    }
    if (q - word_shift == -1 && size() < max_size() - 1) {
      digits[size() - 1] = -Tr::Half;
      digits[inc_size()] = 1;
    } else {
      digits[size() - 1] = pow;
    }
    return true;
  } else if (v >= Tr::Half) {
    if (size() == max_size() - 1) {
      return invalidate_bool();
    } else {
      digits[size() - 1] = v | -Tr::Half;
      digits[inc_size()] = ((word_t)1 << (q - word_shift));
      return true;
    }
  } else {
    digits[size() - 1] = v;
    return true;
  }
}

template <class Tr>
bool AnyIntView<Tr>::mod_pow2_any(int exponent, int round_mode) {
  if (round_mode < 0) {
    return mod_pow2_any(exponent);
  }
  if (!is_valid()) {
    return false;
  }
  if (exponent <= 0) {
    *this = 0;
    return true;
  }
  if (round_mode > 0) {
    negate_any();
    bool res = mod_pow2_any(exponent);
    negate_any();
    return res;
  }
  if (signed_fits_bits_any(exponent)) {
    return true;
  }
  if (!mod_pow2_any(exponent)) {
    return false;
  }
  if (!unsigned_fits_bits_any(exponent - 1)) {
    return add_pow2_any(exponent, -1);
  }
  return true;
}

template <class Tr>
bool AnyIntView<Tr>::rshift_any(int exponent, int round_mode) {
  if (exponent < 0) {
    return invalidate_bool();
  }
  if (!exponent) {
    return true;
  }
  if (exponent > size() * word_shift + word_bits - word_shift) {
    if (!round_mode) {
      *this = 0;
    } else if (round_mode < 0) {
      *this = (sgn() < 0 ? -1 : 0);
    } else {
      *this = (sgn() > 0 ? 1 : 0);
    }
    return true;
  }
  int q = exponent / word_shift, r = exponent % word_shift;
  assert(q <= size());

  if (!round_mode && !r) {
    digits[q - 1] += Tr::Half;
    round_mode = -1;
  }

  word_t v = (round_mode > 0 ? -1 : 0);
  for (int i = 0; i < q; i++) {
    v += digits[i];
    v >>= word_shift;
  }

  set_size(size() - q);
  if (!size()) {
    if (!round_mode) {
      *this = (((v >> (r - 1)) + 1) >> 1);
    } else {
      *this = (v >> r) + (round_mode > 0);
    }
    return true;
  }

  if (!r) {
    std::memmove(digits.data(), digits.data() + q, size() * sizeof(word_t));
    digits[0] += v + (round_mode > 0);
    return true;
  }

  v += digits[q];
  if (!round_mode) {
    v = (((v >> (r - 1)) + 1) >> 1);
  } else {
    v >>= r;
    v += (round_mode > 0);
  }

  word_t mask = ((word_t)1 << r) - 1;
  for (int i = 1; i < size(); i++) {
    word_t w = digits[q + i];
    v += ((w & mask) << (word_shift - r));
    digits[i - 1] = v;
    v = (w >> r);
  }
  digits[size() - 1] = v;
  return true;
}

template <class Tr>
bool AnyIntView<Tr>::lshift_any(int exponent) {
  if (exponent < 0) {
    return invalidate_bool();
  }
  if (!exponent) {
    return true;
  }
  int q = exponent / word_shift, r = exponent % word_shift;
  if (size() + q > max_size()) {
    return invalidate_bool();
  }
  if (!r) {
    std::memmove(digits.data() + q, digits.data(), size() * sizeof(word_t));
    std::memset(digits.data(), 0, q * sizeof(word_t));
    set_size(size() + q);
    return true;
  }

  word_t v = 0, mask = (Tr::Base >> r) - 1;
  for (int i = 0; i < size(); i++) {
    word_t w = digits[i];
    v += ((w & mask) << r);
    digits[i] = v;
    v = (w >> (word_shift - r));
  }
  if (v) {
    if (size() + q < max_size()) {
      digits[inc_size()] = v;
    } else if (v != -1) {
      return invalidate_bool();
    } else {
      digits[size() - 1] += (v << word_shift);
    }
  }
  if (q) {
    std::memmove(digits.data() + q, digits.data(), size() * sizeof(word_t));
    std::memset(digits.data(), 0, q * sizeof(word_t));
    set_size(size() + q);
  }
  return true;
}

template <class Tr>
bool AnyIntView<Tr>::unsigned_fits_bits_any(int nbits) const {
  if (!is_valid()) {
    return false;
  }
  if (sgn() < 0) {
    return false;
  }
  if (!sgn()) {
    return true;
  }
  if (nbits >= size() * word_shift) {
    return true;
  }
  if (nbits < 0) {
    return false;
  }
  auto dm = std::div(nbits, word_shift);
  int k = dm.quot;
  if (size() >= k + 2) {
    if (!(size() == k + 2 && dm.rem == word_shift - 1)) {
      return false;
    }
    if (digits[k + 1] != 1) {
      return false;
    }
    if (digits[k] > -Tr::Half) {
      return false;
    } else if (digits[k] < -Tr::Half) {
      return true;
    }
  } else {
    if (size() <= k) {
      return true;
    }
    word_t pow = ((word_t)1 << dm.rem);
    if (digits[k] > pow) {
      return false;
    } else if (digits[k] < pow) {
      return true;
    }
  }
  while (--k >= 0) {
    if (digits[k] < 0) {
      return true;
    } else if (digits[k] > 0) {
      return false;
    }
  }
  return false;
}

template <class Tr>
bool AnyIntView<Tr>::signed_fits_bits_any(int nbits) const {
  if (!is_valid()) {
    return false;
  }
  if (nbits > size() * word_shift) {
    return true;
  }
  int s = sgn();
  if (!s) {
    return true;
  }
  if (nbits <= 0) {
    return false;
  }
  auto dm = std::div(nbits - 1, word_shift);
  int k = dm.quot;
  if (size() <= k) {
    return true;
  }
  if (size() >= k + 2) {
    if (!(size() == k + 2 && dm.rem == word_shift - 1)) {
      return false;
    }
    if (digits[k + 1] != s) {
      return false;
    }
    word_t val = (s > 0 ? digits[k] : -digits[k]);
    if (val > -Tr::Half) {
      return false;
    } else if (val < -Tr::Half) {
      return true;
    }
  } else {
    word_t val = (s > 0 ? digits[k] : -digits[k]);
    word_t pow = ((word_t)1 << dm.rem);
    if (val > pow) {
      return false;
    } else if (val < pow) {
      return true;
    }
  }
  while (--k >= 0) {
    if (digits[k] < 0) {
      return s > 0;
    } else if (digits[k] > 0) {
      return s < 0;
    }
  }
  return s < 0;
}

template <class Tr>
int AnyIntView<Tr>::bit_size_any(bool sgnd) const {
  if (!is_valid()) {
    return 0x7fffffff;
  }
  int sg = sgn();
  if (!sg) {
    return 0;
  } else if (sg >= 0) {
    int k = size() - 1;
    word_t q = digits[k];
    if (k > 0 && q < Tr::MaxDenorm / 2) {
      q <<= word_shift;
      q += digits[--k];
    }
    if (!k) {
      int s = 64 - td::count_leading_zeroes64(q);
      return s + sgnd;
    }
    int s = 64 - td::count_leading_zeroes64(q - Tr::MaxDenorm / 4);
    q -= (word_t)1 << s;
    s += k * word_shift + sgnd;
    while (k > 0) {
      if (q >= Tr::MaxDenorm / 2) {
        return s + 1;
      } else if (q <= -Tr::MaxDenorm / 2) {
        return s;
      }
      q <<= word_shift;
      q += digits[--k];
    }
    return q >= 0 ? s + 1 : s;
  } else if (sgnd) {
    int k = size() - 1;
    word_t q = digits[k];
    if (k > 0 && q > -Tr::MaxDenorm / 2) {
      q <<= word_shift;
      q += digits[--k];
    }
    if (!k) {
      int s = 64 - td::count_leading_zeroes64(~q);
      return s + 1;
    }
    int s = 64 - td::count_leading_zeroes64(-q - Tr::MaxDenorm / 4);
    q += (word_t)1 << s;
    s += k * word_shift + 1;
    while (k > 0) {
      if (q >= Tr::MaxDenorm / 2) {
        return s;
      } else if (q <= -Tr::MaxDenorm / 2) {
        return s + 1;
      }
      q <<= word_shift;
      q += digits[--k];
    }
    return q >= 0 ? s : s + 1;
  } else {
    return 0x7fffffff;
  }
}

template <class Tr>
bool AnyIntView<Tr>::export_bytes_any(unsigned char* buff, std::size_t buff_size, bool sgnd) const {
  if (!is_valid()) {
    return false;
  }
  if (!buff_size) {
    return sgn_un_any() == 0;
  }
  int k = 0;
  word_t v = 0;
  unsigned char* ptr = buff + buff_size;
  unsigned char s = (sgn_un_any() < 0 ? 0xff : 0);
  if (s && !sgnd) {
    return false;
  }
  for (int i = 0; i < size(); i++) {
    if ((word_shift & 7) && word_shift + 8 >= word_bits && k >= word_bits - word_shift - 1) {
      int k1 = 8 - k;
      v += (digits[i] << k) & 0xff;
      if (ptr > buff) {
        *--ptr = (unsigned char)(v & 0xff);
      } else if ((unsigned char)(v & 0xff) != s) {
        return false;
      }
      v >>= 8;
      v += (digits[i] >> k1);
      k += word_shift - 8;
    } else {
      v += (digits[i] << k);
      k += word_shift;
    }
    while (k >= 8) {
      if (ptr > buff) {
        *--ptr = (unsigned char)(v & 0xff);
      } else if ((unsigned char)(v & 0xff) != s) {
        return false;
      }
      v >>= 8;
      k -= 8;
    }
  }
  while (ptr > buff) {
    *--ptr = (unsigned char)(v & 0xff);
    v >>= 8;
  }
  if (v != -(s & 1)) {
    return false;
  }
  return !sgnd ? true : !((*ptr ^ s) & 0x80);
}

template <class Tr>
bool AnyIntView<Tr>::export_bytes_lsb_any(unsigned char* buff, std::size_t buff_size, bool sgnd) const {
  if (!is_valid()) {
    return false;
  }
  if (!buff_size) {
    return sgn_un_any() == 0;
  }
  int k = 0;
  word_t v = 0;
  unsigned char* end = buff + buff_size;
  unsigned char s = (sgn_un_any() < 0 ? 0xff : 0);
  if (s && !sgnd) {
    return false;
  }
  for (int i = 0; i < size(); i++) {
    if ((word_shift & 7) && word_shift + 8 >= word_bits && k >= word_bits - word_shift - 1) {
      int k1 = 8 - k;
      v += (digits[i] << k) & 0xff;
      if (buff < end) {
        *buff++ = (unsigned char)(v & 0xff);
      } else if ((unsigned char)(v & 0xff) != s) {
        return false;
      }
      v >>= 8;
      v += (digits[i] >> k1);
      k += word_shift - 8;
    } else {
      v += (digits[i] << k);
      k += word_shift;
    }
    while (k >= 8) {
      if (buff < end) {
        *buff++ = (unsigned char)(v & 0xff);
      } else if ((unsigned char)(v & 0xff) != s) {
        return false;
      }
      v >>= 8;
      k -= 8;
    }
  }
  while (buff < end) {
    *buff++ = (unsigned char)(v & 0xff);
    v >>= 8;
  }
  if (v != -(s & 1)) {
    return false;
  }
  return !sgnd ? true : !((buff[-1] ^ s) & 0x80);
}

template <class Tr>
bool AnyIntView<Tr>::export_bits_any(unsigned char* buff, int offs, unsigned bits, bool sgnd) const {
  if (!is_valid()) {
    return false;
  }
  if (!bits) {
    return sgn_un_any() == 0;
  }
  if (size() == 1 || bits < 64) {
    word_t v = to_long_any();
    if (bits < 64) {
      if (!sgnd) {
        if (v < 0 || (unsigned long long)v >= (1ULL << bits)) {
          return false;
        }
      } else {
        word_t pw = (1LL << (bits - 1));
        if (v < -pw || v >= pw) {
          return false;
        }
      }
      td::bitstring::bits_store_long_top(buff, offs, v << (64 - bits), bits);
    } else {
      if (!sgnd && v < 0) {
        return false;
      }
      td::bitstring::bits_memset(buff, offs, v < 0, bits - 64);
      td::bitstring::bits_store_long_top(buff, offs + bits - 64, v, 64);
    }
    return true;
  }
  buff += (offs >> 3);
  offs &= 7;
  unsigned char s = (sgn_un_any() < 0 ? 0xff : 0);
  if (s && !sgnd) {
    return false;
  }
  unsigned end_offs = offs + bits;
  unsigned char* ptr = buff + (end_offs >> 3);
  int k = td::bits_negate32(end_offs) & 7;
  word_t v = k ? (*ptr++ & ((1 << k) - 1)) : 0;
  for (int i = 0; i < size(); i++) {
    if (word_shift + 8 >= word_bits && k >= word_bits - word_shift - 1) {
      int k1 = 8 - k;
      v += (digits[i] << k) & 0xff;
      if (ptr > buff) {
        if (--ptr > buff) {
          *ptr = (unsigned char)(v & 0xff);
        } else {
          int mask = (0xff00 >> offs) & 0xff;
          if (((unsigned char)v ^ s) & mask) {
            return false;
          }
          *ptr = (unsigned char)((*ptr & mask) | ((int)v & ~mask));
        }
      } else if ((unsigned char)(v & 0xff) != s) {
        return false;
      }
      v >>= 8;
      v += (digits[i] >> k1);
      k += word_shift - 8;
    } else {
      v += (digits[i] << k);
      k += word_shift;
    }
    while (k >= 8) {
      if (ptr > buff) {
        if (--ptr > buff) {
          *ptr = (unsigned char)(v & 0xff);
        } else {
          int mask = (0xff00 >> offs) & 0xff;
          if (((unsigned char)v ^ s) & mask) {
            return false;
          }
          *ptr = (unsigned char)((*ptr & mask) | ((int)v & ~mask));
        }
      } else if ((unsigned char)(v & 0xff) != s) {
        return false;
      }
      v >>= 8;
      k -= 8;
    }
  }
  if (ptr > buff) {
    while (--ptr > buff) {
      *ptr = (unsigned char)(v & 0xff);
      v >>= 8;
    }
    int mask = (0xff00 >> offs) & 0xff;
    if (((unsigned char)v ^ s) & mask) {
      return false;
    }
    *ptr = (unsigned char)((*ptr & mask) | ((int)v & ~mask));
    v >>= 8;
  }
  if (v != -(s & 1)) {
    return false;
  }
  return !sgnd ? true : !((*ptr ^ s) & (0x80 >> offs));
}

template <class Tr>
bool AnyIntView<Tr>::import_bytes_any(const unsigned char* buff, std::size_t buff_size, bool sgnd) {
  if (!buff_size) {
    *this = 0;
    return true;
  }
  unsigned char s = (sgnd && (buff[0] & 0x80)) ? 0xff : 0;
  const unsigned char* ptr = buff + buff_size;
  while (buff < ptr && *buff == s) {
    buff++;
  }
  int k = 0;
  word_t v = 0;
  set_size(1);
  assert(word_bits - word_shift >= 8);
  while (ptr > buff) {
    if (k >= word_shift) {
      if (size() < max_size()) {
        digits[size() - 1] = v;
        inc_size();
        v = 0;
        k -= word_shift;
      } else if (k >= word_bits - 8) {
        return invalidate_bool();
      }
    }
    v |= (((word_t) * --ptr) << k);
    k += 8;
  }
  if (s) {
    v -= ((word_t)1 << k);
  }
  digits[size() - 1] = v;
  return normalize_bool_any();
}

template <class Tr>
bool AnyIntView<Tr>::import_bits_any(const unsigned char* buff, int offs, unsigned bits, bool sgnd) {
  if (bits < word_shift) {
    set_size(1);
    unsigned long long val = td::bitstring::bits_load_long_top(buff, offs, bits);
    if (sgnd) {
      digits[0] = ((long long)val >> (64 - bits));
    } else {
      digits[0] = (val >> (64 - bits));
    }
    return true;
  }
  buff += (offs >> 3);
  offs &= 7;
  unsigned char s = (sgnd && (buff[0] & (0x80 >> offs))) ? 0xff : 0;
  unsigned end_offs = (unsigned)offs + bits;
  const unsigned char* ptr = buff + (end_offs >> 3);
  if (buff < ptr && !((*buff ^ s) & (0xff >> offs))) {
    buff++;
    offs = 0;
    while (buff < ptr && *buff == s) {
      buff++;
    }
  }
  int k = end_offs & 7;
  word_t v = k ? (*ptr >> (8 - k)) : 0;
  set_size(1);
  assert(word_bits - word_shift >= 8);
  while (ptr > buff) {
    if (k >= word_shift) {
      if (size() < max_size()) {
        digits[size() - 1] = v;
        inc_size();
        v = 0;
        k -= word_shift;
      } else if (k >= word_bits - 8) {
        return invalidate_bool();
      }
    }
    v |= (((word_t) * --ptr) << k);
    k += 8;
  }
  k -= offs;
  word_t pw = ((word_t)1 << k);
  v &= pw - 1;
  if (s) {
    v -= pw;
  }
  digits[size() - 1] = v;
  return normalize_bool_any();
}

template <class Tr>
bool AnyIntView<Tr>::import_bytes_lsb_any(const unsigned char* buff, std::size_t buff_size, bool sgnd) {
  if (!buff_size) {
    *this = 0;
    return true;
  }
  const unsigned char* end = buff + buff_size;
  unsigned char s = (sgnd && (end[-1] & 0x80)) ? 0xff : 0;
  while (end > buff && end[-1] == s) {
    --end;
  }
  int k = 0;
  word_t v = 0;
  set_size(1);
  assert(word_bits - word_shift >= 8);
  while (buff < end) {
    if (k >= word_shift) {
      if (size() < max_size()) {
        digits[size() - 1] = v;
        inc_size();
        v = 0;
        k -= word_shift;
      } else if (k >= word_bits - 8) {
        return invalidate_bool();
      }
    }
    v |= (((word_t)*buff++) << k);
    k += 8;
  }
  if (s) {
    v -= ((word_t)1 << k);
  }
  digits[size() - 1] = v;
  return normalize_bool_any();
}

template <class Tr>
int AnyIntView<Tr>::parse_hex_any(const char* str, int str_len, int* frac) {
  invalidate();
  bool sgn = (str[0] == '-');
  int i = sgn, j;
  int p = (frac ? -1 : 0);
  while (i < str_len && str[i] == '0') {
    i++;
  }
  for (j = i; j < str_len; j++) {
    int c = str[j];
    if (c == '.' && p < 0) {
      p = j + 1;
      continue;
    }
    if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'))) {
      break;
    }
  }
  if (j == sgn + (p > 0)) {
    return 0;
  }
  if ((j - i - (p > 0)) * 4 > (max_size() - 1) * word_shift + word_bits - 2) {
    return 0;
  }
  int j_len = j, k = 0;
  word_t v = 0;
  set_size(0);
  while (j > i) {
    if (j == p) {
      --j;
      continue;
    }
    if (k >= word_shift && size() < max_size() - 1) {
      digits[inc_size()] = (sgn ? -v : v);
      v = 0;
      k -= word_shift;
    }
    int c = str[--j];
    if (c <= '9') {
      c -= '0';
    } else {
      c = (c | 0x20) - ('a' - 10);
    }
    v += ((word_t)c << k);
    k += 4;
    enforce(k < word_bits - 1);
  }
  digits[inc_size()] = (sgn ? -v : v);
  if (!normalize_bool_any()) {
    invalidate();
    return 0;
  }
  if (p) {
    *frac = (p > 0 ? j_len - p : -1);
  }
  return j_len;
}

template <class Tr>
int AnyIntView<Tr>::parse_binary_any(const char* str, int str_len, int* frac) {
  invalidate();
  bool sgn = (str[0] == '-');
  int i = sgn, j, p = (frac ? -1 : 0);
  while (i < str_len && str[i] == '0') {
    i++;
  }
  for (j = i; j < str_len; j++) {
    int c = str[j];
    if (c != '0' && c != '1') {
      if (c == '.' && p < 0) {
        p = j + 1;
        continue;
      }
      break;
    }
  }
  if (j == sgn + (p > 0)) {
    return 0;
  }
  if (j - i - (p > 0) > (max_size() - 1) * word_shift + word_bits - 2) {
    return 0;
  }
  int j_len = j, k = 0;
  word_t v = 0;
  set_size(0);
  while (j > i) {
    if (j == p) {
      --j;
      continue;
    }
    if (k >= word_shift && size() < max_size() - 1) {
      digits[inc_size()] = (sgn ? -v : v);
      v = 0;
      k -= word_shift;
    }
    v += ((word_t)(str[--j] & 1) << k);
    k++;
    enforce(k < word_bits - 1);
  }
  digits[inc_size()] = (sgn ? -v : v);
  if (!normalize_bool_any()) {
    invalidate();
    return 0;
  }
  if (p) {
    *frac = (p > 0 ? j_len - p : -1);
  }
  return j_len;
}

template <class Tr>
std::string AnyIntView<Tr>::to_dec_string_slow_destroy_any() {
  if (!is_valid()) {
    return "NaN";
  }
  std::string x;
  x.reserve((size() * word_shift + word_bits) * 97879 / 325147 + 2);
  int s = sgn();
  if (s < 0) {
    negate_any();
  }
  do {
    x += (char)('0' + divmod_short_any(10));
  } while (sgn());
  if (s < 0) {
    x += '-';
  }
  std::reverse(x.begin(), x.end());
  return x;
}

template <class Tr>
std::string AnyIntView<Tr>::to_dec_string_destroy_any() {
  if (!is_valid()) {
    return "NaN";
  }
  std::string s;
  std::vector<word_t> stack;
  int l10 = (size() * word_shift + word_bits) * 97879 / 325147;
  s.reserve(l10 + 2);
  stack.reserve(l10 / Tr::max_pow10_exp + 1);
  if (sgn() < 0) {
    negate_any();
    s += '-';
  }
  do {
    stack.push_back(divmod_short_any(Tr::max_pow10));
  } while (sgn());
  char slice[word_bits * 97879 / 325147 + 2];
  std::sprintf(slice, "%lld", stack.back());
  s += slice;
  stack.pop_back();
  while (stack.size()) {
    std::sprintf(slice, "%018lld", stack.back());
    s += slice;
    stack.pop_back();
  }
  return s;
}

static const char hex_digits[] = "0123456789abcdef";
static const char HEX_digits[] = "0123456789ABCDEF";

template <class Tr>
std::string AnyIntView<Tr>::to_hex_string_slow_destroy_any() {
  if (!is_valid()) {
    return "NaN";
  }
  std::string x;
  x.reserve(((size() * word_shift + word_bits) >> 2) + 2);
  int s = sgn();
  if (s < 0) {
    negate_any();
  }
  do {
    x += hex_digits[divmod_short_any(16)];
  } while (sgn());
  if (s < 0) {
    x += '-';
  }
  std::reverse(x.begin(), x.end());
  return x;
}

template <class Tr>
std::string AnyIntView<Tr>::to_hex_string_any(bool upcase) const {
  if (!is_valid()) {
    return "NaN";
  }
  int s = sgn(), k = 0;
  if (!s) {
    return "0";
  }
  std::string x;
  x.reserve(((size() * word_shift + word_bits) >> 2) + 2);
  assert(word_shift < word_bits - 4);
  const char* hex_digs = (upcase ? HEX_digits : hex_digits);
  word_t v = 0;
  for (int i = 0; i < size(); i++) {
    v += ((s >= 0 ? digits[i] : -digits[i]) << k);
    k += word_shift;
    while (k >= 4 && (v || i < size() - 1)) {
      x += hex_digs[v & 15];
      v >>= 4;
      k -= 4;
    }
  }
  assert(v >= 0);
  while (v > 0) {
    x += hex_digs[v & 15];
    v >>= 4;
  }
  if (s < 0) {
    x += '-';
  }
  std::reverse(x.begin(), x.end());
  return x;
}

template <class Tr>
std::string AnyIntView<Tr>::to_binary_string_any() const {
  if (!is_valid()) {
    return "NaN";
  }
  int s = sgn();
  if (!s) {
    return "0";
  }
  std::string x;
  x.reserve(size() * word_shift + word_bits + 2);
  assert(word_shift < word_bits - 1);
  word_t v = 0;
  for (int i = 0; i < size(); i++) {
    v += (s >= 0 ? digits[i] : -digits[i]);
    int k = word_shift;
    while (--k >= 0 && (v || i < size() - 1)) {
      x += (v & 1 ? '1' : '0');
      v >>= 1;
    }
  }
  assert(v >= 0);
  while (v > 0) {
    x += (v & 1 ? '1' : '0');
    v >>= 1;
  }
  if (s < 0) {
    x += '-';
  }
  std::reverse(x.begin(), x.end());
  return x;
}

template <int len, class Tr>
BigIntG<len, Tr>& BigIntG<len, Tr>::denormalize() {
  word_t val = 0;
  for (int i = 0; i < n; i++) {
    val += digits[i];
    digits[i] = (val & (Tr::Base - 1));
    val >>= word_shift;
  }
  while (n < word_cnt) {
    digits[n++] = (val & (Tr::Base - 1));
    val >>= word_shift;
  }
  return *this;
}

template <int len, class Tr>
BigIntG<len, Tr>& BigIntG<len, Tr>::logical_not() {
  digits[0] = ~digits[0];
  for (int i = 1; i < n; i++) {
    digits[i] = -digits[i];
  }
  return *this;
}

template <int len, class Tr>
std::ostream& BigIntG<len, Tr>::dump(std::ostream& os, bool nl) const {
  os << "{";
  //auto f = os.flags();
  //os.flags(std::ios::hex | std::ios::showbase);
  //os.width(16);
  for (int i = n - 1; i >= 0; i--) {
    os << digits[i] << (i ? ' ' : '}');
  }
  if (!n) {
    os << "nan}";
  }
  if (nl) {
    os << std::endl;
  }
  //os.flags(f);
  return os;
}

template <int len, class Tr>
std::string BigIntG<len, Tr>::dump() const {
  std::ostringstream os;
  dump(os);
  return os.str();
}

template <int len, class Tr>
int BigIntG<len, Tr>::parse_dec_slow(const char* str, int str_len) {
  *this = 0;
  int i;
  bool sgn = (str[0] == '-');
  if (str_len <= static_cast<int>(sgn)) {
    return 0;
  }
  for (i = sgn; i < str_len; i++) {
    if (str[i] < '0' || str[i] > '9') {
      return i;
    }
    mul_tiny(10);
    add_tiny(sgn ? '0' - str[i] : str[i] - '0');
    if (!normalize_bool()) {
      *this = 0;
      return 0;
    }
  }
  return i;
}

template <int len, class Tr>
int BigIntG<len, Tr>::parse_dec(const char* str, int str_len, int* frac) {
  *this = 0;
  int i;
  int p = frac ? -1 : 0;
  bool sgn = (str[0] == '-'), ok = false;
  word_t q = 1, a = 0;
  for (i = sgn; i < str_len; i++) {
    if (str[i] == '.') {
      if (p >= 0) {
        break;
      }
      p = i + 1;
      continue;
    }
    int digit = (int)str[i] - '0';
    if ((unsigned)digit >= 10) {
      break;
    }
    ok = true;
    if (q >= Tr::Half / 10) {
      if (!mul_add_short_bool(q, a)) {
        return 0;
      }
      q = 1;
      a = 0;
    }
    q *= 10;
    a *= 10;
    a += (sgn ? -digit : digit);
  }
  if (!ok || !mul_add_short_bool(q, a) || !normalize_bool()) {
    return 0;
  }
  if (frac) {
    *frac = (p > 0 ? i - p : -1);
  }
  return i;
}

template <int len, class Tr>
std::string BigIntG<len, Tr>::to_dec_string_slow() const {
  BigIntG<len, Tr> copy(*this);
  copy.normalize_bool();
  return copy.as_any_int().to_dec_string_slow_destroy_any();
}

template <int len, class Tr>
std::string BigIntG<len, Tr>::to_dec_string() const {
  BigIntG<len, Tr> copy(*this);
  copy.normalize_bool();
  //std::cout << "(tds " << (const void*)this << "->" << (void*)&copy << ")";
  return copy.as_any_int().to_dec_string_destroy_any();
}

template <int len, class Tr>
std::string BigIntG<len, Tr>::to_dec_string_destroy() {
  normalize_bool();
  return as_any_int().to_dec_string_destroy_any();
}

template <int len, class Tr>
std::string BigIntG<len, Tr>::to_hex_string_slow() const {
  BigIntG<len, Tr> copy(*this);
  copy.normalize_bool();
  return copy.as_any_int().to_hex_string_slow_destroy_any();
}

template <int len, class Tr>
std::string BigIntG<len, Tr>::to_hex_string(bool upcase) const {
  return as_any_int().to_hex_string_any(upcase);
}

template <int len, class Tr>
std::string BigIntG<len, Tr>::to_binary_string() const {
  return as_any_int().to_binary_string_any();
}

template <int len, class Tr>
std::ostream& operator<<(std::ostream& os, const BigIntG<len, Tr>& x) {
  return os << x.to_dec_string();
}

template <int len, class Tr>
std::ostream& operator<<(std::ostream& os, BigIntG<len, Tr>&& x) {
  return os << x.to_dec_string_destroy();
}

extern template class AnyIntView<BigIntInfo>;
extern template class BigIntG<257, BigIntInfo>;
typedef BigIntG<257, BigIntInfo> BigInt256;

namespace literals {

extern BigInt256 operator""_i256(const char* str, std::size_t str_len);
extern BigInt256 operator""_x256(const char* str, std::size_t str_len);

}  // namespace literals

}  // namespace td
