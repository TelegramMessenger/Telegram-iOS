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

#include "smc-envelope/SmartContract.h"
#include "smc-envelope/WalletInterface.h"
#include "vm/cells.h"
#include "Ed25519.h"
#include "block/block.h"
#include "vm/cells/CellString.h"

namespace ton {
class WalletV3 : public ton::SmartContract, public WalletInterface {
 public:
  explicit WalletV3(State state) : ton::SmartContract(std::move(state)) {
  }
  explicit WalletV3(const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id, td::uint32 seqno = 0)
      : WalletV3(State{get_init_code(), get_init_data(public_key, wallet_id, seqno)}) {
  }
  static constexpr unsigned max_message_size = vm::CellString::max_bytes;
  static constexpr unsigned max_gifts_size = 4;

  static td::optional<td::int32> guess_revision(const vm::Cell::Hash& code_hash);
  static td::optional<td::int32> guess_revision(const block::StdAddress& address,
                                                const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id);
  static td::Ref<vm::Cell> get_init_state(const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id,
                                          td::int32 revision = 0) noexcept;
  static td::Ref<vm::Cell> make_a_gift_message(const td::Ed25519::PrivateKey& private_key, td::uint32 wallet_id,
                                               td::uint32 seqno, td::uint32 valid_until, td::Span<Gift> gifts) noexcept;

  static td::Ref<vm::Cell> get_init_code(td::int32 revision = 0) noexcept;
  static vm::CellHash get_init_code_hash() noexcept;
  static td::Ref<vm::Cell> get_init_data(const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id,
                                         td::uint32 seqno = 0) noexcept;

  td::Result<td::uint32> get_seqno() const;
  td::Result<td::uint32> get_wallet_id() const;

  using WalletInterface::get_init_message;
  td::Result<td::Ref<vm::Cell>> make_a_gift_message(const td::Ed25519::PrivateKey& private_key, td::uint32 valid_until,
                                                    td::Span<Gift> gifts) const override {
    TRY_RESULT(seqno, get_seqno());
    TRY_RESULT(wallet_id, get_wallet_id());
    return make_a_gift_message(private_key, wallet_id, seqno, valid_until, gifts);
  }
  size_t get_max_gifts_size() const override {
    return max_gifts_size;
  }
  td::Result<td::Ed25519::PublicKey> get_public_key() const override;

 private:
  td::Result<td::uint32> get_seqno_or_throw() const;
  td::Result<td::uint32> get_wallet_id_or_throw() const;
  td::Result<td::Ed25519::PublicKey> get_public_key_or_throw() const;
};
}  // namespace ton
