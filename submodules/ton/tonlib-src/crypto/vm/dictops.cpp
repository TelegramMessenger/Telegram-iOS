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
#include <functional>
#include "vm/log.h"
#include "vm/opctable.h"
#include "vm/stack.hpp"
#include "vm/excno.hpp"
#include "vm/vm.h"
#include "common/bigint.hpp"
#include "common/refint.h"
#include "vm/dictops.h"
#include "vm/dict.h"

namespace vm {

template <typename T>
void push_dict(Stack& stack, T&& dict) {
  stack.push_maybe_cell(std::move(dict).extract_root_cell());
}

template <typename T>
void push_dict(Stack& stack, const T& dict) {
  stack.push_maybe_cell(dict.get_root_cell());
}

int exec_dict_empty(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DICTEMPTY";
  auto dict = stack.pop_cellslice();
  if (!dict->have(1)) {
    throw VmError{Excno::cell_und};
  }
  stack.push_smallint(~dict->prefetch_long(1));
  return 0;
}

int exec_store_dict(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute STDICT";
  stack.check_underflow(2);
  auto cb = stack.pop_builder();
  auto d = stack.pop_maybe_cell();
  if (!cb.write().store_maybe_ref(std::move(d))) {
    throw VmError{Excno::cell_ov};
  }
  stack.push_builder(std::move(cb));
  return 0;
}

int dict_nonempty(const CellSlice& dict) {
  if (!dict.have(1)) {
    return -1;
  }
  int res = (int)dict.prefetch_ulong(1);
  return dict.have_refs(res) ? res : -1;
}

int dict_nonempty_chk(const CellSlice& dict) {
  int res = dict_nonempty(dict);
  if (res < 0) {
    throw VmError{Excno::cell_und};
  }
  return res;
}

int exec_skip_dict(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute SKIPDICT\n";
  auto dict = stack.pop_cellslice();
  int res = dict_nonempty_chk(*dict);
  dict.write().advance_ext(1, res);
  stack.push_cellslice(std::move(dict));
  return 0;
}

int exec_load_optref(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute LDOPTREF\n";
  auto dict = stack.pop_cellslice();
  int res = dict_nonempty_chk(*dict);
  dict.write().advance(1);
  if (res) {
    auto cell = dict.write().fetch_ref();
    stack.push_cellslice(std::move(dict));
    stack.push_cell(std::move(cell));
  } else {
    stack.push_cellslice(std::move(dict));
  }
  stack.push_smallint(-res);
  return 0;
}

int exec_preload_optref(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PLDOPTREF\n";
  auto dict = stack.pop_cellslice();
  int res = dict_nonempty_chk(*dict);
  if (res) {
    stack.push_cell(dict->prefetch_ref());
  }
  stack.push_smallint(-res);
  return 0;
}

int exec_load_dict_slice(VmState* st, unsigned args) {
  bool preload = args & 1, quiet = args & 2;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << (preload ? "P" : "") << "LDDICTS" << (quiet ? "Q\n" : "\n");
  auto cs = stack.pop_cellslice();
  int res = dict_nonempty(*cs);
  if (res < 0) {
    if (!quiet) {
      throw VmError{Excno::cell_und};
    }
    if (!preload) {
      stack.push_cellslice(std::move(cs));
    }
  } else {
    if (preload) {
      stack.push_cellslice(cs->prefetch_subslice(1, res));
    } else {
      stack.push_cellslice(cs.write().fetch_subslice(1, res));
      stack.push_cellslice(std::move(cs));
    }
  }
  if (quiet) {
    stack.push_bool(res >= 0);
  }
  return 0;
}

int exec_load_dict(VmState* st, unsigned args) {
  bool preload = args & 1, quiet = args & 2;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << (preload ? "P" : "") << "LDDICT" << (quiet ? "Q\n" : "\n");
  auto cs = stack.pop_cellslice();
  int res = dict_nonempty(*cs);
  if (res < 0) {
    if (!quiet) {
      throw VmError{Excno::cell_und};
    }
    if (!preload) {
      stack.push_cellslice(std::move(cs));
    }
  } else {
    stack.push_maybe_cell(res ? cs->prefetch_ref() : Ref<Cell>{});
    if (!preload) {
      cs.write().advance_ext(1, res);
      stack.push_cellslice(std::move(cs));
    }
  }
  if (quiet) {
    stack.push_bool(res >= 0);
  }
  return 0;
}

std::string dump_dictop(unsigned args, const char* name) {
  std::ostringstream os{"DICT"};
  if (args & 4) {
    os << (args & 2 ? 'U' : 'I');
  }
  os << name;
  if (args & 1) {
    os << "REF";
  }
  return os.str();
}

std::string dump_dictop2(unsigned args, const char* name) {
  std::ostringstream os{"DICT"};
  if (args & 2) {
    os << (args & 1 ? 'U' : 'I');
  }
  os << name;
  return os.str();
}

std::string dump_subdictop2(unsigned args, const char* name) {
  std::ostringstream os{"SUBDICT"};
  if (args & 2) {
    os << (args & 1 ? 'U' : 'I');
  }
  os << name;
  return os.str();
}

int exec_dict_get(VmState* st, unsigned args) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DICT" << (args & 4 ? (args & 2 ? "U" : "I") : "") << "GET" << (args & 1 ? "REF" : "");
  stack.check_underflow(3);
  int n = stack.pop_smallint_range(Dictionary::max_key_bits);
  Dictionary dict{stack.pop_maybe_cell(), n};
  BitSlice key;
  unsigned char buffer[Dictionary::max_key_bytes];
  if (args & 4) {
    key = dict.integer_key(stack.pop_int_finite(), n, !(args & 2), buffer, true);
    if (!key.is_valid()) {
      stack.push_smallint(0);
      return 0;
    }
  } else {
    key = stack.pop_cellslice()->prefetch_bits(n);
  }
  if (!key.is_valid()) {
    throw VmError{Excno::cell_und, "not enough bits for a dictionary key"};
  }
  if (args & 1) {
    auto value = dict.lookup_ref(key);
    if (value.not_null()) {
      stack.push_cell(std::move(value));
      stack.push_smallint(-1);
    } else {
      stack.push_smallint(0);
    }
  } else {
    auto value = dict.lookup(key);
    if (value.not_null()) {
      stack.push_cellslice(std::move(value));
      stack.push_smallint(-1);
    } else {
      stack.push_smallint(0);
    }
  }
  return 0;
}

