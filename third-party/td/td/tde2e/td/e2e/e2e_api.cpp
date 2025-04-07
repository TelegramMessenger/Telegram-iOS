//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/e2e_api.h"

#include "td/e2e/Blockchain.h"
#include "td/e2e/Call.h"
#include "td/e2e/Container.h"
#include "td/e2e/DecryptedKey.h"
#include "td/e2e/EncryptedKey.h"
#include "td/e2e/EncryptedStorage.h"
#include "td/e2e/MessageEncryption.h"
#include "td/e2e/Mnemonic.h"
#include "td/e2e/QRHandshake.h"

#include "td/utils/algorithm.h"
#include "td/utils/base64.h"
#include "td/utils/common.h"
#include "td/utils/int_types.h"
#include "td/utils/logging.h"
#include "td/utils/overloaded.h"
#include "td/utils/Random.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/UInt.h"

#include <memory>

namespace tde2e_core {
namespace api = tde2e_api;

using SecretRef = SharedRef<td::SecureString>;
using HandshakeBobRef = UniqueRef<QRHandshakeBob>;
using HandshakeAliceRef = UniqueRef<QRHandshakeAlice>;
using StorageRef = UniqueRef<EncryptedStorage>;
using CallRef = UniqueRef<Call>;

td::UInt256 to_hash(td::Slice tag, td::Slice serialization) {
  auto res = MessageEncryption::hmac_sha512(tag, serialization);
  td::UInt256 hash;
  hash.as_mutable_slice().copy_from(res.as_slice().substr(0, 32));
  return hash;
}

class KeyChain {
 public:
  KeyChain() {
    set_log_verbosity_level(1).ignore();
  }

  td::Result<api::Ok> set_log_verbosity_level(td::int32 new_verbosity_level) {
    if (0 <= new_verbosity_level && new_verbosity_level <= VERBOSITY_NAME(NEVER)) {
      SET_VERBOSITY_LEVEL(VERBOSITY_NAME(FATAL) + new_verbosity_level);
      return api::Ok{};
    }
    return td::Status::Error("Wrong new verbosity level specified");
  }
  td::Result<api::PrivateKeyId> generate_private_key() {
    TRY_RESULT(mnemonic, Mnemonic::create_new({}));
    return from_words(mnemonic.get_words_string());
  }
  td::Result<api::PrivateKeyId> generate_dummy_key() {
    auto hash = to_hash("dummy key", "...");
    return container_.try_build<Key>(hash, [&]() -> td::Result<PrivateKeyWithMnemonic> {
      td::SecureString key(32, 1);
      return PrivateKeyWithMnemonic::from_private_key(PrivateKey::from_slice(key).move_as_ok(), {});
    });
  }
  td::Result<api::PrivateKeyId> generate_temporary_private_key() {
    TRY_RESULT(private_key, PrivateKey::generate());
    auto hash = to_hash("temporary private key", private_key.to_public_key().to_u256().as_slice());
    return container_.try_build<Key>(hash, [&]() -> td::Result<PrivateKeyWithMnemonic> {
      return PrivateKeyWithMnemonic::from_private_key(private_key, {});
    });
  }

  td::Result<api::SymmetricKeyId> derive_secret(api::PrivateKeyId key_id, td::Slice tag) {
    TRY_RESULT(pk, to_private_key_with_mnemonic(key_id));
    auto hash = to_hash(PSLICE() << "derive secret with tag: " << td::base64_encode(tag),
                        pk.to_public_key().to_u256().as_slice());
    return container_.try_build<Key>(hash, [&]() -> td::Result<td::SecureString> {
      // TODO: this is probably wrong and should be changed
      return MessageEncryption::hmac_sha512(pk.to_private_key().to_secure_string(), tag);
    });
  }

  td::Result<api::PrivateKeyId> from_words(td::Slice words) {
    auto hash = to_hash("private ed25519 key from menemonic", words);
    return container_.try_build<Key>(hash, [&]() -> td::Result<PrivateKeyWithMnemonic> {
      TRY_RESULT(mnemonic, Mnemonic::create(td::SecureString(words), td::SecureString("")));
      TRY_RESULT(private_key, mnemonic_to_private_key(mnemonic));
      return private_key;
    });
  }

  td::Result<api::Bytes> to_encrypted_private_key(api::PrivateKeyId key_id, api::SymmetricKeyId secret_id) {
    TRY_RESULT(pk, to_private_key_with_mnemonic(key_id));
    TRY_RESULT(secret, to_secret_ref(secret_id));
    auto decrypted_key =
        DecryptedKey(td::transform(pk.words(), [](const auto &m) { return m.copy(); }), pk.to_private_key());
    auto encrypted = decrypted_key.encrypt("tde2e private key", *secret);
    return encrypted.encrypted_data.as_slice().str();
  }

  td::Result<api::PrivateKeyId> from_encrypted_private_key(td::Slice encrypted_private_key,
                                                           api::SymmetricKeyId secret_id) {
    TRY_RESULT(secret, to_secret_ref(secret_id));
    auto hash = to_hash(PSLICE() << "encrypted private ed25519 key " << encrypted_private_key.str(), *secret);
    return container_.try_build<Key>(hash, [&]() -> td::Result<PrivateKeyWithMnemonic> {
      // WOW. empty public key. is it good?
      auto encrypted_key = EncryptedKey{td::SecureString(encrypted_private_key), {}, secret->copy()};
      TRY_RESULT(decrypted_key, encrypted_key.decrypt("tde2e private key", false));
      return PrivateKeyWithMnemonic::from_private_key(decrypted_key.private_key,
                                                      std::move(decrypted_key.mnemonic_words));
    });
  }

