//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/utils.h"

#include "td/utils/common.h"
#include "td/utils/optional.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

#include <utility>

namespace tde2e_core {

struct QRHandshakeBob {
  QRHandshakeBob(td::int64 bob_user_id, PrivateKey &&bob_private_key);

  static QRHandshakeBob create(td::int64 bob_user_id, PrivateKey bob_private_key);

  std::string generate_start() const;

  td::Result<td::SecureString> receive_accept(td::int64 alice_user_id, PublicKey alice_public_key,
                                              td::Slice encrypted_accept);

  td::SecureString encrypt(td::Slice data) const;
  td::Result<td::SecureString> decrypt(td::Slice encrypted_message) const;
  td::Result<td::SecureString> decrypt_ephemeral(td::Slice encrypted_message) const;
  td::Result<td::SecureString> shared_secret() const {
    if (!o_ephemeral_shared_secret_) {
      return td::Status::Error("No shared secret was set");
    }
    return td::SecureString(as_slice(*o_ephemeral_shared_secret_));
  }

  PrivateKey bob_ephemeral_private_key_;

  PrivateKey bob_private_key_;
  td::int64 bob_user_id_;
  td::UInt256 bob_nonce_;

  td::optional<td::int64> o_alice_user_id_;

  td::optional<PublicKey> o_alice_public_key_;
  td::optional<td::SecureString> o_shared_secret_;
  td::optional<td::SecureString> o_ephemeral_shared_secret_;
  td::optional<td::UInt256> o_alice_nonce_;

  bool had_accept_{false};
};

struct QRHandshakeAlice {
  QRHandshakeAlice(td::int64 alice_user_id, PrivateKey &&alice_private_key, td::int64 bob_user_id,
                   PublicKey &&bob_public_key, const td::UInt256 &bob_nonce, td::SecureString &&ephemeral_shared_secret,
                   td::SecureString &&shared_secret);

  static td::Result<QRHandshakeAlice> create(td::int64 alice_user_id, PrivateKey alice_private_key,
                                             td::int64 bob_user_id, PublicKey bob_public_key, td::Slice serialized_qr);

  static td::string serialize_login_import(td::Slice accept, td::Slice encrypted_alice_pk);
  static td::Result<std::pair<td::string, td::string>> deserialize_login_import(td::Slice data);
  td::SecureString generate_accept() const;

  td::Status receive_finish(td::Slice encrypted_finish);

  td::SecureString encrypt_ephemeral(td::Slice data) const;
  td::SecureString encrypt(td::Slice data) const;
  td::Result<td::SecureString> decrypt(td::Slice data) const;
  td::Result<td::SecureString> shared_secret() const;

  PrivateKey alice_private_key_;
  td::int64 alice_user_id_;
  td::UInt256 alice_nonce_;

  PublicKey bob_public_key_;
  td::int64 bob_user_id_;
  td::UInt256 bob_nonce_;

  td::SecureString ephemeral_shared_secret_;
  td::SecureString shared_secret_;

  bool had_finish_{false};
};

}  // namespace tde2e_core