int exec_dict_get_optref(VmState* st, unsigned args) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DICT" << (args & 2 ? (args & 1 ? "U" : "I") : "") << "GETOPTREF";
  stack.check_underflow(3);
  int n = stack.pop_smallint_range(Dictionary::max_key_bits);
  Dictionary dict{stack.pop_maybe_cell(), n};
  BitSlice key;
  unsigned char buffer[Dictionary::max_key_bytes];
  if (args & 2) {
    key = dict.integer_key(stack.pop_int_finite(), n, !(args & 1), buffer, true);
    if (!key.is_valid()) {
      stack.push_null();
      return 0;
    }
  } else {
    key = stack.pop_cellslice()->prefetch_bits(n);
  }
  if (!key.is_valid()) {
    throw VmError{Excno::cell_und, "not enough bits for a dictionary key"};
  }
  stack.push_maybe_cell(dict.lookup_ref(key));
  return 0;
}

int exec_dict_set(VmState* st, unsigned args, Dictionary::SetMode mode, const char* name, bool bld = false) {
  args <<= (bld ? 1 : 0);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DICT" << (args & 4 ? (args & 2 ? "U" : "I") : "") << name
             << (args & 1 ? "REF" : (bld ? "B" : ""));
  stack.check_underflow(4);
  int n = stack.pop_smallint_range(Dictionary::max_key_bits);
  Dictionary dict{stack.pop_maybe_cell(), n};
  BitSlice key;
  unsigned char buffer[Dictionary::max_key_bytes];
  if (args & 4) {
    key = dict.integer_key(stack.pop_int(), n, !(args & 2), buffer);
  } else {
    key = stack.pop_cellslice()->prefetch_bits(n);
  }
  bool res;
  if (bld) {
    auto new_value = stack.pop_builder();
    if (!key.is_valid()) {
      throw VmError{Excno::cell_und, "not enough bits for a dictionary key"};
    }
    res = dict.set_builder(key, std::move(new_value), mode);
  } else if (!(args & 1)) {
    auto new_value = stack.pop_cellslice();
    if (!key.is_valid()) {
      throw VmError{Excno::cell_und, "not enough bits for a dictionary key"};
    }
    res = dict.set(key, std::move(new_value), mode);
  } else {
    auto new_value_ref = stack.pop_cell();
    if (!key.is_valid()) {
      throw VmError{Excno::cell_und, "not enough bits for a dictionary key"};
    }
    res = dict.set_ref(key, std::move(new_value_ref), mode);
  }
  push_dict(stack, std::move(dict));
  if (mode == Dictionary::SetMode::Set) {
    st->ensure_throw(res);
  } else {
    stack.push_bool(res);
  }
  return 0;
}

