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
#include "ton/ton-types.h"
#include "block/block.h"
#include "block/block-parse.h"

namespace tonlib {
template <class F>
auto try_f(F&& f) noexcept -> decltype(f()) {
  try {
    return f();
  } catch (vm::VmError error) {
    return td::Status::Error(PSLICE() << "Got a vm exception: " << error.get_msg());
  }
}

#define TRY_VM(f) try_f([&] { return f; })

extern int VERBOSITY_NAME(tonlib_query);
extern int VERBOSITY_NAME(last_block);
extern int VERBOSITY_NAME(lite_server);
td::Result<td::Ref<vm::CellSlice>> binary_bitstring_to_cellslice(td::Slice literal);
}  // namespace tonlib
