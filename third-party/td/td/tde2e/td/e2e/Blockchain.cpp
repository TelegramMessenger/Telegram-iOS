//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/Blockchain.h"

#include "td/e2e/Keys.h"

#include "td/telegram/e2e_api.hpp"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/misc.h"
#include "td/utils/overloaded.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_parsers.h"

#include <algorithm>
#include <map>
#include <set>
#include <tuple>
#include <utility>

namespace tde2e_core {

GroupParticipant GroupParticipant::from_tl(const td::e2e_api::e2e_chain_groupParticipant &participant) {
  return GroupParticipant{participant.user_id_, participant.flags_, PublicKey::from_u256(participant.public_key_),
                          participant.version_};
}

e2e::object_ptr<e2e::e2e_chain_groupParticipant> GroupParticipant::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_groupParticipant>(user_id, public_key.to_u256(), flags, add_users(),
                                                           remove_users(), version);
}
td::int32 GroupState::version() const {
  if (participants.empty()) {
    return 0;
  }
  td::int32 version = participants.front().version;
  for (auto &participant : participants) {
    version = std::min(version, participant.version);
  }
  return std::clamp(version, 0, 255);
}
td::Result<GroupParticipant> GroupState::get_participant(td::int64 user_id) const {
  for (const auto &participant : participants) {
    if (participant.user_id == user_id) {
      return participant;
    }
  }
  return td::Status::Error("Participant not found");
}

td::Result<GroupParticipant> GroupState::get_participant(const PublicKey &public_key) const {
  for (const auto &participant : participants) {
    if (participant.public_key == public_key) {
      return participant;
    }
  }
  return td::Status::Error("Participant not found");
};
Permissions GroupState::get_permissions(const PublicKey &public_key, td::int32 limit_permissions) const {
  limit_permissions &= GroupParticipantFlags::AllPermissions;
  auto r_participant = get_participant(public_key);
  if (r_participant.is_ok()) {
    return Permissions{(r_participant.ok().flags & limit_permissions) | GroupParticipantFlags::IsParticipant};
  }
  return Permissions{(external_permissions & limit_permissions)};
}