int exec_dict_setget(VmState* st, unsigned args, Dictionary::SetMode mode, const char* name, bool bld = false) {
  args <<= (bld ? 1 : 0);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DICT" << (args & 4 ? (args & 2 ? "U" : "I") : "") << name
             << (args & 1 ? "REF\n" : (bld ? "B\n" : "\n"));
  stack.check_underflow(4);
  int n = stack.pop_smallint_range(Dictionary::max_key_bits);
  Dictionary dict{stack.pop_maybe_cell(), n};
  BitSlice key;
  unsigned char buffer[Dictionary::max_key_bytes];
  if (args & 4) {
    key = dict.integer_key(stack.pop_int(), n, !(args & 2), buffer);
  } else {
    key = stack.pop_cellslice()->prefetch_bits(n);
  }
  bool ok_f = (mode != Dictionary::SetMode::Add);
  if (bld) {
    auto new_value = stack.pop_builder();
    if (!key.is_valid()) {
      throw VmError{Excno::cell_und, "not enough bits for a dictionary key"};
    }
    auto res = dict.lookup_set_builder(key, std::move(new_value), mode);
    push_dict(stack, std::move(dict));
    if (res.not_null()) {
      stack.push_cellslice(std::move(res));
      stack.push_bool(ok_f);
    } else {
      stack.push_bool(!ok_f);
    }
  } else if (!(args & 1)) {
    auto new_value = stack.pop_cellslice();
    if (!key.is_valid()) {
      throw VmError{Excno::cell_und, "not enough bits for a dictionary key"};
    }
    auto res = dict.lookup_set(key, std::move(new_value), mode);
    push_dict(stack, std::move(dict));
    if (res.not_null()) {
      stack.push_cellslice(std::move(res));
      stack.push_bool(ok_f);
    } else {
      stack.push_bool(!ok_f);
    }
  } else {
    auto new_value_ref = stack.pop_cell();
    if (!key.is_valid()) {
      throw VmError{Excno::cell_und, "not enough bits for a dictionary key"};
    }
    auto res = dict.lookup_set_ref(key, std::move(new_value_ref), mode);
    push_dict(stack, std::move(dict));
    if (res.not_null()) {
      stack.push_cell(std::move(res));
      stack.push_bool(ok_f);
    } else {
      stack.push_bool(!ok_f);
    }
  }
  return 0;
}

int exec_dict_delete(VmState* st, unsigned args) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DICT" << (args & 2 ? (args & 1 ? "U" : "I") : "") << "DEL\n";
  stack.check_underflow(3);
  int n = stack.pop_smallint_range(Dictionary::max_key_bits);
  Dictionary dict{stack.pop_maybe_cell(), n};
  BitSlice key;
  unsigned char buffer[Dictionary::max_key_bytes];
  if (args & 2) {
    key = dict.integer_key(stack.pop_int_finite(), n, !(args & 1), buffer);
    if (!key.is_valid()) {
      push_dict(stack, std::move(dict));
      stack.push_smallint(0);
      return 0;
    }
  } else {
    key = stack.pop_cellslice()->prefetch_bits(n);
  }
  if (!key.is_valid()) {
    throw VmError{Excno::cell_und, "not enough bits for a dictionary key"};
  }
  bool res = dict.lookup_delete(key).not_null();
  push_dict(stack, std::move(dict));
  stack.push_bool(res);
  return 0;
}

int exec_dict_deleteget(VmState* st, unsigned args) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DICT" << (args & 4 ? (args & 2 ? "U" : "I") : "") << "DELGET" << (args & 1 ? "REF\n" : "\n");
  stack.check_underflow(3);
  int n = stack.pop_smallint_range(Dictionary::max_key_bits);
  Dictionary dict{stack.pop_maybe_cell(), n};
  BitSlice key;
  unsigned char buffer[Dictionary::max_key_bytes];
  if (args & 4) {
    key = dict.integer_key(stack.pop_int_finite(), n, !(args & 2), buffer);
    if (!key.is_valid()) {
      push_dict(stack, std::move(dict));
      stack.push_smallint(0);
      return 0;
    }
  } else {
    key = stack.pop_cellslice()->prefetch_bits(n);
  }
  if (!key.is_valid()) {
    throw VmError{Excno::cell_und, "not enough bits for a dictionary key"};
  }
  if (!(args & 1)) {
    auto res = dict.lookup_delete(key);
    push_dict(stack, std::move(dict));
    bool ok = res.not_null();
    if (ok) {
      stack.push_cellslice(std::move(res));
    }
    stack.push_bool(ok);
  } else {
    auto res = dict.lookup_delete_ref(key);
    push_dict(stack, std::move(dict));
    bool ok = res.not_null();
    if (ok) {
      stack.push_cell(std::move(res));
    }
    stack.push_bool(ok);
  }
  return 0;
}

