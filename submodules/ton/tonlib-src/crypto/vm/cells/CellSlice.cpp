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
#include "vm/cells/CellSlice.h"
#include "vm/excno.hpp"
#include "td/utils/bits.h"

namespace vm {

/*
CellSlice::CellSlice(Ref<Cell>&& ref) : cell(std::move(ref)), bits_st(0), refs_st(0), ptr(0), zd(0) {
  init_bits_refs();
}
*/

CellSlice::CellSlice(VirtualCell::LoadedCell loaded_cell)
    : virt(loaded_cell.virt)
    , cell(std::move(loaded_cell.data_cell))
    , tree_node(std::move(loaded_cell.tree_node))
    , bits_st(0)
    , refs_st(0)
    , ptr(0)
    , zd(0) {
  init_bits_refs();
}

CellSlice::CellSlice() : bits_st(0), refs_st(0), bits_en(0), refs_en(0), ptr(0), zd(0) {
}

namespace {
Cell::LoadedCell load_cell_nothrow(const Ref<Cell>& ref) {
  auto res = ref->load_cell();
  if (res.is_ok()) {
    auto ld = res.move_as_ok();
    CHECK(ld.virt.get_virtualization() == 0 || ld.data_cell->special_type() != Cell::SpecialType::PrunnedBranch);
    return ld;
  }
  return {};
}

Cell::LoadedCell load_cell_nothrow(const Ref<Cell>& ref, int mode) {
  auto res = ref->load_cell();
  if (res.is_ok()) {
    auto ld = res.move_as_ok();
    CHECK(ld.virt.get_virtualization() == 0 || ld.data_cell->special_type() != Cell::SpecialType::PrunnedBranch);
    if ((mode >> (ld.data_cell->is_special() ? 1 : 0)) & 1) {
      return ld;
    }
  }
  return {};
}

}  // namespace

CellSlice::CellSlice(NoVm, Ref<Cell> ref) : CellSlice(load_cell_nothrow(std::move(ref))) {
}
CellSlice::CellSlice(NoVmOrd, Ref<Cell> ref) : CellSlice(load_cell_nothrow(std::move(ref), 1)) {
}
CellSlice::CellSlice(NoVmSpec, Ref<Cell> ref) : CellSlice(load_cell_nothrow(std::move(ref), 2)) {
}
CellSlice::CellSlice(Ref<DataCell> ref) : CellSlice(VirtualCell::LoadedCell{std::move(ref), {}, {}}) {
}
CellSlice::CellSlice(const CellSlice& cs) = default;

bool CellSlice::load(VirtualCell::LoadedCell loaded_cell) {
  virt = loaded_cell.virt;
  cell = std::move(loaded_cell.data_cell);
  tree_node = std::move(loaded_cell.tree_node);
  bits_st = 0;
  refs_st = 0;
  ptr = 0;
  zd = 0;
  init_bits_refs();
  return cell.not_null();
}

bool CellSlice::load(NoVm, Ref<Cell> cell_ref) {
  return load(load_cell_nothrow(std::move(cell_ref)));
}
bool CellSlice::load(NoVmOrd, Ref<Cell> cell_ref) {
  return load(load_cell_nothrow(std::move(cell_ref), 1));
}
bool CellSlice::load(NoVmSpec, Ref<Cell> cell_ref) {
  return load(load_cell_nothrow(std::move(cell_ref), 2));
}
bool CellSlice::load(Ref<DataCell> dc_ref) {
  return load(VirtualCell::LoadedCell{std::move(dc_ref), {}, {}});
}

/*
CellSlice::CellSlice(Ref<DataCell> dc_ref, unsigned _bits_en, unsigned _refs_en, unsigned _bits_st, unsigned _refs_st)
    : cell(std::move(dc_ref))
    , bits_st(_bits_st)
    , refs_st(_refs_st)
    , bits_en(_bits_en)
    , refs_en(_refs_en)
    , ptr(0)
    , zd(0) {
  assert(bits_st <= bits_en && refs_st <= refs_en);
  if (cell.is_null()) {
    assert(!bits_en && !refs_en);
  } else {
    assert(bits_en <= cell->get_bits() && refs_en <= cell->get_refs_cnt());
    if (bits_en) {
      init_preload();
    }
  }
}
*/

CellSlice::CellSlice(const CellSlice& cs, unsigned _bits_en, unsigned _refs_en, unsigned _bits_st, unsigned _refs_st)
    : virt(cs.virt)
    , cell(cs.cell)
    , tree_node(cs.tree_node)
    , bits_st(cs.bits_st + _bits_st)
    , refs_st(cs.refs_st + _refs_st)
    , bits_en(cs.bits_st + _bits_en)
    , refs_en(cs.refs_st + _refs_en)
    , ptr(0)
    , zd(0) {
  assert(_bits_st <= _bits_en && _refs_st <= _refs_en);
  assert(_bits_en <= cs.size() && _refs_en <= cs.size_refs());
  if (_bits_en > _bits_st) {
    init_preload();
  }
}

CellSlice::CellSlice(const CellSlice& cs, unsigned _bits_en, unsigned _refs_en)
    : virt(cs.virt)
    , cell(cs.cell)
    , tree_node(cs.tree_node)
    , bits_st(cs.bits_st)
    , refs_st(cs.refs_st)
    , bits_en(cs.bits_st + _bits_en)
    , refs_en(cs.refs_st + _refs_en)
    , ptr(0)
    , zd(0) {
  assert(_bits_en <= cs.size() && _refs_en <= cs.size_refs());
  if (_bits_en) {
    init_preload();
  }
}

Cell::LoadedCell CellSlice::move_as_loaded_cell() {
  Cell::LoadedCell res{std::move(cell), std::move(virt), std::move(tree_node)};
  clear();
  return res;
}

void CellSlice::init_bits_refs() {
  if (cell.is_null()) {
    bits_en = 0;
    refs_en = 0;
  } else {
    bits_en = cell->get_bits();
    refs_en = cell->get_refs_cnt();
    if (bits_en) {
      init_preload();
    }
  }
}

void CellSlice::init_preload() const {
  if (bits_st >= bits_en) {
    zd = 0;
    return;
  }
  ptr = cell->get_data() + (bits_st >> 3) + 1;
  unsigned t = 8 - (bits_st & 7);
  z = (((unsigned long long)ptr[-1]) << (64 - t));
  zd = std::min(t, size());
}

void CellSlice::clear() {
  zd = 0;
  bits_en = bits_st = 0;
  refs_st = refs_en = 0;
  ptr = 0;
  cell.clear();
}

/*
void CellSlice::error() {
  // maybe throw a different simple exception, and convert it at the upper level of the vm
  throw VmError{Excno::cell_und, "cell deserialization error"};
}
*/

unsigned CellSlice::get_cell_level() const {
  return cell->get_level_mask().apply(virt.get_level()).get_level();
}

unsigned CellSlice::get_level() const {
  unsigned l = 0;
  for (unsigned i = refs_st; i < refs_en; i++) {
    auto res = cell->get_ref(i)->virtualize(child_virt());
    unsigned l1 = res->get_level();
    // maybe l1 = cell->get_ref(i)->get_level_mask().apply(virt.get_level()).get_level();
    if (l1 > l) {
      l = l1;
    }
  }
  return l;
}

bool CellSlice::advance(unsigned bits) {
  if (have(bits)) {
    bits_st += bits;
    if (zd <= bits) {  // NB: if we write here zd < bits, we obtain bug with z <<= 64
      init_preload();
    } else {
      zd -= bits;
      z <<= bits;
    }
    return true;
  } else {
    return false;
  }
}

bool CellSlice::advance_refs(unsigned refs = 1) {
  if (have_refs(refs)) {
    refs_st += refs;
    return true;
  } else {
    return false;
  }
}

bool CellSlice::advance_ext(unsigned bits, unsigned refs) {
  if (have(bits) && have_refs(refs)) {
    refs_st += refs;
    return advance(bits);
  } else {
    return false;
  }
}

bool CellSlice::advance_ext(unsigned bits_refs) {
  return advance_ext(bits_refs >> 16, bits_refs & 0xffff);
}

// (PRIVATE)
// assume: at least `req_bits` bits can be preloaded
void CellSlice::preload_at_least(unsigned req_bits) const {
  assert(req_bits <= 64 && have(req_bits) && ptr);
  if (req_bits <= zd) {
    return;
  }
  int remain = bits_en - bits_st - zd;
  if (zd <= 32 && remain > 24) {
    z |= (((unsigned long long)td::bswap32(td::as<unsigned>(ptr))) << (32 - zd));
    ptr += 4;
    if (remain <= 32) {
      zd += remain;
      return;
    }
    zd += 32;
    remain -= 32;
  }
  while (zd < req_bits && remain > 0) {
    if (zd > 56) {
      z |= (*ptr >> (zd - 56));
      return;
    }
    z |= (((unsigned long long)*ptr++) << (56 - zd));
    if (remain <= 8) {
      zd += remain;
      return;
    }
    zd += 8;
    remain -= 8;
  }
}

int CellSlice::prefetch_octet() const {
  if (!have(8)) {
    return -1;
  } else {
    preload_at_least(8);
    return (int)(z >> 56);
  }
}

int CellSlice::fetch_octet() {
  if (!have(8)) {
    return -1;
  } else {
    preload_at_least(8);
    int res = (int)(z >> 56);
    z <<= 8;
    zd -= 8;
    return res;
  }
}

unsigned long long CellSlice::fetch_ulong(unsigned bits) {
  if (!have(bits) || bits > 64) {
    return fetch_ulong_eof;
  } else if (!bits) {
    return 0;
  } else if (bits <= 56) {
    preload_at_least(bits);
    unsigned long long res = (z >> (64 - bits));
    z <<= bits;
    assert(zd >= bits);
    zd -= bits;
    bits_st += bits;
    return res;
  } else {
    preload_at_least(bits);
    unsigned long long res = (z >> (64 - bits));
    advance(bits);
    return res;
  }
}

unsigned long long CellSlice::prefetch_ulong(unsigned bits) const {
  if (!have(bits) || bits > 64) {
    return fetch_ulong_eof;
  } else if (!bits) {
    return 0;
  } else {
    preload_at_least(bits);
    return (z >> (64 - bits));
  }
}

unsigned long long CellSlice::prefetch_ulong_top(unsigned& bits) const {
  if (bits > size()) {
    bits = size();
  }
  if (!bits) {
    return 0;
  }
  preload_at_least(bits);
  return z;
}

long long CellSlice::fetch_long(unsigned bits) {
  if (!have(bits) || bits > 64) {
    return fetch_long_eof;
  } else if (!bits) {
    return 0;
  } else if (bits <= 56) {
    preload_at_least(bits);
    long long res = ((long long)z >> (64 - bits));
    z <<= bits;
    assert(zd >= bits);
    zd -= bits;
    bits_st += bits;
    return res;
  } else {
    preload_at_least(bits);
    long long res = ((long long)z >> (64 - bits));
    advance(bits);
    return res;
  }
}

long long CellSlice::prefetch_long(unsigned bits) const {
  if (!have(bits) || bits > 64) {
    return fetch_long_eof;
  } else if (!bits) {
    return 0;
  } else {
    preload_at_least(bits);
    return ((long long)z >> (64 - bits));
  }
}

bool CellSlice::fetch_long_bool(unsigned bits, long long& res) {
  if (bits > 64 || !have(bits)) {
    return false;
  }
  res = fetch_long(bits);
  return true;
}

bool CellSlice::prefetch_long_bool(unsigned bits, long long& res) const {
  if (bits > 64 || !have(bits)) {
    return false;
  }
  res = prefetch_long(bits);
  return true;
}

bool CellSlice::fetch_ulong_bool(unsigned bits, unsigned long long& res) {
  if (bits > 64 || !have(bits)) {
    return false;
  }
  res = fetch_ulong(bits);
  return true;
}

bool CellSlice::prefetch_ulong_bool(unsigned bits, unsigned long long& res) const {
  if (bits > 64 || !have(bits)) {
    return false;
  }
  res = prefetch_ulong(bits);
  return true;
}

bool CellSlice::fetch_bool_to(bool& res) {
  if (!have(1)) {
    return false;
  } else {
    res = (bool)fetch_ulong(1);
    return true;
  }
}

bool CellSlice::fetch_bool_to(int& res) {
  if (!have(1)) {
    return false;
  } else {
    res = (int)fetch_ulong(1);
    return true;
  }
}

bool CellSlice::fetch_bool_to(int& res, int mask) {
  if (!have(1)) {
    return false;
  } else if (fetch_ulong(1)) {
    res |= mask;
  } else {
    res &= ~mask;
  }
  return true;
}

bool CellSlice::fetch_uint_to(unsigned bits, unsigned long long& res) {
  if (bits > 64 || !have(bits)) {
    return false;
  } else {
    res = fetch_ulong(bits);
    return true;
  }
}

bool CellSlice::fetch_uint_to(unsigned bits, long long& res) {
  if (bits > 64 || !have(bits)) {
    return false;
  } else {
    res = (long long)fetch_ulong(bits);
    return res >= 0;
  }
}

bool CellSlice::fetch_uint_to(unsigned bits, unsigned long& res) {
  if (bits > 8 * sizeof(unsigned long) || !have(bits)) {
    return false;
  } else {
    res = static_cast<unsigned long>(fetch_ulong(bits));
    return true;
  }
}

bool CellSlice::fetch_uint_to(unsigned bits, long& res) {
  if (bits > 8 * sizeof(long) || !have(bits)) {
    return false;
  } else {
    res = static_cast<long>(fetch_ulong(bits));
    return res >= 0;
  }
}

bool CellSlice::fetch_uint_to(unsigned bits, unsigned& res) {
  if (bits > 32 || !have(bits)) {
    return false;
  } else {
    res = (unsigned)fetch_ulong(bits);
    return true;
  }
}

bool CellSlice::fetch_uint_to(unsigned bits, int& res) {
  if (bits > 32 || !have(bits)) {
    return false;
  } else {
    res = (int)fetch_ulong(bits);
    return res >= 0;
  }
}

bool CellSlice::fetch_int_to(unsigned bits, long long& res) {
  if (bits > 64 || !have(bits)) {
    return false;
  } else {
    res = fetch_long(bits);
    return true;
  }
}

bool CellSlice::fetch_int_to(unsigned bits, int& res) {
  if (bits > 32 || !have(bits)) {
    return false;
  } else {
    res = (int)fetch_long(bits);
    return true;
  }
}

bool CellSlice::fetch_uint_less(unsigned upper_bound, int& res) {
  unsigned bits = 32 - td::count_leading_zeroes32(upper_bound - 1);
  if (!upper_bound || bits > 31 || !have(bits)) {
    return false;
  } else {
    res = (int)fetch_ulong(bits);
    return (unsigned)res < upper_bound;
  }
}

bool CellSlice::fetch_uint_less(unsigned upper_bound, unsigned& res) {
  unsigned bits = 32 - td::count_leading_zeroes32(upper_bound - 1);
  if (!upper_bound || bits > 32 || !have(bits)) {
    return false;
  } else {
    res = (unsigned)fetch_ulong(bits);
    return res < upper_bound;
  }
}

bool CellSlice::fetch_uint_leq(unsigned upper_bound, int& res) {
  unsigned bits = 32 - td::count_leading_zeroes32(upper_bound);
  if (bits > 31 || !have(bits)) {
    return false;
  } else {
    res = (int)fetch_ulong(bits);
    return (unsigned)res <= upper_bound;
  }
}

bool CellSlice::fetch_uint_leq(unsigned upper_bound, unsigned& res) {
  unsigned bits = 32 - td::count_leading_zeroes32(upper_bound);
  if (bits > 32 || !have(bits)) {
    return false;
  } else {
    res = (unsigned)fetch_ulong(bits);
    return res <= upper_bound;
  }
}

int CellSlice::bselect(unsigned bits, unsigned long long mask) const {
  if (bits > 6 || !have(bits)) {
    return -1;
  } else {
    int n = (int)prefetch_ulong(bits);
    return td::count_bits64(mask & ((2ULL << n) - 1)) - 1;
  }
}

int CellSlice::bselect_ext(unsigned bits, unsigned long long mask) const {
  if (bits > 6) {
    return -1;
  }
  int n;
  if (have(bits)) {
    n = (int)prefetch_ulong(bits);
  } else {
    n = (int)prefetch_ulong(size()) << (bits - size());
  }
  return td::count_bits64(mask & ((2ULL << n) - 1)) - 1;
}

td::RefInt256 CellSlice::fetch_int256(unsigned bits, bool sgnd) {
  if (!have(bits)) {
    return {};
  } else if (bits < td::BigInt256::word_shift) {
    long long val = sgnd ? fetch_long(bits) : fetch_ulong(bits);
    return td::RefInt256{true, val};
  } else {
    td::RefInt256 res{true};
    res.unique_write().import_bits(data_bits(), bits, sgnd);
    advance(bits);
    return res;
  }
}

td::RefInt256 CellSlice::prefetch_int256(unsigned bits, bool sgnd) const {
  if (!have(bits)) {
    return {};
  } else if (bits < td::BigInt256::word_shift) {
    long long val = sgnd ? prefetch_long(bits) : prefetch_ulong(bits);
    return td::RefInt256{true, val};
  } else {
    td::RefInt256 res{true};
    res.unique_write().import_bits(data_bits(), bits, sgnd);
    return res;
  }
}

td::RefInt256 CellSlice::prefetch_int256_zeroext(unsigned bits, bool sgnd) const {
  if (bits > 256u + sgnd) {
    return td::RefInt256{false};
  } else {
    unsigned ld_bits = std::min(bits, size());
    if (bits < td::BigInt256::word_shift) {
      long long val = sgnd ? prefetch_long(ld_bits) : prefetch_ulong(ld_bits);
      val <<= bits - ld_bits;
      return td::RefInt256{true, val};
    } else {
      td::RefInt256 res{true};
      res.unique_write().import_bits(data_bits(), ld_bits, sgnd);
      res <<= bits - ld_bits;
      return res;
    }
  }
}

td::BitSlice CellSlice::fetch_bits(unsigned bits) {
  if (!have(bits)) {
    return {};
  } else {
    td::BitSlice res{cell, data(), (int)bits_st, bits};
    advance(bits);
    return res;
  }
}

td::BitSlice CellSlice::prefetch_bits(unsigned bits) const {
  if (!have(bits)) {
    return {};
  } else {
    return td::BitSlice{cell, data(), (int)bits_st, bits};
  }
}

bool CellSlice::fetch_bits_to(td::BitPtr buffer, unsigned bits) {
  if (!have(bits)) {
    return false;
  }
  fetch_bits(bits).copy_to(buffer);
  return true;
}

bool CellSlice::prefetch_bits_to(td::BitPtr buffer, unsigned bits) const {
  if (!have(bits)) {
    return false;
  }
  prefetch_bits(bits).copy_to(buffer);
  return true;
}

td::Ref<CellSlice> CellSlice::fetch_subslice(unsigned bits, unsigned refs) {
  if (!have(bits, refs)) {
    return {};
  } else {
    td::Ref<CellSlice> res{true, *this, bits, refs};
    advance(bits);
    advance_refs(refs);
    return res;
  }
}

td::Ref<CellSlice> CellSlice::prefetch_subslice(unsigned bits, unsigned refs) const {
  if (!have(bits, refs)) {
    return {};
  } else {
    return td::Ref<CellSlice>{true, *this, bits, refs};
  }
}

td::Ref<CellSlice> CellSlice::fetch_subslice_ext(unsigned size) {
  return fetch_subslice(size & 0xffff, size >> 16);
}

td::Ref<CellSlice> CellSlice::prefetch_subslice_ext(unsigned size) const {
  return prefetch_subslice(size & 0xffff, size >> 16);
}

td::Ref<td::BitString> CellSlice::prefetch_bitstring(unsigned bits) const {
  if (!have(bits)) {
    return {};
  } else {
    return td::Ref<td::BitString>{true, prefetch_bits(bits)};
  }
}

td::Ref<td::BitString> CellSlice::fetch_bitstring(unsigned bits) {
  if (!have(bits)) {
    return {};
  } else {
    return td::Ref<td::BitString>{true, fetch_bits(bits)};
  }
}

bool CellSlice::prefetch_bytes(unsigned char* buffer, unsigned bytes) const {
  if (!have(bytes * 8)) {
    return false;
  } else {
    td::BitSliceWrite{buffer, bytes* 8} = prefetch_bits(bytes * 8);
    return true;
  }
}

bool CellSlice::fetch_bytes(unsigned char* buffer, unsigned bytes) {
  if (prefetch_bytes(buffer, bytes)) {
    advance(bytes * 8);
    return true;
  } else {
    return false;
  }
}

Ref<Cell> CellSlice::prefetch_ref(unsigned offset) const {
  if (offset < size_refs()) {
    auto ref_id = refs_st + offset;
    auto res = cell->get_ref(ref_id)->virtualize(child_virt());
    if (!tree_node.empty()) {
      res = UsageCell::create(std::move(res), tree_node.create_child(ref_id));
    }
    return res;
  } else {
    return Ref<Cell>{};
  }
}

Ref<Cell> CellSlice::fetch_ref() {
  if (have_refs()) {
    auto ref_id = refs_st++;
    auto res = cell->get_ref(ref_id)->virtualize(child_virt());
    if (!tree_node.empty()) {
      res = UsageCell::create(std::move(res), tree_node.create_child(ref_id));
    }
    return res;
  } else {
    return Ref<Cell>{};
  }
}

bool CellSlice::prefetch_maybe_ref(Ref<vm::Cell>& res) const {
  auto z = prefetch_ulong(1);
  if (!z) {
    res.clear();
    return true;
  } else {
    return z == 1 && prefetch_ref_to(res);
  }
}

bool CellSlice::fetch_maybe_ref(Ref<vm::Cell>& res) {
  auto z = prefetch_ulong(1);
  if (!z) {
    res.clear();
    return advance(1);
  } else {
    return z == 1 && prefetch_ref_to(res) && advance_ext(1, 1);
  }
}

bool CellSlice::begins_with(unsigned bits, unsigned long long value) const {
  return have(bits) && !((prefetch_ulong(bits) ^ value) & ((1ULL << bits) - 1));
}

bool CellSlice::begins_with(unsigned long long value) const {
  return begins_with(63 - td::count_leading_zeroes_non_zero64(value), value);
}

bool CellSlice::begins_with_skip(unsigned long long value) {
  return begins_with_skip(63 - td::count_leading_zeroes_non_zero64(value), value);
}

bool CellSlice::only_first(unsigned bits, unsigned refs) {
  if (!have(bits, refs)) {
    return false;
  }
  bits_en = bits_st + bits;
  refs_en = refs_st + refs;
  return true;
}

bool CellSlice::only_ext(unsigned size) {
  return only_first(size & 0xffff, size >> 16);
}

bool CellSlice::skip_first(unsigned bits, unsigned refs) {
  if (!have(bits, refs)) {
    return false;
  }
  refs_st += refs;
  return advance(bits);
}

bool CellSlice::skip_ext(unsigned size) {
  return skip_first(size & 0xffff, size >> 16);
}

bool CellSlice::only_last(unsigned bits, unsigned refs) {
  if (!have(bits, refs)) {
    return false;
  }
  refs_st = refs_en - refs;
  return advance(size() - bits);
}

bool CellSlice::skip_last(unsigned bits, unsigned refs) {
  if (!have(bits, refs)) {
    return false;
  }
  bits_en -= bits;
  refs_en -= refs;
  return true;
}

bool CellSlice::cut_tail(const CellSlice& tail_cs) {
  return skip_last(tail_cs.size(), tail_cs.size_refs());
}

int CellSlice::lex_cmp(const CellSlice& cs2) const {
  return td::bitstring::bits_lexcmp(data(), bits_st, size(), cs2.data(), cs2.bits_st, cs2.size());
}

bool CellSlice::contents_equal(const CellSlice& cs2) const {
  if (size() != cs2.size() || size_refs() != cs2.size_refs()) {
    return false;
  }
  if (td::bitstring::bits_memcmp(data_bits(), cs2.data_bits(), size())) {
    return false;
  }
  for (unsigned i = 0; i < size_refs(); i++) {
    if (prefetch_ref(i)->get_hash() != cs2.prefetch_ref(i)->get_hash()) {
      return false;
    }
  }
  return true;
}

bool CellSlice::is_prefix_of(const CellSlice& cs2) const {
  return size() <= cs2.size() && !td::bitstring::bits_memcmp(data_bits(), cs2.data_bits(), size(), 0);
}

bool CellSlice::is_prefix_of(td::ConstBitPtr bs, unsigned len) const {
  return size() <= len && !td::bitstring::bits_memcmp(data_bits(), bs, size(), 0);
}

/*
bool CellSlice::is_prefix_of(const td::BitSlice& bs, unsigned offs, unsigned max_len) const {
  max_len = std::min(max_len, size());
  return max_len + offs <= bs.size() &&
         !td::bitstring::bits_memcmp(data_bits(), bs.bits() + offs, max_len, 0);
}
*/

bool CellSlice::is_suffix_of(const CellSlice& cs2) const {
  return size() <= cs2.size() &&
         !td::bitstring::bits_memcmp(data_bits(), cs2.data_bits() + (cs2.size() - size()), size(), 0);
}

bool CellSlice::has_prefix(const CellSlice& cs2) const {
  return size() >= cs2.size() && !td::bitstring::bits_memcmp(data_bits(), cs2.data_bits(), cs2.size(), 0);
}

bool CellSlice::has_prefix(td::ConstBitPtr bs, unsigned len) const {
  return size() >= len && !td::bitstring::bits_memcmp(data_bits(), bs, len, 0);
}

bool CellSlice::has_suffix(const CellSlice& cs2) const {
  return size() >= cs2.size() &&
         !td::bitstring::bits_memcmp(data_bits() + (size() - cs2.size()), cs2.data_bits(), cs2.size(), 0);
}

bool CellSlice::is_proper_prefix_of(const CellSlice& cs2) const {
  return size() < cs2.size() && !td::bitstring::bits_memcmp(data_bits(), cs2.data_bits(), size(), 0);
}

bool CellSlice::is_proper_suffix_of(const CellSlice& cs2) const {
  return size() < cs2.size() &&
         !td::bitstring::bits_memcmp(data_bits(), cs2.data_bits() + (cs2.size() - size()), size(), 0);
}

int CellSlice::common_prefix_len(const CellSlice& cs2) const {
  std::size_t same_upto = 0;
  td::bitstring::bits_memcmp(data_bits(), cs2.data_bits(), std::min(size(), cs2.size()), &same_upto);
  return (int)same_upto;
}

/*
int CellSlice::common_prefix_len(const td::BitSlice& bs, unsigned offs, unsigned max_len) const {
  return common_prefix_len(bs.bits() + offs, std::min(bs.size() - offs, max_len));
}
*/

int CellSlice::common_prefix_len(td::ConstBitPtr bs, unsigned len) const {
  std::size_t same_upto = 0;
  td::bitstring::bits_memcmp(data_bits(), bs, std::min(size(), len), &same_upto);
  return (int)same_upto;
}

int CellSlice::count_leading(bool bit) const {
  return (int)td::bitstring::bits_memscan(data_bits(), size(), bit);
}

int CellSlice::count_trailing(bool bit) const {
  return (int)td::bitstring::bits_memscan_rev(data_bits(), size(), bit);
}

int CellSlice::remove_trailing() {
  if (bits_st == bits_en) {
    return 0;
  }
  unsigned bits = bits_en - bits_st;
  unsigned trailing = (unsigned)td::bitstring::bits_memscan_rev(data(), bits_st, bits, 0);
  assert(trailing <= bits);
  if (trailing == bits) {
    bits_en -= trailing;
  } else {
    bits_en -= ++trailing;
  }
  return trailing;
}

bool cell_builder_add_slice_bool(CellBuilder& cb, const CellSlice& cs) {
  if (!cb.can_extend_by(cs.size(), cs.size_refs())) {
    return false;
  }
  for (unsigned cnt = 0; cnt < cs.size_refs(); cnt++) {
    cb.store_ref(cs.prefetch_ref(cnt));
  }
  cb.store_bits(cs.as_bitslice());
  return true;
}

CellBuilder& cell_builder_add_slice(CellBuilder& cb, const CellSlice& cs) {
  return cb.ensure_pass(cell_builder_add_slice_bool(cb, cs));
}

void CellSlice::dump(std::ostream& os, int level, bool endl) const {
  os << "Cell";
  if (level > 0) {
    os << "{" << cell->to_hex() << "}";
  }
  os << " bits: " << bits_st << ".." << bits_en;
  os << "; refs: " << refs_st << ".." << refs_en;
  if (level > 2) {
    char tmp[64];
    std::sprintf(tmp, "; ptr=data+%ld; z=%016llx",
                 static_cast<long>(ptr && cell.not_null() ? ptr - cell->get_data() : -1), static_cast<long long>(z));
    os << tmp << " (have " << size() << " bits; " << zd << " preloaded)";
  }
  if (endl) {
    os << std::endl;
  }
}

void CellSlice::dump_hex(std::ostream& os, int mode, bool endl) const {
  os << "x" << as_bitslice().to_hex();
  if (have_refs() && (mode & 1)) {
    os << "," << size_refs();
  }
  if (endl) {
    os << std::endl;
  }
}

void CellSlice::print_rec(std::ostream& os, int indent) const {
  for (int i = 0; i < indent; i++) {
    os << ' ';
  }
  if (cell.is_null()) {
    os << "NULL" << std::endl;
    return;
  }
  if (is_special()) {
    os << "SPECIAL ";
  }
  os << "x{" << as_bitslice().to_hex() << '}' << std::endl;
  for (unsigned i = 0; i < size_refs(); i++) {
    CellSlice cs{NoVm(), prefetch_ref(i)};
    cs.print_rec(os, indent + 1);
  }
}

td::StringBuilder& operator<<(td::StringBuilder& sb, const CellSlice& cs) {
  std::ostringstream os;
  cs.dump_hex(os, 1, false);
  return sb << os.str();
}

std::ostream& operator<<(std::ostream& os, CellSlice cs) {
  cs.dump_hex(os, 1, false);
  return os;
}

std::ostream& operator<<(std::ostream& os, Ref<CellSlice> cs_ref) {
  if (cs_ref.is_null()) {
    os << "(null)";
  } else {
    cs_ref->dump_hex(os, 1, false);
  }
  return os;
}

// BEGIN (SLICE LOAD FUNCTIONS)
// (if these functions become more complicated, move them into a separate file)

// If can_be_special is not null, then it is allowed to load special cell
// Flag whether loaded cell is actually special will be stored into can_be_special
VirtualCell::LoadedCell load_cell_slice_impl(const Ref<Cell>& cell, bool* can_be_special) {
  auto* vm_state_interface = VmStateInterface::get();
  if (vm_state_interface) {
    vm_state_interface->register_cell_load();
  }
  auto r_loaded_cell = cell->load_cell();
  if (r_loaded_cell.is_error()) {
    throw VmError{Excno::cell_und, "failed to load cell"};
  }
  auto loaded_cell = r_loaded_cell.move_as_ok();
  if (loaded_cell.data_cell->special_type() == DataCell::SpecialType::PrunnedBranch) {
    auto virtualization = loaded_cell.virt.get_virtualization();
    if (virtualization != 0) {
      throw VmVirtError{virtualization};
    }
  }
  if (can_be_special) {
    *can_be_special = loaded_cell.data_cell->is_special();
  } else if (loaded_cell.data_cell->is_special()) {
    if (loaded_cell.data_cell->special_type() == DataCell::SpecialType::Library) {
      if (vm_state_interface) {
        CellSlice cs(std::move(loaded_cell));
        DCHECK(cs.size() == Cell::hash_bits + 8);
        auto library_cell = vm_state_interface->load_library(cs.data_bits() + 8);
        if (library_cell.not_null()) {
          //TODO: fix infinity loop
          return load_cell_slice_impl(library_cell, nullptr);
        }
        throw VmError{Excno::cell_und, "failed to load library cell"};
      }
      throw VmError{Excno::cell_und, "failed to load library cell (no vm_state_interface available)"};
    } else if (loaded_cell.data_cell->special_type() == DataCell::SpecialType::PrunnedBranch) {
      CHECK(loaded_cell.virt.get_virtualization() == 0);
      throw VmError{Excno::cell_und, "trying to load prunned cell"};
    }
    throw VmError{Excno::cell_und, "unexpected special cell"};
  }
  return loaded_cell;
}

CellSlice load_cell_slice(const Ref<Cell>& cell) {
  return CellSlice{load_cell_slice_impl(cell, nullptr)};
}

CellSlice load_cell_slice_special(const Ref<Cell>& cell, bool& special) {
  return CellSlice{load_cell_slice_impl(cell, &special)};
}

Ref<CellSlice> load_cell_slice_ref(const Ref<Cell>& cell) {
  return Ref<CellSlice>{true, CellSlice(load_cell_slice_impl(cell, nullptr))};
}

Ref<CellSlice> load_cell_slice_ref_special(const Ref<Cell>& cell, bool& special) {
  return Ref<CellSlice>{true, CellSlice(load_cell_slice_impl(cell, &special))};
}

void print_load_cell(std::ostream& os, Ref<Cell> cell, int indent) {
  auto cs = load_cell_slice(cell);
  cs.print_rec(os, indent);
}

bool CellSlice::load(Ref<Cell> cell) {
  return load(load_cell_slice_impl(std::move(cell), nullptr));
}

bool CellSlice::load_ord(Ref<Cell> cell) {
  return load(load_cell_slice_impl(std::move(cell), nullptr));
}

// END (SLICE LOAD FUNCTIONS)

}  // namespace vm
