//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

class CallbackQueriesManager {
 public:
  explicit CallbackQueriesManager(Td *td);

  void answer_callback_query(int64 callback_query_id, const string &text, bool show_alert, const string &url,
                             int32 cache_time, Promise<Unit> &&promise) const;

  void on_new_query(int64 callback_query_id, UserId sender_user_id, DialogId dialog_id, MessageId message_id,
                    BufferSlice &&data, int64 chat_instance, string &&game_short_name);

  void on_new_inline_query(int64 callback_query_id, UserId sender_user_id,
                           tl_object_ptr<telegram_api::InputBotInlineMessageID> &&inline_message_id, BufferSlice &&data,
                           int64 chat_instance, string &&game_short_name);

  void on_new_business_query(int64 callback_query_id, UserId sender_user_id, string &&connection_id,
                             telegram_api::object_ptr<telegram_api::Message> &&message,
                             telegram_api::object_ptr<telegram_api::Message> &&reply_to_message, BufferSlice &&data,
                             int64 chat_instance);

  void send_callback_query(MessageFullId message_full_id, tl_object_ptr<td_api::CallbackQueryPayload> &&payload,
                           Promise<td_api::object_ptr<td_api::callbackQueryAnswer>> &&promise);

 private:
  static tl_object_ptr<td_api::CallbackQueryPayload> get_query_payload(BufferSlice &&data, string &&game_short_name);

  void send_get_callback_answer_query(MessageFullId message_full_id,
                                      tl_object_ptr<td_api::CallbackQueryPayload> &&payload,
                                      tl_object_ptr<telegram_api::InputCheckPasswordSRP> &&password,
                                      Promise<td_api::object_ptr<td_api::callbackQueryAnswer>> &&promise);

  Td *td_;
};

}  // namespace td