int exec_dict_setget_optref(VmState* st, unsigned args) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DICT" << (args & 2 ? (args & 1 ? "U" : "I") : "") << "SETGETOPTREF";
  stack.check_underflow(4);
  int n = stack.pop_smallint_range(Dictionary::max_key_bits);
  Dictionary dict{stack.pop_maybe_cell(), n};
  BitSlice key;
  unsigned char buffer[Dictionary::max_key_bytes];
  if (args & 2) {
    key = dict.integer_key(stack.pop_int(), n, !(args & 1), buffer);
  } else {
    key = stack.pop_cellslice()->prefetch_bits(n);
  }
  auto new_value = stack.pop_maybe_cell();
  if (!key.is_valid()) {
    throw VmError{Excno::cell_und, "not enough bits for a dictionary key"};
  }
  Ref<vm::Cell> value;
  if (new_value.not_null()) {
    value = dict.lookup_set_ref(key, std::move(new_value));
  } else {
    value = dict.lookup_delete_ref(key);
  }
  push_dict(stack, std::move(dict));
  stack.push_maybe_cell(std::move(value));
  return 0;
}

int exec_dict_getmin(VmState* st, unsigned args) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DICT" << (args & 4 ? (args & 2 ? "U" : "I") : "") << (args & 16 ? "REM" : "")
             << (args & 8 ? "MAX" : "MIN") << (args & 1 ? "REF\n" : "\n");
  stack.check_underflow(2);
  int n = stack.pop_smallint_range(args & 4 ? (args & 2 ? 256 : 257) : Dictionary::max_key_bits);
  Dictionary dict{stack.pop_maybe_cell(), n};
  unsigned char buffer[Dictionary::max_key_bytes];
  bool flip_first = !(args & 2);
  if (!(args & 1)) {
    auto res = (args & 16) ? dict.extract_minmax_key(buffer, n, args & 8, flip_first)
                           : dict.get_minmax_key(buffer, n, args & 8, flip_first);
    if (args & 16) {
      push_dict(stack, std::move(dict));
    }
    if (res.is_null()) {
      stack.push_bool(false);
      return 0;
    }
    stack.push_cellslice(std::move(res));
  } else {
    auto res = (args & 16) ? dict.extract_minmax_key_ref(buffer, n, args & 8, flip_first)
                           : dict.get_minmax_key_ref(buffer, n, args & 8, flip_first);
    if (args & 16) {
      push_dict(stack, std::move(dict));
    }
    if (res.is_null()) {
      stack.push_bool(false);
      return 0;
    }
    stack.push_cell(std::move(res));
  }
  if (args & 4) {
    td::RefInt256 x{true};
    x.unique_write().import_bits(td::ConstBitPtr{buffer}, n, !(args & 2));
    stack.push_int(std::move(x));
  } else {
    stack.push_cellslice(Ref<CellSlice>{true, CellBuilder().store_bits(td::ConstBitPtr{buffer}, n).finalize()});
  }
  stack.push_bool(true);
  return 0;
}

std::string dump_dictop_getnear(CellSlice& cs, unsigned args) {
  std::ostringstream os{"DICT"};
  if (args & 8) {
    os << (args & 4 ? 'U' : 'I');
  }
  os << "GET" << (args & 2 ? "PREV" : "NEXT") << (args & 1 ? "EQ" : "");
  return os.str();
}

