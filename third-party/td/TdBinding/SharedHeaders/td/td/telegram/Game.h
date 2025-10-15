//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/Photo.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class UserManager;
class Td;

class Game {
  int64 id_ = 0;
  int64 access_hash_ = 0;
  UserId bot_user_id_;
  string short_name_;
  string title_;
  string description_;
  Photo photo_;
  FileId animation_file_id_;

  FormattedText text_;

  friend bool operator==(const Game &lhs, const Game &rhs);
  friend bool operator!=(const Game &lhs, const Game &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const Game &game);

 public:
  Game() = default;

  Game(Td *td, UserId bot_user_id, tl_object_ptr<telegram_api::game> &&game, FormattedText text,
       DialogId owner_dialog_id);

  // for inline results
  Game(Td *td, string title, string description, tl_object_ptr<telegram_api::Photo> &&photo,
       tl_object_ptr<telegram_api::Document> &&document, DialogId owner_dialog_id);

  // for outgoing messages
  Game(UserId bot_user_id, string short_name);

  bool is_empty() const;

  UserId get_bot_user_id() const;

  vector<FileId> get_file_ids(const Td *td) const;

  const FormattedText &get_text() const;

  tl_object_ptr<td_api::game> get_game_object(Td *td, bool is_server, bool skip_bot_commands) const;

  bool has_input_media() const;

  tl_object_ptr<telegram_api::inputMediaGame> get_input_media_game(const Td *td) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const Game &lhs, const Game &rhs);
bool operator!=(const Game &lhs, const Game &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const Game &game);

Result<Game> process_input_message_game(const UserManager *user_manager,
                                        tl_object_ptr<td_api::InputMessageContent> &&input_message_content)
    TD_WARN_UNUSED_RESULT;

}  // namespace td
