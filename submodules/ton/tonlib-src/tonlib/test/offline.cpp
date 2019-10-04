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

#include "fift/Fift.h"
#include "fift/words.h"
#include "fift/utils.h"

#include "block/block.h"
#include "block/block-auto.h"

#include "vm/cells.h"
#include "vm/boc.h"
#include "vm/cells/MerkleProof.h"

#include "tonlib/CellString.h"
#include "tonlib/utils.h"
#include "tonlib/TestGiver.h"
#include "tonlib/TestWallet.h"
#include "tonlib/Wallet.h"
#include "tonlib/GenericAccount.h"
#include "tonlib/TonlibClient.h"
#include "tonlib/Client.h"

#include "auto/tl/ton_api_json.h"
#include "auto/tl/tonlib_api_json.h"

#include "td/utils/benchmark.h"
#include "td/utils/filesystem.h"
#include "td/utils/optional.h"
#include "td/utils/port/path.h"
#include "td/utils/PathView.h"
#include "td/utils/tests.h"

// KeyManager
#include "tonlib/keys/bip39.h"
#include "tonlib/keys/DecryptedKey.h"
#include "tonlib/keys/EncryptedKey.h"
#include "tonlib/keys/Mnemonic.h"
#include "tonlib/keys/SimpleEncryption.h"

TEST(Tonlib, CellString) {
  for (unsigned size :
       {0, 1, 7, 8, 35, 127, 128, 255, 256, (int)vm::CellString::max_bytes - 1, (int)vm::CellString::max_bytes}) {
    auto str = td::rand_string('a', 'z', size);
    for (unsigned head : {0, 1, 7, 8, 127, 35 * 8, 127 * 8, 1023, 1024}) {
      vm::CellBuilder cb;
      vm::CellString::store(cb, str, head).ensure();
      auto cs = vm::load_cell_slice(cb.finalize());
      auto got_str = vm::CellString::load(cs, head).move_as_ok();
      ASSERT_EQ(str, got_str);
    }
  }
};

using namespace tonlib;

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