  td::Result<api::Bytes> to_encrypted_private_key_internal(api::PrivateKeyId key_id, api::SymmetricKeyId secret_id) {
    TRY_RESULT(pk, to_private_key_with_mnemonic(key_id));
    TRY_RESULT(secret, to_secret_ref(secret_id));
    return MessageEncryption::encrypt_data(pk.to_private_key().to_secure_string(), *secret).as_slice().str();
  }

  td::Result<api::PrivateKeyId> from_encrypted_private_key_internal(td::Slice encrypted_private_key,
                                                                    api::SymmetricKeyId secret_id) {
    TRY_RESULT(secret, to_secret_ref(secret_id));
    auto hash = to_hash(PSLICE() << "encrypted private ed25519 key internal " << encrypted_private_key.str(), *secret);
    return container_.try_build<Key>(hash, [&]() -> td::Result<PrivateKeyWithMnemonic> {
      TRY_RESULT(raw_pk, MessageEncryption::decrypt_data(encrypted_private_key, *secret));
      TRY_RESULT(pk, PrivateKey::from_slice(raw_pk));
      return PrivateKeyWithMnemonic::from_private_key(pk, {});
    });
  }

  td::Result<api::PublicKeyId> from_public_key(td::Slice public_key) {
    TRY_RESULT(key, PublicKey::from_slice(public_key));
    auto hash = to_hash("public ed25519 key", public_key);
    return container_.try_build<Key>(hash, [&]() -> td::Result<PublicKey> { return std::move(key); });
  }

  td::Result<api::SymmetricKeyId> from_ecdh(api::PrivateKeyId private_key_id, api::PublicKeyId public_key_id) {
    TRY_RESULT(public_key, to_public_key(public_key_id));
    TRY_RESULT(private_key, to_private_key_with_mnemonic(private_key_id));
    auto hash = to_hash("x25519 shared secret",
                        public_key.to_u256().as_slice().str() + private_key.to_public_key().to_u256().as_slice().str());
    return container_.try_build<Key>(hash, [&]() -> td::Result<td::SecureString> {
      TRY_RESULT(shared_secret, private_key.to_private_key().compute_shared_secret(public_key));
      return std::move(shared_secret);
    });
  }

  td::Result<api::SymmetricKeyId> from_bytes(td::Slice secret) {
    auto hash = to_hash("raw secret", secret);
    return container_.try_build<Key>(hash, [&]() -> td::Result<td::SecureString> { return td::SecureString(secret); });
  }
  td::Result<api::SecureBytes> to_words(api::PrivateKeyId private_key_id) {
    TRY_RESULT(private_key, to_private_key_with_mnemonic(private_key_id));
    api::SecureBytes res;
    auto words = private_key.words();
    for (size_t i = 0; i < words.size(); ++i) {
      if (i != 0) {
        res += ' ';
      }
      res.append(words[i].data(), words[i].size());
    }
    return res;
  }

  td::Result<api::Int512> sign(api::PrivateKeyId key, td::Slice data) {
    TRY_RESULT(private_key_ref, to_private_key_with_mnemonic(key));
    TRY_RESULT(signature, private_key_ref.sign(td::Slice(data.data(), data.size())));
    CHECK(signature.to_slice().size() == 64);
    api::Int512 result;
    td::MutableSlice(result.data(), result.size()).copy_from(signature.to_slice());
    return result;
  }

  td::Status destroy(std::optional<api::AnyKeyId> o_key_id) {
    return container_.destroy<Key>(o_key_id);
  }

  td::Result<api::EncryptedMessageForMany> encrypt_message_for_many(const std::vector<api::SymmetricKeyId> &key_ids,
                                                                    td::Slice message) {
    std::vector<SecretRef> secrets;
    for (auto &key_id : key_ids) {
      TRY_RESULT(secret, to_secret_ref(key_id));
      secrets.emplace_back(std::move(secret));
    }

    td::SecureString one_time_secret(32);
    td::Random::secure_bytes(one_time_secret.as_mutable_slice());
    api::EncryptedMessageForMany res;
    res.encrypted_message = MessageEncryption::encrypt_data(message, one_time_secret).as_slice().str();
    for (auto &secret : secrets) {
      TRY_RESULT(encrypted_header,
                 MessageEncryption::encrypt_header(one_time_secret, res.encrypted_message, secret->as_slice()));
      res.encrypted_headers.emplace_back(encrypted_header.as_slice().str());
    }
    return res;
  }
  td::Result<api::EncryptedMessageForMany> re_encrypt_message_for_many(api::SymmetricKeyId decrypt_key,
                                                                       const std::vector<api::SymmetricKeyId> &key_ids,
                                                                       td::Slice encrypted_header,
                                                                       td::Slice encrypted_message) {
    std::vector<SecretRef> secrets;
    for (auto &key_id : key_ids) {
      TRY_RESULT(secret, to_secret_ref(key_id));
      secrets.emplace_back(std::move(secret));
    }
    TRY_RESULT(secret_ref, to_secret_ref(decrypt_key));
    TRY_RESULT(header, MessageEncryption::decrypt_header(encrypted_header, encrypted_message, secret_ref->as_slice()));

    api::EncryptedMessageForMany res;
    for (auto &secret : secrets) {
      TRY_RESULT(new_encrypted_header,
                 MessageEncryption::encrypt_header(header, secret->as_slice(), encrypted_message));
      res.encrypted_headers.emplace_back(new_encrypted_header.as_slice().str());
    }
    return res;
  }

