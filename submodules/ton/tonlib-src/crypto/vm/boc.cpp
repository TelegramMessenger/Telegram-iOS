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
#include <iostream>
#include <iomanip>
#include <algorithm>
#include "vm/boc.h"
#include "vm/cells.h"
#include "vm/cellslice.h"
#include "td/utils/bits.h"
#include "td/utils/Slice-decl.h"
#include "td/utils/format.h"
#include "td/utils/crypto.h"

namespace vm {
using td::Ref;

td::Status CellSerializationInfo::init(td::Slice data, int ref_byte_size) {
  if (data.size() < 2) {
    return td::Status::Error(PSLICE() << "Not enough bytes " << td::tag("got", data.size())
                                      << td::tag("expected", "at least 2"));
  }
  TRY_STATUS(init(data.ubegin()[0], data.ubegin()[1], ref_byte_size));
  if (data.size() < end_offset) {
    return td::Status::Error(PSLICE() << "Not enough bytes " << td::tag("got", data.size())
                                      << td::tag("expected", end_offset));
  }
  return td::Status::OK();
}

td::Status CellSerializationInfo::init(td::uint8 d1, td::uint8 d2, int ref_byte_size) {
  refs_cnt = d1 & 7;
  level_mask = Cell::LevelMask(d1 >> 5);
  special = (d1 & 8) != 0;
  with_hashes = (d1 & 16) != 0;

  if (refs_cnt > 4) {
    if (refs_cnt != 7 || !with_hashes) {
      return td::Status::Error("Invalid first byte");
    }
    refs_cnt = 0;
    // ...
    // do not deserialize absent cells!
    return td::Status::Error("TODO: absent cells");
  }

  hashes_offset = 2;
  auto n = level_mask.get_hashes_count();
  depth_offset = hashes_offset + (with_hashes ? n * Cell::hash_bytes : 0);
  data_offset = depth_offset + (with_hashes ? n * Cell::depth_bytes : 0);
  data_len = (d2 >> 1) + (d2 & 1);
  data_with_bits = (d2 & 1) != 0;
  refs_offset = data_offset + data_len;
  end_offset = refs_offset + refs_cnt * ref_byte_size;

  return td::Status::OK();
}

td::Result<int> CellSerializationInfo::get_bits(td::Slice cell) const {
  if (data_with_bits) {
    DCHECK(data_len != 0);
    int last = cell[data_offset + data_len - 1];
    if (!(last & 0x7f)) {
      return td::Status::Error("overlong encoding");
    }
    return td::narrow_cast<int>((data_len - 1) * 8 + 7 - td::count_trailing_zeroes_non_zero32(last));
  } else {
    return td::narrow_cast<int>(data_len * 8);
  }
}

// TODO: check usage when result is empty
td::Result<Ref<DataCell>> CellSerializationInfo::create_data_cell(td::Slice cell_slice,
                                                                  td::Span<Ref<Cell>> refs) const {
  CellBuilder cb;
  TRY_RESULT(bits, get_bits(cell_slice));
  cb.store_bits(cell_slice.ubegin() + data_offset, bits);
  DCHECK(refs_cnt == (td::int64)refs.size());
  for (int k = 0; k < refs_cnt; k++) {
    cb.store_ref(std::move(refs[k]));
  }
  TRY_RESULT(res, cb.finalize_novm_nothrow(special));
  CHECK(!res.is_null());
  if (res->is_special() != special) {
    return td::Status::Error("is_special mismatch");
  }
  if (res->get_level_mask() != level_mask) {
    return td::Status::Error("level mask mismatch");
  }
  //return res;
  if (with_hashes) {
    auto hash_n = level_mask.get_hashes_count();
    if (res->get_hash().as_slice() !=
        cell_slice.substr(hashes_offset + Cell::hash_bytes * (hash_n - 1), Cell::hash_bytes)) {
      return td::Status::Error("representation hash mismatch");
    }
    if (res->get_depth() !=
        DataCell::load_depth(
            cell_slice.substr(depth_offset + Cell::depth_bytes * (hash_n - 1), Cell::depth_bytes).ubegin())) {
      return td::Status::Error("depth mismatch");
    }

    bool check_all_hashes = true;
    for (unsigned level_i = 0, hash_i = 0, level = level_mask.get_level(); check_all_hashes && level_i < level;
         level_i++) {
      if (!level_mask.is_significant(level_i)) {
        continue;
      }
      if (cell_slice.substr(hashes_offset + Cell::hash_bytes * hash_i, Cell::hash_bytes) !=
          res->get_hash(level_i).as_slice()) {
        // hash mismatch
        return td::Status::Error("lower hash mismatch");
      }
      if (res->get_depth(level_i) !=
          DataCell::load_depth(
              cell_slice.substr(depth_offset + Cell::depth_bytes * hash_i, Cell::depth_bytes).ubegin())) {
        return td::Status::Error("lower depth mismatch");
      }
      hash_i++;
    }
  }
  return res;
}

void BagOfCells::clear() {
  cells_clear();
  roots.clear();
  root_count = 0;
  serialized.clear();
}

int BagOfCells::set_roots(const std::vector<td::Ref<vm::Cell>>& new_roots) {
  clear();
  return add_roots(new_roots);
}

int BagOfCells::set_root(td::Ref<vm::Cell> new_root) {
  clear();
  return add_root(std::move(new_root));
}

int BagOfCells::add_roots(const std::vector<td::Ref<vm::Cell>>& add_roots) {
  int res = 0;
  for (td::Ref<vm::Cell> root : add_roots) {
    res += add_root(std::move(root));
  }
  return res;
}

int BagOfCells::add_root(td::Ref<vm::Cell> add_root) {
  if (add_root.is_null()) {
    return 0;
  }
  LOG_CHECK(add_root->get_virtualization() == 0) << "TODO: support serialization of virtualized cells";
  //const Cell::Hash& hash = add_root->get_hash();
  //for (const auto& root_info : roots) {
  //if (root_info.cell->get_hash() == hash) {
  //return 0;
  //}
  //}
  roots.emplace_back(std::move(add_root), -1);
  ++root_count;
  cells_clear();
  return 1;
}

td::Status BagOfCells::import_cells() {
  cells_clear();
  for (auto& root : roots) {
    auto res = import_cell(root.cell, 0);
    if (res.is_error()) {
      return res.move_as_error();
    }
    root.idx = res.move_as_ok();
  }
  //LOG(INFO) << "[cells: " << cell_count << ", refs: " << int_refs << ", bytes: " << data_bytes << "]";
  reorder_cells();
  //LOG(INFO) << "[cells: " << cell_count << ", refs: " << int_refs << ", bytes: " << data_bytes
  //<< ", internal hashes: " << int_hashes << ", top hashes: " << top_hashes << "]";
  CHECK(cell_count != 0);
  return td::Status::OK();
}

td::Result<int> BagOfCells::import_cell(td::Ref<vm::Cell> cell, int depth) {
  if (depth > max_depth) {
    return td::Status::Error("error while importing a cell into a bag of cells: cell depth too large");
  }
  if (cell.is_null()) {
    return td::Status::Error("error while importing a cell into a bag of cells: cell is null");
  }
  auto it = cells.find(cell->get_hash());
  if (it != cells.end()) {
    auto pos = it->second;
    cell_list_[pos].should_cache = true;
    return pos;
  }
  if (cell->get_virtualization() != 0) {
    return td::Status::Error(
        "error while importing a cell into a bag of cells: cell has non-zero virtualization level");
  }
  auto r_loaded_dc = cell->load_cell();
  if (r_loaded_dc.is_error()) {
    return td::Status::Error("error while importing a cell into a bag of cells: " +
                             r_loaded_dc.move_as_error().to_string());
  }
  auto loaded_dc = r_loaded_dc.move_as_ok();
  CellSlice cs(std::move(loaded_dc));
  std::array<int, 4> refs{-1};
  DCHECK(cs.size_refs() <= 4);
  unsigned sum_child_wt = 1;
  for (unsigned i = 0; i < cs.size_refs(); i++) {
    auto ref = import_cell(cs.prefetch_ref(i), depth + 1);
    if (ref.is_error()) {
      return ref.move_as_error();
    }
    refs[i] = ref.move_as_ok();
    sum_child_wt += cell_list_[refs[i]].wt;
    ++int_refs;
  }
  DCHECK(cell_list_.size() == static_cast<std::size_t>(cell_count));
  auto dc = cs.move_as_loaded_cell().data_cell;
  auto res = cells.emplace(dc->get_hash(), cell_count);
  DCHECK(res.second);
  cell_list_.emplace_back(dc, dc->size_refs(), refs);
  CellInfo& dc_info = cell_list_.back();
  dc_info.hcnt = static_cast<unsigned char>(dc->get_level_mask().get_hashes_count());
  dc_info.wt = static_cast<unsigned char>(std::min(0xffU, sum_child_wt));
  dc_info.new_idx = -1;
  data_bytes += dc->get_serialized_size();
  return cell_count++;
}

void BagOfCells::reorder_cells() {
  int_hashes = 0;
  for (int i = cell_count - 1; i >= 0; --i) {
    CellInfo& dci = cell_list_[i];
    int s = dci.ref_num, c = s, sum = max_cell_whs - 1, mask = 0;
    for (int j = 0; j < s; ++j) {
      CellInfo& dcj = cell_list_[dci.ref_idx[j]];
      int limit = (max_cell_whs - 1 + j) / s;
      if (dcj.wt <= limit) {
        sum -= dcj.wt;
        --c;
        mask |= (1 << j);
      }
    }
    if (c) {
      for (int j = 0; j < s; ++j) {
        if (!(mask & (1 << j))) {
          CellInfo& dcj = cell_list_[dci.ref_idx[j]];
          int limit = sum++ / c;
          if (dcj.wt > limit) {
            dcj.wt = static_cast<unsigned char>(limit);
          }
        }
      }
    }
  }
  for (int i = 0; i < cell_count; i++) {
    CellInfo& dci = cell_list_[i];
    int s = dci.ref_num, sum = 1;
    for (int j = 0; j < s; ++j) {
      sum += cell_list_[dci.ref_idx[j]].wt;
    }
    DCHECK(sum <= max_cell_whs);
    if (sum <= dci.wt) {
      dci.wt = static_cast<unsigned char>(sum);
    } else {
      dci.wt = 0;
      int_hashes += dci.hcnt;
    }
  }
  top_hashes = 0;
  for (auto& root_info : roots) {
    auto& cell_info = cell_list_[root_info.idx];
    if (cell_info.is_root_cell) {
      cell_info.is_root_cell = true;
      if (cell_info.wt) {
        top_hashes += cell_info.hcnt;
      }
    }
  }
  if (cell_count > 0) {
    rv_idx = 0;
    cell_list_tmp.clear();
    cell_list_tmp.reserve(cell_count);

    for (const auto& root_info : roots) {
      revisit(root_info.idx, 0);
      revisit(root_info.idx, 1);
    }
    for (const auto& root_info : roots) {
      revisit(root_info.idx, 2);
    }
    for (auto& root_info : roots) {
      root_info.idx = cell_list_[root_info.idx].new_idx;
    }

    DCHECK(rv_idx == cell_count);
    //DCHECK(cell_list.back().new_idx == cell_count - 1);
    DCHECK(cell_list_.size() == cell_list_tmp.size());
    cell_list_ = std::move(cell_list_tmp);
    cell_list_tmp.clear();
  }
}

// force=0 : previsit (recursively until special cells are found; then visit them)
// force=1 : visit (allocate and process all children)
// force=2 : allocate (assign a new index; can be run only after visiting)
int BagOfCells::revisit(int cell_idx, int force) {
  DCHECK(cell_idx >= 0 && cell_idx < cell_count);
  CellInfo& dci = cell_list_[cell_idx];
  if (dci.new_idx >= 0) {
    return dci.new_idx;
  }
  if (!force) {
    // previsit
    if (dci.new_idx != -1) {
      // already previsited or visited
      return dci.new_idx;
    }
    int n = dci.ref_num;
    for (int j = n - 1; j >= 0; --j) {
      int child_idx = dci.ref_idx[j];
      // either previsit or visit child, depending on whether it is special
      revisit(dci.ref_idx[j], cell_list_[child_idx].is_special());
    }
    return dci.new_idx = -2;  // mark as previsited
  }
  if (force > 1) {
    // time to allocate
    auto i = dci.new_idx = rv_idx++;
    cell_list_tmp.emplace_back(std::move(dci));
    return i;
  }
  if (dci.new_idx == -3) {
    // already visited
    return dci.new_idx;
  }
  if (dci.is_special()) {
    // if current cell is special, previsit it first
    revisit(cell_idx, 0);
  }
  // visit children
  int n = dci.ref_num;
  for (int j = n - 1; j >= 0; --j) {
    revisit(dci.ref_idx[j], 1);
  }
  // allocate children
  for (int j = n - 1; j >= 0; --j) {
    dci.ref_idx[j] = revisit(dci.ref_idx[j], 2);
  }
  return dci.new_idx = -3;  // mark as visited (and all children processed)
}

td::uint64 BagOfCells::compute_sizes(int mode, int& r_size, int& o_size) {
  int rs = 0, os = 0;
  if (!root_count || !data_bytes) {
    r_size = o_size = 0;
    return 0;
  }
  while (cell_count >= (1 << (rs << 3))) {
    rs++;
  }
  td::uint64 hashes =
      (((mode & Mode::WithTopHash) ? top_hashes : 0) + ((mode & Mode::WithIntHashes) ? int_hashes : 0)) *
      (Cell::hash_bytes + Cell::depth_bytes);
  td::uint64 data_bytes_adj = data_bytes + (unsigned long long)int_refs * rs + hashes;
  td::uint64 max_offset = (mode & Mode::WithCacheBits) ? data_bytes_adj * 2 : data_bytes_adj;
  while (max_offset >= (1ULL << (os << 3))) {
    os++;
  }
  if (rs > 4 || os > 8) {
    r_size = o_size = 0;
    return 0;
  }
  r_size = rs;
  o_size = os;
  return data_bytes_adj;
}

std::size_t BagOfCells::estimate_serialized_size(int mode) {
  if ((mode & Mode::WithCacheBits) && !(mode & Mode::WithIndex)) {
    info.invalidate();
    return 0;
  }
  auto data_bytes_adj = compute_sizes(mode, info.ref_byte_size, info.offset_byte_size);
  if (!data_bytes_adj) {
    info.invalidate();
    return 0;
  }
  info.valid = true;
  info.has_crc32c = mode & Mode::WithCRC32C;
  info.has_index = mode & Mode::WithIndex;
  info.has_cache_bits = mode & Mode::WithCacheBits;
  info.root_count = root_count;
  info.cell_count = cell_count;
  info.absent_count = dangle_count;
  int crc_size = info.has_crc32c ? 4 : 0;
  info.roots_offset = 4 + 1 + 1 + 3 * info.ref_byte_size + info.offset_byte_size;
  info.index_offset = info.roots_offset + info.root_count * info.ref_byte_size;
  info.data_offset = info.index_offset;
  if (info.has_index) {
    info.data_offset += (long long)cell_count * info.offset_byte_size;
  }
  info.magic = Info::boc_generic;
  info.data_size = data_bytes_adj;
  info.total_size = info.data_offset + data_bytes_adj + crc_size;
  auto res = td::narrow_cast_safe<size_t>(info.total_size);
  if (res.is_error()) {
    return 0;
  }
  return res.ok();
}

BagOfCells& BagOfCells::serialize(int mode) {
  std::size_t size_est = estimate_serialized_size(mode);
  if (!size_est) {
    serialized.clear();
    return *this;
  }
  serialized.resize(size_est);
  if (serialize_to(const_cast<unsigned char*>(serialized.data()), serialized.size(), mode) != size_est) {
    serialized.clear();
  }
  return *this;
}

std::string BagOfCells::serialize_to_string(int mode) {
  std::size_t size_est = estimate_serialized_size(mode);
  if (!size_est) {
    return {};
  }
  std::string res;
  res.resize(size_est, 0);
  if (serialize_to(const_cast<unsigned char*>(reinterpret_cast<const unsigned char*>(res.data())), res.size(), mode) ==
      res.size()) {
    return res;
  } else {
    return {};
  }
}

td::Result<td::BufferSlice> BagOfCells::serialize_to_slice(int mode) {
  std::size_t size_est = estimate_serialized_size(mode);
  if (!size_est) {
    return td::Status::Error("no cells to serialize to this bag of cells");
  }
  td::BufferSlice res(size_est);
  if (serialize_to(const_cast<unsigned char*>(reinterpret_cast<const unsigned char*>(res.data())), res.size(), mode) ==
      res.size()) {
    return std::move(res);
  } else {
    return td::Status::Error("error while serializing a bag of cells: actual serialized size differs from estimated");
  }
}

std::string BagOfCells::extract_string() const {
  return std::string{serialized.data(), serialized.data() + serialized.size()};
}

void BagOfCells::store_uint(unsigned long long value, unsigned bytes) {
  unsigned char* ptr = store_ptr += bytes;
  store_chk();
  while (bytes) {
    *--ptr = value & 0xff;
    value >>= 8;
    --bytes;
  }
  DCHECK(!bytes);
}

//serialized_boc#672fb0ac has_idx:(## 1) has_crc32c:(## 1)
//  has_cache_bits:(## 1) flags:(## 2) { flags = 0 }
//  size:(## 3) { size <= 4 }
//  off_bytes:(## 8) { off_bytes <= 8 }
//  cells:(##(size * 8))
//  roots:(##(size * 8))
//  absent:(##(size * 8)) { roots + absent <= cells }
//  tot_cells_size:(##(off_bytes * 8))
//  index:(cells * ##(off_bytes * 8))
//  cell_data:(tot_cells_size * [ uint8 ])
//  = BagOfCells;
std::size_t BagOfCells::serialize_to(unsigned char* buffer, std::size_t buff_size, int mode) {
  std::size_t size_est = estimate_serialized_size(mode);
  if (!size_est || size_est > buff_size) {
    return 0;
  }
  init_store(buffer, buffer + size_est);
  store_uint(info.magic, 4);

  td::uint8 byte{0};
  if (info.has_index) {
    byte |= 1 << 7;
  }
  if (info.has_crc32c) {
    byte |= 1 << 6;
  }
  if (info.has_cache_bits) {
    byte |= 1 << 5;
  }
  // 3, 4 - flags
  if (info.ref_byte_size < 1 || info.ref_byte_size > 7) {
    return 0;
  }
  byte |= static_cast<td::uint8>(info.ref_byte_size);
  store_uint(byte, 1);

  store_uint(info.offset_byte_size, 1);
  store_ref(cell_count);
  store_ref(root_count);
  store_ref(0);
  store_offset(info.data_size);
  for (const auto& root_info : roots) {
    int k = cell_count - 1 - root_info.idx;
    DCHECK(k >= 0 && k < cell_count);
    store_ref(k);
  }
  DCHECK(store_ptr - buffer == (long long)info.index_offset);
  DCHECK((unsigned)cell_count == cell_list_.size());
  if (info.has_index) {
    std::size_t offs = 0;
    for (int i = cell_count - 1; i >= 0; --i) {
      const Ref<DataCell>& dc = cell_list_[i].dc_ref;
      bool with_hash = (mode & Mode::WithIntHashes) && !cell_list_[i].wt;
      if (cell_list_[i].is_root_cell && (mode & Mode::WithTopHash)) {
        with_hash = true;
      }
      offs += dc->get_serialized_size(with_hash) + dc->size_refs() * info.ref_byte_size;
      auto fixed_offset = offs;
      if (info.has_cache_bits) {
        fixed_offset = offs * 2 + cell_list_[i].should_cache;
      }
      store_offset(fixed_offset);
    }
    DCHECK(offs == info.data_size);
  }
  DCHECK(store_ptr - buffer == (long long)info.data_offset);
  unsigned char* keep_ptr = store_ptr;
  for (int i = 0; i < cell_count; ++i) {
    const auto& dc_info = cell_list_[cell_count - 1 - i];
    const Ref<DataCell>& dc = dc_info.dc_ref;
    bool with_hash = (mode & Mode::WithIntHashes) && !dc_info.wt;
    if (dc_info.is_root_cell && (mode & Mode::WithTopHash)) {
      with_hash = true;
    }
    int s = dc->serialize(store_ptr, 256, with_hash);
    store_ptr += s;
    store_chk();
    DCHECK(dc->size_refs() == dc_info.ref_num);
    // std::cerr << (dc_info.is_special() ? '*' : ' ') << i << '<' << (int)dc_info.wt << ">:";
    for (unsigned j = 0; j < dc_info.ref_num; ++j) {
      int k = cell_count - 1 - dc_info.ref_idx[j];
      DCHECK(k > i && k < cell_count);
      store_ref(k);
      // std::cerr << ' ' << k;
    }
    // std::cerr << std::endl;
  }
  store_chk();
  DCHECK(store_ptr - keep_ptr == (long long)info.data_size);
  DCHECK(store_end - store_ptr == (info.has_crc32c ? 4 : 0));
  if (info.has_crc32c) {
    // compute crc32c of buffer .. store_ptr
    unsigned crc = td::crc32c(td::Slice{buffer, store_ptr});
    store_uint(td::bswap32(crc), 4);
  }
  DCHECK(store_empty());
  return store_ptr - buffer;
}

unsigned long long BagOfCells::Info::read_int(const unsigned char* ptr, unsigned bytes) {
  unsigned long long res = 0;
  while (bytes > 0) {
    res = (res << 8) + *ptr++;
    --bytes;
  }
  return res;
}

void BagOfCells::Info::write_int(unsigned char* ptr, unsigned long long value, int bytes) {
  ptr += bytes;
  while (bytes) {
    *--ptr = value & 0xff;
    value >>= 8;
    --bytes;
  }
  DCHECK(!bytes);
}

long long BagOfCells::Info::parse_serialized_header(const td::Slice& slice) {
  invalidate();
  int sz = static_cast<int>(std::min(slice.size(), static_cast<std::size_t>(0xffff)));
  if (sz < 4) {
    return -10;  // want at least 10 bytes
  }
  const unsigned char* ptr = slice.ubegin();
  magic = (unsigned)read_int(ptr, 4);
  has_crc32c = false;
  has_index = false;
  has_cache_bits = false;
  ref_byte_size = 0;
  offset_byte_size = 0;
  root_count = cell_count = absent_count = -1;
  index_offset = data_offset = data_size = total_size = 0;
  if (magic != boc_generic && magic != boc_idx && magic != boc_idx_crc32c) {
    magic = 0;
    return 0;
  }
  if (sz < 5) {
    return -10;
  }
  td::uint8 byte = ptr[4];
  if (magic == boc_generic) {
    has_index = (byte >> 7) % 2 == 1;
    has_crc32c = (byte >> 6) % 2 == 1;
    has_cache_bits = (byte >> 5) % 2 == 1;
  } else {
    has_index = true;
    has_crc32c = magic == boc_idx_crc32c;
  }
  if (has_cache_bits && !has_index) {
    return 0;
  }
  ref_byte_size = byte & 7;
  if (ref_byte_size > 4 || ref_byte_size < 1) {
    return 0;
  }
  if (sz < 6) {
    return -7 - 3 * ref_byte_size;
  }
  offset_byte_size = ptr[5];
  if (offset_byte_size > 8 || offset_byte_size < 1) {
    return 0;
  }
  roots_offset = 6 + 3 * ref_byte_size + offset_byte_size;
  ptr += 6;
  sz -= 6;
  if (sz < ref_byte_size) {
    return -static_cast<int>(roots_offset);
  }
  cell_count = (int)read_ref(ptr);
  if (cell_count <= 0) {
    cell_count = -1;
    return 0;
  }
  if (sz < 2 * ref_byte_size) {
    return -static_cast<int>(roots_offset);
  }
  root_count = (int)read_ref(ptr + ref_byte_size);
  if (root_count <= 0) {
    root_count = -1;
    return 0;
  }
  index_offset = roots_offset;
  if (magic == boc_generic) {
    index_offset += (long long)root_count * ref_byte_size;
    has_roots = true;
  } else {
    if (root_count != 1) {
      return 0;
    }
  }
  data_offset = index_offset;
  if (has_index) {
    data_offset += (long long)cell_count * offset_byte_size;
  }
  if (sz < 3 * ref_byte_size) {
    return -static_cast<int>(roots_offset);
  }
  absent_count = (int)read_ref(ptr + 2 * ref_byte_size);
  if (absent_count < 0 || absent_count > cell_count) {
    return 0;
  }
  if (sz < 3 * ref_byte_size + offset_byte_size) {
    return -static_cast<int>(roots_offset);
  }
  data_size = read_offset(ptr + 3 * ref_byte_size);
  if (data_size > ((unsigned long long)cell_count << 10)) {
    return 0;
  }
  if (data_size > (1ull << 40)) {
    return 0;  // bag of cells with more than 1TiB data is unlikely
  }
  if (data_size < cell_count * (2ull + ref_byte_size) - ref_byte_size) {
    return 0;  // invalid header, too many cells for this amount of data bytes
  }
  valid = true;
  total_size = data_offset + data_size + (has_crc32c ? 4 : 0);
  return total_size;
}

td::Result<td::Slice> BagOfCells::get_cell_slice(int idx, td::Slice data) {
  unsigned long long offs = get_idx_entry(idx - 1);
  unsigned long long offs_end = get_idx_entry(idx);
  if (offs > offs_end || offs_end > data.size()) {
    return td::Status::Error(PSLICE() << "invalid index entry [" << offs << "; " << offs_end << "], "
                                      << td::tag("data.size()", data.size()));
  }
  return data.substr(offs, td::narrow_cast<size_t>(offs_end - offs));
}

td::Result<td::Ref<vm::DataCell>> BagOfCells::deserialize_cell(int idx, td::Slice cells_slice,
                                                               td::Span<td::Ref<DataCell>> cells_span,
                                                               std::vector<td::uint8>* cell_should_cache) {
  TRY_RESULT(cell_slice, get_cell_slice(idx, cells_slice));
  std::array<td::Ref<Cell>, 4> refs_buf;

  CellSerializationInfo cell_info;
  TRY_STATUS(cell_info.init(cell_slice, info.ref_byte_size));
  if (cell_info.end_offset != cell_slice.size()) {
    return td::Status::Error("unused space in cell serialization");
  }

  auto refs = td::MutableSpan<td::Ref<Cell>>(refs_buf).substr(0, cell_info.refs_cnt);
  for (int k = 0; k < cell_info.refs_cnt; k++) {
    int ref_idx = (int)info.read_ref(cell_slice.ubegin() + cell_info.refs_offset + k * info.ref_byte_size);
    if (ref_idx <= idx) {
      return td::Status::Error(PSLICE() << "bag-of-cells error: reference #" << k << " of cell #" << idx
                                        << " is to cell #" << ref_idx << " with smaller index");
    }
    if (ref_idx >= cell_count) {
      return td::Status::Error(PSLICE() << "bag-of-cells error: reference #" << k << " of cell #" << idx
                                        << " is to non-existent cell #" << ref_idx << ", only " << cell_count
                                        << " cells are defined");
    }
    refs[k] = cells_span[cell_count - ref_idx - 1];
    if (cell_should_cache) {
      auto& cnt = (*cell_should_cache)[ref_idx];
      if (cnt < 2) {
        cnt++;
      }
    }
  }

  return cell_info.create_data_cell(cell_slice, refs);
}

td::Result<long long> BagOfCells::deserialize(const td::Slice& data, int max_roots) {
  clear();
  long long size_est = info.parse_serialized_header(data);
  //LOG(INFO) << "estimated size " << size_est << ", true size " << data.size();
  if (size_est == 0) {
    return td::Status::Error(PSLICE() << "cannot deserialize bag-of-cells: invalid header, error " << size_est);
  }
  if (size_est < 0) {
    //LOG(ERROR) << "cannot deserialize bag-of-cells: not enough bytes (" << data.size() << " present, " << -size_est
    //<< " required)";
    return size_est;
  }

  if (size_est > (long long)data.size()) {
    //LOG(ERROR) << "cannot deserialize bag-of-cells: not enough bytes (" << data.size() << " present, " << size_est
    //<< " required)";
    return -size_est;
  }
  //LOG(INFO) << "estimated size " << size_est << ", true size " << data.size();
  if (info.root_count > max_roots) {
    return td::Status::Error("Bag-of-cells has more root cells than expected");
  }
  if (info.has_crc32c) {
    unsigned crc_computed = td::crc32c(td::Slice{data.ubegin(), data.uend() - 4});
    unsigned crc_stored = td::as<unsigned>(data.uend() - 4);
    if (crc_computed != crc_stored) {
      return td::Status::Error(PSLICE() << "bag-of-cells CRC32C mismatch: expected " << td::format::as_hex(crc_computed)
                                        << ", found " << td::format::as_hex(crc_stored));
    }
  }

  cell_count = info.cell_count;
  std::vector<td::uint8> cell_should_cache;
  if (info.has_cache_bits) {
    cell_should_cache.resize(cell_count, 0);
  }
  roots.clear();
  roots.resize(info.root_count);
  auto* roots_ptr = data.substr(info.roots_offset).ubegin();
  for (int i = 0; i < info.root_count; i++) {
    int idx = 0;
    if (info.has_roots) {
      idx = (int)info.read_ref(roots_ptr + i * info.ref_byte_size);
    }
    if (idx < 0 || idx >= info.cell_count) {
      return td::Status::Error(PSLICE() << "bag-of-cells invalid root index " << idx);
    }
    roots[i].idx = info.cell_count - idx - 1;
    if (info.has_cache_bits) {
      auto& cnt = cell_should_cache[idx];
      if (cnt < 2) {
        cnt++;
      }
    }
  }
  if (info.has_index) {
    index_ptr = data.substr(info.index_offset).ubegin();
    // TODO: should we validate index here
  } else {
    index_ptr = nullptr;
    unsigned long long cur = 0;
    custom_index.reserve(info.cell_count);

    auto cells_slice = data.substr(info.data_offset, info.data_size);

    for (int i = 0; i < info.cell_count; i++) {
      CellSerializationInfo cell_info;
      auto status = cell_info.init(cells_slice, info.ref_byte_size);
      if (status.is_error()) {
        return td::Status::Error(PSLICE()
                                 << "invalid bag-of-cells failed to deserialize cell #" << i << " " << status.error());
      }
      cells_slice = cells_slice.substr(cell_info.end_offset);
      cur += cell_info.end_offset;
      custom_index.push_back(cur);
    }
    if (!cells_slice.empty()) {
      return td::Status::Error(PSLICE() << "invalid bag-of-cells last cell #" << info.cell_count - 1 << ": end offset "
                                        << cur << " is different from total data size " << info.data_size);
    }
  }
  auto cells_slice = data.substr(info.data_offset, info.data_size);
  std::vector<Ref<DataCell>> cell_list;
  cell_list.reserve(cell_count);
  std::array<td::Ref<Cell>, 4> refs_buf;
  for (int i = 0; i < cell_count; i++) {
    // reconstruct cell with index cell_count - 1 - i
    int idx = cell_count - 1 - i;
    auto r_cell = deserialize_cell(idx, cells_slice, cell_list, info.has_cache_bits ? &cell_should_cache : nullptr);
    if (r_cell.is_error()) {
      return td::Status::Error(PSLICE() << "invalid bag-of-cells failed to deserialize cell #" << idx << " "
                                        << r_cell.error());
    }
    cell_list.push_back(r_cell.move_as_ok());
    DCHECK(cell_list.back().not_null());
  }
  if (info.has_cache_bits) {
    for (int idx = 0; idx < cell_count; idx++) {
      auto should_cache = cell_should_cache[idx] > 1;
      auto stored_should_cache = get_cache_entry(idx);
      if (should_cache != stored_should_cache) {
        return td::Status::Error(PSLICE() << "invalid bag-of-cells cell #" << idx << " has wrong cache flag "
                                          << stored_should_cache);
      }
    }
  }
  custom_index.clear();
  index_ptr = nullptr;
  root_count = info.root_count;
  dangle_count = info.absent_count;
  for (auto& root_info : roots) {
    root_info.cell = cell_list[root_info.idx];
  }
  cell_list.clear();
  return size_est;
}

unsigned long long BagOfCells::get_idx_entry(int index) {
  auto raw = get_idx_entry_raw(index);
  if (info.has_cache_bits) {
    raw /= 2;
  }
  return raw;
}

bool BagOfCells::get_cache_entry(int index) {
  if (!info.has_cache_bits) {
    return true;
  }
  if (!info.has_index) {
    return true;
  }
  auto raw = get_idx_entry_raw(index);
  return raw % 2 == 1;
}

unsigned long long BagOfCells::get_idx_entry_raw(int index) {
  if (index < 0) {
    return 0;
  }
  if (!info.has_index) {
    return custom_index.at(index);
  } else if (index < info.cell_count && index_ptr) {
    return info.read_offset(index_ptr + (long)index * info.offset_byte_size);
  } else {
    // throw ?
    return 0;
  }
}

/*
 * 
 *  Simple BoC serialization/deserialization functions
 * 
 */

td::Result<Ref<Cell>> std_boc_deserialize(td::Slice data, bool can_be_empty) {
  if (data.empty() && can_be_empty) {
    return Ref<Cell>();
  }
  BagOfCells boc;
  auto res = boc.deserialize(data, 1);
  if (res.is_error()) {
    return res.move_as_error();
  }
  if (boc.get_root_count() != 1) {
    return td::Status::Error("bag of cells is expected to have exactly one root");
  }
  auto root = boc.get_root_cell();
  if (root.is_null()) {
    return td::Status::Error("bag of cells has null root cell (?)");
  }
  if (root->get_level() != 0) {
    return td::Status::Error("bag of cells has a root with non-zero level");
  }
  return std::move(root);
}

td::Result<std::vector<Ref<Cell>>> std_boc_deserialize_multi(td::Slice data, int max_roots) {
  if (data.empty()) {
    return std::vector<Ref<Cell>>{};
  }
  BagOfCells boc;
  auto res = boc.deserialize(data, max_roots);
  if (res.is_error()) {
    return res.move_as_error();
  }
  int n = boc.get_root_count();
  std::vector<Ref<Cell>> roots;
  for (int i = 0; i < n; i++) {
    auto root = boc.get_root_cell(i);
    if (root.is_null()) {
      return td::Status::Error("bag of cells has a null root cell (?)");
    }
    if (root->get_level() != 0) {
      return td::Status::Error("bag of cells has a root with non-zero level");
    }
    roots.emplace_back(std::move(root));
  }
  return std::move(roots);
}

td::Result<td::BufferSlice> std_boc_serialize(Ref<Cell> root, int mode) {
  if (root.is_null()) {
    return td::Status::Error("cannot serialize a null cell reference into a bag of cells");
  }
  BagOfCells boc;
  boc.add_root(std::move(root));
  auto res = boc.import_cells();
  if (res.is_error()) {
    return res.move_as_error();
  }
  return boc.serialize_to_slice(mode);
}

td::Result<td::BufferSlice> std_boc_serialize_multi(std::vector<Ref<Cell>> roots, int mode) {
  if (roots.empty()) {
    return td::BufferSlice{};
  }
  BagOfCells boc;
  boc.add_roots(std::move(roots));
  auto res = boc.import_cells();
  if (res.is_error()) {
    return res.move_as_error();
  }
  return boc.serialize_to_slice(mode);
}

/*
 * 
 *  Cell storage statistics
 * 
 */

bool CellStorageStat::compute_used_storage(Ref<vm::CellSlice> cs_ref, bool kill_dup, unsigned skip_count_root) {
  clear();
  return add_used_storage(std::move(cs_ref), kill_dup, skip_count_root) && clear_seen();
}

bool CellStorageStat::compute_used_storage(const CellSlice& cs, bool kill_dup, unsigned skip_count_root) {
  clear();
  return add_used_storage(cs, kill_dup, skip_count_root) && clear_seen();
}

bool CellStorageStat::compute_used_storage(CellSlice&& cs, bool kill_dup, unsigned skip_count_root) {
  clear();
  return add_used_storage(std::move(cs), kill_dup, skip_count_root) && clear_seen();
}

bool CellStorageStat::compute_used_storage(Ref<vm::Cell> cell, bool kill_dup, unsigned skip_count_root) {
  clear();
  return add_used_storage(std::move(cell), kill_dup, skip_count_root) && clear_seen();
}

bool CellStorageStat::add_used_storage(Ref<vm::CellSlice> cs_ref, bool kill_dup, unsigned skip_count_root) {
  if (cs_ref->is_unique()) {
    return add_used_storage(std::move(cs_ref.unique_write()), kill_dup, skip_count_root);
  } else {
    return add_used_storage(*cs_ref, kill_dup, skip_count_root);
  }
}

bool CellStorageStat::add_used_storage(const CellSlice& cs, bool kill_dup, unsigned skip_count_root) {
  if (!(skip_count_root & 1)) {
    ++cells;
  }
  if (!(skip_count_root & 2)) {
    bits += cs.size();
  }
  for (unsigned i = 0; i < cs.size_refs(); i++) {
    if (!add_used_storage(cs.prefetch_ref(i), kill_dup)) {
      return false;
    }
  }
  return true;
}

bool CellStorageStat::add_used_storage(CellSlice&& cs, bool kill_dup, unsigned skip_count_root) {
  if (!(skip_count_root & 1)) {
    ++cells;
  }
  if (!(skip_count_root & 2)) {
    bits += cs.size();
  }
  while (cs.size_refs()) {
    if (!add_used_storage(cs.fetch_ref(), kill_dup)) {
      return false;
    }
  }
  return true;
}

bool CellStorageStat::add_used_storage(Ref<vm::Cell> cell, bool kill_dup, unsigned skip_count_root) {
  if (cell.is_null()) {
    return false;
  }
  if (kill_dup) {
    auto ins = seen.insert(cell->get_hash());
    if (!ins.second) {
      return true;
    }
  }
  vm::CellSlice cs{vm::NoVm{}, std::move(cell)};
  return add_used_storage(std::move(cs), kill_dup, skip_count_root);
}

void NewCellStorageStat::add_cell(Ref<Cell> cell) {
  dfs(std::move(cell), true, false);
}
void NewCellStorageStat::add_proof(Ref<Cell> cell, const CellUsageTree* usage_tree) {
  CHECK(usage_tree);
  usage_tree_ = usage_tree;
  dfs(std::move(cell), false, true);
}
void NewCellStorageStat::add_cell_and_proof(Ref<Cell> cell, const CellUsageTree* usage_tree) {
  CHECK(usage_tree);
  usage_tree_ = usage_tree;
  dfs(std::move(cell), true, true);
}

NewCellStorageStat::Stat NewCellStorageStat::tentative_add_cell(Ref<Cell> cell) const {
  NewCellStorageStat stat;
  stat.parent_ = this;
  stat.add_cell(std::move(cell));
  return stat.get_stat();
}

NewCellStorageStat::Stat NewCellStorageStat::tentative_add_proof(Ref<Cell> cell,
                                                                 const CellUsageTree* usage_tree) const {
  NewCellStorageStat stat;
  stat.parent_ = this;
  stat.add_proof(std::move(cell), usage_tree);
  return stat.get_proof_stat();
}

void NewCellStorageStat::dfs(Ref<Cell> cell, bool need_stat, bool need_proof_stat) {
  if (cell.is_null()) {
    // FIXME: save error flag?
    return;
  }
  if (need_stat) {
    stat_.internal_refs++;
    if ((parent_ && parent_->seen_.count(cell->get_hash()) != 0) || !seen_.insert(cell->get_hash()).second) {
      need_stat = false;
    } else {
      stat_.cells++;
    }
  }

  if (need_proof_stat) {
    auto tree_node = cell->get_tree_node();
    if (!tree_node.empty() && tree_node.is_from_tree(usage_tree_)) {
      proof_stat_.external_refs++;
      need_proof_stat = false;
    } else {
      proof_stat_.internal_refs++;
      if ((parent_ && parent_->proof_seen_.count(cell->get_hash()) != 0) ||
          !proof_seen_.insert(cell->get_hash()).second) {
        need_proof_stat = false;
      } else {
        proof_stat_.cells++;
      }
    }
  }

  if (!need_proof_stat && !need_stat) {
    return;
  }
  vm::CellSlice cs{vm::NoVm{}, std::move(cell)};
  if (need_stat) {
    stat_.bits += cs.size();
  }
  if (need_proof_stat) {
    proof_stat_.bits += cs.size();
  }
  while (cs.size_refs()) {
    dfs(cs.fetch_ref(), need_stat, need_proof_stat);
  }
}

}  // namespace vm
