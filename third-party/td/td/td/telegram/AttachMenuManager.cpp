//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/AttachMenuManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/Document.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileId.hpp"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

class GetAttachMenuBotsQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::AttachMenuBots>> promise_;

 public:
  explicit GetAttachMenuBotsQuery(Promise<telegram_api::object_ptr<telegram_api::AttachMenuBots>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(int64 hash) {
    send_query(G()->net_query_creator().create(telegram_api::messages_getAttachMenuBots(hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getAttachMenuBots>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetAttachMenuBotsQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetAttachMenuBotQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::attachMenuBotsBot>> promise_;

 public:
  explicit GetAttachMenuBotQuery(Promise<telegram_api::object_ptr<telegram_api::attachMenuBotsBot>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(tl_object_ptr<telegram_api::InputUser> &&input_user) {
    send_query(G()->net_query_creator().create(telegram_api::messages_getAttachMenuBot(std::move(input_user))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getAttachMenuBot>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetAttachMenuBotQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ToggleBotInAttachMenuQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ToggleBotInAttachMenuQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(tl_object_ptr<telegram_api::InputUser> &&input_user, bool is_added, bool allow_write_access) {
    int32 flags = 0;
    if (is_added && allow_write_access) {
      flags |= telegram_api::messages_toggleBotInAttachMenu::WRITE_ALLOWED_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_toggleBotInAttachMenu(flags, false /*ignored*/, std::move(input_user), is_added)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_toggleBotInAttachMenu>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    if (!result) {
      LOG(ERROR) << "Failed to add a bot to attachment menu";
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->attach_menu_manager_->reload_attach_menu_bots(Promise<Unit>());
    promise_.set_error(std::move(status));
  }
};

bool operator==(const AttachMenuManager::AttachMenuBotColor &lhs, const AttachMenuManager::AttachMenuBotColor &rhs) {
  return lhs.light_color_ == rhs.light_color_ && lhs.dark_color_ == rhs.dark_color_;
}

bool operator!=(const AttachMenuManager::AttachMenuBotColor &lhs, const AttachMenuManager::AttachMenuBotColor &rhs) {
  return !(lhs == rhs);
}

template <class StorerT>
void AttachMenuManager::AttachMenuBotColor::store(StorerT &storer) const {
  td::store(light_color_, storer);
  td::store(dark_color_, storer);
}

template <class ParserT>
void AttachMenuManager::AttachMenuBotColor::parse(ParserT &parser) {
  td::parse(light_color_, parser);
  td::parse(dark_color_, parser);
}

bool operator==(const AttachMenuManager::AttachMenuBot &lhs, const AttachMenuManager::AttachMenuBot &rhs) {
  return lhs.user_id_ == rhs.user_id_ && lhs.supports_self_dialog_ == rhs.supports_self_dialog_ &&
         lhs.supports_user_dialogs_ == rhs.supports_user_dialogs_ &&
         lhs.supports_bot_dialogs_ == rhs.supports_bot_dialogs_ &&
         lhs.supports_group_dialogs_ == rhs.supports_group_dialogs_ &&
         lhs.supports_broadcast_dialogs_ == rhs.supports_broadcast_dialogs_ &&
         lhs.request_write_access_ == rhs.request_write_access_ &&
         lhs.show_in_attach_menu_ == rhs.show_in_attach_menu_ && lhs.show_in_side_menu_ == rhs.show_in_side_menu_ &&
         lhs.side_menu_disclaimer_needed_ == rhs.side_menu_disclaimer_needed_ && lhs.name_ == rhs.name_ &&
         lhs.default_icon_file_id_ == rhs.default_icon_file_id_ &&
         lhs.ios_static_icon_file_id_ == rhs.ios_static_icon_file_id_ &&
         lhs.ios_animated_icon_file_id_ == rhs.ios_animated_icon_file_id_ &&
         lhs.android_icon_file_id_ == rhs.android_icon_file_id_ && lhs.macos_icon_file_id_ == rhs.macos_icon_file_id_ &&
         lhs.android_side_menu_icon_file_id_ == rhs.android_side_menu_icon_file_id_ &&
         lhs.ios_side_menu_icon_file_id_ == rhs.ios_side_menu_icon_file_id_ &&
         lhs.macos_side_menu_icon_file_id_ == rhs.macos_side_menu_icon_file_id_ && lhs.is_added_ == rhs.is_added_ &&
         lhs.name_color_ == rhs.name_color_ && lhs.icon_color_ == rhs.icon_color_ &&
         lhs.placeholder_file_id_ == rhs.placeholder_file_id_;
}

bool operator!=(const AttachMenuManager::AttachMenuBot &lhs, const AttachMenuManager::AttachMenuBot &rhs) {
  return !(lhs == rhs);
}

template <class StorerT>
void AttachMenuManager::AttachMenuBot::store(StorerT &storer) const {
  bool has_ios_static_icon_file_id = ios_static_icon_file_id_.is_valid();
  bool has_ios_animated_icon_file_id = ios_animated_icon_file_id_.is_valid();
  bool has_android_icon_file_id = android_icon_file_id_.is_valid();
  bool has_macos_icon_file_id = macos_icon_file_id_.is_valid();
  bool has_name_color = name_color_ != AttachMenuBotColor();
  bool has_icon_color = icon_color_ != AttachMenuBotColor();
  bool has_support_flags = true;
  bool has_placeholder_file_id = placeholder_file_id_.is_valid();
  bool has_cache_version = cache_version_ != 0;
  bool has_android_side_menu_icon_file_id = android_side_menu_icon_file_id_.is_valid();
  bool has_ios_side_menu_icon_file_id = ios_side_menu_icon_file_id_.is_valid();
  bool has_macos_side_menu_icon_file_id = macos_side_menu_icon_file_id_.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_ios_static_icon_file_id);
  STORE_FLAG(has_ios_animated_icon_file_id);
  STORE_FLAG(has_android_icon_file_id);
  STORE_FLAG(has_macos_icon_file_id);
  STORE_FLAG(is_added_);
  STORE_FLAG(has_name_color);
  STORE_FLAG(has_icon_color);
  STORE_FLAG(has_support_flags);
  STORE_FLAG(supports_self_dialog_);
  STORE_FLAG(supports_user_dialogs_);
  STORE_FLAG(supports_bot_dialogs_);
  STORE_FLAG(supports_group_dialogs_);
  STORE_FLAG(supports_broadcast_dialogs_);
  STORE_FLAG(false);
  STORE_FLAG(has_placeholder_file_id);
  STORE_FLAG(has_cache_version);
  STORE_FLAG(request_write_access_);
  STORE_FLAG(show_in_attach_menu_);
  STORE_FLAG(show_in_side_menu_);
  STORE_FLAG(side_menu_disclaimer_needed_);
  STORE_FLAG(has_android_side_menu_icon_file_id);
  STORE_FLAG(has_ios_side_menu_icon_file_id);
  STORE_FLAG(has_macos_side_menu_icon_file_id);
  END_STORE_FLAGS();
  td::store(user_id_, storer);
  td::store(name_, storer);
  td::store(default_icon_file_id_, storer);
  if (has_ios_static_icon_file_id) {
    td::store(ios_static_icon_file_id_, storer);
  }
  if (has_ios_animated_icon_file_id) {
    td::store(ios_animated_icon_file_id_, storer);
  }
  if (has_android_icon_file_id) {
    td::store(android_icon_file_id_, storer);
  }
  if (has_macos_icon_file_id) {
    td::store(macos_icon_file_id_, storer);
  }
  if (has_name_color) {
    td::store(name_color_, storer);
  }
  if (has_icon_color) {
    td::store(icon_color_, storer);
  }
  if (has_placeholder_file_id) {
    td::store(placeholder_file_id_, storer);
  }
  if (has_cache_version) {
    td::store(cache_version_, storer);
  }
  if (has_android_side_menu_icon_file_id) {
    td::store(android_side_menu_icon_file_id_, storer);
  }
  if (has_ios_side_menu_icon_file_id) {
    td::store(ios_side_menu_icon_file_id_, storer);
  }
  if (has_macos_side_menu_icon_file_id) {
    td::store(macos_side_menu_icon_file_id_, storer);
  }
}

template <class ParserT>
void AttachMenuManager::AttachMenuBot::parse(ParserT &parser) {
  bool has_ios_static_icon_file_id;
  bool has_ios_animated_icon_file_id;
  bool has_android_icon_file_id;
  bool has_macos_icon_file_id;
  bool has_name_color;
  bool has_icon_color;
  bool has_support_flags;
  bool has_placeholder_file_id;
  bool has_cache_version;
  bool has_android_side_menu_icon_file_id;
  bool has_ios_side_menu_icon_file_id;
  bool has_macos_side_menu_icon_file_id;
  bool legacy_supports_settings;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_ios_static_icon_file_id);
  PARSE_FLAG(has_ios_animated_icon_file_id);
  PARSE_FLAG(has_android_icon_file_id);
  PARSE_FLAG(has_macos_icon_file_id);
  PARSE_FLAG(is_added_);
  PARSE_FLAG(has_name_color);
  PARSE_FLAG(has_icon_color);
  PARSE_FLAG(has_support_flags);
  PARSE_FLAG(supports_self_dialog_);
  PARSE_FLAG(supports_user_dialogs_);
  PARSE_FLAG(supports_bot_dialogs_);
  PARSE_FLAG(supports_group_dialogs_);
  PARSE_FLAG(supports_broadcast_dialogs_);
  PARSE_FLAG(legacy_supports_settings);
  PARSE_FLAG(has_placeholder_file_id);
  PARSE_FLAG(has_cache_version);
  PARSE_FLAG(request_write_access_);
  PARSE_FLAG(show_in_attach_menu_);
  PARSE_FLAG(show_in_side_menu_);
  PARSE_FLAG(side_menu_disclaimer_needed_);
  PARSE_FLAG(has_android_side_menu_icon_file_id);
  PARSE_FLAG(has_ios_side_menu_icon_file_id);
  PARSE_FLAG(has_macos_side_menu_icon_file_id);
  END_PARSE_FLAGS();
  td::parse(user_id_, parser);
  td::parse(name_, parser);
  td::parse(default_icon_file_id_, parser);
  if (has_ios_static_icon_file_id) {
    td::parse(ios_static_icon_file_id_, parser);
  }
  if (has_ios_animated_icon_file_id) {
    td::parse(ios_animated_icon_file_id_, parser);
  }
  if (has_android_icon_file_id) {
    td::parse(android_icon_file_id_, parser);
  }
  if (has_macos_icon_file_id) {
    td::parse(macos_icon_file_id_, parser);
  }
  if (has_name_color) {
    td::parse(name_color_, parser);
  }
  if (has_icon_color) {
    td::parse(icon_color_, parser);
  }
  if (has_placeholder_file_id) {
    td::parse(placeholder_file_id_, parser);
  }
  if (has_cache_version) {
    td::parse(cache_version_, parser);
  }
  if (has_android_side_menu_icon_file_id) {
    td::parse(android_side_menu_icon_file_id_, parser);
  }
  if (has_ios_side_menu_icon_file_id) {
    td::parse(ios_side_menu_icon_file_id_, parser);
  }
  if (has_macos_side_menu_icon_file_id) {
    td::parse(macos_side_menu_icon_file_id_, parser);
  }

  if (!has_support_flags) {
    supports_self_dialog_ = true;
    supports_user_dialogs_ = true;
    supports_bot_dialogs_ = true;
  }
  if (is_added_ && !show_in_attach_menu_ && !show_in_side_menu_ && !has_android_side_menu_icon_file_id &&
      !has_ios_side_menu_icon_file_id && !has_macos_side_menu_icon_file_id) {
    show_in_attach_menu_ = true;
  }
}

class AttachMenuManager::AttachMenuBotsLogEvent {
 public:
  int64 hash_ = 0;
  vector<AttachMenuBot> attach_menu_bots_;

  AttachMenuBotsLogEvent() = default;

  AttachMenuBotsLogEvent(int64 hash, vector<AttachMenuBot> attach_menu_bots)
      : hash_(hash), attach_menu_bots_(std::move(attach_menu_bots)) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(hash_, storer);
    td::store(attach_menu_bots_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(hash_, parser);
    td::parse(attach_menu_bots_, parser);
  }
};

AttachMenuManager::AttachMenuManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void AttachMenuManager::tear_down() {
  parent_.reset();
}

void AttachMenuManager::start_up() {
  init();
}

void AttachMenuManager::init() {
  if (!is_active()) {
    return;
  }
  if (is_inited_) {
    return;
  }
  is_inited_ = true;

  if (!G()->use_chat_info_database()) {
    G()->td_db()->get_binlog_pmc()->erase(get_attach_menu_bots_database_key());
  } else {
    auto attach_menu_bots_string = G()->td_db()->get_binlog_pmc()->get(get_attach_menu_bots_database_key());

    if (!attach_menu_bots_string.empty()) {
      AttachMenuBotsLogEvent attach_menu_bots_log_event;
      bool is_valid = true;
      is_valid &= log_event_parse(attach_menu_bots_log_event, attach_menu_bots_string).is_ok();

      Dependencies dependencies;
      for (auto &attach_menu_bot : attach_menu_bots_log_event.attach_menu_bots_) {
        if (!attach_menu_bot.user_id_.is_valid() || !attach_menu_bot.default_icon_file_id_.is_valid()) {
          is_valid = false;
        }
        if (!is_valid) {
          break;
        }
        dependencies.add(attach_menu_bot.user_id_);
      }
      if (is_valid && dependencies.resolve_force(td_, "AttachMenuBotsLogEvent")) {
        bool is_cache_outdated = false;
        for (auto &bot : attach_menu_bots_log_event.attach_menu_bots_) {
          if (bot.cache_version_ != AttachMenuBot::CACHE_VERSION) {
            is_cache_outdated = true;
          }
        }
        hash_ = is_cache_outdated ? 0 : attach_menu_bots_log_event.hash_;
        attach_menu_bots_ = std::move(attach_menu_bots_log_event.attach_menu_bots_);

        for (auto attach_menu_bot : attach_menu_bots_) {
          auto file_source_id = get_attach_menu_bot_file_source_id(attach_menu_bot.user_id_);
          auto register_file_source = [&](FileId file_id) {
            if (file_id.is_valid()) {
              td_->file_manager_->add_file_source(file_id, file_source_id, "attach_menu_bot");
            }
          };
          register_file_source(attach_menu_bot.default_icon_file_id_);
          register_file_source(attach_menu_bot.ios_static_icon_file_id_);
          register_file_source(attach_menu_bot.ios_animated_icon_file_id_);
          register_file_source(attach_menu_bot.android_icon_file_id_);
          register_file_source(attach_menu_bot.macos_icon_file_id_);
          register_file_source(attach_menu_bot.placeholder_file_id_);
          register_file_source(attach_menu_bot.android_side_menu_icon_file_id_);
          register_file_source(attach_menu_bot.ios_side_menu_icon_file_id_);
          register_file_source(attach_menu_bot.macos_side_menu_icon_file_id_);
        }
      } else {
        LOG(ERROR) << "Ignore invalid attachment menu bots log event";
      }
    }
  }

  send_update_attach_menu_bots();
  reload_attach_menu_bots(Promise<Unit>());
}

void AttachMenuManager::timeout_expired() {
  if (!is_active()) {
    return;
  }

  reload_attach_menu_bots(Promise<Unit>());
}

bool AttachMenuManager::is_active() const {
  return !G()->close_flag() && td_->auth_manager_->is_authorized() && !td_->auth_manager_->is_bot();
}

Result<AttachMenuManager::AttachMenuBot> AttachMenuManager::get_attach_menu_bot(
    tl_object_ptr<telegram_api::attachMenuBot> &&bot) {
  UserId user_id(bot->bot_id_);
  if (!td_->user_manager_->have_user(user_id)) {
    return Status::Error(PSLICE() << "Have no information about " << user_id);
  }

  auto file_source_id = get_attach_menu_bot_file_source_id(user_id);

  AttachMenuBot attach_menu_bot;
  attach_menu_bot.is_added_ = !bot->inactive_;
  attach_menu_bot.user_id_ = user_id;
  attach_menu_bot.name_ = std::move(bot->short_name_);
  for (auto &icon : bot->icons_) {
    Slice name = icon->name_;
    int32 document_id = icon->icon_->get_id();
    if (document_id == telegram_api::documentEmpty::ID) {
      return Status::Error(PSLICE() << "Have no icon for " << user_id << " with name " << name);
    }
    CHECK(document_id == telegram_api::document::ID);

    if (name != "default_static" && name != "ios_static" && name != "ios_animated" && name != "android_animated" &&
        name != "macos_animated" && name != "placeholder_static" && name != "ios_side_menu_static" &&
        name != "android_side_menu_static" && name != "macos_side_menu_static") {
      LOG(ERROR) << "Have icon for " << user_id << " with name " << name;
      continue;
    }

    auto expected_document_type = ends_with(name, "_static") ? Document::Type::General : Document::Type::Sticker;
    auto parsed_document = td_->documents_manager_->on_get_document(
        move_tl_object_as<telegram_api::document>(icon->icon_), DialogId(), false);
    if (parsed_document.type != expected_document_type) {
      LOG(ERROR) << "Receive wrong attachment menu bot icon \"" << name << "\" for " << user_id;
      continue;
    }
    bool expect_colors = false;
    switch (name[5]) {
      case 'l':
        attach_menu_bot.default_icon_file_id_ = parsed_document.file_id;
        break;
      case 't':
        attach_menu_bot.ios_static_icon_file_id_ = parsed_document.file_id;
        break;
      case 'n':
        attach_menu_bot.ios_animated_icon_file_id_ = parsed_document.file_id;
        break;
      case 'i':
        if (name[8] == 's') {
          attach_menu_bot.android_side_menu_icon_file_id_ = parsed_document.file_id;
        } else if (name[8] == '_') {
          attach_menu_bot.ios_side_menu_icon_file_id_ = parsed_document.file_id;
        } else {
          attach_menu_bot.android_icon_file_id_ = parsed_document.file_id;
          expect_colors = true;
        }
        break;
      case '_':
        if (name[6] == 's') {
          attach_menu_bot.macos_side_menu_icon_file_id_ = parsed_document.file_id;
        } else {
          attach_menu_bot.macos_icon_file_id_ = parsed_document.file_id;
        }
        break;
      case 'h':
        attach_menu_bot.placeholder_file_id_ = parsed_document.file_id;
        break;
      default:
        UNREACHABLE();
    }
    td_->file_manager_->add_file_source(parsed_document.file_id, file_source_id, "get_attach_menu_bot");
    if (expect_colors) {
      if (icon->colors_.empty()) {
        LOG(ERROR) << "Have no colors for attachment menu bot icon for " << user_id;
      } else {
        for (auto &color : icon->colors_) {
          if (color->name_ != "light_icon" && color->name_ != "light_text" && color->name_ != "dark_icon" &&
              color->name_ != "dark_text") {
            LOG(ERROR) << "Receive unexpected attachment menu color " << color->name_ << " for " << user_id;
            continue;
          }
          auto alpha = (color->color_ >> 24) & 0xFF;
          if (alpha != 0 && alpha != 0xFF) {
            LOG(ERROR) << "Receive alpha in attachment menu color " << color->name_ << " for " << user_id;
          }
          auto c = color->color_ & 0xFFFFFF;
          switch (color->name_[6]) {
            case 'i':
              attach_menu_bot.icon_color_.light_color_ = c;
              break;
            case 't':
              attach_menu_bot.name_color_.light_color_ = c;
              break;
            case 'c':
              attach_menu_bot.icon_color_.dark_color_ = c;
              break;
            case 'e':
              attach_menu_bot.name_color_.dark_color_ = c;
              break;
            default:
              UNREACHABLE();
          }
        }
        if (attach_menu_bot.icon_color_.light_color_ == -1 || attach_menu_bot.icon_color_.dark_color_ == -1) {
          LOG(ERROR) << "Receive wrong icon_color for " << user_id;
          attach_menu_bot.icon_color_ = AttachMenuBotColor();
        }
        if (attach_menu_bot.name_color_.light_color_ == -1 || attach_menu_bot.name_color_.dark_color_ == -1) {
          LOG(ERROR) << "Receive wrong name_color for " << user_id;
          attach_menu_bot.name_color_ = AttachMenuBotColor();
        }
      }
    } else {
      if (!icon->colors_.empty()) {
        LOG(ERROR) << "Have unexpected colors for attachment menu bot icon for " << user_id << " with name " << name;
      }
    }
  }
  for (auto &peer_type : bot->peer_types_) {
    switch (peer_type->get_id()) {
      case telegram_api::attachMenuPeerTypeSameBotPM::ID:
        attach_menu_bot.supports_self_dialog_ = true;
        break;
      case telegram_api::attachMenuPeerTypeBotPM::ID:
        attach_menu_bot.supports_bot_dialogs_ = true;
        break;
      case telegram_api::attachMenuPeerTypePM::ID:
        attach_menu_bot.supports_user_dialogs_ = true;
        break;
      case telegram_api::attachMenuPeerTypeChat::ID:
        attach_menu_bot.supports_group_dialogs_ = true;
        break;
      case telegram_api::attachMenuPeerTypeBroadcast::ID:
        attach_menu_bot.supports_broadcast_dialogs_ = true;
        break;
      default:
        UNREACHABLE();
        break;
    }
  }
  attach_menu_bot.request_write_access_ = bot->request_write_access_;
  attach_menu_bot.show_in_attach_menu_ = bot->show_in_attach_menu_;
  attach_menu_bot.show_in_side_menu_ = bot->show_in_side_menu_;
  attach_menu_bot.side_menu_disclaimer_needed_ = bot->side_menu_disclaimer_needed_;
  if (!attach_menu_bot.default_icon_file_id_.is_valid()) {
    return Status::Error(PSLICE() << "Have no default icon for " << user_id);
  }
  attach_menu_bot.cache_version_ = AttachMenuBot::CACHE_VERSION;

  return std::move(attach_menu_bot);
}

void AttachMenuManager::reload_attach_menu_bots(Promise<Unit> &&promise) {
  if (!is_active()) {
    return promise.set_error(Status::Error(400, "Can't reload attachment menu bots"));
  }

  reload_attach_menu_bots_queries_.push_back(std::move(promise));
  if (reload_attach_menu_bots_queries_.size() == 1) {
    auto query_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this)](Result<telegram_api::object_ptr<telegram_api::AttachMenuBots>> &&result) {
          send_closure(actor_id, &AttachMenuManager::on_reload_attach_menu_bots, std::move(result));
        });
    td_->create_handler<GetAttachMenuBotsQuery>(std::move(query_promise))->send(hash_);
  }
}

void AttachMenuManager::on_reload_attach_menu_bots(
    Result<telegram_api::object_ptr<telegram_api::AttachMenuBots>> &&result) {
  if (!is_active()) {
    return set_promises(reload_attach_menu_bots_queries_);
  }
  if (result.is_error()) {
    set_timeout_in(Random::fast(60, 120));
    return set_promises(reload_attach_menu_bots_queries_);
  }

  is_inited_ = true;

  set_timeout_in(Random::fast(3600, 4800));

  auto attach_menu_bots_ptr = result.move_as_ok();
  auto constructor_id = attach_menu_bots_ptr->get_id();
  if (constructor_id == telegram_api::attachMenuBotsNotModified::ID) {
    return set_promises(reload_attach_menu_bots_queries_);
  }
  CHECK(constructor_id == telegram_api::attachMenuBots::ID);
  auto attach_menu_bots = move_tl_object_as<telegram_api::attachMenuBots>(attach_menu_bots_ptr);

  td_->user_manager_->on_get_users(std::move(attach_menu_bots->users_), "on_reload_attach_menu_bots");

  auto new_hash = attach_menu_bots->hash_;
  vector<AttachMenuBot> new_attach_menu_bots;

  for (auto &bot : attach_menu_bots->bots_) {
    auto r_attach_menu_bot = get_attach_menu_bot(std::move(bot));
    if (r_attach_menu_bot.is_error()) {
      LOG(ERROR) << r_attach_menu_bot.error().message();
      new_hash = 0;
      continue;
    }

    new_attach_menu_bots.push_back(r_attach_menu_bot.move_as_ok());
  }

  bool need_update = new_attach_menu_bots != attach_menu_bots_;
  if (need_update || hash_ != new_hash) {
    hash_ = new_hash;
    attach_menu_bots_ = std::move(new_attach_menu_bots);

    if (need_update) {
      send_update_attach_menu_bots();
    }

    save_attach_menu_bots();
  }
  set_promises(reload_attach_menu_bots_queries_);
}

void AttachMenuManager::remove_bot_from_attach_menu(UserId user_id) {
  for (auto it = attach_menu_bots_.begin(); it != attach_menu_bots_.end(); ++it) {
    if (it->user_id_ == user_id) {
      hash_ = 0;
      attach_menu_bots_.erase(it);

      send_update_attach_menu_bots();
      save_attach_menu_bots();
      return;
    }
  }
}

void AttachMenuManager::get_attach_menu_bot(UserId user_id,
                                            Promise<td_api::object_ptr<td_api::attachmentMenuBot>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

  TRY_RESULT_PROMISE(promise, bot_data, td_->user_manager_->get_bot_data(user_id));
  if (!bot_data.can_be_added_to_attach_menu) {
    return promise.set_error(Status::Error(400, "The bot can't be added to attachment menu"));
  }

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), user_id, promise = std::move(promise)](
                                 Result<telegram_api::object_ptr<telegram_api::attachMenuBotsBot>> &&result) mutable {
        send_closure(actor_id, &AttachMenuManager::on_get_attach_menu_bot, user_id, std::move(result),
                     std::move(promise));
      });
  td_->create_handler<GetAttachMenuBotQuery>(std::move(query_promise))->send(std::move(input_user));
}

void AttachMenuManager::reload_attach_menu_bot(UserId user_id, Promise<Unit> &&promise) {
  if (!is_active()) {
    return promise.set_error(Status::Error(400, "Can't reload attachment menu bot"));
  }

  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

  auto wrapped_promise = PromiseCreator::lambda(
      [promise = std::move(promise)](Result<td_api::object_ptr<td_api::attachmentMenuBot>> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(Unit());
        }
      });
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), user_id, promise = std::move(wrapped_promise)](
                                 Result<telegram_api::object_ptr<telegram_api::attachMenuBotsBot>> &&result) mutable {
        send_closure(actor_id, &AttachMenuManager::on_get_attach_menu_bot, user_id, std::move(result),
                     std::move(promise));
      });
  td_->create_handler<GetAttachMenuBotQuery>(std::move(query_promise))->send(std::move(input_user));
}

