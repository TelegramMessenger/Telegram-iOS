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

#include "tonlib/GenericAccount.h"
#include "tonlib/TestGiver.h"
#include "tonlib/TestWallet.h"
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

#include "td/utils/port/signals.h"

using namespace tonlib;

auto sync_send = [](auto& client, auto query) {
  using ReturnTypePtr = typename std::decay_t<decltype(*query)>::ReturnType;
  using ReturnType = typename ReturnTypePtr::element_type;
  client.send({1, std::move(query)});
  while (true) {
    auto response = client.receive(100);
    if (response.object) {
      CHECK(response.id == 1);
      if (response.object->get_id() == tonlib_api::error::ID) {
        auto error = tonlib_api::move_object_as<tonlib_api::error>(response.object);
        return td::Result<ReturnTypePtr>(td::Status::Error(error->code_, error->message_));
      }
      return td::Result<ReturnTypePtr>(tonlib_api::move_object_as<ReturnType>(response.object));
    }
  }
};

struct Key {
  std::string public_key;
  td::SecureString secret;
  tonlib_api::object_ptr<tonlib_api::inputKey> get_input_key() const {
    return tonlib_api::make_object<tonlib_api::inputKey>(
        tonlib_api::make_object<tonlib_api::key>(public_key, secret.copy()), td::SecureString("local"));
  }
};
struct Wallet {
  std::string address;
  Key key;
};

std::string test_giver_address(Client& client) {
  using tonlib_api::make_object;
  return sync_send(client, make_object<tonlib_api::testGiver_getAccountAddress>()).move_as_ok()->account_address_;
}

td::int64 get_balance(Client& client, std::string address) {
  auto generic_state = sync_send(client, tonlib_api::make_object<tonlib_api::generic_getAccountState>(
                                             tonlib_api::make_object<tonlib_api::accountAddress>(address)))
                           .move_as_ok();
  td::int64 res = 0;
  tonlib_api::downcast_call(*generic_state, [&](auto& state) { res = state.account_state_->balance_; });
  return res;
}

bool is_inited(Client& client, std::string address) {
  auto generic_state = sync_send(client, tonlib_api::make_object<tonlib_api::generic_getAccountState>(
                                             tonlib_api::make_object<tonlib_api::accountAddress>(address)))
                           .move_as_ok();
  return generic_state->get_id() != tonlib_api::generic_accountStateUninited::ID;
}

void transfer_grams(Client& client, std::string from, std::string to, td::int64 amount,
                    tonlib_api::object_ptr<tonlib_api::inputKey> input_key) {
  auto balance = get_balance(client, to);
  sync_send(client, tonlib_api::make_object<tonlib_api::generic_sendGrams>(
                        std::move(input_key), tonlib_api::make_object<tonlib_api::accountAddress>(from),
                        tonlib_api::make_object<tonlib_api::accountAddress>(to), amount, "GIFT"))
      .ensure();
  while (balance == get_balance(client, to)) {
    client.receive(1);
  }
}
Wallet create_empty_wallet(Client& client) {
  using tonlib_api::make_object;
  auto key = sync_send(client, make_object<tonlib_api::createNewKey>(td::SecureString("local"),
                                                                     td::SecureString("mnemonic"), td::SecureString()))
                 .move_as_ok();
  Wallet wallet{"", {key->public_key_, std::move(key->secret_)}};

  auto account_address =
      sync_send(client, make_object<tonlib_api::testWallet_getAccountAddress>(
                            make_object<tonlib_api::testWallet_initialAccountState>(wallet.key.public_key)))
          .move_as_ok();

  wallet.address = account_address->account_address_;
  return wallet;
}

Wallet create_wallet(Client& client) {
  using tonlib_api::make_object;
  auto wallet = create_empty_wallet(client);

  transfer_grams(client, test_giver_address(client), wallet.address, 6000000000, {});
  sync_send(client, make_object<tonlib_api::testWallet_init>(wallet.key.get_input_key())).ensure();
  while (!is_inited(client, wallet.address)) {
    client.receive(1);
  }
  LOG(ERROR) << get_balance(client, wallet.address);
  return wallet;
}

