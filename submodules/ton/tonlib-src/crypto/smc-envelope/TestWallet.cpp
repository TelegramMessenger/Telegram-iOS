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
#include "TestWallet.h"
#include "GenericAccount.h"

#include "vm/boc.h"
#include "td/utils/base64.h"

namespace ton {
td::Ref<vm::Cell> TestWallet::get_init_state(const td::Ed25519::PublicKey& public_key) noexcept {
  auto code = get_init_code();
  auto data = get_init_data(public_key);
  return GenericAccount::get_init_state(std::move(code), std::move(data));
}

td::Ref<vm::Cell> TestWallet::get_init_message(const td::Ed25519::PrivateKey& private_key) noexcept {
  std::string seq_no(4, 0);
  auto signature =
      private_key.sign(vm::CellBuilder().store_bytes(seq_no).finalize()->get_hash().as_slice()).move_as_ok();
  return vm::CellBuilder().store_bytes(signature).store_bytes(seq_no).finalize();
}

td::Ref<vm::Cell> TestWallet::make_a_gift_message(const td::Ed25519::PrivateKey& private_key, td::uint32 seqno,
                                                  td::int64 gramms, td::Slice message,
                                                  const block::StdAddress& dest_address) noexcept {
  td::int32 send_mode = 3;
  if (gramms == -1) {
    gramms = 0;
    send_mode += 128;
  }
  vm::CellBuilder cb;
  GenericAccount::store_int_message(cb, dest_address, gramms);
  cb.store_bytes("\0\0\0\0", 4);
  vm::CellString::store(cb, message, 35 * 8).ensure();
  auto message_inner = cb.finalize();
  auto message_outer =
      vm::CellBuilder().store_long(seqno, 32).store_long(send_mode, 8).store_ref(message_inner).finalize();
  auto signature = private_key.sign(message_outer->get_hash().as_slice()).move_as_ok();
  return vm::CellBuilder().store_bytes(signature).append_cellslice(vm::load_cell_slice(message_outer)).finalize();
}

td::Ref<vm::Cell> TestWallet::get_init_code() noexcept {
  static auto res = [] {
    auto serialized_code = td::base64_decode(
                               "te6ccgEEAQEAAAAAUwAAov8AIN0gggFMl7qXMO1E0NcLH+Ck8mCBAgDXGCDXCx/tRNDTH9P/"
                               "0VESuvKhIvkBVBBE+RDyovgAAdMfMSDXSpbTB9QC+wDe0aTIyx/L/8ntVA==")
                               .move_as_ok();
    return vm::std_boc_deserialize(serialized_code).move_as_ok();
  }();
  return res;
}

vm::CellHash TestWallet::get_init_code_hash() noexcept {
  return get_init_code()->get_hash();
}

td::Ref<vm::Cell> TestWallet::get_init_data(const td::Ed25519::PublicKey& public_key) noexcept {
  return vm::CellBuilder().store_long(0, 32).store_bytes(public_key.as_octet_string()).finalize();
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

}  // namespace ton
