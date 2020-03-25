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

namespace ton {
class WalletInterface {
 public:
  struct Gift {
    block::StdAddress destination;
    td::int64 gramms;

    bool is_encrypted{false};
    std::string message;

    td::Ref<vm::Cell> body;
  };

  virtual ~WalletInterface() {
  }

  virtual size_t get_max_gifts_size() const = 0;
  virtual td::Result<td::Ref<vm::Cell>> make_a_gift_message(const td::Ed25519::PrivateKey &private_key,
                                                            td::uint32 valid_until, td::Span<Gift> gifts) const = 0;
  virtual td::Result<td::Ed25519::PublicKey> get_public_key() const {
    return td::Status::Error("Unsupported");
  }

  td::Result<td::Ref<vm::Cell>> get_init_message(const td::Ed25519::PrivateKey &private_key,
                                                 td::uint32 valid_until = std::numeric_limits<td::uint32>::max()) {
    return make_a_gift_message(private_key, valid_until, {});
  }
  static void store_gift_message(vm::CellBuilder &cb, const Gift &gift) {
    if (gift.body.not_null()) {
      auto body = vm::load_cell_slice(gift.body);
      //TODO: handle error
      cb.append_cellslice_bool(body);
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
