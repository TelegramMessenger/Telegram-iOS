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
#include "vm/cells/Cell.h"

#include "td/utils/Span.h"

#include "td/utils/ThreadSafeCounter.h"

namespace vm {

class DataCell : public Cell {
 public:
  DataCell(const DataCell& other) = delete;
  ~DataCell() override;

  static void store_depth(td::uint8* dest, td::uint16 depth) {
    td::bitstring::bits_store_long(dest, depth, depth_bits);
  }
  static td::uint16 load_depth(const td::uint8* src) {
    return td::bitstring::bits_load_ulong(src, depth_bits) & 0xff;
  }

 protected:
  struct Info {
    unsigned bits_;

    // d1
    unsigned char refs_count_ : 3;
    bool is_special_ : 1;
    unsigned char level_mask_ : 3;

    unsigned char hash_count_ : 3;

    unsigned char virtualization_ : 3;

    unsigned char d1() const {
      return d1(LevelMask{level_mask_});
    }
    unsigned char d1(LevelMask level_mask) const {
      // d1 = refs_count + 8 * is_special + 32 * level
      //      + 16 * with_hashes - for seriazlization
      // d1 = 7 + 16 + 32 * l - for absent cells
      return static_cast<unsigned char>(refs_count_ + 8 * is_special_ + 32 * level_mask.get_mask());
    }
    unsigned char d2() const {
      auto res = static_cast<unsigned char>((bits_ / 8) * 2);
      if ((bits_ & 7) != 0) {
        return static_cast<unsigned char>(res + 1);
      }
      return res;
    }
    size_t get_hashes_offset() const {
      return 0;
    }
    size_t get_refs_offset() const {
      return get_hashes_offset() + hash_bytes * hash_count_;
    }
    size_t get_depth_offset() const {
      return get_refs_offset() + refs_count_ * sizeof(Cell*);
    }
    size_t get_data_offset() const {
      return get_depth_offset() + sizeof(td::uint16) * hash_count_;
    }
    size_t get_storage_size() const {
      return get_data_offset() + (bits_ + 7) / 8;
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

    const unsigned char* get_data(const char* storage) const {
      return reinterpret_cast<const unsigned char*>(storage + get_data_offset());
    }
    unsigned char* get_data(char* storage) const {
      return reinterpret_cast<unsigned char*>(storage + get_data_offset());
    }

    Cell* const* get_refs(const char* storage) const {
      return reinterpret_cast<Cell* const*>(storage + get_refs_offset());
    }
    Cell** get_refs(char* storage) const {
      return reinterpret_cast<Cell**>(storage + get_refs_offset());
    }
  };

  Info info_;
  virtual char* get_storage() = 0;
  virtual const char* get_storage() const = 0;
  // TODO: we may also save three different pointers

  void destroy_storage(char* storage);

  explicit DataCell(Info info);
  Cell* get_ref_raw_ptr(unsigned idx) const {
    DCHECK(idx < get_refs_cnt());
    return info_.get_refs(get_storage())[idx];
  }

 public:
  td::Result<LoadedCell> load_cell() const override {
    return LoadedCell{Ref<DataCell>{this}, {}, {}};
  }
  unsigned get_refs_cnt() const {
    return info_.refs_count_;
  }
  unsigned get_bits() const {
    return info_.bits_;
  }
  unsigned size_refs() const {
    return info_.refs_count_;
  }
  unsigned size() const {
    return info_.bits_;
  }
  const unsigned char* get_data() const {
    return info_.get_data(get_storage());
  }
  Ref<Cell> get_ref(unsigned idx) const {
    if (idx >= get_refs_cnt()) {
      return Ref<Cell>{};
    }
    return Ref<Cell>(get_ref_raw_ptr(idx));
  }

  td::uint32 get_virtualization() const override {
    return info_.virtualization_;
  }
  CellUsageTree::NodePtr get_tree_node() const override {
    return {};
  }
  bool is_loaded() const override {
    return true;
  }
  LevelMask get_level_mask() const override {
    return LevelMask{info_.level_mask_};
  }

  bool is_special() const {
    return info_.is_special_;
  }
  SpecialType special_type() const;
  int get_serialized_size(bool with_hashes = false) const {
    return ((get_bits() + 23) >> 3) +
           (with_hashes ? get_level_mask().get_hashes_count() * (hash_bytes + depth_bytes) : 0);
  }
  int serialize(unsigned char* buff, int buff_size, bool with_hashes = false) const;
  std::string serialize() const;
  std::string to_hex() const;
  static td::int64 get_total_data_cells() {
    return get_thread_safe_counter().sum();
  }

  template <class StorerT>
  void store(StorerT& storer) const {
    storer.template store_binary<td::uint8>(info_.d1());
    storer.template store_binary<td::uint8>(info_.d2());
    storer.store_slice(td::Slice(get_data(), (get_bits() + 7) / 8));
  }

 protected:
  static constexpr auto max_storage_size = max_refs * sizeof(void*) + (max_level + 1) * hash_bytes + max_bytes;

 private:
  static td::NamedThreadSafeCounter::CounterRef get_thread_safe_counter() {
    static auto res = td::NamedThreadSafeCounter::get_default().get_counter("DataCell");
    return res;
  }
  static std::unique_ptr<DataCell> create_empty_data_cell(Info info);

  const Hash do_get_hash(td::uint32 level) const override;
  td::uint16 do_get_depth(td::uint32 level) const override;

  friend class CellBuilder;
  static td::Result<Ref<DataCell>> create(td::ConstBitPtr data, unsigned bits, td::Span<Ref<Cell>> refs, bool special);
  static td::Result<Ref<DataCell>> create(td::ConstBitPtr data, unsigned bits, td::MutableSpan<Ref<Cell>> refs,
                                          bool special);
};

std::ostream& operator<<(std::ostream& os, const DataCell& c);

}  // namespace vm

