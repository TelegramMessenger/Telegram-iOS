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

#include <cassert>
#include <algorithm>
#include <string>
#include <vector>
#include <iostream>
#include <sstream>
#include <memory>
#include "common/refcnt.hpp"
#include "common/bigint.hpp"
#include "common/refint.h"
#include "common/bitstring.h"
#include "vm/cells.h"
#include "vm/cellslice.h"
#include "vm/excno.hpp"

#include "td/utils/Span.h"

namespace td {
extern template class td::Cnt<std::string>;
extern template class td::Ref<td::Cnt<std::string>>;
}  // namespace td

namespace vm {

using td::Cnt;
using td::Ref;
using td::RefAny;

const char* get_exception_msg(Excno exc_no);
std::string str_to_hex(std::string data, std::string prefix = "");

class StackEntry;
class Stack;
class Continuation;
class Box;
class Atom;

using Tuple = td::Cnt<std::vector<StackEntry>>;

template <typename... Args>
Ref<Tuple> make_tuple_ref(Args&&... args) {
  return td::make_cnt_ref<std::vector<vm::StackEntry>>(std::vector<vm::StackEntry>{std::forward<Args>(args)...});
}

struct from_object_t {};
constexpr from_object_t from_object{};

class StackEntry {
 public:
  enum Type {
    t_null,
    t_int,
    t_cell,
    t_builder,
    t_slice,
    t_vmcont,
    t_tuple,
    t_stack,
    t_string,
    t_bytes,
    t_bitstring,
    t_box,
    t_atom,
    t_object
  };

 private:
  RefAny ref;
  Type tp;

 public:
  StackEntry() : ref(), tp(t_null) {
  }
  ~StackEntry() {
  }
  StackEntry(Ref<Cell> cell_ref) : ref(std::move(cell_ref)), tp(t_cell) {
  }
  StackEntry(Ref<CellBuilder> cb_ref) : ref(std::move(cb_ref)), tp(t_builder) {
  }
  StackEntry(Ref<CellSlice> cs_ref) : ref(std::move(cs_ref)), tp(t_slice) {
  }
  StackEntry(td::RefInt256 int_ref) : ref(std::move(int_ref)), tp(t_int) {
  }
  StackEntry(std::string str, bool bytes = false) : ref(), tp(bytes ? t_bytes : t_string) {
    ref = Ref<Cnt<std::string>>{true, std::move(str)};
  }
  StackEntry(Ref<Stack> stack_ref);
  StackEntry(Ref<Continuation> cont_ref);
  StackEntry(Ref<Box> box_ref);
  StackEntry(Ref<Tuple> tuple_ref);
  StackEntry(const std::vector<StackEntry>& tuple_components);
  StackEntry(std::vector<StackEntry>&& tuple_components);
  StackEntry(Ref<Atom> atom_ref);
  StackEntry(const StackEntry& se) : ref(se.ref), tp(se.tp) {
  }
  StackEntry(StackEntry&& se) noexcept : ref(std::move(se.ref)), tp(se.tp) {
    se.tp = t_null;
  }
  template <class T>
  StackEntry(from_object_t, Ref<T> obj_ref) : ref(std::move(obj_ref)), tp(t_object) {
  }
  StackEntry& operator=(const StackEntry& se) {
    ref = se.ref;
    tp = se.tp;
    return *this;
  }
  StackEntry& operator=(StackEntry&& se) {
    ref = std::move(se.ref);
    tp = se.tp;
    se.tp = t_null;
    return *this;
  }
  StackEntry& clear() {
    ref.clear();
    tp = t_null;
    return *this;
  }
  bool set_int(td::RefInt256 value) {
    return set(t_int, std::move(value));
  }
  bool empty() const {
    return tp == t_null;
  }
  bool is_tuple() const {
    return tp == t_tuple;
  }
  bool is_atom() const {
    return tp == t_atom;
  }
  bool is_int() const {
    return tp == t_int;
  }
  bool is_cell() const {
    return tp == t_cell;
  }
  bool is_null() const {
    return tp == t_null;
  }
  bool is(int wanted) const {
    return tp == wanted;
  }
  bool is_list() const {
    return is_list(this);
  }
  static bool is_list(const StackEntry& se) {
    return is_list(&se);
  }
  void swap(StackEntry& se) {
    ref.swap(se.ref);
    std::swap(tp, se.tp);
  }
  bool operator==(const StackEntry& other) const {
    return tp == other.tp && ref == other.ref;
  }
  bool operator!=(const StackEntry& other) const {
    return !(tp == other.tp && ref == other.ref);
  }
  Type type() const {
    return tp;
  }
  // mode: +1 = disable short ints, +2 = disable continuations
  bool serialize(vm::CellBuilder& cb, int mode = 0) const;
  bool deserialize(vm::CellSlice& cs, int mode = 0);
  bool deserialize(Ref<Cell> cell, int mode = 0);

