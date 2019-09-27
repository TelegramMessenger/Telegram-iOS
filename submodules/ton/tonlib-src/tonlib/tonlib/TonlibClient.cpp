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
#include "tonlib/GenericAccount.h"
#include "tonlib/LastBlock.h"
#include "tonlib/Logging.h"
#include "tonlib/TestWallet.h"
#include "tonlib/Wallet.h"
#include "tonlib/TestGiver.h"
#include "tonlib/utils.h"
#include "tonlib/keys/Mnemonic.h"

#include "auto/tl/tonlib_api.hpp"
#include "block/block-auto.h"
#include "block/check-proof.h"
#include "ton/lite-tl.hpp"
#include "ton/ton-shard.h"

#include "vm/boc.h"

#include "td/utils/Random.h"
#include "td/utils/overloaded.h"

#include "td/utils/tests.h"
#include "td/utils/port/path.h"

namespace tonlib {

template <class F>
auto try_f(F&& f) noexcept -> decltype(f()) {
  try {
    return f();
  } catch (vm::VmError error) {
    return td::Status::Error(PSLICE() << "Got a vm exception: " << error.get_msg());
  }
}

#define TRY_VM(f) try_f([&] { return f; })

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
  td::Ref<vm::CellSlice> code;
  td::Ref<vm::CellSlice> data;
  block::AccountState::Info info;
};

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
                        td::Promise<block::TransactionList::Info> promise)
      : address_(std::move(address)), lt_(std::move(lt)), hash_(std::move(hash)), promise_(std::move(promise)) {
    client_.set_client(ext_client_ref);
  }

 private:
  block::StdAddress address_;
  ton::LogicalTime lt_;
  ton::Bits256 hash_;
  ExtClient client_;
  td::int32 count_{10};
  td::Promise<block::TransactionList::Info> promise_;

  void check(td::Status status) {
    if (status.is_error()) {
      LOG(ERROR) << status;
      promise_.set_error(std::move(status));
      stop();
    }
  }

  td::Status do_with_transactions(std::vector<ton::BlockIdExt> blkids, td::BufferSlice transactions) {
    LOG(INFO) << "got up to " << count_ << " transactions for " << address_ << " from last transaction " << lt_ << ":"
              << hash_.to_hex();
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
    promise_.set_value(std::move(info));
    return td::Status::OK();
  }

  td::Status do_with_transactions(
      td::Result<ton::lite_api::object_ptr<ton::lite_api::liteServer_transactionList>> r_transactions) {
    TRY_RESULT(transactions, std::move(r_transactions));
    std::vector<ton::BlockIdExt> blkids;
    for (auto& id : transactions->ids_) {
      blkids.push_back(ton::create_block_id(std::move(id)));
    }
    return do_with_transactions(std::move(blkids), std::move(transactions->transactions_));
  }

  void with_transactions(
      td::Result<ton::lite_api::object_ptr<ton::lite_api::liteServer_transactionList>> r_transactions) {
    check(TRY_VM(do_with_transactions(std::move(r_transactions))));
    stop();
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
};

class GetRawAccountState : public td::actor::Actor {
 public:
  GetRawAccountState(ExtClientRef ext_client_ref, block::StdAddress address, td::Promise<RawAccountState>&& promise)
      : address_(std::move(address)), promise_(std::move(promise)) {
    client_.set_client(ext_client_ref);
  }

 private:
  block::StdAddress address_;
  td::Promise<RawAccountState> promise_;
  ExtClient client_;
  LastBlockState last_block_;

  void with_account_state(td::Result<ton::tl_object_ptr<ton::lite_api::liteServer_accountState>> r_account_state) {
    promise_.set_result(TRY_VM(do_with_account_state(std::move(r_account_state))));
    stop();
  }

