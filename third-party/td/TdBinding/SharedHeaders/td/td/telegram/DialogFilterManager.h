//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogFilterDialogInfo.h"
#include "td/telegram/DialogFilterId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/InputDialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"
#include "td/actor/Timeout.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class DialogFilter;
class Td;

class DialogFilterManager final : public Actor {
 public:
  DialogFilterManager(Td *td, ActorShared<> parent);
  DialogFilterManager(const DialogFilterManager &) = delete;
  DialogFilterManager &operator=(const DialogFilterManager &) = delete;
  DialogFilterManager(DialogFilterManager &&) = delete;
  DialogFilterManager &operator=(DialogFilterManager &&) = delete;
  ~DialogFilterManager() final;

  void init();

  void on_authorization_success();

  void on_update_dialog_filters(Promise<Unit> &&promise);

  void schedule_reload_dialog_filters(Promise<Unit> &&promise);

  bool have_dialog_filters() const;

  vector<FolderId> get_dialog_filter_folder_ids(DialogFilterId dialog_filter_id) const;

  vector<DialogFilterId> get_dialog_filters_to_add_dialog(DialogId dialog_id) const;

  bool need_dialog_in_filter(DialogFilterId dialog_filter_id, const DialogFilterDialogInfo &dialog_info) const;

  bool is_dialog_pinned(DialogFilterId dialog_filter_id, DialogId dialog_id) const;

  const vector<InputDialogId> &get_pinned_input_dialog_ids(DialogFilterId dialog_filter_id) const;

  vector<DialogId> get_pinned_dialog_ids(DialogFilterId dialog_filter_id) const;

  Status set_dialog_is_pinned(DialogFilterId dialog_filter_id, InputDialogId input_dialog_id, bool is_pinned);

  Status set_pinned_dialog_ids(DialogFilterId dialog_filter_id, vector<InputDialogId> input_dialog_ids,
                               bool need_synchronize);

  Status add_dialog(DialogFilterId dialog_filter_id, InputDialogId input_dialog_id);

  void get_dialog_filter(DialogFilterId dialog_filter_id, Promise<td_api::object_ptr<td_api::chatFolder>> &&promise);

  void create_dialog_filter(td_api::object_ptr<td_api::chatFolder> filter,
                            Promise<td_api::object_ptr<td_api::chatFolderInfo>> &&promise);

  void edit_dialog_filter(DialogFilterId dialog_filter_id, td_api::object_ptr<td_api::chatFolder> filter,
                          Promise<td_api::object_ptr<td_api::chatFolderInfo>> &&promise);

  void delete_dialog_filter(DialogFilterId dialog_filter_id, vector<DialogId> leave_dialog_ids,
                            Promise<Unit> &&promise);

  void get_leave_dialog_filter_suggestions(DialogFilterId dialog_filter_id,
                                           Promise<td_api::object_ptr<td_api::chats>> &&promise);

  void reorder_dialog_filters(vector<DialogFilterId> dialog_filter_ids, int32 main_dialog_list_position,
                              Promise<Unit> &&promise);

  void toggle_dialog_filter_tags(bool are_tags_enabled, Promise<Unit> &&promise);

  void get_dialogs_for_dialog_filter_invite_link(DialogFilterId dialog_filter_id,
                                                 Promise<td_api::object_ptr<td_api::chats>> promise);

  void create_dialog_filter_invite_link(DialogFilterId dialog_filter_id, string invite_link_name,
                                        vector<DialogId> dialog_ids,
                                        Promise<td_api::object_ptr<td_api::chatFolderInviteLink>> promise);

  void get_dialog_filter_invite_links(DialogFilterId dialog_filter_id,
                                      Promise<td_api::object_ptr<td_api::chatFolderInviteLinks>> promise);

  void edit_dialog_filter_invite_link(DialogFilterId dialog_filter_id, string invite_link, string invite_link_name,
                                      vector<DialogId> dialog_ids,
                                      Promise<td_api::object_ptr<td_api::chatFolderInviteLink>> promise);

  void delete_dialog_filter_invite_link(DialogFilterId dialog_filter_id, string invite_link, Promise<Unit> promise);

  void check_dialog_filter_invite_link(const string &invite_link,
                                       Promise<td_api::object_ptr<td_api::chatFolderInviteLinkInfo>> &&promise);

  void on_get_chatlist_invite(const string &invite_link,
                              telegram_api::object_ptr<telegram_api::chatlists_ChatlistInvite> &&invite_ptr,
                              Promise<td_api::object_ptr<td_api::chatFolderInviteLinkInfo>> &&promise);

  void add_dialog_filter_by_invite_link(const string &invite_link, vector<DialogId> dialog_ids,
                                        Promise<Unit> &&promise);

  void get_dialog_filter_new_chats(DialogFilterId dialog_filter_id,
                                   Promise<td_api::object_ptr<td_api::chats>> &&promise);

  void add_dialog_filter_new_chats(DialogFilterId dialog_filter_id, vector<DialogId> dialog_ids,
                                   Promise<Unit> &&promise);

  void on_get_dialog_filter(telegram_api::object_ptr<telegram_api::DialogFilter> filter);

  void get_recommended_dialog_filters(Promise<td_api::object_ptr<td_api::recommendedChatFolders>> &&promise);

  void load_dialog_filter_dialogs(DialogFilterId dialog_filter_id, vector<InputDialogId> &&input_dialog_ids,
                                  Promise<Unit> &&promise);

