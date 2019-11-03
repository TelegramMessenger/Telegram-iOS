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
#include "vm/dict.h"
#include "common/bigint.hpp"

#include "Ed25519.h"

#include "block/block.h"

#include "fift/Fift.h"
#include "fift/words.h"
#include "fift/utils.h"

#include "smc-envelope/GenericAccount.h"
#include "smc-envelope/MultisigWallet.h"
#include "smc-envelope/SmartContract.h"
#include "smc-envelope/SmartContractCode.h"
#include "smc-envelope/TestGiver.h"
#include "smc-envelope/TestWallet.h"
#include "smc-envelope/Wallet.h"
#include "smc-envelope/WalletV3.h"

#include "td/utils/base64.h"
#include "td/utils/crypto.h"
#include "td/utils/Random.h"
#include "td/utils/tests.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Timer.h"
#include "td/utils/PathView.h"
#include "td/utils/filesystem.h"
#include "td/utils/port/path.h"

#include <bitset>
#include <set>
#include <tuple>

std::string current_dir() {
  return td::PathView(td::realpath(__FILE__).move_as_ok()).parent_dir().str();
}

std::string load_source(std::string name) {
  return td::read_file_str(current_dir() + "../../crypto/" + name).move_as_ok();
}

td::Ref<vm::Cell> get_test_wallet_source() {
  std::string code = R"ABCD(
SETCP0 DUP IFNOTRET // return if recv_internal
DUP 85143 INT EQUAL IFJMP:<{ // "seqno" get-method
  DROP c4 PUSHCTR CTOS 32 PLDU  // cnt
}>
INC 32 THROWIF  // fail unless recv_external
512 INT LDSLICEX DUP 32 PLDU   // sign cs cnt
c4 PUSHCTR CTOS 32 LDU 256 LDU ENDS  // sign cs cnt cnt' pubk
s1 s2 XCPU            // sign cs cnt pubk cnt' cnt
EQUAL 33 THROWIFNOT   // ( seqno mismatch? )
s2 PUSH HASHSU        // sign cs cnt pubk hash
s0 s4 s4 XC2PU        // pubk cs cnt hash sign pubk
CHKSIGNU              // pubk cs cnt ?
34 THROWIFNOT         // signature mismatch
ACCEPT
SWAP 32 LDU NIP
DUP SREFS IF:<{
  // 3 INT 35 LSHIFT# 3 INT RAWRESERVE    // reserve all but 103 Grams from the balance
  8 LDU LDREF         // pubk cnt mode msg cs
  s0 s2 XCHG SENDRAWMSG  // pubk cnt cs ; ( message sent )
}>
ENDS
INC NEWC 32 STU 256 STU ENDC c4 POPCTR
)ABCD";
  return fift::compile_asm(code).move_as_ok();
}