  td::Result<RawAccountState> do_with_account_state(
      td::Result<ton::tl_object_ptr<ton::lite_api::liteServer_accountState>> r_account_state) {
    TRY_RESULT(raw_account_state, std::move(r_account_state));
    auto account_state = create_account_state(std::move(raw_account_state));
    TRY_RESULT(info, account_state.validate(last_block_.last_block_id, address_));
    auto serialized_state = account_state.state.clone();
    RawAccountState res;
    res.info = std::move(info);
    LOG_IF(ERROR, res.info.gen_utime > last_block_.utime) << res.info.gen_utime << " " << last_block_.utime;
    auto cell = res.info.root;
    if (cell.is_null()) {
      return res;
    }
    //block::gen::t_Account.print_ref(std::cerr, cell);
    block::gen::Account::Record_account account;
    if (!tlb::unpack_cell(cell, account)) {
      return td::Status::Error("Failed to unpack Account");
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
    // TODO: handle frozen account
    if (state_tag != block::gen::AccountState::account_active) {
      return res;
    }
    block::gen::AccountState::Record_account_active state;
    if (!tlb::csr_unpack(storage.state, state)) {
      return td::Status::Error("Failed to parse AccountState");
    }
    block::gen::StateInit::Record state_init;
    if (!tlb::csr_unpack(state.x, state_init)) {
      return td::Status::Error("Failed to parse StateInit");
    }
    res.code = std::move(state_init.code);
    res.data = std::move(state_init.data);

    return res;
  }

  void start_up() override {
    client_.with_last_block([self = this](td::Result<LastBlockState> r_last_block) {
      if (r_last_block.is_error()) {
        return self->check(r_last_block.move_as_error());
      }
      self->last_block_ = r_last_block.move_as_ok();

      self->client_.send_query(
          ton::lite_api::liteServer_getAccountState(ton::create_tl_lite_block_id(self->last_block_.last_block_id),
                                                    ton::create_tl_object<ton::lite_api::liteServer_accountId>(
                                                        self->address_.workchain, self->address_.addr)),
          [self](auto r_state) { self->with_account_state(std::move(r_state)); });
    });
  }

  void check(td::Status status) {
    if (status.is_error()) {
      promise_.set_error(std::move(status));
      stop();
    }
  }
};

TonlibClient::TonlibClient(td::unique_ptr<TonlibCallback> callback) : callback_(std::move(callback)) {
}
TonlibClient::~TonlibClient() = default;

void TonlibClient::hangup() {
  is_closing_ = true;
  ref_cnt_--;
  raw_client_ = {};
  raw_last_block_ = {};
  try_stop();
}

ExtClientRef TonlibClient::get_client_ref() {
  ExtClientRef ref;
  ref.andl_ext_client_ = raw_client_.get();
  ref.last_block_actor_ = raw_last_block_.get();

  return ref;
}

void TonlibClient::proxy_request(td::int64 query_id, std::string data) {
  callback_->on_result(0, tonlib_api::make_object<tonlib_api::updateSendLiteServerQuery>(query_id, data));
}

void TonlibClient::init_ext_client() {
  if (use_callbacks_for_network_) {
    class Callback : public ExtClientOutbound::Callback {
     public:
      explicit Callback(td::actor::ActorShared<TonlibClient> parent) : parent_(std::move(parent)) {
      }

      void request(td::int64 id, std::string data) override {
        send_closure(parent_, &TonlibClient::proxy_request, id, std::move(data));
      }

     private:
      td::actor::ActorShared<TonlibClient> parent_;
    };
    ref_cnt_++;
    auto client = ExtClientOutbound::create(td::make_unique<Callback>(td::actor::actor_shared(this)));
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
  if (config_generation == config_generation_) {
    last_block_storage_.save_state(blockchain_name_, state);
  }
}

void TonlibClient::init_last_block() {
  ref_cnt_++;
  class Callback : public LastBlock::Callback {
   public:
    Callback(td::actor::ActorShared<TonlibClient> client, td::uint32 config_generation)
        : client_(std::move(client)), config_generation_(config_generation) {
    }
    void on_state_changed(LastBlockState state) override {
      send_closure(client_, &TonlibClient::update_last_block_state, std::move(state), config_generation_);
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

  raw_last_block_ =
      td::actor::create_actor<LastBlock>("LastBlock", get_client_ref(), std::move(state), config_,
                                         td::make_unique<Callback>(td::actor::actor_shared(this), config_generation_));
  client_.set_client(get_client_ref());
}

void TonlibClient::on_result(td::uint64 id, tonlib_api::object_ptr<tonlib_api::Object> response) {
  if (response->get_id() == tonlib_api::error::ID) {
    callback_->on_error(id, tonlib_api::move_object_as<tonlib_api::error>(response));
    return;
  }
  callback_->on_result(id, std::move(response));
}
void TonlibClient::request(td::uint64 id, tonlib_api::object_ptr<tonlib_api::Function> function) {
  LOG(ERROR) << to_string(function);
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
    td::Promise<ReturnType> promise = [actor_id = actor_id(self), id](td::Result<ReturnType> r_result) {
      tonlib_api::object_ptr<tonlib_api::Object> result;
      if (r_result.is_error()) {
        result = status_to_tonlib_api(r_result.error());
      } else {
        result = r_result.move_as_ok();
      }

      send_closure(actor_id, &TonlibClient::on_result, id, std::move(result));
    };
    auto status = this->do_request(request, std::move(promise));
    if (status.is_error()) {
      CHECK(promise);
      promise.set_error(std::move(status));
    }
  });
}
void TonlibClient::close() {
  stop();
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::static_request(
    tonlib_api::object_ptr<tonlib_api::Function> function) {
  if (function == nullptr) {
    LOG(ERROR) << "Receive empty static request";
    return tonlib_api::make_object<tonlib_api::error>(400, "Request is empty");
  }

  tonlib_api::object_ptr<tonlib_api::Object> response;
  downcast_call(*function, [&response](auto& request) { response = TonlibClient::do_static_request(request); });
  return response;
}

bool TonlibClient::is_static_request(td::int32 id) {
  switch (id) {
    case tonlib_api::runTests::ID:
    case tonlib_api::raw_getAccountAddress::ID:
    case tonlib_api::testWallet_getAccountAddress::ID:
    case tonlib_api::wallet_getAccountAddress::ID:
    case tonlib_api::testGiver_getAccountAddress::ID:
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
td::Result<block::StdAddress> get_account_address(const tonlib_api::raw_initialAccountState& raw_state) {
  TRY_RESULT(code, vm::std_boc_deserialize(raw_state.code_));
  TRY_RESULT(data, vm::std_boc_deserialize(raw_state.data_));
  return GenericAccount::get_address(0 /*zerochain*/, GenericAccount::get_init_state(std::move(code), std::move(data)));
}

td::Result<block::StdAddress> get_account_address(const tonlib_api::testWallet_initialAccountState& test_wallet_state) {
  TRY_RESULT(key_bytes, block::PublicKey::parse(test_wallet_state.public_key_));
  auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));
  return GenericAccount::get_address(0 /*zerochain*/, TestWallet::get_init_state(key));
}

td::Result<block::StdAddress> get_account_address(const tonlib_api::wallet_initialAccountState& test_wallet_state) {
  TRY_RESULT(key_bytes, block::PublicKey::parse(test_wallet_state.public_key_));
  auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));
  return GenericAccount::get_address(0 /*zerochain*/, Wallet::get_init_state(key));
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::raw_getAccountAddress& request) {
  auto r_account_address = get_account_address(*request.initital_account_state_);
  if (r_account_address.is_error()) {
    return status_to_tonlib_api(r_account_address.error());
  }
  return tonlib_api::make_object<tonlib_api::accountAddress>(r_account_address.ok().rserialize(true));
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::testWallet_getAccountAddress& request) {
  auto r_account_address = get_account_address(*request.initital_account_state_);
  if (r_account_address.is_error()) {
    return status_to_tonlib_api(r_account_address.error());
  }
  return tonlib_api::make_object<tonlib_api::accountAddress>(r_account_address.ok().rserialize(true));
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::wallet_getAccountAddress& request) {
  auto r_account_address = get_account_address(*request.initital_account_state_);
  if (r_account_address.is_error()) {
    return status_to_tonlib_api(r_account_address.error());
  }
  return tonlib_api::make_object<tonlib_api::accountAddress>(r_account_address.ok().rserialize(true));
}
tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::testGiver_getAccountAddress& request) {
  return tonlib_api::make_object<tonlib_api::accountAddress>(TestGiver::address().rserialize(true));
}

tonlib_api::object_ptr<tonlib_api::Object> TonlibClient::do_static_request(
    const tonlib_api::unpackAccountAddress& request) {
  auto r_account_address = block::StdAddress::parse(request.account_address_);
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
    return status_to_tonlib_api(td::Status::Error(400, "Field account_address must not be empty"));
  }
  if (request.account_address_->addr_.size() != 32) {
    return status_to_tonlib_api(td::Status::Error(400, "Field account_address.addr must not be exactly 32 bytes"));
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
    return td::Status::Error(400, "Field options must not be empty");
  }
  TRY_STATUS(key_storage_.set_directory(request.options_->keystore_directory_));
  TRY_STATUS(last_block_storage_.set_directory(request.options_->keystore_directory_));
  if (request.options_->config_) {
    TRY_STATUS(set_config(std::move(request.options_->config_)));
  }
  state_ = State::Running;
  promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
  return td::Status::OK();
}

