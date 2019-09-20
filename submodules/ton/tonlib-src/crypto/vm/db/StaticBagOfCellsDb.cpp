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
#include "vm/db/StaticBagOfCellsDb.h"

#include "vm/cells/CellWithStorage.h"
#include "vm/boc.h"

#include "vm/cells/ExtCell.h"

#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/misc.h"
#include "td/utils/port/RwMutex.h"
#include "td/utils/ConcurrentHashTable.h"

#include <limits>

namespace vm {
//
// Common interface
//
template <class ExtraT>
class RootCell : public Cell {
  struct PrivateTag {};

 public:
  td::Result<LoadedCell> load_cell() const override {
    return cell_->load_cell();
  }
  Ref<Cell> virtualize(VirtualizationParameters virt) const override {
    return cell_->virtualize(virt);
  }
  td::uint32 get_virtualization() const override {
    return cell_->get_virtualization();
  }
  CellUsageTree::NodePtr get_tree_node() const override {
    return cell_->get_tree_node();
  }
  bool is_loaded() const override {
    return cell_->is_loaded();
  }

  // hash and level
  LevelMask get_level_mask() const override {
    return cell_->get_level_mask();
  }

  template <class T>
  static Ref<Cell> create(Ref<Cell> cell, T&& extra) {
    return Ref<RootCell>(true, std::move(cell), std::forward<T>(extra), PrivateTag{});
  }
  template <class T>
  RootCell(Ref<Cell> cell, T&& extra, PrivateTag) : cell_(std::move(cell)), extra_(std::forward<T>(extra)) {
  }

 private:
  Ref<Cell> cell_;
  ExtraT extra_;
  td::uint16 do_get_depth(td::uint32 level) const override {
    return cell_->get_depth(level);
  }
  const Hash do_get_hash(td::uint32 level) const override {
    return cell_->get_hash(level);
  }
};

class DataCellCacheNoop {
 public:
  Ref<DataCell> store(int idx, Ref<DataCell> cell) {
    return cell;
  }
  Ref<DataCell> load(int idx) {
    return {};
  }
  void clear() {
  }
};
class DataCellCacheMutex {
 public:
  Ref<DataCell> store(int idx, Ref<DataCell> cell) {
    auto lock = cells_rw_mutex_.lock_write();
    return cells_.emplace(idx, std::move(cell)).first->second;
  }
  Ref<DataCell> load(int idx) {
    auto lock = cells_rw_mutex_.lock_read();
    auto it = cells_.find(idx);
    if (it != cells_.end()) {
      return it->second;
    }
    return {};
  }
  void clear() {
    auto guard = cells_rw_mutex_.lock_write();
    cells_.clear();
  }

 private:
  td::RwMutex cells_rw_mutex_;
  td::HashMap<int, Ref<DataCell>> cells_;
};

class DataCellCacheTdlib {
 public:
  Ref<DataCell> store(int idx, Ref<DataCell> cell) {
    return Ref<DataCell>(cells_.insert(as_key(idx), cell.get()));
  }
  Ref<DataCell> load(int idx) {
    return Ref<DataCell>(cells_.find(as_key(idx), nullptr));
  }

  void clear() {
    cells_.for_each([](auto key, auto value) { Ref<DataCell>{value}; });
  }

