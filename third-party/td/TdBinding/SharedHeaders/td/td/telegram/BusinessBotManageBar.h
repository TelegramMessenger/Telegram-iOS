//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

class Dependencies;
class Td;

class BusinessBotManageBar {
  UserId business_bot_user_id_;
  string business_bot_manage_url_;
  bool is_business_bot_paused_ = false;
  bool can_business_bot_reply_ = false;

  friend bool operator==(const BusinessBotManageBar &lhs, const BusinessBotManageBar &rhs);

 public:
  static unique_ptr<BusinessBotManageBar> create(bool is_business_bot_paused, bool can_business_bot_reply,
                                                 UserId business_bot_user_id, string business_bot_manage_url);

  bool is_empty() const;

  void fix(DialogId dialog_id);

  td_api::object_ptr<td_api::businessBotManageBar> get_business_bot_manage_bar_object(Td *td) const;

  bool on_user_deleted();

  bool set_business_bot_is_paused(bool is_paused);

  void add_dependencies(Dependencies &dependencies) const;

  template <class StorerT>
  void store(StorerT &storer) const {
    bool has_business_bot_user_id = business_bot_user_id_.is_valid();
    bool has_business_bot_manage_url = !business_bot_manage_url_.empty();
    BEGIN_STORE_FLAGS();
    STORE_FLAG(is_business_bot_paused_);
    STORE_FLAG(can_business_bot_reply_);
    STORE_FLAG(has_business_bot_user_id);
    STORE_FLAG(has_business_bot_manage_url);
    END_STORE_FLAGS();
    if (has_business_bot_user_id) {
      td::store(business_bot_user_id_, storer);
    }
    if (has_business_bot_manage_url) {
      td::store(business_bot_manage_url_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    bool has_business_bot_user_id;
    bool has_business_bot_manage_url;
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(is_business_bot_paused_);
    PARSE_FLAG(can_business_bot_reply_);
    PARSE_FLAG(has_business_bot_user_id);
    PARSE_FLAG(has_business_bot_manage_url);
    END_PARSE_FLAGS();
    if (has_business_bot_user_id) {
      td::parse(business_bot_user_id_, parser);
    }
    if (has_business_bot_manage_url) {
      td::parse(business_bot_manage_url_, parser);
    }
  }
};

bool operator==(const BusinessBotManageBar &lhs, const BusinessBotManageBar &rhs);

bool operator!=(const BusinessBotManageBar &lhs, const BusinessBotManageBar &rhs);

}  // namespace td
