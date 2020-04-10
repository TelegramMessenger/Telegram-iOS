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
#include <iostream>
#include <string>

#include "openssl/bignum.h"
#include "openssl/residue.h"
#include "ellcurve/Fp25519.h"

namespace ellcurve {
using namespace arith;

class MontgomeryCurve {
  td::Ref<ResidueRing> ring;
  int A_short;   // v^2 = u^2 + Au + 1
  int Gu_short;  // u(G)
  int a_short;   // (A+2)/4
  Residue A_;
  Residue Gu;
  Bignum P_;
  Bignum L;
  Bignum Order;
  Bignum cofactor;
  int cofactor_short;

  void init();

 public:
  MontgomeryCurve(int _A, int _Gu, td::Ref<ResidueRing> _R)
      : ring(_R)
      , A_short(_A)
      , Gu_short(_Gu)
      , a_short((_A + 2) / 4)
      , A_(_A, _R)
      , Gu(_Gu, _R)
      , P_(_R->get_modulus())
      , cofactor_short(0) {
    init();
  }

  const Residue& get_gen_u() const {
    return Gu;
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

  void set_order_cofactor(const Bignum& order, int cof);

  struct PointXZ {
    Residue X, Z;
    PointXZ(Residue x, Residue z) : X(x), Z(z) {
      x.same_ring(z);
    }
    PointXZ(td::Ref<ResidueRing> r) : X(r->one()), Z(r->zero()) {
    }
    explicit PointXZ(Residue u) : X(u), Z(u.ring_of().one()) {
    }
    explicit PointXZ(Residue y, bool) : X(y.ring_of().one() + y), Z(y.ring_of().one() - y) {
    }
    PointXZ(const PointXZ& P) : X(P.X), Z(P.Z) {
    }
    PointXZ& operator=(const PointXZ& P) {
      X = P.X;
      Z = P.Z;
      return *this;
    }
    Residue get_u() const {
      return X * inverse(Z);
    }
    Residue get_v(bool sign_v = false) const;
    bool is_infty() const {
      return Z.is_zero();
    }
    Residue get_y() const {
      return (X - Z) * inverse(X + Z);
    }
    bool export_point_y(unsigned char buffer[32]) const;
    bool export_point_u(unsigned char buffer[32]) const;
    void zeroize() {
      X = Z = Z.ring_of().zero();
    }
  };

  PointXZ power_gen_xz(const Bignum& n) const;
  PointXZ power_xz(const Residue& u, const Bignum& n) const;
  PointXZ power_xz(const PointXZ& P, const Bignum& n) const;
  PointXZ add_xz(const PointXZ& P, const PointXZ& Q) const;
  PointXZ double_xz(const PointXZ& P) const;

  PointXZ import_point_u(const unsigned char point[32]) const;
  PointXZ import_point_y(const unsigned char point[32]) const;
};

const MontgomeryCurve& Curve25519();

}  // namespace ellcurve
