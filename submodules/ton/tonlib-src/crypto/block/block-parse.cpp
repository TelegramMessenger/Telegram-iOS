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
#include "td/utils/bits.h"
#include "block/block-parse.h"
#include "block/block-auto.h"
#include "ton/ton-shard.h"
#include "common/util.h"
#include "td/utils/crypto.h"

namespace block {
using namespace std::literals::string_literals;

using CombineError = vm::CombineError;

namespace {
bool debug(const char* str) TD_UNUSED;
bool debug(const char* str) {
  std::cerr << str;
  return true;
}

bool debug(int x) TD_UNUSED;
bool debug(int x) {
  if (x < 100) {
    std::cerr << '[' << (char)(64 + x) << ']';
  } else {
    std::cerr << '[' << (char)(64 + x / 100) << x % 100 << ']';
  }
  return true;
}
}  // namespace

#define DBG_START int dbg = 0;
#define DBG debug(++dbg)&&
#define DEB_START DBG_START
#define DEB DBG

namespace tlb {

using namespace ::tlb;

int MsgAddressExt::get_size(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
    case addr_none:  // 00, addr_none
      return 2;
    case addr_ext:  // 01, addr_extern
      if (cs.have(2 + 9)) {
        int len = cs.prefetch_long(2 + 9) & 0x1ff;
        return 2 + 9 + len;
      }
  }
  return -1;
}

const MsgAddressExt t_MsgAddressExt;

const Anycast t_Anycast;

bool Maybe_Anycast::skip_get_depth(vm::CellSlice& cs, int& depth) const {
  depth = 0;
  bool have;
  return cs.fetch_bool_to(have) && (!have || t_Anycast.skip_get_depth(cs, depth));
}

const Maybe_Anycast t_Maybe_Anycast;

bool MsgAddressInt::validate_skip(vm::CellSlice& cs, bool weak) const {
  if (!cs.have(3)) {
    return false;
  }
  switch (get_tag(cs)) {
    case addr_std:
      return cs.advance(2) && t_Maybe_Anycast.skip(cs) && cs.advance(8 + 256);
    case addr_var:
      if (cs.advance(2) && t_Maybe_Anycast.skip(cs) && cs.have(9 + 32)) {
        int addr_len = (int)cs.fetch_ulong(9);
        int workchain_id = (int)cs.fetch_long(32);
        return cs.advance(addr_len) && (workchain_id < -0x80 || workchain_id > 0x7f || addr_len != 256) &&
               (workchain_id != 0 && workchain_id != -1);
      }
  }
  return false;
}

bool MsgAddressInt::skip_get_depth(vm::CellSlice& cs, int& depth) const {
  if (!cs.have(3)) {
    return false;
  }
  switch (get_tag(cs)) {
    case addr_std:
      return cs.advance(2) && t_Maybe_Anycast.skip_get_depth(cs, depth) && cs.advance(8 + 256);
    case addr_var:
      if (cs.advance(2) && t_Maybe_Anycast.skip_get_depth(cs, depth) && cs.have(9 + 32)) {
        int addr_len = (int)cs.fetch_ulong(9);
        return cs.advance(32 + addr_len);
      }
  }
  return false;
}

ton::AccountIdPrefixFull MsgAddressInt::get_prefix(vm::CellSlice&& cs) {
  if (!cs.have(3 + 8 + 64)) {
    return {};
  }
  ton::WorkchainId workchain;
  unsigned long long prefix;
  int t = (int)cs.prefetch_ulong(2 + 1 + 5);
  switch (t >> 5) {
    case 4: {  // addr_std$10, anycast=nothing$0
      if (cs.advance(3) && cs.fetch_int_to(8, workchain) && cs.fetch_uint_to(64, prefix)) {
        return {workchain, prefix};
      }
      break;
    }
    case 5: {   // addr_std$10, anycast=just$1 (Anycast)
      t &= 31;  // depth:(## 5)
      unsigned long long rewrite;
      if (cs.advance(8) && cs.fetch_uint_to(t, rewrite)  // rewrite_pfx:(bits depth)
          && cs.fetch_int_to(8, workchain)               // workchain_id:int8
          && cs.fetch_uint_to(64, prefix)) {             // address:bits256
        rewrite <<= 64 - t;
        return {workchain, (prefix & (std::numeric_limits<td::uint64>::max() >> t)) | rewrite};
      }
      break;
    }
    case 6: {  // addr_var$11, anycast=nothing$0
      int len;
      if (cs.advance(3) && cs.fetch_uint_to(9, len)  // addr_len:(## 9)
          && len >= 64                               // { len >= 64 }
          && cs.fetch_int_to(32, workchain)          // workchain_id:int32
          && cs.fetch_uint_to(64, prefix)) {         // address:(bits addr_len)
        return {workchain, prefix};
      }
      break;
    }
    case 7: {   // addr_var$11, anycast=just$1 (Anycast)
      t &= 31;  // depth:(## 5)
      int len;
      unsigned long long rewrite;
      if (cs.advance(8) && cs.fetch_uint_to(t, rewrite)  // rewrite_pfx:(bits depth)
          && cs.fetch_uint_to(9, len)                    // addr_len:(## 9)
          && len >= 64                                   // { len >= 64 }
          && cs.fetch_int_to(32, workchain)              // workchain_id:int32
          && cs.fetch_uint_to(64, prefix)) {             // address:bits256
        rewrite <<= 64 - t;
        return {workchain, (prefix & (std::numeric_limits<td::uint64>::max() >> t)) | rewrite};
      }
      break;
    }
  }
  return {};
}

ton::AccountIdPrefixFull MsgAddressInt::get_prefix(const vm::CellSlice& cs) {
  return get_prefix(vm::CellSlice{cs});
}

ton::AccountIdPrefixFull MsgAddressInt::get_prefix(Ref<vm::CellSlice> cs_ref) {
  if (cs_ref->is_unique()) {
    return get_prefix(std::move(cs_ref.unique_write()));
  } else {
    return get_prefix(vm::CellSlice{*cs_ref});
  }
}

bool MsgAddressInt::extract_std_address(Ref<vm::CellSlice> cs_ref, ton::WorkchainId& workchain,
                                        ton::StdSmcAddress& addr, bool rewrite) const {
  if (cs_ref.is_null()) {
    return false;
  } else if (cs_ref->is_unique()) {
    return extract_std_address(cs_ref.unique_write(), workchain, addr, rewrite);
  } else {
    vm::CellSlice cs{*cs_ref};
    return extract_std_address(cs, workchain, addr, rewrite);
  }
}

bool MsgAddressInt::extract_std_address(vm::CellSlice& cs, ton::WorkchainId& workchain, ton::StdSmcAddress& addr,
                                        bool do_rewrite) const {
  if (!cs.have(3 + 8 + 64)) {
    return {};
  }
  int t = (int)cs.prefetch_ulong(2 + 1 + 5);
  switch (t >> 5) {
    case 4: {  // addr_std$10, anycast=nothing$0
      return cs.advance(3) && cs.fetch_int_to(8, workchain) && cs.fetch_bits_to(addr);
    }
    case 5: {   // addr_std$10, anycast=just$1 (Anycast)
      t &= 31;  // depth:(## 5)
      unsigned long long rewrite;
      if (cs.advance(8) && cs.fetch_uint_to(t, rewrite)  // rewrite_pfx:(bits depth)
          && cs.fetch_int_to(8, workchain)               // workchain_id:int8
          && cs.fetch_bits_to(addr)) {                   // address:bits256
        if (do_rewrite) {
          addr.bits().store_uint(rewrite, t);
        }
        return true;
      }
      break;
    }
    case 6: {  // addr_var$11, anycast=nothing$0
      int len;
      return cs.advance(3) && cs.fetch_uint_to(9, len)  // addr_len:(## 9)
             && len == 256                              // only 256-bit addresses are standard
             && cs.fetch_int_to(32, workchain)          // workchain_id:int32
             && cs.fetch_bits_to(addr);                 // address:(bits addr_len)
    }
    case 7: {   // addr_var$11, anycast=just$1 (Anycast)
      t &= 31;  // depth:(## 5)
      int len;
      unsigned long long rewrite;
      if (cs.advance(8) && cs.fetch_uint_to(t, rewrite)  // rewrite_pfx:(bits depth)
          && cs.fetch_uint_to(9, len)                    // addr_len:(## 9)
          && len == 256                                  // only 256-bit addresses are standard
          && cs.fetch_int_to(32, workchain)              // workchain_id:int32
          && cs.fetch_bits_to(addr)) {                   // address:bits256
        if (do_rewrite) {
          addr.bits().store_uint(rewrite, t);
        }
        return true;
      }
      break;
    }
  }
  return false;
}

const MsgAddressInt t_MsgAddressInt;

bool MsgAddress::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
    case addr_none:
    case addr_ext:
      return t_MsgAddressExt.validate_skip(cs, weak);
    case addr_std:
    case addr_var:
      return t_MsgAddressInt.validate_skip(cs, weak);
  }
  return false;
}

const MsgAddress t_MsgAddress;

bool VarUInteger::skip(vm::CellSlice& cs) const {
  int len = (int)cs.fetch_ulong(ln);
  return len >= 0 && len < n && cs.advance(len * 8);
}

bool VarUInteger::validate_skip(vm::CellSlice& cs, bool weak) const {
  int len = (int)cs.fetch_ulong(ln);
  return len >= 0 && len < n && (!len || cs.prefetch_ulong(8)) && cs.advance(len * 8);
}

td::RefInt256 VarUInteger::as_integer_skip(vm::CellSlice& cs) const {
  int len = (int)cs.fetch_ulong(ln);
  return (len >= 0 && len < n && (!len || cs.prefetch_ulong(8))) ? cs.fetch_int256(len * 8, false) : td::RefInt256{};
}

unsigned long long VarUInteger::as_uint(const vm::CellSlice& cs) const {
  int len = (int)cs.prefetch_ulong(ln);
  return len >= 0 && len <= 8 && cs.have(ln + len * 8) ? td::bitstring::bits_load_ulong(cs.data_bits() + ln, len * 8)
                                                       : std::numeric_limits<td::uint64>::max();
}

bool VarUInteger::store_integer_value(vm::CellBuilder& cb, const td::BigInt256& value) const {
  int k = value.bit_size(false);
  return k <= (n - 1) * 8 && cb.store_long_bool((k + 7) >> 3, ln) && cb.store_int256_bool(value, (k + 7) & -8, false);
}

unsigned VarUInteger::precompute_integer_size(const td::BigInt256& value) const {
  int k = value.bit_size(false);
  return k <= (n - 1) * 8 ? ln + ((k + 7) & -8) : 0xfff;
}

unsigned VarUInteger::precompute_integer_size(td::RefInt256 value) const {
  if (value.is_null()) {
    return 0xfff;
  }
  int k = value->bit_size(false);
  return k <= (n - 1) * 8 ? ln + ((k + 7) & -8) : 0xfff;
}

const VarUInteger t_VarUInteger_3{3}, t_VarUInteger_7{7}, t_VarUInteger_16{16}, t_VarUInteger_32{32};

bool VarUIntegerPos::skip(vm::CellSlice& cs) const {
  int len = (int)cs.fetch_ulong(ln);
  return len > 0 && len < n && cs.advance(len * 8);
}

bool VarUIntegerPos::validate_skip(vm::CellSlice& cs, bool weak) const {
  int len = (int)cs.fetch_ulong(ln);
  return len > 0 && len < n && cs.prefetch_ulong(8) && cs.advance(len * 8);
}

td::RefInt256 VarUIntegerPos::as_integer_skip(vm::CellSlice& cs) const {
  int len = (int)cs.fetch_ulong(ln);
  return (len > 0 && len < n && cs.prefetch_ulong(8)) ? cs.fetch_int256(len * 8, false) : td::RefInt256{};
}

unsigned long long VarUIntegerPos::as_uint(const vm::CellSlice& cs) const {
  int len = (int)cs.prefetch_ulong(ln);
  return len > 0 && len <= 8 && cs.have(ln + len * 8) && cs.prefetch_ulong(8)
             ? td::bitstring::bits_load_ulong(cs.data_bits() + ln, len * 8)
             : std::numeric_limits<td::uint64>::max();
}

bool VarUIntegerPos::store_integer_value(vm::CellBuilder& cb, const td::BigInt256& value) const {
  int k = value.bit_size(false);
  return k <= (n - 1) * 8 && value.sgn() > 0 && cb.store_long_bool((k + 7) >> 3, ln) &&
         cb.store_int256_bool(value, (k + 7) & -8, false);
}

const VarUIntegerPos t_VarUIntegerPos_16{16}, t_VarUIntegerPos_32{32};

static inline bool redundant_int(const vm::CellSlice& cs) {
  int t = (int)cs.prefetch_long(9);
  return t == 0 || t == -1;
}

bool VarInteger::skip(vm::CellSlice& cs) const {
  int len = (int)cs.fetch_ulong(ln);
  return len >= 0 && len < n && cs.advance(len * 8);
}

bool VarInteger::validate_skip(vm::CellSlice& cs, bool weak) const {
  int len = (int)cs.fetch_ulong(ln);
  return len >= 0 && len < n && (!len || !redundant_int(cs)) && cs.advance(len * 8);
}

td::RefInt256 VarInteger::as_integer_skip(vm::CellSlice& cs) const {
  int len = (int)cs.fetch_ulong(ln);
  return (len >= 0 && len < n && (!len || !redundant_int(cs))) ? cs.fetch_int256(len * 8, true) : td::RefInt256{};
}