 private:
  static bool is_list(const StackEntry* se);
  template <typename T, Type tag>
  Ref<T> dynamic_as() const & {
    return tp == tag ? static_cast<Ref<T>>(ref) : td::Ref<T>{};
  }
  template <typename T, Type tag>
  Ref<T> dynamic_as() && {
    return tp == tag ? static_cast<Ref<T>>(std::move(ref)) : td::Ref<T>{};
  }
  template <typename T, Type tag>
  Ref<T> dynamic_move_as() & {
    return tp == tag ? static_cast<Ref<T>>(std::move(ref)) : td::Ref<T>{};
  }
  template <typename T, Type tag>
  Ref<T> as() const & {
    return tp == tag ? Ref<T>{td::static_cast_ref(), ref} : td::Ref<T>{};
  }
  template <typename T, Type tag>
  Ref<T> as() && {
    return tp == tag ? Ref<T>{td::static_cast_ref(), std::move(ref)} : td::Ref<T>{};
  }
  template <typename T, Type tag>
  Ref<T> move_as() & {
    return tp == tag ? Ref<T>{td::static_cast_ref(), std::move(ref)} : td::Ref<T>{};
  }
  bool set(Type _tp, RefAny _ref) {
    tp = _tp;
    ref = std::move(_ref);
    return ref.not_null() || tp == t_null;
  }

 public:
  static StackEntry make_list(std::vector<StackEntry>&& elems);
  static StackEntry make_list(const std::vector<StackEntry>& elems);
  template <typename T1, typename T2>
  static StackEntry cons(T1&& x, T2&& y) {
    return StackEntry{make_tuple_ref(std::forward<T1>(x), std::forward<T2>(y))};
  }
  template <typename T>
  static StackEntry maybe(Ref<T> ref) {
    if (ref.is_null()) {
      return {};
    } else {
      return ref;
    }
  }
  td::RefInt256 as_int() const & {
    return as<td::CntInt256, t_int>();
  }
  td::RefInt256 as_int() && {
    return move_as<td::CntInt256, t_int>();
  }
  Ref<Cell> as_cell() const & {
    return as<Cell, t_cell>();
  }
  Ref<Cell> as_cell() && {
    return move_as<Cell, t_cell>();
  }
  Ref<CellBuilder> as_builder() const & {
    return as<CellBuilder, t_builder>();
  }
  Ref<CellBuilder> as_builder() && {
    return move_as<CellBuilder, t_builder>();
  }
  Ref<CellSlice> as_slice() const & {
    return as<CellSlice, t_slice>();
  }
  Ref<CellSlice> as_slice() && {
    return move_as<CellSlice, t_slice>();
  }
  Ref<Continuation> as_cont() const &;
  Ref<Continuation> as_cont() &&;
  Ref<Cnt<std::string>> as_string_ref() const {
    return as<Cnt<std::string>, t_string>();
  }
  Ref<Cnt<std::string>> as_bytes_ref() const {
    return as<Cnt<std::string>, t_bytes>();
  }
  std::string as_string() const {
    //assert(!as_string_ref().is_null());
    return tp == t_string ? *as_string_ref() : "";
  }
  std::string as_bytes() const {
    return tp == t_bytes ? *as_bytes_ref() : "";
  }
  Ref<Box> as_box() const &;
  Ref<Box> as_box() &&;
  Ref<Tuple> as_tuple() const &;
  Ref<Tuple> as_tuple() &&;
  Ref<Tuple> as_tuple_range(unsigned max_len = 255, unsigned min_len = 0) const &;
  Ref<Tuple> as_tuple_range(unsigned max_len = 255, unsigned min_len = 0) &&;
  Ref<Atom> as_atom() const &;
  Ref<Atom> as_atom() &&;
  template <class T>
  Ref<T> as_object() const & {
    return dynamic_as<T, t_object>();
  }
  template <class T>
  Ref<T> as_object() && {
    return dynamic_move_as<T, t_object>();
  }
  void dump(std::ostream& os) const;
  void print_list(std::ostream& os) const;
  std::string to_string() const;
  std::string to_lisp_string() const;

