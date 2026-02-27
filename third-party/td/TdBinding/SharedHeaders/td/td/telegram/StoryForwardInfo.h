//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/StoryFullId.h"
#include "td/telegram/StoryId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"

#include <utility>

namespace td {

class Dependencies;
class Td;

class StoryForwardInfo {
  DialogId dialog_id_;
  StoryId story_id_;
  string sender_name_;
  bool is_modified_ = false;

  friend bool operator==(const StoryForwardInfo &lhs, const StoryForwardInfo &rhs);

 public:
  StoryForwardInfo() = default;

  StoryForwardInfo(Td *td, telegram_api::object_ptr<telegram_api::storyFwdHeader> &&fwd_header);

  StoryForwardInfo(StoryFullId story_full_id, bool is_modified)
      : dialog_id_(story_full_id.get_dialog_id()), story_id_(story_full_id.get_story_id()), is_modified_(is_modified) {
  }

  void hide_sender_if_needed(Td *td);

  void add_dependencies(Dependencies &dependencies) const;

  td_api::object_ptr<td_api::storyRepostInfo> get_story_repost_info_object(Td *td) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StoryForwardInfo &lhs, const StoryForwardInfo &rhs);

}  // namespace td
