//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BackgroundId.h"
#include "td/telegram/BackgroundType.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class BackgroundInfo {
  BackgroundId background_id_;
  BackgroundType background_type_;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BackgroundInfo &background_info);

 public:
  BackgroundInfo() : background_id_(), background_type_() {
  }

  BackgroundInfo(Td *td, telegram_api::object_ptr<telegram_api::WallPaper> &&wallpaper_ptr, bool allow_empty);

  td_api::object_ptr<td_api::background> get_background_object(const Td *td) const;

  td_api::object_ptr<td_api::chatBackground> get_chat_background_object(const Td *td) const;

  bool is_valid() const {
    return background_id_.is_valid();
  }

  bool operator==(const BackgroundInfo &other) const {
    return background_type_ == other.background_type_ &&
           (background_id_ == other.background_id_ || (background_id_.is_local() && other.background_id_.is_local()));
  }

  bool operator!=(const BackgroundInfo &other) const {
    return !(*this == other);
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

inline StringBuilder &operator<<(StringBuilder &string_builder, const BackgroundInfo &background_info) {
  return string_builder << background_info.background_id_ << " with " << background_info.background_type_;
}

}  // namespace td
