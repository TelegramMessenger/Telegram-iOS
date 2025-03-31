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

#include "td/utils/HashTableUtils.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"
#include "td/utils/UInt.h"
#include "td/utils/VectorQueue.h"

#include <map>
#include <set>
#include <unordered_map>
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
  td::Status process_broadcast(std::string message, e2e::object_ptr<e2e::e2e_chain_GroupBroadcast> broadcast);

  CallVerificationState get_verification_state() const;
  CallVerificationWords get_verification_words() const;

  td::Span<std::string> received_messages() const;

  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const CallVerificationChain &chain);

 private:
  td::Status process_broadcast(e2e::e2e_chain_groupBroadcastNonceCommit &nonce_commit);
  td::Status process_broadcast(e2e::e2e_chain_groupBroadcastNonceReveal &nonce_reveal);

  State state_{End};
  CallVerificationState verification_state_;
  CallVerificationWords verification_words_;
  td::int32 height_{-1};
  td::UInt256 last_block_hash_{};
  std::map<PublicKey, td::int64> participant_keys_;
  std::map<PublicKey, std::string> committed_;
  std::map<PublicKey, std::string> revealed_;

  std::vector<std::string> received_messages_;

  std::map<td::int32, std::vector<std::pair<std::string, e2e::object_ptr<e2e::e2e_chain_GroupBroadcast>>>>
      delayed_broadcasts_;
};

class CallEncryption {
 public:
  explicit CallEncryption(PrivateKey private_key);
  td::Status add_shared_key(td::int32 epoch, td::SecureString key, GroupStateRef group_state);

  td::Result<std::string> decrypt(td::Slice encrypted_data);

  td::Result<std::string> encrypt(td::Slice decrypted_data);

 private:
  PrivateKey private_key_;

  class EpochEncryptor {
   public:
    EpochEncryptor(td::int32 epoch, td::int64 user_id, td::SecureString secret, GroupStateRef group_state,
                   PrivateKey private_key);

    td::Result<std::string> decrypt(td::Slice encrypted_data);
    td::Result<std::string> encrypt(td::Slice decrypted_data);

    td::Status check_not_seen(td::int64 user_id, td::uint32 seqno);
    void mark_as_seen(td::int64 user_id, td::uint32 seqno);

   private:
    td::int32 epoch_;
    td::int64 user_id_;
    td::uint32 seqno_{0};
    td::SecureString secret_;
    GroupStateRef group_state_;
    PrivateKey private_key_;

    std::unordered_map<td::int64, std::set<td::uint32>, td::Hash<td::int64>> seen_;
  };

  td::optional<td::int32> o_last_epoch_;
  std::map<td::int32, EpochEncryptor> encryptor_by_epoch_;
  td::VectorQueue<std::pair<td::Timestamp, td::int32>> epochs_to_forget_;

  void forget_old_epochs();
};

class CallVerification {
 public:
  static CallVerification create(PrivateKey private_key, const Blockchain &blockchain);
  void on_new_main_block(const Blockchain &blockhain);
  CallVerificationState get_verification_state() const;
  std::vector<std::string> pull_outbound_messages();
  CallVerificationWords get_verification_words() const;
  td::Status receive_inbound_message(td::Slice message);

  friend td::StringBuilder &operator<<(td::StringBuilder &sb, const CallVerification &verification);

 private:
  PrivateKey private_key_;
  CallVerificationChain chain_;
  std::vector<tde2e_api::Bytes> pending_outbound_messages_;
  bool sent_commit_{false};
  bool sent_reveal_{false};

  td::int32 height_{};
  td::UInt256 nonce_{};
};

struct Call {
  Call(PrivateKey pk, ClientBlockchain blockchain);
  static td::Result<std::string> create_zero_block(const PrivateKey &private_key, GroupStateRef group_state);
  static td::Result<std::string> create_self_add_block(const PrivateKey &private_key, td::Slice previous_block,
                                                       const GroupParticipant &self);

  static td::Result<Call> create(PrivateKey private_key, td::Slice last_block);
  td::Result<std::string> build_change_state(GroupStateRef new_group_state) const;
  static td::Result<std::vector<Change>> make_changes_for_new_state(GroupStateRef group_state);
  td::int32 get_height() const;
  td::Result<GroupStateRef> get_group_state() const;

  // TODO: add self user_id
  // TODO: verify that call contains us
  // changes CallVerificationState
  td::Status apply_block(td::Slice block);

  td::Slice shared_key() const {
    return group_shared_key_;
  }
  td::Result<std::string> decrypt(td::Slice encrypted_data) {
    return call_encryption_.decrypt(encrypted_data);
  }
  td::Result<std::string> encrypt(td::Slice decrypted_data) {
    return call_encryption_.encrypt(decrypted_data);
  }

  std::vector<std::string> pull_outbound_messages() {
    return call_verification_.pull_outbound_messages();
  }

  td::Result<CallVerificationState> get_verification_state() const {
    return call_verification_.get_verification_state();
  }
  td::Result<CallVerificationWords> get_verification_words() const {
    return call_verification_.get_verification_words();
  }
  td::Result<CallVerificationState> receive_inbound_message(td::Slice verification_message) {
    TRY_STATUS(call_verification_.receive_inbound_message(verification_message));
    return get_verification_state();
  }
  friend td::StringBuilder &operator<<(td::StringBuilder &builder, const Call &call);

 private:
  PrivateKey private_key_;
  ClientBlockchain blockchain_;
  td::SecureString group_shared_key_;
  CallVerification call_verification_;
  CallEncryption call_encryption_;

  td::Status update_group_shared_key();
  td::Status do_apply_block(td::Slice block);
};

}  // namespace tde2e_core
