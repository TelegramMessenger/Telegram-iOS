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
#pragma once
#include "vm/cells/CellTraits.h"
#include "common/bitstring.h"

#include "td/utils/as.h"

#include <array>
namespace td {
class StringBuilder;
}

namespace vm {
struct CellHash {
 public:
  td::Slice as_slice() const {
    return td::Slice(hash_.data(), hash_.size());
  }
  td::MutableSlice as_slice() {
    return td::MutableSlice(hash_.data(), hash_.size());
  }
  bool operator==(const CellHash& other) const {
    return hash_ == other.hash_;
  }
  bool operator<(const CellHash& other) const {
    return hash_ < other.hash_;
  }
  bool operator!=(const CellHash& other) const {
    return hash_ != other.hash_;
  }
  std::string to_hex() const {
    return td::ConstBitPtr{hash_.data()}.to_hex(hash_.size() * 8);
  }
  friend td::StringBuilder& operator<<(td::StringBuilder& sb, const CellHash& hash);
  td::ConstBitPtr bits() const {
    return td::ConstBitPtr{hash_.data()};
  }
  td::BitPtr bits() {
    return td::BitPtr{hash_.data()};
  }
  td::BitSlice as_bitslice() const {
    return td::BitSlice{hash_.data(), (unsigned int)hash_.size() * 8};
  }
  const std::array<td::uint8, CellTraits::hash_bytes>& as_array() const {
    return hash_;
  }

  static CellHash from_slice(td::Slice slice) {
    CellHash res;
    CHECK(slice.size() == res.hash_.size());
    td::MutableSlice(res.hash_.data(), res.hash_.size()).copy_from(slice);
    return res;
  }

 private:
  std::array<td::uint8, CellTraits::hash_bytes> hash_;
};
}  // namespace vm

namespace std {
template <>
struct hash<vm::CellHash> {
  typedef vm::CellHash argument_type;
  typedef std::size_t result_type;
  result_type operator()(argument_type const& s) const noexcept {
    return td::as<size_t>(s.as_slice().ubegin());
  }
};
}  // namespace std
namespace vm {
template <class H>
H AbslHashValue(H h, const CellHash& cell_hash) {
  return H::combine(std::move(h), std::hash<vm::CellHash>()(cell_hash));
}
}  // namespace vm
