//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/BitString.h"
#include "td/e2e/Blockchain.h"
#include "td/e2e/Call.h"
#include "td/e2e/CheckSharedSecret.h"
#include "td/e2e/Container.h"
#include "td/e2e/DecryptedKey.h"
#include "td/e2e/e2e_api.h"
#include "td/e2e/EncryptedKey.h"
#include "td/e2e/EncryptedStorage.h"
#include "td/e2e/MessageEncryption.h"
#include "td/e2e/Mnemonic.h"
#include "td/e2e/QRHandshake.h"
#include "td/e2e/TestBlockchain.h"
#include "td/e2e/Trie.h"

#include "td/telegram/e2e_api.h"

#include "td/utils/base64.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/Ed25519.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/logging.h"
#include "td/utils/overloaded.h"
#include "td/utils/Random.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/simple_tests.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/tests.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/UInt.h"

#include <map>
#include <optional>
#include <utility>

using namespace tde2e_core;

namespace api = tde2e_api;

template <class T>
static td::Status expect_error(td::Result<T> result) {
  if (result.is_ok()) {
    return td::Status::Error("Receive Ok instead of Error");
  }
  return td::Status::OK();
}

S_TEST(MessageEncryption, simple) {
  std::string secret = "secret";
  {
    std::string data = "some private data";
    std::string wrong_secret = "wrong secret";
    auto encrypted_data = MessageEncryption::encrypt_data(data, secret);
    LOG(ERROR) << encrypted_data.size();
    TEST_TRY_RESULT(decrypted_data, MessageEncryption::decrypt_data(encrypted_data, secret));
    TEST_ASSERT_EQ(data, decrypted_data, "decryption");
    TEST_TRY_STATUS(expect_error(MessageEncryption::decrypt_data(encrypted_data, wrong_secret)));
    TEST_TRY_STATUS(expect_error(MessageEncryption::decrypt_data("", secret)));
    TEST_TRY_STATUS(expect_error(MessageEncryption::decrypt_data(std::string(32, 'a'), secret)));
    TEST_TRY_STATUS(expect_error(MessageEncryption::decrypt_data(std::string(33, 'a'), secret)));
    TEST_TRY_STATUS(expect_error(MessageEncryption::decrypt_data(std::string(64, 'a'), secret)));
    TEST_TRY_STATUS(expect_error(MessageEncryption::decrypt_data(std::string(128, 'a'), secret)));
  }

  td::Random::Xorshift128plus rnd(123);
  for (size_t i = 0; i < 255; i++) {
    std::string data;
    for (size_t j = 0; j < i; j++) {
      data += static_cast<char>(rnd.fast('a', 'z'));
    }
    auto encrypted_data = MessageEncryption::encrypt_data(data, secret);
    TEST_TRY_RESULT(decrypted_data, MessageEncryption::decrypt_data(encrypted_data, secret));
    TEST_ASSERT_EQ(data, decrypted_data, "decryption");
  }
  return td::Status::OK();
}

struct E2eHandshakeTest {
  td::Ed25519::PrivateKey alice;
  td::Ed25519::PublicKey alice_public;
  td::Ed25519::PrivateKey bob;
  td::Ed25519::PublicKey bob_public;

  td::SecureString shared_secret;
};

static E2eHandshakeTest gen_test() {
  auto alice = td::Ed25519::generate_private_key().move_as_ok();
  auto alice_public = alice.get_public_key().move_as_ok();
  auto bob = td::Ed25519::generate_private_key().move_as_ok();
  auto bob_public = bob.get_public_key().move_as_ok();
  auto shared_secret = td::Ed25519::compute_shared_secret(alice.get_public_key().move_as_ok(), bob).move_as_ok();
  return E2eHandshakeTest{std::move(alice), std::move(alice_public), std::move(bob), std::move(bob_public),
                          std::move(shared_secret)};
}

static void run_test(const E2eHandshakeTest &test) {
  auto alice_secret =
      td::Ed25519::compute_shared_secret(test.bob.get_public_key().move_as_ok(), test.alice).move_as_ok();
  auto bob_secret = td::Ed25519::compute_shared_secret(test.alice.get_public_key().move_as_ok(), test.bob).move_as_ok();
  CHECK(test.alice.get_public_key().move_as_ok().as_octet_string() == test.alice_public.as_octet_string());
  CHECK(test.bob.get_public_key().move_as_ok().as_octet_string() == test.bob_public.as_octet_string());
  CHECK(alice_secret == bob_secret);
  CHECK(alice_secret == test.shared_secret);
}

