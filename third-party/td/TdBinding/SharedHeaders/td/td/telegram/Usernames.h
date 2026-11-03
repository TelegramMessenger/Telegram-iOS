//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

class Usernames {
  vector<string> active_usernames_;
  vector<string> disabled_usernames_;
  int32 editable_username_pos_ = -1;

  friend bool operator==(const Usernames &lhs, const Usernames &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const Usernames &usernames);

  void check_utf8_validness();

 public:
  Usernames() = default;

  Usernames(string &&first_username, vector<telegram_api::object_ptr<telegram_api::username>> &&usernames);

  td_api::object_ptr<td_api::usernames> get_usernames_object() const;

  bool is_empty() const {
    return editable_username_pos_ == -1 && active_usernames_.empty() && disabled_usernames_.empty();
  }

  string get_first_username() const {
    if (!has_first_username()) {
      return string();
    }
    return active_usernames_[0];
  }

  bool has_first_username() const {
    return !active_usernames_.empty();
  }

  string get_editable_username() const {
    if (!has_editable_username()) {
      return string();
    }
    return active_usernames_[editable_username_pos_];
  }

  bool has_editable_username() const {
    return editable_username_pos_ != -1;
  }

  const vector<string> &get_active_usernames() const {
    return active_usernames_;
  }

  Usernames change_editable_username(string &&new_username) const;

  bool can_toggle(const string &username) const;

  Usernames toggle(const string &username, bool is_active) const;

  Usernames deactivate_all() const;

  bool can_reorder_to(const vector<string> &new_username_order) const;

  Usernames reorder_to(vector<string> &&new_username_order) const;

  template <class StorerT>
  void store(StorerT &storer) const {
    CHECK(!is_empty());
    bool has_many_active_usernames = active_usernames_.size() > 1;
    bool has_disabled_usernames = !disabled_usernames_.empty();
    bool has_editable_username = editable_username_pos_ != -1;
    bool has_active_usernames = !active_usernames_.empty();
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_many_active_usernames);
    STORE_FLAG(has_disabled_usernames);
    STORE_FLAG(has_editable_username);
    STORE_FLAG(has_active_usernames);
    END_STORE_FLAGS();
    if (has_many_active_usernames) {
      td::store(active_usernames_, storer);
      if (has_editable_username) {
        td::store(editable_username_pos_, storer);
      }
    } else if (has_active_usernames) {
      td::store(active_usernames_[0], storer);
    }
    if (has_disabled_usernames) {
      td::store(disabled_usernames_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    using td::parse;
    bool has_many_active_usernames;
    bool has_disabled_usernames;
    bool has_editable_username;
    bool has_active_usernames;
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_many_active_usernames);
    PARSE_FLAG(has_disabled_usernames);
    PARSE_FLAG(has_editable_username);
    PARSE_FLAG(has_active_usernames);
    END_PARSE_FLAGS();
    if (has_many_active_usernames) {
      td::parse(active_usernames_, parser);
      if (has_editable_username) {
        td::parse(editable_username_pos_, parser);
        CHECK(static_cast<size_t>(editable_username_pos_) < active_usernames_.size());
      }
    } else if (has_active_usernames) {
      active_usernames_.resize(1);
      td::parse(active_usernames_[0], parser);
      if (has_editable_username) {
        editable_username_pos_ = 0;
      }
    }
    if (has_disabled_usernames) {
      td::parse(disabled_usernames_, parser);
    }
    check_utf8_validness();
  }
};

bool operator==(const Usernames &lhs, const Usernames &rhs);
bool operator!=(const Usernames &lhs, const Usernames &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const Usernames &usernames);

}  // namespace td
