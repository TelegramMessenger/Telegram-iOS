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
#include "vm/stack.hpp"
#include "vm/continuation.h"
#include "vm/box.hpp"
#include "vm/atom.h"
#include "vm/vmstate.h"

namespace td {
template class td::Cnt<std::string>;
template class td::Ref<td::Cnt<std::string>>;
template class td::Cnt<std::vector<vm::StackEntry>>;
template class td::Ref<td::Cnt<std::vector<vm::StackEntry>>>;
}  // namespace td

namespace vm {

// from_object_t from_object{};

const char* exception_messages[(int)(Excno::total)] = {
    "normal termination",   "alternative termination", "stack underflow",  "stack overflow", "integer overflow",
    "integer out of range", "invalid opcode",          "type check error", "cell overflow",  "cell underflow",
    "dictionary error",     "unknown error",           "fatal error"};

const char* get_exception_msg(Excno exc_no) {
  if (exc_no >= Excno::none && exc_no < Excno::total) {
    return exception_messages[static_cast<int>(exc_no)];
  } else {
    return "unknown vm exception";
  }
}

bool StackEntry::is_list(const StackEntry* se) {
  Ref<Tuple> tuple;
  while (!se->empty()) {
    tuple = se->as_tuple_range(2, 2);
    if (tuple.is_null()) {
      return false;
    }
    se = &tuple->at(1);
  }
  return true;
}

static const char HEX_digits[] = "0123456789ABCDEF";

std::string str_to_hex(std::string data, std::string prefix) {
  prefix.reserve(prefix.size() + data.size() * 2);
  for (char c : data) {
    prefix += HEX_digits[(c >> 4) & 15];
    prefix += HEX_digits[c & 15];
  }
  return prefix;
}

std::string StackEntry::to_string() const {
  std::ostringstream os;
  dump(os);
  return std::move(os).str();
}

std::string StackEntry::to_lisp_string() const {
  std::ostringstream os;
  print_list(os);
  return std::move(os).str();
}

void StackEntry::dump(std::ostream& os) const {
  switch (tp) {
    case t_null:
      os << "(null)";
      break;
    case t_int:
      os << dec_string(as_int());
      break;
    case t_cell:
      os << "C{" << static_cast<Ref<Cell>>(ref)->get_hash().to_hex() << "}";
      break;
    case t_builder:
      os << "BC{" << static_cast<Ref<CellBuilder>>(ref)->to_hex() << "}";
      break;
    case t_slice: {
      os << "CS{";
      static_cast<Ref<CellSlice>>(ref)->dump(os, 1, false);
      os << '}';
      break;
    }
    case t_string:
      os << "\"" << as_string() << "\"";
      break;
    case t_bytes:
      os << "BYTES:" << str_to_hex(as_bytes());
      break;
    case t_box: {
      os << "Box{" << (const void*)&*ref << "}";
      break;
    }
    case t_atom:
      os << as_atom();
      break;
    case t_tuple: {
      const auto& tuple = *static_cast<Ref<Tuple>>(ref);
      auto n = tuple.size();
      if (!n) {
        os << "[]";
      } else if (n == 1) {
        os << "[ ";
        tuple[0].dump(os);
        os << " ]";
      } else {
        os << "[ ";
        for (const auto& entry : tuple) {
          entry.dump(os);
          os << ' ';
        }
        os << ']';
      }
      break;
    }
    case t_object: {
      os << "Object{" << (const void*)&*ref << "}";
      break;
    }
    default:
      os << "???";
  }
}

void StackEntry::print_list(std::ostream& os) const {
  switch (tp) {
    case t_null:
      os << "()";
      break;
    case t_tuple: {
      const auto& tuple = *static_cast<Ref<Tuple>>(ref);
      if (is_list()) {
        os << '(';
        tuple[0].print_list(os);
        print_list_tail(os, &tuple[1]);
        break;
      }
      auto n = tuple.size();
      if (!n) {
        os << "[]";
      } else if (n == 1) {
        os << "[";
        tuple[0].print_list(os);
        os << "]";
      } else {
        os << "[";
        unsigned c = 0;
        for (const auto& entry : tuple) {
          if (c++) {
            os << " ";
          }
          entry.print_list(os);
        }
        os << ']';
      }
      break;
    }
    default:
      dump(os);
  }
}

void StackEntry::print_list_tail(std::ostream& os, const StackEntry* se) {
  Ref<Tuple> tuple;
  while (!se->empty()) {
    tuple = se->as_tuple_range(2, 2);
    if (tuple.is_null()) {
      os << " . ";
      se->print_list(os);
      break;
    }
    os << ' ';
    tuple->at(0).print_list(os);
    se = &tuple->at(1);
  }
  os << ')';
}

StackEntry StackEntry::make_list(std::vector<StackEntry>&& elems) {
  StackEntry tail;
  std::size_t n = elems.size();
  while (n > 0) {
    --n;
    tail = StackEntry{vm::make_tuple_ref(std::move(elems[n]), tail)};
  }
  return tail;
}

StackEntry StackEntry::make_list(const std::vector<StackEntry>& elems) {
  StackEntry tail;
  std::size_t n = elems.size();
  while (n > 0) {
    --n;
    tail = StackEntry{vm::make_tuple_ref(elems[n], tail)};
  }
  return tail;
}

StackEntry::StackEntry(Ref<Stack> stack_ref) : ref(std::move(stack_ref)), tp(t_stack) {
}

StackEntry::StackEntry(Ref<Continuation> cont_ref) : ref(std::move(cont_ref)), tp(t_vmcont) {
}

Ref<Continuation> StackEntry::as_cont() const & {
  return as<Continuation, t_vmcont>();
}

Ref<Continuation> StackEntry::as_cont() && {
  return move_as<Continuation, t_vmcont>();
}

StackEntry::StackEntry(Ref<Box> box_ref) : ref(std::move(box_ref)), tp(t_box) {
}

Ref<Box> StackEntry::as_box() const & {
  return as<Box, t_box>();
}

Ref<Box> StackEntry::as_box() && {
  return move_as<Box, t_box>();
}

StackEntry::StackEntry(Ref<Tuple> tuple_ref) : ref(std::move(tuple_ref)), tp(t_tuple) {
}

StackEntry::StackEntry(const std::vector<StackEntry>& tuple_components)
    : ref(Ref<Tuple>{true, tuple_components}), tp(t_tuple) {
}

StackEntry::StackEntry(std::vector<StackEntry>&& tuple_components)
    : ref(Ref<Tuple>{true, std::move(tuple_components)}), tp(t_tuple) {
}

Ref<Tuple> StackEntry::as_tuple() const & {
  return as<Tuple, t_tuple>();
}

Ref<Tuple> StackEntry::as_tuple() && {
  return move_as<Tuple, t_tuple>();
}

Ref<Tuple> StackEntry::as_tuple_range(unsigned max_len, unsigned min_len) const & {
  auto t = as<Tuple, t_tuple>();
  if (t.not_null() && t->size() <= max_len && t->size() >= min_len) {
    return t;
  } else {
    return {};
  }
}

Ref<Tuple> StackEntry::as_tuple_range(unsigned max_len, unsigned min_len) && {
  auto t = move_as<Tuple, t_tuple>();
  if (t.not_null() && t->size() <= max_len && t->size() >= min_len) {
    return t;
  } else {
    return {};
  }
}

StackEntry::StackEntry(Ref<Atom> atom_ref) : ref(std::move(atom_ref)), tp(t_atom) {
}

Ref<Atom> StackEntry::as_atom() const & {
  return as<Atom, t_atom>();
}

Ref<Atom> StackEntry::as_atom() && {
  return move_as<Atom, t_atom>();
}

bool StackEntry::for_each_scalar(const std::function<bool(const StackEntry&)>& func) const {
  auto t = as<Tuple, t_tuple>();
  if (t.not_null()) {
    for (const auto& entry : *t) {
      if (!entry.for_each_scalar(func)) {
        return false;
      }
    }
    return true;
  } else {
    return func(*this);
  }
}

void StackEntry::for_each_scalar(const std::function<void(const StackEntry&)>& func) const {
  auto t = as<Tuple, t_tuple>();
  if (t.not_null()) {
    for (const auto& entry : *t) {
      entry.for_each_scalar(func);
    }
  } else {
    func(*this);
  }
}

const StackEntry& tuple_index(const Tuple& tup, unsigned idx) {
  if (idx >= tup->size()) {
    throw VmError{Excno::range_chk, "tuple index out of range"};
  }
  return (*tup)[idx];
}

StackEntry tuple_extend_index(const Ref<Tuple>& tup, unsigned idx) {
  if (tup.is_null() || idx >= tup->size()) {
    return {};
  } else {
    return tup->at(idx);
  }
}

unsigned tuple_extend_set_index(Ref<Tuple>& tup, unsigned idx, StackEntry&& value, bool force) {
  if (tup.is_null()) {
    if (value.empty() && !force) {
      return 0;
    }
    tup = Ref<Tuple>{true, idx + 1};
    tup.unique_write().at(idx) = std::move(value);
    return idx + 1;
  }
  if (tup->size() <= idx) {
    if (value.empty() && !force) {
      return 0;
    }
    auto& tuple = tup.write();
    tuple.resize(idx + 1);
    tuple.at(idx) = std::move(value);
    return idx + 1;
  } else {
    tup.write().at(idx) = std::move(value);
    return (unsigned)tup->size();
  }
}

Stack::Stack(const Stack& old_stack, unsigned copy_elem, unsigned skip_top) {
  push_from_stack(old_stack, copy_elem, skip_top);
}

Stack::Stack(Stack&& old_stack, unsigned copy_elem, unsigned skip_top) {
  push_from_stack(old_stack, copy_elem, skip_top);
}

void Stack::push_from_stack(const Stack& old_stack, unsigned copy_elem, unsigned skip_top) {
  unsigned n = old_stack.depth();
  if (skip_top > n || copy_elem > n - skip_top) {
    throw VmError{Excno::stk_und, "cannot construct stack from another one: not enough elements"};
  }
  stack.reserve(stack.size() + copy_elem);
  auto it = old_stack.stack.cend() - skip_top;
  std::copy(it - copy_elem, it, std::back_inserter(stack));
}

void Stack::push_from_stack(Stack&& old_stack, unsigned copy_elem, unsigned skip_top) {
  unsigned n = old_stack.depth();
  if (skip_top > n || copy_elem > n - skip_top) {
    throw VmError{Excno::stk_und, "cannot construct stack from another one: not enough elements"};
  }
  stack.reserve(stack.size() + copy_elem);
  auto it = old_stack.stack.cend() - skip_top;
  std::move(it - copy_elem, it, std::back_inserter(stack));
}

void Stack::move_from_stack(Stack& old_stack, unsigned copy_elem) {
  unsigned n = old_stack.depth();
  if (copy_elem > n) {
    throw VmError{Excno::stk_und, "cannot construct stack from another one: not enough elements"};
  }
  LOG(DEBUG) << "moving " << copy_elem << " top elements to another stack\n";
  stack.reserve(stack.size() + copy_elem);
  auto it = old_stack.stack.cend();
  std::move(it - copy_elem, it, std::back_inserter(stack));
  old_stack.pop_many(copy_elem);
}

void Stack::pop_null() {
  check_underflow(1);
  if (!pop().empty()) {
    throw VmError{Excno::type_chk, "not an null"};
  }
}

td::RefInt256 Stack::pop_int() {
  check_underflow(1);
  td::RefInt256 res = pop().as_int();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not an integer"};
  }
  return res;
}

