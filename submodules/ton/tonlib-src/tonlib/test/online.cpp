/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "adnl/adnl-ext-client.h"
#include "tl-utils/tl-utils.hpp"
#include "auto/tl/ton_api_json.h"
#include "auto/tl/tonlib_api_json.h"
#include "tl/tl_json.h"
#include "ton/ton-types.h"
#include "ton/ton-tl.hpp"
#include "block/block.h"
#include "block/block-auto.h"
#include "Ed25519.h"

#include "smc-envelope/GenericAccount.h"
#include "smc-envelope/MultisigWallet.h"
#include "smc-envelope/TestGiver.h"
#include "smc-envelope/TestWallet.h"
#include "tonlib/LastBlock.h"
#include "tonlib/ExtClient.h"
#include "tonlib/utils.h"

#include "tonlib/TonlibCallback.h"
#include "tonlib/Client.h"

#include "vm/cells.h"
#include "vm/boc.h"
#include "vm/cells/MerkleProof.h"

#include "td/utils/Container.h"
#include "td/utils/OptionsParser.h"
#include "td/utils/Random.h"
#include "td/utils/filesystem.h"
#include "td/utils/tests.h"
#include "td/utils/optional.h"
#include "td/utils/overloaded.h"
#include "td/utils/MpscPollableQueue.h"
#include "td/utils/port/path.h"

#include "td/utils/port/signals.h"

using namespace tonlib;

constexpr td::int64 Gramm = 1000000000;

auto sync_send = [](auto& client, auto query) {
  using ReturnTypePtr = typename std::decay_t<decltype(*query)>::ReturnType;
  using ReturnType = typename ReturnTypePtr::element_type;
  client.send({1, std::move(query)});
  while (true) {
    auto response = client.receive(100);
    if (response.object && response.id != 0) {
      CHECK(response.id == 1);
      if (response.object->get_id() == tonlib_api::error::ID) {
        auto error = tonlib_api::move_object_as<tonlib_api::error>(response.object);
        return td::Result<ReturnTypePtr>(td::Status::Error(error->code_, error->message_));
      }
      return td::Result<ReturnTypePtr>(tonlib_api::move_object_as<ReturnType>(response.object));
    }
  }
};
auto static_send = [](auto query) {
  using ReturnTypePtr = typename std::decay_t<decltype(*query)>::ReturnType;
  using ReturnType = typename ReturnTypePtr::element_type;
  auto response = Client::execute({1, std::move(query)});
  if (response.object->get_id() == tonlib_api::error::ID) {
    auto error = tonlib_api::move_object_as<tonlib_api::error>(response.object);
    return td::Result<ReturnTypePtr>(td::Status::Error(error->code_, error->message_));
  }
  return td::Result<ReturnTypePtr>(tonlib_api::move_object_as<ReturnType>(response.object));
};

struct Key {
  std::string public_key;
  td::SecureString secret;
  tonlib_api::object_ptr<tonlib_api::InputKey> get_input_key() const {
    return tonlib_api::make_object<tonlib_api::inputKeyRegular>(
        tonlib_api::make_object<tonlib_api::key>(public_key, secret.copy()), td::SecureString("local"));
  }
  tonlib_api::object_ptr<tonlib_api::InputKey> get_fake_input_key() const {
    return tonlib_api::make_object<tonlib_api::inputKeyFake>();
  }
};
struct Wallet {
  std::string address;
  Key key;
};

struct TransactionId {
  td::int64 lt{0};
  std::string hash;
};

struct AccountState {
  enum Type { Empty, Wallet, Unknown } type{Empty};
  td::int64 sync_utime{-1};
  td::int64 balance{-1};
  TransactionId last_transaction_id;
  std::string address;

  bool is_inited() const {
    return type != Empty;
  }
};

using tonlib_api::make_object;

void sync(Client& client) {
  sync_send(client, make_object<tonlib_api::sync>()).ensure();
}

static td::uint32 default_wallet_id{0};
std::string wallet_address(Client& client, const Key& key) {
  return sync_send(client,
                   make_object<tonlib_api::wallet_v3_getAccountAddress>(
                       make_object<tonlib_api::wallet_v3_initialAccountState>(key.public_key, default_wallet_id)))
      .move_as_ok()
      ->account_address_;
}

Wallet import_wallet_from_pkey(Client& client, std::string pkey, std::string password) {
  auto key = sync_send(client, make_object<tonlib_api::importPemKey>(
                                   td::SecureString("local"), td::SecureString(password),
                                   make_object<tonlib_api::exportedPemKey>(td::SecureString(pkey))))
                 .move_as_ok();
  Wallet wallet{"", {key->public_key_, std::move(key->secret_)}};
  wallet.address = wallet_address(client, wallet.key);
  return wallet;
}

