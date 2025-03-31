//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/AuthData.h"

#include "td/utils/logging.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"

#include <algorithm>

namespace td {
namespace mtproto {

Status check_message_id_duplicates(MessageId *saved_message_ids, size_t max_size, size_t &end_pos,
                                   MessageId message_id) {
  // In addition, the identifiers (msg_id) of the last N messages received from the other side must be stored, and if
  // a message comes in with msg_id lower than all or equal to any of the stored values, that message is to be
  // ignored. Otherwise, the new message msg_id is added to the set, and, if the number of stored msg_id values is
  // greater than N, the oldest (i.e. the lowest) is forgotten.
  if (end_pos == 2 * max_size) {
    std::copy_n(&saved_message_ids[max_size], max_size, &saved_message_ids[0]);
    end_pos = max_size;
  }
  if (end_pos == 0 || message_id > saved_message_ids[end_pos - 1]) {
    // fast path
    saved_message_ids[end_pos++] = message_id;
    return Status::OK();
  }
  if (end_pos >= max_size && message_id < saved_message_ids[0]) {
    return Status::Error(
        2, PSLICE() << "Ignore very old " << message_id << " older than the oldest known " << saved_message_ids[0]);
  }
  auto it = std::lower_bound(&saved_message_ids[0], &saved_message_ids[end_pos], message_id);
  if (*it == message_id) {
    return Status::Error(1, PSLICE() << "Ignore already processed " << message_id);
  }
  std::copy_backward(it, &saved_message_ids[end_pos], &saved_message_ids[end_pos + 1]);
  *it = message_id;
  ++end_pos;
  return Status::OK();
}

AuthData::AuthData() {
  server_salt_.salt = Random::secure_int64();
  server_salt_.valid_since = -1e10;
  server_salt_.valid_until = -1e10;
}

bool AuthData::is_ready(double now) {
  if (!has_main_auth_key()) {
    LOG(INFO) << "Need main auth key";
    return false;
  }
  if (use_pfs() && !has_tmp_auth_key(now)) {
    LOG(INFO) << "Need tmp auth key";
    return false;
  }
  if (!has_salt(now)) {
    LOG(INFO) << "Need salt";
    return false;
  }
  return true;
}

bool AuthData::update_server_time_difference(double diff) {
  if (!server_time_difference_was_updated_) {
    LOG(DEBUG) << "Set server time difference: " << server_time_difference_ << " -> " << diff;
    server_time_difference_was_updated_ = true;
    server_time_difference_ = diff;
  } else if (server_time_difference_ + 1e-4 < diff) {
    LOG(DEBUG) << "Update server time difference: " << server_time_difference_ << " -> " << diff;
    server_time_difference_ = diff;
  } else {
    return false;
  }
  LOG(DEBUG) << "New server time: " << get_server_time(Time::now_cached());
  return true;
}

void AuthData::reset_server_time_difference(double diff) {
  LOG(DEBUG) << "Reset server time difference: " << server_time_difference_ << " -> " << diff;
  server_time_difference_was_updated_ = false;
  server_time_difference_ = diff;
}

void AuthData::set_future_salts(const std::vector<ServerSalt> &salts, double now) {
  if (salts.empty()) {
    return;
  }
  future_salts_ = salts;
  std::sort(future_salts_.begin(), future_salts_.end(),
            [](const ServerSalt &a, const ServerSalt &b) { return a.valid_since > b.valid_since; });
  update_salt(now);
}

std::vector<ServerSalt> AuthData::get_future_salts() const {
  auto res = future_salts_;
  res.push_back(server_salt_);
  return res;
}

MessageId AuthData::next_message_id(double now) {
  double server_time = get_server_time(now);
  auto t = static_cast<uint64>(server_time * (static_cast<uint64>(1) << 32));

  // randomize lower bits for clocks with low precision
  // TODO(perf) do not do this for systems with good precision?..
  auto rx = Random::secure_int32();
  auto to_xor = rx & ((1 << 22) - 1);

  t ^= to_xor;
  auto result = MessageId(t & static_cast<uint64>(-4));
  if (last_message_id_ >= result) {
    auto to_mul = ((rx >> 22) & 1023) + 1;
    result = MessageId(last_message_id_.get() + 8 * to_mul);
  }
  LOG(DEBUG) << "Create identifier for " << result << " at " << now;
  last_message_id_ = result;
  return result;
}

bool AuthData::is_valid_outbound_msg_id(MessageId message_id, double now) const {
  double server_time = get_server_time(now);
  auto id_time = static_cast<double>(message_id.get()) / static_cast<double>(static_cast<uint64>(1) << 32);
  return server_time - 150 < id_time && id_time < server_time + 30;
}

bool AuthData::is_valid_inbound_msg_id(MessageId message_id, double now) const {
  double server_time = get_server_time(now);
  auto id_time = static_cast<double>(message_id.get()) / static_cast<double>(static_cast<uint64>(1) << 32);
  return server_time - 300 < id_time && id_time < server_time + 30;
}

Status AuthData::check_packet(uint64 session_id, MessageId message_id, double now, bool &time_difference_was_updated) {
  // Client is to check that the session_id field in the decrypted message indeed equals to that of an active session
  // created by the client.
  if (get_session_id() != session_id) {
    return Status::Error(PSLICE() << "Receive packet from different session " << session_id << " in session "
                                  << get_session_id());
  }

  // Client must check that msg_id has even parity for messages from client to server, and odd parity for messages
  // from server to client.
  if ((message_id.get() & 1) == 0) {
    return Status::Error(PSLICE() << "Receive invalid " << message_id);
  }

  TRY_STATUS(duplicate_checker_.check(message_id));

  LOG(DEBUG) << "Receive packet in " << message_id << " from session " << session_id << " at " << now;
  time_difference_was_updated = update_server_time_difference(static_cast<uint32>(message_id.get() >> 32) - now);

  // In addition, msg_id values that belong over 30 seconds in the future or over 300 seconds in the past are to be
  // ignored (recall that msg_id approximately equals unixtime * 2^32). This is especially important for the server.
  // The client would also find this useful (to protect from a replay attack), but only if it is certain of its time
  // (for example, if its time has been synchronized with that of the server).
  if (server_time_difference_was_updated_ && !is_valid_inbound_msg_id(message_id, now)) {
    return Status::Error(PSLICE() << "Ignore too old or too new " << message_id);
  }

  return Status::OK();
}

void AuthData::update_salt(double now) {
  double server_time = get_server_time(now);
  while (!future_salts_.empty() && (future_salts_.back().valid_since < server_time)) {
    server_salt_ = future_salts_.back();
    future_salts_.pop_back();
  }
}

}  // namespace mtproto
}  // namespace td
