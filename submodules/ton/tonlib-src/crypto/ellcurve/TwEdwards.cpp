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
#include "ellcurve/TwEdwards.h"
#include <assert.h>
#include <cstring>

namespace ellcurve {
using namespace arith;

class TwEdwardsCurve;

TwEdwardsCurve::TwEdwardsCurve(const Residue& _D, const Residue& _Gy, td::Ref<ResidueRing> _R)
    : ring(_R)
    , D(_D)
    , D2(_D + _D)
    , Gy(_Gy)
    , P_(_R->get_modulus())
    , cofactor_short(0)
    , G(_R)
    , O(_R)
    , table_lines(0)
    , table() {
  init();
}

TwEdwardsCurve::~TwEdwardsCurve() {
}

void TwEdwardsCurve::init() {
  assert(D != ring->zero() && D != ring->convert(-1));
  O.X = O.Z = ring->one();
  G = SegrePoint(*this, Gy, 0);
  assert(!G.XY.is_zero());
}

void TwEdwardsCurve::set_order_cofactor(const Bignum& order, int cof) {
  assert(order > 0);
  assert(cof >= 0);
  assert(cof == 0 || (order % cof) == 0);
  Order = order;
  cofactor = cofactor_short = cof;
  if (cof > 0) {
    L = order / cof;
    assert(is_prime(L));
    assert(!power_gen(1).is_zero());
    assert(power_gen(L).is_zero());
  }
}

TwEdwardsCurve::SegrePoint::SegrePoint(const TwEdwardsCurve& E, const Residue& y, bool x_sign)
    : XY(y), X(E.get_base_ring()), Y(y), Z(E.get_base_ring()->one()) {
  Residue x(y.ring_ref());
  if (E.recover_x(x, y, x_sign)) {
    XY *= x;
    X = x;
  } else {
    XY = Y = Z = E.get_base_ring()->zero();
  }
}

bool TwEdwardsCurve::recover_x(Residue& x, const Residue& y, bool x_sign) const {
  // recovers x from equation -x^2+y^2 = 1+d*x^2*y^2
  Residue z = inverse(ring->one() + D * sqr(y));
  if (z.is_zero()) {
    return false;
  }
  z *= sqr(y) - ring->one();
  Residue t = sqrt(z);
  if (sqr(t) == z) {
    x = (t.extract().odd() == x_sign) ? t : -t;
    //std::cout << "x=" << x << ", y=" << y << std::endl;
    return true;
  } else {
    return false;
  }
}

void TwEdwardsCurve::add_points(SegrePoint& Res, const SegrePoint& P, const SegrePoint& Q) const {
  Residue a((P.X + P.Y) * (Q.X + Q.Y));
  Residue b((P.X - P.Y) * (Q.X - Q.Y));
  Residue c(P.Z * Q.Z * ring->convert(2));
  Residue d(P.XY * Q.XY * D2);
  Residue x_num(a - b);   // 2(x1y2+x2y1)
  Residue y_num(a + b);   // 2(x1x2+y1y2)
  Residue x_den(c + d);   // 2(1+dx1x2y1y2)
  Residue y_den(c - d);   // 2(1-dx1x2y1y2)
  Res.X = x_num * y_den;  // x = x_num/x_den, y = y_num/y_den
  Res.Y = y_num * x_den;
  Res.XY = x_num * y_num;
  Res.Z = x_den * y_den;
}

TwEdwardsCurve::SegrePoint TwEdwardsCurve::add_points(const SegrePoint& P, const SegrePoint& Q) const {
  SegrePoint Res(ring);
  add_points(Res, P, Q);
  return Res;
}

void TwEdwardsCurve::double_point(SegrePoint& Res, const SegrePoint& P) const {
  add_points(Res, P, P);
}

TwEdwardsCurve::SegrePoint TwEdwardsCurve::double_point(const SegrePoint& P) const {
  SegrePoint Res(ring);
  double_point(Res, P);
  return Res;
}

// computes u([n]P) in form (xy,x,y,1)*Z
TwEdwardsCurve::SegrePoint TwEdwardsCurve::power_point(const SegrePoint& A, const Bignum& n, bool uniform) const {
  assert(n >= 0);
  if (n == 0) {
    return O;
  }

  int k = n.num_bits();
  SegrePoint P(A);

  if (uniform) {
    SegrePoint Q(double_point(A));

    for (int i = k - 2; i >= 0; --i) {
      if (n[i]) {
        add_points(P, P, Q);
        double_point(Q, Q);
      } else {
        // we do more operations than necessary for uniformicity
        add_points(Q, P, Q);
        double_point(P, P);
      }
    }
  } else {
    for (int i = k - 2; i >= 0; --i) {
      double_point(P, P);
      if (n[i]) {
        add_points(P, P, A);  // may optimize further if A.z = 1
      }
    }
  }
  return P;
}

int TwEdwardsCurve::build_table() {
  if (table.size()) {
    return -1;
  }
  table_lines = (P_.num_bits() >> 2) + 2;
  table.reserve(table_lines * 15 + 1);
  table.emplace_back(get_base_point());
  for (int i = 0; i < table_lines; i++) {
    for (int j = 0; j < 15; j++) {
      table.emplace_back(add_points(table[15 * i + j], table[15 * i]));
    }
  }
  return 1;
}

int get_nibble(const Bignum& n, int idx) {
  return n[idx * 4 + 3] * 8 + n[idx * 4 + 2] * 4 + n[idx * 4 + 1] * 2 + n[idx * 4];
}

TwEdwardsCurve::SegrePoint TwEdwardsCurve::power_gen(const Bignum& n, bool uniform) const {
  if (uniform || n.num_bits() > table_lines * 4) {
    return power_point(G, n, uniform);
  } else if (n.is_zero()) {
    return O;
  } else {
    int k = (n.num_bits() + 3) >> 2;
    assert(k > 0 && k <= table_lines);
    int x = get_nibble(n, k - 1);
    assert(x > 0 && x < 16);
    SegrePoint P(table[15 * (k - 1) + x - 1]);
    for (int i = k - 2; i >= 0; i--) {
      x = get_nibble(n, i);
      assert(x >= 0 && x < 16);
      if (x > 0) {
        add_points(P, P, table[15 * i + x - 1]);
      }
    }
    return P;
  }
}

bool TwEdwardsCurve::SegrePoint::export_point(unsigned char buffer[32], bool need_x) const {
  if (!is_normalized()) {
    if (Z.is_zero()) {
      std::memset(buffer, 0xff, 32);
      return false;
    }
    Residue f(inverse(Z));
    Bignum y((Y * f).extract());
    assert(!y[255]);
    if (need_x) {
      y[255] = (X * f).extract().odd();
    }
    y.export_lsb(buffer, 32);
  } else {
    Bignum y(Y.extract());
    assert(!y[255]);
    if (need_x) {
      y[255] = X.extract().odd();
    }
    y.export_lsb(buffer, 32);
  }
  return true;
}

bool TwEdwardsCurve::SegrePoint::export_point_u(unsigned char buffer[32]) const {
  if (Z == Y) {
    std::memset(buffer, 0xff, 32);
    return false;
  }
  Residue f(inverse(Z - Y));
  ((Z + Y) * f).extract().export_lsb(buffer, 32);
  assert(!(buffer[31] & 0x80));
  return true;
}

TwEdwardsCurve::SegrePoint TwEdwardsCurve::import_point(const unsigned char point[32], bool& ok) const {
  Bignum y;
  y.import_lsb(point, 32);
  bool x_sign = y[255];
  y[255] = 0;
  Residue yr(y, ring);
  Residue xr(ring);
  ok = recover_x(xr, yr, x_sign);
  return ok ? SegrePoint(xr, yr) : SegrePoint(ring);
}

const TwEdwardsCurve& Ed25519() {
  static const TwEdwardsCurve Ed25519 = [] {
    TwEdwardsCurve res(Fp25519()->frac(-121665, 121666), Fp25519()->frac(4, 5), Fp25519());
    res.set_order_cofactor(hex_string{"80000000000000000000000000000000a6f7cef517bce6b2c09318d2e7ae9f68"}, 8);
    res.build_table();
    return res;
  }();
  return Ed25519;
}
}  // namespace ellcurve