int exec_dict_getnear(VmState* st, unsigned args) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DICT" << (args & 8 ? (args & 4 ? "U" : "I") : "") << "GET" << (args & 2 ? "PREV" : "NEXT")
             << (args & 1 ? "EQ\n" : "\n");
  stack.check_underflow(3);
  int n = stack.pop_smallint_range(args & 8 ? (args & 4 ? 256 : 257) : Dictionary::max_key_bits);
  Dictionary dict{stack.pop_maybe_cell(), n};
  unsigned char buffer[Dictionary::max_key_bytes];
  bool sgnd = !(args & 4), go_up = !(args & 2), allow_eq = args & 1;
  if (!(args & 8)) {
    auto key_hint = stack.pop_cellslice()->prefetch_bits(n);
    if (!key_hint.is_valid()) {
      throw VmError{Excno::cell_und, "not enough bits for a dictionary key hint"};
    }
    td::BitPtr{buffer}.copy_from(key_hint.bits(), n);
    key_hint.forget();
    auto res = dict.lookup_nearest_key(td::BitPtr{buffer}, n, go_up, allow_eq, false);
    if (res.is_null()) {
      stack.push_bool(false);
      return 0;
    }
    stack.push_cellslice(std::move(res));
    stack.push_cellslice(Ref<CellSlice>{true, CellBuilder().store_bits(td::ConstBitPtr{buffer}, n).finalize()});
  } else {
    auto key = stack.pop_int_finite();
    Ref<CellSlice> res;
    if (key->export_bits(td::BitPtr{buffer}, n, sgnd)) {
      res = dict.lookup_nearest_key(buffer, n, go_up, allow_eq, sgnd);
    } else if ((td::sgn(key) >= 0) ^ go_up) {
      res = dict.get_minmax_key(buffer, n, !go_up, sgnd);
    }
    if (res.is_null()) {
      stack.push_bool(false);
      return 0;
    }
    stack.push_cellslice(std::move(res));
    key.write().import_bits(td::ConstBitPtr{buffer}, n, sgnd);
    stack.push_int(std::move(key));
  }
  stack.push_bool(true);
  return 0;
}

int exec_pfx_dict_set(VmState* st, Dictionary::SetMode mode, const char* name) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PFXDICT" << name;
  stack.check_underflow(3);
  int n = stack.pop_smallint_range(PrefixDictionary::max_key_bits);
  PrefixDictionary dict{stack.pop_maybe_cell(), n};
  auto key_slice = stack.pop_cellslice();
  auto new_value = stack.pop_cellslice();
  bool res = dict.set(key_slice->data_bits(), key_slice->size(), std::move(new_value), mode);
  push_dict(stack, std::move(dict));
  stack.push_bool(res);
  return 0;
}

int exec_pfx_dict_delete(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PFXDICTDEL\n";
  stack.check_underflow(2);
  int n = stack.pop_smallint_range(PrefixDictionary::max_key_bits);
  PrefixDictionary dict{stack.pop_maybe_cell(), n};
  auto key_slice = stack.pop_cellslice();
  bool res = dict.lookup_delete(key_slice->data_bits(), key_slice->size()).not_null();
  push_dict(stack, std::move(dict));
  stack.push_bool(res);
  return 0;
}

int exec_dict_get_exec(VmState* st, unsigned args) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DICT" << (args & 1 ? 'U' : 'I') << "GET" << (args & 2 ? "EXEC" : "JMP")
             << (args & 4 ? "Z" : "");
  stack.check_underflow(3);
  int n = stack.pop_smallint_range(Dictionary::max_key_bits);
  Dictionary dict{stack.pop_maybe_cell(), n};
  unsigned char buffer[Dictionary::max_key_bytes];
  auto idx = stack.pop_int_finite();
  if (dict.integer_key_simple(idx, n, !(args & 1), td::BitPtr{buffer}, true)) {
    auto value = dict.lookup(td::BitPtr{buffer}, n);
    if (value.not_null()) {
      Ref<OrdCont> cont{true, std::move(value), st->get_cp()};
      return (args & 2) ? st->call(std::move(cont)) : st->jump(std::move(cont));
    }
  }
  // key not found or out of range
  if (args & 4) {
    stack.push_int(std::move(idx));
  }
  return 0;
}

std::string dump_dict_get_exec(CellSlice& cs, unsigned args) {
  return std::string{"DICT"} + (args & 1 ? 'U' : 'I') + "GET" + (args & 2 ? "EXEC" : "JMP") + (args & 4 ? "Z" : "");
}

int exec_push_const_dict(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  if (!cs.have(pfx_bits)) {
    throw VmError{Excno::inv_opcode, "not enough data bits for a DICTPUSHCONST instruction"};
  }
  if (!cs.have_refs(1)) {
    throw VmError{Excno::inv_opcode, "not enough references for a DICTPUSHCONST instruction"};
  }
  Stack& stack = st->get_stack();
  cs.advance(pfx_bits - 11);
  auto slice = cs.fetch_subslice(1, 1);
  int n = (int)cs.fetch_ulong(10);
  VM_LOG(st) << "execute DICTPUSHCONST " << n << " (" << slice << ")";
  stack.push_cell(slice->prefetch_ref());
  stack.push_smallint(n);
  return 0;
}

