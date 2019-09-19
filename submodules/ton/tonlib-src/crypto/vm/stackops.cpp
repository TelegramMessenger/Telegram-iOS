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

int exec_nop(VmState* st) {
  VM_LOG(st) << "execute NOP\n";
  return 0;
}

// basic stack manipulation primitives

int exec_swap(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute SWAP\n";
  stack.check_underflow(2);
  swap(stack[0], stack[1]);
  return 0;
}

int exec_xchg0(VmState* st, unsigned args) {
  int x = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XCHG s" << x;
  stack.check_underflow_p(x);
  swap(stack[0], stack[x]);
  return 0;
}

int exec_xchg0_l(VmState* st, unsigned args) {
  int x = args & 255;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XCHG s" << x;
  stack.check_underflow_p(x);
  swap(stack[0], stack[x]);
  return 0;
}

int exec_xchg(VmState* st, unsigned args) {
  int x = (args >> 4) & 15, y = args & 15;
  if (!x || x >= y) {
    throw VmError{Excno::inv_opcode, "invalid XCHG arguments"};
  }
  VM_LOG(st) << "execute XCHG s" << x << ",s" << y;
  Stack& stack = st->get_stack();
  stack.check_underflow_p(y);
  swap(stack[x], stack[y]);
  return 0;
}

std::string dump_xchg(CellSlice&, unsigned args) {
  int x = (args >> 4) & 15, y = args & 15;
  if (!x || x >= y) {
    return "";
  }
  std::ostringstream os{"XCHG s"};
  os << x << ",s" << y;
  return os.str();
}

int exec_xchg1(VmState* st, unsigned args) {
  int x = args & 15;
  assert(x >= 2);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XCHG s1,s" << x;
  stack.check_underflow_p(x);
  swap(stack[1], stack[x]);
  return 0;
}

int exec_dup(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DUP\n";
  stack.check_underflow(1);
  stack.push(stack.fetch(0));
  return 0;
}

int exec_over(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute OVER\n";
  stack.check_underflow(2);
  stack.push(stack.fetch(1));
  return 0;
}

int exec_push(VmState* st, unsigned args) {
  int x = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSH s" << x;
  stack.check_underflow_p(x);
  stack.push(stack.fetch(x));
  return 0;
}

int exec_push_l(VmState* st, unsigned args) {
  int x = args & 255;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSH s" << x;
  stack.check_underflow_p(x);
  stack.push(stack.fetch(x));
  return 0;
}

int exec_drop(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DROP\n";
  stack.check_underflow(1);
  stack.pop();
  return 0;
}

int exec_nip(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute NIP\n";
  stack.check_underflow(2);
  stack.pop(stack[1]);
  return 0;
}

int exec_pop(VmState* st, unsigned args) {
  int x = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute POP s" << x;
  stack.check_underflow_p(x);
  stack.pop(stack[x]);
  return 0;
}

int exec_pop_l(VmState* st, unsigned args) {
  int x = args & 255;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute POP s" << x;
  stack.check_underflow_p(x);
  stack.pop(stack[x]);
  return 0;
}

// compound stack manipulation primitives

int exec_xchg2(VmState* st, unsigned args) {
  int x = (args >> 4) & 15, y = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XCHG2 s" << x << ",s" << y;
  stack.check_underflow_p(x, y, 1);
  swap(stack[1], stack[x]);
  swap(stack[0], stack[y]);
  return 0;
}

int exec_xcpu(VmState* st, unsigned args) {
  int x = (args >> 4) & 15, y = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XCPU s" << x << ",s" << y;
  stack.check_underflow_p(x, y);
  swap(stack[0], stack[x]);
  stack.push(stack.fetch(y));
  return 0;
}

int exec_puxc(VmState* st, unsigned args) {
  int x = (args >> 4) & 15, y = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUXC s" << x << ",s" << y - 1;
  stack.check_underflow_p(x).check_underflow(y);
  stack.push(stack.fetch(x));
  swap(stack[0], stack[1]);
  swap(stack[0], stack[y]);
  return 0;
}

