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
#include "TestWallet.h"
#include "GenericAccount.h"

#include "SmartContractCode.h"

#include "vm/boc.h"
#include "td/utils/base64.h"

namespace ton {
td::Ref<vm::Cell> TestWallet::get_init_state(const td::Ed25519::PublicKey& public_key, td::int32 revision) noexcept {
  auto code = get_init_code(revision);
  auto data = get_init_data(public_key);
  return GenericAccount::get_init_state(std::move(code), std::move(data));
}

td::Ref<vm::Cell> TestWallet::get_init_message(const td::Ed25519::PrivateKey& private_key) noexcept {
  std::string seq_no(4, 0);
  auto signature =
      private_key.sign(vm::CellBuilder().store_bytes(seq_no).finalize()->get_hash().as_slice()).move_as_ok();
  return vm::CellBuilder().store_bytes(signature).store_bytes(seq_no).finalize();
}

td::Ref<vm::Cell> TestWallet::make_a_gift_message_static(const td::Ed25519::PrivateKey& private_key, td::uint32 seqno,
                                                         td::Span<Gift> gifts) noexcept {
  CHECK(gifts.size() <= max_gifts_size);

  vm::CellBuilder cb;
  cb.store_long(seqno, 32);

  for (auto& gift : gifts) {
    td::int32 send_mode = 3;
    auto gramms = gift.gramms;
    if (gramms == -1) {
      gramms = 0;
      send_mode += 128;
    }
    vm::CellBuilder cbi;
    GenericAccount::store_int_message(cbi, gift.destination, gramms);
    store_gift_message(cbi, gift);
    auto message_inner = cbi.finalize();
    cb.store_long(send_mode, 8).store_ref(std::move(message_inner));
  }

  auto message_outer = cb.finalize();
  auto signature = private_key.sign(message_outer->get_hash().as_slice()).move_as_ok();
  return vm::CellBuilder().store_bytes(signature).append_cellslice(vm::load_cell_slice(message_outer)).finalize();
}

td::Ref<vm::Cell> TestWallet::get_init_code(td::int32 revision) noexcept {
  return ton::SmartContractCode::get_code(ton::SmartContractCode::WalletV1, revision);
}

vm::CellHash TestWallet::get_init_code_hash() noexcept {
  return get_init_code()->get_hash();
}

td::Ref<vm::Cell> TestWallet::get_data(const td::Ed25519::PublicKey& public_key, td::uint32 seqno) noexcept {
  return vm::CellBuilder().store_long(seqno, 32).store_bytes(public_key.as_octet_string()).finalize();
}

td::Ref<vm::Cell> TestWallet::get_init_data(const td::Ed25519::PublicKey& public_key) noexcept {
  return get_data(public_key, 0);
}

td::Result<td::uint32> TestWallet::get_seqno() const {
  return TRY_VM(get_seqno_or_throw());
}

td::Result<td::uint32> TestWallet::get_seqno_or_throw() const {
  if (state_.data.is_null()) {
    return 0;
  }
  auto seqno = vm::load_cell_slice(state_.data).fetch_ulong(32);
  if (seqno == vm::CellSlice::fetch_ulong_eof) {
    return td::Status::Error("Failed to parse seq_no");
  }
  return static_cast<td::uint32>(seqno);
}

td::Result<td::Ed25519::PublicKey> TestWallet::get_public_key() const {
  return TRY_VM(get_public_key_or_throw());
}

td::Result<td::Ed25519::PublicKey> TestWallet::get_public_key_or_throw() const {
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
