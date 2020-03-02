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
#include "SmartContract.h"
#include "smc-envelope/WalletInterface.h"
#include "block/block.h"
#include "vm/cells/CellString.h"
namespace ton {
class TestGiver : public SmartContract, public WalletInterface {
 public:
  explicit TestGiver(State state) : ton::SmartContract(std::move(state)) {
  }
  TestGiver() : ton::SmartContract({}) {
  }
  static constexpr unsigned max_message_size = vm::CellString::max_bytes;
  static constexpr unsigned max_gifts_size = 1;
  static const block::StdAddress& address() noexcept;
  static vm::CellHash get_init_code_hash() noexcept;
  static td::Ref<vm::Cell> make_a_gift_message_static(td::uint32 seqno, td::Span<Gift>) noexcept;

  td::Result<td::uint32> get_seqno() const;

  using WalletInterface::get_init_message;
  td::Result<td::Ref<vm::Cell>> make_a_gift_message(const td::Ed25519::PrivateKey& private_key, td::uint32 valid_until,
                                                    td::Span<Gift> gifts) const override {
    TRY_RESULT(seqno, get_seqno());
    return make_a_gift_message_static(seqno, gifts);
  }
  size_t get_max_gifts_size() const override {
    return max_gifts_size;
  }

 private:
  td::Result<td::uint32> get_seqno_or_throw() const;
};
}  // namespace ton
