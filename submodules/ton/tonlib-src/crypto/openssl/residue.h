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
#include "bignum.h"
#include "common/refcnt.hpp"

namespace arith {
class Residue;
class ResidueRing;

class ResidueRing : public td::CntObject {
 public:
  struct bad_modulus {};

 private:
  const Bignum modulus;
  bool prime;
  Residue* Zero;
  Residue* One;
  mutable Residue* Img_i;
  void init();

 public:
  typedef Residue element;
  explicit ResidueRing(Bignum mod) : modulus(mod), prime(arith::is_prime(mod)), Zero(0), One(0), Img_i(0) {
    init();
  }
  ~ResidueRing();
  const Bignum& get_modulus() const {
    return modulus;
  }
  bool is_prime() const {
    return prime;
  }
  const Residue& zero() const {
    return *Zero;
  }
  const Residue& one() const {
    return *One;
  }
  const Residue& img_i() const;
  Residue frac(long num, long denom = 1) const;
  Residue convert(long num) const;
  Residue convert(const Bignum& x) const;

  Bignum reduce(const Bignum& x) const {
    Bignum r = x % modulus;
    if (r.sign() < 0) {
      r += modulus;
    }
    return r;
  }

  Bignum& do_reduce(Bignum& x) const {
    x %= modulus;
    if (x.sign() < 0) {
      x += modulus;
    }
    return x;
  }

 private:
  td::Ref<ResidueRing> self_ref() const {
    return td::Ref<ResidueRing>{this};
  }
};

class Residue {
 public:
  struct not_same_ring {};

 private:
  td::Ref<ResidueRing> ring;
  mutable Bignum val;
  Residue& reduce() {
    ring->do_reduce(val);
    return *this;
  }

 public:
  explicit Residue(td::Ref<ResidueRing> R) : ring(R) {
  }
  Residue(const Bignum& x, td::Ref<ResidueRing> R) : ring(R), val(R->reduce(x)) {
  }
  ~Residue() {
  }
  Residue(const Residue& x) : ring(x.ring), val(x.val) {
  }
  Bignum extract() const {
    return val;
  }
  const Bignum& extract_raw() const {
    return val;
  }
  const Bignum& modulus() const {
    return ring->get_modulus();
  }
  void same_ring(const Residue& y) const {
    if (ring != y.ring) {
      throw not_same_ring();
    }
  }
  const ResidueRing& ring_of() const {
    return *ring;
  }
  td::Ref<ResidueRing> ring_ref() const {
    return ring;
  }
  bool is_zero() const {
    return (val == 0);
  }
  Residue& operator=(const Residue& x) {
    same_ring(x);
    val = x.val;
    return *this;
  }
  Residue& operator=(const Bignum& x) {
    val = ring->reduce(x);
    return *this;
  }
  Residue& operator+=(const Residue& y);
  Residue& operator-=(const Residue& y);
  Residue& operator*=(const Residue& y);
  Residue& operator+=(long y) {
    val += y;
    return reduce();
  }
  Residue& operator-=(long y) {
    val -= y;
    return reduce();
  }
  Residue& operator*=(long y) {
    val *= y;
    return reduce();
  }
  Residue& negate() {
    val.negate();
    return reduce();
  }
  friend const Residue operator+(const Residue& x, const Residue& y);
  friend const Residue operator-(const Residue& x, const Residue& y);
  friend const Residue operator*(const Residue& x, const Residue& y);
  friend const Residue operator-(const Residue& x);
  friend Residue sqr(const Residue& x);
  friend Residue power(const Residue& x, const Bignum& y);
  friend Residue inverse(const Residue& x);
  std::string to_str() const;
};

const Residue operator+(const Residue& x, const Residue& y);
const Residue operator-(const Residue& x, const Residue& y);
const Residue operator*(const Residue& x, const Residue& y);
const Residue operator-(const Residue& x);

bool operator==(const Residue& x, const Residue& y);
bool operator!=(const Residue& x, const Residue& y);

Residue sqr(const Residue& x);
Residue power(const Residue& x, const Bignum& y);
Residue inverse(const Residue& x);
Residue sqrt(const Residue& x);

inline Residue ResidueRing::convert(long x) const {
  return Residue(x, td::Ref<ResidueRing>(this));
}

inline Residue ResidueRing::convert(const Bignum& x) const {
  return Residue(x, td::Ref<ResidueRing>(this));
}

std::ostream& operator<<(std::ostream& os, const Residue& x);
std::istream& operator>>(std::istream& is, Residue& x);
}  // namespace arith
