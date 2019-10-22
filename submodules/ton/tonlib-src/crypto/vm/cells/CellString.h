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

 private:
  template <class F>
  static void for_each(F &&f, CellSlice &cs, unsigned int top_bits = Cell::max_bits);
};

}  // namespace vm
