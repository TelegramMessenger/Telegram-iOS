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
#include "vm/log.h"
#include "vm/stackops.h"
#include "vm/opctable.h"
#include "vm/stack.hpp"
#include "vm/continuation.h"
#include "vm/excno.hpp"

namespace vm {

int exec_push_null(VmState* st) {
  VM_LOG(st) << "execute PUSHNULL";
  st->get_stack().push({});
  return 0;
}

int exec_is_null(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ISNULL";
  stack.push_bool(stack.pop_chk().empty());
  return 0;
}

int exec_null_swap_if(VmState* st, bool cond, int depth) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute NULL" << (depth ? "ROTR" : "SWAP") << (cond ? "IF" : "IFNOT");
  stack.check_underflow(depth + 1);
  auto x = stack.pop_int_finite();
  if (!x->sgn() != cond) {
    stack.push({});
    for (int i = 0; i < depth; i++) {
      swap(stack[i], stack[i + 1]);
    }
  }
  stack.push_int(std::move(x));
  return 0;
}

int exec_mktuple_common(VmState* st, unsigned n) {
  Stack& stack = st->get_stack();
  stack.check_underflow(n);
  Ref<Tuple> ref{true};
  auto& tuple = ref.unique_write();
  tuple.reserve(n);
  for (int i = n - 1; i >= 0; i--) {
    tuple.push_back(std::move(stack[i]));
  }
  stack.pop_many(n);
  st->consume_tuple_gas(n);
  stack.push_tuple(std::move(ref));
  return 0;
}

int exec_mktuple(VmState* st, unsigned args) {
  args &= 15;
  VM_LOG(st) << "execute TUPLE " << args;
  return exec_mktuple_common(st, args);
}

int exec_mktuple_var(VmState* st) {
  VM_LOG(st) << "execute TUPLEVAR";
  unsigned args = st->get_stack().pop_smallint_range(255);
  return exec_mktuple_common(st, args);
}

int exec_tuple_index_common(Stack& stack, unsigned n) {
  auto tuple = stack.pop_tuple_range(255);
  stack.push(tuple_index(*tuple, n));
  return 0;
}

int exec_tuple_index(VmState* st, unsigned args) {
  args &= 15;
  VM_LOG(st) << "execute INDEX " << args;
  return exec_tuple_index_common(st->get_stack(), args);
}

int exec_tuple_index_var(VmState* st) {
  VM_LOG(st) << "execute INDEXVAR";
  st->check_underflow(2);
  unsigned args = st->get_stack().pop_smallint_range(254);
  return exec_tuple_index_common(st->get_stack(), args);
}

int exec_tuple_quiet_index_common(Stack& stack, unsigned n) {
  stack.push(tuple_extend_index(stack.pop_maybe_tuple_range(255), n));
  return 0;
}

int exec_tuple_quiet_index(VmState* st, unsigned args) {
  args &= 15;
  VM_LOG(st) << "execute INDEXQ " << args;
  return exec_tuple_quiet_index_common(st->get_stack(), args);
}

int exec_tuple_quiet_index_var(VmState* st) {
  VM_LOG(st) << "execute INDEXVARQ";
  st->check_underflow(2);
  unsigned args = st->get_stack().pop_smallint_range(254);
  return exec_tuple_quiet_index_common(st->get_stack(), args);
}

int do_explode_tuple(VmState* st, Ref<Tuple> tuple, unsigned n) {
  auto& stack = st->get_stack();
  if (tuple.is_unique()) {
    auto& tw = tuple.unique_write();
    for (unsigned i = 0; i < n; i++) {
      stack.push(std::move(tw[i]));
    }
  } else {
    const auto& t = *tuple;
    for (unsigned i = 0; i < n; i++) {
      stack.push(t[i]);
    }
  }
  st->consume_tuple_gas(n);
  return 0;
}

int exec_untuple_common(VmState* st, unsigned n) {
  return do_explode_tuple(st, st->get_stack().pop_tuple_range(n, n), n);
}

int exec_untuple(VmState* st, unsigned args) {
  args &= 15;
  VM_LOG(st) << "execute UNTUPLE " << args;
  return exec_untuple_common(st, args);
}

int exec_untuple_var(VmState* st) {
  VM_LOG(st) << "execute UNTUPLEVAR";
  st->check_underflow(2);
  unsigned args = st->get_stack().pop_smallint_range(255);
  return exec_untuple_common(st, args);
}

int exec_untuple_first_common(VmState* st, unsigned n) {
  return do_explode_tuple(st, st->get_stack().pop_tuple_range(255, n), n);
}

int exec_untuple_first(VmState* st, unsigned args) {
  args &= 15;
  VM_LOG(st) << "execute UNPACKFIRST " << args;
  return exec_untuple_first_common(st, args);
}

int exec_untuple_first_var(VmState* st) {
  VM_LOG(st) << "execute UNPACKFIRSTVAR";
  st->check_underflow(2);
  unsigned args = st->get_stack().pop_smallint_range(255);
  return exec_untuple_first_common(st, args);
}

