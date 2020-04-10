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
#include "vm/db/DynamicBagOfCellsDb.h"
#include "vm/db/CellStorage.h"
#include "vm/db/CellHashTable.h"

#include "vm/cells/ExtCell.h"

#include "td/utils/base64.h"
#include "td/utils/format.h"
#include "td/utils/ThreadSafeCounter.h"

#include "vm/cellslice.h"

namespace vm {
namespace {

class CellDbReader {
 public:
  virtual ~CellDbReader() = default;
  virtual td::Result<Ref<DataCell>> load_cell(td::Slice hash) = 0;
};

struct DynamicBocExtCellExtra {
  std::shared_ptr<CellDbReader> reader;
};

class DynamicBocCellLoader {
 public:
  static td::Result<Ref<DataCell>> load_data_cell(const Cell &cell, const DynamicBocExtCellExtra &extra) {
    return extra.reader->load_cell(cell.get_hash().as_slice());
  }
};

using DynamicBocExtCell = ExtCell<DynamicBocExtCellExtra, DynamicBocCellLoader>;

struct CellInfo {
  bool sync_with_db{false};
  bool in_db{false};

  bool was_dfs_new_cells{false};
  bool was{false};

  td::int32 db_refcnt{0};
  td::int32 refcnt_diff{0};
  Ref<Cell> cell;
  Cell::Hash key() const {
    return cell->get_hash();
  }
  bool operator<(const CellInfo &other) const {
    return key() < other.key();
  }
};

bool operator<(const CellInfo &a, td::Slice b) {
  return a.key().as_slice() < b;
}

bool operator<(td::Slice a, const CellInfo &b) {
  return a < b.key().as_slice();
}

class DynamicBagOfCellsDbImpl : public DynamicBagOfCellsDb, private ExtCellCreator {
 public:
  DynamicBagOfCellsDbImpl() {
    get_thread_safe_counter().add(1);
  }
  ~DynamicBagOfCellsDbImpl() {
    get_thread_safe_counter().add(-1);
    reset_cell_db_reader();
  }
  td::Result<Ref<Cell>> ext_cell(Cell::LevelMask level_mask, td::Slice hash, td::Slice depth) override {
    return get_cell_info_lazy(level_mask, hash, depth).cell;
  }
  td::Result<Ref<DataCell>> load_cell(td::Slice hash) override {
    TRY_RESULT(loaded_cell, get_cell_info_force(hash).cell->load_cell());
    return std::move(loaded_cell.data_cell);
  }
  CellInfo &get_cell_info_force(td::Slice hash) {
    return hash_table_.apply(hash, [&](CellInfo &info) { update_cell_info_force(info, hash); });
  }
  CellInfo &get_cell_info_lazy(Cell::LevelMask level_mask, td::Slice hash, td::Slice depth) {
    return hash_table_.apply(hash.substr(hash.size() - Cell::hash_bytes),
                             [&](CellInfo &info) { update_cell_info_lazy(info, level_mask, hash, depth); });
  }
  CellInfo &get_cell_info(const Ref<Cell> &cell) {
    return hash_table_.apply(cell->get_hash().as_slice(), [&](CellInfo &info) { update_cell_info(info, cell); });
  }

  void inc(const Ref<Cell> &cell) override {
    if (cell.is_null()) {
      return;
    }
    if (cell->get_virtualization() != 0) {
      return;
    }
    //LOG(ERROR) << "INC";
    //CellSlice(cell, nullptr).print_rec(std::cout);
    to_inc_.push_back(cell);
  }
  void dec(const Ref<Cell> &cell) override {
    if (cell.is_null()) {
      return;
    }
    if (cell->get_virtualization() != 0) {
      return;
    }
    //LOG(ERROR) << "DEC";
    //CellSlice(cell, nullptr).print_rec(std::cout);
    to_dec_.push_back(cell);
  }

  bool is_prepared_for_commit() {
    return to_inc_.empty() && to_dec_.empty();
  }

  Stats get_stats_diff() override {
    CHECK(is_prepared_for_commit());
    return stats_diff_;
  }

