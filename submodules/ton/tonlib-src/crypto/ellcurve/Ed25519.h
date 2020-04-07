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
#pragma once
#include "ellcurve/Montgomery.h"
#include "ellcurve/TwEdwards.h"
#include "openssl/digest.hpp"
#include "openssl/rand.hpp"
#include <assert.h>
#include <cstring>

#include "td/utils/buffer.h"

namespace crypto {
namespace Ed25519 {

const int privkey_bytes = 32;
const int pubkey_bytes = 32;
const int sign_bytes = 64;
const int shared_secret_bytes = 32;

class PublicKey {
  enum { pk_empty, pk_xz, pk_init } inited;
  unsigned char pubkey[pubkey_bytes];
  ellcurve::TwEdwardsCurve::SegrePoint PubKey;
  ellcurve::MontgomeryCurve::PointXZ PubKey_xz;

 public:
  PublicKey() : inited(pk_empty), PubKey(ellcurve::Fp25519()), PubKey_xz(ellcurve::Fp25519()) {
  }
  PublicKey(const unsigned char pub_key[pubkey_bytes]);
  PublicKey(td::Slice pub_key) : PublicKey(pub_key.ubegin()) {
    CHECK(pub_key.size() == pubkey_bytes);
  }
  PublicKey(const ellcurve::TwEdwardsCurve::SegrePoint &Pub_Key);

  bool import_public_key(const unsigned char pub_key[pubkey_bytes]);
  bool import_public_key(td::Slice pub_key) {
    CHECK(pub_key.size() == pubkey_bytes);
    return import_public_key(pub_key.ubegin());
  }
  bool import_public_key(const ellcurve::TwEdwardsCurve::SegrePoint &Pub_Key);
  bool export_public_key(unsigned char pubkey_buffer[pubkey_bytes]) const;
  bool export_public_key(td::MutableSlice pubk) const {
    CHECK(pubk.size() == pubkey_bytes);
    return export_public_key(pubk.ubegin());
  }
  bool check_message_signature(const unsigned char signature[sign_bytes], const unsigned char *message,
                               std::size_t msg_size);
  bool check_message_signature(td::Slice signature, td::Slice message) {
    CHECK(signature.size() == sign_bytes);
    return check_message_signature(signature.ubegin(), message.ubegin(), message.size());
  }

  void clear();
  bool ok() const {
    return inited == pk_init;
  }

  const unsigned char *get_pubkey_ptr() const {
    return inited == pk_init ? pubkey : 0;
  }
  const ellcurve::TwEdwardsCurve::SegrePoint &get_point() const {
    return PubKey;
  }
  const ellcurve::MontgomeryCurve::PointXZ &get_point_xz() const {
    return PubKey_xz;
  }
};

class PrivateKey {
 public:
  struct priv_key_no_copy {};
  PrivateKey() : inited(false) {
    memset(privkey, 0, privkey_bytes);
  }
  PrivateKey(const unsigned char pk[privkey_bytes]) : inited(false) {
    memset(privkey, 0, privkey_bytes);
    import_private_key(pk);
  }
  PrivateKey(td::Slice pk) : inited(false) {
    CHECK(pk.size() == privkey_bytes);
    memset(privkey, 0, privkey_bytes);
    import_private_key(pk.ubegin());
  }
  ~PrivateKey() {
    clear();
  }
  bool random_private_key(bool strong = false);
  bool import_private_key(const unsigned char pk[privkey_bytes]);
  bool import_private_key(td::Slice pk) {
    CHECK(pk.size() == privkey_bytes);
    return import_private_key(pk.ubegin());
  }
  bool export_private_key(unsigned char pk[privkey_bytes]) const;  // careful!
  bool export_private_key(td::MutableSlice pk) const {             // careful!
    return export_private_key(pk.ubegin());
  }
  bool export_public_key(unsigned char pubk[pubkey_bytes]) const {
    return PubKey.export_public_key(pubk);
  }
  bool export_public_key(td::MutableSlice pubk) const {
    return PubKey.export_public_key(pubk);
  }
  void clear();
  bool ok() const {
    return inited;
  }

  // used for EdDSA (sign)
  bool sign_message(unsigned char signature[sign_bytes], const unsigned char *message, std::size_t msg_size);
  bool sign_message(td::MutableSlice signature, td::Slice message) {
    CHECK(signature.size() == sign_bytes);
    return sign_message(signature.ubegin(), message.ubegin(), message.size());
  }
  // used for ECDH (encrypt / decrypt)
  bool compute_shared_secret(unsigned char secret[shared_secret_bytes], const PublicKey &Pub);
  bool compute_shared_secret(td::MutableSlice secret, const PublicKey &Pub) {
    CHECK(secret.size() == shared_secret_bytes);
    return compute_shared_secret(secret.ubegin(), Pub);
  }
  // used for EC asymmetric decryption
  bool compute_temp_shared_secret(unsigned char secret[shared_secret_bytes],
                                  const unsigned char temp_pub_key[pubkey_bytes]);

  const PublicKey &get_public_key() const {
    return PubKey;
  }

 private:
  bool inited;
  unsigned char privkey[privkey_bytes];
  unsigned char priv_salt[32];
  arith::Bignum priv_exp;
  PublicKey PubKey;

  bool process_private_key();
  PrivateKey(const PrivateKey &) {
    throw priv_key_no_copy();
  }
  PrivateKey &operator=(const PrivateKey &) {
    throw priv_key_no_copy();
  }
};

// use one TempKeyGenerator object a lot of times
class TempKeyGenerator {
  enum { salt_size = 64 };
  unsigned char random_salt[salt_size];
  unsigned char buffer[privkey_bytes];

 public:
  TempKeyGenerator() {
    prng::rand_gen().strong_rand_bytes(random_salt, salt_size);
  }
  ~TempKeyGenerator() {
    memset(random_salt, 0, salt_size);
    memset(buffer, 0, privkey_bytes);
  }

  unsigned char *get_temp_private_key(unsigned char *to, const unsigned char *message, std::size_t size,
                                      const unsigned char *rand = 0, std::size_t rand_size = 0);  // rand may be 0
  void create_temp_private_key(PrivateKey &pk, const unsigned char *message, std::size_t size,
                               const unsigned char *rand = 0, std::size_t rand_size = 0);

  // sets temp_pub_key and shared_secret for one-time asymmetric encryption of message
  bool create_temp_shared_secret(unsigned char temp_pub_key[pubkey_bytes], unsigned char secret[shared_secret_bytes],
                                 const PublicKey &recipientPubKey, const unsigned char *message, std::size_t size,
                                 const unsigned char *rand = 0, std::size_t rand_size = 0);
};

}  // namespace Ed25519
}  // namespace crypto
