//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/QRHandshake.h"

#include "td/e2e/e2e_api.h"
#include "td/e2e/MessageEncryption.h"

#include "td/telegram/e2e_api.h"

#include "td/utils/common.h"
#include "td/utils/tl_parsers.h"

namespace tde2e_core {

namespace e2e = td::e2e_api;

QRHandshakeBob::QRHandshakeBob(td::int64 bob_user_id, PrivateKey &&bob_private_key)
    : bob_ephemeral_private_key_(PrivateKey::generate().move_as_ok())
    , bob_private_key_(std::move(bob_private_key))
    , bob_user_id_(bob_user_id)
    , bob_nonce_(generate_nonce()) {
}

QRHandshakeBob QRHandshakeBob::create(td::int64 bob_user_id, PrivateKey bob_private_key) {
  return QRHandshakeBob(bob_user_id, std::move(bob_private_key));
}

std::string QRHandshakeBob::generate_start() const {
  return serialize_boxed(e2e::e2e_handshakeQR(bob_ephemeral_private_key_.to_public_key().to_u256(), bob_nonce_));
}

td::Result<td::SecureString> QRHandshakeBob::receive_accept(td::int64 alice_user_id, PublicKey alice_public_key,
                                                            td::Slice encrypted_accept) {
  if (had_accept_) {
    return td::Status::Error("Already processed accept");
  }
  had_accept_ = true;

  CHECK(!o_alice_public_key_);
  CHECK(!o_alice_user_id_);
  CHECK(!o_alice_nonce_);

  o_alice_public_key_ = std::move(alice_public_key);
  o_alice_user_id_ = alice_user_id;

  TRY_RESULT_ASSIGN(o_ephemeral_shared_secret_, bob_ephemeral_private_key_.compute_shared_secret(*o_alice_public_key_));
  TRY_RESULT(shared_secret_tmp, bob_private_key_.compute_shared_secret(*o_alice_public_key_));
  o_shared_secret_ = MessageEncryption::combine_secrets(o_ephemeral_shared_secret_.value(), shared_secret_tmp);

  TRY_RESULT(decrypted_accept, decrypt_ephemeral(encrypted_accept));
  td::TlParser parser(decrypted_accept);
  auto message = e2e::e2e_HandshakePrivate::fetch(parser);
  TRY_STATUS_PREFIX(parser.get_status(), "Failed to parse message: ");
  if (message->get_id() != e2e::e2e_handshakePrivateAccept::ID) {
    return td::Status::Error("Unexpected public message type");
  }
  auto accept = td::move_tl_object_as<e2e::e2e_handshakePrivateAccept>(message);
  CHECK(accept);

  o_alice_nonce_ = accept->alice_nonce_;

  CHECK(o_alice_user_id_);
  CHECK(o_alice_public_key_);
  CHECK(o_alice_nonce_);

  if (accept->bob_nonce_ != bob_nonce_) {
    return td::Status::Error("Bob's nonce mismatch");
  }
  if (PublicKey::from_u256(accept->alice_PK_) != *o_alice_public_key_) {
    return td::Status::Error("Alice's public key mismatch");
  }
  if (PublicKey::from_u256(accept->bob_PK_) != bob_private_key_.to_public_key()) {
    return td::Status::Error("Bob's public key mismatch");
  }
  if (accept->alice_user_id_ != *o_alice_user_id_) {
    return td::Status::Error("Alice's user_id mismatch");
  }
  if (accept->bob_user_id_ != bob_user_id_) {
    return td::Status::Error("Bob's user_id mismatch");
  }

  auto decrypted_message = serialize_boxed(
      e2e::e2e_handshakePrivateFinish(o_alice_public_key_.value().to_u256(), bob_private_key_.to_public_key().to_u256(),
                                      *o_alice_user_id_, bob_user_id_, *o_alice_nonce_, bob_nonce_));
  return encrypt(decrypted_message);
}

td::SecureString QRHandshakeBob::encrypt(td::Slice data) const {
  CHECK(o_shared_secret_);
  return MessageEncryption::encrypt_data(data, *o_shared_secret_);
}

td::Result<td::SecureString> QRHandshakeBob::decrypt(td::Slice encrypted_message) const {
  if (!o_shared_secret_) {
    return td::Status::Error("Have no shared secret (handshake is in progress)");
  }
  return MessageEncryption::decrypt_data(encrypted_message, *o_shared_secret_);
}
td::Result<td::SecureString> QRHandshakeBob::decrypt_ephemeral(td::Slice encrypted_message) const {
  if (!o_ephemeral_shared_secret_) {
    return td::Status::Error("Have no ephemeral shared secret (handshake is in progress)");
  }
  return MessageEncryption::decrypt_data(encrypted_message, *o_ephemeral_shared_secret_);
}

QRHandshakeAlice::QRHandshakeAlice(td::int64 alice_user_id, PrivateKey &&alice_private_key, td::int64 bob_user_id,
                                   PublicKey &&bob_public_key, const td::UInt256 &bob_nonce,
                                   td::SecureString &&ephemeral_shared_secret, td::SecureString &&shared_secret)
    : alice_private_key_(std::move(alice_private_key))
    , alice_user_id_(alice_user_id)
    , alice_nonce_(generate_nonce())
    , bob_public_key_(std::move(bob_public_key))
    , bob_user_id_(bob_user_id)
    , bob_nonce_(bob_nonce)
    , ephemeral_shared_secret_(std::move(ephemeral_shared_secret))
    , shared_secret_(std::move(shared_secret)) {
}

td::Result<QRHandshakeAlice> QRHandshakeAlice::create(td::int64 alice_user_id, PrivateKey alice_private_key,
                                                      td::int64 bob_user_id, PublicKey bob_public_key,
                                                      td::Slice serialized_qr) {
  auto alice_public_key = alice_private_key.to_public_key();
  td::TlParser parser(serialized_qr);
  auto message = e2e::e2e_HandshakePublic::fetch(parser);
  TRY_STATUS_PREFIX(parser.get_status(), "Failed to parse public qr: ");
  if (message->get_id() != e2e::e2e_handshakeQR::ID) {
    return td::Status::Error("Unexpected public message type");
  }
  auto qr = td::move_tl_object_as<e2e::e2e_handshakeQR>(message);
  CHECK(qr);

  auto bob_ephemeral_public_key = PublicKey::from_u256(qr->bob_ephemeral_PK_);
  TRY_RESULT(ephemeral_shared_secret, alice_private_key.compute_shared_secret(bob_ephemeral_public_key));
  TRY_RESULT(shared_secret_tmp, alice_private_key.compute_shared_secret(bob_public_key));
  auto shared_secret = MessageEncryption::combine_secrets(ephemeral_shared_secret, shared_secret_tmp);
  return QRHandshakeAlice{alice_user_id,
                          std::move(alice_private_key),
                          bob_user_id,
                          std::move(bob_public_key),
                          qr->bob_nonce_,
                          std::move(ephemeral_shared_secret),
                          std::move(shared_secret)};
}

td::string QRHandshakeAlice::serialize_login_import(td::Slice accept, td::Slice encrypted_alice_pk) {
  return serialize_boxed(e2e::e2e_handshakeLoginExport(accept.str(), encrypted_alice_pk.str()));
}
td::Result<std::pair<td::string, td::string>> QRHandshakeAlice::deserialize_login_import(td::Slice data) {
  td::TlParser parser(data);
  auto message = e2e::e2e_HandshakePublic::fetch(parser);
  TRY_STATUS_PREFIX(parser.get_status(), "Failed to parse message: ");
  if (message->get_id() != e2e::e2e_handshakeLoginExport::ID) {
    return td::Status::Error("Unexpected public message type");
  }
  auto login_export = td::move_tl_object_as<e2e::e2e_handshakeLoginExport>(message);
  CHECK(login_export);
  return std::make_pair(login_export->accept_, login_export->encrypted_key_);
}

td::SecureString QRHandshakeAlice::generate_accept() const {
  auto decrypted_message = serialize_boxed(e2e::e2e_handshakePrivateAccept(alice_private_key_.to_public_key().to_u256(),
                                                                           bob_public_key_.to_u256(), alice_user_id_,
                                                                           bob_user_id_, alice_nonce_, bob_nonce_));
  return encrypt_ephemeral(decrypted_message);
}

td::Status QRHandshakeAlice::receive_finish(td::Slice encrypted_finish) {
  if (had_finish_) {
    return td::Status::Error("Already processed finish");
  }
  had_finish_ = true;

  TRY_RESULT(decrypted_finish, decrypt(encrypted_finish));
  td::TlParser parser(decrypted_finish);
  auto message = e2e::e2e_HandshakePrivate::fetch(parser);
  TRY_STATUS_PREFIX(parser.get_status(), "Failed to parse message: ");
  if (message->get_id() != e2e::e2e_handshakePrivateFinish::ID) {
    return td::Status::Error("Unexpected public message type");
  }
  auto finish = td::move_tl_object_as<e2e::e2e_handshakePrivateFinish>(message);
  CHECK(finish);

  if (finish->alice_nonce_ != alice_nonce_) {
    return td::Status::Error("Bob's nonce mismatch");
  }
  if (finish->bob_nonce_ != bob_nonce_) {
    return td::Status::Error("Bob's nonce mismatch");
  }
  if (PublicKey::from_u256(finish->alice_PK_) != alice_private_key_.to_public_key()) {
    return td::Status::Error("Alice's public key mismatch");
  }
  if (PublicKey::from_u256(finish->bob_PK_) != bob_public_key_) {
    return td::Status::Error("Bob's public key mismatch");
  }
  if (finish->alice_user_id_ != alice_user_id_) {
    return td::Status::Error("Alice's user_id mismatch");
  }
  if (finish->bob_user_id_ != bob_user_id_) {
    return td::Status::Error("Bob's user_id mismatch");
  }

  return td::Status::OK();
}

td::SecureString QRHandshakeAlice::encrypt_ephemeral(td::Slice data) const {
  return MessageEncryption::encrypt_data(data, ephemeral_shared_secret_);
}
td::SecureString QRHandshakeAlice::encrypt(td::Slice data) const {
  return MessageEncryption::encrypt_data(data, shared_secret_);
}

td::Result<td::SecureString> QRHandshakeAlice::decrypt(td::Slice data) const {
  return MessageEncryption::decrypt_data(data, shared_secret_);
}
td::Result<td::SecureString> QRHandshakeAlice::shared_secret() const {
  return td::SecureString(as_slice(ephemeral_shared_secret_));
}

}  // namespace tde2e_core
