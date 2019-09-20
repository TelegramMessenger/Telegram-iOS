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
#include "residue.h"

// --- impl
#include <assert.h>

namespace arith {
class Residue;
class ResidueRing;

void ResidueRing::init() {
  Zero = new Residue(0, td::Ref<ResidueRing>(this));
  One = new Residue(1, td::Ref<ResidueRing>(this));
}

ResidueRing::~ResidueRing() {
  delete Zero;
  delete One;
  delete Img_i;
  Zero = One = Img_i = 0;
}

const Residue operator+(const Residue& x, const Residue& y) {
  x.same_ring(y);
  Residue z(x.ring_ref());
  bn_assert(BN_mod_add(z.val.bn_ptr(), x.val.bn_ptr(), y.val.bn_ptr(), x.modulus().bn_ptr(), get_ctx()));
  return z;
}

const Residue operator-(const Residue& x, const Residue& y) {
  x.same_ring(y);
  Residue z(x.ring_ref());
  bn_assert(BN_mod_sub(z.val.bn_ptr(), x.val.bn_ptr(), y.val.bn_ptr(), x.modulus().bn_ptr(), get_ctx()));
  return z;
}

const Residue operator*(const Residue& x, const Residue& y) {
  x.same_ring(y);
  Residue z(x.ring_ref());
  bn_assert(BN_mod_mul(z.val.bn_ptr(), x.val.bn_ptr(), y.val.bn_ptr(), x.modulus().bn_ptr(), get_ctx()));
  return z;
}

const Residue operator-(const Residue& x) {
  Residue z(x);
  z.val.negate();
  return z.reduce();
}

Residue& Residue::operator+=(const Residue& y) {
  same_ring(y);
  bn_assert(BN_mod_add(val.bn_ptr(), val.bn_ptr(), y.val.bn_ptr(), modulus().bn_ptr(), get_ctx()));
  return *this;
}

Residue& Residue::operator-=(const Residue& y) {
  same_ring(y);
  bn_assert(BN_mod_sub(val.bn_ptr(), val.bn_ptr(), y.val.bn_ptr(), modulus().bn_ptr(), get_ctx()));
  return *this;
}

Residue& Residue::operator*=(const Residue& y) {
  same_ring(y);
  bn_assert(BN_mod_mul(val.bn_ptr(), val.bn_ptr(), y.val.bn_ptr(), modulus().bn_ptr(), get_ctx()));
  return *this;
}

bool operator==(const Residue& x, const Residue& y) {
  x.same_ring(y);
  return x.extract() == y.extract();
}

bool operator!=(const Residue& x, const Residue& y) {
  x.same_ring(y);
  return x.extract() != y.extract();
}

Residue sqr(const Residue& x) {
  Residue z(x.ring_ref());
  bn_assert(BN_mod_sqr(z.val.bn_ptr(), x.val.bn_ptr(), x.modulus().bn_ptr(), get_ctx()));
  return z;
}

Residue power(const Residue& x, const Bignum& y) {
  Residue z(x.ring_ref());
  bn_assert(BN_mod_exp(z.val.bn_ptr(), x.val.bn_ptr(), y.bn_ptr(), x.modulus().bn_ptr(), get_ctx()));
  return z;
}

Residue inverse(const Residue& x) {
  assert(x.ring_ref()->is_prime());
  return power(x, x.ring_ref()->get_modulus() - 2);
}

const Residue& ResidueRing::img_i() const {
  if (!Img_i) {
    assert(is_prime());
    assert(modulus % 4 == 1);
    int g = 2;
    Bignum n = (modulus - 1) / 4;
    while (true) {
      Residue t = power(frac(g), n);
      if (t != one() && t != frac(-1)) {
        Img_i = new Residue(t);
        break;
      }
      g++;
    }
  }
  return *Img_i;
}

Residue sqrt(const Residue& x) {
  assert(x.ring_of().is_prime());
  const ResidueRing& R = x.ring_of();
  const Bignum& p = R.get_modulus();
  if (x.is_zero() || !p.odd()) {
    return x;
  }
  if (p[1]) {  // p=3 (mod 4)
    return power(x, (p + 1) >> 2);
  } else if (p[2]) {
    // p=5 (mod 8)
    Residue t = power(x, (p + 3) >> 3);
    return (sqr(t) == x) ? t : R.img_i() * t;
  } else {
    assert(p[2]);
    return R.zero();
  }
}

Residue ResidueRing::frac(long num, long denom) const {
  assert(denom);
  if (denom < 0) {
    num = -num;
    denom = -denom;
  }
  if (!(num % denom)) {
    return Residue(num / denom, self_ref());
  } else {
    return Residue(num, self_ref()) * inverse(Residue(denom, self_ref()));
  }
}

std::string Residue::to_str() const {
  return "Mod(" + val.to_str() + "," + modulus().to_str() + ")";
}

std::ostream& operator<<(std::ostream& os, const Residue& x) {
  return os << x.to_str();
}

std::istream& operator>>(std::istream& is, Residue& x) {
  std::string word;
  is >> word;
  x = dec_string(word);
  return is;
}
}  // namespace arith
