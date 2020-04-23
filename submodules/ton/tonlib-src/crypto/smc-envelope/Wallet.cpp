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
#include "Wallet.h"
#include "GenericAccount.h"
#include "SmartContractCode.h"

#include "vm/boc.h"
#include "vm/cells/CellString.h"
#include "td/utils/base64.h"

#include <limits>

namespace ton {
td::Ref<vm::Cell> Wallet::get_init_state(const td::Ed25519::PublicKey& public_key, td::int32 revision) noexcept {
  auto code = get_init_code(revision);
  auto data = get_init_data(public_key);
  return GenericAccount::get_init_state(std::move(code), std::move(data));
}

td::Ref<vm::Cell> Wallet::get_init_message(const td::Ed25519::PrivateKey& private_key) noexcept {
  td::uint32 seqno = 0;
  td::uint32 valid_until = std::numeric_limits<td::uint32>::max();
  auto signature =
      private_key
          .sign(vm::CellBuilder().store_long(seqno, 32).store_long(valid_until, 32).finalize()->get_hash().as_slice())
          .move_as_ok();
  return vm::CellBuilder().store_bytes(signature).store_long(seqno, 32).store_long(valid_until, 32).finalize();
}

td::Ref<vm::Cell> Wallet::make_a_gift_message(const td::Ed25519::PrivateKey& private_key, td::uint32 seqno,
                                              td::uint32 valid_until, td::Span<Gift> gifts) noexcept {
  CHECK(gifts.size() <= max_gifts_size);

  vm::CellBuilder cb;
  cb.store_long(seqno, 32).store_long(valid_until, 32);

  for (auto& gift : gifts) {
    td::int32 send_mode = 3;
    if (gift.gramms == -1) {
      send_mode += 128;
    }
    cb.store_long(send_mode, 8).store_ref(create_int_message(gift));
  }

  auto message_outer = cb.finalize();
  auto signature = private_key.sign(message_outer->get_hash().as_slice()).move_as_ok();
  return vm::CellBuilder().store_bytes(signature).append_cellslice(vm::load_cell_slice(message_outer)).finalize();
}

td::Ref<vm::Cell> Wallet::get_init_code(td::int32 revision) noexcept {
  return SmartContractCode::get_code(ton::SmartContractCode::WalletV2, revision);
}

vm::CellHash Wallet::get_init_code_hash() noexcept {
  return get_init_code()->get_hash();
}

td::Ref<vm::Cell> Wallet::get_data(const td::Ed25519::PublicKey& public_key, td::uint32 seqno) noexcept {
  return vm::CellBuilder().store_long(seqno, 32).store_bytes(public_key.as_octet_string()).finalize();
}

td::Ref<vm::Cell> Wallet::get_init_data(const td::Ed25519::PublicKey& public_key) noexcept {
  return get_data(public_key, 0);
}

td::Result<td::uint32> Wallet::get_seqno() const {
  return TRY_VM(get_seqno_or_throw());
}

td::Result<td::uint32> Wallet::get_seqno_or_throw() const {
  if (state_.data.is_null()) {
    return 0;
  }
  //FIXME use get method
  return static_cast<td::uint32>(vm::load_cell_slice(state_.data).fetch_ulong(32));
}

td::Result<td::Ed25519::PublicKey> Wallet::get_public_key() const {
  return TRY_VM(get_public_key_or_throw());
}

td::Result<td::Ed25519::PublicKey> Wallet::get_public_key_or_throw() const {
  if (state_.data.is_null()) {
    return td::Status::Error("data is null");
  }
  //FIXME use get method
  auto cs = vm::load_cell_slice(state_.data);
  cs.skip_first(32);
  td::SecureString res(td::Ed25519::PublicKey::LENGTH);
  cs.fetch_bytes(res.as_mutable_slice().ubegin(), td::narrow_cast<td::int32>(res.size()));
  return td::Ed25519::PublicKey(std::move(res));
}

}  // namespace ton
