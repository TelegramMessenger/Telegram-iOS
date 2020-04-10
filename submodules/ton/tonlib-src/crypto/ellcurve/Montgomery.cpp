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
#include "ellcurve/Montgomery.h"

#include <assert.h>
#include <cstring>

namespace ellcurve {
using namespace arith;

class MontgomeryCurve;

void MontgomeryCurve::init() {
  assert(!((a_short + 2) & 3) && a_short >= 0);
}

void MontgomeryCurve::set_order_cofactor(const Bignum& order, int cof) {
  assert(order > 0);
  assert(cof >= 0);
  assert(cof == 0 || (order % cof) == 0);
  Order = order;
  cofactor = cofactor_short = cof;
  if (cof > 0) {
    L = order / cof;
    assert(is_prime(L));
  }
  assert(!power_gen_xz(1).is_infty());
  assert(power_gen_xz(Order).is_infty());
}

// computes u(P+Q)*u(P-Q) as X/Z
MontgomeryCurve::PointXZ MontgomeryCurve::add_xz(const MontgomeryCurve::PointXZ& P,
                                                 const MontgomeryCurve::PointXZ& Q) const {
  Residue u = (P.X + P.Z) * (Q.X - Q.Z);
  Residue v = (P.X - P.Z) * (Q.X + Q.Z);
  return MontgomeryCurve::PointXZ(sqr(u + v), sqr(u - v));
}

// computes u(2P) as X/Z
MontgomeryCurve::PointXZ MontgomeryCurve::double_xz(const MontgomeryCurve::PointXZ& P) const {
  Residue u = sqr(P.X + P.Z);
  Residue v = sqr(P.X - P.Z);
  Residue w = u - v;
  return PointXZ(u * v, w * (v + Residue(a_short, ring) * w));
}

MontgomeryCurve::PointXZ MontgomeryCurve::power_gen_xz(const Bignum& n) const {
  return power_xz(Gu, n);
}

MontgomeryCurve::PointXZ MontgomeryCurve::power_xz(const Residue& u, const Bignum& n) const {
  return power_xz(PointXZ(u), n);
}

// computes u([n]P) in form X/Z
MontgomeryCurve::PointXZ MontgomeryCurve::power_xz(const PointXZ& A, const Bignum& n) const {
  assert(n >= 0);
  if (n == 0) {
    return PointXZ(ring);
  }

  int k = n.num_bits();
  PointXZ P(A);
  PointXZ Q(double_xz(P));
  for (int i = k - 2; i >= 0; --i) {
    PointXZ PQ(add_xz(P, Q));
    PQ.X *= A.Z;
    PQ.Z *= A.X;
    if (n[i]) {
      P = PQ;
      Q = double_xz(Q);
    } else {
      Q = PQ;
      P = double_xz(P);
    }
  }
  return P;
}

bool MontgomeryCurve::PointXZ::export_point_y(unsigned char buffer[32]) const {
  if ((X + Z).is_zero()) {
    std::memset(buffer, 0xff, 32);
    return false;
  } else {
    get_y().extract().export_lsb(buffer, 32);
    return true;
  }
}

bool MontgomeryCurve::PointXZ::export_point_u(unsigned char buffer[32]) const {
  if (Z.is_zero()) {
    std::memset(buffer, 0xff, 32);
    return false;
  } else {
    get_u().extract().export_lsb(buffer, 32);
    return true;
  }
}

MontgomeryCurve::PointXZ MontgomeryCurve::import_point_u(const unsigned char point[32]) const {
  Bignum u;
  u.import_lsb(point, 32);
  u[255] = 0;
  return PointXZ(Residue(u, ring));
}

MontgomeryCurve::PointXZ MontgomeryCurve::import_point_y(const unsigned char point[32]) const {
  Bignum y;
  y.import_lsb(point, 32);
  y[255] = 0;
  return PointXZ(Residue(y, ring), true);
}

const MontgomeryCurve& Curve25519() {
  static const MontgomeryCurve Curve25519 = [] {
    MontgomeryCurve res(486662, 9, Fp25519());
    res.set_order_cofactor(hex_string{"80000000000000000000000000000000a6f7cef517bce6b2c09318d2e7ae9f68"}, 8);
    return res;
  }();
  return Curve25519;
}
}  // namespace ellcurve
