//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/Trie.h"
#include "td/e2e/utils.h"

#include "td/telegram/e2e_api.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/optional.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/UInt.h"

#include <memory>
#include <variant>

namespace tde2e_core {

namespace e2e = td::e2e_api;

struct KeyValueHash {
  td::UInt256 hash{};
};

enum GroupParticipantFlags : td::int32 {
  AddUsers = 1 << 0,
  RemoveUsers = 1 << 1,
  SetValue = 1 << 2,
  AllPermissions = (1 << 3) - 1,
  IsParticipant = 1 << 30
};

struct GroupParticipant {
  td::int64 user_id{0};
  td::int32 flags{0};
  PublicKey public_key{};
  td::int32 version{0};
  bool add_users() const {
    return (flags & GroupParticipantFlags::AddUsers) != 0;
  }
  bool remove_users() const {
    return (flags & GroupParticipantFlags::RemoveUsers) != 0;
  }
  bool operator==(const GroupParticipant &other) const {
    return user_id == other.user_id && flags == other.flags && public_key == other.public_key &&
           version == other.version;
  }
  bool operator!=(const GroupParticipant &other) const {
    return !(other == *this);
  }

  static GroupParticipant from_tl(const td::e2e_api::e2e_chain_groupParticipant &participant);
  e2e::object_ptr<e2e::e2e_chain_groupParticipant> to_tl() const;
};

inline td::StringBuilder &operator<<(td::StringBuilder &sb, const GroupParticipant &part) {
  return sb << "(uid=" << part.user_id << ", flags=" << part.flags << ", pk=" << part.public_key
            << ", version=" << part.version << ")";
}

struct GroupState;
struct GroupSharedKey;
using GroupStateRef = std::shared_ptr<const GroupState>;
using GroupSharedKeyRef = std::shared_ptr<const GroupSharedKey>;

struct Permissions {
  td::int32 flags{0};
  bool may_add_users() const {
    return (flags & GroupParticipantFlags::AddUsers) != 0;
  }
  bool may_remove_users() const {
    return (flags & GroupParticipantFlags::RemoveUsers) != 0;
  }
  bool may_set_value() const {
    return (flags & GroupParticipantFlags::SetValue) != 0;
  }
  bool is_participant() const {
    return (flags & GroupParticipantFlags::IsParticipant) != 0;
  }
  bool may_change_shared_key() const {
    return is_participant() && (may_remove_users() || may_add_users());
  }
};

struct GroupState {
  std::vector<GroupParticipant> participants;
  td::int32 external_permissions{};
  bool empty() const {
    return participants.empty();
  }
  td::int32 version() const;
  td::Result<GroupParticipant> get_participant(td::int64 user_id) const;
  td::Result<GroupParticipant> get_participant(const PublicKey &public_key) const;
  Permissions get_permissions(const PublicKey &public_key, td::int32 limit_permissions) const;
  static GroupStateRef from_tl(const td::e2e_api::e2e_chain_groupState &state);
  e2e::object_ptr<e2e::e2e_chain_groupState> to_tl() const;
  static GroupStateRef empty_state();
  bool operator==(const GroupState &other) const {
    return participants == other.participants && external_permissions == other.external_permissions;
  }
  bool operator!=(const GroupState &other) const {
    return !(other == *this);
  }
};
inline td::StringBuilder &operator<<(td::StringBuilder &sb, const GroupState &state) {
  return sb << state.participants << ", external_permissions=" << state.external_permissions;
}

struct GroupSharedKey {
  PublicKey ek;
  std::string encrypted_shared_key;
  std::vector<td::int64> dest_user_id;
  std::vector<std::string> dest_header;
  static GroupSharedKeyRef from_tl(const td::e2e_api::e2e_chain_sharedKey &shared_key);
  e2e::object_ptr<e2e::e2e_chain_sharedKey> to_tl() const;
  static GroupSharedKeyRef empty_shared_key();
  bool empty() const {
    return *this == *empty_shared_key();
  }
  bool operator==(const GroupSharedKey &other) const {
    return ek == other.ek && encrypted_shared_key == other.encrypted_shared_key && dest_user_id == other.dest_user_id &&
           dest_header == other.dest_header;
  }
  bool operator!=(const GroupSharedKey &other) const {
    return !(other == *this);
  }
};

inline td::StringBuilder &operator<<(td::StringBuilder &sb, const GroupSharedKey &shared_key) {
  return sb << "SharedKey{uids=" << shared_key.dest_user_id << "}";
}

struct ChangeNoop {
  td::UInt256 nonce;
  static ChangeNoop from_tl(const td::e2e_api::e2e_chain_changeNoop &change) {
    return ChangeNoop{change.nonce_};
  }
  e2e::object_ptr<e2e::e2e_chain_changeNoop> to_tl() const {
    return e2e::make_object<e2e::e2e_chain_changeNoop>(nonce);
  }
};
inline td::StringBuilder &operator<<(td::StringBuilder &sb, const ChangeNoop &change) {
  return sb << "Noop{}";
}

struct ChangeSetValue {
  std::string key;
  std::string value;
  static ChangeSetValue from_tl(const td::e2e_api::e2e_chain_changeSetValue &change);
  e2e::object_ptr<e2e::e2e_chain_changeSetValue> to_tl() const;
};
inline td::StringBuilder &operator<<(td::StringBuilder &sb, const ChangeSetValue &state) {
  return sb << "SetValue{key.size=" << state.key.size() << ", value.size=" << state.value.size() << "}";
}
struct ChangeSetGroupState {
  GroupStateRef group_state;
  static ChangeSetGroupState from_tl(const td::e2e_api::e2e_chain_changeSetGroupState &change);
  e2e::object_ptr<e2e::e2e_chain_changeSetGroupState> to_tl() const;
};
inline td::StringBuilder &operator<<(td::StringBuilder &sb, const ChangeSetGroupState &state) {
  return sb << "SetGroupState{" << *state.group_state << "}";
}
struct ChangeSetSharedKey {
  GroupSharedKeyRef shared_key;
  static ChangeSetSharedKey from_tl(const td::e2e_api::e2e_chain_changeSetSharedKey &change);
  e2e::object_ptr<e2e::e2e_chain_changeSetSharedKey> to_tl() const;
};
inline td::StringBuilder &operator<<(td::StringBuilder &sb, const ChangeSetSharedKey &shared_key) {
  return sb << "SetSharedKey{" << *shared_key.shared_key << "}";
}

struct Change {
  std::variant<ChangeSetValue, ChangeSetGroupState, ChangeSetSharedKey, ChangeNoop> value;
  static Change from_tl(const td::e2e_api::e2e_chain_Change &change);
  e2e::object_ptr<e2e::e2e_chain_Change> to_tl() const;
};
inline td::StringBuilder &operator<<(td::StringBuilder &sb, const Change &change) {
  std::visit([&](auto &value) { sb << value; }, change.value);
  return sb;
}

struct KeyValueState {
  TrieRef node_{TrieNode::empty_node()};
  td::optional<td::Slice> snapshot_{td::Slice()};
  td::Result<std::string> get_value(td::Slice key) const;
  td::Result<std::string> gen_proof(td::Span<td::Slice> keys) const;
  static td::Result<KeyValueState> create_from_hash(KeyValueHash hash);
  static td::Result<KeyValueState> create_from_snapshot(td::Slice snapshot);
  td::Result<std::string> build_snapshot() const;
  td::UInt256 get_hash() const;
  td::Status set_value(td::Slice key, td::Slice value);
  //td::Status set_value_fast(KeyValueHash key_value_hash);
};

struct StateProof {
  KeyValueHash kv_hash;
  td::optional<GroupStateRef> o_group_state;
  td::optional<GroupSharedKeyRef> o_shared_key;
  static StateProof from_tl(const td::e2e_api::e2e_chain_stateProof &proof);
  e2e::object_ptr<e2e::e2e_chain_stateProof> to_tl() const;
};

td::StringBuilder &operator<<(td::StringBuilder &sb, const StateProof &state);
struct ValidateOptions {
  bool validate_state_hash{true};
  bool validate_signature{true};
  td::int32 permissions{GroupParticipantFlags::AllPermissions};
};

struct Block;
struct State {
  KeyValueState key_value_state_;
  GroupStateRef group_state_;
  GroupSharedKeyRef shared_key_;
  bool has_set_value_{};
  bool has_shared_key_change_{};
  bool has_group_state_change_{};

