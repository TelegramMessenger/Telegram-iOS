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

#include <string>
#include <iostream>

#include <openssl/bn.h>
#include "td/utils/bits.h"
#include "td/utils/misc.h"

namespace arith {
struct dec_string {
  std::string str;
  explicit dec_string(const std::string& s) : str(s) {
  }
};

struct hex_string {
  std::string str;
  explicit hex_string(const std::string& s) : str(s) {
  }
};

struct bin_string {
  std::string str;
  explicit bin_string(const std::string& s) : str(s) {
  }
};
}  // namespace arith

namespace arith {

inline void bn_assert(int cond);
BN_CTX* get_ctx();

class BignumBitref {
  BIGNUM* ptr;
  int n;

 public:
  BignumBitref(BIGNUM* x, int _n) : ptr(x), n(_n){};
  operator bool() const {
    return BN_is_bit_set(ptr, n);
  }
  BignumBitref& operator=(bool val);
};

class Bignum {
  BIGNUM* val;

 public:
  class bignum_error {};
  Bignum() {
    val = BN_new();
  }
  Bignum(long x) {
    val = BN_new();
    set_long(x);
  }
  ~Bignum() {
    BN_free(val);
  }
  Bignum(const bin_string& bs) {
    val = BN_new();
    set_raw_bytes(bs.str);
  }
  Bignum(const dec_string& ds) {
    val = BN_new();
    set_dec_str(ds.str);
  }
  Bignum(const hex_string& hs) {
    val = BN_new();
    set_hex_str(hs.str);
  }
  Bignum(const Bignum& x) {
    val = BN_new();
    BN_copy(val, x.val);
  }
  //Bignum (Bignum&& x) { val = x.val; }
  void clear() {
    BN_clear(val);
  }  // use this for sensitive data
  Bignum& operator=(const Bignum& x) {
    BN_copy(val, x.val);
    return *this;
  }
  Bignum& operator=(Bignum&& x) {
    swap(x);
    return *this;
  }
  Bignum& operator=(long x) {
    return set_long(x);
  }
  Bignum& operator=(const dec_string& ds) {
    return set_dec_str(ds.str);
  }
  Bignum& operator=(const hex_string& hs) {
    return set_hex_str(hs.str);
  }
  Bignum& swap(Bignum& x) {
    std::swap(val, x.val);
    return *this;
  }
  BIGNUM* bn_ptr() {
    return val;
  }
  const BIGNUM* bn_ptr() const {
    return val;
  }
  bool is_zero() const {
    return BN_is_zero(val);
  }
  int sign() const {
    return BN_is_zero(val) ? 0 : (BN_is_negative(val) ? -1 : 1);
  }
  bool odd() const {
    return BN_is_odd(val);
  }
  int num_bits() const {
    return BN_num_bits(val);
  }
  int num_bytes() const {
    return BN_num_bytes(val);
  }
  bool operator[](int n) const {
    return BN_is_bit_set(val, n);
  }
  BignumBitref operator[](int n) {
    return BignumBitref(val, n);
  }
  void export_msb(unsigned char* buffer, std::size_t size) const;
  Bignum& import_msb(const unsigned char* buffer, std::size_t size);
  Bignum& import_msb(const std::string& s) {
    return import_msb((const unsigned char*)s.c_str(), s.size());
  }
  void export_lsb(unsigned char* buffer, std::size_t size) const;
  Bignum& import_lsb(const unsigned char* buffer, std::size_t size);
  Bignum& import_lsb(const std::string& s) {
    return import_lsb((const unsigned char*)s.c_str(), s.size());
  }

  Bignum& set_dec_str(std::string s) {
    bn_assert(BN_dec2bn(&val, s.c_str()));
    return *this;
  }

  Bignum& set_raw_bytes(std::string s) {
    CHECK(BN_bin2bn(reinterpret_cast<const td::uint8*>(s.c_str()), td::narrow_cast<td::uint32>(s.size()), val));
    return *this;
  }

  Bignum& set_hex_str(std::string s) {
    bn_assert(BN_hex2bn(&val, s.c_str()));
    return *this;
  }

  Bignum& set_ulong(unsigned long x) {
    bn_assert(BN_set_word(val, x));
    return *this;
  }

  Bignum& set_long(long x) {
    set_ulong(std::abs(x));
    return x < 0 ? negate() : *this;
  }

  Bignum& negate() {
    BN_set_negative(val, !BN_is_negative(val));
    return *this;
  }

  Bignum& operator+=(const Bignum& y) {
    bn_assert(BN_add(val, val, y.val));
    return *this;
  }

  Bignum& operator+=(long y) {
    bn_assert((y >= 0 ? BN_add_word : BN_sub_word)(val, std::abs(y)));
    return *this;
  }

  Bignum& operator-=(long y) {
    bn_assert((y >= 0 ? BN_sub_word : BN_add_word)(val, std::abs(y)));
    return *this;
  }

  Bignum& operator*=(const Bignum& y) {
    bn_assert(BN_mul(val, val, y.val, get_ctx()));
    return *this;
  }