long long VarInteger::as_int(const vm::CellSlice& cs) const {
  int len = (int)cs.prefetch_ulong(ln);
  return len >= 0 && len <= 8 && cs.have(ln + len * 8) ? td::bitstring::bits_load_long(cs.data_bits() + ln, len * 8)
                                                       : (1ULL << 63);
}

bool VarInteger::store_integer_value(vm::CellBuilder& cb, const td::BigInt256& value) const {
  int k = value.bit_size(true);
  return k <= (n - 1) * 8 && cb.store_long_bool((k + 7) >> 3, ln) && cb.store_int256_bool(value, (k + 7) & -8, true);
}

bool VarIntegerNz::skip(vm::CellSlice& cs) const {
  int len = (int)cs.fetch_ulong(ln);
  return len > 0 && len < n && cs.advance(len * 8);
}

bool VarIntegerNz::validate_skip(vm::CellSlice& cs, bool weak) const {
  int len = (int)cs.fetch_ulong(ln);
  return len > 0 && len < n && !redundant_int(cs) && cs.advance(len * 8);
}

td::RefInt256 VarIntegerNz::as_integer_skip(vm::CellSlice& cs) const {
  int len = (int)cs.fetch_ulong(ln);
  return (len > 0 && len < n && !redundant_int(cs)) ? cs.fetch_int256(len * 8, true) : td::RefInt256{};
}

long long VarIntegerNz::as_int(const vm::CellSlice& cs) const {
  int len = (int)cs.prefetch_ulong(ln);
  return len > 0 && len <= 8 && cs.have(ln + len * 8) && !redundant_int(cs)
             ? td::bitstring::bits_load_long(cs.data_bits() + ln, len * 8)
             : (1ULL << 63);
}

bool VarIntegerNz::store_integer_value(vm::CellBuilder& cb, const td::BigInt256& value) const {
  int k = value.bit_size(true);
  return k <= (n - 1) * 8 && value.sgn() != 0 && cb.store_long_bool((k + 7) >> 3, ln) &&
         cb.store_int256_bool(value, (k + 7) & -8, true);
}

bool Grams::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_VarUInteger_16.validate_skip(cs, weak);
}

td::RefInt256 Grams::as_integer_skip(vm::CellSlice& cs) const {
  return t_VarUInteger_16.as_integer_skip(cs);
}

bool Grams::null_value(vm::CellBuilder& cb) const {
  return t_VarUInteger_16.null_value(cb);
}

bool Grams::store_integer_value(vm::CellBuilder& cb, const td::BigInt256& value) const {
  return t_VarUInteger_16.store_integer_value(cb, value);
}

unsigned Grams::precompute_size(const td::BigInt256& value) const {
  return t_VarUInteger_16.precompute_integer_size(value);
}

unsigned Grams::precompute_size(td::RefInt256 value) const {
  return t_VarUInteger_16.precompute_integer_size(std::move(value));
}

const Grams t_Grams;

const Unary t_Unary;

bool HmLabel::validate_skip(vm::CellSlice& cs, bool weak, int& n) const {
  switch (get_tag(cs)) {
    case hml_short:
      return cs.advance(1) && (n = cs.count_leading(1)) <= m && cs.advance(2 * n + 1);
    case hml_long:
      return cs.advance(2) && cs.fetch_uint_leq(m, n) && cs.advance(n);
    case hml_same:
      return cs.advance(3) && cs.fetch_uint_leq(m, n);
  }
  return false;
}

int HmLabel::get_tag(const vm::CellSlice& cs) const {
  int tag = (int)cs.prefetch_ulong(2);
  return tag != 1 ? tag : hml_short;
}

int HashmapNode::get_size(const vm::CellSlice& cs) const {
  assert(n >= 0);
  return n ? 0x20000 : value_type.get_size(cs);
}

bool HashmapNode::skip(vm::CellSlice& cs) const {
  assert(n >= 0);
  return n ? cs.advance_refs(2) : value_type.skip(cs);
}

bool HashmapNode::validate_skip(vm::CellSlice& cs, bool weak) const {
  assert(n >= 0);
  if (!n) {
    // hmn_leaf
    return value_type.validate_skip(cs, weak);
  } else {
    // hmn_fork
    Hashmap branch_type{n - 1, value_type};
    return branch_type.validate_ref(cs.fetch_ref(), weak) && branch_type.validate_ref(cs.fetch_ref(), weak);
  }
}

bool Hashmap::skip(vm::CellSlice& cs) const {
  int l;
  return HmLabel{n}.skip(cs, l) && HashmapNode{n - l, value_type}.skip(cs);
}

bool Hashmap::validate_skip(vm::CellSlice& cs, bool weak) const {
  int l;
  return HmLabel{n}.validate_skip(cs, weak, l) && HashmapNode{n - l, value_type}.validate_skip(cs, weak);
}

int HashmapE::get_size(const vm::CellSlice& cs) const {
  int tag = get_tag(cs);
  return (tag >= 0 ? (tag > 0 ? 0x10001 : 1) : -1);
}

bool HashmapE::validate(const vm::CellSlice& cs, bool weak) const {
  int tag = get_tag(cs);
  return tag <= 0 ? !tag : root_type.validate_ref(cs.prefetch_ref(), weak);
}

bool HashmapE::add_values(vm::CellBuilder& cb, vm::CellSlice& cs1, vm::CellSlice& cs2) const {
  int n = root_type.n;
  vm::Dictionary dict1{vm::DictAdvance(), cs1, n}, dict2{vm::DictAdvance(), cs2, n};
  const TLB& vt = root_type.value_type;
  vm::Dictionary::simple_combine_func_t combine = [vt](vm::CellBuilder& cb, Ref<vm::CellSlice> cs1_ref,
                                                       Ref<vm::CellSlice> cs2_ref) -> bool {
    if (!vt.add_values(cb, cs1_ref.write(), cs2_ref.write())) {
      throw CombineError{};
    }
    return true;
  };
  return dict1.combine_with(dict2, combine) && std::move(dict1).append_dict_to_bool(cb);
}

bool HashmapE::add_values_ref(Ref<vm::Cell>& res, Ref<vm::Cell> arg1, Ref<vm::Cell> arg2) const {
  int n = root_type.n;
  vm::Dictionary dict1{std::move(arg1), n}, dict2{std::move(arg2), n};
  const TLB& vt = root_type.value_type;
  vm::Dictionary::simple_combine_func_t combine = [vt](vm::CellBuilder& cb, Ref<vm::CellSlice> cs1_ref,
                                                       Ref<vm::CellSlice> cs2_ref) -> bool {
    if (!vt.add_values(cb, cs1_ref.write(), cs2_ref.write())) {
      throw CombineError{};
    }
    return true;
  };
  if (dict1.combine_with(dict2, combine)) {
    dict2.reset();
    res = std::move(dict1).extract_root_cell();
    return true;
  } else {
    res = Ref<vm::Cell>{};
    return false;
  }
}

int HashmapE::sub_values(vm::CellBuilder& cb, vm::CellSlice& cs1, vm::CellSlice& cs2) const {
  int n = root_type.n;
  vm::Dictionary dict1{vm::DictAdvance(), cs1, n}, dict2{vm::DictAdvance(), cs2, n};
  const TLB& vt = root_type.value_type;
  vm::Dictionary::simple_combine_func_t combine = [vt](vm::CellBuilder& cb, Ref<vm::CellSlice> cs1_ref,
                                                       Ref<vm::CellSlice> cs2_ref) -> bool {
    int r = vt.sub_values(cb, cs1_ref.write(), cs2_ref.write());
    if (r < 0) {
      throw CombineError{};
    }
    return r;
  };
  if (!dict1.combine_with(dict2, combine, 1)) {
    return -1;
  }
  dict2.reset();
  bool not_empty = !dict1.is_empty();
  return std::move(dict1).append_dict_to_bool(cb) ? not_empty : -1;
}

int HashmapE::sub_values_ref(Ref<vm::Cell>& res, Ref<vm::Cell> arg1, Ref<vm::Cell> arg2) const {
  int n = root_type.n;
  vm::Dictionary dict1{std::move(arg1), n}, dict2{std::move(arg2), n};
  const TLB& vt = root_type.value_type;
  vm::Dictionary::simple_combine_func_t combine = [vt](vm::CellBuilder& cb, Ref<vm::CellSlice> cs1_ref,
                                                       Ref<vm::CellSlice> cs2_ref) -> bool {
    int r = vt.sub_values(cb, cs1_ref.write(), cs2_ref.write());
    if (r < 0) {
      throw CombineError{};
    }
    return r;
  };
  if (dict1.combine_with(dict2, combine, 1)) {
    dict2.reset();
    res = std::move(dict1).extract_root_cell();
    return res.not_null();
  } else {
    res = Ref<vm::Cell>{};
    return -1;
  }
}

bool HashmapE::store_ref(vm::CellBuilder& cb, Ref<vm::Cell> arg) const {
  if (arg.is_null()) {
    return cb.store_long_bool(0, 1);
  } else {
    return cb.store_long_bool(1, 1) && cb.store_ref_bool(std::move(arg));
  }
}

const ExtraCurrencyCollection t_ExtraCurrencyCollection;

bool CurrencyCollection::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Grams.validate_skip(cs, weak) && t_ExtraCurrencyCollection.validate_skip(cs, weak);
}

bool CurrencyCollection::skip(vm::CellSlice& cs) const {
  return t_Grams.skip(cs) && t_ExtraCurrencyCollection.skip(cs);
}

td::RefInt256 CurrencyCollection::as_integer_skip(vm::CellSlice& cs) const {
  auto res = t_Grams.as_integer_skip(cs);
  if (res.not_null() && t_ExtraCurrencyCollection.skip(cs)) {
    return res;
  } else {
    return {};
  }
}

bool CurrencyCollection::add_values(vm::CellBuilder& cb, vm::CellSlice& cs1, vm::CellSlice& cs2) const {
  return t_Grams.add_values(cb, cs1, cs2) && t_ExtraCurrencyCollection.add_values(cb, cs1, cs2);
}

bool CurrencyCollection::unpack_special(vm::CellSlice& cs, td::RefInt256& balance, Ref<vm::Cell>& extra,
                                        bool inexact) const {
  balance = t_Grams.as_integer_skip(cs);
  if (cs.fetch_ulong(1) == 1) {
    return balance.not_null() && cs.fetch_ref_to(extra) && (inexact || cs.empty_ext());
  } else {
    extra.clear();
    return balance.not_null() && (inexact || cs.empty_ext());
  }
}

bool CurrencyCollection::unpack_special(vm::CellSlice& cs, block::CurrencyCollection& value, bool inexact) const {
  return unpack_special(cs, value.grams, value.extra, inexact);
}

bool CurrencyCollection::pack_special(vm::CellBuilder& cb, td::RefInt256 balance, Ref<vm::Cell> extra) const {
  return t_Grams.store_integer_ref(cb, std::move(balance)) && t_ExtraCurrencyCollection.store_ref(cb, std::move(extra));
}

bool CurrencyCollection::pack_special(vm::CellBuilder& cb, const block::CurrencyCollection& value) const {
  return value.is_valid() && pack_special(cb, value.grams, value.extra);
}

bool CurrencyCollection::pack_special(vm::CellBuilder& cb, block::CurrencyCollection&& value) const {
  return value.is_valid() && pack_special(cb, std::move(value.grams), std::move(value.extra));
}

bool CurrencyCollection::unpack(vm::CellSlice& cs, block::CurrencyCollection& res) const {
  return unpack_special(cs, res.grams, res.extra);
}

bool CurrencyCollection::pack(vm::CellBuilder& cb, const block::CurrencyCollection& res) const {
  return res.is_valid() && pack_special(cb, res.grams, res.extra);
}

const CurrencyCollection t_CurrencyCollection;

bool CommonMsgInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  int tag = get_tag(cs);
  switch (tag) {
    case int_msg_info:
      return cs.advance(4)                               // int_msg_info$0 ihr_disabled:Bool bounce:Bool bounced:Bool
             && t_MsgAddressInt.validate_skip(cs, weak)  // src
             && t_MsgAddressInt.validate_skip(cs, weak)  // dest
             && t_CurrencyCollection.validate_skip(cs, weak)  // value
             && t_Grams.validate_skip(cs, weak)               // ihr_fee
             && t_Grams.validate_skip(cs, weak)               // fwd_fee
             && cs.advance(64 + 32);                          // created_lt:uint64 created_at:uint32
    case ext_in_msg_info:
      return cs.advance(2) && t_MsgAddressExt.validate_skip(cs, weak)  // src
             && t_MsgAddressInt.validate_skip(cs, weak)                // dest
             && t_Grams.validate_skip(cs, weak);                       // import_fee
    case ext_out_msg_info:
      return cs.advance(2) && t_MsgAddressInt.validate_skip(cs, weak)  // src
             && t_MsgAddressExt.validate_skip(cs, weak)                // dest
             && cs.advance(64 + 32);                                   // created_lt:uint64 created_at:uint32
  }
  return false;
}

bool CommonMsgInfo::unpack(vm::CellSlice& cs, CommonMsgInfo::Record_int_msg_info& data) const {
  return get_tag(cs) == int_msg_info && cs.advance(1) && cs.fetch_bool_to(data.ihr_disabled) &&
         cs.fetch_bool_to(data.bounce) && cs.fetch_bool_to(data.bounced) && t_MsgAddressInt.fetch_to(cs, data.src) &&
         t_MsgAddressInt.fetch_to(cs, data.dest) && t_CurrencyCollection.fetch_to(cs, data.value) &&
         t_Grams.fetch_to(cs, data.ihr_fee) && t_Grams.fetch_to(cs, data.fwd_fee) &&
         cs.fetch_uint_to(64, data.created_lt) && cs.fetch_uint_to(32, data.created_at);
}