TEST(Tonlib, TestWallet) {
  LOG(ERROR) << td::base64_encode(std_boc_serialize(get_test_wallet_source()).move_as_ok());
  CHECK(get_test_wallet_source()->get_hash() == TestWallet::get_init_code()->get_hash());
  auto fift_output = fift::mem_run_fift(load_source("smartcont/new-wallet.fif"), {"aba", "0"}).move_as_ok();

  auto new_wallet_pk = fift_output.source_lookup.read_file("new-wallet.pk").move_as_ok().data;
  auto new_wallet_query = fift_output.source_lookup.read_file("new-wallet-query.boc").move_as_ok().data;
  auto new_wallet_addr = fift_output.source_lookup.read_file("new-wallet.addr").move_as_ok().data;

  td::Ed25519::PrivateKey priv_key{td::SecureString{new_wallet_pk}};
  auto pub_key = priv_key.get_public_key().move_as_ok();
  auto init_state = TestWallet::get_init_state(pub_key);
  auto init_message = TestWallet::get_init_message(priv_key);
  auto address = GenericAccount::get_address(0, init_state);

  CHECK(address.addr.as_slice() == td::Slice(new_wallet_addr).substr(0, 32));

  td::Ref<vm::Cell> res = GenericAccount::create_ext_message(address, init_state, init_message);

  LOG(ERROR) << "-------";
  vm::load_cell_slice(res).print_rec(std::cerr);
  LOG(ERROR) << "-------";
  vm::load_cell_slice(vm::std_boc_deserialize(new_wallet_query).move_as_ok()).print_rec(std::cerr);
  CHECK(vm::std_boc_deserialize(new_wallet_query).move_as_ok()->get_hash() == res->get_hash());

  fift_output.source_lookup.write_file("/main.fif", load_source("smartcont/wallet.fif")).ensure();
  auto dest = block::StdAddress::parse("Ef9Tj6fMJP+OqhAdhKXxq36DL+HYSzCc3+9O6UNzqsgPfYFX").move_as_ok();
  fift_output =
      fift::mem_run_fift(std::move(fift_output.source_lookup),
                         {"aba", "new-wallet", "Ef9Tj6fMJP+OqhAdhKXxq36DL+HYSzCc3+9O6UNzqsgPfYFX", "123", "321"})
          .move_as_ok();
  auto wallet_query = fift_output.source_lookup.read_file("wallet-query.boc").move_as_ok().data;
  auto gift_message = GenericAccount::create_ext_message(
      address, {}, TestWallet::make_a_gift_message(priv_key, 123, 321000000000ll, "TEST", dest));
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
  CHECK(get_wallet_source()->get_hash() == Wallet::get_init_code()->get_hash());

  auto fift_output = fift::mem_run_fift(load_source("smartcont/new-wallet-v2.fif"), {"aba", "0"}).move_as_ok();

  auto new_wallet_pk = fift_output.source_lookup.read_file("new-wallet.pk").move_as_ok().data;
  auto new_wallet_query = fift_output.source_lookup.read_file("new-wallet-query.boc").move_as_ok().data;
  auto new_wallet_addr = fift_output.source_lookup.read_file("new-wallet.addr").move_as_ok().data;

  td::Ed25519::PrivateKey priv_key{td::SecureString{new_wallet_pk}};
  auto pub_key = priv_key.get_public_key().move_as_ok();
  auto init_state = Wallet::get_init_state(pub_key);
  auto init_message = Wallet::get_init_message(priv_key);
  auto address = GenericAccount::get_address(0, init_state);

  CHECK(address.addr.as_slice() == td::Slice(new_wallet_addr).substr(0, 32));

  td::Ref<vm::Cell> res = GenericAccount::create_ext_message(address, init_state, init_message);

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
  auto gift_message = GenericAccount::create_ext_message(
      address, {}, Wallet::make_a_gift_message(priv_key, 123, 60, 321000000000ll, "TESTv2", dest));
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

  auto res = GenericAccount::create_ext_message(
      TestGiver::address(), {}, TestGiver::make_a_gift_message(0, 1000000000ll * 6666 / 1000, "GIFT", address));
  vm::CellSlice(vm::NoVm(), res).print_rec(std::cerr);
  CHECK(vm::std_boc_deserialize(wallet_query).move_as_ok()->get_hash() == res->get_hash());
}
TEST(Tonlib, PublicKey) {
  block::PublicKey::parse("pubjns2gp7DGCnEH7EOWeCnb6Lw1akm538YYaz6sdLVHfRB2").ensure_error();
  auto key = block::PublicKey::parse("Pubjns2gp7DGCnEH7EOWeCnb6Lw1akm538YYaz6sdLVHfRB2").move_as_ok();
  CHECK(td::buffer_to_hex(key.key) == "3EE9DC0A7A0B6CA01770CE34698792BD8ECB53A6949BFD6C81B6E3CA475B74D7");
  CHECK(key.serialize() == "Pubjns2gp7DGCnEH7EOWeCnb6Lw1akm538YYaz6sdLVHfRB2");
}

TEST(Tonlib, Address) {
  auto a = block::StdAddress::parse("-1:538fa7cc24ff8eaa101d84a5f1ab7e832fe1d84b309cdfef4ee94373aac80f7d").move_as_ok();
  auto b = block::StdAddress::parse("Ef9Tj6fMJP+OqhAdhKXxq36DL+HYSzCc3+9O6UNzqsgPfYFX").move_as_ok();
  auto c = block::StdAddress::parse("Ef9Tj6fMJP-OqhAdhKXxq36DL-HYSzCc3-9O6UNzqsgPfYFX").move_as_ok();
  CHECK(a == b);
  CHECK(a == c);
  CHECK(block::StdAddress::parse("Ef9Tj6fMJp-OqhAdhKXxq36DL-HYSzCc3-9O6UNzqsgPfYFX").is_error());
  CHECK(block::StdAddress::parse("Ef9Tj6fMJp+OqhAdhKXxq36DL+HYSzCc3+9O6UNzqsgPfYFX").is_error());
  CHECK(block::StdAddress::parse(a.rserialize()).move_as_ok() == a);
}

static auto sync_send = [](auto &client, auto query) {
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

TEST(Tonlib, InitClose) {
  using tonlib_api::make_object;
  auto cfg = [](auto str) { return make_object<tonlib_api::config>(str, "", false, false); };
  auto dir = [](auto str) { return make_object<tonlib_api::keyStoreTypeDirectory>(str); };
  {
    Client client;
    sync_send(client, make_object<tonlib_api::close>()).ensure();
    sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(nullptr, dir("."))))
        .ensure_error();
  }
  {
    Client client;
    sync_send(client, make_object<tonlib_api::init>(nullptr)).ensure_error();
    sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(cfg("fdajkfldsjkafld"), dir("."))))
        .ensure_error();
    sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(nullptr, dir("fdhskfds"))))
        .ensure_error();
    sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(nullptr, dir(".")))).ensure();
    sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(nullptr, dir("."))))
        .ensure_error();

    td::Slice bad_config = R"abc(
{
  "@type": "config.global",
  "liteclients": [ ]
}
)abc";

    sync_send(client, make_object<tonlib_api::options_setConfig>(cfg(bad_config.str()))).ensure_error();
    sync_send(client, make_object<tonlib_api::testGiver_getAccountState>()).ensure_error();
    sync_send(client, make_object<tonlib_api::close>()).ensure();
    sync_send(client, make_object<tonlib_api::close>()).ensure_error();
    sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(nullptr, dir("."))))
        .ensure_error();
  }
}