GroupStateRef GroupState::from_tl(const td::e2e_api::e2e_chain_groupState &state) {
  auto participant_from_tl = [](const td::e2e_api::object_ptr<td::e2e_api::e2e_chain_groupParticipant> &participant) {
    return GroupParticipant::from_tl(*participant);
  };
  td::optional<td::int32> external_permissions{};
  return std::make_shared<GroupState>(
      GroupState{td::transform(state.participants_, participant_from_tl), state.external_permissions_});
}
e2e::object_ptr<e2e::e2e_chain_groupState> GroupState::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_groupState>(
      td::transform(participants, [](const GroupParticipant &participant) { return participant.to_tl(); }),
      external_permissions);
}
GroupStateRef GroupState::empty_state() {
  static GroupStateRef state = std::make_shared<GroupState>();
  return state;
}
GroupSharedKeyRef GroupSharedKey::from_tl(const td::e2e_api::e2e_chain_sharedKey &shared_key) {
  return std::make_shared<GroupSharedKey>(GroupSharedKey{PublicKey::from_u256(shared_key.ek_),
                                                         shared_key.encrypted_shared_key_, shared_key.dest_user_id_,
                                                         shared_key.dest_header_});
}
e2e::object_ptr<e2e::e2e_chain_sharedKey> GroupSharedKey::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_sharedKey>(ek.to_u256(), encrypted_shared_key,
                                                    std::vector<td::int64>(dest_user_id), std::vector(dest_header));
}
GroupSharedKeyRef GroupSharedKey::empty_shared_key() {
  static GroupSharedKeyRef shared_key = std::make_shared<GroupSharedKey>();
  return shared_key;
}
ChangeSetValue ChangeSetValue::from_tl(const td::e2e_api::e2e_chain_changeSetValue &change) {
  return ChangeSetValue{change.key_, change.value_};
}
e2e::object_ptr<e2e::e2e_chain_changeSetValue> ChangeSetValue::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_changeSetValue>(key, value);
}
ChangeSetGroupState ChangeSetGroupState::from_tl(const td::e2e_api::e2e_chain_changeSetGroupState &change) {
  return ChangeSetGroupState{GroupState::from_tl(*change.group_state_)};
}
e2e::object_ptr<e2e::e2e_chain_changeSetGroupState> ChangeSetGroupState::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_changeSetGroupState>(group_state->to_tl());
}
ChangeSetSharedKey ChangeSetSharedKey::from_tl(const td::e2e_api::e2e_chain_changeSetSharedKey &change) {
  return ChangeSetSharedKey{GroupSharedKey::from_tl(*change.shared_key_)};
}
e2e::object_ptr<e2e::e2e_chain_changeSetSharedKey> ChangeSetSharedKey::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_changeSetSharedKey>(shared_key->to_tl());
}
Change Change::from_tl(const td::e2e_api::e2e_chain_Change &change) {
  Change res;
  downcast_call(
      const_cast<td::e2e_api::e2e_chain_Change &>(change),
      td::overloaded(
          [&](td::e2e_api::e2e_chain_changeNoop &change_t) { res.value = ChangeNoop::from_tl(change_t); },
          [&](td::e2e_api::e2e_chain_changeSetValue &change_t) { res.value = ChangeSetValue::from_tl(change_t); },
          [&](td::e2e_api::e2e_chain_changeSetGroupState &change_t) {
            res.value = ChangeSetGroupState::from_tl(change_t);
          },
          [&](td::e2e_api::e2e_chain_changeSetSharedKey &change_t) {
            res.value = ChangeSetSharedKey::from_tl(change_t);
          }));
  return res;
}
e2e::object_ptr<e2e::e2e_chain_Change> Change::to_tl() const {
  return std::visit(
      td::overloaded(
          [](const ChangeNoop &change) -> td::e2e_api::object_ptr<e2e::e2e_chain_Change> { return change.to_tl(); },
          [](const ChangeSetValue &change) -> td::e2e_api::object_ptr<e2e::e2e_chain_Change> { return change.to_tl(); },
          [](const ChangeSetGroupState &change) -> td::e2e_api::object_ptr<e2e::e2e_chain_Change> {
            return change.to_tl();
          },
          [](const ChangeSetSharedKey &change) -> td::e2e_api::object_ptr<e2e::e2e_chain_Change> {
            return change.to_tl();
          }),
      value);
}
td::UInt256 Block::calc_hash() const {
  if (height_ == -1) {
    return {};
  }
  auto serialized_block = serialize_boxed(*to_tl());
  td::UInt256 hash;
  td::sha256(serialized_block, hash.as_mutable_slice());
  return hash;
}
Block Block::from_tl(const e2e::e2e_chain_block &block) {
  Block result;
  result.state_proof_ = StateProof::from_tl(*block.state_proof_);
  if (block.flags_ & 1) {
    result.o_signature_public_key_ = PublicKey::from_u256(block.signature_public_key_);
  }
  result.signature_ = Signature::from_u512(block.signature_);
  result.prev_block_hash_ = block.prev_block_hash_;
  auto change_from_tl = [&](auto &obj) {
    return Change::from_tl(*obj);
  };
  result.changes_ = td::transform(block.changes_, change_from_tl);
  result.height_ = block.height_;
  return result;
}

td::Result<Block> Block::from_tl_serialized(td::Slice new_block) {
  td::TlParser parser(new_block);
  auto magic = parser.fetch_int();
  if (magic != td::e2e_api::e2e_chain_block::ID) {
    return td::Status::Error(PSLICE() << "Expected magic " << td::format::as_hex(td::e2e_api::e2e_chain_block::ID)
                                      << ", got " << td::format::as_hex(magic));
  }
  auto block_tl = td::e2e_api::e2e_chain_block::fetch(parser);
  parser.fetch_end();
  TRY_STATUS(parser.get_status());
  return from_tl(*block_tl);
}

