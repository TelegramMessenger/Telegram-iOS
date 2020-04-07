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
}  // namespace vm
