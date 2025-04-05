//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/TestBlockchain.h"

#include "td/utils/algorithm.h"
#include "td/utils/base64.h"
#include "td/utils/crypto.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/overloaded.h"
#include "td/utils/simple_tests.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_parsers.h"

#include <cstdio>
#include <ctime>
#include <set>
#include <utility>

int VERBOSITY_NAME(blkch) = VERBOSITY_NAME(INFO);
namespace tde2e_api {
Result<SecureBytes> call_export_shared_key(CallId call_id);
}  // namespace tde2e_api
namespace tde2e_core {

// BlockchainLogger implementation
BlockchainLogger::BlockchainLogger(const std::string &log_file_path) : log_file_path_(log_file_path) {
  log_file_.open(log_file_path, std::ios::out | std::ios::trunc);  // Open in append mode
  LOG(ERROR) << "OPENING BLOCKCHAIN LOG FILE: " << log_file_path_;
  if (!log_file_.is_open()) {
    LOG(ERROR) << "Failed to open blockchain log file: " << log_file_path;
  } else {
    // Write a header to indicate a new test session
    log_file_ << "===== NEW TEST SESSION " << std::time(nullptr) << " =====\n";
    log_file_.flush();
  }
}

BlockchainLogger::~BlockchainLogger() {
  close();
}

void BlockchainLogger::close() {
  if (log_file_.is_open()) {
    log_file_.close();
    LOG(ERROR) << "CLOSE";
  }
}

void BlockchainLogger::write_separator() {
  log_file_ << "---\n";
  log_file_.flush();
}

std::string BlockchainLogger::base64_encode(td::Slice data) {
  return td::base64_encode(data);
}

void BlockchainLogger::log_try_apply_block(td::Slice block_slice, Height height, const td::Status &result) {
  if (!log_file_.is_open())
    return;

  log_file_ << "TRY_APPLY_BLOCK\n";
  log_file_ << base64_encode(block_slice) << "\n";
  log_file_ << base64_encode(Blockchain::from_local_to_server(block_slice.str()).move_as_ok()) << "\n";
  log_file_ << height.height << "\n";
  log_file_ << height.broadcast_height << "\n";
  if (result.is_ok()) {
    log_file_ << "OK\n";
  } else {
    log_file_ << "ERROR " << result.code() << " " << result.message().str() << "\n";
  }
  write_separator();
}

void BlockchainLogger::log_try_apply_broadcast_block(td::Slice block_slice, Height height, const td::Status &result) {
  if (!log_file_.is_open())
    return;

  log_file_ << "TRY_APPLY_BROADCAST_BLOCK\n";
  log_file_ << base64_encode(block_slice) << "\n";
  log_file_ << base64_encode(Blockchain::from_local_to_server(block_slice.str()).move_as_ok()) << "\n";
  log_file_ << height.height << "\n";
  log_file_ << height.broadcast_height << "\n";
  if (result.is_ok()) {
    log_file_ << "OK\n";
  } else {
    log_file_ << "ERROR " << result.code() << " " << result.message().str() << "\n";
  }
  write_separator();
}

void BlockchainLogger::log_reindex() {
  if (!log_file_.is_open())
    return;

  log_file_ << "REINDEX\n";
  write_separator();
}

void BlockchainLogger::log_reset() {
  if (!log_file_.is_open())
    return;

  log_file_ << "RESET\n";
  write_separator();
}

void BlockchainLogger::log_get_block(int subchain_id, size_t height, const td::Result<std::string> &result) {
  if (!log_file_.is_open())
    return;

  log_file_ << "GET_BLOCK\n";
  log_file_ << subchain_id << "\n";
  log_file_ << height << "\n";
  if (result.is_ok()) {
    log_file_ << "OK\n";
    log_file_ << base64_encode(result.ok()) << "\n";
  } else {
    log_file_ << "ERROR " << result.error().code() << " " << result.error().message().str() << "\n";
  }
  write_separator();
}

void BlockchainLogger::log_get_height(Height height) {
  if (!log_file_.is_open())
    return;

  log_file_ << "GET_HEIGHT\n";
  log_file_ << height.height << "\n";
  log_file_ << height.broadcast_height << "\n";
  write_separator();
}

void BlockchainLogger::log_get_proof(td::int64 height, const std::vector<std::string> &keys,
                                     const td::Result<std::string> &result) {
  if (!log_file_.is_open())
    return;

  log_file_ << "GET_PROOF\n";
  log_file_ << height << "\n";
  log_file_ << keys.size() << "\n";
  for (const auto &key : keys) {
    log_file_ << base64_encode(key) << "\n";
  }
  if (result.is_ok()) {
    log_file_ << "OK\n";
    log_file_ << base64_encode(result.ok()) << "\n";
  } else {
    log_file_ << "ERROR " << result.error().code() << " " << result.error().message().str() << "\n";
  }
  write_separator();
}

// ServerBlockchain implementation with logging
td::Status ServerBlockchain::try_apply_block(td::Slice block_slice) {
  TRY_RESULT(block, Block::from_tl_serialized(block_slice));
  ValidateOptions validate_options;
  validate_options.permissions = GroupParticipantFlags::AllPermissions;
  validate_options.validate_signature = true;
  validate_options.validate_state_hash = true;
  auto status = blockchain_.try_apply_block(block, validate_options);
  if (status.is_ok()) {
    blocks_.push_back(block);
    broadcast_chain_.on_new_main_block(blockchain_);
  }

  if (logger_) {
    logger_->log_try_apply_block(block_slice, get_height(), status);
  }

  return status;
}

td::Status ServerBlockchain::try_apply_broadcast(td::Slice broadcast_slice) {
  auto status = broadcast_chain_.try_apply_block(broadcast_slice);
  if (status.is_ok()) {
    broadcast_blocks_.push_back(broadcast_slice.str());
  }
  if (logger_) {
    logger_->log_try_apply_broadcast_block(broadcast_slice, get_height(), status);
  }
  return status;
}

void ServerBlockchain::reindex() {
  snapshot_ = blockchain_.state_.key_value_state_.build_snapshot().move_as_ok();
  auto last_block = blockchain_.last_block_;
  blockchain_ = Blockchain::create_from_block(last_block, snapshot_).move_as_ok();
}

td::Result<std::string> ServerBlockchain::get_block(size_t height, int sub_chain) const {
  td::Result<std::string> result;
  if (sub_chain == 0) {
    if (height >= blocks_.size()) {
      result = td::Status::Error(PSLICE() << "Invalid height " << height);
    } else {
      CHECK(blocks_[height].height_ == static_cast<td::int64>(height));
      result = Blockchain::from_local_to_server(blocks_[height].to_tl_serialized());
    }
  } else if (sub_chain == 1) {
    if (height >= broadcast_blocks_.size()) {
      result = td::Status::Error(PSLICE() << "Invalid height " << height);
    } else {
      result = Blockchain::from_local_to_server(broadcast_blocks_[height]);
    }
  }

  if (logger_) {
    logger_->log_get_block(sub_chain, height, result);
  }

  return result;
}

Height ServerBlockchain::get_height() const {
  auto height = blockchain_.get_height();
  auto broadcast_height = static_cast<td::int64>(broadcast_blocks_.size()) - 1;
  auto res = Height{height, broadcast_height};

  /*
  if (logger_) {
    logger_->log_get_height(res);
  }
  */

  return res;
}

td::Result<std::string> ServerBlockchain::get_proof(td::int64 height, const std::vector<std::string> &keys) const {
  td::Result<std::string> result = [&]() -> td::Result<std::string> {
    if (height != blockchain_.get_height()) {
      return td::Status::Error("Invalid height");
    }
    auto keys_slices = td::transform(keys, [](auto &x) { return td::Slice(x); });
    return blockchain_.state_.key_value_state_.gen_proof(keys_slices);
  }();

  if (logger_) {
    logger_->log_get_proof(height, keys, result);
  }

  return result;
}

const Blockchain &ServerBlockchain::get_blockchain() const {
  return blockchain_;
}

std::string BaselineBlockchainState::get_value(const std::string &key) const {
  auto it = key_value_state.find(key);
  if (it == key_value_state.end()) {
    return "";
  }
  return it->second;
}

void BaselineBlockchainState::apply_changes(const std::vector<Change> &changes) {
  for (const auto &change_v : changes) {
    std::visit(td::overloaded([](const ChangeNoop &) {},
                              [&](const ChangeSetValue &change) { key_value_state[change.key] = change.value; },
                              [&](const ChangeSetGroupState &change) { group_state = change.group_state; },
                              [&](const ChangeSetSharedKey &change) { shared_key = change.shared_key; }),
               change_v.value);
  }
  height++;
}

td::Status expect_error(tde2e_core::E expected_code, td::Result<ApplyResult> r_received) {
  TRY_RESULT(received_result, std::move(r_received));
  const auto &received = received_result.status;
  auto expected_sw = tde2e_api::error_string(expected_code);
  auto expected = td::Slice(expected_sw.data(), expected_sw.size());
  if (received.is_ok()) {
    return td::Status::Error(PSLICE() << "Unexpected OK, expected " << expected);
  }
  if (!td::begins_with(received.message(), expected)) {
    return td::Status::Error(PSLICE() << "Unexpected " << received << ", expected " << expected);
  }
  return td::Status::OK();
}

Change BlockBuilder::make_group_change(const std::vector<GroupParticipant> &participants) {
  return Change{ChangeSetGroupState{BlockBuilder::make_group_state(participants)}};
}

Change BlockBuilder::make_set_value(std::string key, std::string value) {
  return Change{ChangeSetValue{std::move(key), std::move(value)}};
}

GroupSharedKeyRef BlockBuilder::make_shared_key(const std::vector<td::int64> &user_ids) {
  auto n = user_ids.size();
  auto res = std::make_shared<const GroupSharedKey>(
      GroupSharedKey{PublicKey::from_u256({}), "dummy", user_ids, std::vector<std::string>(n, "??")});
  if (user_ids.empty()) {
    res = GroupSharedKey::empty_shared_key();
  }
  return res;
}

GroupStateRef BlockBuilder::make_group_state(std::vector<GroupParticipant> users, td::int32 external_permissions) {
  return std::make_shared<GroupState>(GroupState{std::move(users), external_permissions});
}

Block BlockBuilder::finish() {
  CHECK(has_height);
  CHECK(has_signature);
  CHECK(has_block_hash);
  CHECK(has_hash_proof);
  CHECK(has_shared_key_proof);
  CHECK(has_group_state_proof);
  CHECK(has_signature_public_key);
  return block;
}

Block BlockBuilder::build(const PrivateKey &private_key) {
  with_public_key(private_key.to_public_key());
  sign(private_key);
  return finish();
}

Block BlockBuilder::build_no_public_key(const PrivateKey &private_key) {
  skip_public_key();
  sign(private_key);
  return finish();
}

Block BlockBuilder::build_zero_sign() {
  zero_sign();
  return finish();
}

BlockBuilder &BlockBuilder::with_height(td::int32 height) {
  CHECK(!has_height);
  has_height = true;
  block.height_ = height;
  return *this;
}

BlockBuilder &BlockBuilder::with_block_hash(td::UInt256 hash) {
  CHECK(!has_block_hash);
  has_block_hash = true;
  block.prev_block_hash_ = hash;
  return *this;
}

BlockBuilder &BlockBuilder::with_previous_block(Block &previous_block) {
  return with_height(previous_block.height_ + 1).with_block_hash(previous_block.calc_hash());
}

BlockBuilder &BlockBuilder::with_public_key(const PrivateKey &private_key) {
  return with_public_key(private_key.to_public_key());
}

BlockBuilder &BlockBuilder::with_public_key(const PublicKey &public_key) {
  CHECK(!has_signature_public_key);
  has_signature_public_key = true;
  block.o_signature_public_key_ = public_key;
  return *this;
}

BlockBuilder &BlockBuilder::skip_public_key() {
  CHECK(!has_signature_public_key);
  has_signature_public_key = true;
  return *this;
}

BlockBuilder &BlockBuilder::set_value_raw(td::Slice key, td::Slice value) {
  kv_state_.set_value(key, value).ensure();
  block.state_proof_.kv_hash = KeyValueHash{kv_state_.get_hash()};
  block.changes_.push_back(Change{ChangeSetValue{key.str(), value.str()}});
  has_hash_proof = true;
  return *this;
}

BlockBuilder &BlockBuilder::set_value(td::Slice key, td::Slice value) {
  return set_value_raw(hash_key(key), std::move(value));
}

BlockBuilder &BlockBuilder::with_group_state(const std::vector<GroupParticipant> &users, bool in_changes, bool in_proof,
                                             td::int32 external_permissions) {
  auto state = make_group_state(users, external_permissions);
  if (in_changes) {
    block.changes_.push_back(Change{ChangeSetGroupState{state}});
  }
  if (in_proof) {
    CHECK(!has_group_state_proof);
    has_group_state_proof = true;
    block.state_proof_.o_group_state = state;
  }
  return *this;
}

BlockBuilder &BlockBuilder::skip_group_state_proof() {
  CHECK(!has_group_state_proof);
  has_group_state_proof = true;
  return *this;
}

BlockBuilder &BlockBuilder::with_shared_key(const std::vector<td::int64> &user_ids, bool in_changes, bool in_proof) {
  auto shared_key = make_shared_key(user_ids);
  if (in_changes) {
    block.changes_.push_back(Change{ChangeSetSharedKey{shared_key}});
  }
  if (in_proof) {
    CHECK(!has_shared_key_proof);
    has_shared_key_proof = true;
    block.state_proof_.o_shared_key = shared_key;
  }
  return *this;
}

BlockBuilder &BlockBuilder::skip_shared_key_proof() {
  CHECK(!has_shared_key_proof);
  has_shared_key_proof = true;
  return *this;
}

void BlockBuilder::sign(const PrivateKey &private_key) {
  if (!has_hash_proof) {
    has_hash_proof = true;
    block.state_proof_.kv_hash.hash = TrieNode::empty_node()->hash;
  }

  CHECK(!has_signature);
  block.sign_inplace(private_key).ensure();
  has_signature = true;
}

void BlockBuilder::zero_sign() {
  if (!has_hash_proof) {
    has_hash_proof = true;
    block.state_proof_.kv_hash.hash = TrieNode::empty_node()->hash;
  }

  CHECK(!has_signature);
  block.signature_ = {};
  has_signature = true;
}

std::string BlockBuilder::hash_key(td::Slice key) const {
  std::string hashed_key(32, 0);
  td::sha256(key, hashed_key);
  return hashed_key;
}

BlockchainTester::BlockchainTester() {
  // Automatically set up logging
  server_.set_logger(BlockchainLogger::get_instance());
  BlockchainLogger::get_instance()->log_reset();
}

td::Result<ApplyResult> BlockchainTester::apply(const Block &block) {
  return apply(block, block.to_tl_serialized());
}

td::Result<ApplyResult> BlockchainTester::apply(td::Slice block_str) {
  TRY_RESULT(block, Block::from_tl_serialized(block_str));
  return apply(block, block_str);
}

td::Result<ApplyResult> BlockchainTester::apply(const std::vector<Change> &changes, const PrivateKey &private_key) {
  add_proof(changes);
  auto r_block = client_.build_block(changes, private_key);
  if (r_block.is_error()) {
    return ApplyResult{r_block.move_as_error()};
  }
  return apply(r_block.move_as_ok());
}

td::Status BlockchainTester::expect_error(E expected, const Block &block) {
  return ::tde2e_core::expect_error(expected, apply(block));
}

td::Status BlockchainTester::expect_error(E expected, td::Slice block) {
  return ::tde2e_core::expect_error(expected, apply(block));
}

td::Status BlockchainTester::expect_ok(td::Slice block) {
  TRY_RESULT(answer, apply(block));
  return std::move(answer.status);
}

td::Status BlockchainTester::expect_ok_broadcast(td::Slice block) {
  return server_.try_apply_broadcast(block);
}

td::Status BlockchainTester::expect_ok(const Block &block) {
  TRY_RESULT(answer, apply(block));
  return std::move(answer.status);
}

td::Status BlockchainTester::expect_ok(const std::vector<Change> &changes, const PrivateKey &private_key) {
  TRY_RESULT(answer, apply(changes, private_key));
  return std::move(answer.status);
}

td::Status BlockchainTester::expect_error(E expected, const std::vector<Change> &changes,
                                          const PrivateKey &private_key) {
  return ::tde2e_core::expect_error(expected, apply(changes, private_key));
}

void BlockchainTester::reindex() {
  server_.reindex();
}

td::Result<std::vector<std::string>> BlockchainTester::get_values(const std::vector<std::string> &keys) {
  add_proof(keys);
  std::vector<std::string> values;
  for (const auto &key : keys) {
    auto client_value = client_.get_value(key).move_as_ok();
    auto baseline_value = baseline_state_.get_value(key);
    TEST_ASSERT_EQ(baseline_value, client_value, "baseline and client differs");
    values.push_back(client_value);
  }
  return values;
}

td::Result<std::string> BlockchainTester::get_block_from_server(td::int64 height, int sub_chain) {
  return server_.get_block(static_cast<std::size_t>(height), sub_chain);
}

td::Result<std::string> BlockchainTester::get_value(td::Slice key) {
  TRY_RESULT(values, get_values({key.str()}));
  return values.at(0);
}

td::Status BlockchainTester::expect_key_value(td::Slice key, td::Slice value) {
  TEST_ASSERT_EQ(value, get_value(key), "");
  return td::Status::OK();
}

void BlockchainTester::enable_logging(const std::string &log_file_path) {
  //BlockchainLogger::set_log_file_path(log_file_path);
  server_.set_logger(BlockchainLogger::get_instance());
}

td::Result<Height> BlockchainTester::get_height() {
  return server_.get_height();
}

void BlockchainTester::add_proof(const std::vector<Change> &changes) {
  std::vector<std::string> keys;
  for (auto &change_v : changes) {
    std::visit(
        td::overloaded([](const ChangeNoop &) {}, [&keys](const ChangeSetValue &change) { keys.push_back(change.key); },
                       [](const ChangeSetGroupState &change) {}, [](const ChangeSetSharedKey &change) {}),
        change_v.value);
  }
  add_proof(keys);
}

td::Result<ApplyResult> BlockchainTester::apply(const Block &block, td::Slice block_str) {
  add_proof(block.changes_);
  auto server_status = server_.try_apply_block(block_str);
  auto client_status = client_.try_apply_block(block_str);
  if (server_status.is_error() != client_status.is_error()) {
    return td::Status::Error(PSLICE() << "Server and client return different answers:\n\tserver:" << server_status
                                      << "\n\tclient:" << client_status);
  }
  if (server_status.is_error()) {
    return ApplyResult{std::move(server_status)};
  }
  baseline_state_.apply_changes(block.changes_);
  return ApplyResult{td::Status::OK()};
}

void BlockchainTester::add_proof(const std::vector<std::string> &keys) {
  if (baseline_state_.height != -1) {
    auto proof = server_.get_proof(baseline_state_.height, keys).move_as_ok();
    client_.add_proof(proof).ensure();
  }
}

CallTester::CallTester(int N) {
  for (int i = 0; i < N; i++) {
    auto key = tde2e_api::key_generate_temporary_private_key().value();
    auto public_key = tde2e_api::key_from_public_key(tde2e_api::key_to_public_key(key).value()).value();
    users.push_back(User{i + 1, key, public_key});
  }
}

td::Status CallTester::start_call(const std::vector<int> &ids) {
  auto call_state = make_state(ids);
  TEST_TRY_RESULT(zero_block, to_td(tde2e_api::call_create_zero_block(users[ids[0]].private_key_id, call_state)));
  for (auto id : ids) {
    start_call(users[id]);
  }
  TEST_TRY_STATUS(bt.expect_ok(zero_block));
  return td::Status::OK();
}

td::Status CallTester::update_call(int admin, const std::vector<int> &ids) {
  auto call_state = make_state(ids);
  CHECK(users[admin].call_id);
  TEST_TRY_RESULT(block, to_td(tde2e_api::call_create_change_state_block(users[admin].call_id, call_state)));

  std::set<int> s(ids.begin(), ids.end());
  for (int i = 0; i < static_cast<int>(users.size()); i++) {
    if (s.count(i) > 0) {
      if (!users[i].call_id) {
        start_call(users[i]);
      }
    } else if (users[i].call_id) {
      stop_call(users[i]);
    }
  }
  TEST_TRY_STATUS(bt.expect_ok(block));
  return td::Status::OK();
}

td::Status CallTester::full_sync() {
  for (auto &user : users) {
    TEST_TRY_STATUS(user_full_sync(user));
  }
  return td::Status::OK();
}

td::Status CallTester::check_shared_key() {
  TEST_TRY_STATUS(full_sync());
  td::optional<std::string> o_key;
  for (auto &user : users) {
    if (!user.in_call) {
      continue;
    }
    TRY_RESULT(key, to_td(tde2e_api::call_export_shared_key(user.call_id)));
    if (!o_key) {
      o_key = key;
    }
    TEST_ASSERT(!key.empty(), "key is empty");
    TEST_ASSERT_EQ(o_key, key, "key differs");
  }
  return td::Status::OK();
}

td::Status CallTester::check_emoji_hash() {
  TEST_TRY_STATUS(run_emoji_proto());  // ensure that proto is finished
  td::optional<std::string> o_key;
  for (auto &user : users) {
    if (!user.in_call) {
      continue;
    }
    TRY_RESULT(state, to_td(tde2e_api::call_get_verification_state(user.call_id)));
    TEST_ASSERT(state.emoji_hash, "emoji hash is missing");
    TEST_ASSERT(!state.emoji_hash->empty(), "emoji hash is empty");
    if (!o_key) {
      o_key = state.emoji_hash.value();
    }
    TEST_ASSERT_EQ(o_key, state.emoji_hash.value(), "key differs");
  }
  return td::Status::OK();
}

td::Status CallTester::run_emoji_proto() {
  TEST_TRY_STATUS(full_send());
  TEST_TRY_STATUS(full_sync());
  TEST_TRY_STATUS(full_send());
  TEST_TRY_STATUS(full_sync());
  return td::Status::OK();
}

tde2e_api::CallParticipant CallTester::User::to_participant(int permissions) const {
  return tde2e_api::CallParticipant{user_id, public_key_id, permissions};
}

void CallTester::start_call(User &user) {
  CHECK(user.call_id == 0);
  CHECK(!user.in_call);
  user.in_call = true;
  user.height = bt.get_height().move_as_ok();
}

void CallTester::stop_call(User &user) {
  CHECK(user.call_id != 0);
  CHECK(user.in_call);
  user.in_call = false;
  tde2e_api::call_destroy(user.call_id).value();
  user.call_id = 0;
}

tde2e_api::CallState CallTester::make_state(const std::vector<int> &ids) {
  tde2e_api::CallState state;
  state.participants = td::transform(ids, [&](int uid) { return users[uid].to_participant(); });
  return state;
}

td::Status CallTester::full_send() {
  for (auto &user : users) {
    TEST_TRY_STATUS(user_full_send(user));
  }
  return td::Status::OK();
}

td::Result<bool> CallTester::user_full_send(User &user) {
  if (!user.call_id) {
    return false;
  }
  TEST_TRY_RESULT(msgs, to_td(tde2e_api::call_pull_outbound_messages(user.call_id)));
  if (msgs.empty()) {
    return false;
  }
  TEST_ASSERT(msgs.size() == 1, "Wrong number of messages");
  TEST_TRY_STATUS(bt.expect_ok_broadcast(msgs[0]));
  return true;
}

td::Result<bool> CallTester::user_full_sync(User &user) {
  if (!user.in_call) {
    return false;
  }
  bool res = false;
  if (!user.call_id) {
    TEST_TRY_STATUS(user_init_call(user));
    res = true;
  }
  while (true) {
    TEST_TRY_RESULT(changed, user_sync_step(user));
    if (!changed) {
      return res;
    }
    res = true;
  }
}

td::Status CallTester::user_init_call(User &user) {
  CHECK(user.call_id == 0);
  CHECK(user.in_call);
  TEST_TRY_RESULT(block, bt.get_block_from_server(++user.height.height));
  TRY_RESULT(call_id, to_td(tde2e_api::call_create(user.user_id, user.private_key_id, block)));
  user.call_id = call_id;
  return td::Status::OK();
}

td::Result<bool> CallTester::user_sync_step(User &user) {
  TRY_RESULT(changed, user_sync_chain_step(user));
  if (changed) {
    return changed;
  }
  return user_sync_broadcast_step(user);
}

td::Result<bool> CallTester::user_sync_chain_step(User &user) {
  auto height = bt.get_height().move_as_ok();
  if (user.height.height == height.height) {
    return false;
  }
  TEST_TRY_RESULT(block, bt.get_block_from_server(++user.height.height));
  TEST_TRY_STATUS(to_td(tde2e_api::call_apply_block(user.call_id, block)));
  return true;
}

td::Result<bool> CallTester::user_sync_broadcast_step(User &user) {
  auto height = bt.get_height().move_as_ok();
  CHECK(user.height.broadcast_height <= height.broadcast_height);
  if (user.height.broadcast_height == height.broadcast_height) {
    return false;
  }
  TEST_TRY_RESULT(block, bt.get_block_from_server(++user.height.broadcast_height, 1));
  auto r = tde2e_api::call_receive_inbound_message(user.call_id, block);
  if (!r.is_ok()) {
    return td::Status::Error(PSLICE() << "Failed to call apply broadcast: " << r.error().message);
  }
  return true;
}

}  // namespace tde2e_core
