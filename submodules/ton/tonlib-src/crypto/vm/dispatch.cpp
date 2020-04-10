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
#include "vm/dispatch.h"
#include "vm/excno.hpp"
#include <cassert>
#include <map>
#include <mutex>

namespace vm {

namespace {
std::mutex dispatch_tables_mutex;
std::map<int, const DispatchTable*> dispatch_tables;
}  // namespace

DummyDispatchTable dummy_dispatch_table;

bool DispatchTable::register_table(Codepage _cp, const DispatchTable& dt) {
  assert(dt.is_final());
  int cp = (int)_cp;
  if (cp < -0x8000 || cp >= 0x8000 || cp == -1) {
    return false;
  } else {
    std::lock_guard<std::mutex> guard(dispatch_tables_mutex);
    return dispatch_tables.emplace(cp, &dt).second;
  }
}

bool DispatchTable::register_table(Codepage cp) const {
  return register_table(cp, *this);
}

const DispatchTable* DispatchTable::get_table(Codepage cp) {
  return get_table((int)cp);
}

const DispatchTable* DispatchTable::get_table(int cp) {
  std::lock_guard<std::mutex> guard(dispatch_tables_mutex);
  auto entry = dispatch_tables.find(cp);
  return entry != dispatch_tables.end() ? entry->second : 0;
}

int DummyDispatchTable::dispatch(VmState* st, CellSlice& cs) const {
  throw VmError{Excno::inv_opcode, "empty opcode table"};
}

std::string DummyDispatchTable::dump_instr(CellSlice& cs) const {
  return "";
}

int DummyDispatchTable::instr_len(const CellSlice& cs) const {
  return 0;
}

}  // namespace vm
