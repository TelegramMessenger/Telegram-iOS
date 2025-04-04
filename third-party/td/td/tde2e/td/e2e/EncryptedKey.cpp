//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/EncryptedKey.h"

#include "td/e2e/DecryptedKey.h"
#include "td/e2e/MessageEncryption.h"

#include "td/utils/tl_helpers.h"

namespace tde2e_core {

td::Result<DecryptedKey> EncryptedKey::decrypt(td::Slice local_password, bool check_public_key) const {
  /*
  if (secret.size() != 32) {
    return td::Status::Error("Failed to decrypt key: invalid secret size");
  }
  */
  auto decrypted_secret = MessageEncryption::hmac_sha512(secret, local_password);

  td::SecureString encryption_secret =
      MessageEncryption::kdf(as_slice(decrypted_secret), "tde2e local key", EncryptedKey::PBKDF_ITERATIONS);

  TRY_RESULT(decrypted_data, MessageEncryption::decrypt_data(as_slice(encrypted_data), as_slice(encryption_secret)));

  RawDecryptedKey raw_decrypted_key;
  TRY_STATUS(td::unserialize(raw_decrypted_key, decrypted_data));
  DecryptedKey res(std::move(raw_decrypted_key));
  if (check_public_key && !(res.private_key.to_public_key() == this->o_public_key)) {
    return td::Status::Error("Something wrong: public key of decrypted private key differs from requested public key");
  }
  return std::move(res);
}

}  // namespace tde2e_core
