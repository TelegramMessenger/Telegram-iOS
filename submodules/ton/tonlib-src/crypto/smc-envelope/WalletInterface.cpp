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
#include "WalletInterface.h"

#include "GenericAccount.h"

namespace ton {
td::Ref<vm::Cell> WalletInterfaceRaw::create_int_message(const Gift &gift) {
  vm::CellBuilder cbi;
  GenericAccount::store_int_message(cbi, gift.destination, gift.gramms < 0 ? 0 : gift.gramms);
  if (gift.init_state.not_null()) {
    cbi.store_ones(2);
    cbi.store_ref(gift.init_state);
  }
  cbi.store_zeroes(0);
  store_gift_message(cbi, gift);
  return cbi.finalize();
}

td::Result<td::Ed25519::PublicKey> WalletInterfaceRaw::get_public_key() const {
  auto sc = as_smart_constract();
  auto answer = sc.run_get_method("get_public_key");
  if (!answer.success) {
    return td::Status::Error("get_public_key failed");
  }
  auto do_get_public_key = [&]() -> td::Result<td::Ed25519::PublicKey> {
    auto key = answer.stack.write().pop_int_finite();
    td::SecureString bytes(32);
    if (!key->export_bytes(bytes.as_mutable_slice().ubegin(), bytes.size())) {
      return td::Status::Error("get_public_key failed");
    }
    return td::Ed25519::PublicKey(std::move(bytes));
  };
  return TRY_VM(do_get_public_key());
}
}  // namespace ton
