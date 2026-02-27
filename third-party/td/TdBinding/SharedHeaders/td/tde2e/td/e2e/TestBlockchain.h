//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/Blockchain.h"
#include "td/e2e/Call.h"
#include "td/e2e/utils.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

#include <fstream>
#include <map>
#include <memory>
#include <string>
#include <vector>

// Define a custom verbosity name for blockchain-specific logging
extern int VERBOSITY_NAME(blkch);

namespace tde2e_core {

struct Height {
  td::int64 height;
  td::int64 broadcast_height;
};

// Simple blockchain operation logger that writes to a file
class BlockchainLogger {
 public:
  static std::shared_ptr<BlockchainLogger> &get_instance() {
    static std::shared_ptr<BlockchainLogger> instance = std::make_shared<BlockchainLogger>("blockchain_test.log");
    return instance;
  }

  explicit BlockchainLogger(const std::string &log_file_path);
  ~BlockchainLogger();

  void log_try_apply_block(td::Slice block_slice, Height height, const td::Status &result);
  void log_try_apply_broadcast_block(td::Slice block_slice, Height height, const td::Status &result);
  void log_reindex();
  void log_reset();
  void log_get_block(int subchain_id, size_t height, const td::Result<std::string> &result);
  void log_get_height(Height height);
  void log_get_proof(td::int64 height, const std::vector<std::string> &keys, const td::Result<std::string> &result);
  void close();

 private:
  std::ofstream log_file_;
  std::string log_file_path_;

  void write_separator();
  std::string base64_encode(td::Slice data);
};

class ServerBlockchain {
 public:
  ServerBlockchain() = default;
  explicit ServerBlockchain(std::shared_ptr<BlockchainLogger> logger) : logger_(std::move(logger)) {
  }

  td::Status try_apply_block(td::Slice block_slice);
  td::Status try_apply_broadcast(td::Slice broadcast_slice);
  void reindex();
  td::Result<std::string> get_block(size_t height, int sub_chain = 0) const;
  Height get_height() const;
  td::Result<std::string> get_proof(td::int64 height, const std::vector<std::string> &keys) const;
  const Blockchain &get_blockchain() const;

  void set_logger(std::shared_ptr<BlockchainLogger> logger) {
    logger_ = std::move(logger);
  }

 private:
  Blockchain blockchain_{Blockchain::create_empty()};
  CallVerificationChain broadcast_chain_{};
  std::vector<Block> blocks_;
  std::vector<std::string> broadcast_blocks_;
  std::string snapshot_;
  std::shared_ptr<BlockchainLogger> logger_;
};

struct BaselineBlockchainState {
  std::map<std::string, std::string> key_value_state;
  GroupStateRef group_state;
  GroupSharedKeyRef shared_key;
  td::int32 height{-1};

  std::string get_value(const std::string &key) const;
  void apply_changes(const std::vector<Change> &changes);
};

struct ApplyResult {
  td::Status status;
};
inline td::Status expect_error(tde2e_core::E expected_code, td::Result<ApplyResult> r_received);

struct BlockBuilder {
  static Change make_group_change(const std::vector<GroupParticipant> &participants);
  static Change make_set_value(std::string key, std::string value);

  static GroupSharedKeyRef make_shared_key(const std::vector<td::int64> &user_ids);
  static GroupStateRef make_group_state(std::vector<GroupParticipant> users, td::int32 extrernal_permissions = 0);

  Block finish();
  Block build(const PrivateKey &private_key);
  Block build_no_public_key(const PrivateKey &private_key);
  Block build_zero_sign();

  BlockBuilder &with_height(td::int32 height);
  BlockBuilder &with_block_hash(td::UInt256 hash);
  BlockBuilder &with_previous_block(Block &previous_block);

  BlockBuilder &with_public_key(const PrivateKey &private_key);
  BlockBuilder &with_public_key(const PublicKey &public_key);
  BlockBuilder &skip_public_key();
  BlockBuilder &set_value_raw(td::Slice key, td::Slice value);

