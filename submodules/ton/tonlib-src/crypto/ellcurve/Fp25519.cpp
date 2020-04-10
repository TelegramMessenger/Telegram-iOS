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
#include "ellcurve/Fp25519.h"

namespace ellcurve {
using namespace arith;

const Bignum& P25519() {
  static const Bignum P25519 = (Bignum(1) << 255) - 19;
  return P25519;
}

td::Ref<ResidueRing> Fp25519() {
  static const td::Ref<ResidueRing> Fp25519(true, P25519());
  return Fp25519;
}
}  // namespace ellcurve