void AttachMenuManager::on_get_attach_menu_bot(
    UserId user_id, Result<telegram_api::object_ptr<telegram_api::attachMenuBotsBot>> &&result,
    Promise<td_api::object_ptr<td_api::attachmentMenuBot>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, bot, std::move(result));

  td_->user_manager_->on_get_users(std::move(bot->users_), "on_get_attach_menu_bot");

  auto r_attach_menu_bot = get_attach_menu_bot(std::move(bot->bot_));
  if (r_attach_menu_bot.is_error()) {
    LOG(ERROR) << r_attach_menu_bot.error().message();
    return promise.set_error(Status::Error(500, "Receive invalid response"));
  }
  auto attach_menu_bot = r_attach_menu_bot.move_as_ok();
  if (attach_menu_bot.user_id_ != user_id) {
    return promise.set_error(Status::Error(500, "Receive wrong bot"));
  }
  if (attach_menu_bot.is_added_) {
    bool is_found = false;
    for (auto &old_bot : attach_menu_bots_) {
      if (old_bot.user_id_ == user_id) {
        is_found = true;
        if (old_bot != attach_menu_bot) {
          LOG(INFO) << "Update attachment menu bot " << user_id;

          old_bot = attach_menu_bot;

          send_update_attach_menu_bots();
          save_attach_menu_bots();
        }
        break;
      }
    }
    if (!is_found) {
      LOG(INFO) << "Add missing attachment menu bot " << user_id;

      hash_ = 0;
      attach_menu_bots_.insert(attach_menu_bots_.begin(), attach_menu_bot);

      send_update_attach_menu_bots();
      save_attach_menu_bots();
    }
  }
  promise.set_value(get_attachment_menu_bot_object(attach_menu_bot));
}

