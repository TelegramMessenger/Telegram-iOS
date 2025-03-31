//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BackgroundInfo.h"

#include "td/telegram/BackgroundManager.h"
#include "td/telegram/Td.h"

namespace td {

BackgroundInfo::BackgroundInfo(Td *td, telegram_api::object_ptr<telegram_api::WallPaper> &&wallpaper_ptr,
                               bool allow_empty) {
  auto background = td->background_manager_->on_get_background(BackgroundId(), string(), std::move(wallpaper_ptr),
                                                               false, allow_empty);
  background_id_ = background.first;
  background_type_ = std::move(background.second);
}

td_api::object_ptr<td_api::background> BackgroundInfo::get_background_object(const Td *td) const {
  return td->background_manager_->get_background_object(background_id_, false, &background_type_);
}

td_api::object_ptr<td_api::chatBackground> BackgroundInfo::get_chat_background_object(const Td *td) const {
  auto background = get_background_object(td);
  if (background == nullptr) {
    return nullptr;
  }
  return td_api::make_object<td_api::chatBackground>(std::move(background), background_type_.get_dark_theme_dimming());
}

}  // namespace td
