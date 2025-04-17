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

#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/UInt.h"
#include "td/utils/VectorQueue.h"

#include <map>
#include <set>
#include <utility>

namespace tde2e_core {

using tde2e_api::CallVerificationState;
using tde2e_api::CallVerificationWords;

struct CallVerificationChain {
  enum State {
    End,
    Commit,
    Reveal,
  };
  State get_state() const;
  void on_new_main_block(const Blockchain &blockhain);
  td::Status try_apply_block(td::Slice message);
  std::string to_short_string(e2e::object_ptr<e2e::e2e_chain_GroupBroadcast> &broadcast);

  CallVerificationState get_verification_state() const;
  CallVerificationWords get_verification_words() const;

  void set_user_id(td::int64 user_id) {
    user_id_ = user_id;
  }
  void allow_delay() {
    delay_allowed_ = true;
  }
  void skip_signatures_validation() {
    may_skip_signatures_validation_ = true;
  }

  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const CallVerificationChain &chain);

 private:
  td::Status process_broadcast(td::Slice message, e2e::object_ptr<e2e::e2e_chain_GroupBroadcast> broadcast);
  td::Status process_broadcast(e2e::e2e_chain_groupBroadcastNonceCommit &nonce_commit);
  td::Status process_broadcast(e2e::e2e_chain_groupBroadcastNonceReveal &nonce_reveal);

  State state_{End};
  CallVerificationState verification_state_;
  CallVerificationWords verification_words_;
  td::int32 height_{-1};
  td::UInt256 last_block_hash_{};
  std::map<td::int64, PublicKey> participant_keys_;
  std::map<td::int64, std::string> committed_;
  std::map<td::int64, std::string> revealed_;

  td::int64 user_id_{};

  td::Timestamp commit_at_{};
  td::Timestamp reveal_at_{};
  td::Timestamp done_at_{};
  struct UserState {
    td::Timestamp receive_commit_at_{};
    td::Timestamp receive_reveal_at_{};
  };
  std::map<td::int64, UserState> users_;

  bool delay_allowed_{false};
  bool may_skip_signatures_validation_{false};
  std::map<td::int32, std::vector<std::pair<std::string, e2e::object_ptr<e2e::e2e_chain_GroupBroadcast>>>>
      delayed_broadcasts_;
};

class CallEncryption {
 public:
  CallEncryption(td::int64 user_id, PrivateKey private_key);
  td::Status add_shared_key(td::int32 epoch, td::UInt256 epoch_hash, td::SecureString key, GroupStateRef group_state);
  void forget_shared_key(td::int32 epoch, td::UInt256 epoch_hash);

  td::Result<std::string> decrypt(td::int64 expected_user_id, td::int32 expected_channel_id, td::Slice packet);
  td::Result<std::string> encrypt(td::int32 channel_id, td::Slice data, size_t unencrypted_header_length);

 private:
  static constexpr double FORGET_EPOCH_DELAY = 10;
  static constexpr td::int32 MAX_ACTIVE_EPOCHS = 15;
  td::int64 user_id_{};
  PrivateKey private_key_;

  struct EpochInfo {
    EpochInfo(td::int32 epoch, td::UInt256 epoch_hash, td::int64 user_id, td::SecureString secret,
              GroupStateRef group_state)
        : epoch_(epoch)
        , epoch_hash_(epoch_hash)
        , user_id_(user_id)
        , secret_(std::move(secret))
        , group_state_(std::move(group_state)) {
    }

    td::int32 epoch_{};
    td::UInt256 epoch_hash_{};
    td::int64 user_id_{};
    td::SecureString secret_;
    GroupStateRef group_state_;
  };

  std::map<td::int32, td::uint32> seqno_;
  std::map<td::int32, EpochInfo> epochs_;
  std::map<td::UInt256, td::int32> epoch_by_hash_;
  td::VectorQueue<std::pair<td::Timestamp, td::int32>> epochs_to_forget_;
  std::map<std::pair<PublicKey, td::int32>, std::set<td::uint32>> seen_;

  void sync();

