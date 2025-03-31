//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/EncryptedStorage.h"

#include "td/e2e/Blockchain.h"

#include "td/telegram/e2e_api.hpp"

#include "td/utils/crypto.h"
#include "td/utils/logging.h"
#include "td/utils/overloaded.h"
#include "td/utils/tl_parsers.h"

namespace tde2e_core {

api::UserId from_tl(td::int64 user_id) {
  return user_id;
}

api::Name from_tl(td::e2e_api::e2e_personalName &name) {
  return api::Name{name.first_name_, name.last_name_};
}

api::UserId from_tl(td::e2e_api::e2e_personalUserId &user_id) {
  return user_id.user_id_;
}

api::PhoneNumber from_tl(td::e2e_api::e2e_personalPhoneNumber &phone_number) {
  return api::PhoneNumber{phone_number.phone_number_};
}

api::EmojiNonces from_tl(td::e2e_api::e2e_personalEmojiNonces &emoji_nonces) {
  using Flags = td::e2e_api::e2e_personalEmojiNonces;
  api::EmojiNonces res;
  if ((emoji_nonces.flags_ & Flags::SELF_NONCE_MASK) != 0) {
    res.self_nonce = from_td(emoji_nonces.self_nonce_);
  }
  return res;
}

api::ContactState from_tl(td::e2e_api::e2e_personalContactState &contact_state) {
  return api::ContactState{contact_state.is_contact_ ? api::ContactState::Contact : api::ContactState::NotContact};
}

void init(api::Contact &contact, api::Entry<api::UserId> user_id) {
  contact.o_user_id = user_id;
}
void init(api::Contact &contact, api::Entry<api::Name> name) {
  contact.o_name = std::move(name);
}
void init(api::Contact &contact, api::Entry<api::PhoneNumber> phone_number) {
  contact.o_phone_number = std::move(phone_number);
}
void init(api::Contact &contact, api::Entry<api::EmojiNonces> emoji_nonces) {
  contact.emoji_nonces = std::move(emoji_nonces);
}
void init(api::Contact &contact, api::Entry<api::ContactState> contact_state) {
  contact.contact_state = std::move(contact_state);
}

api::Contact from_tl(td::e2e_api::e2e_valueContactByPublicKey &value) {
  api::Contact contact;
  for (auto &entry : value.entries_) {
    td::e2e_api::downcast_call(*entry->personal_, [&](auto &tl_value) {
      auto entry_value = from_tl(tl_value);
      using ValueT = decltype(entry_value);
      init(contact, api::Entry<ValueT>{api::Entry<ValueT>::Self, static_cast<td::uint32>(entry->signed_at_),
                                       std::move(entry_value)});
    });
  }
  return contact;
}

bool reduce(api::Entry<api::EmojiNonces> &a, const api::Entry<api::EmojiNonces> &b) {
  // do not care about timestamp, first write always win
  // TODO: handle source
  auto &nonces = a.value;
  const auto &other_nonces = b.value;

  bool changed = false;

  if (!nonces.self_nonce && other_nonces.self_nonce) {
    nonces.self_nonce = other_nonces.self_nonce;
    changed = true;
  }
  if (!nonces.contact_nonce_hash && other_nonces.contact_nonce_hash) {
    nonces.contact_nonce_hash = other_nonces.contact_nonce_hash;
    changed = true;
  }
  if (!nonces.contact_nonce && other_nonces.contact_nonce) {
    nonces.contact_nonce = other_nonces.contact_nonce;
    changed = true;
  }
  return changed;
}

template <class T>
bool reduce(api::Entry<T> &a, const api::Entry<T> &b) {
  if (a.timestamp > b.timestamp) {
    a = std::move(b);
    return false;
  }
  // TODO: handle source
  return false;
}

template <class T>
bool reduce(api::Entry<T> &a, const std::optional<api::Entry<T>> &b) {
  if (!b) {
    return false;
  }
  return reduce(a, *b);
}

template <class T>
bool reduce(std::optional<api::Entry<T>> &a, const std::optional<api::Entry<T>> &b) {
  if (!a) {
    a = b;
    return static_cast<bool>(b);
  }
  if (!b) {
    return false;
  }
  return reduce(*a, *b);
}

bool reduce(Update &a, const Update &b) {
  bool changed = false;
  changed = reduce(a.o_user_id, b.o_user_id);
  changed = reduce(a.o_name, b.o_name);
  changed = reduce(a.o_phone_number, b.o_phone_number);
  changed = reduce(a.o_emoji_nonces, b.o_emoji_nonces);
  changed = reduce(a.o_contact_state, b.o_contact_state);
  return changed;
}

std::optional<Value> apply_update(const std::optional<Value> &o_value, const Update &update) {
  auto value = o_value.value_or(Value());
  bool changed = false;
  changed |= reduce(value.o_name, update.o_name);
  changed |= reduce(value.o_phone_number, update.o_phone_number);
  changed |= reduce(value.o_user_id, update.o_user_id);
  changed |= reduce(value.emoji_nonces, update.o_emoji_nonces);
  changed |= reduce(value.contact_state, update.o_contact_state);
  if (changed) {
    return value;
  }
  return std::nullopt;
}

td::Status validate(const api::EmojiNonces &nonces) {
  if (nonces.contact_nonce && !nonces.self_nonce) {
    return td::Status::Error("Receive contact_nonce BEFORE self_nonce");
  }
  if (nonces.contact_nonce && !nonces.contact_nonce_hash) {
    return td::Status::Error("Receive contact_nonce BEFORE concat_nonce_hash");
  }
  if (nonces.contact_nonce) {
    auto &contact_nonce = nonces.contact_nonce.value();
    api::Int256 contact_nonce_hash;
    td::sha256(td::Slice(contact_nonce.data(), contact_nonce.size()),
               td::MutableSlice(contact_nonce_hash.data(), contact_nonce_hash.size()));

    if (contact_nonce_hash != nonces.contact_nonce_hash.value()) {
      return td::Status::Error("Invalid concat_nonce (hash mismatch)");
    }
  }
  return td::Status::OK();
}

td::Result<EncryptedStorage::UpdateId> EncryptedStorage::update(Key key, Update update) {
  LOG(INFO) << "Update [receive] " << key << " " << update;

  auto update_id = ++next_update_id_;
  auto it = updates_.find(key);
  if (it == updates_.end()) {
    // create pending update (original value is unknown)
    updates_.emplace(key, UpdateInfo{{update_id}, std::move(update), {}});
    LOG(INFO) << "Update [delay] " << key << " " << update;
    return update_id;
  }

  auto &update_info = it->second;
  reduce(update_info.update, update);
  update_info.update_ids.emplace_back(update_id);
  LOG(INFO) << "Update [reduce] " << key << " " << update_info.update;

  if (update_info.o_new_value && !reapply_update(update_info, std::move(update_info.o_new_value))) {
    LOG(INFO) << "Update [drop] " << key << " " << update;
    updates_.erase(it);
  }
  return update_id;
}

td::Result<std::optional<Value>> EncryptedStorage::get(Key key, bool optimistic) {
  auto it = partial_key_value_.find(key);
  if (it != partial_key_value_.end()) {
    if (optimistic) {
      auto update_it = updates_.find(key);
      if (update_it != updates_.end()) {
        CHECK(update_it->second.o_new_value);
        return *update_it->second.o_new_value;
      }
    }
    return it->second;
  }
  return td::Status::Error("NEED_PROOF");
}

td::int64 EncryptedStorage::get_height() const {
  return blockchain_.get_height();
}

td::Result<EncryptedStorage::KeyValueUpdates> EncryptedStorage::apply_block(td::Slice block) {
  TRY_RESULT(changes, blockchain_.try_apply_block(block));
  KeyValueUpdates updates;
  for (auto &change : changes) {
    bool skip = false;
    td::Result<std::pair<Key, std::optional<Value>>> r_p;
    std::visit(td::overloaded([&](ChangeNoop &noop) {},
                              [&](ChangeSetValue &set_value) { r_p = parse(set_value.key, set_value.value); },
                              [&](ChangeSetGroupState &) { skip = true; }, [&](ChangeSetSharedKey &) { skip = true; }),
               change.value);
    if (skip) {
      continue;
    }
    if (r_p.is_error()) {
      LOG(ERROR) << "BUG! change from blockchain is ignored: " << r_p.error();
      continue;
    }
    auto p = r_p.move_as_ok();
    updates.updates.emplace_back(p.first, p.second);
    sync_entry(std::move(p.first), std::move(p.second), true);
  }
  return updates;
}

td::Status EncryptedStorage::add_proof(td::Slice proof, td::Span<std::string> keys) {
  TRY_STATUS(blockchain_.add_proof(proof));
  // sync keys
  for (const auto &key : keys) {
    auto r_value = blockchain_.get_value(key);
    if (r_value.is_error()) {
      LOG(ERROR) << "Failed to get value from proof " << r_value.error();
      continue;
    }

    auto raw_value = r_value.move_as_ok();
    auto r_p = parse(key, raw_value);
    if (r_p.is_error()) {
      LOG(ERROR) << "BUG! value from blockchain is ignored: " << r_p.error();
      continue;
    }

    auto p = r_p.move_as_ok();
    sync_entry(std::move(p.first), std::move(p.second));
  }

  return td::Status::OK();
}

EncryptedStorage::BlockchainState EncryptedStorage::get_blockchain_state() {
  //TODO add indexes

  // check if some values are unknown
  BlockchainState state;
  std::vector<Change> changes;
  for (auto &update : updates_) {
    if (!update.second.o_new_value) {
      state.need_proofs.emplace_back(encrypt_key(update.first));
    } else {
      changes.emplace_back(
          Change{ChangeSetValue{encrypt_key(update.first), encrypt_value(update.second.o_new_value.value())}});
    }
  }
  if (!changes.empty()) {
    state.next_block = blockchain_.build_block(changes, private_key_).move_as_ok();
  }
  return state;
}

EncryptedStorage::KeyValueUpdates EncryptedStorage::pull_updates() {
  return std::move(pending_key_value_updates_);
}

td::Result<std::pair<Key, std::optional<Value>>> EncryptedStorage::parse(td::Slice raw_key, td::Slice raw_value) {
  TRY_RESULT(key, decrypt_key(raw_key));
  TRY_RESULT(value, decrypt_value(raw_value));
  return std::make_pair(std::move(key), std::move(value));
}

void EncryptedStorage::sync_entry(Key key, std::optional<Value> value, bool rewrite) {
  LOG(INFO) << "Sync [new] " << key << " " << value;
  auto p = partial_key_value_.try_emplace(key, std::move(value));
  if (!p.second) {
    if (rewrite) {
      p.first->second = std::move(value);
    } else {
      // CHECK(p.first->second == value);
    }
  }

  if (p.second || rewrite) {
    auto it = updates_.find(key);
    if (it != updates_.end()) {
      auto &update_info = it->second;
      if (!reapply_update(update_info, std::move(value))) {
        LOG(INFO) << "Update [drop] " << key << " " << update_info.update;
        updates_.erase(it);
      }
    }
  }
}

bool EncryptedStorage::reapply_update(UpdateInfo &update_info, const std::optional<Value> &value) {
  auto o_new_value = apply_update(value, update_info.update);
  if (o_new_value) {
    update_info.o_new_value = std::move(o_new_value);
    LOG(INFO) << "Update [reapply] value=" << update_info.o_new_value;
    return true;
  }

  // TODO: complete updates
  return false;
}

std::string EncryptedStorage::encrypt_key(const Key &key) const {
  td::string res(32, '\0');
  auto iv = secret_for_key_.as_slice().substr(32, 32).str();
  td::aes_cbc_encrypt(secret_for_key_.as_slice().substr(0, 32), iv, key.public_key.as_slice(), res);
  return res;
}

td::Result<Key> EncryptedStorage::decrypt_key(td::Slice raw_key) const {
  if (raw_key.size() != 32) {
    return td::Status::Error("Invalid key length");
  }
  td::UInt256 key;
  auto iv = secret_for_key_.as_slice().substr(32, 32).str();
  td::aes_cbc_decrypt(secret_for_key_.as_slice().substr(0, 32), iv, raw_key, key.as_mutable_slice());
  return Key{key};
}

std::string EncryptedStorage::encrypt_value(const Value &value) const {
  return MessageEncryption::encrypt_data(serialize_boxed(*to_tl(value)), secret_for_value_).as_slice().str();
}

td::Result<std::optional<Value>> EncryptedStorage::decrypt_value(td::Slice raw_value) const {
  if (raw_value.empty()) {
    return std::nullopt;
  }
  TRY_RESULT(decrypted_raw_value, MessageEncryption::decrypt_data(raw_value, secret_for_value_));
  td::TlParser parser(decrypted_raw_value);
  auto value_tl =
      td::e2e_api::move_object_as<td::e2e_api::e2e_valueContactByPublicKey>(td::e2e_api::e2e_Value::fetch(parser));
  parser.fetch_end();
  TRY_STATUS(parser.get_status());
  return from_tl(*value_tl);
}

}  // namespace tde2e_core
