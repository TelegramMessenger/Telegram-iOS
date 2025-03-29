//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogInviteLink.h"

#include "td/telegram/StarSubscriptionPricing.hpp"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void DialogInviteLink::store(StorerT &storer) const {
  using td::store;
  bool has_expire_date = expire_date_ != 0;
  bool has_usage_limit = usage_limit_ != 0;
  bool has_usage_count = usage_count_ != 0;
  bool has_edit_date = edit_date_ != 0;
  bool has_request_count = request_count_ != 0;
  bool has_title = !title_.empty();
  bool has_pricing = !pricing_.is_empty();
  bool has_expired_usage_count = expired_usage_count_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_revoked_);
  STORE_FLAG(is_permanent_);
  STORE_FLAG(has_expire_date);
  STORE_FLAG(has_usage_limit);
  STORE_FLAG(has_usage_count);
  STORE_FLAG(has_edit_date);
  STORE_FLAG(has_request_count);
  STORE_FLAG(creates_join_request_);
  STORE_FLAG(has_title);
  STORE_FLAG(has_pricing);
  STORE_FLAG(has_expired_usage_count);
  END_STORE_FLAGS();
  store(invite_link_, storer);
  store(creator_user_id_, storer);
  store(date_, storer);
  if (has_expire_date) {
    store(expire_date_, storer);
  }
  if (has_usage_limit) {
    store(usage_limit_, storer);
  }
  if (has_usage_count) {
    store(usage_count_, storer);
  }
  if (has_edit_date) {
    store(edit_date_, storer);
  }
  if (has_request_count) {
    store(request_count_, storer);
  }
  if (has_title) {
    store(title_, storer);
  }
  if (has_pricing) {
    store(pricing_, storer);
  }
  if (has_expired_usage_count) {
    store(expired_usage_count_, storer);
  }
}

template <class ParserT>
void DialogInviteLink::parse(ParserT &parser) {
  using td::parse;
  bool has_expire_date;
  bool has_usage_limit;
  bool has_usage_count;
  bool has_edit_date;
  bool has_request_count;
  bool has_title;
  bool has_pricing;
  bool has_expired_usage_count;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_revoked_);
  PARSE_FLAG(is_permanent_);
  PARSE_FLAG(has_expire_date);
  PARSE_FLAG(has_usage_limit);
  PARSE_FLAG(has_usage_count);
  PARSE_FLAG(has_edit_date);
  PARSE_FLAG(has_request_count);
  PARSE_FLAG(creates_join_request_);
  PARSE_FLAG(has_title);
  PARSE_FLAG(has_pricing);
  PARSE_FLAG(has_expired_usage_count);
  END_PARSE_FLAGS();
  parse(invite_link_, parser);
  parse(creator_user_id_, parser);
  parse(date_, parser);
  if (has_expire_date) {
    parse(expire_date_, parser);
  }
  if (has_usage_limit) {
    parse(usage_limit_, parser);
  }
  if (has_usage_count) {
    parse(usage_count_, parser);
  }
  if (has_edit_date) {
    parse(edit_date_, parser);
  }
  if (has_request_count) {
    parse(request_count_, parser);
  }
  if (has_title) {
    parse(title_, parser);
  }
  if (has_pricing) {
    parse(pricing_, parser);
  }
  if (has_expired_usage_count) {
    parse(expired_usage_count_, parser);
  }
  if (creates_join_request_) {
    usage_limit_ = 0;
  }
}

}  // namespace td