 private:
  td::ConcurrentHashMap<td::uint32, const DataCell*> cells_;
  td::uint32 as_key(int idx) {
    td::uint32 key = static_cast<td::uint32>(idx + 1);
    key *= 1000000007;
    return key;
  }
};

struct StaticBocExtCellExtra {
  int idx;
  std::weak_ptr<StaticBagOfCellsDb> deserializer;
};

class StaticBocLoader {
 public:
  static td::Result<Ref<DataCell>> load_data_cell(const Cell& cell, const StaticBocExtCellExtra& extra) {
    auto deserializer = extra.deserializer.lock();
    if (!deserializer) {
      return td::Status::Error("StaticBocDb is already destroyed, cannot fetch cell");
    }
    return deserializer->load_by_idx(extra.idx);
  }
};
using StaticBocExtCell = ExtCell<StaticBocExtCellExtra, StaticBocLoader>;
using StaticBocRootCell = RootCell<std::shared_ptr<StaticBagOfCellsDb>>;

td::Result<Ref<Cell>> StaticBagOfCellsDb::create_ext_cell(Cell::LevelMask level_mask, td::Slice hash, td::Slice depth,
                                                          int idx) {
  TRY_RESULT(res, StaticBocExtCell::create(PrunnedCellInfo{level_mask, hash, depth},
                                           StaticBocExtCellExtra{idx, shared_from_this()}));
  return std::move(res);
}

//
// Baseline implementation
//
class StaticBagOfCellsDbBaselineImpl : public StaticBagOfCellsDb {
 public:
  StaticBagOfCellsDbBaselineImpl(std::vector<Ref<Cell>> roots) : roots_(std::move(roots)) {
  }
  td::Result<size_t> get_root_count() override {
    return roots_.size();
  };
  td::Result<Ref<Cell>> get_root_cell(size_t idx) override {
    if (idx >= roots_.size()) {
      return td::Status::Error(PSLICE() << "invalid root_cell index: " << idx);
    }
    return roots_[idx];
  };

 private:
  std::vector<Ref<Cell>> roots_;

  td::Result<Ref<DataCell>> load_by_idx(int idx) override {
    UNREACHABLE();
  }
};

td::Result<std::shared_ptr<StaticBagOfCellsDb>> StaticBagOfCellsDbBaseline::create(std::unique_ptr<BlobView> data) {
  std::string buf(data->size(), '\0');
  TRY_RESULT(slice, data->view(buf, 0));
  return create(slice);
}

td::Result<std::shared_ptr<StaticBagOfCellsDb>> StaticBagOfCellsDbBaseline::create(td::Slice data) {
  BagOfCells boc;
  TRY_RESULT(x, boc.deserialize(data));
  if (x <= 0) {
    return td::Status::Error("failed to deserialize");
  }
  std::vector<Ref<Cell>> roots(boc.get_root_count());
  for (int i = 0; i < boc.get_root_count(); i++) {
    roots[i] = boc.get_root_cell(i);
  }
  return std::make_shared<StaticBagOfCellsDbBaselineImpl>(std::move(roots));
}

//
// Main implementation
//
class StaticBagOfCellsDbLazyImpl : public StaticBagOfCellsDb {
 public:
  explicit StaticBagOfCellsDbLazyImpl(std::unique_ptr<BlobView> data, StaticBagOfCellsDbLazy::Options options)
      : data_(std::move(data)), options_(std::move(options)) {
    get_thread_safe_counter().add(1);
  }
  td::Result<size_t> get_root_count() override {
    TRY_STATUS(check_status());
    TRY_STATUS(check_result(load_header()));
    return info_.root_count;
  };
  td::Result<Ref<Cell>> get_root_cell(size_t idx) override {
    TRY_STATUS(check_status());
    TRY_RESULT(root_count, get_root_count());
    if (idx >= root_count) {
      return td::Status::Error(PSLICE() << "invalid root_cell index: " << idx);
    }
    TRY_RESULT(cell_idx, load_root_idx(td::narrow_cast<int>(idx)));
    // Load DataCell in order to ensure lower hashes correctness
    // They will be valid for all non-root cell automaically
    TRY_RESULT(data_cell, check_result(load_data_cell(td::narrow_cast<int>(cell_idx))));
    return create_root_cell(std::move(data_cell));
  };

  ~StaticBagOfCellsDbLazyImpl() {
    //LOG(ERROR) << deserialize_cell_cnt_ << " " << deserialize_cell_hash_cnt_;
    get_thread_safe_counter().add(-1);
  }

 private:
  std::atomic<bool> should_cache_cells_{true};
  std::unique_ptr<BlobView> data_;
  StaticBagOfCellsDbLazy::Options options_;
  bool has_info_{false};
  BagOfCells::Info info_;

  std::mutex index_i_mutex_;
  td::RwMutex index_data_rw_mutex_;
  std::string index_data_;
  std::atomic<int> index_i_{0};
  size_t index_offset_{0};
  DataCellCacheMutex cells_;
  //DataCellCacheNoop cells_;
  //DataCellCacheTdlib cells_;
  int next_idx_{0};
  Ref<Cell> empty_cell_;

