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
#include "vm/cells/CellTraits.h"

#include "td/utils/StringBuilder.h"
#include "td/utils/Slice.h"

namespace vm {
td::StringBuilder& operator<<(td::StringBuilder& sb, CellTraits::SpecialType special_type) {
  switch (special_type) {
    case CellTraits::SpecialType::Ordinary:
      sb << "Ordinary";
      break;
    case CellTraits::SpecialType::MerkleProof:
      sb << "MerkleProof";
      break;
    case CellTraits::SpecialType::MerkleUpdate:
      sb << "MerkleUpdate";
      break;
    case CellTraits::SpecialType::PrunnedBranch:
      sb << "PrunnedBranch";
      break;
    case CellTraits::SpecialType::Library:
      sb << "Library";
      break;
  }
  return sb;
}
}  // namespace vm