e2e::object_ptr<e2e::e2e_chain_block> Block::to_tl() const {
  td::int32 flags{};
  auto state_proof = state_proof_.to_tl();
  td::UInt256 public_key{};
  if (o_signature_public_key_) {
    public_key = o_signature_public_key_.value().to_u256();
    flags |= e2e::e2e_chain_block::SIGNATURE_PUBLIC_KEY_MASK;
  }
  auto changes = td::transform(changes_, [](const auto &change) { return change.to_tl(); });

  return e2e::make_object<e2e::e2e_chain_block>(signature_.to_u512(), flags, prev_block_hash_, std::move(changes),
                                                height_, std::move(state_proof), public_key);
}
std::string Block::to_tl_serialized() const {
  return serialize_boxed(*to_tl());
}
td::StringBuilder &operator<<(td::StringBuilder &sb, const Block &block) {
  return sb << "Block(sign=" << block.signature_
            << "..., prev_hash=" << hex_encode(block.prev_block_hash_.as_slice().substr(0, 8))
            << "\theight=" << block.height_ << " \n"
            << "\tproof=" << block.state_proof_ << "\n"
            << "\tchanges=" << block.changes_ << "\n"
            << "\tsignature_key=" << block.o_signature_public_key_ << ")";
}
td::Result<BitString> key_to_bitstring(td::Slice key) {
  if (key.size() != 32) {
    return td::Status::Error("Invalid key size");
  }
  return BitString(key);
}
td::Result<std::string> KeyValueState::get_value(td::Slice key) const {
  TRY_RESULT(bitstring, key_to_bitstring(key));
  return get(node_, bitstring, snapshot_.value());
}
td::Result<std::string> KeyValueState::gen_proof(td::Span<td::Slice> keys) const {
  // TODO: validate keys..
  TRY_RESULT(pruned_tree, generate_pruned_tree(node_, keys, snapshot_.value()));
  return TrieNode::serialize_for_network(pruned_tree);
}
td::Result<KeyValueState> KeyValueState::create_from_hash(KeyValueHash hash) {
  auto node = std::make_shared<TrieNode>(hash.hash);
  return KeyValueState{std::move(node), td::Slice()};
}
td::Result<KeyValueState> KeyValueState::create_from_snapshot(td::Slice snapshot) {
  TRY_RESULT(node, TrieNode::fetch_from_snapshot(snapshot));
  return KeyValueState{std::move(node), snapshot};
}
td::Result<std::string> KeyValueState::build_snapshot() const {
  return TrieNode::serialize_for_snapshot(node_, snapshot_.value());
}

td::Status KeyValueState::set_value(td::Slice key, td::Slice value) {
  TRY_RESULT(bitstring, key_to_bitstring(key));
  TRY_RESULT_ASSIGN(node_, set(node_, bitstring, value, snapshot_.value()));
  return td::Status::OK();
}

td::UInt256 KeyValueState::get_hash() const {
  //TODO: hash of public key
  return node_->hash;
}

StateProof StateProof::from_tl(const td::e2e_api::e2e_chain_stateProof &proof) {
  StateProof res;
  res.kv_hash = KeyValueHash{proof.kv_hash_};
  if (proof.group_state_) {
    res.o_group_state = GroupState::from_tl(*proof.group_state_);
  }
  if (proof.shared_key_) {
    res.o_shared_key = GroupSharedKey::from_tl(*proof.shared_key_);
  }
  return res;
}
e2e::object_ptr<e2e::e2e_chain_stateProof> StateProof::to_tl() const {
  td::int32 flags{};
  e2e::object_ptr<e2e::e2e_chain_groupState> o_group_state_tl;
  if (o_group_state) {
    o_group_state_tl = o_group_state.value()->to_tl();
    flags |= td::e2e_api::e2e_chain_stateProof::GROUP_STATE_MASK;
  }
  e2e::object_ptr<e2e::e2e_chain_sharedKey> o_shared_key_tl;
  if (o_shared_key) {
    o_shared_key_tl = o_shared_key.value()->to_tl();
    flags |= td::e2e_api::e2e_chain_stateProof::SHARED_KEY_MASK;
  }

  return e2e::make_object<e2e::e2e_chain_stateProof>(flags, kv_hash.hash, std::move(o_group_state_tl),
                                                     std::move(o_shared_key_tl));
}
td::StringBuilder &operator<<(td::StringBuilder &sb, const StateProof &state) {
  sb << "StateProof{";
  sb << "\n\tkv=" << td::format::as_hex_dump<0>(state.kv_hash.hash.as_slice().substr(0, 8));
  if (state.o_group_state) {
    sb << "\n\tgroup=" << **state.o_group_state;
  }
  if (state.o_shared_key) {
    sb << "\n\tgroup=" << **state.o_shared_key;
  }
  return sb << "}";
}

