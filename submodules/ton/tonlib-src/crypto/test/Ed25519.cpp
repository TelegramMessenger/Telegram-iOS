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
#include "crypto/Ed25519.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/tests.h"
#include "td/utils/JsonBuilder.h"

#include "wycheproof.h"

#include <string>
#include <utility>

unsigned char fixed_privkey[32] = "abacabadabacabaeabacabadabacaba";
unsigned char fixed_pubkey[32] = {0x6f, 0x9e, 0x5b, 0xde, 0xce, 0x87, 0x21, 0xeb, 0x57, 0x37, 0xfb,
                                  0xb5, 0x92, 0x28, 0xba, 0x07, 0xf7, 0x88, 0x0f, 0x73, 0xce, 0x5b,
                                  0xfa, 0xa1, 0xb7, 0x15, 0x73, 0x03, 0xd4, 0x20, 0x1e, 0x74};

unsigned char rfc8032_secret_key1[32] = {0x9d, 0x61, 0xb1, 0x9d, 0xef, 0xfd, 0x5a, 0x60, 0xba, 0x84, 0x4a,
                                         0xf4, 0x92, 0xec, 0x2c, 0xc4, 0x44, 0x49, 0xc5, 0x69, 0x7b, 0x32,
                                         0x69, 0x19, 0x70, 0x3b, 0xac, 0x03, 0x1c, 0xae, 0x7f, 0x60};

unsigned char rfc8032_public_key1[32] = {0xd7, 0x5a, 0x98, 0x01, 0x82, 0xb1, 0x0a, 0xb7, 0xd5, 0x4b, 0xfe,
                                         0xd3, 0xc9, 0x64, 0x07, 0x3a, 0x0e, 0xe1, 0x72, 0xf3, 0xda, 0xa6,
                                         0x23, 0x25, 0xaf, 0x02, 0x1a, 0x68, 0xf7, 0x07, 0x51, 0x1a};

unsigned char rfc8032_signature1[64] = {
    0xe5, 0x56, 0x43, 0x00, 0xc3, 0x60, 0xac, 0x72, 0x90, 0x86, 0xe2, 0xcc, 0x80, 0x6e, 0x82, 0x8a,
    0x84, 0x87, 0x7f, 0x1e, 0xb8, 0xe5, 0xd9, 0x74, 0xd8, 0x73, 0xe0, 0x65, 0x22, 0x49, 0x01, 0x55,
    0x5f, 0xb8, 0x82, 0x15, 0x90, 0xa3, 0x3b, 0xac, 0xc6, 0x1e, 0x39, 0x70, 0x1c, 0xf9, 0xb4, 0x6b,
    0xd2, 0x5b, 0xf5, 0xf0, 0x59, 0x5b, 0xbe, 0x24, 0x65, 0x51, 0x41, 0x43, 0x8e, 0x7a, 0x10, 0x0b,
};

unsigned char rfc8032_secret_key2[32] = {
    0xc5, 0xaa, 0x8d, 0xf4, 0x3f, 0x9f, 0x83, 0x7b, 0xed, 0xb7, 0x44, 0x2f, 0x31, 0xdc, 0xb7, 0xb1,
    0x66, 0xd3, 0x85, 0x35, 0x07, 0x6f, 0x09, 0x4b, 0x85, 0xce, 0x3a, 0x2e, 0x0b, 0x44, 0x58, 0xf7,
};

unsigned char rfc8032_public_key2[32] = {
    0xfc, 0x51, 0xcd, 0x8e, 0x62, 0x18, 0xa1, 0xa3, 0x8d, 0xa4, 0x7e, 0xd0, 0x02, 0x30, 0xf0, 0x58,
    0x08, 0x16, 0xed, 0x13, 0xba, 0x33, 0x03, 0xac, 0x5d, 0xeb, 0x91, 0x15, 0x48, 0x90, 0x80, 0x25,
};

unsigned char rfc8032_message2[2] = {0xaf, 0x82};

unsigned char rfc8032_signature2[64] = {
    0x62, 0x91, 0xd6, 0x57, 0xde, 0xec, 0x24, 0x02, 0x48, 0x27, 0xe6, 0x9c, 0x3a, 0xbe, 0x01, 0xa3,
    0x0c, 0xe5, 0x48, 0xa2, 0x84, 0x74, 0x3a, 0x44, 0x5e, 0x36, 0x80, 0xd7, 0xdb, 0x5a, 0xc3, 0xac,
    0x18, 0xff, 0x9b, 0x53, 0x8d, 0x16, 0xf2, 0x90, 0xae, 0x67, 0xf7, 0x60, 0x98, 0x4d, 0xc6, 0x59,
    0x4a, 0x7c, 0x15, 0xe9, 0x71, 0x6e, 0xd2, 0x8d, 0xc0, 0x27, 0xbe, 0xce, 0xea, 0x1e, 0xc4, 0x0a,
};