int exec_explode_tuple_common(VmState* st, unsigned n) {
  auto t = st->get_stack().pop_tuple_range(n);
  unsigned l = (unsigned)(t->size());
  do_explode_tuple(st, std::move(t), l);
  st->get_stack().push_smallint(l);
  return 0;
}

int exec_explode_tuple(VmState* st, unsigned args) {
  args &= 15;
  VM_LOG(st) << "execute EXPLODE " << args;
  return exec_explode_tuple_common(st, args);
}

int exec_explode_tuple_var(VmState* st) {
  VM_LOG(st) << "execute EXPLODEVAR";
  st->check_underflow(2);
  unsigned args = st->get_stack().pop_smallint_range(255);
  return exec_explode_tuple_common(st, args);
}

int exec_tuple_set_index_common(VmState* st, unsigned idx) {
  Stack& stack = st->get_stack();
  auto x = stack.pop();
  auto tuple = stack.pop_tuple_range(255);
  if (idx >= tuple->size()) {
    throw VmError{Excno::range_chk, "tuple index out of range"};
  }
  tuple.write()[idx] = std::move(x);
  st->consume_tuple_gas(tuple);
  stack.push(std::move(tuple));
  return 0;
}

int exec_tuple_set_index(VmState* st, unsigned args) {
  args &= 15;
  VM_LOG(st) << "execute SETINDEX " << args;
  st->check_underflow(2);
  return exec_tuple_set_index_common(st, args);
}

int exec_tuple_set_index_var(VmState* st) {
  VM_LOG(st) << "execute SETINDEXVAR";
  st->check_underflow(3);
  unsigned args = st->get_stack().pop_smallint_range(254);
  return exec_tuple_set_index_common(st, args);
}

int exec_tuple_quiet_set_index_common(VmState* st, unsigned idx) {
  Stack& stack = st->get_stack();
  auto x = stack.pop();
  auto tuple = stack.pop_maybe_tuple_range(255);
  if (idx >= 255) {
    throw VmError{Excno::range_chk, "tuple index out of range"};
  }
  auto tpay = tuple_extend_set_index(tuple, idx, std::move(x));
  if (tpay > 0) {
    st->consume_tuple_gas(tpay);
  }
  stack.push_maybe_tuple(std::move(tuple));
  return 0;
}

int exec_tuple_quiet_set_index(VmState* st, unsigned args) {
  args &= 15;
  VM_LOG(st) << "execute SETINDEXQ " << args;
  st->check_underflow(2);
  return exec_tuple_quiet_set_index_common(st, args);
}

int exec_tuple_quiet_set_index_var(VmState* st) {
  VM_LOG(st) << "execute SETINDEXVARQ";
  st->check_underflow(3);
  unsigned args = st->get_stack().pop_smallint_range(254);
  return exec_tuple_quiet_set_index_common(st, args);
}

int exec_tuple_length(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute TLEN";
  auto t = stack.pop_tuple_range(255);
  stack.push_smallint((long long)(t->size()));
  return 0;
}

int exec_tuple_length_quiet(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute QTLEN";
  auto t = stack.pop_chk();
  stack.push_smallint(t.is_tuple() ? (long long)(t.as_tuple()->size()) : -1LL);
  return 0;
}

int exec_is_tuple(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ISTUPLE";
  stack.push_bool(stack.pop_chk().is_tuple());
  return 0;
}

int exec_tuple_last(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute LAST";
  auto t = stack.pop_tuple_range(255, 1);
  stack.push(t->back());
  return 0;
}

int exec_tuple_push(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute TPUSH";
  stack.check_underflow(2);
  auto x = stack.pop();
  auto t = stack.pop_tuple_range(254);
  t.write().push_back(std::move(x));
  st->consume_tuple_gas(t);
  stack.push(std::move(t));
  return 0;
}

int exec_tuple_pop(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute TPOP";
  auto t = stack.pop_tuple_range(255, 1);
  auto x = std::move(t.write().back());
  t.write().pop_back();
  st->consume_tuple_gas(t);
  stack.push(std::move(t));
  stack.push(std::move(x));
  return 0;
}

int exec_tuple_index2(VmState* st, unsigned args) {
  unsigned i = (args >> 2) & 3, j = args & 3;
  VM_LOG(st) << "execute INDEX2 " << i << "," << j;
  Stack& stack = st->get_stack();
  auto tuple = stack.pop_tuple_range(255);
  auto t1 = tuple_index(*tuple, i).as_tuple_range(255);
  if (t1.is_null()) {
    throw VmError{Excno::type_chk, "intermediate value is not a tuple"};
  }
  stack.push(tuple_index(*t1, j));
  return 0;
}

std::string dump_tuple_index2(CellSlice& cs, unsigned args) {
  unsigned i = (args >> 2) & 3, j = args & 3;
  std::ostringstream os;
  os << "INDEX2 " << i << ',' << j;
  return os.str();
}

