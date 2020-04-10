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
#include <vector>
#include "common/refcnt.hpp"
#include "openssl/residue.h"
#include "ellcurve/Fp25519.h"

namespace ellcurve {
using namespace arith;

class TwEdwardsCurve {
 public:
  struct SegrePoint {
    Residue XY, X, Y, Z;  // if x=X/Z and y=Y/T, stores (xy,x,y,1)*Z*T
    SegrePoint(td::Ref<ResidueRing> R) : XY(R), X(R), Y(R), Z(R) {
    }
    SegrePoint(const Residue& x, const Residue& y) : XY(x * y), X(x), Y(y), Z(y.ring_of().one()) {
    }
    SegrePoint(const TwEdwardsCurve& E, const Residue& y, bool x_sign);
    SegrePoint(const SegrePoint& P) : XY(P.XY), X(P.X), Y(P.Y), Z(P.Z) {
    }
    SegrePoint& operator=(const SegrePoint& P) {
      XY = P.XY;
      X = P.X;
      Y = P.Y;
      Z = P.Z;
      return *this;
    }
    bool is_zero() const {
      return X.is_zero() && (Y == Z);
    }
    bool is_valid() const {
      return (XY * Z == X * Y) && !(XY.is_zero() && X.is_zero() && Y.is_zero() && Z.is_zero());
    }
    bool is_finite() const {
      return !Z.is_zero();
    }
    bool is_normalized() const {
      return Z == Z.ring_of().one();
    }
    SegrePoint& normalize() {
      auto f = inverse(Z);
      XY *= f;
      X *= f;
      Y *= f;
      Z = Z.ring_of().one();
      return *this;
    }
    SegrePoint& zeroize() {
      XY = X = Y = Z = Z.ring_of().zero();
      return *this;
    }
    bool export_point(unsigned char buffer[32], bool need_x = true) const;
    bool export_point_y(unsigned char buffer[32]) const {
      return export_point(buffer, false);
    }
    bool export_point_u(unsigned char buffer[32]) const;
    Residue get_y() const {
      return Y * inverse(Z);
    }
    Residue get_x() const {
      return X * inverse(Z);
    }
    Residue get_u() const {
      return (Z + Y) * inverse(Z - Y);
    }
    void negate() {
      XY.negate();
      X.negate();
    }
  };

 private:
  td::Ref<ResidueRing> ring;
  Residue D;
  Residue D2;
  Residue Gy;
  Bignum P_;
  Bignum L;
  Bignum Order;
  Bignum cofactor;
  int cofactor_short;
  SegrePoint G;
  SegrePoint O;
  int table_lines;
  std::vector<SegrePoint> table;

  void init();

 public:
  TwEdwardsCurve(const Residue& _D, const Residue& _Gy, td::Ref<ResidueRing> _R);
  ~TwEdwardsCurve();
  const Residue& get_gen_y() const {
    return Gy;
  }
  const Bignum& get_ell() const {
    return L;
  }
  const Bignum& get_order() const {
    return Order;
  }
  td::Ref<ResidueRing> get_base_ring() const {
    return ring;
  }
  const Bignum& get_p() const {
    return P_;
  }
  const SegrePoint& get_base_point() const {
    return G;
  }

  void set_order_cofactor(const Bignum& order, int cof);
  bool recover_x(Residue& x, const Residue& y, bool x_sign) const;

  void add_points(SegrePoint& R, const SegrePoint& P, const SegrePoint& Q) const;
  SegrePoint add_points(const SegrePoint& P, const SegrePoint& Q) const;
  void double_point(SegrePoint& R, const SegrePoint& P) const;
  SegrePoint double_point(const SegrePoint& P) const;
  SegrePoint power_point(const SegrePoint& A, const Bignum& n, bool uniform = false) const;
  SegrePoint power_gen(const Bignum& n, bool uniform = false) const;
  int build_table();

  SegrePoint import_point(const unsigned char point[32], bool& ok) const;
};

std::ostream& operator<<(std::ostream& os, const TwEdwardsCurve::SegrePoint& P);
const TwEdwardsCurve& Ed25519();
}  // namespace ellcurve
