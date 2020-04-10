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
#include "Ed25519.h"

#include "td/utils/Random.h"

namespace crypto {
namespace Ed25519 {

bool all_bytes_same(const unsigned char *str, std::size_t size) {
  unsigned char c = str[0];
  for (std::size_t i = 0; i < size; i++) {
    if (str[i] != c) {
      return false;
    }
  }
  return true;
}

void PublicKey::clear(void) {
  if (inited != pk_empty) {
    std::memset(pubkey, 0, pubkey_bytes);
    PubKey.zeroize();
    PubKey_xz.zeroize();
  }
  inited = pk_empty;
}

PublicKey::PublicKey(const unsigned char pub_key[pubkey_bytes])
    : inited(pk_empty), PubKey(ellcurve::Fp25519()), PubKey_xz(ellcurve::Fp25519()) {
  import_public_key(pub_key);
}

PublicKey::PublicKey(const ellcurve::TwEdwardsCurve::SegrePoint &Pub_Key)
    : inited(pk_empty), PubKey(ellcurve::Fp25519()), PubKey_xz(ellcurve::Fp25519()) {
  import_public_key(Pub_Key);
}

bool PublicKey::import_public_key(const unsigned char pub_key[pubkey_bytes]) {
  clear();
  if (all_bytes_same(pub_key, pubkey_bytes)) {
    return false;
  }
  bool ok = false;
  PubKey = ellcurve::Ed25519().import_point(pub_key, ok);
  if (!ok) {
    clear();
    return false;
  }
  std::memcpy(pubkey, pub_key, pubkey_bytes);
  PubKey_xz.X = PubKey.Z + PubKey.Y;
  PubKey_xz.Z = PubKey.Z - PubKey.Y;
  inited = pk_init;
  return true;
}

bool PublicKey::import_public_key(const ellcurve::TwEdwardsCurve::SegrePoint &Pub_Key) {
  clear();
  if (!Pub_Key.is_valid()) {
    return false;
  }
  PubKey = Pub_Key;
  PubKey_xz.X = PubKey.Z + PubKey.Y;
  PubKey_xz.Z = PubKey.Z - PubKey.Y;
  inited = pk_init;

  if (!PubKey.export_point(pubkey)) {
    clear();
    return false;
  }
  return true;
}

bool PublicKey::export_public_key(unsigned char pubkey_buffer[pubkey_bytes]) const {
  if (inited != pk_init) {
    std::memset(pubkey_buffer, 0, pubkey_bytes);
    return false;
  } else {
    std::memcpy(pubkey_buffer, pubkey, pubkey_bytes);
    return true;
  }
}

bool PublicKey::check_message_signature(const unsigned char signature[sign_bytes], const unsigned char *message,
                                        std::size_t msg_size) {
  if (inited != pk_init) {
    return false;
  }
  unsigned char hash[64];
  {
    digest::SHA512 hasher(signature, 32);
    hasher.feed(pubkey, 32);
    hasher.feed(message, msg_size);
    hasher.extract(hash);
  }
  auto &E = ellcurve::Ed25519();
  const arith::Bignum &L = E.get_ell();
  arith::Bignum H, S;
  S.import_lsb(signature + 32, 32);
  H.import_lsb(hash, 64);
  H %= L;
  H = L - H;
  auto sG = E.power_gen(S);
  auto hA = E.power_point(PubKey, H);
  auto pR1 = E.add_points(sG, hA);
  unsigned char pR1_bytes[32];
  if (!pR1.export_point(pR1_bytes)) {
    return false;
  }
  return !std::memcmp(pR1_bytes, signature, 32);
}

// ---------------------
class PrivateKey;

bool PrivateKey::random_private_key(bool strong) {
  inited = false;
  if (!prng::rand_gen().rand_bytes(privkey, privkey_bytes, strong)) {
    clear();
    return false;
  }
  return process_private_key();
}

void PrivateKey::clear(void) {
  std::memset(privkey, 0, privkey_bytes);
  std::memset(priv_salt, 0, sizeof(priv_salt));
  priv_exp.clear();
  PubKey.clear();
  inited = false;
}

bool PrivateKey::import_private_key(const unsigned char pk[privkey_bytes]) {
  clear();
  if (all_bytes_same(pk, privkey_bytes)) {
    return false;
  }
  std::memcpy(privkey, pk, privkey_bytes);
  return process_private_key();
}

bool PrivateKey::export_private_key(unsigned char pk[privkey_bytes]) const {  // careful!
  if (!inited) {
    std::memset(pk, 0, privkey_bytes);
    return false;
  } else {
    std::memcpy(pk, privkey, privkey_bytes);
    return true;
  }
}

bool PrivateKey::process_private_key() {
  unsigned char buff[64];
  digest::hash_str<digest::SHA512>(buff, privkey, privkey_bytes);
  std::memcpy(priv_salt, buff + 32, 32);
  buff[0] = (unsigned char)(buff[0] & -8);
  buff[31] = (unsigned char)((buff[31] | 0x40) & ~0x80);
  priv_exp.import_lsb(buff, 32);
  PubKey = ellcurve::Ed25519().power_gen(priv_exp, true);  // uniform
  inited = PubKey.ok();
  if (!inited) {
    clear();
  }
  return inited;
}

bool PrivateKey::compute_shared_secret(unsigned char secret[shared_secret_bytes], const PublicKey &Pub) {
  if (!inited || !Pub.ok()) {
    std::memset(secret, 0, shared_secret_bytes);
    *(long *)secret = static_cast<long>(td::Random::fast_uint64());
    return false;
  }
  // uniform power!
  auto P = ellcurve::Curve25519().power_xz(Pub.get_point_xz(), priv_exp);
  if (P.is_infty()) {
    std::memset(secret, 0, shared_secret_bytes);
    *(long *)secret = static_cast<long>(td::Random::fast_uint64());
    return false;
  }
  P.export_point_u(secret);
  return true;
}

bool PrivateKey::compute_temp_shared_secret(unsigned char secret[shared_secret_bytes],
                                            const unsigned char temp_pub_key[pubkey_bytes]) {
  PublicKey tempPubkey(temp_pub_key);
  if (!tempPubkey.ok()) {
    return false;
  }
  return compute_shared_secret(secret, tempPubkey);
}

bool PrivateKey::sign_message(unsigned char signature[sign_bytes], const unsigned char *message, std::size_t msg_size) {
  if (!inited) {
    std::memset(signature, 0, sign_bytes);
    return false;
  }
  unsigned char r_bytes[64];
  digest::hash_two_str<digest::SHA512>(r_bytes, priv_salt, 32, message, msg_size);
  const arith::Bignum &L = ellcurve::Ed25519().get_ell();
  arith::Bignum eR;
  eR.import_lsb(r_bytes, 64);
  eR %= L;
  std::memset(r_bytes, 0, sizeof(r_bytes));

  // uniform power
  auto pR = ellcurve::Ed25519().power_gen(eR, true);

  auto ok = pR.export_point(signature, true);
  (void)ok;
  assert(ok);
  {
    digest::SHA512 hasher(signature, 32);
    hasher.feed(PubKey.get_pubkey_ptr(), 32);
    hasher.feed(message, msg_size);
    hasher.extract(r_bytes);
  }
  arith::Bignum S;
  S.import_lsb(r_bytes, 64);
  S %= L;
  S *= priv_exp;
  S += eR;
  S %= L;
  eR.clear();
  S.export_lsb(signature + 32, 32);
  return true;
}

// ---------------------------------
class TempKeyGenerator;

unsigned char *TempKeyGenerator::get_temp_private_key(unsigned char *to, const unsigned char *message, std::size_t size,
                                                      const unsigned char *rand,
                                                      std::size_t rand_size) {  // rand may be 0
  digest::SHA256 hasher(message, size);
  hasher.feed(random_salt, salt_size);
  if (rand && rand_size) {
    hasher.feed(rand, rand_size);
  }
  if (!to) {
    to = buffer;
  }
  hasher.extract(to);
  //++ *((long *)random_salt);
  return to;
}

void TempKeyGenerator::create_temp_private_key(PrivateKey &pk, const unsigned char *message, std::size_t size,
                                               const unsigned char *rand, std::size_t rand_size) {
  pk.import_private_key(get_temp_private_key(buffer, message, size, rand, rand_size));
  std::memset(buffer, 0, privkey_bytes);
}

bool TempKeyGenerator::create_temp_shared_secret(unsigned char temp_pub_key[pubkey_bytes],
                                                 unsigned char shared_secret[shared_secret_bytes],
                                                 const PublicKey &recipientPubKey, const unsigned char *message,
                                                 std::size_t size, const unsigned char *rand, std::size_t rand_size) {
  PrivateKey tmpPk;
  create_temp_private_key(tmpPk, message, size, rand, rand_size);
  return tmpPk.export_public_key(temp_pub_key) && tmpPk.compute_shared_secret(shared_secret, recipientPubKey);
}

}  // namespace Ed25519
}  // namespace crypto