State State::create_empty() {
  return State{KeyValueState{}, GroupState::empty_state(), GroupSharedKey::empty_shared_key()};
}

td::Status State::set_value(td::Slice key, td::Slice value, const Permissions &permissions) {
  if (!permissions.may_set_value()) {
    return Error(E::InvalidBlock_NoPermissions, "Can't set value");
  }
  return key_value_state_.set_value(key, value);
}

td::Status State::set_value_fast(const KeyValueHash &key_value_hash) {
  TRY_RESULT_ASSIGN(key_value_state_, KeyValueState::create_from_hash(key_value_hash));
  return td::Status::OK();
}

td::Status State::validate_group_state(const GroupStateRef &group_state) {
  std::set<td::int64> new_user_ids;
  std::set<PublicKey> new_keys;
  for (const auto &p : group_state->participants) {
    new_user_ids.insert(p.user_id);
    new_keys.insert(p.public_key);
    if ((p.flags & ~GroupParticipantFlags::AllPermissions) != 0) {
      return Error(E::InvalidBlock_InvalidGroupState, "invalid permissions");
    }
  }
  if ((group_state->external_permissions & ~GroupParticipantFlags::AllPermissions) != 0) {
    return Error(E::InvalidBlock_InvalidGroupState, "invalid external permissions");
  }
  if (new_user_ids.size() != group_state->participants.size()) {
    return Error(E::InvalidBlock_InvalidGroupState, "duplicate user_id");
  }
  if (new_keys.size() != group_state->participants.size()) {
    return Error(E::InvalidBlock_InvalidGroupState, "duplicate public_key");
  }
  return td::Status::OK();
}

td::Status State::set_group_state(GroupStateRef group_state, const Permissions &permissions) {
  TRY_STATUS(validate_group_state(group_state));

  std::map<std::pair<td::int64, PublicKey>, td::int32> old_participants;
  std::map<std::pair<td::int64, PublicKey>, td::int32> new_participants;

  for (const auto &p : group_state_->participants) {
    old_participants[std::make_pair(p.user_id, p.public_key)] = p.flags;
  }
  for (const auto &p : group_state->participants) {
    new_participants[std::make_pair(p.user_id, p.public_key)] = p.flags;
  }
  if ((~group_state_->external_permissions & group_state->external_permissions) != 0) {
    return Error(E::InvalidBlock_NoPermissions, "Can't increase external permissions");
  }

  td::int32 needed_flags = 0;
  for (const auto &[p, flags] : old_participants) {
    if (!new_participants.count(p)) {
      if (!permissions.may_remove_users()) {
        return Error(E::InvalidBlock_NoPermissions, "Can't remove users");
      }
    }
  }
  for (const auto &[p, flags] : new_participants) {
    auto old_p = old_participants.find(p);
    if (old_p == old_participants.end()) {
      if (!permissions.may_add_users()) {
        return Error(E::InvalidBlock_NoPermissions, "Can't add users");
      }
      needed_flags |= flags;
    } else if (flags != old_p->second) {
      if (!permissions.may_add_users() || !permissions.may_remove_users()) {
        return Error(E::InvalidBlock_NoPermissions, "Can't add users");
      }
      needed_flags |= flags & ~old_p->second;
    }
  }

  td::int32 missing_flags = needed_flags & ~(permissions.flags & GroupParticipantFlags::AllPermissions);
  if (missing_flags != 0) {
    return Error(E::InvalidBlock_NoPermissions, "Can't give more permissions than we have");
  }
  group_state_ = std::move(group_state);
  return td::Status::OK();
}