bool CommonMsgInfo::skip(vm::CellSlice& cs) const {
  int tag = get_tag(cs);
  switch (tag) {
    case int_msg_info:
      return cs.advance(4)                     // int_msg_info$0 ihr_disabled:Bool bounce:Bool bounced:Bool
             && t_MsgAddressInt.skip(cs)       // src
             && t_MsgAddressInt.skip(cs)       // dest
             && t_CurrencyCollection.skip(cs)  // value
             && t_Grams.skip(cs)               // ihr_fee
             && t_Grams.skip(cs)               // fwd_fee
             && cs.advance(64 + 32);           // created_lt:uint64 created_at:uint32
    case ext_in_msg_info:
      return cs.advance(2) && t_MsgAddressExt.skip(cs)  // src
             && t_MsgAddressInt.skip(cs)                // dest
             && t_Grams.skip(cs);                       // import_fee
    case ext_out_msg_info:
      return cs.advance(2) && t_MsgAddressInt.skip(cs)  // src
             && t_MsgAddressExt.skip(cs)                // dest
             && cs.advance(64 + 32);                    // created_lt:uint64 created_at:uint32
  }
  return false;
}

bool CommonMsgInfo::get_created_lt(vm::CellSlice& cs, unsigned long long& created_lt) const {
  switch (get_tag(cs)) {
    case int_msg_info:
      return cs.advance(4)                           // int_msg_info$0 ihr_disabled:Bool bounce:Bool bounced:Bool
             && t_MsgAddressInt.skip(cs)             // src
             && t_MsgAddressInt.skip(cs)             // dest
             && t_CurrencyCollection.skip(cs)        // value
             && t_Grams.skip(cs)                     // ihr_fee
             && t_Grams.skip(cs)                     // fwd_fee
             && cs.fetch_ulong_bool(64, created_lt)  // created_lt:uint64
             && cs.advance(32);                      // created_at:uint32
    case ext_in_msg_info:
      return false;
    case ext_out_msg_info:
      return cs.advance(2) && t_MsgAddressInt.skip(cs)  // src
             && t_MsgAddressExt.skip(cs)                // dest
             && cs.fetch_ulong_bool(64, created_lt)     // created_lt:uint64
             && cs.advance(32);                         // created_at:uint32
  }
  return false;
}

const CommonMsgInfo t_CommonMsgInfo;
const TickTock t_TickTock;
const RefAnything t_RefCell;

bool StateInit::validate_skip(vm::CellSlice& cs, bool weak) const {
  return Maybe<UInt>{5}.validate_skip(cs, weak)            // split_depth:(Maybe (## 5))
         && Maybe<TickTock>{}.validate_skip(cs, weak)      // special:(Maybe TickTock)
         && Maybe<RefAnything>{}.validate_skip(cs, weak)   // code:(Maybe ^Cell)
         && Maybe<RefAnything>{}.validate_skip(cs, weak)   // data:(Maybe ^Cell)
         && Maybe<RefAnything>{}.validate_skip(cs, weak);  // library:(Maybe ^Cell)
}

bool StateInit::get_ticktock(vm::CellSlice& cs, int& ticktock) const {
  bool have_tt;
  ticktock = 0;
  return Maybe<UInt>{5}.validate_skip(cs) && cs.fetch_bool_to(have_tt) && (!have_tt || cs.fetch_uint_to(2, ticktock));
}

const StateInit t_StateInit;

bool Message::validate_skip(vm::CellSlice& cs, bool weak) const {
  static const Maybe<Either<StateInit, RefTo<StateInit>>> init_type;
  static const Either<Anything, RefAnything> body_type;
  return t_CommonMsgInfo.validate_skip(cs, weak)  // info:CommonMsgInfo
         && init_type.validate_skip(cs, weak)     // init:(Maybe (Either StateInit ^StateInit))
         && body_type.validate_skip(cs, weak);    // body:(Either X ^X)
}

bool Message::extract_info(vm::CellSlice& cs) const {
  return t_CommonMsgInfo.extract(cs);
}

bool Message::get_created_lt(vm::CellSlice& cs, unsigned long long& created_lt) const {
  return t_CommonMsgInfo.get_created_lt(cs, created_lt);
}

bool Message::is_internal(Ref<vm::Cell> ref) const {
  return is_internal(load_cell_slice(std::move(ref)));
}

const Message t_Message;
const RefTo<Message> t_Ref_Message;

bool IntermediateAddress::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
    case interm_addr_regular:
      return cs.advance(1) && cs.fetch_ulong(7) <= 96U;
    case interm_addr_simple:
      return cs.advance(2 + 8 + 64);
    case interm_addr_ext:
      if (cs.have(2 + 32 + 64)) {
        cs.advance(2);
        int workchain_id = (int)cs.fetch_long(32);
        return (workchain_id < -128 || workchain_id >= 128) && cs.advance(64);
      }
      // no break
  }
  return false;
}

bool IntermediateAddress::skip(vm::CellSlice& cs) const {
  return cs.advance(get_size(cs));
}

int IntermediateAddress::get_size(const vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
    case interm_addr_regular:
      return 1 + 7;
    case interm_addr_simple:
      return 2 + 8 + 64;
    case interm_addr_ext:
      return 2 + 32 + 64;
  }
  return -1;
}

const IntermediateAddress t_IntermediateAddress;

bool MsgEnvelope::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(4) == 4                            // msg_envelope#4
         && t_IntermediateAddress.validate_skip(cs, weak)  // cur_addr:IntermediateAddress
         && t_IntermediateAddress.validate_skip(cs, weak)  // next_addr:IntermediateAddress
         && t_Grams.validate_skip(cs, weak)                // fwd_fee_remaining:Grams
         && t_Ref_Message.validate_skip(cs, weak);         // msg:^Message
}

bool MsgEnvelope::skip(vm::CellSlice& cs) const {
  return cs.advance(4)                      // msg_envelope#4
         && t_IntermediateAddress.skip(cs)  // cur_addr:IntermediateAddress
         && t_IntermediateAddress.skip(cs)  // next_addr:IntermediateAddress
         && t_Grams.skip(cs)                // fwd_fee_remaining:Grams
         && t_Ref_Message.skip(cs);         // msg:^Message
}

bool MsgEnvelope::extract_fwd_fees_remaining(vm::CellSlice& cs) const {
  return t_IntermediateAddress.skip(cs) && t_IntermediateAddress.skip(cs) && t_Grams.extract(cs);
}

bool MsgEnvelope::unpack(vm::CellSlice& cs, MsgEnvelope::Record& data) const {
  return cs.fetch_ulong(4) == 4                                 // msg_envelope#4
         && t_IntermediateAddress.fetch_to(cs, data.cur_addr)   // cur_addr:IntermediateAddress
         && t_IntermediateAddress.fetch_to(cs, data.next_addr)  // next_addr:IntermediateAddress
         && t_Grams.fetch_to(cs, data.fwd_fee_remaining)        // fwd_fee_remaining:Grams
         && cs.fetch_ref_to(data.msg);                          // msg:^Message
}

bool MsgEnvelope::unpack(vm::CellSlice& cs, MsgEnvelope::Record_std& data) const {
  return cs.fetch_ulong(4) == 4                                      // msg_envelope#4
         && t_IntermediateAddress.fetch_regular(cs, data.cur_addr)   // cur_addr:IntermediateAddress
         && t_IntermediateAddress.fetch_regular(cs, data.next_addr)  // next_addr:IntermediateAddress
         && t_Grams.as_integer_skip_to(cs, data.fwd_fee_remaining)   // fwd_fee_remaining:Grams
         && cs.fetch_ref_to(data.msg);                               // msg:^Message
}

bool MsgEnvelope::unpack_std(vm::CellSlice& cs, int& cur_a, int& nhop_a, Ref<vm::Cell>& msg) const {
  return cs.fetch_ulong(4) == 4                              // msg_envelope#4
         && t_IntermediateAddress.fetch_regular(cs, cur_a)   // cur_addr:IntermediateAddress
         && t_IntermediateAddress.fetch_regular(cs, nhop_a)  // next_addr:IntermediateAddress
         && cs.fetch_ref_to(msg);
}

bool MsgEnvelope::get_created_lt(const vm::CellSlice& cs, unsigned long long& created_lt) const {
  if (!cs.size_refs()) {
    return false;
  }
  auto msg_cs = load_cell_slice(cs.prefetch_ref());
  return t_Message.get_created_lt(msg_cs, created_lt);
}

const MsgEnvelope t_MsgEnvelope;
const RefTo<MsgEnvelope> t_Ref_MsgEnvelope;

bool StorageUsed::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_VarUInteger_7.validate_skip(cs, weak)      // cells:(VarUInteger 7)
         && t_VarUInteger_7.validate_skip(cs, weak)   // bits:(VarUInteger 7)
         && t_VarUInteger_7.validate_skip(cs, weak);  // public_cells:(VarUInteger 7)
}

bool StorageUsed::skip(vm::CellSlice& cs) const {
  return t_VarUInteger_7.skip(cs)      // cells:(VarUInteger 7)
         && t_VarUInteger_7.skip(cs)   // bits:(VarUInteger 7)
         && t_VarUInteger_7.skip(cs);  // public_cells:(VarUInteger 7)
}

const StorageUsed t_StorageUsed;

bool StorageUsedShort::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_VarUInteger_7.validate_skip(cs, weak)      // cells:(VarUInteger 7)
         && t_VarUInteger_7.validate_skip(cs, weak);  // bits:(VarUInteger 7)
}

bool StorageUsedShort::skip(vm::CellSlice& cs) const {
  return t_VarUInteger_7.skip(cs)      // cells:(VarUInteger 7)
         && t_VarUInteger_7.skip(cs);  // bits:(VarUInteger 7)
}

const StorageUsedShort t_StorageUsedShort;

const Maybe<Grams> t_Maybe_Grams;

bool StorageInfo::skip(vm::CellSlice& cs) const {
  return t_StorageUsed.skip(cs)      // used:StorageUsed
         && cs.advance(32)           // last_paid:uint32
         && t_Maybe_Grams.skip(cs);  // due_payment:(Maybe Grams)
}

bool StorageInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_StorageUsed.validate_skip(cs, weak)      // used:StorageUsed
         && cs.advance(32)                          // last_paid:uint32
         && t_Maybe_Grams.validate_skip(cs, weak);  // due_payment:(Maybe Grams)
}

const StorageInfo t_StorageInfo;

bool AccountState::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
    case account_uninit:
      return cs.advance(2);
    case account_frozen:
      return cs.advance(2 + 256);
    case account_active:
      return cs.advance(1) && t_StateInit.validate_skip(cs, weak);
  }
  return false;
}

bool AccountState::get_ticktock(vm::CellSlice& cs, int& ticktock) const {
  if (get_tag(cs) != account_active) {
    ticktock = 0;
    return true;
  }
  return cs.advance(1) && t_StateInit.get_ticktock(cs, ticktock);
}

const AccountState t_AccountState;

bool AccountStorage::skip(vm::CellSlice& cs) const {
  return cs.advance(64) && t_CurrencyCollection.skip(cs) && t_AccountState.skip(cs);
}

bool AccountStorage::skip_copy_balance(vm::CellBuilder& cb, vm::CellSlice& cs) const {
  return cs.advance(64) && t_CurrencyCollection.skip_copy(cb, cs) && t_AccountState.skip(cs);
}

bool AccountStorage::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance(64) && t_CurrencyCollection.validate_skip(cs, weak) && t_AccountState.validate_skip(cs, weak);
}

const AccountStorage t_AccountStorage;

bool Account::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
    case account_none:
      return cs.advance(1);
    case account:
      return cs.advance(1)                  // account$1
             && t_MsgAddressInt.skip(cs)    // addr:MsgAddressInt
             && t_StorageInfo.skip(cs)      // storage_stat:StorageInfo
             && t_AccountStorage.skip(cs);  // storage:AccountStorage
  }
  return false;
}

bool Account::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
    case account_none:
      return allow_empty && cs.advance(1);
    case account:
      return cs.advance(1)                                 // account$1
             && t_MsgAddressInt.validate_skip(cs, weak)    // addr:MsgAddressInt
             && t_StorageInfo.validate_skip(cs, weak)      // storage_stat:StorageInfo
             && t_AccountStorage.validate_skip(cs, weak);  // storage:AccountStorage
  }
  return false;
}

bool Account::skip_copy_balance(vm::CellBuilder& cb, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
    case account_none:
      return allow_empty && cs.advance(1) && t_CurrencyCollection.null_value(cb);
    case account:
      return cs.advance(1)                                   // account$1
             && t_MsgAddressInt.skip(cs)                     // addr:MsgAddressInt
             && t_StorageInfo.skip(cs)                       // storage_stat:StorageInfo
             && t_AccountStorage.skip_copy_balance(cb, cs);  // storage:AccountStorage
  }
  return false;
}

bool Account::skip_copy_depth_balance(vm::CellBuilder& cb, vm::CellSlice& cs) const {
  int depth;
  switch (get_tag(cs)) {
    case account_none:
      return allow_empty && cs.advance(1) && t_DepthBalanceInfo.null_value(cb);
    case account:
      return cs.advance(1)                                   // account$1
             && t_MsgAddressInt.skip_get_depth(cs, depth)    // addr:MsgAddressInt
             && cb.store_uint_leq(30, depth)                 // -> store split_depth:(#<= 30)
             && t_StorageInfo.skip(cs)                       // storage_stat:StorageInfo
             && t_AccountStorage.skip_copy_balance(cb, cs);  // storage:AccountStorage
  }
  return false;
}

