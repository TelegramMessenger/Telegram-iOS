//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/FactCheck.h"

#include "td/telegram/Dependencies.h"
#include "td/telegram/telegram_api.h"

namespace td {

FactCheck::~FactCheck() = default;

unique_ptr<FactCheck> FactCheck::get_fact_check(const UserManager *user_manager,
                                                telegram_api::object_ptr<telegram_api::factCheck> &&fact_check,
                                                bool is_bot) {
  if (is_bot || fact_check == nullptr || fact_check->hash_ == 0) {
    return nullptr;
  }
  auto result = make_unique<FactCheck>();
  result->country_code_ = std::move(fact_check->country_);
  result->text_ = get_formatted_text(user_manager, std::move(fact_check->text_), true, false, "factCheck");
  result->hash_ = fact_check->hash_;
  result->need_check_ = fact_check->need_check_;
  return result;
}

void FactCheck::update_from(const FactCheck &old_fact_check) {
  if (!need_check_ || old_fact_check.need_check_ || hash_ != old_fact_check.hash_) {
    return;
  }
  need_check_ = false;
  country_code_ = old_fact_check.country_code_;
  text_ = old_fact_check.text_;
}

void FactCheck::add_dependencies(Dependencies &dependencies) const {
  add_formatted_text_dependencies(dependencies, &text_);
}

td_api::object_ptr<td_api::factCheck> FactCheck::get_fact_check_object(const UserManager *user_manager) const {
  if (is_empty() || need_check_) {
    return nullptr;
  }
  return td_api::make_object<td_api::factCheck>(get_formatted_text_object(user_manager, text_, true, -1),
                                                country_code_);
}

bool operator==(const FactCheck &lhs, const FactCheck &rhs) {
  return lhs.country_code_ == rhs.country_code_ && lhs.text_ == rhs.text_ && lhs.hash_ == rhs.hash_ &&
         lhs.need_check_ == rhs.need_check_;
}

}  // namespace td