int exec_push2(VmState* st, unsigned args) {
  int x = (args >> 4) & 15, y = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSH2 s" << x << ",s" << y;
  stack.check_underflow_p(x, y);
  stack.push(stack.fetch(x));
  stack.push(stack.fetch(y + 1));
  return 0;
}

int exec_xchg3(VmState* st, unsigned args) {
  int x = (args >> 8) & 15, y = (args >> 4) & 15, z = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XCHG3 s" << x << ",s" << y << ",s" << z;
  stack.check_underflow_p(x, y, z, 2);
  swap(stack[2], stack[x]);
  swap(stack[1], stack[y]);
  swap(stack[0], stack[z]);
  return 0;
}

int exec_xc2pu(VmState* st, unsigned args) {
  int x = (args >> 8) & 15, y = (args >> 4) & 15, z = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XC2PU s" << x << ",s" << y << ",s" << z;
  stack.check_underflow_p(x, y, z, 1);
  swap(stack[1], stack[x]);
  swap(stack[0], stack[y]);
  stack.push(stack.fetch(z));
  return 0;
}

int exec_xcpuxc(VmState* st, unsigned args) {
  int x = (args >> 8) & 15, y = (args >> 4) & 15, z = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XCPUXC s" << x << ",s" << y << ",s" << z - 1;
  stack.check_underflow_p(x, y, 1).check_underflow(z);
  swap(stack[1], stack[x]);
  stack.push(stack.fetch(y));
  swap(stack[0], stack[1]);
  swap(stack[0], stack[z]);
  return 0;
}

int exec_xcpu2(VmState* st, unsigned args) {
  int x = (args >> 8) & 15, y = (args >> 4) & 15, z = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XCPU2 s" << x << ",s" << y << ",s" << z;
  stack.check_underflow_p(x, y, z);
  swap(stack[0], stack[x]);
  stack.push(stack.fetch(y));
  stack.push(stack.fetch(z + 1));
  return 0;
}

int exec_puxc2(VmState* st, unsigned args) {
  int x = (args >> 8) & 15, y = (args >> 4) & 15, z = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUXC2 s" << x << ",s" << y - 1 << ",s" << z - 1;
  stack.check_underflow_p(x, 1).check_underflow(y, z);
  stack.push(stack.fetch(x));
  swap(stack[2], stack[0]);
  swap(stack[1], stack[y]);
  swap(stack[0], stack[z]);
  return 0;
}

int exec_puxcpu(VmState* st, unsigned args) {
  int x = (args >> 8) & 15, y = (args >> 4) & 15, z = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUXCPU s" << x << ",s" << y - 1 << ",s" << z - 1;
  stack.check_underflow_p(x).check_underflow(y, z);
  stack.push(stack.fetch(x));
  swap(stack[0], stack[1]);
  swap(stack[0], stack[y]);
  stack.push(stack.fetch(z));
  return 0;
}

int exec_pu2xc(VmState* st, unsigned args) {
  int x = (args >> 8) & 15, y = (args >> 4) & 15, z = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PU2XC s" << x << ",s" << y - 1 << ",s" << z - 2;
  stack.check_underflow_p(x).check_underflow(y, z - 1);
  stack.push(stack.fetch(x));
  swap(stack[1], stack[0]);
  stack.push(stack.fetch(y));
  swap(stack[1], stack[0]);
  swap(stack[0], stack[z]);
  return 0;
}

int exec_push3(VmState* st, unsigned args) {
  int x = (args >> 8) & 15, y = (args >> 4) & 15, z = args & 15;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSH3 s" << x << ",s" << y << ",s" << z;
  stack.check_underflow_p(x, y, z);
  stack.push(stack.fetch(x));
  stack.push(stack.fetch(y + 1));
  stack.push(stack.fetch(z + 2));
  return 0;
}