static E2eHandshakeTest pregenerated_test() {
  auto alice_public_key_str = td::base64url_decode_secure("RvG0CT5i8D-CYnfhp2akVC1tPRBIw-4X6ZqNBjH-mZI").move_as_ok();
  auto alice_private_key_str = td::base64url_decode_secure("8NZGWKfRCJfiks74RG9_xHmYydarLiRsoq8VcJGPglg").move_as_ok();
  auto bob_public_key_str = td::base64url_decode_secure("1V3BGwmbo-Mwsw7QlWKN4OZFPBP9z9VhFlZKRdzTrGw").move_as_ok();
  auto bob_private_key_str = td::base64url_decode_secure("YMGoowtnZ99roUM2y5JRwiQrwGaNJ-ZRE5boy-l4aHg").move_as_ok();

  auto alice_public_key = td::Ed25519::PublicKey(alice_public_key_str.copy());
  auto alice_private_key = td::Ed25519::PrivateKey(alice_private_key_str.copy());
  auto bob_public_key = td::Ed25519::PublicKey(bob_public_key_str.copy());
  auto bob_private_key = td::Ed25519::PrivateKey(bob_private_key_str.copy());
  auto shared_secret = td::base64url_decode_secure("CU6NsPBw59neM9crFvxKELbtKgAkI7G8tDHsb4CmyVA").move_as_ok();

  return E2eHandshakeTest{std::move(alice_private_key), std::move(alice_public_key), std::move(bob_private_key),
                          std::move(bob_public_key), std::move(shared_secret)};
}

TEST(Handshake, InvalidKeys) {
  auto private_key = td::Ed25519::generate_private_key().move_as_ok();
  auto zero_key = td::Ed25519::PublicKey(td::SecureString(32, 0));
  td::Ed25519::compute_shared_secret(zero_key, private_key).ensure_error();
}

TEST(Handshake, Random) {
  auto test = gen_test();
  run_test(test);
}

TEST(Handshake, Pregenerated) {
  auto test = pregenerated_test();
  run_test(test);
}

TEST(QRHandshake, Basic) {
  td::int64 alice_user_id = 123;
  td::int64 bob_user_id = 321;
  auto alice_private_key = PrivateKey::generate().move_as_ok();
  auto bob_private_key = PrivateKey::generate().move_as_ok();

  auto bob = QRHandshakeBob::create(bob_user_id, bob_private_key);
  auto start = bob.generate_start();  // should be passed via QR
  auto alice =
      QRHandshakeAlice::create(alice_user_id, alice_private_key, bob_user_id, bob_private_key.to_public_key(), start)
          .move_as_ok();
  auto accept = alice.generate_accept();
  auto finish = bob.receive_accept(alice_user_id, alice_private_key.to_public_key(), accept).move_as_ok();
  alice.receive_finish(finish).ensure();
}

TEST(CheckSharedSecret, Basic) {
  auto alice = CheckSharedSecret::create();
  auto bob = CheckSharedSecret::create();

  alice.recive_commit_nonce(bob.commit_nonce()).ensure();
  bob.recive_commit_nonce(alice.commit_nonce()).ensure();

  alice.receive_reveal_nonce(bob.reveal_nonce().move_as_ok()).ensure();
  bob.receive_reveal_nonce(alice.reveal_nonce().move_as_ok()).ensure();

  CHECK(alice.finalize_hash("abc").move_as_ok() == bob.finalize_hash("abc").move_as_ok());
}

// node_type enum

TEST(MiniBlockchain, Basic) {
  auto private_key = PrivateKey::generate().move_as_ok();
  Blockchain remote_blockchain = Blockchain::create_empty();
  Blockchain local_blockchain = Blockchain::create_empty();

  auto block = local_blockchain.set_value(std::string(32, 'a'), "b", private_key);
  remote_blockchain.try_apply_block(block, {}).ensure();
  local_blockchain.try_apply_block(block, {}).ensure();
  block = local_blockchain.set_value(std::string(32, 'b'), "c", private_key);
  remote_blockchain.try_apply_block(block, {}).ensure();
  local_blockchain.try_apply_block(block, {}).ensure();
}

// Example usage
TEST(Tree, BitString) {
  LOG(ERROR) << "BitString count: " << BitString::get_counter_value();
  td::UInt256 hash;
  sha256("hello world", hash.as_mutable_slice());
  BitString s(hash.as_slice());
  for (auto l = 0; l <= 256; l++) {
    for (auto r = l; r <= 256; r++) {
      if (l > r) {
        return;
      }
      auto a = s.substr(l, r - l);
      BitString b;
      auto str = td::serialize(a);
      CHECK(str.size() % 4 == 0);

      b = BitString::fetch_from_network(str).move_as_ok();
      ASSERT_EQ(a, b);
    }
  }
  LOG(ERROR) << "BitString count: " << BitString::get_counter_value();
}