td::Status TonlibClient::set_config(object_ptr<tonlib_api::config> config) {
  if (!config) {
    return td::Status::Error(400, "config is empty");
  }
  if (config->config_.empty()) {
    return td::Status::Error(400, "config is empty");
  }
  TRY_RESULT(new_config, Config::parse(std::move(config->config_)));
  if (new_config.lite_clients.empty() && !config->use_callbacks_for_network_) {
    return td::Status::Error("No lite clients in config");
  }
  config_ = std::move(new_config);
  config_generation_++;
  if (config->blockchain_name_.empty()) {
    blockchain_name_ = td::sha256(config_.zero_state_id.to_str()).substr(0, 16);
  } else {
    blockchain_name_ = config->blockchain_name_;
  }
  use_callbacks_for_network_ = config->use_callbacks_for_network_;
  ignore_cache_ = config->ignore_cache_;
  init_ext_client();
  init_last_block();
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::close& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  CHECK(state_ != State::Closed);
  state_ = State::Closed;
  promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::options_setConfig& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  TRY_STATUS(set_config(std::move(request.config_)));
  promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
  return td::Status::OK();
}

tonlib_api::object_ptr<tonlib_api::internal_transactionId> empty_transaction_id() {
  return tonlib_api::make_object<tonlib_api::internal_transactionId>(0, std::string(32, 0));
}

tonlib_api::object_ptr<tonlib_api::internal_transactionId> to_transaction_id(const block::AccountState::Info& info) {
  return tonlib_api::make_object<tonlib_api::internal_transactionId>(info.last_trans_lt,
                                                                     info.last_trans_hash.as_slice().str());
}

td::Result<tonlib_api::object_ptr<tonlib_api::raw_accountState>> to_raw_accountState(RawAccountState&& raw_state) {
  std::string code;
  if (raw_state.code.not_null()) {
    code = vm::std_boc_serialize(vm::CellBuilder().append_cellslice(std::move(raw_state.code)).finalize())
               .move_as_ok()
               .as_slice()
               .str();
  }
  std::string data;
  if (raw_state.data.not_null()) {
    data = vm::std_boc_serialize(vm::CellBuilder().append_cellslice(std::move(raw_state.data)).finalize())
               .move_as_ok()
               .as_slice()
               .str();
  }
  return tonlib_api::make_object<tonlib_api::raw_accountState>(
      raw_state.balance, std::move(code), std::move(data), to_transaction_id(raw_state.info), raw_state.info.gen_utime);
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
      td::Ref<vm::CellSlice> body;
      if (message.body->prefetch_long(1) == 0) {
        body = std::move(message.body);
        body.write().advance(1);
      } else {
        body = vm::load_cell_slice_ref(message.body->prefetch_ref());
      }
      std::string body_message;
      if (body->size() % 8 == 0) {
        body_message = std::string(body->size() / 8, 0);
        body->prefetch_bytes(td::MutableSlice(body_message).ubegin(), body->size() / 8);
        if (body_message.size() >= 4 && body_message[0] == 0 && body_message[1] == 0 && body_message[2] == 0 &&
            body_message[3] == 0) {
          body_message = body_message.substr(4);
        }
      }

      return tonlib_api::make_object<tonlib_api::raw_message>(std::move(src), std::move(dest), balance,
                                                              std::move(body_message));
    }
    case block::gen::CommonMsgInfo::ext_in_msg_info: {
      block::gen::CommonMsgInfo::Record_ext_in_msg_info msg_info;
      if (!tlb::csr_unpack(message.info, msg_info)) {
        return td::Status::Error("Failed to unpack CommonMsgInfo::ext_in_msg_info");
      }
      TRY_RESULT(dest, to_std_address(msg_info.dest));
      return tonlib_api::make_object<tonlib_api::raw_message>("", std::move(dest), 0, "");
    }
    case block::gen::CommonMsgInfo::ext_out_msg_info: {
      block::gen::CommonMsgInfo::Record_ext_out_msg_info msg_info;
      if (!tlb::csr_unpack(message.info, msg_info)) {
        return td::Status::Error("Failed to unpack CommonMsgInfo::ext_out_msg_info");
      }
      TRY_RESULT(src, to_std_address(msg_info.src));
      return tonlib_api::make_object<tonlib_api::raw_message>(std::move(src), "", 0, "");
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
  if (info.transaction.not_null()) {
    TRY_RESULT(copy_data, vm::std_boc_serialize(info.transaction));
    data = copy_data.as_slice().str();
    block::gen::Transaction::Record trans;
    if (!tlb::unpack_cell(info.transaction, trans)) {
      return td::Status::Error("Failed to unpack Transaction");
    }

    TRY_RESULT(copy_fees, to_balance(trans.total_fees));
    fees = copy_fees;

    std::ostringstream outp;
    block::gen::t_Transaction.print_ref(outp, info.transaction);
    LOG(ERROR) << outp.str();

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
        out_msgs.push_back(std::move(out_msg));
      }
    }
  }
  return tonlib_api::make_object<tonlib_api::raw_transaction>(
      info.now, data,
      tonlib_api::make_object<tonlib_api::internal_transactionId>(info.prev_trans_lt,
                                                                  info.prev_trans_hash.as_slice().str()),
      fees, std::move(in_msg), std::move(out_msgs));
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

td::Result<tonlib_api::object_ptr<tonlib_api::testWallet_accountState>> to_testWallet_accountState(
    RawAccountState&& raw_state) {
  if (raw_state.data.is_null()) {
    return td::Status::Error(400, "Not a TestWallet");
  }
  auto ref = raw_state.data->prefetch_ref();
  auto cs = vm::load_cell_slice(std::move(ref));
  auto seqno = cs.fetch_ulong(32);
  if (seqno == cs.fetch_ulong_eof) {
    return td::Status::Error("Failed to parse seq_no");
  }
  return tonlib_api::make_object<tonlib_api::testWallet_accountState>(
      raw_state.balance, static_cast<td::uint32>(seqno), to_transaction_id(raw_state.info), raw_state.info.gen_utime);
}