const Account t_Account, t_AccountE{true};
const RefTo<Account> t_Ref_Account;

bool ShardAccount::extract_account_state(Ref<vm::CellSlice> cs_ref, Ref<vm::Cell>& acc_state) {
  if (cs_ref.is_null()) {
    vm::CellBuilder cb;
    return cb.store_bool_bool(false) && cb.finalize_to(acc_state);
  } else {
    return cs_ref->prefetch_ref_to(acc_state);
  }
}

bool ShardAccount::Record::reset() {
  last_trans_hash.set_zero();
  last_trans_lt = 0;
  is_zero = valid = true;
  vm::CellBuilder cb;
  return (cb.store_bool_bool(false) && cb.finalize_to(account)) || invalidate();
}

bool ShardAccount::Record::unpack(vm::CellSlice& cs) {
  is_zero = false;
  valid = true;
  return (cs.fetch_ref_to(account) && cs.fetch_bits_to(last_trans_hash) && cs.fetch_uint_to(64, last_trans_lt)) ||
         invalidate();
}

bool ShardAccount::Record::unpack(Ref<vm::CellSlice> cs_ref) {
  if (cs_ref.not_null()) {
    return unpack(cs_ref.write()) && (cs_ref->empty_ext() || invalidate());
  } else {
    return reset();
  }
}

const ShardAccount t_ShardAccount;

const AccountStatus t_AccountStatus;

bool HashmapAugNode::skip(vm::CellSlice& cs) const {
  if (n < 0) {
    return false;
  } else if (!n) {
    // ahmn_leaf
    return aug.extra_type.skip(cs) && aug.value_type.skip(cs);
  } else {
    // ahmn_fork
    return cs.advance_refs(2) && aug.extra_type.skip(cs);
  }
}

bool HashmapAugNode::validate_skip(vm::CellSlice& cs, bool weak) const {
  if (n < 0) {
    return false;
  }
  if (!n) {
    // ahmn_leaf
    vm::CellSlice cs_extra{cs};
    if (!aug.extra_type.validate_skip(cs, weak)) {
      return false;
    }
    cs_extra.cut_tail(cs);
    vm::CellSlice cs_value{cs};
    if (!aug.value_type.validate_skip(cs, weak)) {
      return false;
    }
    cs_value.cut_tail(cs);
    return aug.check_leaf(cs_extra, cs_value);
  }
  // ahmn_fork
  if (!cs.have_refs(2)) {
    return false;
  }
  HashmapAug branch_type{n - 1, aug};
  if (!branch_type.validate_ref(cs.prefetch_ref(0), weak) || !branch_type.validate_ref(cs.prefetch_ref(1), weak)) {
    return false;
  }
  auto cs_left = load_cell_slice(cs.fetch_ref());
  auto cs_right = load_cell_slice(cs.fetch_ref());
  vm::CellSlice cs_extra{cs};
  if (!aug.extra_type.validate_skip(cs, weak)) {
    return false;
  }
  cs_extra.cut_tail(cs);
  return branch_type.extract_extra(cs_left) && branch_type.extract_extra(cs_right) &&
         aug.check_fork(cs_extra, cs_left, cs_right);
}

bool HashmapAug::skip(vm::CellSlice& cs) const {
  int l;
  return HmLabel{n}.skip(cs, l) && HashmapAugNode{n - l, aug}.skip(cs);
}

bool HashmapAug::validate_skip(vm::CellSlice& cs, bool weak) const {
  int l;
  return HmLabel{n}.validate_skip(cs, weak, l) && HashmapAugNode{n - l, aug}.validate_skip(cs, weak);
}

bool HashmapAug::extract_extra(vm::CellSlice& cs) const {
  int l;
  return HmLabel{n}.skip(cs, l) && (l == n || cs.advance_refs(2)) && aug.extra_type.extract(cs);
}

bool HashmapAugE::validate_skip(vm::CellSlice& cs, bool weak) const {
  Ref<vm::CellSlice> extra;
  switch (get_tag(cs)) {
    case ahme_empty:
      return cs.advance(1) && (extra = root_type.aug.extra_type.validate_fetch(cs, weak)).not_null() &&
             root_type.aug.check_empty(extra.unique_write());
    case ahme_root:
      if (cs.advance(1) && root_type.validate_ref(cs.prefetch_ref(), weak)) {
        bool special;
        auto cs_root = load_cell_slice_special(cs.fetch_ref(), special);
        if (special) {
          return weak;
        }
        return (extra = root_type.aug.extra_type.validate_fetch(cs, weak)).not_null() &&
               root_type.extract_extra(cs_root) && extra->contents_equal(cs_root);
      }
      break;
  }
  return false;
}

bool HashmapAugE::skip(vm::CellSlice& cs) const {
  int tag = (int)cs.fetch_ulong(1);
  return tag >= 0 && cs.advance_refs(tag) && root_type.aug.extra_type.skip(cs);
}

bool HashmapAugE::extract_extra(vm::CellSlice& cs) const {
  int tag = (int)cs.fetch_ulong(1);
  return tag >= 0 && cs.advance_refs(tag) && root_type.aug.extra_type.extract(cs);
}

bool DepthBalanceInfo::skip(vm::CellSlice& cs) const {
  return cs.advance(5) &&
         t_CurrencyCollection.skip(
             cs);  // depth_balance$_ split_depth:(#<= 30) balance:CurrencyCollection = DepthBalanceInfo;
}

bool DepthBalanceInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(5) <= 30 && t_CurrencyCollection.validate_skip(
                                        cs, weak);  // depth_balance$_ split_depth:(#<= 30) balance:CurrencyCollection
}

bool DepthBalanceInfo::null_value(vm::CellBuilder& cb) const {
  return cb.store_zeroes_bool(5) && t_CurrencyCollection.null_value(cb);
}

bool DepthBalanceInfo::add_values(vm::CellBuilder& cb, vm::CellSlice& cs1, vm::CellSlice& cs2) const {
  unsigned d1, d2;
  return cs1.fetch_uint_leq(30, d1) && cs2.fetch_uint_leq(30, d2) && cb.store_uint_leq(30, std::max(d1, d2)) &&
         t_CurrencyCollection.add_values(cb, cs1, cs2);
}

const DepthBalanceInfo t_DepthBalanceInfo;

bool Aug_ShardAccounts::eval_leaf(vm::CellBuilder& cb, vm::CellSlice& cs) const {
  if (cs.have_refs()) {
    auto cs2 = load_cell_slice(cs.prefetch_ref());
    return t_Account.skip_copy_depth_balance(cb, cs2);
  } else {
    return false;
  }
}

const Aug_ShardAccounts aug_ShardAccounts;

const ShardAccounts t_ShardAccounts;

const AccStatusChange t_AccStatusChange;

bool TrStoragePhase::skip(vm::CellSlice& cs) const {
  return t_Grams.skip(cs)                // storage_fees_collected:Grams
         && t_Maybe_Grams.skip(cs)       // storage_fees_due:Grams
         && t_AccStatusChange.skip(cs);  // status_change:AccStatusChange
}

bool TrStoragePhase::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Grams.validate_skip(cs, weak)                // storage_fees_collected:Grams
         && t_Maybe_Grams.validate_skip(cs, weak)       // storage_fees_due:Grams
         && t_AccStatusChange.validate_skip(cs, weak);  // status_change:AccStatusChange
}

bool TrStoragePhase::get_storage_fees(vm::CellSlice& cs, td::RefInt256& storage_fees) const {
  return t_Grams.as_integer_skip_to(cs, storage_fees);  // storage_fees_collected:Grams
}

bool TrStoragePhase::maybe_get_storage_fees(vm::CellSlice& cs, td::RefInt256& storage_fees) const {
  auto z = cs.fetch_ulong(1);
  if (!z) {
    storage_fees = td::make_refint(0);
    return true;
  } else {
    return z == 1 && get_storage_fees(cs, storage_fees);
  }
}

const TrStoragePhase t_TrStoragePhase;

bool TrCreditPhase::skip(vm::CellSlice& cs) const {
  return t_Maybe_Grams.skip(cs)             // due_fees_collected:(Maybe Grams)
         && t_CurrencyCollection.skip(cs);  // credit:CurrencyCollection
}

bool TrCreditPhase::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Maybe_Grams.validate_skip(cs, weak)             // due_fees_collected:(Maybe Grams)
         && t_CurrencyCollection.validate_skip(cs, weak);  // credit:CurrencyCollection
}

const TrCreditPhase t_TrCreditPhase;

bool TrComputeInternal1::skip(vm::CellSlice& cs) const {
  return t_VarUInteger_7.skip(cs)           // gas_used:(VarUInteger 7)
         && t_VarUInteger_7.skip(cs)        // gas_limit:(VarUInteger 7)
         && Maybe<VarUInteger>{3}.skip(cs)  // gas_credit:(Maybe (VarUInteger 3))
         && cs.advance(8 + 32)              // mode:int8 exit_code:int32
         && Maybe<Int>{32}.skip(cs)         // exit_arg:(Maybe int32)
         && cs.advance(32 + 256 + 256);     // vm_steps:uint32
                                            // vm_init_state_hash:uint256
                                            // vm_final_state_hash:uint256
}

bool TrComputeInternal1::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_VarUInteger_7.validate_skip(cs, weak)           // gas_used:(VarUInteger 7)
         && t_VarUInteger_7.validate_skip(cs, weak)        // gas_limit:(VarUInteger 7)
         && Maybe<VarUInteger>{3}.validate_skip(cs, weak)  // gas_credit:(Maybe (VarUInteger 3))
         && cs.advance(8 + 32)                             // mode:int8 exit_code:int32
         && Maybe<Int>{32}.validate_skip(cs, weak)         // exit_arg:(Maybe int32)
         && cs.advance(32 + 256 + 256);                    // vm_steps:uint32
                                                           // vm_init_state_hash:uint256
                                                           // vm_final_state_hash:uint256
}

const TrComputeInternal1 t_TrComputeInternal1;
const RefTo<TrComputeInternal1> t_Ref_TrComputeInternal1;
const ComputeSkipReason t_ComputeSkipReason;

bool TrComputePhase::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
    case tr_phase_compute_skipped:
      return cs.advance(1) && t_ComputeSkipReason.skip(cs);
    case tr_phase_compute_vm:
      return cs.advance(1 + 3)    // tr_phase_compute_vm$1 success:Bool msg_state_used:Bool account_activated:Bool
             && t_Grams.skip(cs)  // gas_fees:Grams
             && t_Ref_TrComputeInternal1.skip(cs);  // ^[ gas_used:(..) .. ]
  }
  return false;
}

bool TrComputePhase::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
    case tr_phase_compute_skipped:
      return cs.advance(1) && t_ComputeSkipReason.validate_skip(cs, weak);
    case tr_phase_compute_vm:
      return cs.advance(1 + 3)  // tr_phase_compute_vm$1 success:Bool msg_state_used:Bool account_activated:Bool
             && t_Grams.validate_skip(cs, weak)                    // gas_fees:Grams
             && t_Ref_TrComputeInternal1.validate_skip(cs, weak);  // ^[ gas_used:(..) .. ]
  }
  return false;
}

const TrComputePhase t_TrComputePhase;

bool TrActionPhase::skip(vm::CellSlice& cs) const {
  return cs.advance(3)                    // success:Bool valid:Bool no_funds:Bool
         && t_AccStatusChange.skip(cs)    // status_change:AccStatusChange
         && t_Maybe_Grams.skip(cs)        // total_fwd_fees:(Maybe Grams)
         && t_Maybe_Grams.skip(cs)        // total_action_fees:(Maybe Grams)
         && cs.advance(32)                // result_code:int32
         && Maybe<Int>{32}.skip(cs)       // result_arg:(Maybe int32)
         && cs.advance(16 * 4 + 256)      // tot_actions:uint16 spec_actions:uint16
                                          // skipped_actions:uint16 msgs_created:uint16
                                          // action_list_hash:uint256
         && t_StorageUsedShort.skip(cs);  // tot_msg_size:StorageUsedShort
}

bool TrActionPhase::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance(3)                                   // success:Bool valid:Bool no_funds:Bool
         && t_AccStatusChange.validate_skip(cs, weak)    // status_change:AccStatusChange
         && t_Maybe_Grams.validate_skip(cs, weak)        // total_fwd_fees:(Maybe Grams)
         && t_Maybe_Grams.validate_skip(cs, weak)        // total_action_fees:(Maybe Grams)
         && cs.advance(32)                               // result_code:int32
         && Maybe<Int>{32}.validate_skip(cs, weak)       // result_arg:(Maybe int32)
         && cs.advance(16 * 4 + 256)                     // tot_actions:uint16 spec_actions:uint16
                                                         // skipped_actions:uint16 msgs_created:uint16
                                                         // action_list_hash:uint256
         && t_StorageUsedShort.validate_skip(cs, weak);  // tot_msg_size:StorageUsed
}

const TrActionPhase t_TrActionPhase;

