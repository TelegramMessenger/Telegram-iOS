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
#include "common/refcnt.hpp"
#include "vm/cells.h"

#include "td/utils/Context.h"

namespace vm {
using td::Ref;

class VmStateInterface : public td::Context<VmStateInterface> {
 public:
  virtual ~VmStateInterface() = default;
  virtual Ref<Cell> load_library(
      td::ConstBitPtr hash) {  // may throw a dictionary exception; returns nullptr if library is not found
    return {};
  }
  virtual void register_cell_load(const CellHash& cell_hash){};
  virtual void register_cell_create(){};
  virtual void register_new_cell(Ref<DataCell>& cell){};
  virtual bool register_op(int op_units = 1) {
    return true;
  };
};

}  // namespace vm