td::Result<tonlib_api::object_ptr<tonlib_api::wallet_accountState>> to_wallet_accountState(
    RawAccountState&& raw_state) {
  if (raw_state.data.is_null()) {
    return td::Status::Error(400, "Not a Wallet");
  }
  auto ref = raw_state.data->prefetch_ref();
  auto cs = vm::load_cell_slice(std::move(ref));
  auto seqno = cs.fetch_ulong(32);
  if (seqno == cs.fetch_ulong_eof) {
    return td::Status::Error("Failed to parse seq_no");
  }
  return tonlib_api::make_object<tonlib_api::wallet_accountState>(
      raw_state.balance, static_cast<td::uint32>(seqno), to_transaction_id(raw_state.info), raw_state.info.gen_utime);
}

td::Result<tonlib_api::object_ptr<tonlib_api::testGiver_accountState>> to_testGiver_accountState(
    RawAccountState&& raw_state) {
  if (raw_state.data.is_null()) {
    return td::Status::Error(400, "Not a TestGiver");
  }
  auto ref = raw_state.data->prefetch_ref();
  auto cs = vm::load_cell_slice(std::move(ref));
  auto seqno = cs.fetch_ulong(32);
  if (seqno == cs.fetch_ulong_eof) {
    return td::Status::Error("Failed to parse seq_no");
  }
  return tonlib_api::make_object<tonlib_api::testGiver_accountState>(
      raw_state.balance, static_cast<td::uint32>(seqno), to_transaction_id(raw_state.info), raw_state.info.gen_utime);
}

td::Result<tonlib_api::object_ptr<tonlib_api::generic_AccountState>> to_generic_accountState(
    RawAccountState&& raw_state) {
  if (raw_state.code.is_null()) {
    return tonlib_api::make_object<tonlib_api::generic_accountStateUninited>(
        tonlib_api::make_object<tonlib_api::uninited_accountState>(raw_state.balance, to_transaction_id(raw_state.info),
                                                                   raw_state.info.gen_utime));
  }

  auto code_hash = raw_state.code->prefetch_ref()->get_hash();
  if (code_hash == TestWallet::get_init_code_hash()) {
    TRY_RESULT(test_wallet, to_testWallet_accountState(std::move(raw_state)));
    return tonlib_api::make_object<tonlib_api::generic_accountStateTestWallet>(std::move(test_wallet));
  }
  if (code_hash == Wallet::get_init_code_hash()) {
    TRY_RESULT(wallet, to_wallet_accountState(std::move(raw_state)));
    return tonlib_api::make_object<tonlib_api::generic_accountStateWallet>(std::move(wallet));
  }
  if (code_hash == TestGiver::get_init_code_hash()) {
    TRY_RESULT(test_wallet, to_testGiver_accountState(std::move(raw_state)));
    return tonlib_api::make_object<tonlib_api::generic_accountStateTestGiver>(std::move(test_wallet));
  }
  TRY_RESULT(raw, to_raw_accountState(std::move(raw_state)));
  return tonlib_api::make_object<tonlib_api::generic_accountStateRaw>(std::move(raw));
}

// Raw

td::Status TonlibClient::do_request(const tonlib_api::raw_sendMessage& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  td::Ref<vm::Cell> init_state;
  if (!request.initial_account_state_.empty()) {
    TRY_RESULT(new_init_state, vm::std_boc_deserialize(request.initial_account_state_));
    init_state = std::move(new_init_state);
  }
  TRY_RESULT(data, vm::std_boc_deserialize(request.data_));
  TRY_RESULT(account_address, block::StdAddress::parse(request.destination_->account_address_));
  auto message = GenericAccount::create_ext_message(account_address, std::move(init_state), std::move(data));
  client_.send_query(ton::lite_api::liteServer_sendMessage(vm::std_boc_serialize(message).move_as_ok()),
                     [promise = std::move(promise)](auto r_info) mutable {
                       if (r_info.is_error()) {
                         promise.set_error(r_info.move_as_error());
                       } else {
                         auto info = r_info.move_as_ok();
                         LOG(ERROR) << "info: " << to_string(info);
                         promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
                       }
                     });
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::raw_getAccountState& request,
                                    td::Promise<object_ptr<tonlib_api::raw_accountState>>&& promise) {
  if (!request.account_address_) {
    return td::Status::Error(400, "Field account_address must not be empty");
  }
  TRY_RESULT(account_address, block::StdAddress::parse(request.account_address_->account_address_));
  td::actor::create_actor<GetRawAccountState>(
      "GetAccountState", client_.get_client(), std::move(account_address),
      [promise = std::move(promise)](td::Result<RawAccountState> r_state) mutable {
        if (r_state.is_error()) {
          return promise.set_error(r_state.move_as_error());
        }
        promise.set_result(to_raw_accountState(r_state.move_as_ok()));
      })
      .release();
  return td::Status::OK();
}

td::Status TonlibClient::do_request(tonlib_api::raw_getTransactions& request,
                                    td::Promise<object_ptr<tonlib_api::raw_transactions>>&& promise) {
  if (!request.account_address_) {
    return td::Status::Error(400, "Field account_address must not be empty");
  }
  if (!request.from_transaction_id_) {
    return td::Status::Error(400, "Field from_transaction_id must not be empty");
  }
  TRY_RESULT(account_address, block::StdAddress::parse(request.account_address_->account_address_));
  auto lt = request.from_transaction_id_->lt_;
  auto hash_str = request.from_transaction_id_->hash_;
  if (hash_str.size() != 32) {
    return td::Status::Error(400, "Invalid transaction id hash size");
  }
  td::Bits256 hash;
  hash.as_slice().copy_from(hash_str);

  td::actor::create_actor<GetTransactionHistory>(
      "GetTransactionHistory", client_.get_client(), account_address, lt, hash,
      [promise = std::move(promise)](td::Result<block::TransactionList::Info> r_info) mutable {
        if (r_info.is_error()) {
          return promise.set_error(r_info.move_as_error());
        }
        promise.set_result(to_raw_transactions(r_info.move_as_ok()));
      })
      .release();
  return td::Status::OK();
}

td::Result<KeyStorage::InputKey> from_tonlib(tonlib_api::inputKey& input_key) {
  if (!input_key.key_) {
    return td::Status::Error(400, "Field key must not be empty");
  }

  TRY_RESULT(key_bytes, block::PublicKey::parse(input_key.key_->public_key_));
  return KeyStorage::InputKey{{td::SecureString(key_bytes.key), std::move(input_key.key_->secret_)},
                              std::move(input_key.local_password_)};
}