FileSourceId AttachMenuManager::get_attach_menu_bot_file_source_id(UserId user_id) {
  if (!user_id.is_valid() || !is_active()) {
    return FileSourceId();
  }

  auto &source_id = attach_menu_bot_file_source_ids_[user_id];
  if (!source_id.is_valid()) {
    source_id = td_->file_reference_manager_->create_attach_menu_bot_file_source(user_id);
  }
  VLOG(file_references) << "Return " << source_id << " for attach menu bot " << user_id;
  return source_id;
}

void AttachMenuManager::toggle_bot_is_added_to_attach_menu(UserId user_id, bool is_added, bool allow_write_access,
                                                           Promise<Unit> &&promise) {
  CHECK(is_active());

  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

  if (is_added) {
    TRY_RESULT_PROMISE(promise, bot_data, td_->user_manager_->get_bot_data(user_id));
    if (!bot_data.can_be_added_to_attach_menu) {
      return promise.set_error(Status::Error(400, "The bot can't be added to attachment menu"));
    }
  } else {
    remove_bot_from_attach_menu(user_id);
  }

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          send_closure(actor_id, &AttachMenuManager::reload_attach_menu_bots, std::move(promise));
        }
      });

  td_->create_handler<ToggleBotInAttachMenuQuery>(std::move(query_promise))
      ->send(std::move(input_user), is_added, allow_write_access);
}

