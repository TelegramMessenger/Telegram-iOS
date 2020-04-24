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

#include "smc-envelope/SmartContract.h"
#include "smc-envelope/WalletInterface.h"
#include "vm/cells.h"
#include "Ed25519.h"
#include "block/block.h"
#include "vm/cells/CellString.h"

namespace ton {
class WalletV3 : public ton::SmartContract, public WalletInterface {
 public:
  explicit WalletV3(State state) : ton::SmartContract(std::move(state)) {
  }
  explicit WalletV3(const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id, td::uint32 seqno = 0)
      : WalletV3(State{get_init_code(), get_init_data(public_key, wallet_id, seqno)}) {
  }
  static constexpr unsigned max_message_size = vm::CellString::max_bytes;
  static constexpr unsigned max_gifts_size = 4;

  static td::optional<td::int32> guess_revision(const vm::Cell::Hash& code_hash);
  static td::optional<td::int32> guess_revision(const block::StdAddress& address,
                                                const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id);
  static td::Ref<vm::Cell> get_init_state(const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id,
                                          td::int32 revision = 0) noexcept;
  static td::Ref<vm::Cell> make_a_gift_message(const td::Ed25519::PrivateKey& private_key, td::uint32 wallet_id,
                                               td::uint32 seqno, td::uint32 valid_until, td::Span<Gift> gifts) noexcept;

  static td::Ref<vm::Cell> get_init_code(td::int32 revision = 0) noexcept;
  static vm::CellHash get_init_code_hash() noexcept;
  static td::Ref<vm::Cell> get_init_data(const td::Ed25519::PublicKey& public_key, td::uint32 wallet_id,
                                         td::uint32 seqno = 0) noexcept;

  td::Result<td::uint32> get_seqno() const;
  td::Result<td::uint32> get_wallet_id() const;

  using WalletInterface::get_init_message;
  td::Result<td::Ref<vm::Cell>> make_a_gift_message(const td::Ed25519::PrivateKey& private_key, td::uint32 valid_until,
                                                    td::Span<Gift> gifts) const override {
    TRY_RESULT(seqno, get_seqno());
    TRY_RESULT(wallet_id, get_wallet_id());
    return make_a_gift_message(private_key, wallet_id, seqno, valid_until, gifts);
  }
  size_t get_max_gifts_size() const override {
    return max_gifts_size;
  }
  td::Result<td::Ed25519::PublicKey> get_public_key() const override;

 private:
  td::Result<td::uint32> get_seqno_or_throw() const;
  td::Result<td::uint32> get_wallet_id_or_throw() const;
  td::Result<td::Ed25519::PublicKey> get_public_key_or_throw() const;
};
}  // namespace ton

#include "smc-envelope/SmartContractCode.h"
#include "smc-envelope/GenericAccount.h"
#include "block/block-parse.h"
#include <algorithm>
namespace ton {
template <class WalletT, class TraitsT>
class WalletBase : public SmartContract, public WalletInterface {
 public:
  using Traits = TraitsT;
  using InitData = typename Traits::InitData;

  explicit WalletBase(State state) : SmartContract(std::move(state)) {
  }
  static td::Ref<WalletT> create(State state) {
    return td::Ref<WalletT>(true, std::move(state));
  }
  static td::Ref<vm::Cell> get_init_code(int revision) {
    return SmartContractCode::get_code(get_code_type(), revision);
  };
  size_t get_max_gifts_size() const override {
    return Traits::max_gifts_size;
  }
  static SmartContractCode::Type get_code_type() {
    return Traits::code_type;
  }
  static td::optional<td::int32> guess_revision(const vm::Cell::Hash& code_hash) {
    for (auto i : ton::SmartContractCode::get_revisions(get_code_type())) {
      auto code = SmartContractCode::get_code(get_code_type(), i);
      if (code->get_hash() == code_hash) {
        return i;
      }
    }
    return {};
  }

  static td::Ref<WalletT> create(const InitData& init_data, int revision) {
    return td::Ref<WalletT>(true, State{get_init_code(revision), WalletT::get_init_data(init_data)});
  }

  td::Result<td::uint32> get_seqno() const {
    return TRY_VM([&]() -> td::Result<td::uint32> {
      Answer answer = this->run_get_method("seqno");
      if (!answer.success) {
        return td::Status::Error("seqno get method failed");
      }
      return static_cast<td::uint32>(answer.stack.write().pop_long_range(std::numeric_limits<td::uint32>::max()));
    }());
  }
  td::Result<td::uint32> get_wallet_id() const {
    return TRY_VM([&]() -> td::Result<td::uint32> {
      Answer answer = this->run_get_method("wallet_id");
      if (!answer.success) {
        return td::Status::Error("seqno get method failed");
      }
      return static_cast<td::uint32>(answer.stack.write().pop_long_range(std::numeric_limits<td::uint32>::max()));
    }());
  }

  td::Result<td::uint64> get_balance(td::uint64 account_balance, td::uint32 now) const {
    return TRY_VM([&]() -> td::Result<td::uint64> {
      Answer answer = this->run_get_method(Args().set_method_id("balance").set_balance(account_balance).set_now(now));
      if (!answer.success) {
        return td::Status::Error("balance get method failed");
      }
      return static_cast<td::uint64>(answer.stack.write().pop_long());
    }());
  }