// TestWallet
td::Status TonlibClient::do_request(const tonlib_api::testWallet_init& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  if (!request.private_key_) {
    return td::Status::Error(400, "Field private_key must not be empty");
  }
  TRY_RESULT(input_key, from_tonlib(*request.private_key_));
  auto init_state = TestWallet::get_init_state(td::Ed25519::PublicKey(input_key.key.public_key.copy()));
  auto address = GenericAccount::get_address(0 /*zerochain*/, init_state);
  TRY_RESULT(private_key, key_storage_.load_private_key(std::move(input_key)));
  auto init_message = TestWallet::get_init_message(td::Ed25519::PrivateKey(std::move(private_key.private_key)));
  return do_request(
      tonlib_api::raw_sendMessage(tonlib_api::make_object<tonlib_api::accountAddress>(address.rserialize(true)),
                                  vm::std_boc_serialize(init_state).move_as_ok().as_slice().str(),
                                  vm::std_boc_serialize(init_message).move_as_ok().as_slice().str()),
      std::move(promise));
}

td::Status TonlibClient::do_request(const tonlib_api::testWallet_sendGrams& request,
                                    td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise) {
  if (!request.destination_) {
    return td::Status::Error(400, "Field destination must not be empty");
  }
  if (!request.private_key_) {
    return td::Status::Error(400, "Field private_key must not be empty");
  }
  if (request.message_.size() > 70) {
    return td::Status::Error(400, "Message is too long");
  }
  TRY_RESULT(account_address, block::StdAddress::parse(request.destination_->account_address_));
  account_address.bounceable = false;
  TRY_RESULT(input_key, from_tonlib(*request.private_key_));
  auto address = GenericAccount::get_address(
      0 /*zerochain*/, TestWallet::get_init_state(td::Ed25519::PublicKey(input_key.key.public_key.copy())));
  TRY_RESULT(private_key_str, key_storage_.load_private_key(std::move(input_key)));
  auto private_key = td::Ed25519::PrivateKey(std::move(private_key_str.private_key));
  std::string init_state;
  if (request.seqno_ == 0) {
    TRY_RESULT(public_key, private_key.get_public_key());
    init_state = vm::std_boc_serialize(TestWallet::get_init_state(public_key)).move_as_ok().as_slice().str();
  }
  td::Promise<object_ptr<tonlib_api::ok>> new_promise =
      [promise = std::move(promise)](td::Result<object_ptr<tonlib_api::ok>> res) mutable {
        if (res.is_error()) {
          promise.set_error(res.move_as_error());
        } else {
          promise.set_value(tonlib_api::make_object<tonlib_api::sendGramsResult>(0));
        }
      };
  return do_request(
      tonlib_api::raw_sendMessage(
          tonlib_api::make_object<tonlib_api::accountAddress>(address.rserialize(true)), std::move(init_state),
          vm::std_boc_serialize(TestWallet::make_a_gift_message(private_key, request.seqno_, request.amount_,
                                                                request.message_, account_address))
              .move_as_ok()
              .as_slice()
              .str()),
      std::move(new_promise));
}

td::Status TonlibClient::do_request(tonlib_api::testWallet_getAccountState& request,
                                    td::Promise<object_ptr<tonlib_api::testWallet_accountState>>&& promise) {
  if (!request.account_address_) {
    return td::Status::Error(400, "Field account_address must not be empty");
  }
  TRY_RESULT(account_address, block::StdAddress::parse(request.account_address_->account_address_));
  td::actor::create_actor<GetRawAccountState>(
      "GetAccountState", client_.get_client(), std::move(account_address),
      [promise = std::move(promise)](td::Result<RawAccountState> r_state) mutable {
        if (r_state.is_error()) {
          return promise.set_error(r_state.move_as_error());
        }
        promise.set_result(to_testWallet_accountState(r_state.move_as_ok()));
      })
      .release();
  return td::Status::OK();
}

// Wallet
td::Status TonlibClient::do_request(const tonlib_api::wallet_init& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  if (!request.private_key_) {
    return td::Status::Error(400, "Field private_key must not be empty");
  }
  TRY_RESULT(input_key, from_tonlib(*request.private_key_));
  auto init_state = Wallet::get_init_state(td::Ed25519::PublicKey(input_key.key.public_key.copy()));
  auto address = GenericAccount::get_address(0 /*zerochain*/, init_state);
  TRY_RESULT(private_key, key_storage_.load_private_key(std::move(input_key)));
  auto init_message = Wallet::get_init_message(td::Ed25519::PrivateKey(std::move(private_key.private_key)));
  return do_request(
      tonlib_api::raw_sendMessage(tonlib_api::make_object<tonlib_api::accountAddress>(address.rserialize(true)),
                                  vm::std_boc_serialize(init_state).move_as_ok().as_slice().str(),
                                  vm::std_boc_serialize(init_message).move_as_ok().as_slice().str()),
      std::move(promise));
}

td::Status TonlibClient::do_request(const tonlib_api::wallet_sendGrams& request,
                                    td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise) {
  if (!request.destination_) {
    return td::Status::Error(400, "Field destination must not be empty");
  }
  if (!request.private_key_) {
    return td::Status::Error(400, "Field private_key must not be empty");
  }
  if (request.message_.size() > 70) {
    return td::Status::Error(400, "Message is too long");
  }
  TRY_RESULT(valid_until, td::narrow_cast_safe<td::uint32>(request.valid_until_));
  TRY_RESULT(account_address, block::StdAddress::parse(request.destination_->account_address_));
  account_address.bounceable = false;
  TRY_RESULT(input_key, from_tonlib(*request.private_key_));
  auto address = GenericAccount::get_address(
      0 /*zerochain*/, Wallet::get_init_state(td::Ed25519::PublicKey(input_key.key.public_key.copy())));
  TRY_RESULT(private_key_str, key_storage_.load_private_key(std::move(input_key)));
  auto private_key = td::Ed25519::PrivateKey(std::move(private_key_str.private_key));
  std::string init_state;
  if (request.seqno_ == 0) {
    TRY_RESULT(public_key, private_key.get_public_key());
    init_state = vm::std_boc_serialize(Wallet::get_init_state(public_key)).move_as_ok().as_slice().str();
  }
  td::Promise<object_ptr<tonlib_api::ok>> new_promise =
      [promise = std::move(promise), valid_until](td::Result<object_ptr<tonlib_api::ok>> res) mutable {
        if (res.is_error()) {
          promise.set_error(res.move_as_error());
        } else {
          promise.set_value(tonlib_api::make_object<tonlib_api::sendGramsResult>(valid_until));
        }
      };
  return do_request(
      tonlib_api::raw_sendMessage(
          tonlib_api::make_object<tonlib_api::accountAddress>(address.rserialize(true)), std::move(init_state),
          vm::std_boc_serialize(Wallet::make_a_gift_message(private_key, request.seqno_, valid_until, request.amount_,
                                                            request.message_, account_address))
              .move_as_ok()
              .as_slice()
              .str()),
      std::move(new_promise));
}

