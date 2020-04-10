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
#include "smc-envelope/ManualDns.h"
#include "smc-envelope/TestWallet.h"
#include "smc-envelope/Wallet.h"
#include "smc-envelope/WalletV3.h"
#include "smc-envelope/HighloadWallet.h"
#include "smc-envelope/HighloadWalletV2.h"
#include "smc-envelope/TestGiver.h"
#include "smc-envelope/SmartContractCode.h"

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

#include "common/util.h"

namespace tonlib {
namespace int_api {
struct GetAccountState {
  block::StdAddress address;
  td::optional<ton::BlockIdExt> block_id;
  using ReturnType = td::unique_ptr<AccountState>;
};

struct RemoteRunSmcMethod {
  block::StdAddress address;
  td::optional<ton::BlockIdExt> block_id;
  ton::SmartContract::Args args;
  bool need_result{false};

  using ReturnType = RemoteRunSmcMethodReturnType;
};

struct RemoteRunSmcMethodReturnType {
  ton::SmartContract::State smc_state;
  ton::BlockIdExt block_id;
  // result
  // c7
  // libs
};

struct GetPrivateKey {
  KeyStorage::InputKey input_key;
  using ReturnType = KeyStorage::PrivateKey;
};
struct GetDnsResolver {
  using ReturnType = block::StdAddress;
};
struct SendMessage {
  td::Ref<vm::Cell> message;
  using ReturnType = td::Unit;
};
}  // namespace int_api

template <class R, class O, class F>
R downcast_call2(O&& o, F&& f, R res = {}) {
  downcast_call(o, [&](auto& x) { res = f(x); });
  return res;
}

auto to_tonlib_api(const ton::BlockIdExt& blk) {
  return tonlib_api::make_object<tonlib_api::ton_blockIdExt>(
      blk.id.workchain, blk.id.shard, blk.id.seqno, blk.root_hash.as_slice().str(), blk.file_hash.as_slice().str());
}

tonlib_api::object_ptr<tonlib_api::options_configInfo> to_tonlib_api(const TonlibClient::FullConfig& full_config) {
  return tonlib_api::make_object<tonlib_api::options_configInfo>(full_config.wallet_id);
}

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
static block::AccountState create_account_state(ton::tl_object_ptr<ton::lite_api::liteServer_runMethodResult>& from) {
  block::AccountState res;
  res.blk = ton::create_block_id(from->id_);
  res.shard_blk = ton::create_block_id(from->shardblk_);
  res.shard_proof = std::move(from->shard_proof_);
  res.proof = std::move(from->proof_);
  res.state = std::move(from->state_proof_);
  res.is_virtualized = from->mode_ > 0;
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
  ton::BlockIdExt block_id;
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
    guess_type();
  }

  auto to_uninited_accountState() const {
    return tonlib_api::make_object<tonlib_api::uninited_accountState>(raw().frozen_hash);
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
    return tonlib_api::make_object<tonlib_api::raw_accountState>(std::move(code), std::move(data), raw().frozen_hash);
  }

  td::Result<tonlib_api::object_ptr<tonlib_api::raw_fullAccountState>> to_raw_fullAccountState() const {
    auto state = get_smc_state();
    std::string code;
    if (state.code.not_null()) {
      code = to_bytes(state.code);
    }
    std::string data;
    if (state.data.not_null()) {
      data = to_bytes(state.data);
    }
    return tonlib_api::make_object<tonlib_api::raw_fullAccountState>(
        get_balance(), std::move(code), std::move(data), to_transaction_id(raw().info), to_tonlib_api(raw().block_id),
        raw().frozen_hash, get_sync_time());
  }

  td::Result<tonlib_api::object_ptr<tonlib_api::testWallet_accountState>> to_testWallet_accountState() const {
    if (wallet_type_ != SimpleWallet) {
      return TonlibError::AccountTypeUnexpected("TestWallet");
    }
    TRY_RESULT(seqno, ton::TestWallet(get_smc_state()).get_seqno());
    return tonlib_api::make_object<tonlib_api::testWallet_accountState>(static_cast<td::uint32>(seqno));
  }

  td::Result<tonlib_api::object_ptr<tonlib_api::wallet_accountState>> to_wallet_accountState() const {
    if (wallet_type_ != Wallet) {
      return TonlibError::AccountTypeUnexpected("Wallet");
    }
    TRY_RESULT(seqno, ton::Wallet(get_smc_state()).get_seqno());
    return tonlib_api::make_object<tonlib_api::wallet_accountState>(static_cast<td::uint32>(seqno));
  }
  td::Result<tonlib_api::object_ptr<tonlib_api::wallet_v3_accountState>> to_wallet_v3_accountState() const {
    if (wallet_type_ != WalletV3) {
      return TonlibError::AccountTypeUnexpected("WalletV3");
    }
    auto wallet = ton::WalletV3(get_smc_state());
    TRY_RESULT(seqno, wallet.get_seqno());
    TRY_RESULT(wallet_id, wallet.get_wallet_id());
    return tonlib_api::make_object<tonlib_api::wallet_v3_accountState>(static_cast<td::uint32>(wallet_id),
                                                                       static_cast<td::uint32>(seqno));
  }
  td::Result<tonlib_api::object_ptr<tonlib_api::wallet_highload_v1_accountState>> to_wallet_highload_v1_accountState()
      const {
    if (wallet_type_ != HighloadWalletV1) {
      return TonlibError::AccountTypeUnexpected("HighloadWalletV1");
    }
    auto wallet = ton::HighloadWallet(get_smc_state());
    TRY_RESULT(seqno, wallet.get_seqno());
    TRY_RESULT(wallet_id, wallet.get_wallet_id());
    return tonlib_api::make_object<tonlib_api::wallet_highload_v1_accountState>(static_cast<td::uint32>(wallet_id),
                                                                                static_cast<td::uint32>(seqno));
  }
  td::Result<tonlib_api::object_ptr<tonlib_api::wallet_highload_v2_accountState>> to_wallet_highload_v2_accountState()
      const {
    if (wallet_type_ != HighloadWalletV2) {
      return TonlibError::AccountTypeUnexpected("HighloadWalletV2");
    }
    auto wallet = ton::HighloadWalletV2(get_smc_state());
    TRY_RESULT(wallet_id, wallet.get_wallet_id());
    return tonlib_api::make_object<tonlib_api::wallet_highload_v2_accountState>(static_cast<td::uint32>(wallet_id));
  }

  td::Result<tonlib_api::object_ptr<tonlib_api::testGiver_accountState>> to_testGiver_accountState() const {
    if (wallet_type_ != Giver) {
      return TonlibError::AccountTypeUnexpected("TestGiver");
    }
    TRY_RESULT(seqno, ton::TestGiver(get_smc_state()).get_seqno());
    return tonlib_api::make_object<tonlib_api::testGiver_accountState>(static_cast<td::uint32>(seqno));
  }
  td::Result<tonlib_api::object_ptr<tonlib_api::dns_accountState>> to_dns_accountState() const {
    if (wallet_type_ != ManualDns) {
      return TonlibError::AccountTypeUnexpected("ManualDns");
    }
    TRY_RESULT(wallet_id, ton::ManualDns(get_smc_state()).get_wallet_id());
    return tonlib_api::make_object<tonlib_api::dns_accountState>(static_cast<td::uint32>(wallet_id));
  }

  td::Result<tonlib_api::object_ptr<tonlib_api::AccountState>> to_accountState() const {
    auto f = [](auto&& r_x) -> td::Result<tonlib_api::object_ptr<tonlib_api::AccountState>> {
      TRY_RESULT(x, std::move(r_x));
      return std::move(x);
    };

    switch (wallet_type_) {
      case Empty:
        return to_uninited_accountState();
      case Unknown:
        return f(to_raw_accountState());
      case Giver:
        return f(to_testGiver_accountState());
      case SimpleWallet:
        return f(to_testWallet_accountState());
      case Wallet:
        return f(to_wallet_accountState());
      case WalletV3:
        return f(to_wallet_v3_accountState());
      case HighloadWalletV1:
        return f(to_wallet_highload_v1_accountState());
      case HighloadWalletV2:
        return f(to_wallet_highload_v2_accountState());
      case ManualDns:
        return f(to_dns_accountState());
      default:
        UNREACHABLE();
    }
  }

  td::Result<tonlib_api::object_ptr<tonlib_api::fullAccountState>> to_fullAccountState() const {
    TRY_RESULT(account_state, to_accountState());
    return tonlib_api::make_object<tonlib_api::fullAccountState>(get_balance(), to_transaction_id(raw().info),
                                                                 to_tonlib_api(raw().block_id), get_sync_time(),
                                                                 std::move(account_state));
  }