// exotic stack manipulation primitives

int exec_blkswap(VmState* st, unsigned args) {
  int x = ((args >> 4) & 15) + 1, y = (args & 15) + 1;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute BLKSWAP " << x << ',' << y;
  stack.check_underflow(x + y);
  std::reverse(stack.from_top(x + y), stack.from_top(y));
  std::reverse(stack.from_top(y), stack.top());
  std::reverse(stack.from_top(x + y), stack.top());
  return 0;
}

int exec_rot(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ROT\n";
  stack.check_underflow(3);
  swap(stack[1], stack[2]);
  swap(stack[0], stack[1]);
  return 0;
}

int exec_rotrev(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ROTREV\n";
  stack.check_underflow(3);
  swap(stack[0], stack[1]);
  swap(stack[1], stack[2]);
  return 0;
}

int exec_2swap(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute 2SWAP\n";
  stack.check_underflow(4);
  swap(stack[1], stack[3]);
  swap(stack[0], stack[2]);
  return 0;
}

int exec_2drop(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute 2DROP\n";
  stack.check_underflow(2);
  stack.pop();
  stack.pop();
  return 0;
}

int exec_2dup(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute 2DUP\n";
  stack.check_underflow(2);
  stack.push(stack.fetch(1));
  stack.push(stack.fetch(1));
  return 0;
}

int exec_2over(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute 2OVER\n";
  stack.check_underflow(4);
  stack.push(stack.fetch(3));
  stack.push(stack.fetch(3));
  return 0;
}

int exec_reverse(VmState* st, unsigned args) {
  int x = ((args >> 4) & 15) + 2, y = (args & 15);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute REVERSE " << x << ',' << y;
  stack.check_underflow(x + y);
  std::reverse(stack.from_top(x + y), stack.from_top(y));
  return 0;
}

int exec_blkdrop(VmState* st, unsigned args) {
  int x = (args & 15);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute BLKDROP " << x;
  stack.check_underflow(x);
  stack.pop_many(x);
  return 0;
}

int exec_blkpush(VmState* st, unsigned args) {
  int x = ((args >> 4) & 15), y = (args & 15);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute BLKPUSH " << x << ',' << y;
  stack.check_underflow_p(y);
  while (--x >= 0) {
    stack.push(stack.fetch(y));
  }
  return 0;
}

int exec_pick(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PICK\n";
  stack.check_underflow(1);
  int x = stack.pop_smallint_range(255);
  stack.check_underflow_p(x);
  stack.push(stack.fetch(x));
  return 0;
}

int exec_roll(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ROLL\n";
  stack.check_underflow(1);
  int x = stack.pop_smallint_range(255);
  stack.check_underflow_p(x);
  while (--x >= 0) {
    swap(stack[x], stack[x + 1]);
  }
  return 0;
}

int exec_rollrev(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ROLLREV\n";
  stack.check_underflow(1);
  int x = stack.pop_smallint_range(255);
  stack.check_underflow_p(x);
  for (int i = 0; i < x; i++) {
    swap(stack[i], stack[i + 1]);
  }
  return 0;
}

int exec_blkswap_x(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute BLKSWX\n";
  stack.check_underflow(2);
  int y = stack.pop_smallint_range(255);
  int x = stack.pop_smallint_range(255);
  stack.check_underflow(x + y);
  if (x > 0 && y > 0) {
    std::reverse(stack.from_top(x + y), stack.from_top(y));
    std::reverse(stack.from_top(y), stack.top());
    std::reverse(stack.from_top(x + y), stack.top());
  }
  return 0;
}

int exec_reverse_x(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute REVX\n";
  stack.check_underflow(2);
  int y = stack.pop_smallint_range(255);
  int x = stack.pop_smallint_range(255);
  stack.check_underflow(x + y);
  std::reverse(stack.from_top(x + y), stack.from_top(y));
  return 0;
}

