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
#include "TonlibClient.h"

#include "tonlib/ExtClientLazy.h"
#include "tonlib/ExtClientOutbound.h"
#include "tonlib/LastBlock.h"
#include "tonlib/LastConfig.h"
#include "tonlib/Logging.h"
#include "tonlib/utils.h"
#include "tonlib/keys/Mnemonic.h"
#include "tonlib/keys/SimpleEncryption.h"
#include "tonlib/TonlibError.h"

#include "smc-envelope/GenericAccount.h"
#include "smc-envelope/TestWallet.h"
#include "smc-envelope/Wallet.h"
#include "smc-envelope/WalletV3.h"
#include "smc-envelope/TestGiver.h"

#include "auto/tl/tonlib_api.hpp"
#include "block/block-auto.h"
#include "block/check-proof.h"
#include "ton/lite-tl.hpp"
#include "ton/ton-shard.h"

#include "vm/boc.h"

#include "td/utils/as.h"
#include "td/utils/Random.h"
#include "td/utils/optional.h"
#include "td/utils/overloaded.h"

#include "td/utils/tests.h"
#include "td/utils/port/path.h"

namespace tonlib {
namespace int_api {
struct GetAccountState {
  block::StdAddress address;
  using ReturnType = td::unique_ptr<AccountState>;
};
struct GetPrivateKey {
  KeyStorage::InputKey input_key;
  using ReturnType = KeyStorage::PrivateKey;
};
struct SendMessage {
  td::Ref<vm::Cell> message;
  using ReturnType = td::Unit;
};
}  // namespace int_api

class TonlibQueryActor : public td::actor::Actor {
 public:
  TonlibQueryActor(td::actor::ActorShared<TonlibClient> client) : client_(std::move(client)) {
  }
  template <class QueryT>
  void send_query(QueryT query, td::Promise<typename QueryT::ReturnType> promise) {
    td::actor::send_lambda(client_,
                           [self = client_.get(), query = std::move(query), promise = std::move(promise)]() mutable {
                             self.get_actor_unsafe().make_request(std::move(query), std::move(promise));
                           });
  }

 private:
  td::actor::ActorShared<TonlibClient> client_;
};

tonlib_api::object_ptr<tonlib_api::error> status_to_tonlib_api(const td::Status& status) {
  return tonlib_api::make_object<tonlib_api::error>(status.code(), status.message().str());
}

static block::AccountState create_account_state(ton::tl_object_ptr<ton::lite_api::liteServer_accountState> from) {
  block::AccountState res;
  res.blk = ton::create_block_id(from->id_);
  res.shard_blk = ton::create_block_id(from->shardblk_);
  res.shard_proof = std::move(from->shard_proof_);
  res.proof = std::move(from->proof_);
  res.state = std::move(from->state_);
  return res;
}
struct RawAccountState {
  td::int64 balance = -1;

  ton::UnixTime storage_last_paid{0};
  vm::CellStorageStat storage_stat;

  td::Ref<vm::Cell> code;
  td::Ref<vm::Cell> data;
  td::Ref<vm::Cell> state;
  std::string frozen_hash;
  block::AccountState::Info info;
};

tonlib_api::object_ptr<tonlib_api::internal_transactionId> empty_transaction_id() {
  return tonlib_api::make_object<tonlib_api::internal_transactionId>(0, std::string(32, 0));
}

tonlib_api::object_ptr<tonlib_api::internal_transactionId> to_transaction_id(const block::AccountState::Info& info) {
  return tonlib_api::make_object<tonlib_api::internal_transactionId>(info.last_trans_lt,
                                                                     info.last_trans_hash.as_slice().str());
}

std::string to_bytes(td::Ref<vm::Cell> cell) {
  return vm::std_boc_serialize(cell, vm::BagOfCells::Mode::WithCRC32C).move_as_ok().as_slice().str();
}

class AccountState {
 public:
  AccountState(block::StdAddress address, RawAccountState&& raw, td::uint32 wallet_id)
      : address_(std::move(address)), raw_(std::move(raw)), wallet_id_(wallet_id) {
    wallet_type_ = guess_type();
  }

  auto to_uninited_accountState() const {
    return tonlib_api::make_object<tonlib_api::uninited_accountState>(get_balance(), to_transaction_id(raw().info),
                                                                      raw().frozen_hash, get_sync_time());
  }

  td::Result<tonlib_api::object_ptr<tonlib_api::raw_accountState>> to_raw_accountState() const {
    auto state = get_smc_state();
    std::string code;
    if (state.code.not_null()) {
      code = to_bytes(state.code);
    }
    std::string data;
    if (state.data.not_null()) {
      data = to_bytes(state.data);
    }
    return tonlib_api::make_object<tonlib_api::raw_accountState>(get_balance(), std::move(code), std::move(data),
                                                                 to_transaction_id(raw().info), raw().frozen_hash,
                                                                 get_sync_time());
  }

  td::Result<tonlib_api::object_ptr<tonlib_api::testWallet_accountState>> to_testWallet_accountState() const {
    if (wallet_type_ != SimpleWallet) {
      return TonlibError::AccountTypeUnexpected("TestWallet");
    }
    TRY_RESULT(seqno, ton::TestWallet(get_smc_state()).get_seqno());
    return tonlib_api::make_object<tonlib_api::testWallet_accountState>(get_balance(), static_cast<td::uint32>(seqno),
                                                                        to_transaction_id(raw().info), get_sync_time());
  }

  td::Result<tonlib_api::object_ptr<tonlib_api::wallet_accountState>> to_wallet_accountState() const {
    if (wallet_type_ != Wallet) {
      return TonlibError::AccountTypeUnexpected("Wallet");
    }
    TRY_RESULT(seqno, ton::Wallet(get_smc_state()).get_seqno());
    return tonlib_api::make_object<tonlib_api::wallet_accountState>(get_balance(), static_cast<td::uint32>(seqno),
                                                                    to_transaction_id(raw().info), get_sync_time());
  }
  td::Result<tonlib_api::object_ptr<tonlib_api::wallet_v3_accountState>> to_wallet_v3_accountState() const {
    if (wallet_type_ != WalletV3) {
      return TonlibError::AccountTypeUnexpected("WalletV3");
    }
    auto wallet = ton::WalletV3(get_smc_state());
    TRY_RESULT(seqno, wallet.get_seqno());
    TRY_RESULT(wallet_id, wallet.get_wallet_id());
    return tonlib_api::make_object<tonlib_api::wallet_v3_accountState>(
        get_balance(), static_cast<td::uint32>(wallet_id), static_cast<td::uint32>(seqno),
        to_transaction_id(raw().info), get_sync_time());
  }

  td::Result<tonlib_api::object_ptr<tonlib_api::testGiver_accountState>> to_testGiver_accountState() const {
    if (wallet_type_ != Giver) {
      return TonlibError::AccountTypeUnexpected("TestGiver");
    }
    TRY_RESULT(seqno, ton::TestGiver(get_smc_state()).get_seqno());
    return tonlib_api::make_object<tonlib_api::testGiver_accountState>(get_balance(), static_cast<td::uint32>(seqno),
                                                                       to_transaction_id(raw().info), get_sync_time());
  }
  td::Result<tonlib_api::object_ptr<tonlib_api::generic_AccountState>> to_generic_accountState() const {
    switch (wallet_type_) {
      case Empty:
        return tonlib_api::make_object<tonlib_api::generic_accountStateUninited>(to_uninited_accountState());
      case Unknown: {
        TRY_RESULT(res, to_raw_accountState());
        return tonlib_api::make_object<tonlib_api::generic_accountStateRaw>(std::move(res));
      }
      case Giver: {
        TRY_RESULT(res, to_testGiver_accountState());
        return tonlib_api::make_object<tonlib_api::generic_accountStateTestGiver>(std::move(res));
      }
      case SimpleWallet: {
        TRY_RESULT(res, to_testWallet_accountState());
        return tonlib_api::make_object<tonlib_api::generic_accountStateTestWallet>(std::move(res));
      }
      case Wallet: {
        TRY_RESULT(res, to_wallet_accountState());
        return tonlib_api::make_object<tonlib_api::generic_accountStateWallet>(std::move(res));
      }
      case WalletV3: {
        TRY_RESULT(res, to_wallet_v3_accountState());
        return tonlib_api::make_object<tonlib_api::generic_accountStateWalletV3>(std::move(res));
      }
    }
    UNREACHABLE();
  }

  enum WalletType { Empty, Unknown, Giver, SimpleWallet, Wallet, WalletV3 };
  WalletType get_wallet_type() const {
    return wallet_type_;
  }
  bool is_frozen() const {
    return !raw_.frozen_hash.empty();
  }

  const block::StdAddress& get_address() const {
    return address_;
  }

  void make_non_bounceable() {
    address_.bounceable = false;
  }

  td::uint32 get_sync_time() const {
    return raw_.info.gen_utime;
  }

  td::int64 get_balance() const {
    return raw_.balance;
  }

  const RawAccountState& raw() const {
    return raw_;
  }

  WalletType guess_type_by_public_key(td::Ed25519::PublicKey& key) {
    if (wallet_type_ != WalletType::Empty) {
      return wallet_type_;
    }
    if (ton::GenericAccount::get_address(address_.workchain, ton::TestWallet::get_init_state(key)).addr ==
        address_.addr) {
      set_new_state({ton::TestWallet::get_init_code(), ton::TestWallet::get_init_data(key)});
      wallet_type_ = WalletType::SimpleWallet;
    } else if (ton::GenericAccount::get_address(address_.workchain, ton::Wallet::get_init_state(key)).addr ==
               address_.addr) {
      set_new_state({ton::Wallet::get_init_code(), ton::Wallet::get_init_data(key)});
      wallet_type_ = WalletType::Wallet;
    } else if (ton::GenericAccount::get_address(address_.workchain, ton::WalletV3::get_init_state(key, wallet_id_))
                   .addr == address_.addr) {
      set_new_state({ton::WalletV3::get_init_code(), ton::WalletV3::get_init_data(key, wallet_id_)});
      wallet_type_ = WalletType::WalletV3;
    }
    return wallet_type_;
  }

  WalletType guess_type_default(td::Ed25519::PublicKey& key) {
    if (wallet_type_ != WalletType::Empty) {
      return wallet_type_;
    }
    set_new_state({ton::WalletV3::get_init_code(), ton::WalletV3::get_init_data(key, wallet_id_)});
    wallet_type_ = WalletType::WalletV3;
    return wallet_type_;
  }

  ton::SmartContract::State get_smc_state() const {
    return {raw_.code, raw_.data};
  }

  td::Ref<vm::Cell> get_raw_state() {
    return raw_.state;
  }

  void set_new_state(ton::SmartContract::State state) {
    raw_.code = std::move(state.code);
    raw_.data = std::move(state.data);
    raw_.state = ton::GenericAccount::get_init_state(raw_.code, raw_.data);
    has_new_state_ = true;
  }

  td::Ref<vm::Cell> get_new_state() const {
    if (!has_new_state_) {
      return {};
    }
    return raw_.state;
  }

 private:
  block::StdAddress address_;
  RawAccountState raw_;
  WalletType wallet_type_{Unknown};
  td::uint32 wallet_id_{0};
  bool has_new_state_{false};

  WalletType guess_type() const {
    if (raw_.code.is_null()) {
      return WalletType::Empty;
    }
    auto code_hash = raw_.code->get_hash();
    if (code_hash == ton::TestGiver::get_init_code_hash()) {
      return WalletType::Giver;
    }
    if (code_hash == ton::TestWallet::get_init_code_hash()) {
      return WalletType::SimpleWallet;
    }
    if (code_hash == ton::Wallet::get_init_code_hash()) {
      return WalletType::Wallet;
    }
    if (code_hash == ton::WalletV3::get_init_code_hash()) {
      return WalletType::WalletV3;
    }
    LOG(WARNING) << "Unknown code hash: " << td::base64_encode(code_hash.as_slice());
    return WalletType::Unknown;
  }
};

class Query {
 public:
  struct Raw {
    td::unique_ptr<AccountState> source;
    td::unique_ptr<AccountState> destination;

    td::uint32 valid_until{std::numeric_limits<td::uint32>::max()};

    td::Ref<vm::Cell> message;
    td::Ref<vm::Cell> new_state;
    td::Ref<vm::Cell> message_body;
  };

  Query(Raw&& raw) : raw_(std::move(raw)) {
  }

  td::Ref<vm::Cell> get_message() const {
    return raw_.message;
  }

  vm::CellHash get_body_hash() const {
    return raw_.message_body->get_hash();
  }

  td::uint32 get_valid_until() const {
    return raw_.valid_until;
  }

  // ported from block/transaction.cpp
  // TODO: reuse code
  static td::RefInt256 compute_threshold(const block::GasLimitsPrices& cfg) {
    auto gas_price256 = td::RefInt256{true, cfg.gas_price};
    if (cfg.gas_limit > cfg.flat_gas_limit) {
      return td::rshift(gas_price256 * (cfg.gas_limit - cfg.flat_gas_limit), 16, 1) +
             td::make_refint(cfg.flat_gas_price);
    } else {
      return td::make_refint(cfg.flat_gas_price);
    }
  }

