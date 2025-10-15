//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/Blockchain.h"
#include "td/e2e/Container.h"
#include "td/e2e/e2e_api.h"
#include "td/e2e/MessageEncryption.h"
#include "td/e2e/utils.h"

#include "td/telegram/e2e_api.h"

#include "td/utils/base64.h"
#include "td/utils/common.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/UInt.h"

#include <map>
#include <optional>
#include <utility>

namespace td {

template <class T>
StringBuilder &operator<<(td::StringBuilder &sb, std::optional<T> const &opt) {
  if (opt.has_value()) {
    sb << "Some{" << opt.value() << "}";
  } else {
    sb << "None";
  }
  return sb;
}

}  // namespace td

namespace tde2e_core {
namespace api = tde2e_api;
struct Update {
  std::optional<api::Entry<api::UserId>> o_user_id;
  std::optional<api::Entry<api::Name>> o_name;
  std::optional<api::Entry<api::PhoneNumber>> o_phone_number;

  std::optional<api::Entry<api::EmojiNonces>> o_emoji_nonces;
  std::optional<api::Entry<api::ContactState>> o_contact_state;
};

inline api::Int256 from_td(const td::UInt256 &value) {
  api::Int256 result;
  td::MutableSlice(result.data(), result.size()).copy_from(value.as_slice());
  return result;
}

inline api::Int512 from_td(const td::UInt512 &value) {
  api::Int512 result;
  td::MutableSlice(result.data(), result.size()).copy_from(value.as_slice());
  return result;
}
}  // namespace tde2e_core

