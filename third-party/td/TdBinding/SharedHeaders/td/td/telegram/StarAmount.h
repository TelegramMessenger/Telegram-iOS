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

namespace td {

class StarAmount {
  int64 star_count_ = 0;
  int32 nanostar_count_ = 0;

  friend bool operator==(const StarAmount &lhs, const StarAmount &rhs);

 public:
  StarAmount() = default;

  StarAmount(telegram_api::object_ptr<telegram_api::starsAmount> &&amount, bool allow_negative);

  int64 get_star_count() const {
    return star_count_;
  }

  int32 get_nanostar_count() const {
    return nanostar_count_;
  }

  bool is_positive() const {
    return star_count_ > 0 || nanostar_count_ > 0;
  }

  td_api::object_ptr<td_api::starAmount> get_star_amount_object() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StarAmount &lhs, const StarAmount &rhs);

inline bool operator!=(const StarAmount &lhs, const StarAmount &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const StarAmount &star_amount);

}  // namespace td
