//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "MessageEncryption.h"
#include "td/e2e/Keys.h"

#include "td/utils/Ed25519.h"
#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"

namespace tde2e_core {

struct PublicKeyRaw {
  td::Ed25519::PublicKey public_key;
};
struct PrivateKeyRaw {
  PublicKeyRaw public_key;
  td::Ed25519::PrivateKey private_key;
};
struct PrivateKeyWithMnemonicRaw {
  std::vector<td::SecureString> mnemonic;
  PrivateKeyRaw key_pair;
};

Signature Signature::from_u512(const td::UInt512 &signature) {
  return Signature{signature};
}
td::UInt512 Signature::to_u512() const {
  return signature_;
}
td::Result<Signature> Signature::from_slice(const td::Slice &slice) {
  td::UInt512 signature;
  if (slice.size() != 64) {
    return td::Status::Error(PSLICE() << "Invalid signature length: " << slice.size());
  }
  signature.as_mutable_slice().copy_from(slice);
  return Signature{signature};
}
td::Slice Signature::to_slice() const {
  return signature_.as_slice();
}

auto empty_public_key() {
  static auto pk = PublicKey::from_u256({});
  return pk;
}
PublicKey::PublicKey() : raw_(empty_public_key().raw_) {
}
PublicKey::PublicKey(std::shared_ptr<const PublicKeyRaw> public_key) : raw_(std::move(public_key)) {
  CHECK(raw_);
}
td::Result<PublicKey> PublicKey::from_slice(td::Slice slice) {
  if (slice.size() != td::Ed25519::PublicKey::LENGTH) {
    return td::Status::Error("Invalid length of public key");
  }
  PublicKeyRaw public_key_raw{td::Ed25519::PublicKey(td::SecureString(slice))};
  return PublicKey(std::make_shared<PublicKeyRaw>(std::move(public_key_raw)));
}
PublicKey PublicKey::from_u256(const td::UInt256 &public_key) {
  PublicKeyRaw public_key_raw{td::Ed25519::PublicKey(td::SecureString(public_key.as_slice()))};
  return PublicKey(std::make_shared<PublicKeyRaw>(std::move(public_key_raw)));
}
td::UInt256 PublicKey::to_u256() const {
  CHECK(raw_);
  td::UInt256 result;
  result.as_mutable_slice().copy_from(raw_->public_key.as_octet_string());
  return result;
}
td::Status PublicKey::verify(td::Slice data, const Signature &signature) const {
  CHECK(raw_);
  return raw_->public_key.verify_signature(data, signature.to_slice());
}
td::SecureString PublicKey::to_secure_string() const {
  return raw_->public_key.as_octet_string();
}
bool PublicKey::operator==(const PublicKey &other) const {
  return to_u256() == other.to_u256();
}
bool PublicKey::operator!=(const PublicKey &other) const {
  return !(*this == other);
}
bool PublicKey::operator<(const PublicKey &other) const {
  return to_u256() < other.to_u256();
}
auto empty_private_key() {
  static auto pk = PrivateKey::from_slice(std::string(32, 1)).move_as_ok();
  return pk;
}
PrivateKey::PrivateKey() : raw_(empty_private_key().raw_) {
}
PrivateKey::PrivateKey(std::shared_ptr<const PrivateKeyRaw> key_pair) : raw_(std::move(key_pair)) {
  CHECK(raw_);
}
td::Result<PrivateKey> PrivateKey::generate() {
  TRY_RESULT(private_key, td::Ed25519::generate_private_key());
  TRY_RESULT(public_key, private_key.get_public_key());
  return std::make_shared<PrivateKeyRaw>(PrivateKeyRaw{{std::move(public_key)}, std::move(private_key)});
}
td::Result<PrivateKey> PrivateKey::from_slice(const td::Slice &slice) {
  if (slice.size() != td::Ed25519::PublicKey::LENGTH) {
    return td::Status::Error("Invalid private key length");
  }
  auto private_key = td::Ed25519::PrivateKey(td::SecureString(slice));
  TRY_RESULT(public_key, private_key.get_public_key());
  return std::make_shared<PrivateKeyRaw>(PrivateKeyRaw{{std::move(public_key)}, std::move(private_key)});
}
td::Result<td::SecureString> PrivateKey::compute_shared_secret(const PublicKey &public_key) const {
  TRY_RESULT(x25519_shared_secret, td::Ed25519::compute_shared_secret(public_key.raw().public_key, raw_->private_key));
  return td::SecureString(
      MessageEncryption::hmac_sha512("tde2e_shared_secret", x25519_shared_secret).as_slice().substr(0, 32));
}
td::Result<Signature> PrivateKey::sign(const td::Slice &data) const {
  CHECK(raw_);
  TRY_RESULT(signature, raw_->private_key.sign(data));
  return Signature::from_slice(signature);
}
PublicKey PrivateKey::to_public_key() const {
  CHECK(raw_);
  return PublicKey(std::shared_ptr<const PublicKeyRaw>(raw_, &raw_->public_key));
}
td::SecureString PrivateKey::to_secure_string() const {
  return raw_->private_key.as_octet_string();
}
PrivateKeyWithMnemonic::PrivateKeyWithMnemonic(std::shared_ptr<const PrivateKeyWithMnemonicRaw> raw)
    : raw_(std::move(raw)) {
  CHECK(raw_);
}
PrivateKeyWithMnemonic PrivateKeyWithMnemonic::from_private_key(const PrivateKey &private_key,
                                                                std::vector<td::SecureString> words) {
  return PrivateKeyWithMnemonic(std::make_shared<PrivateKeyWithMnemonicRaw>(PrivateKeyWithMnemonicRaw{
      std::move(words),
      PrivateKeyRaw{{td::Ed25519::PublicKey(td::SecureString(private_key.to_public_key().to_u256().as_slice()))},
                    td::Ed25519::PrivateKey(private_key.to_secure_string())}}));
}
PrivateKey PrivateKeyWithMnemonic::to_private_key() const {
  return PrivateKey(std::shared_ptr<const PrivateKeyRaw>(raw_, &raw_->key_pair));
}
td::Span<td::SecureString> PrivateKeyWithMnemonic::words() const {
  CHECK(raw_);
  return raw_->mnemonic;
}
PublicKey PrivateKeyWithMnemonic::to_public_key() const {
  return to_private_key().to_public_key();
}
td::Result<Signature> PrivateKeyWithMnemonic::sign(const td::Slice &data) const {
  return to_private_key().sign(data);
}
td::StringBuilder &operator<<(td::StringBuilder &sb, const PrivateKeyWithMnemonic &key_pair_with_mnemonic) {
  return sb << "EdPrivateKey(pub="
            << td::hex_encode(key_pair_with_mnemonic.to_public_key().to_u256().as_slice().substr(0, 8)) << "...)";
}
td::StringBuilder &operator<<(td::StringBuilder &sb, const PrivateKey &key_pair) {
  return sb << "EdPrivateKey(pub=" << td::hex_encode(key_pair.to_public_key().to_u256().as_slice().substr(0, 8))
            << "...)";
}
td::StringBuilder &operator<<(td::StringBuilder &sb, const PublicKey &public_key) {
  return sb << "EdPublicKey(" << td::hex_encode(public_key.to_u256().as_slice().substr(0, 8)) << "...)";
}
td::StringBuilder &operator<<(td::StringBuilder &sb, const Signature &signature) {
  return sb << "Signature(" << td::hex_encode(signature.signature_.as_slice().substr(0, 8)) << "...)";
}

}  // namespace tde2e_core
