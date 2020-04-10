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
#include "vm/cells/Cell.h"
#include "vm/cells/PrunnedCell.h"
#include "common/AtomicRef.h"

#include <mutex>
#include "td/utils/port/thread_local.h"
#include "td/utils/HazardPointers.h"
#include "td/utils/optional.h"

namespace vm {

template <class ExtraT, class Loader>
class ExtCell : public Cell {
 private:
  struct PrivateTag {};

 public:
  static td::Result<Ref<ExtCell<ExtraT, Loader>>> create(const PrunnedCellInfo& prunned_cell_info, ExtraT&& extra) {
    TRY_RESULT(prunned_cell, PrunnedCell<ExtraT>::create(prunned_cell_info, std::move(extra)));
    return Ref<ExtCell<ExtraT, Loader>>(true, std::move(prunned_cell), PrivateTag{});
  }

  ExtCell(Ref<PrunnedCell<ExtraT>> prunned_cell, PrivateTag) : prunned_cell_(std::move(prunned_cell)) {
    get_thread_safe_counter().add(1);
    get_thread_safe_counter_unloaded().add(prunned_cell_.load_unsafe().not_null());
  }
  ~ExtCell() {
    get_thread_safe_counter().add(-1);
    get_thread_safe_counter_unloaded().add(-static_cast<int>(prunned_cell_.load_unsafe().not_null()));
  }

  LevelMask get_level_mask() const override {
    return CellView(this)->get_level_mask();
  }

  td::Result<LoadedCell> load_cell() const override {
    TRY_RESULT(data_cell, load_data_cell());
    return LoadedCell{std::move(data_cell), {}, {}};
  }
  td::uint32 get_virtualization() const override {
    return 0;
  }
  CellUsageTree::NodePtr get_tree_node() const override {
    return {};
  }
  bool is_loaded() const override {
    return CellView(this)->is_loaded();
  }

 private:
  mutable td::AtomicRef<DataCell> data_cell_;
  mutable td::AtomicRef<PrunnedCell<ExtraT>> prunned_cell_;

  static td::NamedThreadSafeCounter::CounterRef get_thread_safe_counter() {
    static auto res = td::NamedThreadSafeCounter::get_default().get_counter("ExtCell");
    return res;
  }

  static td::NamedThreadSafeCounter::CounterRef get_thread_safe_counter_unloaded() {
    static auto res = td::NamedThreadSafeCounter::get_default().get_counter("ExtCell.unloaded");
    return res;
  }

  struct CellView {
    CellView(const ExtCell<ExtraT, Loader>* cell) {
      cell_ = cell->data_cell_.get_unsafe();
      if (cell_) {
        return;
      }

      prunned_cell_ = cell->prunned_cell_.load();
      if (!prunned_cell_.is_null()) {
        cell_ = &*prunned_cell_;
        return;
      }
      cell_ = cell->data_cell_.get_unsafe();
      DCHECK(cell_);
    }

    const Cell* operator->() const {
      return cell_;
    }

    td::Ref<PrunnedCell<ExtraT>> prunned_cell_;
    const Cell* cell_;
  };

  const Hash do_get_hash(td::uint32 level) const override {
    return CellView(this)->get_hash(level);
  }

  td::uint16 do_get_depth(td::uint32 level) const override {
    return CellView(this)->get_depth(level);
  }

  td::Result<Ref<DataCell>> load_data_cell() const {
    auto data_cell = data_cell_.get_unsafe();
    if (data_cell) {
      return Ref<DataCell>(data_cell);
    }

    auto prunned_cell = prunned_cell_.load();

    if (prunned_cell.is_null()) {
      data_cell = data_cell_.get_unsafe();
      DCHECK(data_cell);
      return Ref<DataCell>(data_cell);
    }

    TRY_RESULT(new_data_cell, Loader::load_data_cell(*this, prunned_cell->get_extra()));
    TRY_STATUS(prunned_cell->check_equals_unloaded(new_data_cell));

    if (data_cell_.store_if_empty(new_data_cell)) {
      prunned_cell_.store({});
      get_thread_safe_counter_unloaded().add(-1);
    }

    return data_cell_.load_unsafe();
  }
};
}  // namespace vm
