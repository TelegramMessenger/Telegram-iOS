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
#include "cp0.h"
#include "opctable.h"
#include "stackops.h"
#include "tupleops.h"
#include "arithops.h"
#include "cellops.h"
#include "contops.h"
#include "dictops.h"
#include "debugops.h"
#include "tonops.h"

namespace vm {

const OpcodeTable* init_op_cp0(bool enable_debug) {
  set_debug_enabled(enable_debug);
  static const OpcodeTable* static_op_cp0 = [] {
    auto op_cp0 = new OpcodeTable("TEST CODEPAGE", Codepage::test_cp);
    register_stack_ops(*op_cp0);         // stackops.cpp
    register_tuple_ops(*op_cp0);         // tupleops.cpp
    register_arith_ops(*op_cp0);         // arithops.cpp
    register_cell_ops(*op_cp0);          // cellops.cpp
    register_continuation_ops(*op_cp0);  // contops.cpp
    register_dictionary_ops(*op_cp0);    // dictops.cpp
    register_ton_ops(*op_cp0);           // tonops.cpp
    register_debug_ops(*op_cp0);         // debugops.cpp
    register_codepage_ops(*op_cp0);      // contops.cpp
    op_cp0->finalize()->register_table(Codepage::test_cp);
    return op_cp0;
  }();
  return static_op_cp0;
}

}  // namespace vm