  //stats
  td::ThreadSafeCounter deserialize_cell_cnt_;
  td::ThreadSafeCounter deserialize_cell_hash_cnt_;

  std::atomic<bool> has_error_{false};
  std::mutex status_mutex_;
  td::Status status_;

  static td::NamedThreadSafeCounter::CounterRef get_thread_safe_counter() {
    static auto res = td::NamedThreadSafeCounter::get_default().get_counter("StaticBagOfCellsDbLazy");
    return res;
  }

  td::Status check_status() TD_WARN_UNUSED_RESULT {
    if (has_error_.load(std::memory_order_relaxed)) {
      std::lock_guard<std::mutex> guard(status_mutex_);
      return status_.clone();
    }
    return td::Status::OK();
  }
  template <class T>
  T check_result(T&& to_check) {
    CHECK(status_.is_ok());
    if (to_check.is_error()) {
      std::lock_guard<std::mutex> guard(status_mutex_);
      has_error_.store(true);
      status_ = to_check.error().clone();
    }
    return std::forward<T>(to_check);
  }

  td::Result<Ref<DataCell>> load_by_idx(int idx) override {
    TRY_STATUS(check_status());
    return check_result(load_data_cell(idx));
  }

  struct Ptr {
    td::MutableSlice as_slice() {
      return data;
    }
    td::string data;
  };
  // May be optimized
  auto alloc(size_t size) {
    //return td::StackAllocator::alloc(size);
    return Ptr{std::string(size, '\0')};
  }

  td::Result<size_t> load_idx_offset(int idx) {
    if (idx < 0) {
      return 0;
    }
    td::Slice offset_view;
    CHECK(info_.offset_byte_size <= 8);
    char arr[8];
    td::RwMutex::ReadLock guard;
    if (info_.has_index) {
      TRY_RESULT(new_offset_view, data_->view(td::MutableSlice(arr, info_.offset_byte_size),
                                              info_.index_offset + idx * info_.offset_byte_size));
      offset_view = new_offset_view;
    } else {
      guard = index_data_rw_mutex_.lock_read().move_as_ok();
      offset_view = td::Slice(index_data_).substr(idx * info_.offset_byte_size, info_.offset_byte_size);
    }

    CHECK(offset_view.size() == (size_t)info_.offset_byte_size);
    return td::narrow_cast<std::size_t>(info_.read_offset(offset_view.ubegin()));
  }

  td::Result<td::int64> load_root_idx(int root_i) {
    CHECK(root_i >= 0 && root_i < info_.root_count);
    if (!info_.has_roots) {
      return 0;
    }
    char arr[8];
    TRY_RESULT(idx_view, data_->view(td::MutableSlice(arr, info_.ref_byte_size),
                                     info_.roots_offset + root_i * info_.ref_byte_size));
    CHECK(idx_view.size() == (size_t)info_.ref_byte_size);
    return info_.read_ref(idx_view.ubegin());
  }

  struct CellLocation {
    std::size_t begin;
    std::size_t end;
    bool should_cache;
  };
  td::Result<CellLocation> get_cell_location(int idx) {
    CHECK(idx >= 0);
    CHECK(idx < info_.cell_count);
    TRY_STATUS(preload_index(idx));
    TRY_RESULT(from, load_idx_offset(idx - 1));
    TRY_RESULT(till, load_idx_offset(idx));
    CellLocation res;
    res.begin = from;
    res.end = till;
    res.should_cache = true;
    if (info_.has_cache_bits) {
      res.begin /= 2;
      res.should_cache = res.end % 2 == 1;
      res.end /= 2;
    }
    CHECK(std::numeric_limits<std::size_t>::max() - res.begin >= info_.data_offset);
    CHECK(std::numeric_limits<std::size_t>::max() - res.end >= info_.data_offset);
    res.begin += static_cast<std::size_t>(info_.data_offset);
    res.end += static_cast<std::size_t>(info_.data_offset);
    return res;
  }