  Bignum& operator*=(long y) {
    if (y < 0) {
      negate();
    }
    bn_assert(BN_mul_word(val, std::abs(y)));
    return *this;
  }

  Bignum& operator<<=(int r) {
    bn_assert(BN_lshift(val, val, r));
    return *this;
  }

  Bignum& operator>>=(int r) {
    bn_assert(BN_rshift(val, val, r));
    return *this;
  }

  Bignum& operator/=(const Bignum& y) {
    Bignum w;
    bn_assert(BN_div(val, w.val, val, y.val, get_ctx()));
    return *this;
  }

  Bignum& operator/=(long y) {
    bn_assert(BN_div_word(val, std::abs(y)) != (BN_ULONG)(-1));
    return y < 0 ? negate() : *this;
  }

  Bignum& operator%=(const Bignum& y) {
    bn_assert(BN_mod(val, val, y.val, get_ctx()));
    return *this;
  }

  Bignum& operator%=(long y) {
    BN_ULONG rem = BN_mod_word(val, std::abs(y));
    bn_assert(rem != (BN_ULONG)(-1));
    return set_long(static_cast<long>(y < 0 ? td::bits_negate64(rem) : rem));
  }

  unsigned long divmod(unsigned long y) {
    BN_ULONG rem = BN_div_word(val, y);
    bn_assert(rem != (BN_ULONG)(-1));
    return static_cast<unsigned long>(rem);
  }

  const Bignum divmod(const Bignum& y);

  std::string to_str() const;
  std::string to_hex() const;
};

inline void bn_assert(int cond) {
  if (!cond) {
    throw Bignum::bignum_error();
  }
}

BN_CTX* get_ctx(void);

const Bignum operator+(const Bignum& x, const Bignum& y);
const Bignum operator+(const Bignum& x, long y);

/*
  const Bignum operator+ (Bignum&& x, long y) {
    if (y > 0) {
      bn_assert (BN_add_word (x.bn_ptr(), y));
    } else if (y < 0) {
      bn_assert (BN_sub_word (x.bn_ptr(), -y));
    }
    return std::move (x);
  }
  */

inline const Bignum operator+(long y, const Bignum& x) {
  return x + y;
}

/*
  const Bignum operator+ (long y, Bignum&& x) {
    return x + y;
  }
  */

const Bignum operator-(const Bignum& x, const Bignum& y);
inline const Bignum operator-(const Bignum& x, long y) {
  return x + (-y);
}

/*
  const Bignum operator- (Bignum&& x, long y) {
    return x + (-y);
  }
  */

const Bignum operator*(const Bignum& x, const Bignum& y);
const Bignum operator*(const Bignum& x, long y);

/*
  const Bignum operator* (Bignum&& x, long y) {
    if (y > 0) {
      bn_assert (BN_mul_word (x.bn_ptr(), y));
    } else if (y < 0) {
      x.negate();
      bn_assert (BN_mul_word (x.bn_ptr(), -y));
    } else {
      x = 0;
    }
    return std::move (x);
  }
  */

inline const Bignum operator*(long y, const Bignum& x) {
  return x * y;
}

const Bignum operator/(const Bignum& x, const Bignum& y);
const Bignum operator%(const Bignum& x, const Bignum& y);
unsigned long operator%(const Bignum& x, unsigned long y);

const Bignum operator<<(const Bignum& x, int r);
const Bignum operator>>(const Bignum& x, int r);

const Bignum abs(const Bignum& x);
const Bignum sqr(const Bignum& x);

std::ostream& operator<<(std::ostream& os, const Bignum& x);
std::istream& operator>>(std::istream& is, Bignum& x);

bool is_prime(const Bignum& p, int nchecks = 64, bool trial_div = true);

inline int cmp(const Bignum& x, const Bignum& y) {
  return BN_cmp(x.bn_ptr(), y.bn_ptr());
}

inline bool operator==(const Bignum& x, const Bignum& y) {
  return cmp(x, y) == 0;
}

inline bool operator!=(const Bignum& x, const Bignum& y) {
  return cmp(x, y) != 0;
}

inline bool operator<(const Bignum& x, const Bignum& y) {
  return cmp(x, y) < 0;
}

inline bool operator<=(const Bignum& x, const Bignum& y) {
  return cmp(x, y) <= 0;
}

inline bool operator>(const Bignum& x, const Bignum& y) {
  return cmp(x, y) > 0;
}

inline bool operator>=(const Bignum& x, const Bignum& y) {
  return cmp(x, y) >= 0;
}

inline bool operator==(const Bignum& x, long y) {
  if (y >= 0) {
    return BN_is_word(x.bn_ptr(), y);
  } else {
    return x == Bignum(y);
  }
}

inline bool operator!=(const Bignum& x, long y) {
  if (y >= 0) {
    return !BN_is_word(x.bn_ptr(), y);
  } else {
    return x != Bignum(y);
  }
}

}  // namespace arith