TEST(Crypto, ed25519) {
  td::Ed25519::generate_private_key().ensure();

  auto PK1 = td::Ed25519::generate_private_key().move_as_ok();
  auto PK2 = td::Ed25519::PrivateKey(td::SecureString(td::Slice(fixed_privkey, 32)));
  LOG(ERROR) << "PK1 = " << td::buffer_to_hex(PK1.as_octet_string());
  auto priv2_export = PK2.as_octet_string();
  LOG(ERROR) << "PK2 = " << td::buffer_to_hex(priv2_export);
  auto PK3 = td::Ed25519::PrivateKey(std::move(priv2_export));

  auto PubK1 = PK1.get_public_key().move_as_ok();
  LOG(ERROR) << "PubK1 = " << td::buffer_to_hex(PubK1.as_octet_string());
  auto PubK2 = PK2.get_public_key().move_as_ok();
  LOG(ERROR) << "PubK2 = " << td::buffer_to_hex(PubK2.as_octet_string());
  CHECK(td::Slice(fixed_pubkey, 32) == PubK2.as_octet_string());
  auto PubK3 = PK3.get_public_key().move_as_ok();
  LOG(ERROR) << "PubK3 = " << td::buffer_to_hex(PubK3.as_octet_string());
  CHECK(td::Slice(fixed_pubkey, 32) == PubK3.as_octet_string());
  LOG(ERROR) << "PubK1 = " << td::buffer_to_hex(PubK1.as_octet_string());

  auto secret22 = td::Ed25519::compute_shared_secret(PubK3, PK2).move_as_ok();
  LOG(ERROR) << "secret(PK2, PubK2)=" << td::buffer_to_hex(secret22);

  auto secret12 = td::Ed25519::compute_shared_secret(PubK3, PK1).move_as_ok();
  LOG(ERROR) << "secret(PK1, PubK2)=" << td::buffer_to_hex(secret12);
  auto secret21 = td::Ed25519::compute_shared_secret(PubK1, PK2).move_as_ok();
  LOG(ERROR) << "secret(PK2, PubK1)=" << td::buffer_to_hex(secret21);
  CHECK(secret12 == secret21);

  //  for (int i = 0; i < 1000; i++) {
  //    td::Ed25519::compute_shared_secret(PubK2, PK1).ensure();
  //    td::Ed25519::compute_shared_secret(PubK1, PK2).ensure();
  //  }

  auto signature = PK1.sign("abc").move_as_ok();
  LOG(ERROR) << "PK1.signature=" << td::buffer_to_hex(signature);

  // signature[63] ^= 1;
  auto ok = PubK1.verify_signature("abc", signature);
  LOG(ERROR) << "PubK1.check_signature=" << ok;
  ok.ensure();

  td::Ed25519::PrivateKey PK4(td::SecureString(td::Slice(rfc8032_secret_key1, 32)));
  auto PubK4 = PK4.get_public_key().move_as_ok();
  LOG(ERROR) << "PK4.private_key = " << td::buffer_to_hex(PK4.as_octet_string());
  LOG(ERROR) << "PK4.public_key = " << td::buffer_to_hex(PubK4.as_octet_string());
  CHECK(td::Slice(rfc8032_public_key1, 32) == PubK4.as_octet_string());
  signature = PK4.sign("").move_as_ok();
  LOG(ERROR) << "PK4.signature('') = " << td::buffer_to_hex(signature);
  CHECK(signature == td::Slice(rfc8032_signature1, 64));

  td::Ed25519::PrivateKey PK5(td::SecureString(td::Slice(rfc8032_secret_key2, 32)));
  auto PubK5 = PK5.get_public_key().move_as_ok();
  LOG(ERROR) << "PK5.private_key = " << td::buffer_to_hex(PK5.as_octet_string());
  LOG(ERROR) << "PK5.public_key = " << td::buffer_to_hex(PubK5.as_octet_string());
  CHECK(td::Slice(rfc8032_public_key2, 32) == PubK5.as_octet_string());
  signature = PK5.sign(td::Slice(rfc8032_message2, 2)).move_as_ok();
  LOG(ERROR) << "PK5.signature('') = " << td::buffer_to_hex(signature);
  CHECK(signature == td::Slice(rfc8032_signature2, 64));

  //  for (int i = 0; i < 100000; i++) {
  //    PK5.sign(td::Slice(rfc8032_message2, 2));
  //  }
  //  for (int i = 0; i < 1000; i++) {
  //    PubK5.verify_signature(td::Slice(rfc8032_message2, 2), signature).ensure();
  //  }

  /*
  unsigned char temp_pubkey[32];
  crypto::Ed25519::TempKeyGenerator TKG; // use one generator a lot of times

  TKG.create_temp_shared_secret(temp_pubkey, secret12, PubK1, (const unsigned char*)"abc", 3);
  LOG(ERROR) << "secret12=" << td::buffer_to_hex(secret12) << "; temp_pubkey=" << td::buffer_to_hex(temp_pubkey);

  PK1.compute_temp_shared_secret(secret21, temp_pubkey);
  LOG(ERROR) << "secret21=" << td::buffer_to_hex(secret21);
  assert(!std::memcmp(secret12, secret21, 32));
*/
}