  td::Status load_header() {
    if (has_info_) {
      return td::Status::OK();
    }
    std::string header(1000, '\0');
    TRY_RESULT(header_view, data_->view(td::MutableSlice(header).truncate(data_->size()), 0))
    auto parse_res = info_.parse_serialized_header(header_view);
    if (parse_res <= 0) {
      return td::Status::Error("bag-of-cell error: failed to read header");
    }
    if (info_.total_size < data_->size()) {
      return td::Status::Error("bag-of-cell error: not enough data");
    }
    if (options_.check_crc32c && info_.has_crc32c) {
      std::string buf(td::narrow_cast<std::size_t>(info_.total_size), '\0');
      TRY_RESULT(data, data_->view(td::MutableSlice(buf), 0));
      unsigned crc_computed = td::crc32c(td::Slice{data.ubegin(), data.uend() - 4});
      unsigned crc_stored = td::as<unsigned>(data.uend() - 4);
      if (crc_computed != crc_stored) {
        return td::Status::Error(PSLICE()
                                 << "bag-of-cells CRC32C mismatch: expected " << td::format::as_hex(crc_computed)
                                 << ", found " << td::format::as_hex(crc_stored));
      }
    }
    has_info_ = true;
    return td::Status::OK();
  }

  td::Status preload_index(int idx) {
    if (info_.has_index) {
      return td::Status::OK();
    }

    CHECK(idx < info_.cell_count);
    if (index_i_.load(std::memory_order_relaxed) > idx) {
      return td::Status::OK();
    }

    std::lock_guard<std::mutex> index_i_guard(index_i_mutex_);
    std::array<char, 1024> buf;
    auto buf_slice = td::MutableSlice(buf.data(), buf.size());
    for (; index_i_ <= idx; index_i_++) {
      auto offset = td::narrow_cast<size_t>(info_.data_offset + index_offset_);
      CHECK(data_->size() >= offset);
      TRY_RESULT(cell, data_->view(buf_slice.copy().truncate(data_->size() - offset), offset));
      CellSerializationInfo cell_info;
      TRY_STATUS(cell_info.init(cell, info_.ref_byte_size));
      index_offset_ += cell_info.end_offset;
      LOG_CHECK((unsigned)info_.offset_byte_size <= 8) << info_.offset_byte_size;
      td::uint8 tmp[8];
      info_.write_offset(tmp, index_offset_);
      auto guard = index_data_rw_mutex_.lock_write();
      index_data_.append(reinterpret_cast<const char*>(tmp), info_.offset_byte_size);
    }
    return td::Status::OK();
  }

  Ref<Cell> get_any_cell(int idx) {
    return get_data_cell(idx);
  }

  Ref<DataCell> get_data_cell(int idx) {
    return cells_.load(idx);
  }

  Ref<DataCell> set_data_cell(int idx, Ref<DataCell> cell) {
    if (/*idx >= info_.root_count || */ !should_cache_cells_.load(std::memory_order_relaxed)) {
      return cell;
    }
    CHECK(cell.not_null());
    return cells_.store(idx, std::move(cell));
  }

  Ref<Cell> set_any_cell(int idx, Ref<Cell> cell) {
    auto data_cell = Ref<DataCell>(cell);
    if (data_cell.is_null()) {
      return cell;
    }
    return set_data_cell(idx, std::move(data_cell));
  }

  td::Result<Ref<Cell>> load_any_cell(int idx) {
    {
      auto cell = get_any_cell(idx);
      if (cell.not_null()) {
        return std::move(cell);
      }
    }

    TRY_RESULT(cell_location, get_cell_location(idx));
    auto buf = alloc(cell_location.end - cell_location.begin);
    TRY_RESULT(cell_slice, data_->view(buf.as_slice(), cell_location.begin));
    TRY_RESULT(res, deserialize_any_cell(idx, cell_slice, cell_location.should_cache));
    return std::move(res);
  }

  td::Result<Ref<DataCell>> load_data_cell(int idx) {
    {
      auto cell = get_data_cell(idx);
      if (cell.not_null()) {
        return std::move(cell);
      }
    }

    TRY_RESULT(cell_location, get_cell_location(idx));
    auto buf = alloc(cell_location.end - cell_location.begin);
    TRY_RESULT(cell_slice, data_->view(buf.as_slice(), cell_location.begin));
    TRY_RESULT(res, deserialize_data_cell(idx, cell_slice, cell_location.should_cache));
    return std::move(res);
  }