td::Ref<vm::Cell> get_wallet_source() {
  std::string code = R"ABCD(
SETCP0 DUP IFNOTRET // return if recv_internal
   DUP 85143 INT EQUAL IFJMP:<{ // "seqno" get-method
     DROP c4 PUSHCTR CTOS 32 PLDU  // cnt
   }>
   INC 32 THROWIF	// fail unless recv_external
   9 PUSHPOW2 LDSLICEX DUP 32 LDU 32 LDU	//  signature in_msg msg_seqno valid_until cs
   SWAP NOW LEQ 35 THROWIF	//  signature in_msg msg_seqno cs
   c4 PUSH CTOS 32 LDU 256 LDU ENDS	//  signature in_msg msg_seqno cs stored_seqno public_key
   s3 s1 XCPU	//  signature in_msg public_key cs stored_seqno msg_seqno stored_seqno
   EQUAL 33 THROWIFNOT	//  signature in_msg public_key cs stored_seqno
   s0 s3 XCHG HASHSU	//  signature stored_seqno public_key cs hash
   s0 s4 s2 XC2PU CHKSIGNU 34 THROWIFNOT	//  cs stored_seqno public_key
   ACCEPT
   s0 s2 XCHG	//  public_key stored_seqno cs
   WHILE:<{
     DUP SREFS	//  public_key stored_seqno cs _40
   }>DO<{	//  public_key stored_seqno cs
     // 3 INT 35 LSHIFT# 3 INT RAWRESERVE    // reserve all but 103 Grams from the balance
     8 LDU LDREF s0 s2 XCHG	//  public_key stored_seqno cs _45 mode
     SENDRAWMSG	//  public_key stored_seqno cs
   }>
   ENDS INC	//  public_key seqno'
   NEWC 32 STU 256 STU ENDC c4 POP
)ABCD";
  return fift::compile_asm(code).move_as_ok();
}
td::Ref<vm::Cell> get_wallet_v3_source() {
  std::string code = R"ABCD(
SETCP0 DUP IFNOTRET // return if recv_internal
   DUP 85143 INT EQUAL IFJMP:<{ // "seqno" get-method
     DROP c4 PUSHCTR CTOS 32 PLDU  // cnt
   }>
   INC 32 THROWIF	// fail unless recv_external
   9 PUSHPOW2 LDSLICEX DUP 32 LDU 32 LDU 32 LDU 	//  signature in_msg subwallet_id valid_until msg_seqno cs
   NOW s1 s3 XCHG LEQ 35 THROWIF	//  signature in_msg subwallet_id cs msg_seqno
   c4 PUSH CTOS 32 LDU 32 LDU 256 LDU ENDS	//  signature in_msg subwallet_id cs msg_seqno stored_seqno stored_subwallet public_key
   s3 s2 XCPU EQUAL 33 THROWIFNOT	//  signature in_msg subwallet_id cs public_key stored_seqno stored_subwallet
   s4 s4 XCPU EQUAL 34 THROWIFNOT	//  signature in_msg stored_subwallet cs public_key stored_seqno
   s0 s4 XCHG HASHSU	//  signature stored_seqno stored_subwallet cs public_key msg_hash
   s0 s5 s5 XC2PU	//  public_key stored_seqno stored_subwallet cs msg_hash signature public_key
   CHKSIGNU 35 THROWIFNOT	//  public_key stored_seqno stored_subwallet cs
   ACCEPT
   WHILE:<{
     DUP SREFS	//  public_key stored_seqno stored_subwallet cs _51
   }>DO<{	//  public_key stored_seqno stored_subwallet cs
     8 LDU LDREF s0 s2 XCHG	//  public_key stored_seqno stored_subwallet cs _56 mode
     SENDRAWMSG
   }>	//  public_key stored_seqno stored_subwallet cs
   ENDS SWAP INC	//  public_key stored_subwallet seqno'
   NEWC 32 STU 32 STU 256 STU ENDC c4 POP
)ABCD";
  return fift::compile_asm(code).move_as_ok();
}