TEST(Crypto, wycheproof) {
  std::vector<std::pair<std::string, std::string>> bad_tests;
  auto json_str = wycheproof_ed25519();
  auto value = td::json_decode(json_str).move_as_ok();
  auto &root = value.get_object();
  auto test_groups_o = get_json_object_field(root, "testGroups", td::JsonValue::Type::Array, false).move_as_ok();
  auto &test_groups = test_groups_o.get_array();
  auto from_hexc = [](char c) {
    if (c >= '0' && c <= '9') {
      return c - '0';
    }
    return c - 'a' + 10;
  };
  auto from_hex = [&](td::Slice s) {
    CHECK(s.size() % 2 == 0);
    std::string res(s.size() / 2, 0);
    for (size_t i = 0; i < s.size(); i += 2) {
      res[i / 2] = char(from_hexc(s[i]) * 16 + from_hexc(s[i + 1]));
    }
    return res;
  };
  for (auto &test_o : test_groups) {
    auto &test = test_o.get_object();
    auto key_o = get_json_object_field(test, "key", td::JsonValue::Type::Object, false).move_as_ok();
    auto sk_str = td::get_json_object_string_field(key_o.get_object(), "sk", false).move_as_ok();
    auto pk_str = td::get_json_object_string_field(key_o.get_object(), "pk", false).move_as_ok();
    auto pk = td::Ed25519::PublicKey(td::SecureString(from_hex(pk_str)));
    auto sk = td::Ed25519::PrivateKey(td::SecureString(from_hex(sk_str)));
    CHECK(sk.get_public_key().move_as_ok().as_octet_string().as_slice() == pk.as_octet_string().as_slice());

    //auto key =
    //td::Ed25519::PrivateKey::from_pem(
    //td::SecureString(td::get_json_object_string_field(test, "keyPem", false).move_as_ok()), td::SecureString())
    //.move_as_ok();

    auto tests_o = get_json_object_field(test, "tests", td::JsonValue::Type::Array, false).move_as_ok();
    auto &tests = tests_o.get_array();
    for (auto &test_o : tests) {
      auto &test = test_o.get_object();
      auto id = td::get_json_object_string_field(test, "tcId", false).move_as_ok();
      auto comment = td::get_json_object_string_field(test, "comment", false).move_as_ok();
      auto sig = from_hex(td::get_json_object_string_field(test, "sig", false).move_as_ok());
      auto msg = from_hex(td::get_json_object_string_field(test, "msg", false).move_as_ok());
      auto result = td::get_json_object_string_field(test, "result", false).move_as_ok();
      auto has_result = pk.verify_signature(msg, sig).is_ok() ? "valid" : "invalid";
      if (result != has_result) {
        bad_tests.push_back({id, comment});
      }
    }
  }
  if (bad_tests.empty()) {
    return;
  }
  LOG(ERROR) << "FAILED: " << td::format::as_array(bad_tests);
}

TEST(Crypto, almost_zero) {
  td::SecureString pub(32);
  td::SecureString sig(64);
  td::SecureString msg(1);

  pub.as_mutable_slice().ubegin()[31] = static_cast<unsigned char>(128);
  for (td::int32 j = 0; j < 256; j++) {
    msg.as_mutable_slice()[0] = (char)j;
    if (td::Ed25519::PublicKey(pub.copy()).verify_signature(msg, sig).is_ok()) {
      LOG(ERROR) << "FAILED: " << j;
      break;
    }
  }
}
