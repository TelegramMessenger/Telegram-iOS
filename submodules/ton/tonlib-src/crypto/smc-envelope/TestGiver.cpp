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
#include "TestGiver.h"
#include "GenericAccount.h"

#include "td/utils/base64.h"

namespace ton {
const block::StdAddress& TestGiver::address() noexcept {
  static block::StdAddress res =
      block::StdAddress::parse("kf_8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15-KsQHFLbKSMiYIny").move_as_ok();
  //static block::StdAddress res =
  //block::StdAddress::parse("kf9tswzQaryeJ4aAYLy_phLhx4afF1aEvpUVak-2BuA0CmZi").move_as_ok();
  return res;
}

vm::CellHash TestGiver::get_init_code_hash() noexcept {
  return vm::CellHash::from_slice(td::base64_decode("wDkZp0yR4xo+9+BnuAPfGVjBzK6FPzqdv2DwRq3z3KE=").move_as_ok());
  //return vm::CellHash::from_slice(td::base64_decode("YV/IANhoI22HVeatFh6S5LbCHp+5OilARfzW+VQPZgQ=").move_as_ok());
}

td::Ref<vm::Cell> TestGiver::make_a_gift_message_static(td::uint32 seqno, td::Span<Gift> gifts) noexcept {
  CHECK(gifts.size() <= max_gifts_size);

  vm::CellBuilder cb;
  cb.store_long(seqno, 32);

  for (auto& gift : gifts) {
    td::int32 send_mode = 1;
    cb.store_long(send_mode, 8).store_ref(create_int_message(gift));
  }

  return cb.finalize();
}

td::Result<td::uint32> TestGiver::get_seqno() const {
  return TRY_VM(get_seqno_or_throw());
}

td::Result<td::uint32> TestGiver::get_seqno_or_throw() const {
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
