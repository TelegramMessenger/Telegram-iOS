//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/Call.h"

#include "td/e2e/e2e_api.h"
#include "td/e2e/MessageEncryption.h"
#include "td/e2e/Mnemonic.h"

#include "td/telegram/e2e_api.hpp"
#include "td/utils/algorithm.h"

#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/overloaded.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/tl_storers.h"

#include <algorithm>
#include <limits>
#include <memory>
#include <utility>

namespace tde2e_core {

CallVerificationChain::State CallVerificationChain::get_state() const {
  return state_;
}

template <class F>
struct LambdaStorer {
  const F &store_;
};

template <class F, class StorerT>
void store(const LambdaStorer<F> &lambda_storer, StorerT &storer) {
  lambda_storer.store_(storer);
}

template <class F>
std::string lambda_serialize(F &&f) {
  return td::serialize(LambdaStorer<F>{std::forward<F>(f)});
}

void CallVerificationChain::on_new_main_block(const Blockchain &blockhain) {
  state_ = Commit;
  CHECK(blockhain.get_height() > height_);
  height_ = td::narrow_cast<td::int32>(blockhain.get_height());
  last_block_hash_ = blockhain.last_block_hash_;
  verification_state_ = {};
  verification_state_.height = height_;

  verification_words_ =
      CallVerificationWords{height_, Mnemonic::generate_verification_words(last_block_hash_.as_slice())};
  auto &group_state = *blockhain.state_.group_state_;
  committed_ = {};
  revealed_ = {};

  participant_keys_ = {};
  for (auto &participant : group_state.participants) {
    participant_keys_.emplace(participant.user_id, participant.public_key);
  }
  CHECK(participant_keys_.size() == group_state.participants.size());

  if (auto it = delayed_broadcasts_.find(height_); it != delayed_broadcasts_.end()) {
    for (auto &[message, broadcast] : it->second) {
      auto status = process_broadcast(std::move(message), std::move(broadcast));
      LOG_IF(ERROR, status.is_error()) << "Failed to process broadcast: " << status;
    }
    delayed_broadcasts_.erase(it);
  }
}
td::Status CallVerificationChain::try_apply_block(td::Slice message) {
  // parse e2e::e2e_chain_GroupBroadcast
  td::TlParser parser(message);
  auto kv_broadcast = e2e::e2e_chain_GroupBroadcast::fetch(parser);
  parser.fetch_end();
  TRY_STATUS(parser.get_status());

  td::int32 chain_height{-1};
  downcast_call(*kv_broadcast, td::overloaded([&](auto &broadcast) { chain_height = broadcast.chain_height_; }));

  if (chain_height < height_) {
    LOG(INFO) << "skip old broadcast " << to_short_string(kv_broadcast);
    // broadcast is too old
    return td::Status::OK();
  }

  if (chain_height > height_) {
    if (!delay_allowed_) {
      return Error(E::InvalidBroadcast_InFuture, PSLICE()
                                                     << "broadcast_height=" << chain_height << " height=" << height_);
    }

    LOG(INFO) << "delay broadcast " << to_short_string(kv_broadcast);
    delayed_broadcasts_[chain_height].emplace_back(message.str(), std::move(kv_broadcast));
    return td::Status::OK();
  }

  return process_broadcast(message.str(), std::move(kv_broadcast));
}
std::string CallVerificationChain::to_short_string(e2e::object_ptr<e2e::e2e_chain_GroupBroadcast> &broadcast) {
  td::StringBuilder sb;
  downcast_call(*broadcast,
                td::overloaded([&](e2e::e2e_chain_groupBroadcastNonceCommit &commit) { sb << "CommitBroadcast"; },
                               [&](e2e::e2e_chain_groupBroadcastNonceReveal &reveal) { sb << "RevealBroadcast"; }));
  downcast_call(*broadcast, [&](auto &v) {
    sb << "{height=" << v.chain_height_ << " user_id=" << v.user_id_;
    auto it = participant_keys_.find(v.user_id_);
    if (it != participant_keys_.end()) {
      sb << " pk=" << it->second;
    } else {
      sb << " pk=?";
    }
    sb << "}";
  });
  return sb.as_cslice().str();
}

td::Status CallVerificationChain::process_broadcast(std::string message,
                                                    e2e::object_ptr<e2e::e2e_chain_GroupBroadcast> broadcast) {
  td::Status status;
  td::UInt256 got_chain_hash{};
  downcast_call(*broadcast, td::overloaded([&](auto &broadcast) { got_chain_hash = broadcast.chain_hash_; }));
  if (got_chain_hash != last_block_hash_) {
    status = Error(E::InvalidBroadcast_InvalidBlockHash);
  }
  if (status.is_ok()) {
    downcast_call(
        *broadcast,
        td::overloaded([&](e2e::e2e_chain_groupBroadcastNonceCommit &commit) { status = process_broadcast(commit); },
                       [&](e2e::e2e_chain_groupBroadcastNonceReveal &reveal) { status = process_broadcast(reveal); }));
  }

  if (status.is_error()) {
    LOG(ERROR) << "Failed broadcast\n" << to_short_string(broadcast) << "\n\t" << status;
  } else {
    LOG(DEBUG) << "Applied broadcast\n\t" << to_short_string(broadcast) << "\n\t" << *this;
  }
  return status;
}

CallVerificationState CallVerificationChain::get_verification_state() const {
  return verification_state_;
}
CallVerificationWords CallVerificationChain::get_verification_words() const {
  return verification_words_;
}
td::Status CallVerificationChain::process_broadcast(e2e::e2e_chain_groupBroadcastNonceCommit &nonce_commit) {
  CHECK(nonce_commit.chain_height_ == height_);
  if (state_ != Commit) {
    return Error(E::InvalidBroadcast_NotInCommit);
  }
  auto user_id = nonce_commit.user_id_;
  auto it = participant_keys_.find(user_id);
  if (it == participant_keys_.end()) {
    return Error(E::InvalidBroadcast_UnknownUserId);
  }
  auto public_key = it->second;
  if (!may_skip_signatures_validation_) {
    TRY_STATUS(verify_signature(public_key, nonce_commit));
  }

  if (committed_.count(user_id) != 0) {
    return Error(E::InvalidBroadcast_AlreadyApplied);
  }

  committed_[user_id] = nonce_commit.nonce_hash_.as_slice().str();

  if (committed_.size() == participant_keys_.size()) {
    state_ = Reveal;
  }

  return td::Status::OK();
}
td::Status CallVerificationChain::process_broadcast(e2e::e2e_chain_groupBroadcastNonceReveal &nonce_reveal) {
  CHECK(nonce_reveal.chain_height_ == height_);
  if (state_ != Reveal) {
    return Error(E::InvalidBroadcast_NotInReveal);
  }
  auto user_id = nonce_reveal.user_id_;
  auto user_id_it = participant_keys_.find(user_id);
  if (user_id_it == participant_keys_.end()) {
    return Error(E::InvalidBroadcast_UnknownUserId);
  }
  auto public_key = user_id_it->second;
  if (!may_skip_signatures_validation_) {
    TRY_STATUS(verify_signature(public_key, nonce_reveal));
  }

  if (revealed_.count(user_id) != 0) {
    return Error(E::InvalidBroadcast_AlreadyApplied);
  }

  auto it = committed_.find(user_id);
  CHECK(it != committed_.end());
  auto expected_nonce_hash = it->second;
  auto received_nonce_hash = td::sha256(nonce_reveal.nonce_.as_slice());
  if (expected_nonce_hash != received_nonce_hash) {
    return Error(E::InvalidBroadcast_InvalidReveal);
  }

  revealed_[user_id] = nonce_reveal.nonce_.as_slice().str();

  CHECK(!verification_state_.emoji_hash);
  if (revealed_.size() == participant_keys_.size()) {
    auto nonces = td::transform(revealed_, [](auto &p) { return p.second; });
    std::sort(nonces.begin(), nonces.end());

    std::string full_nonce;
    for (auto &nonce : nonces) {
      full_nonce += nonce;
    }

    verification_state_.emoji_hash =
        MessageEncryption::hmac_sha512(full_nonce, last_block_hash_.as_slice()).as_slice().str();
    state_ = End;
  }
  return td::Status::OK();
}
CallEncryption::CallEncryption(td::int64 user_id, PrivateKey private_key)
    : user_id_(user_id), private_key_(std::move(private_key)) {
}
td::Status CallEncryption::add_shared_key(td::int32 epoch, td::SecureString key, GroupStateRef group_state) {
  sync();

  TRY_RESULT(self, group_state->get_participant(private_key_.to_public_key()));
  if (self.user_id != user_id_) {
    // should not happen
    return td::Status::Error("Wrong user id in state");
  }

  LOG(INFO) << "Add key from epoch: " << epoch;
  auto added = epochs_.emplace(epoch, EpochInfo(epoch, self.user_id, std::move(key), std::move(group_state))).second;
  CHECK(added);
  return td::Status::OK();
}
void CallEncryption::forget_shared_key(td::int32 epoch) {
  sync();
  epochs_to_forget_.emplace(td::Timestamp::in(FORGET_EPOCH_DELAY), epoch);
}

td::Result<std::string> CallEncryption::decrypt(td::int64 user_id, td::int32 channel_id, td::Slice encrypted_data) {
  sync();
  if (user_id == user_id_) {
    return td::Status::Error("Packet is encrypted by us");
  }
  td::TlParser parser(encrypted_data);
  auto head = static_cast<td::uint32>(parser.fetch_int());
  td::int32 epochs_n = head & 0xff;
  auto version = (head >> 8) & 0xff;
  auto reserved = head >> 16;

  if (version != 0) {
    return td::Status::Error("Unsupported protocol version");
  }
  if (reserved != 0) {
    return td::Status::Error("reserved part of head is not zero");
  }

  if (epochs_n > MAX_ACTIVE_EPOCHS) {
    return td::Status::Error("Too many active epochs");
  }

  using td::parse;

  std::vector<td::int32> epochs;
  for (int i = 0; i < epochs_n; i++) {
    epochs.push_back(parser.fetch_int());
  }
  auto unencrypted_header = encrypted_data.substr(0, encrypted_data.size() - parser.get_left_len());

  std::vector<td::Slice> encrypted_headers;
  for (int i = 0; i < epochs_n; i++) {
    auto encrypted_header = parser.fetch_string_raw<td::Slice>(32);
    encrypted_headers.emplace_back(encrypted_header);
  }

  auto encrypted_packet = parser.fetch_string_raw<td::Slice>(parser.get_left_len());
  parser.fetch_end();
  TRY_STATUS(parser.get_status());

  for (td::int32 i = 0; i < epochs_n; i++) {
    auto epoch = epochs[i];
    auto encrypted_header = encrypted_headers[i];
    if (auto it = epochs_.find(epoch); it != epochs_.end()) {
      auto &epoch_info = it->second;
      TRY_RESULT(one_time_secret,
                 MessageEncryption::decrypt_header(encrypted_header, encrypted_packet, epoch_info.secret_));
      return decrypt_packet_with_secret(user_id, channel_id, unencrypted_header, encrypted_packet, one_time_secret,
                                        epoch_info.group_state_);
    }
  }
  return Error(E::Decrypt_UnknownEpoch);
}

td::Result<std::string> CallEncryption::encrypt(td::int32 channel_id, td::Slice decrypted_data) {
  sync();

  // use all active epochs
  if (epochs_.empty()) {
    return Error(E::Encrypt_UnknownEpoch);
  }
  auto epochs_n = td::narrow_cast<td::int32>(epochs_.size());

  using td::store;
  std::string header_a = lambda_serialize([&](auto &storer) {
    store(epochs_n, storer);
    for (auto &[epoch_i, epoch] : epochs_) {
      store(epoch_i, storer);
    }
  });

  td::SecureString one_time_secret(32, 0);
  td::Random::secure_bytes(one_time_secret.as_mutable_slice());
  TRY_RESULT(encrypted_packet, encrypt_packet_with_secret(channel_id, header_a, decrypted_data, one_time_secret));

  std::vector<td::SecureString> encrypted_headers;
  for (auto &[epoch_i, epoch] : epochs_) {
    TRY_RESULT(encrypted_header, MessageEncryption::encrypt_header(one_time_secret, encrypted_packet, epoch.secret_));
    encrypted_headers.emplace_back(std::move(encrypted_header));
  }

  std::string header_b = lambda_serialize([&](auto &storer) {
    for (auto &encrypted_header : encrypted_headers) {
      CHECK(encrypted_header.size() == 32);
      storer.store_slice(encrypted_header);
    }
  });

  //LOG(ERROR) << decrypted_data.size() << " -> " << header_a.size() << " + " << header_b.size() << " + " << encrypted_packet.size();
  return header_a + header_b + encrypted_packet;
}

td::Result<std::string> CallEncryption::encrypt_packet_with_secret(td::int32 channel_id, td::Slice unencrypted_part,
                                                                   td::Slice packet, td::Slice one_time_secret) {
  TRY_STATUS(validate_channel_id(channel_id));
  auto &seqno = seqno_[channel_id];
  if (seqno == std::numeric_limits<td::uint32>::max()) {
    return td::Status::Error("Seqno overflow");
  }
  seqno++;

  td::UInt512 zero_signature{};
  auto payload = lambda_serialize([&](auto &storer) {
    using td::store;
    store(static_cast<td::int32>(channel_id), storer);
    store(seqno, storer);
    storer.store_slice(packet);
    storer.store_slice(zero_signature.as_mutable_slice());
  });
  CHECK(payload.size() >= 64);
  auto signature_offset = payload.size() - 64;
  auto encrypted_part = td::Slice(payload.data(), signature_offset);
  auto to_sign = MessageEncryption::hmac_sha512(unencrypted_part, encrypted_part);

  TRY_RESULT(signature, private_key_.sign(to_sign));
  td::MutableSlice(payload).substr(signature_offset).copy_from(signature.to_slice());

  // TODO: there is too much copies happening here. Almost all of them could be avoided
  return MessageEncryption::encrypt_data(payload, one_time_secret).as_slice().str();
}

td::Result<std::string> CallEncryption::decrypt_packet_with_secret(
    td::int64 expected_user_id, td::int32 expected_channel_id, td::Slice unencrypted_header, td::Slice encrypted_packet,
    td::Slice one_time_secret, const GroupStateRef &group_state) {
  TRY_RESULT(participant, group_state->get_participant(expected_user_id));
  TRY_RESULT(payload_str, MessageEncryption::decrypt_data(encrypted_packet, one_time_secret));
  auto payload = td::Slice(payload_str);
  if (payload.size() < 64) {
    return td::Status::Error("Not enough encryption data");
  }
  auto signature_offset = payload.size() - 64;

  auto encrypted_part = payload.substr(0, signature_offset);
  auto to_verify = MessageEncryption::hmac_sha512(unencrypted_header, encrypted_part);

  TRY_RESULT(signature, Signature::from_slice(payload.substr(signature_offset)));
  TRY_STATUS(participant.public_key.verify(to_verify, signature));

  // we know that this is packet create by some participant
  td::TlParser parser(payload);
  td::int32 channel_id;
  td::uint32 seqno{};
  td::UInt512 signature_to_skip{};
  parse(channel_id, parser);
  TRY_STATUS(validate_channel_id(channel_id));
  parse(seqno, parser);
  if (parser.get_left_len() < 64) {
    return td::Status::Error("Message is too short");
  }
  auto result = parser.template fetch_string_raw<std::string>(parser.get_left_len() - 64);
  parse(signature_to_skip, parser);
  parser.fetch_end();
  TRY_STATUS(parser.get_status());

  if (channel_id != expected_channel_id) {
    // currently ignore expected_channel_id
    // return td::Status::Error("Channel id mismatch");
  }
  TRY_STATUS(check_not_seen(participant.public_key, channel_id, seqno));
  mark_as_seen(participant.public_key, channel_id, seqno);
  return result;
}

td::Status CallEncryption::check_not_seen(const PublicKey &public_key, td::int32 channel_id, td::uint32 seqno) {
  auto &s = seen_[std::make_pair(public_key, channel_id)];
  if (s.empty()) {
    return td::Status::OK();
  }
  auto value = seqno;
  if (value < *s.begin()) {
    return td::Status::Error("Message is too old");
  }
  if (s.count(value) != 0) {
    return td::Status::Error("Message is already processed");
  }
  return td::Status::OK();
}

void CallEncryption::mark_as_seen(const PublicKey &public_key, td::int32 channel_id, td::uint32 seqno) {
  auto value = seqno;
  auto &s = seen_[std::make_pair(public_key, channel_id)];
  CHECK(s.insert(value).second);
  while (s.size() > 1024 || (!s.empty() && *s.begin() + 1024 < seqno)) {
    s.erase(s.begin());
  }
}

void CallEncryption::sync() {
  auto now = td::Timestamp::now();
  while (!epochs_to_forget_.empty() &&
         (epochs_to_forget_.front().first.is_in_past(now) || epochs_.size() > MAX_ACTIVE_EPOCHS)) {
    auto epoch = epochs_to_forget_.front().second;
    LOG(INFO) << "Forget key from epoch: " << epoch;
    epochs_.erase(epoch);
    epochs_to_forget_.pop();
  }
}

td::Status CallEncryption::validate_channel_id(td::int32 channel_id) {
  if (channel_id < 0 || channel_id > 1023) {
    return Error(E::InvalidCallChannelId);
  }
  return td::Status::OK();
}

CallVerification CallVerification::create(td::int64 user_id, PrivateKey private_key, const Blockchain &blockchain) {
  CallVerification result;
  result.user_id_ = user_id;
  result.private_key_ = std::move(private_key);
  result.on_new_main_block(blockchain);
  result.chain_.allow_delay();
  return result;
}

void CallVerification::on_new_main_block(const Blockchain &blockchain) {
  auto nonce = generate_nonce();
  td::UInt256 nonce_hash;
  td::sha256(nonce.as_mutable_slice(), nonce_hash.as_mutable_slice());

  auto height = td::narrow_cast<td::int32>(blockchain.get_height());
  auto last_block_hash = blockchain.last_block_hash_;
  auto nonce_commit_tl = e2e::e2e_chain_groupBroadcastNonceCommit({}, user_id_, height, last_block_hash, nonce_hash);
  nonce_commit_tl.signature_ = sign(private_key_, nonce_commit_tl).move_as_ok().to_u512();
  auto nonce_commit = serialize_boxed(nonce_commit_tl);

  height_ = height;
  last_block_hash_ = blockchain.last_block_hash_;
  nonce_ = nonce;
  sent_commit_ = true;
  sent_reveal_ = false;
  pending_outbound_messages_ = {nonce_commit};
  chain_.on_new_main_block(blockchain);
}

CallVerificationWords CallVerification::get_verification_words() const {
  return chain_.get_verification_words();
}

CallVerificationState CallVerification::get_verification_state() const {
  return chain_.get_verification_state();
}
std::vector<std::string> CallVerification::pull_outbound_messages() {
  std::vector<std::string> result;
  std::swap(result, pending_outbound_messages_);
  return result;
}

td::Status CallVerification::receive_inbound_message(td::Slice message) {
  TRY_STATUS(chain_.try_apply_block(message));

  if (chain_.get_state() == CallVerificationChain::Reveal && !sent_reveal_) {
    sent_reveal_ = true;
    auto nonce_reveal_tl = e2e::e2e_chain_groupBroadcastNonceReveal({}, user_id_, height_, last_block_hash_, nonce_);
    nonce_reveal_tl.signature_ = sign(private_key_, nonce_reveal_tl).move_as_ok().to_u512();
    auto nonce_reveal = serialize_boxed(nonce_reveal_tl);
    CHECK(pending_outbound_messages_.empty());
    pending_outbound_messages_.push_back(nonce_reveal);
  }
  return td::Status::OK();
}

Call::Call(td::int64 user_id, PrivateKey pk, ClientBlockchain blockchain)
    : user_id_(user_id)
    , private_key_(std::move(pk))
    , blockchain_(std::move(blockchain))
    , call_encryption_(user_id, private_key_) {
  CHECK(private_key_);
  LOG(INFO) << "Create call \n" << *this;
  call_verification_ = CallVerification::create(user_id_, private_key_, blockchain_.get_inner_chain());
}

td::Result<std::string> Call::create_zero_block(const PrivateKey &private_key, GroupStateRef group_state) {
  TRY_RESULT(blockchain, ClientBlockchain::create_empty());
  TRY_RESULT(changes, make_changes_for_new_state(std::move(group_state)));
  return blockchain.build_block(changes, private_key);
}
td::Result<std::string> Call::create_self_add_block(const PrivateKey &private_key, td::Slice previous_block_server,
                                                    const GroupParticipant &self) {
  TRY_RESULT(previous_block, Blockchain::from_server_to_local(previous_block_server.str()));
  TRY_RESULT(blockchain, ClientBlockchain::create_from_block(previous_block, private_key.to_public_key()));
  auto old_state = *blockchain.get_group_state();
  td::remove_if(old_state.participants,
                [&self](const GroupParticipant &participant) { return participant.user_id == self.user_id; });
  old_state.participants.push_back(self);
  auto new_group_state = std::make_shared<GroupState>(std::move(old_state));
  TRY_RESULT(changes, make_changes_for_new_state(std::move(new_group_state)));
  return blockchain.build_block(changes, private_key);
}

td::Result<Call> Call::create(td::int64 user_id, PrivateKey private_key, td::Slice last_block_server) {
  TRY_RESULT(last_block, Blockchain::from_server_to_local(last_block_server.str()));
  TRY_RESULT(blockchain, ClientBlockchain::create_from_block(last_block, private_key.to_public_key()));
  auto call = Call(user_id, std::move(private_key), std::move(blockchain));
  TRY_STATUS(call.update_group_shared_key());
  return call;
}

td::Result<std::string> Call::build_change_state(GroupStateRef new_group_state) const {
  TRY_STATUS(get_status());
  TRY_RESULT(changes, make_changes_for_new_state(std::move(new_group_state)));
  return blockchain_.build_block(changes, private_key_);
}

td::Result<std::vector<Change>> Call::make_changes_for_new_state(GroupStateRef group_state) {
  TRY_RESULT(e_private_key, PrivateKey::generate());
  td::SecureString group_shared_key(32);
  td::Random::secure_bytes(group_shared_key.as_mutable_slice());

  td::SecureString one_time_secret(32);
  td::Random::secure_bytes(one_time_secret.as_mutable_slice());

  auto encrypted_group_shared_key = MessageEncryption::encrypt_data(group_shared_key, one_time_secret);

  std::vector<td::int64> dst_user_id;
  std::vector<std::string> dst_header;
  for (auto &participant : group_state->participants) {
    auto public_key = participant.public_key;
    TRY_RESULT(shared_key, e_private_key.compute_shared_secret(public_key));
    dst_user_id.push_back(participant.user_id);
    TRY_RESULT(header, MessageEncryption::encrypt_header(one_time_secret, encrypted_group_shared_key, shared_key));
    dst_header.push_back(header.as_slice().str());
  }
  auto change_set_shared_key = Change{ChangeSetSharedKey{std::make_shared<GroupSharedKey>(
      GroupSharedKey{e_private_key.to_public_key(), encrypted_group_shared_key.as_slice().str(), std::move(dst_user_id),
                     std::move(dst_header)})}};
  auto change_set_group_state = Change{ChangeSetGroupState{std::move(group_state)}};

  return std::vector<Change>{std::move(change_set_group_state), std::move(change_set_shared_key)};
}

td::Result<td::int32> Call::get_height() const {
  TRY_STATUS(get_status());
  return td::narrow_cast<td::int32>(blockchain_.get_height());
}

td::Result<GroupStateRef> Call::get_group_state() const {
  TRY_STATUS(get_status());
  return blockchain_.get_group_state();
}

td::Status Call::apply_block(td::Slice server_block) {
  TRY_STATUS(get_status());
  TRY_RESULT(block, Blockchain::from_server_to_local(server_block.str()));
  auto status = do_apply_block(block);
  if (status.is_error()) {
    LOG(ERROR) << "Failed to apply block: " << status << "\n" << Block::from_tl_serialized(block);
    status_ = std::move(status);
  } else {
    LOG(INFO) << "Block has been applied\n" << *this;
  }

  return get_status();
}
td::Status Call::do_apply_block(td::Slice block) {
  TRY_RESULT(changes, blockchain_.try_apply_block(block));
  call_verification_.on_new_main_block(blockchain_.get_inner_chain());
  TRY_STATUS(update_group_shared_key());
  return td::Status::OK();
}

td::Result<td::SecureString> Call::decrypt_shared_key() {
  auto group_shared_key = blockchain_.get_group_shared_key();
  for (size_t i = 0; i < group_shared_key->dest_user_id.size(); i++) {
    if (group_shared_key->dest_user_id[i] == user_id_) {
      TRY_RESULT(shared_key, private_key_.compute_shared_secret(group_shared_key->ek));
      TRY_RESULT(one_time_secret,
                 MessageEncryption::decrypt_header(group_shared_key->dest_header[i],
                                                   group_shared_key->encrypted_shared_key, shared_key));
      TRY_RESULT(decrypted_shared_key,
                 MessageEncryption::decrypt_data(group_shared_key->encrypted_shared_key, one_time_secret));
      if (decrypted_shared_key.size() != 32) {
        return td::Status::Error("Invalid shared key (size != 32)");
      }
      return decrypted_shared_key;
    }
  }
  return td::Status::Error("Could not find user_id in group_shared_key");
}

td::Status Call::update_group_shared_key() {
  // NB: we drop key immediately, we don't want old key to be active due to some errors later
  group_shared_key_ = {};
  call_encryption_.forget_shared_key(td::narrow_cast<td::int32>(blockchain_.get_height() - 1));

  auto group_state = blockchain_.get_group_state();

  auto r_participant = group_state->get_participant(private_key_.to_public_key());
  if (r_participant.is_error()) {
    return Error(E::InvalidCallGroupState_NotParticipant);
  }
  auto participant = r_participant.move_as_ok();
  if (participant.user_id != user_id_) {
    return Error(E::InvalidCallGroupState_WrongUserId);
  }

  TRY_RESULT_ASSIGN(group_shared_key_, decrypt_shared_key());

  return call_encryption_.add_shared_key(td::narrow_cast<td::int32>(blockchain_.get_height()), group_shared_key_.copy(),
                                         group_state);
}

td::StringBuilder &operator<<(td::StringBuilder &sb, const CallVerificationChain &chain) {
  sb << "Verification {height=" << chain.height_ << " state=";
  switch (chain.state_) {
    case CallVerificationChain::State::Commit:
      sb << "commit";
      break;
    case CallVerificationChain::State::Reveal:
      sb << "reveal";
      break;
    case CallVerificationChain::State::End:
      sb << "done";
      break;
  }
  sb << " commit_n=" << chain.committed_.size() << " reveal_n=" << chain.revealed_.size() << "}";
  switch (chain.state_) {
    case CallVerificationChain::State::Commit:
      sb << "\n\t\tcommit="
         << td::transform(chain.committed_, [&](auto &key) { return chain.participant_keys_.at(key.first); });
      break;
    case CallVerificationChain::State::Reveal:
      sb << "\n\t\treveal="
         << td::transform(chain.revealed_, [&](auto &key) { return chain.participant_keys_.at(key.first); });
      break;
    case CallVerificationChain::State::End:
      break;
  }
  return sb;
}

td::StringBuilder &operator<<(td::StringBuilder &sb, const CallVerification &verification) {
  return sb << verification.chain_;
}
td::StringBuilder &operator<<(td::StringBuilder &sb, const Call &call) {
  auto status = call.get_status();
  sb << "Call{" << call.blockchain_.get_height() << ":" << call.private_key_.to_public_key() << "}";
  if (status.is_error()) {
    sb << "\nCALL_FAILED: " << call.status_;
  }
  auto group_state = call.blockchain_.get_group_state();
  sb << "\n\tusers=" << td::transform(group_state->participants, [](auto &p) { return p.user_id; });
  sb << "\n\tpkeys=" << td::transform(group_state->participants, [](auto &p) { return p.public_key; });
  sb << "\n\t" << call.call_verification_;
  return sb;
}
}  // namespace tde2e_core