td::Status State::clear_shared_key(const Permissions &permissions) {
  if (!permissions.may_change_shared_key()) {
    return Error(E::InvalidBlock_NoPermissions, "Can't clear shared key");
  }
  shared_key_ = GroupSharedKey::empty_shared_key();
  return td::Status::OK();
}

td::Status State::validate_shared_key(const GroupSharedKeyRef &shared_key, const GroupStateRef &group_state) {
  if (shared_key->empty_shared_key()) {
    return td::Status::OK();
  }
  if (shared_key->dest_user_id.size() != shared_key->dest_header.size()) {
    return td::Status::Error("Shared key different number of users and headers");
  }
  if (shared_key->dest_user_id.size() != group_state->participants.size()) {
    return td::Status::Error("Shared key has wrong number of users");
  }
  std::set<td::int64> participants;
  for (const auto user_id : shared_key->dest_user_id) {
    participants.insert(user_id);
  }
  if (participants.size() != shared_key->dest_user_id.size()) {
    return td::Status::Error("Shared key has duplicated users");
  }
  for (auto &p : group_state->participants) {
    if (!participants.count(p.user_id)) {
      return td::Status::Error("Unknown user_id in SetSharedKey");
    }
  }
  return td::Status::OK();
}

td::Status State::set_shared_key(GroupSharedKeyRef shared_key, const Permissions &permissions) {
  if (*shared_key_ != *GroupSharedKey::empty_shared_key()) {
    return td::Status::Error("Shared key is already set");
  }
  if (!permissions.may_change_shared_key()) {
    return Error(E::InvalidBlock_NoPermissions, "Can't set shared key");
  }
  TRY_STATUS(validate_shared_key(shared_key, group_state_));
  shared_key_ = std::move(shared_key);
  return td::Status::OK();
}

td::Status State::validate_state(const StateProof &state_proof) const {
  if (state_proof.kv_hash.hash != key_value_state_.get_hash()) {
    return td::Status::Error("State hash mismatch");
  }

  if (!has_group_state_change_ && !has_set_value_) {
    return Error(E::InvalidBlock_NoChanges, "There must be at least SetValue or SetGroupState changes");
  }
  if (has_group_state_change_ && state_proof.o_group_state) {
    return Error(E::InvalidBlock_InvalidStateProof_Group,
                 "Group state must be omitted when there is a group state change");
  }
  if (!has_group_state_change_ && !state_proof.o_group_state) {
    return Error(E::InvalidBlock_InvalidStateProof_Group,
                 "Group state must be provided when there is no group state change");
  }
  if (!has_group_state_change_ && **state_proof.o_group_state != *group_state_) {
    return Error(E::InvalidBlock_InvalidStateProof_Group, "group state differs");
  }

  bool shared_key_must_be_omitted = has_group_state_change_ || has_shared_key_change_;
  if (shared_key_must_be_omitted && state_proof.o_shared_key) {
    return Error(E::InvalidBlock_InvalidStateProof_Secret, "Shared key state must be omitted");
  }
  if (!shared_key_must_be_omitted && !state_proof.o_shared_key) {
    return Error(E::InvalidBlock_InvalidStateProof_Secret, "Shared key state must be provided");
  }
  if (!shared_key_must_be_omitted && **state_proof.o_shared_key != *shared_key_) {
    return Error(E::InvalidBlock_InvalidStateProof_Secret, "shared key state differs");
  }

  TRY_STATUS(validate_group_state(group_state_));
  TRY_STATUS(validate_shared_key(shared_key_, group_state_));

  return td::Status::OK();
}

td::Status State::apply_change(const Change &change_outer, const PublicKey &public_key,
                               const ValidateOptions &validate_options) {
  bool full_apply = validate_options.validate_state_hash;
  auto limit_permissions = validate_options.permissions;
  return std::visit(
      td::overloaded(
          [](const ChangeNoop &change) { return td::Status::OK(); },
          [this, full_apply, limit_permissions, &public_key](const ChangeSetValue &change) {
            has_set_value_ = true;
            if (full_apply) {
              return set_value(change.key, change.value, group_state_->get_permissions(public_key, limit_permissions));
            }
            return td::Status::OK();
          },
          [this, limit_permissions, &public_key](const ChangeSetGroupState &change) {
            has_group_state_change_ = true;
            TRY_STATUS(
                set_group_state(change.group_state, group_state_->get_permissions(public_key, limit_permissions)));
            return clear_shared_key(group_state_->get_permissions(public_key, limit_permissions));
          },
          [this, limit_permissions, &public_key](const ChangeSetSharedKey &change) {
            has_shared_key_change_ = true;
            return set_shared_key(change.shared_key, group_state_->get_permissions(public_key, limit_permissions));
          }),
      change_outer.value);
}