td::RefInt256 Stack::pop_int_finite() {
  auto res = pop_int();
  if (!res->is_valid()) {
    throw VmError{Excno::int_ov};
  }
  return res;
}

bool Stack::pop_bool() {
  return sgn(pop_int_finite()) != 0;
}

long long Stack::pop_long() {
  return pop_int()->to_long();
}

long long Stack::pop_long_range(long long max, long long min) {
  auto res = pop_long();
  if (res > max || res < min) {
    throw VmError{Excno::range_chk};
  }
  return res;
}

int Stack::pop_smallint_range(int max, int min) {
  return (int)pop_long_range(max, min);
}

Ref<Cell> Stack::pop_cell() {
  check_underflow(1);
  auto res = pop().as_cell();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not a cell"};
  }
  return res;
}

Ref<Cell> Stack::pop_maybe_cell() {
  check_underflow(1);
  auto tmp = pop();
  if (tmp.empty()) {
    return {};
  }
  auto res = std::move(tmp).as_cell();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not a cell"};
  }
  return res;
}

Ref<CellBuilder> Stack::pop_builder() {
  check_underflow(1);
  auto res = pop().as_builder();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not a cell builder"};
  }
  return res;
}

Ref<CellSlice> Stack::pop_cellslice() {
  check_underflow(1);
  auto res = pop().as_slice();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not a cell slice"};
  }
  return res;
}