TEST(Tonlib, TestWallet) {
  LOG(ERROR) << td::base64_encode(std_boc_serialize(get_test_wallet_source()).move_as_ok());
  CHECK(get_test_wallet_source()->get_hash() == ton::TestWallet::get_init_code()->get_hash());
  auto fift_output = fift::mem_run_fift(load_source("smartcont/new-wallet.fif"), {"aba", "0"}).move_as_ok();

  auto new_wallet_pk = fift_output.source_lookup.read_file("new-wallet.pk").move_as_ok().data;
  auto new_wallet_query = fift_output.source_lookup.read_file("new-wallet-query.boc").move_as_ok().data;
  auto new_wallet_addr = fift_output.source_lookup.read_file("new-wallet.addr").move_as_ok().data;

  td::Ed25519::PrivateKey priv_key{td::SecureString{new_wallet_pk}};
  auto pub_key = priv_key.get_public_key().move_as_ok();
  auto init_state = ton::TestWallet::get_init_state(pub_key);
  auto init_message = ton::TestWallet::get_init_message(priv_key);
  auto address = ton::GenericAccount::get_address(0, init_state);

  CHECK(address.addr.as_slice() == td::Slice(new_wallet_addr).substr(0, 32));

  td::Ref<vm::Cell> res = ton::GenericAccount::create_ext_message(address, init_state, init_message);

  LOG(ERROR) << "-------";
  vm::load_cell_slice(res).print_rec(std::cerr);
  LOG(ERROR) << "-------";
  vm::load_cell_slice(vm::std_boc_deserialize(new_wallet_query).move_as_ok()).print_rec(std::cerr);
  CHECK(vm::std_boc_deserialize(new_wallet_query).move_as_ok()->get_hash() == res->get_hash());

  fift_output.source_lookup.write_file("/main.fif", load_source("smartcont/wallet.fif")).ensure();
  auto dest = block::StdAddress::parse("Ef9Tj6fMJP+OqhAdhKXxq36DL+HYSzCc3+9O6UNzqsgPfYFX").move_as_ok();
  fift_output = fift::mem_run_fift(std::move(fift_output.source_lookup),
                                   {"aba", "new-wallet", "Ef9Tj6fMJP+OqhAdhKXxq36DL+HYSzCc3+9O6UNzqsgPfYFX", "123",
                                    "321", "-C", "TEST"})
                    .move_as_ok();
  auto wallet_query = fift_output.source_lookup.read_file("wallet-query.boc").move_as_ok().data;
  auto gift_message = ton::GenericAccount::create_ext_message(
      address, {}, ton::TestWallet::make_a_gift_message(priv_key, 123, 321000000000ll, "TEST", dest));
  LOG(ERROR) << "-------";
  vm::load_cell_slice(gift_message).print_rec(std::cerr);
  LOG(ERROR) << "-------";
  vm::load_cell_slice(vm::std_boc_deserialize(wallet_query).move_as_ok()).print_rec(std::cerr);
  CHECK(vm::std_boc_deserialize(wallet_query).move_as_ok()->get_hash() == gift_message->get_hash());
}

td::Ref<vm::Cell> get_wallet_source_fc() {
  return fift::compile_asm(load_source("smartcont/wallet-code.fif"), "", false).move_as_ok();
}

TEST(Tonlib, Wallet) {
  LOG(ERROR) << td::base64_encode(std_boc_serialize(get_wallet_source()).move_as_ok());
  CHECK(get_wallet_source()->get_hash() == ton::Wallet::get_init_code()->get_hash());

  auto fift_output = fift::mem_run_fift(load_source("smartcont/new-wallet-v2.fif"), {"aba", "0"}).move_as_ok();

  auto new_wallet_pk = fift_output.source_lookup.read_file("new-wallet.pk").move_as_ok().data;
  auto new_wallet_query = fift_output.source_lookup.read_file("new-wallet-query.boc").move_as_ok().data;
  auto new_wallet_addr = fift_output.source_lookup.read_file("new-wallet.addr").move_as_ok().data;

  td::Ed25519::PrivateKey priv_key{td::SecureString{new_wallet_pk}};
  auto pub_key = priv_key.get_public_key().move_as_ok();
  auto init_state = ton::Wallet::get_init_state(pub_key);
  auto init_message = ton::Wallet::get_init_message(priv_key);
  auto address = ton::GenericAccount::get_address(0, init_state);

  CHECK(address.addr.as_slice() == td::Slice(new_wallet_addr).substr(0, 32));

  td::Ref<vm::Cell> res = ton::GenericAccount::create_ext_message(address, init_state, init_message);

  LOG(ERROR) << "-------";
  vm::load_cell_slice(res).print_rec(std::cerr);
  LOG(ERROR) << "-------";
  vm::load_cell_slice(vm::std_boc_deserialize(new_wallet_query).move_as_ok()).print_rec(std::cerr);
  CHECK(vm::std_boc_deserialize(new_wallet_query).move_as_ok()->get_hash() == res->get_hash());

  fift_output.source_lookup.write_file("/main.fif", load_source("smartcont/wallet-v2.fif")).ensure();
  class ZeroOsTime : public fift::OsTime {
   public:
    td::uint32 now() override {
      return 0;
    }
  };
  fift_output.source_lookup.set_os_time(std::make_unique<ZeroOsTime>());
  auto dest = block::StdAddress::parse("Ef9Tj6fMJP+OqhAdhKXxq36DL+HYSzCc3+9O6UNzqsgPfYFX").move_as_ok();
  fift_output =
      fift::mem_run_fift(std::move(fift_output.source_lookup),
                         {"aba", "new-wallet", "Ef9Tj6fMJP+OqhAdhKXxq36DL+HYSzCc3+9O6UNzqsgPfYFX", "123", "321"})
          .move_as_ok();
  auto wallet_query = fift_output.source_lookup.read_file("wallet-query.boc").move_as_ok().data;
  auto gift_message = ton::GenericAccount::create_ext_message(
      address, {}, ton::Wallet::make_a_gift_message(priv_key, 123, 60, 321000000000ll, "TESTv2", dest));
  LOG(ERROR) << "-------";
  vm::load_cell_slice(gift_message).print_rec(std::cerr);
  LOG(ERROR) << "-------";
  vm::load_cell_slice(vm::std_boc_deserialize(wallet_query).move_as_ok()).print_rec(std::cerr);
  CHECK(vm::std_boc_deserialize(wallet_query).move_as_ok()->get_hash() == gift_message->get_hash());
}

