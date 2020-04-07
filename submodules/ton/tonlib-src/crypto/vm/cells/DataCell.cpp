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
#include "vm/cells/DataCell.h"

#include "openssl/digest.hpp"

#include "td/utils/ScopeGuard.h"

#include "vm/cells/CellWithStorage.h"

namespace vm {
std::unique_ptr<DataCell> DataCell::create_empty_data_cell(Info info) {
  return detail::CellWithUniquePtrStorage<DataCell>::create(info.get_storage_size(), info);
}

DataCell::DataCell(Info info) : info_(std::move(info)) {
  get_thread_safe_counter().add(1);
}
DataCell::~DataCell() {
  get_thread_safe_counter().add(-1);
}

void DataCell::destroy_storage(char* storage) {
  auto* refs = info_.get_refs(storage);
  for (size_t i = 0; i < get_refs_cnt(); i++) {
    Ref<Cell>(refs[i], Ref<Cell>::acquire_t{});  // call destructor
  }
}

td::Result<Ref<DataCell>> DataCell::create(td::ConstBitPtr data, unsigned bits, td::Span<Ref<Cell>> refs,
                                           bool special) {
  std::array<Ref<Cell>, max_refs> copied_refs;
  CHECK(refs.size() <= copied_refs.size());
  for (size_t i = 0; i < refs.size(); i++) {
    copied_refs[i] = refs[i];
  }
  return create(std::move(data), bits, td::MutableSpan<Ref<Cell>>(copied_refs.data(), refs.size()), special);
}

DataCell::SpecialType DataCell::special_type() const {
  if (is_special()) {
    return static_cast<SpecialType>(td::bitstring::bits_load_ulong(get_data(), 8));
  }
  return SpecialType::Ordinary;
}

td::Result<Ref<DataCell>> DataCell::create(td::ConstBitPtr data, unsigned bits, td::MutableSpan<Ref<Cell>> refs,
                                           bool special) {
  for (auto& ref : refs) {
    if (ref.is_null()) {
      return td::Status::Error("Has null cell reference");
    }
  }

  SpecialType type = SpecialType::Ordinary;
  if (special) {
    if (bits < 8) {
      return td::Status::Error("Not enough data for a special cell");
    }
    type = static_cast<SpecialType>(td::bitstring::bits_load_ulong(data, 8));
    if (type == SpecialType::Ordinary) {
      return td::Status::Error("Special cell has Ordinary type");
    }
  }

  LevelMask level_mask;
  td::uint32 virtualization = 0;
  switch (type) {
    case SpecialType::Ordinary: {
      for (auto& ref : refs) {
        level_mask = level_mask.apply_or(ref->get_level_mask());
        virtualization = td::max(virtualization, ref->get_virtualization());
      }
      break;
    }

    case SpecialType::PrunnedBranch: {
      if (refs.size() != 0) {
        return td::Status::Error("PrunnedBranch special cell has a cell reference");
      }
      if (bits < 16) {
        return td::Status::Error("Not enough data for a PrunnedBranch special cell");
      }
      level_mask = LevelMask((td::bitstring::bits_load_ulong(data + 8, 8)) & 0xff);
      auto level = level_mask.get_level();
      if (level > max_level || level == 0) {
        return td::Status::Error("Prunned Branch has an invalid level");
      }
      if (bits != (2 + level_mask.apply(level - 1).get_hashes_count() * (hash_bytes + depth_bytes)) * 8) {
        return td::Status::Error("Not enouch data for a PrunnedBranch special cell");
      }
      // depth will be checked later!
      break;
    }

    case SpecialType::Library: {
      if (bits != 8 + hash_bytes * 8) {
        return td::Status::Error("Not enouch data for a Library special cell");
      }
      break;
    }

    case SpecialType::MerkleProof: {
      if (bits != 8 + (hash_bytes + depth_bytes) * 8) {
        return td::Status::Error("Not enouch data for a MerkleProof special cell");
      }
      if (refs.size() != 1) {
        return td::Status::Error("Wrong references count for a MerkleProof special cell");
      }
      if (td::bitstring::bits_memcmp(data + 8, refs[0]->get_hash(0).as_bitslice().get_ptr(), hash_bits) != 0) {
        return td::Status::Error("Hash mismatch in a MerkleProof special cell");
      }
      if (td::bitstring::bits_load_ulong(data + 8 + hash_bits, depth_bytes * 8) != refs[0]->get_depth(0)) {
        return td::Status::Error("Depth mismatch in a MerkleProof special cell");
      }
      level_mask = refs[0]->get_level_mask().shift_right();
      virtualization = refs[0]->get_virtualization();
      break;
    }

    case SpecialType::MerkleUpdate: {
      if (bits != 8 + (hash_bytes + depth_bytes) * 8 * 2) {
        return td::Status::Error("Not enouch data for a MerkleUpdate special cell");
      }
      if (refs.size() != 2) {
        return td::Status::Error("Wrong references count for a MerkleUpdate special cell");
      }
      if (td::bitstring::bits_memcmp(data + 8, refs[0]->get_hash(0).as_bitslice().get_ptr(), hash_bits) != 0) {
        return td::Status::Error("First hash mismatch in a MerkleProof special cell");
      }
      if (td::bitstring::bits_memcmp(data + 8 + hash_bits, refs[1]->get_hash(0).as_bitslice().get_ptr(), hash_bits) !=
          0) {
        return td::Status::Error("Second hash mismatch in a MerkleProof special cell");
      }
      if (td::bitstring::bits_load_ulong(data + 8 + 2 * hash_bits, depth_bytes * 8) != refs[0]->get_depth(0)) {
        return td::Status::Error("First depth mismatch in a MerkleProof special cell");
      }
      if (td::bitstring::bits_load_ulong(data + 8 + 2 * hash_bits + depth_bytes * 8, depth_bytes * 8) !=
          refs[1]->get_depth(0)) {
        return td::Status::Error("Second depth mismatch in a MerkleProof special cell");
      }

      level_mask = refs[0]->get_level_mask().apply_or(refs[1]->get_level_mask()).shift_right();
      virtualization = td::max(refs[0]->get_virtualization(), refs[1]->get_virtualization());
      break;
    }

    default:
      return td::Status::Error("Unknown special cell type");
  }

  Info info;
  if (td::unlikely(bits > max_bits)) {
    return td::Status::Error("Too many bits");
  }
  if (td::unlikely(refs.size() > max_refs)) {
    return td::Status::Error("Too many cell references");
  }
  if (td::unlikely(virtualization > max_virtualization)) {
    return td::Status::Error("Too big virtualization");
  }

  CHECK(level_mask.get_level() <= max_level);

  auto hash_count = type == SpecialType::PrunnedBranch ? 1 : level_mask.get_hashes_count();
  DCHECK(hash_count <= max_level + 1);

  info.bits_ = bits;
  info.refs_count_ = refs.size() & 7;
  info.is_special_ = special;
  info.level_mask_ = level_mask.get_mask() & 7;
  info.hash_count_ = hash_count & 7;
  info.virtualization_ = virtualization & 7;

  auto data_cell = create_empty_data_cell(info);
  auto* storage = data_cell->get_storage();

  // init data
  auto* data_ptr = info.get_data(storage);
  td::BitPtr{data_ptr}.copy_from(data, bits);
  // prepare for serialization
  if (bits & 7) {
    int m = (0x80 >> (bits & 7));
    unsigned l = bits / 8;
    data_ptr[l] = static_cast<unsigned char>((data_ptr[l] & -m) | m);
  }

  // init refs
  auto refs_ptr = info.get_refs(storage);
  for (size_t i = 0; i < refs.size(); i++) {
    refs_ptr[i] = refs[i].release();
  }

  // init hashes and depth
  auto* hashes_ptr = info.get_hashes(storage);
  auto* depth_ptr = info.get_depth(storage);

  // NB: be careful with special cells
  auto total_hash_count = level_mask.get_hashes_count();
  auto hash_i_offset = total_hash_count - hash_count;
  for (td::uint32 level_i = 0, hash_i = 0, level = level_mask.get_level(); level_i <= level; level_i++) {
    if (!level_mask.is_significant(level_i)) {
      continue;
    }
    SCOPE_EXIT {
      hash_i++;
    };
    if (hash_i < hash_i_offset) {
      continue;
    }
    unsigned char tmp[2];
    tmp[0] = info.d1(level_mask.apply(level_i));
    tmp[1] = info.d2();

    static TD_THREAD_LOCAL digest::SHA256* hasher;
    td::init_thread_local<digest::SHA256>(hasher);
    hasher->reset();

    hasher->feed(td::Slice(tmp, 2));

    if (hash_i == hash_i_offset) {
      DCHECK(level_i == 0 || type == SpecialType::PrunnedBranch);
      hasher->feed(td::Slice(data_ptr, (bits + 7) >> 3));
    } else {
      DCHECK(level_i != 0 && type != SpecialType::PrunnedBranch);
      hasher->feed(hashes_ptr[hash_i - hash_i_offset - 1].as_slice());
    }

    auto dest_i = hash_i - hash_i_offset;

    // calc depth
    td::uint16 depth = 0;
    for (int i = 0; i < info.refs_count_; i++) {
      td::uint16 child_depth = 0;
      if (type == SpecialType::MerkleProof || type == SpecialType::MerkleUpdate) {
        child_depth = refs_ptr[i]->get_depth(level_i + 1);
      } else {
        child_depth = refs_ptr[i]->get_depth(level_i);
      }

      // add depth into hash
      td::uint8 child_depth_buf[depth_bytes];
      store_depth(child_depth_buf, child_depth);
      hasher->feed(td::Slice(child_depth_buf, depth_bytes));

      depth = std::max(depth, child_depth);
    }
    if (info.refs_count_ != 0) {
      if (depth >= max_depth) {
        return td::Status::Error("Depth is too big");
      }
      depth++;
    }
    depth_ptr[dest_i] = depth;

    // children hash
    for (int i = 0; i < info.refs_count_; i++) {
      if (type == SpecialType::MerkleProof || type == SpecialType::MerkleUpdate) {
        hasher->feed(refs_ptr[i]->get_hash(level_i + 1).as_slice());
      } else {
        hasher->feed(refs_ptr[i]->get_hash(level_i).as_slice());
      }
    }
    auto extracted_size = hasher->extract(hashes_ptr[dest_i].as_slice());
    DCHECK(extracted_size == hash_bytes);
  }

  return Ref<DataCell>(data_cell.release(), Ref<DataCell>::acquire_t{});
}

const DataCell::Hash DataCell::do_get_hash(td::uint32 level) const {
  auto hash_i = get_level_mask().apply(level).get_hash_i();
  if (special_type() == SpecialType::PrunnedBranch) {
    auto this_hash_i = get_level_mask().get_hash_i();
    if (hash_i != this_hash_i) {
      return reinterpret_cast<const Hash*>(info_.get_data(get_storage()) + 2)[hash_i];
    }
    hash_i = 0;
  }
  return info_.get_hashes(get_storage())[hash_i];
}

td::uint16 DataCell::do_get_depth(td::uint32 level) const {
  auto hash_i = get_level_mask().apply(level).get_hash_i();
  if (special_type() == SpecialType::PrunnedBranch) {
    auto this_hash_i = get_level_mask().get_hash_i();
    if (hash_i != this_hash_i) {
      return load_depth(info_.get_data(get_storage()) + 2 + hash_bytes * this_hash_i + hash_i * depth_bytes);
    }
    hash_i = 0;
  }
  return info_.get_depth(get_storage())[hash_i];
}

int DataCell::serialize(unsigned char* buff, int buff_size, bool with_hashes) const {
  int len = get_serialized_size(with_hashes);
  if (len > buff_size) {
    return 0;
  }
  buff[0] = static_cast<unsigned char>(info_.d1() | (with_hashes * 16));
  buff[1] = info_.d2();
  int hs = 0;
  if (with_hashes) {
    hs = (get_level_mask().get_hashes_count()) * (hash_bytes + depth_bytes);
    assert(len >= 2 + hs);
    std::memset(buff + 2, 0, hs);
    auto dest = td::MutableSlice(buff + 2, hs);
    auto level = get_level();
    // TODO: optimize for prunned brandh
    for (unsigned i = 0; i <= level; i++) {
      if (!get_level_mask().is_significant(i)) {
        continue;
      }
      dest.copy_from(get_hash(i).as_slice());
      dest.remove_prefix(hash_bytes);
    }
    for (unsigned i = 0; i <= level; i++) {
      if (!get_level_mask().is_significant(i)) {
        continue;
      }
      store_depth(dest.ubegin(), get_depth(i));
      dest.remove_prefix(depth_bytes);
    }
    // buff[2] = 0;  // for testing hash verification in deserialization
    buff += hs;
    len -= hs;
  }
  std::memcpy(buff + 2, get_data(), len - 2);
  return len + hs;
}

std::string DataCell::serialize() const {
  unsigned char buff[max_serialized_bytes];
  int len = serialize(buff, sizeof(buff));
  return std::string(buff, buff + len);
}

std::string DataCell::to_hex() const {
  unsigned char buff[max_serialized_bytes];
  int len = serialize(buff, sizeof(buff));
  char hex_buff[max_serialized_bytes * 2 + 1];
  for (int i = 0; i < len; i++) {
    sprintf(hex_buff + 2 * i, "%02x", buff[i]);
  }
  return hex_buff;
}

std::ostream& operator<<(std::ostream& os, const DataCell& c) {
  return os << c.to_hex();
}

}  // namespace vm
