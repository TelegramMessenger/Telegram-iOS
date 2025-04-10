//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DisallowedGiftsSettings.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class StarGiftSettings {
  bool display_gifts_button_ = false;
  DisallowedGiftsSettings disallowed_gifts_;

  friend bool operator==(const StarGiftSettings &lhs, const StarGiftSettings &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const StarGiftSettings &settings);

 public:
  StarGiftSettings() = default;

  StarGiftSettings(bool display_gifts_button,
                   telegram_api::object_ptr<telegram_api::disallowedGiftsSettings> &&settings);

  explicit StarGiftSettings(const td_api::object_ptr<td_api::giftSettings> &settings);

  td_api::object_ptr<td_api::giftSettings> get_gift_settings_object() const;

  bool get_display_gifts_button() const {
    return display_gifts_button_;
  }

  const DisallowedGiftsSettings &get_disallowed_gifts() const {
    return disallowed_gifts_;
  }

  bool is_default() const {
    return !display_gifts_button_ && disallowed_gifts_.is_default();
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StarGiftSettings &lhs, const StarGiftSettings &rhs);

inline bool operator!=(const StarGiftSettings &lhs, const StarGiftSettings &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const StarGiftSettings &settings);

}  // namespace td
