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
#include <functional>
#include "vm/debugops.h"
#include "vm/log.h"
#include "vm/opctable.h"
#include "vm/stack.hpp"
#include "vm/continuation.h"
#include "vm/excno.hpp"

namespace vm {

bool vm_debug_enabled = true;

int exec_dummy_debug(VmState* st, int args) {
  VM_LOG(st) << "execute DEBUG " << (args & 0xff);
  return 0;
}

// similar to PUSHSLICE instruction in cellops.cpp
int exec_dummy_debug_str(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  int data_bits = ((args & 15) + 1) * 8;
  if (!cs.have(pfx_bits + data_bits)) {
    throw VmError{Excno::inv_opcode, "not enough data bits for a DEBUGSTR instruction"};
  }
  cs.advance(pfx_bits);
  auto slice = cs.fetch_subslice(data_bits);
  VM_LOG(st) << "execute DEBUGSTR " << slice->as_bitslice().to_hex();
  return 0;
}

std::string dump_dummy_debug_str(CellSlice& cs, unsigned args, int pfx_bits) {
  int data_bits = ((args & 15) + 1) * 8;
  if (!cs.have(pfx_bits + data_bits)) {
    return "";
  }
  cs.advance(pfx_bits);
  auto slice = cs.fetch_subslice(data_bits);
  slice.unique_write().remove_trailing();
  std::ostringstream os;
  os << "DEBUGSTR ";
  slice->dump_hex(os, 1, false);
  return os.str();
}

int compute_len_debug_str(const CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned bits = pfx_bits + ((args & 15) + 1) * 8;
  return cs.have(bits) ? bits : 0;
}

int exec_dump_stack(VmState* st) {
  VM_LOG(st) << "execute DUMPSTK";
  Stack& stack = st->get_stack();
  int d = stack.depth();
  std::cerr << "#DEBUG#: stack(" << d << " values) : ";
  if (d > 255) {
    std::cerr << "... ";
    d = 255;
  }
  for (int i = d; i > 0; i--) {
    std::cerr << stack[i - 1].to_string() << " ";
  }
  std::cerr << std::endl;
  return 0;
}

int exec_dump_value(VmState* st, unsigned arg) {
  arg &= 15;
  VM_LOG(st) << "execute DUMP s" << arg;
  Stack& stack = st->get_stack();
  if ((int)arg < stack.depth()) {
    std::cerr << "#DEBUG#: s" << arg << " = " << stack[arg].to_string() << std::endl;
  } else {
    std::cerr << "#DEBUG#: s" << arg << " is absent" << std::endl;
  }
  return 0;
}

void register_debug_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  if (!vm_debug_enabled) {
    cp0.insert(OpcodeInstr::mkfixedrange(0xfe00, 0xfef0, 16, 8, instr::dump_1c_and(0xff, "DEBUG "), exec_dummy_debug))
        .insert(OpcodeInstr::mkext(0xfef, 12, 4, dump_dummy_debug_str, exec_dummy_debug_str, compute_len_debug_str));
  } else {
    // NB: all non-redefined opcodes in fe00..feff should be redirected to dummy debug definitions
    cp0.insert(OpcodeInstr::mksimple(0xfe00, 16, "DUMPSTK", exec_dump_stack))
        .insert(OpcodeInstr::mkfixedrange(0xfe01, 0xfe20, 16, 8, instr::dump_1c_and(0xff, "DEBUG "), exec_dummy_debug))
        .insert(OpcodeInstr::mkfixed(0xfe2, 12, 4, instr::dump_1sr("DUMP"), exec_dump_value))
        .insert(OpcodeInstr::mkfixedrange(0xfe30, 0xfef0, 16, 8, instr::dump_1c_and(0xff, "DEBUG "), exec_dummy_debug))
        .insert(OpcodeInstr::mkext(0xfef, 12, 4, dump_dummy_debug_str, exec_dummy_debug_str, compute_len_debug_str));
  }
}

}  // namespace vm