TEST(Tonlib, SimpleEncryption) {
  std::string secret = "secret";
  {
    std::string data = "some private data";
    std::string wrong_secret = "wrong secret";
    auto encrypted_data = SimpleEncryption::encrypt_data(data, secret);
    LOG(ERROR) << encrypted_data.size();
    auto decrypted_data = SimpleEncryption::decrypt_data(encrypted_data, secret).move_as_ok();
    CHECK(data == decrypted_data);
    SimpleEncryption::decrypt_data(encrypted_data, wrong_secret).ensure_error();
    SimpleEncryption::decrypt_data("", secret).ensure_error();
    SimpleEncryption::decrypt_data(std::string(32, 'a'), secret).ensure_error();
    SimpleEncryption::decrypt_data(std::string(33, 'a'), secret).ensure_error();
    SimpleEncryption::decrypt_data(std::string(64, 'a'), secret).ensure_error();
    SimpleEncryption::decrypt_data(std::string(128, 'a'), secret).ensure_error();
  }

  for (size_t i = 0; i < 255; i++) {
    auto data = td::rand_string('a', 'z', static_cast<int>(i));
    auto encrypted_data = SimpleEncryption::encrypt_data(data, secret);
    auto decrypted_data = SimpleEncryption::decrypt_data(encrypted_data, secret).move_as_ok();
    CHECK(data == decrypted_data);
  }
}

class MnemonicBench : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "mnemonic is_password_seed";
  }
  void start_up() override {
    Mnemonic::Options options;
    options.password = td::SecureString("qwerty");
    mnemonic_ = Mnemonic::create_new(std::move(options)).move_as_ok();
  }
  void run(int n) override {
    int x = 0;
    for (int i = 0; i < n; i++) {
      x += mnemonic_.value().is_password_seed();
    }
    td::do_not_optimize_away(x);
  }

  td::optional<Mnemonic> mnemonic_;
};

TEST(Tonlib, Mnemonic) {
  td::bench(MnemonicBench());
  //for (int i = 0; i < 20; i++) {
  //td::PerfWarningTimer perf("Mnemonic::create", 0.01);
  //Mnemonic::Options options;
  //options.password = td::SecureString("qwerty");
  //Mnemonic::create_new(std::move(options)).move_as_ok();
  //}
  // FIXME
  //auto tmp = std::vector<td::SecureString>{"hello", "world"};
  //CHECK(tmp[0].as_slice() == "hello");
  auto a = Mnemonic::create(td::SecureString(" Hello, . $^\n# World!   "), td::SecureString("cucumber")).move_as_ok();
  auto get_word_list = [] {
    std::vector<td::SecureString> words;
    words.emplace_back("hello");
    words.emplace_back("world");
    return words;
  };
  auto b = Mnemonic::create(get_word_list(), td::SecureString("cucumber")).move_as_ok();
  CHECK(a.get_words() == b.get_words());
  CHECK(a.get_words() == get_word_list());

  Mnemonic::Options options;
  options.password = td::SecureString("qwerty");
  auto password = options.password.copy();
  auto c = Mnemonic::create_new(std::move(options)).move_as_ok();
  auto d = Mnemonic::create(c.get_words(), std::move(password)).move_as_ok();
  CHECK(c.to_private_key().as_octet_string() == d.to_private_key().as_octet_string());
}

TEST(Tonlib, Keys) {
  auto a = Mnemonic::create(td::SecureString(" Hello, . $^\n# World!   "), td::SecureString("cucumber")).move_as_ok();
  DecryptedKey decrypted_key(std::move(a));
  EncryptedKey encrypted_key = decrypted_key.encrypt("qwerty");
  auto other_decrypted_key = encrypted_key.decrypt("qwerty").move_as_ok();
  encrypted_key.decrypt("abcde").ensure_error();
  CHECK(decrypted_key.mnemonic_words == other_decrypted_key.mnemonic_words);
  CHECK(decrypted_key.private_key.as_octet_string() == other_decrypted_key.private_key.as_octet_string());
}

