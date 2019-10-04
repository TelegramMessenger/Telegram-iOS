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
#include "DecryptedKey.h"

#include "tonlib/keys/EncryptedKey.h"
#include "tonlib/keys/SimpleEncryption.h"

#include "td/utils/Random.h"
#include "td/utils/crypto.h"

namespace tonlib {
DecryptedKey::DecryptedKey(const Mnemonic &mnemonic)
    : mnemonic_words(mnemonic.get_words()), private_key(mnemonic.to_private_key()) {
}
DecryptedKey::DecryptedKey(std::vector<td::SecureString> mnemonic_words, td::Ed25519::PrivateKey key)
    : mnemonic_words(std::move(mnemonic_words)), private_key(std::move(key)) {
}
DecryptedKey::DecryptedKey(RawDecryptedKey key)
    : DecryptedKey(std::move(key.mnemonic_words), td::Ed25519::PrivateKey(key.private_key.copy())) {
}

EncryptedKey DecryptedKey::encrypt(td::Slice local_password, td::Slice old_secret) const {
  td::SecureString secret(32);
  if (old_secret.size() == td::as_slice(secret).size()) {
    secret.as_mutable_slice().copy_from(old_secret);
  } else {
    td::Random::secure_bytes(secret.as_mutable_slice());
  }
  td::SecureString decrypted_secret = SimpleEncryption::combine_secrets(secret, local_password);

  td::SecureString encryption_secret =
      SimpleEncryption::kdf(as_slice(decrypted_secret), "TON local key", EncryptedKey::PBKDF_ITERATIONS);

  std::vector<td::SecureString> mnemonic_words_copy;
  for (auto &w : mnemonic_words) {
    mnemonic_words_copy.push_back(w.copy());
  }
  auto data = td::serialize_secure(RawDecryptedKey{std::move(mnemonic_words_copy), private_key.as_octet_string()});
  auto encrypted_data = SimpleEncryption::encrypt_data(data, as_slice(encryption_secret));

  return EncryptedKey{std::move(encrypted_data), private_key.get_public_key().move_as_ok(), std::move(secret)};
}
}  // namespace tonlib