  td::Status prepare_commit() override {
    if (is_prepared_for_commit()) {
      return td::Status::OK();
    }
    //LOG(ERROR) << "dfs_new_cells_in_db";
    for (auto &new_cell : to_inc_) {
      auto &new_cell_info = get_cell_info(new_cell);
      dfs_new_cells_in_db(new_cell_info);
    }
    //return td::Status::OK();
    //LOG(ERROR) << "dfs_new_cells";
    for (auto &new_cell : to_inc_) {
      auto &new_cell_info = get_cell_info(new_cell);
      dfs_new_cells(new_cell_info);
    }

    //LOG(ERROR) << "dfs_old_cells";
    for (auto &old_cell : to_dec_) {
      auto &old_cell_info = get_cell_info(old_cell);
      dfs_old_cells(old_cell_info);
    }

    //LOG(ERROR) << "save_diff_prepare";
    save_diff_prepare();

    to_inc_.clear();
    to_dec_.clear();

    return td::Status::OK();
  }

  td::Status commit(CellStorer &storer) override {
    prepare_commit();
    save_diff(storer);
    // Some elements are erased from hash table, to keep it small.
    // Hash table is no longer represents the difference between the loader and
    // the current bag of cells.
    reset_cell_db_reader();
    return td::Status::OK();
  }

  td::Status set_loader(std::unique_ptr<CellLoader> loader) override {
    reset_cell_db_reader();
    loader_ = std::move(loader);
    //cell_db_reader_ = std::make_shared<CellDbReaderImpl>(this);
    // Temporary(?) fix to make ExtCell thread safe.
    // Downside(?) - loaded cells won't be cached
    cell_db_reader_ = std::make_shared<CellDbReaderImpl>(std::make_unique<CellLoader>(*loader_));
    stats_diff_ = {};
    return td::Status::OK();
  }

 private:
  std::unique_ptr<CellLoader> loader_;
  std::vector<Ref<Cell>> to_inc_;
  std::vector<Ref<Cell>> to_dec_;
  CellHashTable<CellInfo> hash_table_;
  std::vector<CellInfo *> visited_;
  Stats stats_diff_;

  static td::NamedThreadSafeCounter::CounterRef get_thread_safe_counter() {
    static auto res = td::NamedThreadSafeCounter::get_default().get_counter("DynamicBagOfCellsDb");
    return res;
  }

  class CellDbReaderImpl : public CellDbReader,
                           private ExtCellCreator,
                           public std::enable_shared_from_this<CellDbReaderImpl> {
   public:
    CellDbReaderImpl(std::unique_ptr<CellLoader> cell_loader) : db_(nullptr), cell_loader_(std::move(cell_loader)) {
      if (cell_loader_) {
        get_thread_safe_counter().add(1);
      }
    }
    CellDbReaderImpl(DynamicBagOfCellsDb *db) : db_(db) {
    }
    ~CellDbReaderImpl() {
      if (cell_loader_) {
        get_thread_safe_counter().add(-1);
      }
    }
    void set_loader(std::unique_ptr<CellLoader> cell_loader) {
      if (cell_loader_) {
        // avoid race
        return;
      }
      cell_loader_ = std::move(cell_loader);
      db_ = nullptr;
      if (cell_loader_) {
        get_thread_safe_counter().add(1);
      }
    }

    td::Result<Ref<Cell>> ext_cell(Cell::LevelMask level_mask, td::Slice hash, td::Slice depth) override {
      CHECK(!db_);
      TRY_RESULT(ext_cell, DynamicBocExtCell::create(PrunnedCellInfo{level_mask, hash, depth},
                                                     DynamicBocExtCellExtra{shared_from_this()}));
      return std::move(ext_cell);
    }

    td::Result<Ref<DataCell>> load_cell(td::Slice hash) override {
      if (db_) {
        return db_->load_cell(hash);
      }
      TRY_RESULT(load_result, cell_loader_->load(hash, true, *this));
      CHECK(load_result.status == CellLoader::LoadResult::Ok);
      return std::move(load_result.cell());
    }

   private:
    static td::NamedThreadSafeCounter::CounterRef get_thread_safe_counter() {
      static auto res = td::NamedThreadSafeCounter::get_default().get_counter("DynamicBagOfCellsDbLoader");
      return res;
    }
    DynamicBagOfCellsDb *db_;
    std::unique_ptr<CellLoader> cell_loader_;
  };