std::string test_giver_address(Client& client) {
  using tonlib_api::make_object;
  return sync_send(client, make_object<tonlib_api::testGiver_getAccountAddress>()).move_as_ok()->account_address_;
}

AccountState get_account_state(Client& client, std::string address) {
  auto generic_state = sync_send(client, tonlib_api::make_object<tonlib_api::generic_getAccountState>(
                                             tonlib_api::make_object<tonlib_api::accountAddress>(address)))
                           .move_as_ok();
  AccountState res;
  tonlib_api::downcast_call(*generic_state, [&](auto& state) {
    res.balance = state.account_state_->balance_;
    res.sync_utime = state.account_state_->sync_utime_;
    res.last_transaction_id.lt = state.account_state_->last_transaction_id_->lt_;
    res.last_transaction_id.hash = state.account_state_->last_transaction_id_->hash_;
  });
  res.address = address;
  switch (generic_state->get_id()) {
    case tonlib_api::generic_accountStateUninited::ID:
      res.type = AccountState::Empty;
      break;
    case tonlib_api::generic_accountStateWalletV3::ID:
    case tonlib_api::generic_accountStateWallet::ID:
      res.type = AccountState::Wallet;
      break;
    default:
      res.type = AccountState::Unknown;
      break;
  }
  return res;
}

struct QueryId {
  td::int64 id;
};

struct Fee {
  td::int64 in_fwd_fee{0};
  td::int64 storage_fee{0};
  td::int64 gas_fee{0};
  td::int64 fwd_fee{0};
  td::int64 sum() const {
    return in_fwd_fee + storage_fee + gas_fee + fwd_fee;
  }
};

template <class T>
auto to_fee(const T& fee) {
  Fee res;
  res.in_fwd_fee = fee->in_fwd_fee_;
  res.storage_fee = fee->storage_fee_;
  res.gas_fee = fee->gas_fee_;
  res.fwd_fee = fee->fwd_fee_;
  return res;
}

td::StringBuilder& operator<<(td::StringBuilder& sb, const Fee& fees) {
  return sb << td::tag("in_fwd_fee", fees.in_fwd_fee) << td::tag("storage_fee", fees.storage_fee)
            << td::tag("gas_fee", fees.gas_fee) << td::tag("fwd_fee", fees.fwd_fee);
}

struct QueryInfo {
  td::int64 valid_until;
  std::string body_hash;
};

td::Result<QueryId> create_send_grams_query(Client& client, const Wallet& source, std::string destination,
                                            td::int64 amount, std::string message, bool force = false, int timeout = 0,
                                            bool fake = false) {
  auto r_id = sync_send(client, tonlib_api::make_object<tonlib_api::generic_createSendGramsQuery>(
                                    fake ? source.key.get_fake_input_key() : source.key.get_input_key(),
                                    tonlib_api::make_object<tonlib_api::accountAddress>(source.address),
                                    tonlib_api::make_object<tonlib_api::accountAddress>(destination), amount, timeout,
                                    force, std::move(message)));
  TRY_RESULT(id, std::move(r_id));
  return QueryId{id->id_};
}

td::Result<QueryId> create_raw_query(Client& client, std::string source, std::string init_code, std::string init_data,
                                     std::string body) {
  auto r_id =
      sync_send(client, tonlib_api::make_object<tonlib_api::raw_createQuery>(
                            tonlib_api::make_object<tonlib_api::accountAddress>(source), init_code, init_data, body));
  TRY_RESULT(id, std::move(r_id));
  return QueryId{id->id_};
}

std::pair<Fee, Fee> query_estimate_fees(Client& client, QueryId query_id, bool ignore_chksig = false) {
  auto fees = sync_send(client, tonlib_api::make_object<tonlib_api::query_estimateFees>(query_id.id, ignore_chksig))
                  .move_as_ok();
  return std::make_pair(to_fee(fees->source_fees_), to_fee(fees->destination_fees_));
}

void query_send(Client& client, QueryId query_id) {
  sync_send(client, tonlib_api::make_object<tonlib_api::query_send>(query_id.id)).ensure();
}
QueryInfo query_get_info(Client& client, QueryId query_id) {
  auto info = sync_send(client, tonlib_api::make_object<tonlib_api::query_getInfo>(query_id.id)).move_as_ok();
  return QueryInfo{info->valid_until_, info->body_hash_};
}