  enum WalletType {
    Empty,
    Unknown,
    Giver,
    SimpleWallet,
    Wallet,
    WalletV3,
    HighloadWalletV1,
    HighloadWalletV2,
    ManualDns
  };
  WalletType get_wallet_type() const {
    return wallet_type_;
  }
  bool is_wallet() const {
    switch (get_wallet_type()) {
      case AccountState::Empty:
      case AccountState::Unknown:
      case AccountState::ManualDns:
        return false;
      case AccountState::Giver:
      case AccountState::SimpleWallet:
      case AccountState::Wallet:
      case AccountState::WalletV3:
      case AccountState::HighloadWalletV1:
      case AccountState::HighloadWalletV2:
        return true;
    }
    UNREACHABLE();
    return false;
  }
  td::unique_ptr<ton::WalletInterface> get_wallet() const {
    switch (get_wallet_type()) {
      case AccountState::Empty:
      case AccountState::Unknown:
      case AccountState::ManualDns:
        return {};
      case AccountState::Giver:
        return td::make_unique<ton::TestGiver>(get_smc_state());
      case AccountState::SimpleWallet:
        return td::make_unique<ton::TestWallet>(get_smc_state());
      case AccountState::Wallet:
        return td::make_unique<ton::Wallet>(get_smc_state());
      case AccountState::WalletV3:
        return td::make_unique<ton::WalletV3>(get_smc_state());
      case AccountState::HighloadWalletV1:
        return td::make_unique<ton::HighloadWallet>(get_smc_state());
      case AccountState::HighloadWalletV2:
        return td::make_unique<ton::HighloadWalletV2>(get_smc_state());
    }
    UNREACHABLE();
    return {};
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

  ton::BlockIdExt get_block_id() const {
    return raw_.block_id;
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
    auto o_revision = ton::WalletV3::guess_revision(address_, key, wallet_id_);
    if (o_revision) {
      wallet_type_ = WalletType::WalletV3;
      wallet_revision_ = o_revision.value();
      set_new_state({ton::WalletV3::get_init_code(wallet_revision_), ton::WalletV3::get_init_data(key, wallet_id_)});
      return wallet_type_;
    }
    o_revision = ton::HighloadWalletV2::guess_revision(address_, key, wallet_id_);
    if (o_revision) {
      wallet_type_ = WalletType::HighloadWalletV2;
      wallet_revision_ = o_revision.value();
      set_new_state({ton::HighloadWalletV2::get_init_code(wallet_revision_),
                     ton::HighloadWalletV2::get_init_data(key, wallet_id_)});
      return wallet_type_;
    }
    o_revision = ton::HighloadWallet::guess_revision(address_, key, wallet_id_);
    if (o_revision) {
      wallet_type_ = WalletType::HighloadWalletV1;
      wallet_revision_ = o_revision.value();
      set_new_state(
          {ton::HighloadWallet::get_init_code(wallet_revision_), ton::HighloadWallet::get_init_data(key, wallet_id_)});
      return wallet_type_;
    }
    o_revision = ton::ManualDns::guess_revision(address_, key, wallet_id_);
    if (o_revision) {
      wallet_type_ = WalletType::ManualDns;
      wallet_revision_ = o_revision.value();
      auto dns = ton::ManualDns::create(key, wallet_id_, wallet_revision_);
      set_new_state(dns->get_state());
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
  td::int32 wallet_revision_{0};
  td::uint32 wallet_id_{0};
  bool has_new_state_{false};

  WalletType guess_type() {
    if (raw_.code.is_null()) {
      wallet_type_ = WalletType::Empty;
      return wallet_type_;
    }
    auto code_hash = raw_.code->get_hash();
    auto o_revision = ton::WalletV3::guess_revision(code_hash);
    if (o_revision) {
      wallet_type_ = WalletType::WalletV3;
      wallet_revision_ = o_revision.value();
      return wallet_type_;
    }
    o_revision = ton::HighloadWalletV2::guess_revision(code_hash);
    if (o_revision) {
      wallet_type_ = WalletType::HighloadWalletV2;
      wallet_revision_ = o_revision.value();
      return wallet_type_;
    }
    o_revision = ton::HighloadWallet::guess_revision(code_hash);
    if (o_revision) {
      wallet_type_ = WalletType::HighloadWalletV1;
      wallet_revision_ = o_revision.value();
      return wallet_type_;
    }
    o_revision = ton::ManualDns::guess_revision(code_hash);
    if (o_revision) {
      wallet_type_ = WalletType::ManualDns;
      wallet_revision_ = o_revision.value();
      return wallet_type_;
    }

    if (code_hash == ton::TestGiver::get_init_code_hash()) {
      wallet_type_ = WalletType::Giver;
    } else if (code_hash == ton::TestWallet::get_init_code_hash()) {
      wallet_type_ = WalletType::SimpleWallet;
    } else if (code_hash == ton::Wallet::get_init_code_hash()) {
      wallet_type_ = WalletType::Wallet;
    } else if (code_hash == ton::HighloadWallet::get_init_code_hash()) {
      wallet_type_ = WalletType::HighloadWalletV1;
    } else {
      LOG(WARNING) << "Unknown code hash: " << td::base64_encode(code_hash.as_slice());
      wallet_type_ = WalletType::Unknown;
    }
    return wallet_type_;
  }
};

class Query {
 public:
  struct Raw {
    td::unique_ptr<AccountState> source;
    std::vector<td::unique_ptr<AccountState>> destinations;

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

  td::Result<td::int64> calc_fwd_fees(td::Ref<vm::Cell> list, block::MsgPrices** msg_prices, bool is_masterchain) {
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

          bool dest_is_masterchain = false;
          if (block::gen::t_CommonMsgInfoRelaxed.get_tag(*msg.info) == block::gen::CommonMsgInfoRelaxed::int_msg_info) {
            block::gen::CommonMsgInfoRelaxed::Record_int_msg_info info;
            if (!tlb::csr_unpack(msg.info, info)) {
              return td::Status::Error("estimate_fee: can't parse send_msg");
            }
            auto dest_addr = info.dest;
            if (!dest_addr->prefetch_ulong(1)) {
              return td::Status::Error("estimate_fee: messages with external addresses are unsupported");
            }
            int tag = block::gen::t_MsgAddressInt.get_tag(*dest_addr);

            if (tag == block::gen::MsgAddressInt::addr_std) {
              block::gen::MsgAddressInt::Record_addr_std recs;
              if (!tlb::csr_unpack(dest_addr, recs)) {
                return td::Status::Error("estimate_fee: can't parse send_msg");
              }
              dest_is_masterchain = recs.workchain_id == ton::masterchainId;
            }
          }
          vm::CellStorageStat sstat;                  // for message size
          sstat.add_used_storage(msg.init, true, 3);  // message init
          sstat.add_used_storage(msg.body, true, 3);  // message body (the root cell itself is not counted)
          res += msg_prices[is_masterchain || dest_is_masterchain]->compute_fwd_fees(sstat.cells, sstat.bits);
          break;
        }
        case block::gen::OutAction::action_reserve_currency:
          return td::Status::Error("estimate_fee: action_reserve_currency unsupported");
      }
    }
    return res;
  }
  td::Result<std::pair<Fee, std::vector<Fee>>> estimate_fees(bool ignore_chksig, const block::Config& cfg) {
    // gas fees
    bool is_masterchain = raw_.source->get_address().workchain == ton::masterchainId;
    TRY_RESULT(gas_limits_prices, cfg.get_gas_limits_prices(is_masterchain));
    TRY_RESULT(storage_prices, cfg.get_storage_prices());
    TRY_RESULT(masterchain_msg_prices, cfg.get_msg_prices(true));
    TRY_RESULT(basechain_msg_prices, cfg.get_msg_prices(false));
    block::MsgPrices* msg_prices[2] = {&basechain_msg_prices, &masterchain_msg_prices};
    auto storage_fee_256 = block::StoragePrices::compute_storage_fees(
        raw_.source->get_sync_time(), storage_prices, raw_.source->raw().storage_stat,
        raw_.source->raw().storage_last_paid, false, is_masterchain);
    auto storage_fee = storage_fee_256.is_null() ? 0 : storage_fee_256->to_long();

    auto smc = ton::SmartContract::create(raw_.source->get_smc_state());

    td::int64 in_fwd_fee = 0;
    {
      vm::CellStorageStat sstat;                      // for message size
      sstat.add_used_storage(raw_.message, true, 3);  // message init
      in_fwd_fee += msg_prices[is_masterchain]->compute_fwd_fees(sstat.cells, sstat.bits);
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

      TRY_RESULT_ASSIGN(fwd_fee, calc_fwd_fees(res.actions, msg_prices, is_masterchain));
    }

    auto gas_fee = res.accepted ? compute_gas_price(res.gas_used, gas_limits_prices)->to_long() : 0;
    LOG(ERROR) << storage_fee << " " << in_fwd_fee << " " << gas_fee << " " << fwd_fee;

    Fee fee;
    fee.in_fwd_fee = in_fwd_fee;
    fee.storage_fee = storage_fee;
    fee.gas_fee = gas_fee;
    fee.fwd_fee = fwd_fee;

    std::vector<Fee> dst_fees;

    for (auto& destination : raw_.destinations) {
      bool dest_is_masterchain = destination && destination->get_address().workchain == ton::masterchainId;
      TRY_RESULT(dest_gas_limits_prices, cfg.get_gas_limits_prices(dest_is_masterchain));
      auto dest_storage_fee_256 =
          destination ? block::StoragePrices::compute_storage_fees(
                            destination->get_sync_time(), storage_prices, destination->raw().storage_stat,
                            destination->raw().storage_last_paid, false, is_masterchain)
                      : td::make_refint(0);
      Fee dst_fee;
      auto dest_storage_fee = dest_storage_fee_256.is_null() ? 0 : dest_storage_fee_256->to_long();
      if (destination && destination->get_wallet_type() != AccountState::WalletType::Empty) {
        dst_fee.gas_fee = dest_gas_limits_prices.flat_gas_price;
        dst_fee.storage_fee = dest_storage_fee;
      }
      dst_fees.push_back(dst_fee);
    }
    return std::make_pair(fee, dst_fees);
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

class RemoteRunSmcMethod : public td::actor::Actor {
 public:
  RemoteRunSmcMethod(ExtClientRef ext_client_ref, int_api::RemoteRunSmcMethod query, td::actor::ActorShared<> parent,
                     td::Promise<int_api::RemoteRunSmcMethod::ReturnType>&& promise)
      : query_(std::move(query)), promise_(std::move(promise)), parent_(std::move(parent)) {
    client_.set_client(ext_client_ref);
  }

 private:
  int_api::RemoteRunSmcMethod query_;
  td::Promise<int_api::RemoteRunSmcMethod::ReturnType> promise_;
  td::actor::ActorShared<> parent_;
  ExtClient client_;

  void with_run_method_result(
      td::Result<ton::tl_object_ptr<ton::lite_api::liteServer_runMethodResult>> r_run_method_result) {
    check(do_with_run_method_result(std::move(r_run_method_result)));
  }

  td::Status do_with_run_method_result(
      td::Result<ton::tl_object_ptr<ton::lite_api::liteServer_runMethodResult>> r_run_method_result) {
    TRY_RESULT(run_method_result, std::move(r_run_method_result));
    TRY_RESULT_PREFIX(state, TRY_VM(do_with_run_method_result(std::move(run_method_result))),
                      TonlibError::ValidateAccountState());
    promise_.set_value(std::move(state));
    stop();
    return td::Status::OK();
  }
  td::Result<int_api::RemoteRunSmcMethod::ReturnType> do_with_run_method_result(
      ton::tl_object_ptr<ton::lite_api::liteServer_runMethodResult> run_method_result) {
    auto account_state = create_account_state(run_method_result);
    TRY_RESULT(info, account_state.validate(query_.block_id.value(), query_.address));
    auto serialized_state = account_state.state.clone();
    int_api::RemoteRunSmcMethod::ReturnType res;
    res.block_id = query_.block_id.value();
    auto cell = info.root;
    if (cell.is_null()) {
      return res;
    }
    block::gen::Account::Record_account account;
    if (!tlb::unpack_cell(cell, account)) {
      return td::Status::Error("Failed to unpack Account");
    }

    block::gen::AccountStorage::Record storage;
    if (!tlb::csr_unpack(account.storage, storage)) {
      return td::Status::Error("Failed to unpack AccountStorage");
    }
    auto state_tag = block::gen::t_AccountState.get_tag(*storage.state);
    if (state_tag < 0) {
      return td::Status::Error("Failed to parse AccountState tag");
    }
    if (state_tag != block::gen::AccountState::account_active) {
      return td::Status::Error("Account is not active");
    }
    block::gen::AccountState::Record_account_active state;
    if (!tlb::csr_unpack(storage.state, state)) {
      return td::Status::Error("Failed to parse AccountState");
    }
    block::gen::StateInit::Record state_init;
    if (!tlb::csr_unpack(state.x, state_init)) {
      return td::Status::Error("Failed to parse StateInit");
    }
    state_init.code->prefetch_maybe_ref(res.smc_state.code);
    state_init.data->prefetch_maybe_ref(res.smc_state.data);
    return res;
  }

  void with_last_block(td::Result<LastBlockState> r_last_block) {
    check(do_with_last_block(std::move(r_last_block)));
  }

  td::Status with_block_id() {
    TRY_RESULT(method_id, query_.args.get_method_id());
    TRY_RESULT(serialized_stack, query_.args.get_serialized_stack());
    client_.send_query(
        //liteServer.runSmcMethod mode:# id:tonNode.blockIdExt account:liteServer.accountId method_id:long params:bytes = liteServer.RunMethodResult;
        ton::lite_api::liteServer_runSmcMethod(
            0x1f, ton::create_tl_lite_block_id(query_.block_id.value()),
            ton::create_tl_object<ton::lite_api::liteServer_accountId>(query_.address.workchain, query_.address.addr),
            method_id, std::move(serialized_stack)),
        [self = this](auto r_state) { self->with_run_method_result(std::move(r_state)); },
        query_.block_id.value().id.seqno);
    return td::Status::OK();
  }

  td::Status do_with_last_block(td::Result<LastBlockState> r_last_block) {
    TRY_RESULT(last_block, std::move(r_last_block));
    query_.block_id = std::move(last_block.last_block_id);
    with_block_id();
    return td::Status::OK();
  }

  void start_up() override {
    if (query_.block_id) {
      check(with_block_id());
    } else {
      client_.with_last_block(
          [self = this](td::Result<LastBlockState> r_last_block) { self->with_last_block(std::move(r_last_block)); });
    }
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

class GetRawAccountState : public td::actor::Actor {
 public:
  GetRawAccountState(ExtClientRef ext_client_ref, block::StdAddress address, td::optional<ton::BlockIdExt> block_id,
                     td::actor::ActorShared<> parent, td::Promise<RawAccountState>&& promise)
      : address_(std::move(address))
      , block_id_(std::move(block_id))
      , promise_(std::move(promise))
      , parent_(std::move(parent)) {
    client_.set_client(ext_client_ref);
  }

 private:
  block::StdAddress address_;
  td::optional<ton::BlockIdExt> block_id_;
  td::Promise<RawAccountState> promise_;
  td::actor::ActorShared<> parent_;
  ExtClient client_;

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
    TRY_RESULT(info, account_state.validate(block_id_.value(), address_));
    auto serialized_state = account_state.state.clone();
    RawAccountState res;
    res.block_id = block_id_.value();
    res.info = std::move(info);
    auto cell = res.info.root;
    //std::ostringstream outp;
    //block::gen::t_Account.print_ref(outp, cell);
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

  void with_block_id() {
    client_.send_query(
        ton::lite_api::liteServer_getAccountState(
            ton::create_tl_lite_block_id(block_id_.value()),
            ton::create_tl_object<ton::lite_api::liteServer_accountId>(address_.workchain, address_.addr)),
        [self = this](auto r_state) { self->with_account_state(std::move(r_state)); }, block_id_.value().id.seqno);
  }

  td::Status do_with_last_block(td::Result<LastBlockState> r_last_block) {
    TRY_RESULT(last_block, std::move(r_last_block));
    block_id_ = std::move(last_block.last_block_id);
    with_block_id();
    return td::Status::OK();
  }

  void start_up() override {
    if (block_id_) {
      with_block_id();
    } else {
      client_.with_last_block(
          [self = this](td::Result<LastBlockState> r_last_block) { self->with_last_block(std::move(r_last_block)); });
    }
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

  last_block_storage_.save_state(last_state_key_, state);
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

void TonlibClient::init_last_block(LastBlockState state) {
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

  last_block_storage_.save_state(last_state_key_, state);

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

void TonlibClient::make_any_request(tonlib_api::Function& function, QueryContext query_context,
                                    td::Promise<tonlib_api::object_ptr<tonlib_api::Object>>&& promise) {
  auto old_context = std::move(query_context_);
  SCOPE_EXIT {
    query_context_ = std::move(old_context);
  };
  query_context_ = std::move(query_context);
  downcast_call(function, [&](auto& request) { this->make_request(request, promise.wrap([](auto x) { return x; })); });
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

  ref_cnt_++;
  using Object = tonlib_api::object_ptr<tonlib_api::Object>;
  td::Promise<Object> promise = [actor_id = actor_id(this), id, tmp = actor_shared(this)](td::Result<Object> r_result) {
    tonlib_api::object_ptr<tonlib_api::Object> result;
    if (r_result.is_error()) {
      result = status_to_tonlib_api(r_result.error());
    } else {
      result = r_result.move_as_ok();
    }

    send_closure(actor_id, &TonlibClient::on_result, id, std::move(result));
  };

  make_any_request(*function, {}, std::move(promise));
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

  auto response = downcast_call2<tonlib_api::object_ptr<tonlib_api::Object>>(
      *function, [](auto& request) { return TonlibClient::do_static_request(request); });
  VLOG(tonlib_query) << "  answer static query " << to_string(response);
  return response;
}

bool TonlibClient::is_static_request(td::int32 id) {
  switch (id) {
    case tonlib_api::runTests::ID:
    case tonlib_api::getAccountAddress::ID:
    case tonlib_api::packAccountAddress::ID:
    case tonlib_api::unpackAccountAddress::ID:
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
    case tonlib_api::msg_decryptWithProof::ID:
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

td::Result<block::StdAddress> get_account_address(const tonlib_api::raw_initialAccountState& raw_state,
                                                  td::int32 revision) {
  TRY_RESULT_PREFIX(code, vm::std_boc_deserialize(raw_state.code_), TonlibError::InvalidBagOfCells("raw_state.code"));
  TRY_RESULT_PREFIX(data, vm::std_boc_deserialize(raw_state.data_), TonlibError::InvalidBagOfCells("raw_state.data"));
  return ton::GenericAccount::get_address(0 /*zerochain*/,
                                          ton::GenericAccount::get_init_state(std::move(code), std::move(data)));
}

td::Result<block::StdAddress> get_account_address(const tonlib_api::testGiver_initialAccountState& test_wallet_state,
                                                  td::int32 revision) {
  return ton::TestGiver::address();
}

td::Result<block::StdAddress> get_account_address(const tonlib_api::testWallet_initialAccountState& test_wallet_state,
                                                  td::int32 revision) {
  TRY_RESULT(key_bytes, get_public_key(test_wallet_state.public_key_));
  auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));
  return ton::GenericAccount::get_address(0 /*zerochain*/, ton::TestWallet::get_init_state(key, revision));
}

td::Result<block::StdAddress> get_account_address(const tonlib_api::wallet_initialAccountState& wallet_state,
                                                  td::int32 revision) {
  TRY_RESULT(key_bytes, get_public_key(wallet_state.public_key_));
  auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));
  return ton::GenericAccount::get_address(0 /*zerochain*/, ton::Wallet::get_init_state(key, revision));
}
td::Result<block::StdAddress> get_account_address(const tonlib_api::wallet_v3_initialAccountState& test_wallet_state,
                                                  td::int32 revision) {
  TRY_RESULT(key_bytes, get_public_key(test_wallet_state.public_key_));
  auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));
  return ton::GenericAccount::get_address(
      0 /*zerochain*/,
      ton::WalletV3::get_init_state(key, static_cast<td::uint32>(test_wallet_state.wallet_id_), revision));
}

td::Result<block::StdAddress> get_account_address(
    const tonlib_api::wallet_highload_v1_initialAccountState& test_wallet_state, td::int32 revision) {
  TRY_RESULT(key_bytes, get_public_key(test_wallet_state.public_key_));
  auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));
  return ton::GenericAccount::get_address(
      0 /*zerochain*/,
      ton::HighloadWallet::get_init_state(key, static_cast<td::uint32>(test_wallet_state.wallet_id_), revision));
}

td::Result<block::StdAddress> get_account_address(
    const tonlib_api::wallet_highload_v2_initialAccountState& test_wallet_state, td::int32 revision) {
  TRY_RESULT(key_bytes, get_public_key(test_wallet_state.public_key_));
  auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));
  return ton::GenericAccount::get_address(
      0 /*zerochain*/,
      ton::HighloadWalletV2::get_init_state(key, static_cast<td::uint32>(test_wallet_state.wallet_id_), revision));
}

