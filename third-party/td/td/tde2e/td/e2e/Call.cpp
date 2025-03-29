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

#include <limits>
#include <memory>
#include <utility>

namespace tde2e_core {

CallVerificationChain::State CallVerificationChain::get_state() const {
  return state_;
}

void CallVerificationChain::on_new_main_block(const Blockchain &blockhain) {
  state_ = Commit;
  CHECK(blockhain.get_height() >= height_);
  height_ = td::narrow_cast<td::int32>(blockhain.get_height());
  last_block_hash_ = blockhain.last_block_hash_;
  verification_state_ = {};
  verification_state_.height = height_;

  verification_words_ = CallVerificationWords{blockhain.last_block_.height_,
                                              Mnemonic::generate_verification_words(last_block_hash_.as_slice())};
  auto group_state = *blockhain.state_.group_state_;
  committed_ = {};
  revealed_ = {};
  received_messages_ = {};

  participant_keys_ = {};
  for (auto &participant : group_state.participants) {
    participant_keys_.emplace(participant.public_key, participant.user_id);
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
  td::Status status;

  td::int32 broadcast_height{-1};
  downcast_call(*kv_broadcast, td::overloaded([&](auto &broadcast) { broadcast_height = broadcast.chain_height_; }));

  if (broadcast_height < height_) {
    LOG(INFO) << "skip old broadcast " << to_short_string(kv_broadcast);
    // broadcast is too old
    return td::Status::OK();
  }

  if (broadcast_height > height_) {
    LOG(INFO) << "delay broadcast " << to_short_string(kv_broadcast);
    delayed_broadcasts_[broadcast_height].emplace_back(message.str(), std::move(kv_broadcast));
    return td::Status::OK();
  }

  return process_broadcast(message.str(), std::move(kv_broadcast));
}
std::string CallVerificationChain::to_short_string(e2e::object_ptr<e2e::e2e_chain_GroupBroadcast> &broadcast) {
  td::StringBuilder sb;
  downcast_call(*broadcast, td::overloaded([&](e2e::e2e_chain_groupBroadcastNonceCommit &commit) { sb << "CommitBroadcast"; },
                                           [&](e2e::e2e_chain_groupBroadcastNonceReveal &reveal) { sb << "RevealBroadcast"; }));
  downcast_call(*broadcast, [&](auto &v) {
    sb << "{height=" << v.chain_height_;
    auto public_key = PublicKey::from_u256(v.public_key_);
    auto it = participant_keys_.find(public_key);
    if (it != participant_keys_.end()) {
      sb << " user_id=" << it->second;
    } else {
      sb << " user_id=?";
    }
    sb << " " << public_key;
    sb << "}";
  });
  return sb.as_cslice().str();
}

td::Status CallVerificationChain::process_broadcast(std::string message,
                                                    e2e::object_ptr<e2e::e2e_chain_GroupBroadcast> broadcast) {
  td::Status status;
  downcast_call(
      *broadcast,
      td::overloaded([&](e2e::e2e_chain_groupBroadcastNonceCommit &commit) { status = process_broadcast(commit); },
                     [&](e2e::e2e_chain_groupBroadcastNonceReveal &reveal) { status = process_broadcast(reveal); }));
  if (status.is_ok()) {
    received_messages_.push_back(std::move(message));
  }

  if (status.is_error()) {
    LOG(ERROR) << "Failed broadcast\n" << to_short_string(broadcast) << "\n\t" << status;
  } else {
    LOG(INFO) << "Applied broadcast\n\t" << to_short_string(broadcast) << "\n\t" << *this;
  }
  return status;
}

CallVerificationState CallVerificationChain::get_verification_state() const {
  return verification_state_;
}
CallVerificationWords CallVerificationChain::get_verification_words() const {
  return verification_words_;
}
td::Span<std::string> CallVerificationChain::received_messages() const {
  return received_messages_;
}
td::Status CallVerificationChain::process_broadcast(e2e::e2e_chain_groupBroadcastNonceCommit &nonce_commit) {
  if (nonce_commit.chain_height_ != height_) {
    return td::Status::Error(PSLICE() << "Invalid height expected=" << height_
                                      << " received=" << nonce_commit.chain_height_);
  }
  if (state_ != Commit) {
    return td::Status::Error("We are not in commit state");
  }
  auto public_key = PublicKey::from_u256(nonce_commit.public_key_);
  if (participant_keys_.count(public_key) == 0) {
    return td::Status::Error("NonceCommit: unknown public key");
  }
  TRY_STATUS(verify_signature(public_key, nonce_commit));

  if (committed_.count(public_key) != 0) {
    return td::Status::Error("NonceCommit: duplicate commit");
  }

  committed_[public_key] = nonce_commit.nonce_hash_.as_slice().str();

  if (committed_.size() == participant_keys_.size()) {
    state_ = Reveal;
  }

  return td::Status::OK();
}
td::Status CallVerificationChain::process_broadcast(e2e::e2e_chain_groupBroadcastNonceReveal &nonce_reveal) {
  if (nonce_reveal.chain_height_ != height_) {
    return td::Status::Error("NonceReveal: Invalid height");
  }
  if (state_ != Reveal) {
    return td::Status::Error("We are not in reveal state");
  }
  auto public_key = PublicKey::from_u256(nonce_reveal.public_key_);
  if (participant_keys_.count(public_key) == 0) {
    return td::Status::Error("NonceReveal: unknown public key");
  }
  TRY_STATUS(verify_signature(public_key, nonce_reveal));

  if (revealed_.count(public_key) != 0) {
    return td::Status::Error("NonceReveal: duplicate reveal");
  }

  auto it = committed_.find(public_key);
  CHECK(it != committed_.end());
  auto expected_nonce_hash = it->second;
  auto received_nonce_hash = td::sha256(nonce_reveal.nonce_.as_slice());
  if (expected_nonce_hash != received_nonce_hash) {
    return td::Status::Error("NonceReveal: hash(nonce) != nonce_hash");
  }

  revealed_[public_key] = nonce_reveal.nonce_.as_slice().str();

  CHECK(!verification_state_.emoji_hash);
  if (revealed_.size() == participant_keys_.size()) {
    std::string full_nonce;
    for (auto &[key, nonce] : revealed_) {
      full_nonce += nonce;
    }
    verification_state_.emoji_hash =
        MessageEncryption::combine_secrets(last_block_hash_.as_slice(), full_nonce).as_slice().str();
    state_ = End;
  }
  return td::Status::OK();
}
CallEncryption::CallEncryption(PrivateKey private_key) : private_key_(std::move(private_key)) {
}
td::Status CallEncryption::add_shared_key(td::int32 epoch, td::SecureString key, GroupStateRef group_state) {
  forget_old_epochs();
  CHECK(!o_last_epoch_ || *o_last_epoch_ + 1 == epoch);
  if (o_last_epoch_) {
    epochs_to_forget_.emplace(td::Timestamp::in(10), *o_last_epoch_);
  }
  o_last_epoch_ = epoch;

  TRY_RESULT(self, group_state->get_participant(private_key_.to_public_key()));

  auto added =
      encryptor_by_epoch_
          .emplace(epoch, EpochEncryptor(epoch, self.user_id, std::move(key), std::move(group_state), private_key_))
          .second;
  CHECK(added);
  return td::Status::OK();
}
td::Result<std::string> CallEncryption::decrypt(td::Slice encrypted_data) {
  forget_old_epochs();
  td::TlParser parser(encrypted_data);
  auto epoch = parser.fetch_int();
  TRY_STATUS(parser.get_status());
  auto it = encryptor_by_epoch_.find(epoch);
  if (it == encryptor_by_epoch_.end()) {
    return Error(E::Decrypt_UnknownEpoch);
  }
  return it->second.decrypt(encrypted_data);
}
td::Result<std::string> CallEncryption::encrypt(td::Slice decrypted_data) {
  CHECK(o_last_epoch_);
  auto it = encryptor_by_epoch_.find(*o_last_epoch_);
  if (it == encryptor_by_epoch_.end()) {
    return Error(E::Encrypt_UnknownEpoch);
  }
  return it->second.encrypt(decrypted_data);
}
CallEncryption::EpochEncryptor::EpochEncryptor(td::int32 epoch, td::int64 user_id, td::SecureString secret,
                                               GroupStateRef group_state, PrivateKey private_key)
    : epoch_(epoch)
    , user_id_(user_id)
    , secret_(std::move(secret))
    , group_state_(std::move(group_state))
    , private_key_(std::move(private_key)) {
}
td::Result<std::string> CallEncryption::EpochEncryptor::decrypt(td::Slice encrypted_data) {
  td::int32 epoch{};
  using td::parse;
  {
    td::TlParser parser(encrypted_data);
    parse(epoch, parser);
    TRY_STATUS(parser.get_status());
  }

  TRY_RESULT(payload, MessageEncryption::decrypt_data(encrypted_data.substr(4), secret_));
  td::TlParser parser(payload);
  td::int64 user_id;
  td::uint32 seqno{};
  td::UInt512 signature{};
  parse(user_id, parser);
  parse(seqno, parser);
  if (parser.get_left_len() < 64) {
    return td::Status::Error("Message is too short");
  }
  // TODO: check replay
  auto result = parser.template fetch_string_raw<std::string>(parser.get_left_len() - 64);
  parse(signature, parser);
  parser.fetch_end();
  TRY_STATUS(parser.get_status());

  TRY_STATUS(check_not_seen(user_id, seqno));

  // verify signature
  TRY_RESULT(participant, group_state_->get_participant(user_id));
  TRY_STATUS(
      participant.public_key.verify(td::Slice(payload.data(), payload.size() - 64), Signature::from_u512(signature)));

  mark_as_seen(user_id, seqno);

  return result;
}
td::Result<std::string> CallEncryption::EpochEncryptor::encrypt(td::Slice decrypted_data) {
  if (seqno_ == std::numeric_limits<td::uint32>::max()) {
    return td::Status::Error("Seqno overflow");
  }
  seqno_++;

  auto store = [&](auto &storer) {
    using td::store;
    store(user_id_, storer);
    store(seqno_, storer);
    storer.store_slice(decrypted_data);
  };
  td::TlStorerCalcLength calc_length;
  store(calc_length);
  auto length = calc_length.get_length();

  std::string payload(length + 64, '\0');
  td::TlStorerUnsafe storer(td::MutableSlice(payload).ubegin());
  store(storer);

  TRY_RESULT(signature, private_key_.sign(td::Slice(payload.data(), length)));
  td::store(signature.to_u512(), storer);

  // TODO: there is too much copies happening here. Almost all of them could be avoided
  auto encrypted = MessageEncryption::encrypt_data(payload, secret_);
  std::string res(4 + encrypted.size(), '\0');
  td::TlStorerUnsafe res_storer(td::MutableSlice(res).ubegin());
  td::store(epoch_, res_storer);
  res_storer.store_slice(encrypted);

  // LOG(ERROR) << decrypted_data.size() << " +info-> " << length << " +signature-> " << payload.size()
  //            << " +padding&msg_id-> " << encrypted.size() << " +epoch-> " << res.size();
  return res;
}
td::Status CallEncryption::EpochEncryptor::check_not_seen(td::int64 user_id, td::uint32 seqno) {
  auto &s = seen_[user_id];
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
void CallEncryption::EpochEncryptor::mark_as_seen(td::int64 user_id, td::uint32 seqno) {
  auto value = seqno;
  auto &s = seen_[user_id];
  CHECK(s.insert(value).second);
  while (s.size() > 1024) {
    s.erase(s.begin());
  }
}
void CallEncryption::forget_old_epochs() {
  if (epochs_to_forget_.empty()) {
    return;
  }
  auto now = td::Timestamp::now();
  while (!epochs_to_forget_.empty() && epochs_to_forget_.front().first.is_in_past(now)) {
    encryptor_by_epoch_.erase(epochs_to_forget_.front().second);
    epochs_to_forget_.pop();
  }
}

CallVerification CallVerification::create(PrivateKey private_key, const Blockchain &blockchain) {
  CallVerification result;
  result.private_key_ = std::move(private_key);
  result.on_new_main_block(blockchain);
  return result;
}

void CallVerification::on_new_main_block(const Blockchain &blockchain) {
  auto nonce = generate_nonce();
  td::UInt256 nonce_hash;
  td::sha256(nonce.as_mutable_slice(), nonce_hash.as_mutable_slice());

  auto height = td::narrow_cast<td::int32>(blockchain.get_height());
  auto nonce_commit_tl =
      e2e::e2e_chain_groupBroadcastNonceCommit({}, private_key_.to_public_key().to_u256(), height, nonce_hash);
  nonce_commit_tl.signature_ = sign(private_key_, nonce_commit_tl).move_as_ok().to_u512();
  auto nonce_commit = serialize_boxed(nonce_commit_tl);

  height_ = height;
  ;
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
    auto nonce_reveal_tl =
        e2e::e2e_chain_groupBroadcastNonceReveal({}, private_key_.to_public_key().to_u256(), height_, nonce_);
    nonce_reveal_tl.signature_ = sign(private_key_, nonce_reveal_tl).move_as_ok().to_u512();
    auto nonce_reveal = serialize_boxed(nonce_reveal_tl);
    pending_outbound_messages_.clear();
    pending_outbound_messages_.push_back(nonce_reveal);
  }
  return td::Status::OK();
}

Call::Call(PrivateKey pk, ClientBlockchain blockchain)
    : private_key_(std::move(pk)), blockchain_(std::move(blockchain)), call_encryption_(private_key_) {
  CHECK(private_key_);
  LOG(INFO) << "Create call \n" << *this;
  call_verification_ = CallVerification::create(private_key_, blockchain_.get_inner_chain());
}

td::Result<std::string> Call::create_zero_block(const PrivateKey &private_key, GroupStateRef group_state) {
  TRY_RESULT(blockchain, ClientBlockchain::create_empty());
  TRY_RESULT(changes, make_changes_for_new_state(std::move(group_state)));
  return blockchain.build_block(changes, private_key);
}
td::Result<std::string> Call::create_self_add_block(const PrivateKey &private_key, td::Slice previous_block,
                                                    const GroupParticipant &self) {
  TRY_RESULT(blockchain, ClientBlockchain::create_from_block(previous_block, private_key.to_public_key()));
  auto old_state = *blockchain.get_group_state();
  td::remove_if(old_state.participants,
                [&self](const GroupParticipant &participant) { return participant.user_id == self.user_id; });
  old_state.participants.push_back(self);
  auto new_group_state = std::make_shared<GroupState>(std::move(old_state));
  TRY_RESULT(changes, make_changes_for_new_state(std::move(new_group_state)));
  return blockchain.build_block(changes, private_key);
}

td::Result<Call> Call::create(PrivateKey private_key, td::Slice last_block) {
  TRY_RESULT(blockchain, ClientBlockchain::create_from_block(last_block, private_key.to_public_key()));
  auto call = Call(std::move(private_key), std::move(blockchain));
  TRY_STATUS(call.update_group_shared_key());
  return call;
}

td::Result<std::string> Call::build_change_state(GroupStateRef new_group_state) const {
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
    auto header = MessageEncryption::encrypt_header(one_time_secret, encrypted_group_shared_key, shared_key);
    dst_header.push_back(header.as_slice().str());
  }
  auto change_set_shared_key = Change{ChangeSetSharedKey{std::make_shared<GroupSharedKey>(
      GroupSharedKey{e_private_key.to_public_key(), encrypted_group_shared_key.as_slice().str(), std::move(dst_user_id),
                     std::move(dst_header)})}};
  auto change_set_group_state = Change{ChangeSetGroupState{std::move(group_state)}};

  return std::vector<Change>{std::move(change_set_group_state), std::move(change_set_shared_key)};
}

td::int32 Call::get_height() const {
  return td::narrow_cast<td::int32>(blockchain_.get_height());
}

td::Result<GroupStateRef> Call::get_group_state() const {
  return blockchain_.get_group_state();
}

td::Status Call::apply_block(td::Slice block) {
  auto status = do_apply_block(block);
  if (status.is_error()) {
    LOG(ERROR) << "Failed to apply block: " << status << "\n" << Block::from_tl_serialized(block);
  } else {
    LOG(INFO) << "Block has been applied\n" << *this;
  }

  return status;
}
td::Status Call::do_apply_block(td::Slice block) {
  TRY_RESULT(changes, blockchain_.try_apply_block(block));
  bool changed_shared_key = false;
  for (auto &change : changes) {
    if (std::holds_alternative<ChangeSetSharedKey>(change.value)) {
      changed_shared_key = true;
    }
    if (std::holds_alternative<ChangeSetGroupState>(change.value)) {
      changed_shared_key = true;
    }
  }
  call_verification_.on_new_main_block(blockchain_.get_inner_chain());
  if (changed_shared_key) {
    TRY_STATUS(update_group_shared_key());
  }
  return td::Status::OK();
}

td::Status Call::update_group_shared_key() {
  auto group_shared_key = blockchain_.get_group_shared_key();
  auto group_state = blockchain_.get_group_state();
  TRY_RESULT(participant, group_state->get_participant(private_key_.to_public_key()));

  for (size_t i = 0; i < group_shared_key->dest_user_id.size(); i++) {
    if (group_shared_key->dest_user_id[i] == participant.user_id) {
      TRY_RESULT(shared_key, private_key_.compute_shared_secret(group_shared_key->ek));
      TRY_RESULT(one_time_secret,
                 MessageEncryption::decrypt_header(group_shared_key->dest_header[i],
                                                   group_shared_key->encrypted_shared_key, shared_key));
      TRY_RESULT(decrypted_group_shared_key,
                 MessageEncryption::decrypt_data(group_shared_key->encrypted_shared_key, one_time_secret));
      group_shared_key_ = std::move(decrypted_group_shared_key);
      return call_encryption_.add_shared_key(td::narrow_cast<td::int32>(blockchain_.get_height()),
                                             group_shared_key_.copy(), group_state);
    }
  }
  group_shared_key_ = td::SecureString();

  return td::Status::Error("Could not find user_id in group_shared_key");
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
  sb << "Call{" << call.get_height() << ":" << call.private_key_.to_public_key() << "}";
  auto group_state = call.get_group_state().move_as_ok();
  sb << "\n\tusers=" << td::transform(group_state->participants, [](auto &p) { return p.user_id; });
  sb << "\n\tpkeys=" << td::transform(group_state->participants, [](auto &p) { return p.public_key; });
  sb << "\n\t" << call.call_verification_;

  return sb;
}
}  // namespace tde2e_core
