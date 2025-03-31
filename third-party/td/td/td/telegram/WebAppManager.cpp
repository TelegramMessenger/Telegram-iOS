//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/WebAppManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AttachMenuManager.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/TopDialogCategory.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/WebApp.h"
#include "td/telegram/WebAppOpenParameters.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"

namespace td {

class GetPopularAppBotsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::foundUsers>> promise_;

 public:
  explicit GetPopularAppBotsQuery(Promise<td_api::object_ptr<td_api::foundUsers>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &offset, int32 limit) {
    send_query(G()->net_query_creator().create(telegram_api::bots_getPopularAppBots(offset, limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_getPopularAppBots>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetPopularAppBotsQuery: " << to_string(ptr);

    vector<int64> user_ids;
    for (auto &user : ptr->users_) {
      auto user_id = td_->user_manager_->get_user_id(user);
      td_->user_manager_->on_get_user(std::move(user), "GetPopularAppBotsQuery");
      if (td_->user_manager_->is_user_bot(user_id)) {
        user_ids.push_back(td_->user_manager_->get_user_id_object(user_id, "GetPopularAppBotsQuery"));
      }
    }
    promise_.set_value(td_api::make_object<td_api::foundUsers>(std::move(user_ids), ptr->next_offset_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetBotAppQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::messages_botApp>> promise_;

 public:
  explicit GetBotAppQuery(Promise<telegram_api::object_ptr<telegram_api::messages_botApp>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::InputUser> &&input_user, const string &short_name) {
    auto input_bot_app =
        telegram_api::make_object<telegram_api::inputBotAppShortName>(std::move(input_user), short_name);
    send_query(G()->net_query_creator().create(telegram_api::messages_getBotApp(std::move(input_bot_app), 0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getBotApp>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetBotAppQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class RequestAppWebViewQuery final : public Td::ResultHandler {
  Promise<string> promise_;

 public:
  explicit RequestAppWebViewQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, telegram_api::object_ptr<telegram_api::InputUser> &&input_user,
            const string &web_app_short_name, const string &start_parameter, const WebAppOpenParameters &parameters,
            bool allow_write_access) {
    int32 flags = 0;
    auto theme_parameters = parameters.get_input_theme_parameters();
    if (theme_parameters != nullptr) {
      flags |= telegram_api::messages_requestAppWebView::THEME_PARAMS_MASK;
    }
    if (allow_write_access) {
      flags |= telegram_api::messages_requestAppWebView::WRITE_ALLOWED_MASK;
    }
    if (!start_parameter.empty()) {
      flags |= telegram_api::messages_requestAppWebView::START_PARAM_MASK;
    }
    if (parameters.is_compact()) {
      flags |= telegram_api::messages_requestAppWebView::COMPACT_MASK;
    }
    if (parameters.is_full_screen()) {
      flags |= telegram_api::messages_requestAppWebView::FULLSCREEN_MASK;
    }
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);
    auto input_bot_app =
        telegram_api::make_object<telegram_api::inputBotAppShortName>(std::move(input_user), web_app_short_name);
    send_query(G()->net_query_creator().create(telegram_api::messages_requestAppWebView(
        flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, std::move(input_peer), std::move(input_bot_app),
        start_parameter, std::move(theme_parameters), parameters.get_application_name())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_requestAppWebView>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for RequestAppWebViewQuery: " << to_string(ptr);
    LOG_IF(ERROR, ptr->query_id_ != 0) << "Receive " << to_string(ptr);
    promise_.set_value(std::move(ptr->url_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class RequestMainWebViewQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::mainWebApp>> promise_;
  bool is_full_screen_ = false;

 public:
  explicit RequestMainWebViewQuery(Promise<td_api::object_ptr<td_api::mainWebApp>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, telegram_api::object_ptr<telegram_api::InputUser> &&input_user,
            const string &start_parameter, const WebAppOpenParameters &parameters) {
    int32 flags = 0;
    auto theme_parameters = parameters.get_input_theme_parameters();
    if (theme_parameters != nullptr) {
      flags |= telegram_api::messages_requestMainWebView::THEME_PARAMS_MASK;
    }
    if (!start_parameter.empty()) {
      flags |= telegram_api::messages_requestMainWebView::START_PARAM_MASK;
    }
    if (parameters.is_compact()) {
      flags |= telegram_api::messages_requestMainWebView::COMPACT_MASK;
    }
    if (parameters.is_full_screen()) {
      is_full_screen_ = true;
      flags |= telegram_api::messages_requestMainWebView::FULLSCREEN_MASK;
    }
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::messages_requestMainWebView(
        flags, false /*ignored*/, false /*ignored*/, std::move(input_peer), std::move(input_user), start_parameter,
        std::move(theme_parameters), parameters.get_application_name())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_requestMainWebView>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for RequestMainWebViewQuery: " << to_string(ptr);
    LOG_IF(ERROR, ptr->query_id_ != 0) << "Receive " << to_string(ptr);
    td_api::object_ptr<td_api::WebAppOpenMode> mode;
    if (is_full_screen_) {
      mode = td_api::make_object<td_api::webAppOpenModeFullScreen>();
    } else if (ptr->fullsize_) {
      mode = td_api::make_object<td_api::webAppOpenModeFullSize>();
    } else {
      mode = td_api::make_object<td_api::webAppOpenModeCompact>();
    }
    promise_.set_value(td_api::make_object<td_api::mainWebApp>(ptr->url_, std::move(mode)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class RequestWebViewQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::webAppInfo>> promise_;
  DialogId dialog_id_;
  UserId bot_user_id_;
  MessageId top_thread_message_id_;
  MessageInputReplyTo input_reply_to_;
  DialogId as_dialog_id_;
  bool from_attach_menu_ = false;

 public:
  explicit RequestWebViewQuery(Promise<td_api::object_ptr<td_api::webAppInfo>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, UserId bot_user_id, tl_object_ptr<telegram_api::InputUser> &&input_user, string &&url,
            const WebAppOpenParameters &parameters, MessageId top_thread_message_id, MessageInputReplyTo input_reply_to,
            bool silent, DialogId as_dialog_id) {
    dialog_id_ = dialog_id;
    bot_user_id_ = bot_user_id;
    top_thread_message_id_ = top_thread_message_id;
    input_reply_to_ = std::move(input_reply_to);
    as_dialog_id_ = as_dialog_id;

    int32 flags = 0;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    string start_parameter;
    if (begins_with(url, "start://")) {
      start_parameter = url.substr(8);
      url = string();

      flags |= telegram_api::messages_requestWebView::START_PARAM_MASK;
    } else if (begins_with(url, "menu://")) {
      url = url.substr(7);

      flags |= telegram_api::messages_requestWebView::FROM_BOT_MENU_MASK;
      flags |= telegram_api::messages_requestWebView::URL_MASK;
    } else if (!url.empty()) {
      flags |= telegram_api::messages_requestWebView::URL_MASK;
    } else {
      from_attach_menu_ = true;
    }

    auto theme_parameters = parameters.get_input_theme_parameters();
    if (theme_parameters != nullptr) {
      flags |= telegram_api::messages_requestWebView::THEME_PARAMS_MASK;
    }

    auto reply_to = input_reply_to_.get_input_reply_to(td_, top_thread_message_id);
    if (reply_to != nullptr) {
      flags |= telegram_api::messages_requestWebView::REPLY_TO_MASK;
    }

    if (silent) {
      flags |= telegram_api::messages_requestWebView::SILENT_MASK;
    }

    tl_object_ptr<telegram_api::InputPeer> as_input_peer;
    if (as_dialog_id.is_valid()) {
      as_input_peer = td_->dialog_manager_->get_input_peer(as_dialog_id, AccessRights::Write);
      if (as_input_peer != nullptr) {
        flags |= telegram_api::messages_requestWebView::SEND_AS_MASK;
      }
    }

    if (parameters.is_compact()) {
      flags |= telegram_api::messages_requestWebView::COMPACT_MASK;
    }
    if (parameters.is_full_screen()) {
      flags |= telegram_api::messages_requestWebView::FULLSCREEN_MASK;
    }

    send_query(G()->net_query_creator().create(telegram_api::messages_requestWebView(
        flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, std::move(input_peer),
        std::move(input_user), url, start_parameter, std::move(theme_parameters), parameters.get_application_name(),
        std::move(reply_to), std::move(as_input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_requestWebView>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG_IF(ERROR, (ptr->flags_ & telegram_api::webViewResultUrl::QUERY_ID_MASK) == 0) << "Receive " << to_string(ptr);
    td_->web_app_manager_->open_web_view(ptr->query_id_, dialog_id_, bot_user_id_, top_thread_message_id_,
                                         std::move(input_reply_to_), as_dialog_id_);
    promise_.set_value(td_api::make_object<td_api::webAppInfo>(ptr->query_id_, ptr->url_));
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "RequestWebViewQuery")) {
      if (from_attach_menu_) {
        td_->attach_menu_manager_->reload_attach_menu_bots(Promise<Unit>());
      }
    }
    promise_.set_error(std::move(status));
  }
};

class ProlongWebViewQuery final : public Td::ResultHandler {
  DialogId dialog_id_;

 public:
  void send(DialogId dialog_id, UserId bot_user_id, int64 query_id, MessageId top_thread_message_id,
            const MessageInputReplyTo &input_reply_to, bool silent, DialogId as_dialog_id) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    auto r_input_user = td_->user_manager_->get_input_user(bot_user_id);
    if (input_peer == nullptr || r_input_user.is_error()) {
      return;
    }

    int32 flags = 0;
    auto reply_to = input_reply_to.get_input_reply_to(td_, top_thread_message_id);
    if (reply_to != nullptr) {
      flags |= telegram_api::messages_prolongWebView::REPLY_TO_MASK;
    }
    if (silent) {
      flags |= telegram_api::messages_prolongWebView::SILENT_MASK;
    }

    tl_object_ptr<telegram_api::InputPeer> as_input_peer;
    if (as_dialog_id.is_valid()) {
      as_input_peer = td_->dialog_manager_->get_input_peer(as_dialog_id, AccessRights::Write);
      if (as_input_peer != nullptr) {
        flags |= telegram_api::messages_prolongWebView::SEND_AS_MASK;
      }
    }

    send_query(G()->net_query_creator().create(telegram_api::messages_prolongWebView(
        flags, false /*ignored*/, std::move(input_peer), r_input_user.move_as_ok(), query_id, std::move(reply_to),
        std::move(as_input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_prolongWebView>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool ptr = result_ptr.ok();
    if (!ptr) {
      LOG(ERROR) << "Failed to prolong a web view";
    }
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ProlongWebViewQuery");
  }
};

class InvokeWebViewCustomMethodQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::customRequestResult>> promise_;

 public:
  explicit InvokeWebViewCustomMethodQuery(Promise<td_api::object_ptr<td_api::customRequestResult>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(UserId bot_user_id, const string &method, const string &parameters) {
    auto r_input_user = td_->user_manager_->get_input_user(bot_user_id);
    if (r_input_user.is_error()) {
      return on_error(r_input_user.move_as_error());
    }
    send_query(G()->net_query_creator().create(telegram_api::bots_invokeWebViewCustomMethod(
        r_input_user.move_as_ok(), method, make_tl_object<telegram_api::dataJSON>(parameters))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_invokeWebViewCustomMethod>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    promise_.set_value(td_api::make_object<td_api::customRequestResult>(result->data_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class CheckDownloadFileParamsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit CheckDownloadFileParamsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::InputUser> &&input_user, const string &file_name,
            const string &url) {
    send_query(G()->net_query_creator().create(
        telegram_api::bots_checkDownloadFileParams(std::move(input_user), file_name, url)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_checkDownloadFileParams>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (!result_ptr.ok()) {
      return on_error(Status::Error(400, "The file can't be downloaded"));
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

WebAppManager::WebAppManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void WebAppManager::start_up() {
  class StateCallback final : public StateManager::Callback {
   public:
    explicit StateCallback(ActorId<WebAppManager> parent) : parent_(std::move(parent)) {
    }
    bool on_online(bool is_online) final {
      if (is_online) {
        send_closure(parent_, &WebAppManager::on_online, is_online);
      }
      return parent_.is_alive();
    }

   private:
    ActorId<WebAppManager> parent_;
  };
  send_closure(G()->state_manager(), &StateManager::add_callback, make_unique<StateCallback>(actor_id(this)));
}

void WebAppManager::tear_down() {
  parent_.reset();
}

void WebAppManager::on_online(bool is_online) {
  if (is_online) {
    ping_web_view();
  } else {
    ping_web_view_timeout_.cancel_timeout();
  }
}

void WebAppManager::ping_web_view_static(void *td_void) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(td_void != nullptr);
  auto td = static_cast<Td *>(td_void);

  td->web_app_manager_->ping_web_view();
}

void WebAppManager::ping_web_view() {
  if (G()->close_flag() || opened_web_views_.empty()) {
    return;
  }

  for (const auto &it : opened_web_views_) {
    const auto &opened_web_view = it.second;
    bool silent = td_->messages_manager_->get_dialog_silent_send_message(opened_web_view.dialog_id_);
    td_->create_handler<ProlongWebViewQuery>()->send(
        opened_web_view.dialog_id_, opened_web_view.bot_user_id_, it.first, opened_web_view.top_thread_message_id_,
        opened_web_view.input_reply_to_, silent, opened_web_view.as_dialog_id_);
  }

  schedule_ping_web_view();
}

void WebAppManager::schedule_ping_web_view() {
  ping_web_view_timeout_.set_callback(ping_web_view_static);
  ping_web_view_timeout_.set_callback_data(static_cast<void *>(td_));
  ping_web_view_timeout_.set_timeout_in(PING_WEB_VIEW_TIMEOUT);
}

void WebAppManager::get_popular_app_bots(const string &offset, int32 limit,
                                         Promise<td_api::object_ptr<td_api::foundUsers>> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Limit must be positive"));
  }
  td_->create_handler<GetPopularAppBotsQuery>(std::move(promise))->send(offset, limit);
}

void WebAppManager::get_web_app(UserId bot_user_id, const string &web_app_short_name,
                                Promise<td_api::object_ptr<td_api::foundWebApp>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(bot_user_id));
  TRY_RESULT_PROMISE(promise, bot_data, td_->user_manager_->get_bot_data(bot_user_id));
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), bot_user_id, web_app_short_name, promise = std::move(promise)](
                                 Result<telegram_api::object_ptr<telegram_api::messages_botApp>> result) mutable {
        send_closure(actor_id, &WebAppManager::on_get_web_app, bot_user_id, std::move(web_app_short_name),
                     std::move(result), std::move(promise));
      });
  td_->create_handler<GetBotAppQuery>(std::move(query_promise))->send(std::move(input_user), web_app_short_name);
}

void WebAppManager::on_get_web_app(UserId bot_user_id, string web_app_short_name,
                                   Result<telegram_api::object_ptr<telegram_api::messages_botApp>> result,
                                   Promise<td_api::object_ptr<td_api::foundWebApp>> promise) {
  G()->ignore_result_if_closing(result);
  if (result.is_error() && result.error().message() == "BOT_APP_INVALID") {
    return promise.set_value(nullptr);
  }
  TRY_RESULT_PROMISE(promise, bot_app, std::move(result));
  if (bot_app->app_->get_id() != telegram_api::botApp::ID) {
    CHECK(bot_app->app_->get_id() != telegram_api::botAppNotModified::ID);
    LOG(ERROR) << "Receive " << to_string(bot_app);
    return promise.set_error(Status::Error(500, "Receive invalid response"));
  }

  WebApp web_app(td_, telegram_api::move_object_as<telegram_api::botApp>(bot_app->app_), DialogId(bot_user_id));
  auto file_ids = web_app.get_file_ids(td_);
  if (!file_ids.empty()) {
    auto file_source_id = get_web_app_file_source_id(bot_user_id, web_app_short_name);
    for (auto file_id : file_ids) {
      td_->file_manager_->add_file_source(file_id, file_source_id, "on_get_web_app");
    }
  }
  promise.set_value(td_api::make_object<td_api::foundWebApp>(web_app.get_web_app_object(td_),
                                                             bot_app->request_write_access_, !bot_app->inactive_));
}

void WebAppManager::reload_web_app(UserId bot_user_id, const string &web_app_short_name, Promise<Unit> &&promise) {
  get_web_app(bot_user_id, web_app_short_name,
              PromiseCreator::lambda(
                  [promise = std::move(promise)](Result<td_api::object_ptr<td_api::foundWebApp>> result) mutable {
                    if (result.is_error()) {
                      promise.set_error(result.move_as_error());
                    } else {
                      promise.set_value(Unit());
                    }
                  }));
}

void WebAppManager::request_app_web_view(DialogId dialog_id, UserId bot_user_id, string &&web_app_short_name,
                                         string &&start_parameter, const WebAppOpenParameters &parameters,
                                         bool allow_write_access, Promise<string> &&promise) {
  if (!td_->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Read)) {
    dialog_id = DialogId(bot_user_id);
  }
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(bot_user_id));
  TRY_RESULT_PROMISE(promise, bot_data, td_->user_manager_->get_bot_data(bot_user_id));
  on_dialog_used(TopDialogCategory::BotApp, DialogId(bot_user_id), G()->unix_time());

  td_->create_handler<RequestAppWebViewQuery>(std::move(promise))
      ->send(dialog_id, std::move(input_user), web_app_short_name, start_parameter, parameters, allow_write_access);
}

void WebAppManager::request_main_web_view(DialogId dialog_id, UserId bot_user_id, string &&start_parameter,
                                          const WebAppOpenParameters &parameters,
                                          Promise<td_api::object_ptr<td_api::mainWebApp>> &&promise) {
  if (!td_->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Read)) {
    dialog_id = DialogId(bot_user_id);
  }
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(bot_user_id));
  TRY_RESULT_PROMISE(promise, bot_data, td_->user_manager_->get_bot_data(bot_user_id));
  if (!bot_data.has_main_app) {
    return promise.set_error(Status::Error(400, "The bot has no main Mini App"));
  }
  on_dialog_used(TopDialogCategory::BotApp, DialogId(bot_user_id), G()->unix_time());

  td_->create_handler<RequestMainWebViewQuery>(std::move(promise))
      ->send(dialog_id, std::move(input_user), start_parameter, parameters);
}

void WebAppManager::request_web_view(DialogId dialog_id, UserId bot_user_id, MessageId top_thread_message_id,
                                     td_api::object_ptr<td_api::InputMessageReplyTo> &&reply_to, string &&url,
                                     const WebAppOpenParameters &parameters,
                                     Promise<td_api::object_ptr<td_api::webAppInfo>> &&promise) {
  TRY_STATUS_PROMISE(promise, td_->user_manager_->get_bot_data(bot_user_id));
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(bot_user_id));
  TRY_RESULT_PROMISE(promise, bot_data, td_->user_manager_->get_bot_data(bot_user_id));
  TRY_STATUS_PROMISE(
      promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Write, "request_web_view"));
  on_dialog_used(TopDialogCategory::BotApp, DialogId(bot_user_id), G()->unix_time());

  if (!top_thread_message_id.is_valid() || !top_thread_message_id.is_server() ||
      dialog_id.get_type() != DialogType::Channel ||
      !td_->chat_manager_->is_megagroup_channel(dialog_id.get_channel_id())) {
    top_thread_message_id = MessageId();
  }
  auto input_reply_to = td_->messages_manager_->create_message_input_reply_to(dialog_id, top_thread_message_id,
                                                                              std::move(reply_to), false);

  bool silent = td_->messages_manager_->get_dialog_silent_send_message(dialog_id);
  DialogId as_dialog_id = td_->messages_manager_->get_dialog_default_send_message_as_dialog_id(dialog_id);

  td_->create_handler<RequestWebViewQuery>(std::move(promise))
      ->send(dialog_id, bot_user_id, std::move(input_user), std::move(url), parameters, top_thread_message_id,
             std::move(input_reply_to), silent, as_dialog_id);
}

void WebAppManager::open_web_view(int64 query_id, DialogId dialog_id, UserId bot_user_id,
                                  MessageId top_thread_message_id, MessageInputReplyTo &&input_reply_to,
                                  DialogId as_dialog_id) {
  if (query_id == 0) {
    LOG(ERROR) << "Receive Web App query identifier == 0";
    return;
  }

  if (opened_web_views_.empty()) {
    schedule_ping_web_view();
  }
  OpenedWebView opened_web_view;
  opened_web_view.dialog_id_ = dialog_id;
  opened_web_view.bot_user_id_ = bot_user_id;
  opened_web_view.top_thread_message_id_ = top_thread_message_id;
  opened_web_view.input_reply_to_ = std::move(input_reply_to);
  opened_web_view.as_dialog_id_ = as_dialog_id;
  opened_web_views_.emplace(query_id, std::move(opened_web_view));
}

void WebAppManager::close_web_view(int64 query_id, Promise<Unit> &&promise) {
  opened_web_views_.erase(query_id);
  if (opened_web_views_.empty()) {
    ping_web_view_timeout_.cancel_timeout();
  }
  promise.set_value(Unit());
}

void WebAppManager::invoke_web_view_custom_method(UserId bot_user_id, const string &method, const string &parameters,
                                                  Promise<td_api::object_ptr<td_api::customRequestResult>> &&promise) {
  td_->create_handler<InvokeWebViewCustomMethodQuery>(std::move(promise))->send(bot_user_id, method, parameters);
}

void WebAppManager::check_download_file_params(UserId bot_user_id, const string &file_name, const string &url,
                                               Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(bot_user_id));
  if (file_name.size() >= 256u || url.size() > 32768u || file_name.find('/') != string::npos ||
      file_name.find('\\') != string::npos) {
    return promise.set_error(Status::Error(400, "The file can't be downloaded"));
  }
  td_->create_handler<CheckDownloadFileParamsQuery>(std::move(promise))->send(std::move(input_user), file_name, url);
}

FileSourceId WebAppManager::get_web_app_file_source_id(UserId user_id, const string &short_name) {
  if (G()->close_flag()) {
    return FileSourceId();
  }
  if (!user_id.is_valid() || !td_->auth_manager_->is_authorized() || td_->auth_manager_->is_bot()) {
    return FileSourceId();
  }

  auto &source_id = web_app_file_source_ids_[user_id][short_name];
  if (!source_id.is_valid()) {
    source_id = td_->file_reference_manager_->create_web_app_file_source(user_id, short_name);
  }
  VLOG(file_references) << "Return " << source_id << " for Web App " << user_id << '/' << short_name;
  return source_id;
}

}  // namespace td
