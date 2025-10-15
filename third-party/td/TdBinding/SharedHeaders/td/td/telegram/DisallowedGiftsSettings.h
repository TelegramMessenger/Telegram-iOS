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

class DisallowedGiftsSettings {
  bool disallow_unlimited_stargifts_ = false;
  bool disallow_limited_stargifts_ = false;
  bool disallow_unique_stargifts_ = false;
  bool disallow_premium_gifts_ = false;

  friend bool operator==(const DisallowedGiftsSettings &lhs, const DisallowedGiftsSettings &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const DisallowedGiftsSettings &settings);

 public:
  DisallowedGiftsSettings() = default;

  explicit DisallowedGiftsSettings(telegram_api::object_ptr<telegram_api::disallowedGiftsSettings> &&settings);

  explicit DisallowedGiftsSettings(const td_api::object_ptr<td_api::acceptedGiftTypes> &types);

  td_api::object_ptr<td_api::acceptedGiftTypes> get_accepted_gift_types_object() const;

  telegram_api::object_ptr<telegram_api::disallowedGiftsSettings> get_input_disallowed_gifts_settings() const;

  bool is_default() const {
    return !disallow_unlimited_stargifts_ && !disallow_limited_stargifts_ && !disallow_unique_stargifts_ &&
           !disallow_premium_gifts_;
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const DisallowedGiftsSettings &lhs, const DisallowedGiftsSettings &rhs);

inline bool operator!=(const DisallowedGiftsSettings &lhs, const DisallowedGiftsSettings &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const DisallowedGiftsSettings &settings);

}  // namespace td