td::Status TonlibClient::do_request(tonlib_api::wallet_getAccountState& request,
                                    td::Promise<object_ptr<tonlib_api::wallet_accountState>>&& promise) {
  if (!request.account_address_) {
    return td::Status::Error(400, "Field account_address must not be empty");
  }
  TRY_RESULT(account_address, block::StdAddress::parse(request.account_address_->account_address_));
  td::actor::create_actor<GetRawAccountState>(
      "GetAccountState", client_.get_client(), std::move(account_address),
      [promise = std::move(promise)](td::Result<RawAccountState> r_state) mutable {
        if (r_state.is_error()) {
          return promise.set_error(r_state.move_as_error());
        }
        promise.set_result(to_wallet_accountState(r_state.move_as_ok()));
      })
      .release();
  return td::Status::OK();
}

// TestGiver
td::Status TonlibClient::do_request(const tonlib_api::testGiver_sendGrams& request,
                                    td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise) {
  if (!request.destination_) {
    return td::Status::Error(400, "Field destination must not be empty");
  }
  if (request.message_.size() > 70) {
    return td::Status::Error(400, "Message is too long");
  }
  TRY_RESULT(account_address, block::StdAddress::parse(request.destination_->account_address_));
  account_address.bounceable = false;
  td::Promise<object_ptr<tonlib_api::ok>> new_promise =
      [promise = std::move(promise)](td::Result<object_ptr<tonlib_api::ok>> res) mutable {
        if (res.is_error()) {
          promise.set_error(res.move_as_error());
        } else {
          promise.set_value(tonlib_api::make_object<tonlib_api::sendGramsResult>(0));
        }
      };
  return do_request(tonlib_api::raw_sendMessage(
                        tonlib_api::make_object<tonlib_api::accountAddress>(TestGiver::address().rserialize(true)), "",
                        vm::std_boc_serialize(TestGiver::make_a_gift_message(request.seqno_, request.amount_,
                                                                             request.message_, account_address))
                            .move_as_ok()
                            .as_slice()
                            .str()),
                    std::move(new_promise));
}

td::Status TonlibClient::do_request(const tonlib_api::testGiver_getAccountState& request,
                                    td::Promise<object_ptr<tonlib_api::testGiver_accountState>>&& promise) {
  td::actor::create_actor<GetRawAccountState>(
      "GetAccountState", client_.get_client(), TestGiver::address(),
      [promise = std::move(promise)](td::Result<RawAccountState> r_state) mutable {
        if (r_state.is_error()) {
          return promise.set_error(r_state.move_as_error());
        }
        promise.set_result(to_testGiver_accountState(r_state.move_as_ok()));
      })
      .release();
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::generic_getAccountState& request,
                                    td::Promise<object_ptr<tonlib_api::generic_AccountState>>&& promise) {
  if (!request.account_address_) {
    return td::Status::Error(400, "Field account_address must not be empty");
  }
  TRY_RESULT(account_address, block::StdAddress::parse(request.account_address_->account_address_));
  td::actor::create_actor<GetRawAccountState>(
      "GetAccountState", client_.get_client(), std::move(account_address),
      [promise = std::move(promise)](td::Result<RawAccountState> r_state) mutable {
        if (r_state.is_error()) {
          return promise.set_error(r_state.move_as_error());
        }
        promise.set_result(to_generic_accountState(r_state.move_as_ok()));
      })
      .release();
  return td::Status::OK();
}

class TonlibQueryActor : public td::actor::Actor {
 public:
  TonlibQueryActor(td::actor::ActorShared<TonlibClient> client) : client_(std::move(client)) {
  }
  template <class QueryT>
  void send_query(QueryT query, td::Promise<typename QueryT::ReturnType> promise) {
    td::actor::send_lambda(client_,
                           [self = client_.get(), query = std::move(query), promise = std::move(promise)]() mutable {
                             auto status = self.get_actor_unsafe().do_request(query, std::move(promise));
                             if (status.is_error()) {
                               promise.set_error(std::move(status));
                             }
                           });
  }

 private:
  td::actor::ActorShared<TonlibClient> client_;
};

class GenericSendGrams : public TonlibQueryActor {
 public:
  GenericSendGrams(td::actor::ActorShared<TonlibClient> client, tonlib_api::generic_sendGrams send_grams,
                   td::Promise<tonlib_api::object_ptr<tonlib_api::sendGramsResult>>&& promise)
      : TonlibQueryActor(std::move(client)), send_grams_(std::move(send_grams)), promise_(std::move(promise)) {
  }

 private:
  tonlib_api::generic_sendGrams send_grams_;
  td::Promise<tonlib_api::object_ptr<tonlib_api::sendGramsResult>> promise_;

  tonlib_api::object_ptr<tonlib_api::generic_AccountState> source_state_;
  block::StdAddress source_address_;

  tonlib_api::object_ptr<tonlib_api::generic_AccountState> destination_state_;
  bool is_destination_bounce_{false};

  void check(td::Status status) {
    if (status.is_error()) {
      LOG(ERROR) << status;
      promise_.set_error(std::move(status));
      return stop();
    }
  }

  void start_up() override {
    check(do_start_up());
  }

  td::Status do_start_up() {
    alarm_timestamp() = td::Timestamp::in(15);
    if (!send_grams_.destination_) {
      return td::Status::Error(400, "Field destination must not be empty");
    }
    TRY_RESULT(destination_address, block::StdAddress::parse(send_grams_.destination_->account_address_));
    is_destination_bounce_ = destination_address.bounceable;

    if (!send_grams_.source_) {
      return td::Status::Error(400, "Field source must not be empty");
    }
    TRY_RESULT(source_address, block::StdAddress::parse(send_grams_.source_->account_address_));
    source_address_ = std::move(source_address);

    send_query(tonlib_api::generic_getAccountState(
                   tonlib_api::make_object<tonlib_api::accountAddress>(send_grams_.source_->account_address_)),
               [actor_id = actor_id(this)](auto r_res) {
                 send_closure(actor_id, &GenericSendGrams::on_source_state, std::move(r_res));
               });
    send_query(tonlib_api::generic_getAccountState(
                   tonlib_api::make_object<tonlib_api::accountAddress>(send_grams_.destination_->account_address_)),
               [actor_id = actor_id(this)](auto r_res) {
                 send_closure(actor_id, &GenericSendGrams::on_destination_state, std::move(r_res));
               });
    return do_loop();
  }