td_api::object_ptr<td_api::attachmentMenuBot> AttachMenuManager::get_attachment_menu_bot_object(
    const AttachMenuBot &bot) const {
  auto get_file = [td = td_](FileId file_id) -> td_api::object_ptr<td_api::file> {
    if (!file_id.is_valid()) {
      return nullptr;
    }
    return td->file_manager_->get_file_object(file_id);
  };
  auto get_attach_menu_bot_color_object =
      [](const AttachMenuBotColor &color) -> td_api::object_ptr<td_api::attachmentMenuBotColor> {
    if (color == AttachMenuBotColor()) {
      return nullptr;
    }
    return td_api::make_object<td_api::attachmentMenuBotColor>(color.light_color_, color.dark_color_);
  };

  return td_api::make_object<td_api::attachmentMenuBot>(
      td_->user_manager_->get_user_id_object(bot.user_id_, "get_attachment_menu_bot_object"), bot.supports_self_dialog_,
      bot.supports_user_dialogs_, bot.supports_bot_dialogs_, bot.supports_group_dialogs_,
      bot.supports_broadcast_dialogs_, bot.request_write_access_, bot.is_added_, bot.show_in_attach_menu_,
      bot.show_in_side_menu_, bot.side_menu_disclaimer_needed_, bot.name_,
      get_attach_menu_bot_color_object(bot.name_color_), get_file(bot.default_icon_file_id_),
      get_file(bot.ios_static_icon_file_id_), get_file(bot.ios_animated_icon_file_id_),
      get_file(bot.ios_side_menu_icon_file_id_), get_file(bot.android_icon_file_id_),
      get_file(bot.android_side_menu_icon_file_id_), get_file(bot.macos_icon_file_id_),
      get_file(bot.macos_side_menu_icon_file_id_), get_attach_menu_bot_color_object(bot.icon_color_),
      get_file(bot.placeholder_file_id_));
}