bool TrBouncePhase::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
    case tr_phase_bounce_negfunds:
      return cs.advance(2);  // tr_phase_bounce_negfunds$00
    case tr_phase_bounce_nofunds:
      return cs.advance(2)                   // tr_phase_bounce_nofunds$01
             && t_StorageUsedShort.skip(cs)  // msg_size:StorageUsedShort
             && t_Grams.skip(cs);            // req_fwd_fees:Grams
    case tr_phase_bounce_ok:
      return cs.advance(1)                   // tr_phase_bounce_ok$1
             && t_StorageUsedShort.skip(cs)  // msg_size:StorageUsedShort
             && t_Grams.skip(cs)             // msg_fees:Grams
             && t_Grams.skip(cs);            // fwd_fees:Grams
  }
  return false;
}

bool TrBouncePhase::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
    case tr_phase_bounce_negfunds:
      return cs.advance(2);  // tr_phase_bounce_negfunds$00
    case tr_phase_bounce_nofunds:
      return cs.advance(2)                                  // tr_phase_bounce_nofunds$01
             && t_StorageUsedShort.validate_skip(cs, weak)  // msg_size:StorageUsedShort
             && t_Grams.validate_skip(cs, weak);            // req_fwd_fees:Grams
    case tr_phase_bounce_ok:
      return cs.advance(1)                                  // tr_phase_bounce_ok$1
             && t_StorageUsedShort.validate_skip(cs, weak)  // msg_size:StorageUsedShort
             && t_Grams.validate_skip(cs, weak)             // msg_fees:Grams
             && t_Grams.validate_skip(cs, weak);            // fwd_fees:Grams
  }
  return false;
}

int TrBouncePhase::get_tag(const vm::CellSlice& cs) const {
  if (cs.size() == 1) {
    return (int)cs.prefetch_ulong(1) == 1 ? tr_phase_bounce_ok : -1;
  }
  int v = (int)cs.prefetch_ulong(2);
  return v == 3 ? tr_phase_bounce_ok : v;
};

const TrBouncePhase t_TrBouncePhase;

bool SplitMergeInfo::skip(vm::CellSlice& cs) const {
  // cur_shard_pfx_len:(## 6) acc_split_depth:(##6) this_addr:uint256 sibling_addr:uint256
  return cs.advance(6 + 6 + 256 + 256);
}

bool SplitMergeInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  if (!cs.have(6 + 6 + 256 + 256)) {
    return false;
  }
  int cur_pfx_len = (int)cs.fetch_ulong(6);
  int split_depth = (int)cs.fetch_ulong(6);
  unsigned char this_addr[32], sibling_addr[32];
  if (!cs.fetch_bytes(this_addr, 32) || !cs.fetch_bytes(sibling_addr, 32)) {
    return false;
  }
  // cur_pfx_len < split_depth, addresses match except in bit cur_pfx_len
  if (cur_pfx_len >= split_depth) {
    return false;
  }
  sibling_addr[cur_pfx_len >> 3] ^= (unsigned char)(0x80 >> (cur_pfx_len & 7));
  return !std::memcmp(this_addr, sibling_addr, 32);
}

const SplitMergeInfo t_SplitMergeInfo;

bool TransactionDescr::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
    case trans_ord:
      return cs.advance(4 + 1)                          // trans_ord$0000 storage_first:Bool
             && Maybe<TrStoragePhase>{}.skip(cs)        // storage_ph:(Maybe TrStoragePhase)
             && Maybe<TrCreditPhase>{}.skip(cs)         // credit_ph:(Maybe TrCreditPhase)
             && t_TrComputePhase.skip(cs)               // compute_ph:TrComputePhase
             && Maybe<RefTo<TrActionPhase>>{}.skip(cs)  // action:(Maybe ^TrActionPhase)
             && cs.advance(1)                           // aborted:Bool
             && Maybe<TrBouncePhase>{}.skip(cs)         // bounce:(Maybe TrBouncePhase)
             && cs.advance(1);                          // destroyed:Bool
    case trans_storage:
      return cs.advance(4)                  // trans_storage$0001
             && t_TrStoragePhase.skip(cs);  // storage_ph:TrStoragePhase
    case trans_tick_tock:
      return cs.advance(4)                              // trans_tick_tock$001 is_tock:Bool
             && t_TrStoragePhase.skip(cs)               // storage_ph:TrStoragePhase
             && t_TrComputePhase.skip(cs)               // compute_ph:TrComputePhase
             && Maybe<RefTo<TrActionPhase>>{}.skip(cs)  // action:(Maybe ^TrActionPhase)
             && cs.advance(2);                          // aborted:Bool destroyed:Bool
    case trans_split_prepare:
      return cs.advance(4)                              // trans_split_prepare$0100
             && t_SplitMergeInfo.skip(cs)               // split_info:SplitMergeInfo
             && Maybe<TrStoragePhase>{}.skip(cs)        // storage_ph:(Maybe TrStoragePhase)
             && t_TrComputePhase.skip(cs)               // compute_ph:TrComputePhase
             && Maybe<RefTo<TrActionPhase>>{}.skip(cs)  // action:(Maybe ^TrActionPhase)
             && cs.advance(2);                          // aborted:Bool destroyed:Bool
    case trans_split_install:
      return cs.advance(4)                  // trans_split_install$0101
             && t_SplitMergeInfo.skip(cs)   // split_info:SplitMergeInfo
             && t_Ref_Transaction.skip(cs)  // prepare_transaction:^Transaction
             && cs.advance(1);              // installed:Bool
    case trans_merge_prepare:
      return cs.advance(4)                 // trans_merge_prepare$0110
             && t_SplitMergeInfo.skip(cs)  // split_info:SplitMergeInfo
             && t_TrStoragePhase.skip(cs)  // storage_ph:TrStoragePhase
             && cs.advance(1);             // aborted:Bool
    case trans_merge_install:
      return cs.advance(4)                              // trans_merge_install$0111
             && t_SplitMergeInfo.skip(cs)               // split_info:SplitMergeInfo
             && t_Ref_Transaction.skip(cs)              // prepare_transaction:^Transaction
             && Maybe<TrStoragePhase>{}.skip(cs)        // storage_ph:(Maybe TrStoragePhase)
             && Maybe<TrCreditPhase>{}.skip(cs)         // credit_ph:(Maybe TrCreditPhase)
             && Maybe<TrComputePhase>{}.skip(cs)        // compute_ph:TrComputePhase
             && Maybe<RefTo<TrActionPhase>>{}.skip(cs)  // action:(Maybe ^TrActionPhase)
             && cs.advance(2);                          // aborted:Bool destroyed:Bool
  }
  return false;
}

bool TransactionDescr::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
    case trans_ord:
      return cs.advance(4 + 1)                                         // trans_ord$0000 credit_first:Bool
             && Maybe<TrStoragePhase>{}.validate_skip(cs, weak)        // storage_ph:(Maybe TrStoragePhase)
             && Maybe<TrCreditPhase>{}.validate_skip(cs, weak)         // credit_ph:(Maybe TrCreditPhase)
             && t_TrComputePhase.validate_skip(cs, weak)               // compute_ph:TrComputePhase
             && Maybe<RefTo<TrActionPhase>>{}.validate_skip(cs, weak)  // action:(Maybe ^TrActionPhase)
             && cs.advance(1)                                          // aborted:Bool
             && Maybe<TrBouncePhase>{}.validate_skip(cs, weak)         // bounce:(Maybe TrBouncePhase)
             && cs.advance(1);                                         // destroyed:Bool
    case trans_storage:
      return cs.advance(4)                                 // trans_storage$0001
             && t_TrStoragePhase.validate_skip(cs, weak);  // storage_ph:TrStoragePhase
    case trans_tick_tock:
      return cs.advance(4)                                             // trans_tick_tock$001 is_tock:Bool
             && t_TrStoragePhase.validate_skip(cs, weak)               // storage_ph:TrStoragePhase
             && t_TrComputePhase.validate_skip(cs, weak)               // compute_ph:TrComputePhase
             && Maybe<RefTo<TrActionPhase>>{}.validate_skip(cs, weak)  // action:(Maybe ^TrActionPhase)
             && cs.advance(2);                                         // aborted:Bool destroyed:Bool
    case trans_split_prepare:
      return cs.advance(4)                                             // trans_split_prepare$0100
             && t_SplitMergeInfo.validate_skip(cs, weak)               // split_info:SplitMergeInfo
             && Maybe<TrStoragePhase>{}.validate_skip(cs, weak)        // storage_ph:(Maybe TrStoragePhase)
             && t_TrComputePhase.validate_skip(cs, weak)               // compute_ph:TrComputePhase
             && Maybe<RefTo<TrActionPhase>>{}.validate_skip(cs, weak)  // action:(Maybe ^TrActionPhase)
             && cs.advance(2);                                         // aborted:Bool destroyed:Bool
    case trans_split_install:
      return cs.advance(4)                                 // trans_split_install$0101
             && t_SplitMergeInfo.validate_skip(cs, weak)   // split_info:SplitMergeInfo
             && t_Ref_Transaction.validate_skip(cs, weak)  // prepare_transaction:^Transaction
             && cs.advance(1);                             // installed:Bool
    case trans_merge_prepare:
      return cs.advance(4)                                // trans_merge_prepare$0110
             && t_SplitMergeInfo.validate_skip(cs, weak)  // split_info:SplitMergeInfo
             && t_TrStoragePhase.validate_skip(cs, weak)  // storage_ph:TrStoragePhase
             && cs.advance(1);                            // aborted:Bool
    case trans_merge_install:
      return cs.advance(4)                                             // trans_merge_install$0111
             && t_SplitMergeInfo.validate_skip(cs, weak)               // split_info:SplitMergeInfo
             && t_Ref_Transaction.validate_skip(cs, weak)              // prepare_transaction:^Transaction
             && Maybe<TrStoragePhase>{}.validate_skip(cs, weak)        // storage_ph:(Maybe TrStoragePhase)
             && Maybe<TrCreditPhase>{}.validate_skip(cs, weak)         // credit_ph:(Maybe TrCreditPhase)
             && Maybe<TrComputePhase>{}.validate_skip(cs, weak)        // compute_ph:TrComputePhase
             && Maybe<RefTo<TrActionPhase>>{}.validate_skip(cs, weak)  // action:(Maybe ^TrActionPhase)
             && cs.advance(2);                                         // aborted:Bool destroyed:Bool
  }
  return false;
}

int TransactionDescr::get_tag(const vm::CellSlice& cs) const {
  int t = (int)cs.prefetch_ulong(4);
  return (t >= 0 && t <= 7) ? (t == 3 ? 2 : t) : -1;
}

bool TransactionDescr::skip_to_storage_phase(vm::CellSlice& cs, bool& found) const {
  found = false;
  switch (get_tag(cs)) {
    case trans_ord:
      return cs.advance(4 + 1)            // trans_ord$0000 storage_first:Bool
             && cs.fetch_bool_to(found);  // storage_ph:(Maybe TrStoragePhase)
    case trans_storage:
      return cs.advance(4)       // trans_storage$0001
             && (found = true);  // storage_ph:TrStoragePhase
    case trans_tick_tock:
      return cs.advance(4)       // trans_tick_tock$001 is_tock:Bool
             && (found = true);  // storage_ph:TrStoragePhase
    case trans_split_prepare:
      return cs.advance(4)                 // trans_split_prepare$0100
             && t_SplitMergeInfo.skip(cs)  // split_info:SplitMergeInfo
             && cs.fetch_bool_to(found);   // storage_ph:(Maybe TrStoragePhase)
    case trans_split_install:
      return true;
    case trans_merge_prepare:
      return cs.advance(4)                 // trans_merge_prepare$0110
             && t_SplitMergeInfo.skip(cs)  // split_info:SplitMergeInfo
             && (found = true);            // storage_ph:TrStoragePhase
    case trans_merge_install:
      return cs.advance(4)                  // trans_merge_install$0111
             && t_SplitMergeInfo.skip(cs)   // split_info:SplitMergeInfo
             && t_Ref_Transaction.skip(cs)  // prepare_transaction:^Transaction
             && cs.fetch_bool_to(found);    // storage_ph:(Maybe TrStoragePhase)
  }
  return false;
}

bool TransactionDescr::get_storage_fees(Ref<vm::Cell> cell, td::RefInt256& storage_fees) const {
  if (cell.is_null()) {
    return false;
  }
  auto cs = vm::load_cell_slice(std::move(cell));
  bool found;
  if (!skip_to_storage_phase(cs, found)) {
    return false;
  } else if (found) {
    return t_TrStoragePhase.get_storage_fees(cs, storage_fees);
  } else {
    storage_fees = td::make_refint(0);
    return true;
  }
}

const TransactionDescr t_TransactionDescr;

bool Transaction_aux::skip(vm::CellSlice& cs) const {
  return Maybe<RefTo<Message>>{}.skip(cs)          // in_msg:(Maybe ^Message)
         && HashmapE{15, t_Ref_Message}.skip(cs);  // out_msgs:(HashmapE 15 ^Message)
}

bool Transaction_aux::validate_skip(vm::CellSlice& cs, bool weak) const {
  return Maybe<RefTo<Message>>{}.validate_skip(cs, weak)          // in_msg:(Maybe ^Message)
         && HashmapE{15, t_Ref_Message}.validate_skip(cs, weak);  // out_msgs:(HashmapE 15 ^Message)
}

const Transaction_aux t_Transaction_aux;