std::string Stack::pop_string() {
  check_underflow(1);
  auto res = pop().as_string_ref();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not a string"};
  }
  return *res;
}

std::string Stack::pop_bytes() {
  check_underflow(1);
  auto res = pop().as_bytes_ref();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not a bytes chunk"};
  }
  return *res;
}

Ref<Continuation> Stack::pop_cont() {
  check_underflow(1);
  auto res = pop().as_cont();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not a continuation"};
  }
  return res;
}

Ref<Box> Stack::pop_box() {
  check_underflow(1);
  auto res = pop().as_box();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not a box"};
  }
  return res;
}

Ref<Tuple> Stack::pop_tuple() {
  check_underflow(1);
  auto res = pop().as_tuple();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not a tuple"};
  }
  return res;
}

Ref<Tuple> Stack::pop_tuple_range(unsigned max_len, unsigned min_len) {
  check_underflow(1);
  auto res = pop().as_tuple();
  if (res.is_null() || res->size() > max_len || res->size() < min_len) {
    throw VmError{Excno::type_chk, "not a tuple of valid size"};
  }
  return res;
}

Ref<Tuple> Stack::pop_maybe_tuple() {
  check_underflow(1);
  auto val = pop();
  if (val.empty()) {
    return {};
  }
  auto res = std::move(val).as_tuple();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not a tuple"};
  }
  return res;
}

