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
#include "vm/arithops.h"
#include "vm/log.h"
#include "vm/opctable.h"
#include "vm/stack.hpp"
#include "vm/continuation.h"
#include "vm/excno.hpp"
#include "common/bigint.hpp"
#include "common/refint.h"

namespace vm {

int exec_push_tinyint4(VmState* st, unsigned args) {
  int x = (int)((args + 5) & 15) - 5;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSHINT " << x;
  stack.push_smallint(x);
  return 0;
}

std::string dump_push_tinyint4(CellSlice&, unsigned args) {
  int x = (int)((args + 5) & 15) - 5;
  std::ostringstream os{"PUSHINT "};
  os << x;
  return os.str();
}

int exec_push_tinyint8(VmState* st, unsigned args) {
  int x = (signed char)args;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSHINT " << x;
  stack.push_smallint(x);
  return 0;
}

std::string dump_op_tinyint8(const char* op_prefix, CellSlice&, unsigned args) {
  int x = (signed char)args;
  std::ostringstream os{op_prefix};
  os << x;
  return os.str();
}

int exec_push_smallint(VmState* st, unsigned args) {
  int x = (short)args;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSHINT " << x;
  stack.push_smallint(x);
  return 0;
}

std::string dump_push_smallint(CellSlice&, unsigned args) {
  int x = (short)args;
  std::ostringstream os{"PUSHINT "};
  os << x;
  return os.str();
}

int exec_push_int(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  int l = (int)(args & 31) + 2;
  if (!cs.have(pfx_bits + 3 + l * 8)) {
    throw VmError{Excno::inv_opcode, "not enough bits for integer constant in PUSHINT"};
  }
  cs.advance(pfx_bits);
  td::RefInt256 x = cs.fetch_int256(3 + l * 8);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSHINT " << x;
  stack.push_int(std::move(x));
  return 0;
}

std::string dump_push_int(CellSlice& cs, unsigned args, int pfx_bits) {
  int l = (int)(args & 31) + 2;
  if (!cs.have(pfx_bits + 3 + l * 8)) {
    return "";
  }
  cs.advance(pfx_bits);
  td::RefInt256 x = cs.fetch_int256(3 + l * 8);
  std::ostringstream os{"PUSHINT "};
  os << x;
  return os.str();
}

int compute_len_push_int(const CellSlice& cs, unsigned args, int pfx_bits) {
  int l = (int)(args & 31) + 2;
  if (!cs.have(pfx_bits + 3 + l * 8)) {
    return 0;
  } else {
    return pfx_bits + 3 + l * 8;
  }
}

int exec_push_pow2(VmState* st, unsigned args) {
  int x = (args & 255) + 1;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSHPOW2 " << x;
  td::RefInt256 r{true};
  r.unique_write().set_pow2(x);
  stack.push(std::move(r));
  return 0;
}

int exec_push_nan(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSHNAN";
  td::RefInt256 r{true};
  r.unique_write().invalidate();
  stack.push(std::move(r));
  return 0;
}

int exec_push_pow2dec(VmState* st, unsigned args) {
  int x = (args & 255) + 1;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSHPOW2DEC " << x;
  td::RefInt256 r{true};
  r.unique_write().set_pow2(x).add_tiny(-1).normalize();
  stack.push(std::move(r));
  return 0;
}

int exec_push_negpow2(VmState* st, unsigned args) {
  int x = (args & 255) + 1;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSHNEGPOW2 " << x;
  td::RefInt256 r{true};
  r.unique_write().set_pow2(x).negate().normalize();
  stack.push(std::move(r));
  return 0;
}

void register_int_const_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  cp0.insert(OpcodeInstr::mkfixed(0x7, 4, 4, dump_push_tinyint4, exec_push_tinyint4))
      .insert(OpcodeInstr::mkfixed(0x80, 8, 8, std::bind(dump_op_tinyint8, "PUSHINT ", _1, _2), exec_push_tinyint8))
      .insert(OpcodeInstr::mkfixed(0x81, 8, 16, dump_push_smallint, exec_push_smallint))
      .insert(OpcodeInstr::mkextrange(0x82 << 5, (0x82 << 5) + 31, 13, 5, dump_push_int, exec_push_int,
                                      compute_len_push_int))
      .insert(OpcodeInstr::mkfixedrange(0x8300, 0x83ff, 16, 8, instr::dump_1c_l_add(1, "PUSHPOW2 "), exec_push_pow2))
      .insert(OpcodeInstr::mksimple(0x83ff, 16, "PUSHNAN", exec_push_nan))
      .insert(OpcodeInstr::mkfixed(0x84, 8, 8, instr::dump_1c_l_add(1, "PUSHPOW2DEC "), exec_push_pow2dec))
      .insert(OpcodeInstr::mkfixed(0x85, 8, 8, instr::dump_1c_l_add(1, "PUSHNEGPOW2 "), exec_push_negpow2));
}

