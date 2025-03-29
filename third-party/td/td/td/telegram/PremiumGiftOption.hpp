//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/PremiumGiftOption.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void PremiumGiftOption::store(StorerT &storer) const {
  bool has_months = months_ != 0;
  bool has_currency = !currency_.empty();
  bool has_amount = amount_ != 0;
  bool has_bot_url = !bot_url_.empty();
  bool has_store_product = !store_product_.empty();
  bool has_transaction = !transaction_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_months);
  STORE_FLAG(has_currency);
  STORE_FLAG(has_amount);
  STORE_FLAG(has_bot_url);
  STORE_FLAG(has_store_product);
  STORE_FLAG(is_current_);
  STORE_FLAG(is_upgrade_);
  STORE_FLAG(has_transaction);
  END_STORE_FLAGS();
  if (has_months) {
    td::store(months_, storer);
  }
  if (has_currency) {
    td::store(currency_, storer);
  }
  if (has_amount) {
    td::store(amount_, storer);
  }
  if (has_bot_url) {
    td::store(bot_url_, storer);
  }
  if (has_store_product) {
    td::store(store_product_, storer);
  }
  if (has_transaction) {
    td::store(transaction_, storer);
  }
}

template <class ParserT>
void PremiumGiftOption::parse(ParserT &parser) {
  bool has_months;
  bool has_currency;
  bool has_amount;
  bool has_bot_url;
  bool has_store_product;
  bool has_transaction;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_months);
  PARSE_FLAG(has_currency);
  PARSE_FLAG(has_amount);
  PARSE_FLAG(has_bot_url);
  PARSE_FLAG(has_store_product);
  PARSE_FLAG(is_current_);
  PARSE_FLAG(is_upgrade_);
  PARSE_FLAG(has_transaction);
  END_PARSE_FLAGS();
  if (has_months) {
    td::parse(months_, parser);
  }
  if (has_currency) {
    td::parse(currency_, parser);
  }
  if (has_amount) {
    td::parse(amount_, parser);
  }
  if (has_bot_url) {
    td::parse(bot_url_, parser);
  }
  if (has_store_product) {
    td::parse(store_product_, parser);
  }
  if (has_transaction) {
    td::parse(transaction_, parser);
  }
}

}  // namespace td