  static td::uint64 gas_bought_for(td::RefInt256 nanograms, td::RefInt256 max_gas_threshold,
                                   const block::GasLimitsPrices& cfg) {
    if (nanograms.is_null() || sgn(nanograms) < 0) {
      return 0;
    }
    if (nanograms >= max_gas_threshold) {
      return cfg.gas_limit;
    }
    if (nanograms < cfg.flat_gas_price) {
      return 0;
    }
    auto gas_price256 = td::RefInt256{true, cfg.gas_price};
    auto res = td::div((std::move(nanograms) - cfg.flat_gas_price) << 16, gas_price256);
    return res->to_long() + cfg.flat_gas_limit;
  }

  static td::RefInt256 compute_gas_price(td::uint64 gas_used, const block::GasLimitsPrices& cfg) {
    auto gas_price256 = td::RefInt256{true, cfg.gas_price};
    return gas_used <= cfg.flat_gas_limit
               ? td::make_refint(cfg.flat_gas_price)
               : td::rshift(gas_price256 * (gas_used - cfg.flat_gas_limit), 16, 1) + cfg.flat_gas_price;
  }

  static vm::GasLimits compute_gas_limits(td::RefInt256 balance, const block::GasLimitsPrices& cfg) {
    vm::GasLimits res;
    // Compute gas limits
    if (false /*account.is_special*/) {
      res.gas_max = cfg.special_gas_limit;
    } else {
      res.gas_max = gas_bought_for(balance, compute_threshold(cfg), cfg);
    }
    res.gas_credit = 0;
    if (false /*trans_type != tr_ord*/) {
      // may use all gas that can be bought using remaining balance
      res.gas_limit = res.gas_max;
    } else {
      // originally use only gas bought using remaining message balance
      // if the message is "accepted" by the smart contract, the gas limit will be set to gas_max
      res.gas_limit = gas_bought_for(td::make_refint(0) /*msg balance remaining*/, compute_threshold(cfg), cfg);
      if (true /*!block::tlb::t_Message.is_internal(in_msg)*/) {
        // external messages carry no balance, give them some credit to check whether they are accepted
        res.gas_credit = std::min(static_cast<td::int64>(cfg.gas_credit), static_cast<td::int64>(res.gas_max));
      }
    }
    LOG(DEBUG) << "gas limits: max=" << res.gas_max << ", limit=" << res.gas_limit << ", credit=" << res.gas_credit;
    return res;
  }

  struct Fee {
    td::int64 in_fwd_fee{0};
    td::int64 storage_fee{0};
    td::int64 gas_fee{0};
    td::int64 fwd_fee{0};
    auto to_tonlib_api() const {
      return tonlib_api::make_object<tonlib_api::fees>(in_fwd_fee, storage_fee, gas_fee, fwd_fee);
    }
  };

  td::Result<td::int64> calc_fwd_fees(td::Ref<vm::Cell> list, const block::MsgPrices& msg_prices) {
    td::int64 res = 0;
    std::vector<td::Ref<vm::Cell>> actions;
    int n{0};
    int max_actions = 20;
    while (true) {
      actions.push_back(list);
      auto cs = load_cell_slice(std::move(list));
      if (!cs.size_ext()) {
        break;
      }
      if (!cs.have_refs()) {
        return td::Status::Error("action list invalid: entry found with data but no next reference");
      }
      list = cs.prefetch_ref();
      n++;
      if (n > max_actions) {
        return td::Status::Error(PSLICE() << "action list too long: more than " << max_actions << " actions");
      }
    }
    for (int i = n - 1; i >= 0; --i) {
      vm::CellSlice cs = load_cell_slice(actions[i]);
      CHECK(cs.fetch_ref().not_null());
      int tag = block::gen::t_OutAction.get_tag(cs);
      CHECK(tag >= 0);
      switch (tag) {
        case block::gen::OutAction::action_set_code:
          return td::Status::Error("estimate_fee: action_set_code unsupported");
        case block::gen::OutAction::action_send_msg: {
          block::gen::OutAction::Record_action_send_msg act_rec;
          // mode: +128 = attach all remaining balance, +64 = attach all remaining balance of the inbound message, +1 = pay message fees, +2 = skip if message cannot be sent
          if (!tlb::unpack_exact(cs, act_rec) || (act_rec.mode & ~0xe3) || (act_rec.mode & 0xc0) == 0xc0) {
            return td::Status::Error("estimate_fee: can't parse send_msg");
          }
          block::gen::MessageRelaxed::Record msg;
          if (!tlb::type_unpack_cell(act_rec.out_msg, block::gen::t_MessageRelaxed_Any, msg)) {
            return td::Status::Error("estimate_fee: can't parse send_msg");
          }
          vm::CellStorageStat sstat;                  // for message size
          sstat.add_used_storage(msg.init, true, 3);  // message init
          sstat.add_used_storage(msg.body, true, 3);  // message body (the root cell itself is not counted)
          res += msg_prices.compute_fwd_fees(sstat.cells, sstat.bits);
          break;
        }
        case block::gen::OutAction::action_reserve_currency:
          return td::Status::Error("estimate_fee: action_reserve_currency unsupported");
      }
    }
    return res;
  }
  td::Result<std::pair<Fee, Fee>> estimate_fees(bool ignore_chksig, const block::Config& cfg) {
    // gas fees
    bool is_masterchain = raw_.source->get_address().workchain == ton::masterchainId;
    bool dest_is_masterchain = raw_.destination && raw_.destination->get_address().workchain == ton::masterchainId;
    TRY_RESULT(gas_limits_prices, cfg.get_gas_limits_prices(is_masterchain));
    TRY_RESULT(dest_gas_limits_prices, cfg.get_gas_limits_prices(dest_is_masterchain));
    TRY_RESULT(msg_prices, cfg.get_msg_prices(is_masterchain || dest_is_masterchain));
    TRY_RESULT(storage_prices, cfg.get_storage_prices());

    auto storage_fee_256 = block::StoragePrices::compute_storage_fees(
        raw_.source->get_sync_time(), storage_prices, raw_.source->raw().storage_stat,
        raw_.source->raw().storage_last_paid, false, is_masterchain);
    auto storage_fee = storage_fee_256.is_null() ? 0 : storage_fee_256->to_long();

    auto dest_storage_fee_256 =
        raw_.destination ? block::StoragePrices::compute_storage_fees(
                               raw_.destination->get_sync_time(), storage_prices, raw_.destination->raw().storage_stat,
                               raw_.destination->raw().storage_last_paid, false, is_masterchain)
                         : td::make_refint(0);
    auto dest_storage_fee = dest_storage_fee_256.is_null() ? 0 : dest_storage_fee_256->to_long();

    auto smc = ton::SmartContract::create(raw_.source->get_smc_state());

    td::int64 in_fwd_fee = 0;
    {
      vm::CellStorageStat sstat;                      // for message size
      sstat.add_used_storage(raw_.message, true, 3);  // message init
      in_fwd_fee += msg_prices.compute_fwd_fees(sstat.cells, sstat.bits);
    }

    vm::GasLimits gas_limits = compute_gas_limits(td::make_refint(raw_.source->get_balance()), gas_limits_prices);
    auto res = smc.write().send_external_message(
        raw_.message_body, ton::SmartContract::Args().set_limits(gas_limits).set_ignore_chksig(ignore_chksig));
    td::int64 fwd_fee = 0;
    if (res.success) {
      //std::cerr << "new smart contract data: ";
      //load_cell_slice(res.new_state.data).print_rec(std::cerr);
      //std::cerr << "output actions: ";
      //int out_act_num = output_actions_count(res.actions);
      //block::gen::OutList{out_act_num}.print_ref(std::cerr, res.actions);

      TRY_RESULT_ASSIGN(fwd_fee, calc_fwd_fees(res.actions, msg_prices));
    }

    auto gas_fee = res.accepted ? compute_gas_price(res.gas_used, gas_limits_prices)->to_long() : 0;
    LOG(ERROR) << storage_fee << " " << in_fwd_fee << " " << gas_fee << " " << fwd_fee;

    Fee fee;
    fee.in_fwd_fee = in_fwd_fee;
    fee.storage_fee = storage_fee;
    fee.gas_fee = gas_fee;
    fee.fwd_fee = fwd_fee;

    Fee dst_fee;
    if (raw_.destination && raw_.destination->get_wallet_type() != AccountState::WalletType::Empty) {
      dst_fee.gas_fee = dest_gas_limits_prices.flat_gas_price;
      dst_fee.storage_fee = dest_storage_fee;
    }
    return std::make_pair(fee, dst_fee);
  }

 private:
  Raw raw_;
  static int output_actions_count(td::Ref<vm::Cell> list) {
    int i = -1;
    do {
      ++i;
      list = load_cell_slice(std::move(list)).prefetch_ref();
    } while (list.not_null());
    return i;
  }
};  // namespace tonlib

td::Result<td::int64> to_balance_or_throw(td::Ref<vm::CellSlice> balance_ref) {
  vm::CellSlice balance_slice = *balance_ref;
  auto balance = block::tlb::t_Grams.as_integer_skip(balance_slice);
  if (balance.is_null()) {
    return td::Status::Error("Failed to unpack balance");
  }
  auto res = balance->to_long();
  if (res == td::int64(~0ULL << 63)) {
    return td::Status::Error("Failed to unpack balance (2)");
  }
  return res;
}

td::Result<td::int64> to_balance(td::Ref<vm::CellSlice> balance_ref) {
  return TRY_VM(to_balance_or_throw(std::move(balance_ref)));
}

class GetTransactionHistory : public td::actor::Actor {
 public:
  GetTransactionHistory(ExtClientRef ext_client_ref, block::StdAddress address, ton::LogicalTime lt, ton::Bits256 hash,
                        td::actor::ActorShared<> parent, td::Promise<block::TransactionList::Info> promise)
      : address_(std::move(address))
      , lt_(std::move(lt))
      , hash_(std::move(hash))
      , parent_(std::move(parent))
      , promise_(std::move(promise)) {
    client_.set_client(ext_client_ref);
  }

 private:
  block::StdAddress address_;
  ton::LogicalTime lt_;
  ton::Bits256 hash_;
  ExtClient client_;
  td::int32 count_{10};
  td::actor::ActorShared<> parent_;
  td::Promise<block::TransactionList::Info> promise_;

  void check(td::Status status) {
    if (status.is_error()) {
      promise_.set_error(std::move(status));
      stop();
    }
  }

  void with_transactions(
      td::Result<ton::lite_api::object_ptr<ton::lite_api::liteServer_transactionList>> r_transactions) {
    check(do_with_transactions(std::move(r_transactions)));
    stop();
  }

  td::Status do_with_transactions(
      td::Result<ton::lite_api::object_ptr<ton::lite_api::liteServer_transactionList>> r_transactions) {
    TRY_RESULT(transactions, std::move(r_transactions));
    TRY_RESULT_PREFIX(info, TRY_VM(do_with_transactions(std::move(transactions))), TonlibError::ValidateTransactions());
    promise_.set_value(std::move(info));
    return td::Status::OK();
  }

  td::Result<block::TransactionList::Info> do_with_transactions(
      ton::lite_api::object_ptr<ton::lite_api::liteServer_transactionList> transactions) {
    std::vector<ton::BlockIdExt> blkids;
    for (auto& id : transactions->ids_) {
      blkids.push_back(ton::create_block_id(std::move(id)));
    }
    return do_with_transactions(std::move(blkids), std::move(transactions->transactions_));
  }

  td::Result<block::TransactionList::Info> do_with_transactions(std::vector<ton::BlockIdExt> blkids,
                                                                td::BufferSlice transactions) {
    //LOG(INFO) << "got up to " << count_ << " transactions for " << address_ << " from last transaction " << lt_ << ":"
    //<< hash_.to_hex();
    block::TransactionList list;
    list.blkids = std::move(blkids);
    list.hash = hash_;
    list.lt = lt_;
    list.transactions_boc = std::move(transactions);
    TRY_RESULT(info, list.validate());
    if (info.transactions.size() > static_cast<size_t>(count_)) {
      LOG(WARNING) << "obtained " << info.transactions.size() << " transaction, but only " << count_
                   << " have been requested";
    }
    return info;
  }

  void start_up() override {
    if (lt_ == 0) {
      promise_.set_value(block::TransactionList::Info());
      stop();
      return;
    }
    client_.send_query(
        ton::lite_api::liteServer_getTransactions(
            count_, ton::create_tl_object<ton::lite_api::liteServer_accountId>(address_.workchain, address_.addr), lt_,
            hash_),
        [self = this](auto r_transactions) { self->with_transactions(std::move(r_transactions)); });
  }
  void hangup() override {
    check(TonlibError::Cancelled());
  }
};

class GetRawAccountState : public td::actor::Actor {
 public:
  GetRawAccountState(ExtClientRef ext_client_ref, block::StdAddress address, td::actor::ActorShared<> parent,
                     td::Promise<RawAccountState>&& promise)
      : address_(std::move(address)), promise_(std::move(promise)), parent_(std::move(parent)) {
    client_.set_client(ext_client_ref);
  }

 private:
  block::StdAddress address_;
  td::Promise<RawAccountState> promise_;
  td::actor::ActorShared<> parent_;
  ExtClient client_;
  LastBlockState last_block_;

  void with_account_state(td::Result<ton::tl_object_ptr<ton::lite_api::liteServer_accountState>> r_account_state) {
    check(do_with_account_state(std::move(r_account_state)));
  }

