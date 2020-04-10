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
#include "vm/cells/Cell.h"
#include "vm/cells/VirtualCell.h"
#include "vm/cells/DataCell.h"

#include <iostream>

namespace vm {
td::Status Cell::check_equals_unloaded(const Ref<Cell>& other) const {
  auto level_mask = get_level_mask();
  if (level_mask != other->get_level_mask()) {
    return td::Status::Error("level mismatch");
  }
  auto level = level_mask.get_level();
  for (unsigned i = 0; i <= level; i++) {
    if (!get_level_mask().is_significant(i)) {
      continue;
    }
    if (get_hash(i) != other->get_hash(i)) {
      return td::Status::Error("hash mismatch");
    }
  }
  for (unsigned i = 0; i <= level; i++) {
    if (!get_level_mask().is_significant(i)) {
      continue;
    }
    if (get_depth(i) != other->get_depth(i)) {
      return td::Status::Error("depth mismatch");
    }
  }
  return td::Status::OK();
}

Ref<Cell> Cell::virtualize(VirtualizationParameters virt) const {
  return VirtualCell::create(virt, Ref<Cell>(this));
}

std::ostream& operator<<(std::ostream& os, const Cell& c) {
  return os << c.get_hash().to_hex();
}

}  // namespace vm