std::string get_test_giver_address(Client& client) {
  return sync_send(client, tonlib_api::make_object<tonlib_api::testGiver_getAccountAddress>())
      .move_as_ok()
      ->account_address_;
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

int main(int argc, char* argv[]) {
  td::set_default_failure_signal_handler();
  using tonlib_api::make_object;

  td::OptionsParser p;
  std::string global_config_str;
  p.add_option('C', "global-config", "file to read global config", [&](td::Slice fname) {
    TRY_RESULT(str, td::read_file_str(fname.str()));
    global_config_str = std::move(str);
    LOG(ERROR) << global_config_str;
    return td::Status::OK();
  });
  p.run(argc, argv).ensure();

  Client client;
  {
    sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(global_config_str, ".", false)))
        .ensure();
  }
  //dump_transaction_history(client, get_test_giver_address(client));
  auto wallet_a = create_wallet(client);
  auto wallet_b = create_empty_wallet(client);
  transfer_grams(client, wallet_a.address, wallet_b.address, 3000000000, wallet_a.key.get_input_key());
  auto a = get_balance(client, wallet_a.address);
  auto b = get_balance(client, wallet_b.address);
  LOG(ERROR) << a << " " << b;
  return 0;
  {
    // init
    sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(global_config_str, ".", false)))
        .ensure();

    auto key = sync_send(client, make_object<tonlib_api::createNewKey>(
                                     td::SecureString("local"), td::SecureString("mnemonic"), td::SecureString()))
                   .move_as_ok();

    auto create_input_key = [&] {
      return make_object<tonlib_api::inputKey>(make_object<tonlib_api::key>(key->public_key_, key->secret_.copy()),
                                               td::SecureString("local"));
    };

    auto public_key_raw = key->public_key_;
    td::Ed25519::PublicKey public_key_std(td::SecureString{public_key_raw});

    sync_send(client, make_object<tonlib_api::options_setConfig>(global_config_str)).ensure();

    auto wallet_addr = GenericAccount::get_address(0, TestWallet::get_init_state(public_key_std));
    {
      auto account_address =
          sync_send(client, make_object<tonlib_api::testWallet_getAccountAddress>(
                                make_object<tonlib_api::testWallet_initialAccountState>(public_key_raw)))
              .move_as_ok();
      ASSERT_EQ(wallet_addr.rserialize(), account_address->account_address_);
    }

    std::string test_giver_address;
    {
      auto account_address = sync_send(client, make_object<tonlib_api::testGiver_getAccountAddress>()).move_as_ok();
      test_giver_address = account_address->account_address_;
      ASSERT_EQ(TestGiver::address().rserialize(), test_giver_address);
    }

    {
      auto account_address =
          sync_send(
              client,
              make_object<tonlib_api::raw_getAccountAddress>(make_object<tonlib_api::raw_initialAccountState>(
                  vm::std_boc_serialize(TestWallet::get_init_code()).move_as_ok().as_slice().str(),
                  vm::std_boc_serialize(TestWallet::get_init_data(public_key_std)).move_as_ok().as_slice().str())))
              .move_as_ok();
      ASSERT_EQ(wallet_addr.rserialize(), account_address->account_address_);
    }

    {
      auto state = sync_send(client, make_object<tonlib_api::raw_getAccountState>(
                                         make_object<tonlib_api::accountAddress>(wallet_addr.rserialize())))
                       .move_as_ok();
      LOG(ERROR) << to_string(state);
    }

    td::int32 seqno = 0;
    {
      auto state = sync_send(client, make_object<tonlib_api::testGiver_getAccountState>()).move_as_ok();
      LOG(ERROR) << to_string(state);
      seqno = state->seqno_;
    }

    {
      sync_send(client, make_object<tonlib_api::testGiver_sendGrams>(
                            make_object<tonlib_api::accountAddress>(wallet_addr.rserialize()), seqno,
                            1000000000ll * 6666 / 1000, "GIFT"))
          .ensure();
    }

    while (true) {
      auto state = sync_send(client, make_object<tonlib_api::testGiver_getAccountState>()).move_as_ok();
      if (state->seqno_ > seqno) {
        break;
      }
      client.receive(1);
    }

    while (true) {
      auto state = sync_send(client, make_object<tonlib_api::raw_getAccountState>(
                                         make_object<tonlib_api::accountAddress>(wallet_addr.rserialize())))
                       .move_as_ok();
      td::int64 grams_count = state->balance_;
      if (grams_count > 0) {
        LOG(ERROR) << "GOT " << grams_count;
        break;
      }
      client.receive(1);
    }

    { sync_send(client, make_object<tonlib_api::testWallet_init>(create_input_key())).ensure(); }

    while (true) {
      auto r_state = sync_send(client, make_object<tonlib_api::testWallet_getAccountState>(
                                           make_object<tonlib_api::accountAddress>(wallet_addr.rserialize())));
      if (r_state.is_ok()) {
        LOG(ERROR) << to_string(r_state.ok());
        break;
      }
      client.receive(1);
    }

    {
      sync_send(client,
                make_object<tonlib_api::generic_sendGrams>(
                    create_input_key(), make_object<tonlib_api::accountAddress>(wallet_addr.rserialize()),
                    make_object<tonlib_api::accountAddress>(test_giver_address), 1000000000ll * 3333 / 1000, "GIFT"))
          .ensure();
    }
    while (true) {
      auto generic_state = sync_send(client, make_object<tonlib_api::generic_getAccountState>(
                                                 make_object<tonlib_api::accountAddress>(wallet_addr.rserialize())))
                               .move_as_ok();
      if (generic_state->get_id() == tonlib_api::generic_accountStateTestWallet::ID) {
        auto state = tonlib_api::move_object_as<tonlib_api::generic_accountStateTestWallet>(generic_state);
        if (state->account_state_->balance_ < 5617007000) {
          LOG(ERROR) << to_string(state);
          break;
        }
      }
      client.receive(1);
    }
    {
      auto generic_state = sync_send(client, make_object<tonlib_api::generic_getAccountState>(
                                                 make_object<tonlib_api::accountAddress>(test_giver_address)))
                               .move_as_ok();
      CHECK(generic_state->get_id() == tonlib_api::generic_accountStateTestGiver::ID);
      LOG(ERROR) << to_string(generic_state);
    }
  }

  return 0;
}