  //!!! we should check it fails with invalid key length!!!
  BlockBuilder &set_value(td::Slice key, td::Slice value);
  BlockBuilder &with_group_state(const std::vector<GroupParticipant> &users, bool in_changes = true,
                                 bool in_proof = true, td::int32 external_permissions = 0);
  BlockBuilder &skip_group_state_proof();
  BlockBuilder &with_shared_key(const std::vector<td::int64> &user_ids, bool in_changes = true, bool in_proof = true);
  BlockBuilder &with_shared_key(GroupSharedKeyRef shared_key, bool in_changes, bool in_proof);
  BlockBuilder &skip_shared_key_proof();

 private:
  bool has_height{false};
  bool has_block_hash{false};
  bool has_hash_proof{false};
  bool has_shared_key_proof{false};
  bool has_group_state_proof{false};
  bool has_signature_public_key{false};
  bool has_signature{false};
  tde2e_core::Block block;

  KeyValueState kv_state_;

  void sign(const PrivateKey &private_key);
  void zero_sign();
  std::string hash_key(td::Slice key) const;
};

struct BlockchainTester {
  // Default constructor with automatic logging
  BlockchainTester();

  td::Result<ApplyResult> apply(const Block &block);
  td::Result<ApplyResult> apply(td::Slice block_str);
  td::Result<ApplyResult> apply(const std::vector<Change> &changes, const PrivateKey &private_key);
  td::Status expect_error(E expected, const Block &block);
  td::Status expect_error(E expected, td::Slice block);
  td::Status expect_ok(td::Slice block);
  td::Status expect_ok_broadcast(td::Slice block);
  td::Status expect_ok(const Block &block);
  td::Status expect_ok(const std::vector<Change> &changes, const PrivateKey &private_key);
  td::Status expect_error(E expected, const std::vector<Change> &changes, const PrivateKey &private_key);
  void reindex();
  td::Result<std::vector<std::string>> get_values(const std::vector<std::string> &keys);

  td::Result<std::string> get_block_from_server(td::int64 height, int sub_chain = 0);

  td::Result<std::string> get_value(td::Slice key);

  td::Status expect_key_value(td::Slice key, td::Slice value);

  // For backwards compatibility
  void enable_logging(const std::string &log_file_path);
  td::Result<Height> get_height();

 private:
  BaselineBlockchainState baseline_state_;
  ServerBlockchain server_;
  ClientBlockchain client_;

  void add_proof(const std::vector<Change> &changes);

  td::Result<ApplyResult> apply(const Block &block, td::Slice block_str);

  void add_proof(const std::vector<std::string> &keys);
};

struct CallTester {
  explicit CallTester(int N = 10);

  td::Status start_call(const std::vector<int> &ids);
  td::Status update_call(int admin, const std::vector<int> &ids);
  td::Status full_sync();
  td::Status check_shared_key();
  td::Status check_emoji_hash();

  td::Status run_emoji_proto();

 private:
  struct User {
    tde2e_api::UserId user_id;
    tde2e_api::PrivateKeyId private_key_id;
    tde2e_api::PublicKeyId public_key_id;
    tde2e_api::CallId call_id{};

    bool in_call{false};
    Height height{};

    tde2e_api::CallParticipant to_participant(int permissions = 3) const;
  };

  std::vector<User> users;
  BlockchainTester bt;

  void start_call(User &user);
  void stop_call(User &user);
  tde2e_api::CallState make_state(const std::vector<int> &ids);

  td::Status full_send();

  td::Result<bool> user_full_send(User &user);

  td::Result<bool> user_full_sync(User &user);
  td::Status user_init_call(User &user);

  td::Result<bool> user_sync_step(User &user);
  td::Result<bool> user_sync_chain_step(User &user);
  td::Result<bool> user_sync_broadcast_step(User &user);
};

}  // namespace tde2e_core