std::string dump_push_const_dict(CellSlice& cs, int pfx_bits, const char* name) {
  if (!cs.have(pfx_bits, 1)) {
    return "";
  }
  cs.advance(pfx_bits - 11);
  auto slice = cs.fetch_subslice(1, 1);
  int n = (int)cs.fetch_ulong(10);
  std::ostringstream os{name};
  os << ' ' << n << " (";
  slice->dump_hex(os, false);
  os << ')';
  return os.str();
}

int compute_len_push_const_dict(const CellSlice& cs, unsigned args, int pfx_bits) {
  if (!cs.have(pfx_bits, 1)) {
    return 0;
  }
  return 0x10000 + pfx_bits;
}

int exec_pfx_dict_get(VmState* st, int op, const char* name_suff) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PFXDICTGET" << name_suff;
  stack.check_underflow(3);
  int n = stack.pop_smallint_range(PrefixDictionary::max_key_bits);
  PrefixDictionary dict{stack.pop_maybe_cell(), n};
  auto cs = stack.pop_cellslice();
  auto res = dict.lookup_prefix(cs->data_bits(), cs->size());
  if (res.first.is_null()) {
    if (op & 1) {
      throw VmError{Excno::cell_und, "cannot parse a prefix belonging to a given prefix code dictionary"};
    }
    stack.push_cellslice(std::move(cs));
    if (!op) {
      stack.push_bool(false);
    }
    return 0;
  }
  stack.push_cellslice(cs.write().fetch_subslice(res.second));
  if (!(op & 2)) {
    stack.push_cellslice(std::move(res.first));
  }
  stack.push_cellslice(std::move(cs));
  if (!op) {
    stack.push_bool(true);
    return 0;
  }
  if (op == 1) {
    return 0;
  }
  Ref<OrdCont> cont{true, std::move(res.first), st->get_cp()};
  return op & 1 ? st->call(std::move(cont)) : st->jump(std::move(cont));
}

int exec_const_pfx_dict_switch(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  if (!cs.have(pfx_bits)) {
    throw VmError{Excno::inv_opcode, "not enough data bits for a PFXDICTSWITCH instruction"};
  }
  if (!cs.have_refs(1)) {
    throw VmError{Excno::inv_opcode, "not enough references for a PFXDICTSWITCH instruction"};
  }
  Stack& stack = st->get_stack();
  cs.advance(pfx_bits - 11);

  auto dict_slice = cs.fetch_subslice(1, 1);
  int n = (int)cs.fetch_ulong(10);

  VM_LOG(st) << "execute PFXDICTSWITCH " << n << " (" << dict_slice << ")";

  PrefixDictionary dict{std::move(dict_slice), n};
  auto cs1 = stack.pop_cellslice();
  auto res = dict.lookup_prefix(cs1->data_bits(), cs1->size());

  if (res.first.is_null()) {
    stack.push_cellslice(std::move(cs1));
    return 0;
  } else {
    stack.push_cellslice(cs1.write().fetch_subslice(res.second));
    stack.push_cellslice(std::move(cs1));
    Ref<OrdCont> cont{true, std::move(res.first), st->get_cp()};
    return st->jump(std::move(cont));
  }
}

int exec_subdict_get(VmState* st, unsigned args) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute SUBDICT" << (args & 2 ? (args & 1 ? "U" : "I") : "") << (args & 4 ? "RP" : "") << "GET";
  stack.check_underflow(4);
  int n = stack.pop_smallint_range(Dictionary::max_key_bits);
  Dictionary dict{stack.pop_maybe_cell(), n};
  int mk = (args & 2 ? (args & 1 ? 256 : 257) : Dictionary::max_key_bits);
  int k = stack.pop_smallint_range(std::min(mk, n));
  BitSlice key;
  unsigned char buffer[Dictionary::max_key_bytes];
  if (args & 2) {
    key = dict.integer_key(stack.pop_int_finite(), k, !(args & 1), buffer, true);
  } else {
    key = stack.pop_cellslice()->prefetch_bits(k);
  }
  if (!key.is_valid()) {
    throw VmError{Excno::cell_und, "not enough bits for a dictionary key prefix"};
  }
  if (!dict.cut_prefix_subdict(key.bits(), k, args & 4)) {
    throw VmError{Excno::dict_err, "cannot construct subdictionary by key prefix"};
  }
  push_dict(stack, std::move(dict));
  return 0;
}

