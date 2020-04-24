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

#include "common/refcnt.hpp"
#include "common/refint.h"
#include "vm/cells.h"

namespace td {
class StringBuilder;
}
namespace vm {

struct NoVm {};
struct NoVmOrd {};
struct NoVmSpec {};

class CellSlice : public td::CntObject {
  Cell::VirtualizationParameters virt;
  Ref<DataCell> cell;
  CellUsageTree::NodePtr tree_node;
  unsigned bits_st, refs_st;
  unsigned bits_en, refs_en;
  mutable const unsigned char* ptr{nullptr};
  mutable unsigned long long z;
  mutable unsigned zd;

 public:
  static constexpr long long fetch_long_eof = (static_cast<unsigned long long>(-1LL) << 63);
  static constexpr unsigned long long fetch_ulong_eof = (unsigned long long)-1LL;
  enum { default_recursive_print_limit = 100 };
  struct CellReadError {};

  CellSlice(NoVm, Ref<Cell> cell_ref);
  CellSlice(NoVmOrd, Ref<Cell> cell_ref);
  CellSlice(NoVmSpec, Ref<Cell> cell_ref);
  CellSlice(Ref<DataCell> dc_ref);
  CellSlice(VirtualCell::LoadedCell loaded_cell);
  /*
  CellSlice(Ref<DataCell> dc_ref, unsigned _bits_en, unsigned _refs_en, unsigned _bits_st = 0, unsigned _refs_st = 0);*/
  CellSlice(const CellSlice& cs, unsigned _bits_en, unsigned _refs_en);
  CellSlice(const CellSlice& cs, unsigned _bits_en, unsigned _refs_en, unsigned _bits_st, unsigned _refs_st);
  CellSlice(const CellSlice&);
  CellSlice& operator=(const CellSlice& other) = default;
  CellSlice();
  Cell::LoadedCell move_as_loaded_cell();
  td::CntObject* make_copy() const override {
    return new CellSlice{*this};
  }
  void clear();
  bool load(VirtualCell::LoadedCell loaded_cell);
  bool load(NoVm, Ref<Cell> cell_ref);
  bool load(NoVmOrd, Ref<Cell> cell_ref);
  bool load(NoVmSpec, Ref<Cell> cell_ref);
  bool load(Ref<DataCell> dc_ref);
  bool load(Ref<Cell> cell);
  bool load_ord(Ref<Cell> cell);
  unsigned size() const {
    return bits_en - bits_st;
  }
  bool is_special() const {
    return cell->is_special();
  }
  bool is_valid() const {
    return cell.not_null();
  }
  Cell::SpecialType special_type() const {
    return cell->special_type();
  }
  int child_merkle_depth(int merkle_depth) const {
    if (merkle_depth == Cell::VirtualizationParameters::max_level()) {
      return merkle_depth;
    }
    if (cell->special_type() == Cell::SpecialType::MerkleProof ||
        cell->special_type() == Cell::SpecialType::MerkleUpdate) {
      merkle_depth++;
    }
    return merkle_depth;
  }
  unsigned size_refs() const {
    return refs_en - refs_st;
  }
  unsigned size_ext() const {
    return size() + (size_refs() << 16);
  }
  bool have(unsigned bits) const {
    return bits <= size();
  }
  bool have(unsigned bits, unsigned refs) const {
    return bits <= size() && refs <= size_refs();
  }
  bool have_ext(unsigned ext_size) const {
    return have(ext_size & 0xffff, ext_size >> 16);
  }
  bool empty() const {
    return !size();
  }
  bool empty_ext() const {
    return !size() && !size_refs();
  }
  bool have_refs(unsigned refs = 1) const {
    return refs <= size_refs();
  }
  bool advance(unsigned bits);
  bool advance_refs(unsigned refs);
  bool advance_ext(unsigned bits_refs);
  bool advance_ext(unsigned bits, unsigned refs);
  unsigned cur_pos() const {
    return bits_st;
  }
  unsigned cur_ref() const {
    return refs_st;
  }
  const unsigned char* data() const {
    return cell->get_data();
  }
  td::uint16 get_depth() const;
  td::ConstBitPtr data_bits() const {
    return td::ConstBitPtr{data(), (int)cur_pos()};
  }
  int subtract_base_ext(const CellSlice& base) {
    return (bits_st - base.bits_st) | ((refs_st - base.refs_st) << 16);
  }
  unsigned get_cell_level() const;
  unsigned get_level() const;
  Ref<Cell> get_base_cell() const;  // be careful with this one!
  int fetch_octet();
  int prefetch_octet() const;
  unsigned long long prefetch_ulong_top(unsigned& bits) const;
  unsigned long long fetch_ulong(unsigned bits);
  unsigned long long prefetch_ulong(unsigned bits) const;
  long long fetch_long(unsigned bits);
  long long prefetch_long(unsigned bits) const;
  bool fetch_long_bool(unsigned bits, long long& res);
  bool prefetch_long_bool(unsigned bits, long long& res) const;
  bool fetch_ulong_bool(unsigned bits, unsigned long long& res);
  bool prefetch_ulong_bool(unsigned bits, unsigned long long& res) const;
  bool fetch_bool_to(bool& res);
  bool fetch_bool_to(int& res);
  bool fetch_bool_to(int& res, int mask);
  bool fetch_uint_to(unsigned bits, unsigned long long& res);
  bool fetch_uint_to(unsigned bits, long long& res);
  bool fetch_uint_to(unsigned bits, unsigned long& res);
  bool fetch_uint_to(unsigned bits, long& res);
  bool fetch_uint_to(unsigned bits, unsigned& res);
  bool fetch_uint_to(unsigned bits, int& res);
  bool fetch_uint_less(unsigned upper_bound, int& res);
  bool fetch_uint_less(unsigned upper_bound, unsigned& res);
  bool fetch_uint_leq(unsigned upper_bound, int& res);
  bool fetch_uint_leq(unsigned upper_bound, unsigned& res);
  bool fetch_int_to(unsigned bits, long long& res);
  bool fetch_int_to(unsigned bits, int& res);
  int bselect(unsigned bits, unsigned long long mask) const;
  int bselect_ext(unsigned bits, unsigned long long mask) const;
  int bit_at(unsigned i) const {
    return have(i) ? data_bits()[i] : -1;
  }
  td::RefInt256 fetch_int256(unsigned bits, bool sgnd = true);
  td::RefInt256 prefetch_int256(unsigned bits, bool sgnd = true) const;
  td::RefInt256 prefetch_int256_zeroext(unsigned bits, bool sgnd = true) const;
  bool fetch_int256_to(unsigned bits, td::RefInt256& res, bool sgnd = true) {
    return (res = fetch_int256(bits, sgnd)).not_null();
  }
  bool fetch_uint256_to(unsigned bits, td::RefInt256& res) {
    return (res = fetch_int256(bits, false)).not_null();
  }
  Ref<Cell> prefetch_ref(unsigned offset = 0) const;
  Ref<Cell> fetch_ref();
  bool fetch_ref_to(Ref<Cell>& ref) {
    return (ref = fetch_ref()).not_null();
  }
  bool prefetch_ref_to(Ref<Cell>& ref, unsigned offset = 0) const {
    return (ref = prefetch_ref(offset)).not_null();
  }
  bool fetch_maybe_ref(Ref<Cell>& ref);
  bool prefetch_maybe_ref(Ref<Cell>& ref) const;
  td::BitSlice fetch_bits(unsigned bits);
  td::BitSlice prefetch_bits(unsigned bits) const;
  td::Ref<CellSlice> fetch_subslice(unsigned bits, unsigned refs = 0);
  td::Ref<CellSlice> prefetch_subslice(unsigned bits, unsigned refs = 0) const;
  td::Ref<CellSlice> fetch_subslice_ext(unsigned size);
  td::Ref<CellSlice> prefetch_subslice_ext(unsigned size) const;
  td::Ref<td::BitString> fetch_bitstring(unsigned size);
  td::Ref<td::BitString> prefetch_bitstring(unsigned size) const;
  bool fetch_subslice_to(unsigned bits, td::Ref<CellSlice>& res) {
    return (res = fetch_subslice(bits)).not_null();
  }
  bool fetch_subslice_ext_to(unsigned bits, td::Ref<CellSlice>& res) {
    return (res = fetch_subslice_ext(bits)).not_null();
  }
  bool fetch_bitstring_to(unsigned bits, td::Ref<td::BitString>& res) {
    return (res = fetch_bitstring(bits)).not_null();
  }
  bool fetch_bits_to(td::BitPtr buffer, unsigned bits);
  bool prefetch_bits_to(td::BitPtr buffer, unsigned bits) const;
  template <unsigned n>
  bool fetch_bits_to(td::BitArray<n>& buffer) {
    return fetch_bits_to(buffer.bits(), n);
  }
  template <unsigned n>
  bool prefetch_bits_to(td::BitArray<n>& buffer) const {
    return prefetch_bits_to(buffer.bits(), n);
  }
  bool fetch_bytes(unsigned char* buffer, unsigned bytes);
  bool fetch_bytes(td::MutableSlice slice);
  bool prefetch_bytes(unsigned char* buffer, unsigned bytes) const;
  bool prefetch_bytes(td::MutableSlice slice) const;
  td::BitSlice as_bitslice() const {
    return prefetch_bits(size());
  }
  bool begins_with(unsigned bits, unsigned long long value) const;
  bool begins_with(unsigned long long value) const;
  bool begins_with_skip(unsigned bits, unsigned long long value) {
    return begins_with(bits, value) && advance(bits);
  }
  bool begins_with_skip(unsigned long long value);
  bool only_first(unsigned bits, unsigned refs = 0);
  bool only_ext(unsigned size);
  bool skip_first(unsigned bits, unsigned refs = 0);
  bool skip_ext(unsigned size);
  bool only_last(unsigned bits, unsigned refs = 0);
  bool skip_last(unsigned bits, unsigned refs = 0);
  bool cut_tail(const CellSlice& tail_cs);
  int remove_trailing();
  int count_leading(bool bit) const;
  int count_trailing(bool bit) const;
  int lex_cmp(const CellSlice& cs2) const;
  int common_prefix_len(const CellSlice& cs2) const;
  bool is_prefix_of(const CellSlice& cs2) const;
  bool is_prefix_of(td::ConstBitPtr bs, unsigned len) const;
  bool is_suffix_of(const CellSlice& cs2) const;
  bool has_prefix(const CellSlice& cs2) const;
  bool has_prefix(td::ConstBitPtr bs, unsigned len) const;
  bool has_suffix(const CellSlice& cs2) const;
  bool is_proper_prefix_of(const CellSlice& cs2) const;
  bool is_proper_suffix_of(const CellSlice& cs2) const;
  // int common_prefix_len(const td::BitSlice& bs, unsigned offs = 0, unsigned max_len = 0xffffffffU) const;
  int common_prefix_len(td::ConstBitPtr bs, unsigned len) const;
  // bool is_prefix_of(const td::BitSlice& bs, unsigned offs = 0, unsigned max_len = 0xffffffffU) const;
  bool contents_equal(const CellSlice& cs2) const;
  void dump(std::ostream& os, int level = 0, bool endl = true) const;
  void dump_hex(std::ostream& os, int mode = 0, bool endl = false) const;
  bool print_rec(std::ostream& os, int indent = 0) const;
  bool print_rec(std::ostream& os, int* limit, int indent = 0) const;
  bool print_rec(int limit, std::ostream& os, int indent = 0) const;
  void error() const {
    throw CellReadError{};
  }
  bool chk(bool cond) const {
    if (!cond) {
      error();
    }
    return cond;
  }
  bool have_chk(unsigned bits) const {
    return chk(have(bits));
  }
  bool have_chk(unsigned bits, unsigned refs) const {
    return chk(have(bits, refs));
  }
  bool have_refs_chk(unsigned refs = 1) const {
    return chk(have_refs(refs));
  }
  CellSlice operator+(unsigned offs) const {
    offs = std::min(offs, size());
    return CellSlice{*this, size() - offs, size_refs(), offs, 0};
  }
  CellSlice clone() const;