  static tonlib_api::object_ptr<tonlib_api::key> clone(const tonlib_api::object_ptr<tonlib_api::key>& ptr) {
    if (!ptr) {
      return nullptr;
    }
    return tonlib_api::make_object<tonlib_api::key>(ptr->public_key_, ptr->secret_.copy());
  }

  static tonlib_api::object_ptr<tonlib_api::inputKey> clone(const tonlib_api::object_ptr<tonlib_api::inputKey>& ptr) {
    if (!ptr) {
      return nullptr;
    }
    return tonlib_api::make_object<tonlib_api::inputKey>(clone(ptr->key_), ptr->local_password_.copy());
  }

  void on_source_state(td::Result<tonlib_api::object_ptr<tonlib_api::generic_AccountState>> r_state) {
    check(do_on_source_state(std::move(r_state)));
  }

  td::Status do_on_source_state(td::Result<tonlib_api::object_ptr<tonlib_api::generic_AccountState>> r_state) {
    TRY_RESULT(state, std::move(r_state));
    source_state_ = std::move(state);
    if (source_state_->get_id() == tonlib_api::generic_accountStateUninited::ID && send_grams_.private_key_ &&
        send_grams_.private_key_->key_) {
      TRY_RESULT(key_bytes, block::PublicKey::parse(send_grams_.private_key_->key_->public_key_));
      auto key = td::Ed25519::PublicKey(td::SecureString(key_bytes.key));

      if (GenericAccount::get_address(0 /*zerochain*/, TestWallet::get_init_state(key)).addr == source_address_.addr) {
        auto state = ton::move_tl_object_as<tonlib_api::generic_accountStateUninited>(source_state_);
        source_state_ = tonlib_api::make_object<tonlib_api::generic_accountStateTestWallet>(
            tonlib_api::make_object<tonlib_api::testWallet_accountState>(-1, 0, nullptr,
                                                                         state->account_state_->sync_utime_));
      } else if (GenericAccount::get_address(0 /*zerochain*/, Wallet::get_init_state(key)).addr ==
                 source_address_.addr) {
        auto state = ton::move_tl_object_as<tonlib_api::generic_accountStateUninited>(source_state_);
        source_state_ = tonlib_api::make_object<tonlib_api::generic_accountStateWallet>(
            tonlib_api::make_object<tonlib_api::wallet_accountState>(-1, 0, nullptr,
                                                                     state->account_state_->sync_utime_));
      }
    }
    return do_loop();
  }

  void on_destination_state(td::Result<tonlib_api::object_ptr<tonlib_api::generic_AccountState>> r_state) {
    check(do_on_destination_state(std::move(r_state)));
  }

  td::Status do_on_destination_state(td::Result<tonlib_api::object_ptr<tonlib_api::generic_AccountState>> r_state) {
    TRY_RESULT(state, std::move(r_state));
    destination_state_ = std::move(state);
    if (destination_state_->get_id() == tonlib_api::generic_accountStateUninited::ID && is_destination_bounce_ &&
        !send_grams_.allow_send_to_uninited_) {
      return td::Status::Error(400, "DANGEROUS_TRANSACTION: Transfer to uninited wallet");
    }
    return do_loop();
  }

  void alarm() override {
    check(td::Status::Error("Timeout"));
  }
  td::Status do_loop() {
    if (!source_state_ || !destination_state_) {
      return td::Status::OK();
    }
    downcast_call(*source_state_,
                  td::overloaded(
                      [&](tonlib_api::generic_accountStateTestGiver& test_giver_state) {
                        send_query(tonlib_api::testGiver_sendGrams(
                                       std::move(send_grams_.destination_), test_giver_state.account_state_->seqno_,
                                       send_grams_.amount_, std::move(send_grams_.message_)),
                                   std::move(promise_));
                        stop();
                      },
                      [&](tonlib_api::generic_accountStateTestWallet& test_wallet_state) {
                        send_query(tonlib_api::testWallet_sendGrams(
                                       std::move(send_grams_.private_key_), std::move(send_grams_.destination_),
                                       test_wallet_state.account_state_->seqno_, send_grams_.amount_,
                                       std::move(send_grams_.message_)),
                                   std::move(promise_));
                        stop();
                      },
                      [&](tonlib_api::generic_accountStateWallet& test_wallet_state) {
                        send_query(tonlib_api::wallet_sendGrams(
                                       std::move(send_grams_.private_key_), std::move(send_grams_.destination_),
                                       test_wallet_state.account_state_->seqno_,
                                       send_grams_.timeout_ == 0
                                           ? 60 + test_wallet_state.account_state_->sync_utime_
                                           : send_grams_.timeout_ + test_wallet_state.account_state_->sync_utime_,
                                       send_grams_.amount_, std::move(send_grams_.message_)),
                                   std::move(promise_));
                        stop();
                      },
                      [&](tonlib_api::generic_accountStateUninited&) {
                        promise_.set_error(td::Status::Error(400, "Account is not inited"));
                        stop();
                      },
                      [&](tonlib_api::generic_accountStateRaw&) {
                        promise_.set_error(td::Status::Error(400, "Unknown account type"));
                        stop();
                      }));
    return td::Status::OK();
  }
};

