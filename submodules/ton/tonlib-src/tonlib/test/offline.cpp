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

#include "block/block.h"
#include "block/block-auto.h"
#include "block/mc-config.h"

#include "vm/cells.h"
#include "vm/boc.h"
#include "vm/cells/CellString.h"

#include "tonlib/utils.h"
#include "tonlib/TonlibClient.h"
#include "tonlib/Client.h"

#include "auto/tl/ton_api_json.h"
#include "auto/tl/tonlib_api_json.h"

#include "td/utils/benchmark.h"
#include "td/utils/filesystem.h"
#include "td/utils/optional.h"
#include "td/utils/overloaded.h"
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

TEST(Tonlib, Text) {
  for (unsigned size :
       {0, 1, 7, 8, 35, 127, 128, 255, 256, (int)vm::CellText::max_bytes - 1, (int)vm::CellText::max_bytes}) {
    auto str = td::rand_string('a', 'z', size);
    for (unsigned head : {16, 17, 127, 35 * 8, 127 * 8, 1023, 1024}) {
      vm::CellBuilder cb;
      vm::CellText::store(cb, str, head).ensure();
      auto cs = vm::load_cell_slice(cb.finalize());
      auto cs2 = cs;
      cs.print_rec(std::cerr);
      CHECK(block::gen::t_Text.validate_exact_upto(1024, cs2));
      auto got_str = vm::CellText::load(cs).move_as_ok();
      ASSERT_EQ(str, got_str);
    }
  }
};

using namespace tonlib;

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
    auto address = sync_send(client, make_object<tonlib_api::getAccountAddress>(
                                         make_object<tonlib_api::testGiver_initialAccountState>(), 0))
                       .move_as_ok();
    sync_send(client, make_object<tonlib_api::getAccountState>(std::move(address))).ensure_error();
    sync_send(client, make_object<tonlib_api::close>()).ensure();
    sync_send(client, make_object<tonlib_api::close>()).ensure_error();
    sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(nullptr, dir("."))))
        .ensure_error();
  }
}

td::Slice to_data(const td::SecureString &str) {
  return str.as_slice();
}
td::Slice to_data(const tonlib::SimpleEncryptionV2::Decrypted &str) {
  return str.data.as_slice();
}

template <class Encryption>
void test_encryption() {
  std::string secret = "secret";
  {
    std::string data = "some private data";
    std::string wrong_secret = "wrong secret";
    auto encrypted_data = Encryption::encrypt_data(data, secret);
    LOG(ERROR) << encrypted_data.size();
    auto decrypted_data = Encryption::decrypt_data(encrypted_data, secret).move_as_ok();
    CHECK(data == to_data(decrypted_data));
    Encryption::decrypt_data(encrypted_data, wrong_secret).ensure_error();
    Encryption::decrypt_data("", secret).ensure_error();
    Encryption::decrypt_data(std::string(32, 'a'), secret).ensure_error();
    Encryption::decrypt_data(std::string(33, 'a'), secret).ensure_error();
    Encryption::decrypt_data(std::string(64, 'a'), secret).ensure_error();
    Encryption::decrypt_data(std::string(128, 'a'), secret).ensure_error();
  }

  for (size_t i = 0; i < 255; i++) {
    auto data = td::rand_string('a', 'z', static_cast<int>(i));
    auto encrypted_data = Encryption::encrypt_data(data, secret);
    auto decrypted_data = Encryption::decrypt_data(encrypted_data, secret).move_as_ok();
    CHECK(data == to_data(decrypted_data));
  }
}
TEST(Tonlib, SimpleEncryption) {
  test_encryption<SimpleEncryption>();
}

TEST(Tonlib, SimpleEncryptionV2) {
  test_encryption<SimpleEncryptionV2>();
}