  td::Status do_with_account_state(
      td::Result<ton::tl_object_ptr<ton::lite_api::liteServer_accountState>> r_raw_account_state) {
    TRY_RESULT(raw_account_state, std::move(r_raw_account_state));
    TRY_RESULT_PREFIX(state, TRY_VM(do_with_account_state(std::move(raw_account_state))),
                      TonlibError::ValidateAccountState());
    promise_.set_value(std::move(state));
    stop();
    return td::Status::OK();
  }

  td::Result<RawAccountState> do_with_account_state(
      ton::tl_object_ptr<ton::lite_api::liteServer_accountState> raw_account_state) {
    auto account_state = create_account_state(std::move(raw_account_state));
    TRY_RESULT(info, account_state.validate(last_block_.last_block_id, address_));
    auto serialized_state = account_state.state.clone();
    RawAccountState res;
    res.info = std::move(info);
    LOG_IF(ERROR, res.info.gen_utime > last_block_.utime) << res.info.gen_utime << " " << last_block_.utime;
    auto cell = res.info.root;
    std::ostringstream outp;
    block::gen::t_Account.print_ref(outp, cell);
    //LOG(INFO) << outp.str();
    if (cell.is_null()) {
      return res;
    }
    block::gen::Account::Record_account account;
    if (!tlb::unpack_cell(cell, account)) {
      return td::Status::Error("Failed to unpack Account");
    }
    {
      block::gen::StorageInfo::Record storage_info;
      if (!tlb::csr_unpack(account.storage_stat, storage_info)) {
        return td::Status::Error("Failed to unpack StorageInfo");
      }
      res.storage_last_paid = storage_info.last_paid;
      td::RefInt256 due_payment;
      if (storage_info.due_payment->prefetch_ulong(1) == 1) {
        vm::CellSlice& cs2 = storage_info.due_payment.write();
        cs2.advance(1);
        due_payment = block::tlb::t_Grams.as_integer_skip(cs2);
        if (due_payment.is_null() || !cs2.empty_ext()) {
          return td::Status::Error("Failed to upack due_payment");
        }
      } else {
        due_payment = td::RefInt256{true, 0};
      }
      block::gen::StorageUsed::Record storage_used;
      if (!tlb::csr_unpack(storage_info.used, storage_used)) {
        return td::Status::Error("Failed to unpack StorageInfo");
      }
      unsigned long long u = 0;
      vm::CellStorageStat storage_stat;
      u |= storage_stat.cells = block::tlb::t_VarUInteger_7.as_uint(*storage_used.cells);
      u |= storage_stat.bits = block::tlb::t_VarUInteger_7.as_uint(*storage_used.bits);
      u |= storage_stat.public_cells = block::tlb::t_VarUInteger_7.as_uint(*storage_used.public_cells);
      //LOG(DEBUG) << "last_paid=" << res.storage_last_paid << "; cells=" << storage_stat.cells
      //<< " bits=" << storage_stat.bits << " public_cells=" << storage_stat.public_cells;
      if (u == std::numeric_limits<td::uint64>::max()) {
        return td::Status::Error("Failed to unpack StorageStat");
      }

      res.storage_stat = storage_stat;
    }

    block::gen::AccountStorage::Record storage;
    if (!tlb::csr_unpack(account.storage, storage)) {
      return td::Status::Error("Failed to unpack AccountStorage");
    }
    TRY_RESULT(balance, to_balance(storage.balance));
    res.balance = balance;
    auto state_tag = block::gen::t_AccountState.get_tag(*storage.state);
    if (state_tag < 0) {
      return td::Status::Error("Failed to parse AccountState tag");
    }
    if (state_tag == block::gen::AccountState::account_frozen) {
      block::gen::AccountState::Record_account_frozen state;
      if (!tlb::csr_unpack(storage.state, state)) {
        return td::Status::Error("Failed to parse AccountState");
      }
      res.frozen_hash = state.state_hash.as_slice().str();
      return res;
    }
    if (state_tag != block::gen::AccountState::account_active) {
      return res;
    }
    block::gen::AccountState::Record_account_active state;
    if (!tlb::csr_unpack(storage.state, state)) {
      return td::Status::Error("Failed to parse AccountState");
    }
    block::gen::StateInit::Record state_init;
    res.state = vm::CellBuilder().append_cellslice(state.x).finalize();
    if (!tlb::csr_unpack(state.x, state_init)) {
      return td::Status::Error("Failed to parse StateInit");
    }
    state_init.code->prefetch_maybe_ref(res.code);
    state_init.data->prefetch_maybe_ref(res.data);
    return res;
  }

  void with_last_block(td::Result<LastBlockState> r_last_block) {
    check(do_with_last_block(std::move(r_last_block)));
  }

  td::Status do_with_last_block(td::Result<LastBlockState> r_last_block) {
    TRY_RESULT_ASSIGN(last_block_, std::move(r_last_block));
    client_.send_query(
        ton::lite_api::liteServer_getAccountState(
            ton::create_tl_lite_block_id(last_block_.last_block_id),
            ton::create_tl_object<ton::lite_api::liteServer_accountId>(address_.workchain, address_.addr)),
        [self = this](auto r_state) { self->with_account_state(std::move(r_state)); },
        last_block_.last_block_id.id.seqno);
    return td::Status::OK();
  }

  void start_up() override {
    client_.with_last_block(
        [self = this](td::Result<LastBlockState> r_last_block) { self->with_last_block(std::move(r_last_block)); });
  }

  void check(td::Status status) {
    if (status.is_error()) {
      promise_.set_error(std::move(status));
      stop();
    }
  }
  void hangup() override {
    check(TonlibError::Cancelled());
  }
};

TonlibClient::TonlibClient(td::unique_ptr<TonlibCallback> callback) : callback_(std::move(callback)) {
}
TonlibClient::~TonlibClient() = default;

void TonlibClient::hangup() {
  source_.cancel();
  is_closing_ = true;
  ref_cnt_--;
  raw_client_ = {};
  raw_last_block_ = {};
  raw_last_config_ = {};
  try_stop();
}

ExtClientRef TonlibClient::get_client_ref() {
  ExtClientRef ref;
  ref.andl_ext_client_ = raw_client_.get();
  ref.last_block_actor_ = raw_last_block_.get();
  ref.last_config_actor_ = raw_last_config_.get();

  return ref;
}

void TonlibClient::proxy_request(td::int64 query_id, std::string data) {
  on_update(tonlib_api::make_object<tonlib_api::updateSendLiteServerQuery>(query_id, data));
}

void TonlibClient::init_ext_client() {
  if (use_callbacks_for_network_) {
    class Callback : public ExtClientOutbound::Callback {
     public:
      explicit Callback(td::actor::ActorShared<TonlibClient> parent, td::uint32 config_generation)
          : parent_(std::move(parent)), config_generation_(config_generation) {
      }

      void request(td::int64 id, std::string data) override {
        send_closure(parent_, &TonlibClient::proxy_request, (id << 16) | (config_generation_ & 0xffff),
                     std::move(data));
      }

     private:
      td::actor::ActorShared<TonlibClient> parent_;
      td::uint32 config_generation_;
    };
    ref_cnt_++;
    auto client =
        ExtClientOutbound::create(td::make_unique<Callback>(td::actor::actor_shared(this), config_generation_));
    ext_client_outbound_ = client.get();
    raw_client_ = std::move(client);
  } else {
    auto lite_clients_size = config_.lite_clients.size();
    CHECK(lite_clients_size != 0);
    auto lite_client_id = td::Random::fast(0, td::narrow_cast<int>(lite_clients_size) - 1);
    auto& lite_client = config_.lite_clients[lite_client_id];
    class Callback : public ExtClientLazy::Callback {
     public:
      explicit Callback(td::actor::ActorShared<> parent) : parent_(std::move(parent)) {
      }

     private:
      td::actor::ActorShared<> parent_;
    };
    ext_client_outbound_ = {};
    ref_cnt_++;
    raw_client_ = ExtClientLazy::create(lite_client.adnl_id, lite_client.address,
                                        td::make_unique<Callback>(td::actor::actor_shared()));
  }
}

void TonlibClient::update_last_block_state(LastBlockState state, td::uint32 config_generation) {
  if (config_generation != config_generation_) {
    return;
  }

  last_block_storage_.save_state(blockchain_name_, state);
}

void TonlibClient::update_sync_state(LastBlockSyncState state, td::uint32 config_generation) {
  if (config_generation != config_generation_) {
    return;
  }
  switch (state.type) {
    case LastBlockSyncState::Done:
      on_update(
          tonlib_api::make_object<tonlib_api::updateSyncState>(tonlib_api::make_object<tonlib_api::syncStateDone>()));
      break;
    case LastBlockSyncState::InProgress:
      on_update(
          tonlib_api::make_object<tonlib_api::updateSyncState>(tonlib_api::make_object<tonlib_api::syncStateInProgress>(
              state.from_seqno, state.to_seqno, state.current_seqno)));
      break;
    default:
      LOG(ERROR) << "Unknown LastBlockSyncState type " << state.type;
  }
}

void TonlibClient::init_last_block(td::optional<Config> o_master_config) {
  ref_cnt_++;
  class Callback : public LastBlock::Callback {
   public:
    Callback(td::actor::ActorShared<TonlibClient> client, td::uint32 config_generation)
        : client_(std::move(client)), config_generation_(config_generation) {
    }
    void on_state_changed(LastBlockState state) override {
      send_closure(client_, &TonlibClient::update_last_block_state, std::move(state), config_generation_);
    }
    void on_sync_state_changed(LastBlockSyncState sync_state) override {
      send_closure(client_, &TonlibClient::update_sync_state, std::move(sync_state), config_generation_);
    }

   private:
    td::actor::ActorShared<TonlibClient> client_;
    td::uint32 config_generation_;
  };
  LastBlockState state;

  td::Result<LastBlockState> r_state;
  if (!ignore_cache_) {
    r_state = last_block_storage_.get_state(blockchain_name_);
  }
  if (ignore_cache_ || r_state.is_error()) {
    LOG_IF(WARNING, !ignore_cache_) << "Unknown LastBlockState: " << r_state.error();
    state.zero_state_id = ton::ZeroStateIdExt(config_.zero_state_id.id.workchain, config_.zero_state_id.root_hash,
                                              config_.zero_state_id.file_hash),
    state.last_block_id = config_.zero_state_id;
    state.last_key_block_id = config_.zero_state_id;
    last_block_storage_.save_state(blockchain_name_, state);
  } else {
    state = r_state.move_as_ok();
  }

  if (o_master_config) {
    auto master_config = o_master_config.unwrap();
    if (master_config.init_block_id.is_valid() &&
        state.last_key_block_id.id.seqno < master_config.init_block_id.id.seqno) {
      state.last_key_block_id = master_config.init_block_id;
      LOG(INFO) << "Use init block from MASTER config: " << master_config.init_block_id.to_str();
    }
  }

  raw_last_block_ = td::actor::create_actor<LastBlock>(
      td::actor::ActorOptions().with_name("LastBlock").with_poll(false), get_client_ref(), std::move(state), config_,
      source_.get_cancellation_token(), td::make_unique<Callback>(td::actor::actor_shared(this), config_generation_));
}
void TonlibClient::init_last_config() {
  ref_cnt_++;
  class Callback : public LastConfig::Callback {
   public:
    Callback(td::actor::ActorShared<TonlibClient> client) : client_(std::move(client)) {
    }

   private:
    td::actor::ActorShared<TonlibClient> client_;
  };
  raw_last_config_ =
      td::actor::create_actor<LastConfig>(td::actor::ActorOptions().with_name("LastConfig").with_poll(false),
                                          get_client_ref(), td::make_unique<Callback>(td::actor::actor_shared(this)));
}

void TonlibClient::on_result(td::uint64 id, tonlib_api::object_ptr<tonlib_api::Object> response) {
  VLOG_IF(tonlib_query, id != 0) << "Tonlib answer query " << td::tag("id", id) << " " << to_string(response);
  VLOG_IF(tonlib_query, id == 0) << "Tonlib update " << to_string(response);
  if (response->get_id() == tonlib_api::error::ID) {
    callback_->on_error(id, tonlib_api::move_object_as<tonlib_api::error>(response));
    return;
  }
  callback_->on_result(id, std::move(response));
}
void TonlibClient::on_update(object_ptr<tonlib_api::Object> response) {
  on_result(0, std::move(response));
}

void TonlibClient::request(td::uint64 id, tonlib_api::object_ptr<tonlib_api::Function> function) {
  VLOG(tonlib_query) << "Tonlib got query " << td::tag("id", id) << " " << to_string(function);
  if (function == nullptr) {
    LOG(ERROR) << "Receive empty static request";
    return on_result(id, tonlib_api::make_object<tonlib_api::error>(400, "Request is empty"));
  }

  if (is_static_request(function->get_id())) {
    return on_result(id, static_request(std::move(function)));
  }

  if (state_ == State::Closed) {
    return on_result(id, tonlib_api::make_object<tonlib_api::error>(400, "tonlib is closed"));
  }
  if (state_ == State::Uninited) {
    if (!is_uninited_request(function->get_id())) {
      return on_result(id, tonlib_api::make_object<tonlib_api::error>(400, "library is not inited"));
    }
  }

  downcast_call(*function, [this, self = this, id](auto& request) {
    using ReturnType = typename std::decay_t<decltype(request)>::ReturnType;
    ref_cnt_++;
    td::Promise<ReturnType> promise = [actor_id = actor_id(self), id,
                                       tmp = actor_shared(self)](td::Result<ReturnType> r_result) {
      tonlib_api::object_ptr<tonlib_api::Object> result;
      if (r_result.is_error()) {
        result = status_to_tonlib_api(r_result.error());
      } else {
        result = r_result.move_as_ok();
      }

      send_closure(actor_id, &TonlibClient::on_result, id, std::move(result));
    };
    this->make_request(request, std::move(promise));
  });
}
void TonlibClient::close() {
  stop();
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::static_request(
    tonlib_api::object_ptr<tonlib_api::Function> function) {
  VLOG(tonlib_query) << "Tonlib got static query " << to_string(function);
  if (function == nullptr) {
    LOG(ERROR) << "Receive empty static request";
    return tonlib_api::make_object<tonlib_api::error>(400, "Request is empty");
  }

  tonlib_api::object_ptr<tonlib_api::Object> response;
  downcast_call(*function, [&response](auto& request) { response = TonlibClient::do_static_request(request); });
  VLOG(tonlib_query) << "  answer static query " << to_string(response);
  return response;
}

bool TonlibClient::is_static_request(td::int32 id) {
  switch (id) {
    case tonlib_api::runTests::ID:
    case tonlib_api::raw_getAccountAddress::ID:
    case tonlib_api::testWallet_getAccountAddress::ID:
    case tonlib_api::wallet_getAccountAddress::ID:
    case tonlib_api::wallet_v3_getAccountAddress::ID:
    case tonlib_api::testGiver_getAccountAddress::ID:
    case tonlib_api::packAccountAddress::ID:
    case tonlib_api::unpackAccountAddress::ID:
    case tonlib_api::options_validateConfig::ID:
    case tonlib_api::getBip39Hints::ID:
    case tonlib_api::setLogStream::ID:
    case tonlib_api::getLogStream::ID:
    case tonlib_api::setLogVerbosityLevel::ID:
    case tonlib_api::getLogVerbosityLevel::ID:
    case tonlib_api::getLogTags::ID:
    case tonlib_api::setLogTagVerbosityLevel::ID:
    case tonlib_api::getLogTagVerbosityLevel::ID:
    case tonlib_api::addLogMessage::ID:
    case tonlib_api::encrypt::ID:
    case tonlib_api::decrypt::ID:
    case tonlib_api::kdf::ID:
      return true;
    default:
      return false;
  }
}
bool TonlibClient::is_uninited_request(td::int32 id) {
  switch (id) {
    case tonlib_api::init::ID:
    case tonlib_api::close::ID:
      return true;
    default:
      return false;
  }
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(const tonlib_api::runTests& request) {
  auto& runner = td::TestsRunner::get_default();
  if (!request.dir_.empty()) {
    td::chdir(request.dir_).ignore();
  }
  runner.run_all();
  return tonlib_api::make_object<tonlib_api::ok>();
}

td::Result<block::PublicKey> get_public_key(td::Slice public_key) {
  TRY_RESULT_PREFIX(address, block::PublicKey::parse(public_key), TonlibError::InvalidPublicKey());
  return address;
}

td::Result<block::StdAddress> get_account_address(const tonlib_api::raw_initialAccountState& raw_state) {
  TRY_RESULT_PREFIX(code, vm::std_boc_deserialize(raw_state.code_), TonlibError::InvalidBagOfCells("raw_state.code"));
  TRY_RESULT_PREFIX(data, vm::std_boc_deserialize(raw_state.data_), TonlibError::InvalidBagOfCells("raw_state.data"));
  return ton::GenericAccount::get_address(0 /*zerochain*/,
                                          ton::GenericAccount::get_init_state(std::move(code), std::move(data)));
}

td::Result<block::StdAddress> get_account_address(const tonlib_api::testWallet_initialAccountState& test_wallet_state) {
  TRY_RESULT(key_bytes, get_public_key(test_wallet_state.public_key_));
  auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));
  return ton::GenericAccount::get_address(0 /*zerochain*/, ton::TestWallet::get_init_state(key));
}

td::Result<block::StdAddress> get_account_address(const tonlib_api::wallet_initialAccountState& test_wallet_state) {
  TRY_RESULT(key_bytes, get_public_key(test_wallet_state.public_key_));
  auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));
  return ton::GenericAccount::get_address(0 /*zerochain*/, ton::Wallet::get_init_state(key));
}
td::Result<block::StdAddress> get_account_address(const tonlib_api::wallet_v3_initialAccountState& test_wallet_state) {
  TRY_RESULT(key_bytes, get_public_key(test_wallet_state.public_key_));
  auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));
  return ton::GenericAccount::get_address(
      0 /*zerochain*/, ton::WalletV3::get_init_state(key, static_cast<td::uint32>(test_wallet_state.wallet_id_)));
}

