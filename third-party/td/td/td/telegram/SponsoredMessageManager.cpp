//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SponsoredMessageManager.h"

#include "td/telegram/AccentColorId.h"
#include "td/telegram/AccessRights.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessageContent.h"
#include "td/telegram/MessageContentType.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageSelfDestructType.h"
#include "td/telegram/net/NetQueryCreator.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/PeerColor.h"
#include "td/telegram/Photo.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/ThemeManager.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"

namespace td {

class GetSponsoredMessagesQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::messages_SponsoredMessages>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetSponsoredMessagesQuery(
      Promise<telegram_api::object_ptr<telegram_api::messages_SponsoredMessages>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::messages_getSponsoredMessages(std::move(input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getSponsoredMessages>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetSponsoredMessagesQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetSponsoredMessagesQuery");
    promise_.set_error(std::move(status));
  }
};

class ViewSponsoredMessageQuery final : public Td::ResultHandler {
 public:
  void send(const string &message_id) {
    send_query(G()->net_query_creator().create(telegram_api::messages_viewSponsoredMessage(BufferSlice(message_id))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_viewSponsoredMessage>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }
  }

  void on_error(Status status) final {
  }
};

class ClickSponsoredMessageQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ClickSponsoredMessageQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &message_id, bool is_media_click, bool from_fullscreen) {
    int32 flags = 0;
    if (is_media_click) {
      flags |= telegram_api::messages_clickSponsoredMessage::MEDIA_MASK;
    }
    if (from_fullscreen) {
      flags |= telegram_api::messages_clickSponsoredMessage::FULLSCREEN_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_clickSponsoredMessage(
        flags, false /*ignored*/, false /*ignored*/, BufferSlice(message_id))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_clickSponsoredMessage>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ReportSponsoredMessageQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::ReportSponsoredResult>> promise_;

 public:
  explicit ReportSponsoredMessageQuery(Promise<td_api::object_ptr<td_api::ReportSponsoredResult>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &message_id, const string &option_id) {
    send_query(G()->net_query_creator().create(
        telegram_api::messages_reportSponsoredMessage(BufferSlice(message_id), BufferSlice(option_id))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_reportSponsoredMessage>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for ReportSponsoredMessageQuery: " << to_string(ptr);
    switch (ptr->get_id()) {
      case telegram_api::channels_sponsoredMessageReportResultReported::ID:
        return promise_.set_value(td_api::make_object<td_api::reportSponsoredResultOk>());
      case telegram_api::channels_sponsoredMessageReportResultAdsHidden::ID:
        return promise_.set_value(td_api::make_object<td_api::reportSponsoredResultAdsHidden>());
      case telegram_api::channels_sponsoredMessageReportResultChooseOption::ID: {
        auto options =
            telegram_api::move_object_as<telegram_api::channels_sponsoredMessageReportResultChooseOption>(ptr);
        if (options->options_.empty()) {
          return promise_.set_value(td_api::make_object<td_api::reportSponsoredResultFailed>());
        }
        vector<td_api::object_ptr<td_api::reportOption>> report_options;
        for (auto &option : options->options_) {
          report_options.push_back(
              td_api::make_object<td_api::reportOption>(option->option_.as_slice().str(), option->text_));
        }
        return promise_.set_value(td_api::make_object<td_api::reportSponsoredResultOptionRequired>(
            options->title_, std::move(report_options)));
      }
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    if (status.message() == "AD_EXPIRED") {
      return promise_.set_value(td_api::make_object<td_api::reportSponsoredResultFailed>());
    }
    if (status.message() == "PREMIUM_ACCOUNT_REQUIRED") {
      return promise_.set_value(td_api::make_object<td_api::reportSponsoredResultPremiumRequired>());
    }
    promise_.set_error(std::move(status));
  }
};

class GetSponsoredPeersQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::contacts_SponsoredPeers>> promise_;

 public:
  explicit GetSponsoredPeersQuery(Promise<telegram_api::object_ptr<telegram_api::contacts_SponsoredPeers>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &query) {
    send_query(G()->net_query_creator().create(telegram_api::contacts_getSponsoredPeers(query)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_getSponsoredPeers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetSponsoredPeersQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

struct SponsoredMessageManager::SponsoredContentInfo {
  string random_id_;
  bool is_viewed_ = false;
  bool is_clicked_ = false;
};

struct SponsoredMessageManager::SponsoredMessage {
  int64 local_id = 0;
  bool is_recommended = false;
  bool can_be_reported = false;
  unique_ptr<MessageContent> content;
  string url;
  Photo photo;
  string title;
  string button_text;
  PeerColor peer_color;
  string sponsor_info;
  string additional_info;

  SponsoredMessage(int64 local_id, bool is_recommended, bool can_be_reported, unique_ptr<MessageContent> content,
                   string url, Photo photo, string title, string button_text, PeerColor peer_color, string sponsor_info,
                   string additional_info)
      : local_id(local_id)
      , is_recommended(is_recommended)
      , can_be_reported(can_be_reported)
      , content(std::move(content))
      , url(std::move(url))
      , photo(std::move(photo))
      , title(std::move(title))
      , button_text(std::move(button_text))
      , peer_color(std::move(peer_color))
      , sponsor_info(std::move(sponsor_info))
      , additional_info(std::move(additional_info)) {
  }
};

struct SponsoredMessageManager::DialogSponsoredMessages {
  vector<Promise<td_api::object_ptr<td_api::sponsoredMessages>>> promises;
  vector<SponsoredMessage> messages;
  FlatHashMap<int64, SponsoredContentInfo> message_infos;
  int32 messages_between = 0;
  bool is_premium = false;
  bool sponsored_enabled = false;
};

struct SponsoredMessageManager::SponsoredDialog {
  int64 local_id = 0;
  DialogId dialog_id;
  string sponsor_info;
  string additional_info;

  SponsoredDialog(int64 local_id, DialogId dialog_id, string &&sponsor_info, string &&additional_info)
      : local_id(local_id)
      , dialog_id(dialog_id)
      , sponsor_info(std::move(sponsor_info))
      , additional_info(std::move(additional_info)) {
  }
};

struct SponsoredMessageManager::SponsoredDialogs {
  int64 local_id = 0;
  vector<Promise<td_api::object_ptr<td_api::sponsoredChats>>> promises;
  vector<SponsoredDialog> dialogs;
  bool is_premium = false;
  bool sponsored_enabled = false;
};

SponsoredMessageManager::SponsoredMessageManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  delete_cached_sponsored_messages_timeout_.set_callback(on_delete_cached_sponsored_messages_timeout_callback);
  delete_cached_sponsored_messages_timeout_.set_callback_data(static_cast<void *>(this));

  delete_cached_sponsored_dialogs_timeout_.set_callback(on_delete_cached_sponsored_dialogs_timeout_callback);
  delete_cached_sponsored_dialogs_timeout_.set_callback_data(static_cast<void *>(this));
}

SponsoredMessageManager::~SponsoredMessageManager() = default;

void SponsoredMessageManager::tear_down() {
  parent_.reset();
}

void SponsoredMessageManager::on_delete_cached_sponsored_messages_timeout_callback(void *sponsored_message_manager_ptr,
                                                                                   int64 dialog_id_int) {
  if (G()->close_flag()) {
    return;
  }

  auto sponsored_message_manager = static_cast<SponsoredMessageManager *>(sponsored_message_manager_ptr);
  send_closure_later(sponsored_message_manager->actor_id(sponsored_message_manager),
                     &SponsoredMessageManager::delete_cached_sponsored_messages, DialogId(dialog_id_int));
}

void SponsoredMessageManager::delete_cached_sponsored_messages(DialogId dialog_id) {
  if (G()->close_flag()) {
    return;
  }

  auto it = dialog_sponsored_messages_.find(dialog_id);
  if (it != dialog_sponsored_messages_.end() && it->second->promises.empty()) {
    dialog_sponsored_messages_.erase(it);
  }
}

void SponsoredMessageManager::on_delete_cached_sponsored_dialogs_timeout_callback(void *sponsored_message_manager_ptr,
                                                                                  int64 local_id) {
  if (G()->close_flag()) {
    return;
  }

  auto sponsored_message_manager = static_cast<SponsoredMessageManager *>(sponsored_message_manager_ptr);
  send_closure_later(sponsored_message_manager->actor_id(sponsored_message_manager),
                     &SponsoredMessageManager::delete_cached_sponsored_dialogs, local_id);
}

void SponsoredMessageManager::delete_cached_sponsored_dialogs(int64 local_id) {
  if (G()->close_flag()) {
    return;
  }

  auto query_it = local_id_to_search_query_.find(local_id);
  if (query_it == local_id_to_search_query_.end()) {
    return;
  }

  auto it = search_sponsored_dialogs_.find(query_it->second);
  CHECK(it != search_sponsored_dialogs_.end());
  if (it->second->promises.empty()) {
    for (auto &dialog : it->second->dialogs) {
      dialog_infos_.erase(dialog.local_id);
    }
    search_sponsored_dialogs_.erase(it);
    local_id_to_search_query_.erase(query_it);
  }
}

td_api::object_ptr<td_api::messageSponsor> SponsoredMessageManager::get_message_sponsor_object(
    const SponsoredMessage &sponsored_message) const {
  return td_api::make_object<td_api::messageSponsor>(
      sponsored_message.url, get_photo_object(td_->file_manager_.get(), sponsored_message.photo),
      sponsored_message.sponsor_info);
}

td_api::object_ptr<td_api::sponsoredMessage> SponsoredMessageManager::get_sponsored_message_object(
    DialogId dialog_id, const SponsoredMessage &sponsored_message) const {
  auto sponsor = get_message_sponsor_object(sponsored_message);
  if (sponsor == nullptr) {
    return nullptr;
  }
  return td_api::make_object<td_api::sponsoredMessage>(
      sponsored_message.local_id, sponsored_message.is_recommended, sponsored_message.can_be_reported,
      get_message_content_object(sponsored_message.content.get(), td_, dialog_id, MessageId(ServerMessageId(1)), false,
                                 dialog_id, 0, false, true, -1, false, true),
      std::move(sponsor), sponsored_message.title, sponsored_message.button_text,
      td_->theme_manager_->get_accent_color_id_object(sponsored_message.peer_color.accent_color_id_, AccentColorId()),
      sponsored_message.peer_color.background_custom_emoji_id_.get(), sponsored_message.additional_info);
}

td_api::object_ptr<td_api::sponsoredMessages> SponsoredMessageManager::get_sponsored_messages_object(
    DialogId dialog_id, const DialogSponsoredMessages &sponsored_messages) const {
  auto messages = transform(sponsored_messages.messages, [this, dialog_id](const SponsoredMessage &message) {
    return get_sponsored_message_object(dialog_id, message);
  });
  td::remove_if(messages, [](const auto &message) { return message == nullptr; });
  return td_api::make_object<td_api::sponsoredMessages>(std::move(messages), sponsored_messages.messages_between);
}

td_api::object_ptr<td_api::sponsoredChat> SponsoredMessageManager::get_sponsored_chat_object(
    const SponsoredDialog &sponsored_dialog) const {
  return td_api::make_object<td_api::sponsoredChat>(
      sponsored_dialog.local_id, td_->dialog_manager_->get_chat_id_object(sponsored_dialog.dialog_id, "sponsoredChat"),
      sponsored_dialog.sponsor_info, sponsored_dialog.additional_info);
}

td_api::object_ptr<td_api::sponsoredChats> SponsoredMessageManager::get_sponsored_chats_object(
    const SponsoredDialogs &sponsored_dialogs) const {
  return td_api::make_object<td_api::sponsoredChats>(transform(
      sponsored_dialogs.dialogs, [this](const SponsoredDialog &dialog) { return get_sponsored_chat_object(dialog); }));
}

void SponsoredMessageManager::get_dialog_sponsored_messages(
    DialogId dialog_id, Promise<td_api::object_ptr<td_api::sponsoredMessages>> &&promise) {
  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read,
                                                                        "get_dialog_sponsored_messages"));

  auto &messages = dialog_sponsored_messages_[dialog_id];
  if (messages != nullptr && messages->promises.empty()) {
    if (messages->is_premium == td_->option_manager_->get_option_boolean("is_premium", false) &&
        messages->sponsored_enabled == td_->user_manager_->get_my_sponsored_enabled()) {
      // use cached value
      return promise.set_value(get_sponsored_messages_object(dialog_id, *messages));
    } else {
      // drop cache
      messages = nullptr;
      delete_cached_sponsored_messages_timeout_.cancel_timeout(dialog_id.get());
    }
  }

  if (messages == nullptr) {
    messages = make_unique<DialogSponsoredMessages>();
  }
  messages->promises.push_back(std::move(promise));
  if (messages->promises.size() == 1) {
    auto query_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this),
         dialog_id](Result<telegram_api::object_ptr<telegram_api::messages_SponsoredMessages>> &&result) {
          send_closure(actor_id, &SponsoredMessageManager::on_get_dialog_sponsored_messages, dialog_id,
                       std::move(result));
        });
    td_->create_handler<GetSponsoredMessagesQuery>(std::move(query_promise))->send(dialog_id);
  }
}

void SponsoredMessageManager::on_get_dialog_sponsored_messages(
    DialogId dialog_id, Result<telegram_api::object_ptr<telegram_api::messages_SponsoredMessages>> &&result) {
  G()->ignore_result_if_closing(result);

  auto &messages = dialog_sponsored_messages_[dialog_id];
  CHECK(messages != nullptr);
  auto promises = std::move(messages->promises);
  reset_to_empty(messages->promises);
  CHECK(messages->messages.empty());
  CHECK(messages->message_infos.empty());

  if (result.is_error()) {
    dialog_sponsored_messages_.erase(dialog_id);
    fail_promises(promises, result.move_as_error());
    return;
  }

  auto sponsored_messages_ptr = result.move_as_ok();
  switch (sponsored_messages_ptr->get_id()) {
    case telegram_api::messages_sponsoredMessages::ID: {
      auto sponsored_messages =
          telegram_api::move_object_as<telegram_api::messages_sponsoredMessages>(sponsored_messages_ptr);

      td_->user_manager_->on_get_users(std::move(sponsored_messages->users_), "on_get_dialog_sponsored_messages");
      td_->chat_manager_->on_get_chats(std::move(sponsored_messages->chats_), "on_get_dialog_sponsored_messages");

      for (auto &sponsored_message : sponsored_messages->messages_) {
        Photo photo = get_photo(td_, std::move(sponsored_message->photo_), DialogId());
        auto message_text = get_message_text(td_->user_manager_.get(), std::move(sponsored_message->message_),
                                             std::move(sponsored_message->entities_), true, true, 0, false,
                                             "on_get_dialog_sponsored_messages");
        MessageSelfDestructType ttl;
        auto content =
            get_message_content(td_, std::move(message_text), std::move(sponsored_message->media_), DialogId(),
                                G()->unix_time(), true, UserId(), &ttl, nullptr, "on_get_dialog_sponsored_messages");
        if (!ttl.is_empty()) {
          LOG(ERROR) << "Receive sponsored message with " << ttl;
          continue;
        }
        bool is_allowed_content_type = [&] {
          switch (content->get_type()) {
            case MessageContentType::Animation:
            case MessageContentType::Photo:
            case MessageContentType::Text:
            case MessageContentType::Video:
              return true;
            default:
              return false;
          }
        }();
        if (!is_allowed_content_type) {
          LOG(ERROR) << "Receive sponsored message with " << content->get_type();
          continue;
        }

        current_sponsored_message_id_ = current_sponsored_message_id_.get_next_message_id(MessageType::Local);
        if (!current_sponsored_message_id_.is_valid_sponsored()) {
          LOG(ERROR) << "Sponsored message identifier overflowed";
          current_sponsored_message_id_ = MessageId::max().get_next_message_id(MessageType::Local);
          CHECK(current_sponsored_message_id_.is_valid_sponsored());
        }
        auto local_id = current_sponsored_message_id_.get();
        CHECK(!current_sponsored_message_id_.is_valid());
        CHECK(!current_sponsored_message_id_.is_scheduled());
        SponsoredContentInfo message_info;
        message_info.random_id_ = sponsored_message->random_id_.as_slice().str();
        auto is_inserted = messages->message_infos.emplace(local_id, std::move(message_info)).second;
        CHECK(is_inserted);
        messages->messages.emplace_back(
            local_id, sponsored_message->recommended_, sponsored_message->can_report_, std::move(content),
            std::move(sponsored_message->url_), std::move(photo), std::move(sponsored_message->title_),
            std::move(sponsored_message->button_text_), PeerColor(sponsored_message->color_),
            std::move(sponsored_message->sponsor_info_), std::move(sponsored_message->additional_info_));
      }
      messages->messages_between = sponsored_messages->posts_between_;
      break;
    }
    case telegram_api::messages_sponsoredMessagesEmpty::ID:
      break;
    default:
      UNREACHABLE();
  }
  messages->is_premium = td_->option_manager_->get_option_boolean("is_premium", false);
  messages->sponsored_enabled = td_->user_manager_->get_my_sponsored_enabled();

  for (auto &promise : promises) {
    promise.set_value(get_sponsored_messages_object(dialog_id, *messages));
  }
  delete_cached_sponsored_messages_timeout_.set_timeout_in(dialog_id.get(), 300.0);
}

void SponsoredMessageManager::view_sponsored_message(DialogId dialog_id, MessageId sponsored_message_id) {
  auto it = dialog_sponsored_messages_.find(dialog_id);
  if (it == dialog_sponsored_messages_.end()) {
    return;
  }
  auto random_id_it = it->second->message_infos.find(sponsored_message_id.get());
  if (random_id_it == it->second->message_infos.end() || random_id_it->second.is_viewed_) {
    return;
  }

  random_id_it->second.is_viewed_ = true;
  td_->create_handler<ViewSponsoredMessageQuery>()->send(random_id_it->second.random_id_);
}

void SponsoredMessageManager::click_sponsored_message(DialogId dialog_id, MessageId sponsored_message_id,
                                                      bool is_media_click, bool from_fullscreen,
                                                      Promise<Unit> &&promise) {
  if (!dialog_id.is_valid() || !sponsored_message_id.is_valid_sponsored()) {
    return promise.set_error(Status::Error(400, "Invalid message specified"));
  }
  auto it = dialog_sponsored_messages_.find(dialog_id);
  if (it == dialog_sponsored_messages_.end()) {
    return promise.set_value(Unit());
  }
  auto random_id_it = it->second->message_infos.find(sponsored_message_id.get());
  if (random_id_it == it->second->message_infos.end() || random_id_it->second.is_clicked_) {
    return promise.set_value(Unit());
  }

  random_id_it->second.is_clicked_ = true;
  td_->create_handler<ClickSponsoredMessageQuery>(std::move(promise))
      ->send(random_id_it->second.random_id_, is_media_click, from_fullscreen);
}

void SponsoredMessageManager::report_sponsored_message(
    DialogId dialog_id, MessageId sponsored_message_id, const string &option_id,
    Promise<td_api::object_ptr<td_api::ReportSponsoredResult>> &&promise) {
  if (!dialog_id.is_valid() || !sponsored_message_id.is_valid_sponsored()) {
    return promise.set_error(Status::Error(400, "Invalid message specified"));
  }
  auto it = dialog_sponsored_messages_.find(dialog_id);
  if (it == dialog_sponsored_messages_.end()) {
    return promise.set_value(td_api::make_object<td_api::reportSponsoredResultFailed>());
  }
  auto random_id_it = it->second->message_infos.find(sponsored_message_id.get());
  if (random_id_it == it->second->message_infos.end()) {
    return promise.set_value(td_api::make_object<td_api::reportSponsoredResultFailed>());
  }

  td_->create_handler<ReportSponsoredMessageQuery>(std::move(promise))
      ->send(random_id_it->second.random_id_, option_id);
}

void SponsoredMessageManager::get_search_sponsored_dialogs(
    const string &query, Promise<td_api::object_ptr<td_api::sponsoredChats>> &&promise) {
  if (query.size() < 4u) {
    return promise.set_value(td_api::make_object<td_api::sponsoredChats>());
  }
  auto &dialogs = search_sponsored_dialogs_[query];
  if (dialogs != nullptr && dialogs->promises.empty()) {
    if (dialogs->is_premium == td_->option_manager_->get_option_boolean("is_premium", false) &&
        dialogs->sponsored_enabled == td_->user_manager_->get_my_sponsored_enabled()) {
      // use cached value
      return promise.set_value(get_sponsored_chats_object(*dialogs));
    } else {
      // drop cache
      delete_cached_sponsored_dialogs_timeout_.cancel_timeout(dialogs->local_id);
      local_id_to_search_query_.erase(dialogs->local_id);
      for (auto &dialog : dialogs->dialogs) {
        dialog_infos_.erase(dialog.local_id);
      }
      dialogs = nullptr;
    }
  }

  if (dialogs == nullptr) {
    dialogs = make_unique<SponsoredDialogs>();
    dialogs->local_id = ++current_local_id_;
    local_id_to_search_query_[dialogs->local_id] = query;
  }
  dialogs->promises.push_back(std::move(promise));
  if (dialogs->promises.size() == 1) {
    auto query_promise =
        PromiseCreator::lambda([actor_id = actor_id(this), query](
                                   Result<telegram_api::object_ptr<telegram_api::contacts_SponsoredPeers>> &&result) {
          send_closure(actor_id, &SponsoredMessageManager::on_get_search_sponsored_dialogs, query, std::move(result));
        });
    td_->create_handler<GetSponsoredPeersQuery>(std::move(query_promise))->send(query);
  }
}

void SponsoredMessageManager::on_get_search_sponsored_dialogs(
    const string &query, Result<telegram_api::object_ptr<telegram_api::contacts_SponsoredPeers>> &&result) {
  G()->ignore_result_if_closing(result);

  auto &dialogs = search_sponsored_dialogs_[query];
  CHECK(dialogs != nullptr);
  auto promises = std::move(dialogs->promises);
  reset_to_empty(dialogs->promises);
  CHECK(dialogs->dialogs.empty());

  auto local_id = dialogs->local_id;
  if (result.is_error()) {
    search_sponsored_dialogs_.erase(query);
    local_id_to_search_query_.erase(local_id);
    fail_promises(promises, result.move_as_error());
    return;
  }

  auto sponsored_dialogs_ptr = result.move_as_ok();
  switch (sponsored_dialogs_ptr->get_id()) {
    case telegram_api::contacts_sponsoredPeers::ID: {
      auto sponsored_dialogs =
          telegram_api::move_object_as<telegram_api::contacts_sponsoredPeers>(sponsored_dialogs_ptr);

      td_->user_manager_->on_get_users(std::move(sponsored_dialogs->users_), "on_get_search_sponsored_dialogs");
      td_->chat_manager_->on_get_chats(std::move(sponsored_dialogs->chats_), "on_get_search_sponsored_dialogs");

      for (auto &sponsored_dialog : sponsored_dialogs->peers_) {
        auto dialog_id = DialogId(sponsored_dialog->peer_);
        if (!dialog_id.is_valid() || !td_->dialog_manager_->have_dialog_info(dialog_id)) {
          LOG(ERROR) << "Receive unknown " << dialog_id;
          continue;
        }
        td_->dialog_manager_->force_create_dialog(dialog_id, "on_get_search_sponsored_dialogs");

        auto dialog_local_id = ++current_local_id_;

        auto dialog_info = make_unique<SponsoredContentInfo>();
        dialog_info->random_id_ = sponsored_dialog->random_id_.as_slice().str();
        auto is_inserted = dialog_infos_.emplace(dialog_local_id, std::move(dialog_info)).second;
        CHECK(is_inserted);

        dialogs->dialogs.emplace_back(dialog_local_id, dialog_id, std::move(sponsored_dialog->sponsor_info_),
                                      std::move(sponsored_dialog->additional_info_));
      }
      break;
    }
    case telegram_api::contacts_sponsoredPeersEmpty::ID:
      break;
    default:
      UNREACHABLE();
  }
  dialogs->is_premium = td_->option_manager_->get_option_boolean("is_premium", false);
  dialogs->sponsored_enabled = td_->user_manager_->get_my_sponsored_enabled();

  for (auto &promise : promises) {
    promise.set_value(get_sponsored_chats_object(*dialogs));
  }
  delete_cached_sponsored_dialogs_timeout_.set_timeout_in(local_id, 300.0);
}

void SponsoredMessageManager::view_sponsored_dialog(int64 local_id, Promise<Unit> &&promise) {
  promise.set_value(Unit());

  auto it = dialog_infos_.find(local_id);
  if (it == dialog_infos_.end() || it->second->is_viewed_) {
    return;
  }

  it->second->is_viewed_ = true;
  td_->create_handler<ViewSponsoredMessageQuery>()->send(it->second->random_id_);
}

void SponsoredMessageManager::open_sponsored_dialog(int64 local_id, Promise<Unit> &&promise) {
  auto it = dialog_infos_.find(local_id);
  if (it == dialog_infos_.end() || it->second->is_clicked_) {
    return promise.set_value(Unit());
  }

  it->second->is_clicked_ = true;
  td_->create_handler<ClickSponsoredMessageQuery>(std::move(promise))->send(it->second->random_id_, false, false);
}

void SponsoredMessageManager::report_sponsored_dialog(
    int64 local_id, const string &option_id, Promise<td_api::object_ptr<td_api::ReportSponsoredResult>> &&promise) {
  auto it = dialog_infos_.find(local_id);
  if (it == dialog_infos_.end()) {
    return promise.set_value(td_api::make_object<td_api::reportSponsoredResultFailed>());
  }

  td_->create_handler<ReportSponsoredMessageQuery>(std::move(promise))->send(it->second->random_id_, option_id);
}

}  // namespace td
