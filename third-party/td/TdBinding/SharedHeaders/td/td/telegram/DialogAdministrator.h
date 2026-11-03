//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

class UserManager;

class DialogAdministrator {
  UserId user_id_;
  string rank_;
  bool is_creator_ = false;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const DialogAdministrator &administrator);

 public:
  DialogAdministrator() = default;

  DialogAdministrator(UserId user_id, const string &rank, bool is_creator)
      : user_id_(user_id), rank_(rank), is_creator_(is_creator) {
  }

  td_api::object_ptr<td_api::chatAdministrator> get_chat_administrator_object(const UserManager *user_manager) const;

  UserId get_user_id() const {
    return user_id_;
  }

  const string &get_rank() const {
    return rank_;
  }

  bool is_creator() const {
    return is_creator_;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    using td::store;
    bool has_rank = !rank_.empty();
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_rank);
    STORE_FLAG(is_creator_);
    END_STORE_FLAGS();
    store(user_id_, storer);
    if (has_rank) {
      store(rank_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    using td::parse;
    bool has_rank;
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_rank);
    PARSE_FLAG(is_creator_);
    END_PARSE_FLAGS();
    parse(user_id_, parser);
    if (has_rank) {
      parse(rank_, parser);
    }
  }
};

inline bool operator==(const DialogAdministrator &lhs, const DialogAdministrator &rhs) {
  return lhs.get_user_id() == rhs.get_user_id() && lhs.get_rank() == rhs.get_rank() &&
         lhs.is_creator() == rhs.is_creator();
}

inline bool operator!=(const DialogAdministrator &lhs, const DialogAdministrator &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const DialogAdministrator &administrator);

}  // namespace td