bool Transaction::skip(vm::CellSlice& cs) const {
  return cs.advance(
             4 + 256 + 64 + 256 + 64 + 32 +
             15)  // transaction$0111 account_addr:uint256 lt:uint64 prev_trans_hash:bits256 prev_trans_lt:uint64 now:uint32 outmsg_cnt:uint15
         && t_AccountStatus.skip(cs)             // orig_status:AccountStatus
         && t_AccountStatus.skip(cs)             // end_status:AccountStatus
         && cs.advance_refs(1)                   // ^[ in_msg:(Maybe ^Message) out_msgs:(HashmapE 15 ^Message) ]
         && t_CurrencyCollection.skip(cs)        // total_fees:CurrencyCollection
         && cs.advance_refs(1)                   // state_update:^(MERKLE_UPDATE Account)
         && RefTo<TransactionDescr>{}.skip(cs);  // description:^TransactionDescr
}

bool Transaction::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(4) == 7  // transaction$0111
         &&
         cs.advance(
             256 + 64 + 256 + 64 + 32 +
             15)  // account_addr:uint256 lt:uint64 prev_trans_hash:bits256 prev_trans_lt:uint64 now:uint32 outmsg_cnt:uint15
         && t_AccountStatus.validate_skip(cs, weak)             // orig_status:AccountStatus
         && t_AccountStatus.validate_skip(cs, weak)             // end_status:AccountStatus
         && RefTo<Transaction_aux>{}.validate_skip(cs, weak)    // ^[ in_msg:... out_msgs:... ]
         && t_CurrencyCollection.validate_skip(cs, weak)        // total_fees:CurrencyCollection
         && t_Ref_HashUpdate.validate_skip(cs, weak)            // state_update:^(HASH_UPDATE Account)
         && RefTo<TransactionDescr>{}.validate_skip(cs, weak);  // description:^TransactionDescr
}

bool Transaction::get_storage_fees(Ref<vm::Cell> cell, td::RefInt256& storage_fees) const {
  Ref<vm::Cell> tdescr;
  return get_descr(std::move(cell), tdescr) && t_TransactionDescr.get_storage_fees(std::move(tdescr), storage_fees);
}

bool Transaction::get_descr(Ref<vm::Cell> cell, Ref<vm::Cell>& tdescr) const {
  if (cell.is_null()) {
    return false;
  } else {
    auto cs = vm::load_cell_slice(std::move(cell));
    return cs.is_valid() && get_descr(cs, tdescr) && cs.empty_ext();
  }
}

bool Transaction::get_descr(vm::CellSlice& cs, Ref<vm::Cell>& tdescr) const {
  return cs.advance(
             4 + 256 + 64 + 256 + 64 + 32 +
             15)  // transaction$0111 account_addr:uint256 lt:uint64 prev_trans_hash:bits256 prev_trans_lt:uint64 now:uint32 outmsg_cnt:uint15
         && t_AccountStatus.skip(cs)       // orig_status:AccountStatus
         && t_AccountStatus.skip(cs)       // end_status:AccountStatus
         && cs.advance_refs(1)             // ^[ in_msg:(Maybe ^Message) out_msgs:(HashmapE 15 ^Message) ]
         && t_CurrencyCollection.skip(cs)  // total_fees:CurrencyCollection
         && cs.advance_refs(1)             // state_update:^(MERKLE_UPDATE Account)
         && cs.fetch_ref_to(tdescr);       // description:^TransactionDescr
}

bool Transaction::get_total_fees(vm::CellSlice&& cs, block::CurrencyCollection& total_fees) const {
  return cs.is_valid() && cs.fetch_ulong(4) == 7  // transaction$0111
         &&
         cs.advance(
             256 + 64 + 256 + 64 + 32 +
             15)  // account_addr:uint256 lt:uint64 prev_trans_hash:bits256 prev_trans_lt:uint64 now:uint32 outmsg_cnt:uint15
         && t_AccountStatus.skip(cs)  // orig_status:AccountStatus
         && t_AccountStatus.skip(cs)  // end_status:AccountStatus
         && cs.advance_refs(1)        // ^[ in_msg:... out_msg:... ]
         && total_fees.fetch(cs);     // total_fees:CurrencyCollection
}

const Transaction t_Transaction;
const RefTo<Transaction> t_Ref_Transaction;

// leaf evaluation for (HashmapAug 64 ^Transaction CurrencyCollection)
bool Aug_AccountTransactions::eval_leaf(vm::CellBuilder& cb, vm::CellSlice& cs) const {
  auto cell_ref = cs.prefetch_ref();
  block::CurrencyCollection total_fees;
  return cell_ref.not_null() && t_Transaction.get_total_fees(vm::load_cell_slice(std::move(cell_ref)), total_fees) &&
         total_fees.store(cb);
}

const Aug_AccountTransactions aug_AccountTransactions;
const HashmapAug t_AccountTransactions{64, aug_AccountTransactions};

const HashUpdate t_HashUpdate;
const RefTo<HashUpdate> t_Ref_HashUpdate;

bool AccountBlock::skip(vm::CellSlice& cs) const {
  return cs.advance(4 + 256)                // acc_trans#5 account_addr:bits256
         && t_AccountTransactions.skip(cs)  // transactions:(HashmapAug 64 ^Transaction CurrencyCollection)
         && cs.advance_refs(1);             // state_update:^(HASH_UPDATE Account)
}

bool AccountBlock::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.fetch_ulong(4) == 5  // acc_trans#5
         && cs.advance(256)      // account_addr:bits256
         &&
         t_AccountTransactions.validate_skip(cs, weak)  // transactions:(HashmapAug 64 ^Transaction CurrencyCollection)
         && t_Ref_HashUpdate.validate_skip(cs, weak);   // state_update:^(HASH_UPDATE Account)
}

bool AccountBlock::get_total_fees(vm::CellSlice&& cs, block::CurrencyCollection& total_fees) const {
  return cs.advance(4 + 256)                         // acc_trans#5 account_addr:bits256
         && t_AccountTransactions.extract_extra(cs)  // transactions:(HashmapAug 64 ^Transaction Grams)
         && total_fees.fetch(cs);
}

const AccountBlock t_AccountBlock;

bool Aug_ShardAccountBlocks::eval_leaf(vm::CellBuilder& cb, vm::CellSlice& cs) const {
  block::CurrencyCollection total_fees;
  return t_AccountBlock.get_total_fees(std::move(cs), total_fees) && total_fees.store(cb);
}

const Aug_ShardAccountBlocks aug_ShardAccountBlocks;
const HashmapAugE t_ShardAccountBlocks{256,
                                       aug_ShardAccountBlocks};  // (HashmapAugE 256 AccountBlock CurrencyCollection)

bool ImportFees::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_Grams.validate_skip(cs, weak) && t_CurrencyCollection.validate_skip(cs, weak);
}

bool ImportFees::skip(vm::CellSlice& cs) const {
  return t_Grams.skip(cs) && t_CurrencyCollection.skip(cs);
}

bool ImportFees::add_values(vm::CellBuilder& cb, vm::CellSlice& cs1, vm::CellSlice& cs2) const {
  return t_Grams.add_values(cb, cs1, cs2) && t_CurrencyCollection.add_values(cb, cs1, cs2);
}

const ImportFees t_ImportFees;

bool InMsg::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
    case msg_import_ext:
      return cs.advance(3)                   // msg_import_ext$000
             && t_Ref_Message.skip(cs)       // msg:^Message
             && t_Ref_Transaction.skip(cs);  // transaction:^Transaction
    case msg_import_ihr:
      return cs.advance(3)                  // msg_import_ihr$010
             && t_Ref_Message.skip(cs)      // msg:^Message
             && t_Ref_Transaction.skip(cs)  // transaction:^Transaction
             && t_Grams.skip(cs)            // ihr_fee:Grams
             && t_RefCell.skip(cs);         // proof_created:^Cell
    case msg_import_imm:
      return cs.advance(3)                  // msg_import_imm$011
             && t_Ref_MsgEnvelope.skip(cs)  // in_msg:^MsgEnvelope
             && t_Ref_Transaction.skip(cs)  // transaction:^Transaction
             && t_Grams.skip(cs);           // fwd_fee:Grams
    case msg_import_fin:
      return cs.advance(3)                  // msg_import_fin$100
             && t_Ref_MsgEnvelope.skip(cs)  // in_msg:^MsgEnvelope
             && t_Ref_Transaction.skip(cs)  // transaction:^Transaction
             && t_Grams.skip(cs);           // fwd_fee:Grams
    case msg_import_tr:
      return cs.advance(3)                  // msg_import_tr$101
             && t_Ref_MsgEnvelope.skip(cs)  // in_msg:^MsgEnvelope
             && t_Ref_MsgEnvelope.skip(cs)  // out_msg:^MsgEnvelope
             && t_Grams.skip(cs);           // transit_fee:Grams
    case msg_discard_fin:
      return cs.advance(3)                  // msg_discard_fin$110
             && t_Ref_MsgEnvelope.skip(cs)  // in_msg:^MsgEnvelope
             && cs.advance(64)              // transaction_id:uint64
             && t_Grams.skip(cs);           // fwd_fee:Grams
    case msg_discard_tr:
      return cs.advance(3)                  // msg_discard_tr$111
             && t_Ref_MsgEnvelope.skip(cs)  // in_msg:^MsgEnvelope
             && cs.advance(64)              // transaction_id:uint64
             && t_Grams.skip(cs)            // fwd_fee:Grams
             && t_RefCell.skip(cs);         // proof_delivered:^Cell
  }
  return false;
}

bool InMsg::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
    case msg_import_ext:
      return cs.advance(3)                                  // msg_import_ext$000
             && t_Ref_Message.validate_skip(cs, weak)       // msg:^Message
             && t_Ref_Transaction.validate_skip(cs, weak);  // transaction:^Transaction
    case msg_import_ihr:
      return cs.advance(3)                                 // msg_import_ihr$010
             && t_Ref_Message.validate_skip(cs, weak)      // msg:^Message
             && t_Ref_Transaction.validate_skip(cs, weak)  // transaction:^Transaction
             && t_Grams.validate_skip(cs, weak)            // ihr_fee:Grams
             && t_RefCell.validate_skip(cs, weak);         // proof_created:^Cell
    case msg_import_imm:
      return cs.advance(3)                                 // msg_import_imm$011
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)  // in_msg:^MsgEnvelope
             && t_Ref_Transaction.validate_skip(cs, weak)  // transaction:^Transaction
             && t_Grams.validate_skip(cs, weak);           // fwd_fee:Grams
    case msg_import_fin:
      return cs.advance(3)                                 // msg_import_fin$100
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)  // in_msg:^MsgEnvelope
             && t_Ref_Transaction.validate_skip(cs, weak)  // transaction:^Transaction
             && t_Grams.validate_skip(cs, weak);           // fwd_fee:Grams
    case msg_import_tr:
      return cs.advance(3)                                 // msg_import_tr$101
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)  // in_msg:^MsgEnvelope
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)  // out_msg:^MsgEnvelope
             && t_Grams.validate_skip(cs, weak);           // transit_fee:Grams
    case msg_discard_fin:
      return cs.advance(3)                                 // msg_discard_fin$110
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)  // in_msg:^MsgEnvelope
             && cs.advance(64)                             // transaction_id:uint64
             && t_Grams.validate_skip(cs, weak);           // fwd_fee:Grams
    case msg_discard_tr:
      return cs.advance(3)                                 // msg_discard_tr$111
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)  // in_msg:^MsgEnvelope
             && cs.advance(64)                             // transaction_id:uint64
             && t_Grams.validate_skip(cs, weak)            // fwd_fee:Grams
             && t_RefCell.validate_skip(cs, weak);         // proof_delivered:^Cell
  }
  return false;
}