td::Result<block::StdAddress> get_account_address(td::Slice account_address) {
  TRY_RESULT_PREFIX(address, block::StdAddress::parse(account_address), TonlibError::InvalidAccountAddress());
  return address;
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::raw_getAccountAddress& request) {
  if (!request.initital_account_state_) {
    return status_to_tonlib_api(TonlibError::EmptyField("initial_account_state"));
  }
  auto r_account_address = get_account_address(*request.initital_account_state_);
  if (r_account_address.is_error()) {
    return status_to_tonlib_api(r_account_address.error());
  }
  return tonlib_api::make_object<tonlib_api::accountAddress>(r_account_address.ok().rserialize(true));
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::testWallet_getAccountAddress& request) {
  if (!request.initital_account_state_) {
    return status_to_tonlib_api(TonlibError::EmptyField("initial_account_state"));
  }
  if (!request.initital_account_state_) {
    return status_to_tonlib_api(TonlibError::EmptyField("initial_account_state"));
  }
  auto r_account_address = get_account_address(*request.initital_account_state_);
  if (r_account_address.is_error()) {
    return status_to_tonlib_api(r_account_address.error());
  }
  return tonlib_api::make_object<tonlib_api::accountAddress>(r_account_address.ok().rserialize(true));
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::wallet_getAccountAddress& request) {
  if (!request.initital_account_state_) {
    return status_to_tonlib_api(TonlibError::EmptyField("initial_account_state"));
  }
  auto r_account_address = get_account_address(*request.initital_account_state_);
  if (r_account_address.is_error()) {
    return status_to_tonlib_api(r_account_address.error());
  }
  return tonlib_api::make_object<tonlib_api::accountAddress>(r_account_address.ok().rserialize(true));
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::wallet_v3_getAccountAddress& request) {
  if (!request.initital_account_state_) {
    return status_to_tonlib_api(TonlibError::EmptyField("initial_account_state"));
  }
  auto r_account_address = get_account_address(*request.initital_account_state_);
  if (r_account_address.is_error()) {
    return status_to_tonlib_api(r_account_address.error());
  }
  return tonlib_api::make_object<tonlib_api::accountAddress>(r_account_address.ok().rserialize(true));
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::testGiver_getAccountAddress& request) {
  return tonlib_api::make_object<tonlib_api::accountAddress>(ton::TestGiver::address().rserialize(true));
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::unpackAccountAddress& request) {
  auto r_account_address = get_account_address(request.account_address_);
  if (r_account_address.is_error()) {
    return status_to_tonlib_api(r_account_address.move_as_error());
  }
  auto account_address = r_account_address.move_as_ok();
  return tonlib_api::make_object<tonlib_api::unpackedAccountAddress>(
      account_address.workchain, account_address.bounceable, account_address.testnet,
      account_address.addr.as_slice().str());
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::packAccountAddress& request) {
  if (!request.account_address_) {
    return status_to_tonlib_api(TonlibError::EmptyField("account_address"));
  }
  if (request.account_address_->addr_.size() != 32) {
    return status_to_tonlib_api(TonlibError::InvalidField("account_address.addr", "must be 32 bytes long"));
  }
  block::StdAddress addr;
  addr.workchain = request.account_address_->workchain_id_;
  addr.bounceable = request.account_address_->bounceable_;
  addr.testnet = request.account_address_->testnet_;
  addr.addr.as_slice().copy_from(request.account_address_->addr_);
  return tonlib_api::make_object<tonlib_api::accountAddress>(addr.rserialize(true));
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(tonlib_api::getBip39Hints& request) {
  return tonlib_api::make_object<tonlib_api::bip39Hints>(
      td::transform(Mnemonic::word_hints(td::trim(td::to_lower_inplace(request.prefix_))), [](auto& x) { return x; }));
}

td::Status TonlibClient::do_request(const tonlib_api::init& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  if (state_ != State::Uninited) {
    return td::Status::Error(400, "Tonlib is already inited");
  }
  if (!request.options_) {
    return TonlibError::EmptyField("options");
  }
  if (!request.options_->keystore_type_) {
    return TonlibError::EmptyField("options.keystore_type");
  }

  td::Result<td::unique_ptr<KeyValue>> r_kv;
  downcast_call(
      *request.options_->keystore_type_,
      td::overloaded(
          [&](tonlib_api::keyStoreTypeDirectory& directory) { r_kv = KeyValue::create_dir(directory.directory_); },
          [&](tonlib_api::keyStoreTypeInMemory& inmemory) { r_kv = KeyValue::create_inmemory(); }));
  TRY_RESULT(kv, std::move(r_kv));
  kv_ = std::shared_ptr<KeyValue>(kv.release());

  key_storage_.set_key_value(kv_);
  last_block_storage_.set_key_value(kv_);
  if (request.options_->config_) {
    TRY_RESULT(full_config, validate_config(std::move(request.options_->config_)));
    set_config(std::move(full_config));
  }
  state_ = State::Running;
  promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
  return td::Status::OK();
}

class MasterConfig {
 public:
  void add_config(std::string name, std::string json) {
    auto config = std::make_shared<Config>(Config::parse(json).move_as_ok());
    if (!name.empty()) {
      by_name_[name] = config;
    }
    by_root_hash_[config->zero_state_id.root_hash] = config;
  }
  td::optional<Config> by_name(std::string name) const {
    auto it = by_name_.find(name);
    if (it == by_name_.end()) {
      return {};
    }
    return *it->second;
  }

  td::optional<Config> by_root_hash(const ton::RootHash& root_hash) const {
    auto it = by_root_hash_.find(root_hash);
    if (it == by_root_hash_.end()) {
      return {};
    }
    return *it->second;
  }

 private:
  size_t next_id_{0};
  std::map<std::string, std::shared_ptr<const Config>> by_name_;
  std::map<ton::RootHash, std::shared_ptr<const Config>> by_root_hash_;
};

const MasterConfig& get_default_master_config() {
  static MasterConfig config = [] {
    MasterConfig res;
    res.add_config("testnet", R"abc({
  "liteservers": [
  ],
  "validator": {
    "@type": "validator.config.global",
    "zero_state": {
      "workchain": -1,
      "shard": -9223372036854775808,
      "seqno": 0,
      "root_hash": "VCSXxDHhTALFxReyTZRd8E4Ya3ySOmpOWAS4rBX9XBY=",
      "file_hash": "eh9yveSz1qMdJ7mOsO+I+H77jkLr9NpAuEkoJuseXBo="
    },
    "init_block": 
{"workchain":-1,"shard":-9223372036854775808,"seqno":870721,"root_hash":"jYKhSQ1xeSPprzgjqiUOnAWwc2yqs7nCVAU21k922s4=","file_hash":"kHidF02CZpaz2ia9jtXUJLp0AiWMWwfzprTUIsddHSo="}
  }
})abc");
    return res;
  }();
  return config;
}

td::Result<TonlibClient::FullConfig> TonlibClient::validate_config(tonlib_api::object_ptr<tonlib_api::config> config) {
  if (!config) {
    return TonlibError::EmptyField("config");
  }
  if (config->config_.empty()) {
    return TonlibError::InvalidConfig("config is empty");
  }
  TRY_RESULT_PREFIX(new_config, Config::parse(std::move(config->config_)),
                    TonlibError::InvalidConfig("can't parse config"));

  if (new_config.lite_clients.empty() && !config->use_callbacks_for_network_) {
    return TonlibError::InvalidConfig("no lite clients");
  }

  td::optional<Config> o_master_config;
  if (config->blockchain_name_.empty()) {
    o_master_config = get_default_master_config().by_root_hash(new_config.zero_state_id.root_hash);
  } else {
    o_master_config = get_default_master_config().by_name(config->blockchain_name_);
  }

  if (o_master_config && o_master_config.value().zero_state_id != new_config.zero_state_id) {
    return TonlibError::InvalidConfig("zero_state differs from embedded zero_state");
  }
  FullConfig res;
  res.config = std::move(new_config);
  res.o_master_config = std::move(o_master_config);
  res.ignore_cache = config->ignore_cache_;
  res.use_callbacks_for_network = config->use_callbacks_for_network_;
  res.wallet_id = td::as<td::uint32>(res.config.zero_state_id.root_hash.as_slice().data());
  return std::move(res);
}

void TonlibClient::set_config(FullConfig full_config) {
  config_ = std::move(full_config.config);
  config_generation_++;
  wallet_id_ = full_config.wallet_id;
  blockchain_name_ = config_.zero_state_id.root_hash.as_slice().str();

  use_callbacks_for_network_ = full_config.use_callbacks_for_network;
  ignore_cache_ = full_config.ignore_cache;
  init_ext_client();
  init_last_block(std::move(full_config.o_master_config));
  init_last_config();
  client_.set_client(get_client_ref());
}