TEST(Tonlib, WalletV3) {
  LOG(ERROR) << td::base64_encode(std_boc_serialize(get_wallet_v3_source()).move_as_ok());
  CHECK(get_wallet_v3_source()->get_hash() == ton::WalletV3::get_init_code()->get_hash());

  auto fift_output = fift::mem_run_fift(load_source("smartcont/new-wallet-v3.fif"), {"aba", "0", "239"}).move_as_ok();

  auto new_wallet_pk = fift_output.source_lookup.read_file("new-wallet.pk").move_as_ok().data;
  auto new_wallet_query = fift_output.source_lookup.read_file("new-wallet-query.boc").move_as_ok().data;
  auto new_wallet_addr = fift_output.source_lookup.read_file("new-wallet.addr").move_as_ok().data;

  td::Ed25519::PrivateKey priv_key{td::SecureString{new_wallet_pk}};
  auto pub_key = priv_key.get_public_key().move_as_ok();
  auto init_state = ton::WalletV3::get_init_state(pub_key, 239);
  auto init_message = ton::WalletV3::get_init_message(priv_key, 239);
  auto address = ton::GenericAccount::get_address(0, init_state);

  CHECK(address.addr.as_slice() == td::Slice(new_wallet_addr).substr(0, 32));

  td::Ref<vm::Cell> res = ton::GenericAccount::create_ext_message(address, init_state, init_message);

  LOG(ERROR) << "-------";
  vm::load_cell_slice(res).print_rec(std::cerr);
  LOG(ERROR) << "-------";
  vm::load_cell_slice(vm::std_boc_deserialize(new_wallet_query).move_as_ok()).print_rec(std::cerr);
  CHECK(vm::std_boc_deserialize(new_wallet_query).move_as_ok()->get_hash() == res->get_hash());

  fift_output.source_lookup.write_file("/main.fif", load_source("smartcont/wallet-v3.fif")).ensure();
  class ZeroOsTime : public fift::OsTime {
   public:
    td::uint32 now() override {
      return 0;
    }
  };
  fift_output.source_lookup.set_os_time(std::make_unique<ZeroOsTime>());
  auto dest = block::StdAddress::parse("Ef9Tj6fMJP+OqhAdhKXxq36DL+HYSzCc3+9O6UNzqsgPfYFX").move_as_ok();
  fift_output =
      fift::mem_run_fift(std::move(fift_output.source_lookup),
                         {"aba", "new-wallet", "Ef9Tj6fMJP+OqhAdhKXxq36DL+HYSzCc3+9O6UNzqsgPfYFX", "239", "123", "321"})
          .move_as_ok();
  auto wallet_query = fift_output.source_lookup.read_file("wallet-query.boc").move_as_ok().data;
  auto gift_message = ton::GenericAccount::create_ext_message(
      address, {}, ton::WalletV3::make_a_gift_message(priv_key, 239, 123, 60, 321000000000ll, "TESTv3", dest));
  LOG(ERROR) << "-------";
  vm::load_cell_slice(gift_message).print_rec(std::cerr);
  LOG(ERROR) << "-------";
  vm::load_cell_slice(vm::std_boc_deserialize(wallet_query).move_as_ok()).print_rec(std::cerr);
  CHECK(vm::std_boc_deserialize(wallet_query).move_as_ok()->get_hash() == gift_message->get_hash());
}