 private:
  static void print_list_tail(std::ostream& os, const StackEntry* se);
};

inline void swap(StackEntry& se1, StackEntry& se2) {
  se1.swap(se2);
}

const StackEntry& tuple_index(const Tuple& tup, unsigned idx);
StackEntry tuple_extend_index(const Ref<Tuple>& tup, unsigned idx);
unsigned tuple_extend_set_index(Ref<Tuple>& tup, unsigned idx, StackEntry&& value, bool force = false);

class Stack : public td::CntObject {
  std::vector<StackEntry> stack;

 public:
  Stack() {
  }
  ~Stack() override = default;
  Stack(const std::vector<StackEntry>& _stack) : stack(_stack) {
  }
  Stack(std::vector<StackEntry>&& _stack) : stack(std::move(_stack)) {
  }
  Stack(const Stack& old_stack, unsigned copy_elem, unsigned skip_top);
  Stack(Stack&& old_stack, unsigned copy_elem, unsigned skip_top);
  td::CntObject* make_copy() const override {
    std::cerr << "copy stack at " << (const void*)this << " (" << depth() << " entries)\n";
    return new Stack{stack};
  }
  void push_from_stack(const Stack& old_stack, unsigned copy_elem, unsigned skip_top = 0);
  void push_from_stack(Stack&& old_stack, unsigned copy_elem, unsigned skip_top = 0);
  void move_from_stack(Stack& old_stack, unsigned copy_elem);
  Ref<Stack> split_top(unsigned top_cnt, unsigned drop_cnt = 0);