td::Result<AccountState> wait_state_change(Client& client, const AccountState& old_state, td::int64 valid_until) {
  while (true) {
    auto new_state = get_account_state(client, old_state.address);
    if (new_state.last_transaction_id.lt != old_state.last_transaction_id.lt) {
      return new_state;
    }
    if (valid_until != 0 && new_state.sync_utime >= valid_until) {
      return td::Status::Error("valid_until expired");
    }
    client.receive(1);
  }
};

td::Result<tonlib_api::object_ptr<tonlib_api::raw_transactions>> get_transactions(Client& client, std::string address,
                                                                                  const TransactionId& from) {
  auto got_transactions = sync_send(client, make_object<tonlib_api::raw_getTransactions>(
                                                make_object<tonlib_api::accountAddress>(address),
                                                make_object<tonlib_api::internal_transactionId>(from.lt, from.hash)))
                              .move_as_ok();
  return std::move(got_transactions);
}

td::Status transfer_grams(Client& client, const Wallet& wallet, std::string address, td::int64 amount) {
  auto src_state = get_account_state(client, wallet.address);
  auto dst_state = get_account_state(client, address);
  auto message = td::rand_string('a', 'z', 500);

  LOG(INFO) << "Transfer: create query " << (double)amount / Gramm << " from " << wallet.address << " to " << address;
  auto r_query_id = create_send_grams_query(client, wallet, address, amount, message);
  if (r_query_id.is_error() && td::begins_with(r_query_id.error().message(), "DANGEROUS_TRANSACTION")) {
    ASSERT_TRUE(dst_state.type == AccountState::Empty);
    LOG(INFO) << "Transfer: recreate query due to DANGEROUS_TRANSACTION error";
    r_query_id = create_send_grams_query(client, wallet, address, amount, message, true);
  }

  r_query_id.ensure();
  QueryId query_id = r_query_id.move_as_ok();
  auto query_info = query_get_info(client, query_id);
  auto fees = query_estimate_fees(client, query_id);

  LOG(INFO) << "Expected src fees: " << fees.first;
  LOG(INFO) << "Expected dst fees: " << fees.second;

  bool transfer_all = amount == src_state.balance;
  if (!transfer_all && amount + fees.first.sum() + 10 > src_state.balance) {
    return td::Status::Error("Not enough balance for query");
  }

  LOG(INFO) << "Transfer: send query";

  query_send(client, query_id);
  td::Timer timer;
  TRY_RESULT(new_src_state, wait_state_change(client, src_state, query_info.valid_until));
  LOG(INFO) << "Transfer: reached source in " << timer;

  td::int64 lt;
  td::int64 first_fee;
  {
    auto tr = get_transactions(client, src_state.address, new_src_state.last_transaction_id).move_as_ok();
    CHECK(tr->transactions_.size() > 0);
    const auto& txn = tr->transactions_[0];
    CHECK(txn->in_msg_->body_hash_ == query_info.body_hash);
    ASSERT_EQ(1u, txn->out_msgs_.size());
    ASSERT_EQ(message, txn->out_msgs_[0]->message_);
    lt = txn->out_msgs_[0]->created_lt_;
    auto fee_difference = fees.first.sum() - txn->fee_;
    first_fee = txn->fee_;
    auto desc = PSTRING() << fee_difference << " storage:[" << fees.first.storage_fee << " vs " << txn->storage_fee_
                          << "] other:[" << fees.first.sum() - fees.first.storage_fee << " vs " << txn->other_fee_
                          << "]";
    LOG(INFO) << "Source fee difference " << desc;
    LOG_IF(ERROR, std::abs(fee_difference) > 1) << "Too big source fee difference " << desc;
  }

  TRY_RESULT(new_dst_state, wait_state_change(client, dst_state, new_src_state.sync_utime + 30));
  LOG(INFO) << "Transfer: reached destination in " << timer;

  {
    auto tr = get_transactions(client, dst_state.address, new_dst_state.last_transaction_id).move_as_ok();
    CHECK(tr->transactions_.size() > 0);
    const auto& txn = tr->transactions_[0];
    ASSERT_EQ(lt, txn->in_msg_->created_lt_);
    if (transfer_all) {
      ASSERT_EQ(amount - first_fee, txn->in_msg_->value_);
    } else {
      ASSERT_EQ(new_src_state.address, txn->in_msg_->source_);
    }
    ASSERT_EQ(new_src_state.address, txn->in_msg_->source_);
    ASSERT_EQ(message, txn->in_msg_->message_);
    auto fee_difference = fees.second.sum() - txn->fee_;
    auto desc = PSTRING() << fee_difference << " storage:[" << fees.second.storage_fee << " vs " << txn->storage_fee_
                          << "] other:[" << fees.second.sum() - fees.second.storage_fee << " vs " << txn->other_fee_
                          << "]";
    LOG(INFO) << "Destination fee difference " << desc;
    LOG_IF(ERROR, std::abs(fee_difference) > 1) << "Too big destination fee difference " << desc;
  }

  return td::Status::OK();
}