  td::Result<api::SecureBytes> decrypt_message_for_many(api::SymmetricKeyId key_id, td::Slice encrypted_header,
                                                        td::Slice encrypted_message) {
    TRY_RESULT(secret, to_secret_ref(key_id));
    TRY_RESULT(header, MessageEncryption::decrypt_header(encrypted_header, encrypted_message, secret->as_slice()));
    TRY_RESULT(message, MessageEncryption::decrypt_data(encrypted_message, header));
    return message.as_slice().str();
  }

  td::Result<api::SecureBytes> encrypt_message_for_one(api::SymmetricKeyId key_id, td::Slice message) {
    TRY_RESULT(secret, to_secret_ref(key_id));
    auto encrypted_message = MessageEncryption::encrypt_data(message, secret->as_slice());
    return encrypted_message.as_slice().str();
  }

  td::Result<api::SecureBytes> decrypt_message_for_one(api::SymmetricKeyId key_id, td::Slice encrypted_message) {
    TRY_RESULT(secret, to_secret_ref(key_id));
    TRY_RESULT(message, MessageEncryption::decrypt_data(encrypted_message, secret->as_slice()));
    return message.as_slice().str();
  }

  td::Result<api::HandshakeId> handshake_create_for_bob(api::UserId bob_user_id, api::PrivateKeyId bob_private_key_id) {
    TRY_RESULT(private_key_ref, to_private_key_with_mnemonic(bob_private_key_id));
    return container_.try_build<Handshake>({}, [&]() -> td::Result<QRHandshakeBob> {
      return QRHandshakeBob::create(bob_user_id, private_key_ref.to_private_key());
    });
  }
  td::Result<api::Bytes> handshake_bob_send_start(api::HandshakeId bob_handshake_id) {
    TRY_RESULT(bob_handshake, to_handshake_bob_ref(bob_handshake_id));
    return bob_handshake->generate_start();
  }
  td::Result<api::HandshakeId> handshake_create_for_alice(api::UserId alice_user_id,
                                                          api::PrivateKeyId alice_private_key_id,
                                                          api::UserId bob_user_id, td::Slice bob_public_key,
                                                          td::Slice start) {
    TRY_RESULT(private_key_ref, to_private_key_with_mnemonic(alice_private_key_id));
    TRY_RESULT(bob_public_key_internal, PublicKey::from_slice(bob_public_key));
    return container_.try_build<Handshake>({}, [&] {
      return QRHandshakeAlice::create(alice_user_id, private_key_ref.to_private_key(), bob_user_id,
                                      bob_public_key_internal, start.str());
    });
  }
  td::Result<api::Bytes> handshake_alice_send_accept(api::HandshakeId alice_handshake_id) {
    TRY_RESULT(alice_handshake, to_handshake_alice_ref(alice_handshake_id));
    return alice_handshake->generate_accept().as_slice().str();
  }

  td::Result<api::Bytes> handshake_bob_receive_accept_send_finish(api::HandshakeId bob_handshake_id,
                                                                  api::UserId alice_id, td::Slice alice_public_key,
                                                                  td::Slice accept) {
    TRY_RESULT(bob_handshake, to_handshake_bob_ref(bob_handshake_id));
    TRY_RESULT(alice_public_key_internal, PublicKey::from_slice(alice_public_key));
    TRY_RESULT(msg, bob_handshake->receive_accept(alice_id, alice_public_key_internal, accept.str()));
    return msg.as_slice().str();
  }

  td::Result<api::Ok> handshake_alice_receive_finish(api::HandshakeId alice_handshake_id, td::Slice finish) {
    TRY_RESULT(alice_handshake, to_handshake_alice_ref(alice_handshake_id));
    TRY_STATUS(alice_handshake->receive_finish(finish));
    return api::Ok();
  }

  td::Result<api::SymmetricKeyId> handshake_get_shared_key_id(api::HandshakeId handshake_id) {
    TRY_RESULT(handshake, container_.get_unique<Handshake>(handshake_id));
    TRY_RESULT(shared_secret, std::visit([&](auto &&v) { return v.shared_secret(); }, *handshake));
    auto hash = to_hash("handshake shared_secret", shared_secret.as_slice());
    return container_.try_build<Key>(hash, [&]() -> td::Result<td::SecureString> { return std::move(shared_secret); });
  }

  td::Result<api::Ok> handshake_destroy(std::optional<api::HandshakeId> o_handshake_id) {
    TRY_STATUS(container_.destroy<Handshake>(o_handshake_id));
    return api::Ok();
  }

  td::Result<api::Bytes> handshake_get_start_id(td::Slice start) {
    auto hash = to_hash("handshake start id", start);
    return hash.as_slice().str();
  }
  td::Result<api::LoginId> login_create_for_bob() {
    auto bob_fake_id = 0;
    auto bob_fake_pk = generate_dummy_key().move_as_ok();
    return handshake_create_for_bob(bob_fake_id, bob_fake_pk);
  }
  td::Result<api::Bytes> login_bob_send_start(api::LoginId bob_login_id) {
    TRY_RESULT(bob_handshake, to_handshake_bob_ref(bob_login_id));
    return bob_handshake->generate_start();
  }
  td::Result<api::Bytes> login_create_for_alice(api::UserId alice_user_id, api::PrivateKeyId alice_private_key_id,
                                                td::Slice start) {
    auto bob_fake_id = 0;
    auto bob_fake_pk = generate_dummy_key().move_as_ok();
    TRY_RESULT(handshake_id,
               handshake_create_for_alice(alice_user_id, alice_private_key_id, bob_fake_id,
                                          to_public_key(bob_fake_pk).move_as_ok().to_secure_string(), start));
    TRY_RESULT(shared_key_id, handshake_get_shared_key_id(handshake_id));
    TRY_RESULT(encrypted_alice_pk, to_encrypted_private_key(alice_private_key_id, shared_key_id));
    TRY_RESULT(accept, handshake_alice_send_accept(handshake_id));
    return QRHandshakeAlice::serialize_login_import(accept, encrypted_alice_pk);
  }