int exec_add(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ADD";
  stack.check_underflow(2);
  auto y = stack.pop_int();
  stack.push_int_quiet(stack.pop_int() + std::move(y), quiet);
  return 0;
}

int exec_sub(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute SUB";
  stack.check_underflow(2);
  auto y = stack.pop_int();
  stack.push_int_quiet(stack.pop_int() - std::move(y), quiet);
  return 0;
}

int exec_subr(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute SUBR";
  stack.check_underflow(2);
  auto y = stack.pop_int();
  stack.push_int_quiet(std::move(y) - stack.pop_int(), quiet);
  return 0;
}

int exec_negate(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute NEGATE";
  stack.check_underflow(1);
  stack.push_int_quiet(-stack.pop_int(), quiet);
  return 0;
}

int exec_inc(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute INC";
  stack.check_underflow(1);
  stack.push_int_quiet(stack.pop_int() + 1, quiet);
  return 0;
}

int exec_dec(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DEC";
  stack.check_underflow(1);
  stack.push_int_quiet(stack.pop_int() - 1, quiet);
  return 0;
}

int exec_add_tinyint8(VmState* st, unsigned args, bool quiet) {
  int x = (signed char)args;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ADDINT " << x;
  stack.check_underflow(1);
  stack.push_int_quiet(stack.pop_int() + x, quiet);
  return 0;
}

int exec_mul_tinyint8(VmState* st, unsigned args, bool quiet) {
  int x = (signed char)args;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute MULINT " << x;
  stack.check_underflow(1);
  stack.push_int_quiet(stack.pop_int() * x, quiet);
  return 0;
}

int exec_mul(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute MUL";
  stack.check_underflow(2);
  auto y = stack.pop_int();
  stack.push_int_quiet(stack.pop_int() * std::move(y), quiet);
  return 0;
}