Ref<Tuple> Stack::pop_maybe_tuple_range(unsigned max_len) {
  check_underflow(1);
  auto val = pop();
  if (val.empty()) {
    return {};
  }
  auto res = std::move(val).as_tuple();
  if (res.is_null() || res->size() > max_len) {
    throw VmError{Excno::type_chk, "not a tuple of valid size"};
  }
  return res;
}

Ref<Atom> Stack::pop_atom() {
  check_underflow(1);
  auto res = pop().as_atom();
  if (res.is_null()) {
    throw VmError{Excno::type_chk, "not an atom"};
  }
  return res;
}

void Stack::push_null() {
  push({});
}

void Stack::push_int(td::RefInt256 val) {
  if (!val->signed_fits_bits(257)) {
    throw VmError{Excno::int_ov};
  }
  push(std::move(val));
}

void Stack::push_int_quiet(td::RefInt256 val, bool quiet) {
  if (!val->signed_fits_bits(257)) {
    if (!quiet) {
      throw VmError{Excno::int_ov};
    } else if (val->is_valid()) {
      push(td::make_refint());
      return;
    }
  }
  push(std::move(val));
}

void Stack::push_string(std::string str) {
  push(std::move(str));
}

void Stack::push_string(td::Slice slice) {
  push(slice.str());
}

void Stack::push_bytes(std::string str) {
  push(std::move(str), true);
}

void Stack::push_bytes(td::Slice slice) {
  push(slice.str(), true);
}

void Stack::push_cell(Ref<Cell> cell) {
  push(std::move(cell));
}

void Stack::push_maybe_cell(Ref<Cell> cell) {
  push_maybe(std::move(cell));
}

void Stack::push_builder(Ref<CellBuilder> cb) {
  push(std::move(cb));
}

void Stack::push_smallint(long long val) {
  push(td::make_refint(val));
}

void Stack::push_bool(bool val) {
  push_smallint(val ? -1 : 0);
}

void Stack::push_cont(Ref<Continuation> cont) {
  push(std::move(cont));
}

void Stack::push_box(Ref<Box> box) {
  push(std::move(box));
}

void Stack::push_tuple(Ref<Tuple> tuple) {
  push(std::move(tuple));
}

void Stack::push_maybe_tuple(Ref<Tuple> tuple) {
  if (tuple.not_null()) {
    push(std::move(tuple));
  } else {
    push_null();
  }
}

void Stack::push_tuple(const std::vector<StackEntry>& components) {
  push(components);
}

void Stack::push_tuple(std::vector<StackEntry>&& components) {
  push(std::move(components));
}

void Stack::push_atom(Ref<Atom> atom) {
  push(std::move(atom));
}