  td::Result<td::Ed25519::PublicKey> get_public_key() const override {
    return TRY_VM([&]() -> td::Result<td::Ed25519::PublicKey> {
      Answer answer = this->run_get_method("get_public_key");
      if (!answer.success) {
        return td::Status::Error("get_public_key get method failed");
      }
      auto key_int = answer.stack.write().pop_int();
      LOG(ERROR) << key_int->bit_size(false);
      td::SecureString bytes(32);
      if (!key_int->export_bytes(bytes.as_mutable_slice().ubegin(), bytes.size(), false)) {
        return td::Status::Error("not a public key");
      }
      return td::Ed25519::PublicKey(std::move(bytes));
    }());
  };
};

struct RestrictedWalletTraits {
  struct InitData {
    td::SecureString init_key;
    td::SecureString main_key;
    td::uint32 wallet_id{0};
  };

  static constexpr unsigned max_message_size = vm::CellString::max_bytes;
  static constexpr unsigned max_gifts_size = 4;
  static constexpr auto code_type = SmartContractCode::RestrictedWallet;
};

class RestrictedWallet : public WalletBase<RestrictedWallet, RestrictedWalletTraits> {
 public:
  struct Config {
    td::uint32 start_at{0};
    std::vector<std::pair<td::int32, td::uint64>> limits;
  };

  explicit RestrictedWallet(State state) : WalletBase(std::move(state)) {
  }

  td::Result<Config> get_config() const {
    return TRY_VM([this]() -> td::Result<Config> {
      auto cs = vm::load_cell_slice(get_state().data);
      Config config;
      td::Ref<vm::Cell> dict_root;
      auto ok = cs.advance(32 + 32 + 256) && cs.fetch_uint_to(32, config.start_at) && cs.fetch_maybe_ref(dict_root);
      vm::Dictionary dict(std::move(dict_root), 32);
      dict.check_for_each([&](auto cs, auto ptr, auto ptr_bits) {
        auto r_seconds = td::narrow_cast_safe<td::int32>(dict.key_as_integer(ptr, true)->to_long());
        if (r_seconds.is_error()) {
          ok = false;
          return ok;
        }
        td::uint64 value;
        ok &= smc::unpack_grams(cs, value);
        config.limits.emplace_back(r_seconds.ok(), value);
        return ok;
      });
      if (!ok) {
        return td::Status::Error("Can't parse config");
      }
      std::sort(config.limits.begin(), config.limits.end());
      return config;
    }());
  }

  static td::Ref<vm::Cell> get_init_data(const InitData& init_data) {
    vm::CellBuilder cb;
    cb.store_long(0, 32);
    cb.store_long(init_data.wallet_id, 32);
    CHECK(init_data.init_key.size() == 32);
    CHECK(init_data.main_key.size() == 32);
    cb.store_bytes(init_data.init_key.as_slice());
    cb.store_bytes(init_data.main_key.as_slice());
    return cb.finalize();
  }

  td::Result<td::Ref<vm::Cell>> get_init_message(const td::Ed25519::PrivateKey& init_private_key,
                                                 td::uint32 valid_until, const Config& config) const {
    vm::CellBuilder cb;
    TRY_RESULT(seqno, get_seqno());
    TRY_RESULT(wallet_id, get_wallet_id());
    LOG(ERROR) << "seqno: " << seqno << " wallet_id: " << wallet_id;
    if (seqno != 0) {
      return td::Status::Error("Wallet is already inited");
    }

    cb.store_long(wallet_id, 32);
    cb.store_long(valid_until, 32);
    cb.store_long(seqno, 32);

    cb.store_long(config.start_at, 32);
    vm::Dictionary dict(32);

    auto add = [&](td::int32 till, td::uint64 value) {
      auto key = dict.integer_key(td::make_refint(till), 32, true);
      vm::CellBuilder gcb;
      block::tlb::t_Grams.store_integer_value(gcb, td::BigInt256(value));
      dict.set_builder(key.bits(), 32, gcb);
    };
    for (auto limit : config.limits) {
      add(limit.first, limit.second);
    }
    cb.store_maybe_ref(dict.get_root_cell());

    auto message_outer = cb.finalize();
    auto signature = init_private_key.sign(message_outer->get_hash().as_slice()).move_as_ok();
    return vm::CellBuilder().store_bytes(signature).append_cellslice(vm::load_cell_slice(message_outer)).finalize();
  }

  td::Result<td::Ref<vm::Cell>> make_a_gift_message(const td::Ed25519::PrivateKey& private_key, td::uint32 valid_until,
                                                    td::Span<Gift> gifts) const override {
    CHECK(gifts.size() <= Traits::max_gifts_size);

    vm::CellBuilder cb;
    TRY_RESULT(seqno, get_seqno());
    TRY_RESULT(wallet_id, get_wallet_id());
    if (seqno == 0) {
      return td::Status::Error("Wallet is not inited yet");
    }
    cb.store_long(wallet_id, 32);
    cb.store_long(valid_until, 32);
    cb.store_long(seqno, 32);

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
};
}  // namespace ton
