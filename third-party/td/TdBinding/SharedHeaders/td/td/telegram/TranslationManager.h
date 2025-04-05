//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageEntity.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

class TranslationManager final : public Actor {
 public:
  TranslationManager(Td *td, ActorShared<> parent);

  void translate_text(td_api::object_ptr<td_api::formattedText> &&text, const string &to_language_code,
                      Promise<td_api::object_ptr<td_api::formattedText>> &&promise);

  void translate_text(FormattedText text, bool skip_bot_commands, int32 max_media_timestamp,
                      const string &to_language_code, Promise<td_api::object_ptr<td_api::formattedText>> &&promise);

 private:
  void tear_down() final;

  void on_get_translated_texts(vector<telegram_api::object_ptr<telegram_api::textWithEntities>> texts,
                               bool skip_bot_commands, int32 max_media_timestamp,
                               Promise<td_api::object_ptr<td_api::formattedText>> &&promise);

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
