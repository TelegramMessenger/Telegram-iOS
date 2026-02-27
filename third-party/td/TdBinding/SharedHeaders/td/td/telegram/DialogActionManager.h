//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessConnectionId.h"
#include "td/telegram/DialogAction.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/MessageContentType.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/net/NetQuery.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

class DialogActionManager final : public Actor {
 public:
  DialogActionManager(Td *td, ActorShared<> parent);

  void on_dialog_action(DialogId dialog_id, MessageId top_thread_message_id, DialogId typing_dialog_id,
                        DialogAction action, int32 date,
                        MessageContentType message_content_type = MessageContentType::None);

  void send_dialog_action(DialogId dialog_id, MessageId top_thread_message_id,
                          BusinessConnectionId business_connection_id, DialogAction action, Promise<Unit> &&promise);

  void cancel_send_dialog_action_queries(DialogId dialog_id);

  void after_set_typing_query(DialogId dialog_id, int32 generation);

  void clear_active_dialog_actions(DialogId dialog_id);

 private:
  static constexpr double DIALOG_ACTION_TIMEOUT = 5.5;

  void tear_down() final;

  void send_update_chat_action(DialogId dialog_id, MessageId top_thread_message_id, DialogId typing_dialog_id,
                               const DialogAction &action);

  static void on_active_dialog_action_timeout_callback(void *dialog_action_manager_ptr, int64 dialog_id_int);

  void on_active_dialog_action_timeout(DialogId dialog_id);

  struct ActiveDialogAction {
    MessageId top_thread_message_id;
    DialogId typing_dialog_id;
    DialogAction action;
    double start_time;

    ActiveDialogAction(MessageId top_thread_message_id, DialogId typing_dialog_id, DialogAction action,
                       double start_time)
        : top_thread_message_id(top_thread_message_id)
        , typing_dialog_id(typing_dialog_id)
        , action(std::move(action))
        , start_time(start_time) {
    }
  };
  FlatHashMap<DialogId, std::vector<ActiveDialogAction>, DialogIdHash> active_dialog_actions_;

  MultiTimeout active_dialog_action_timeout_{"ActiveDialogActionTimeout"};

  FlatHashMap<DialogId, NetQueryRef, DialogIdHash> set_typing_query_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
