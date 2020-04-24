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
#pragma once
#include "vm/cells.h"
#include "block/block.h"
#include "Ed25519.h"
#include "SmartContract.h"

namespace ton {
namespace smc {
td::Ref<vm::CellSlice> pack_grams(td::uint64 amount);
bool unpack_grams(td::Ref<vm::CellSlice> cs, td::uint64& amount);
}  // namespace smc
class GenericAccount {
 public:
  static td::Ref<vm::Cell> get_init_state(td::Ref<vm::Cell> code, td::Ref<vm::Cell> data) noexcept;
  static block::StdAddress get_address(ton::WorkchainId workchain_id, const td::Ref<vm::Cell>& init_state) noexcept;
  static td::Ref<vm::Cell> create_ext_message(const block::StdAddress& address, td::Ref<vm::Cell> new_state,
                                              td::Ref<vm::Cell> body) noexcept;
  static void store_int_message(vm::CellBuilder& cb, const block::StdAddress& dest_address, td::int64 gramms);

  static td::Result<td::Ed25519::PublicKey> get_public_key(const SmartContract& sc);
};
}  // namespace ton