void register_dictionary_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  cp0.insert(OpcodeInstr::mksimple(0xf400, 16, "STDICT", exec_store_dict))
      .insert(OpcodeInstr::mksimple(0xf401, 16, "SKIPDICT", exec_skip_dict))
      .insert(OpcodeInstr::mksimple(0xf402, 16, "LDDICTS", std::bind(exec_load_dict_slice, _1, 0)))
      .insert(OpcodeInstr::mksimple(0xf403, 16, "PLDDICTS", std::bind(exec_load_dict_slice, _1, 1)))
      .insert(OpcodeInstr::mksimple(0xf404, 16, "LDDICT", std::bind(exec_load_dict, _1, 0)))
      .insert(OpcodeInstr::mksimple(0xf405, 16, "PLDDICT", std::bind(exec_load_dict, _1, 1)))
      .insert(OpcodeInstr::mksimple(0xf406, 16, "LDDICTQ", std::bind(exec_load_dict, _1, 2)))
      .insert(OpcodeInstr::mksimple(0xf407, 16, "PLDDICTQ", std::bind(exec_load_dict, _1, 3)))
      .insert(OpcodeInstr::mkfixedrange(0xf40a, 0xf410, 16, 3, std::bind(dump_dictop, _2, "GET"), exec_dict_get))
      .insert(OpcodeInstr::mkfixedrange(0xf412, 0xf418, 16, 3, std::bind(dump_dictop, _2, "SET"),
                                        std::bind(exec_dict_set, _1, _2, Dictionary::SetMode::Set, "SET", false)))
      .insert(OpcodeInstr::mkfixedrange(0xf41a, 0xf420, 16, 3, std::bind(dump_dictop, _2, "SETGET"),
                                        std::bind(exec_dict_setget, _1, _2, Dictionary::SetMode::Set, "SETGET", false)))
      .insert(
          OpcodeInstr::mkfixedrange(0xf422, 0xf428, 16, 3, std::bind(dump_dictop, _2, "REPLACE"),
                                    std::bind(exec_dict_set, _1, _2, Dictionary::SetMode::Replace, "REPLACE", false)))
      .insert(OpcodeInstr::mkfixedrange(
          0xf42a, 0xf430, 16, 3, std::bind(dump_dictop, _2, "REPLACEGET"),
          std::bind(exec_dict_setget, _1, _2, Dictionary::SetMode::Replace, "REPLACEGET", false)))
      .insert(OpcodeInstr::mkfixedrange(0xf432, 0xf438, 16, 3, std::bind(dump_dictop, _2, "ADD"),
                                        std::bind(exec_dict_set, _1, _2, Dictionary::SetMode::Add, "ADD", false)))
      .insert(OpcodeInstr::mkfixedrange(0xf43a, 0xf440, 16, 3, std::bind(dump_dictop, _2, "ADDGET"),
                                        std::bind(exec_dict_setget, _1, _2, Dictionary::SetMode::Add, "ADDGET", false)))
      .insert(OpcodeInstr::mkfixedrange(0xf441, 0xf444, 16, 2, std::bind(dump_dictop2, _2, "SETB"),
                                        std::bind(exec_dict_set, _1, _2, Dictionary::SetMode::Set, "SET", true)))
      .insert(OpcodeInstr::mkfixedrange(0xf445, 0xf448, 16, 2, std::bind(dump_dictop2, _2, "SETGETB"),
                                        std::bind(exec_dict_setget, _1, _2, Dictionary::SetMode::Set, "SETGET", true)))
      .insert(
          OpcodeInstr::mkfixedrange(0xf449, 0xf44c, 16, 2, std::bind(dump_dictop2, _2, "REPLACEB"),
                                    std::bind(exec_dict_set, _1, _2, Dictionary::SetMode::Replace, "REPLACE", true)))
      .insert(OpcodeInstr::mkfixedrange(
          0xf44d, 0xf450, 16, 2, std::bind(dump_dictop2, _2, "REPLACEGETB"),
          std::bind(exec_dict_setget, _1, _2, Dictionary::SetMode::Replace, "REPLACEGET", true)))
      .insert(OpcodeInstr::mkfixedrange(0xf451, 0xf454, 16, 2, std::bind(dump_dictop2, _2, "ADDB"),
                                        std::bind(exec_dict_set, _1, _2, Dictionary::SetMode::Add, "ADD", true)))
      .insert(OpcodeInstr::mkfixedrange(0xf455, 0xf458, 16, 2, std::bind(dump_dictop2, _2, "ADDGETB"),
                                        std::bind(exec_dict_setget, _1, _2, Dictionary::SetMode::Add, "ADDGET", true)))
      .insert(OpcodeInstr::mkfixedrange(0xf459, 0xf45c, 16, 2, std::bind(dump_dictop2, _2, "DEL"), exec_dict_delete))
      .insert(
          OpcodeInstr::mkfixedrange(0xf462, 0xf468, 16, 3, std::bind(dump_dictop, _2, "DELGET"), exec_dict_deleteget))
      .insert(OpcodeInstr::mkfixedrange(0xf469, 0xf46c, 16, 2, std::bind(dump_dictop2, _2, "GETOPTREF"),
                                        exec_dict_get_optref))
      .insert(OpcodeInstr::mkfixedrange(0xf46d, 0xf470, 16, 2, std::bind(dump_dictop2, _2, "SETGETOPTREF"),
                                        exec_dict_setget_optref))
      .insert(OpcodeInstr::mksimple(0xf470, 16, "PFXDICTSET",
                                    std::bind(exec_pfx_dict_set, _1, PrefixDictionary::SetMode::Set, "SET")))
      .insert(OpcodeInstr::mksimple(0xf471, 16, "PFXDICTREPLACE",
                                    std::bind(exec_pfx_dict_set, _1, PrefixDictionary::SetMode::Replace, "REPLACE")))
      .insert(OpcodeInstr::mksimple(0xf472, 16, "PFXDICTADD",
                                    std::bind(exec_pfx_dict_set, _1, PrefixDictionary::SetMode::Add, "ADD")))
      .insert(OpcodeInstr::mksimple(0xf473, 16, "PFXDICTDEL", exec_pfx_dict_delete))
      .insert(OpcodeInstr::mkfixedrange(0xf474, 0xf480, 16, 4, dump_dictop_getnear, exec_dict_getnear))
      .insert(OpcodeInstr::mkfixedrange(0xf482, 0xf488, 16, 5, std::bind(dump_dictop, _2, "MIN"), exec_dict_getmin))
      .insert(OpcodeInstr::mkfixedrange(0xf48a, 0xf490, 16, 5, std::bind(dump_dictop, _2, "MAX"), exec_dict_getmin))
      .insert(OpcodeInstr::mkfixedrange(0xf492, 0xf498, 16, 5, std::bind(dump_dictop, _2, "REMMIN"), exec_dict_getmin))
      .insert(OpcodeInstr::mkfixedrange(0xf49a, 0xf4a0, 16, 5, std::bind(dump_dictop, _2, "REMMAX"), exec_dict_getmin))
      .insert(OpcodeInstr::mkfixed(0xf4a0 >> 2, 14, 2, dump_dict_get_exec, exec_dict_get_exec))
      .insert(OpcodeInstr::mkextrange(0xf4a400, 0xf4a800, 24, 11,
                                      std::bind(dump_push_const_dict, _1, _3, "DICTPUSHCONST"), exec_push_const_dict,
                                      compute_len_push_const_dict))
      .insert(OpcodeInstr::mksimple(0xf4a8, 16, "PFXDICTGETQ", std::bind(exec_pfx_dict_get, _1, 0, "Q")))
      .insert(OpcodeInstr::mksimple(0xf4a9, 16, "PFXDICTGET", std::bind(exec_pfx_dict_get, _1, 1, "")))
      .insert(OpcodeInstr::mksimple(0xf4aa, 16, "PFXDICTGETJMP", std::bind(exec_pfx_dict_get, _1, 2, "JMP")))
      .insert(OpcodeInstr::mksimple(0xf4ab, 16, "PFXDICTGETEXEC", std::bind(exec_pfx_dict_get, _1, 3, "EXEC")))
      .insert(OpcodeInstr::mkextrange(0xf4ac00, 0xf4b000, 24, 11,
                                      std::bind(dump_push_const_dict, _1, _3, "PFXDICTSWITCH"),
                                      exec_const_pfx_dict_switch, compute_len_push_const_dict))
      .insert(OpcodeInstr::mkfixedrange(0xf4b1, 0xf4b4, 16, 3, std::bind(dump_subdictop2, _2, "GET"), exec_subdict_get))
      .insert(
          OpcodeInstr::mkfixedrange(0xf4b5, 0xf4b8, 16, 3, std::bind(dump_subdictop2, _2, "RPGET"), exec_subdict_get))
      .insert(OpcodeInstr::mkfixed(0xf4bc >> 2, 14, 2, dump_dict_get_exec, exec_dict_get_exec));
}

}  // namespace vm
