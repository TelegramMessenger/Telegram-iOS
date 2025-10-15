//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/UInt.h"

#include <memory>

namespace tde2e_core {

// new shiny public/private key classes
struct PublicKeyRaw;
struct PrivateKeyRaw;
struct PrivateKeyWithMnemonicRaw;

class Signature {
 public:
  Signature() = default;
  explicit Signature(td::UInt512 signature) : signature_(signature) {
  }
  static Signature from_u512(const td::UInt512 &signature);
  td::UInt512 to_u512() const;
  static td::Result<Signature> from_slice(const td::Slice &slice);
  td::Slice to_slice() const;
  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const Signature &signature);

 private:
  td::UInt512 signature_{};
};

class PublicKey {
 public:
  PublicKey();
  explicit PublicKey(std::shared_ptr<const PublicKeyRaw> public_key);
  static td::Result<PublicKey> from_slice(td::Slice);
  static PublicKey from_u256(const td::UInt256 &public_key);
  td::UInt256 to_u256() const;
  td::Status verify(td::Slice data, const Signature &signature) const;
  td::SecureString to_secure_string() const;
  bool operator==(const PublicKey &other) const;
  bool operator!=(const PublicKey &other) const;
  bool operator<(const PublicKey &other) const;
  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const PublicKey &public_key);

  const PublicKeyRaw &raw() const {
    CHECK(raw_);
    return *raw_;
  }

 private:
  std::shared_ptr<const PublicKeyRaw> raw_;
};

class PrivateKey {
 public:
  PrivateKey();
  explicit PrivateKey(std::shared_ptr<const PrivateKeyRaw> key_pair);
  explicit operator bool() const noexcept {
    return static_cast<bool>(raw_);
  }
  static td::Result<PrivateKey> generate();

  static td::Result<PrivateKey> from_slice(const td::Slice &slice);
  td::Result<td::SecureString> compute_shared_secret(const PublicKey &public_key) const;
  td::Result<Signature> sign(const td::Slice &data) const;
  PublicKey to_public_key() const;
  td::SecureString to_secure_string() const;
  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const PrivateKey &key_pair);
  const PrivateKeyRaw &raw() const {
    CHECK(raw_);
    return *raw_;
  }

 private:
  std::shared_ptr<const PrivateKeyRaw> raw_;
};

class PrivateKeyWithMnemonic {
 public:
  explicit PrivateKeyWithMnemonic(std::shared_ptr<const PrivateKeyWithMnemonicRaw> raw);
  static PrivateKeyWithMnemonic from_private_key(const PrivateKey &private_key,
                                                 std::vector<td::SecureString> words = {});
  PrivateKey to_private_key() const;
  td::Span<td::SecureString> words() const;

  PublicKey to_public_key() const;
  td::Result<Signature> sign(const td::Slice &data) const;
  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const PrivateKeyWithMnemonic &key_pair_with_mnemonic);

 private:
  std::shared_ptr<const PrivateKeyWithMnemonicRaw> raw_;
};

}  // namespace tde2e_core
