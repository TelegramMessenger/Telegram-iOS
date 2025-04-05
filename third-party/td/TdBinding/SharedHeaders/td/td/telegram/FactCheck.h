//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageEntity.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"

namespace td {

class Dependencies;

class UserManager;

class FactCheck {
  string country_code_;
  FormattedText text_;
  int64 hash_ = 0;
  bool need_check_ = false;

  friend bool operator==(const FactCheck &lhs, const FactCheck &rhs);

 public:
  FactCheck() = default;
  FactCheck(const FactCheck &) = delete;
  FactCheck &operator=(const FactCheck &) = delete;
  FactCheck(FactCheck &&) = default;
  FactCheck &operator=(FactCheck &&) = default;
  ~FactCheck();

  static unique_ptr<FactCheck> get_fact_check(const UserManager *user_manager,
                                              telegram_api::object_ptr<telegram_api::factCheck> &&fact_check,
                                              bool is_bot);

  bool is_empty() const {
    return hash_ == 0;
  }

  bool need_check() const {
    return need_check_;
  }

  void update_from(const FactCheck &old_fact_check);

  void add_dependencies(Dependencies &dependencies) const;

  td_api::object_ptr<td_api::factCheck> get_fact_check_object(const UserManager *user_manager) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const FactCheck &lhs, const FactCheck &rhs);

}  // namespace td