void register_add_mul_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  cp0.insert(OpcodeInstr::mksimple(0xa0, 8, "ADD", std::bind(exec_add, _1, false)))
      .insert(OpcodeInstr::mksimple(0xa1, 8, "SUB", std::bind(exec_sub, _1, false)))
      .insert(OpcodeInstr::mksimple(0xa2, 8, "SUBR", std::bind(exec_subr, _1, false)))
      .insert(OpcodeInstr::mksimple(0xa3, 8, "NEGATE", std::bind(exec_negate, _1, false)))
      .insert(OpcodeInstr::mksimple(0xa4, 8, "INC", std::bind(exec_inc, _1, false)))
      .insert(OpcodeInstr::mksimple(0xa5, 8, "DEC", std::bind(exec_dec, _1, false)))
      .insert(OpcodeInstr::mkfixed(0xa6, 8, 8, std::bind(dump_op_tinyint8, "ADDINT ", _1, _2),
                                   std::bind(exec_add_tinyint8, _1, _2, false)))
      .insert(OpcodeInstr::mkfixed(0xa7, 8, 8, std::bind(dump_op_tinyint8, "MULINT ", _1, _2),
                                   std::bind(exec_mul_tinyint8, _1, _2, false)))
      .insert(OpcodeInstr::mksimple(0xa8, 8, "MUL", std::bind(exec_mul, _1, false)));
  cp0.insert(OpcodeInstr::mksimple(0xb7a0, 16, "QADD", std::bind(exec_add, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7a1, 16, "QSUB", std::bind(exec_sub, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7a2, 16, "QSUBR", std::bind(exec_subr, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7a3, 16, "QNEGATE", std::bind(exec_negate, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7a4, 16, "QINC", std::bind(exec_inc, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7a5, 16, "QDEC", std::bind(exec_dec, _1, true)))
      .insert(OpcodeInstr::mkfixed(0xb7a6, 16, 8, std::bind(dump_op_tinyint8, "QADDINT ", _1, _2),
                                   std::bind(exec_add_tinyint8, _1, _2, true)))
      .insert(OpcodeInstr::mkfixed(0xb7a7, 16, 8, std::bind(dump_op_tinyint8, "QMULINT ", _1, _2),
                                   std::bind(exec_mul_tinyint8, _1, _2, true)))
      .insert(OpcodeInstr::mksimple(0xb7a8, 16, "QMUL", std::bind(exec_mul, _1, true)));
}

int exec_divmod(VmState* st, unsigned args, int quiet) {
  int round_mode = (int)(args & 3) - 1;
  if (!(args & 12) || round_mode == 2) {
    throw VmError{Excno::inv_opcode};
  }
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute DIV/MOD " << (args & 15);
  stack.check_underflow(2);
  auto y = stack.pop_int();
  auto x = stack.pop_int();
  switch ((args >> 2) & 3) {
    case 1:
      stack.push_int_quiet(td::div(std::move(x), std::move(y), round_mode), quiet);
      break;
    case 2:
      stack.push_int_quiet(td::mod(std::move(x), std::move(y), round_mode), quiet);
      break;
    case 3: {
      auto dm = td::divmod(std::move(x), std::move(y), round_mode);
      stack.push_int_quiet(std::move(dm.first), quiet);
      stack.push_int_quiet(std::move(dm.second), quiet);
      break;
    }
  }
  return 0;
}

std::string dump_divmod(CellSlice&, unsigned args, bool quiet) {
  int round_mode = (int)(args & 3);
  if (!(args & 12) || round_mode == 3) {
    return "";
  }
  std::string s = (args & 4) ? "DIV" : "";
  if (args & 8) {
    s += "MOD";
  }
  if (quiet) {
    s = "Q" + s;
  }
  return s + "FRC"[round_mode];
}

int exec_shrmod(VmState* st, unsigned args, int mode) {
  int y = -1;
  if (mode & 2) {
    y = (args & 0xff) + 1;
    args >>= 8;
  }
  int round_mode = (int)(args & 3) - 1;
  if (!(args & 12) || round_mode == 2) {
    throw VmError{Excno::inv_opcode};
  }
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute SHR/MOD " << (args & 15) << ',' << y;
  if (!(mode & 2)) {
    stack.check_underflow(2);
    y = stack.pop_smallint_range(256);
  } else {
    stack.check_underflow(1);
  }
  if (!y) {
    round_mode = -1;
  }
  auto x = stack.pop_int();
  switch ((args >> 2) & 3) {
    case 1:
      stack.push_int_quiet(td::rshift(std::move(x), y, round_mode), mode & 1);
      break;
    case 3:
      stack.push_int_quiet(td::rshift(x, y, round_mode), mode & 1);
      // fallthrough
    case 2:
      x.write().mod_pow2(y, round_mode).normalize();
      stack.push_int_quiet(std::move(x), mode & 1);
      break;
  }
  return 0;
}

std::string dump_shrmod(CellSlice&, unsigned args, int mode) {
  int y = -1;
  if (mode & 2) {
    y = (args & 0xff) + 1;
    args >>= 8;
  }
  int round_mode = (int)(args & 3);
  if (!(args & 12) || round_mode == 3) {
    return "";
  }
  std::string s;
  switch (args & 12) {
    case 4:
      s = "RSHIFT";
      break;
    case 8:
      s = "MODPOW2";
      break;
    case 12:
      s = "RSHIFTMOD";
      break;
  }
  if (mode & 1) {
    s = "Q" + s;
  }
  s += "FRC"[round_mode];
  if (mode & 2) {
    char buff[8];
    sprintf(buff, " %d", y);
    s += buff;
  }
  return s;
}

int exec_muldivmod(VmState* st, unsigned args, int quiet) {
  int round_mode = (int)(args & 3) - 1;
  if (!(args & 12) || round_mode == 2) {
    throw VmError{Excno::inv_opcode};
  }
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute MULDIV/MOD " << (args & 15);
  stack.check_underflow(3);
  auto z = stack.pop_int();
  auto y = stack.pop_int();
  auto x = stack.pop_int();
  typename td::BigInt256::DoubleInt tmp{0};
  tmp.add_mul(*x, *y);
  auto q = td::RefInt256{true};
  tmp.mod_div(*z, q.unique_write(), round_mode);
  switch ((args >> 2) & 3) {
    case 1:
      q.unique_write().normalize();
      stack.push_int_quiet(std::move(q), quiet);
      break;
    case 3:
      q.unique_write().normalize();
      stack.push_int_quiet(std::move(q), quiet);
      // fallthrough
    case 2:
      stack.push_int_quiet(td::RefInt256{true, tmp}, quiet);
      break;
  }
  return 0;
}

std::string dump_muldivmod(CellSlice&, unsigned args, bool quiet) {
  int round_mode = (int)(args & 3);
  if (!(args & 12) || round_mode == 3) {
    return "";
  }
  std::string s = (args & 4) ? "MULDIV" : "MUL";
  if (args & 8) {
    s += "MOD";
  }
  if (quiet) {
    s = "Q" + s;
  }
  return s + "FRC"[round_mode];
}

int exec_mulshrmod(VmState* st, unsigned args, int mode) {
  int z = -1;
  if (mode & 2) {
    z = (args & 0xff) + 1;
    args >>= 8;
  }
  int round_mode = (int)(args & 3) - 1;
  if (!(args & 12) || round_mode == 2) {
    throw VmError{Excno::inv_opcode};
  }
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute MULSHR/MOD " << (args & 15) << ',' << z;
  if (!(mode & 2)) {
    stack.check_underflow(3);
    z = stack.pop_smallint_range(256);
  } else {
    stack.check_underflow(2);
  }
  if (!z) {
    round_mode = -1;
  }
  auto y = stack.pop_int();
  auto x = stack.pop_int();
  typename td::BigInt256::DoubleInt tmp{0};
  tmp.add_mul(*x, *y);
  switch ((args >> 2) & 3) {
    case 1:
      tmp.rshift(z, round_mode).normalize();
      stack.push_int_quiet(td::RefInt256{true, tmp}, mode & 1);
      break;
    case 3: {
      typename td::BigInt256::DoubleInt tmp2{tmp};
      tmp2.rshift(z, round_mode).normalize();
      stack.push_int_quiet(td::RefInt256{true, tmp2}, mode & 1);
    }
      // fallthrough
    case 2:
      tmp.mod_pow2(z, round_mode).normalize();
      stack.push_int_quiet(td::RefInt256{true, tmp}, mode & 1);
      break;
  }
  return 0;
}

std::string dump_mulshrmod(CellSlice&, unsigned args, int mode) {
  int y = -1;
  if (mode & 2) {
    y = (args & 0xff) + 1;
    args >>= 8;
  }
  int round_mode = (int)(args & 3);
  if (!(args & 12) || round_mode == 3) {
    return "";
  }
  std::string s;
  switch (args & 12) {
    case 4:
      s = "MULRSHIFT";
      break;
    case 8:
      s = "MULMODPOW2";
      break;
    case 12:
      s = "MULRSHIFTMOD";
      break;
  }
  if (mode & 1) {
    s = "Q" + s;
  }
  s += "FRC"[round_mode];
  if (mode & 2) {
    char buff[8];
    sprintf(buff, " %d", y);
    s += buff;
  }
  return s;
}

int exec_shldivmod(VmState* st, unsigned args, int mode) {
  int y = -1;
  if (mode & 2) {
    y = (args & 0xff) + 1;
    args >>= 8;
  }
  int round_mode = (int)(args & 3) - 1;
  if (!(args & 12) || round_mode == 2) {
    throw VmError{Excno::inv_opcode};
  }
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute SHLDIV/MOD " << (args & 15) << ',' << y;
  if (!(mode & 2)) {
    stack.check_underflow(3);
    y = stack.pop_smallint_range(256);
  } else {
    stack.check_underflow(2);
  }
  auto z = stack.pop_int();
  auto x = stack.pop_int();
  typename td::BigInt256::DoubleInt tmp{*x};
  tmp <<= y;
  switch ((args >> 2) & 3) {
    case 1: {
      auto q = td::RefInt256{true};
      tmp.mod_div(*z, q.unique_write(), round_mode);
      q.unique_write().normalize();
      stack.push_int_quiet(std::move(q), mode & 1);
      break;
    }
    case 3: {
      auto q = td::RefInt256{true};
      tmp.mod_div(*z, q.unique_write(), round_mode);
      q.unique_write().normalize();
      stack.push_int_quiet(std::move(q), mode & 1);
      stack.push_int_quiet(td::RefInt256{true, tmp}, mode & 1);
      break;
    }
    case 2: {
      typename td::BigInt256::DoubleInt tmp2;
      tmp.mod_div(*z, tmp2, round_mode);
      stack.push_int_quiet(td::RefInt256{true, tmp}, mode & 1);
      break;
    }
  }
  return 0;
}

std::string dump_shldivmod(CellSlice&, unsigned args, bool quiet) {
  int round_mode = (int)(args & 3);
  if (!(args & 12) || round_mode == 3) {
    return "";
  }
  std::string s = (args & 4) ? "LSHIFTDIV" : "LSHIFT";
  if (args & 8) {
    s += "MOD";
  }
  if (quiet) {
    s = "Q" + s;
  }
  return s + "FRC"[round_mode];
}

void register_div_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  cp0.insert(OpcodeInstr::mkfixed(0xa90, 12, 4, std::bind(dump_divmod, _1, _2, false),
                                  std::bind(exec_divmod, _1, _2, false)))
      .insert(OpcodeInstr::mkfixed(0xa92, 12, 4, std::bind(dump_shrmod, _1, _2, 0), std::bind(exec_shrmod, _1, _2, 0)))
      .insert(OpcodeInstr::mkfixed(0xa93, 12, 12, std::bind(dump_shrmod, _1, _2, 2), std::bind(exec_shrmod, _1, _2, 2)))
      .insert(OpcodeInstr::mkfixed(0xa98, 12, 4, std::bind(dump_muldivmod, _1, _2, false),
                                   std::bind(exec_muldivmod, _1, _2, false)))
      .insert(OpcodeInstr::mkfixed(0xa9a, 12, 4, std::bind(dump_mulshrmod, _1, _2, 0),
                                   std::bind(exec_mulshrmod, _1, _2, 0)))
      .insert(OpcodeInstr::mkfixed(0xa9b, 12, 12, std::bind(dump_mulshrmod, _1, _2, 2),
                                   std::bind(exec_mulshrmod, _1, _2, 2)))
      .insert(OpcodeInstr::mkfixed(0xa9c, 12, 4, std::bind(dump_shldivmod, _1, _2, 0),
                                   std::bind(exec_shldivmod, _1, _2, 0)))
      .insert(OpcodeInstr::mkfixed(0xa9d, 12, 12, std::bind(dump_shldivmod, _1, _2, 2),
                                   std::bind(exec_shldivmod, _1, _2, 2)));
  cp0.insert(OpcodeInstr::mkfixed(0xb7a90, 20, 4, std::bind(dump_divmod, _1, _2, true),
                                  std::bind(exec_divmod, _1, _2, true)))
      .insert(
          OpcodeInstr::mkfixed(0xb7a92, 20, 4, std::bind(dump_shrmod, _1, _2, 1), std::bind(exec_shrmod, _1, _2, 1)))
      //     .insert(OpcodeInstr::mkfixed(0xb7a93, 20, 12, std::bind(dump_shrmod, _1, _2, 3), std::bind(exec_shrmod, _1, _2, 3)))
      .insert(OpcodeInstr::mkfixed(0xb7a98, 20, 4, std::bind(dump_muldivmod, _1, _2, true),
                                   std::bind(exec_muldivmod, _1, _2, true)))
      .insert(OpcodeInstr::mkfixed(0xb7a9a, 20, 4, std::bind(dump_mulshrmod, _1, _2, 1),
                                   std::bind(exec_mulshrmod, _1, _2, 1)))
      //     .insert(OpcodeInstr::mkfixed(0xb7a9b, 20, 12, std::bind(dump_mulshrmod, _1, _2, 3), std::bind(exec_mulshrmod, _1, _2, 3)))
      .insert(OpcodeInstr::mkfixed(0xb7a9c, 20, 4, std::bind(dump_shldivmod, _1, _2, 1),
                                   std::bind(exec_shldivmod, _1, _2, 1)))
      //     .insert(OpcodeInstr::mkfixed(0xb7a9d, 20, 12, std::bind(dump_shldivmod, _1, _2, 3), std::bind(exec_shldivmod, _1, _2, 3)))
      ;
}

int exec_lshift_tinyint8(VmState* st, unsigned args, bool quiet) {
  int x = (args & 0xff) + 1;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute LSHIFT " << x;
  stack.check_underflow(1);
  stack.push_int_quiet(stack.pop_int() << x, quiet);
  return 0;
}

int exec_rshift_tinyint8(VmState* st, unsigned args, bool quiet) {
  int x = (args & 0xff) + 1;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute RSHIFT " << x;
  stack.check_underflow(1);
  stack.push_int_quiet(stack.pop_int() >> x, quiet);
  return 0;
}

int exec_lshift(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute LSHIFT";
  stack.check_underflow(2);
  int x = stack.pop_smallint_range(1023);
  stack.push_int_quiet(stack.pop_int() << x, quiet);
  return 0;
}

int exec_rshift(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute RSHIFT";
  stack.check_underflow(2);
  int x = stack.pop_smallint_range(1023);
  stack.push_int_quiet(stack.pop_int() >> x, quiet);
  return 0;
}

int exec_pow2(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute POW2";
  stack.check_underflow(1);
  int x = stack.pop_smallint_range(1023);
  td::RefInt256 r{true};
  r.unique_write().set_pow2(x);
  stack.push_int_quiet(std::move(r), quiet);
  return 0;
}

int exec_and(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute AND";
  stack.check_underflow(2);
  auto y = stack.pop_int();
  stack.push_int_quiet(stack.pop_int() & std::move(y), quiet);
  return 0;
}

int exec_or(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute OR";
  stack.check_underflow(2);
  auto y = stack.pop_int();
  stack.push_int_quiet(stack.pop_int() | std::move(y), quiet);
  return 0;
}

int exec_xor(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XOR";
  stack.check_underflow(2);
  auto y = stack.pop_int();
  stack.push_int_quiet(stack.pop_int() ^ std::move(y), quiet);
  return 0;
}

int exec_not(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute NOT";
  stack.check_underflow(1);
  stack.push_int_quiet(~stack.pop_int(), quiet);
  return 0;
}

int exec_fits_tinyint8(VmState* st, unsigned args, bool quiet) {
  int y = (args & 0xff) + 1;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute FITS " << y;
  stack.check_underflow(1);
  auto x = stack.pop_int();
  if (!x->signed_fits_bits(y)) {
    x.write().invalidate();
  }
  stack.push_int_quiet(std::move(x), quiet);
  return 0;
}

int exec_ufits_tinyint8(VmState* st, unsigned args, bool quiet) {
  int y = (args & 0xff) + 1;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute UFITS " << y;
  stack.check_underflow(1);
  auto x = stack.pop_int();
  if (!x->unsigned_fits_bits(y)) {
    x.write().invalidate();
  }
  stack.push_int_quiet(std::move(x), quiet);
  return 0;
}

int exec_fits(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute FITSX";
  stack.check_underflow(2);
  int y = stack.pop_smallint_range(1023);
  auto x = stack.pop_int();
  if (!x->signed_fits_bits(y)) {
    x.write().invalidate();
  }
  stack.push_int_quiet(std::move(x), quiet);
  return 0;
}

int exec_ufits(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute UFITSX";
  stack.check_underflow(2);
  int y = stack.pop_smallint_range(1023);
  auto x = stack.pop_int();
  if (!x->unsigned_fits_bits(y)) {
    x.write().invalidate();
  }
  stack.push_int_quiet(std::move(x), quiet);
  return 0;
}

int exec_bitsize(VmState* st, bool sgnd, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << (sgnd ? "" : "U") << "BITSIZE";
  stack.check_underflow(1);
  auto x = stack.pop_int();
  int y = x->bit_size(sgnd);
  if (y < 0x7fffffff) {
    stack.push_smallint(y);
  } else if (!quiet) {
    throw VmError{Excno::range_chk, "CHKSIZE for negative integer"};
  } else {
    stack.push_int_quiet(td::RefInt256{true}, quiet);
  }
  return 0;
}

void register_shift_logic_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  cp0.insert(OpcodeInstr::mkfixed(0xaa, 8, 8, instr::dump_1c_l_add(1, "LSHIFT "),
                                  std::bind(exec_lshift_tinyint8, _1, _2, false)))
      .insert(OpcodeInstr::mkfixed(0xab, 8, 8, instr::dump_1c_l_add(1, "RSHIFT "),
                                   std::bind(exec_rshift_tinyint8, _1, _2, false)))
      .insert(OpcodeInstr::mksimple(0xac, 8, "LSHIFT", std::bind(exec_lshift, _1, false)))
      .insert(OpcodeInstr::mksimple(0xad, 8, "RSHIFT", std::bind(exec_rshift, _1, false)))
      .insert(OpcodeInstr::mksimple(0xae, 8, "POW2", std::bind(exec_pow2, _1, false)))
      .insert(OpcodeInstr::mksimple(0xb0, 8, "AND", std::bind(exec_and, _1, false)))
      .insert(OpcodeInstr::mksimple(0xb1, 8, "OR", std::bind(exec_or, _1, false)))
      .insert(OpcodeInstr::mksimple(0xb2, 8, "XOR", std::bind(exec_xor, _1, false)))
      .insert(OpcodeInstr::mksimple(0xb3, 8, "NOT", std::bind(exec_not, _1, false)))
      .insert(OpcodeInstr::mkfixed(0xb4, 8, 8, instr::dump_1c_l_add(1, "FITS "),
                                   std::bind(exec_fits_tinyint8, _1, _2, false)))
      .insert(OpcodeInstr::mkfixed(0xb5, 8, 8, instr::dump_1c_l_add(1, "UFITS "),
                                   std::bind(exec_ufits_tinyint8, _1, _2, false)))
      .insert(OpcodeInstr::mksimple(0xb600, 16, "FITSX", std::bind(exec_fits, _1, false)))
      .insert(OpcodeInstr::mksimple(0xb601, 16, "UFITSX", std::bind(exec_ufits, _1, false)))
      .insert(OpcodeInstr::mksimple(0xb602, 16, "BITSIZE", std::bind(exec_bitsize, _1, true, false)))
      .insert(OpcodeInstr::mksimple(0xb603, 16, "UBITSIZE", std::bind(exec_bitsize, _1, false, false)));
  cp0.insert(OpcodeInstr::mkfixed(0xb7aa, 16, 8, instr::dump_1c_l_add(1, "QLSHIFT "),
                                  std::bind(exec_lshift_tinyint8, _1, _2, true)))
      .insert(OpcodeInstr::mkfixed(0xb7ab, 16, 8, instr::dump_1c_l_add(1, "QRSHIFT "),
                                   std::bind(exec_rshift_tinyint8, _1, _2, true)))
      .insert(OpcodeInstr::mksimple(0xb7ac, 16, "QLSHIFT", std::bind(exec_lshift, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7ad, 16, "QRSHIFT", std::bind(exec_rshift, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7ae, 16, "QPOW2", std::bind(exec_pow2, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7b0, 16, "QAND", std::bind(exec_and, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7b1, 16, "QOR", std::bind(exec_or, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7b2, 16, "QXOR", std::bind(exec_xor, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7b3, 16, "QNOT", std::bind(exec_not, _1, true)))
      .insert(OpcodeInstr::mkfixed(0xb7b4, 16, 8, instr::dump_1c_l_add(1, "QFITS "),
                                   std::bind(exec_fits_tinyint8, _1, _2, true)))
      .insert(OpcodeInstr::mkfixed(0xb7b5, 16, 8, instr::dump_1c_l_add(1, "QUFITS "),
                                   std::bind(exec_ufits_tinyint8, _1, _2, true)))
      .insert(OpcodeInstr::mksimple(0xb7b600, 24, "QFITSX", std::bind(exec_fits, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7b601, 24, "QUFITSX", std::bind(exec_ufits, _1, true)))
      .insert(OpcodeInstr::mksimple(0xb7b602, 24, "QBITSIZE", std::bind(exec_bitsize, _1, true, true)))
      .insert(OpcodeInstr::mksimple(0xb7b603, 24, "QUBITSIZE", std::bind(exec_bitsize, _1, false, true)));
}

int exec_minmax(VmState* st, int mode) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute MINMAXOP " << mode;
  stack.check_underflow(2);
  auto x = stack.pop_int();
  auto y = stack.pop_int();
  if (!x->is_valid()) {
    y = x;
  } else if (!y->is_valid()) {
    x = y;
  } else if (cmp(x, y) > 0) {
    swap(x, y);
  }
  if (mode & 2) {
    stack.push_int_quiet(std::move(x), mode & 1);
  }
  if (mode & 4) {
    stack.push_int_quiet(std::move(y), mode & 1);
  }
  return 0;
}

int exec_abs(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ABS";
  stack.check_underflow(1);
  auto x = stack.pop_int();
  if (x->is_valid() && x->sgn() < 0) {
    stack.push_int_quiet(-std::move(x), quiet);
  } else {
    stack.push_int_quiet(std::move(x), quiet);
  }
  return 0;
}

void register_other_arith_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  cp0.insert(OpcodeInstr::mksimple(0xb608, 16, "MIN", std::bind(exec_minmax, _1, 2)))
      .insert(OpcodeInstr::mksimple(0xb609, 16, "MAX", std::bind(exec_minmax, _1, 4)))
      .insert(OpcodeInstr::mksimple(0xb60a, 16, "MINMAX", std::bind(exec_minmax, _1, 6)))
      .insert(OpcodeInstr::mksimple(0xb60b, 16, "ABS", std::bind(exec_abs, _1, false)));
  cp0.insert(OpcodeInstr::mksimple(0xb7b608, 24, "QMIN", std::bind(exec_minmax, _1, 3)))
      .insert(OpcodeInstr::mksimple(0xb7b609, 24, "QMAX", std::bind(exec_minmax, _1, 5)))
      .insert(OpcodeInstr::mksimple(0xb7b60a, 24, "QMINMAX", std::bind(exec_minmax, _1, 7)))
      .insert(OpcodeInstr::mksimple(0xb7b60b, 24, "QABS", std::bind(exec_abs, _1, true)));
}

int exec_sgn(VmState* st, int mode, bool quiet, const char* name) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(1);
  auto x = stack.pop_int();
  if (!x->is_valid()) {
    stack.push_int_quiet(std::move(x), quiet);
  } else {
    int y = td::sgn(std::move(x));
    stack.push_smallint(((mode >> (4 + y * 4)) & 15) - 8);
  }
  return 0;
}

int exec_cmp(VmState* st, int mode, bool quiet, const char* name) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(2);
  auto y = stack.pop_int();
  auto x = stack.pop_int();
  if (!x->is_valid() || !y->is_valid()) {
    stack.push_int_quiet(std::move(x), quiet);
  } else {
    int z = td::cmp(std::move(x), std::move(y));
    stack.push_smallint(((mode >> (4 + z * 4)) & 15) - 8);
  }
  return 0;
}

int exec_cmp_int(VmState* st, unsigned args, int mode, bool quiet, const char* name) {
  int y = (signed char)args;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name << "INT " << y;
  stack.check_underflow(1);
  auto x = stack.pop_int();
  if (!x->is_valid()) {
    stack.push_int_quiet(std::move(x), quiet);
  } else {
    int z = td::cmp(std::move(x), y);
    stack.push_smallint(((mode >> (4 + z * 4)) & 15) - 8);
  }
  return 0;
}

int exec_is_nan(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ISNAN";
  stack.check_underflow(1);
  auto x = stack.pop_int();
  stack.push_smallint(x->is_valid() ? 0 : -1);
  return 0;
}

int exec_chk_nan(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute CHKNAN";
  stack.check_underflow(1);
  auto x = stack.pop_int();
  stack.push_int(std::move(x));
  return 0;
}

void register_int_cmp_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  cp0.insert(OpcodeInstr::mksimple(0xb8, 8, "SGN", std::bind(exec_sgn, _1, 0x987, false, "SGN")))
      .insert(OpcodeInstr::mksimple(0xb9, 8, "LESS", std::bind(exec_cmp, _1, 0x887, false, "LESS")))
      .insert(OpcodeInstr::mksimple(0xba, 8, "EQUAL", std::bind(exec_cmp, _1, 0x878, false, "EQUAL")))
      .insert(OpcodeInstr::mksimple(0xbb, 8, "LEQ", std::bind(exec_cmp, _1, 0x877, false, "LEQ")))
      .insert(OpcodeInstr::mksimple(0xbc, 8, "GREATER", std::bind(exec_cmp, _1, 0x788, false, "GREATER")))
      .insert(OpcodeInstr::mksimple(0xbd, 8, "NEQ", std::bind(exec_cmp, _1, 0x787, false, "NEQ")))
      .insert(OpcodeInstr::mksimple(0xbe, 8, "GEQ", std::bind(exec_cmp, _1, 0x778, false, "GEQ")))
      .insert(OpcodeInstr::mksimple(0xbf, 8, "CMP", std::bind(exec_cmp, _1, 0x987, false, "CMP")))
      .insert(OpcodeInstr::mkfixed(0xc0, 8, 8, std::bind(dump_op_tinyint8, "EQINT ", _1, _2),
                                   std::bind(exec_cmp_int, _1, _2, 0x878, false, "EQ")))
      .insert(OpcodeInstr::mkfixed(0xc1, 8, 8, std::bind(dump_op_tinyint8, "LESSINT ", _1, _2),
                                   std::bind(exec_cmp_int, _1, _2, 0x887, false, "LESS")))
      .insert(OpcodeInstr::mkfixed(0xc2, 8, 8, std::bind(dump_op_tinyint8, "GTINT ", _1, _2),
                                   std::bind(exec_cmp_int, _1, _2, 0x788, false, "GT")))
      .insert(OpcodeInstr::mkfixed(0xc3, 8, 8, std::bind(dump_op_tinyint8, "NEQINT ", _1, _2),
                                   std::bind(exec_cmp_int, _1, _2, 0x787, false, "NEQ")))
      .insert(OpcodeInstr::mksimple(0xc4, 8, "ISNAN", exec_is_nan))
      .insert(OpcodeInstr::mksimple(0xc5, 8, "CHKNAN", exec_chk_nan));
  cp0.insert(OpcodeInstr::mksimple(0xb7b8, 16, "QSGN", std::bind(exec_sgn, _1, 0x987, true, "QSGN")))
      .insert(OpcodeInstr::mksimple(0xb7b9, 16, "QLESS", std::bind(exec_cmp, _1, 0x887, true, "QLESS")))
      .insert(OpcodeInstr::mksimple(0xb7ba, 16, "QEQUAL", std::bind(exec_cmp, _1, 0x878, true, "QEQUAL")))
      .insert(OpcodeInstr::mksimple(0xb7bb, 16, "QLEQ", std::bind(exec_cmp, _1, 0x877, true, "QLEQ")))
      .insert(OpcodeInstr::mksimple(0xb7bc, 16, "QGREATER", std::bind(exec_cmp, _1, 0x788, true, "QGREATER")))
      .insert(OpcodeInstr::mksimple(0xb7bd, 16, "QNEQ", std::bind(exec_cmp, _1, 0x787, true, "QNEQ")))
      .insert(OpcodeInstr::mksimple(0xb7be, 16, "QGEQ", std::bind(exec_cmp, _1, 0x778, true, "QGEQ")))
      .insert(OpcodeInstr::mksimple(0xb7bf, 16, "QCMP", std::bind(exec_cmp, _1, 0x987, true, "QCMP")))
      .insert(OpcodeInstr::mkfixed(0xb7c0, 16, 8, std::bind(dump_op_tinyint8, "QEQINT ", _1, _2),
                                   std::bind(exec_cmp_int, _1, _2, 0x878, true, "QEQ")))
      .insert(OpcodeInstr::mkfixed(0xb7c1, 16, 8, std::bind(dump_op_tinyint8, "QLESSINT ", _1, _2),
                                   std::bind(exec_cmp_int, _1, _2, 0x887, true, "QLESS")))
      .insert(OpcodeInstr::mkfixed(0xb7c2, 16, 8, std::bind(dump_op_tinyint8, "QGTINT ", _1, _2),
                                   std::bind(exec_cmp_int, _1, _2, 0x788, true, "QGT")))
      .insert(OpcodeInstr::mkfixed(0xb7c3, 16, 8, std::bind(dump_op_tinyint8, "QNEQINT ", _1, _2),
                                   std::bind(exec_cmp_int, _1, _2, 0x787, true, "QNEQ")));
}

void register_arith_ops(OpcodeTable& cp0) {
  register_int_const_ops(cp0);
  register_add_mul_ops(cp0);
  register_div_ops(cp0);
  register_shift_logic_ops(cp0);
  register_other_arith_ops(cp0);
  register_int_cmp_ops(cp0);
}

}  // namespace vm
