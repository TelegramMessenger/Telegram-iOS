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
#include <string>

namespace vm {

class VmState;
class CellSlice;

enum class Codepage { test_cp = 0 };

class DispatchTable {
 public:
  DispatchTable() = default;
  virtual ~DispatchTable() = default;
  virtual int dispatch(VmState* st, CellSlice& cs) const = 0;
  virtual std::string dump_instr(CellSlice& cs) const = 0;
  virtual int instr_len(const CellSlice& cs) const = 0;
  virtual DispatchTable* finalize() = 0;
  virtual bool is_final() const = 0;
  static const DispatchTable* get_table(Codepage cp);
  static const DispatchTable* get_table(int cp);
  static bool register_table(Codepage cp, const DispatchTable& dt);
  bool register_table(Codepage cp) const;
};

class DummyDispatchTable : public DispatchTable {
 public:
  DummyDispatchTable() : DispatchTable() {
  }
  ~DummyDispatchTable() override = default;
  int dispatch(VmState* st, CellSlice& cs) const override;
  std::string dump_instr(CellSlice& cs) const override;
  int instr_len(const CellSlice& cs) const override;
  DispatchTable* finalize() override {
    return this;
  }
  bool is_final() const override {
    return true;
  }
};

extern DummyDispatchTable dummy_dispatch_table;

}  // namespace vm