TEST(Tree, SerializeStress) {
  std::string value(32, 'a');
  td::Random::Xorshift128plus rnd(123);
  for (size_t i = 0; i < 10000; i++) {
    size_t n = rnd.fast(0, 20);
    TrieRef root = TrieNode::empty_node();
    for (size_t j = 0; j < n; j++) {
      td::UInt256 hash;
      rnd.bytes(hash.as_mutable_slice());
      root = set(root, hash.as_slice(), td::to_string(j)).move_as_ok();
    }

    auto old_hash = root->hash;
    auto s = TrieNode::serialize_for_network(root).move_as_ok();
    root = TrieNode::fetch_from_network(s).move_as_ok();
    auto new_hash = root->hash;
    CHECK(old_hash == new_hash);

    auto snapshot = TrieNode::serialize_for_snapshot(root, "").move_as_ok();
    auto snapshot_root = TrieNode::fetch_from_snapshot(snapshot).move_as_ok();
    auto snapshot2 = TrieNode::serialize_for_snapshot(snapshot_root, snapshot).move_as_ok();
    CHECK(snapshot == snapshot2);
  }
}

TEST(Tree, BitStringCounter) {
  CHECK(BitString::get_counter_value() == 0);
  {
    BitString bs(1);
    size_t l = 1;
    size_t r = 2;

    auto a = bs.substr(l, r - l);
    auto s = td::serialize(a);
    CHECK(s.size() % 4 == 0);

    BitString b = BitString::fetch_from_network(s).move_as_ok();
    ASSERT_EQ(a, b);
  }
  CHECK(BitString::get_counter_value() == 0);
}

TEST(MerkleTree, Basic) {
  // Build the tree
  TrieRef root = TrieNode::empty_node();
  root = set(root, "apple", "fruit").move_as_ok();
  print_tree(root);
  root = set(root, "application", "software").move_as_ok();
  print_tree(root);
  root = set(root, "banana", "fruit").move_as_ok();
  print_tree(root);

  ASSERT_EQ("fruit", get(root, "apple").move_as_ok());
  ASSERT_EQ("software", get(root, "application").move_as_ok());
  ASSERT_EQ("fruit", get(root, "banana").move_as_ok());

  std::vector<td::Slice> keys = {"apple", "banana"};
  TrieRef pruned_tree = generate_pruned_tree(root, keys).move_as_ok();
  print_tree(pruned_tree);

  ASSERT_EQ("fruit", get(pruned_tree, "apple").move_as_ok());
  ASSERT_EQ("fruit", get(pruned_tree, "banana").move_as_ok());
  get(pruned_tree, "application").ensure_error();

  auto serialized = TrieNode::serialize_for_network(pruned_tree).move_as_ok();
  TrieRef pruned_tree2 = TrieNode::fetch_from_network(serialized).move_as_ok();
  print_tree(pruned_tree2);

  ASSERT_EQ("fruit", get(pruned_tree2, "apple").move_as_ok());
  ASSERT_EQ("fruit", get(pruned_tree2, "banana").move_as_ok());
  get(pruned_tree2, "application").ensure_error();
}

static TrieRef root;
static const int N = 1'000'000;

TEST(Tree, BenchA) {
  LOG(ERROR) << "BitString count: " << BitString::get_counter_value();
  root = TrieNode::empty_node();
  std::string value(32, 'a');
  for (int i = 0; i < N; i++) {
    auto key = value + std::to_string(i);
    td::UInt256 hash;
    sha256(key, hash.as_mutable_slice());
    root = set(std::move(root), hash.as_slice().str(), value).move_as_ok();
  }
  LOG(ERROR) << "BitString count: " << BitString::get_counter_value();
}

static std::string serialized_root;

TEST(Tree, Serialize) {
  serialized_root = TrieNode::serialize_for_network(root).move_as_ok();
}

TEST(Tree, Clear) {
  root = {};
  LOG(ERROR) << "BitString count: " << BitString::get_counter_value();
}

TEST(Tree, Deserialize) {
  root = TrieNode::fetch_from_network(serialized_root).move_as_ok();
  LOG(ERROR) << "BitString count: " << BitString::get_counter_value();
}