td::Status State::apply(Block &block, ValidateOptions validate_options) {
  // To apply the first block an ephemeral -1 block is used
  //   - It has only one participant - Participant(user_id = 0, public_key = signer_public_key, permissions = all)
  if (block.height_ == 0) {
    CHECK(group_state_->empty());
    group_state_ = std::make_unique<GroupState>(GroupState{{}, GroupParticipantFlags::AllPermissions});
  }

  td::optional<PublicKey> o_signature_public_key = block.o_signature_public_key_;
  if (!o_signature_public_key && !group_state_->empty()) {
    o_signature_public_key = group_state_->participants[0].public_key;
  }
  if (!o_signature_public_key) {
    return td::Status::Error("Unknown public key");
  }

  // 5. Verifies the signature of the block.
  if (validate_options.validate_signature) {
    TRY_STATUS(block.verify_signature(o_signature_public_key.value()));
  }

  // 6. Applies the changes to the state.
  //   - If `validate_state_hash` is true, the state hash is validated.
  //   - Otherwise, the state hash is set to the hash of the block.
  has_set_value_ = false;
  has_shared_key_change_ = false;
  has_group_state_change_ = false;
  for (auto &change : block.changes_) {
    TRY_STATUS(apply_change(change, o_signature_public_key.value(), validate_options));
  }
  if (!validate_options.validate_state_hash) {
    TRY_STATUS(set_value_fast(block.state_proof_.kv_hash));
  }

  TRY_STATUS(validate_state(block.state_proof_));

  return td::Status::OK();
}

td::Result<State> State::create_from_block(const Block &block, td::optional<td::Slice> o_snapshot) {
  KeyValueState key_value_state;
  GroupStateRef group_state;
  GroupSharedKeyRef shared_key;

  if (o_snapshot) {
    TRY_RESULT_ASSIGN(key_value_state, KeyValueState::create_from_snapshot(o_snapshot.value()));
  } else {
    TRY_RESULT_ASSIGN(key_value_state, KeyValueState::create_from_hash(block.state_proof_.kv_hash));
  }

  // For the first block we fixup group state.
  if (block.height_ == 0) {
    group_state = std::make_shared<GroupState>(GroupState{{}, GroupParticipantFlags::AllPermissions});
  }

  bool has_set_value = false;
  bool has_group_state_change = false;
  bool has_shared_key_change = false;
  for (const auto &change_v : block.changes_) {
    std::visit(
        td::overloaded([](const ChangeNoop &change) {}, [&](const ChangeSetValue &change) { has_set_value = true; },
                       [&](const ChangeSetGroupState &change) {
                         group_state = change.group_state;
                         shared_key = GroupSharedKey::empty_shared_key();
                         has_group_state_change = true;
                       },
                       [&](const ChangeSetSharedKey &change) {
                         shared_key = change.shared_key;
                         has_shared_key_change = true;
                       }),
        change_v.value);
  }

  if (block.state_proof_.o_group_state) {
    group_state = block.state_proof_.o_group_state.value();
  }
  if (block.state_proof_.o_shared_key) {
    shared_key = block.state_proof_.o_shared_key.value();
  }
  if (!group_state) {
    return Error(E::InvalidBlock_InvalidStateProof_Group, "no group state proof");
  }
  if (!shared_key) {
    return Error(E::InvalidBlock_InvalidStateProof_Secret, "no shared key");
  }

  auto state = State(key_value_state, group_state, shared_key);
  state.has_set_value_ = has_set_value;
  state.has_group_state_change_ = has_group_state_change;
  state.has_shared_key_change_ = has_shared_key_change;
  TRY_STATUS(state.validate_state(block.state_proof_));
  return state;
}