namespace tde2e_api {
using Update = tde2e_core::Update;

inline td::UInt256 to_td(const Int256 &value) {
  td::UInt256 result;
  result.as_mutable_slice().copy_from(td::Slice(value.data(), value.size()));
  return result;
}
inline td::UInt512 to_td(const Int512 &value) {
  td::UInt512 result;
  result.as_mutable_slice().copy_from(td::Slice(value.data(), value.size()));
  return result;
}
inline auto to_tl(const UserId &entry) {
  return td::e2e_api::make_object<td::e2e_api::e2e_personalUserId>(entry);
}
inline auto to_tl(const Name &entry) {
  return td::e2e_api::make_object<td::e2e_api::e2e_personalName>(entry.first_name, entry.last_name);
}
inline auto to_tl(const PhoneNumber &entry) {
  return td::e2e_api::make_object<td::e2e_api::e2e_personalPhoneNumber>(entry.phone_number);
}

inline auto to_tl(const EmojiNonces &entry) {
  using TlType = td::e2e_api::e2e_personalEmojiNonces;
  td::int32 flags = TlType::SELF_NONCE_MASK * static_cast<bool>(entry.self_nonce) +
                    TlType::CONTACT_NONCE_MASK * static_cast<bool>(entry.contact_nonce) +
                    TlType::CONTACT_NONCE_MASK * static_cast<bool>(entry.contact_nonce_hash);
  return td::e2e_api::make_object<TlType>(flags, to_td(entry.self_nonce.value_or(Int256{})),
                                          to_td(entry.contact_nonce_hash.value_or(Int256{})),
                                          to_td(entry.contact_nonce.value_or(Int256{})));
}

inline auto to_tl(const ContactState &entry) {
  // TODO
  return td::e2e_api::make_object<td::e2e_api::e2e_personalContactState>(0, false);
}

template <class T>
auto to_tl(const Entry<T> &entry) {
  return td::e2e_api::make_object<td::e2e_api::e2e_personalOnClient>(entry.timestamp, to_tl(entry.value));
}

template <class T>
auto to_tl(const SignedEntry<T> &entry) {
  return td::e2e_api::make_object<td::e2e_api::e2e_personalOnServer>(to_td(entry.signature), entry.timestamp,
                                                                     to_tl(entry.value));
}
inline auto to_tl(const Contact &contact) {
  std::vector<td::e2e_api::object_ptr<td::e2e_api::e2e_personalOnClient>> entries;
  if (contact.o_user_id) {
    entries.push_back(to_tl(*contact.o_user_id));
  }
  if (contact.o_name) {
    entries.push_back(to_tl(*contact.o_name));
  }
  if (contact.o_phone_number) {
    entries.push_back(to_tl(*contact.o_phone_number));
  }
  entries.push_back(to_tl(contact.emoji_nonces));
  entries.push_back(to_tl(contact.contact_state));
  return td::e2e_api::make_object<td::e2e_api::e2e_valueContactByPublicKey>(std::move(entries));
}

inline Update to_update(Entry<UserId> user_id) {
  Update result;
  result.o_user_id = std::move(user_id);
  return result;
}
inline Update to_update(Entry<Name> name) {
  Update result;
  result.o_name = std::move(name);
  return result;
}
inline Update to_update(Entry<PhoneNumber> phone_number) {
  Update result;
  result.o_phone_number = std::move(phone_number);
  return result;
}
inline Update to_update(Entry<EmojiNonces> emoji) {
  Update result;
  result.o_emoji_nonces = std::move(emoji);
  return result;
}
inline Update to_update(Entry<ContactState> contact_state) {
  Update result;
  result.o_contact_state = std::move(contact_state);
  return result;
}

inline td::StringBuilder &operator<<(td::StringBuilder &sb, const Name &entry) {
  return sb << "Name{" << entry.first_name << " " << entry.last_name << "}";
}
inline td::StringBuilder &operator<<(td::StringBuilder &sb, const PhoneNumber &entry) {
  return sb << "PhoneNumber{" << entry.phone_number << "}";
}
inline bool operator==(const Name &lhs, const Name &rhs) {
  return lhs.first_name == rhs.first_name && lhs.last_name == rhs.last_name;
}
inline td::StringBuilder &operator<<(td::StringBuilder &sb, const EmojiNonces &entry) {
  sb << "EmojiNonces{";
  bool f = false;
  if (entry.self_nonce) {
    sb << "SelfNonce";
    f = true;
  }
  if (entry.contact_nonce_hash) {
    if (f) {
      sb << "|";
    }
    sb << "TheirNonceHash";
    f = true;
  }
  if (entry.contact_nonce) {
    if (f) {
      sb << "|";
    }
    sb << "ContactNonce";
    f = true;
  }
  return sb << "}";
}
inline bool operator==(const PhoneNumber &lhs, const PhoneNumber &rhs) {
  return lhs.phone_number == rhs.phone_number;
}

inline td::StringBuilder &operator<<(td::StringBuilder &sb, const ContactState &entry) {
  switch (entry.state) {
    case ContactState::Unknown:
      return sb << "Unknown";
    case ContactState::Contact:
      return sb << "Contact";
    case ContactState::NotContact:
      return sb << "NotContact";
    default:
      UNREACHABLE();
  }
}
inline bool operator==(const ContactState &lhs, const ContactState &rhs) {
  return lhs.state == rhs.state;
}

template <class S>
td::StringBuilder &operator<<(td::StringBuilder &sb, const Entry<S> &entry) {
  sb << entry.value << "\t";
  switch (entry.source) {
    case Entry<S>::Self:
      sb << "[Self]";
      break;

    case Entry<S>::Server:
      sb << "[Server]";
      break;

    case Entry<S>::Contact:
      sb << "[Contact]";
      break;
    default:
      UNREACHABLE();
  }
  sb << "\tts=" << entry.timestamp;
  return sb;
}
template <class T>
bool operator==(const Entry<T> &lhs, const Entry<T> &rhs) {
  return true;
  //TODO(now)
  //  return lhs.source == rhs.source && lhs.value == rhs.value && lhs.timestamp == rhs.timestamp;
}

template <class S>
td::StringBuilder &operator<<(td::StringBuilder &sb, const SignedEntry<S> &entry) {
  sb << "[Signed]";
  sb << " ts=" << entry.timestamp;
  sb << " " << entry.value;
  return sb;
}
inline td::StringBuilder &operator<<(td::StringBuilder &sb, const Contact &contact) {
  sb << "\nContact{";
  auto p = [&](auto &value) {
    sb << "\n\t" << value;
  };
  auto op = [&](auto &o_value) {
    if (o_value) {
      p(*o_value);
    }
  };
  op(contact.o_user_id);
  op(contact.o_name);
  op(contact.o_phone_number);
  p(contact.emoji_nonces);
  p(contact.contact_state);
  return sb << "\n}";
}

inline bool operator==(const Contact &lhs, const Contact &rhs) {
  return lhs.generation == rhs.generation && lhs.o_name == rhs.o_name && lhs.o_phone_number == rhs.o_phone_number &&
         lhs.o_user_id == rhs.o_user_id && lhs.public_key == rhs.public_key && lhs.contact_state == rhs.contact_state &&
         lhs.emoji_nonces == rhs.emoji_nonces;
}
}  // namespace tde2e_api
namespace tde2e_core {
inline td::StringBuilder &operator<<(td::StringBuilder &sb, const Update &update) {
  sb << "\nUpdate{";
  auto p = [&](auto &value) {
    sb << "\n\t" << value;
  };
  auto op = [&](auto &o_value) {
    if (o_value) {
      p(*o_value);
    }
  };
  op(update.o_user_id);
  op(update.o_name);
  op(update.o_phone_number);
  op(update.o_emoji_nonces);
  op(update.o_contact_state);
  return sb << "\n}\n";
}
inline bool operator==(const Update &lhs, const Update &rhs) {
  return lhs.o_contact_state == rhs.o_contact_state && lhs.o_user_id == rhs.o_user_id &&
         lhs.o_phone_number == rhs.o_phone_number && lhs.o_emoji_nonces == rhs.o_emoji_nonces &&
         lhs.o_user_id == rhs.o_user_id;
}

struct KeyContactByPublicKey {
  td::UInt256 public_key{};

