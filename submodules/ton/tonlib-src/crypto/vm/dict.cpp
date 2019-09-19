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
#include "vm/dict.h"
#include "vm/cells.h"
#include "vm/cellslice.h"
#include "vm/stack.hpp"
#include "common/bitstring.h"

#include "td/utils/bits.h"

namespace vm {

/*
 * 
 *  DictionaryBase : basic (common) dictionary manipulation
 * 
 */

DictionaryBase::DictionaryBase(Ref<CellSlice> _root, int _n, bool validate)
    : root(std::move(_root)), root_cell(), key_bits(_n), flags(f_root_cached) {
  if (validate) {
    force_validate();
  }
}

DictionaryBase::DictionaryBase(const CellSlice& root_cs, int _n, bool validate)
    : root(), root_cell(), key_bits(_n), flags(0) {
  int f = (int)root_cs.prefetch_ulong(1);
  if (f < 0) {
    flags |= f_invalid;
  } else if (f > 0) {
    if (root_cs.size_refs()) {
      root_cell = root_cs.prefetch_ref();
    } else {
      flags |= f_invalid;
    }
  }
  if (validate) {
    force_validate();
  }
}

DictionaryBase::DictionaryBase(DictAdvance, CellSlice& root_cs, int _n, bool validate)
    : root(), root_cell(), key_bits(_n), flags(0) {
  int f = (int)root_cs.prefetch_ulong(1);
  if (!f) {
    root_cs.advance(1);
  } else if (f > 0 && root_cs.size_refs()) {
    root_cs.advance(1);
    root_cell = root_cs.fetch_ref();
  } else {
    flags |= f_invalid;
  }
  if (validate) {
    force_validate();
  }
}

DictionaryBase::DictionaryBase(Ref<Cell> cell, int _n, bool validate)
    : root(), root_cell(std::move(cell)), key_bits(_n), flags(0) {
  if (validate) {
    force_validate();
  }
}

DictionaryBase::DictionaryBase(int _n, bool validate) : root(), root_cell(), key_bits(_n), flags(0) {
  if (validate) {
    force_validate();
  }
}

DictionaryBase::DictionaryBase(DictNonEmpty, Ref<CellSlice> _root, int _n, bool validate)
    : root(), root_cell(), key_bits(_n), flags(0) {
  if (_root.is_null() || !init_root_for_nonempty(*_root)) {  // empty ?
    invalidate();                                            // invalidate
  }
  if (validate) {
    force_validate();
  }
}

DictionaryBase::DictionaryBase(DictNonEmpty, const CellSlice& _root, int _n, bool validate)
    : root(), root_cell(), key_bits(_n), flags(0) {
  if (!init_root_for_nonempty(_root)) {
    invalidate();
  }
  if (validate) {
    force_validate();
  }
}

bool DictionaryBase::init_root_for_nonempty(const CellSlice& cs) {
  vm::CellBuilder cb;
  return cb.append_cellslice_bool(cs) && cb.finalize_to(root_cell);
}

Ref<Cell> DictionaryBase::construct_root_from(const CellSlice& root_node_cs) {
  vm::CellBuilder cb;
  if (cb.append_cellslice_bool(root_node_cs)) {
    return cb.finalize();
  } else {
    return {};
  }
}

void DictionaryBase::force_validate() {
  if (!is_valid() && !validate()) {
    throw VmError{Excno::dict_err, "invalid dictionary"};
  }
}

bool DictionaryBase::validate() {
  if (is_valid()) {
    return true;
  }
  if (flags & f_invalid) {
    return false;
  }
  if (key_bits < 0 || key_bits > max_key_bits) {
    return invalidate();
  }
  if (flags & f_root_cached) {
    if (root.is_null() || root->size() != 1) {
      return invalidate();
    }
    bool non_empty = root->prefetch_ulong(1);
    if (root->size_refs() != (non_empty ? 1u : 0u)) {
      return invalidate();
    }
    if (root_cell.not_null()) {
      return invalidate();
    }
    if (non_empty) {
      root_cell = root->prefetch_ref();
    }
  } else if (root.not_null()) {
    return invalidate();
  }
  flags |= f_valid;
  return true;
}

Ref<CellSlice> DictionaryBase::get_root() const {
  if (!(flags & f_root_cached) && !compute_root()) {
    return {};
  }
  return root;
}

Ref<CellSlice> DictionaryBase::extract_root() && {
  if (!(flags & f_root_cached) && !compute_root()) {
    return {};
  }
  flags = f_invalid;
  return std::move(root);
}

bool DictionaryBase::append_dict_to_bool(CellBuilder& cb) && {
  if (!is_valid()) {
    return false;
  }
  flags = f_invalid;
  return cb.store_maybe_ref(std::move(root_cell));
}

bool DictionaryBase::append_dict_to_bool(CellBuilder& cb) const& {
  return is_valid() && cb.store_maybe_ref(root_cell);
}

bool DictionaryBase::compute_root() const {
  if (!is_valid()) {
    return false;
  }
  if (root_cell.is_null()) {
    root = get_empty_dictionary();
    flags |= f_root_cached;
    return true;
  }
  CellBuilder cb;
  cb.store_long(1, 1);
  cb.store_ref(root_cell);
  root = Ref<CellSlice>{true, cb.finalize()};
  flags |= f_root_cached;
  return true;
}

Ref<CellSlice> DictionaryBase::get_empty_dictionary() {
  static Ref<CellSlice> empty_dict{new_empty_dictionary()};
  return empty_dict;
}

Ref<CellSlice> DictionaryBase::new_empty_dictionary() {
  CellBuilder cb;  // Builder
  cb.store_long(0, 1);
  return Ref<CellSlice>{true, cb.finalize()};
}

Ref<Cell> DictionaryFixed::finish_create_leaf(CellBuilder& cb, const CellSlice& value) const {
  if (!cb.append_cellslice_bool(value)) {
    throw VmError{Excno::dict_err, "cannot store new value into a dictionary leaf cell"};
  }
  return cb.finalize();
}

Ref<Cell> DictionaryFixed::finish_create_fork(CellBuilder& cb, Ref<Cell> c1, Ref<Cell> c2, int n) const {
  assert(n > 0);
  if (!(cb.store_ref_bool(std::move(c1)) && cb.store_ref_bool(std::move(c2)))) {
    throw VmError{Excno::dict_err, "cannot store branch references into a dictionary fork cell"};
  }
  return cb.finalize();
}

bool DictionaryFixed::check_fork_raw(Ref<CellSlice> cs_ref, int n) const {
  if (cs_ref.is_null()) {
    return false;
  }
  Ref<Cell> c1, c2;
  CellSlice& cs = cs_ref.write();
  return cs.fetch_ref_to(c1) && cs.fetch_ref_to(c2) && check_fork(cs, std::move(c1), std::move(c2), n);
}

/*
 * 
 *  Label parser (HmLabel n ~l) for all dictionary types
 *
 */

namespace dict {

LabelParser::LabelParser(Ref<CellSlice> cs, int max_label_len, int auto_validate) : remainder(), l_offs(0), l_same(0) {
  if (!parse_label(cs.write(), max_label_len)) {
    l_offs = 0;
  } else {
    s_bits = (l_same ? 0 : l_bits);
    remainder = std::move(cs);
  }
  if (auto_validate) {
    if (auto_validate > 2) {
      validate_ext(max_label_len);
    } else if (auto_validate == 2) {
      validate_simple(max_label_len);
    } else {
      validate();
    }
  }
}

LabelParser::LabelParser(Ref<Cell> cell, int max_label_len, int auto_validate) : remainder(), l_offs(0), l_same(0) {
  Ref<CellSlice> cs = load_cell_slice_ref(std::move(cell));
  if (!parse_label(cs.unique_write(), max_label_len)) {
    l_offs = 0;
  } else {
    s_bits = (l_same ? 0 : l_bits);
    remainder = std::move(cs);
  }
  if (auto_validate) {
    if (auto_validate > 2) {
      validate_ext(max_label_len);
    } else if (auto_validate == 2) {
      validate_simple(max_label_len);
    } else {
      validate();
    }
  }
}

bool LabelParser::parse_label(CellSlice& cs, int max_label_len) {
  int ltype = (int)cs.prefetch_ulong(2);
  // std::cerr << "parse_label of type " << ltype << " and maximal length " << max_label_len << " in ";
  // cs.dump_hex(std::cerr, 0, true);
  switch (ltype) {
    case 0: {
      l_bits = 0;
      l_offs = 2;
      cs.advance(2);
      return true;
    }
    case 1: {
      cs.advance(1);
      l_bits = cs.count_leading(1);
      // std::cerr << "unary-encoded l_bits = " << l_bits << ", have " << cs.size() << std::endl;
      if (l_bits > max_label_len || !cs.have(2 * l_bits + 1)) {
        return false;
      }
      l_offs = l_bits + 2;
      cs.advance(l_bits + 1);
      return true;
    }
    case 2: {
      int len_bits = 32 - td::count_leading_zeroes32(max_label_len);
      cs.advance(2);
      l_bits = (int)cs.fetch_ulong(len_bits);
      if (l_bits < 0 || l_bits > max_label_len) {
        return false;
      }
      l_offs = len_bits + 2;
      return cs.have(l_bits);
    }
    case 3: {
      int len_bits = 32 - td::count_leading_zeroes32(max_label_len);
      // std::cerr << "len_bits = " << len_bits << ", have " << cs.size() << std::endl;
      if (!cs.have(3 + len_bits)) {
        return false;
      }
      l_same = (int)cs.fetch_ulong(3);
      l_bits = (int)cs.fetch_ulong(len_bits);
      // std::cerr << "l_bits = " << l_bits << ", l_same = " << l_same << std::endl;
      if (l_bits < 0 || l_bits > max_label_len) {
        return false;
      }
      l_offs = -1;
      return true;
    }
    default:
      return false;
  }
}

void LabelParser::validate() const {
  if (!is_valid()) {
    throw VmError{Excno::cell_und, "error while parsing a dictionary node label"};
  }
}

void LabelParser::validate_ext(int n) const {
  validate();
  if (l_bits > n) {
    throw VmError{Excno::dict_err, "invalid dictionary node"};
  } else if (l_bits < n && (remainder->size() != s_bits || remainder->size_refs() != 2)) {
    throw VmError{Excno::dict_err, "invalid dictionary fork node"};
  }
}

void LabelParser::validate_simple(int n) const {
  validate();
  if (l_bits > n) {
    throw VmError{Excno::dict_err, "invalid dictionary node"};
  } else if (l_bits < n && (remainder->size() < s_bits || remainder->size_refs() < 2)) {
    throw VmError{Excno::dict_err, "invalid dictionary fork node"};
  }
}

bool LabelParser::is_prefix_of(td::ConstBitPtr key, int len) const {
  if (l_bits > len) {
    return false;
  } else if (!l_same) {
    //std::cerr << "key is " << key.to_hex(len) << "; len = " << len << "; label_bits = " << l_bits << "; remainder = ";
    //remainder->dump_hex(std::cerr, 0, true);
    return remainder->has_prefix(key, l_bits);
  } else {
    return td::bitstring::bits_memscan(key, l_bits, l_same & 1) == (unsigned)l_bits;
  }
}

bool LabelParser::has_prefix(td::ConstBitPtr key, int len) const {
  return len >= 0 && len <= l_bits && common_prefix_len(key, len) == len;
}

int LabelParser::common_prefix_len(td::ConstBitPtr key, int len) const {
  if (!l_same) {
    //std::cerr << "key is " << key.to_hex(len) << "; len = " << len << "; label_bits = " << l_bits << "; remainder = ";
    //remainder->dump_hex(std::cerr, 0, true);
    return remainder->common_prefix_len(key, std::min(l_bits, len));
  } else {
    return (int)td::bitstring::bits_memscan(key, std::min(l_bits, len), l_same & 1);
  }
}

int LabelParser::extract_label_to(td::BitPtr to) {
  if (!l_same) {
    to.copy_from(remainder->data_bits(), l_bits);
    remainder.write().advance(l_bits);
  } else {
    to.fill(l_same & 1, l_bits);
  }
  return l_bits;
}

int LabelParser::copy_label_prefix_to(td::BitPtr to, int max_len) const {
  if (max_len <= 0) {
    return max_len;
  }
  int sz = std::min(max_len, l_bits);
  if (!l_same) {
    to.copy_from(remainder->data_bits(), sz);
  } else {
    to.fill(l_same & 1, sz);
  }
  return sz;
}

}  // namespace dict

/*
 * 
 *   Usual Dictionary
 * 
 */

using dict::LabelParser;

BitSlice DictionaryFixed::integer_key(td::RefInt256 x, unsigned n, bool sgnd, unsigned char buffer[128], bool quiet) {
  if (x.not_null() && x->fits_bits(n, sgnd)) {
    if (buffer) {
      if (x->export_bits(buffer, 0, n, sgnd)) {
        return BitSlice{{}, buffer, 0, n};
      }
    } else {
      Ref<td::BitString> bs{true, n};
      if (x->export_bits(bs.unique_write().reserve_bitslice(n), sgnd)) {
        return static_cast<BitSlice>(*bs);
      }
    }
  }
  if (!quiet) {
    throw VmError{Excno::range_chk, "dictionary index out of bounds"};
  }
  return {};
}

bool DictionaryFixed::integer_key_simple(td::RefInt256 x, unsigned n, bool sgnd, td::BitPtr buffer, bool quiet) {
  if (x.not_null() && x->fits_bits(n, sgnd) && x->export_bits(buffer, n, sgnd)) {
    return true;
  }
  if (!quiet) {
    throw VmError{Excno::range_chk, "dictionary index out of bounds"};
  }
  return false;
}

Ref<Cell> Dictionary::extract_value_ref(Ref<CellSlice> cs) {
  if (cs.is_null()) {
    return {};
  } else if (!cs->size() && cs->size_refs() == 1) {
    return cs->prefetch_ref();
  } else {
    throw VmError{Excno::dict_err, "dictionary value does not consist of exactly one reference"};
  }
}

Ref<CellSlice> DictionaryFixed::lookup(td::ConstBitPtr key, int key_len) {
  force_validate();
  if (key_len != get_key_bits() || is_empty()) {
    return {};
  }
  //std::cerr << "dictionary lookup for key = " << key.to_hex(key_len) << std::endl;
  Ref<Cell> cell = get_root_cell();
  int n = key_len;
  while (true) {
    LabelParser label{std::move(cell), n, label_mode()};
    if (!label.is_prefix_of(key, n)) {
      //std::cerr << "(not a prefix)\n";
      return {};
    }
    n -= label.l_bits;
    if (n <= 0) {
      assert(!n);
      label.skip_label();
      return std::move(label.remainder);
    }
    key += label.l_bits;
    bool sw = *key++;
    //std::cerr << "key bit at position " << key_bits - n << " equals " << sw << std::endl;
    --n;
    cell = label.remainder->prefetch_ref(sw);
  }
}

Ref<Cell> Dictionary::lookup_ref(td::ConstBitPtr key, int key_len) {
  return extract_value_ref(lookup(key, key_len));
}

bool DictionaryFixed::has_common_prefix(td::ConstBitPtr prefix, int prefix_len) {
  force_validate();
  if (is_empty() || prefix_len <= 0) {
    return true;
  }
  if (prefix_len > get_key_bits()) {
    return false;
  }
  LabelParser label{get_root_cell(), get_key_bits(), label_mode()};
  return label.has_prefix(prefix, prefix_len);
}

int DictionaryFixed::get_common_prefix(td::BitPtr buffer, unsigned buffer_len) {
  force_validate();
  if (is_empty()) {
    return 0;
  }
  LabelParser label{get_root_cell(), get_key_bits(), label_mode()};
  return label.copy_label_prefix_to(buffer, (int)buffer_len);
}

bool DictionaryFixed::key_exists(td::ConstBitPtr key, int key_len) {
  return lookup(key, key_len).not_null();
}

bool DictionaryFixed::int_key_exists(long long key) {
  force_validate();
  int l = get_key_bits();
  if (is_empty() || l > 64) {
    return false;
  }
  if (l < 64) {
    long long m = (1LL << (l - 1));
    if (key < -m || key >= m) {
      return false;
    }
  }
  td::BitArray<64> a;
  a.bits().store_int(key, l);
  return key_exists(a.cbits(), l);
}

bool DictionaryFixed::uint_key_exists(unsigned long long key) {
  force_validate();
  int l = get_key_bits();
  if (is_empty() || l > 64) {
    return false;
  }
  if (l < 64 && key >= (1ULL << l)) {
    return false;
  }
  td::BitArray<64> a;
  a.bits().store_uint(key, l);
  return key_exists(a.cbits(), l);
}

namespace {

void append_dict_label_same(CellBuilder& cb, bool same, int len, int max_len) {
  int k = 32 - td::count_leading_zeroes32(max_len);
  assert(len >= 0 && len <= max_len && max_len <= 1023);
  // options: mode '0', requires 2n+2 bits (always for n=0)
  // mode '10', requires 2+k+n bits (only for n<=1)
  // mode '11', requires 3+k bits (for n>=2, k<2n-1)
  if (len > 1 && k < 2 * len - 1) {
    // mode '11'
    cb.store_long(6 + same, 3).store_long(len, k);
  } else if (k < len) {
    // mode '10'
    cb.store_long(2, 2).store_long(len, k).store_long(-static_cast<int>(same), len);
  } else {
    // mode '0'
    cb.store_long(0, 1).store_long(-2, len + 1).store_long(-static_cast<int>(same), len);
  }
}

void append_dict_label(CellBuilder& cb, td::ConstBitPtr label, int len, int max_len) {
  assert(len <= max_len && max_len <= 1023);
  if (len > 0 && (int)td::bitstring::bits_memscan(label, len, *label) == len) {
    return append_dict_label_same(cb, *label, len, max_len);
  }
  int k = 32 - td::count_leading_zeroes32(max_len);
  // two options: mode '0', requires 2n+2 bits
  // mode '10', requires 2+k+n bits
  if (k < len) {
    cb.store_long(2, 2).store_long(len, k);
  } else {
    cb.store_long(0, 1).store_long(-2, len + 1);
  }
  if ((int)cb.remaining_bits() < len) {
    throw VmError{Excno::cell_ov, "cannot store a label into a dictionary cell"};
  }
  cb.store_bits(label, len);
}

std::pair<Ref<Cell>, bool> dict_set(Ref<Cell> dict, td::ConstBitPtr key, int n,
                                    const Dictionary::store_value_func_t& store_val, Dictionary::SetMode mode) {
  //std::cerr << "dictionary modification for " << n << "-bit key = " << key.to_hex(n) << std::endl;
  if (dict.is_null()) {
    // the dictionary is very empty
    if (mode == Dictionary::SetMode::Replace) {
      return std::make_pair<Ref<Cell>, bool>({}, false);
    }
    // create an one-element dictionary
    CellBuilder cb;
    append_dict_label(cb, key, n, n);
    if (!store_val(cb)) {
      throw VmError{Excno::cell_ov, "cannot store new value into a dictionary cell"};
    }
    return std::make_pair(cb.finalize(), true);
  }
  LabelParser label{std::move(dict), n};
  label.validate();
  int pfx_len = label.common_prefix_len(key, n);
  assert(pfx_len >= 0 && pfx_len <= label.l_bits && label.l_bits <= n);
  if (pfx_len < label.l_bits) {
    // have to insert a new node (fork) inside the current edge
    if (mode == Dictionary::SetMode::Replace) {
      // key not found, return unchanged dictionary
      return std::make_pair(Ref<Cell>{}, false);
    }
    // first, create the edge + new leaf cell
    int m = n - pfx_len - 1;
    CellBuilder cb;
    append_dict_label(cb, key + (pfx_len + 1), m, m);
    if (!store_val(cb)) {
      throw VmError{Excno::cell_ov, "cannot store new value into a dictionary cell"};
    }
    Ref<Cell> c1 = cb.finalize();  // new leaf cell corresponding to `key`
    //cb.reset();
    // create the lower portion of the old edge
    int t = label.l_bits - pfx_len - 1;
    auto cs = std::move(label.remainder);
    if (label.l_same) {
      append_dict_label_same(cb, label.l_same & 1, t, m);
    } else {
      cs.write().advance(pfx_len + 1);
      append_dict_label(cb, cs->data_bits(), t, m);
      cs.unique_write().advance(t);
    }
    // now cs is the old payload of the edge, either a value or two subdictionary references
    if (!cell_builder_add_slice_bool(cb, *cs)) {
      throw VmError{Excno::cell_ov, "cannot change label of an old dictionary cell (?)"};
    }
    Ref<Cell> c2 = cb.finalize();  // the other child of the new fork
    // cb.reset();
    append_dict_label(cb, key, pfx_len, n);
    bool sw_bit = key[pfx_len];
    if (sw_bit) {
      c1.swap(c2);
    }
    cb.store_ref(std::move(c1)).store_ref(std::move(c2));
    return std::make_pair(cb.finalize(), true);
  }
  if (label.l_bits == n) {
    // the edge leads to a leaf node
    // this leaf node already contains a value for the key wanted
    if (mode == Dictionary::SetMode::Add) {
      // return unchanged dictionary
      return std::make_pair(Ref<Cell>{}, false);
    }
    // replace the value of the only element of the dictionary
    CellBuilder cb;
    append_dict_label(cb, key, n, n);
    if (!store_val(cb)) {
      throw VmError{Excno::cell_ov, "cannot store new value into a dictionary cell"};
    }
    return std::make_pair(cb.finalize(), true);
  }
  // main case: the edge leads to a fork, have to insert new value either in the right or in the left subtree
  auto c1 = label.remainder->prefetch_ref(0);
  auto c2 = label.remainder->prefetch_ref(1);
  label.remainder.clear();
  if (key[label.l_bits]) {
    // insert key into the right child (c2)
    auto res = dict_set(std::move(c2), key + (label.l_bits + 1), n - label.l_bits - 1, store_val, mode);
    if (!res.second) {
      // return unchanged dictionary
      return std::make_pair(Ref<Cell>{}, false);
    }
    c2 = std::move(res.first);
  } else {
    // insert key into the left child (c1)
    auto res = dict_set(std::move(c1), key + (label.l_bits + 1), n - label.l_bits - 1, store_val, mode);
    if (!res.second) {
      // return unchanged dictionary
      return std::make_pair(Ref<Cell>{}, false);
    }
    c1 = std::move(res.first);
  }
  // create a new label with the same content
  CellBuilder cb;
  append_dict_label(cb, key, label.l_bits, n);
  cb.store_ref(std::move(c1)).store_ref(std::move(c2));
  return std::make_pair(cb.finalize(), true);
}

std::tuple<Ref<CellSlice>, Ref<Cell>, bool> dict_lookup_set(Ref<Cell> dict, td::ConstBitPtr key, int n,
                                                            const Dictionary::store_value_func_t& store_val,
                                                            Dictionary::SetMode mode) {
  //std::cerr << "dictionary lookup/modification for " << n << "-bit key = " << key.to_hex(n) << std::endl;
  if (dict.is_null()) {
    // the dictionary is very empty
    if (mode == Dictionary::SetMode::Replace) {
      return std::make_tuple<Ref<CellSlice>, Ref<Cell>, bool>({}, {}, false);
    }
    // create an one-element dictionary
    CellBuilder cb;
    append_dict_label(cb, key, n, n);
    if (!store_val(cb)) {
      throw VmError{Excno::cell_ov, "cannot store new value into a dictionary cell"};
    }
    return std::make_tuple<Ref<CellSlice>, Ref<Cell>, bool>({}, cb.finalize(), true);
  }
  LabelParser label{std::move(dict), n};
  int pfx_len = label.common_prefix_len(key, n);
  assert(pfx_len >= 0 && pfx_len <= label.l_bits && label.l_bits <= n);
  if (pfx_len < label.l_bits) {
    // have to insert a new node (fork) inside the current edge
    if (mode == Dictionary::SetMode::Replace) {
      // key not found, return unchanged dictionary
      return std::make_tuple<Ref<CellSlice>, Ref<Cell>, bool>({}, {}, false);
    }
    // first, create the edge + new leaf cell
    int m = n - pfx_len - 1;
    CellBuilder cb;
    append_dict_label(cb, key + (pfx_len + 1), m, m);
    if (!store_val(cb)) {
      throw VmError{Excno::cell_ov, "cannot store new value into a dictionary cell"};
    }
    Ref<Cell> c1 = cb.finalize();  // new leaf cell corresponding to `key`
    //cb.reset();
    // create the lower portion of the old edge
    int t = label.l_bits - pfx_len - 1;
    auto cs = std::move(label.remainder);
    if (label.l_same) {
      append_dict_label_same(cb, label.l_same & 1, t, m);
    } else {
      cs.write().advance(pfx_len + 1);
      append_dict_label(cb, cs->data_bits(), t, m);
      cs.unique_write().fetch_bits(t);
    }
    // now cs is the old payload of the edge, either a value or two subdictionary references
    if (!cell_builder_add_slice_bool(cb, *cs)) {
      throw VmError{Excno::cell_ov, "cannot change label of an old dictionary cell (?)"};
    }
    Ref<Cell> c2 = cb.finalize();  // the other child of the new fork
    //cb.reset();
    append_dict_label(cb, key, pfx_len, n);
    bool sw_bit = key[pfx_len];
    if (sw_bit) {
      c1.swap(c2);
    }
    cb.store_ref(std::move(c1)).store_ref(std::move(c2));
    return std::make_tuple<Ref<CellSlice>, Ref<Cell>, bool>({}, cb.finalize(), true);
  }
  if (label.l_bits == n) {
    // the edge leads to a leaf node
    // this leaf node already contains a value for the key wanted
    auto old_val = std::move(label.remainder);
    old_val.write().advance(label.s_bits);
    if (mode == Dictionary::SetMode::Add) {
      // return unchanged dictionary
      return std::make_tuple<Ref<CellSlice>, Ref<Cell>, bool>(std::move(old_val), {}, false);
    }
    // replace the value of the only element of the dictionary
    CellBuilder cb;
    append_dict_label(cb, key, n, n);
    if (!store_val(cb)) {
      throw VmError{Excno::cell_ov, "cannot store new value into a dictionary cell"};
    }
    return std::make_tuple(std::move(old_val), cb.finalize(), true);
  }
  // main case: the edge leads to a fork, have to insert new value either in the right or in the left subtree
  auto c1 = label.remainder->prefetch_ref(0);
  auto c2 = label.remainder->prefetch_ref(1);
  Ref<CellSlice> old_val;
  label.remainder.clear();
  if (key[label.l_bits]) {
    // insert key into the right child (c2)
    auto res = dict_lookup_set(std::move(c2), key + (label.l_bits + 1), n - label.l_bits - 1, store_val, mode);
    old_val = std::get<Ref<CellSlice>>(res);
    if (!std::get<bool>(res)) {
      // return unchanged dictionary
      return std::make_tuple<Ref<CellSlice>, Ref<Cell>, bool>(std::move(old_val), {}, false);
    }
    c2 = std::get<Ref<Cell>>(std::move(res));
  } else {
    // insert key into the left child (c1)
    auto res = dict_lookup_set(std::move(c1), key + (label.l_bits + 1), n - label.l_bits - 1, store_val, mode);
    old_val = std::get<Ref<CellSlice>>(res);
    if (!std::get<bool>(res)) {
      // return unchanged dictionary
      return std::make_tuple(std::move(old_val), Ref<Cell>{}, false);
    }
    c1 = std::get<Ref<Cell>>(std::move(res));
  }
  // create a new label with the same content
  CellBuilder cb;
  append_dict_label(cb, key, label.l_bits, n);
  cb.store_ref(std::move(c1)).store_ref(std::move(c2));
  return std::make_tuple<Ref<CellSlice>, Ref<Cell>, bool>(std::move(old_val), cb.finalize(), true);
}

std::pair<Ref<Cell>, bool> pfx_dict_set(Ref<Cell> dict, td::ConstBitPtr key, int m, int n,
                                        const PrefixDictionary::store_value_func_t& store_val,
                                        Dictionary::SetMode mode) {
  std::cerr << "up to " << n << "-bit prefix code dictionary modification for " << m << "-bit key = " << key.to_hex(m)
            << std::endl;
  if (m > n) {
    return std::make_pair(Ref<Cell>{}, false);
  }
  if (dict.is_null()) {
    // the dictionary is very empty
    if (mode == Dictionary::SetMode::Replace) {
      return std::make_pair(Ref<Cell>{}, false);
    }
    // create an one-element dictionary
    CellBuilder cb;
    append_dict_label(cb, key, m, n);
    cb.store_long(0, 1);
    if (!store_val(cb)) {
      throw VmError{Excno::cell_ov, "cannot store new value into a dictionary cell"};
    }
    return std::make_pair(cb.finalize(), true);
  }
  LabelParser label{std::move(dict), n, 1};
  int l = label.common_prefix_len(key, m);
  assert(l >= 0 && l <= label.l_bits && label.l_bits <= n && l <= m && m <= n);
  if (l < label.l_bits) {
    // have to insert a new node (fork) inside the current edge
    if (l == m || mode == Dictionary::SetMode::Replace) {
      // key not found, return unchanged dictionary
      return std::make_pair(Ref<Cell>{}, false);
    }
    // first, create the edge + new leaf cell
    int q = l + 1;
    CellBuilder cb;
    append_dict_label(cb, key + q, m - q, n - q);
    cb.store_long(0, 1);
    if (!store_val(cb)) {
      throw VmError{Excno::cell_ov, "cannot store new value into a prefix dictionary cell"};
    }
    Ref<Cell> c1 = cb.finalize();  // new leaf cell corresponding to `key`
    // cb.reset(); // contained in finalize()
    // create the lower portion of the old edge
    int t = label.l_bits - q;
    auto cs = std::move(label.remainder);
    if (label.l_same) {
      append_dict_label_same(cb, label.l_same & 1, t, n - q);
    } else {
      cs.write().advance(l + 1);
      append_dict_label(cb, cs->data_bits(), t, n - q);
      cs.unique_write().advance(t);
    }
    // now cs is the old payload of the edge, either a value or two subdictionary references
    if (!cell_builder_add_slice_bool(cb, *cs)) {
      throw VmError{Excno::cell_ov, "cannot change label of an old dictionary cell (?)"};
    }
    Ref<Cell> c2 = cb.finalize();  // the other child of the new fork
    //cb.reset();
    append_dict_label(cb, key, l, n);
    bool sw_bit = key[l];
    if (sw_bit) {
      c1.swap(c2);
    }
    cb.store_long(1, 1).store_ref(c1).store_ref(c2);
    return std::make_pair<Ref<Cell>, bool>(cb.finalize(), true);
  }
  assert(label.l_bits == l);
  label.skip_label();
  if (!label.remainder->have(1)) {
    throw VmError{Excno::dict_err, "no node constructor in a prefix code dictionary"};
  }
  if (!label.remainder.unique_write().fetch_ulong(1)) {
    // the edge leads to a leaf node
    if (l != m || mode == Dictionary::SetMode::Add) {
      // return unchanged dictionary
      return std::make_pair<Ref<Cell>, bool>({}, false);
    }
    // this leaf node already contains a value for the key wanted
    // replace the value of the only element of the dictionary
    CellBuilder cb;
    append_dict_label(cb, key, m, n);
    cb.store_long(0, 1);
    if (!store_val(cb)) {
      throw VmError{Excno::cell_ov, "cannot store new value into a dictionary cell"};
    }
    return std::make_pair<Ref<Cell>, bool>(cb.finalize(), true);
  }
  // main case: the edge leads to a fork, have to insert new value either in the right or in the left subtree
  if (label.remainder->size() || label.remainder->size_refs() != 2) {
    throw VmError{Excno::dict_err, "invalid fork node in a prefix code dictionary"};
  }
  if (m == l) {
    // cannot insert a value into a fork
    return std::make_pair(Ref<Cell>{}, false);
  }
  auto c1 = label.remainder->prefetch_ref(0);
  auto c2 = label.remainder->prefetch_ref(1);
  label.remainder.clear();
  if (key[l++]) {
    // insert key into the right child (c2)
    auto res = pfx_dict_set(std::move(c2), key + l, m - l, n - l, store_val, mode);
    if (!res.second) {
      // return unchanged dictionary
      return std::make_pair(Ref<Cell>{}, false);
    }
    c2 = std::move(res.first);
  } else {
    // insert key into the left child (c1)
    auto res = pfx_dict_set(std::move(c1), key + l, m - l, n - l, store_val, mode);
    if (!res.second) {
      // return unchanged dictionary
      return std::make_pair(Ref<Cell>{}, false);
    }
    c1 = std::move(res.first);
  }
  // create a new label with the same content
  CellBuilder cb;
  append_dict_label(cb, key, l - 1, n);
  cb.store_long(1, 1).store_ref(std::move(c1)).store_ref(std::move(c2));
  return std::make_pair(cb.finalize(), true);
}

std::pair<Ref<CellSlice>, Ref<Cell>> pfx_dict_lookup_delete(Ref<Cell> dict, td::ConstBitPtr key, int m, int n) {
  //std::cerr << "up to " << n << "-bit prefix dictionary delete for " << m << "-bit key = " << key.to_hex(m) << std::endl;
  if (dict.is_null()) {
    // the dictionary is very empty
    return std::make_pair(Ref<CellSlice>{}, Ref<Cell>{});
  }
  LabelParser label{std::move(dict), n, 1};
  int l = label.common_prefix_len(key, m);
  assert(l >= 0 && l <= label.l_bits && l <= m && m <= n && label.l_bits <= n);
  if (l < label.l_bits) {
    // key not found
    return std::make_pair(Ref<CellSlice>{}, Ref<Cell>{});
  }
  assert(label.l_bits == l);
  label.skip_label();
  if (!label.remainder->have(1)) {
    throw VmError{Excno::dict_err, "no node constructor in a prefix code dictionary"};
  }
  if (!label.remainder.unique_write().fetch_ulong(1)) {
    // the edge leads to a leaf node
    if (l < m) {
      // key not found
      return std::make_pair(Ref<CellSlice>{}, Ref<Cell>{});
    }
    // this leaf node contains the value for the key wanted
    return std::make_pair(std::move(label.remainder), Ref<Cell>{});
  }
  // main case: the edge leads to a fork, have to delete the key either from the right or from the left subtree
  if (label.remainder->size() || label.remainder->size_refs() != 2) {
    throw VmError{Excno::dict_err, "invalid fork node in a prefix code dictionary"};
  }
  if (l == m) {
    // the fork itself cannot correspond to a key, key not found
    return std::make_pair(Ref<CellSlice>{}, Ref<Cell>{});
  }
  auto c1 = label.remainder->prefetch_ref(0);
  auto c2 = label.remainder->prefetch_ref(1);
  Ref<CellSlice> old_val;
  label.remainder.clear();
  bool sw_bit = key[l++];
  if (sw_bit) {
    // delete key from the right child (c2)
    auto res = pfx_dict_lookup_delete(std::move(c2), key + l, m - l, n - l);
    if (res.first.is_null()) {
      // return unchanged dictionary
      return std::make_pair(Ref<CellSlice>{}, Ref<Cell>{});
    }
    old_val = std::move(res.first);
    c2 = std::move(res.second);
  } else {
    // delete key from the left child (c1)
    auto res = pfx_dict_lookup_delete(std::move(c1), key + l, m - l, n - l);
    if (res.first.is_null()) {
      // return unchanged dictionary
      return std::make_pair(Ref<CellSlice>{}, Ref<Cell>{});
    }
    old_val = std::move(res.first);
    c1 = std::move(res.second);
  }
  if (c1.not_null() && c2.not_null()) {
    // create a new label with the same content leading to a fork with modified children
    CellBuilder cb;
    append_dict_label(cb, key, label.l_bits, n);
    cb.store_long(1, 1).store_ref(std::move(c1)).store_ref(std::move(c2));
    return std::make_pair(std::move(old_val), cb.finalize());
  }
  // have to merge current edge with the edge leading to c1 or c2
  if (!sw_bit) {
    c1.swap(c2);
  }
  assert(c1.not_null() && c2.is_null());
  unsigned char buffer[Dictionary::max_key_bytes];
  td::BitPtr bw{buffer};
  bw.concat(key, label.l_bits);
  bw.concat_same(!sw_bit, 1);
  LabelParser label2{std::move(c1), n - l, 1};
  bw += label2.extract_label_to(bw);
  assert(bw.offs >= 0 && bw.offs <= Dictionary::max_key_bits);
  CellBuilder cb;
  append_dict_label(cb, td::ConstBitPtr{buffer}, bw.offs, n);
  if (!cell_builder_add_slice_bool(cb, *label2.remainder)) {
    throw VmError{Excno::cell_ov, "cannot change label of an old prefix code dictionary cell while merging edges"};
  }
  label2.remainder.clear();
  return std::make_pair(std::move(old_val), cb.finalize());
}

Ref<Cell> dict_map(Ref<Cell> dict, td::BitPtr key_buffer, int n, int total_key_len,
                   const Dictionary::map_func_t& map_func) {
  if (dict.is_null()) {
    // dictionary is empty
    return dict;
  }
  LabelParser label{std::move(dict), n};
  int l = label.l_bits;
  label.extract_label_to(key_buffer);
  if (l == n) {
    // leaf node, value left in label.remainder
    CellBuilder cb;
    append_dict_label(cb, key_buffer, l, n);
    if (!map_func(cb, std::move(label.remainder), key_buffer + n - total_key_len, total_key_len)) {
      return {};  // leaf to be omitted from the result altogether
    }
    return cb.finalize();
  }
  assert(l >= 0 && l < n);
  // a fork with two children, c1 and c2
  auto c1 = label.remainder->prefetch_ref(0);
  auto c2 = label.remainder->prefetch_ref(1);
  key_buffer += l + 1;
  key_buffer[-1] = 0;
  // recursive map applied to both children
  c1 = dict_map(std::move(c1), key_buffer, n - l - 1, total_key_len, map_func);
  key_buffer[-1] = 1;
  c2 = dict_map(std::move(c2), key_buffer, n - l - 1, total_key_len, map_func);
  if (c1.is_null() && c2.is_null()) {
    return {};  // both children have become empty
  }
  if (c1.is_null() || c2.is_null()) {
    if (c1.is_null()) {
      c1 = std::move(c2);
      // notice that the label of c2 is still in key_buffer
    } else {
      // recover label of c1
      key_buffer[-1] = 0;
    }
    // one of children is empty, have to combine current edge with the root edge of c1
    LabelParser label1{std::move(c1), n - l - 1};
    label1.extract_label_to(key_buffer);
    CellBuilder cb;
    key_buffer -= l + 1;
    // store combined label for the new edge
    append_dict_label(cb, key_buffer, l + 1 + label1.l_bits, n);
    // store payload
    if (!cell_builder_add_slice_bool(cb, *label1.remainder)) {
      throw VmError{Excno::cell_ov, "cannot change label of an old dictionary cell while merging edges"};
    }
    return cb.finalize();
  }
  // main case: both children c1 and c2 remain non-empty
  key_buffer -= l + 1;
  CellBuilder cb;
  append_dict_label(cb, key_buffer, l, n);
  return cb.store_ref(std::move(c1)).store_ref(std::move(c2)).finalize();
}

}  // namespace

bool Dictionary::set_gen(td::ConstBitPtr key, int key_len, const std::function<bool(CellBuilder&)>& store_val,
                         SetMode mode) {
  force_validate();
  if (key_len != get_key_bits()) {
    return false;
  }
  auto res = dict_set(get_root_cell(), key, key_len, store_val, mode);
  if (res.second) {
    set_root_cell(std::move(res.first));
  }
  return res.second;
}

bool Dictionary::set(td::ConstBitPtr key, int key_len, Ref<CellSlice> value, SetMode mode) {
  return set_gen(key, key_len, [value](CellBuilder& cb) { return cell_builder_add_slice_bool(cb, *value); }, mode);
}

bool Dictionary::set_ref(td::ConstBitPtr key, int key_len, Ref<Cell> val_ref, SetMode mode) {
  return set_gen(key, key_len, [val_ref](CellBuilder& cb) { return cb.store_ref_bool(val_ref); }, mode);
}

bool Dictionary::set_builder(td::ConstBitPtr key, int key_len, Ref<CellBuilder> val_b, SetMode mode) {
  return set_gen(key, key_len, [val_b](CellBuilder& cb) { return cb.append_builder_bool(val_b); }, mode);
}

bool Dictionary::set_builder(td::ConstBitPtr key, int key_len, const CellBuilder& val_b, SetMode mode) {
  return set_gen(key, key_len, [&val_b](CellBuilder& cb) { return cb.append_builder_bool(val_b); }, mode);
}

Ref<CellSlice> Dictionary::lookup_set_gen(td::ConstBitPtr key, int key_len, const store_value_func_t& store_val,
                                          SetMode mode) {
  force_validate();
  if (key_len != get_key_bits()) {
    return {};
  }
  auto res = dict_lookup_set(get_root_cell(), key, key_len, store_val, mode);
  if (std::get<bool>(res)) {
    set_root_cell(std::get<Ref<Cell>>(res));
  }
  return std::get<Ref<CellSlice>>(std::move(res));
}

Ref<CellSlice> Dictionary::lookup_set(td::ConstBitPtr key, int key_len, Ref<CellSlice> value, SetMode mode) {
  return lookup_set_gen(key, key_len, [value](CellBuilder& cb) { return cell_builder_add_slice_bool(cb, *value); },
                        mode);
}

Ref<Cell> Dictionary::lookup_set_ref(td::ConstBitPtr key, int key_len, Ref<Cell> val_ref, SetMode mode) {
  return extract_value_ref(
      lookup_set_gen(key, key_len, [val_ref](CellBuilder& cb) { return cb.store_ref_bool(val_ref); }, mode));
}

Ref<CellSlice> Dictionary::lookup_set_builder(td::ConstBitPtr key, int key_len, Ref<CellBuilder> val_b, SetMode mode) {
  return lookup_set_gen(key, key_len, [val_b](CellBuilder& cb) { return cb.append_builder_bool(val_b); }, mode);
}

std::pair<Ref<CellSlice>, Ref<Cell>> DictionaryFixed::dict_lookup_delete(Ref<Cell> dict, td::ConstBitPtr key,
                                                                         int n) const {
  // std::cerr << "dictionary delete for " << n << "-bit key = " << key.to_hex(n) << std::endl;
  if (dict.is_null()) {
    // the dictionary is very empty
    return std::make_pair(Ref<CellSlice>{}, Ref<Cell>{});
  }
  LabelParser label{std::move(dict), n, label_mode()};
  int pfx_len = label.common_prefix_len(key, n);
  assert(pfx_len >= 0 && pfx_len <= label.l_bits && label.l_bits <= n);
  if (pfx_len < label.l_bits) {
    // key not found
    return std::make_pair(Ref<CellSlice>{}, Ref<Cell>{});
  }
  if (label.l_bits == n) {
    // the edge leads to a leaf node
    // this leaf node contains the value for the key wanted
    label.skip_label();
    return std::make_pair(std::move(label.remainder), Ref<Cell>{});
  }
  // main case: the edge leads to a fork, have to delete the key either from the right or from the left subtree
  auto c1 = label.remainder->prefetch_ref(0);
  auto c2 = label.remainder->prefetch_ref(1);
  Ref<CellSlice> old_val;
  label.remainder.clear();
  bool sw_bit = key[label.l_bits];
  if (sw_bit) {
    // delete key from the right child (c2)
    auto res = dict_lookup_delete(std::move(c2), key + (label.l_bits + 1), n - label.l_bits - 1);
    if (res.first.is_null()) {
      // return unchanged dictionary
      return std::make_pair(Ref<CellSlice>{}, Ref<Cell>{});
    }
    old_val = std::move(res.first);
    c2 = std::move(res.second);
  } else {
    // delete key from the left child (c1)
    auto res = dict_lookup_delete(std::move(c1), key + (label.l_bits + 1), n - label.l_bits - 1);
    if (res.first.is_null()) {
      // return unchanged dictionary
      return std::make_pair(Ref<CellSlice>{}, Ref<Cell>{});
    }
    old_val = std::move(res.first);
    c1 = std::move(res.second);
  }
  if (c1.not_null() && c2.not_null()) {
    // create a new label with the same content leading to a fork with modified children
    CellBuilder cb;
    append_dict_label(cb, key, label.l_bits, n);
    return std::make_pair(std::move(old_val), finish_create_fork(cb, std::move(c1), std::move(c2), n - label.l_bits));
  }
  // have to merge current edge with the edge leading to c1 or c2
  if (!sw_bit) {
    c1.swap(c2);
  }
  assert(c1.not_null() && c2.is_null());
  unsigned char buffer[Dictionary::max_key_bytes];
  td::BitPtr bw{buffer};
  bw.concat(key, label.l_bits);
  bw.concat_same(!sw_bit, 1);
  LabelParser label2{std::move(c1), n - label.l_bits - 1, label_mode()};
  bw += label2.extract_label_to(bw);
  assert(bw.offs >= 0 && bw.offs <= Dictionary::max_key_bits);
  CellBuilder cb;
  append_dict_label(cb, td::ConstBitPtr{buffer}, bw.offs, n);
  if (!cell_builder_add_slice_bool(cb, *label2.remainder)) {
    throw VmError{Excno::cell_ov, "cannot change label of an old dictionary cell while merging edges"};
  }
  label2.remainder.clear();
  return std::make_pair(std::move(old_val), cb.finalize());
}

Ref<CellSlice> DictionaryFixed::lookup_delete(td::ConstBitPtr key, int key_len) {
  force_validate();
  if (key_len != get_key_bits()) {
    return {};
  }
  auto res = dict_lookup_delete(get_root_cell(), key, key_len);
  if (res.first.not_null()) {
    set_root_cell(std::move(res.second));
  }
  return std::move(res.first);
}

Ref<Cell> Dictionary::lookup_delete_ref(td::ConstBitPtr key, int key_len) {
  return extract_value_ref(lookup_delete(key, key_len));
}

Ref<CellSlice> DictionaryFixed::dict_lookup_minmax(Ref<Cell> dict, td::BitPtr key_buffer, int n, int mode) const {
  if (dict.is_null()) {
    return {};
  }
  while (1) {
    LabelParser label{std::move(dict), n, label_mode()};
    int l = label.extract_label_to(key_buffer);
    assert(l >= 0 && l <= n);
    key_buffer += l;
    n -= l;
    if (!n) {
      return std::move(label.remainder);
    }
    if (l) {
      mode >>= 1;
    }
    bool bit = mode & 1;
    dict = label.remainder->prefetch_ref(bit);
    *key_buffer++ = bit;
    --n;
    mode >>= 1;
  }
}

Ref<CellSlice> DictionaryFixed::dict_lookup_nearest(Ref<Cell> dict, td::BitPtr key_buffer, int n, bool allow_eq,
                                                    int mode) const {
  if (dict.is_null()) {
    return {};
  }
  LabelParser label{dict, n, label_mode()};
  int pfx_len = label.common_prefix_len(key_buffer, n);
  assert(pfx_len >= 0 && pfx_len <= label.l_bits && label.l_bits <= n);
  if (pfx_len < label.l_bits) {
    if (key_buffer[pfx_len] == ((mode >> static_cast<int>(pfx_len != 0)) & 1)) {
      return {};
    } else {
      return dict_lookup_minmax(std::move(dict), key_buffer, n, ~mode);
    }
  }
  dict.clear();
  if (label.l_bits) {
    mode >>= 1;
  }
  key_buffer += label.l_bits;
  n -= label.l_bits;
  if (!n) {
    if (!allow_eq) {
      return {};
    }
    label.skip_label();
    return std::move(label.remainder);
  }
  bool bit = *key_buffer++;
  auto res = dict_lookup_nearest(label.remainder->prefetch_ref(bit), key_buffer, n - 1, allow_eq, mode >> 1);
  if (res.not_null() || bit == (mode & 1)) {
    return res;
  }
  key_buffer[-1] = mode & 1;
  dict = label.remainder->prefetch_ref(mode & 1);
  label.remainder.clear();
  return dict_lookup_minmax(std::move(dict), key_buffer, n - 1, ~mode >> 1);
}

Ref<CellSlice> DictionaryFixed::lookup_nearest_key(td::BitPtr key_buffer, int key_len, bool fetch_next, bool allow_eq,
                                                   bool invert_first) {
  force_validate();
  if (key_len != get_key_bits()) {
    return {};
  }
  return dict_lookup_nearest(get_root_cell(), key_buffer, key_len, allow_eq,
                             (-static_cast<int>(fetch_next)) ^ static_cast<int>(invert_first));
}

Ref<CellSlice> DictionaryFixed::get_minmax_key(td::BitPtr key_buffer, int key_len, bool fetch_max, bool invert_first) {
  force_validate();
  if (key_len != get_key_bits()) {
    return {};
  }
  return dict_lookup_minmax(get_root_cell(), key_buffer, key_len,
                            (-static_cast<int>(fetch_max)) ^ static_cast<int>(invert_first));
}

Ref<Cell> Dictionary::get_minmax_key_ref(td::BitPtr key_buffer, int key_len, bool fetch_max, bool invert_first) {
  return extract_value_ref(get_minmax_key(key_buffer, key_len, fetch_max, invert_first));
}

Ref<CellSlice> DictionaryFixed::extract_minmax_key(td::BitPtr key_buffer, int key_len, bool fetch_max,
                                                   bool invert_first) {
  force_validate();
  if (key_len != get_key_bits()) {
    return {};
  }
  auto val = dict_lookup_minmax(get_root_cell(), key_buffer, key_len, -(fetch_max ? 1 : 0) ^ (invert_first ? 1 : 0));
  if (val.is_null()) {
    return {};
  }
  auto res = dict_lookup_delete(get_root_cell(), key_buffer, key_len);
  assert(res.first.not_null());
  set_root_cell(std::move(res.second));
  return val;
}

Ref<Cell> Dictionary::extract_minmax_key_ref(td::BitPtr key_buffer, int key_len, bool fetch_max, bool invert_first) {
  return extract_value_ref(extract_minmax_key(key_buffer, key_len, fetch_max, invert_first));
}

std::pair<Ref<Cell>, bool> DictionaryFixed::extract_prefix_subdict_internal(Ref<Cell> dict, td::ConstBitPtr prefix,
                                                                            int prefix_len, bool remove_prefix) const {
  if (is_empty() || prefix_len <= 0) {
    return {{}, false};  // unchanged
  }
  if (prefix_len > get_key_bits()) {
    return {{}, true};  // empty dict
  }
  int n = get_key_bits(), m = 0;
  while (true) {
    LabelParser label{std::move(dict), n - m, label_mode()};
    int l = std::min(prefix_len - m, label.l_bits);
    if (label.common_prefix_len(prefix + m, l) < l) {
      return {{}, true};  // empty dict
    }
    if (m + label.l_bits < prefix_len) {
      m += label.l_bits;
      dict = label.remainder->prefetch_ref(prefix[m++]);
      continue;
    }
    // end, have consumed all of prefix
    vm::CellBuilder cb;
    if (!remove_prefix) {
      if (!m) {
        // dictionary unchanged: all keys already begin with prefix
        return {{}, false};
      }
      // concatenate prefix with a suffix of the label
      assert(m <= prefix_len);
      unsigned char buffer[max_key_bytes];
      auto p = td::BitPtr{buffer};
      p.copy_from(prefix, m);
      label.extract_label_to(p + m);
      append_dict_label(cb, p, m + label.l_bits, key_bits);
    } else if (!label.l_same) {
      m += label.l_bits - prefix_len;  // leave that many last bits of the label
      append_dict_label(cb, label.bits_end() - m, m, key_bits - prefix_len);
      label.skip_label();
    } else {
      m += label.l_bits - prefix_len;  // leave that many last bits of the label
      append_dict_label_same(cb, label.l_same & 1, m, key_bits - prefix_len);
    }
    if (!cb.append_cellslice_bool(*label.remainder)) {
      throw VmError{Excno::cell_ov, "cannot create new dictionary root while constructing prefix subdictionary"};
    }
    return {Ref<Cell>{cb.finalize()}, true};
  }
}

bool DictionaryFixed::cut_prefix_subdict(td::ConstBitPtr prefix, int prefix_len, bool remove_prefix) {
  force_validate();
  if (prefix_len < 0) {
    return false;
  }
  if (prefix_len > key_bits && remove_prefix) {
    return false;
  }
  auto res = extract_prefix_subdict_internal(get_root_cell(), prefix, prefix_len, remove_prefix);
  if (remove_prefix) {
    key_bits -= prefix_len;
  }
  if (res.second) {
    set_root_cell(std::move(res.first));
  }
  return true;
}

Ref<vm::Cell> DictionaryFixed::extract_prefix_subdict_root(td::ConstBitPtr prefix, int prefix_len, bool remove_prefix) {
  force_validate();
  auto res = extract_prefix_subdict_internal(get_root_cell(), prefix, prefix_len, remove_prefix);
  return res.second ? res.first : root_cell;
}

std::pair<Ref<Cell>, int> DictionaryFixed::dict_filter(Ref<Cell> dict, td::BitPtr key, int n,
                                                       const DictionaryFixed::filter_func_t& check_leaf) const {
  // std::cerr << "dictionary filter for " << n << "-bit key = " << (key + n - key_bits).to_hex(key_bits - n)
  //           << std::endl;
  if (dict.is_null()) {
    // empty dictionary, return unchanged
    return {{}, 0};
  }
  LabelParser label{std::move(dict), n, label_mode()};
  assert(label.l_bits >= 0 && label.l_bits <= n);
  label.extract_label_to(key);
  key += label.l_bits;
  if (label.l_bits == n) {
    // leaf
    int res = check_leaf(label.remainder.write(), key - key_bits, key_bits);
    return {{}, res < 0 ? res : !res};
  }
  // fork, process left and right subtrees
  ++key;
  key[-1] = false;
  int delta = label.l_bits + 1;
  n -= delta;
  auto left_res = dict_filter(label.remainder->prefetch_ref(0), key, n, check_leaf);
  if (left_res.second < 0) {
    return left_res;
  }
  key[-1] = true;
  auto right_res = dict_filter(label.remainder->prefetch_ref(1), key, n, check_leaf);
  if ((left_res.second | right_res.second) <= 0) {
    // error in right, or both left and right unchanged
    return right_res;
  }
  auto left = left_res.second ? std::move(left_res.first) : label.remainder->prefetch_ref(0);
  auto right = right_res.second ? std::move(right_res.first) : label.remainder->prefetch_ref(1);
  auto changes = left_res.second + right_res.second;
  label.clear();
  if (left.is_null()) {
    if (right.is_null()) {
      // both branches are empty => the result is an empty tree
      return {{}, changes};
    }
    std::swap(left, right);
  } else if (right.is_null()) {
    key[-1] = false;
  } else {
    // both new branches are non-empty => create new fork
    CellBuilder cb;
    append_dict_label(cb, key - delta, label.l_bits, n + delta);
    return {finish_create_fork(cb, std::move(left), std::move(right), n + 1), changes};
  }
  // only one child (in `left`) remains, collapse an edge
  // NB: similar to code in lookup_delete()
  assert(left.not_null() && right.is_null());
  LabelParser label2{std::move(left), n, label_mode()};
  label2.extract_label_to(key);
  CellBuilder cb;
  append_dict_label(cb, key - delta, delta + label2.l_bits, n + delta);
  if (!cell_builder_add_slice_bool(cb, *label2.remainder)) {
    throw VmError{Excno::cell_ov, "cannot change label of an old dictionary cell while merging edges"};
  }
  label2.remainder.clear();
  return {cb.finalize(), changes};
}

int DictionaryFixed::filter(DictionaryFixed::filter_func_t check_leaf) {
  force_validate();
  unsigned char buffer[DictionaryFixed::max_key_bytes];
  auto res = dict_filter(get_root_cell(), td::BitPtr{buffer}, key_bits, check_leaf);
  if (res.second > 0) {
    // std::cerr << "after filter (" << res.second << " changes): new augmented dictionary root is:\n";
    // vm::load_cell_slice(res.first).print_rec(std::cerr);
    set_root_cell(std::move(res.first));
  }
  return res.second;
}

void Dictionary::map(const map_func_t& map_func) {
  force_validate();
  int key_len = get_key_bits();
  unsigned char key_buffer[max_key_bytes];
  auto res = dict_map(get_root_cell(), td::BitPtr{key_buffer}, key_len, key_len, map_func);
  set_root_cell(std::move(res));
}

void Dictionary::map(const simple_map_func_t& simple_map_func) {
  using namespace std::placeholders;
  map_func_t map_func = std::bind(simple_map_func, _1, _2);
  map(map_func);
}

// mode: +1 = forbid empty dict1 with non-empty dict2
//       +2 = forbid empty dict2 with non-empty dict1
Ref<Cell> DictionaryFixed::dict_combine_with(Ref<Cell> dict1, Ref<Cell> dict2, td::BitPtr key_buffer, int n,
                                             int total_key_len, const DictionaryFixed::combine_func_t& combine_func,
                                             int mode, int skip1, int skip2) const {
  if (dict1.is_null()) {
    assert(!skip2);
    if ((mode & 1) && dict2.is_null()) {
      throw CombineError{};
    }
    return dict2;
  } else if (dict2.is_null()) {
    assert(!skip1);
    if ((mode & 2)) {
      throw CombineError{};
    }
    return dict1;
  }
  // both dictionaries non-empty
  // skip1: remove that much first bits from all keys in dictionary dict1 (its keys are actually n + skip1 bits long)
  // skip2: similar for dict2
  // resulting dictionary will have n-bit keys
  LabelParser label1{dict1, n + skip1, label_mode()}, label2{dict2, n + skip2, label_mode()};
  int l1 = label1.l_bits - skip1, l2 = label2.l_bits - skip2;
  assert(l1 >= 0 && l2 >= 0);
  assert(!skip1 || label1.common_prefix_len(key_buffer - skip1, skip1) == skip1);
  assert(!skip2 || label2.common_prefix_len(key_buffer - skip2, skip2) == skip2);
  label1.extract_label_to(key_buffer - skip1);
  int c = label2.common_prefix_len(key_buffer - skip2, skip2 + l1) - skip2;
  assert(c >= 0 && c <= l1 && c <= l2);
  if (c < l1 && c < l2) {
    // the two dictionaries have disjoint keys
    dict1.clear();
    dict2.clear();
    if ((mode & 3)) {
      throw CombineError{};
    }
    CellBuilder cb;
    append_dict_label(cb, key_buffer + c + 1, l1 - c - 1, n - c - 1);
    if (!cell_builder_add_slice_bool(cb, *label1.remainder)) {
      throw VmError{Excno::cell_ov, "cannot prune label of an old dictionary cell while merging dictionaries"};
    }
    label1.remainder.clear();
    dict1 = cb.finalize();
    // cb.reset(); // included into finalize();
    // now dict1 has been "pruned" -- first skip1+c+1 bits removed from its root egde label
    label2.extract_label_to(key_buffer - skip2);
    append_dict_label(cb, key_buffer + c + 1, l2 - c - 1, n - c - 1);
    if (!cell_builder_add_slice_bool(cb, *label2.remainder)) {
      throw VmError{Excno::cell_ov, "cannot change label of an old dictionary cell while merging edges"};
    }
    label2.remainder.clear();
    dict2 = cb.finalize();
    // now dict2 has also been pruned
    if (!key_buffer[c]) {
      std::swap(dict1, dict2);
    }
    // put dict1 into the left tree (with smaller labels), dict2 into the right tree
    append_dict_label(cb, key_buffer, c, n);
    return finish_create_fork(cb, std::move(dict1), std::move(dict2), n - c);
  }
  if (c == l1 && c == l2) {
    // funny enough, the non-skipped parts of labels of l1 and l2 match
    dict1.clear();
    dict2.clear();
    label2.skip_label();
    CellBuilder cb;
    append_dict_label(cb, key_buffer, c, n);
    if (c == n) {
      // our two dictionaries are in fact leafs with matching edge labels (keys)
      if (!combine_func(cb, std::move(label1.remainder), std::move(label2.remainder), key_buffer + n - total_key_len,
                        total_key_len)) {
        // alas, the two values did not combine, this key will be absent from resulting dictionary
        return {};
      }
      return cb.finalize();
    }
    assert(c < n);
    key_buffer += c + 1;
    key_buffer[-1] = 0;
    // combine left subtrees
    auto c1 = dict_combine_with(label1.remainder->prefetch_ref(0), label2.remainder->prefetch_ref(0), key_buffer,
                                n - c - 1, total_key_len, combine_func);
    key_buffer[-1] = 1;
    // combine right subtrees
    auto c2 = dict_combine_with(label1.remainder->prefetch_ref(1), label2.remainder->prefetch_ref(1), key_buffer,
                                n - c - 1, total_key_len, combine_func);
    label1.remainder.clear();
    label2.remainder.clear();
    // c1 and c2 are merged left and right children of dict1 and dict2
    if (!c1.is_null() && !c2.is_null()) {
      // both children non-empty, simply put them into the new node
      return finish_create_fork(cb, std::move(c1), std::move(c2), n - c);
    }
    if (c1.is_null() && c2.is_null()) {
      return {};  // both children empty, resulting dictionary also empty
    }
    // exactly one of c1 and c2 is non-empty, have to merge labels
    bool sw = c1.is_null();
    key_buffer[-1] = sw;
    if (sw) {
      c1 = std::move(c2);
    }
    LabelParser label3{std::move(c1), n - c - 1, label_mode()};
    label3.extract_label_to(key_buffer);
    key_buffer -= c + 1;
    // store combined label for the new edge
    cb.reset();
    append_dict_label(cb, key_buffer, c + 1 + label3.l_bits, n);
    // store payload
    if (!cell_builder_add_slice_bool(cb, *label3.remainder)) {
      throw VmError{Excno::cell_ov, "cannot change label of an old dictionary cell while merging edges"};
    }
    return cb.finalize();
  }
  if (c == l1) {
    assert(c < l2);
    dict1.clear();
    if ((mode & 2)) {
      throw CombineError{};
    }
    // children of root node of dict1
    auto c1 = label1.remainder->prefetch_ref(0);
    auto c2 = label1.remainder->prefetch_ref(1);
    label1.remainder.clear();
    // have to merge dict2 with one of the children of dict1
    label2.extract_label_to(key_buffer - skip2);  // dict2 has longer label, extract it
    bool sw = key_buffer[c];
    if (!sw) {
      // merge c1 with dict2
      c1 = dict_combine_with(std::move(c1), std::move(dict2), key_buffer + c + 1, n - c - 1, total_key_len,
                             combine_func, mode, 0, skip2 + c + 1);
    } else {
      // merge c2 with dict2
      c2 = dict_combine_with(std::move(c2), std::move(dict2), key_buffer + c + 1, n - c - 1, total_key_len,
                             combine_func, mode, 0, skip2 + c + 1);
    }
    if (!c1.is_null() && !c2.is_null()) {
      CellBuilder cb;
      append_dict_label(cb, key_buffer, c, n);
      return finish_create_fork(cb, std::move(c1), std::move(c2), n - c);
    }
    // one of children is empty, have to merge root edges
    key_buffer[c] = !sw;
    if (!sw) {
      std::swap(c1, c2);
    }
    assert(!c1.is_null() && c2.is_null());
    LabelParser label3{std::move(c1), n - c - 1, label_mode()};
    label3.extract_label_to(key_buffer + c + 1);
    CellBuilder cb;
    append_dict_label(cb, key_buffer, c + 1 + label3.l_bits, n);
    // store payload
    if (!cell_builder_add_slice_bool(cb, *label3.remainder)) {
      throw VmError{Excno::cell_ov, "cannot change label of an old dictionary cell while merging edges"};
    }
    return cb.finalize();
  } else {
    assert(c == l2 && c < l1);
    dict2.clear();
    if ((mode & 1)) {
      throw CombineError{};
    }
    // children of root node of dict2
    label2.skip_label();  // dict2 had shorter label anyway, label1 is already unpacked
    auto c1 = label2.remainder->prefetch_ref(0);
    auto c2 = label2.remainder->prefetch_ref(1);
    label2.remainder.clear();
    // have to merge dict1 with one of the children of dict2
    bool sw = key_buffer[c];
    if (!sw) {
      // merge dict1 with c1
      c1 = dict_combine_with(std::move(dict1), std::move(c1), key_buffer + c + 1, n - c - 1, total_key_len,
                             combine_func, mode, skip1 + c + 1, 0);
    } else {
      // merge dict1 with c2
      c2 = dict_combine_with(std::move(dict1), std::move(c2), key_buffer + c + 1, n - c - 1, total_key_len,
                             combine_func, mode, skip1 + c + 1, 0);
    }
    if (!c1.is_null() && !c2.is_null()) {
      CellBuilder cb;
      append_dict_label(cb, key_buffer, c, n);
      return finish_create_fork(cb, std::move(c1), std::move(c2), n - c);
    }
    // one of children is empty, have to merge root edges
    key_buffer[c] = !sw;
    if (!sw) {
      std::swap(c1, c2);
    }
    assert(!c1.is_null() && c2.is_null());
    LabelParser label3{std::move(c1), n - c - 1, label_mode()};
    label3.extract_label_to(key_buffer + c + 1);
    CellBuilder cb;
    append_dict_label(cb, key_buffer, c + 1 + label3.l_bits, n);
    // store payload
    if (!cell_builder_add_slice_bool(cb, *label3.remainder)) {
      throw VmError{Excno::cell_ov, "cannot change label of an old dictionary cell while merging edges"};
    }
    return cb.finalize();
  }
}

bool DictionaryFixed::combine_with(DictionaryFixed& dict2, const combine_func_t& combine_func, int mode) {
  force_validate();
  dict2.force_validate();
  int key_len = get_key_bits();
  if (key_len != dict2.get_key_bits()) {
    throw VmError{Excno::dict_err, "cannot combine dictionaries with different key lengths"};
  }
  unsigned char key_buffer[max_key_bytes];
  try {
    auto res = dict_combine_with(get_root_cell(), dict2.get_root_cell(), td::BitPtr{key_buffer}, key_len, key_len,
                                 combine_func, mode);
    set_root_cell(std::move(res));
    return true;
  } catch (CombineError) {
    return false;
  }
}

bool DictionaryFixed::combine_with(DictionaryFixed& dict2, const simple_combine_func_t& simple_combine_func, int mode) {
  using namespace std::placeholders;
  combine_func_t combine_func = std::bind(simple_combine_func, _1, _2, _3);
  return combine_with(dict2, combine_func, mode);
}

bool DictionaryFixed::combine_with(DictionaryFixed& dict2) {
  return combine_with(dict2,
                      [](CellBuilder&, Ref<CellSlice>, Ref<CellSlice>, td::ConstBitPtr key, int key_len) -> bool {
                        LOG(WARNING) << "dictionary merge conflict for key " << key.to_hex(key_len);
                        throw CombineError{};
                      });
}

bool DictionaryFixed::dict_check_for_each(Ref<Cell> dict, td::BitPtr key_buffer, int n, int total_key_len,
                                          const DictionaryFixed::foreach_func_t& foreach_func,
                                          bool invert_first) const {
  if (dict.is_null()) {
    return true;
  }
  LabelParser label{std::move(dict), n, label_mode()};
  int l = label.l_bits;
  label.extract_label_to(key_buffer);
  if (l == n) {
    // leaf node, value left in label.remainder
    return foreach_func(std::move(label.remainder), key_buffer + n - total_key_len, total_key_len);
  }
  assert(l >= 0 && l < n);
  // a fork with two children, c1 and c2
  auto c1 = label.remainder->prefetch_ref(0);
  auto c2 = label.remainder->prefetch_ref(1);
  label.remainder.clear();
  key_buffer += l + 1;
  if (l) {
    invert_first = false;
  } else if (invert_first) {
    std::swap(c1, c2);
  }
  key_buffer[-1] = invert_first;
  // recursive check_foreach applied to both children
  if (!dict_check_for_each(std::move(c1), key_buffer, n - l - 1, total_key_len, foreach_func)) {
    return false;
  }
  key_buffer[-1] = !invert_first;
  return dict_check_for_each(std::move(c2), key_buffer, n - l - 1, total_key_len, foreach_func);
}

bool DictionaryFixed::check_for_each(const foreach_func_t& foreach_func, bool invert_first) {
  force_validate();
  if (is_empty()) {
    return true;
  }
  int key_len = get_key_bits();
  unsigned char key_buffer[max_key_bytes];
  return dict_check_for_each(get_root_cell(), td::BitPtr{key_buffer}, key_len, key_len, foreach_func, invert_first);
}

static inline bool set_bit(td::BitPtr ptr, bool value = true) {
  *ptr = value;
  return true;
}

// mode: +1 = check augmentation of dict1, +2 = ... of dict2
bool DictionaryFixed::dict_scan_diff(Ref<Cell> dict1, Ref<Cell> dict2, td::BitPtr key_buffer, int n, int total_key_len,
                                     const scan_diff_func_t& diff_func, int mode, int skip1, int skip2) const {
  // skip1: remove that much first bits from all keys in dictionary dict1 (its keys are actually n + skip1 bits long)
  // skip2: similar for dict2
  // pretending to compare subdictionaries with n-bit keys
  if (dict1.is_null()) {
    if (dict2.is_null()) {
      return true;  // both dictionaries are empty
    }
    assert(!skip2);
    // dict1 empty, dict2 non-empty -> parse label of dict2
    LabelParser label{dict2, n, label_mode()};
    label.extract_label_to(key_buffer);
    if (label.l_bits >= n) {
      assert(label.l_bits == n);
      // leaf in dict2, empty dict1
      auto key = key_buffer + label.l_bits - total_key_len;
      if ((mode & 2) && !check_leaf(label.remainder, key, total_key_len)) {
        throw VmError{Excno::dict_err, "invalid leaf in the second dictionary being compared"};
      }
      return diff_func(key, total_key_len, {}, std::move(label.remainder));
    }
    n -= label.l_bits + 1;
    key_buffer += label.l_bits + 1;
    if ((mode & 2) && !check_fork_raw(label.remainder, n + 1)) {
      throw VmError{Excno::dict_err, "invalid fork in the second dictionary being compared"};
    }
    // compare {} with each of children of dict2
    for (unsigned sw = 0; sw < 2; sw++) {
      key_buffer[-1] = (bool)sw;
      if (!dict_scan_diff({}, label.remainder->prefetch_ref(sw), key_buffer, n, total_key_len, diff_func, mode)) {
        return false;
      }
    }
    return true;
  } else if (dict2.is_null()) {
    assert(!skip1);
    // dict2 empty, dict1 non-empty -> parse label of dict1
    LabelParser label{dict1, n, label_mode()};
    label.extract_label_to(key_buffer);
    if (label.l_bits >= n) {
      assert(label.l_bits == n);
      // leaf in dict1, empty dict2
      auto key = key_buffer + label.l_bits - total_key_len;
      if ((mode & 1) && !check_leaf(label.remainder, key, total_key_len)) {
        throw VmError{Excno::dict_err, "invalid leaf in the first dictionary being compared"};
      }
      return diff_func(key, total_key_len, std::move(label.remainder), {});
    }
    n -= label.l_bits + 1;
    key_buffer += label.l_bits + 1;
    if ((mode & 1) && !check_fork_raw(label.remainder, n + 1)) {
      throw VmError{Excno::dict_err, "invalid fork in the first dictionary being compared"};
    }
    // compare each of children of dict1 with {}
    for (unsigned sw = 0; sw < 2; sw++) {
      key_buffer[-1] = (bool)sw;
      if (!dict_scan_diff(label.remainder->prefetch_ref(sw), {}, key_buffer, n, total_key_len, diff_func, mode)) {
        return false;
      }
    }
    return true;
  }
  // both dictionaries non-empty
  if (skip1 == skip2 && (dict1 == dict2 || dict1->get_hash() == dict2->get_hash())) {
    // dictionaries match, subtree comparison not necessary
    return true;
  }
  LabelParser label1{dict1, n + skip1, label_mode()}, label2{dict2, n + skip2, label_mode()};
  int l1 = label1.l_bits - skip1, l2 = label2.l_bits - skip2;
  assert(l1 >= 0 && l2 >= 0);
  assert(!skip1 || label1.common_prefix_len(key_buffer - skip1, skip1) == skip1);
  assert(!skip2 || label2.common_prefix_len(key_buffer - skip2, skip2) == skip2);
  label1.extract_label_to(key_buffer - skip1);
  int c = label2.common_prefix_len(key_buffer - skip2, skip2 + l1) - skip2;
  assert(c >= 0 && c <= l1 && c <= l2);
  if (c < l1 && c < l2) {
    // the two dictionaries have disjoint keys
    if (!key_buffer[c]) {
      // all keys of dict1 are before dict2
      return dict_scan_diff(std::move(dict1), {}, key_buffer - skip1, n + skip1, total_key_len, diff_func, mode) &&
             dict_scan_diff({}, std::move(dict2), key_buffer - skip2, n + skip2, total_key_len, diff_func, mode);
    } else {
      // all keys of dict2 are before dict1
      return dict_scan_diff({}, std::move(dict2), key_buffer - skip2, n + skip2, total_key_len, diff_func, mode) &&
             dict_scan_diff(std::move(dict1), {}, key_buffer - skip1, n + skip1, total_key_len, diff_func, mode);
    }
  }
  if (c == l1 && c == l2) {
    // funny enough, the non-skipped parts of labels of l1 and l2 match
    dict1.clear();
    dict2.clear();
    label2.skip_label();
    if (c == n) {
      // our two dictionaries are in fact leafs with matching edge labels (keys)
      auto key = key_buffer + n - total_key_len;
      if ((mode & 1) && !check_leaf(label1.remainder, key, total_key_len)) {
        throw VmError{Excno::dict_err, "invalid leaf in the first dictionary being compared"};
      }
      if ((mode & 2) && !check_leaf(label2.remainder, key, total_key_len)) {
        throw VmError{Excno::dict_err, "invalid leaf in the second dictionary being compared"};
      }
      return label1.remainder->contents_equal(*label2.remainder) ||
             diff_func(key, total_key_len, std::move(label1.remainder), std::move(label2.remainder));
    }
    assert(c < n);
    key_buffer += c + 1;
    n -= c + 1;
    if ((mode & 1) && !check_fork_raw(label1.remainder, n + 1)) {
      throw VmError{Excno::dict_err, "invalid fork in the first dictionary being compared"};
    }
    if ((mode & 2) && !check_fork_raw(label2.remainder, n + 1)) {
      throw VmError{Excno::dict_err, "invalid fork in the second dictionary being compared"};
    }
    for (unsigned sw = 0; sw <= 1; sw++) {
      key_buffer[-1] = (bool)sw;
      // compare left and then right subtrees
      if (!dict_scan_diff(label1.remainder->prefetch_ref(sw), label2.remainder->prefetch_ref(sw), key_buffer, n,
                          total_key_len, diff_func, mode)) {
        return false;
      }
    }
    return true;
  }
  if (c == l1) {
    assert(c < l2);
    dict1.clear();
    if ((mode & 1) && !check_fork_raw(label1.remainder, n - c)) {
      throw VmError{Excno::dict_err, "invalid fork in the first dictionary being compared"};
    }
    // children of root node of dict1
    auto c1 = label1.remainder->prefetch_ref(0);
    auto c2 = label1.remainder->prefetch_ref(1);
    label1.remainder.clear();
    // have to compare dict2 with one of the children of dict1
    label2.extract_label_to(key_buffer - skip2);  // dict2 has longer label, extract it
    key_buffer += c + 1;
    n -= c + 1;
    bool sw = key_buffer[-1];
    key_buffer[-1] = false;
    if (!sw) {
      // compare c1 with dict2, then c2 with {}
      return dict_scan_diff(std::move(c1), std::move(dict2), key_buffer, n, total_key_len, diff_func, mode, 0,
                            skip2 + c + 1) &&
             set_bit(key_buffer - 1) &&
             dict_scan_diff(std::move(c2), {}, key_buffer, n, total_key_len, diff_func, mode);
    } else {
      // compare c1 with {}, then c2 with dict2
      return dict_scan_diff(std::move(c1), {}, key_buffer, n, total_key_len, diff_func, mode) &&
             set_bit(key_buffer - 1) &&
             dict_scan_diff(std::move(c2), std::move(dict2), key_buffer, n, total_key_len, diff_func, mode, 0,
                            skip2 + c + 1);
    }
  } else {
    assert(c == l2 && c < l1);
    dict2.clear();
    label2.skip_label();  // dict2 had shorter label anyway, label1 is already unpacked
    if ((mode & 2) && !check_fork_raw(label2.remainder, n - c)) {
      throw VmError{Excno::dict_err, "invalid fork in the second dictionary being compared"};
    }
    // children of root node of dict2
    auto c1 = label2.remainder->prefetch_ref(0);
    auto c2 = label2.remainder->prefetch_ref(1);
    label2.remainder.clear();
    // have to compare dict1 with one of the children of dict2
    key_buffer += c + 1;
    n -= c + 1;
    bool sw = key_buffer[-1];
    key_buffer[-1] = false;
    if (!sw) {
      // compare dict1 with c1, then {} with c2
      return dict_scan_diff(std::move(dict1), std::move(c1), key_buffer, n, total_key_len, diff_func, mode,
                            skip1 + c + 1, 0) &&
             set_bit(key_buffer - 1) &&
             dict_scan_diff({}, std::move(c2), key_buffer, n, total_key_len, diff_func, mode);
    } else {
      // compare {} with c1, then dict1 with c2
      return dict_scan_diff({}, std::move(c1), key_buffer, n, total_key_len, diff_func, mode) &&
             set_bit(key_buffer - 1) &&
             dict_scan_diff(std::move(dict1), std::move(c2), key_buffer, n, total_key_len, diff_func, mode,
                            skip1 + c + 1, 0);
    }
  }
}

bool DictionaryFixed::scan_diff(DictionaryFixed& dict2, const scan_diff_func_t& diff_func, int check_augm) {
  force_validate();
  dict2.force_validate();
  int key_len = get_key_bits();
  if (key_len != dict2.get_key_bits()) {
    throw VmError{Excno::dict_err, "cannot compare dictionaries with different key lengths"};
  }
  unsigned char key_buffer[max_key_bytes];
  try {
    return dict_scan_diff(get_root_cell(), dict2.get_root_cell(), td::BitPtr{key_buffer}, key_len, key_len, diff_func,
                          check_augm);
  } catch (CombineError) {
    return false;
  }
}

bool DictionaryFixed::dict_validate_check(Ref<Cell> dict, td::BitPtr key_buffer, int n, int total_key_len,
                                          const DictionaryFixed::foreach_func_t& foreach_func,
                                          bool invert_first) const {
  //LOG(DEBUG) << "dict_validate_check for " << total_key_len - n << "-bit key prefix " << (key_buffer - n + total_key_len).to_hex(total_key_len - n);
  if (dict.is_null()) {
    return true;
  }
  LabelParser label{std::move(dict), n, label_mode()};
  int l = label.l_bits;
  label.extract_label_to(key_buffer);
  if (l == n) {
    // leaf node, value left in label.remainder
    vm::CellSlice cs{*label.remainder};
    auto key = key_buffer + n - total_key_len;
    if (!(check_leaf(cs, key, total_key_len) && foreach_func(std::move(label.remainder), key, total_key_len))) {
      LOG(DEBUG) << "invalid dictionary leaf node with " << total_key_len << "-bit key " << key.to_hex(total_key_len);
      return false;
    }
    return true;
  }
  assert(l >= 0 && l < n);
  // a fork with two children, c1 and c2
  auto c1 = label.remainder.write().fetch_ref();
  auto c2 = label.remainder.unique_write().fetch_ref();
  key_buffer += l + 1;
  n -= l + 1;
  if (!check_fork(label.remainder.write(), c1, c2, n + 1)) {
    LOG(DEBUG) << "invalid dictionary fork augmentation for fork node with " << total_key_len - n - 1
               << "-bit key prefix " << (key_buffer + n - total_key_len).to_hex(total_key_len - n - 1);
    return false;
  }
  label.remainder.clear();
  if (l) {
    invert_first = false;
  } else if (invert_first) {
    std::swap(c1, c2);
  }
  key_buffer[-1] = invert_first;
  // recursive check_foreach applied to both children
  if (!dict_validate_check(std::move(c1), key_buffer, n, total_key_len, foreach_func)) {
    return false;
  }
  key_buffer[-1] = !invert_first;
  return dict_validate_check(std::move(c2), key_buffer, n, total_key_len, foreach_func);
}

bool DictionaryFixed::validate_check(const DictionaryFixed::foreach_func_t& foreach_func, bool invert_first) {
  if (!validate()) {
    return false;
  }
  if (is_empty()) {
    return true;
  }
  int key_len = get_key_bits();
  unsigned char key_buffer[max_key_bytes];
  return dict_validate_check(get_root_cell(), td::BitPtr{key_buffer}, key_len, key_len, foreach_func, invert_first);
}

bool DictionaryFixed::validate_all() {
  return validate_check([](Ref<CellSlice> value, td::ConstBitPtr key, int n) { return true; }) || invalidate();
}

/*
 * 
 *   PREFIX DICTIONARIES
 * 
 */

std::pair<Ref<CellSlice>, int> PrefixDictionary::lookup_prefix(td::ConstBitPtr key, int key_len) {
  force_validate();
  int n = get_key_bits();
  if (is_empty()) {
    return std::make_pair(Ref<CellSlice>{}, 0);
  }
  //std::cerr << "dictionary lookup for key = " << key.to_hex(key_len) << std::endl;
  Ref<Cell> cell = get_root_cell();
  int m = key_len;
  while (true) {
    LabelParser label{std::move(cell), n, 1};
    int l = label.common_prefix_len(key, m);
    if (l < label.l_bits) {
      //std::cerr << "(not a prefix)\n";
      return std::make_pair(Ref<CellSlice>{}, key_len - m + l);
    }
    n -= label.l_bits;
    m -= label.l_bits;
    assert(m >= 0);
    label.skip_label();
    Ref<CellSlice> cs = std::move(label.remainder);
    if (!cs->have(1)) {
      throw VmError{Excno::dict_err, "no node constructor in a prefix code dictionary"};
    }
    if (!cs.unique_write().fetch_ulong(1)) {
      return std::make_pair(std::move(cs), key_len - m);
    }
    if (!n) {
      throw VmError{Excno::dict_err, "a fork node in a prefix code dictionary with zero remaining key length"};
    }
    if (cs->size() != 0 || cs->size_refs() != 2) {
      throw VmError{Excno::dict_err, "invalid fork node in a prefix code dictionary"};
    }
    if (!m) {
      return std::make_pair(Ref<CellSlice>{}, key_len);
    }
    key += label.l_bits;
    bool sw = *key++;
    //std::cerr << "key bit at position " << key_bits - n << " equals " << sw << std::endl;
    --n;
    --m;
    cell = cs->prefetch_ref(sw);
  }
}

Ref<CellSlice> PrefixDictionary::lookup(td::ConstBitPtr key, int key_len) {
  force_validate();
  if (key_len > get_key_bits()) {
    return {};
  }
  auto res = lookup_prefix(key, key_len);
  return res.second == key_len ? std::move(res.first) : Ref<CellSlice>{};
}

bool PrefixDictionary::set_gen(td::ConstBitPtr key, int key_len, const std::function<bool(CellBuilder&)>& store_val,
                               SetMode mode) {
  force_validate();
  if (key_len > get_key_bits() || key_len < 0) {
    return false;
  }
  auto res = pfx_dict_set(get_root_cell(), key, key_len, get_key_bits(), store_val, mode);
  if (res.second) {
    set_root_cell(std::move(res.first));
  }
  return res.second;
}

bool PrefixDictionary::set(td::ConstBitPtr key, int key_len, Ref<CellSlice> value, SetMode mode) {
  return set_gen(key, key_len, [value](CellBuilder& cb) { return cell_builder_add_slice_bool(cb, *value); }, mode);
}

bool PrefixDictionary::set_builder(td::ConstBitPtr key, int key_len, Ref<CellBuilder> val_b, SetMode mode) {
  return set_gen(key, key_len, [val_b](CellBuilder& cb) { return cb.append_builder_bool(val_b); }, mode);
}

Ref<CellSlice> PrefixDictionary::lookup_delete(td::ConstBitPtr key, int key_len) {
  force_validate();
  if (key_len > get_key_bits() || key_len < 0) {
    return {};
  }
  auto res = pfx_dict_lookup_delete(get_root_cell(), key, key_len, get_key_bits());
  if (res.first.not_null()) {
    set_root_cell(std::move(res.second));
  }
  return std::move(res.first);
}

/*
 * 
 *   AUGMENTED DICTIONARIES
 * 
 */

namespace dict {

bool AugmentationData::check_empty(vm::CellSlice& cs) const {
  vm::CellBuilder cb;
  return eval_empty(cb) && cb.contents_equal(cs);
}

bool AugmentationData::check_leaf(vm::CellSlice& cs, vm::CellSlice& val_cs) const {
  vm::CellBuilder cb;
  return eval_leaf(cb, val_cs) && cb.contents_equal(cs);
}

bool AugmentationData::check_fork(vm::CellSlice& cs, vm::CellSlice& left_cs, vm::CellSlice& right_cs) const {
  vm::CellBuilder cb;
  return eval_fork(cb, left_cs, right_cs) && cb.contents_equal(cs);
}

Ref<vm::CellSlice> AugmentationData::extract_extra(vm::CellSlice& cs) const {
  Ref<CellSlice> res{true, cs};
  return skip_extra(cs) && res.write().cut_tail(cs) ? std::move(res) : Ref<CellSlice>{};
}

Ref<vm::CellSlice> AugmentationData::extract_extra(Ref<vm::CellSlice> cs_ref) const {
  CellSlice cs{*cs_ref};
  return skip_extra(cs) && cs_ref.write().cut_tail(cs) ? std::move(cs_ref) : Ref<CellSlice>{};
}

bool AugmentationData::extract_extra_to(vm::CellSlice& cs, vm::CellSlice& extra) const {
  extra = cs;
  return cs.is_valid() && skip_extra(cs) && extra.cut_tail(cs);
}

}  // namespace dict

using dict::AugmentationData;
using dict::LabelParser;

AugmentedDictionary::AugmentedDictionary(int _n, const AugmentationData& _aug, bool validate)
    : DictionaryFixed(_n, false), aug(_aug) {
  if (validate) {
    force_validate();
  }
}

AugmentedDictionary::AugmentedDictionary(Ref<CellSlice> _root, int _n, const AugmentationData& _aug, bool validate)
    : DictionaryFixed(std::move(_root), _n, false), aug(_aug) {
  if (validate) {
    force_validate();
  }
}

AugmentedDictionary::AugmentedDictionary(Ref<Cell> cell, int _n, const AugmentationData& _aug, bool validate)
    : DictionaryFixed(std::move(cell), _n, false), aug(_aug) {
  if (validate) {
    force_validate();
  }
}

AugmentedDictionary::AugmentedDictionary(DictNonEmpty, Ref<CellSlice> _root, int _n, const AugmentationData& _aug,
                                         bool validate)
    : DictionaryFixed(DictNonEmpty{}, std::move(_root), _n, false), aug(_aug) {
  if (validate) {
    force_validate();
  }
}

bool AugmentedDictionary::validate() {
  if (is_valid()) {
    return true;
  }
  if (flags & f_invalid) {
    return false;
  }
  if (key_bits < 0 || key_bits > max_key_bits) {
    return invalidate();
  }
  if (flags & f_root_cached) {
    if (root.is_null() || !root->size()) {
      return invalidate();
    }
    bool non_empty = root->prefetch_ulong(1);
    if (non_empty && !root->size_refs()) {
      return invalidate();
    }
    if (root_cell.not_null()) {
      return invalidate();
    }
    vm::CellSlice cs{*root};
    if (!cs.advance(1)) {
      return invalidate();
    }
    if (non_empty) {
      root_cell = cs.fetch_ref();
      auto root_extra = get_root_extra();
      if (!(root_extra.not_null() && root_extra->contents_equal(cs))) {
        return invalidate();
      }
    } else {
      if (!aug.check_empty(cs)) {
        return invalidate();
      }
    }
  } else if (root.not_null()) {
    return invalidate();
  }
  flags |= f_valid;
  return true;
}

Ref<CellSlice> AugmentedDictionary::get_root() const {
  if (!(flags & f_root_cached) && !compute_root()) {
    return {};
  }
  return root;
}

Ref<CellSlice> AugmentedDictionary::extract_root() && {
  if (!(flags & f_root_cached) && !compute_root()) {
    return {};
  }
  flags = f_invalid;
  return std::move(root);
}

bool AugmentedDictionary::append_dict_to_bool(CellBuilder& cb) const& {
  if (!is_valid()) {
    return false;
  }
  if (root_cell.is_null()) {
    return cb.store_zeroes_bool(1) && aug.eval_empty(cb);
  } else {
    return cb.store_ones_bool(1) && cb.store_ref_bool(root_cell) && cb.append_cellslice_bool(get_root_extra());
  }
}

bool AugmentedDictionary::append_dict_to_bool(CellBuilder& cb) && {
  if (!is_valid()) {
    return false;
  }
  flags = f_invalid;
  if (root_cell.is_null()) {
    return cb.store_zeroes_bool(1) && aug.eval_empty(cb);
  } else {
    return cb.store_ones_bool(1) && cb.store_ref_bool(root_cell) && cb.append_cellslice_bool(get_root_extra());
  }
}

bool AugmentedDictionary::compute_root() const {
  if (!is_valid()) {
    return false;
  }
  if (root_cell.is_null()) {
    root = get_empty_dictionary();
    flags |= f_root_cached;
    return true;
  }
  CellBuilder cb;
  if (cb.store_long_bool(1, 1) && cb.store_ref_bool(root_cell) && cb.append_cellslice_bool(get_root_extra())) {
    root = Ref<CellSlice>{true, cb.finalize()};
    flags |= f_root_cached;
    return true;
  } else {
    return false;
  }
}

Ref<CellSlice> AugmentedDictionary::get_empty_dictionary() const {
  CellBuilder cb;
  cb.store_long(0, 1);
  return aug.eval_empty(cb) ? Ref<CellSlice>{true, cb.finalize()} : Ref<CellSlice>{};
}

Ref<CellSlice> AugmentedDictionary::get_node_extra(Ref<Cell> cell_ref, int n) const {
  if (cell_ref.is_null()) {
    CellBuilder cb;
    if (!aug.eval_empty(cb)) {
      return {};
    }
    return Ref<CellSlice>{true, cb.finalize()};
  }
  LabelParser label{std::move(cell_ref), n, 2};
  label.skip_label();
  if (label.l_bits == n) {
    return aug.extract_extra(std::move(label.remainder));
  } else if (label.remainder.write().advance_refs(2)) {
    vm::CellSlice cs{*label.remainder};
    if (aug.skip_extra(cs) && cs.empty_ext()) {
      return std::move(label.remainder);
    }
  }
  return {};
}

Ref<CellSlice> AugmentedDictionary::get_root_extra() const {
  return get_node_extra(root_cell, key_bits);
}

Ref<CellSlice> AugmentedDictionary::extract_value(Ref<CellSlice> value_extra) const {
  if (value_extra.not_null() && aug.skip_extra(value_extra.write())) {
    return value_extra;
  } else {
    return {};
  }
}

Ref<Cell> AugmentedDictionary::extract_value_ref(Ref<CellSlice> value_extra) const {
  if (value_extra.not_null() && aug.skip_extra(value_extra.write()) && value_extra->size_ext() == 0x10000) {
    return value_extra->prefetch_ref();
  } else {
    return {};
  }
}

std::pair<Ref<CellSlice>, Ref<CellSlice>> AugmentedDictionary::decompose_value_extra(Ref<CellSlice> value_extra) const {
  if (value_extra.is_null()) {
    return {};
  }
  auto extra = aug.extract_extra(value_extra.write());
  if (extra.is_null()) {
    return {};
  } else {
    return {std::move(value_extra), std::move(extra)};
  }
}

std::pair<Ref<Cell>, Ref<CellSlice>> AugmentedDictionary::decompose_value_ref_extra(Ref<CellSlice> value_extra) const {
  if (value_extra.is_null()) {
    return {};
  }
  auto extra = aug.extract_extra(value_extra.write());
  if (extra.is_null() || value_extra->size_ext() != 0x10000) {
    return {};
  } else {
    return {value_extra->prefetch_ref(), std::move(extra)};
  }
}

Ref<CellSlice> AugmentedDictionary::lookup_with_extra(td::ConstBitPtr key, int key_len) {
  return DictionaryFixed::lookup(key, key_len);
}

Ref<CellSlice> AugmentedDictionary::lookup(td::ConstBitPtr key, int key_len) {
  return extract_value(lookup_with_extra(key, key_len));
}

Ref<Cell> AugmentedDictionary::lookup_ref(td::ConstBitPtr key, int key_len) {
  return extract_value_ref(lookup_with_extra(key, key_len));
}

std::pair<Ref<CellSlice>, Ref<CellSlice>> AugmentedDictionary::lookup_extra(td::ConstBitPtr key, int key_len) {
  return decompose_value_extra(lookup_with_extra(key, key_len));
}

std::pair<Ref<Cell>, Ref<CellSlice>> AugmentedDictionary::lookup_ref_extra(td::ConstBitPtr key, int key_len) {
  return decompose_value_ref_extra(lookup_with_extra(key, key_len));
}

Ref<CellSlice> AugmentedDictionary::lookup_delete_with_extra(td::ConstBitPtr key, int key_len) {
  return DictionaryFixed::lookup_delete(key, key_len);
}

Ref<CellSlice> AugmentedDictionary::lookup_delete(td::ConstBitPtr key, int key_len) {
  return extract_value(lookup_delete_with_extra(key, key_len));
}

Ref<Cell> AugmentedDictionary::lookup_delete_ref(td::ConstBitPtr key, int key_len) {
  return extract_value_ref(lookup_delete_with_extra(key, key_len));
}

std::pair<Ref<CellSlice>, Ref<CellSlice>> AugmentedDictionary::lookup_delete_extra(td::ConstBitPtr key, int key_len) {
  return decompose_value_extra(lookup_delete_with_extra(key, key_len));
}

bool AugmentedDictionary::check_leaf(CellSlice& cs, td::ConstBitPtr key, int key_len) const {
  vm::CellSlice extra;
  return aug.extract_extra_to(cs, extra) && aug.check_leaf_key_extra(cs, extra, key, key_len);
}

bool AugmentedDictionary::check_fork(CellSlice& cs, Ref<Cell> c1, Ref<Cell> c2, int n) const {
  if (n <= 0) {
    return false;
  }
  auto extra1 = get_node_extra(std::move(c1), n - 1);
  auto extra2 = get_node_extra(std::move(c2), n - 1);
  return extra1.not_null() && extra2.not_null() && aug.check_fork(cs, extra1.write(), extra2.write());
}

Ref<Cell> AugmentedDictionary::finish_create_leaf(CellBuilder& cb, const CellSlice& value) const {
  CellSlice value_copy{value};
  if (!aug.eval_leaf(cb, value_copy)) {
    throw VmError{Excno::dict_err, "cannot compute and store extra value into an augmented dictionary cell"};
  }
  if (!cb.append_cellslice_bool(value)) {
    throw VmError{Excno::dict_err, "cannot store new value into an augmented dictionary cell"};
  }
  return cb.finalize();
}

Ref<Cell> AugmentedDictionary::finish_create_fork(CellBuilder& cb, Ref<Cell> c1, Ref<Cell> c2, int n) const {
  assert(n > 0);
  if (!(cb.store_ref_bool(c1) && cb.store_ref_bool(c2))) {
    throw VmError{Excno::dict_err, "cannot store branch references into an augmented dictionary cell"};
  }
  auto extra1 = get_node_extra(std::move(c1), n - 1);
  auto extra2 = get_node_extra(std::move(c2), n - 1);
  if (extra1.is_null()) {
    throw VmError{Excno::dict_err, "cannot extract extra value from left branch of an augmented dictionary fork node"};
  }
  if (extra2.is_null()) {
    throw VmError{Excno::dict_err, "cannot extract extra value from left branch of an augmented dictionary fork node"};
  }
  if (!aug.eval_fork(cb, extra1.write(), extra2.write())) {
    throw VmError{Excno::dict_err, "cannot compute extra value for an augmented dictionary fork node"};
  }
  return cb.finalize();
}

std::pair<Ref<Cell>, bool> AugmentedDictionary::dict_set(Ref<Cell> dict, td::ConstBitPtr key, int n,
                                                         const CellSlice& value, Dictionary::SetMode mode) const {
  //std::cerr << "augmented dictionary modification for " << n << "-bit key = " << key.to_hex(n) << std::endl;
  if (dict.is_null()) {
    // the dictionary is very empty
    if (mode == Dictionary::SetMode::Replace) {
      return std::make_pair<Ref<Cell>, bool>({}, false);
    }
    // create an one-element dictionary
    CellBuilder cb;
    append_dict_label(cb, key, n, n);
    return std::make_pair(finish_create_leaf(cb, value), true);
  }
  LabelParser label{std::move(dict), n, 2};
  label.validate();
  int pfx_len = label.common_prefix_len(key, n);
  assert(pfx_len >= 0 && pfx_len <= label.l_bits && label.l_bits <= n);
  if (pfx_len < label.l_bits) {
    // have to insert a new node (fork) inside the current edge
    if (mode == Dictionary::SetMode::Replace) {
      // key not found, return unchanged dictionary
      return std::make_pair(Ref<Cell>{}, false);
    }
    // first, create the edge + new leaf cell
    int m = n - pfx_len - 1;
    CellBuilder cb;
    append_dict_label(cb, key + (pfx_len + 1), m, m);
    Ref<Cell> c1 = finish_create_leaf(cb, value);  // new leaf cell corresponding to `key`
    //cb.reset();
    // create the lower portion of the old edge
    int t = label.l_bits - pfx_len - 1;
    auto cs = std::move(label.remainder);
    if (label.l_same) {
      append_dict_label_same(cb, label.l_same & 1, t, m);
    } else {
      cs.write().advance(pfx_len + 1);
      append_dict_label(cb, cs->data_bits(), t, m);
      cs.unique_write().advance(t);
    }
    // now cs is the old payload of the edge, either a value or two subdictionary references
    if (!cell_builder_add_slice_bool(cb, *cs)) {
      throw VmError{Excno::cell_ov, "cannot change label of an old augmented dictionary cell (?)"};
    }
    Ref<Cell> c2 = cb.finalize();  // the other child of the new fork
    // cb.reset();
    append_dict_label(cb, key, pfx_len, n);
    bool sw_bit = key[pfx_len];
    if (sw_bit) {
      c1.swap(c2);
    }
    return std::make_pair(finish_create_fork(cb, std::move(c1), std::move(c2), n - pfx_len), true);
  }
  if (label.l_bits == n) {
    // the edge leads to a leaf node
    // this leaf node already contains a value for the key wanted
    if (mode == Dictionary::SetMode::Add) {
      // return unchanged dictionary
      return std::make_pair(Ref<Cell>{}, false);
    }
    // replace the value of the only element of the dictionary
    CellBuilder cb;
    append_dict_label(cb, key, n, n);
    return std::make_pair(finish_create_leaf(cb, value), true);
  }
  // main case: the edge leads to a fork, have to insert new value either in the right or in the left subtree
  auto c1 = label.remainder->prefetch_ref(0);
  auto c2 = label.remainder->prefetch_ref(1);
  label.remainder.clear();
  if (key[label.l_bits]) {
    // insert key into the right child (c2)
    auto res = dict_set(std::move(c2), key + (label.l_bits + 1), n - label.l_bits - 1, value, mode);
    if (!res.second) {
      // return unchanged dictionary
      return std::make_pair(Ref<Cell>{}, false);
    }
    c2 = std::move(res.first);
  } else {
    // insert key into the left child (c1)
    auto res = dict_set(std::move(c1), key + (label.l_bits + 1), n - label.l_bits - 1, value, mode);
    if (!res.second) {
      // return unchanged dictionary
      return std::make_pair(Ref<Cell>{}, false);
    }
    c1 = std::move(res.first);
  }
  // create a new label with the same content
  CellBuilder cb;
  append_dict_label(cb, key, label.l_bits, n);
  return std::make_pair(finish_create_fork(cb, std::move(c1), std::move(c2), n - label.l_bits), true);
}

bool AugmentedDictionary::set(td::ConstBitPtr key, int key_len, Ref<CellSlice> value, SetMode mode) {
  return value.not_null() && set(key, key_len, *value, mode);
}

bool AugmentedDictionary::set(td::ConstBitPtr key, int key_len, const CellSlice& value, SetMode mode) {
  force_validate();
  if (key_len != get_key_bits()) {
    return false;
  }
  auto res = dict_set(get_root_cell(), key, key_len, value, mode);
  if (res.second) {
    //vm::CellSlice cs{vm::NoVm{}, res.first};
    //std::cerr << "new augmented dictionary root is:\n";
    //cs.print_rec(std::cerr);
    set_root_cell(std::move(res.first));
  }
  return res.second;
}

bool AugmentedDictionary::set_ref(td::ConstBitPtr key, int key_len, Ref<Cell> value_ref, SetMode mode) {
  if (value_ref.not_null()) {
    CellBuilder cb;
    cb.store_ref(std::move(value_ref));
    return set(key, key_len, load_cell_slice(cb.finalize()));
  } else {
    return false;
  }
}

bool AugmentedDictionary::set_builder(td::ConstBitPtr key, int key_len, const CellBuilder& value, SetMode mode) {
  return set(key, key_len, load_cell_slice(value.finalize_copy()));
}

bool AugmentedDictionary::check_for_each_extra(const foreach_extra_func_t& foreach_extra_func, bool invert_first) {
  force_validate();
  const auto& augm = aug;
  foreach_func_t foreach_func = [&foreach_extra_func, &augm](Ref<vm::CellSlice> value_extra, td::ConstBitPtr key,
                                                             int key_len) {
    auto extra = augm.extract_extra(value_extra.write());
    return extra.not_null() && foreach_extra_func(std::move(value_extra), std::move(extra), key, key_len);
  };
  return DictionaryFixed::check_for_each(foreach_func, invert_first);
}

std::pair<Ref<CellSlice>, Ref<CellSlice>> AugmentedDictionary::dict_traverse_extra(
    Ref<Cell> dict, td::BitPtr key_buffer, int n, const traverse_func_t& traverse_node) const {
  int m = get_key_bits();
  while (true) {
    CHECK(dict.not_null());
    LabelParser label{std::move(dict), n, 2};
    label.extract_label_to(key_buffer);
    key_buffer += label.l_bits;
    n -= label.l_bits;
    if (n <= 0) {
      // reached a leaf, check it
      assert(!n);
      auto pair = decompose_value_extra(std::move(label.remainder));
      if (pair.first.is_null()) {
        throw VmError{Excno::dict_err, "invalid leaf value/extra in an augmented dictionary"};
      }
      int r = traverse_node(key_buffer - m, m, pair.second /* extra */, pair.first /* value */);
      if (r < 0) {
        throw CombineErrorValue{r};
      } else if (r > 0) {
        return pair;
      } else {
        return {};
      }
    }
    // visit (traverse) fork
    auto c1 = label.remainder.write().fetch_ref(), c2 = label.remainder.write().fetch_ref();
    int r = traverse_node(key_buffer + n - m, m - n, std::move(label.remainder) /* extra */, {});
    if (r < 0 || (r & 3) == 3) {
      throw CombineErrorValue{r};
    } else if (!(r & 3)) {
      return {};
    }
    // r = 1 : visit only left, 2 = visit only right, 5 = visit right, then left, 6 = visit left, then right
    ++key_buffer;
    --n;
    bool sw = r & 1;
    if (sw) {
      std::swap(c1, c2);
    }
    if (r & 4) {
      // have to visit both children in some order; do a recursive call to visit the first child
      key_buffer[-1] = sw;
      auto tmp = dict_traverse_extra(std::move(c1), key_buffer, n, traverse_node);
      if (tmp.first.not_null()) {
        return tmp;
      }
    }
    // visit the remaining child
    key_buffer[-1] = !sw;
    dict = std::move(c2);
  }
}

std::pair<Ref<CellSlice>, Ref<CellSlice>> AugmentedDictionary::traverse_extra(td::BitPtr key_buffer, int key_len,
                                                                              const traverse_func_t& traverse_node) {
  force_validate();
  if (key_len != get_key_bits() || is_empty()) {
    return {};
  }
  return dict_traverse_extra(get_root_cell(), key_buffer, key_len, traverse_node);
}

bool AugmentedDictionary::validate_check_extra(const AugmentedDictionary::foreach_extra_func_t& foreach_extra_func,
                                               bool invert_first) {
  const AugmentationData& augm = aug;
  int key_len = get_key_bits();
  return validate_check(
      [&foreach_extra_func, &augm, key_len](Ref<CellSlice> value_extra, td::ConstBitPtr key, int value) {
        auto extra = augm.extract_extra(value_extra.write());
        return extra.not_null() && foreach_extra_func(std::move(value_extra), std::move(extra), key, key_len);
      },
      invert_first);
}

}  // namespace vm
