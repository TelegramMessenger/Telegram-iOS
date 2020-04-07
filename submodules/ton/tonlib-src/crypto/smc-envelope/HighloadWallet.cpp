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
#include "HighloadWallet.h"
#include "GenericAccount.h"
#include "SmartContractCode.h"

#include "vm/boc.h"
#include "vm/cells/CellString.h"
#include "td/utils/base64.h"

#include <limits>

namespace ton {
td::optional<td::int32> HighloadWallet::guess_revision(const vm::Cell::Hash& code_hash) {
  for (td::int32 i = 1; i <= 2; i++) {
    if (get_init_code(i)->get_hash() == code_hash) {
      return i;
    }
  }
  return {};
}
td::optional<td::int32> HighloadWallet::guess_revision(const block::StdAddress& address,
                                                       const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id) {
  for (td::int32 i = 1; i <= 2; i++) {
    if (GenericAccount::get_address(address.workchain, get_init_state(public_key, wallet_id, i)) == address) {
      return i;
    }
  }
  return {};
}
td::Ref<vm::Cell> HighloadWallet::get_init_state(const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id,
                                                 td::int32 revision) noexcept {
  auto code = get_init_code(revision);
  auto data = get_init_data(public_key, wallet_id);
  return GenericAccount::get_init_state(std::move(code), std::move(data));
}

td::Ref<vm::Cell> HighloadWallet::get_init_message(const td::Ed25519::PrivateKey& private_key,
                                                   td::uint32 wallet_id) noexcept {
  td::uint32 seqno = 0;
  td::uint32 valid_until = std::numeric_limits<td::uint32>::max();
  auto append_message = [&](auto&& cb) -> vm::CellBuilder& {
    cb.store_long(wallet_id, 32).store_long(valid_until, 32).store_long(seqno, 32);
    CHECK(cb.store_maybe_ref({}));
    return cb;
  };
  auto signature = private_key.sign(append_message(vm::CellBuilder()).finalize()->get_hash().as_slice()).move_as_ok();

  return append_message(vm::CellBuilder().store_bytes(signature)).finalize();
}

td::Ref<vm::Cell> HighloadWallet::make_a_gift_message(const td::Ed25519::PrivateKey& private_key, td::uint32 wallet_id,
                                                      td::uint32 seqno, td::uint32 valid_until,
                                                      td::Span<Gift> gifts) noexcept {
  CHECK(gifts.size() <= max_gifts_size);
  vm::Dictionary messages(16);
  for (size_t i = 0; i < gifts.size(); i++) {
    auto& gift = gifts[i];
    td::int32 send_mode = 3;
    auto gramms = gift.gramms;
    if (gramms == -1) {
      gramms = 0;
      send_mode += 128;
    }
    vm::CellBuilder cb;
    GenericAccount::store_int_message(cb, gift.destination, gramms);
    cb.store_bytes("\0\0\0\0", 4);
    vm::CellString::store(cb, gift.message, 35 * 8).ensure();
    auto message_inner = cb.finalize();
    cb = {};
    cb.store_long(send_mode, 8).store_ref(message_inner);
    auto key = messages.integer_key(td::make_refint(i), 16, false);
    messages.set_builder(key.bits(), 16, cb);
  }

  vm::CellBuilder cb;
  cb.store_long(wallet_id, 32).store_long(valid_until, 32).store_long(seqno, 32);
  CHECK(cb.store_maybe_ref(messages.get_root_cell()));
  auto message_outer = cb.finalize();
  auto signature = private_key.sign(message_outer->get_hash().as_slice()).move_as_ok();
  return vm::CellBuilder().store_bytes(signature).append_cellslice(vm::load_cell_slice(message_outer)).finalize();
}

td::Ref<vm::Cell> HighloadWallet::get_init_code(td::int32 revision) noexcept {
  return SmartContractCode::get_code(SmartContractCode::HighloadWalletV1, revision);
}

vm::CellHash HighloadWallet::get_init_code_hash() noexcept {
  return get_init_code(0)->get_hash();
}

td::Ref<vm::Cell> HighloadWallet::get_init_data(const td::Ed25519::PublicKey& public_key,
                                                td::uint32 wallet_id) noexcept {
  return vm::CellBuilder()
      .store_long(0, 32)
      .store_long(wallet_id, 32)
      .store_bytes(public_key.as_octet_string())
      .finalize();
}

td::Result<td::uint32> HighloadWallet::get_seqno() const {
  return TRY_VM(get_seqno_or_throw());
}

td::Result<td::uint32> HighloadWallet::get_seqno_or_throw() const {
  if (state_.data.is_null()) {
    return 0;
  }
  //FIXME use get method
  return static_cast<td::uint32>(vm::load_cell_slice(state_.data).fetch_ulong(32));
}

td::Result<td::uint32> HighloadWallet::get_wallet_id() const {
  return TRY_VM(get_wallet_id_or_throw());
}

td::Result<td::uint32> HighloadWallet::get_wallet_id_or_throw() const {
  if (state_.data.is_null()) {
    return 0;
  }
  //FIXME use get method
  auto cs = vm::load_cell_slice(state_.data);
  cs.skip_first(32);
  return static_cast<td::uint32>(cs.fetch_ulong(32));
}

td::Result<td::Ed25519::PublicKey> HighloadWallet::get_public_key() const {
  return TRY_VM(get_public_key_or_throw());
}

td::Result<td::Ed25519::PublicKey> HighloadWallet::get_public_key_or_throw() const {
  if (state_.data.is_null()) {
    return td::Status::Error("data is null");
  }
  //FIXME use get method
  auto cs = vm::load_cell_slice(state_.data);
  cs.skip_first(64);
  td::SecureString res(td::Ed25519::PublicKey::LENGTH);
  cs.fetch_bytes(res.as_mutable_slice().ubegin(), td::narrow_cast<td::int32>(res.size()));
  return td::Ed25519::PublicKey(std::move(res));
}

}  // namespace ton