Ref<Stack> Stack::split_top(unsigned top_cnt, unsigned drop_cnt) {
  unsigned n = depth();
  if (top_cnt > n || drop_cnt > n - top_cnt) {
    return Ref<Stack>{};
  }
  Ref<Stack> new_stk = Ref<Stack>{true};
  if (top_cnt) {
    new_stk.unique_write().move_from_stack(*this, top_cnt);
  }
  if (drop_cnt) {
    pop_many(drop_cnt);
  }
  return new_stk;
}

void Stack::dump(std::ostream& os, int mode) const {
  os << " [ ";
  if (mode & 2) {
    for (const auto& x : stack) {
      x.print_list(os);
      os << ' ';
    }
  } else {
    for (const auto& x : stack) {
      x.dump(os);
      os << ' ';
    }
  }
  os << "] ";
  if (mode & 1) {
    os << std::endl;
  }
}
void Stack::push_cellslice(Ref<CellSlice> cs) {
  push(std::move(cs));
}

void Stack::push_maybe_cellslice(Ref<CellSlice> cs) {
  push_maybe(std::move(cs));
}

bool Stack::for_each_scalar(const std::function<bool(const StackEntry&)>& func) const {
  for (const auto& v : stack) {
    if (!v.for_each_scalar(func)) {
      return false;
    }
  }
  return true;
}

void Stack::for_each_scalar(const std::function<void(const StackEntry&)>& func) const {
  for (const auto& v : stack) {
    v.for_each_scalar(func);
  }
}

/*
 *
 *   SERIALIZE/DESERIALIZE STACK VALUES
 *
 */

bool StackEntry::serialize(vm::CellBuilder& cb, int mode) const {
  auto* vsi = VmStateInterface::get();
  if (vsi && !vsi->register_op()) {
    return false;
  }
  switch (tp) {
    case t_null:
      return cb.store_long_bool(0, 8);  // vm_stk_null#00 = VmStackValue;
    case t_int: {
      auto val = as_int();
      if (!val->is_valid()) {
        // vm_stk_nan#02ff = VmStackValue;
        return cb.store_long_bool(0x02ff, 16);
      } else if (!(mode & 1) && val->signed_fits_bits(64)) {
        // vm_stk_tinyint#01 value:int64 = VmStackValue;
        return cb.store_long_bool(1, 8) && cb.store_int256_bool(std::move(val), 64);
      } else {
        // vm_stk_int#0201_ value:int257 = VmStackValue;
        return cb.store_long_bool(0x0200 / 2, 15) && cb.store_int256_bool(std::move(val), 257);
      }
    }
    case t_cell:
      // vm_stk_cell#03 cell:^Cell = VmStackValue;
      return cb.store_long_bool(3, 8) && cb.store_ref_bool(as_cell());
    case t_slice: {
      // _ cell:^Cell st_bits:(## 10) end_bits:(## 10) { st_bits <= end_bits }
      // st_ref:(#<= 4) end_ref:(#<= 4) { st_ref <= end_ref } = VmCellSlice;
      const auto& cs = *static_cast<Ref<CellSlice>>(ref);
      return ((mode & 0x1000) || cb.store_long_bool(4, 8))             // vm_stk_slice#04 _:VmCellSlice = VmStackValue;
             && cb.store_ref_bool(cs.get_base_cell())                  // _ cell:^Cell
             && cb.store_long_bool(cs.cur_pos(), 10)                   // st_bits:(## 10)
             && cb.store_long_bool(cs.cur_pos() + cs.size(), 10)       // end_bits:(## 10)
             && cb.store_long_bool(cs.cur_ref(), 3)                    // st_ref:(#<= 4)
             && cb.store_long_bool(cs.cur_ref() + cs.size_refs(), 3);  // end_ref:(#<= 4)
    }
    case t_builder:
      // vm_stk_builder#05 cell:^Cell = VmStackValue;
      return cb.store_long_bool(5, 8) && cb.store_ref_bool(as_builder()->finalize_copy());
    case t_vmcont:
      // vm_stk_cont#06 cont:VmCont = VmStackValue;
      return !(mode & 2) && cb.store_long_bool(6, 8) && as_cont()->serialize(cb);
    case t_tuple: {
      const auto& tuple = *static_cast<Ref<Tuple>>(ref);
      auto n = tuple.size();
      // vm_stk_tuple#07 len:(## 16) data:(VmTuple len) = VmStackValue;
      Ref<Cell> head, tail;
      vm::CellBuilder cb2;
      for (std::size_t i = 0; i < n; i++) {
        std::swap(head, tail);
        if (i > 1 &&
            !(cb2.store_ref_bool(std::move(tail)) && cb2.store_ref_bool(std::move(head)) && cb2.finalize_to(head))) {
          return false;
        }
        if (!(tuple[i].serialize(cb2, mode) && cb2.finalize_to(tail))) {
          return false;
        }
      }
      return cb.store_long_bool(7, 8) && cb.store_long_bool(n, 16) && (head.is_null() || cb.store_ref_bool(head)) &&
             (tail.is_null() || cb.store_ref_bool(tail));
    }
    default:
      return false;
  }
}