int exec_tuple_index3(VmState* st, unsigned args) {
  unsigned i = (args >> 4) & 3, j = (args >> 2) & 3, k = args & 3;
  VM_LOG(st) << "execute INDEX3 " << i << "," << j << "," << k;
  Stack& stack = st->get_stack();
  auto tuple = stack.pop_tuple_range(255);
  auto t1 = tuple_index(*tuple, i).as_tuple_range(255);
  if (t1.is_null()) {
    throw VmError{Excno::type_chk, "intermediate value is not a tuple"};
  }
  auto t2 = tuple_index(*t1, j).as_tuple_range(255);
  if (t2.is_null()) {
    throw VmError{Excno::type_chk, "intermediate value is not a tuple"};
  }
  stack.push(tuple_index(*t2, k));
  return 0;
}

std::string dump_tuple_index3(CellSlice& cs, unsigned args) {
  unsigned i = (args >> 4) & 3, j = (args >> 2) & 3, k = args & 3;
  std::ostringstream os;
  os << "INDEX3 " << i << ',' << j << ',' << k;
  return os.str();
}

void register_tuple_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  cp0.insert(OpcodeInstr::mksimple(0x6d, 8, "PUSHNULL", exec_push_null))
      .insert(OpcodeInstr::mksimple(0x6e, 8, "ISNULL", exec_is_null))
      .insert(OpcodeInstr::mkfixed(0x6f0, 12, 4, instr::dump_1c("TUPLE "), exec_mktuple))
      .insert(OpcodeInstr::mkfixed(0x6f1, 12, 4, instr::dump_1c("INDEX "), exec_tuple_index))
      .insert(OpcodeInstr::mkfixed(0x6f2, 12, 4, instr::dump_1c("UNTUPLE "), exec_untuple))
      .insert(OpcodeInstr::mkfixed(0x6f3, 12, 4, instr::dump_1c("UNPACKFIRST "), exec_untuple_first))
      .insert(OpcodeInstr::mkfixed(0x6f4, 12, 4, instr::dump_1c("EXPLODE "), exec_explode_tuple))
      .insert(OpcodeInstr::mkfixed(0x6f5, 12, 4, instr::dump_1c("SETINDEX "), exec_tuple_set_index))
      .insert(OpcodeInstr::mkfixed(0x6f6, 12, 4, instr::dump_1c("INDEXQ "), exec_tuple_quiet_index))
      .insert(OpcodeInstr::mkfixed(0x6f7, 12, 4, instr::dump_1c("SETINDEXQ "), exec_tuple_quiet_set_index))
      .insert(OpcodeInstr::mksimple(0x6f80, 16, "TUPLEVAR", exec_mktuple_var))
      .insert(OpcodeInstr::mksimple(0x6f81, 16, "INDEXVAR", exec_tuple_index_var))
      .insert(OpcodeInstr::mksimple(0x6f82, 16, "UNTUPLEVAR", exec_untuple_var))
      .insert(OpcodeInstr::mksimple(0x6f83, 16, "UNPACKFIRSTVAR", exec_untuple_first_var))
      .insert(OpcodeInstr::mksimple(0x6f84, 16, "EXPLODEVAR", exec_explode_tuple_var))
      .insert(OpcodeInstr::mksimple(0x6f85, 16, "SETINDEXVAR", exec_tuple_set_index_var))
      .insert(OpcodeInstr::mksimple(0x6f86, 16, "INDEXVARQ", exec_tuple_quiet_index_var))
      .insert(OpcodeInstr::mksimple(0x6f87, 16, "SETINDEXVARQ", exec_tuple_quiet_set_index_var))
      .insert(OpcodeInstr::mksimple(0x6f88, 16, "TLEN", exec_tuple_length))
      .insert(OpcodeInstr::mksimple(0x6f89, 16, "QTLEN", exec_tuple_length_quiet))
      .insert(OpcodeInstr::mksimple(0x6f8a, 16, "ISTUPLE", exec_is_tuple))
      .insert(OpcodeInstr::mksimple(0x6f8b, 16, "LAST", exec_tuple_last))
      .insert(OpcodeInstr::mksimple(0x6f8c, 16, "TPUSH", exec_tuple_push))
      .insert(OpcodeInstr::mksimple(0x6f8d, 16, "TPOP", exec_tuple_pop))
      .insert(OpcodeInstr::mksimple(0x6fa0, 16, "NULLSWAPIF", std::bind(exec_null_swap_if, _1, true, 0)))
      .insert(OpcodeInstr::mksimple(0x6fa1, 16, "NULLSWAPIFNOT", std::bind(exec_null_swap_if, _1, false, 0)))
      .insert(OpcodeInstr::mksimple(0x6fa2, 16, "NULLROTRIF", std::bind(exec_null_swap_if, _1, true, 1)))
      .insert(OpcodeInstr::mksimple(0x6fa3, 16, "NULLROTRIFNOT", std::bind(exec_null_swap_if, _1, false, 1)))
      .insert(OpcodeInstr::mkfixed(0x6fb, 12, 4, dump_tuple_index2, exec_tuple_index2))
      .insert(OpcodeInstr::mkfixed(0x6fc >> 2, 10, 6, dump_tuple_index3, exec_tuple_index3));
}

}  // namespace vm
