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
#include "vm/cells/CellBuilder.h"

#include "vm/cells/CellSlice.h"
#include "vm/cells/DataCell.h"

#include "td/utils/misc.h"
#include "td/utils/format.h"

#include "openssl/digest.hpp"

namespace vm {

using td::Ref;
using td::RefAny;

/*
 * 
 *   CELL BUILDERS
 * 
 */

CellBuilder::~CellBuilder() {
  get_thread_safe_counter().add(-1);
}

CellBuilder::CellBuilder() : bits(0), refs_cnt(0) {
  get_thread_safe_counter().add(+1);
}

Ref<DataCell> CellBuilder::finalize_copy(bool special) const {
  auto* vm_state_interface = VmStateInterface::get();
  if (vm_state_interface) {
    vm_state_interface->register_cell_create();
  }
  auto res = DataCell::create(data, size(), td::span(refs.data(), size_refs()), special);
  if (res.is_error()) {
    LOG(DEBUG) << res.error();
    throw CellWriteError{};
  }
  auto cell = res.move_as_ok();
  CHECK(cell.not_null());
  if (vm_state_interface) {
    vm_state_interface->register_new_cell(cell);
    if (cell.is_null()) {
      LOG(DEBUG) << "cannot register new data cell";
      throw CellWriteError{};
    }
  }
  return cell;
}

td::Result<Ref<DataCell>> CellBuilder::finalize_novm_nothrow(bool special) {
  auto res = DataCell::create(data, size(), td::mutable_span(refs.data(), size_refs()), special);
  bits = refs_cnt = 0;
  return res;
}

Ref<DataCell> CellBuilder::finalize_novm(bool special) {
  auto res = finalize_novm_nothrow(special);
  if (res.is_error()) {
    LOG(DEBUG) << res.error();
    throw CellWriteError{};
  }
  CHECK(res.ok().not_null());
  return res.move_as_ok();
}

Ref<DataCell> CellBuilder::finalize(bool special) {
  auto* vm_state_interface = VmStateInterface::get();
  if (!vm_state_interface) {
    return finalize_novm(special);
  }
  vm_state_interface->register_cell_create();
  auto cell = finalize_novm(special);
  vm_state_interface->register_new_cell(cell);
  if (cell.is_null()) {
    LOG(DEBUG) << "cannot register new data cell";
    throw CellWriteError{};
  }
  return cell;
}

Ref<Cell> CellBuilder::create_pruned_branch(Ref<Cell> cell, td::uint32 new_level, td::uint32 virt_level) {
  if (cell->is_loaded() && cell->get_level() <= virt_level && cell->get_virtualization() == 0) {
    CellSlice cs(NoVm{}, cell);
    if (cs.size_refs() == 0) {
      return cell;
    }
  }
  return do_create_pruned_branch(std::move(cell), new_level, virt_level);
}

Ref<DataCell> CellBuilder::do_create_pruned_branch(Ref<Cell> cell, td::uint32 new_level, td::uint32 virt_level) {
  auto level_mask = cell->get_level_mask().apply(virt_level);
  auto level = level_mask.get_level();
  if (new_level < level + 1) {
    throw CellWriteError();
  }
  CellBuilder cb;
  cb.store_long(static_cast<td::uint8>(Cell::SpecialType::PrunnedBranch), 8);
  cb.store_long(level_mask.apply_or(Cell::LevelMask::one_level(new_level)).get_mask(), 8);
  for (td::uint32 i = 0; i <= level; i++) {
    if (level_mask.is_significant(i)) {
      cb.store_bytes(cell->get_hash(i).as_slice());
    }
  }
  for (td::uint32 i = 0; i <= level; i++) {
    if (level_mask.is_significant(i)) {
      cb.store_long(cell->get_depth(i), 16);
    }
  }
  return cb.finalize(true);
}

Ref<DataCell> CellBuilder::create_merkle_proof(Ref<Cell> cell_proof) {
  CellBuilder cb;
  cb.store_long(static_cast<td::uint8>(Cell::SpecialType::MerkleProof), 8);
  cb.store_bytes(cell_proof->get_hash(0).as_slice());
  cb.store_long(cell_proof->get_depth(0), Cell::depth_bytes * 8);
  cb.store_ref(cell_proof);
  return cb.finalize(true);
}

Ref<DataCell> CellBuilder::create_merkle_update(Ref<Cell> from_proof, Ref<Cell> to_proof) {
  CellBuilder cb;
  cb.store_long(static_cast<td::uint8>(Cell::SpecialType::MerkleUpdate), 8);
  cb.store_bytes(from_proof->get_hash(0).as_slice());
  cb.store_bytes(to_proof->get_hash(0).as_slice());
  cb.store_long(from_proof->get_depth(0), Cell::depth_bytes * 8);
  cb.store_long(to_proof->get_depth(0), Cell::depth_bytes * 8);
  cb.store_ref(from_proof);
  cb.store_ref(to_proof);
  return cb.finalize(true);
}

void CellBuilder::reset(void) {
  while (refs_cnt > 0) {
    refs[--refs_cnt].clear();
  }
  bits = 0;
}

CellBuilder& CellBuilder::operator=(const CellBuilder& other) {
  bits = other.bits;
  refs_cnt = other.refs_cnt;
  refs = other.refs;
  std::memcpy(data, other.data, (bits + 7) >> 3);
  return *this;
}

CellBuilder& CellBuilder::operator=(CellBuilder&& other) {
  bits = other.bits;
  refs_cnt = other.refs_cnt;
  refs = std::move(other.refs);
  other.refs_cnt = 0;
  std::memcpy(data, other.data, (bits + 7) >> 3);
  return *this;
}

bool CellBuilder::can_extend_by(std::size_t new_bits, unsigned new_refs) const {
  return (new_bits <= Cell::max_bits - bits && new_refs <= (unsigned)Cell::max_refs - refs_cnt);
}

bool CellBuilder::can_extend_by(std::size_t new_bits) const {
  return new_bits <= Cell::max_bits - bits;
}

CellBuilder& CellBuilder::store_bytes(const unsigned char* str, std::size_t len) {
  ensure_throw(len <= Cell::max_bytes);
  return store_bits(str, len * 8);
}

CellBuilder& CellBuilder::store_bytes(const unsigned char* str, const unsigned char* end) {
  ensure_throw(end >= str && end <= str + Cell::max_bytes);
  return store_bits(str, (end - str) * 8);
}

CellBuilder& CellBuilder::store_bytes(const char* str, std::size_t len) {
  return store_bytes((const unsigned char*)(str), len);
}

CellBuilder& CellBuilder::store_bytes(const char* str, const char* end) {
  return store_bytes((const unsigned char*)(str), (const unsigned char*)(end));
}

CellBuilder& CellBuilder::store_bytes(td::Slice s) {
  return store_bytes((const unsigned char*)(s.data()), (const unsigned char*)(s.data() + s.size()));
}

bool CellBuilder::store_bytes_bool(const unsigned char* str, std::size_t len) {
  return len <= Cell::max_bytes && store_bits_bool(str, len * 8);
}

bool CellBuilder::store_bytes_bool(const char* str, std::size_t len) {
  return len <= Cell::max_bytes && store_bits_bool((const unsigned char*)str, len * 8);
}

bool CellBuilder::store_bytes_bool(td::Slice s) {
  return store_bytes_bool((const unsigned char*)s.data(), s.size());
}

bool CellBuilder::store_bits_bool(const unsigned char* str, std::size_t bit_count, int bit_offset) {
  unsigned pos = bits;
  if (!prepare_reserve(bit_count)) {
    return false;
  }
  td::bitstring::bits_memcpy(data, pos, str, bit_offset, bit_count);
  return true;
}

CellBuilder& CellBuilder::store_bits(const unsigned char* str, std::size_t bit_count, int bit_offset) {
  unsigned pos = bits;
  ensure_throw(prepare_reserve(bit_count));
  td::bitstring::bits_memcpy(data, pos, str, bit_offset, bit_count);
  return *this;
}

CellBuilder& CellBuilder::store_bits(const td::BitSlice& bs) {
  return store_bits(bs.get_ptr(), bs.size(), bs.get_offs());
}

CellBuilder& CellBuilder::store_bits(const char* str, std::size_t bit_count, int bit_offset) {
  return store_bits((const unsigned char*)str, bit_count, bit_offset);
}

CellBuilder& CellBuilder::store_bits(td::ConstBitPtr bs, std::size_t bit_count) {
  return store_bits(bs.ptr, bit_count, bs.offs);
}

bool CellBuilder::store_bits_bool(td::ConstBitPtr bs, std::size_t bit_count) {
  return store_bits_bool(bs.ptr, bit_count, bs.offs);
}

CellBuilder& CellBuilder::store_bits_same(std::size_t bit_count, bool val) {
  unsigned pos = bits;
  if (prepare_reserve(bit_count)) {
    td::bitstring::bits_memset(data, pos, val, bit_count);
  }
  return *this;
}

bool CellBuilder::store_bits_same_bool(std::size_t bit_count, bool val) {
  unsigned pos = bits;
  if (!prepare_reserve(bit_count)) {
    return false;
  }
  td::bitstring::bits_memset(data, pos, val, bit_count);
  return true;
}

inline bool CellBuilder::prepare_reserve(std::size_t bit_count) {
  if (!can_extend_by(bit_count)) {
    return false;
  } else {
    bits += (unsigned)bit_count;
    return true;
  }
}

td::BitSliceWrite CellBuilder::reserve_slice(std::size_t bit_count) {
  unsigned offs = bits;
  if (prepare_reserve(bit_count)) {
    return td::BitSliceWrite{Ref<CellBuilder>{this}, data, offs, (unsigned)bit_count};
  } else {
    return td::BitSliceWrite{};
  }
}

CellBuilder& CellBuilder::reserve_slice(std::size_t bit_count, td::BitSliceWrite& bsw) {
  unsigned offs = bits;
  if (prepare_reserve(bit_count)) {
    bsw.assign(Ref<CellBuilder>{this}, data, offs, (unsigned)bit_count);
  } else {
    bsw.forget();
  }
  return *this;
}

bool CellBuilder::store_bool_bool(bool val) {
  if (can_extend_by_fast(1)) {
    store_long(val, 1);
    return true;
  } else {
    return false;
  }
}

bool CellBuilder::store_long_bool(long long val, unsigned val_bits) {
  if (val_bits > 64 || !can_extend_by(val_bits)) {
    return false;
  }
  store_long(val, val_bits);
  return true;
}

bool CellBuilder::store_long_rchk_bool(long long val, unsigned val_bits) {
  if (val_bits > 64 || !can_extend_by(val_bits)) {
    return false;
  }
  if (val_bits < 64 && (val < static_cast<long long>(std::numeric_limits<td::uint64>::max() << (val_bits - 1)) ||
                        val >= (1LL << (val_bits - 1)))) {
    return false;
  }
  store_long(val, val_bits);
  return true;
}

bool CellBuilder::store_ulong_rchk_bool(unsigned long long val, unsigned val_bits) {
  if (val_bits > 64 || !can_extend_by(val_bits)) {
    return false;
  }
  if (val_bits < 64 && val >= (1ULL << val_bits)) {
    return false;
  }
  store_long(val, val_bits);
  return true;
}

CellBuilder& CellBuilder::store_long(long long val, unsigned val_bits) {
  return store_long_top(val << (64 - val_bits), val_bits);
}

CellBuilder& CellBuilder::store_long_top(unsigned long long val, unsigned top_bits) {
  unsigned pos = bits;
  auto reserve_ok = prepare_reserve(top_bits);
  ensure_throw(reserve_ok);
  td::bitstring::bits_store_long_top(data, pos, val, top_bits);
  return *this;
}

bool CellBuilder::store_uint_less(unsigned upper_bound, unsigned long long val) {
  return val < upper_bound && store_long_bool(val, 32 - td::count_leading_zeroes32(upper_bound - 1));
}

bool CellBuilder::store_uint_leq(unsigned upper_bound, unsigned long long val) {
  return val <= upper_bound && store_long_bool(val, 32 - td::count_leading_zeroes32(upper_bound));
}

bool CellBuilder::store_int256_bool(const td::BigInt256& val, unsigned val_bits, bool sgnd) {
  unsigned pos = bits;
  if (!prepare_reserve(val_bits)) {
    return false;
  }
  if (val.export_bits(data, pos, val_bits, sgnd)) {
    return true;
  } else {
    bits = pos;
    return false;
  }
}

CellBuilder& CellBuilder::store_int256(const td::BigInt256& val, unsigned val_bits, bool sgnd) {
  return ensure_pass(store_int256_bool(val, val_bits, sgnd));
}

bool CellBuilder::store_int256_bool(td::RefInt256 val, unsigned val_bits, bool sgnd) {
  return val.not_null() && store_int256_bool(*val, val_bits, sgnd);
}

bool CellBuilder::store_builder_ref_bool(vm::CellBuilder&& cb) {
  return store_ref_bool(cb.finalize());
}

bool CellBuilder::store_ref_bool(Ref<Cell> ref) {
  if (refs_cnt < Cell::max_refs && ref.not_null()) {
    refs[refs_cnt++] = std::move(ref);
    return true;
  } else {
    return false;
  }
}

CellBuilder& CellBuilder::store_ref(Ref<Cell> ref) {
  return ensure_pass(store_ref_bool(std::move(ref)));
}

td::uint16 CellBuilder::get_depth() const {
  int d = 0;
  for (unsigned i = 0; i < refs_cnt; i++) {
    d = std::max(d, 1 + refs[i]->get_depth());
  }
  return static_cast<td::uint16>(d);
}

bool CellBuilder::append_data_cell_bool(const DataCell& cell) {
  unsigned len = cell.size();
  if (can_extend_by(len, cell.size_refs())) {
    unsigned pos = bits;
    ensure_throw(prepare_reserve(len));
    td::bitstring::bits_memcpy(data, pos, cell.get_data(), 0, len);
    for (unsigned i = 0; i < cell.size_refs(); i++) {
      refs[refs_cnt++] = cell.get_ref(i);
    }
    return true;
  } else {
    return false;
  }
}

CellBuilder& CellBuilder::append_data_cell(const DataCell& cell) {
  return ensure_pass(append_data_cell_bool(cell));
}

bool CellBuilder::append_data_cell_bool(Ref<DataCell> cell_ref) {
  return append_data_cell_bool(*cell_ref);
}

CellBuilder& CellBuilder::append_data_cell(Ref<DataCell> cell_ref) {
  return ensure_pass(append_data_cell_bool(std::move(cell_ref)));
}

bool CellBuilder::append_builder_bool(const CellBuilder& cb) {
  unsigned len = cb.size();
  if (can_extend_by(len, cb.size_refs())) {
    unsigned pos = bits;
    ensure_throw(prepare_reserve(len));
    td::bitstring::bits_memcpy(data, pos, cb.get_data(), 0, len);
    for (unsigned i = 0; i < cb.size_refs(); i++) {
      refs[refs_cnt++] = cb.get_ref(i);
    }
    return true;
  } else {
    return false;
  }
}

CellBuilder& CellBuilder::append_builder(const CellBuilder& cb) {
  return ensure_pass(append_builder_bool(cb));
}

bool CellBuilder::append_builder_bool(Ref<CellBuilder> cb_ref) {
  return append_builder_bool(*cb_ref);
}

CellBuilder& CellBuilder::append_builder(Ref<CellBuilder> cb_ref) {
  return ensure_pass(append_builder_bool(std::move(cb_ref)));
}

bool CellBuilder::append_cellslice_bool(const CellSlice& cs) {
  unsigned len = cs.size();
  if (can_extend_by(len, cs.size_refs())) {
    int pos = bits;
    ensure_throw(prepare_reserve(len));
    td::bitstring::bits_memcpy(td::BitPtr{data, pos}, cs.data_bits(), len);
    for (unsigned i = 0; i < cs.size_refs(); i++) {
      refs[refs_cnt++] = cs.prefetch_ref(i);
    }
    return true;
  } else {
    return false;
  }
}

CellBuilder& CellBuilder::append_cellslice(const CellSlice& cs) {
  return ensure_pass(append_cellslice_bool(cs));
}

bool CellBuilder::append_cellslice_bool(Ref<CellSlice> cs_ref) {
  return cs_ref.not_null() && append_cellslice_bool(*cs_ref);
}

CellBuilder& CellBuilder::append_cellslice(Ref<CellSlice> cs) {
  return ensure_pass(append_cellslice_bool(cs));
}

bool CellBuilder::append_cellslice_chk(const CellSlice& cs, unsigned size_ext) {
  return cs.size_ext() == size_ext && append_cellslice_bool(cs);
}

bool CellBuilder::append_cellslice_chk(Ref<CellSlice> cs_ref, unsigned size_ext) {
  return cs_ref.not_null() && append_cellslice_chk(*cs_ref, size_ext);
}

CellSlice CellSlice::clone() const {
  CellBuilder cb;
  Ref<Cell> cell;
  if (cb.append_cellslice_bool(*this) && cb.finalize_to(cell)) {
    return CellSlice{NoVmOrd(), std::move(cell)};
  } else {
    return {};
  }
}

bool CellBuilder::append_bitstring(const td::BitString& bs) {
  return store_bits_bool(bs.cbits(), bs.size());
}

bool CellBuilder::append_bitstring(Ref<td::BitString> bs_ref) {
  return bs_ref.not_null() && append_bitstring(*bs_ref);
}

bool CellBuilder::append_bitstring_chk(const td::BitString& bs, unsigned size) {
  return bs.size() == size && store_bits_bool(bs.cbits(), size);
}

bool CellBuilder::append_bitstring_chk(Ref<td::BitString> bs_ref, unsigned size) {
  return bs_ref.not_null() && append_bitstring_chk(*bs_ref, size);
}

bool CellBuilder::append_bitslice(const td::BitSlice& bs) {
  return store_bits_bool(bs.bits(), bs.size());
}

bool CellBuilder::store_maybe_ref(Ref<Cell> cell) {
  if (cell.is_null()) {
    return store_long_bool(0, 1);
  } else {
    return store_long_bool(1, 1) && store_ref_bool(std::move(cell));
  }
}

void CellBuilder::flush(unsigned char d[2]) const {
  assert(refs_cnt <= Cell::max_refs && bits <= Cell::max_bits);

  unsigned l = (bits >> 3);
  if (bits & 7) {
    int m = (0x80 >> (bits & 7));
    data[l] = static_cast<unsigned char>((data[l] & -m) | m);
    d[1] = static_cast<unsigned char>(2 * l + 1);
  } else {
    d[1] = static_cast<unsigned char>(2 * l);
  }
  d[0] = static_cast<unsigned char>(refs_cnt);
}

const unsigned char* CellBuilder::compute_hash(unsigned char buffer[Cell::hash_bytes]) const {
  unsigned char tmp[2];
  flush(tmp);
  digest::SHA256 hasher(tmp, 2);
  hasher.feed(data, (bits + 7) >> 3);
  for (unsigned i = 0; i < refs_cnt; i++) {
    hasher.feed(refs[i]->get_hash().as_slice().data(), Cell::hash_bytes);
  }
  auto extracted_size = hasher.extract(buffer);
  DCHECK(extracted_size == Cell::hash_bytes);
  return buffer;
}

int CellBuilder::serialize(unsigned char* buff, int buff_size) const {
  int len = get_serialized_size();
  if (len > buff_size) {
    return 0;
  }
  flush(buff);
  std::memcpy(buff + 2, data, len - 2);
  return len;
}

CellBuilder* CellBuilder::make_copy() const {
  CellBuilder* c = new CellBuilder();
  c->bits = bits;
  std::memcpy(c->data, data, (bits + 7) >> 3);
  c->refs_cnt = refs_cnt;
  for (unsigned i = 0; i < refs_cnt; i++) {
    c->refs[i] = refs[i];
  }
  return c;
}

CellSlice CellBuilder::as_cellslice() const& {
  return CellSlice{finalize_copy()};
}

Ref<CellSlice> CellBuilder::as_cellslice_ref() const& {
  return Ref<CellSlice>{true, finalize_copy()};
}

CellSlice CellBuilder::as_cellslice() && {
  return CellSlice{finalize()};
}

Ref<CellSlice> CellBuilder::as_cellslice_ref() && {
  return Ref<CellSlice>{true, finalize()};
}

bool CellBuilder::contents_equal(const CellSlice& cs) const {
  if (size() != cs.size() || size_refs() != cs.size_refs()) {
    return false;
  }
  if (td::bitstring::bits_memcmp(data_bits(), cs.data_bits(), size())) {
    return false;
  }
  for (unsigned i = 0; i < size_refs(); i++) {
    if (refs[i]->get_hash() != cs.prefetch_ref(i)->get_hash()) {
      return false;
    }
  }
  return true;
}

std::string CellBuilder::serialize() const {
  unsigned char buff[Cell::max_serialized_bytes];
  int len = serialize(buff, sizeof(buff));
  return std::string(buff, buff + len);
}

std::string CellBuilder::to_hex() const {
  unsigned char buff[Cell::max_serialized_bytes];
  int len = serialize(buff, sizeof(buff));
  char hex_buff[Cell::max_serialized_bytes * 2 + 1];
  for (int i = 0; i < len; i++) {
    sprintf(hex_buff + 2 * i, "%02x", buff[i]);
  }
  return hex_buff;
}

std::ostream& operator<<(std::ostream& os, const CellBuilder& cb) {
  return os << cb.to_hex();
}
}  // namespace vm
