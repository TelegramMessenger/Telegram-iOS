//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessIntro.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StickersManager.hpp"
#include "td/telegram/Td.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void BusinessIntro::store(StorerT &storer) const {
  bool has_title = !title_.empty();
  bool has_description = !description_.empty();
  bool has_sticker_file_id = sticker_file_id_.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_title);
  STORE_FLAG(has_description);
  STORE_FLAG(has_sticker_file_id);
  END_STORE_FLAGS();
  if (has_title) {
    td::store(title_, storer);
  }
  if (has_description) {
    td::store(description_, storer);
  }
  if (has_sticker_file_id) {
    StickersManager *stickers_manager = storer.context()->td().get_actor_unsafe()->stickers_manager_.get();
    stickers_manager->store_sticker(sticker_file_id_, false, storer, "BusinessIntro");
  }
}

template <class ParserT>
void BusinessIntro::parse(ParserT &parser) {
  bool has_title;
  bool has_description;
  bool has_sticker_file_id;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_title);
  PARSE_FLAG(has_description);
  PARSE_FLAG(has_sticker_file_id);
  END_PARSE_FLAGS();
  if (has_title) {
    td::parse(title_, parser);
  }
  if (has_description) {
    td::parse(description_, parser);
  }
  if (has_sticker_file_id) {
    StickersManager *stickers_manager = parser.context()->td().get_actor_unsafe()->stickers_manager_.get();
    sticker_file_id_ = stickers_manager->parse_sticker(false, parser);
  }
}

}  // namespace td