TEST(Tonlib, ParseAddres) {
  using tonlib_api::make_object;
  Client client;

  // init
  sync_send(client, make_object<tonlib_api::init>(
                        make_object<tonlib_api::options>(nullptr, make_object<tonlib_api::keyStoreTypeDirectory>("."))))
      .ensure();

  sync_send(client, make_object<tonlib_api::unpackAccountAddress>("hello")).ensure_error();
  auto addr =
      sync_send(client,
                make_object<tonlib_api::unpackAccountAddress>("Ef9Tj6fMJP-OqhAdhKXxq36DL-HYSzCc3-9O6UNzqsgPfYFX"))
          .move_as_ok();
  ASSERT_EQ(-1, addr->workchain_id_);
  ASSERT_EQ(true, addr->bounceable_);
  ASSERT_EQ(false, addr->testnet_);

  auto addr_str = sync_send(client, make_object<tonlib_api::packAccountAddress>(std::move(addr))).move_as_ok();
  ASSERT_EQ("Ef9Tj6fMJP-OqhAdhKXxq36DL-HYSzCc3-9O6UNzqsgPfYFX", addr_str->account_address_);
}

TEST(Tonlib, KeysApi) {
  using tonlib_api::make_object;
  Client client;

  // init
  sync_send(client, make_object<tonlib_api::init>(
                        make_object<tonlib_api::options>(nullptr, make_object<tonlib_api::keyStoreTypeDirectory>("."))))
      .ensure();
  auto local_password = td::SecureString("local password");
  auto mnemonic_password = td::SecureString("mnemonic password");
  {
    auto key = sync_send(client, make_object<tonlib_api::createNewKey>(local_password.copy(), td::SecureString{},
                                                                       td::SecureString{}))
                   .move_as_ok();
  }

  //createNewKey local_password:bytes mnemonic_password:bytes = Key;
  auto key = sync_send(client, make_object<tonlib_api::createNewKey>(local_password.copy(), mnemonic_password.copy(),
                                                                     td::SecureString{}))
                 .move_as_ok();

  sync_send(client, make_object<tonlib_api::exportKey>(make_object<tonlib_api::inputKey>(
                        make_object<tonlib_api::key>(key->public_key_, key->secret_.copy()),
                        td::SecureString("wrong password"))))
      .ensure_error();

  //exportKey input_key:inputKey = ExportedKey;
  auto exported_key =
      sync_send(client,
                make_object<tonlib_api::exportKey>(make_object<tonlib_api::inputKey>(
                    make_object<tonlib_api::key>(key->public_key_, key->secret_.copy()), local_password.copy())))
          .move_as_ok();
  LOG(ERROR) << to_string(exported_key);
  auto copy_word_list = [&] {
    std::vector<td::SecureString> word_list_copy;
    for (auto &w : exported_key->word_list_) {
      word_list_copy.push_back(w.copy());
    }
    return word_list_copy;
  };

  //changeLocalPassword input_key:inputKey new_local_password:bytes = Key;
  auto new_key =
      sync_send(client,
                make_object<tonlib_api::changeLocalPassword>(
                    make_object<tonlib_api::inputKey>(
                        make_object<tonlib_api::key>(key->public_key_, key->secret_.copy()), local_password.copy()),
                    td::SecureString("tmp local password")))
          .move_as_ok();
  sync_send(client,
            make_object<tonlib_api::exportKey>(make_object<tonlib_api::inputKey>(
                make_object<tonlib_api::key>(key->public_key_, new_key->secret_.copy()), local_password.copy())))
      .ensure_error();

  auto exported_key2 = sync_send(client, make_object<tonlib_api::exportKey>(make_object<tonlib_api::inputKey>(
                                             make_object<tonlib_api::key>(key->public_key_, new_key->secret_.copy()),
                                             td::SecureString("tmp local password"))))
                           .move_as_ok();
  CHECK(exported_key2->word_list_ == exported_key->word_list_);

  //importKey local_password:bytes mnemonic_password:bytes exported_key:exportedKey = Key;
  auto new_local_password = td::SecureString("new_local_password");
  // import already existed key
  //sync_send(client, make_object<tonlib_api::importKey>(new_local_password.copy(), mnemonic_password.copy(),
  //make_object<tonlib_api::exportedKey>(copy_word_list())))
  //.ensure_error();

  {
    auto export_password = td::SecureString("export password");
    auto wrong_export_password = td::SecureString("wrong_export password");
    auto exported_encrypted_key =
        sync_send(client, make_object<tonlib_api::exportEncryptedKey>(
                              make_object<tonlib_api::inputKey>(
                                  make_object<tonlib_api::key>(key->public_key_, new_key->secret_.copy()),
                                  td::SecureString("tmp local password")),
                              export_password.copy()))
            .move_as_ok();

    sync_send(client,
              make_object<tonlib_api::deleteKey>(make_object<tonlib_api::key>(key->public_key_, key->secret_.copy())))
        .move_as_ok();

    sync_send(client, make_object<tonlib_api::importEncryptedKey>(
                          new_local_password.copy(), wrong_export_password.copy(),
                          make_object<tonlib_api::exportedEncryptedKey>(exported_encrypted_key->data_.copy())))
        .ensure_error();

    auto imported_encrypted_key =
        sync_send(client, make_object<tonlib_api::importEncryptedKey>(
                              new_local_password.copy(), export_password.copy(),
                              make_object<tonlib_api::exportedEncryptedKey>(exported_encrypted_key->data_.copy())))
            .move_as_ok();
    CHECK(imported_encrypted_key->public_key_ == key->public_key_);
    key = std::move(imported_encrypted_key);
  }

  //deleteKey public_key:bytes = Ok;
  sync_send(client,
            make_object<tonlib_api::deleteKey>(make_object<tonlib_api::key>(key->public_key_, key->secret_.copy())))
      .move_as_ok();

  auto err1 = sync_send(client, make_object<tonlib_api::importKey>(
                                    new_local_password.copy(), td::SecureString("wrong password"),
                                    make_object<tonlib_api::exportedKey>(copy_word_list())))
                  .move_as_error();
  auto err2 =
      sync_send(client, make_object<tonlib_api::importKey>(new_local_password.copy(), td::SecureString(),
                                                           make_object<tonlib_api::exportedKey>(copy_word_list())))
          .move_as_error();
  LOG(INFO) << err1 << " | " << err2;
  auto imported_key =
      sync_send(client, make_object<tonlib_api::importKey>(new_local_password.copy(), mnemonic_password.copy(),
                                                           make_object<tonlib_api::exportedKey>(copy_word_list())))
          .move_as_ok();
  CHECK(imported_key->public_key_ == key->public_key_);
  CHECK(imported_key->secret_ != key->secret_);

  //exportPemKey input_key:inputKey key_password:bytes = ExportedPemKey;
  auto pem_password = td::SecureString("pem password");
  auto r_exported_pem_key = sync_send(
      client,
      make_object<tonlib_api::exportPemKey>(
          make_object<tonlib_api::inputKey>(
              make_object<tonlib_api::key>(key->public_key_, imported_key->secret_.copy()), new_local_password.copy()),
          pem_password.copy()));
  if (r_exported_pem_key.is_error() && r_exported_pem_key.error().message() == "Not supported") {
    return;
  }
  auto exported_pem_key = r_exported_pem_key.move_as_ok();
  LOG(ERROR) << to_string(exported_pem_key);

  //importPemKey exported_key:exportedPemKey key_password:bytes = Key;
  //sync_send(client, make_object<tonlib_api::importPemKey>(
  //new_local_password.copy(), pem_password.copy(),
  //make_object<tonlib_api::exportedPemKey>(exported_pem_key->pem_.copy())))
  //.ensure_error();
  sync_send(client, make_object<tonlib_api::deleteKey>(
                        make_object<tonlib_api::key>(imported_key->public_key_, imported_key->secret_.copy())))
      .move_as_ok();
  sync_send(client, make_object<tonlib_api::importPemKey>(
                        new_local_password.copy(), td::SecureString("wrong pem password"),
                        make_object<tonlib_api::exportedPemKey>(exported_pem_key->pem_.copy())))
      .ensure_error();

  auto new_imported_key = sync_send(client, make_object<tonlib_api::importPemKey>(
                                                new_local_password.copy(), pem_password.copy(),
                                                make_object<tonlib_api::exportedPemKey>(exported_pem_key->pem_.copy())))
                              .move_as_ok();
  CHECK(new_imported_key->public_key_ == key->public_key_);
  CHECK(new_imported_key->secret_ != key->secret_);
}