td_api::object_ptr<td_api::updateAttachmentMenuBots> AttachMenuManager::get_update_attachment_menu_bots_object() const {
  CHECK(is_active());
  CHECK(is_inited_);
  auto bots =
      transform(attach_menu_bots_, [this](const AttachMenuBot &bot) { return get_attachment_menu_bot_object(bot); });
  return td_api::make_object<td_api::updateAttachmentMenuBots>(std::move(bots));
}

void AttachMenuManager::send_update_attach_menu_bots() const {
  send_closure(G()->td(), &Td::send_update, get_update_attachment_menu_bots_object());
}

string AttachMenuManager::get_attach_menu_bots_database_key() {
  return "attach_bots";
}

void AttachMenuManager::save_attach_menu_bots() {
  if (!G()->use_chat_info_database()) {
    return;
  }

  if (attach_menu_bots_.empty()) {
    G()->td_db()->get_binlog_pmc()->erase(get_attach_menu_bots_database_key());
  } else {
    AttachMenuBotsLogEvent attach_menu_bots_log_event{hash_, attach_menu_bots_};
    G()->td_db()->get_binlog_pmc()->set(get_attach_menu_bots_database_key(),
                                        log_event_store(attach_menu_bots_log_event).as_slice().str());
  }
}

void AttachMenuManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (!is_active()) {
    return;
  }

  updates.push_back(get_update_attachment_menu_bots_object());
}

}  // namespace td
