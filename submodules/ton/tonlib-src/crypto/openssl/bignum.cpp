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
#include "openssl/bignum.h"

// impl only
#include <cstring>

namespace arith {

BN_CTX* get_ctx(void) {
  thread_local BN_CTX* ctx = BN_CTX_new();
  return ctx;
}

BignumBitref& BignumBitref::operator=(bool val) {
  if (val) {
    BN_set_bit(ptr, n);
  } else {
    BN_clear_bit(ptr, n);
  }
  return *this;
}

const Bignum operator+(const Bignum& x, const Bignum& y) {
  Bignum z;
  bn_assert(BN_add(z.bn_ptr(), x.bn_ptr(), y.bn_ptr()));
  return z;
}

const Bignum operator+(const Bignum& x, long y) {
  if (y > 0) {
    Bignum z(x);
    bn_assert(BN_add_word(z.bn_ptr(), y));
    return z;
  } else if (y < 0) {
    Bignum z(x);
    bn_assert(BN_sub_word(z.bn_ptr(), -y));
    return z;
  } else {
    return x;
  }
}

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

/*
  const Bignum operator+ (long y, Bignum&& x) {
    return x + y;
  }
  */

const Bignum operator-(const Bignum& x, const Bignum& y) {
  Bignum z;
  bn_assert(BN_sub(z.bn_ptr(), x.bn_ptr(), y.bn_ptr()));
  return z;
}

/*
  const Bignum operator- (Bignum&& x, long y) {
    return x + (-y);
  }
  */

const Bignum operator*(const Bignum& x, const Bignum& y) {
  Bignum z;
  bn_assert(BN_mul(z.bn_ptr(), x.bn_ptr(), y.bn_ptr(), get_ctx()));
  return z;
}

const Bignum operator*(const Bignum& x, long y) {
  if (y > 0) {
    Bignum z(x);
    bn_assert(BN_mul_word(z.bn_ptr(), y));
    return z;
  } else if (y < 0) {
    Bignum z(x);
    z.negate();
    bn_assert(BN_mul_word(z.bn_ptr(), -y));
    return z;
  } else {
    Bignum z(0);
    return z;
  }
}

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

const Bignum operator/(const Bignum& x, const Bignum& y) {
  Bignum z, w;
  bn_assert(BN_div(z.bn_ptr(), w.bn_ptr(), x.bn_ptr(), y.bn_ptr(), get_ctx()));
  return z;
}

const Bignum Bignum::divmod(const Bignum& y) {
  Bignum w;
  bn_assert(BN_div(val, w.bn_ptr(), val, y.bn_ptr(), get_ctx()));
  return w;
}

const Bignum operator%(const Bignum& x, const Bignum& y) {
  Bignum z;
  bn_assert(BN_mod(z.bn_ptr(), x.bn_ptr(), y.bn_ptr(), get_ctx()));
  return z;
}

unsigned long operator%(const Bignum& x, unsigned long y) {
  BN_ULONG rem = BN_mod_word(x.bn_ptr(), y);
  bn_assert(rem != (BN_ULONG)(-1));
  return static_cast<unsigned long>(rem);
}

const Bignum operator<<(const Bignum& x, int r) {
  Bignum z;
  bn_assert(BN_lshift(z.bn_ptr(), x.bn_ptr(), r));
  return z;
}

const Bignum operator>>(const Bignum& x, int r) {
  Bignum z;
  bn_assert(BN_rshift(z.bn_ptr(), x.bn_ptr(), r));
  return z;
}

const Bignum abs(const Bignum& x) {
  Bignum T(x);
  if (T.sign() < 0) {
    T.negate();
  }
  return T;
}

const Bignum sqr(const Bignum& x) {
  Bignum z;
  bn_assert(BN_sqr(z.bn_ptr(), x.bn_ptr(), get_ctx()));
  return z;
}

void Bignum::export_msb(unsigned char* buffer, std::size_t size) const {
  bn_assert(size <= (1 << 20));
  bn_assert(sign() >= 0);
  std::size_t n = BN_num_bytes(val);
  bn_assert(n <= size);
  bn_assert(BN_bn2bin(val, buffer + size - n) == static_cast<int>(n));
  std::memset(buffer, 0, size - n);
}

Bignum& Bignum::import_msb(const unsigned char* buffer, std::size_t size) {
  bn_assert(size <= (1 << 20));
  std::size_t i = 0;
  while (i < size && !buffer[i]) {
    i++;
  }
  bn_assert(BN_bin2bn(buffer + i, static_cast<int>(size - i), val) == val);
  return *this;
}

void Bignum::export_lsb(unsigned char* buffer, std::size_t size) const {
  bn_assert(size <= (1 << 20));
  bn_assert(sign() >= 0);
  std::size_t n = BN_num_bytes(val);
  bn_assert(n <= size);
  bn_assert(BN_bn2bin(val, buffer) == (int)n);
  std::memset(buffer + n, 0, size - n);
  for (std::size_t i = 0; 2 * i + 1 < n; i++) {
    std::swap(buffer[i], buffer[n - 1 - i]);
  }
}

Bignum& Bignum::import_lsb(const unsigned char* buffer, std::size_t size) {
  bn_assert(size <= (1 << 20));
  while (size > 0 && !buffer[size - 1]) {
    size--;
  }
  if (!size) {
    // Use BN_set_word, because from 1.1.0 BN_zero may return void
    bn_assert(BN_set_word(val, 0));
    return *this;
  }
  unsigned char tmp_buff[1024];
  unsigned char* tmp = (size < 1024 ? tmp_buff : new unsigned char[size]);
  unsigned char* ptr = tmp + size;
  for (std::size_t i = 0; i < size; i++) {
    *--ptr = buffer[i];
  }
  bn_assert(BN_bin2bn(tmp, static_cast<int>(size), val) == val);
  if (tmp != tmp_buff) {
    delete[] tmp;
  }
  return *this;
}

std::string Bignum::to_str() const {
  char* ptr = BN_bn2dec(val);
  std::string z(ptr);
  OPENSSL_free(ptr);
  return z;
}

std::string Bignum::to_hex() const {
  char* ptr = BN_bn2hex(val);
  std::string z(ptr);
  OPENSSL_free(ptr);
  return z;
}

std::ostream& operator<<(std::ostream& os, const Bignum& x) {
  return os << x.to_str();
}

std::istream& operator>>(std::istream& is, Bignum& x) {
  std::string word;
  is >> word;
  x = dec_string(word);
  return is;
}

bool is_prime(const Bignum& p, int nchecks, bool trial_div) {
  return BN_is_prime_fasttest_ex(p.bn_ptr(), BN_prime_checks, get_ctx(), trial_div, 0);
}
}  // namespace arith
