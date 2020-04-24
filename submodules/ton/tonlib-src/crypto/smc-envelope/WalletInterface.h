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

#include "td/utils/common.h"
#include "Ed25519.h"
#include "block/block.h"
#include "vm/cells/CellString.h"

#include "SmartContract.h"
#include "GenericAccount.h"

namespace ton {
class WalletInterface {
 public:
  struct Gift {
    block::StdAddress destination;
    td::int64 gramms;

    bool is_encrypted{false};
    std::string message;

    td::Ref<vm::Cell> body;
    td::Ref<vm::Cell> init_state;
  };

  virtual ~WalletInterface() {
  }

  virtual size_t get_max_gifts_size() const = 0;
  virtual td::Result<td::Ref<vm::Cell>> make_a_gift_message(const td::Ed25519::PrivateKey &private_key,
                                                            td::uint32 valid_until, td::Span<Gift> gifts) const = 0;
  virtual td::Result<td::Ed25519::PublicKey> get_public_key() const {
    return td::Status::Error("Unsupported");
  }

  td::Result<td::Ref<vm::Cell>> get_init_message(
      const td::Ed25519::PrivateKey &private_key,
      td::uint32 valid_until = std::numeric_limits<td::uint32>::max()) const {
    return make_a_gift_message(private_key, valid_until, {});
  }
  static td::Ref<vm::Cell> create_int_message(const Gift &gift) {
    vm::CellBuilder cbi;
    GenericAccount::store_int_message(cbi, gift.destination, gift.gramms < 0 ? 0 : gift.gramms);
    if (gift.init_state.not_null()) {
      cbi.store_ones(2);
      cbi.store_ref(gift.init_state);
    } else {
      cbi.store_zeroes(1);
    }
    cbi.store_zeroes(1);
    store_gift_message(cbi, gift);
    return cbi.finalize();
  }
  static void store_gift_message(vm::CellBuilder &cb, const Gift &gift) {
    if (gift.body.not_null()) {
      auto body = vm::load_cell_slice(gift.body);
      //TODO: handle error
      CHECK(cb.append_cellslice_bool(body));
      return;
    }

    if (gift.is_encrypted) {
      cb.store_long(1, 32);
    } else {
      cb.store_long(0, 32);
    }
    vm::CellString::store(cb, gift.message, 35 * 8).ensure();
  }
};

}  // namespace ton