  td::Result<api::PrivateKeyId> login_finish_for_bob(api::LoginId bob_login_id, api::UserId alice_user_id,
                                                     const api::PublicKey &alice_public_key, td::Slice data) {
    std::pair<std::string, std::string> accept_and_key;
    {
      TRY_RESULT(bob_handshake, to_handshake_bob_ref(bob_login_id));
      TRY_RESULT_ASSIGN(accept_and_key, QRHandshakeAlice::deserialize_login_import(data));
      TRY_RESULT(alice_public_key_internal, PublicKey::from_slice(alice_public_key));
      TRY_RESULT(finish, bob_handshake->receive_accept(alice_user_id, alice_public_key_internal, accept_and_key.first));
    }
    TRY_RESULT(shared_key_id, handshake_get_shared_key_id(bob_login_id));
    return from_encrypted_private_key(accept_and_key.second, shared_key_id);
  }

  api::Result<api::Ok> login_destroy(api::LoginId login_id) {
    return handshake_destroy(login_id);
  }
  td::Result<api::Ok> login_destroy_all() {
    return handshake_destroy({});
  }
  td::Result<api::StorageId> storage_create(api::PrivateKeyId key_id, td::Slice last_block) {
    TRY_RESULT(private_key_ref, to_private_key_with_mnemonic(key_id));

    TRY_RESULT(storage, EncryptedStorage::create(last_block, private_key_ref.to_private_key()));
    return container_.emplace<EncryptedStorage>(std::move(storage));
  }

  td::Result<api::Ok> storage_destroy(std::optional<api::StorageId> o_storage_id) {
    TRY_STATUS(container_.destroy<EncryptedStorage>(o_storage_id));
    return api::Ok();
  }

  td::Result<api::Ok> call_destroy(std::optional<api::CallId> o_call_id) {
    TRY_STATUS(container_.destroy<Call>(o_call_id));
    return api::Ok();
  }

  template <class T>
  td::Result<api::UpdateId> storage_update_contact(api::StorageId storage_id, api::PublicKeyId key,
                                                   api::SignedEntry<T> signed_entry) {
    TRY_RESULT(storage_ref, to_storage_ref(storage_id));
    TRY_RESULT(public_key_ref, to_public_key(key));
    return storage_ref->update(KeyContactByPublicKey{public_key_ref.to_u256()}, std::move(signed_entry));
  }
  template <class T>
  td::Result<api::SignedEntry<T>> storage_sign_entry(api::PrivateKeyId key, api::Entry<T> entry) {
    TRY_RESULT(private_key_ref, to_private_key_with_mnemonic(key));
    return EncryptedStorage::sign_entry(private_key_ref.to_private_key(), std::move(entry));
  }
  td::Result<std::optional<api::Contact>> storage_get_contact(api::StorageId storage_id, api::PublicKeyId key) {
    TRY_RESULT(storage_ref, to_storage_ref(storage_id));
    TRY_RESULT(public_key_ref, to_public_key(key));
    return storage_ref->get(KeyContactByPublicKey{public_key_ref.to_u256()}, false);
  }
  td::Result<std::optional<api::Contact>> storage_get_contact_optimistic(api::StorageId storage_id,
                                                                         api::PublicKeyId key) {
    TRY_RESULT(storage_ref, to_storage_ref(storage_id));
    TRY_RESULT(public_key_ref, to_public_key(key));
    return storage_ref->get(KeyContactByPublicKey{public_key_ref.to_u256()}, true);
  }
  td::Result<std::int64_t> storage_blockchain_height(api::StorageId storage_id) {
    TRY_RESULT(storage_ref, to_storage_ref(storage_id));
    return storage_ref->get_height();
  }
  td::Result<api::StorageUpdates> storage_blockchain_apply_block(api::StorageId storage_id, td::Slice block) {
    TRY_RESULT(storage_ref, to_storage_ref(storage_id));
    TRY_RESULT(updates, storage_ref->apply_block(block));
    auto fixed_updates = td::transform(updates.updates, [&](auto update) {
      auto public_key_id = from_public_key(update.first.public_key.as_slice()).move_as_ok();
      return std::make_pair(public_key_id, std::move(update.second));
    });
    return api::StorageUpdates{std::move(fixed_updates)};
  }
  td::Result<api::Ok> storage_blockchain_add_proof(api::StorageId storage_id, td::Slice proof,
                                                   td::Span<std::string> keys) {
    TRY_RESULT(storage_ref, to_storage_ref(storage_id));
    TRY_STATUS(storage_ref->add_proof(proof, keys));
    return api::Ok();
  }
  td::Result<api::StorageBlockchainState> storage_get_blockchain_state(api::StorageId storage_id) {
    TRY_RESULT(storage_ref, to_storage_ref(storage_id));
    auto state = storage_ref->get_blockchain_state();
    return api::StorageBlockchainState{state.next_block, state.need_proofs};
  }

