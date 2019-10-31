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
#include "SmartContract.h"
#include "block/block.h"
#include "vm/cells/CellString.h"
namespace ton {
class TestGiver : public SmartContract {
 public:
  explicit TestGiver(State state) : ton::SmartContract(std::move(state)) {
  }
  static constexpr unsigned max_message_size = vm::CellString::max_bytes;
  static const block::StdAddress& address() noexcept;
  static vm::CellHash get_init_code_hash() noexcept;
  static td::Ref<vm::Cell> make_a_gift_message(td::uint32 seqno, td::uint64 gramms, td::Slice message,
                                               const block::StdAddress& dest_address) noexcept;

  td::Result<td::uint32> get_seqno() const;

 private:
  td::Result<td::uint32> get_seqno_or_throw() const;
};
}  // namespace ton