 private:
  void init_bits_refs();
  void init_preload() const;
  void preload_at_least(unsigned req_bits) const;
  Cell::VirtualizationParameters child_virt() const {
    return Cell::VirtualizationParameters(static_cast<td::uint8>(child_merkle_depth(virt.get_level())),
                                          virt.get_virtualization());
  }
};

td::StringBuilder& operator<<(td::StringBuilder& sb, const CellSlice& cs);

bool cell_builder_add_slice_bool(CellBuilder& cb, const CellSlice& cs);
CellBuilder& cell_builder_add_slice(CellBuilder& cb, const CellSlice& cs);

std::ostream& operator<<(std::ostream& os, CellSlice cs);
std::ostream& operator<<(std::ostream& os, Ref<CellSlice> cs_ref);

template <class T>
CellSlice& operator>>(CellSlice& cs, T& val) {
  cs.chk(val.deserialize(cs));
  return cs;
}

template <class T>
Ref<CellSlice>& operator>>(Ref<CellSlice>& cs_ref, T& val) {
  bool res = val.deserialize(cs_ref.write());
  cs_ref->chk(res);
  return cs_ref;
}

template <class T>
CellSlice& operator>>(CellSlice& cs, const T& val) {
  cs.chk(val.deserialize(cs));
  return cs;
}

template <class T>
Ref<CellSlice>& operator>>(Ref<CellSlice>& cs_ref, const T& val) {
  bool res = val.deserialize(cs_ref.write());
  cs_ref->chk(res);
  return cs_ref;
}

// If can_be_special is not null, then it is allowed to load special cell
// Flag whether loaded cell is actually special will be stored into can_be_special
CellSlice load_cell_slice(const Ref<Cell>& cell);
Ref<CellSlice> load_cell_slice_ref(const Ref<Cell>& cell);
CellSlice load_cell_slice_special(const Ref<Cell>& cell, bool& is_special);
Ref<CellSlice> load_cell_slice_ref_special(const Ref<Cell>& cell, bool& is_special);
void print_load_cell(std::ostream& os, Ref<Cell> cell, int indent = 0);

}  // namespace vm
