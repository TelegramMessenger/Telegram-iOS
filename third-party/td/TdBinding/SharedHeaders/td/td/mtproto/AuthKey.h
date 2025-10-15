//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/Time.h"

namespace td {
namespace mtproto {

class AuthKey {
 public:
  AuthKey() = default;
  AuthKey(uint64 auth_key_id, string &&auth_key) : auth_key_id_(auth_key_id), auth_key_(auth_key) {
  }
  void break_key() {
    auth_key_id_++;
    auth_key_[0]++;
  }

  bool empty() const {
    return auth_key_.empty();
  }
  const string &key() const {
    return auth_key_;
  }
  uint64 id() const {
    return auth_key_id_;
  }
  bool auth_flag() const {
    return auth_flag_;
  }
  void set_auth_flag(bool new_auth_flag) {
    auth_flag_ = new_auth_flag;
  }

  bool need_header() const {
    return have_header_ || Time::now() < header_expires_at_;
  }
  void remove_header() {
    if (auth_flag_ && have_header_) {
      have_header_ = false;
      header_expires_at_ = Time::now() + 3;
    }
  }
  void restore_header() {
    have_header_ = true;
  }

  double expires_at() const {
    return expires_at_;
  }
  double created_at() const {
    return created_at_;
  }

  void set_expires_at(double expires_at) {
    expires_at_ = expires_at;
  }
  void set_created_at(double created_at) {
    created_at_ = created_at;
  }
  void clear() {
    auth_key_.clear();
  }

  static constexpr int32 AUTH_FLAG = 1;
  static constexpr int32 HAS_CREATED_AT = 4;
  static constexpr int32 HAS_EXPIRES_AT = 8;

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_binary(auth_key_id_);
    bool has_created_at = created_at_ != 0;
    bool has_expires_at = expires_at_ != 0;
    int32 flags = 0;
    if (auth_flag_) {
      flags |= AUTH_FLAG;
    }
    if (has_created_at) {
      flags |= HAS_CREATED_AT;
    }
    if (has_expires_at) {
      flags |= HAS_EXPIRES_AT;
    }
    storer.store_binary(flags);
    storer.store_string(auth_key_);
    if (has_created_at) {
      storer.store_binary(created_at_);
    }
    if (has_expires_at) {
      double time_left = max(expires_at_ - Time::now(), 0.0);
      storer.store_binary(time_left);
      storer.store_binary(Clocks::system());
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    auth_key_id_ = parser.fetch_long();
    auto flags = parser.fetch_int();
    auth_flag_ = (flags & AUTH_FLAG) != 0;
    auth_key_ = parser.template fetch_string<string>();
    if ((flags & HAS_CREATED_AT) != 0) {
      created_at_ = parser.fetch_double();
    }
    if ((flags & HAS_EXPIRES_AT) != 0) {
      double time_left = parser.fetch_double();
      double old_server_time = parser.fetch_double();
      double passed_server_time = max(Clocks::system() - old_server_time, 0.0);
      time_left = max(time_left - passed_server_time, 0.0);
      expires_at_ = Time::now() + time_left;
    }
    // just in case
    have_header_ = true;
  }

 private:
  uint64 auth_key_id_{0};
  string auth_key_;
  bool auth_flag_{false};
  bool have_header_{true};
  double header_expires_at_{0};
  double expires_at_{0};
  double created_at_{0};
};

}  // namespace mtproto
}  // namespace td