  td::Result<std::string> encrypt_packet_with_secret(td::int32 channel_id, td::Slice header, td::Slice packet,
                                                     td::Slice one_time_secret);
  td::Result<std::string> decrypt_packet_with_secret(td::int64 expected_user_id, td::int32 expected_channel_id,
                                                     td::Slice unencrypted_header, td::Slice unencrypted_prefix,
                                                     td::Slice encrypted_packet, td::Slice one_time_secret,
                                                     const GroupStateRef &group_state);
  td::Status check_not_seen(const PublicKey &public_key, td::int32 channel_id, td::uint32 seqno);
  void mark_as_seen(const PublicKey &public_key, td::int32 channel_id, td::uint32 seqno);
  static td::Status validate_channel_id(td::int32 channel_id);
};

class CallVerification {
 public:
  static CallVerification create(td::int64 user_id, PrivateKey private_key, const Blockchain &blockchain);
  void on_new_main_block(const Blockchain &blockhain);
  CallVerificationState get_verification_state() const;
  std::vector<std::string> pull_outbound_messages();
  CallVerificationWords get_verification_words() const;
  td::Status receive_inbound_message(td::Slice message);

  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const CallVerification &verification);

 private:
  td::int64 user_id_{};
  PrivateKey private_key_;
  CallVerificationChain chain_;
  std::vector<tde2e_api::Bytes> pending_outbound_messages_;
  bool sent_commit_{false};
  bool sent_reveal_{false};

  td::int32 height_{-1};
  td::UInt256 last_block_hash_{};
  td::UInt256 nonce_{};
};

struct Call {
  static td::Result<std::string> create_zero_block(const PrivateKey &private_key, GroupStateRef group_state);
  static td::Result<std::string> create_self_add_block(const PrivateKey &private_key, td::Slice previous_block,
                                                       const GroupParticipant &self);

  static td::Result<Call> create(td::int64 user_id, PrivateKey private_key, td::Slice last_block);
  static td::Result<std::vector<Change>> make_changes_for_new_state(GroupStateRef group_state);

  td::Result<std::string> build_change_state(GroupStateRef new_group_state) const;
  td::Result<td::int32> get_height() const;
  td::Result<GroupStateRef> get_group_state() const;

  td::Status apply_block(td::Slice block);

  td::Status get_status() const {
    if (status_.is_error()) {
      return Error(E::CallFailed, PSLICE() << status_);
    }
    return td::Status::OK();
  }

  td::Result<td::SecureString> shared_key() const {
    TRY_STATUS(get_status());
    return group_shared_key_.copy();
  }

  td::Result<std::string> decrypt(td::int64 user_id, td::int32 channel_id, td::Slice encrypted_data) {
    TRY_STATUS(get_status());
    return call_encryption_.decrypt(user_id, channel_id, encrypted_data);
  }
  td::Result<std::string> encrypt(td::int32 channel_id, td::Slice decrypted_data, size_t unencrypted_prefix_size) {
    TRY_STATUS(get_status());
    return call_encryption_.encrypt(channel_id, decrypted_data, unencrypted_prefix_size);
  }

  td::Result<std::vector<std::string>> pull_outbound_messages() {
    TRY_STATUS(get_status());
    return call_verification_.pull_outbound_messages();
  }

  td::Result<CallVerificationState> get_verification_state() const {
    TRY_STATUS(get_status());
    return call_verification_.get_verification_state();
  }
  td::Result<CallVerificationWords> get_verification_words() const {
    TRY_STATUS(get_status());
    return call_verification_.get_verification_words();
  }
  td::Result<CallVerificationState> receive_inbound_message(td::Slice verification_message) {
    TRY_STATUS(get_status());
    // For now, don't fail the call in case of some errors
    TRY_RESULT(local_verification_message, Blockchain::from_server_to_local(verification_message.str()));
    TRY_STATUS(call_verification_.receive_inbound_message(local_verification_message));
    return get_verification_state();
  }
  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const Call &call);

 private:
  td::Status status_{td::Status::OK()};
  td::int64 user_id_{0};
  PrivateKey private_key_;
  ClientBlockchain blockchain_;
  CallVerification call_verification_;
  CallEncryption call_encryption_;
  td::SecureString group_shared_key_;

  Call(td::int64 user_id, PrivateKey pk, ClientBlockchain blockchain);

  td::Status update_group_shared_key();
  td::Status do_apply_block(td::Slice block);
  td::Result<td::SecureString> decrypt_shared_key();
};

}  // namespace tde2e_core