  td::Result<GroupStateRef> to_group_state(const api::CallState &call_state) {
    GroupState group_state;
    group_state.external_permissions = GroupParticipantFlags::AddUsers | GroupParticipantFlags::RemoveUsers;
    for (auto &participant : call_state.participants) {
      TRY_RESULT(public_key, to_public_key(participant.public_key_id));
      group_state.participants.push_back(
          GroupParticipant{participant.user_id, participant.permissions & 3, public_key, 0});
    }
    return std::make_shared<GroupState>(std::move(group_state));
  }
  td::Result<api::CallState> to_call_state(const GroupState &group_state) {
    api::CallState call_state;
    for (auto &participant : group_state.participants) {
      auto public_key_id = from_public_key(participant.public_key.to_secure_string()).move_as_ok();
      call_state.participants.push_back(
          api::CallParticipant{participant.user_id, public_key_id, participant.flags & 3});
    }
    return call_state;
  }

  td::Result<api::Bytes> call_create_zero_block(api::PrivateKeyId private_key_id, const api::CallState &initial_state) {
    TRY_RESULT(private_key_ref, to_private_key_with_mnemonic(private_key_id));
    TRY_RESULT(group_state, to_group_state(initial_state));
    return Call::create_zero_block(private_key_ref.to_private_key(), group_state);
  }
  tde2e_api::Result<std::string> call_create_self_add_block(api::PrivateKeyId private_key_id, td::Slice previous_block,
                                                            const tde2e_api::CallParticipant &self) {
    TRY_RESULT(private_key_ref, to_private_key_with_mnemonic(private_key_id));
    TRY_RESULT(public_key, to_public_key(self.public_key_id));
    return Call::create_self_add_block(private_key_ref.to_private_key(), previous_block,
                                       tde2e_core::GroupParticipant{self.user_id, 3, public_key, 0});
  }

  td::Result<api::CallId> call_create(api::UserId user_id, api::PrivateKeyId private_key_id, td::Slice last_block) {
    TRY_RESULT(private_key_ref, to_private_key_with_mnemonic(private_key_id));

    TRY_RESULT(call, Call::create(user_id, private_key_ref.to_private_key(), last_block));
    return container_.emplace<Call>(std::move(call));
  }
  td::Result<api::Bytes> call_describe(api::CallId call_id) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    td::StringBuilder sb;
    sb << *call_ref;
    return sb.as_cslice().str();
  }