TEST(Tonlib, SimpleEncryptionAsym) {
  auto private_key = td::Ed25519::generate_private_key().move_as_ok();
  auto public_key = private_key.get_public_key().move_as_ok();
  auto other_private_key = td::Ed25519::generate_private_key().move_as_ok();
  auto other_public_key = private_key.get_public_key().move_as_ok();
  auto wrong_private_key = td::Ed25519::generate_private_key().move_as_ok();
  {
    std::string data = "some private data";
    auto encrypted_data = SimpleEncryptionV2::encrypt_data(data, public_key, other_private_key).move_as_ok();
    LOG(ERROR) << encrypted_data.size();
    auto decrypted_data = SimpleEncryptionV2::decrypt_data(encrypted_data, private_key).move_as_ok();
    CHECK(data == decrypted_data.data);
    auto decrypted_data2 = SimpleEncryptionV2::decrypt_data(encrypted_data, other_private_key).move_as_ok();
    CHECK(data == decrypted_data2.data);

    CHECK(decrypted_data.proof == decrypted_data2.proof);

    auto decrypted_data3 =
        SimpleEncryptionV2::decrypt_data_with_proof(encrypted_data, decrypted_data.proof).move_as_ok();
    CHECK(data == decrypted_data3);

    SimpleEncryptionV2::decrypt_data(encrypted_data, wrong_private_key).ensure_error();
    SimpleEncryptionV2::decrypt_data("", private_key).ensure_error();
    SimpleEncryptionV2::decrypt_data(std::string(32, 'a'), private_key).ensure_error();
    SimpleEncryptionV2::decrypt_data(std::string(33, 'a'), private_key).ensure_error();
    SimpleEncryptionV2::decrypt_data(std::string(64, 'a'), private_key).ensure_error();
    SimpleEncryptionV2::decrypt_data(std::string(128, 'a'), private_key).ensure_error();

    SimpleEncryptionV2::decrypt_data_with_proof(encrypted_data, decrypted_data.proof, "bad salt").ensure_error();
  }

  for (size_t i = 0; i < 255; i++) {
    auto data = td::rand_string('a', 'z', static_cast<int>(i));
    auto encrypted_data = SimpleEncryptionV2::encrypt_data(data, public_key, other_private_key).move_as_ok();
    auto decrypted_data = SimpleEncryptionV2::decrypt_data(encrypted_data, private_key).move_as_ok();
    CHECK(data == decrypted_data.data);
    auto decrypted_data2 = SimpleEncryptionV2::decrypt_data(encrypted_data, other_private_key).move_as_ok();
    CHECK(data == decrypted_data2.data);
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
  auto raw = addr->addr_;

  auto addr_str = sync_send(client, make_object<tonlib_api::packAccountAddress>(std::move(addr))).move_as_ok();
  ASSERT_EQ("Ef9Tj6fMJP-OqhAdhKXxq36DL-HYSzCc3-9O6UNzqsgPfYFX", addr_str->account_address_);
  auto addr_str2 = sync_send(client, make_object<tonlib_api::packAccountAddress>(
                                         make_object<tonlib_api::unpackedAccountAddress>(-1, false, false, raw)))
                       .move_as_ok();
  ASSERT_EQ("Uf9Tj6fMJP-OqhAdhKXxq36DL-HYSzCc3-9O6UNzqsgPfdyS", addr_str2->account_address_);
}

TEST(Tonlib, ConfigParseBug) {
  td::Slice literal =
      "D1000000000000006400000000000186A0DE0000000003E8000000000000000F424000000000000F42400000000000002710000000000098"
      "96800000000005F5E100000000003B9ACA00";
  unsigned char buff[128];
  int bits = (int)td::bitstring::parse_bitstring_hex_literal(buff, sizeof(buff), literal.begin(), literal.end());
  CHECK(bits >= 0);
  auto slice = vm::CellBuilder().store_bits(td::ConstBitPtr{buff}, bits).finalize();
  block::Config::do_get_gas_limits_prices(std::move(slice), 21).ensure();
}

TEST(Tonlib, EncryptionApi) {
  using tonlib_api::make_object;
  Client client;

  // init
  sync_send(client, make_object<tonlib_api::init>(
                        make_object<tonlib_api::options>(nullptr, make_object<tonlib_api::keyStoreTypeDirectory>("."))))
      .ensure();

  std::string password = "hello world";
  std::string data = "very secret data";
  auto key = std::move(
      sync_send(client, make_object<tonlib_api::kdf>(td::SecureString(password), td::SecureString("salt"), 100000))
          .move_as_ok()
          ->bytes_);
  auto encrypted = std::move(
      sync_send(client, make_object<tonlib_api::encrypt>(td::SecureString(data), key.copy())).move_as_ok()->bytes_);
  auto decrypted =
      std::move(sync_send(client, make_object<tonlib_api::decrypt>(encrypted.copy(), key.copy())).move_as_ok()->bytes_);
  ASSERT_EQ(data, decrypted);

  auto bad_key = std::move(sync_send(client, make_object<tonlib_api::kdf>(td::SecureString(password + "BAD"),
                                                                          td::SecureString("salt"), 100000))
                               .move_as_ok()
                               ->bytes_);
  sync_send(client, make_object<tonlib_api::decrypt>(encrypted.copy(), bad_key.copy())).ensure_error();
}

TEST(Tonlib, KeysApi) {
  using tonlib_api::make_object;
  Client client;

  td::mkdir("testdir").ignore();
  // init
  sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(
                        nullptr, make_object<tonlib_api::keyStoreTypeDirectory>("testdir"))))
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

  sync_send(client, make_object<tonlib_api::exportKey>(make_object<tonlib_api::inputKeyRegular>(
                        make_object<tonlib_api::key>(key->public_key_, key->secret_.copy()),
                        td::SecureString("wrong password"))))
      .ensure_error();

  //exportKey input_key:inputKeyRegular = ExportedKey;
  auto exported_key =
      sync_send(client,
                make_object<tonlib_api::exportKey>(make_object<tonlib_api::inputKeyRegular>(
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

  //changeLocalPassword input_key:inputKeyRegular new_local_password:bytes = Key;
  auto new_key =
      sync_send(client,
                make_object<tonlib_api::changeLocalPassword>(
                    make_object<tonlib_api::inputKeyRegular>(
                        make_object<tonlib_api::key>(key->public_key_, key->secret_.copy()), local_password.copy()),
                    td::SecureString("tmp local password")))
          .move_as_ok();
  sync_send(client,
            make_object<tonlib_api::exportKey>(make_object<tonlib_api::inputKeyRegular>(
                make_object<tonlib_api::key>(key->public_key_, new_key->secret_.copy()), local_password.copy())))
      .ensure_error();

  auto exported_key2 = sync_send(client, make_object<tonlib_api::exportKey>(make_object<tonlib_api::inputKeyRegular>(
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
                              make_object<tonlib_api::inputKeyRegular>(
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

  //exportPemKey input_key:inputKeyRegular key_password:bytes = ExportedPemKey;
  auto pem_password = td::SecureString("pem password");
  auto r_exported_pem_key = sync_send(
      client,
      make_object<tonlib_api::exportPemKey>(
          make_object<tonlib_api::inputKeyRegular>(
              make_object<tonlib_api::key>(key->public_key_, imported_key->secret_.copy()), new_local_password.copy()),
          pem_password.copy()));
  if (r_exported_pem_key.is_error() && r_exported_pem_key.error().message() == "INTERNAL Not supported") {
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

  auto exported_raw_key =
      sync_send(client, make_object<tonlib_api::exportUnencryptedKey>(make_object<tonlib_api::inputKeyRegular>(
                            make_object<tonlib_api::key>(key->public_key_, new_imported_key->secret_.copy()),
                            new_local_password.copy())))
          .move_as_ok();
  sync_send(client, make_object<tonlib_api::deleteKey>(
                        make_object<tonlib_api::key>(new_imported_key->public_key_, new_imported_key->secret_.copy())))
      .move_as_ok();
  td::Ed25519::PrivateKey pkey(exported_raw_key->data_.copy());
  auto raw_imported_key = sync_send(client, make_object<tonlib_api::importUnencryptedKey>(new_local_password.copy(),
                                                                                          std::move(exported_raw_key)))
                              .move_as_ok();

  CHECK(raw_imported_key->public_key_ == key->public_key_);
  CHECK(raw_imported_key->secret_ != key->secret_);

  auto other_public_key = td::Ed25519::generate_private_key().move_as_ok().get_public_key().move_as_ok();
  std::string text = "hello world";

  std::vector<tonlib_api::object_ptr<tonlib_api::msg_dataEncrypted>> elements;
  td::Slice addr = "Ef9Tj6fMJP-OqhAdhKXxq36DL-HYSzCc3-9O6UNzqsgPfYFX";
  auto encrypted = SimpleEncryptionV2::encrypt_data(text, other_public_key, pkey, addr).move_as_ok().as_slice().str();
  elements.push_back(make_object<tonlib_api::msg_dataEncrypted>(
      make_object<tonlib_api::accountAddress>(addr.str()), make_object<tonlib_api::msg_dataEncryptedText>(encrypted)));

  auto decrypted =
      sync_send(client, make_object<tonlib_api::msg_decrypt>(
                            make_object<tonlib_api::inputKeyRegular>(
                                make_object<tonlib_api::key>(key->public_key_, raw_imported_key->secret_.copy()),
                                new_local_password.copy()),
                            make_object<tonlib_api::msg_dataEncryptedArray>(std::move(elements))))
          .move_as_ok();

  auto proof = decrypted->elements_[0]->proof_;
  downcast_call(*decrypted->elements_[0]->data_,
                td::overloaded([](auto &) { UNREACHABLE(); },
                               [&](tonlib_api::msg_dataDecryptedText &decrypted) { CHECK(decrypted.text_ == text); }));
  auto decrypted2 = sync_send(client, make_object<tonlib_api::msg_decryptWithProof>(
                                          proof, make_object<tonlib_api::msg_dataEncrypted>(
                                                     make_object<tonlib_api::accountAddress>(addr.str()),
                                                     make_object<tonlib_api::msg_dataEncryptedText>(encrypted))))
                        .move_as_ok();
  downcast_call(*decrypted2,
                td::overloaded([](auto &) { UNREACHABLE(); },
                               [&](tonlib_api::msg_dataDecryptedText &decrypted) { CHECK(decrypted.text_ == text); }));
}

TEST(Tonlib, ConfigCache) {
  using tonlib_api::make_object;
  Client client;

  td::rmrf("testdir").ignore();
  td::mkdir("testdir").ignore();
  // init
  sync_send(client, make_object<tonlib_api::init>(make_object<tonlib_api::options>(
                        nullptr, make_object<tonlib_api::keyStoreTypeDirectory>("testdir"))))
      .ensure();

  auto testnet = R"abc({
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
    }
  }
})abc";
  auto testnet2 = R"abc({
  "liteservers": [
  ],
  "validator": {
    "@type": "validator.config.global",
    "zero_state": {
      "workchain": -1,
      "shard": -9223372036854775808,
      "seqno": 0,
      "root_hash": "F6OpKZKqvqeFp6CQmFomXNMfMj2EnaUSOXN+Mh+wVWk=",
      "file_hash": "XplPz01CXAps5qeSWUtxcyBfdAo5zVb1N979KLSKD24="
    }
  }
})abc";
  auto testnet3 = R"abc({
  "liteservers": [
  ],
  "validator": {
    "@type": "validator.config.global",
    "zero_state": {
      "workchain": -1,
      "shard": -9223372036854775808,
      "seqno": 0,
      "root_hash": "ZXSXxDHhTALFxReyTZRd8E4Ya3ySOmpOWAS4rBX9XBY=",
      "file_hash": "eh9yveSz1qMdJ7mOsO+I+H77jkLr9NpAuEkoJuseXBo="
    }
  }
})abc";
  auto bad = R"abc({
  "liteservers": [
  ],
  "validator": {
    "@type": "validator.config.global",
    "zero_state": {
      "workchain": -1,
      "shard": -9223372036854775808,
      "seqno": 0,
      "file_hash": "eh9yveSz1qMdJ7mOsO+I+H77jkLr9NpAuEkoJuseXBo="
    }
  }
})abc";
  sync_send(client,
            make_object<tonlib_api::options_validateConfig>(make_object<tonlib_api::config>(bad, "", true, false)))
      .ensure_error();

  sync_send(client,
            make_object<tonlib_api::options_validateConfig>(make_object<tonlib_api::config>(testnet, "", true, false)))
      .ensure();
  sync_send(client,
            make_object<tonlib_api::options_validateConfig>(make_object<tonlib_api::config>(testnet2, "", true, false)))
      .ensure();
  sync_send(client,
            make_object<tonlib_api::options_validateConfig>(make_object<tonlib_api::config>(testnet3, "", true, false)))
      .ensure();

  sync_send(client, make_object<tonlib_api::options_validateConfig>(
                        make_object<tonlib_api::config>(testnet2, "testnet", true, false)))
      .ensure_error();

  sync_send(client, make_object<tonlib_api::options_setConfig>(
                        make_object<tonlib_api::config>(testnet2, "testnet2", true, false)))
      .ensure();
  sync_send(client, make_object<tonlib_api::options_setConfig>(
                        make_object<tonlib_api::config>(testnet3, "testnet2", true, false)))
      .ensure_error();
}