  td::Result<Ref<DataCell>> deserialize_data_cell(int idx, td::Slice cell_slice, bool should_cache) {
    CellSerializationInfo cell_info;
    TRY_STATUS(cell_info.init(cell_slice, info_.ref_byte_size));
    if (cell_slice.size() != cell_info.end_offset) {
      return td::Status::Error(PSLICE() << "unused space in cell #" << idx << " serialization");
    }
    return deserialize_data_cell(idx, cell_slice, cell_info, should_cache);
  }

  td::Result<Ref<DataCell>> deserialize_data_cell(int idx, td::Slice cell_slice, const CellSerializationInfo& cell_info,
                                                  bool should_cache) {
    deserialize_cell_cnt_.add(1);
    Ref<Cell> refs[4];
    CHECK(cell_info.refs_cnt <= 4);
    auto* ref_ptr = cell_slice.ubegin() + cell_info.refs_offset;
    for (int k = 0; k < cell_info.refs_cnt; k++, ref_ptr += info_.ref_byte_size) {
      int ref_idx = td::narrow_cast<int>(info_.read_ref(ref_ptr));
      if (ref_idx >= info_.cell_count) {
        return td::Status::Error(PSLICE() << "invalid bag-of-cells cell #" << idx << " refers to cell #" << ref_idx
                                          << " which is too big " << td::tag("cell_count", info_.cell_count));
      }
      if (idx >= ref_idx) {
        return td::Status::Error(PSLICE() << "invalid bag-of-cells cell #" << idx << " refers to cell #" << ref_idx
                                          << " which is a backward reference");
      }
      TRY_RESULT(ref, load_any_cell(ref_idx));
      refs[k] = std::move(ref);
    }

    TRY_RESULT(data_cell, cell_info.create_data_cell(cell_slice, td::Span<Ref<Cell>>(refs, cell_info.refs_cnt)));
    if (!should_cache) {
      return std::move(data_cell);
    }
    return set_data_cell(idx, std::move(data_cell));
  }

  td::Result<Ref<Cell>> deserialize_any_cell(int idx, td::Slice cell_slice, bool should_cache) {
    CellSerializationInfo cell_info;
    TRY_STATUS(cell_info.init(cell_slice, info_.ref_byte_size));
    if (cell_info.with_hashes) {
      deserialize_cell_hash_cnt_.add(1);
      int n = cell_info.level_mask.get_hashes_count();
      return create_ext_cell(cell_info.level_mask, cell_slice.substr(cell_info.hashes_offset, n * Cell::hash_bytes),
                             cell_slice.substr(cell_info.depth_offset, n * Cell::depth_bytes), idx);
    }
    TRY_RESULT(data_cell, deserialize_data_cell(idx, cell_slice, cell_info, should_cache));
    return std::move(data_cell);
  }
  td::Result<Ref<Cell>> create_root_cell(Ref<DataCell> data_cell) {
    return StaticBocRootCell::create(std::move(data_cell), shared_from_this());
  }
};

td::Result<std::shared_ptr<StaticBagOfCellsDb>> StaticBagOfCellsDbLazy::create(std::unique_ptr<BlobView> data,
                                                                               Options options) {
  return std::make_shared<StaticBagOfCellsDbLazyImpl>(std::move(data), std::move(options));
}

td::Result<std::shared_ptr<StaticBagOfCellsDb>> StaticBagOfCellsDbLazy::create(td::BufferSlice data, Options options) {
  return std::make_shared<StaticBagOfCellsDbLazyImpl>(vm::BufferSliceBlobView::create(std::move(data)),
                                                      std::move(options));
}

td::Result<std::shared_ptr<StaticBagOfCellsDb>> StaticBagOfCellsDbLazy::create(std::string data, Options options) {
  return create(BufferSliceBlobView::create(td::BufferSlice(data)), std::move(options));
}

}  // namespace vm