td::Result<Block> Blockchain::build_block(std::vector<Change> changes, const PrivateKey &private_key) const {
  //TODO(now): check if we are allowed to sign this block
  auto public_key = private_key.to_public_key();
  auto state = state_;
  if (last_block_.height_ == std::numeric_limits<td::int32>::max()) {
    return td::Status::Error("Blockchain::build_block: last block height is too high");
  }
  td::int32 height = last_block_.height_ + 1;
  if (height == 0) {
    state.group_state_ = std::make_shared<GroupState>(GroupState{{}, GroupParticipantFlags::AllPermissions});
  }

  ValidateOptions validate_options;
  validate_options.validate_state_hash = true;
  validate_options.validate_signature = false;
  validate_options.permissions = GroupParticipantFlags::AllPermissions;
  for (const auto &change : changes) {
    TRY_STATUS(state.apply_change(change, public_key, validate_options));
  }

  StateProof state_proof;
  state_proof.kv_hash = KeyValueHash{state.key_value_state_.get_hash()};
  state_proof.o_group_state = state.group_state_;
  state_proof.o_shared_key = state.shared_key_;
  state.has_set_value_ = false;
  state.has_group_state_change_ = false;
  state.has_shared_key_change_ = false;
  for (const auto &change_v : changes) {
    std::visit(td::overloaded([](const ChangeNoop &change) {},
                              [&](const ChangeSetValue &change) { state.has_set_value_ = true; },
                              [&](const ChangeSetGroupState &change) {
                                state_proof.o_group_state = {};
                                state_proof.o_shared_key = {};
                                state.has_group_state_change_ = true;
                              },
                              [&](const ChangeSetSharedKey &change) {
                                state_proof.o_shared_key = {};
                                state.has_shared_key_change_ = true;
                              }),
               change_v.value);
  }
  TRY_STATUS(state.validate_state(state_proof));

  Block block;
  block.height_ = height;
  block.prev_block_hash_ = last_block_hash_;
  block.changes_ = std::move(changes);
  block.o_signature_public_key_ = public_key;
  block.state_proof_ = std::move(state_proof);
  TRY_STATUS(block.sign_inplace(private_key));
  return block;
}

td::Status Blockchain::try_apply_block(Block block, ValidateOptions validate_options) {
  // To apply the first block an ephemeral -1 block is used
  //   - It has hash UInt256(0)
  //   - It has height -1
  //   - It has only one participant - Participant(user_id = 0, public_key = signer_public_key, permissions = all)

  if (block.height_ != get_height() + 1 || get_height() == std::numeric_limits<td::int32>::max()) {
    return Error(E::InvalidBlock_HeightMismatch,
                 PSLICE() << "new_block.height=" << block.height_ << " != 1 + last_block.height=" << get_height());
  }

  if (block.prev_block_hash_ != last_block_hash_) {
    return Error(E::InvalidBlock_HashMismatch);
  }

  // TODO: validate total size of block
  auto state = state_;
  TRY_STATUS(state.apply(block, validate_options));

  // NO errors after this point
  state_ = std::move(state);

  last_block_hash_ = block.calc_hash();

  last_block_ = std::move(block);
  return td::Status::OK();
}

Block Blockchain::set_value(td::Slice key, td::Slice value, const PrivateKey &private_key) const {
  return build_block({Change{ChangeSetValue{key.str(), value.str()}}}, private_key).move_as_ok();
}

td::int64 Blockchain::get_height() const {
  return last_block_.height_;
}

td::Result<td::UInt256> as_key(td::Slice key) {
  if (key.size() != 32) {
    return td::Status::Error("Invalid key size");
  }
  td::UInt256 key_int256;
  key_int256.as_mutable_slice().copy_from(key);
  if (key_int256.is_zero()) {
    return td::Status::Error("Invalid zero key");
  }
  return key_int256;
}

