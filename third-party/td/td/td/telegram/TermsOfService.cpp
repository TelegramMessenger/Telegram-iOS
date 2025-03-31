//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/TermsOfService.h"

namespace td {

TermsOfService::TermsOfService(telegram_api::object_ptr<telegram_api::help_termsOfService> terms) {
  if (terms == nullptr) {
    return;
  }

  id_ = std::move(terms->id_->data_);
  text_ =
      get_formatted_text(nullptr, std::move(terms->text_), std::move(terms->entities_), true, false, "TermsOfService");
  if (text_.text.empty()) {
    id_.clear();
  }
  min_user_age_ = terms->min_age_confirm_;
  show_popup_ = terms->popup_;
}

td_api::object_ptr<td_api::termsOfService> TermsOfService::get_terms_of_service_object() const {
  if (id_.empty()) {
    return nullptr;
  }

  return td_api::make_object<td_api::termsOfService>(get_formatted_text_object(nullptr, text_, true, -1), min_user_age_,
                                                     show_popup_);
}

}  // namespace td