  td::Result<api::Bytes> call_create_change_state_block(api::CallId call_id, const api::CallState &new_state) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    TRY_RESULT(group_state, to_group_state(new_state));
    return call_ref->build_change_state(group_state);
  }
  td::Result<api::SecureBytes> call_export_shared_key(api::CallId call_id) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    TRY_RESULT(shared_key, call_ref->shared_key());
    return shared_key.as_slice().str();
  }
  td::Result<api::Bytes> call_encrypt(api::CallId call_id, api::CallChannelId channel_id, td::Slice message) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    return call_ref->encrypt(channel_id, message);
  }
  td::Result<api::SecureBytes> call_decrypt(api::CallId call_id, api::UserId user_id, api::CallChannelId channel_id,
                                            td::Slice message) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    return call_ref->decrypt(user_id, channel_id, message);
  }

  td::Result<int> call_get_height(api::CallId call_id) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    return call_ref->get_height();
  }
  td::Result<api::CallState> call_apply_block(api::CallId call_id, td::Slice block) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    TRY_STATUS(call_ref->apply_block(block));
    TRY_RESULT(group_state, call_ref->get_group_state());
    return to_call_state(*group_state);
  }

  td::Result<api::CallState> call_get_state(api::CallId call_id) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    TRY_RESULT(group_state, call_ref->get_group_state());
    return to_call_state(*group_state);
  }

  td::Result<api::CallVerificationState> call_get_verification_state(api::CallId call_id) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    return call_ref->get_verification_state();
  }
  td::Result<api::CallVerificationState> call_receive_inbound_message(api::CallId call_id, td::Slice message) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    return call_ref->receive_inbound_message(message);
  }
  td::Result<std::vector<std::string>> call_pull_outbound_messages(api::CallId call_id) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    return call_ref->pull_outbound_messages();
  }

  td::Result<api::CallVerificationWords> call_get_verification_words(api::CallId call_id) {
    TRY_RESULT(call_ref, to_call_ref(call_id));
    return call_ref->get_verification_words();
  }
  td::Result<api::PublicKey> to_public_key_api(api::AnyKeyId key_id) const {
    TRY_RESULT(public_key, to_public_key(key_id));
    return public_key.to_secure_string().as_slice().str();
  }

 private:
  using Key = std::variant<td::SecureString, PublicKey, PrivateKeyWithMnemonic>;
  using Handshake = std::variant<QRHandshakeAlice, QRHandshakeBob>;
  Container<TypeInfo<Key, false, true>, TypeInfo<Handshake, true, true>, TypeInfo<EncryptedStorage, true, false>,
            TypeInfo<Call, true, true>>
      container_;

  td::Result<PrivateKeyWithMnemonic> mnemonic_to_private_key(const Mnemonic &mnemonic) {
    auto decrypted_key = DecryptedKey(mnemonic);
    auto private_key = PrivateKeyWithMnemonic::from_private_key(mnemonic.to_private_key(), mnemonic.get_words());
    return private_key;
  }

  td::Result<PublicKey> to_public_key(api::AnyKeyId key_id) const {
    TRY_RESULT(key, container_.get_shared<Key>(key_id));
    return std::visit(
        td::overloaded([&](const PrivateKeyWithMnemonic &pk) -> td::Result<PublicKey> { return pk.to_public_key(); },
                       [&](const PublicKey &pk) -> td::Result<PublicKey> { return pk; },
                       [](const auto &) -> td::Result<PublicKey> {
                         return td::Status::Error(static_cast<int>(api::ErrorCode::InvalidInput),
                                                  "key_id doesn't contain public key");
                       }),
        *key);
  }

  td::Result<PrivateKeyWithMnemonic> to_private_key_with_mnemonic(api::AnyKeyId key_id) const {
    TRY_RESULT(key, container_.get_shared<Key>(key_id));
    TRY_RESULT(ref, convert<PrivateKeyWithMnemonic>(std::move(key)));
    return *ref;
  }

  td::Result<SecretRef> to_secret_ref(api::AnyKeyId key_id) const {
    TRY_RESULT(key, container_.get_shared<Key>(key_id));
    return convert<td::SecureString>(std::move(key));
  }

  td::Result<HandshakeAliceRef> to_handshake_alice_ref(api::HandshakeId alice_handshake_id) {
    TRY_RESULT(handshake, container_.get_unique<Handshake>(alice_handshake_id));
    return convert<QRHandshakeAlice>(std::move(handshake));
  }
  td::Result<HandshakeBobRef> to_handshake_bob_ref(api::HandshakeId bob_handshake_id) {
    TRY_RESULT(handshake, container_.get_unique<Handshake>(bob_handshake_id));
    return convert<QRHandshakeBob>(std::move(handshake));
  }
  td::Result<StorageRef> to_storage_ref(api::StorageId storage_id) {
    return container_.get_unique<EncryptedStorage>(storage_id);
  }
  td::Result<CallRef> to_call_ref(api::CallId call_id) {
    return container_.get_unique<Call>(call_id);
  }
};

}  // namespace tde2e_core
namespace tde2e_api {
tde2e_core::KeyChain &get_default_keychain() {
  static tde2e_core::KeyChain keychain;
  return keychain;
}
td::Slice to_slice(std::string_view s) {
  if (s.empty()) {
    return td::Slice();
  }
  return td::Slice(s.data(), s.size());
}
Result<Ok> set_log_verbosity_level(int new_verbosity_level) {
  return get_default_keychain().set_log_verbosity_level(new_verbosity_level);
}
Result<PrivateKeyId> key_generate_private_key() {
  return get_default_keychain().generate_private_key();
}
Result<PrivateKeyId> key_generate_temporary_private_key() {
  return get_default_keychain().generate_temporary_private_key();
}
Result<PrivateKeyId> key_derive_secret(PrivateKeyId key_id, Slice tag) {
  return get_default_keychain().derive_secret(key_id, to_slice(tag));
}
Result<Bytes> key_to_encrypted_private_key(PrivateKeyId key_id, SymmetricKeyId secret_id) {
  return get_default_keychain().to_encrypted_private_key(key_id, secret_id);
}
Result<PrivateKeyId> key_from_encrypted_private_key(Slice encrypted_key, SymmetricKeyId secret_id) {
  return get_default_keychain().from_encrypted_private_key(to_slice(encrypted_key), secret_id);
}
Result<SymmetricKeyId> key_from_bytes(SecureSlice secret) {
  return get_default_keychain().from_bytes(to_slice(secret));
}
Result<Bytes> key_to_encrypted_private_key_internal(PrivateKeyId key_id, SymmetricKeyId secret_id) {
  return get_default_keychain().to_encrypted_private_key_internal(key_id, secret_id);
}
Result<PrivateKeyId> key_from_encrypted_private_key_internal(Slice encrypted_key, SymmetricKeyId secret_id) {
  return get_default_keychain().from_encrypted_private_key_internal(to_slice(encrypted_key), secret_id);
}

Result<PublicKeyId> key_from_public_key(Slice public_key) {
  return get_default_keychain().from_public_key(to_slice(public_key));
}

Result<PrivateKeyId> key_from_ecdh(PrivateKeyId key_id, PublicKeyId other_public_key_id) {
  return get_default_keychain().from_ecdh(key_id, other_public_key_id);
}

Result<PublicKey> key_to_public_key(PrivateKeyId key_id) {
  return get_default_keychain().to_public_key_api(key_id);
}

Result<SecureBytes> key_to_words(PrivateKeyId key_id) {
  return get_default_keychain().to_words(key_id);
}
Result<PrivateKeyId> key_from_words(SecureSlice words) {
  return get_default_keychain().from_words(to_slice(words));
}
Result<Int512> key_sign(PrivateKeyId key, Slice data) {
  return get_default_keychain().sign(key, to_slice(data));
}
Result<Ok> key_destroy(AnyKeyId key_id) {
  TRY_STATUS(get_default_keychain().destroy(key_id));
  return Ok();
}
Result<Ok> key_destroy_all() {
  TRY_STATUS(get_default_keychain().destroy({}));
  return Ok();
}

Result<EncryptedMessageForMany> encrypt_message_for_many(const std::vector<SymmetricKeyId> &key_ids,
                                                         SecureSlice message) {
  return get_default_keychain().encrypt_message_for_many(std::move(key_ids), to_slice(message));
}
Result<SecureBytes> decrypt_message_for_many(SymmetricKeyId key_id, Slice encrypted_header, Slice encrypted_message) {
  return get_default_keychain().decrypt_message_for_many(key_id, to_slice(encrypted_header),
                                                         to_slice(encrypted_message));
}
Result<Bytes> encrypt_message_for_one(SymmetricKeyId key_id, SecureSlice message) {
  return get_default_keychain().encrypt_message_for_one(key_id, to_slice(message));
}
Result<SecureBytes> decrypt_message_for_one(SymmetricKeyId key_id, Slice encrypted_message) {
  return get_default_keychain().decrypt_message_for_one(key_id, to_slice(encrypted_message));
}
Result<EncryptedMessageForMany> re_encrypt_message_for_many(SymmetricKeyId decrypt_key_id,
                                                            const std::vector<SymmetricKeyId> &encrypt_key_ids,
                                                            Slice encrypted_header, Slice encrypted_message) {
  return get_default_keychain().re_encrypt_message_for_many(decrypt_key_id, std::move(encrypt_key_ids),
                                                            to_slice(encrypted_header), to_slice(encrypted_message));
}

Result<HandshakeId> handshake_create_for_bob(UserId bob_user_id, PrivateKeyId bob_private_key_id) {
  return get_default_keychain().handshake_create_for_bob(bob_user_id, bob_private_key_id);
}
Result<Bytes> handshake_bob_send_start(HandshakeId bob_handshake_id) {
  return get_default_keychain().handshake_bob_send_start(bob_handshake_id);
}
Result<HandshakeId> handshake_create_for_alice(UserId alice_user_id, PrivateKeyId alice_private_key_id,
                                               UserId bob_user_id, const PublicKey &bob_public_key, Slice start) {
  return get_default_keychain().handshake_create_for_alice(alice_user_id, alice_private_key_id, bob_user_id,
                                                           to_slice(bob_public_key), to_slice(start));
}
Result<Bytes> handshake_alice_send_accept(HandshakeId alice_handshake_id) {
  return get_default_keychain().handshake_alice_send_accept(alice_handshake_id);
}
Result<Bytes> handshake_bob_receive_accept_send_finish(HandshakeId bob_handshake_id, UserId alice_id,
                                                       const PublicKey &alice_public_key, Slice accept) {
  return get_default_keychain().handshake_bob_receive_accept_send_finish(bob_handshake_id, alice_id,
                                                                         to_slice(alice_public_key), to_slice(accept));
}
Result<Bytes> handshake_start_id(Slice start) {
  return get_default_keychain().handshake_get_start_id(to_slice(start));
}
Result<Ok> handshake_alice_receive_finish(HandshakeId alice_handshake_id, Slice finish) {
  return get_default_keychain().handshake_alice_receive_finish(alice_handshake_id, to_slice(finish));
}
Result<SymmetricKeyId> handshake_get_shared_key_id(HandshakeId handshake_id) {
  return get_default_keychain().handshake_get_shared_key_id(handshake_id);
}
Result<Ok> handshake_destroy(HandshakeId handshake_id) {
  return get_default_keychain().handshake_destroy(handshake_id);
}
Result<Ok> handshake_destroy_all() {
  return get_default_keychain().handshake_destroy({});
}

Result<LoginId> login_create_for_bob() {
  return get_default_keychain().login_create_for_bob();
}
Result<Bytes> login_bob_send_start(LoginId bob_login_id) {
  return get_default_keychain().login_bob_send_start(bob_login_id);
}
Result<Bytes> login_create_for_alice(UserId alice_user_id, PrivateKeyId alice_private_key_id, Slice start) {
  return get_default_keychain().login_create_for_alice(alice_user_id, alice_private_key_id, to_slice(start));
}
Result<PrivateKeyId> login_finish_for_bob(LoginId bob_login_id, UserId alice_user_id, const PublicKey &alice_public_key,
                                          Slice data) {
  return get_default_keychain().login_finish_for_bob(bob_login_id, alice_user_id, alice_public_key, to_slice(data));
}
Result<Ok> login_destroy(LoginId login_id) {
  return get_default_keychain().login_destroy(login_id);
}
Result<Ok> login_destroy_all() {
  return get_default_keychain().login_destroy_all();
}

Result<StorageId> storage_create(PrivateKeyId key_id, Slice last_block) {
  return get_default_keychain().storage_create(key_id, to_slice(last_block));
}
Result<Ok> storage_destroy(StorageId storage_id) {
  return get_default_keychain().storage_destroy(storage_id);
}
Result<Ok> storage_destroy_all() {
  return get_default_keychain().storage_destroy({});
}
template <class T>
Result<UpdateId> storage_update_contact(StorageId storage_id, PublicKeyId key, SignedEntry<T> signed_entry) {
  return get_default_keychain().storage_update_contact(storage_id, key, std::move(signed_entry));
}
template <class T>
Result<SignedEntry<T>> storage_sign_entry(PrivateKeyId key, Entry<T> entry) {
  return get_default_keychain().storage_sign_entry(key, std::move(entry));
}
Result<std::optional<Contact>> storage_get_contact(StorageId storage_id, PublicKeyId key) {
  return get_default_keychain().storage_get_contact(storage_id, key);
}
Result<std::optional<Contact>> storage_get_contact_optimistic(StorageId storage_id, PublicKeyId key) {
  return get_default_keychain().storage_get_contact_optimistic(storage_id, key);
}
Result<std::int64_t> storage_blockchain_height(StorageId storage_id) {
  return get_default_keychain().storage_blockchain_height(storage_id);
}
Result<StorageUpdates> storage_blockchain_apply_block(StorageId storage_id, Slice block) {
  return get_default_keychain().storage_blockchain_apply_block(storage_id, to_slice(block));
}
Result<Ok> storage_blockchain_add_proof(StorageId storage_id, Slice proof, const std::vector<std::string> &keys) {
  return get_default_keychain().storage_blockchain_add_proof(storage_id, to_slice(proof), keys);
}
Result<StorageBlockchainState> storage_get_blockchain_state(StorageId storage_id) {
  return get_default_keychain().storage_get_blockchain_state(storage_id);
}

Result<Bytes> call_create_zero_block(PrivateKeyId private_key_id, const CallState &initial_state) {
  return get_default_keychain().call_create_zero_block(private_key_id, initial_state);
}
Result<Bytes> call_create_self_add_block(PrivateKeyId private_key_id, Slice previous_block,
                                         const CallParticipant &self) {
  return get_default_keychain().call_create_self_add_block(private_key_id, to_slice(previous_block), self);
}
Result<CallId> call_create(UserId user_id, PrivateKeyId private_key_id, Slice last_block) {
  return get_default_keychain().call_create(user_id, private_key_id, to_slice(last_block));
}
Result<std::string> call_describe(CallId call_id) {
  return get_default_keychain().call_describe(call_id);
}
Result<std::string> call_describe_block(Slice block_slice) {
  bool is_server = tde2e_core::Blockchain::is_from_server(to_slice(block_slice));
  TRY_RESULT(block_str, tde2e_core::Blockchain::from_any_to_local(std::string(block_slice)));
  td::TlParser parser(block_str);
  auto magic = parser.fetch_int();
  if (magic != td::e2e_api::e2e_chain_block::ID) {
    return td::Status::Error("Wrong magic");
  }
  auto block = td::e2e_api::e2e_chain_block::fetch(parser);
  parser.fetch_end();
  TRY_STATUS(parser.get_status());
  return PSTRING() << (is_server ? "Server:" : "Local:") << to_string(block);
}
Result<std::string> call_describe_message(Slice broadcast_slice) {
  bool is_server = tde2e_core::Blockchain::is_from_server(to_slice(broadcast_slice));
  TRY_RESULT(broadcast_str, tde2e_core::Blockchain::from_any_to_local(std::string(broadcast_slice)));

  td::TlParser parser(broadcast_str);
  auto broadcast = td::e2e_api::e2e_chain_GroupBroadcast::fetch(parser);
  parser.fetch_end();
  TRY_STATUS(parser.get_status());
  return PSTRING() << (is_server ? "Server:" : "Local:") << to_string(broadcast);
}
Result<Bytes> call_create_change_state_block(CallId call_id, const CallState &new_state) {
  return get_default_keychain().call_create_change_state_block(call_id, new_state);
}
Result<SecureBytes> call_export_shared_key(CallId call_id) {
  return get_default_keychain().call_export_shared_key(call_id);
}
Result<Bytes> call_encrypt(CallId call_id, CallChannelId channel_id, SecureSlice message) {
  return get_default_keychain().call_encrypt(call_id, channel_id, to_slice(message));
}
Result<SecureBytes> call_decrypt(CallId call_id, UserId user_id, CallChannelId channel_id, Slice message) {
  return get_default_keychain().call_decrypt(call_id, user_id, channel_id, to_slice(message));
}
Result<int> call_get_height(CallId call_id) {
  return get_default_keychain().call_get_height(call_id);
}
Result<CallState> call_apply_block(CallId call_id, Slice block) {
  return get_default_keychain().call_apply_block(call_id, to_slice(block));
}
Result<CallState> call_get_state(CallId call_id) {
  return get_default_keychain().call_get_state(call_id);
}
Result<CallVerificationState> call_get_verification_state(CallId call_id) {
  return get_default_keychain().call_get_verification_state(call_id);
}
Result<CallVerificationState> call_receive_inbound_message(CallId call_id, Slice message) {
  return get_default_keychain().call_receive_inbound_message(call_id, to_slice(message));
}
Result<std::vector<Bytes>> call_pull_outbound_messages(CallId call_id) {
  return get_default_keychain().call_pull_outbound_messages(call_id);
}

Result<CallVerificationWords> call_get_verification_words(CallId call_id) {
  return get_default_keychain().call_get_verification_words(call_id);
}
Result<Ok> call_destroy(CallId call_id) {
  return get_default_keychain().call_destroy(call_id);
}
Result<Ok> call_destroy_all() {
  return get_default_keychain().call_destroy({});
}

// instantiations of templates
template Result<UpdateId> storage_update_contact<UserId>(StorageId storage_id, PublicKeyId key,
                                                         SignedEntry<UserId> signed_entry);

template Result<SignedEntry<UserId>> storage_sign_entry<UserId>(PrivateKeyId key, Entry<UserId> entry);

template Result<UpdateId> storage_update_contact<Name>(StorageId storage_id, PublicKeyId key,
                                                       SignedEntry<Name> signed_entry);

template Result<SignedEntry<Name>> storage_sign_entry<Name>(PrivateKeyId key, Entry<Name> entry);

template Result<UpdateId> storage_update_contact<PhoneNumber>(StorageId storage_id, PublicKeyId key,
                                                              SignedEntry<PhoneNumber> signed_entry);

template Result<SignedEntry<PhoneNumber>> storage_sign_entry<PhoneNumber>(PrivateKeyId key, Entry<PhoneNumber> entry);

template Result<UpdateId> storage_update_contact<EmojiNonces>(StorageId storage_id, PublicKeyId key,
                                                              SignedEntry<EmojiNonces> signed_entry);

template Result<SignedEntry<EmojiNonces>> storage_sign_entry<EmojiNonces>(PrivateKeyId key, Entry<EmojiNonces> entry);

template Result<UpdateId> storage_update_contact<ContactState>(StorageId storage_id, PublicKeyId key,
                                                               SignedEntry<ContactState> signed_entry);

template Result<SignedEntry<ContactState>> storage_sign_entry<ContactState>(PrivateKeyId key,
                                                                            Entry<ContactState> entry);

}  // namespace tde2e_api
