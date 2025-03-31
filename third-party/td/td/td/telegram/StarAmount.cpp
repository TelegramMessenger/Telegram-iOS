//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StarAmount.h"

#include "td/telegram/StarManager.h"

#include "td/utils/misc.h"

namespace td {

StarAmount::StarAmount(telegram_api::object_ptr<telegram_api::starsAmount> &&amount, bool allow_negative) {
  if (amount != nullptr) {
    star_count_ = StarManager::get_star_count(amount->amount_, allow_negative);
    nanostar_count_ = StarManager::get_nanostar_count(star_count_, amount->nanos_);
  }
}

td_api::object_ptr<td_api::starAmount> StarAmount::get_star_amount_object() const {
  return td_api::make_object<td_api::starAmount>(star_count_, nanostar_count_);
}

bool operator==(const StarAmount &lhs, const StarAmount &rhs) {
  return lhs.star_count_ == rhs.star_count_ && lhs.nanostar_count_ == rhs.nanostar_count_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const StarAmount &star_amount) {
  auto star_count = star_amount.get_star_count();
  auto nanostar_count = star_amount.get_nanostar_count();
  if (star_count < 0 || nanostar_count < 0) {
    string_builder << '-';
    star_count *= -1;
    nanostar_count *= -1;
  }
  string_builder << star_count;
  if (nanostar_count != 0) {
    auto nanostar_str = lpad0(to_string(nanostar_count), 9);
    while (!nanostar_str.empty() && nanostar_str.back() == '0') {
      nanostar_str.pop_back();
    }
    string_builder << '.' << nanostar_str;
  }
  return string_builder << " Telegram Stars";
}

}  // namespace td
