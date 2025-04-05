//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/AuthKey.h"
#include "td/mtproto/MessageId.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <array>

namespace td {
namespace mtproto {

struct ServerSalt {
  int64 salt;
  double valid_since;
  double valid_until;
};

template <class StorerT>
void store(const ServerSalt &salt, StorerT &storer) {
  storer.template store_binary<int64>(salt.salt);
  storer.template store_binary<double>(salt.valid_since);
  storer.template store_binary<double>(salt.valid_until);
}

template <class ParserT>
void parse(ServerSalt &salt, ParserT &parser) {
  salt.salt = parser.fetch_long();
  salt.valid_since = parser.fetch_double();
  salt.valid_until = parser.fetch_double();
}

Status check_message_id_duplicates(MessageId *saved_message_ids, size_t max_size, size_t &end_pos,
                                   MessageId message_id);

template <size_t max_size>
class MessageIdDuplicateChecker {
 public:
  Status check(MessageId message_id) {
    return check_message_id_duplicates(&saved_message_ids_[0], max_size, end_pos_, message_id);
  }

 private:
  std::array<MessageId, 2 * max_size> saved_message_ids_;
  size_t end_pos_ = 0;
};

class AuthData {
 public:
  AuthData();
  AuthData(const AuthData &) = default;
  AuthData &operator=(const AuthData &) = delete;
  AuthData(AuthData &&) = delete;
  AuthData &operator=(AuthData &&) = delete;
  ~AuthData() = default;

  bool is_ready(double now);

  void set_main_auth_key(AuthKey auth_key) {
    main_auth_key_ = std::move(auth_key);
  }
  void break_main_auth_key() {
    main_auth_key_.break_key();
  }
  const AuthKey &get_main_auth_key() const {
    // CHECK(has_main_auth_key());
    return main_auth_key_;
  }
  bool has_main_auth_key() const {
    return !main_auth_key_.empty();
  }
  bool need_main_auth_key() const {
    return !has_main_auth_key();
  }

  void set_tmp_auth_key(AuthKey auth_key) {
    CHECK(!auth_key.empty());
    tmp_auth_key_ = std::move(auth_key);
  }
  const AuthKey &get_tmp_auth_key() const {
    return tmp_auth_key_;
  }
  bool was_tmp_auth_key() const {
    return use_pfs() && !tmp_auth_key_.empty();
  }
  bool need_tmp_auth_key(double now, double refresh_margin) const {
    if (!use_pfs()) {
      return false;
    }
    if (tmp_auth_key_.empty()) {
      return true;
    }
    if (now > tmp_auth_key_.expires_at() - refresh_margin) {
      return true;
    }
    return false;
  }
  void drop_main_auth_key() {
    main_auth_key_ = AuthKey();
  }
  void drop_tmp_auth_key() {
    tmp_auth_key_ = AuthKey();
  }
  bool has_tmp_auth_key(double now) const {
    if (!use_pfs()) {
      return false;
    }
    if (tmp_auth_key_.empty()) {
      return false;
    }
    if (now > tmp_auth_key_.expires_at()) {
      return false;
    }
    return true;
  }

  const AuthKey &get_auth_key() const {
    if (use_pfs()) {
      return get_tmp_auth_key();
    }
    return get_main_auth_key();
  }
  bool has_auth_key(double now) const {
    if (use_pfs()) {
      return has_tmp_auth_key(now);
    }
    return has_main_auth_key();
  }

  bool get_auth_flag() const {
    return main_auth_key_.auth_flag();
  }
  void set_auth_flag(bool auth_flag) {
    main_auth_key_.set_auth_flag(auth_flag);
    if (!auth_flag) {
      drop_tmp_auth_key();
    }
  }

  bool get_bind_flag() const {
    return !use_pfs() || tmp_auth_key_.auth_flag();
  }
  void on_bind() {
    CHECK(use_pfs());
    tmp_auth_key_.set_auth_flag(true);
  }

  Slice get_header() const {
    if (use_pfs()) {
      return tmp_auth_key_.need_header() ? Slice(header_) : Slice();
    } else {
      return main_auth_key_.need_header() ? Slice(header_) : Slice();
    }
  }

  void set_header(std::string header) {
    header_ = std::move(header);
  }

  void on_api_response() {
    if (use_pfs()) {
      tmp_auth_key_.remove_header();
    } else {
      main_auth_key_.remove_header();
    }
  }

  void on_connection_not_inited() {
    if (use_pfs()) {
      tmp_auth_key_.restore_header();
    } else {
      main_auth_key_.restore_header();
    }
  }

  void set_session_id(uint64 session_id) {
    session_id_ = session_id;
  }
  uint64 get_session_id() const {
    CHECK(session_id_ != 0);
    return session_id_;
  }

  double get_server_time(double now) const {
    return server_time_difference_ + now;
  }

  double get_server_time_difference() const {
    return server_time_difference_;
  }

  // diff == msg_id / 2^32 - now == old_server_now - now <= server_now - now
  // server_time_difference >= max{diff}
  bool update_server_time_difference(double diff);

  void reset_server_time_difference(double diff);

  uint64 get_server_salt(double now) {
    update_salt(now);
    return server_salt_.salt;
  }

  void set_server_salt(uint64 salt, double now) {
    server_salt_.salt = salt;
    double server_time = get_server_time(now);
    server_salt_.valid_since = server_time;
    server_salt_.valid_until = server_time + 60 * 10;
    future_salts_.clear();
  }

  bool is_server_salt_valid(double now) const {
    return server_salt_.valid_until > get_server_time(now) + 60;
  }

  bool has_salt(double now) {
    update_salt(now);
    return is_server_salt_valid(now);
  }

  bool need_future_salts(double now) {
    update_salt(now);
    return future_salts_.empty() || !is_server_salt_valid(now);
  }

  void set_future_salts(const std::vector<ServerSalt> &salts, double now);

  std::vector<ServerSalt> get_future_salts() const;

  MessageId next_message_id(double now);

  bool is_valid_outbound_msg_id(MessageId message_id, double now) const;

  bool is_valid_inbound_msg_id(MessageId message_id, double now) const;

  Status check_packet(uint64 session_id, MessageId message_id, double now, bool &time_difference_was_updated);

  Status check_update(MessageId message_id) {
    return updates_duplicate_checker_.check(message_id);
  }

  Status recheck_update(MessageId message_id) {
    return updates_duplicate_rechecker_.check(message_id);
  }

  int32 next_seq_no(bool is_content_related) {
    int32 res = seq_no_;
    if (is_content_related) {
      res |= 1;
      seq_no_ += 2;
    }
    return res;
  }

  void clear_seq_no() {
    seq_no_ = 0;
  }

  void set_use_pfs(bool use_pfs) {
    use_pfs_ = use_pfs;
  }
  bool use_pfs() const {
    return use_pfs_;
  }

 private:
  bool use_pfs_ = true;
  AuthKey main_auth_key_;
  AuthKey tmp_auth_key_;
  bool server_time_difference_was_updated_ = false;
  double server_time_difference_ = 0;
  ServerSalt server_salt_;
  MessageId last_message_id_;
  int32 seq_no_ = 0;
  string header_;
  uint64 session_id_ = 0;

  std::vector<ServerSalt> future_salts_;

  MessageIdDuplicateChecker<1000> duplicate_checker_;
  MessageIdDuplicateChecker<1000> updates_duplicate_checker_;
  MessageIdDuplicateChecker<100> updates_duplicate_rechecker_;

  void update_salt(double now);
};

}  // namespace mtproto
}  // namespace td
