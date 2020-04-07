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
#include "tonlib/Wallet.h"
#include "tonlib/CellString.h"
#include "tonlib/GenericAccount.h"
#include "tonlib/utils.h"

#include "vm/boc.h"
#include "td/utils/base64.h"

#include <limits>

namespace tonlib {
td::Ref<vm::Cell> Wallet::get_init_state(const td::Ed25519::PublicKey& public_key) noexcept {
  auto code = get_init_code();
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
                                              td::uint32 valid_until, td::int64 gramms, td::Slice message,
                                              const block::StdAddress& dest_address) noexcept {
  td::BigInt256 dest_addr;
  dest_addr.import_bits(dest_address.addr.as_bitslice());
  vm::CellBuilder cb;
  cb.append_cellslice(binary_bitstring_to_cellslice("b{01}").move_as_ok())
      .store_long(dest_address.bounceable, 1)
      .append_cellslice(binary_bitstring_to_cellslice("b{000100}").move_as_ok())
      .store_long(dest_address.workchain, 8)
      .store_int256(dest_addr, 256);
  td::int32 send_mode = 3;
  if (gramms == -1) {
    gramms = 0;
    send_mode += 128;
  }
  block::tlb::t_Grams.store_integer_value(cb, td::BigInt256(gramms));
  cb.store_zeroes(9 + 64 + 32 + 1 + 1).store_bytes("\0\0\0\0", 4);
  vm::CellString::store(cb, message, 35 * 8).ensure();
  auto message_inner = cb.finalize();
  auto message_outer = vm::CellBuilder()
                           .store_long(seqno, 32)
                           .store_long(valid_until, 32)
                           .store_long(send_mode, 8)
                           .store_ref(message_inner)
                           .finalize();
  std::string seq_no(4, 0);
  auto signature = private_key.sign(message_outer->get_hash().as_slice()).move_as_ok();
  return vm::CellBuilder().store_bytes(signature).append_cellslice(vm::load_cell_slice(message_outer)).finalize();
}

td::Ref<vm::Cell> Wallet::get_init_code() noexcept {
  static auto res = [] {
    auto serialized_code = td::base64_decode(
                               "te6ccgEEAQEAAAAAVwAAqv8AIN0gggFMl7qXMO1E0NcLH+Ck8mCDCNcYINMf0x8B+CO78mPtRNDTH9P/"
                               "0VExuvKhA/kBVBBC+RDyovgAApMg10qW0wfUAvsA6NGkyMsfy//J7VQ=")
                               .move_as_ok();
    return vm::std_boc_deserialize(serialized_code).move_as_ok();
  }();
  return res;
}

vm::CellHash Wallet::get_init_code_hash() noexcept {
  return get_init_code()->get_hash();
}

td::Ref<vm::Cell> Wallet::get_init_data(const td::Ed25519::PublicKey& public_key) noexcept {
  return vm::CellBuilder().store_long(0, 32).store_bytes(public_key.as_octet_string()).finalize();
}
}  // namespace tonlib