TEST(Tonlib, TestGiver) {
  auto address =
      block::StdAddress::parse("-1:60c04141c6a7b96d68615e7a91d265ad0f3a9a922e9ae9c901d4fa83f5d3c0d0").move_as_ok();
  LOG(ERROR) << address.bounceable;
  auto fift_output = fift::mem_run_fift(load_source("smartcont/testgiver.fif"),
                                        {"aba", address.rserialize(), "0", "6.666", "wallet-query"})
                         .move_as_ok();
  LOG(ERROR) << fift_output.output;

  auto wallet_query = fift_output.source_lookup.read_file("wallet-query.boc").move_as_ok().data;

  auto res = ton::GenericAccount::create_ext_message(
      ton::TestGiver::address(), {},
      ton::TestGiver::make_a_gift_message(0, 1000000000ll * 6666 / 1000, "GIFT", address));
  vm::CellSlice(vm::NoVm(), res).print_rec(std::cerr);
  CHECK(vm::std_boc_deserialize(wallet_query).move_as_ok()->get_hash() == res->get_hash());
}

class SimpleWallet : public ton::SmartContract {
 public:
  SimpleWallet(State state) : SmartContract(std::move(state)) {
  }

  const State& get_state() const {
    return state_;
  }
  SimpleWallet* make_copy() const override {
    return new SimpleWallet{state_};
  }

  static td::Ref<SimpleWallet> create_empty() {
    return td::Ref<SimpleWallet>(true, State{ton::SmartContractCode::simple_wallet_ext(), {}});
  }
  static td::Ref<SimpleWallet> create(td::Ref<vm::Cell> data) {
    return td::Ref<SimpleWallet>(true, State{ton::SmartContractCode::simple_wallet_ext(), std::move(data)});
  }
  static td::Ref<SimpleWallet> create_fast(td::Ref<vm::Cell> data) {
    return td::Ref<SimpleWallet>(true, State{ton::SmartContractCode::simple_wallet(), std::move(data)});
  }

  td::int32 seqno() const {
    auto res = run_get_method("seqno");
    return res.stack.write().pop_smallint_range(1000000000);
  }

  td::Ref<vm::Cell> create_init_state(td::Slice public_key) const {
    td::RefInt256 pk{true};
    pk.write().import_bytes(public_key.ubegin(), public_key.size(), false);
    auto res = run_get_method("create_init_state", {pk});
    return res.stack.write().pop_cell();
  }

  td::Ref<vm::Cell> prepare_send_message(td::Ref<vm::Cell> msg, td::int8 mode = 3) const {
    auto res = run_get_method("prepare_send_message", {td::make_refint(mode), msg});
    return res.stack.write().pop_cell();
  }

  static td::Ref<vm::Cell> sign_message(vm::Ref<vm::Cell> body, const td::Ed25519::PrivateKey& pk) {
    auto signature = pk.sign(body->get_hash().as_slice()).move_as_ok();
    return vm::CellBuilder().store_bytes(signature.as_slice()).append_cellslice(vm::load_cell_slice(body)).finalize();
  }
};

TEST(Smartcon, Simple) {
  auto private_key = td::Ed25519::generate_private_key().move_as_ok();
  auto public_key = private_key.get_public_key().move_as_ok().as_octet_string();

  auto w_lib = SimpleWallet::create_empty();
  auto init_data = w_lib->create_init_state(public_key);

  auto w = SimpleWallet::create(init_data);
  LOG(ERROR) << w->code_size();
  auto fw = SimpleWallet::create_fast(init_data);
  LOG(ERROR) << fw->code_size();
  LOG(ERROR) << w->seqno();

  for (int i = 0; i < 20; i++) {
    auto msg = w->sign_message(w->prepare_send_message(vm::CellBuilder().finalize()), private_key);
    w.write().send_external_message(msg);
    fw.write().send_external_message(msg);
  }
  ASSERT_EQ(20, w->seqno());
  CHECK(w->get_state().data->get_hash() == fw->get_state().data->get_hash());
}