td::Status TonlibClient::do_request(const tonlib_api::close& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  CHECK(state_ != State::Closed);
  state_ = State::Closed;
  source_.cancel();
  promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
  return td::Status::OK();
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    tonlib_api::options_validateConfig& request) {
  auto r_config = validate_config(std::move(request.config_));
  if (r_config.is_error()) {
    return status_to_tonlib_api(r_config.move_as_error());
  }
  return tonlib_api::make_object<tonlib_api::options_configInfo>(r_config.ok().wallet_id);
}

td::Status TonlibClient::do_request(tonlib_api::options_setConfig& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  if (!request.config_) {
    return TonlibError::EmptyField("config");
  }
  TRY_RESULT(config, validate_config(std::move(request.config_)));
  set_config(std::move(config));
  promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
  return td::Status::OK();
}

td::Result<std::string> to_std_address_or_throw(td::Ref<vm::CellSlice> cs) {
  auto tag = block::gen::MsgAddressInt().get_tag(*cs);
  if (tag < 0) {
    return td::Status::Error("Failed to read MsgAddressInt tag");
  }
  if (tag != block::gen::MsgAddressInt::addr_std) {
    return "";
  }
  block::gen::MsgAddressInt::Record_addr_std addr;
  if (!tlb::csr_unpack(cs, addr)) {
    return td::Status::Error("Failed to unpack MsgAddressInt");
  }
  return block::StdAddress(addr.workchain_id, addr.address).rserialize(true);
}

td::Result<std::string> to_std_address(td::Ref<vm::CellSlice> cs) {
  return TRY_VM(to_std_address_or_throw(std::move(cs)));
}

td::Result<tonlib_api::object_ptr<tonlib_api::raw_message>> to_raw_message_or_throw(td::Ref<vm::Cell> cell) {
  block::gen::Message::Record message;
  if (!tlb::type_unpack_cell(cell, block::gen::t_Message_Any, message)) {
    return td::Status::Error("Failed to unpack Message");
  }

  auto tag = block::gen::CommonMsgInfo().get_tag(*message.info);
  if (tag < 0) {
    return td::Status::Error("Failed to read CommonMsgInfo tag");
  }
  switch (tag) {
    case block::gen::CommonMsgInfo::int_msg_info: {
      block::gen::CommonMsgInfo::Record_int_msg_info msg_info;
      if (!tlb::csr_unpack(message.info, msg_info)) {
        return td::Status::Error("Failed to unpack CommonMsgInfo::int_msg_info");
      }

      TRY_RESULT(balance, to_balance(msg_info.value));
      TRY_RESULT(src, to_std_address(msg_info.src));
      TRY_RESULT(dest, to_std_address(msg_info.dest));
      TRY_RESULT(fwd_fee, to_balance(msg_info.fwd_fee));
      TRY_RESULT(ihr_fee, to_balance(msg_info.ihr_fee));
      auto created_lt = static_cast<td::int64>(msg_info.created_lt);
      td::Ref<vm::CellSlice> body;
      if (message.body->prefetch_long(1) == 0) {
        body = std::move(message.body);
        body.write().advance(1);
      } else {
        body = vm::load_cell_slice_ref(message.body->prefetch_ref());
      }
      auto body_hash = vm::CellBuilder().append_cellslice(*body).finalize()->get_hash().as_slice().str();
      std::string body_message;
      if (body->size() >= 32 && body->prefetch_long(32) == 0) {
        body.write().fetch_long(32);
        auto r_body_message = vm::CellString::load(body.write());
        if (r_body_message.is_ok()) {
          body_message = r_body_message.move_as_ok();
        }
      }

      return tonlib_api::make_object<tonlib_api::raw_message>(std::move(src), std::move(dest), balance, fwd_fee,
                                                              ihr_fee, created_lt, std::move(body_hash),
                                                              std::move(body_message));
    }
    case block::gen::CommonMsgInfo::ext_in_msg_info: {
      block::gen::CommonMsgInfo::Record_ext_in_msg_info msg_info;
      if (!tlb::csr_unpack(message.info, msg_info)) {
        return td::Status::Error("Failed to unpack CommonMsgInfo::ext_in_msg_info");
      }
      TRY_RESULT(dest, to_std_address(msg_info.dest));
      td::Ref<vm::CellSlice> body;
      if (message.body->prefetch_long(1) == 0) {
        body = std::move(message.body);
        body.write().advance(1);
      } else {
        body = vm::load_cell_slice_ref(message.body->prefetch_ref());
      }
      auto body_hash = vm::CellBuilder().append_cellslice(*body).finalize()->get_hash().as_slice().str();
      return tonlib_api::make_object<tonlib_api::raw_message>("", std::move(dest), 0, 0, 0, 0, std::move(body_hash),
                                                              "");
    }
    case block::gen::CommonMsgInfo::ext_out_msg_info: {
      block::gen::CommonMsgInfo::Record_ext_out_msg_info msg_info;
      if (!tlb::csr_unpack(message.info, msg_info)) {
        return td::Status::Error("Failed to unpack CommonMsgInfo::ext_out_msg_info");
      }
      TRY_RESULT(src, to_std_address(msg_info.src));
      return tonlib_api::make_object<tonlib_api::raw_message>(std::move(src), "", 0, 0, 0, 0, "", "");
    }
  }

  return td::Status::Error("Unknown CommonMsgInfo tag");
}

td::Result<tonlib_api::object_ptr<tonlib_api::raw_message>> to_raw_message(td::Ref<vm::Cell> cell) {
  return TRY_VM(to_raw_message_or_throw(std::move(cell)));
}

td::Result<tonlib_api::object_ptr<tonlib_api::raw_transaction>> to_raw_transaction_or_throw(
    block::Transaction::Info&& info) {
  std::string data;

  tonlib_api::object_ptr<tonlib_api::raw_message> in_msg;
  std::vector<tonlib_api::object_ptr<tonlib_api::raw_message>> out_msgs;
  td::int64 fees = 0;
  td::int64 storage_fee = 0;
  if (info.transaction.not_null()) {
    data = to_bytes(info.transaction);
    block::gen::Transaction::Record trans;
    if (!tlb::unpack_cell(info.transaction, trans)) {
      return td::Status::Error("Failed to unpack Transaction");
    }

    TRY_RESULT_ASSIGN(fees, to_balance(trans.total_fees));

    //std::ostringstream outp;
    //block::gen::t_Transaction.print_ref(outp, info.transaction);
    //LOG(INFO) << outp.str();

    auto is_just = trans.r1.in_msg->prefetch_long(1);
    if (is_just == trans.r1.in_msg->fetch_long_eof) {
      return td::Status::Error("Failed to parse long");
    }
    if (is_just == -1) {
      auto msg = trans.r1.in_msg->prefetch_ref();
      TRY_RESULT(in_msg_copy, to_raw_message(trans.r1.in_msg->prefetch_ref()));
      in_msg = std::move(in_msg_copy);
    }

    if (trans.outmsg_cnt != 0) {
      vm::Dictionary dict{trans.r1.out_msgs, 15};
      for (int x = 0; x < trans.outmsg_cnt && x < 100; x++) {
        TRY_RESULT(out_msg, to_raw_message(dict.lookup_ref(td::BitArray<15>{x})));
        fees += out_msg->fwd_fee_;
        fees += out_msg->ihr_fee_;
        out_msgs.push_back(std::move(out_msg));
      }
    }
    td::RefInt256 storage_fees;
    if (!block::tlb::t_TransactionDescr.get_storage_fees(trans.description, storage_fees)) {
      return td::Status::Error("Failed to fetch storage fee from transaction");
    }
    storage_fee = storage_fees->to_long();
  }
  return tonlib_api::make_object<tonlib_api::raw_transaction>(
      info.now, data,
      tonlib_api::make_object<tonlib_api::internal_transactionId>(info.prev_trans_lt,
                                                                  info.prev_trans_hash.as_slice().str()),
      fees, storage_fee, fees - storage_fee, std::move(in_msg), std::move(out_msgs));
}

td::Result<tonlib_api::object_ptr<tonlib_api::raw_transaction>> to_raw_transaction(block::Transaction::Info&& info) {
  return TRY_VM(to_raw_transaction_or_throw(std::move(info)));
}

td::Result<tonlib_api::object_ptr<tonlib_api::raw_transactions>> to_raw_transactions(
    block::TransactionList::Info&& info) {
  std::vector<tonlib_api::object_ptr<tonlib_api::raw_transaction>> transactions;
  for (auto& transaction : info.transactions) {
    TRY_RESULT(raw_transaction, to_raw_transaction(std::move(transaction)));
    transactions.push_back(std::move(raw_transaction));
  }

  auto transaction_id =
      tonlib_api::make_object<tonlib_api::internal_transactionId>(info.lt, info.hash.as_slice().str());
  for (auto& transaction : transactions) {
    std::swap(transaction->transaction_id_, transaction_id);
  }

  return tonlib_api::make_object<tonlib_api::raw_transactions>(std::move(transactions), std::move(transaction_id));
}

// Raw

auto to_any_promise(td::Promise<tonlib_api::object_ptr<tonlib_api::ok>>&& promise) {
  return promise.wrap([](auto x) { return tonlib_api::make_object<tonlib_api::ok>(); });
}
auto to_any_promise(td::Promise<td::Unit>&& promise) {
  return promise.wrap([](auto x) { return td::Unit(); });
}