bool InMsg::get_import_fees(vm::CellBuilder& cb, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
    case msg_import_ext:                   // inbound external message
      return t_ImportFees.null_value(cb);  // external messages have no value and no import fees
    case msg_import_ihr:                   // IHR-forwarded internal message to its final destination
      if (cs.advance(3) && cs.size_refs() >= 3) {
        auto msg_cs = load_cell_slice(cs.fetch_ref());
        CommonMsgInfo::Record_int_msg_info msg_info;
        td::RefInt256 ihr_fee;
        vm::CellBuilder aux;
        // sort of Prolog-style in C++
        return t_Message.extract_info(msg_cs) && t_CommonMsgInfo.unpack(msg_cs, msg_info) &&
               cs.fetch_ref().not_null() && (ihr_fee = t_Grams.as_integer_skip(cs)).not_null() &&
               cs.fetch_ref().not_null() && !cmp(ihr_fee, t_Grams.as_integer(*msg_info.ihr_fee)) &&
               cb.append_cellslice_bool(msg_info.ihr_fee)  // fees_collected := ihr_fee
               && aux.append_cellslice_bool(msg_info.ihr_fee) && t_ExtraCurrencyCollection.null_value(aux) &&
               t_CurrencyCollection.add_values(cb, aux.as_cellslice_ref().write(),
                                               msg_info.value.write());  // value_imported := ihr_fee + value
      }
      return false;
    case msg_import_imm:  // internal message re-imported from this very block
      if (cs.advance(3) && cs.size_refs() >= 2) {
        return cs.fetch_ref().not_null() && cs.fetch_ref().not_null() &&
               cb.append_cellslice_bool(t_Grams.fetch(cs))  // fees_collected := fwd_fees
               && t_CurrencyCollection.null_value(cb);      // value_imported := 0
      }
      return false;
    case msg_import_fin:  // internal message delivered to its final destination in this block
      if (cs.advance(3) && cs.size_refs() >= 2) {
        auto msg_env_cs = load_cell_slice(cs.fetch_ref());
        MsgEnvelope::Record in_msg;
        td::RefInt256 fwd_fee, fwd_fee_remaining, value_grams, ihr_fee;
        if (!(t_MsgEnvelope.unpack(msg_env_cs, in_msg) && cs.fetch_ref().not_null() &&
              t_Grams.as_integer_skip_to(cs, fwd_fee) &&
              (fwd_fee_remaining = t_Grams.as_integer(in_msg.fwd_fee_remaining)).not_null() &&
              !(cmp(fwd_fee, fwd_fee_remaining)))) {
          return false;
        }
        auto msg_cs = load_cell_slice(std::move(in_msg.msg));
        CommonMsgInfo::Record_int_msg_info msg_info;
        return t_Message.extract_info(msg_cs) && t_CommonMsgInfo.unpack(msg_cs, msg_info) &&
               cb.append_cellslice_bool(in_msg.fwd_fee_remaining)  // fees_collected := fwd_fee_remaining
               && t_Grams.as_integer_skip_to(msg_info.value.write(), value_grams) &&
               (ihr_fee = t_Grams.as_integer(std::move(msg_info.ihr_fee))).not_null() &&
               t_Grams.store_integer_ref(cb, value_grams + ihr_fee + fwd_fee_remaining) &&
               cb.append_cellslice_bool(
                   msg_info.value.write());  // value_imported = msg.value + msg.ihr_fee + fwd_fee_remaining
      }
      return false;
    case msg_import_tr:  // transit internal message
      if (cs.advance(3) && cs.size_refs() >= 2) {
        auto msg_env_cs = load_cell_slice(cs.fetch_ref());
        MsgEnvelope::Record in_msg;
        td::RefInt256 transit_fee, fwd_fee_remaining, value_grams, ihr_fee;
        if (!(t_MsgEnvelope.unpack(msg_env_cs, in_msg) && cs.fetch_ref().not_null() &&
              t_Grams.as_integer_skip_to(cs, transit_fee) &&
              (fwd_fee_remaining = t_Grams.as_integer(in_msg.fwd_fee_remaining)).not_null() &&
              cmp(transit_fee, fwd_fee_remaining) <= 0)) {
          return false;
        }
        auto msg_cs = load_cell_slice(in_msg.msg);
        CommonMsgInfo::Record_int_msg_info msg_info;
        return t_Message.extract_info(msg_cs) && t_CommonMsgInfo.unpack(msg_cs, msg_info) &&
               t_Grams.store_integer_ref(cb, std::move(transit_fee))  // fees_collected := transit_fees
               && t_Grams.as_integer_skip_to(msg_info.value.write(), value_grams) &&
               (ihr_fee = t_Grams.as_integer(std::move(msg_info.ihr_fee))).not_null() &&
               t_Grams.store_integer_ref(cb, value_grams + ihr_fee + fwd_fee_remaining) &&
               cb.append_cellslice_bool(
                   msg_info.value.write());  // value_imported = msg.value + msg.ihr_fee + fwd_fee_remaining
      }
      return false;
    case msg_discard_fin:  // internal message discarded at its final destination because of previous IHR delivery
      if (cs.advance(3) && cs.size_refs() >= 1) {
        Ref<vm::CellSlice> fwd_fee;
        return cs.fetch_ref().not_null() && cs.advance(64) && (fwd_fee = t_Grams.fetch(cs)).not_null() &&
               cb.append_cellslice_bool(fwd_fee)  // fees_collected := fwd_fee
               && cb.append_cellslice_bool(std::move(fwd_fee)) &&
               t_ExtraCurrencyCollection.null_value(cb);  // value_imported := fwd_fee
      }
      return false;
    case msg_discard_tr:  // internal message discarded at an intermediate destination
      if (cs.advance(3) && cs.size_refs() >= 2) {
        Ref<vm::CellSlice> fwd_fee;
        return cs.fetch_ref().not_null() && cs.advance(64) && (fwd_fee = t_Grams.fetch(cs)).not_null() &&
               cs.fetch_ref().not_null() && cb.append_cellslice_bool(fwd_fee)  // fees_collected := fwd_fee
               && cb.append_cellslice_bool(std::move(fwd_fee)) &&
               t_ExtraCurrencyCollection.null_value(cb);  // value_imported := fwd_fee
      }
      return false;
  }
  return false;
}

const InMsg t_InMsg;

const Aug_InMsgDescr aug_InMsgDescr;
const InMsgDescr t_InMsgDescr;

bool OutMsg::skip(vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
    case msg_export_ext:
      return cs.advance(3)                   // msg_export_ext$000
             && t_Ref_Message.skip(cs)       // msg:^Message
             && t_Ref_Transaction.skip(cs);  // transaction:^Transaction
    case msg_export_imm:
      return cs.advance(3)                  // msg_export_imm$010
             && t_Ref_MsgEnvelope.skip(cs)  // out_msg:^MsgEnvelope
             && t_Ref_Transaction.skip(cs)  // transaction:^Transaction
             && RefTo<InMsg>{}.skip(cs);    // reimport:^InMsg
    case msg_export_new:
      return cs.advance(3)                   // msg_export_new$001
             && t_Ref_MsgEnvelope.skip(cs)   // out_msg:^MsgEnvelope
             && t_Ref_Transaction.skip(cs);  // transaction:^Transaction
    case msg_export_tr:
      return cs.advance(3)                  // msg_export_tr$011
             && t_Ref_MsgEnvelope.skip(cs)  // out_msg:^MsgEnvelope
             && RefTo<InMsg>{}.skip(cs);    // imported:^InMsg
    case msg_export_deq_imm:
      return cs.advance(3)                  // msg_export_deq_imm$100
             && t_Ref_MsgEnvelope.skip(cs)  // out_msg:^MsgEnvelope
             && RefTo<InMsg>{}.skip(cs);    // reimport:^InMsg
    case msg_export_deq:
      return cs.advance(3)                  // msg_export_deq$110
             && t_Ref_MsgEnvelope.skip(cs)  // out_msg:^MsgEnvelope
             && cs.advance(64);             // import_block_lt:uint64
    case msg_export_tr_req:
      return cs.advance(3)                  // msg_export_tr_req$111
             && t_Ref_MsgEnvelope.skip(cs)  // out_msg:^MsgEnvelope
             && RefTo<InMsg>{}.skip(cs);    // imported:^InMsg
  }
  return false;
}

bool OutMsg::validate_skip(vm::CellSlice& cs, bool weak) const {
  switch (get_tag(cs)) {
    case msg_export_ext:
      return cs.advance(3)                                  // msg_export_ext$000
             && t_Ref_Message.validate_skip(cs, weak)       // msg:^Message
             && t_Ref_Transaction.validate_skip(cs, weak);  // transaction:^Transaction
    case msg_export_imm:
      return cs.advance(3)                                 // msg_export_imm$010
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)  // out_msg:^MsgEnvelope
             && t_Ref_Transaction.validate_skip(cs, weak)  // transaction:^Transaction
             && RefTo<InMsg>{}.validate_skip(cs, weak);    // reimport:^InMsg
    case msg_export_new:
      return cs.advance(3)                                  // msg_export_new$001
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)   // out_msg:^MsgEnvelope
             && t_Ref_Transaction.validate_skip(cs, weak);  // transaction:^Transaction
    case msg_export_tr:
      return cs.advance(3)                                 // msg_export_tr$011
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)  // out_msg:^MsgEnvelope
             && RefTo<InMsg>{}.validate_skip(cs, weak);    // imported:^InMsg
    case msg_export_deq_imm:
      return cs.advance(3)                                 // msg_export_deq_imm$100
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)  // out_msg:^MsgEnvelope
             && RefTo<InMsg>{}.validate_skip(cs, weak);    // reimport:^InMsg
    case msg_export_deq:
      return cs.advance(3)                                 // msg_export_deq$110
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)  // out_msg:^MsgEnvelope
             && cs.advance(64);                            // import_block_lt:uint64
    case msg_export_tr_req:
      return cs.advance(3)                                 // msg_export_tr_req$111
             && t_Ref_MsgEnvelope.validate_skip(cs, weak)  // out_msg:^MsgEnvelope
             && RefTo<InMsg>{}.validate_skip(cs, weak);    // imported:^InMsg
  }
  return false;
}

bool OutMsg::get_export_value(vm::CellBuilder& cb, vm::CellSlice& cs) const {
  switch (get_tag(cs)) {
    case msg_export_ext:  // external outbound message carries no value
      if (cs.have(3, 2)) {
        return t_CurrencyCollection.null_value(cb);
      }
      return false;
    case msg_export_imm:  // outbound internal message delivered in this very block, no value exported
      return cs.have(3, 3) && t_CurrencyCollection.null_value(cb);
    case msg_export_deq_imm:  // dequeuing record for outbound message delivered in this very block, no value exported
      return cs.have(3, 2) && t_CurrencyCollection.null_value(cb);
    case msg_export_deq:  // dequeueing record for outbound message, no exported value
      return cs.have(3, 1) && t_CurrencyCollection.null_value(cb);
    case msg_export_new:     // newly-generated outbound internal message, queued
    case msg_export_tr:      // transit internal message, queued
    case msg_export_tr_req:  // transit internal message, re-queued from this shardchain
      if (cs.advance(3) && cs.size_refs() >= 2) {
        auto msg_env_cs = load_cell_slice(cs.fetch_ref());
        MsgEnvelope::Record out_msg;
        if (!(cs.fetch_ref().not_null() && t_MsgEnvelope.unpack(msg_env_cs, out_msg))) {
          return false;
        }
        auto msg_cs = load_cell_slice(std::move(out_msg.msg));
        CommonMsgInfo::Record_int_msg_info msg_info;
        td::RefInt256 value_grams, ihr_fee, fwd_fee_remaining;
        return t_Message.extract_info(msg_cs) && t_CommonMsgInfo.unpack(msg_cs, msg_info) &&
               (value_grams = t_Grams.as_integer_skip(msg_info.value.write())).not_null() &&
               (ihr_fee = t_Grams.as_integer(std::move(msg_info.ihr_fee))).not_null() &&
               (fwd_fee_remaining = t_Grams.as_integer(out_msg.fwd_fee_remaining)).not_null() &&
               t_Grams.store_integer_ref(cb, value_grams + ihr_fee + fwd_fee_remaining) &&
               cb.append_cellslice_bool(std::move(msg_info.value));
        // exported value = msg.value + msg.ihr_fee + fwd_fee_remaining
      }
      return false;
  }
  return false;
}

bool OutMsg::get_created_lt(vm::CellSlice& cs, unsigned long long& created_lt) const {
  switch (get_tag(cs)) {
    case msg_export_ext:
      if (cs.have(3, 1)) {
        auto msg_cs = load_cell_slice(cs.prefetch_ref());
        return t_Message.get_created_lt(msg_cs, created_lt);
      } else {
        return false;
      }
    case msg_export_imm:
    case msg_export_new:
    case msg_export_tr:
    case msg_export_deq:
    case msg_export_deq_imm:
    case msg_export_tr_req:
      if (cs.have(3, 1)) {
        auto out_msg_cs = load_cell_slice(cs.prefetch_ref());
        return t_MsgEnvelope.get_created_lt(out_msg_cs, created_lt);
      } else {
        return false;
      }
  }
  return false;
}

const OutMsg t_OutMsg;

const Aug_OutMsgDescr aug_OutMsgDescr;
const OutMsgDescr t_OutMsgDescr;

bool EnqueuedMsg::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance(64) && t_Ref_MsgEnvelope.validate_skip(cs, weak);
}

const EnqueuedMsg t_EnqueuedMsg;

bool Aug_OutMsgQueue::eval_fork(vm::CellBuilder& cb, vm::CellSlice& left_cs, vm::CellSlice& right_cs) const {
  unsigned long long x, y;
  return left_cs.fetch_ulong_bool(64, x) && right_cs.fetch_ulong_bool(64, y) &&
         cb.store_ulong_rchk_bool(std::min(x, y), 64);
}

bool Aug_OutMsgQueue::eval_empty(vm::CellBuilder& cb) const {
  return cb.store_long_bool(0, 64);
}

bool Aug_OutMsgQueue::eval_leaf(vm::CellBuilder& cb, vm::CellSlice& cs) const {
  Ref<vm::Cell> msg_env;
  unsigned long long created_lt;
  return cs.fetch_ref_to(msg_env) && t_MsgEnvelope.get_created_lt(load_cell_slice(std::move(msg_env)), created_lt) &&
         cb.store_ulong_rchk_bool(created_lt, 64);
}

const Aug_OutMsgQueue aug_OutMsgQueue;
const OutMsgQueue t_OutMsgQueue;

const ProcessedUpto t_ProcessedUpto;
const HashmapE t_ProcessedInfo{96, t_ProcessedUpto};
const HashmapE t_IhrPendingInfo{256, t_uint128};

// _ out_queue:OutMsgQueue proc_info:ProcessedInfo = OutMsgQueueInfo;
bool OutMsgQueueInfo::skip(vm::CellSlice& cs) const {
  return t_OutMsgQueue.skip(cs) && t_ProcessedInfo.skip(cs) && t_IhrPendingInfo.skip(cs);
}

bool OutMsgQueueInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_OutMsgQueue.validate_skip(cs, weak) && t_ProcessedInfo.validate_skip(cs, weak) &&
         t_IhrPendingInfo.validate_skip(cs, weak);
}

const OutMsgQueueInfo t_OutMsgQueueInfo;
const RefTo<OutMsgQueueInfo> t_Ref_OutMsgQueueInfo;