int exec_drop_x(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DROPX\n";
  stack.check_underflow(1);
  int x = stack.pop_smallint_range(255);
  stack.check_underflow(x);
  stack.pop_many(x);
  return 0;
}

int exec_tuck(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute TUCK\n";
  stack.check_underflow(2);
  swap(stack[0], stack[1]);
  stack.push(stack.fetch(1));
  return 0;
}

int exec_xchg_x(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XCHGX\n";
  stack.check_underflow(1);
  int x = stack.pop_smallint_range(255);
  stack.check_underflow_p(x);
  swap(stack[0], stack[x]);
  return 0;
}

int exec_depth(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DEPTH\n";
  stack.push_smallint(stack.depth());
  return 0;
}

int exec_chkdepth(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute CHKDEPTH\n";
  stack.check_underflow(1);
  int x = stack.pop_smallint_range(255);
  stack.check_underflow(x);
  return 0;
}

int exec_onlytop_x(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ONLYTOPX\n";
  stack.check_underflow(1);
  int x = stack.pop_smallint_range(255);
  stack.check_underflow(x);
  int n = stack.depth(), d = n - x;
  if (d > 0) {
    for (int i = n - 1; i >= d; i--) {
      stack[i] = std::move(stack[i - d]);
    }
  }
  stack.pop_many(d);
  return 0;
}

int exec_only_x(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ONLYX\n";
  stack.check_underflow(1);
  int x = stack.pop_smallint_range(255);
  stack.check_underflow(x);
  stack.pop_many(stack.depth() - x);
  return 0;
}