  StackEntry& push() {
    stack.emplace_back();
    return stack.back();
  }
  template <typename... Args>
  StackEntry& push(Args&&... args) {
    stack.emplace_back(args...);
    return stack.back();
  }
  StackEntry& push(const StackEntry& se) {
    stack.push_back(se);
    return stack.back();
  }
  StackEntry& push(StackEntry&& se) {
    stack.emplace_back(std::move(se));
    return stack.back();
  }
  void pop(StackEntry& se) {
    stack.back().swap(se);
    stack.pop_back();
  }
  StackEntry pop() {
    StackEntry res = std::move(stack.back());
    stack.pop_back();
    return res;
  }
  StackEntry pop_chk() {
    check_underflow(1);
    return pop();
  }
  void pop_many(int count) {
    stack.resize(stack.size() - count);
  }
  void pop_many(int count, int offs) {
    std::move(stack.cend() - offs, stack.cend(), stack.end() - (count + offs));
    pop_many(count);
  }
  void drop_bottom(int count) {
    std::move(stack.cbegin() + count, stack.cend(), stack.begin());
    pop_many(count);
  }
  StackEntry& operator[](int idx) {  // NB: we sometimes use idx=-1
    return stack[stack.size() - idx - 1];
  }
  const StackEntry& operator[](int idx) const {
    return stack[stack.size() - idx - 1];
  }
  StackEntry& at(int idx) {
    return stack.at(stack.size() - idx - 1);
  }
  const StackEntry& at(int idx) const {
    return stack.at(stack.size() - idx - 1);
  }
  StackEntry fetch(int idx) const {
    return stack[stack.size() - idx - 1];
  }
  StackEntry& tos() {
    return stack.back();
  }
  const StackEntry& tos() const {
    return stack.back();
  }
  bool is_empty() const {
    return stack.empty();
  }
  int depth() const {
    return (int)stack.size();
  }
  std::vector<StackEntry>::iterator top() {
    return stack.end();
  }
  std::vector<StackEntry>::const_iterator top() const {
    return stack.cend();
  }
  std::vector<StackEntry>::iterator from_top(int offs) {
    return stack.end() - offs;
  }
  std::vector<StackEntry>::const_iterator from_top(int offs) const {
    return stack.cend() - offs;
  }
  td::Span<StackEntry> as_span() const {
    return stack;
  }
  bool at_least(int req) const {
    return depth() >= req;
  }
  template <typename... Args>
  bool at_least(int req, Args... args) const {
    return at_least(req) && at_least(args...);
  }
  bool more_than(int req) const {
    return depth() > req;
  }
  template <typename... Args>
  bool more_than(int req, Args... args) const {
    return more_than(req) && more_than(args...);
  }
  void clear() {
    stack.clear();
  }
  Stack& set_contents(const Stack& other_stack) {
    stack = other_stack.stack;
    return *this;
  }
  Stack& set_contents(Stack&& other_stack) {
    stack = std::move(other_stack.stack);
    return *this;
  }
  Stack& set_contents(Ref<Stack> ref) {
    if (ref.is_null()) {
      clear();
    } else if (ref->is_unique()) {
      set_contents(std::move(ref.unique_write()));
    } else {
      set_contents(*ref);
    }
    return *this;
  }
  std::vector<StackEntry> extract_contents() const & {
    return stack;
  }
  std::vector<StackEntry> extract_contents() && {
    return std::move(stack);
  }
  template <typename... Args>
  const Stack& check_underflow(Args... args) const {
    if (!at_least(args...)) {
      throw VmError{Excno::stk_und};
    }
    return *this;
  }
  template <typename... Args>
  Stack& check_underflow(Args... args) {
    if (!at_least(args...)) {
      throw VmError{Excno::stk_und};
    }
    return *this;
  }
  template <typename... Args>
  const Stack& check_underflow_p(Args... args) const {
    if (!more_than(args...)) {
      throw VmError{Excno::stk_und};
    }
    return *this;
  }
  template <typename... Args>
  Stack& check_underflow_p(Args... args) {
    if (!more_than(args...)) {
      throw VmError{Excno::stk_und};
    }
    return *this;
  }
  Stack& reserve(int cnt) {
    stack.reserve(cnt);
    return *this;
  }
  void pop_null();
  td::RefInt256 pop_int();
  td::RefInt256 pop_int_finite();
  bool pop_bool();
  long long pop_long();
  long long pop_long_range(long long max, long long min = 0);
  int pop_smallint_range(int max, int min = 0);
  Ref<Cell> pop_cell();
  Ref<Cell> pop_maybe_cell();
  Ref<CellBuilder> pop_builder();
  Ref<CellSlice> pop_cellslice();
  Ref<Continuation> pop_cont();
  Ref<Box> pop_box();
  Ref<Tuple> pop_tuple();
  Ref<Tuple> pop_tuple_range(unsigned max_len = 255, unsigned min_len = 0);
  Ref<Tuple> pop_maybe_tuple();
  Ref<Tuple> pop_maybe_tuple_range(unsigned max_len = 255);
  Ref<Atom> pop_atom();
  std::string pop_string();
  std::string pop_bytes();
  template <typename T>
  Ref<T> pop_object() {
    return pop_chk().as_object<T>();
  }
  template <typename T>
  Ref<T> pop_object_type_chk() {
    auto res = pop_object<T>();
    if (!res) {
      throw VmError{Excno::type_chk, "not an object of required type"};
    }
    return res;
  }
  void push_null();
  void push_int(td::RefInt256 val);
  void push_int_quiet(td::RefInt256 val, bool quiet = true);
  void push_smallint(long long val);
  void push_bool(bool val);
  void push_string(std::string str);
  void push_string(td::Slice slice);
  void push_bytes(std::string str);
  void push_bytes(td::Slice slice);
  void push_cell(Ref<Cell> cell);
  void push_maybe_cell(Ref<Cell> cell);
  void push_maybe_cellslice(Ref<CellSlice> cs);
  void push_builder(Ref<CellBuilder> cb);
  void push_cellslice(Ref<CellSlice> cs);
  void push_cont(Ref<Continuation> cont);
  void push_box(Ref<Box> box);
  void push_tuple(Ref<Tuple> tuple);
  void push_tuple(const std::vector<StackEntry>& components);
  void push_tuple(std::vector<StackEntry>&& components);
  void push_maybe_tuple(Ref<Tuple> tuple);
  void push_atom(Ref<Atom> atom);
  template <typename T>
  void push_object(Ref<T> obj) {
    push({vm::from_object, std::move(obj)});
  }
  template <typename T, typename... Args>
  void push_make_object(Args&&... args) {
    push_object<T>(td::make_ref<T>(std::forward<Args>(args)...));
  }
  template <typename T>
  void push_maybe(Ref<T> val) {
    if (val.is_null()) {
      push({});
    } else {
      push(std::move(val));
    }
  }
  // mode: +1 = add eoln, +2 = Lisp-style lists
  void dump(std::ostream& os, int mode = 1) const;
  bool serialize(vm::CellBuilder& cb, int mode = 0) const;
  bool deserialize(vm::CellSlice& cs, int mode = 0);
  static bool deserialize_to(vm::CellSlice& cs, Ref<Stack>& stack, int mode = 0);
};

}  // namespace vm

namespace td {
extern template class td::Cnt<std::vector<vm::StackEntry>>;
extern template class td::Ref<td::Cnt<std::vector<vm::StackEntry>>>;
}  // namespace td
