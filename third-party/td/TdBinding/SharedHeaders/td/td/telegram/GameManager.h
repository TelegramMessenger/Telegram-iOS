//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageFullId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

class GameManager final : public Actor {
 public:
  GameManager(Td *td, ActorShared<> parent);
  GameManager(const GameManager &) = delete;
  GameManager &operator=(const GameManager &) = delete;
  GameManager(GameManager &&) = delete;
  GameManager &operator=(GameManager &&) = delete;
  ~GameManager() final;

  void set_game_score(MessageFullId message_full_id, bool edit_message, UserId user_id, int32 score, bool force,
                      Promise<td_api::object_ptr<td_api::message>> &&promise);

  void get_game_high_scores(MessageFullId message_full_id, UserId user_id,
                            Promise<td_api::object_ptr<td_api::gameHighScores>> &&promise);

  td_api::object_ptr<td_api::gameHighScores> get_game_high_scores_object(
      telegram_api::object_ptr<telegram_api::messages_highScores> &&high_scores);

 private:
  void tear_down() final;

  void on_set_game_score(MessageFullId message_full_id, Promise<td_api::object_ptr<td_api::message>> &&promise);

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