bool ExtBlkRef::unpack(vm::CellSlice& cs, ton::BlockIdExt& blkid, ton::LogicalTime* end_lt) const {
  block::gen::ExtBlkRef::Record data;
  if (!tlb::unpack(cs, data)) {
    blkid.invalidate();
    return false;
  }
  blkid.id = ton::BlockId{ton::masterchainId, ton::shardIdAll, data.seq_no};
  blkid.root_hash = data.root_hash;
  blkid.file_hash = data.file_hash;
  if (end_lt) {
    *end_lt = data.end_lt;
  }
  return true;
}

bool ExtBlkRef::unpack(Ref<vm::CellSlice> cs_ref, ton::BlockIdExt& blkid, ton::LogicalTime* end_lt) const {
  block::gen::ExtBlkRef::Record data;
  if (!tlb::csr_unpack_safe(std::move(cs_ref), data)) {
    blkid.invalidate();
    return false;
  }
  blkid.id = ton::BlockId{ton::masterchainId, ton::shardIdAll, data.seq_no};
  blkid.root_hash = data.root_hash;
  blkid.file_hash = data.file_hash;
  if (end_lt) {
    *end_lt = data.end_lt;
  }
  return true;
}

const ExtBlkRef t_ExtBlkRef;
const BlkMasterInfo t_BlkMasterInfo;

bool ShardIdent::validate_skip(vm::CellSlice& cs, bool weak) const {
  int shard_pfx_len, workchain_id;
  unsigned long long shard_pfx;
  if (cs.fetch_ulong(2) == 0 && cs.fetch_uint_to(6, shard_pfx_len) && cs.fetch_int_to(32, workchain_id) &&
      workchain_id != ton::workchainInvalid && cs.fetch_uint_to(64, shard_pfx)) {
    auto pow2 = (1ULL << (63 - shard_pfx_len));
    if (!(shard_pfx & (pow2 - 1))) {
      return true;
    }
  }
  return false;
}

bool ShardIdent::Record::check() const {
  return workchain_id != ton::workchainInvalid && !(shard_prefix & ((1ULL << (63 - shard_pfx_bits)) - 1));
}

bool ShardIdent::unpack(vm::CellSlice& cs, ShardIdent::Record& data) const {
  if (cs.fetch_ulong(2) == 0 && cs.fetch_uint_to(6, data.shard_pfx_bits) && cs.fetch_int_to(32, data.workchain_id) &&
      cs.fetch_uint_to(64, data.shard_prefix) && data.check()) {
    return true;
  } else {
    data.invalidate();
    return false;
  }
}

bool ShardIdent::pack(vm::CellBuilder& cb, const Record& data) const {
  return data.check() && cb.store_ulong_rchk_bool(0, 2) && cb.store_ulong_rchk_bool(data.shard_pfx_bits, 6) &&
         cb.store_long_rchk_bool(data.workchain_id, 32) && cb.store_ulong_rchk_bool(data.shard_prefix, 64);
}

bool ShardIdent::unpack(vm::CellSlice& cs, ton::WorkchainId& workchain, ton::ShardId& shard) const {
  int bits;
  unsigned long long pow2;
  auto assign = [](auto& a, auto b) { return a = b; };
  auto assign_or = [](auto& a, auto b) { return a |= b; };
  return cs.fetch_ulong(2) == 0                  // shard_ident$00
         && cs.fetch_uint_leq(60, bits)          // shard_pfx_bits:(#<= 60)
         && assign(pow2, (1ULL << (63 - bits)))  // (power)
         && cs.fetch_int_to(32, workchain)       // workchain_id:int32
         && cs.fetch_uint_to(64, shard)          // shard_prefix:uint64
         && workchain != ton::workchainInvalid && !(shard & (2 * pow2 - 1)) && assign_or(shard, pow2);
}

bool ShardIdent::unpack(vm::CellSlice& cs, ton::ShardIdFull& data) const {
  return unpack(cs, data.workchain, data.shard);
}

bool ShardIdent::pack(vm::CellBuilder& cb, ton::WorkchainId workchain, ton::ShardId shard) const {
  int bits = ton::shard_prefix_length(shard);
  return workchain != ton::workchainInvalid               // check workchain
         && shard                                         // check shard
         && cb.store_long_bool(0, 2)                      // shard_ident$00
         && cb.store_uint_leq(60, bits)                   // shard_pfx_bits:(#<= 60)
         && cb.store_long_bool(workchain, 32)             // workchain_id:int32
         && cb.store_long_bool(shard & (shard - 1), 64);  // shard_prefix:uint64
}

bool ShardIdent::pack(vm::CellBuilder& cb, ton::ShardIdFull data) const {
  return pack(cb, data.workchain, data.shard);
}

const ShardIdent t_ShardIdent;

bool BlockIdExt::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_ShardIdent.validate_skip(cs, weak) && cs.advance(32 + 256 * 2);
}

bool BlockIdExt::unpack(vm::CellSlice& cs, ton::BlockIdExt& data) const {
  return t_ShardIdent.unpack(cs, data.id.workchain, data.id.shard)  // block_id_ext$_ shard_id:ShardIdent
         && cs.fetch_uint_to(32, data.id.seqno)                     // seq_no:uint32
         && cs.fetch_bits_to(data.root_hash)                        // root_hash:bits256
         && cs.fetch_bits_to(data.file_hash);                       // file_hash:bits256
}

bool BlockIdExt::pack(vm::CellBuilder& cb, const ton::BlockIdExt& data) const {
  return t_ShardIdent.pack(cb, data.id.workchain, data.id.shard)  // block_id_ext$_ shard_id:ShardIdent
         && cb.store_long_bool(data.id.seqno, 32)                 // seq_no:uint32
         && cb.store_bits_bool(data.root_hash)                    // root_hash:bits256
         && cb.store_bits_bool(data.file_hash);                   // file_hash:bits256
}

const BlockIdExt t_BlockIdExt;

bool ShardState::skip(vm::CellSlice& cs) const {
  return get_tag(cs) == shard_state && cs.advance(64)  // shard_state#9023afe2 blockchain_id:int32
         && t_ShardIdent.skip(cs)                      // shard_id:ShardIdent
         && cs.advance(32 + 32 + 32 + 64 +
                       32)  // seq_no:int32 vert_seq_no:# gen_utime:uint32 gen_lt:uint64 min_ref_mc_seqno:uint32
         && t_Ref_OutMsgQueueInfo.skip(cs)  // out_msg_queue_info:^OutMsgQueueInfo
         && cs.advance(1)                   // before_split:Bool
         && cs.advance_refs(1)              // accounts:^ShardAccounts
         &&
         cs.advance_refs(
             1)  // ^[ total_balance:CurrencyCollection total_validator_fees:CurrencyCollection libraries:(HashmapE 256 LibDescr) master_ref:(Maybe BlkMasterInfo) ]
         && Maybe<RefTo<McStateExtra>>{}.skip(cs);  // custom:(Maybe ^McStateExtra)
}

bool ShardState::validate_skip(vm::CellSlice& cs, bool weak) const {
  int seq_no;
  return get_tag(cs) == shard_state && cs.advance(64)  // shard_state#9023afe2 blockchain_id:int32
         && t_ShardIdent.validate_skip(cs, weak)       // shard_id:ShardIdent
         && cs.fetch_int_to(32, seq_no)                // seq_no:int32
         && seq_no >= -1                               // { seq_no >= -1 }
         && cs.advance(32 + 32 + 64 + 32)  // vert_seq_no:# gen_utime:uint32 gen_lt:uint64 min_ref_mc_seqno:uint32
         && t_Ref_OutMsgQueueInfo.validate_skip(cs, weak)  // out_msg_queue_info:^OutMsgQueueInfo
         && cs.advance(1)                                  // before_split:Bool
         && t_ShardAccounts.validate_skip_ref(cs, weak)    // accounts:^ShardAccounts
         &&
         t_ShardState_aux.validate_skip_ref(
             cs,
             weak)  // ^[ total_balance:CurrencyCollection total_validator_fees:CurrencyCollection libraries:(HashmapE 256 LibDescr) master_ref:(Maybe BlkMasterInfo) ]
         && Maybe<RefTo<McStateExtra>>{}.validate_skip(cs, weak);  // custom:(Maybe ^McStateExtra)
}

const ShardState t_ShardState;

bool ShardState_aux::skip(vm::CellSlice& cs) const {
  return cs.advance(128)                        // overload_history:uint64 underload_history:uint64
         && t_CurrencyCollection.skip(cs)       // total_balance:CurrencyCollection
         && t_CurrencyCollection.skip(cs)       // total_validator_fees:CurrencyCollection
         && HashmapE{256, t_LibDescr}.skip(cs)  // libraries:(HashmapE 256 LibDescr)
         && Maybe<BlkMasterInfo>{}.skip(cs);    // master_ref:(Maybe BlkMasterInfo)
}

bool ShardState_aux::validate_skip(vm::CellSlice& cs, bool weak) const {
  return cs.advance(128)                                       // overload_history:uint64 underload_history:uint64
         && t_CurrencyCollection.validate_skip(cs, weak)       // total_balance:CurrencyCollection
         && t_CurrencyCollection.validate_skip(cs, weak)       // total_validator_fees:CurrencyCollection
         && HashmapE{256, t_LibDescr}.validate_skip(cs, weak)  // libraries:(HashmapE 256 LibDescr)
         && Maybe<BlkMasterInfo>{}.validate_skip(cs, weak);    // master_ref:(Maybe BlkMasterInfo)
}

const ShardState_aux t_ShardState_aux;

bool LibDescr::skip(vm::CellSlice& cs) const {
  return cs.advance(2)                      // shared_lib_descr$00
         && cs.fetch_ref().not_null()       // lib:^Cell
         && Hashmap{256, t_True}.skip(cs);  // publishers:(Hashmap 256 False)
}

bool LibDescr::validate_skip(vm::CellSlice& cs, bool weak) const {
  return get_tag(cs) == shared_lib_descr && cs.advance(2)  // shared_lib_descr$00
         && cs.fetch_ref().not_null()                      // lib:^Cell
         && Hashmap{256, t_True}.validate_skip(cs, weak);  // publishers:(Hashmap 256 False)
}

const LibDescr t_LibDescr;

bool BlkPrevInfo::skip(vm::CellSlice& cs) const {
  return t_ExtBlkRef.skip(cs)                   // prev_blk_info$_ {merged:#} prev:ExtBlkRef
         && (!merged || t_ExtBlkRef.skip(cs));  // prev_alt:merged?ExtBlkRef
}

bool BlkPrevInfo::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_ExtBlkRef.validate_skip(cs, weak)                   // prev_blk_info$_ {merged:#} prev:ExtBlkRef
         && (!merged || t_ExtBlkRef.validate_skip(cs, weak));  // prev_alt:merged?ExtBlkRef
}

const BlkPrevInfo t_BlkPrevInfo_0{0};

bool McStateExtra::skip(vm::CellSlice& cs) const {
  return block::gen::t_McStateExtra.skip(cs);
}

bool McStateExtra::validate_skip(vm::CellSlice& cs, bool weak) const {
  return block::gen::t_McStateExtra.validate_skip(cs, weak);  // ??
}

const McStateExtra t_McStateExtra;

const KeyExtBlkRef t_KeyExtBlkRef;

bool KeyMaxLt::add_values(vm::CellBuilder& cb, vm::CellSlice& cs1, vm::CellSlice& cs2) const {
  bool key1, key2;
  unsigned long long lt1, lt2;
  return cs1.fetch_bool_to(key1) && cs1.fetch_ulong_bool(64, lt1)     // cs1 => _ key:Bool max_end_lt:uint64 = KeyMaxLt;
         && cs2.fetch_bool_to(key2) && cs2.fetch_ulong_bool(64, lt2)  // cs2 => _ key:Bool max_end_lt:uint64 = KeyMaxLt;
         && cb.store_bool_bool(key1 | key2) && cb.store_long_bool(std::max(lt1, lt2), 64);
}

const KeyMaxLt t_KeyMaxLt;

bool Aug_OldMcBlocksInfo::eval_leaf(vm::CellBuilder& cb, vm::CellSlice& cs) const {
  return cs.have(65) && cb.append_bitslice(cs.prefetch_bits(65));  // copy first 1+64 bits
};

const Aug_OldMcBlocksInfo aug_OldMcBlocksInfo;

bool ShardFeeCreated::skip(vm::CellSlice& cs) const {
  return t_CurrencyCollection.skip(cs) && t_CurrencyCollection.skip(cs);
}

bool ShardFeeCreated::validate_skip(vm::CellSlice& cs, bool weak) const {
  return t_CurrencyCollection.validate_skip(cs, weak) && t_CurrencyCollection.validate_skip(cs, weak);
}

bool ShardFeeCreated::null_value(vm::CellBuilder& cb) const {
  return t_CurrencyCollection.null_value(cb) && t_CurrencyCollection.null_value(cb);
}

bool ShardFeeCreated::add_values(vm::CellBuilder& cb, vm::CellSlice& cs1, vm::CellSlice& cs2) const {
  return t_CurrencyCollection.add_values(cb, cs1, cs2) && t_CurrencyCollection.add_values(cb, cs1, cs2);
}

const ShardFeeCreated t_ShardFeeCreated;

bool Aug_ShardFees::eval_leaf(vm::CellBuilder& cb, vm::CellSlice& cs) const {
  return cb.append_cellslice_bool(cs) && t_ShardFeeCreated.skip(cs) && cs.empty_ext();
};

const Aug_ShardFees aug_ShardFees;

}  // namespace tlb
}  // namespace block