TEST(Tree, BenchAPruned) {
  std::string value(32, 'a');
  size_t step = 1;
  std::vector<td::UInt256> keys_str(step);
  std::vector<td::Slice> keys(step);
  for (size_t i = 0; i < 1000000; i += step) {
    for (size_t j = 0; j < step; j++) {
      auto key = value + std::to_string((i + j) % N);
      sha256(key, keys_str[j].as_mutable_slice());
      keys[j] = keys_str[j].as_slice();
    }
    //auto node = generate_pruned_tree(TrieNode::fetch_from_snapshot(serialized_root).move_as_ok(), keys, serialized_root).move_as_ok();
    auto node = generate_pruned_tree(root, keys, serialized_root).move_as_ok();
    auto x = TrieNode::serialize_for_network(node).move_as_ok();
    LOG_IF(ERROR, i == 0) << x.size() << " bytes serialized";
  }
}

TEST(Tree, BenchAA) {
  std::string value(32, 'a');
  for (int i = 0; i < N; i++) {
    auto key = value + std::to_string(i);
    td::UInt256 hash;
    sha256(key, hash.as_mutable_slice());
    CHECK(value == get(root, hash.as_slice().str()).move_as_ok());
  }
}
TEST(Tree, BenchAAA) {
  std::string value(32, 'a');
  for (int i = 0; i < N; i++) {
    auto key = value + std::to_string(i);
    td::UInt256 hash;
    sha256(key, hash.as_mutable_slice());
    root = set(std::move(root), hash.as_slice().str(), value).move_as_ok();
  }
}

static td::FlatHashMap<std::string, std::string> map;

TEST(Tree, BenchB) {
  std::string value(32, 'a');
  for (int i = 0; i < N; i++) {
    auto key = value + std::to_string(i);
    td::UInt256 hash;
    sha256(key, hash.as_mutable_slice());
    map.emplace(hash.as_slice().str(), value);
  }
}

TEST(Tree, BenchBB) {
  std::string value(32, 'a');
  for (int i = 0; i < N; i++) {
    auto key = value + std::to_string(i);
    td::UInt256 hash;
    sha256(key, hash.as_mutable_slice());
    CHECK(value == map.find(hash.as_slice().str())->second);
  }
}

TEST(Tree, BenchBBB) {
  std::string value(32, 'a');
  for (int i = 0; i < N; i++) {
    auto key = value + std::to_string(i);
    td::UInt256 hash;
    sha256(key, hash.as_mutable_slice());
    map.emplace(hash.as_slice().str(), value);
  }
}

// TODO: to we need both secret and local password?..
// user_password is known only to user and never stored
// secret used to decrypt the key and should be stored somewhere safe
// encrypted_data could be stored anywhere
//
// Is it too complicated? Is it neccessary to encrypt
static td::Result<EncryptedKey> create_new_encrypted_key(td::Slice user_password) {
  TRY_RESULT(mnemonic, Mnemonic::create_new());
  auto private_key = mnemonic.to_private_key();
  auto decrypted_key = DecryptedKey(mnemonic.get_words(), std::move(private_key));
  return decrypted_key.encrypt(user_password);
}

static td::Result<EncryptedKey> change_user_password(const EncryptedKey &encrypted_key, td::Slice user_password,
                                                     td::Slice new_user_password) {
  TRY_RESULT(decrypted_key, encrypted_key.decrypt(user_password, false));
  return decrypted_key.encrypt(new_user_password);
}

static td::Result<td::SecureString> export_mnemonic(const EncryptedKey &encrypted_key, td::Slice user_password) {
  TRY_RESULT(decrypted_key, encrypted_key.decrypt(user_password, false));
  CHECK(decrypted_key.mnemonic_words.size() == 24);
  size_t length = decrypted_key.mnemonic_words.size() - 1;
  for (auto &word : decrypted_key.mnemonic_words) {
    length += word.size();
  }
  td::SecureString res(length);
  auto dest = res.as_mutable_slice();
  bool is_first = true;
  for (auto &word : decrypted_key.mnemonic_words) {
    if (!is_first) {
      dest[0] = ' ';
      dest.remove_prefix(1);
    } else {
      is_first = false;
    }
    dest.copy_from(word);
    dest.remove_prefix(word.size());
  }
  return res;
}

static td::Result<EncryptedKey> import_mnemonic(td::Slice mnemonic_words, td::Slice user_password) {
  TRY_RESULT(mnemonic, Mnemonic::create(td::SecureString(mnemonic_words), td::SecureString()));
  auto decrypted_key = DecryptedKey(mnemonic);
  return decrypted_key.encrypt(user_password);
}

