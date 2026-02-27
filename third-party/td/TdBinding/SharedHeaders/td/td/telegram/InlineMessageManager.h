//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

class InlineMessageManager final : public Actor {
 public:
  InlineMessageManager(Td *td, ActorShared<> parent);

  void edit_inline_message_text(const string &inline_message_id, td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                                td_api::object_ptr<td_api::InputMessageContent> &&input_message_content,
                                Promise<Unit> &&promise);

  void edit_inline_message_live_location(const string &inline_message_id,
                                         td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                                         td_api::object_ptr<td_api::location> &&input_location, int32 live_period,
                                         int32 heading, int32 proximity_alert_radius, Promise<Unit> &&promise);

  void edit_inline_message_media(const string &inline_message_id,
                                 td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                                 td_api::object_ptr<td_api::InputMessageContent> &&input_message_content,
                                 Promise<Unit> &&promise);

  void edit_inline_message_caption(const string &inline_message_id,
                                   td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                                   td_api::object_ptr<td_api::formattedText> &&input_caption, bool invert_media,
                                   Promise<Unit> &&promise);

  void edit_inline_message_reply_markup(const string &inline_message_id,
                                        td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                                        Promise<Unit> &&promise);

  void set_inline_game_score(const string &inline_message_id, bool edit_message, UserId user_id, int32 score,
                             bool force, Promise<Unit> &&promise);

  void get_inline_game_high_scores(const string &inline_message_id, UserId user_id,
                                   Promise<td_api::object_ptr<td_api::gameHighScores>> &&promise);

 private:
  void tear_down() final;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