Wallet create_empty_wallet(Client& client) {
  using tonlib_api::make_object;
  auto key = sync_send(client, make_object<tonlib_api::createNewKey>(td::SecureString("local"), td::SecureString(),
                                                                     td::SecureString()))
                 .move_as_ok();
  Wallet wallet{"", {key->public_key_, std::move(key->secret_)}};

  auto account_address =
      sync_send(client,
                make_object<tonlib_api::wallet_v3_getAccountAddress>(
                    make_object<tonlib_api::wallet_v3_initialAccountState>(wallet.key.public_key, default_wallet_id)))
          .move_as_ok();

  wallet.address = account_address->account_address_;

  // get state of empty account
  auto state = get_account_state(client, wallet.address);
  ASSERT_EQ(-1, state.balance);
  ASSERT_EQ(AccountState::Empty, state.type);

  return wallet;
}

void dump_transaction_history(Client& client, std::string address) {
  using tonlib_api::make_object;
  auto state = sync_send(client, make_object<tonlib_api::testGiver_getAccountState>()).move_as_ok();
  auto tid = std::move(state->last_transaction_id_);
  int cnt = 0;
  while (tid->lt_ != 0) {
    auto lt = tid->lt_;
    auto got_transactions = sync_send(client, make_object<tonlib_api::raw_getTransactions>(
                                                  make_object<tonlib_api::accountAddress>(address), std::move(tid)))
                                .move_as_ok();
    CHECK(got_transactions->transactions_.size() > 0);
    CHECK(got_transactions->previous_transaction_id_->lt_ < lt);
    for (auto& txn : got_transactions->transactions_) {
      LOG(ERROR) << to_string(txn);
      cnt++;
    }
    tid = std::move(got_transactions->previous_transaction_id_);
  }
  LOG(ERROR) << cnt;
}

void test_estimate_fees_without_key(Client& client, const Wallet& wallet_a, const Wallet& wallet_b) {
  LOG(ERROR) << " SUBTEST: estimate fees without key";
  {
    auto query_id = create_send_grams_query(client, wallet_a, wallet_b.address, 0, "???", true, 0, true).move_as_ok();
    auto fees1 = query_estimate_fees(client, query_id, false);
    auto fees2 = query_estimate_fees(client, query_id, true);
    LOG(INFO) << "Fee without ignore_chksig\t" << fees1;
    LOG(INFO) << "Fee with    ignore_chksig\t" << fees2;
    CHECK(fees1.first.gas_fee == 0);
    CHECK(fees2.first.gas_fee != 0);
  }
}

void test_back_and_forth_transfer(Client& client, const Wallet& giver_wallet, bool flag) {
  LOG(ERROR) << "TEST: back and forth transfer";
  // just generate private key and address
  auto wallet_a = create_empty_wallet(client);
  LOG(INFO) << wallet_a.address;

  // get state of empty account
  auto state = get_account_state(client, wallet_a.address);
  ASSERT_EQ(-1, state.balance);
  ASSERT_EQ(AccountState::Empty, state.type);

  test_estimate_fees_without_key(client, giver_wallet, wallet_a);

  // transfer from giver to a
  transfer_grams(client, giver_wallet, wallet_a.address, 1 * Gramm).ensure();
  state = get_account_state(client, wallet_a.address);
  ASSERT_EQ(1 * Gramm, state.balance);
  ASSERT_EQ(AccountState::Empty, state.type);

  test_estimate_fees_without_key(client, wallet_a, giver_wallet);

  if (flag) {
    // transfer from a to giver
    transfer_grams(client, wallet_a, giver_wallet.address, 5 * Gramm / 10).ensure();
    state = get_account_state(client, wallet_a.address);
    ASSERT_TRUE(state.balance < 5 * Gramm / 10);
    ASSERT_EQ(AccountState::Wallet, state.type);
  }

  // transfer all remaining balance (test flag 128)
  transfer_grams(client, wallet_a, giver_wallet.address, state.balance).ensure();
  state = get_account_state(client, wallet_a.address);
  ASSERT_TRUE(state.balance == 0);
  ASSERT_EQ(AccountState::Wallet, state.type);
}