bool StackEntry::deserialize(CellSlice& cs, int mode) {
  auto* vsi = VmStateInterface::get();
  if (vsi && !vsi->register_op()) {
    return false;
  }
  clear();
  int t = (mode & 0xf000) ? ((mode >> 12) & 15) : (int)cs.prefetch_ulong(8);
  switch (t) {
    case 0:
      // vm_stk_null#00 = VmStackValue;
      return cs.advance(8);
    case 1: {
      // vm_stk_tinyint#01 value:int64 = VmStackValue;
      td::RefInt256 val;
      return !(mode & 1) && cs.advance(8) && cs.fetch_int256_to(64, val) && set_int(std::move(val));
    }
    case 2: {
      t = (int)cs.prefetch_ulong(16) & 0x1ff;
      if (t == 0xff) {
        // vm_stk_nan#02ff = VmStackValue;
        return cs.advance(16) && set_int(td::make_refint());
      } else {
        // vm_stk_int#0201_ value:int257 = VmStackValue;
        td::RefInt256 val;
        return cs.fetch_ulong(15) == 0x0200 / 2 && cs.fetch_int256_to(257, val) && set_int(std::move(val));
      }
    }
    case 3: {
      // vm_stk_cell#03 cell:^Cell = VmStackValue;
      return cs.have_refs() && cs.advance(8) && set(t_cell, cs.fetch_ref());
    }
    case 4: {
      // _ cell:^Cell st_bits:(## 10) end_bits:(## 10) { st_bits <= end_bits }
      //   st_ref:(#<= 4) end_ref:(#<= 4) { st_ref <= end_ref } = VmCellSlice;
      // vm_stk_slice#04 _:VmCellSlice = VmStackValue;
      unsigned st_bits, end_bits, st_ref, end_ref;
      Ref<Cell> cell;
      Ref<CellSlice> csr;
      return ((mode & 0xf000) || cs.advance(8))                          // vm_stk_slice#04
             && cs.fetch_ref_to(cell)                                    // cell:^Cell
             && cs.fetch_uint_to(10, st_bits)                            // st_bits:(## 10)
             && cs.fetch_uint_to(10, end_bits)                           // end_bits:(## 10)
             && st_bits <= end_bits                                      // { st_bits <= end_bits }
             && cs.fetch_uint_to(3, st_ref)                              // st_ref:(#<= 4)
             && cs.fetch_uint_to(3, end_ref)                             // end_ref:(#<= 4)
             && st_ref <= end_ref && end_ref <= 4                        // { st_ref <= end_ref }
             && (csr = load_cell_slice_ref(std::move(cell))).not_null()  // load cell slice
             && csr->have(end_bits, end_ref) &&
             csr.write().skip_last(csr->size() - end_bits, csr->size_refs() - end_ref) &&
             csr.write().skip_first(st_bits, st_ref) && set(t_slice, std::move(csr));
    }
    case 5: {
      // vm_stk_builder#05 cell:^Cell = VmStackValue;
      Ref<Cell> cell;
      Ref<CellSlice> csr;
      Ref<CellBuilder> cb{true};
      return cs.advance(8) && cs.fetch_ref_to(cell) && (csr = load_cell_slice_ref(std::move(cell))).not_null() &&
             cb.write().append_cellslice_bool(std::move(csr)) && set(t_builder, std::move(cb));
    }
    case 6: {
      // vm_stk_cont#06 cont:VmCont = VmStackValue;
      Ref<Continuation> cont;
      return !(mode & 2) && cs.advance(8) && Continuation::deserialize_to(cs, cont, mode) &&
             set(t_vmcont, std::move(cont));
    }
    case 7: {
      // vm_stk_tuple#07 len:(## 16) data:(VmTuple len) = VmStackValue;
      int n;
      if (!(cs.advance(8) && cs.fetch_uint_to(16, n))) {
        return false;
      }
      Ref<Tuple> tuple{true, n};
      auto& t = tuple.write();
      if (n > 1) {
        Ref<Cell> head, tail;
        n--;
        if (!(cs.fetch_ref_to(head) && cs.fetch_ref_to(tail) && t[n].deserialize(std::move(tail), mode))) {
          return false;
        }
        vm::CellSlice cs2;
        while (--n > 0) {
          if (!(cs2.load(std::move(head)) && cs2.fetch_ref_to(head) && cs2.fetch_ref_to(tail) && cs2.empty_ext() &&
                t[n].deserialize(std::move(tail), mode))) {
            return false;
          }
        }
        if (!t[0].deserialize(std::move(head), mode)) {
          return false;
        }
      } else if (n == 1) {
        return cs.have_refs() && t[0].deserialize(cs.fetch_ref(), mode) && set(t_tuple, std::move(tuple));
      }
      return set(t_tuple, std::move(tuple));
    }
    default:
      return false;
  }
}

