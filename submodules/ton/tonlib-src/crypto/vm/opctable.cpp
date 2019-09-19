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
#include <cassert>
#include <iterator>
#include "vm/opctable.h"
#include "vm/cellslice.h"
#include "vm/excno.hpp"
#include "vm/continuation.h"
#include <iostream>
#include <iomanip>
#include <sstream>
#include <functional>

#include "td/utils/format.h"

namespace vm {

DispatchTable* OpcodeTable::finalize() {
  if (final) {
    return this;
  }
  instruction_list.clear();
  instruction_list.reserve(instructions.size() * 2 + 1);

  unsigned upto = 0;
  for (const auto& x : instructions) {
    auto range = x.second->get_opcode_range();
    assert(range.first == x.first);
    assert(range.first < range.second);
    assert(range.first >= upto);
    assert(range.second <= top_opcode);
    if (range.first > upto) {
      instruction_list.emplace_back(upto, new OpcodeInstrDummy{upto, range.first});
    }
    instruction_list.emplace_back(x);
    upto = range.second;
  }

  if (upto < top_opcode) {
    instruction_list.emplace_back(upto, new OpcodeInstrDummy{upto, top_opcode});
  }

  instruction_list.shrink_to_fit();
  final = true;
  return this;
}

OpcodeTable& OpcodeTable::insert(const OpcodeInstr* instr) {
  LOG_IF(FATAL, !insert_bool(instr)) << td::format::lambda([&](auto& sb) {
    sb << "cannot insert instruction into table " << name << ": ";
    if (!instr) {
      sb << "instruction is null";
    } else if (final) {
      sb << "instruction table already finalized";
    } else {
      auto range = instr->get_opcode_range();
      sb << "opcode range " << td::format::as_hex(range.first) << ".." << td::format::as_hex(range.second - 1)
         << " already occupied or invalid";
    }
  });
  return *this;
}

bool OpcodeTable::insert_bool(const OpcodeInstr* instr) {
  if (!instr || final) {
    return false;
  }
  auto range = instr->get_opcode_range();
  assert(range.first < range.second);
  assert(range.second <= top_opcode);
  auto it = instructions.lower_bound(range.first);
  if (it != instructions.end() && it->first < range.second) {
    return false;
  }
  if (it != instructions.begin()) {
    auto prev_range = std::prev(it)->second->get_opcode_range();
    assert(prev_range.first < prev_range.second);
    assert(prev_range.first == std::prev(it)->first);
    if (prev_range.second > range.first) {
      return false;
    }
  }
  instructions.emplace_hint(it, range.first, instr);
  return true;
}

const OpcodeInstr* OpcodeTable::lookup_instr(unsigned opcode, unsigned bits) const {
  std::size_t i = 0, j = instruction_list.size();
  assert(j);
  while (j - i > 1) {
    auto k = ((j + i) >> 1);
    if (instruction_list[k].first <= opcode) {
      i = k;
    } else {
      j = k;
    }
  }
  return instruction_list[i].second;
}

const OpcodeInstr* OpcodeTable::lookup_instr(const CellSlice& cs, unsigned& opcode, unsigned& bits) const {
  bits = max_opcode_bits;
  unsigned long long prefetch = cs.prefetch_ulong_top(bits);
  opcode = (unsigned)(prefetch >> (64 - max_opcode_bits));
  opcode &= (static_cast<int32_t>(static_cast<td::uint32>(-1) << max_opcode_bits) >> bits);
  return lookup_instr(opcode, bits);
}

int OpcodeTable::dispatch(VmState* st, CellSlice& cs) const {
  assert(final);
  unsigned bits, opcode;
  auto instr = lookup_instr(cs, opcode, bits);
  //std::cerr << "lookup_instr: cs.size()=" << cs.size() << "; bits=" << bits << "; opcode=" << std::setw(6) << std::setfill('0') << std::hex << opcode << std::dec << std::endl;
  return instr->dispatch(st, cs, opcode, bits);
}

std::string OpcodeTable::dump_instr(CellSlice& cs) const {
  assert(final);
  unsigned bits, opcode;
  auto instr = lookup_instr(cs, opcode, bits);
  return instr->dump(cs, opcode, bits);
}

int OpcodeTable::instr_len(const CellSlice& cs) const {
  assert(final);
  unsigned bits, opcode;
  auto instr = lookup_instr(cs, opcode, bits);
  return instr->instr_len(cs, opcode, bits);
}

OpcodeInstr::OpcodeInstr(unsigned _opcode, unsigned _bits, bool)
    : min_opcode(_opcode << (max_opcode_bits - _bits)), max_opcode((_opcode + 1) << (max_opcode_bits - _bits)) {
  assert(_opcode < (1U << _bits) && _bits <= max_opcode_bits);
}

int OpcodeInstrDummy::dispatch(VmState* st, CellSlice& cs, unsigned opcode, unsigned bits) const {
  st->consume_gas(gas_per_instr);
  throw VmError{Excno::inv_opcode, "invalid opcode", opcode};
}

std::string OpcodeInstr::dump(CellSlice& cs, unsigned opcode, unsigned bits) const {
  return "";
}

int OpcodeInstr::instr_len(const CellSlice& cs, unsigned opcode, unsigned bits) const {
  return 0;
}

OpcodeInstrSimple::OpcodeInstrSimple(unsigned opcode, unsigned _opc_bits, std::string _name, exec_instr_func_t exec)
    : OpcodeInstr(opcode, _opc_bits, false)
    , opc_bits(static_cast<unsigned char>(_opc_bits))
    , name(_name)
    , exec_instr(exec) {
}

int OpcodeInstrSimple::dispatch(VmState* st, CellSlice& cs, unsigned opcode, unsigned bits) const {
  st->consume_gas(gas_per_instr + opc_bits * gas_per_bit);
  if (bits < opc_bits) {
    throw VmError{Excno::inv_opcode, "invalid or too short opcode", opcode + (bits << max_opcode_bits)};
  }
  cs.advance(opc_bits);
  return exec_instr(st, cs, opcode >> (max_opcode_bits - opc_bits), opc_bits);
}

std::string OpcodeInstrSimple::dump(CellSlice& cs, unsigned opcode, unsigned bits) const {
  if (bits < opc_bits) {
    return "";
  }
  cs.advance(opc_bits);
  return name;
}

int OpcodeInstrSimple::instr_len(const CellSlice& cs, unsigned opcode, unsigned bits) const {
  if (bits < opc_bits) {
    return 0;
  } else {
    return opc_bits;
  }
}

OpcodeInstrSimplest::OpcodeInstrSimplest(unsigned opcode, unsigned _opc_bits, std::string _name,
                                         exec_simple_instr_func_t exec)
    : OpcodeInstr(opcode, _opc_bits, false)
    , opc_bits(static_cast<unsigned char>(_opc_bits))
    , name(_name)
    , exec_instr(exec) {
}

int OpcodeInstrSimplest::dispatch(VmState* st, CellSlice& cs, unsigned opcode, unsigned bits) const {
  st->consume_gas(gas_per_instr + opc_bits * gas_per_bit);
  if (bits < opc_bits) {
    throw VmError{Excno::inv_opcode, "invalid or too short opcode", opcode + (bits << max_opcode_bits)};
  }
  cs.advance(opc_bits);
  return exec_instr(st);
}

std::string OpcodeInstrSimplest::dump(CellSlice& cs, unsigned opcode, unsigned bits) const {
  if (bits < opc_bits) {
    return "";
  }
  cs.advance(opc_bits);
  return name;
}

int OpcodeInstrSimplest::instr_len(const CellSlice& cs, unsigned opcode, unsigned bits) const {
  if (bits < opc_bits) {
    return 0;
  } else {
    return opc_bits;
  }
}

OpcodeInstrFixed::OpcodeInstrFixed(unsigned opcode, unsigned _opc_bits, unsigned _arg_bits, dump_arg_instr_func_t dump,
                                   exec_arg_instr_func_t exec)
    : OpcodeInstr(opcode, _opc_bits, false)
    , opc_bits(static_cast<unsigned char>(_opc_bits))
    , tot_bits(static_cast<unsigned char>(_opc_bits + _arg_bits))
    , dump_instr(dump)
    , exec_instr(exec) {
  assert(_arg_bits <= max_opcode_bits && _opc_bits <= max_opcode_bits && _arg_bits + _opc_bits <= max_opcode_bits);
}

OpcodeInstrFixed::OpcodeInstrFixed(unsigned opcode_min, unsigned opcode_max, unsigned _tot_bits, unsigned _arg_bits,
                                   dump_arg_instr_func_t dump, exec_arg_instr_func_t exec)
    : OpcodeInstr(opcode_min << (max_opcode_bits - _tot_bits), opcode_max << (max_opcode_bits - _tot_bits))
    , opc_bits(static_cast<unsigned char>(_tot_bits - _arg_bits))
    , tot_bits(static_cast<unsigned char>(_tot_bits))
    , dump_instr(dump)
    , exec_instr(exec) {
  assert(_arg_bits <= _tot_bits && _tot_bits <= max_opcode_bits);
  assert(opcode_min < opcode_max && opcode_max <= (1U << _tot_bits));
}

int OpcodeInstrFixed::dispatch(VmState* st, CellSlice& cs, unsigned opcode, unsigned bits) const {
  st->consume_gas(gas_per_instr + tot_bits * gas_per_bit);
  if (bits < tot_bits) {
    throw VmError{Excno::inv_opcode, "invalid or too short opcode", opcode + (bits << max_opcode_bits)};
  }
  cs.advance(tot_bits);
  return exec_instr(st, opcode >> (max_opcode_bits - tot_bits));
}

std::string OpcodeInstrFixed::dump(CellSlice& cs, unsigned opcode, unsigned bits) const {
  if (bits < tot_bits) {
    return "";
  }
  cs.advance(tot_bits);
  return dump_instr(cs, opcode >> (max_opcode_bits - tot_bits));
}

int OpcodeInstrFixed::instr_len(const CellSlice& cs, unsigned opcode, unsigned bits) const {
  if (bits < tot_bits) {
    return 0;
  } else {
    return tot_bits;
  }
}

OpcodeInstrExt::OpcodeInstrExt(unsigned opcode, unsigned _opc_bits, unsigned _arg_bits, dump_instr_func_t dump,
                               exec_instr_func_t exec, compute_instr_len_func_t comp_len)
    : OpcodeInstr(opcode, _opc_bits, false)
    , opc_bits(static_cast<unsigned char>(_opc_bits))
    , tot_bits(static_cast<unsigned char>(_opc_bits + _arg_bits))
    , dump_instr(dump)
    , exec_instr(exec)
    , compute_instr_len(comp_len) {
  assert(_arg_bits <= max_opcode_bits && _opc_bits <= max_opcode_bits && _arg_bits + _opc_bits <= max_opcode_bits);
}

OpcodeInstrExt::OpcodeInstrExt(unsigned opcode_min, unsigned opcode_max, unsigned _tot_bits, unsigned _arg_bits,
                               dump_instr_func_t dump, exec_instr_func_t exec, compute_instr_len_func_t comp_len)
    : OpcodeInstr(opcode_min << (max_opcode_bits - _tot_bits), opcode_max << (max_opcode_bits - _tot_bits))
    , opc_bits(static_cast<unsigned char>(_tot_bits - _arg_bits))
    , tot_bits(static_cast<unsigned char>(_tot_bits))
    , dump_instr(dump)
    , exec_instr(exec)
    , compute_instr_len(comp_len) {
  assert(_arg_bits <= _tot_bits && _tot_bits <= max_opcode_bits);
  assert(opcode_min < opcode_max && opcode_max <= (1U << _tot_bits));
}

int OpcodeInstrExt::dispatch(VmState* st, CellSlice& cs, unsigned opcode, unsigned bits) const {
  st->consume_gas(gas_per_instr + tot_bits * gas_per_bit);
  if (bits < tot_bits) {
    throw VmError{Excno::inv_opcode, "invalid or too short opcode", opcode + (bits << max_opcode_bits)};
  }
  return exec_instr(st, cs, opcode >> (max_opcode_bits - tot_bits), tot_bits);
}

std::string OpcodeInstrExt::dump(CellSlice& cs, unsigned opcode, unsigned bits) const {
  if (bits < tot_bits) {
    return "";
  }
  return dump_instr(cs, opcode >> (max_opcode_bits - tot_bits), (int)tot_bits);
}

int OpcodeInstrExt::instr_len(const CellSlice& cs, unsigned opcode, unsigned bits) const {
  if (bits < tot_bits) {
    return 0;
  } else {
    return compute_instr_len(cs, opcode >> (max_opcode_bits - tot_bits), (int)tot_bits);
  }
}

/*
OpcodeInstr* OpcodeInstr::mksimple(unsigned opcode, unsigned opc_bits, std::string _name, exec_instr_func_t exec) {
  return new OpcodeInstrSimple(opcode, opc_bits, _name, exec);
}
*/

OpcodeInstr* OpcodeInstr::mksimple(unsigned opcode, unsigned opc_bits, std::string _name,
                                   exec_simple_instr_func_t exec) {
  return new OpcodeInstrSimplest(opcode, opc_bits, _name, exec);
}

OpcodeInstr* OpcodeInstr::mkfixed(unsigned opcode, unsigned opc_bits, unsigned arg_bits, dump_arg_instr_func_t dump,
                                  exec_arg_instr_func_t exec) {
  return new OpcodeInstrFixed(opcode, opc_bits, arg_bits, dump, exec);
}

OpcodeInstr* OpcodeInstr::mkfixedrange(unsigned opcode_min, unsigned opcode_max, unsigned tot_bits, unsigned arg_bits,
                                       dump_arg_instr_func_t dump, exec_arg_instr_func_t exec) {
  return new OpcodeInstrFixed(opcode_min, opcode_max, tot_bits, arg_bits, dump, exec);
}

OpcodeInstr* OpcodeInstr::mkext(unsigned opcode, unsigned opc_bits, unsigned arg_bits, dump_instr_func_t dump,
                                exec_instr_func_t exec, compute_instr_len_func_t comp_len) {
  return new OpcodeInstrExt(opcode, opc_bits, arg_bits, dump, exec, comp_len);
}

OpcodeInstr* OpcodeInstr::mkextrange(unsigned opcode_min, unsigned opcode_max, unsigned tot_bits, unsigned arg_bits,
                                     dump_instr_func_t dump, exec_instr_func_t exec,
                                     compute_instr_len_func_t comp_len) {
  return new OpcodeInstrExt(opcode_min, opcode_max, tot_bits, arg_bits, dump, exec, comp_len);
}

namespace instr {

using namespace std::placeholders;

dump_arg_instr_func_t dump_1sr(std::string prefix, std::string suffix) {
  return [prefix, suffix](CellSlice&, unsigned args) -> std::string {
    std::ostringstream os{prefix};
    os << 's' << (args & 15) << suffix;
    return os.str();
  };
}

dump_arg_instr_func_t dump_1sr_l(std::string prefix, std::string suffix) {
  return [prefix, suffix](CellSlice&, unsigned args) -> std::string {
    std::ostringstream os{prefix};
    os << 's' << (args & 255) << suffix;
    return os.str();
  };
}

dump_arg_instr_func_t dump_2sr(std::string prefix, std::string suffix) {
  return [prefix, suffix](CellSlice&, unsigned args) -> std::string {
    std::ostringstream os{prefix};
    os << 's' << ((args >> 4) & 15) << ",s" << (args & 15) << suffix;
    return os.str();
  };
}

dump_arg_instr_func_t dump_2sr_adj(unsigned adj, std::string prefix, std::string suffix) {
  return [adj, prefix, suffix](CellSlice&, unsigned args) -> std::string {
    std::ostringstream os{prefix};
    os << 's' << (int)((args >> 4) & 15) - (int)((adj >> 4) & 15) << ",s" << (int)(args & 15) - (int)(adj & 15)
       << suffix;
    return os.str();
  };
}

dump_arg_instr_func_t dump_3sr(std::string prefix, std::string suffix) {
  return [prefix, suffix](CellSlice&, unsigned args) -> std::string {
    std::ostringstream os{prefix};
    os << 's' << ((args >> 8) & 15) << ",s" << ((args >> 4) & 15) << ",s" << (args & 15) << suffix;
    return os.str();
  };
}

dump_arg_instr_func_t dump_3sr_adj(unsigned adj, std::string prefix, std::string suffix) {
  return [adj, prefix, suffix](CellSlice&, unsigned args) -> std::string {
    std::ostringstream os{prefix};
    os << 's' << (int)((args >> 8) & 15) - (int)((adj >> 8) & 15) << ",s"
       << (int)((args >> 4) & 15) - (int)((adj >> 4) & 15) << ",s" << (int)(args & 15) - (int)(adj & 15) << suffix;
    return os.str();
  };
}

dump_arg_instr_func_t dump_1c(std::string prefix, std::string suffix) {
  return [prefix, suffix](CellSlice&, unsigned args) -> std::string {
    std::ostringstream os{prefix};
    os << (args & 15) << suffix;
    return os.str();
  };
}

dump_arg_instr_func_t dump_1c_l_add(int adj, std::string prefix, std::string suffix) {
  return [adj, prefix, suffix](CellSlice&, unsigned args) -> std::string {
    std::ostringstream os{prefix};
    os << (int)(args & 255) + adj << suffix;
    return os.str();
  };
}

dump_arg_instr_func_t dump_1c_and(unsigned mask, std::string prefix, std::string suffix) {
  return [mask, prefix, suffix](CellSlice&, unsigned args) -> std::string {
    std::ostringstream os{prefix};
    os << (args & mask) << suffix;
    return os.str();
  };
}

dump_arg_instr_func_t dump_2c(std::string prefix, std::string interfix, std::string suffix) {
  return [prefix, interfix, suffix](CellSlice&, unsigned args) -> std::string {
    std::ostringstream os{prefix};
    os << ((args >> 4) & 15) << interfix << (args & 15) << suffix;
    return os.str();
  };
}

dump_arg_instr_func_t dump_2c_add(unsigned add, std::string prefix, std::string interfix, std::string suffix) {
  return [add, prefix, interfix, suffix](CellSlice&, unsigned args) -> std::string {
    std::ostringstream os{prefix};
    os << ((args >> 4) & 15) + ((add >> 4) & 15) << interfix << (args & 15) + (add & 15) << suffix;
    return os.str();
  };
}

}  // namespace instr

}  // namespace vm