td::Result<block::StdAddress> get_account_address(const tonlib_api::dns_initialAccountState& dns_state,
                                                  td::int32 revision) {
  TRY_RESULT(key_bytes, get_public_key(dns_state.public_key_));
  auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));
  return ton::ManualDns::create(key, static_cast<td::uint32>(dns_state.wallet_id_), revision)->get_address();
}

td::Result<block::StdAddress> get_account_address(td::Slice account_address) {
  TRY_RESULT_PREFIX(address, block::StdAddress::parse(account_address), TonlibError::InvalidAccountAddress());
  return address;
}

td::Result<td::Bits256> get_adnl_address(td::Slice adnl_address) {
  TRY_RESULT_PREFIX(address, td::adnl_id_decode(adnl_address),
                    TonlibError::InvalidField("adnl_address", "can't decode"));
  return address;
}

static td::optional<ton::SmartContractCode::Type> get_wallet_type(tonlib_api::InitialAccountState& state) {
  return downcast_call2<td::optional<ton::SmartContractCode::Type>>(
      state,
      td::overloaded(
          [](const tonlib_api::raw_initialAccountState&) { return td::optional<ton::SmartContractCode::Type>(); },
          [](const tonlib_api::testGiver_initialAccountState&) { return td::optional<ton::SmartContractCode::Type>(); },
          [](const tonlib_api::testWallet_initialAccountState&) { return ton::SmartContractCode::WalletV1; },
          [](const tonlib_api::wallet_initialAccountState&) { return ton::SmartContractCode::WalletV2; },
          [](const tonlib_api::wallet_v3_initialAccountState&) { return ton::SmartContractCode::WalletV3; },
          [](const tonlib_api::wallet_highload_v1_initialAccountState&) {
            return ton::SmartContractCode::HighloadWalletV1;
          },
          [](const tonlib_api::wallet_highload_v2_initialAccountState&) {
            return ton::SmartContractCode::HighloadWalletV2;
          },
          [](const tonlib_api::dns_initialAccountState&) { return ton::SmartContractCode::ManualDns; }));
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::getAccountAddress& request) {
  if (!request.initial_account_state_) {
    return status_to_tonlib_api(TonlibError::EmptyField("initial_account_state"));
  }
  auto o_type = get_wallet_type(*request.initial_account_state_);
  if (o_type) {
    auto status = ton::SmartContractCode::validate_revision(o_type.value(), request.revision_);
    if (status.is_error()) {
      return status_to_tonlib_api(TonlibError::InvalidRevision());
    }
  }
  auto r_account_address = downcast_call2<td::Result<block::StdAddress>>(
      *request.initial_account_state_,
      [&request](auto&& state) { return get_account_address(state, request.revision_); });
  if (r_account_address.is_error()) {
    return status_to_tonlib_api(r_account_address.error());
  }
  return tonlib_api::make_object<tonlib_api::accountAddress>(r_account_address.ok().rserialize(true));
}