  KeyContactByPublicKey() = default;

  explicit KeyContactByPublicKey(td::UInt256 public_key) : public_key(public_key) {
  }

  bool operator<(const KeyContactByPublicKey &other) const {
    return public_key < other.public_key;
  }

  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const KeyContactByPublicKey &key) {
    return sb << "PubKey{" << td::base64_encode(key.public_key.as_slice()).substr(0, 8) << "}";
  }
};
using Key = KeyContactByPublicKey;
using Value = api::Contact;

// TODO:
// - delete value
struct EncryptedStorage {
  struct BlockchainState {
    std::string next_block;
    std::vector<std::string> need_proofs;
  };
  struct KeyValueUpdates {
    std::vector<std::pair<Key, std::optional<Value>>> updates;
  };
  using UpdateId = td::int64;

  static td::Result<EncryptedStorage> create(td::Slice last_block, PrivateKey pk) {
    auto public_key = pk.to_public_key();
    auto secret_for_key = MessageEncryption::hmac_sha512(pk.to_secure_string(), "EncryptedStorage::secret_for_key");
    auto secret_for_value = MessageEncryption::hmac_sha512(pk.to_secure_string(), "EncryptedStorage::secret_for_value");
    ClientBlockchain blockchain;
    if (last_block.empty()) {
      TRY_RESULT_ASSIGN(blockchain, ClientBlockchain::create_empty());
    } else {
      TRY_RESULT_ASSIGN(blockchain, ClientBlockchain::create_from_block(last_block, std::move(public_key)));
    }
    return EncryptedStorage(std::move(pk), std::move(secret_for_key), std::move(secret_for_value),
                            std::move(blockchain));
  }

  EncryptedStorage(PrivateKey pk, td::SecureString secret_for_key, td::SecureString secret_for_value,
                   ClientBlockchain blockchain)
      : private_key_(std::move(pk))
      , secret_for_key_(std::move(secret_for_key))
      , secret_for_value_(std::move(secret_for_value))
      , blockchain_(std::move(blockchain)) {
  }

  template <class T>
  td::Result<UpdateId> update(Key key, api::SignedEntry<T> signed_entry) {
    // verify signature
    TRY_STATUS(verify_signature(PublicKey::from_u256(key.public_key), *to_tl(signed_entry)));

    return update(
        key, to_update(api::Entry<T>{api::Entry<T>::Contact, signed_entry.timestamp, std::move(signed_entry.value)}));
  }

  template <class T>
  static td::Result<api::SignedEntry<T>> sign_entry(const PrivateKey &pk, api::Entry<T> entry) {
    api::SignedEntry<T> signed_entry;
    signed_entry.value = std::move(entry.value);
    TRY_RESULT(signature, sign(pk, *to_tl(signed_entry)));
    td::MutableSlice(signed_entry.signature.data(), signed_entry.signature.size()).copy_from(signature.to_slice());
    return signed_entry;
  }

  td::Result<std::optional<Value>> get(Key key, bool optimistic = false);

  // current blockchain height
  td::int64 get_height() const;
  // one should only apply blocks from server (TODO: signature from server?)
  td::Result<KeyValueUpdates> apply_block(td::Slice block);

  // proof must be from block of current height
  // after proof is applied
  // Keys are used as a hint
  td::Status add_proof(td::Slice proof, td::Span<std::string> keys);

  BlockchainState get_blockchain_state();
  KeyValueUpdates pull_updates();

 private:
  struct UpdateInfo {
    std::vector<UpdateId> update_ids;
    Update update;
    std::optional<Value> o_new_value;
  };

  std::map<Key, UpdateInfo> updates_;
  std::map<Key, std::optional<Value>> partial_key_value_;
  UpdateId next_update_id_{0};

  PrivateKey private_key_;
  td::SecureString secret_for_key_;
  td::SecureString secret_for_value_;

  ClientBlockchain blockchain_;

  KeyValueUpdates pending_key_value_updates_;

  td::Result<UpdateId> update(Key key, Update update);

  td::Result<std::pair<Key, std::optional<Value>>> parse(td::Slice raw_key, td::Slice raw_value);
  void sync_entry(Key key, std::optional<Value> value, bool rewrite = false);
  bool reapply_update(UpdateInfo &update_info, const std::optional<Value> &value);

  std::string encrypt_key(const Key &key) const;
  std::string encrypt_value(const Value &value) const;
  td::Result<Key> decrypt_key(td::Slice raw_key) const;
  td::Result<std::optional<Value>> decrypt_value(td::Slice raw_value) const;
};

}  // namespace tde2e_core
