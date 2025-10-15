//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class Td;

class AttachMenuManager final : public Actor {
 public:
  AttachMenuManager(Td *td, ActorShared<> parent);

  void init();

  void reload_attach_menu_bots(Promise<Unit> &&promise);

  void get_attach_menu_bot(UserId user_id, Promise<td_api::object_ptr<td_api::attachmentMenuBot>> &&promise);

  void reload_attach_menu_bot(UserId user_id, Promise<Unit> &&promise);

  FileSourceId get_attach_menu_bot_file_source_id(UserId user_id);

  void toggle_bot_is_added_to_attach_menu(UserId user_id, bool is_added, bool allow_write_access,
                                          Promise<Unit> &&promise);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

  static string get_attach_menu_bots_database_key();

 private:
  void start_up() final;

  void timeout_expired() final;

  void tear_down() final;

  struct AttachMenuBotColor {
    int32 light_color_ = -1;
    int32 dark_color_ = -1;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  friend bool operator==(const AttachMenuBotColor &lhs, const AttachMenuBotColor &rhs);

  friend bool operator!=(const AttachMenuBotColor &lhs, const AttachMenuBotColor &rhs);

  struct AttachMenuBot {
    bool is_added_ = false;
    UserId user_id_;
    bool supports_self_dialog_ = false;
    bool supports_user_dialogs_ = false;
    bool supports_bot_dialogs_ = false;
    bool supports_group_dialogs_ = false;
    bool supports_broadcast_dialogs_ = false;
    bool request_write_access_ = false;
    bool show_in_attach_menu_ = false;
    bool show_in_side_menu_ = false;
    bool side_menu_disclaimer_needed_ = false;
    string name_;
    AttachMenuBotColor name_color_;
    FileId default_icon_file_id_;
    FileId ios_static_icon_file_id_;
    FileId ios_animated_icon_file_id_;
    FileId android_icon_file_id_;
    FileId macos_icon_file_id_;
    FileId android_side_menu_icon_file_id_;
    FileId ios_side_menu_icon_file_id_;
    FileId macos_side_menu_icon_file_id_;
    AttachMenuBotColor icon_color_;
    FileId placeholder_file_id_;

    static constexpr uint32 CACHE_VERSION = 3;
    uint32 cache_version_ = 0;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  class AttachMenuBotsLogEvent;

  friend bool operator==(const AttachMenuBot &lhs, const AttachMenuBot &rhs);

  friend bool operator!=(const AttachMenuBot &lhs, const AttachMenuBot &rhs);

  bool is_active() const;

  Result<AttachMenuBot> get_attach_menu_bot(tl_object_ptr<telegram_api::attachMenuBot> &&bot);

  td_api::object_ptr<td_api::attachmentMenuBot> get_attachment_menu_bot_object(const AttachMenuBot &bot) const;

  td_api::object_ptr<td_api::updateAttachmentMenuBots> get_update_attachment_menu_bots_object() const;

  void remove_bot_from_attach_menu(UserId user_id);

  void send_update_attach_menu_bots() const;

  void save_attach_menu_bots();

  void on_reload_attach_menu_bots(Result<telegram_api::object_ptr<telegram_api::AttachMenuBots>> &&result);

  void on_get_attach_menu_bot(UserId user_id,
                              Result<telegram_api::object_ptr<telegram_api::attachMenuBotsBot>> &&result,
                              Promise<td_api::object_ptr<td_api::attachmentMenuBot>> &&promise);

  Td *td_;
  ActorShared<> parent_;

  bool is_inited_ = false;
  int64 hash_ = 0;
  vector<AttachMenuBot> attach_menu_bots_;
  FlatHashMap<UserId, FileSourceId, UserIdHash> attach_menu_bot_file_source_ids_;
  vector<Promise<Unit>> reload_attach_menu_bots_queries_;
};

}  // namespace td
