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
#include "vm/cells/CellWithStorage.h"
#include "vm/cells/Cell.h"

namespace vm {
struct PrunnedCellInfo {
  Cell::LevelMask level_mask;
  td::Slice hash;
  td::Slice depth;
};

template <class ExtraT>
class PrunnedCell : public Cell {
 public:
  const ExtraT& get_extra() const {
    return extra_;
  }

  static td::Result<Ref<PrunnedCell<ExtraT>>> create(const PrunnedCellInfo& prunned_cell_info, ExtraT&& extra) {
    auto level_mask = prunned_cell_info.level_mask;
    if (level_mask.get_level() > max_level) {
      return td::Status::Error("Level is too big");
    }
    Info info(level_mask);
    auto prunned_cell =
        detail::CellWithUniquePtrStorage<PrunnedCell<ExtraT>>::create(info.get_storage_size(), info, std::move(extra));
    TRY_STATUS(prunned_cell->init(prunned_cell_info));
    return Ref<PrunnedCell<ExtraT>>(prunned_cell.release(), typename Ref<PrunnedCell<ExtraT>>::acquire_t{});
  }

  LevelMask get_level_mask() const override {
    return LevelMask(info_.level_mask_);
  }

 protected:
  struct Info {
    Info(LevelMask level_mask) {
      level_mask_ = level_mask.get_mask() & 7;
      hash_count_ = level_mask.get_hashes_count() & 7;
    }
    unsigned char level_mask_ : 3;
    unsigned char hash_count_ : 3;
    size_t get_hashes_offset() const {
      return 0;
    }
    size_t get_depth_offset() const {
      return get_hashes_offset() + hash_bytes * hash_count_;
    }
    size_t get_storage_size() const {
      return get_depth_offset() + sizeof(td::uint16) * hash_count_;
    }
    const Hash* get_hashes(const char* storage) const {
      return reinterpret_cast<const Hash*>(storage + get_hashes_offset());
    }
    Hash* get_hashes(char* storage) const {
      return reinterpret_cast<Hash*>(storage + get_hashes_offset());
    }
    const td::uint16* get_depth(const char* storage) const {
      return reinterpret_cast<const td::uint16*>(storage + get_depth_offset());
    }
    td::uint16* get_depth(char* storage) const {
      return reinterpret_cast<td::uint16*>(storage + get_depth_offset());
    }
  };

  Info info_;
  ExtraT extra_;
  virtual char* get_storage() = 0;
  virtual const char* get_storage() const = 0;
  void destroy_storage(char* storage) {
    // noop
  }

  td::Status init(const PrunnedCellInfo& prunned_cell_info) {
    auto storage = get_storage();
    auto& new_hash = prunned_cell_info.hash;
    auto* hash = info_.get_hashes(storage);
    size_t n = prunned_cell_info.level_mask.get_hashes_count();
    CHECK(new_hash.size() == n * hash_bytes);
    for (td::uint32 i = 0; i < n; i++) {
      hash[i].as_slice().copy_from(new_hash.substr(i * Cell::hash_bytes, Cell::hash_bytes));
    }

    auto& new_depth = prunned_cell_info.depth;
    CHECK(new_depth.size() == n * depth_bytes);
    auto* depth = info_.get_depth(storage);
    for (td::uint32 i = 0; i < n; i++) {
      depth[i] = DataCell::load_depth(new_depth.substr(i * Cell::depth_bytes, Cell::depth_bytes).ubegin());
      if (depth[i] > max_depth) {
        return td::Status::Error("Depth is too big");
      }
    }
    return td::Status::OK();
  }

  explicit PrunnedCell(Info info, ExtraT&& extra) : info_(info), extra_(std::move(extra)) {
  }
  td::uint32 get_virtualization() const override {
    return 0;
  }
  CellUsageTree::NodePtr get_tree_node() const override {
    return {};
  }
  bool is_loaded() const override {
    return false;
  }

 private:
  const Hash do_get_hash(td::uint32 level) const override {
    return info_.get_hashes(get_storage())[get_level_mask().apply(level).get_hash_i()];
  }

  td::uint16 do_get_depth(td::uint32 level) const override {
    return info_.get_depth(get_storage())[get_level_mask().apply(level).get_hash_i()];
  }

  td::Result<LoadedCell> load_cell() const override {
    return td::Status::Error("Can't load prunned branch");
  }
};
}  // namespace vm