TEST(E2E, GenerateKeys) {
  // generate key
  auto encrypted_key = create_new_encrypted_key("user_password").move_as_ok();
  change_user_password(encrypted_key, "bad_user_password", "user_password").ensure_error();
  auto new_encrypted_key = change_user_password(encrypted_key, "user_password", "new_password").move_as_ok();
  export_mnemonic(new_encrypted_key, "user_password").ensure_error();
  auto mnemonic = export_mnemonic(new_encrypted_key, "new_password").move_as_ok();
  auto other_encrypted_key = import_mnemonic(mnemonic, "new_password").move_as_ok();
  CHECK(encrypted_key.o_public_key == new_encrypted_key.o_public_key);
}

TEST(E2E_API, Key) {
  using namespace tde2e_api;
  auto alice_pk = key_generate_private_key().value();
  auto bob_pk = key_generate_private_key().value();
  auto carol_pk = key_generate_private_key().value();

  auto secret = key_from_bytes("secret").value();
  auto bad_secret = key_from_bytes("bad_secret").value();

  auto encrypted_alice_pk = key_to_encrypted_private_key(alice_pk, secret).value();
  key_from_encrypted_private_key(encrypted_alice_pk, bad_secret).error();
  auto alice_pk_copy = key_from_encrypted_private_key(encrypted_alice_pk, secret).value();

  ASSERT_EQ(key_to_public_key(alice_pk).value(), key_to_public_key(alice_pk_copy).value());
  auto alice_PK = key_from_public_key(key_to_public_key(alice_pk).value()).value();
  auto bob_PK = key_from_public_key(key_to_public_key(bob_pk).value()).value();
  auto carol_PK = key_from_public_key(key_to_public_key(carol_pk).value()).value();

  key_destroy(alice_pk_copy).value();
  key_to_public_key(alice_pk_copy).error();

  auto words = key_to_words(alice_pk).value();
  ASSERT_EQ(alice_pk, key_from_words(std::move(words)).value());

  auto shared_key_ab = key_from_ecdh(alice_pk, bob_PK).value();
  auto shared_key_ba = key_from_ecdh(bob_pk, alice_PK).value();
  auto shared_key_ac = key_from_ecdh(alice_pk, carol_PK).value();

  auto encrypted = encrypt_message_for_many({shared_key_ab, shared_key_ac}, "very secret message").value();
  ASSERT_EQ(
      "very secret message",
      decrypt_message_for_many(shared_key_ba, encrypted.encrypted_headers[0], encrypted.encrypted_message).value());
  decrypt_message_for_many(shared_key_ac, encrypted.encrypted_headers[0], encrypted.encrypted_message).error();

  auto encrypted2 = encrypt_message_for_one(shared_key_ab, "very secret message").value();
  ASSERT_EQ("very secret message", decrypt_message_for_one(shared_key_ba, encrypted2).value());
  decrypt_message_for_one(shared_key_ac, encrypted2).error();
  key_destroy_all();
}

TEST(E2E_API, HandshakeVerify) {
  using namespace tde2e_api;
  auto bob_id = 123;
  auto alice_id = 321;
  auto alice_pk = key_generate_private_key().value();
  auto bob_pk = key_generate_private_key().value();

  // Bob creates handshake
  auto bob_handshake_id = handshake_create_for_bob(bob_id, bob_pk).value();
  // Start is shown on QR
  auto start = handshake_bob_send_start(bob_handshake_id).value();

  // Alice received qr, received information about qr from server and create handshake
  auto alice_handshake_id =
      handshake_create_for_alice(alice_id, alice_pk, bob_id, key_to_public_key(bob_pk).value(), start).value();
  auto accept = handshake_alice_send_accept(alice_handshake_id).value();
  // Alice knows shared key. She knows that it is known to author of QR code, but not necessary to bob_pk owner.
  auto shared_a = handshake_get_shared_key_id(alice_handshake_id).value();

  // Bob receives accept and generates finish
  auto finish =
      handshake_bob_receive_accept_send_finish(bob_handshake_id, alice_id, key_to_public_key(alice_pk).value(), accept)
          .value();
  // At this point Bob "verified" Alice
  // Bob knows shared key
  auto shared_b = handshake_get_shared_key_id(bob_handshake_id).value();

  // Alice receives and verifies finish
  handshake_alice_receive_finish(alice_handshake_id, finish).value();
  // At this point Alice "verified" Bob

  ASSERT_EQ(shared_a, shared_b);
  handshake_destroy_all();
}