td::Status TonlibClient::do_request(const tonlib_api::raw_sendMessage& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  TRY_RESULT_PREFIX(body, vm::std_boc_deserialize(request.body_), TonlibError::InvalidBagOfCells("body"));
  std::ostringstream os;
  block::gen::t_Message_Any.print_ref(os, body);
  LOG(ERROR) << os.str();
  make_request(int_api::SendMessage{std::move(body)}, to_any_promise(std::move(promise)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::raw_createAndSendMessage& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  td::Ref<vm::Cell> init_state;
  if (!request.initial_account_state_.empty()) {
    TRY_RESULT_PREFIX(new_init_state, vm::std_boc_deserialize(request.initial_account_state_),
                      TonlibError::InvalidBagOfCells("initial_account_state"));
    init_state = std::move(new_init_state);
  }
  TRY_RESULT_PREFIX(data, vm::std_boc_deserialize(request.data_), TonlibError::InvalidBagOfCells("data"));
  TRY_RESULT(account_address, get_account_address(request.destination_->account_address_));
  auto message = ton::GenericAccount::create_ext_message(account_address, std::move(init_state), std::move(data));

  make_request(int_api::SendMessage{std::move(message)}, to_any_promise(std::move(promise)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::raw_getAccountState& request,
                                    td::Promise<object_ptr<tonlib_api::raw_accountState>>&& promise) {
  if (!request.account_address_) {
    return TonlibError::EmptyField("account_address");
  }
  TRY_RESULT(account_address, get_account_address(request.account_address_->account_address_));
  make_request(int_api::GetAccountState{std::move(account_address)},
               promise.wrap([](auto&& res) { return res->to_raw_accountState(); }));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::raw_getTransactions& request,
                                    td::Promise<object_ptr<tonlib_api::raw_transactions>>&& promise) {
  if (!request.account_address_) {
    return TonlibError::EmptyField("account_address");
  }
  if (!request.from_transaction_id_) {
    return TonlibError::EmptyField("from_transaction_id");
  }
  TRY_RESULT(account_address, get_account_address(request.account_address_->account_address_));
  auto lt = request.from_transaction_id_->lt_;
  auto hash_str = request.from_transaction_id_->hash_;
  if (hash_str.size() != 32) {
    return td::Status::Error(400, "Invalid transaction id hash size");
  }
  td::Bits256 hash;
  hash.as_slice().copy_from(hash_str);

  auto actor_id = actor_id_++;
  actors_[actor_id] = td::actor::create_actor<GetTransactionHistory>(
      "GetTransactionHistory", client_.get_client(), account_address, lt, hash, actor_shared(this, actor_id),
      promise.wrap(to_raw_transactions));
  return td::Status::OK();
}
td::Result<KeyStorage::InputKey> from_tonlib(tonlib_api::inputKeyRegular& input_key) {
  if (!input_key.key_) {
    return TonlibError::EmptyField("key");
  }

  TRY_RESULT(key_bytes, get_public_key(input_key.key_->public_key_));
  return KeyStorage::InputKey{{td::SecureString(key_bytes.key), std::move(input_key.key_->secret_)},
                              std::move(input_key.local_password_)};
}

td::Result<KeyStorage::InputKey> from_tonlib(tonlib_api::InputKey& input_key) {
  td::Result<KeyStorage::InputKey> r_key;
  tonlib_api::downcast_call(
      input_key, td::overloaded([&](tonlib_api::inputKeyRegular& input_key) { r_key = from_tonlib(input_key); },
                                [&](tonlib_api::inputKeyFake&) { r_key = KeyStorage::fake_input_key(); }));
  return r_key;
}

// ton::TestWallet
td::Status TonlibClient::do_request(const tonlib_api::testWallet_init& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  if (!request.private_key_) {
    return td::Status::Error(400, "Field private_key must not be empty");
  }
  TRY_RESULT(input_key, from_tonlib(*request.private_key_));
  auto init_state = ton::TestWallet::get_init_state(td::Ed25519::PublicKey(input_key.key.public_key.copy()));
  auto address = ton::GenericAccount::get_address(0 /*zerochain*/, init_state);
  TRY_RESULT(private_key, key_storage_.load_private_key(std::move(input_key)));
  auto init_message = ton::TestWallet::get_init_message(td::Ed25519::PrivateKey(std::move(private_key.private_key)));
  auto message = ton::GenericAccount::create_ext_message(address, std::move(init_state), std::move(init_message));
  make_request(int_api::SendMessage{std::move(message)}, to_any_promise(std::move(promise)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::testWallet_sendGrams& request,
                                    td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise) {
  if (!request.destination_) {
    return TonlibError::EmptyField("destination");
  }
  if (!request.private_key_) {
    return TonlibError::EmptyField("private_key");
  }
  if (request.message_.size() > ton::TestWallet::max_message_size) {
    return TonlibError::MessageTooLong();
  }
  TRY_RESULT(account_address, get_account_address(request.destination_->account_address_));
  TRY_RESULT(input_key, from_tonlib(*request.private_key_));
  auto address = ton::GenericAccount::get_address(
      0 /*zerochain*/, ton::TestWallet::get_init_state(td::Ed25519::PublicKey(input_key.key.public_key.copy())));
  TRY_RESULT(private_key_str, key_storage_.load_private_key(std::move(input_key)));
  auto private_key = td::Ed25519::PrivateKey(std::move(private_key_str.private_key));
  td::Ref<vm::Cell> init_state;
  if (request.seqno_ == 0) {
    TRY_RESULT_PREFIX(public_key, private_key.get_public_key(), TonlibError::Internal());
    init_state = ton::TestWallet::get_init_state(public_key);
  }
  auto message = ton::TestWallet::make_a_gift_message(private_key, request.seqno_, request.amount_, request.message_,
                                                      account_address);
  auto message_hash = message->get_hash().as_slice().str();
  auto new_promise = promise.wrap([message_hash = std::move(message_hash)](auto&&) {
    return tonlib_api::make_object<tonlib_api::sendGramsResult>(0, std::move(message_hash));
  });

  auto ext_message = ton::GenericAccount::create_ext_message(address, std::move(init_state), std::move(message));
  make_request(int_api::SendMessage{std::move(message)}, std::move(new_promise));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::testWallet_getAccountState& request,
                                    td::Promise<object_ptr<tonlib_api::testWallet_accountState>>&& promise) {
  if (!request.account_address_) {
    return TonlibError::EmptyField("account_address");
  }
  TRY_RESULT(account_address, get_account_address(request.account_address_->account_address_));
  make_request(int_api::GetAccountState{std::move(account_address)},
               promise.wrap([](auto&& res) { return res->to_testWallet_accountState(); }));
  return td::Status::OK();
}

// ton::Wallet
td::Status TonlibClient::do_request(const tonlib_api::wallet_init& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  if (!request.private_key_) {
    return TonlibError::EmptyField("private_key");
  }
  TRY_RESULT(input_key, from_tonlib(*request.private_key_));
  auto init_state = ton::Wallet::get_init_state(td::Ed25519::PublicKey(input_key.key.public_key.copy()));
  auto address = ton::GenericAccount::get_address(0 /*zerochain*/, init_state);
  TRY_RESULT(private_key, key_storage_.load_private_key(std::move(input_key)));
  auto init_message = ton::Wallet::get_init_message(td::Ed25519::PrivateKey(std::move(private_key.private_key)));
  auto message =
      ton::GenericAccount::create_ext_message(std::move(address), std::move(init_state), std::move(init_message));

  make_request(int_api::SendMessage{std::move(message)}, to_any_promise(std::move(promise)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::wallet_sendGrams& request,
                                    td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise) {
  if (!request.destination_) {
    return TonlibError::EmptyField("destination");
  }
  if (!request.private_key_) {
    return TonlibError::EmptyField("private_key");
  }
  if (request.message_.size() > ton::Wallet::max_message_size) {
    return TonlibError::MessageTooLong();
  }
  TRY_RESULT_PREFIX(valid_until, td::narrow_cast_safe<td::uint32>(request.valid_until_),
                    TonlibError::InvalidField("valid_until", "overflow"));
  TRY_RESULT(account_address, get_account_address(request.destination_->account_address_));
  TRY_RESULT(input_key, from_tonlib(*request.private_key_));
  auto address = ton::GenericAccount::get_address(
      0 /*zerochain*/, ton::Wallet::get_init_state(td::Ed25519::PublicKey(input_key.key.public_key.copy())));
  TRY_RESULT(private_key_str, key_storage_.load_private_key(std::move(input_key)));
  auto private_key = td::Ed25519::PrivateKey(std::move(private_key_str.private_key));
  td::Ref<vm::Cell> init_state;
  if (request.seqno_ == 0) {
    TRY_RESULT_PREFIX(public_key, private_key.get_public_key(), TonlibError::Internal());
    init_state = ton::Wallet::get_init_state(public_key);
  }
  auto message = ton::Wallet::make_a_gift_message(private_key, request.seqno_, valid_until, request.amount_,
                                                  request.message_, account_address);
  auto message_hash = message->get_hash().as_slice().str();
  auto new_promise = promise.wrap([valid_until, message_hash = std::move(message_hash)](auto&&) {
    return tonlib_api::make_object<tonlib_api::sendGramsResult>(valid_until, std::move(message_hash));
  });
  auto ext_message = ton::GenericAccount::create_ext_message(address, std::move(init_state), std::move(message));
  make_request(int_api::SendMessage{std::move(message)}, std::move(new_promise));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::wallet_getAccountState& request,
                                    td::Promise<object_ptr<tonlib_api::wallet_accountState>>&& promise) {
  if (!request.account_address_) {
    return TonlibError::EmptyField("account_address");
  }
  TRY_RESULT(account_address, get_account_address(request.account_address_->account_address_));
  make_request(int_api::GetAccountState{std::move(account_address)},
               promise.wrap([](auto&& res) { return res->to_wallet_accountState(); }));
  return td::Status::OK();
}

// ton::TestGiver
td::Status TonlibClient::do_request(const tonlib_api::testGiver_sendGrams& request,
                                    td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise) {
  if (!request.destination_) {
    return TonlibError::EmptyField("destination");
  }
  if (request.message_.size() > ton::TestGiver::max_message_size) {
    return TonlibError::MessageTooLong();
  }
  TRY_RESULT(account_address, get_account_address(request.destination_->account_address_));
  auto message =
      ton::TestGiver::make_a_gift_message(request.seqno_, request.amount_, request.message_, account_address);
  auto message_hash = message->get_hash().as_slice().str();
  auto new_promise = promise.wrap([message_hash = std::move(message_hash)](auto&&) {
    return tonlib_api::make_object<tonlib_api::sendGramsResult>(0, std::move(message_hash));
  });

  auto ext_message = ton::GenericAccount::create_ext_message(ton::TestGiver::address(), {}, std::move(message));
  make_request(int_api::SendMessage{std::move(message)}, std::move(new_promise));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::testGiver_getAccountState& request,
                                    td::Promise<object_ptr<tonlib_api::testGiver_accountState>>&& promise) {
  make_request(int_api::GetAccountState{ton::TestGiver::address()},
               promise.wrap([](auto&& res) { return res->to_testGiver_accountState(); }));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::generic_getAccountState& request,
                                    td::Promise<object_ptr<tonlib_api::generic_AccountState>>&& promise) {
  if (!request.account_address_) {
    return TonlibError::EmptyField("account_address");
  }
  TRY_RESULT(account_address, get_account_address(request.account_address_->account_address_));
  make_request(int_api::GetAccountState{std::move(account_address)},
               promise.wrap([](auto&& res) { return res->to_generic_accountState(); }));
  return td::Status::OK();
}

class GenericCreateSendGrams : public TonlibQueryActor {
 public:
  GenericCreateSendGrams(td::actor::ActorShared<TonlibClient> client,
                         tonlib_api::generic_createSendGramsQuery send_grams,
                         td::Promise<td::unique_ptr<Query>>&& promise)
      : TonlibQueryActor(std::move(client)), send_grams_(std::move(send_grams)), promise_(std::move(promise)) {
  }

 private:
  tonlib_api::generic_createSendGramsQuery send_grams_;
  td::Promise<td::unique_ptr<Query>> promise_;

  td::unique_ptr<AccountState> source_;
  td::unique_ptr<AccountState> destination_;
  bool has_private_key_{false};
  bool is_fake_key_{false};
  td::optional<td::Ed25519::PrivateKey> private_key_;
  td::optional<td::Ed25519::PublicKey> public_key_;

  void check(td::Status status) {
    if (status.is_error()) {
      promise_.set_error(std::move(status));
      return stop();
    }
  }

  void start_up() override {
    check(do_start_up());
  }
  void hangup() override {
    check(TonlibError::Cancelled());
  }

  td::Status do_start_up() {
    if (send_grams_.timeout_ < 0 || send_grams_.timeout_ > 300) {
      return TonlibError::InvalidField("timeout", "must be between 0 and 300");
    }
    if (!send_grams_.destination_) {
      return TonlibError::EmptyField("destination");
    }
    if (!send_grams_.source_) {
      return TonlibError::EmptyField("source");
    }
    if (send_grams_.amount_ < 0) {
      return TonlibError::InvalidField("amount", "can't be negative");
    }
    // Use this limit as a preventive check
    if (send_grams_.message_.size() > ton::Wallet::max_message_size) {
      return TonlibError::MessageTooLong();
    }
    TRY_RESULT(destination_address, get_account_address(send_grams_.destination_->account_address_));
    TRY_RESULT(source_address, get_account_address(send_grams_.source_->account_address_));

    has_private_key_ = bool(send_grams_.private_key_);
    if (has_private_key_) {
      TRY_RESULT(input_key, from_tonlib(*send_grams_.private_key_));
      is_fake_key_ = send_grams_.private_key_->get_id() == tonlib_api::inputKeyFake::ID;
      public_key_ = td::Ed25519::PublicKey(input_key.key.public_key.copy());
      send_query(int_api::GetPrivateKey{std::move(input_key)},
                 promise_send_closure(actor_id(this), &GenericCreateSendGrams::on_private_key));
    }

    send_query(int_api::GetAccountState{source_address},
               promise_send_closure(actor_id(this), &GenericCreateSendGrams::on_source_state));

    send_query(int_api::GetAccountState{destination_address},
               promise_send_closure(actor_id(this), &GenericCreateSendGrams::on_destination_state));

    return do_loop();
  }

  void on_private_key(td::Result<KeyStorage::PrivateKey> r_key) {
    check(do_on_private_key(std::move(r_key)));
  }

  td::Status do_on_private_key(td::Result<KeyStorage::PrivateKey> r_key) {
    TRY_RESULT(key, std::move(r_key));
    private_key_ = td::Ed25519::PrivateKey(std::move(key.private_key));
    return do_loop();
  }

  void on_source_state(td::Result<td::unique_ptr<AccountState>> r_state) {
    check(do_on_source_state(std::move(r_state)));
  }

  td::Status do_on_source_state(td::Result<td::unique_ptr<AccountState>> r_state) {
    TRY_RESULT(state, std::move(r_state));
    source_ = std::move(state);
    if (source_->get_wallet_type() == AccountState::Empty && public_key_) {
      source_->guess_type_by_public_key(public_key_.value());
    }

    //TODO: pass default type through api
    if (source_->get_wallet_type() == AccountState::Empty && public_key_ && is_fake_key_) {
      source_->guess_type_default(public_key_.value());
    }

    return do_loop();
  }

  void on_destination_state(td::Result<td::unique_ptr<AccountState>> r_state) {
    check(do_on_destination_state(std::move(r_state)));
  }

  td::Status do_on_destination_state(td::Result<td::unique_ptr<AccountState>> r_state) {
    TRY_RESULT(state, std::move(r_state));
    destination_ = std::move(state);
    if (destination_->is_frozen()) {
      //FIXME: after restoration of frozen accounts will be supported
      return TonlibError::TransferToFrozen();
    }
    if (destination_->get_wallet_type() == AccountState::Empty && destination_->get_address().bounceable) {
      if (!send_grams_.allow_send_to_uninited_) {
        return TonlibError::DangerousTransaction("Transfer to uninited wallet");
      }
      destination_->make_non_bounceable();
      LOG(INFO) << "Change destination address from bounceable to non-bounceable ";
    }
    return do_loop();
  }

  td::Status do_loop() {
    if (!source_ || !destination_) {
      return td::Status::OK();
    }
    if (has_private_key_ && !private_key_) {
      return td::Status::OK();
    }

    Query::Raw raw;

    auto amount = send_grams_.amount_;
    if (amount > source_->get_balance()) {
      return TonlibError::NotEnoughFunds();
    }
    if (amount == source_->get_balance()) {
      amount = -1;
    }
    auto message = send_grams_.message_;
    switch (source_->get_wallet_type()) {
      case AccountState::Empty:
        return TonlibError::AccountNotInited();
      case AccountState::Unknown:
        return TonlibError::AccountTypeUnknown();
      case AccountState::Giver: {
        raw.message_body = ton::TestGiver::make_a_gift_message(0, amount, message, destination_->get_address());
        break;
      }

      case AccountState::SimpleWallet: {
        if (!private_key_) {
          return TonlibError::EmptyField("private_key");
        }
        if (message.size() > ton::TestWallet::max_message_size) {
          return TonlibError::MessageTooLong();
        }
        TRY_RESULT(seqno, ton::TestWallet(source_->get_smc_state()).get_seqno());
        raw.message_body = ton::TestWallet::make_a_gift_message(private_key_.unwrap(), seqno, amount, message,
                                                                destination_->get_address());
        break;
      }
      case AccountState::Wallet: {
        if (!private_key_) {
          return TonlibError::EmptyField("private_key");
        }
        if (message.size() > ton::Wallet::max_message_size) {
          return TonlibError::MessageTooLong();
        }
        TRY_RESULT(seqno, ton::Wallet(source_->get_smc_state()).get_seqno());
        auto valid_until = source_->get_sync_time();
        valid_until += send_grams_.timeout_ == 0 ? 60 : send_grams_.timeout_;
        raw.valid_until = valid_until;
        raw.message_body = ton::Wallet::make_a_gift_message(private_key_.unwrap(), seqno, valid_until, amount, message,
                                                            destination_->get_address());
        break;
      }
      case AccountState::WalletV3: {
        if (!private_key_) {
          return TonlibError::EmptyField("private_key");
        }
        if (message.size() > ton::WalletV3::max_message_size) {
          return TonlibError::MessageTooLong();
        }
        auto wallet = ton::WalletV3(source_->get_smc_state());
        TRY_RESULT(seqno, wallet.get_seqno());
        TRY_RESULT(wallet_id, wallet.get_wallet_id());
        auto valid_until = source_->get_sync_time();
        valid_until += send_grams_.timeout_ == 0 ? 60 : send_grams_.timeout_;
        raw.valid_until = valid_until;
        raw.message_body = ton::WalletV3::make_a_gift_message(private_key_.unwrap(), wallet_id, seqno, valid_until,
                                                              amount, message, destination_->get_address());
        break;
      }
    }

    raw.new_state = source_->get_new_state();
    raw.message = ton::GenericAccount::create_ext_message(source_->get_address(), raw.new_state, raw.message_body);
    raw.source = std::move(source_);
    raw.destination = std::move(destination_);

    promise_.set_value(td::make_unique<Query>(std::move(raw)));
    stop();
    return td::Status::OK();
  }
};

td::int64 TonlibClient::register_query(td::unique_ptr<Query> query) {
  auto query_id = ++next_query_id_;
  queries_[query_id] = std::move(query);
  return query_id;
}

td::Result<tonlib_api::object_ptr<tonlib_api::query_info>> TonlibClient::get_query_info(td::int64 id) {
  auto it = queries_.find(id);
  if (it == queries_.end()) {
    return TonlibError::InvalidQueryId();
  }
  return tonlib_api::make_object<tonlib_api::query_info>(id, it->second->get_valid_until(),
                                                         it->second->get_body_hash().as_slice().str());
}

void TonlibClient::finish_create_query(td::Result<td::unique_ptr<Query>> r_query,
                                       td::Promise<object_ptr<tonlib_api::query_info>>&& promise) {
  TRY_RESULT_PROMISE(promise, query, std::move(r_query));
  auto id = register_query(std::move(query));
  promise.set_result(get_query_info(id));
}
void TonlibClient::finish_send_query(td::Result<td::unique_ptr<Query>> r_query,
                                     td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise) {
  TRY_RESULT_PROMISE(promise, query, std::move(r_query));
  auto result = tonlib_api::make_object<tonlib_api::sendGramsResult>(query->get_valid_until(),
                                                                     query->get_body_hash().as_slice().str());
  auto id = register_query(std::move(query));
  make_request(tonlib_api::query_send(id),
               promise.wrap([result = std::move(result)](auto&&) mutable { return std::move(result); }));
}
td::Status TonlibClient::do_request(tonlib_api::generic_createSendGramsQuery& request,
                                    td::Promise<object_ptr<tonlib_api::query_info>>&& promise) {
  auto id = actor_id_++;
  actors_[id] = td::actor::create_actor<GenericCreateSendGrams>(
      "GenericSendGrams", actor_shared(this, id), std::move(request),
      promise.send_closure(actor_id(this), &TonlibClient::finish_create_query));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::raw_createQuery& request,
                                    td::Promise<object_ptr<tonlib_api::query_info>>&& promise) {
  if (!request.destination_) {
    return TonlibError::EmptyField("destination");
  }
  TRY_RESULT(account_address, get_account_address(request.destination_->account_address_));

  td::optional<ton::SmartContract::State> smc_state;
  if (!request.init_code_.empty()) {
    TRY_RESULT_PREFIX(code, vm::std_boc_deserialize(request.init_code_), TonlibError::InvalidBagOfCells("init_code"));
    TRY_RESULT_PREFIX(data, vm::std_boc_deserialize(request.init_data_), TonlibError::InvalidBagOfCells("init_data"));
    smc_state = ton::SmartContract::State{std::move(code), std::move(data)};
  }
  TRY_RESULT_PREFIX(body, vm::std_boc_deserialize(request.body_), TonlibError::InvalidBagOfCells("body"));

  td::Promise<td::unique_ptr<Query>> new_promise =
      promise.send_closure(actor_id(this), &TonlibClient::finish_create_query);

  make_request(int_api::GetAccountState{account_address},
               new_promise.wrap([smc_state = std::move(smc_state), body = std::move(body)](auto&& source) mutable {
                 Query::Raw raw;
                 if (smc_state) {
                   source->set_new_state(smc_state.unwrap());
                 }
                 raw.new_state = source->get_new_state();
                 raw.message_body = std::move(body);
                 raw.message =
                     ton::GenericAccount::create_ext_message(source->get_address(), raw.new_state, raw.message_body);
                 raw.source = std::move(source);
                 raw.destination = nullptr;
                 return td::make_unique<Query>(std::move(raw));
               }));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::generic_sendGrams& request,
                                    td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise) {
  auto id = actor_id_++;
  actors_[id] = td::actor::create_actor<GenericCreateSendGrams>(
      "GenericSendGrams", actor_shared(this, id),
      tonlib_api::generic_createSendGramsQuery(std::move(request.private_key_), std::move(request.source_),
                                               std::move(request.destination_), request.amount_, request.timeout_,
                                               request.allow_send_to_uninited_, std::move(request.message_)),
      promise.send_closure(actor_id(this), &TonlibClient::finish_send_query));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::query_getInfo& request,
                                    td::Promise<object_ptr<tonlib_api::query_info>>&& promise) {
  promise.set_result(get_query_info(request.id_));
  return td::Status::OK();
}

void TonlibClient::query_estimate_fees(td::int64 id, bool ignore_chksig, td::Result<LastConfigState> r_state,
                                       td::Promise<object_ptr<tonlib_api::query_fees>>&& promise) {
  auto it = queries_.find(id);
  if (it == queries_.end()) {
    promise.set_error(TonlibError::InvalidQueryId());
    return;
  }
  TRY_RESULT_PROMISE(promise, state, std::move(r_state));
  TRY_RESULT_PROMISE_PREFIX(promise, fees, TRY_VM(it->second->estimate_fees(ignore_chksig, *state.config)),
                            TonlibError::Internal());
  promise.set_value(
      tonlib_api::make_object<tonlib_api::query_fees>(fees.first.to_tonlib_api(), fees.second.to_tonlib_api()));
}

td::Status TonlibClient::do_request(const tonlib_api::query_estimateFees& request,
                                    td::Promise<object_ptr<tonlib_api::query_fees>>&& promise) {
  auto it = queries_.find(request.id_);
  if (it == queries_.end()) {
    return TonlibError::InvalidQueryId();
  }

  client_.with_last_config([this, id = request.id_, ignore_chksig = request.ignore_chksig_,
                            promise = std::move(promise)](td::Result<LastConfigState> r_state) mutable {
    this->query_estimate_fees(id, ignore_chksig, std::move(r_state), std::move(promise));
  });
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::query_send& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  auto it = queries_.find(request.id_);
  if (it == queries_.end()) {
    return TonlibError::InvalidQueryId();
  }

  auto message = it->second->get_message();
  if (GET_VERBOSITY_LEVEL() >= VERBOSITY_NAME(DEBUG)) {
    std::ostringstream ss;
    block::gen::t_Message_Any.print_ref(ss, message);
    LOG(DEBUG) << ss.str();
  }
  make_request(int_api::SendMessage{std::move(message)}, to_any_promise(std::move(promise)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::query_forget& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  auto it = queries_.find(request.id_);
  if (it == queries_.end()) {
    return TonlibError::InvalidQueryId();
  }
  promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
  return td::Status::OK();
}

td::int64 TonlibClient::register_smc(td::unique_ptr<AccountState> smc) {
  auto smc_id = ++next_smc_id_;
  smcs_[smc_id] = std::move(smc);
  return smc_id;
}

td::Result<tonlib_api::object_ptr<tonlib_api::smc_info>> TonlibClient::get_smc_info(td::int64 id) {
  auto it = smcs_.find(id);
  if (it == smcs_.end()) {
    return TonlibError::InvalidSmcId();
  }
  return tonlib_api::make_object<tonlib_api::smc_info>(id);
}

void TonlibClient::finish_load_smc(td::unique_ptr<AccountState> smc,
                                   td::Promise<object_ptr<tonlib_api::smc_info>>&& promise) {
  auto id = register_smc(std::move(smc));
  promise.set_result(get_smc_info(id));
}

td::Status TonlibClient::do_request(const tonlib_api::smc_load& request,
                                    td::Promise<object_ptr<tonlib_api::smc_info>>&& promise) {
  if (!request.account_address_) {
    return TonlibError::EmptyField("account_address");
  }
  TRY_RESULT(account_address, get_account_address(request.account_address_->account_address_));
  make_request(int_api::GetAccountState{std::move(account_address)},
               promise.send_closure(actor_id(this), &TonlibClient::finish_load_smc));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::smc_getCode& request,
                                    td::Promise<object_ptr<tonlib_api::tvm_cell>>&& promise) {
  auto it = smcs_.find(request.id_);
  if (it == smcs_.end()) {
    return TonlibError::InvalidSmcId();
  }
  auto& acc = it->second;
  auto code = acc->get_smc_state().code;
  promise.set_value(tonlib_api::make_object<tonlib_api::tvm_cell>(to_bytes(code)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::smc_getData& request,
                                    td::Promise<object_ptr<tonlib_api::tvm_cell>>&& promise) {
  auto it = smcs_.find(request.id_);
  if (it == smcs_.end()) {
    return TonlibError::InvalidSmcId();
  }
  auto& acc = it->second;
  auto data = acc->get_smc_state().data;
  promise.set_value(tonlib_api::make_object<tonlib_api::tvm_cell>(to_bytes(data)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::smc_getState& request,
                                    td::Promise<object_ptr<tonlib_api::tvm_cell>>&& promise) {
  auto it = smcs_.find(request.id_);
  if (it == smcs_.end()) {
    return TonlibError::InvalidSmcId();
  }
  auto& acc = it->second;
  auto data = acc->get_raw_state();
  promise.set_value(tonlib_api::make_object<tonlib_api::tvm_cell>(to_bytes(data)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::smc_runGetMethod& request,
                                    td::Promise<object_ptr<tonlib_api::smc_runResult>>&& promise) {
  auto it = smcs_.find(request.id_);
  if (it == smcs_.end()) {
    return TonlibError::InvalidSmcId();
  }

  td::Ref<ton::SmartContract> smc(true, it->second->get_smc_state());
  ton::SmartContract::Args args;
  downcast_call(*request.method_,
                td::overloaded([&](tonlib_api::smc_methodIdNumber& number) { args.set_method_id(number.number_); },
                               [&](tonlib_api::smc_methodIdName& name) { args.set_method_id(name.name_); }));
  td::Ref<vm::Stack> stack(true);
  td::Status status;
  // TODO: error codes
  // downcast_call
  for (auto& entry : request.stack_) {
    downcast_call(*entry, td::overloaded(
                              [&](tonlib_api::tvm_stackEntryUnsupported& cell) {
                                status = td::Status::Error("Unsuppored stack entry");
                              },
                              [&](tonlib_api::tvm_stackEntrySlice& cell) {
                                auto r_cell = vm::std_boc_deserialize(cell.slice_->bytes_);
                                if (r_cell.is_error()) {
                                  status = r_cell.move_as_error();
                                  return;
                                }
                                stack.write().push_cell(r_cell.move_as_ok());
                              },
                              [&](tonlib_api::tvm_stackEntryCell& cell) {
                                auto r_cell = vm::std_boc_deserialize(cell.cell_->bytes_);
                                if (r_cell.is_error()) {
                                  status = r_cell.move_as_error();
                                  return;
                                }
                                stack.write().push_cell(r_cell.move_as_ok());
                              },
                              [&](tonlib_api::tvm_stackEntryNumber& number) {
                                [&](tonlib_api::tvm_numberDecimal& dec) {
                                  auto num = td::dec_string_to_int256(dec.number_);
                                  if (num.is_null()) {
                                    status = td::Status::Error("Failed to parse dec string to int256");
                                    return;
                                  }
                                  stack.write().push_int(std::move(num));
                                }(*number.number_);
                              }));
  }
  TRY_STATUS(std::move(status));
  args.set_stack(std::move(stack));
  auto res = smc->run_get_method(std::move(args));

  // smc.runResult gas_used:int53 stack:vector<tvm.StackEntry> exit_code:int32 = smc.RunResult;
  std::vector<object_ptr<tonlib_api::tvm_StackEntry>> res_stack;
  for (auto& entry : res.stack->as_span()) {
    switch (entry.type()) {
      case vm::StackEntry::Type::t_int:
        res_stack.push_back(tonlib_api::make_object<tonlib_api::tvm_stackEntryNumber>(
            tonlib_api::make_object<tonlib_api::tvm_numberDecimal>(dec_string(entry.as_int()))));
        break;
      case vm::StackEntry::Type::t_slice:
        res_stack.push_back(
            tonlib_api::make_object<tonlib_api::tvm_stackEntryCell>(tonlib_api::make_object<tonlib_api::tvm_cell>(
                to_bytes(vm::CellBuilder().append_cellslice(entry.as_slice()).finalize()))));
        break;
      case vm::StackEntry::Type::t_cell:
        res_stack.push_back(tonlib_api::make_object<tonlib_api::tvm_stackEntryCell>(
            tonlib_api::make_object<tonlib_api::tvm_cell>(to_bytes(entry.as_cell()))));
        break;
      default:
        res_stack.push_back(tonlib_api::make_object<tonlib_api::tvm_stackEntryUnsupported>());
        break;
    }
  }
  promise.set_value(tonlib_api::make_object<tonlib_api::smc_runResult>(res.gas_used, std::move(res_stack), res.code));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::sync& request, td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  client_.with_last_block(to_any_promise(std::move(promise)));
  return td::Status::OK();
}

td::Result<block::PublicKey> public_key_from_bytes(td::Slice bytes) {
  TRY_RESULT_PREFIX(key_bytes, block::PublicKey::from_bytes(bytes), TonlibError::Internal());
  return key_bytes;
}

td::Status TonlibClient::do_request(const tonlib_api::createNewKey& request,
                                    td::Promise<object_ptr<tonlib_api::key>>&& promise) {
  TRY_RESULT_PREFIX(
      key,
      key_storage_.create_new_key(std::move(request.local_password_), std::move(request.mnemonic_password_),
                                  std::move(request.random_extra_seed_)),
      TonlibError::Internal());
  TRY_RESULT(key_bytes, public_key_from_bytes(key.public_key.as_slice()));
  promise.set_value(tonlib_api::make_object<tonlib_api::key>(key_bytes.serialize(true), std::move(key.secret)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::exportKey& request,
                                    td::Promise<object_ptr<tonlib_api::exportedKey>>&& promise) {
  if (!request.input_key_) {
    return TonlibError::EmptyField("input_key");
  }
  TRY_RESULT(input_key, from_tonlib(*request.input_key_));
  TRY_RESULT(exported_key, key_storage_.export_key(std::move(input_key)));
  promise.set_value(tonlib_api::make_object<tonlib_api::exportedKey>(std::move(exported_key.mnemonic_words)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::deleteKey& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  if (!request.key_) {
    return TonlibError::EmptyField("key");
  }
  TRY_RESULT(key_bytes, get_public_key(request.key_->public_key_));
  KeyStorage::Key key;
  key.public_key = td::SecureString(key_bytes.key);
  key.secret = std::move(request.key_->secret_);
  TRY_STATUS_PREFIX(key_storage_.delete_key(key), TonlibError::KeyUnknown());
  promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::deleteAllKeys& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  TRY_STATUS_PREFIX(key_storage_.delete_all_keys(), TonlibError::Internal());
  promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::importKey& request,
                                    td::Promise<object_ptr<tonlib_api::key>>&& promise) {
  if (!request.exported_key_) {
    return TonlibError::EmptyField("exported_key");
  }
  TRY_RESULT(key, key_storage_.import_key(std::move(request.local_password_), std::move(request.mnemonic_password_),
                                          KeyStorage::ExportedKey{std::move(request.exported_key_->word_list_)}));
  TRY_RESULT(key_bytes, public_key_from_bytes(key.public_key.as_slice()));
  promise.set_value(tonlib_api::make_object<tonlib_api::key>(key_bytes.serialize(true), std::move(key.secret)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::exportPemKey& request,
                                    td::Promise<object_ptr<tonlib_api::exportedPemKey>>&& promise) {
  if (!request.input_key_) {
    return TonlibError::EmptyField("input_key");
  }
  TRY_RESULT(input_key, from_tonlib(*request.input_key_));
  TRY_RESULT(exported_pem_key, key_storage_.export_pem_key(std::move(input_key), std::move(request.key_password_)));
  promise.set_value(tonlib_api::make_object<tonlib_api::exportedPemKey>(std::move(exported_pem_key.pem)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::importPemKey& request,
                                    td::Promise<object_ptr<tonlib_api::key>>&& promise) {
  if (!request.exported_key_) {
    return TonlibError::EmptyField("exported_key");
  }
  TRY_RESULT(key, key_storage_.import_pem_key(std::move(request.local_password_), std::move(request.key_password_),
                                              KeyStorage::ExportedPemKey{std::move(request.exported_key_->pem_)}));
  TRY_RESULT(key_bytes, public_key_from_bytes(key.public_key.as_slice()));
  promise.set_value(tonlib_api::make_object<tonlib_api::key>(key_bytes.serialize(true), std::move(key.secret)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::exportEncryptedKey& request,
                                    td::Promise<object_ptr<tonlib_api::exportedEncryptedKey>>&& promise) {
  if (!request.input_key_) {
    return TonlibError::EmptyField("input_key");
  }
  TRY_RESULT(input_key, from_tonlib(*request.input_key_));
  TRY_RESULT(exported_key, key_storage_.export_encrypted_key(std::move(input_key), request.key_password_));
  promise.set_value(tonlib_api::make_object<tonlib_api::exportedEncryptedKey>(std::move(exported_key.data)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::importEncryptedKey& request,
                                    td::Promise<object_ptr<tonlib_api::key>>&& promise) {
  if (!request.exported_encrypted_key_) {
    return TonlibError::EmptyField("exported_encrypted_key");
  }
  TRY_RESULT(key, key_storage_.import_encrypted_key(
                      std::move(request.local_password_), std::move(request.key_password_),
                      KeyStorage::ExportedEncryptedKey{std::move(request.exported_encrypted_key_->data_)}));
  TRY_RESULT(key_bytes, public_key_from_bytes(key.public_key.as_slice()));
  promise.set_value(tonlib_api::make_object<tonlib_api::key>(key_bytes.serialize(true), std::move(key.secret)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::changeLocalPassword& request,
                                    td::Promise<object_ptr<tonlib_api::key>>&& promise) {
  if (!request.input_key_) {
    return TonlibError::EmptyField("input_key");
  }
  TRY_RESULT(input_key, from_tonlib(*request.input_key_));
  TRY_RESULT(key, key_storage_.change_local_password(std::move(input_key), std::move(request.new_local_password_)));
  promise.set_value(tonlib_api::make_object<tonlib_api::key>(key.public_key.as_slice().str(), std::move(key.secret)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::onLiteServerQueryResult& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  if (ext_client_outbound_.empty()) {
    return TonlibError::InvalidQueryId();
  }
  if (((request.id_ ^ config_generation_) & 0xffff) != 0) {
    return TonlibError::InvalidQueryId();
  }
  send_closure(ext_client_outbound_, &ExtClientOutbound::on_query_result, request.id_ >> 16,
               td::BufferSlice(request.bytes_), to_any_promise(std::move(promise)));
  return td::Status::OK();
}
td::Status TonlibClient::do_request(const tonlib_api::onLiteServerQueryError& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  if (ext_client_outbound_.empty()) {
    return TonlibError::InvalidQueryId();
  }
  if (((request.id_ ^ config_generation_) & 0xffff) != 0) {
    return TonlibError::InvalidQueryId();
  }
  send_closure(ext_client_outbound_, &ExtClientOutbound::on_query_result, request.id_ >> 16,
               td::Status::Error(request.error_->code_, request.error_->message_)
                   .move_as_error_prefix(TonlibError::LiteServerNetwork()),
               to_any_promise(std::move(promise)));
  return td::Status::OK();
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(tonlib_api::setLogStream& request) {
  auto result = Logging::set_current_stream(std::move(request.log_stream_));
  if (result.is_ok()) {
    return tonlib_api::make_object<tonlib_api::ok>();
  } else {
    return tonlib_api::make_object<tonlib_api::error>(400, result.message().str());
  }
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(const tonlib_api::getLogStream& request) {
  auto result = Logging::get_current_stream();
  if (result.is_ok()) {
    return result.move_as_ok();
  } else {
    return tonlib_api::make_object<tonlib_api::error>(400, result.error().message().str());
  }
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::setLogVerbosityLevel& request) {
  auto result = Logging::set_verbosity_level(static_cast<int>(request.new_verbosity_level_));
  if (result.is_ok()) {
    return tonlib_api::make_object<tonlib_api::ok>();
  } else {
    return tonlib_api::make_object<tonlib_api::error>(400, result.message().str());
  }
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::setLogTagVerbosityLevel& request) {
  auto result = Logging::set_tag_verbosity_level(request.tag_, static_cast<int>(request.new_verbosity_level_));
  if (result.is_ok()) {
    return tonlib_api::make_object<tonlib_api::ok>();
  } else {
    return tonlib_api::make_object<tonlib_api::error>(400, result.message().str());
  }
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::getLogVerbosityLevel& request) {
  return tonlib_api::make_object<tonlib_api::logVerbosityLevel>(Logging::get_verbosity_level());
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::getLogTagVerbosityLevel& request) {
  auto result = Logging::get_tag_verbosity_level(request.tag_);
  if (result.is_ok()) {
    return tonlib_api::make_object<tonlib_api::logVerbosityLevel>(result.ok());
  } else {
    return tonlib_api::make_object<tonlib_api::error>(400, result.error().message().str());
  }
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(const tonlib_api::getLogTags& request) {
  return tonlib_api::make_object<tonlib_api::logTags>(Logging::get_tags());
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(const tonlib_api::addLogMessage& request) {
  Logging::add_message(request.verbosity_level_, request.text_);
  return tonlib_api::make_object<tonlib_api::ok>();
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(const tonlib_api::encrypt& request) {
  return tonlib_api::make_object<tonlib_api::data>(
      SimpleEncryption::encrypt_data(request.decrypted_data_, request.secret_));
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(const tonlib_api::decrypt& request) {
  auto r_data = SimpleEncryption::decrypt_data(request.encrypted_data_, request.secret_);
  if (r_data.is_ok()) {
    return tonlib_api::make_object<tonlib_api::data>(r_data.move_as_ok());
  } else {
    return status_to_tonlib_api(r_data.error().move_as_error_prefix(TonlibError::KeyDecrypt()));
  }
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(const tonlib_api::kdf& request) {
  auto max_iterations = 10000000;
  if (request.iterations_ < 0 || request.iterations_ > max_iterations) {
    return status_to_tonlib_api(
        TonlibError::InvalidField("iterations", PSLICE() << "must be between 0 and " << max_iterations));
  }
  return tonlib_api::make_object<tonlib_api::data>(
      SimpleEncryption::kdf(request.password_, request.salt_, request.iterations_));
}

td::Status TonlibClient::do_request(int_api::GetAccountState request,
                                    td::Promise<td::unique_ptr<AccountState>>&& promise) {
  auto actor_id = actor_id_++;
  actors_[actor_id] = td::actor::create_actor<GetRawAccountState>(
      "GetAccountState", client_.get_client(), request.address, actor_shared(this, actor_id),
      promise.wrap([address = request.address, wallet_id = wallet_id_](auto&& state) mutable {
        return td::make_unique<AccountState>(std::move(address), std::move(state), wallet_id);
      }));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(int_api::GetPrivateKey request, td::Promise<KeyStorage::PrivateKey>&& promise) {
  TRY_RESULT(pk, key_storage_.load_private_key(std::move(request.input_key)));
  promise.set_value(std::move(pk));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(int_api::SendMessage request, td::Promise<td::Unit>&& promise) {
  client_.send_query(ton::lite_api::liteServer_sendMessage(vm::std_boc_serialize(request.message).move_as_ok()),
                     to_any_promise(std::move(promise)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::liteServer_getInfo& request,
                                    td::Promise<object_ptr<tonlib_api::liteServer_info>>&& promise) {
  client_.send_query(ton::lite_api::liteServer_getVersion(), promise.wrap([](auto&& version) {
    return tonlib_api::make_object<tonlib_api::liteServer_info>(version->now_, version->version_,
                                                                version->capabilities_);
  }));
  return td::Status::OK();
}

template <class P>
td::Status TonlibClient::do_request(const tonlib_api::runTests& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::raw_getAccountAddress& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::testWallet_getAccountAddress& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::wallet_getAccountAddress& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::wallet_v3_getAccountAddress& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::testGiver_getAccountAddress& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::packAccountAddress& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::unpackAccountAddress& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::options_validateConfig& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(tonlib_api::getBip39Hints& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(tonlib_api::setLogStream& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::getLogStream& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::setLogVerbosityLevel& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::setLogTagVerbosityLevel& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::getLogVerbosityLevel& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::getLogTagVerbosityLevel& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::getLogTags& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::addLogMessage& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::encrypt& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::decrypt& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::kdf& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
}  // namespace tonlib