  State() = default;
  State(KeyValueState key_value_state, GroupStateRef group_state, GroupSharedKeyRef shared_key)
      : key_value_state_(std::move(key_value_state))
      , group_state_(std::move(group_state))
      , shared_key_(std::move(shared_key)) {
    CHECK(group_state_);
    CHECK(shared_key_);
  }

  static State create_empty();
  static td::Result<State> create_from_block(const Block &block, td::optional<td::Slice> o_snapshot = {});

  td::Status set_value(td::Slice key, td::Slice value, const Permissions &permissions);
  td::Status set_group_state(GroupStateRef group_state, const Permissions &permissions);
  td::Status clear_shared_key(const Permissions &permissions);
  td::Status set_shared_key(GroupSharedKeyRef shared_key, const Permissions &permissions);
  td::Status set_value_fast(const KeyValueHash &key_value_hash);
  td::Status apply_change(const Change &change_outer, const PublicKey &public_key, const ValidateOptions &options);

  td::Status apply(Block &block, ValidateOptions validate_options = {});

  td::Status validate_state(const StateProof &state_proof) const;

  static td::Status validate_group_state(const GroupStateRef &group_state);
  static td::Status validate_shared_key(const GroupSharedKeyRef &shared_key, const GroupStateRef &group_state);
};

struct Block {
  Signature signature_;
  td::UInt256 prev_block_hash_{};
  std::vector<Change> changes_;
  td::int32 height_{-1};

