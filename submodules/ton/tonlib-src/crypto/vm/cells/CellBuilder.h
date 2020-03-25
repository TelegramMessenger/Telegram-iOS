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
#include "vm/cells/DataCell.h"
#include "vm/cells/VirtualCell.h"
#include "vm/vmstate.h"
#include "common/refint.h"

#include "td/utils/ThreadSafeCounter.h"

namespace vm {

class CellSlice;
class DataCell;

class CellBuilder : public td::CntObject {
 public:
  struct CellWriteError {};
  struct CellCreateError {};

 private:
  unsigned bits;
  unsigned refs_cnt;
  std::array<Ref<Cell>, Cell::max_refs> refs;
  mutable unsigned char data[Cell::max_bytes];
  static td::NamedThreadSafeCounter::CounterRef get_thread_safe_counter() {
    static auto res = td::NamedThreadSafeCounter::get_default().get_counter("CellBuilder");
    return res;
  }

 public:
  CellBuilder();
  virtual ~CellBuilder() override;

  static Ref<Cell> create_pruned_branch(Ref<Cell> cell, td::uint32 new_level, td::uint32 virt_level = Cell::max_level);
  static Ref<DataCell> do_create_pruned_branch(Ref<Cell> cell, td::uint32 new_level,
                                               td::uint32 virt_level = Cell::max_level);
  static Ref<DataCell> create_merkle_proof(Ref<Cell> cell_proof);
  static Ref<DataCell> create_merkle_update(Ref<Cell> from_proof, Ref<Cell> to_proof);

  unsigned get_refs_cnt() const {
    return refs_cnt;
  }
  unsigned get_bits() const {
    return bits;
  }
  unsigned size_refs() const {
    return refs_cnt;
  }
  unsigned size() const {
    return bits;
  }
  unsigned size_ext() const {
    return (refs_cnt << 16) + bits;
  }
  unsigned remaining_bits() const {
    return Cell::max_bits - bits;
  }
  unsigned remaining_refs() const {
    return Cell::max_refs - refs_cnt;
  }
  const unsigned char* get_data() const {
    return data;
  }
  td::uint16 get_depth() const;
  td::ConstBitPtr data_bits() const {
    return data;
  }
  Ref<Cell> get_ref(unsigned idx) const {
    return idx < refs_cnt ? refs[idx] : Ref<Cell>{};
  }
  void reset();
  bool reset_bool() {
    reset();
    return true;
  }
  CellBuilder& operator=(const CellBuilder&);
  CellBuilder& operator=(CellBuilder&&);
  CellBuilder& store_bytes(const char* str, std::size_t len);
  CellBuilder& store_bytes(const char* str, const char* end);
  CellBuilder& store_bytes(const unsigned char* str, std::size_t len);
  CellBuilder& store_bytes(const unsigned char* str, const unsigned char* end);
  CellBuilder& store_bytes(td::Slice s);
  bool store_bytes_bool(const unsigned char* str, std::size_t len);
  bool store_bytes_bool(const char* str, std::size_t len);
  bool store_bytes_bool(td::Slice s);
  CellBuilder& store_bits(const unsigned char* str, std::size_t bit_count, int bit_offset = 0);
  CellBuilder& store_bits(const char* str, std::size_t bit_count, int bit_offset = 0);
  CellBuilder& store_bits(td::ConstBitPtr bs, std::size_t bit_count);
  CellBuilder& store_bits(const td::BitSlice& bs);
  CellBuilder& store_bits_same(std::size_t bit_count, bool val);
  bool store_bits_bool(const unsigned char* str, std::size_t bit_count, int bit_offset = 0);
  bool store_bits_bool(td::ConstBitPtr bs, std::size_t bit_count);
  template <unsigned n>
  bool store_bits_bool(const td::BitArray<n>& ba) {
    return store_bits_bool(ba.cbits(), n);
  }
  bool store_bits_same_bool(std::size_t bit_count, bool val);
  CellBuilder& store_zeroes(std::size_t bit_count) {
    return store_bits_same(bit_count, false);
  }
  CellBuilder& store_ones(std::size_t bit_count) {
    return store_bits_same(bit_count, true);
  }
  bool store_zeroes_bool(std::size_t bit_count) {
    return store_bits_same_bool(bit_count, false);
  }
  bool store_ones_bool(std::size_t bit_count) {
    return store_bits_same_bool(bit_count, true);
  }
  td::BitSliceWrite reserve_slice(std::size_t bit_count);
  CellBuilder& reserve_slice(std::size_t bit_count, td::BitSliceWrite& bsw);
  bool store_long_bool(long long val, unsigned val_bits = 64);
  bool store_long_rchk_bool(long long val, unsigned val_bits = 64);
  bool store_ulong_rchk_bool(unsigned long long val, unsigned val_bits = 64);
  bool store_uint_less(unsigned upper_bound, unsigned long long val);
  bool store_uint_leq(unsigned upper_bound, unsigned long long val);
  CellBuilder& store_long(long long val, unsigned val_bits = 64);
  // bool store_long_top_bool(unsigned long long val, unsigned top_bits);
  CellBuilder& store_long_top(unsigned long long val, unsigned top_bits);
  bool store_bool_bool(bool val);
  bool store_int256_bool(const td::BigInt256& val, unsigned val_bits, bool sgnd = true);
  bool store_int256_bool(td::RefInt256 val, unsigned val_bits, bool sgnd = true);
  bool store_uint256_bool(const td::BigInt256& val, unsigned val_bits) {
    return store_int256_bool(val, val_bits, false);
  }
  bool store_uint256_bool(td::RefInt256 val, unsigned val_bits) {
    return store_int256_bool(std::move(val), val_bits, false);
  }
  CellBuilder& store_int256(const td::BigInt256& val, unsigned val_bits, bool sgnd = true);
  CellBuilder& store_uint256(const td::BigInt256& val, unsigned val_bits) {
    return store_int256(val, val_bits, false);
  }
  bool store_builder_ref_bool(vm::CellBuilder&& cb);
  bool store_ref_bool(Ref<Cell> r);
  CellBuilder& store_ref(Ref<Cell> r);
  bool append_data_cell_bool(const DataCell& cell);
  CellBuilder& append_data_cell(const DataCell& cell);
  bool append_data_cell_bool(Ref<DataCell> cell_ref);
  CellBuilder& append_data_cell(Ref<DataCell> cell_ref);
  bool append_builder_bool(const CellBuilder& cb);
  CellBuilder& append_builder(const CellBuilder& cb);
  bool append_builder_bool(Ref<CellBuilder> cb_ref);
  CellBuilder& append_builder(Ref<CellBuilder> cb_ref);
  bool append_cellslice_bool(const CellSlice& cs);
  CellBuilder& append_cellslice(const CellSlice& cs);
  bool append_cellslice_bool(Ref<CellSlice> cs_ref);
  CellBuilder& append_cellslice(Ref<CellSlice> cs_ref);
  bool append_cellslice_chk(const CellSlice& cs, unsigned size_ext);
  bool append_cellslice_chk(Ref<CellSlice> cs, unsigned size_ext);
  bool append_bitstring(const td::BitString& bs);
  bool append_bitstring(Ref<td::BitString> bs_ref);
  bool append_bitstring_chk(const td::BitString& bs, unsigned size);
  bool append_bitstring_chk(Ref<td::BitString> bs, unsigned size);
  bool append_bitslice(const td::BitSlice& bs);
  bool store_maybe_ref(Ref<Cell> cell);
  bool contents_equal(const CellSlice& cs) const;
  CellBuilder* make_copy() const override;
  bool can_extend_by(std::size_t bits) const;
  bool can_extend_by(std::size_t bits, unsigned refs) const;
  Ref<DataCell> finalize_copy(bool special = false) const;
  Ref<DataCell> finalize(bool special = false);
  Ref<DataCell> finalize_novm(bool special = false);
  td::Result<Ref<DataCell>> finalize_novm_nothrow(bool special = false);
  bool finalize_to(Ref<Cell>& res, bool special = false) {
    return (res = finalize(special)).not_null();
  }
  CellSlice as_cellslice() const&;
  CellSlice as_cellslice() &&;
  Ref<CellSlice> as_cellslice_ref() const&;
  Ref<CellSlice> as_cellslice_ref() &&;
  static td::int64 get_total_cell_builders() {
    return get_thread_safe_counter().sum();
  }
  int get_serialized_size() const {
    return ((bits + 23) >> 3);
  }
  int serialize(unsigned char* buff, int buff_size) const;
  std::string serialize() const;
  std::string to_hex() const;
  const unsigned char* compute_hash(unsigned char buffer[Cell::hash_bytes]) const;