td::Result<Blockchain> Blockchain::create_from_block(Block block, td::optional<td::Slice> o_snapshot) {
  if (block.height_ < 0) {
    return Error(E::InvalidBlock, "negative height");
  }
  Blockchain res;
  res.last_block_hash_ = block.calc_hash();
  TRY_RESULT_ASSIGN(res.state_, State::create_from_block(block, std::move(o_snapshot)));
  res.last_block_ = std::move(block);

  return res;
}
namespace {
bool is_good_magic(td::int32 magic) {
  return magic == td::e2e_api::e2e_chain_block::ID || magic == td::e2e_api::e2e_chain_groupBroadcastNonceCommit::ID ||
         magic == td::e2e_api::e2e_chain_groupBroadcastNonceReveal::ID;
};
}  // namespace

bool Blockchain::is_from_server(td::Slice block) {
  if (block.size() < 4) {
    return false;
  }
  td::int32 server_magic = td::as<td::int32>(block.data());
  return is_good_magic(server_magic - 1) && !is_good_magic(server_magic);
}

td::Result<std::string> Blockchain::from_any_to_local(std::string block) {
  if (is_from_server(block)) {
    return from_server_to_local(std::move(block));
  }
  return block;
}
td::Result<std::string> Blockchain::from_server_to_local(std::string block) {
  if (block.size() < 4) {
    return td::Status::Error("block is too short");
  }
  td::int32 server_magic = td::as<td::int32>(block.data());
  if (is_good_magic(server_magic)) {
    return td::Status::Error("Trying to apply local block, not from server");
  }
  td::int32 real_magic = server_magic - 1;
  td::as<td::int32>(block.data()) = real_magic;
  return block;
}
td::Result<std::string> Blockchain::from_local_to_server(std::string block) {
  if (block.size() < 4) {
    return td::Status::Error("block is too short");
  }
  td::int32 magic = td::as<td::int32>(block.data());
  td::as<td::int32>(block.data()) = magic + 1;
  return block;
}

td::Result<ClientBlockchain> ClientBlockchain::create_from_block(td::Slice block_slice, const PublicKey &public_key) {
  TRY_RESULT(block, Block::from_tl_serialized(block_slice));
  TRY_RESULT(blockchain, Blockchain::create_from_block(std::move(block)));
  ClientBlockchain res;
  res.blockchain_ = std::move(blockchain);
  return res;
}

td::Result<ClientBlockchain> ClientBlockchain::create_empty() {
  ClientBlockchain res;
  res.blockchain_ = Blockchain::create_empty();
  return res;
}

td::Result<std::vector<Change>> ClientBlockchain::try_apply_block(td::Slice block_slice) {
  TRY_RESULT(block, Block::from_tl_serialized(block_slice));

  ValidateOptions validate_options;
  validate_options.validate_signature = true;
  validate_options.validate_state_hash = false;
  TRY_STATUS(blockchain_.try_apply_block(block, validate_options));
  for (auto &change : block.changes_) {
    if (std::holds_alternative<ChangeSetValue>(change.value)) {
      auto &change_value = std::get<ChangeSetValue>(change.value);
      auto key = as_key(change_value.key).move_as_ok();  // already verified in try_apply_block
      map_[key] = Entry{block.height_, change_value.value};
    }
  }

  return std::move(block.changes_);
}

td::Status ClientBlockchain::add_proof(td::Slice proof) {
  TRY_RESULT(state, TrieNode::fetch_from_network(proof));

  if (state->hash != blockchain_.state_.key_value_state_.get_hash()) {
    return td::Status::Error("Invalid proof");
  }
  // TODO: merge proof
  blockchain_.state_.key_value_state_.node_ = state;
  return td::Status::OK();
}

td::Result<std::string> ClientBlockchain::build_block(const std::vector<Change> &changes,
                                                      const PrivateKey &private_key) const {
  TRY_RESULT(block, blockchain_.build_block(changes, private_key));
  return block.to_tl_serialized();
}

td::Result<std::string> ClientBlockchain::get_value(td::Slice raw_key) const {
  TRY_RESULT(key, as_key(raw_key));
  auto it = map_.find(key);
  if (it != map_.end()) {
    return it->second.value;
  }
  return blockchain_.state_.key_value_state_.get_value(raw_key);
}

}  // namespace tde2e_core