void test_multisig(Client& client, const Wallet& giver_wallet) {
  LOG(ERROR) << "TEST: multisig";

  int n = 16;
  int k = 10;
  std::vector<td::Ed25519::PrivateKey> private_keys;
  for (int i = 0; i < n; i++) {
    private_keys.push_back(td::Ed25519::generate_private_key().move_as_ok());
  }

  auto ms = ton::MultisigWallet::create();
  auto init_data = ms->create_init_data(
      td::transform(private_keys, [](const auto& pk) { return pk.get_public_key().move_as_ok().as_octet_string(); }),
      k);
  ms = ton::MultisigWallet::create(init_data);
  auto raw_address = ms->get_address(ton::basechainId);
  auto address = raw_address.rserialize();
  transfer_grams(client, giver_wallet, address, 1 * Gramm).ensure();
  auto init_state = ms->get_init_state();

  for (int i = 0; i < 2; i++) {
    // Just transfer all (some) money back in one query
    vm::CellBuilder icb;
    ton::GenericAccount::store_int_message(icb, block::StdAddress::parse(giver_wallet.address).move_as_ok(), 1);
    icb.store_bytes("\0\0\0\0", 4);
    vm::CellString::store(icb, "Greatings from multisig", 35 * 8).ensure();
    ton::MultisigWallet::QueryBuilder qb(-1 - i, icb.finalize());
    for (int i = 0; i < k - 1; i++) {
      qb.sign(i, private_keys[i]);
    }

    auto query_id =
        create_raw_query(client, address,
                         i == 0 ? vm::std_boc_serialize(ms->get_state().code).move_as_ok().as_slice().str() : "",
                         i == 0 ? vm::std_boc_serialize(ms->get_state().data).move_as_ok().as_slice().str() : "",
                         vm::std_boc_serialize(qb.create(k - 1, private_keys[k - 1])).move_as_ok().as_slice().str())
            .move_as_ok();
    auto fees = query_estimate_fees(client, query_id);

    LOG(INFO) << "Expected src fees: " << fees.first;
    LOG(INFO) << "Expected dst fees: " << fees.second;
    auto a_state = get_account_state(client, address);
    query_send(client, query_id);
    auto new_a_state = wait_state_change(client, a_state, a_state.sync_utime + 30).move_as_ok();
  }
}

int main(int argc, char* argv[]) {
  td::set_default_failure_signal_handler();
  using tonlib_api::make_object;

  td::OptionsParser p;
  std::string global_config_str;
  std::string giver_key_str;
  std::string giver_key_pwd = "cucumber";
  std::string keystore_dir = "test-keystore";
  bool reset_keystore_dir = false;
  p.add_option('C', "global-config", "file to read global config", [&](td::Slice fname) {
    TRY_RESULT(str, td::read_file_str(fname.str()));
    global_config_str = std::move(str);
    return td::Status::OK();
  });
  p.add_option('G', "giver-key", "file with a wallet key that should be used as a giver", [&](td::Slice fname) {
    TRY_RESULT(str, td::read_file_str(fname.str()));
    giver_key_str = std::move(str);
    return td::Status::OK();
  });
  p.add_option('f', "force", "reser keystore dir", [&]() {
    reset_keystore_dir = true;
    return td::Status::OK();
  });
  p.run(argc, argv).ensure();

  if (reset_keystore_dir) {
    td::rmrf(keystore_dir).ignore();
  }
  td::mkdir(keystore_dir).ensure();

  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(INFO));
  static_send(make_object<tonlib_api::setLogTagVerbosityLevel>("tonlib_query", 4)).ensure();
  auto tags = static_send(make_object<tonlib_api::getLogTags>()).move_as_ok()->tags_;
  for (auto& tag : tags) {
    static_send(make_object<tonlib_api::setLogTagVerbosityLevel>(tag, 4)).ensure();
  }

  Client client;
  {
    auto info = sync_send(client, make_object<tonlib_api::options_validateConfig>(
                                      make_object<tonlib_api::config>(global_config_str, "", false, false)))
                    .move_as_ok();
    default_wallet_id = static_cast<td::uint32>(info->default_wallet_id_);
    sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(
                          make_object<tonlib_api::config>(global_config_str, "", false, false),
                          make_object<tonlib_api::keyStoreTypeDirectory>(keystore_dir))))
        .ensure();
  }

  // wait till client is synchronized with blockchain.
  // not necessary, but synchronized will be trigged anyway later
  sync(client);

  // give wallet with some test grams to run test
  auto giver_wallet = import_wallet_from_pkey(client, giver_key_str, giver_key_pwd);

  test_back_and_forth_transfer(client, giver_wallet, false);
  test_back_and_forth_transfer(client, giver_wallet, true);
  test_multisig(client, giver_wallet);

  return 0;
}
