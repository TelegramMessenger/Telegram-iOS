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
#include "vm/cellslice.h"

namespace vm {

class OpcodeTable;

void register_cell_ops(OpcodeTable &cp0);

std::string dump_push_ref(CellSlice &cs, unsigned args, int pfx_bits, std::string name);
int compute_len_push_ref(const CellSlice &cs, unsigned args, int pfx_bits);

}  // namespace vm