td::Status TonlibClient::do_request(tonlib_api::generic_sendGrams& request,
                                    td::Promise<object_ptr<tonlib_api::sendGramsResult>>&& promise) {
  if (request.timeout_ < 0 || request.timeout_ > 300) {
    return td::Status::Error(400, "Invalid timeout: must be between 0 and 300");
  }
  auto id = actor_id_++;
  actors_[id] = td::actor::create_actor<GenericSendGrams>("GenericSendGrams", actor_shared(this, id),
                                                          std::move(request), std::move(promise));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::createNewKey& request,
                                    td::Promise<object_ptr<tonlib_api::key>>&& promise) {
  TRY_RESULT(key, key_storage_.create_new_key(std::move(request.local_password_), std::move(request.mnemonic_password_),
                                              std::move(request.random_extra_seed_)));
  TRY_RESULT(key_bytes, block::PublicKey::from_bytes(key.public_key.as_slice()));
  promise.set_value(tonlib_api::make_object<tonlib_api::key>(key_bytes.serialize(true), std::move(key.secret)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::exportKey& request,
                                    td::Promise<object_ptr<tonlib_api::exportedKey>>&& promise) {
  if (!request.input_key_) {
    return td::Status::Error(400, "Field input_key must not be empty");
  }
  TRY_RESULT(input_key, from_tonlib(*request.input_key_));
  TRY_RESULT(exported_key, key_storage_.export_key(std::move(input_key)));
  promise.set_value(tonlib_api::make_object<tonlib_api::exportedKey>(std::move(exported_key.mnemonic_words)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::deleteKey& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  if (!request.key_) {
    return td::Status::Error(400, "Field key must not be empty");
  }
  TRY_RESULT(key_bytes, block::PublicKey::parse(request.key_->public_key_));
  KeyStorage::Key key;
  key.public_key = td::SecureString(key_bytes.key);
  key.secret = std::move(request.key_->secret_);
  TRY_STATUS(key_storage_.delete_key(key));
  promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::importKey& request,
                                    td::Promise<object_ptr<tonlib_api::key>>&& promise) {
  if (!request.exported_key_) {
    return td::Status::Error(400, "Field exported_key must not be empty");
  }
  TRY_RESULT(key, key_storage_.import_key(std::move(request.local_password_), std::move(request.mnemonic_password_),
                                          KeyStorage::ExportedKey{std::move(request.exported_key_->word_list_)}));
  TRY_RESULT(key_bytes, block::PublicKey::from_bytes(key.public_key.as_slice()));
  promise.set_value(tonlib_api::make_object<tonlib_api::key>(key_bytes.serialize(true), std::move(key.secret)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::exportPemKey& request,
                                    td::Promise<object_ptr<tonlib_api::exportedPemKey>>&& promise) {
  if (!request.input_key_) {
    return td::Status::Error(400, "Field input_key must not be empty");
  }
  if (!request.input_key_->key_) {
    return td::Status::Error(400, "Field key must not be empty");
  }

  TRY_RESULT(key_bytes, block::PublicKey::parse(request.input_key_->key_->public_key_));
  KeyStorage::InputKey input_key{{td::SecureString(key_bytes.key), std::move(request.input_key_->key_->secret_)},
                                 std::move(request.input_key_->local_password_)};
  TRY_RESULT(exported_pem_key, key_storage_.export_pem_key(std::move(input_key), std::move(request.key_password_)));
  promise.set_value(tonlib_api::make_object<tonlib_api::exportedPemKey>(std::move(exported_pem_key.pem)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::importPemKey& request,
                                    td::Promise<object_ptr<tonlib_api::key>>&& promise) {
  if (!request.exported_key_) {
    return td::Status::Error(400, "Field exported_key must not be empty");
  }
  TRY_RESULT(key, key_storage_.import_pem_key(std::move(request.local_password_), std::move(request.key_password_),
                                              KeyStorage::ExportedPemKey{std::move(request.exported_key_->pem_)}));
  TRY_RESULT(key_bytes, block::PublicKey::from_bytes(key.public_key.as_slice()));
  promise.set_value(tonlib_api::make_object<tonlib_api::key>(key_bytes.serialize(true), std::move(key.secret)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::exportEncryptedKey& request,
                                    td::Promise<object_ptr<tonlib_api::exportedEncryptedKey>>&& promise) {
  if (!request.input_key_) {
    return td::Status::Error(400, "Field input_key must not be empty");
  }
  TRY_RESULT(input_key, from_tonlib(*request.input_key_));
  TRY_RESULT(exported_key, key_storage_.export_encrypted_key(std::move(input_key), request.key_password_));
  promise.set_value(tonlib_api::make_object<tonlib_api::exportedEncryptedKey>(std::move(exported_key.data)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::importEncryptedKey& request,
                                    td::Promise<object_ptr<tonlib_api::key>>&& promise) {
  if (!request.exported_encrypted_key_) {
    return td::Status::Error(400, "Field exported_encrypted_key must not be empty");
  }
  TRY_RESULT(key, key_storage_.import_encrypted_key(
                      std::move(request.local_password_), std::move(request.key_password_),
                      KeyStorage::ExportedEncryptedKey{std::move(request.exported_encrypted_key_->data_)}));
  TRY_RESULT(key_bytes, block::PublicKey::from_bytes(key.public_key.as_slice()));
  promise.set_value(tonlib_api::make_object<tonlib_api::key>(key_bytes.serialize(true), std::move(key.secret)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::changeLocalPassword& request,
                                    td::Promise<object_ptr<tonlib_api::key>>&& promise) {
  if (!request.input_key_) {
    return td::Status::Error(400, "Field input_key must not be empty");
  }
  if (!request.input_key_->key_) {
    return td::Status::Error(400, "Field key must not be empty");
  }
  TRY_RESULT(input_key, from_tonlib(*request.input_key_));
  TRY_RESULT(key, key_storage_.change_local_password(std::move(input_key), std::move(request.new_local_password_)));
  promise.set_value(
      tonlib_api::make_object<tonlib_api::key>(request.input_key_->key_->public_key_, std::move(key.secret)));
  return td::Status::OK();
}

td::Status TonlibClient::do_request(const tonlib_api::onLiteServerQueryResult& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  send_closure(ext_client_outbound_, &ExtClientOutbound::on_query_result, request.id_, td::BufferSlice(request.bytes_),
               [promise = std::move(promise)](td::Result<td::Unit> res) mutable {
                 if (res.is_ok()) {
                   promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
                 } else {
                   promise.set_error(res.move_as_error());
                 }
               });
  return td::Status::OK();
}
td::Status TonlibClient::do_request(const tonlib_api::onLiteServerQueryError& request,
                                    td::Promise<object_ptr<tonlib_api::ok>>&& promise) {
  send_closure(ext_client_outbound_, &ExtClientOutbound::on_query_result, request.id_,
               td::Status::Error(request.error_->code_, request.error_->message_),
               [promise = std::move(promise)](td::Result<td::Unit> res) mutable {
                 if (res.is_ok()) {
                   promise.set_value(tonlib_api::make_object<tonlib_api::ok>());
                 } else {
                   promise.set_error(res.move_as_error());
                 }
               });
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

}  // namespace tonlib