TEST(E2E_API, HandshakeLogin) {
  using namespace tde2e_api;

  auto alice_id = 321;
  auto alice_pk = key_generate_private_key().value();

  auto bob_login_id = login_create_for_bob().value();
  auto start = login_bob_send_start(bob_login_id).value();
  auto alice_data = login_create_for_alice(alice_id, alice_pk, start).value();
  auto received_alice_pk =
      login_finish_for_bob(bob_login_id, alice_id, key_to_public_key(alice_pk).value(), alice_data).value();
  ASSERT_EQ(key_to_public_key(alice_pk).value(), key_to_public_key(received_alice_pk).value());
  login_destroy_all();
}

TEST(Container, Basic) {
  using namespace tde2e_api;
  Container<TypeInfo<int, false, false>, TypeInfo<std::string, false, true>, TypeInfo<std::vector<int>, true, false>,
            TypeInfo<std::vector<std::string>, true, true>>
      container;

  auto id_int = container.emplace<int>(1);
  td::UInt256 hash;
  hash.as_mutable_slice().fill(7);
  auto id_string = container.try_emplace<std::string>(hash, "hello");
  auto id_string_2 = container
                         .try_build<std::string>(hash,
                                                 []() -> td::Result<std::string> {
                                                   UNREACHABLE();
                                                   return "...";
                                                 })
                         .move_as_ok();
  ASSERT_EQ(id_string, id_string_2);
  auto id_vec_int = container
                        .try_build<std::vector<int>>({},
                                                     []() -> td::Result<std::vector<int>> {
                                                       return std::vector<int>{1, 2, 3, 4};
                                                     })
                        .move_as_ok();
  auto id_vec_string = container.emplace<std::vector<std::string>>(std::vector<std::string>{"a", "b", "c"});

  container.get_shared<int>(id_int).ensure();
  container.get_shared<std::string>(id_string).ensure();
  container.get_unique<std::vector<int>>(id_vec_int).ensure();
  container.get_unique<std::vector<std::string>>(id_vec_string).ensure();

  container.get_shared<int>(id_string).ensure_error();
  container.get_shared<std::string>(id_int).ensure_error();
  container.get_unique<std::vector<int>>(id_vec_string).ensure_error();
  container.get_unique<std::vector<std::string>>(id_vec_int).ensure_error();
}

struct BaselineBlockchainState {
  std::map<std::string, std::string> key_value_state;
  GroupStateRef group_state;
  GroupSharedKeyRef shared_key;
  td::int32 height{-1};
  std::string get_value(const std::string &key) const {
    auto it = key_value_state.find(key);
    if (it == key_value_state.end()) {
      return "";
    }
    return it->second;
  }
  void apply_changes(const std::vector<Change> &changes) {
    for (const auto &change_v : changes) {
      std::visit(td::overloaded([&](const ChangeNoop &) {},
                                [&](const ChangeSetValue &change) { key_value_state[change.key] = change.value; },
                                [&](const ChangeSetGroupState &change) { group_state = change.group_state; },
                                [&](const ChangeSetSharedKey &change) { shared_key = change.shared_key; }),
                 change_v.value);
    }
    height++;
  }
};

S_TEST(E2E_Blockchain, Base) {
  TEST_TRY_RESULT(pk, PrivateKey::generate());
  TEST_TRY_RESULT(pk2, PrivateKey::generate());

  BlockchainTester tester;

  auto to_hash = [](td::Slice key) {
    std::string res(32, 0);
    td::sha256(key, res);
    return res;
  };

  auto a = to_hash("a");
  auto b = to_hash("b");

  TEST_ASSERT_EQ("", tester.get_value(a), "empty blockchain");
  TEST_ASSERT_EQ("", tester.get_value(b), "empty blockchain");
  using BB = BlockBuilder;

  TEST_TRY_STATUS(
      tester.expect_ok({BB::make_set_value(a, "hello a"),
                        BB::make_group_change({{2, GroupParticipantFlags::AllPermissions, pk2.to_public_key()}})},
                       pk2));
  TEST_ASSERT_EQ("hello a", tester.get_value(a), "hello a");
  TEST_TRY_STATUS(tester.expect_error(E::Any, {BB::make_set_value(a, "hello b")}, pk));
  TEST_TRY_STATUS(tester.expect_ok({BB::make_set_value(a, "hello b")}, pk2));
  TEST_ASSERT_EQ("hello b", tester.get_value(a), "...");
  tester.reindex();
  TEST_ASSERT_EQ("hello b", tester.get_value(a), "...");
  return td::Status::OK();
}