  std::shared_ptr<CellDbReaderImpl> cell_db_reader_;

  void reset_cell_db_reader() {
    if (!cell_db_reader_) {
      return;
    }
    cell_db_reader_->set_loader(std::move(loader_));
    cell_db_reader_.reset();
    //EXPERIMENTAL: clear cache to drop all references to old reader.
    hash_table_ = {};
  }

  bool is_in_db(CellInfo &info) {
    if (info.in_db) {
      return true;
    }
    load_cell(info);
    return info.in_db;
  }
  bool is_loaded(CellInfo &info) {
    return info.sync_with_db;
  }

  void load_cell(CellInfo &info) {
    if (is_loaded(info)) {
      return;
    }
    do_load_cell(info);
  }

  bool dfs_new_cells_in_db(CellInfo &info) {
    if (info.sync_with_db) {
      return is_in_db(info);
    }
    if (info.in_db) {
      return true;
    }

    bool not_in_db = false;
    for_each(
        info, [&not_in_db, this](auto &child_info) { not_in_db |= !dfs_new_cells_in_db(child_info); }, false);

    if (not_in_db) {
      CHECK(!info.in_db);
      info.sync_with_db = true;
    }
    return is_in_db(info);
  }

  void dfs_new_cells(CellInfo &info) {
    info.refcnt_diff++;
    if (!info.was) {
      info.was = true;
      visited_.push_back(&info);
    }
    //LOG(ERROR) << "dfs new " << td::format::escaped(info.cell->hash());

    if (info.was_dfs_new_cells) {
      return;
    }
    info.was_dfs_new_cells = true;

    if (is_in_db(info)) {
      return;
    }

    CHECK(is_loaded(info));
    for_each(info, [this](auto &child_info) { dfs_new_cells(child_info); });
  }

  void dfs_old_cells(CellInfo &info) {
    info.refcnt_diff--;
    if (!info.was) {
      info.was = true;
      visited_.push_back(&info);
    }
    //LOG(ERROR) << "dfs old " << td::format::escaped(info.cell->hash());

    load_cell(info);

    auto new_refcnt = info.refcnt_diff + info.db_refcnt;
    CHECK(new_refcnt >= 0);
    if (new_refcnt != 0) {
      return;
    }

    for_each(info, [this](auto &child_info) { dfs_old_cells(child_info); });
  }

  void save_diff_prepare() {
    stats_diff_ = {};
    for (auto info_ptr : visited_) {
      save_cell_prepare(*info_ptr);
    }
  }

  void save_diff(CellStorer &storer) {
    //LOG(ERROR) << hash_table_.size();
    for (auto info_ptr : visited_) {
      save_cell(*info_ptr, storer);
    }
    visited_.clear();
  }

  void save_cell_prepare(CellInfo &info) {
    if (info.refcnt_diff == 0) {
      //CellSlice(info.cell, nullptr).print_rec(std::cout);
      return;
    }
    load_cell(info);

    auto loaded_cell = info.cell->load_cell().move_as_ok();
    if (info.db_refcnt + info.refcnt_diff == 0) {
      CHECK(info.in_db);
      // erase
      stats_diff_.cells_total_count--;
      stats_diff_.cells_total_size -= loaded_cell.data_cell->get_serialized_size(true);
    } else {
      //save
      if (info.in_db == false) {
        stats_diff_.cells_total_count++;
        stats_diff_.cells_total_size += loaded_cell.data_cell->get_serialized_size(true);
      }
    }
  }

