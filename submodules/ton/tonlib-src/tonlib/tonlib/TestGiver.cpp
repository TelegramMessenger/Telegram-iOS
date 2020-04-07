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
#include "tonlib/TestGiver.h"
#include "tonlib/utils.h"

#include "td/utils/base64.h"

namespace tonlib {
const block::StdAddress& TestGiver::address() noexcept {
  static block::StdAddress res =
      block::StdAddress::parse("kf_8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15-KsQHFLbKSMiYIny").move_as_ok();
  return res;
}

vm::CellHash TestGiver::get_init_code_hash() noexcept {
  return vm::CellHash::from_slice(td::base64_decode("wDkZp0yR4xo+9+BnuAPfGVjBzK6FPzqdv2DwRq3z3KE=").move_as_ok());
}

td::Ref<vm::Cell> TestGiver::make_a_gift_message(td::uint32 seqno, td::uint64 gramms, td::Slice message,
                                                 const block::StdAddress& dest_address) noexcept {
  td::BigInt256 dest_addr;
  dest_addr.import_bits(dest_address.addr.as_bitslice());
  vm::CellBuilder cb;
  cb.append_cellslice(binary_bitstring_to_cellslice("b{01}").move_as_ok())
      .store_long(dest_address.bounceable, 1)
      .append_cellslice(binary_bitstring_to_cellslice("b{000100}").move_as_ok())
      .store_long(dest_address.workchain, 8)
      .store_int256(dest_addr, 256);
  block::tlb::t_Grams.store_integer_value(cb, td::BigInt256(gramms));

  cb.store_zeroes(9 + 64 + 32 + 1 + 1).store_bytes("\0\0\0\0", 4);
  vm::CellString::store(cb, message, 35 * 8).ensure();
  auto message_inner = cb.finalize();
  return vm::CellBuilder().store_long(seqno, 32).store_long(1, 8).store_ref(message_inner).finalize();
}
}  // namespace tonlib