S_TEST(E2E_Blockchain, Stress) {
  BlockchainTester tester;
  TEST_TRY_RESULT(pk, PrivateKey::generate());

  td::Random::Xorshift128plus rnd(123);
  auto gen_string = [&](auto from, auto to, auto size) {
    std::string s(size, 0);
    for (auto &c : s) {
      c = static_cast<char>(rnd.fast(from, to));
    }
    return s;
  };

  auto to_hash = [](td::Slice key) {
    std::string res(32, 0);
    td::sha256(key, res);
    return res;
  };
  auto gen_key = [&] {
    auto len = rnd.fast(1, 15);
    return to_hash(gen_string('a', 'b', len));
  };

  auto gen_value = [&] {
    std::string res(rnd.fast(1, 64), 0);
    rnd.bytes(res);
    return res;
  };

  auto gen_query = [&] {
    std::vector<std::string> keys(rnd.fast(1, 1));
    for (auto &key : keys) {
      key = gen_key();
    };
    return keys;
  };

  auto gen_changes = [&] {
    auto n = rnd.fast(1, 2);
    std::vector<Change> changes;
    changes.reserve(n);
    for (int i = 0; i < n; i++) {
      changes.push_back(BlockBuilder::make_set_value(gen_key(), gen_value()));
    }
    return changes;
  };

  auto run_get = [&] {
    auto keys = gen_query();
    TEST_TRY_STATUS(tester.get_values(keys));
    return td::Status::OK();
  };

  auto run_set = [&] {
    auto changes = gen_changes();
    TEST_TRY_STATUS(tester.apply(changes, pk));
    return td::Status::OK();
  };

  auto reindex = [&] {
    tester.reindex();
    return td::Status::OK();
  };

  td::RandomSteps steps{{{run_set, 10}, {run_get, 100}, {reindex, 1}}};
  for (size_t i = 0; i < 10000; i++) {
    steps.step(rnd);
  }
  return td::Status::OK();
}

using namespace tde2e_api;
S_TEST(E2E_Blockchain, Call) {
  SET_VERBOSITY_LEVEL(3);
  CallTester ct;
  TEST_TRY_STATUS(ct.start_call({0, 1, 2}));
  TEST_TRY_STATUS(ct.check_shared_key());
  TEST_TRY_STATUS(ct.check_emoji_hash());
  TEST_TRY_STATUS(ct.update_call(0, {0, 3, 4, 5}));
  TEST_TRY_STATUS(ct.check_shared_key());
  TEST_TRY_STATUS(ct.check_emoji_hash());
  return td::Status::OK();
}