  const CellBuilder& ensure_pass(bool cond) const {
    ensure_throw(cond);
    return *this;
  }
  CellBuilder& ensure_pass(bool cond) {
    ensure_throw(cond);
    return *this;
  }
  void ensure_throw(bool cond) const {
    if (!cond) {
      throw CellCreateError{};
    }
  }

 private:
  void flush(unsigned char d[2]) const;
  bool prepare_reserve(std::size_t bit_count);
  bool can_extend_by_fast(unsigned bits_req) const {
    return (int)bits <= (int)(Cell::max_bits - bits_req);
  }
  bool can_extend_by_fast(unsigned bits_req, unsigned refs_req) const {
    return (int)bits <= (int)(Cell::max_bits - bits_req) && (int)refs_cnt <= (int)(Cell::max_refs - refs_req);
  }
  bool can_extend_by_fast2(unsigned bits_req) const {
    return bits + bits_req <= Cell::max_bits;
  }
  bool can_extend_by_fast2(unsigned bits_req, unsigned refs_req) const {
    return bits + bits_req <= Cell::max_bits && refs_cnt + refs_req <= Cell::max_refs;
  }
};

std::ostream& operator<<(std::ostream& os, const CellBuilder& cb);

template <class T>
CellBuilder& operator<<(CellBuilder& cb, const T& val) {
  return cb.ensure_pass(val.serialize(cb));
}

template <class T>
Ref<CellBuilder>& operator<<(Ref<CellBuilder>& cb_ref, const T& val) {
  bool res = val.serialize(cb_ref.write());
  cb_ref->ensure_throw(res);
  return cb_ref;
}

}  // namespace vm