td::Status TonlibClient::do_request(const tonlib_api::guessAccountRevision& request,
                                    td::Promise<object_ptr<tonlib_api::accountRevisionList>>&& promise) {
  if (!request.initial_account_state_) {
    return TonlibError::EmptyField("initial_account_state");
  }
  auto o_type = get_wallet_type(*request.initial_account_state_);
  if (!o_type) {
    promise.set_value(tonlib_api::make_object<tonlib_api::accountRevisionList>(std::vector<td::int32>{0}));
    return td::Status::OK();
  }
  auto revisions = ton::SmartContractCode::get_revisions(o_type.value());

  std::vector<std::pair<int, block::StdAddress>> addresses;
  TRY_STATUS(downcast_call2<td::Status>(*request.initial_account_state_, [&revisions, &addresses](const auto& state) {
    for (auto revision : revisions) {
      TRY_RESULT(address, get_account_address(state, revision));
      addresses.push_back(std::make_pair(revision, address));
    }
    return td::Status::OK();
  }));

  auto actor_id = actor_id_++;
  class GuessRevisions : public TonlibQueryActor {
   public:
    GuessRevisions(td::actor::ActorShared<TonlibClient> client, td::optional<ton::BlockIdExt> block_id,
                   std::vector<std::pair<int, block::StdAddress>> addresses, td::Promise<std::vector<int>> promise)
        : TonlibQueryActor(std::move(client))
        , block_id_(std::move(block_id))
        , addresses_(std::move(addresses))
        , promise_(std::move(promise)) {
    }

   private:
    td::optional<ton::BlockIdExt> block_id_;
    std::vector<std::pair<int, block::StdAddress>> addresses_;
    td::Promise<std::vector<int>> promise_;

    size_t left_{0};
    std::vector<int> res;

    void start_up() {
      left_ += addresses_.size();
      for (auto& p : addresses_) {
        send_query(int_api::GetAccountState{p.second, block_id_.copy()},
                   promise_send_closure(td::actor::actor_id(this), &GuessRevisions::on_account_state, p.first));
      }
    }
    void on_account_state(int revision, td::Result<td::unique_ptr<AccountState>> r_state) {
      if (r_state.is_ok() && r_state.ok()->get_wallet_type() != AccountState::WalletType::Empty) {
        res.push_back(revision);
      }
      left_--;
      if (left_ == 0) {
        promise_.set_value(std::move(res));
        stop();
      }
    }
  };

  actors_[actor_id] = td::actor::create_actor<GuessRevisions>(
      "GuessRevisions", actor_shared(this, actor_id), query_context_.block_id.copy(), std::move(addresses),
      promise.wrap(
          [](auto&& x) mutable { return tonlib_api::make_object<tonlib_api::accountRevisionList>(std::move(x)); }));
  return td::Status::OK();
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
                                    td::Promise<object_ptr<tonlib_api::options_info>>&& promise) {
  if (state_ != State::Uninited) {
    return td::Status::Error(400, "Tonlib is already inited");
  }
  if (!request.options_) {
    return TonlibError::EmptyField("options");
  }
  if (!request.options_->keystore_type_) {
    return TonlibError::EmptyField("options.keystore_type");
  }

  auto r_kv = downcast_call2<td::Result<td::unique_ptr<KeyValue>>>(
      *request.options_->keystore_type_,
      td::overloaded(
          [](tonlib_api::keyStoreTypeDirectory& directory) { return KeyValue::create_dir(directory.directory_); },
          [](tonlib_api::keyStoreTypeInMemory& inmemory) { return KeyValue::create_inmemory(); }));
  TRY_RESULT(kv, std::move(r_kv));
  kv_ = std::shared_ptr<KeyValue>(kv.release());

  key_storage_.set_key_value(kv_);
  last_block_storage_.set_key_value(kv_);
  auto res = tonlib_api::make_object<tonlib_api::options_info>();
  if (request.options_->config_) {
    TRY_RESULT(full_config, validate_config(std::move(request.options_->config_)));
    res->config_info_ = to_tonlib_api(full_config);
    set_config(std::move(full_config));
  }
  state_ = State::Running;
  promise.set_value(std::move(res));
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
    res.add_config("testnet2", R"abc({
  "liteservers": [
    {
      "ip": 1137658550,
      "port": 4924,
      "id": {
        "@type": "pub.ed25519",
        "key": "peJTw/arlRfssgTuf9BMypJzqOi7SXEqSPSWiEw2U1M="
      }
    }
  ],
  "validator": {
    "@type": "validator.config.global",
    "zero_state": {
      "workchain": -1,
      "shard": -9223372036854775808,
      "seqno": 0,
      "root_hash": "F6OpKZKqvqeFp6CQmFomXNMfMj2EnaUSOXN+Mh+wVWk=",
      "file_hash": "XplPz01CXAps5qeSWUtxcyBfdAo5zVb1N979KLSKD24="
    },
    "init_block": {"workchain":-1,"shard":-9223372036854775808,"seqno":2908451,"root_hash":"5+7X1QHVUBFLFMwa/yd/2fGzt2KeQtwr+o6UUFOQ7Qc=","file_hash":"gmiUgrtAbvEJZYDEkcbeNOhGPS3g+qCepSOEBFLZFzk="}
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
  std::string last_state_key;
  if (config->blockchain_name_.empty()) {
    last_state_key = new_config.zero_state_id.root_hash.as_slice().str();
    o_master_config = get_default_master_config().by_root_hash(new_config.zero_state_id.root_hash);
  } else {
    last_state_key = config->blockchain_name_;
    o_master_config = get_default_master_config().by_name(config->blockchain_name_);
  }

  if (o_master_config && o_master_config.value().zero_state_id != new_config.zero_state_id) {
    return TonlibError::InvalidConfig("zero_state differs from embedded zero_state");
  }

  LastBlockState state;
  td::Result<LastBlockState> r_state;
  if (!config->ignore_cache_) {
    r_state = last_block_storage_.get_state(last_state_key);
  }
  auto zero_state = ton::ZeroStateIdExt(new_config.zero_state_id.id.workchain, new_config.zero_state_id.root_hash,
                                        new_config.zero_state_id.file_hash);
  if (config->ignore_cache_ || r_state.is_error()) {
    LOG_IF(WARNING, !config->ignore_cache_) << "Unknown LastBlockState: " << r_state.error();
    state.zero_state_id = zero_state;
    state.last_block_id = new_config.zero_state_id;
    state.last_key_block_id = new_config.zero_state_id;
  } else {
    state = r_state.move_as_ok();
    if (state.zero_state_id != zero_state) {
      LOG(ERROR) << state.zero_state_id.to_str() << " " << zero_state.to_str();
      return TonlibError::InvalidConfig("zero_state differs from cached zero_state");
    }
  }

  if (o_master_config) {
    auto master_config = o_master_config.unwrap();
    if (master_config.init_block_id.is_valid() &&
        state.last_key_block_id.id.seqno < master_config.init_block_id.id.seqno) {
      state.last_key_block_id = master_config.init_block_id;
      LOG(INFO) << "Use init block from MASTER config: " << master_config.init_block_id.to_str();
    }
  }

  FullConfig res;
  res.config = std::move(new_config);
  res.use_callbacks_for_network = config->use_callbacks_for_network_;
  res.wallet_id = td::as<td::uint32>(res.config.zero_state_id.root_hash.as_slice().data());
  res.last_state_key = std::move(last_state_key);
  res.last_state = std::move(state);

  return std::move(res);
}

void TonlibClient::set_config(FullConfig full_config) {
  config_ = std::move(full_config.config);
  config_generation_++;
  wallet_id_ = full_config.wallet_id;
  last_state_key_ = full_config.last_state_key;

  use_callbacks_for_network_ = full_config.use_callbacks_for_network;
  init_ext_client();
  init_last_block(std::move(full_config.last_state));
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

td::Status TonlibClient::do_request(tonlib_api::options_validateConfig& request,
                                    td::Promise<object_ptr<tonlib_api::options_configInfo>>&& promise) {
  TRY_RESULT(config, validate_config(std::move(request.config_)));
  auto res = to_tonlib_api(config);
  promise.set_value(std::move(res));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::options_setConfig& request,
                                    td::Promise<object_ptr<tonlib_api::options_configInfo>>&& promise) {
  if (!request.config_) {
    return TonlibError::EmptyField("config");
  }
  TRY_RESULT(config, validate_config(std::move(request.config_)));
  auto res = to_tonlib_api(config);
  set_config(std::move(config));
  promise.set_value(std::move(res));
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
struct ToRawTransactions {
  explicit ToRawTransactions(td::optional<td::Ed25519::PrivateKey> private_key) : private_key_(std::move(private_key)) {
  }

  td::optional<td::Ed25519::PrivateKey> private_key_;
  td::Result<tonlib_api::object_ptr<tonlib_api::raw_message>> to_raw_message_or_throw(td::Ref<vm::Cell> cell) {
    block::gen::Message::Record message;
    if (!tlb::type_unpack_cell(cell, block::gen::t_Message_Any, message)) {
      return td::Status::Error("Failed to unpack Message");
    }

    td::Ref<vm::CellSlice> body;
    if (message.body->prefetch_long(1) == 0) {
      body = std::move(message.body);
      body.write().advance(1);
    } else {
      body = vm::load_cell_slice_ref(message.body->prefetch_ref());
    }
    auto body_cell = vm::CellBuilder().append_cellslice(*body).finalize();
    auto body_hash = body_cell->get_hash().as_slice().str();

    auto get_data = [body = std::move(body), body_cell, this](td::Slice salt) mutable {
      tonlib_api::object_ptr<tonlib_api::msg_Data> data;
      if (body->size() >= 32 && static_cast<td::uint32>(body->prefetch_long(32)) <= 1) {
        auto type = body.write().fetch_long(32);
        td::Status status;

        auto r_body_message = vm::CellString::load(body.write());
        LOG_IF(WARNING, r_body_message.is_error()) << "Failed to parse a message: " << r_body_message.error();

        if (r_body_message.is_ok()) {
          if (type == 0) {
            data = tonlib_api::make_object<tonlib_api::msg_dataText>(r_body_message.move_as_ok());
          } else {
            LOG(ERROR) << "TRY DECRYPT";
            auto encrypted_message = r_body_message.move_as_ok();
            auto r_decrypted_message = [&]() -> td::Result<std::string> {
              if (!private_key_) {
                return TonlibError::EmptyField("private_key");
              }
              TRY_RESULT(decrypted, SimpleEncryptionV2::decrypt_data(encrypted_message, private_key_.value(), salt));
              return decrypted.data.as_slice().str();
            }();
            if (r_decrypted_message.is_ok()) {
              data = tonlib_api::make_object<tonlib_api::msg_dataDecryptedText>(r_decrypted_message.move_as_ok());
            } else {
              data = tonlib_api::make_object<tonlib_api::msg_dataEncryptedText>(encrypted_message);
            }
          }
        }
      }
      if (!data) {
        data = tonlib_api::make_object<tonlib_api::msg_dataRaw>(to_bytes(std::move(body_cell)));
      }
      return data;
    };

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

        return tonlib_api::make_object<tonlib_api::raw_message>(
            tonlib_api::make_object<tonlib_api::accountAddress>(src),
            tonlib_api::make_object<tonlib_api::accountAddress>(std::move(dest)), balance, fwd_fee, ihr_fee, created_lt,
            std::move(body_hash), get_data(src));
      }
      case block::gen::CommonMsgInfo::ext_in_msg_info: {
        block::gen::CommonMsgInfo::Record_ext_in_msg_info msg_info;
        if (!tlb::csr_unpack(message.info, msg_info)) {
          return td::Status::Error("Failed to unpack CommonMsgInfo::ext_in_msg_info");
        }
        TRY_RESULT(dest, to_std_address(msg_info.dest));
        return tonlib_api::make_object<tonlib_api::raw_message>(
            tonlib_api::make_object<tonlib_api::accountAddress>(),
            tonlib_api::make_object<tonlib_api::accountAddress>(std::move(dest)), 0, 0, 0, 0, std::move(body_hash),
            get_data(""));
      }
      case block::gen::CommonMsgInfo::ext_out_msg_info: {
        block::gen::CommonMsgInfo::Record_ext_out_msg_info msg_info;
        if (!tlb::csr_unpack(message.info, msg_info)) {
          return td::Status::Error("Failed to unpack CommonMsgInfo::ext_out_msg_info");
        }
        TRY_RESULT(src, to_std_address(msg_info.src));
        return tonlib_api::make_object<tonlib_api::raw_message>(
            tonlib_api::make_object<tonlib_api::accountAddress>(src),
            tonlib_api::make_object<tonlib_api::accountAddress>(), 0, 0, 0, 0, std::move(body_hash), get_data(src));
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
      //LOG(ERROR) << fees;

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
};

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
                                    td::Promise<object_ptr<tonlib_api::raw_fullAccountState>>&& promise) {
  if (!request.account_address_) {
    return TonlibError::EmptyField("account_address");
  }
  TRY_RESULT(account_address, get_account_address(request.account_address_->account_address_));
  make_request(int_api::GetAccountState{std::move(account_address), query_context_.block_id.copy()},
               promise.wrap([](auto&& res) { return res->to_raw_fullAccountState(); }));
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
  return downcast_call2<td::Result<KeyStorage::InputKey>>(
      input_key, td::overloaded([&](tonlib_api::inputKeyRegular& input_key) { return from_tonlib(input_key); },
                                [&](tonlib_api::inputKeyFake&) { return KeyStorage::fake_input_key(); }));
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
  td::optional<td::Ed25519::PrivateKey> private_key;
  if (request.private_key_) {
    TRY_RESULT(input_key, from_tonlib(*request.private_key_));
    //NB: options<Status> has lot of problems. We use emplace to migitate them
    td::optional<td::Status> o_status;
    //NB: rely on (and assert) that GetPrivateKey is a synchonous request
    make_request(int_api::GetPrivateKey{std::move(input_key)}, [&](auto&& r_key) {
      if (r_key.is_error()) {
        o_status.emplace(r_key.move_as_error());
        return;
      }
      o_status.emplace(td::Status::OK());
      private_key = td::Ed25519::PrivateKey(std::move(r_key.move_as_ok().private_key));
    });
    TRY_STATUS(o_status.unwrap());
  }
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
      promise.wrap([private_key = std::move(private_key)](auto&& x) mutable {
        return ToRawTransactions(std::move(private_key)).to_raw_transactions(std::move(x));
      }));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::getAccountState& request,
                                    td::Promise<object_ptr<tonlib_api::fullAccountState>>&& promise) {
  if (!request.account_address_) {
    return TonlibError::EmptyField("account_address");
  }
  TRY_RESULT(account_address, get_account_address(request.account_address_->account_address_));
  make_request(int_api::GetAccountState{std::move(account_address), query_context_.block_id.copy()},
               promise.wrap([](auto&& res) { return res->to_fullAccountState(); }));
  return td::Status::OK();
}

td::Result<ton::ManualDns::EntryData> to_dns_entry_data(tonlib_api::dns_EntryData& entry_data) {
  using R = td::Result<ton::ManualDns::EntryData>;
  return downcast_call2<R>(
      entry_data,
      td::overloaded(
          [&](tonlib_api::dns_entryDataUnknown& unknown) -> R { return ton::ManualDns::EntryData(); },
          [&](tonlib_api::dns_entryDataNextResolver& next_resolver) -> R {
            if (!next_resolver.resolver_) {
              return TonlibError::EmptyField("resolver");
            }
            TRY_RESULT(resolver, get_account_address(next_resolver.resolver_->account_address_));
            return ton::ManualDns::EntryData::next_resolver(std::move(resolver));
          },
          [&](tonlib_api::dns_entryDataSmcAddress& smc_address) -> R {
            if (!smc_address.smc_address_) {
              return TonlibError::EmptyField("smc_address");
            }
            TRY_RESULT(address, get_account_address(smc_address.smc_address_->account_address_));
            return ton::ManualDns::EntryData::smc_address(std::move(address));
          },
          [&](tonlib_api::dns_entryDataAdnlAddress& adnl_address) -> R {
            if (!adnl_address.adnl_address_) {
              return TonlibError::EmptyField("adnl_address");
            }
            TRY_RESULT(address, get_adnl_address(adnl_address.adnl_address_->adnl_address_));
            return ton::ManualDns::EntryData::adnl_address(std::move(address));
          },
          [&](tonlib_api::dns_entryDataText& text) -> R { return ton::ManualDns::EntryData::text(text.text_); }));
}

class GenericCreateSendGrams : public TonlibQueryActor {
 public:
  GenericCreateSendGrams(td::actor::ActorShared<TonlibClient> client, tonlib_api::createQuery query,
                         td::optional<ton::BlockIdExt> block_id, td::Promise<td::unique_ptr<Query>>&& promise)
      : TonlibQueryActor(std::move(client))
      , query_(std::move(query))
      , promise_(std::move(promise))
      , block_id_(std::move(block_id)) {
  }

 private:
  tonlib_api::createQuery query_;
  td::Promise<td::unique_ptr<Query>> promise_;

  td::unique_ptr<AccountState> source_;
  std::vector<td::unique_ptr<AccountState>> destinations_;
  size_t destinations_left_ = 0;
  bool has_private_key_{false};
  bool is_fake_key_{false};
  td::optional<td::Ed25519::PrivateKey> private_key_;
  td::optional<td::Ed25519::PublicKey> public_key_;
  td::optional<ton::BlockIdExt> block_id_;

  struct Action {
    block::StdAddress destination;
    td::int64 amount;

    bool is_encrypted{false};
    bool should_encrypt;
    std::string message;

    td::Ref<vm::Cell> body;

    td::optional<td::Ed25519::PublicKey> o_public_key;
  };
  bool allow_send_to_uninited_{false};
  std::vector<Action> actions_;

  // We combine compelty different actions in one actor
  // Should be splitted eventually
  std::vector<ton::ManualDns::Action> dns_actions_;

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

  td::Result<Action> to_action(const tonlib_api::msg_message& message) {
    if (!message.destination_) {
      return TonlibError::EmptyField("message.destination");
    }
    Action res;
    TRY_RESULT(destination, get_account_address(message.destination_->account_address_));
    res.destination = destination;
    if (message.amount_ < 0) {
      return TonlibError::InvalidField("amount", "can't be negative");
    }
    res.amount = message.amount_;
    if (!message.public_key_.empty()) {
      TRY_RESULT(public_key, get_public_key(message.public_key_));
      auto key = td::Ed25519::PublicKey(td::SecureString(public_key.key));
      res.o_public_key = std::move(key);
    }
    auto status =
        downcast_call2<td::Status>(*message.data_, td::overloaded(
                                                       [&](tonlib_api::msg_dataRaw& text) {
                                                         TRY_RESULT(body, vm::std_boc_deserialize(text.body_));
                                                         res.body = std::move(body);
                                                         return td::Status::OK();
                                                       },
                                                       [&](tonlib_api::msg_dataText& text) {
                                                         res.message = text.text_;
                                                         res.should_encrypt = false;
                                                         res.is_encrypted = false;
                                                         return td::Status::OK();
                                                       },
                                                       [&](tonlib_api::msg_dataDecryptedText& text) {
                                                         res.message = text.text_;
                                                         if (!has_private_key_) {
                                                           return TonlibError::EmptyField("input_key");
                                                         }
                                                         res.should_encrypt = true;
                                                         res.is_encrypted = true;
                                                         return td::Status::OK();
                                                       },
                                                       [&](tonlib_api::msg_dataEncryptedText& text) {
                                                         res.message = text.text_;
                                                         res.should_encrypt = false;
                                                         res.is_encrypted = true;
                                                         return td::Status::OK();
                                                       }));
    // Use this limit as a preventive check
    if (res.message.size() > ton::Wallet::max_message_size) {
      return TonlibError::MessageTooLong();
    }
    TRY_STATUS(std::move(status));
    return std::move(res);
  }

  td::Result<ton::ManualDns::Action> to_dns_action(tonlib_api::dns_Action& action) {
    using R = td::Result<ton::ManualDns::Action>;
    return downcast_call2<R>(action,
                             td::overloaded(
                                 [&](tonlib_api::dns_actionDeleteAll& del_all) -> R {
                                   return ton::ManualDns::Action{"", 0, {}};
                                 },
                                 [&](tonlib_api::dns_actionDelete& del) -> R {
                                   TRY_RESULT(category, td::narrow_cast_safe<td::int16>(del.category_));
                                   return ton::ManualDns::Action{del.name_, category, {}};
                                 },
                                 [&](tonlib_api::dns_actionSet& set) -> R {
                                   if (!set.entry_) {
                                     return TonlibError::EmptyField("entry");
                                   }
                                   if (!set.entry_->entry_) {
                                     return TonlibError::EmptyField("entry.entry");
                                   }
                                   TRY_RESULT(category, td::narrow_cast_safe<td::int16>(set.entry_->category_));
                                   TRY_RESULT(entry_data, to_dns_entry_data(*set.entry_->entry_));
                                   TRY_RESULT(data_cell, entry_data.as_cell());
                                   return ton::ManualDns::Action{set.entry_->name_, category, std::move(data_cell)};
                                 }));
  }

  td::Status parse_action(tonlib_api::Action& action) {
    return downcast_call2<td::Status>(action,
                                      td::overloaded([&](tonlib_api::actionNoop& cell) { return td::Status::OK(); },
                                                     [&](tonlib_api::actionMsg& cell) {
                                                       allow_send_to_uninited_ = cell.allow_send_to_uninited_;
                                                       for (auto& from_action : cell.messages_) {
                                                         if (!from_action) {
                                                           return TonlibError::EmptyField("message");
                                                         }
                                                         TRY_RESULT(action, to_action(*from_action));
                                                         actions_.push_back(std::move(action));
                                                       }
                                                       return td::Status::OK();
                                                     },
                                                     [&](tonlib_api::actionDns& cell) {
                                                       for (auto& from_action : cell.actions_) {
                                                         if (!from_action) {
                                                           return TonlibError::EmptyField("action");
                                                         }
                                                         TRY_RESULT(action, to_dns_action(*from_action));
                                                         dns_actions_.push_back(std::move(action));
                                                       }
                                                       return td::Status::OK();
                                                     }));
  }

  td::Status do_start_up() {
    if (query_.timeout_ < 0 || query_.timeout_ > 300) {
      return TonlibError::InvalidField("timeout", "must be between 0 and 300");
    }
    if (!query_.address_) {
      return TonlibError::EmptyField("address");
    }
    if (!query_.action_) {
      return TonlibError::EmptyField("action");
    }

    TRY_RESULT(source_address, get_account_address(query_.address_->account_address_));

    has_private_key_ = bool(query_.private_key_);
    if (has_private_key_) {
      TRY_RESULT(input_key, from_tonlib(*query_.private_key_));
      is_fake_key_ = query_.private_key_->get_id() == tonlib_api::inputKeyFake::ID;
      public_key_ = td::Ed25519::PublicKey(input_key.key.public_key.copy());
      send_query(int_api::GetPrivateKey{std::move(input_key)},
                 promise_send_closure(actor_id(this), &GenericCreateSendGrams::on_private_key));
    }
    TRY_STATUS(parse_action(*query_.action_));

    send_query(int_api::GetAccountState{source_address, block_id_.copy()},
               promise_send_closure(actor_id(this), &GenericCreateSendGrams::on_source_state));

    destinations_.resize(actions_.size());
    destinations_left_ = destinations_.size();
    for (size_t i = 0; i < actions_.size(); i++) {
      send_query(int_api::GetAccountState{actions_[i].destination, block_id_.copy()},
                 promise_send_closure(actor_id(this), &GenericCreateSendGrams::on_destination_state, i));
    }

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

  void on_destination_state(size_t i, td::Result<td::unique_ptr<AccountState>> state) {
    check(do_on_destination_state(i, std::move(state)));
  }

  td::Status do_on_destination_state(size_t i, td::Result<td::unique_ptr<AccountState>> r_state) {
    TRY_RESULT(state, std::move(r_state));
    CHECK(destinations_left_ > 0);
    destinations_left_--;
    destinations_[i] = std::move(state);
    auto& destination = *destinations_[i];
    if (destination.is_frozen()) {
      //FIXME: after restoration of frozen accounts will be supported
      return TonlibError::TransferToFrozen();
    }
    if (destination.get_wallet_type() == AccountState::Empty && destination.get_address().bounceable) {
      if (!allow_send_to_uninited_) {
        return TonlibError::DangerousTransaction("Transfer to uninited wallet");
      }
      destination.make_non_bounceable();
      LOG(INFO) << "Change destination address from bounceable to non-bounceable ";
    }
    return do_loop();
  }

  td::Status do_dns_loop() {
    if (!private_key_) {
      return TonlibError::EmptyField("private_key");
    }

    Query::Raw raw;
    auto valid_until = source_->get_sync_time();
    valid_until += query_.timeout_ == 0 ? 60 : query_.timeout_;
    raw.valid_until = valid_until;
    auto dns = ton::ManualDns::create(source_->get_smc_state());
    if (dns_actions_.empty()) {
      TRY_RESULT(message_body, dns->create_init_query(private_key_.value(), valid_until));
      raw.message_body = std::move(message_body);
    } else {
      TRY_RESULT(message_body, dns->create_update_query(private_key_.value(), dns_actions_, valid_until));
      raw.message_body = std::move(message_body);
    }
    raw.new_state = source_->get_new_state();
    raw.message = ton::GenericAccount::create_ext_message(source_->get_address(), raw.new_state, raw.message_body);
    raw.source = std::move(source_);
    raw.destinations = std::move(destinations_);
    promise_.set_value(td::make_unique<Query>(std::move(raw)));
    stop();
    return td::Status::OK();
  }

  td::Status do_loop() {
    if (!source_ || destinations_left_ != 0) {
      return td::Status::OK();
    }
    if (has_private_key_ && !private_key_) {
      return td::Status::OK();
    }

    if (source_->get_wallet_type() == AccountState::ManualDns) {
      return do_dns_loop();
    }

    switch (source_->get_wallet_type()) {
      case AccountState::Empty:
        return TonlibError::AccountNotInited();
      case AccountState::Unknown:
        return TonlibError::AccountTypeUnknown();
      default:
        break;
    }

    if (!source_->is_wallet()) {
      return TonlibError::AccountActionUnsupported("wallet action");
    }

    td::int64 amount = 0;
    for (auto& action : actions_) {
      amount += action.amount;
    }

    if (amount > source_->get_balance()) {
      return TonlibError::NotEnoughFunds();
    }

    auto valid_until = source_->get_sync_time();
    valid_until += query_.timeout_ == 0 ? 60 : query_.timeout_;
    std::vector<ton::WalletInterface::Gift> gifts;
    size_t i = 0;
    for (auto& action : actions_) {
      ton::HighloadWalletV2::Gift gift;
      auto& destination = destinations_[i];
      gift.destination = destinations_[i]->get_address();
      gift.gramms = action.amount;
      if (action.amount == source_->get_balance()) {
        gift.gramms = -1;
      }
      if (action.body.not_null()) {
        gift.body = action.body;
      } else if (action.should_encrypt) {
        LOG(ERROR) << "TRY ENCRYPT";
        if (!private_key_) {
          return TonlibError::EmptyField("private_key");
        }

        auto o_public_key = std::move(action.o_public_key);
        if (!o_public_key && destination->is_wallet()) {
          auto wallet = destination->get_wallet();
          auto r_public_key = wallet->get_public_key();
          if (r_public_key.is_ok()) {
            o_public_key = r_public_key.move_as_ok();
          }
        }

        if (!o_public_key) {
          auto smc = ton::SmartContract::create(destination->get_smc_state());
          auto r_public_key = ton::GenericAccount::get_public_key(destination->get_smc_state());
          if (r_public_key.is_ok()) {
            o_public_key = r_public_key.move_as_ok();
          }
        }

        if (!o_public_key) {
          return TonlibError::MessageEncryption("Get public key (in destination)");
        }

        auto addr = source_->get_address();
        addr.bounceable = true;
        addr.testnet = false;

        TRY_RESULT_PREFIX(encrypted_message,
                          SimpleEncryptionV2::encrypt_data(action.message, o_public_key.unwrap(), private_key_.value(),
                                                           addr.rserialize(true)),
                          TonlibError::Internal());
        gift.message = encrypted_message.as_slice().str();
        gift.is_encrypted = true;
      } else {
        gift.message = action.message;
        gift.is_encrypted = action.is_encrypted;
      }
      i++;
      gifts.push_back(gift);
    }

    Query::Raw raw;
    auto with_wallet = [&](auto&& wallet) {
      if (!private_key_) {
        return TonlibError::EmptyField("private_key");
      }
      if (wallet.get_max_gifts_size() < gifts.size()) {
        return TonlibError::MessageTooLong();  // TODO: other error
      }

      raw.valid_until = valid_until;
      TRY_RESULT(message_body, wallet.make_a_gift_message(private_key_.unwrap(), valid_until, gifts));
      raw.message_body = std::move(message_body);
      raw.new_state = source_->get_new_state();
      raw.message = ton::GenericAccount::create_ext_message(source_->get_address(), raw.new_state, raw.message_body);
      raw.source = std::move(source_);
      raw.destinations = std::move(destinations_);

      promise_.set_value(td::make_unique<Query>(std::move(raw)));
      stop();
      return td::Status::OK();
    };

    if (source_->get_wallet_type() == AccountState::Giver) {
      valid_until = 0;
      private_key_ = td::Ed25519::PrivateKey(td::SecureString(std::string(32, '\0')));
    }

    return with_wallet(*source_->get_wallet());
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

td::Status TonlibClient::do_request(tonlib_api::createQuery& request,
                                    td::Promise<object_ptr<tonlib_api::query_info>>&& promise) {
  auto id = actor_id_++;
  actors_[id] = td::actor::create_actor<GenericCreateSendGrams>(
      "GenericSendGrams", actor_shared(this, id), std::move(request), query_context_.block_id.copy(),
      promise.send_closure(actor_id(this), &TonlibClient::finish_create_query));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::msg_decrypt& request,
                                    td::Promise<object_ptr<tonlib_api::msg_dataDecryptedArray>>&& promise) {
  if (!request.input_key_) {
    return TonlibError::EmptyField("input_key");
  }
  if (!request.data_) {
    return TonlibError::EmptyField("data");
  }
  TRY_RESULT(input_key, from_tonlib(*request.input_key_));
  using ReturnType = tonlib_api::object_ptr<tonlib_api::msg_dataDecrypted>;
  make_request(
      int_api::GetPrivateKey{std::move(input_key)},
      promise.wrap([elements = std::move(request.data_)](auto key) mutable {
        auto private_key = td::Ed25519::PrivateKey(std::move(key.private_key));
        auto new_elements = td::transform(std::move(elements->elements_), [&private_key](auto msg) -> ReturnType {
          auto res = tonlib_api::make_object<tonlib_api::msg_dataDecrypted>();
          if (!msg) {
            return res;
          }
          if (!msg->data_) {
            return res;
          }
          res->data_ = std::move(msg->data_);
          if (!msg->source_) {
            return res;
          }
          auto r_account_address = get_account_address(msg->source_->account_address_);
          if (r_account_address.is_error()) {
            return res;
          }
          return downcast_call2<ReturnType>(
              *res->data_,
              td::overloaded(
                  [&res](auto&) { return std::move(res); },
                  [&res, &private_key, &msg](tonlib_api::msg_dataEncryptedText& encrypted) -> ReturnType {
                    auto r_decrypted =
                        SimpleEncryptionV2::decrypt_data(encrypted.text_, private_key, msg->source_->account_address_);
                    if (r_decrypted.is_error()) {
                      return std::move(res);
                    }
                    auto decrypted = r_decrypted.move_as_ok();
                    return tonlib_api::make_object<tonlib_api::msg_dataDecrypted>(
                        decrypted.proof.as_slice().str(),
                        tonlib_api::make_object<tonlib_api::msg_dataDecryptedText>(decrypted.data.as_slice().str()));
                  }));
        });
        return tonlib_api::make_object<tonlib_api::msg_dataDecryptedArray>(std::move(new_elements));
      }));
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

  make_request(int_api::GetAccountState{account_address, query_context_.block_id.copy()},
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
                 return td::make_unique<Query>(std::move(raw));
               }));
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
  promise.set_value(tonlib_api::make_object<tonlib_api::query_fees>(
      fees.first.to_tonlib_api(), td::transform(fees.second, [](auto& x) { return x.to_tonlib_api(); })));
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
  make_request(int_api::GetAccountState{std::move(account_address), query_context_.block_id.copy()},
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

bool is_list(vm::StackEntry entry) {
  while (true) {
    if (entry.type() == vm::StackEntry::Type::t_null) {
      return true;
    }
    if (entry.type() != vm::StackEntry::Type::t_tuple) {
      return false;
    }
    if (entry.as_tuple()->size() != 2) {
      return false;
    }
    entry = entry.as_tuple()->at(1);
  }
};
auto to_tonlib_api(const vm::StackEntry& entry) -> tonlib_api::object_ptr<tonlib_api::tvm_StackEntry> {
  switch (entry.type()) {
    case vm::StackEntry::Type::t_int:
      return tonlib_api::make_object<tonlib_api::tvm_stackEntryNumber>(
          tonlib_api::make_object<tonlib_api::tvm_numberDecimal>(dec_string(entry.as_int())));
    case vm::StackEntry::Type::t_slice:
      return tonlib_api::make_object<tonlib_api::tvm_stackEntryCell>(tonlib_api::make_object<tonlib_api::tvm_cell>(
          to_bytes(vm::CellBuilder().append_cellslice(entry.as_slice()).finalize())));
    case vm::StackEntry::Type::t_cell:
      return tonlib_api::make_object<tonlib_api::tvm_stackEntryCell>(
          tonlib_api::make_object<tonlib_api::tvm_cell>(to_bytes(entry.as_cell())));
    case vm::StackEntry::Type::t_null:
    case vm::StackEntry::Type::t_tuple: {
      std::vector<tonlib_api::object_ptr<tonlib_api::tvm_StackEntry>> elements;
      if (is_list(entry)) {
        auto node = entry;
        while (node.type() == vm::StackEntry::Type::t_tuple) {
          elements.push_back(to_tonlib_api(node.as_tuple()->at(0)));
          node = node.as_tuple()->at(1);
        }
        return tonlib_api::make_object<tonlib_api::tvm_stackEntryList>(
            tonlib_api::make_object<tonlib_api::tvm_list>(std::move(elements)));

      } else {
        for (auto& element : *entry.as_tuple()) {
          elements.push_back(to_tonlib_api(element));
        }
        return tonlib_api::make_object<tonlib_api::tvm_stackEntryTuple>(
            tonlib_api::make_object<tonlib_api::tvm_tuple>(std::move(elements)));
      }
    }

    default:
      return tonlib_api::make_object<tonlib_api::tvm_stackEntryUnsupported>();
  }
};

td::Result<vm::StackEntry> from_tonlib_api(tonlib_api::tvm_StackEntry& entry) {
  // TODO: error codes
  // downcast_call
  return downcast_call2<td::Result<vm::StackEntry>>(
      entry,
      td::overloaded(
          [&](tonlib_api::tvm_stackEntryUnsupported& cell) { return td::Status::Error("Unsuppored stack entry"); },
          [&](tonlib_api::tvm_stackEntrySlice& cell) -> td::Result<vm::StackEntry> {
            TRY_RESULT(res, vm::std_boc_deserialize(cell.slice_->bytes_));
            return vm::StackEntry{std::move(res)};
          },
          [&](tonlib_api::tvm_stackEntryCell& cell) -> td::Result<vm::StackEntry> {
            TRY_RESULT(res, vm::std_boc_deserialize(cell.cell_->bytes_));
            return vm::StackEntry{std::move(res)};
          },
          [&](tonlib_api::tvm_stackEntryTuple& tuple) -> td::Result<vm::StackEntry> {
            std::vector<vm::StackEntry> elements;
            for (auto& element : tuple.tuple_->elements_) {
              TRY_RESULT(new_element, from_tonlib_api(*element));
              elements.push_back(std::move(new_element));
            }
            return td::Ref<vm::Tuple>(true, std::move(elements));
          },
          [&](tonlib_api::tvm_stackEntryList& tuple) -> td::Result<vm::StackEntry> {
            vm::StackEntry tail;
            for (auto& element : td::reversed(tuple.list_->elements_)) {
              TRY_RESULT(new_element, from_tonlib_api(*element));
              tail = vm::make_tuple_ref(std::move(new_element), std::move(tail));
            }
            return tail;
          },
          [&](tonlib_api::tvm_stackEntryNumber& number) -> td::Result<vm::StackEntry> {
            auto& dec = *number.number_;
            auto num = td::dec_string_to_int256(dec.number_);
            if (num.is_null()) {
              return td::Status::Error("Failed to parse dec string to int256");
            }
            return num;
          }));
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
  for (auto& entry : request.stack_) {
    TRY_RESULT(e, from_tonlib_api(*entry));
    stack.write().push(std::move(e));
  }
  args.set_stack(std::move(stack));
  auto res = smc->run_get_method(std::move(args));

  // smc.runResult gas_used:int53 stack:vector<tvm.StackEntry> exit_code:int32 = smc.RunResult;
  std::vector<object_ptr<tonlib_api::tvm_StackEntry>> res_stack;
  for (auto& entry : res.stack->as_span()) {
    res_stack.push_back(to_tonlib_api(entry));
  }
  promise.set_value(tonlib_api::make_object<tonlib_api::smc_runResult>(res.gas_used, std::move(res_stack), res.code));
  return td::Status::OK();
}

td::Result<tonlib_api::object_ptr<tonlib_api::dns_EntryData>> to_tonlib_api(
    const ton::ManualDns::EntryData& entry_data) {
  td::Result<tonlib_api::object_ptr<tonlib_api::dns_EntryData>> res;
  if (entry_data.data.empty()) {
    return TonlibError::Internal("Unexpected empty EntryData");
  }
  entry_data.data.visit(td::overloaded(
      [&](const ton::ManualDns::EntryDataText& text) {
        res = tonlib_api::make_object<tonlib_api::dns_entryDataText>(text.text);
      },
      [&](const ton::ManualDns::EntryDataNextResolver& resolver) {
        res = tonlib_api::make_object<tonlib_api::dns_entryDataNextResolver>(
            tonlib_api::make_object<tonlib_api::accountAddress>(resolver.resolver.rserialize(true)));
      },
      [&](const ton::ManualDns::EntryDataAdnlAddress& adnl_address) {
        res = tonlib_api::make_object<tonlib_api::dns_entryDataAdnlAddress>(
            tonlib_api::make_object<tonlib_api::adnlAddress>(
                td::adnl_id_encode(adnl_address.adnl_address.as_slice()).move_as_ok()));
      },
      [&](const ton::ManualDns::EntryDataSmcAddress& smc_address) {
        res = tonlib_api::make_object<tonlib_api::dns_entryDataSmcAddress>(
            tonlib_api::make_object<tonlib_api::accountAddress>(smc_address.smc_address.rserialize(true)));
      }));
  return res;
}

void TonlibClient::finish_dns_resolve(std::string name, td::int32 category, td::int32 ttl,
                                      td::optional<ton::BlockIdExt> block_id, DnsFinishData dns_finish_data,
                                      td::Promise<object_ptr<tonlib_api::dns_resolved>>&& promise) {
  block_id = dns_finish_data.block_id;
  // TODO: check if the smartcontract supports Dns interface
  // TODO: should we use some DnsInterface instead of ManualDns?
  auto dns = ton::ManualDns::create(dns_finish_data.smc_state);
  TRY_RESULT_PROMISE(promise, entries, dns->resolve(name, category));

  if (entries.size() == 1 && entries[0].category == -1 && entries[0].name != name && ttl > 0 &&
      entries[0].data.type == ton::ManualDns::EntryData::Type::NextResolver) {
    td::Slice got_name = entries[0].name;
    if (got_name.size() >= name.size()) {
      TRY_STATUS_PROMISE(promise, TonlibError::Internal("domain is too long"));
    }
    auto dot_position = name.size() - got_name.size() - 1;
    auto suffix = name.substr(dot_position + 1);
    auto prefix = name.substr(0, dot_position);
    if (name[dot_position] != '.') {
      TRY_STATUS_PROMISE(promise, td::Status::Error("next resolver error: domain split not at a component boundary "));
    }
    if (suffix != got_name) {
      TRY_STATUS_PROMISE(promise, TonlibError::Internal("domain is not a suffix of the query"));
    }

    auto address = entries[0].data.data.get<ton::ManualDns::EntryDataNextResolver>().resolver;
    return do_dns_request(prefix, category, ttl - 1, std::move(block_id), address, std::move(promise));
  }

  std::vector<tonlib_api::object_ptr<tonlib_api::dns_entry>> api_entries;
  for (auto& entry : entries) {
    TRY_RESULT_PROMISE(promise, entry_data, to_tonlib_api(entry.data));
    api_entries.push_back(
        tonlib_api::make_object<tonlib_api::dns_entry>(entry.name, entry.category, std::move(entry_data)));
  }
  promise.set_value(tonlib_api::make_object<tonlib_api::dns_resolved>(std::move(api_entries)));
}

void TonlibClient::do_dns_request(std::string name, td::int32 category, td::int32 ttl,
                                  td::optional<ton::BlockIdExt> block_id, block::StdAddress address,
                                  td::Promise<object_ptr<tonlib_api::dns_resolved>>&& promise) {
  auto block_id_copy = block_id.copy();
  td::Promise<DnsFinishData> new_promise =
      promise.send_closure(actor_id(this), &TonlibClient::finish_dns_resolve, name, category, ttl, std::move(block_id));

  if (0) {
    make_request(int_api::GetAccountState{address, std::move(block_id_copy)},
                 new_promise.wrap([](auto&& account_state) {
                   return DnsFinishData{account_state->get_block_id(), account_state->get_smc_state()};
                 }));

    return;
  }

  TRY_RESULT_PROMISE(promise, args, ton::DnsInterface::resolve_args(name, category));
  int_api::RemoteRunSmcMethod query;
  query.address = std::move(address);
  query.args = std::move(args);
  query.block_id = std::move(block_id_copy);
  query.need_result = false;

  make_request(std::move(query), new_promise.wrap([](auto&& run_method) {
    return DnsFinishData{run_method.block_id, run_method.smc_state};
  }));
  ;
}

td::Status TonlibClient::do_request(const tonlib_api::dns_resolve& request,
                                    td::Promise<object_ptr<tonlib_api::dns_resolved>>&& promise) {
  auto block_id = query_context_.block_id.copy();
  if (!request.account_address_) {
    make_request(int_api::GetDnsResolver{},
                 promise.send_closure(actor_id(this), &TonlibClient::do_dns_request, request.name_, request.category_,
                                      request.ttl_, std::move(block_id)));
    return td::Status::OK();
  }
  TRY_RESULT(account_address, get_account_address(request.account_address_->account_address_));
  do_dns_request(request.name_, request.category_, request.ttl_, std::move(block_id), account_address,
                 std::move(promise));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::sync& request,
                                    td::Promise<object_ptr<tonlib_api::ton_blockIdExt>>&& promise) {
  // ton.blockIdExt workchain:int32 shard:int64 seqno:int32 root_hash:bytes file_hash:bytes = ton.BlockIdExt;
  client_.with_last_block(
      std::move(promise).wrap([](auto last_block) -> td::Result<tonlib_api::object_ptr<tonlib_api::ton_blockIdExt>> {
        return to_tonlib_api(last_block.last_block_id);
      }));
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
td::Status TonlibClient::do_request(const tonlib_api::exportUnencryptedKey& request,
                                    td::Promise<object_ptr<tonlib_api::exportedUnencryptedKey>>&& promise) {
  if (!request.input_key_) {
    return TonlibError::EmptyField("input_key");
  }
  TRY_RESULT(input_key, from_tonlib(*request.input_key_));
  TRY_RESULT(exported_key, key_storage_.export_unencrypted_key(std::move(input_key)));
  promise.set_value(tonlib_api::make_object<tonlib_api::exportedUnencryptedKey>(std::move(exported_key.data)));
  return td::Status::OK();
}
td::Status TonlibClient::do_request(const tonlib_api::importUnencryptedKey& request,
                                    td::Promise<object_ptr<tonlib_api::key>>&& promise) {
  if (!request.exported_unencrypted_key_) {
    return TonlibError::EmptyField("exported_encrypted_key");
  }
  TRY_RESULT(key, key_storage_.import_unencrypted_key(
                      std::move(request.local_password_),
                      KeyStorage::ExportedUnencryptedKey{std::move(request.exported_unencrypted_key_->data_)}));
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

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::msg_decryptWithProof& request) {
  if (!request.data_) {
    return status_to_tonlib_api(TonlibError::EmptyField("data"));
  }
  if (!request.data_->data_) {
    TonlibError::EmptyField("data.data");
  }
  if (!request.data_->source_) {
    TonlibError::EmptyField("data.source");
  }
  using ReturnType = tonlib_api::object_ptr<tonlib_api::msg_Data>;
  return downcast_call2<ReturnType>(
      *request.data_->data_,
      td::overloaded([&request](auto&) { return std::move(request.data_->data_); },
                     [&request](tonlib_api::msg_dataEncryptedText& encrypted) -> ReturnType {
                       auto r_decrypted = SimpleEncryptionV2::decrypt_data_with_proof(
                           encrypted.text_, request.proof_, request.data_->source_->account_address_);
                       if (r_decrypted.is_error()) {
                         return std::move(request.data_->data_);
                       }
                       auto decrypted = r_decrypted.move_as_ok();
                       return tonlib_api::make_object<tonlib_api::msg_dataDecryptedText>(decrypted.as_slice().str());
                     }));
}

td::Status TonlibClient::do_request(int_api::GetAccountState request,
                                    td::Promise<td::unique_ptr<AccountState>>&& promise) {
  auto actor_id = actor_id_++;
  actors_[actor_id] = td::actor::create_actor<GetRawAccountState>(
      "GetAccountState", client_.get_client(), request.address, std::move(request.block_id),
      actor_shared(this, actor_id),
      promise.wrap([address = request.address, wallet_id = wallet_id_](auto&& state) mutable {
        return td::make_unique<AccountState>(std::move(address), std::move(state), wallet_id);
      }));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(int_api::RemoteRunSmcMethod request,
                                    td::Promise<int_api::RemoteRunSmcMethod::ReturnType>&& promise) {
  auto actor_id = actor_id_++;
  actors_[actor_id] = td::actor::create_actor<RemoteRunSmcMethod>(
      "RemoteRunSmcMethod", client_.get_client(), std::move(request), actor_shared(this, actor_id), std::move(promise));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(int_api::GetPrivateKey request, td::Promise<KeyStorage::PrivateKey>&& promise) {
  TRY_RESULT(pk, key_storage_.load_private_key(std::move(request.input_key)));
  promise.set_value(std::move(pk));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(int_api::GetDnsResolver request, td::Promise<block::StdAddress>&& promise) {
  client_.with_last_config(promise.wrap([](auto&& state) mutable -> td::Result<block::StdAddress> {
    TRY_RESULT_PREFIX(addr, TRY_VM(state.config->get_dns_root_addr()),
                      TonlibError::Internal("get dns root addr from config: "));
    return block::StdAddress(ton::masterchainId, addr);
  }));
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

td::Status TonlibClient::do_request(tonlib_api::withBlock& request,
                                    td::Promise<object_ptr<tonlib_api::Object>>&& promise) {
  if (!request.id_) {
    return TonlibError::EmptyField("id");
  }
  auto to_bits256 = [](td::Slice data, td::Slice name) -> td::Result<td::Bits256> {
    if (data.size() != 32) {
      return TonlibError::InvalidField(name, "wrong length (not 32 bytes)");
    }
    return td::Bits256(data.ubegin());
  };
  TRY_RESULT(root_hash, to_bits256(request.id_->root_hash_, "root_hash"));
  TRY_RESULT(file_hash, to_bits256(request.id_->file_hash_, "file_hash"));
  ton::BlockIdExt block_id(request.id_->workchain_, request.id_->shard_, request.id_->seqno_, root_hash, file_hash);
  make_any_request(*request.function_, {std::move(block_id)}, std::move(promise));
  return td::Status::OK();
}

template <class P>
td::Status TonlibClient::do_request(const tonlib_api::runTests& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::getAccountAddress& request, P&&) {
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
template <class P>
td::Status TonlibClient::do_request(const tonlib_api::msg_decryptWithProof& request, P&&) {
  UNREACHABLE();
  return TonlibError::Internal();
}
}  // namespace tonlib
