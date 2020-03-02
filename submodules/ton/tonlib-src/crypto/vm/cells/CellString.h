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

    Copyright 2019-2020 Telegram Systems LLP
*/
#pragma once

#include "td/utils/Status.h"

#include "vm/cells/CellBuilder.h"

namespace vm {
class CellString {
 public:
  static constexpr unsigned int max_bytes = 1024;
  static constexpr unsigned int max_chain_length = 16;

  static td::Status store(CellBuilder &cb, td::Slice slice, unsigned int top_bits = Cell::max_bits);
  static td::Status store(CellBuilder &cb, td::BitSlice slice, unsigned int top_bits = Cell::max_bits);
  static td::Result<td::string> load(CellSlice &cs, unsigned int top_bits = Cell::max_bits);
  static td::Result<td::Ref<vm::Cell>> create(td::Slice slice, unsigned int top_bits = Cell::max_bits) {
    vm::CellBuilder cb;
    TRY_STATUS(store(cb, slice, top_bits));
    return cb.finalize();
  }

 private:
  template <class F>
  static void for_each(F &&f, CellSlice &cs, unsigned int top_bits = Cell::max_bits);
};

class CellText {
 public:
  static constexpr unsigned int max_bytes = 1024;
  static constexpr unsigned int max_chain_length = 16;

  static td::Status store(CellBuilder &cb, td::Slice slice, unsigned int top_bits = Cell::max_bits);
  static td::Status store(CellBuilder &cb, td::BitSlice slice, unsigned int top_bits = Cell::max_bits);
  static td::Result<td::string> load(CellSlice &cs);
  static td::Result<td::Ref<vm::Cell>> create(td::Slice slice, unsigned int top_bits = Cell::max_bits) {
    vm::CellBuilder cb;
    TRY_STATUS(store(cb, slice, top_bits));
    return cb.finalize();
  }

 private:
  template <class F>
  static void for_each(F &&f, CellSlice cs);
  static td::Ref<vm::Cell> do_store(td::BitSlice slice);
};

}  // namespace vm