void register_stack_ops(OpcodeTable& cp0) {
  cp0.insert(OpcodeInstr::mksimple(0x00, 8, "NOP", exec_nop))
      .insert(OpcodeInstr::mksimple(0x01, 8, "SWAP", exec_swap))
      .insert(OpcodeInstr::mkfixedrange(0x02, 0x10, 8, 4, instr::dump_1sr("XCHG "), exec_xchg0))
      .insert(OpcodeInstr::mkfixed(0x10, 8, 8, dump_xchg, exec_xchg))
      .insert(OpcodeInstr::mkfixed(0x11, 8, 8, instr::dump_1sr_l("XCHG "), exec_xchg0_l))
      .insert(OpcodeInstr::mkfixedrange(0x12, 0x20, 8, 4, instr::dump_1sr("XCHG s1,"), exec_xchg1))
      .insert(OpcodeInstr::mksimple(0x20, 8, "DUP", exec_dup))
      .insert(OpcodeInstr::mksimple(0x21, 8, "OVER", exec_over))
      .insert(OpcodeInstr::mkfixedrange(0x22, 0x30, 8, 4, instr::dump_1sr("PUSH "), exec_push))
      .insert(OpcodeInstr::mksimple(0x30, 8, "DROP", exec_drop))
      .insert(OpcodeInstr::mksimple(0x31, 8, "NIP", exec_nip))
      .insert(OpcodeInstr::mkfixedrange(0x32, 0x40, 8, 4, instr::dump_1sr("POP "), exec_pop))
      .insert(OpcodeInstr::mkfixed(0x4, 4, 12, instr::dump_3sr("XCHG3 "), exec_xchg3))
      .insert(OpcodeInstr::mkfixed(0x50, 8, 8, instr::dump_2sr("XCHG2 "), exec_xchg2))
      .insert(OpcodeInstr::mkfixed(0x51, 8, 8, instr::dump_2sr("XCPU "), exec_xcpu))
      .insert(OpcodeInstr::mkfixed(0x52, 8, 8, instr::dump_2sr_adj(1, "PUXC "), exec_puxc))
      .insert(OpcodeInstr::mkfixed(0x53, 8, 8, instr::dump_2sr("PUSH2 "), exec_push2))
      .insert(OpcodeInstr::mkfixed(0x540, 12, 12, instr::dump_3sr("XCHG3 "), exec_xchg3))
      .insert(OpcodeInstr::mkfixed(0x541, 12, 12, instr::dump_3sr("XC2PU "), exec_xc2pu))
      .insert(OpcodeInstr::mkfixed(0x542, 12, 12, instr::dump_3sr_adj(1, "XCPUXC "), exec_xcpuxc))
      .insert(OpcodeInstr::mkfixed(0x543, 12, 12, instr::dump_3sr("XCPU2 "), exec_xcpu2))
      .insert(OpcodeInstr::mkfixed(0x544, 12, 12, instr::dump_3sr_adj(0x11, "PUXC2 "), exec_puxc2))
      .insert(OpcodeInstr::mkfixed(0x545, 12, 12, instr::dump_3sr_adj(0x11, "PUXCPU "), exec_puxcpu))
      .insert(OpcodeInstr::mkfixed(0x546, 12, 12, instr::dump_3sr_adj(0x12, "PU2XC "), exec_pu2xc))
      .insert(OpcodeInstr::mkfixed(0x547, 12, 12, instr::dump_3sr("PUSH3 "), exec_push3))
      .insert(OpcodeInstr::mkfixed(0x55, 8, 8, instr::dump_2c_add(0x11, "BLKSWAP ", ","), exec_blkswap))
      .insert(OpcodeInstr::mkfixed(0x56, 8, 8, instr::dump_1sr_l("PUSH "), exec_push_l))
      .insert(OpcodeInstr::mkfixed(0x57, 8, 8, instr::dump_1sr_l("POP "), exec_pop_l))
      .insert(OpcodeInstr::mksimple(0x58, 8, "ROT", exec_rot))
      .insert(OpcodeInstr::mksimple(0x59, 8, "ROTREV", exec_rotrev))
      .insert(OpcodeInstr::mksimple(0x5a, 8, "2SWAP", exec_2swap))
      .insert(OpcodeInstr::mksimple(0x5b, 8, "2DROP", exec_2drop))
      .insert(OpcodeInstr::mksimple(0x5c, 8, "2DUP", exec_2dup))
      .insert(OpcodeInstr::mksimple(0x5d, 8, "2OVER", exec_2over))
      .insert(OpcodeInstr::mkfixed(0x5e, 8, 8, instr::dump_2c_add(0x20, "REVERSE ", ","), exec_reverse))
      .insert(OpcodeInstr::mkfixed(0x5f0, 12, 4, instr::dump_1c("BLKDROP "), exec_blkdrop))
      .insert(OpcodeInstr::mkfixedrange(0x5f10, 0x6000, 16, 8, instr::dump_2c("BLKPUSH ", ","), exec_blkpush))
      .insert(OpcodeInstr::mksimple(0x60, 8, "PICK", exec_pick))
      .insert(OpcodeInstr::mksimple(0x61, 8, "ROLL", exec_roll))
      .insert(OpcodeInstr::mksimple(0x62, 8, "ROLLREV", exec_rollrev))
      .insert(OpcodeInstr::mksimple(0x63, 8, "BLKSWX", exec_blkswap_x))
      .insert(OpcodeInstr::mksimple(0x64, 8, "REVX", exec_reverse_x))
      .insert(OpcodeInstr::mksimple(0x65, 8, "DROPX", exec_drop_x))
      .insert(OpcodeInstr::mksimple(0x66, 8, "TUCK", exec_tuck))
      .insert(OpcodeInstr::mksimple(0x67, 8, "XCHGX", exec_xchg_x))
      .insert(OpcodeInstr::mksimple(0x68, 8, "DEPTH", exec_depth))
      .insert(OpcodeInstr::mksimple(0x69, 8, "CHKDEPTH", exec_chkdepth))
      .insert(OpcodeInstr::mksimple(0x6a, 8, "ONLYTOPX", exec_onlytop_x))
      .insert(OpcodeInstr::mksimple(0x6b, 8, "ONLYX", exec_only_x));
}

}  // namespace vm
