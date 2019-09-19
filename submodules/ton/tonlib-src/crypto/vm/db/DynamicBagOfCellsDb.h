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
#pragma once
#include "vm/cells.h"

#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace vm {
class CellLoader;
class CellStorer;
}  // namespace vm

namespace vm {
class ExtCellCreator {
 public:
  virtual ~ExtCellCreator() = default;
  virtual td::Result<Ref<Cell>> ext_cell(Cell::LevelMask level_mask, td::Slice hash, td::Slice depth) = 0;
};

class DynamicBagOfCellsDb {
 public:
  virtual ~DynamicBagOfCellsDb() = default;
  virtual td::Result<Ref<DataCell>> load_cell(td::Slice hash) = 0;
  struct Stats {
    td::int64 cells_total_count{0};
    td::int64 cells_total_size{0};
    void apply_diff(Stats diff) {
      cells_total_count += diff.cells_total_count;
      cells_total_size += diff.cells_total_size;
    }
  };
  virtual void inc(const Ref<Cell> &old_root) = 0;
  virtual void dec(const Ref<Cell> &old_root) = 0;

  virtual td::Status prepare_commit() = 0;
  virtual Stats get_stats_diff() = 0;
  virtual td::Status commit(CellStorer &) = 0;

  // restart with new loader will also reset stats_diff
  virtual td::Status set_loader(std::unique_ptr<CellLoader> loader) = 0;

  static std::unique_ptr<DynamicBagOfCellsDb> create();
};

}  // namespace vm
