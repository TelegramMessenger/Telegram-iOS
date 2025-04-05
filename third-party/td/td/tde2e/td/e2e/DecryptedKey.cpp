//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/DecryptedKey.h"

#include "td/e2e/EncryptedKey.h"
#include "td/e2e/MessageEncryption.h"

#include "td/utils/algorithm.h"

namespace tde2e_core {

DecryptedKey::DecryptedKey(const Mnemonic &mnemonic)
    : mnemonic_words(mnemonic.get_words()), private_key(mnemonic.to_private_key()) {
}
DecryptedKey::DecryptedKey(std::vector<td::SecureString> mnemonic_words, PrivateKey key)
    : mnemonic_words(std::move(mnemonic_words)), private_key(std::move(key)) {
}
DecryptedKey::DecryptedKey(RawDecryptedKey key)
    : DecryptedKey(std::move(key.mnemonic_words), PrivateKey::from_slice(key.private_key).move_as_ok()) {
}

EncryptedKey DecryptedKey::encrypt(td::Slice local_password, td::Slice secret) const {
  td::SecureString decrypted_secret = MessageEncryption::hmac_sha512(secret, local_password);

  td::SecureString encryption_secret =
      MessageEncryption::kdf(as_slice(decrypted_secret), "tde2e local key", EncryptedKey::PBKDF_ITERATIONS);

  std::vector<td::SecureString> mnemonic_words_copy =
      td::transform(mnemonic_words, [](const auto &word) { return word.copy(); });
  auto data = td::serialize_secure(RawDecryptedKey{std::move(mnemonic_words_copy), private_key.to_secure_string()});
  auto encrypted_data = MessageEncryption::encrypt_data(data, as_slice(encryption_secret));

  return EncryptedKey{std::move(encrypted_data), private_key.to_public_key(), {}};
}

}  // namespace tde2e_core