  void save_cell(CellInfo &info, CellStorer &storer) {
    auto guard = td::ScopeExit{} + [&] {
      info.was_dfs_new_cells = false;
      info.was = false;
    };
    if (info.refcnt_diff == 0) {
      //CellSlice(info.cell, nullptr).print_rec(std::cout);
      return;
    }
    CHECK(info.sync_with_db);

    info.db_refcnt += info.refcnt_diff;
    info.refcnt_diff = 0;

    if (info.db_refcnt == 0) {
      CHECK(info.in_db);
      //LOG(ERROR) << "ERASE";
      //CellSlice(NoVm(), info.cell).print_rec(std::cout);
      storer.erase(info.cell->get_hash().as_slice());
      info.in_db = false;
      hash_table_.erase(info.cell->get_hash().as_slice());
      guard.dismiss();
    } else {
      //LOG(ERROR) << "SAVE " << info.db_refcnt;
      //CellSlice(NoVm(), info.cell).print_rec(std::cout);
      auto loaded_cell = info.cell->load_cell().move_as_ok();
      storer.set(info.db_refcnt, *loaded_cell.data_cell);
      info.in_db = true;
    }
  }

  template <class F>
  void for_each(CellInfo &info, F &&f, bool force = true) {
    auto cell = info.cell;

    if (!cell->is_loaded()) {
      if (!force) {
        return;
      }
      load_cell(info);
      cell = info.cell;
    }
    if (!cell->is_loaded()) {
      cell->load_cell().ensure();
    }
    CHECK(cell->is_loaded());
    vm::CellSlice cs(vm::NoVm{}, cell);  // FIXME
    for (unsigned i = 0; i < cs.size_refs(); i++) {
      //LOG(ERROR) << "---> " << td::format::escaped(cell->ref(i)->hash());
      f(get_cell_info(cs.prefetch_ref(i)));
    }
  }

  void do_load_cell(CellInfo &info) {
    update_cell_info_force(info, info.cell->get_hash().as_slice());
  }

  void update_cell_info(CellInfo &info, const Ref<Cell> &cell) {
    CHECK(!cell.is_null());
    if (info.sync_with_db) {
      return;
    }
    info.cell = cell;
  }

  void update_cell_info_lazy(CellInfo &info, Cell::LevelMask level_mask, td::Slice hash, td::Slice depth) {
    if (info.sync_with_db) {
      CHECK(info.cell.not_null());
      CHECK(info.cell->get_level_mask() == level_mask);
      return;
    }
    if (info.cell.is_null()) {
      auto ext_cell_r = create_empty_ext_cell(level_mask, hash, depth);
      if (ext_cell_r.is_error()) {
        //FIXME
        LOG(ERROR) << "Failed to create ext_cell" << ext_cell_r.error();
        return;
      }
      info.cell = ext_cell_r.move_as_ok();
      info.in_db = true;  // TODO
    }
  }
  void update_cell_info_force(CellInfo &info, td::Slice hash) {
    if (info.sync_with_db) {
      return;
    }

    do {
      CHECK(loader_);
      auto r_res = loader_->load(hash, true, *this);
      if (r_res.is_error()) {
        //FIXME
        LOG(ERROR) << "Failed to load cell from db" << r_res.error();
        break;
      }
      auto res = r_res.move_as_ok();
      if (res.status != CellLoader::LoadResult::Ok) {
        break;
      }
      info.cell = std::move(res.cell());
      CHECK(info.cell->get_hash().as_slice() == hash);
      info.in_db = true;
      info.db_refcnt = res.refcnt();
    } while (false);
    info.sync_with_db = true;
  }

  td::Result<Ref<Cell>> create_empty_ext_cell(Cell::LevelMask level_mask, td::Slice hash, td::Slice depth) {
    TRY_RESULT(res, DynamicBocExtCell::create(PrunnedCellInfo{level_mask, hash, depth},
                                              DynamicBocExtCellExtra{cell_db_reader_}));
    return std::move(res);
  }
};
}  // namespace

std::unique_ptr<DynamicBagOfCellsDb> DynamicBagOfCellsDb::create() {
  return std::make_unique<DynamicBagOfCellsDbImpl>();
}
}  // namespace vm