TEST(Call, Basic_API) {
  using namespace tde2e_api;
  auto F = [](Result<std::string> block) -> Result<std::string> {
    if (block.is_ok()) {
      return Blockchain::from_local_to_server(block.value());
    }
    return block;
  };

  auto key0 = key_generate_temporary_private_key().value();
  auto pkey0 = key_from_public_key(key_to_public_key(key0).value()).value();
  auto key1 = key_generate_temporary_private_key().value();
  auto pkey1 = key_from_public_key(key_to_public_key(key1).value()).value();
  auto key2 = key_generate_temporary_private_key().value();
  auto pkey2 = key_from_public_key(key_to_public_key(key2).value()).value();
  auto key3 = key_generate_temporary_private_key().value();
  auto pkey3 = key_from_public_key(key_to_public_key(key3).value()).value();

  auto zero_block = F(call_create_zero_block(key0, CallState{0, {CallParticipant{-1, pkey0, 3}}})).value();

  auto call1 = call_create(-1, key0, zero_block).value();
  auto block0 = F(call_create_self_add_block(key1, zero_block, CallParticipant{1, pkey1, 3})).value();
  call1 = call_create(1, key1, block0).value();

  auto block1 = F(call_create_self_add_block(key2, block0, CallParticipant{2, pkey2, 3})).value();
  call_apply_block(call1, block1).value();
  auto call2 = call_create(2, key2, block1).value();
  ASSERT_EQ(call_get_verification_words(call2).value().words, call_get_verification_words(call1).value().words);

  auto block2 = F(call_create_change_state_block(
                      call2, CallState{0, {CallParticipant{2, pkey2, 3}, CallParticipant{3, pkey3, 3}}}))
                    .value();
  call_describe_block(block2).value();
  auto call3 = call_create(3, key3, block2).value();

  call_apply_block(call2, block2).value();
  CHECK(!call_apply_block(call1, block2).is_ok());

  // call2 and call3 verification
  ASSERT_EQ(call_get_verification_words(call2).value().words, call_get_verification_words(call3).value().words);

  auto block31 = F(call_create_change_state_block(
                       call2, CallState{0, {CallParticipant{2, pkey2, 3}, CallParticipant{3, pkey3, 3}}}))
                     .value();

  call_apply_block(call2, block31).value();
  auto commit2 = F(call_pull_outbound_messages(call2).value().at(0)).value();

  call_describe_message(commit2).value();

  call_receive_inbound_message(call2, commit2).value();
  call_receive_inbound_message(call3, commit2).value();

  call_apply_block(call3, block31).value();
  auto commit3 = F(call_pull_outbound_messages(call3).value().at(0)).value();

  CHECK(commit2 != commit3);
  call_receive_inbound_message(call2, commit3).value();
  call_receive_inbound_message(call3, commit3).value();

  auto reveal2 = F(call_pull_outbound_messages(call2).value().at(0)).value();
  auto reveal3 = F(call_pull_outbound_messages(call3).value().at(0)).value();
  call_receive_inbound_message(call2, reveal2).value();
  call_receive_inbound_message(call2, reveal3).value();
  call_receive_inbound_message(call3, reveal2).value();
  call_receive_inbound_message(call3, reveal3).value();

  ASSERT_EQ(call_get_verification_state(call2).value().emoji_hash.value(),
            call_get_verification_state(call3).value().emoji_hash.value());

  auto e = call_encrypt(call2, 1, "hello").value();
  auto e2 = call_encrypt(call2, 1, "hello").value();
  CHECK(e != "hello");
  LOG(ERROR) << e.size();
  ASSERT_TRUE(!call_decrypt(call2, 2, 1, e).is_ok());
  // ASSERT_TRUE(!call_decrypt(call3, 2, 2, e).is_ok()); Uncomment if we will validate channel_id
  ASSERT_TRUE(!call_decrypt(call3, 1, 1, e).is_ok());
  ASSERT_EQ("hello", call_decrypt(call3, 2, 1, e).value());
  ASSERT_TRUE(!call_decrypt(call3, 2, 1, e).is_ok());

  auto block3 = F(call_create_change_state_block(
                      call2, CallState{0, {CallParticipant{2, pkey2, 3}, CallParticipant{3, pkey3, 3}}}))
                    .value();
  call_apply_block(call3, block3).value();
  ASSERT_TRUE(!call_decrypt(call3, 2, 1, e).is_ok());
  ASSERT_EQ("hello", call_decrypt(call3, 2, 1, e2).value());
  ASSERT_TRUE(call_decrypt(call2, 3, 1, call_encrypt(call3, 1, "bye").value()).is_ok());

  LOG(ERROR) << call_describe(call1).value();
  LOG(ERROR) << call_describe(call2).value();

  key_destroy_all();
  call_destroy_all();
}

TEST(State, Basic) {
  SET_VERBOSITY_LEVEL(3);
  using namespace tde2e_api;

  ServerBlockchain kv_server;
  auto pk = key_generate_private_key().value();
  auto storage = storage_create(pk, {}).value();

  auto contact_pk = key_generate_private_key().value();
  auto contact_public_key = key_from_public_key(key_to_public_key(contact_pk).value()).value();

  storage_get_contact(storage, contact_public_key);
  storage_get_contact(storage, contact_public_key).error();
  Entry<Name> entry_name;
  entry_name.value = Name{"A", "B"};
  auto signed_entry_name = storage_sign_entry(contact_pk, entry_name).value();
  auto update_id = storage_update_contact(storage, contact_public_key, signed_entry_name).value();
  (void)update_id;

  auto load_proofs = [&] {
    auto keys = storage_get_blockchain_state(storage).value().required_proofs;
    auto proof = kv_server.get_proof(storage_blockchain_height(storage).value(), keys).move_as_ok();
    storage_blockchain_add_proof(storage, proof, keys).value();
  };
  auto update_blockchain = [&] {
    auto block = storage_get_blockchain_state(storage).value().next_suggested_block;
    if (block.empty()) {
      return;
    }
    kv_server.try_apply_block(block).ensure();
    storage_blockchain_apply_block(storage, block).value();
  };

  load_proofs();

  Value value;
  value.o_name = entry_name;

  ASSERT_EQ(std::optional<Value>(), storage_get_contact(storage, contact_public_key).value());
  ASSERT_EQ(value, storage_get_contact_optimistic(storage, contact_public_key).value());

  update_blockchain();
  ASSERT_EQ(value, storage_get_contact(storage, contact_public_key).value());
}

#if TG_ENGINE
int main() {
  td::TestsRunner::get_default().run_all();
  _Exit(0);
}
#endif