  void load_input_dialog(const InputDialogId &input_dialog_id, Promise<Unit> &&promise);

  void set_dialog_filter_has_my_invite_links(DialogFilterId dialog_filter_id, bool has_my_invite_links);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  static constexpr int32 DIALOG_FILTERS_CACHE_TIME = 86400;

  class DialogFiltersLogEvent;

  void hangup() final;

  void tear_down() final;

  struct RecommendedDialogFilter {
    unique_ptr<DialogFilter> dialog_filter;
    string description;
  };

  DialogFilter *get_dialog_filter(DialogFilterId dialog_filter_id);

  const DialogFilter *get_dialog_filter(DialogFilterId dialog_filter_id) const;

  static double get_dialog_filters_cache_time();

  void schedule_dialog_filters_reload(double timeout);

  static void on_reload_dialog_filters_timeout(void *dialog_filter_manager_ptr);

  void reload_dialog_filters();

  void on_get_dialog_filters(Result<telegram_api::object_ptr<telegram_api::messages_dialogFilters>> r_filters,
                             bool dummy);

  bool need_synchronize_dialog_filters() const;

  void synchronize_dialog_filters();

  td_api::object_ptr<td_api::chatFolder> get_chat_folder_object(DialogFilterId dialog_filter_id);

  td_api::object_ptr<td_api::chatFolder> get_chat_folder_object(const DialogFilter *dialog_filter);

  void send_update_chat_folders();

  td_api::object_ptr<td_api::updateChatFolders> get_update_chat_folders_object() const;

  void do_edit_dialog_filter(unique_ptr<DialogFilter> &&filter, bool need_synchronize, const char *source);

  void update_dialog_filter_on_server(unique_ptr<DialogFilter> &&dialog_filter);

  void on_update_dialog_filter(unique_ptr<DialogFilter> dialog_filter, Status result);

  void delete_dialog_filter_on_server(DialogFilterId dialog_filter_id, bool is_shareable);

  void on_delete_dialog_filter(DialogFilterId dialog_filter_id, Status result);

  void on_get_leave_dialog_filter_suggestions(DialogFilterId dialog_filter_id,
                                              vector<telegram_api::object_ptr<telegram_api::Peer>> peers,
                                              Promise<td_api::object_ptr<td_api::chats>> &&promise);

  void reorder_dialog_filters_on_server(vector<DialogFilterId> dialog_filter_ids, int32 main_dialog_list_position);

  void on_reorder_dialog_filters(vector<DialogFilterId> dialog_filter_ids, int32 main_dialog_list_position,
                                 Status result);

  void toggle_are_tags_enabled_on_server(bool are_tags_enabled);

  void on_toggle_are_tags_enabled(bool are_tags_enabled, Status result);

  void save_dialog_filters();

  void add_dialog_filter(unique_ptr<DialogFilter> dialog_filter, bool at_beginning, const char *source);

  void edit_dialog_filter(unique_ptr<DialogFilter> new_dialog_filter, const char *source);

  int32 do_delete_dialog_filter(DialogFilterId dialog_filter_id, const char *source);

  const DialogFilter *get_server_dialog_filter(DialogFilterId dialog_filter_id) const;

  int32 get_server_main_dialog_list_position() const;

  bool is_recommended_dialog_filter(const DialogFilter *dialog_filter);

  void on_get_recommended_dialog_filters(
      Result<vector<telegram_api::object_ptr<telegram_api::dialogFilterSuggested>>> result,
      Promise<td_api::object_ptr<td_api::recommendedChatFolders>> &&promise);

  void on_load_recommended_dialog_filters(Result<Unit> &&result, vector<RecommendedDialogFilter> &&filters,
                                          Promise<td_api::object_ptr<td_api::recommendedChatFolders>> &&promise);

  void load_dialog_filter(const DialogFilter *dialog_filter, Promise<Unit> &&promise);

  void on_load_dialog_filter(DialogFilterId dialog_filter_id,
                             Promise<td_api::object_ptr<td_api::chatFolder>> &&promise);

  void on_load_dialog_filter_dialogs(DialogFilterId dialog_filter_id, vector<DialogId> &&dialog_ids,
                                     Promise<Unit> &&promise);

  void delete_dialogs_from_filter(const DialogFilter *dialog_filter, vector<DialogId> &&dialog_ids, const char *source);

  void do_get_dialogs_for_dialog_filter_invite_link(DialogFilterId dialog_filter_id,
                                                    Promise<td_api::object_ptr<td_api::chats>> promise);

  bool is_inited_ = false;

  bool are_dialog_filters_being_synchronized_ = false;
  bool are_dialog_filters_being_reloaded_ = false;
  bool need_dialog_filters_reload_ = false;
  bool disable_get_dialog_filter_ = false;
  bool is_update_chat_folders_sent_ = false;
  bool server_are_tags_enabled_ = false;
  bool are_tags_enabled_ = false;
  int32 dialog_filters_updated_date_ = 0;
  vector<unique_ptr<DialogFilter>> server_dialog_filters_;
  vector<unique_ptr<DialogFilter>> dialog_filters_;
  vector<Promise<Unit>> dialog_filter_reload_queries_;
  int32 server_main_dialog_list_position_ = 0;  // position of the main dialog list stored on the server
  int32 main_dialog_list_position_ = 0;         // local position of the main dialog list stored on the server

  vector<RecommendedDialogFilter> recommended_dialog_filters_;

  Timeout reload_dialog_filters_timeout_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