  StateProof state_proof_;
  td::optional<PublicKey> o_signature_public_key_;

  td::Status sign_inplace(const PrivateKey &private_key) {
    TRY_RESULT_ASSIGN(signature_, ::tde2e_core::sign(private_key, *to_tl()));
    return td::Status::OK();
  }
  td::Status verify_signature(const PublicKey &public_key) const {
    return ::tde2e_core::verify_signature(public_key, *to_tl());
  }
  td::UInt256 calc_hash() const;

  static td::Result<Block> from_tl_serialized(td::Slice new_block);
  std::string to_tl_serialized() const;

 private:
  e2e::object_ptr<e2e::e2e_chain_block> to_tl() const;
  static Block from_tl(const e2e::e2e_chain_block &block);
};
td::StringBuilder &operator<<(td::StringBuilder &sb, const Block &block);

struct Blockchain {
  static Blockchain create_empty() {
    return Blockchain{Block{}, td::UInt256{}, State::create_empty()};
  }
  static td::Result<Blockchain> create_from_block(Block block, td::optional<td::Slice> o_snapshot = {});

  static bool is_from_server(td::Slice block);
  static td::Result<std::string> from_any_to_local(std::string block);
  static td::Result<std::string> from_server_to_local(std::string block);
  static td::Result<std::string> from_local_to_server(std::string block);

  td::Result<Block> build_block(std::vector<Change> changes, const PrivateKey &private_key) const;
  td::Status try_apply_block(Block block, ValidateOptions validate_options);
  Block set_value(td::Slice key, td::Slice value, const PrivateKey &private_key) const;
  td::int64 get_height() const;

  Block last_block_;
  td::UInt256 last_block_hash_{};
  State state_{State::create_empty()};

  void attach_snapshot(td::Slice snapshot) {
    state_.key_value_state_.snapshot_ = snapshot;
  }
  void detach_snapshot() {
    state_.key_value_state_.snapshot_ = td::Slice();
  }
};

class ClientBlockchain {
 public:
  static td::Result<ClientBlockchain> create_from_block(td::Slice block_slice, const PublicKey &public_key);
  static td::Result<ClientBlockchain> create_empty();

  td::Result<std::vector<Change>> try_apply_block(td::Slice block_slice);

  td::int64 get_height() const {
    return blockchain_.get_height();
  }
  td::UInt256 get_last_block_hash() const {
    return blockchain_.last_block_hash_;
  }
  td::UInt256 get_previous_block_hash() const {
    return blockchain_.last_block_.prev_block_hash_;
  }

  td::Status add_proof(td::Slice proof);

  td::Result<std::string> build_block(const std::vector<Change> &changes, const PrivateKey &private_key) const;

  td::Result<std::string> get_value(td::Slice key) const;
  GroupSharedKeyRef get_group_shared_key() const {
    return blockchain_.state_.shared_key_;
  }
  GroupStateRef get_group_state() const {
    return blockchain_.state_.group_state_;
  }
  const Blockchain &get_inner_chain() const {
    return blockchain_;
  }

 private:
  Blockchain blockchain_;
  struct Entry {
    td::int64 height;
    std::string value;
  };
  td::FlatHashMap<td::UInt256, Entry, UInt256Hash> map_;
};

}  // namespace tde2e_core