namespace std {  // ouch
bool operator<(const ton::MultisigWallet::Mask& a, const ton::MultisigWallet::Mask& b) {
  for (size_t i = 0; i < a.size(); i++) {
    if (a[i] != b[i]) {
      return a[i] < b[i];
    }
  }
  return false;
}
}  // namespace std

TEST(Smartcon, Multisig) {
  auto ms_lib = ton::MultisigWallet::create();

  int n = 100;
  int k = 99;
  std::vector<td::Ed25519::PrivateKey> keys;
  for (int i = 0; i < n; i++) {
    keys.push_back(td::Ed25519::generate_private_key().move_as_ok());
  }
  auto init_state = ms_lib->create_init_data(
      td::transform(keys, [](auto& key) { return key.get_public_key().ok().as_octet_string(); }), k);
  auto ms = ton::MultisigWallet::create(init_state);

  td::uint64 query_id = 123;
  ton::MultisigWallet::QueryBuilder qb(query_id, vm::CellBuilder().finalize());
  // first empty query (init)
  CHECK(ms.write().send_external_message(vm::CellBuilder().finalize()).code == 0);
  // first empty query
  CHECK(ms.write().send_external_message(vm::CellBuilder().finalize()).code > 0);

  for (int i = 0; i < 10; i++) {
    auto query = qb.create(i, keys[i]);
    auto ans = ms.write().send_external_message(query);
    LOG(INFO) << "CODE: " << ans.code;
    LOG(INFO) << "GAS: " << ans.gas_used;
  }
  for (int i = 0; i + 1 < 50; i++) {
    qb.sign(i, keys[i]);
  }
  auto query = qb.create(49, keys[49]);

  CHECK(ms->get_n_k() == std::make_pair(n, k));
  auto ans = ms.write().send_external_message(query);
  LOG(INFO) << "CODE: " << ans.code;
  LOG(INFO) << "GAS: " << ans.gas_used;
  CHECK(ans.success);
  ASSERT_EQ(0, ms->processed(query_id));
  CHECK(ms.write().send_external_message(query).code > 0);
  ASSERT_EQ(0, ms->processed(query_id));

  {
    ton::MultisigWallet::QueryBuilder qb(query_id, vm::CellBuilder().finalize());
    for (int i = 50; i + 1 < 100; i++) {
      qb.sign(i, keys[i]);
    }
    query = qb.create(99, keys[99]);
  }

  ans = ms.write().send_external_message(query);
  LOG(INFO) << "CODE: " << ans.code;
  LOG(INFO) << "GAS: " << ans.gas_used;
  ASSERT_EQ(-1, ms->processed(query_id));
}

