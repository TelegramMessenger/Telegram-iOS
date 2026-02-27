//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageInputReplyTo.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"
#include "td/actor/Timeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class Td;
class WebAppOpenParameters;

class WebAppManager final : public Actor {
 public:
  WebAppManager(Td *td, ActorShared<> parent);

  void get_popular_app_bots(const string &offset, int32 limit,
                            Promise<td_api::object_ptr<td_api::foundUsers>> &&promise);

  void get_web_app(UserId bot_user_id, const string &web_app_short_name,
                   Promise<td_api::object_ptr<td_api::foundWebApp>> &&promise);

  void reload_web_app(UserId bot_user_id, const string &web_app_short_name, Promise<Unit> &&promise);

  void request_app_web_view(DialogId dialog_id, UserId bot_user_id, string &&web_app_short_name,
                            string &&start_parameter, const WebAppOpenParameters &parameters, bool allow_write_access,
                            Promise<string> &&promise);

  void request_main_web_view(DialogId dialog_id, UserId bot_user_id, string &&start_parameter,
                             const WebAppOpenParameters &parameters,
                             Promise<td_api::object_ptr<td_api::mainWebApp>> &&promise);

  void request_web_view(DialogId dialog_id, UserId bot_user_id, MessageId top_thread_message_id,
                        td_api::object_ptr<td_api::InputMessageReplyTo> &&reply_to, string &&url,
                        const WebAppOpenParameters &parameters,
                        Promise<td_api::object_ptr<td_api::webAppInfo>> &&promise);

  void open_web_view(int64 query_id, DialogId dialog_id, UserId bot_user_id, MessageId top_thread_message_id,
                     MessageInputReplyTo &&input_reply_to, DialogId as_dialog_id);

  void close_web_view(int64 query_id, Promise<Unit> &&promise);

  void invoke_web_view_custom_method(UserId bot_user_id, const string &method, const string &parameters,
                                     Promise<td_api::object_ptr<td_api::customRequestResult>> &&promise);

  void check_download_file_params(UserId bot_user_id, const string &file_name, const string &url,
                                  Promise<Unit> &&promise);

  FileSourceId get_web_app_file_source_id(UserId user_id, const string &short_name);

 private:
  static const int32 PING_WEB_VIEW_TIMEOUT = 60;

  void start_up() final;

  void tear_down() final;

  void on_online(bool is_online);

  static void ping_web_view_static(void *td_void);

  void ping_web_view();

  void schedule_ping_web_view();

  void on_get_web_app(UserId bot_user_id, string web_app_short_name,
                      Result<telegram_api::object_ptr<telegram_api::messages_botApp>> result,
                      Promise<td_api::object_ptr<td_api::foundWebApp>> promise);

  Td *td_;
  ActorShared<> parent_;

  FlatHashMap<UserId, FlatHashMap<string, FileSourceId>, UserIdHash> web_app_file_source_ids_;

  struct OpenedWebView {
    DialogId dialog_id_;
    UserId bot_user_id_;
    MessageId top_thread_message_id_;
    MessageInputReplyTo input_reply_to_;
    DialogId as_dialog_id_;
  };
  FlatHashMap<int64, OpenedWebView> opened_web_views_;
  Timeout ping_web_view_timeout_;
};

}  // namespace td
