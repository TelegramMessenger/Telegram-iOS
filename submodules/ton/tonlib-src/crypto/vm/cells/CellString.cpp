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
#include "CellString.h"
#include "td/utils/misc.h"

#include "vm/cells/CellSlice.h"

namespace vm {
td::Status CellString::store(CellBuilder &cb, td::Slice slice, unsigned int top_bits) {
  td::uint32 size = td::narrow_cast<td::uint32>(slice.size() * 8);
  return store(cb, td::BitSlice(slice.ubegin(), size), top_bits);
}

td::Status CellString::store(CellBuilder &cb, td::BitSlice slice, unsigned int top_bits) {
  if (slice.size() > max_bytes * 8) {
    return td::Status::Error("String is too long (1)");
  }
  unsigned int head = td::min(slice.size(), td::min(cb.remaining_bits(), top_bits)) / 8 * 8;
  auto max_bits = vm::Cell::max_bits / 8 * 8;
  auto depth = 1 + (slice.size() - head + max_bits - 1) / max_bits;
  if (depth > max_chain_length) {
    return td::Status::Error("String is too long (2)");
  }
  cb.append_bitslice(slice.subslice(0, head));
  slice.advance(head);
  if (slice.size() == 0) {
    return td::Status::OK();
  }
  CellBuilder child_cb;
  store(child_cb, std::move(slice));
  cb.store_ref(child_cb.finalize());
  return td::Status::OK();
}

template <class F>
void CellString::for_each(F &&f, CellSlice &cs, unsigned int top_bits) {
  unsigned int head = td::min(cs.size(), top_bits);
  f(cs.prefetch_bits(head));
  if (!cs.have_refs()) {
    return;
  }
  auto ref = cs.prefetch_ref();
  while (true) {
    auto cs = vm::load_cell_slice(ref);
    f(cs.prefetch_bits(cs.size()));
    if (!cs.have_refs()) {
      return;
    }
    ref = cs.prefetch_ref();
  }
}

td::Result<td::string> CellString::load(CellSlice &cs, unsigned int top_bits) {
  unsigned int size = 0;
  for_each([&](auto slice) { size += slice.size(); }, cs, top_bits);
  if (size % 8 != 0) {
    return td::Status::Error("Size is not divisible by 8");
  }
  std::string res(size / 8, 0);

  td::BitPtr to(td::MutableSlice(res).ubegin());
  for_each([&](auto slice) { to.concat(slice); }, cs, top_bits);
  CHECK(to.offs == (int)size);
  return res;
}

td::Status CellText::store(CellBuilder &cb, td::Slice slice, unsigned int top_bits) {
  td::uint32 size = td::narrow_cast<td::uint32>(slice.size() * 8);
  return store(cb, td::BitSlice(slice.ubegin(), size), top_bits);
}

td::Status CellText::store(CellBuilder &cb, td::BitSlice slice, unsigned int top_bits) {
  if (slice.size() > max_bytes * 8) {
    return td::Status::Error("String is too long (1)");
  }
  if (cb.remaining_bits() < 16) {
    return td::Status::Error("Not enough space in a builder");
  }
  if (top_bits < 16) {
    return td::Status::Error("Need at least 16 top bits");
  }
  if (slice.size() == 0) {
    cb.store_long(0, 8);
    return td::Status::OK();
  }
  unsigned int head = td::min(slice.size(), td::min(cb.remaining_bits(), top_bits) - 16) / 8 * 8;
  auto max_bits = vm::Cell::max_bits / 8 * 8;
  auto depth = 1 + (slice.size() - head + max_bits - 8 - 1) / (max_bits - 8);
  if (depth > max_chain_length) {
    return td::Status::Error("String is too long (2)");
  }
  cb.store_long(depth, 8);
  cb.store_long(head / 8, 8);
  cb.append_bitslice(slice.subslice(0, head));
  slice.advance(head);
  if (slice.size() == 0) {
    return td::Status::OK();
  }
  cb.store_ref(do_store(std::move(slice)));
  return td::Status::OK();
}

td::Ref<vm::Cell> CellText::do_store(td::BitSlice slice) {
  vm::CellBuilder cb;
  unsigned int head = td::min(slice.size(), cb.remaining_bits() - 8) / 8 * 8;
  cb.store_long(head / 8, 8);
  cb.append_bitslice(slice.subslice(0, head));
  slice.advance(head);
  if (slice.size() != 0) {
    cb.store_ref(do_store(std::move(slice)));
  }
  return cb.finalize();
}

template <class F>
void CellText::for_each(F &&f, CellSlice cs) {
  auto depth = cs.fetch_ulong(8);

  for (td::uint32 i = 0; i < depth; i++) {
    auto size = cs.fetch_ulong(8);
    f(cs.fetch_bits(td::narrow_cast<int>(size) * 8));
    if (i + 1 < depth) {
      cs = vm::load_cell_slice(cs.prefetch_ref());
    }
  }
}

td::Result<td::string> CellText::load(CellSlice &cs) {
  unsigned int size = 0;
  for_each([&](auto slice) { size += slice.size(); }, cs);
  if (size % 8 != 0) {
    return td::Status::Error("Size is not divisible by 8");
  }
  std::string res(size / 8, 0);

  td::BitPtr to(td::MutableSlice(res).ubegin());
  for_each([&](auto slice) { to.concat(slice); }, cs);
  CHECK(to.offs == (int)size);
  return res;
}
}  // namespace vm