TEST(Smartcont, MultisigStress) {
  int n = 10;
  int k = 5;

  std::vector<td::Ed25519::PrivateKey> keys;
  for (int i = 0; i < n; i++) {
    keys.push_back(td::Ed25519::generate_private_key().move_as_ok());
  }
  auto public_keys = td::transform(keys, [](auto& key) { return key.get_public_key().ok().as_octet_string(); });
  auto ms_lib = ton::MultisigWallet::create();
  auto init_state_old =
      ms_lib->create_init_data_fast(td::transform(public_keys, [](auto& key) { return key.copy(); }), k);
  auto init_state = ms_lib->create_init_data(td::transform(public_keys, [](auto& key) { return key.copy(); }), k);
  CHECK(init_state_old->get_hash() == init_state->get_hash());
  auto ms = ton::MultisigWallet::create(init_state);
  CHECK(ms->get_public_keys() == public_keys);

  td::int32 now = 0;
  td::int32 qid = 1;
  using Mask = std::bitset<128>;
  struct Query {
    td::int64 id;
    td::Ref<vm::Cell> message;
    Mask signed_mask;
  };

  std::vector<Query> queries;
  int max_queries = 300;

  td::Random::Xorshift128plus rnd(123);

  auto new_query = [&] {
    if (qid > max_queries) {
      return;
    }
    Query query;
    query.id = (static_cast<td::int64>(now) << 32) | qid++;
    query.message = vm::CellBuilder().store_bytes(td::rand_string('a', 'z', rnd.fast(0, 100))).finalize();
    queries.push_back(std::move(query));
  };

  auto verify = [&] {
    auto messages = ms->get_unsigned_messaged();
    std::set<std::tuple<td::uint64, ton::MultisigWallet::Mask, std::string>> s;
    std::set<std::tuple<td::uint64, ton::MultisigWallet::Mask, std::string>> t;

    for (auto& m : messages) {
      auto x = std::make_tuple(m.query_id, m.signed_by, m.message->get_hash().as_slice().str());
      s.insert(std::move(x));
    }

    for (auto& q : queries) {
      if (q.signed_mask.none()) {
        continue;
      }
      t.insert(std::make_tuple(q.id, q.signed_mask, q.message->get_hash().as_slice().str()));
    }
    ASSERT_EQ(t.size(), s.size());
    CHECK(s == t);
  };

  auto sign_query = [&](Query& query, Mask mask) {
    auto qb = ton::MultisigWallet::QueryBuilder(query.id, query.message);
    int first_i = -1;
    for (int i = 0; i < (int)mask.size(); i++) {
      if (mask.test(i)) {
        if (first_i == -1) {
          first_i = i;
        } else {
          qb.sign(i, keys[i]);
        }
      }
    }
    return qb.create(first_i, keys[first_i]);
  };

  auto send_signature = [&](td::Ref<vm::Cell> query) {
    auto ans = ms.write().send_external_message(query);
    LOG(ERROR) << "GAS: " << ans.gas_used;
    return ans.code == 0;
  };

  auto is_ready = [&](Query& query) { return ms->processed(query.id) == -1; };

  auto gen_query = [&](Query& query) {
    auto x = rnd.fast(1, n);
    Mask mask;
    for (int t = 0; t < x; t++) {
      mask.set(rnd() % n);
    }

    auto signature = sign_query(query, mask);
    return std::make_pair(signature, mask);
  };

  auto rand_sign = [&] {
    if (queries.empty()) {
      return;
    }

    size_t query_i = rnd() % queries.size();
    auto& query = queries[query_i];

    Mask mask;
    td::Ref<vm::Cell> signature;
    std::tie(signature, mask) = gen_query(query);
    if (false && rnd() % 6 == 0) {
      Mask mask2;
      td::Ref<vm::Cell> signature2;
      std::tie(signature2, mask2) = gen_query(query);
      for (int i = 0; i < (int)keys.size(); i++) {
        if (mask[i]) {
          signature = ms->merge_queries(std::move(signature), std::move(signature2));
          break;
        }
        if (mask2[i]) {
          signature = ms->merge_queries(std::move(signature2), std::move(signature));
          break;
        }
      }
      //signature = ms->merge_queries(std::move(signature), std::move(signature2));
      mask |= mask2;
    }

    int got_cnt;
    Mask got_cnt_bits;
    std::tie(got_cnt, got_cnt_bits) = ms->check_query_signatures(signature);
    CHECK(mask == got_cnt_bits);

    bool expect_ok = true;
    {
      auto new_mask = mask & ~query.signed_mask;
      expect_ok &= new_mask.any();
      for (size_t i = 0; i < mask.size(); i++) {
        if (mask[i]) {
          expect_ok &= new_mask[i];
          break;
        }
      }
    }

    ASSERT_EQ(expect_ok, send_signature(std::move(signature)));
    if (expect_ok) {
      query.signed_mask |= mask;
    }
    auto expect_is_ready = query.signed_mask.count() >= (size_t)k;
    auto state = ms->get_query_state(query.id);
    ASSERT_EQ(expect_is_ready, (state.state == ton::MultisigWallet::QueryState::Sent));
    CHECK(expect_is_ready || state.mask == query.signed_mask);
    ASSERT_EQ(expect_is_ready, is_ready(query));
    if (expect_is_ready) {
      queries.erase(queries.begin() + query_i);
    }
    verify();
  };
  td::RandomSteps steps({{rand_sign, 2}, {new_query, 1}});
  while (!queries.empty() || qid <= max_queries) {
    steps.step(rnd);
    //LOG(ERROR) << ms->data_size();
  }
  LOG(INFO) << "Final code size: " << ms->code_size();
  LOG(INFO) << "Final data size: " << ms->data_size();
}