bool StackEntry::deserialize(Ref<Cell> cell, int mode) {
  if (cell.is_null()) {
    clear();
    return false;
  }
  CellSlice cs = load_cell_slice(std::move(cell));
  return deserialize(cs, mode) && cs.empty_ext();
}

bool Stack::serialize(vm::CellBuilder& cb, int mode) const {
  auto* vsi = VmStateInterface::get();
  if (vsi && !vsi->register_op()) {
    return false;
  }
  // vm_stack#_ depth:(## 24) stack:(VmStackList depth) = VmStack;
  unsigned n = depth();
  if (!cb.store_ulong_rchk_bool(n, 24)) {  // vm_stack#_ depth:(## 24)
    return false;
  }
  if (!n) {
    return true;
  }
  vm::CellBuilder cb2;
  Ref<vm::Cell> rest = cb2.finalize();  // vm_stk_nil#_ = VmStackList 0;
  for (unsigned i = 0; i < n - 1; i++) {
    // vm_stk_cons#_ {n:#} rest:^(VmStackList n) tos:VmStackValue = VmStackList (n + 1);
    if (!(cb2.store_ref_bool(std::move(rest)) && stack[i].serialize(cb2, mode) && cb2.finalize_to(rest))) {
      return false;
    }
  }
  return cb.store_ref_bool(std::move(rest)) && stack[n - 1].serialize(cb, mode);
}

bool Stack::deserialize(vm::CellSlice& cs, int mode) {
  auto* vsi = VmStateInterface::get();
  if (vsi && !vsi->register_op()) {
    return false;
  }
  clear();
  // vm_stack#_ depth:(## 24) stack:(VmStackList depth) = VmStack;
  int n;
  if (!cs.fetch_uint_to(24, n)) {
    return false;
  }
  if (!n) {
    return true;
  }
  stack.resize(n);
  Ref<Cell> rest;
  if (!(cs.fetch_ref_to(rest) && stack[n - 1].deserialize(cs, mode))) {
    clear();
    return false;
  }
  for (int i = n - 2; i >= 0; --i) {
    // vm_stk_cons#_ {n:#} rest:^(VmStackList n) tos:VmStackValue = VmStackList (n + 1);
    vm::CellSlice cs2 = load_cell_slice(std::move(rest));
    if (!(cs2.fetch_ref_to(rest) && stack[i].deserialize(cs2, mode) && cs2.empty_ext())) {
      clear();
      return false;
    }
  }
  if (!load_cell_slice(std::move(rest)).empty_ext()) {
    clear();
    return false;
  }
  return true;
}

bool Stack::deserialize_to(vm::CellSlice& cs, Ref<Stack>& stack, int mode) {
  stack = Ref<Stack>{true};
  if (stack.unique_write().deserialize(cs, mode)) {
    return true;
  } else {
    stack.clear();
    return false;
  }
}

}  // namespace vm
