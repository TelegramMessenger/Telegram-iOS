//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogFilterManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogFilter.h"
#include "td/telegram/DialogFilter.hpp"
#include "td/telegram/DialogFilterInviteLink.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/DialogParticipantManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageEntity.hpp"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/Version.h"

#include "td/actor/MultiPromise.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/tl_helpers.h"

#include <unordered_set>

namespace td {

class GetDialogFiltersQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::messages_dialogFilters>> promise_;

 public:
  explicit GetDialogFiltersQuery(Promise<telegram_api::object_ptr<telegram_api::messages_dialogFilters>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::messages_getDialogFilters()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getDialogFilters>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateDialogFilterQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit UpdateDialogFilterQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogFilterId dialog_filter_id, telegram_api::object_ptr<telegram_api::DialogFilter> filter) {
    int32 flags = 0;
    if (filter != nullptr) {
      flags |= telegram_api::messages_updateDialogFilter::FILTER_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_updateDialogFilter(flags, dialog_filter_id.get(), std::move(filter))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_updateDialogFilter>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(INFO) << "Receive result for UpdateDialogFilterQuery: " << result_ptr.ok();
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    LOG(ERROR) << "Receive error for UpdateDialogFilterQuery: " << status;
    promise_.set_error(std::move(status));
  }
};

class UpdateDialogFiltersOrderQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit UpdateDialogFiltersOrderQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const vector<DialogFilterId> &dialog_filter_ids, int32 main_dialog_list_position) {
    auto filter_ids = transform(dialog_filter_ids, [](auto dialog_filter_id) { return dialog_filter_id.get(); });
    CHECK(0 <= main_dialog_list_position);
    CHECK(main_dialog_list_position <= static_cast<int32>(filter_ids.size()));
    filter_ids.insert(filter_ids.begin() + main_dialog_list_position, 0);
    send_query(G()->net_query_creator().create(telegram_api::messages_updateDialogFiltersOrder(std::move(filter_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_updateDialogFiltersOrder>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(INFO) << "Receive result for UpdateDialogFiltersOrderQuery: " << result_ptr.ok();
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ToggleDialogFilterTagsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ToggleDialogFilterTagsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(bool are_tags_enabled) {
    send_query(G()->net_query_creator().create(telegram_api::messages_toggleDialogFilterTags(are_tags_enabled)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_toggleDialogFilterTags>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(INFO) << "Receive result for ToggleDialogFilterTagsQuery: " << result_ptr.ok();
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ExportChatlistInviteQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatFolderInviteLink>> promise_;

 public:
  explicit ExportChatlistInviteQuery(Promise<td_api::object_ptr<td_api::chatFolderInviteLink>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogFilterId dialog_filter_id, const string &title,
            vector<tl_object_ptr<telegram_api::InputPeer>> &&input_peers) {
    send_query(G()->net_query_creator().create(telegram_api::chatlists_exportChatlistInvite(
        dialog_filter_id.get_input_chatlist(), title, std::move(input_peers))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::chatlists_exportChatlistInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ExportChatlistInviteQuery: " << to_string(ptr);
    td_->dialog_filter_manager_->on_get_dialog_filter(std::move(ptr->filter_));
    promise_.set_value(DialogFilterInviteLink(td_, std::move(ptr->invite_)).get_chat_folder_invite_link_object(td_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetExportedChatlistInvitesQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatFolderInviteLinks>> promise_;
  DialogFilterId dialog_filter_id_;

 public:
  explicit GetExportedChatlistInvitesQuery(Promise<td_api::object_ptr<td_api::chatFolderInviteLinks>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogFilterId dialog_filter_id) {
    dialog_filter_id_ = dialog_filter_id;
    send_query(G()->net_query_creator().create(
        telegram_api::chatlists_getExportedInvites(dialog_filter_id.get_input_chatlist())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::chatlists_getExportedInvites>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetExportedChatlistInvitesQuery: " << to_string(ptr);
    td_->user_manager_->on_get_users(std::move(ptr->users_), "GetExportedChatlistInvitesQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "GetExportedChatlistInvitesQuery");
    auto result = td_api::make_object<td_api::chatFolderInviteLinks>();
    for (auto &invite : ptr->invites_) {
      result->invite_links_.push_back(
          DialogFilterInviteLink(td_, std::move(invite)).get_chat_folder_invite_link_object(td_));
    }
    td_->dialog_filter_manager_->set_dialog_filter_has_my_invite_links(dialog_filter_id_,
                                                                       !result->invite_links_.empty());
    promise_.set_value(std::move(result));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class EditExportedChatlistInviteQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatFolderInviteLink>> promise_;

 public:
  explicit EditExportedChatlistInviteQuery(Promise<td_api::object_ptr<td_api::chatFolderInviteLink>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogFilterId dialog_filter_id, const string &slug, const string &title,
            vector<tl_object_ptr<telegram_api::InputPeer>> &&input_peers) {
    int32 flags =
        telegram_api::chatlists_editExportedInvite::TITLE_MASK | telegram_api::chatlists_editExportedInvite::PEERS_MASK;
    send_query(G()->net_query_creator().create(telegram_api::chatlists_editExportedInvite(
        flags, dialog_filter_id.get_input_chatlist(), slug, title, std::move(input_peers))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::chatlists_editExportedInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditExportedChatlistInviteQuery: " << to_string(ptr);
    promise_.set_value(DialogFilterInviteLink(td_, std::move(ptr)).get_chat_folder_invite_link_object(td_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteExportedChatlistInviteQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit DeleteExportedChatlistInviteQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogFilterId dialog_filter_id, const string &slug) {
    send_query(G()->net_query_creator().create(
        telegram_api::chatlists_deleteExportedInvite(dialog_filter_id.get_input_chatlist(), slug)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::chatlists_deleteExportedInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for DeleteExportedChatlistInviteQuery: " << ptr;
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class LeaveChatlistQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit LeaveChatlistQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogFilterId dialog_filter_id) {
    send_query(G()->net_query_creator().create(telegram_api::chatlists_leaveChatlist(
        dialog_filter_id.get_input_chatlist(), vector<telegram_api::object_ptr<telegram_api::InputPeer>>())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::chatlists_leaveChatlist>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for LeaveChatlistQuery: " << to_string(ptr);

    // must be set before updates are processed to drop are_dialog_filters_being_synchronized_
    promise_.set_value(Unit());

    td_->updates_manager_->on_get_updates(std::move(ptr), Promise<Unit>());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetLeaveChatlistSuggestionsQuery final : public Td::ResultHandler {
  Promise<vector<telegram_api::object_ptr<telegram_api::Peer>>> promise_;

 public:
  explicit GetLeaveChatlistSuggestionsQuery(Promise<vector<telegram_api::object_ptr<telegram_api::Peer>>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogFilterId dialog_filter_id) {
    send_query(G()->net_query_creator().create(
        telegram_api::chatlists_getLeaveChatlistSuggestions(dialog_filter_id.get_input_chatlist())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::chatlists_getLeaveChatlistSuggestions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetLeaveChatlistSuggestionsQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class CheckChatlistInviteQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatFolderInviteLinkInfo>> promise_;
  string invite_link_;

 public:
  explicit CheckChatlistInviteQuery(Promise<td_api::object_ptr<td_api::chatFolderInviteLinkInfo>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &invite_link) {
    invite_link_ = invite_link;
    send_query(G()->net_query_creator().create(
        telegram_api::chatlists_checkChatlistInvite(LinkManager::get_dialog_filter_invite_link_slug(invite_link_))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::chatlists_checkChatlistInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->dialog_filter_manager_->on_get_chatlist_invite(invite_link_, result_ptr.move_as_ok(), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class JoinChatlistInviteQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit JoinChatlistInviteQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &invite_link, vector<DialogId> dialog_ids) {
    send_query(G()->net_query_creator().create(telegram_api::chatlists_joinChatlistInvite(
        LinkManager::get_dialog_filter_invite_link_slug(invite_link),
        td_->dialog_manager_->get_input_peers(dialog_ids, AccessRights::Know))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::chatlists_joinChatlistInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for JoinChatlistInviteQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetChatlistUpdatesQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chats>> promise_;

 public:
  explicit GetChatlistUpdatesQuery(Promise<td_api::object_ptr<td_api::chats>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogFilterId dialog_filter_id) {
    send_query(G()->net_query_creator().create(
        telegram_api::chatlists_getChatlistUpdates(dialog_filter_id.get_input_chatlist())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::chatlists_getChatlistUpdates>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetChatlistUpdatesQuery: " << to_string(ptr);
    td_->user_manager_->on_get_users(std::move(ptr->users_), "GetChatlistUpdatesQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "GetChatlistUpdatesQuery");
    auto missing_dialog_ids = td_->dialog_manager_->get_peers_dialog_ids(std::move(ptr->missing_peers_), true);
    promise_.set_value(td_->dialog_manager_->get_chats_object(-1, missing_dialog_ids, "GetChatlistUpdatesQuery"));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class JoinChatlistUpdatesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit JoinChatlistUpdatesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogFilterId dialog_filter_id, vector<DialogId> dialog_ids) {
    send_query(G()->net_query_creator().create(telegram_api::chatlists_joinChatlistUpdates(
        dialog_filter_id.get_input_chatlist(), td_->dialog_manager_->get_input_peers(dialog_ids, AccessRights::Know))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::chatlists_joinChatlistUpdates>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for JoinChatlistUpdatesQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class HideChatlistUpdatesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit HideChatlistUpdatesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogFilterId dialog_filter_id) {
    send_query(G()->net_query_creator().create(
        telegram_api::chatlists_hideChatlistUpdates(dialog_filter_id.get_input_chatlist())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::chatlists_hideChatlistUpdates>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for HideChatlistUpdatesQuery: " << ptr;
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetDialogsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  bool is_single_ = false;

 public:
  explicit GetDialogsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<InputDialogId> input_dialog_ids) {
    CHECK(!input_dialog_ids.empty());
    CHECK(input_dialog_ids.size() <= 100);
    is_single_ = input_dialog_ids.size() == 1;
    auto input_dialog_peers = InputDialogId::get_input_dialog_peers(input_dialog_ids);
    CHECK(input_dialog_peers.size() == input_dialog_ids.size());
    send_query(G()->net_query_creator().create(telegram_api::messages_getPeerDialogs(std::move(input_dialog_peers))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getPeerDialogs>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetDialogsQuery: " << to_string(result);

    td_->user_manager_->on_get_users(std::move(result->users_), "GetDialogsQuery");
    td_->chat_manager_->on_get_chats(std::move(result->chats_), "GetDialogsQuery");
    td_->messages_manager_->on_get_dialogs(FolderId(), std::move(result->dialogs_), -1, std::move(result->messages_),
                                           std::move(promise_));
  }

  void on_error(Status status) final {
    if (is_single_ && status.code() == 400) {
      return promise_.set_value(Unit());
    }
    promise_.set_error(std::move(status));
  }
};

class GetSuggestedDialogFiltersQuery final : public Td::ResultHandler {
  Promise<vector<telegram_api::object_ptr<telegram_api::dialogFilterSuggested>>> promise_;

 public:
  explicit GetSuggestedDialogFiltersQuery(
      Promise<vector<telegram_api::object_ptr<telegram_api::dialogFilterSuggested>>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::messages_getSuggestedDialogFilters()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getSuggestedDialogFilters>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

DialogFilterManager::DialogFilterManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

DialogFilterManager::~DialogFilterManager() = default;

void DialogFilterManager::hangup() {
  fail_promises(dialog_filter_reload_queries_, Global::request_aborted_error());
  stop();
}

void DialogFilterManager::tear_down() {
  parent_.reset();
}

class DialogFilterManager::DialogFiltersLogEvent {
 public:
  int32 server_main_dialog_list_position = 0;
  int32 main_dialog_list_position = 0;
  int32 updated_date = 0;
  const vector<unique_ptr<DialogFilter>> *server_dialog_filters_in;
  const vector<unique_ptr<DialogFilter>> *dialog_filters_in;
  vector<unique_ptr<DialogFilter>> server_dialog_filters_out;
  vector<unique_ptr<DialogFilter>> dialog_filters_out;
  bool server_are_tags_enabled = false;
  bool are_tags_enabled = false;

  template <class StorerT>
  void store(StorerT &storer) const {
    bool has_server_dialog_filters = !server_dialog_filters_in->empty();
    bool has_dialog_filters = !dialog_filters_in->empty();
    bool has_server_main_dialog_list_position = server_main_dialog_list_position != 0;
    bool has_main_dialog_list_position = main_dialog_list_position != 0;
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_server_dialog_filters);
    STORE_FLAG(has_dialog_filters);
    STORE_FLAG(has_server_main_dialog_list_position);
    STORE_FLAG(has_main_dialog_list_position);
    STORE_FLAG(server_are_tags_enabled);
    STORE_FLAG(are_tags_enabled);
    END_STORE_FLAGS();
    td::store(updated_date, storer);
    if (has_server_dialog_filters) {
      td::store(*server_dialog_filters_in, storer);
    }
    if (has_dialog_filters) {
      td::store(*dialog_filters_in, storer);
    }
    if (has_server_main_dialog_list_position) {
      td::store(server_main_dialog_list_position, storer);
    }
    if (has_main_dialog_list_position) {
      td::store(main_dialog_list_position, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    bool has_server_dialog_filters = true;
    bool has_dialog_filters = true;
    bool has_server_main_dialog_list_position = false;
    bool has_main_dialog_list_position = false;
    if (parser.version() >= static_cast<int32>(Version::AddMainDialogListPosition)) {
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_server_dialog_filters);
      PARSE_FLAG(has_dialog_filters);
      PARSE_FLAG(has_server_main_dialog_list_position);
      PARSE_FLAG(has_main_dialog_list_position);
      PARSE_FLAG(server_are_tags_enabled);
      PARSE_FLAG(are_tags_enabled);
      END_PARSE_FLAGS();
    }
    td::parse(updated_date, parser);
    if (has_server_dialog_filters) {
      td::parse(server_dialog_filters_out, parser);
    }
    if (has_dialog_filters) {
      td::parse(dialog_filters_out, parser);
    }
    if (has_server_main_dialog_list_position) {
      td::parse(server_main_dialog_list_position, parser);
    }
    if (has_main_dialog_list_position) {
      td::parse(main_dialog_list_position, parser);
    }
  }
};

void DialogFilterManager::init() {
  if (is_inited_) {
    return;
  }
  is_inited_ = true;

  bool is_authorized = td_->auth_manager_->is_authorized();
  bool was_authorized_user = td_->auth_manager_->was_authorized() && !td_->auth_manager_->is_bot();
  if (is_authorized && td_->auth_manager_->is_bot()) {
    disable_get_dialog_filter_ = true;
  }

  if (was_authorized_user) {
    auto dialog_filters = G()->td_db()->get_binlog_pmc()->get("dialog_filters");
    if (!dialog_filters.empty()) {
      DialogFiltersLogEvent log_event;
      if (log_event_parse(log_event, dialog_filters).is_ok()) {
        server_are_tags_enabled_ = log_event.server_are_tags_enabled;
        are_tags_enabled_ = log_event.are_tags_enabled;
        server_main_dialog_list_position_ = log_event.server_main_dialog_list_position;
        main_dialog_list_position_ = log_event.main_dialog_list_position;
        if (!td_->option_manager_->get_option_boolean("is_premium")) {
          if (server_main_dialog_list_position_ != 0 || main_dialog_list_position_ != 0) {
            LOG(INFO) << "Ignore main chat list position " << server_main_dialog_list_position_ << '/'
                      << main_dialog_list_position_;
            server_main_dialog_list_position_ = 0;
            main_dialog_list_position_ = 0;
          }
          if (server_are_tags_enabled_ || are_tags_enabled_) {
            LOG(INFO) << "Ignore enabled tags " << server_are_tags_enabled_ << '/' << are_tags_enabled_;
            server_are_tags_enabled_ = false;
            are_tags_enabled_ = false;
          }
        }

        dialog_filters_updated_date_ = td_->ignore_background_updates() ? 0 : log_event.updated_date;
        std::unordered_set<DialogFilterId, DialogFilterIdHash> server_dialog_filter_ids;
        for (auto &dialog_filter : log_event.server_dialog_filters_out) {
          if (dialog_filter->get_dialog_filter_id().is_valid() &&
              server_dialog_filter_ids.insert(dialog_filter->get_dialog_filter_id()).second) {
            server_dialog_filters_.push_back(std::move(dialog_filter));
          }
        }
        for (auto &dialog_filter : log_event.dialog_filters_out) {
          add_dialog_filter(std::move(dialog_filter), false, "binlog");
        }
        LOG(INFO) << "Loaded server chat folders "
                  << DialogFilter::get_dialog_filter_ids(server_dialog_filters_, server_main_dialog_list_position_)
                  << " and local chat folders "
                  << DialogFilter::get_dialog_filter_ids(dialog_filters_, main_dialog_list_position_);
      } else {
        LOG(ERROR) << "Failed to parse chat folders from binlog";
      }
    }
    send_update_chat_folders();  // always send updateChatFolders

    if (is_authorized) {
      if (need_synchronize_dialog_filters()) {
        reload_dialog_filters();
      } else {
        auto cache_time = get_dialog_filters_cache_time();
        schedule_dialog_filters_reload(cache_time - max(0, G()->unix_time() - dialog_filters_updated_date_));
      }
    }
  }
}

void DialogFilterManager::on_authorization_success() {
  CHECK(td_->auth_manager_->is_authorized());
  if (td_->auth_manager_->is_bot()) {
    disable_get_dialog_filter_ = true;
    return;
  }

  reload_dialog_filters();
}

void DialogFilterManager::on_update_dialog_filters(Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    // just in case
    return promise.set_value(Unit());
  }

  schedule_reload_dialog_filters(std::move(promise));
}

void DialogFilterManager::schedule_reload_dialog_filters(Promise<Unit> &&promise) {
  schedule_dialog_filters_reload(0.0);
  dialog_filter_reload_queries_.push_back(std::move(promise));
}

bool DialogFilterManager::have_dialog_filters() const {
  return !dialog_filters_.empty();
}

vector<FolderId> DialogFilterManager::get_dialog_filter_folder_ids(DialogFilterId dialog_filter_id) const {
  const auto *dialog_filter = get_dialog_filter(dialog_filter_id);
  CHECK(dialog_filter != nullptr);
  return dialog_filter->get_folder_ids();
}

vector<DialogFilterId> DialogFilterManager::get_dialog_filters_to_add_dialog(DialogId dialog_id) const {
  vector<DialogFilterId> result;
  for (const auto &dialog_filter : dialog_filters_) {
    if (dialog_filter->can_include_dialog(dialog_id)) {
      result.push_back(dialog_filter->get_dialog_filter_id());
    }
  }
  return result;
}

bool DialogFilterManager::need_dialog_in_filter(DialogFilterId dialog_filter_id,
                                                const DialogFilterDialogInfo &dialog_info) const {
  const auto *dialog_filter = get_dialog_filter(dialog_filter_id);
  CHECK(dialog_filter != nullptr);
  return dialog_filter->need_dialog(td_, dialog_info);
}

bool DialogFilterManager::is_dialog_pinned(DialogFilterId dialog_filter_id, DialogId dialog_id) const {
  const auto *dialog_filter = get_dialog_filter(dialog_filter_id);
  return dialog_filter != nullptr && dialog_filter->is_dialog_pinned(dialog_id);
}

const vector<InputDialogId> &DialogFilterManager::get_pinned_input_dialog_ids(DialogFilterId dialog_filter_id) const {
  auto *dialog_filter = get_dialog_filter(dialog_filter_id);
  CHECK(dialog_filter != nullptr);
  return dialog_filter->get_pinned_input_dialog_ids();
}

vector<DialogId> DialogFilterManager::get_pinned_dialog_ids(DialogFilterId dialog_filter_id) const {
  auto *dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return {};
  }
  return InputDialogId::get_dialog_ids(dialog_filter->get_pinned_input_dialog_ids());
}

Status DialogFilterManager::set_dialog_is_pinned(DialogFilterId dialog_filter_id, InputDialogId input_dialog_id,
                                                 bool is_pinned) {
  CHECK(is_update_chat_folders_sent_);
  auto old_dialog_filter = get_dialog_filter(dialog_filter_id);
  CHECK(old_dialog_filter != nullptr);
  auto new_dialog_filter = make_unique<DialogFilter>(*old_dialog_filter);
  new_dialog_filter->set_dialog_is_pinned(input_dialog_id, is_pinned);

  TRY_STATUS(new_dialog_filter->check_limits());
  new_dialog_filter->sort_input_dialog_ids(td_, "set_dialog_is_pinned");

  do_edit_dialog_filter(std::move(new_dialog_filter),
                        input_dialog_id.get_dialog_id().get_type() != DialogType::SecretChat, "set_dialog_is_pinned");
  return Status::OK();
}

Status DialogFilterManager::set_pinned_dialog_ids(DialogFilterId dialog_filter_id,
                                                  vector<InputDialogId> input_dialog_ids, bool need_synchronize) {
  CHECK(is_update_chat_folders_sent_);
  auto old_dialog_filter = get_dialog_filter(dialog_filter_id);
  CHECK(old_dialog_filter != nullptr);
  auto new_dialog_filter = make_unique<DialogFilter>(*old_dialog_filter);
  new_dialog_filter->set_pinned_dialog_ids(std::move(input_dialog_ids));
  TRY_STATUS(new_dialog_filter->check_limits());
  new_dialog_filter->sort_input_dialog_ids(td_, "set_pinned_dialog_ids");

  do_edit_dialog_filter(std::move(new_dialog_filter), need_synchronize, "set_pinned_dialog_ids");
  return Status::OK();
}

Status DialogFilterManager::add_dialog(DialogFilterId dialog_filter_id, InputDialogId input_dialog_id) {
  CHECK(is_update_chat_folders_sent_);
  auto old_dialog_filter = get_dialog_filter(dialog_filter_id);
  CHECK(old_dialog_filter != nullptr);
  if (old_dialog_filter->is_dialog_included(input_dialog_id.get_dialog_id())) {
    return Status::OK();
  }

  auto new_dialog_filter = make_unique<DialogFilter>(*old_dialog_filter);
  new_dialog_filter->include_dialog(input_dialog_id);
  TRY_STATUS(new_dialog_filter->check_limits());
  new_dialog_filter->sort_input_dialog_ids(td_, "add_dialog");

  do_edit_dialog_filter(std::move(new_dialog_filter),
                        input_dialog_id.get_dialog_id().get_type() != DialogType::SecretChat, "add_dialog");
  return Status::OK();
}

bool DialogFilterManager::is_recommended_dialog_filter(const DialogFilter *dialog_filter) {
  for (const auto &recommended_dialog_filter : recommended_dialog_filters_) {
    if (DialogFilter::are_similar(*recommended_dialog_filter.dialog_filter, *dialog_filter)) {
      return true;
    }
  }
  return false;
}

td_api::object_ptr<td_api::chatFolder> DialogFilterManager::get_chat_folder_object(DialogFilterId dialog_filter_id) {
  CHECK(!td_->auth_manager_->is_bot());
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return nullptr;
  }

  return get_chat_folder_object(dialog_filter);
}

td_api::object_ptr<td_api::chatFolder> DialogFilterManager::get_chat_folder_object(const DialogFilter *dialog_filter) {
  DialogFilterId dialog_filter_id = dialog_filter->get_dialog_filter_id();

  vector<DialogId> left_dialog_ids;
  vector<DialogId> unknown_dialog_ids;
  dialog_filter->for_each_dialog([&](const InputDialogId &input_dialog_id) {
    auto dialog_id = input_dialog_id.get_dialog_id();
    if (td_->messages_manager_->is_dialog_in_dialog_list(dialog_id)) {
      return;
    }
    if (td_->messages_manager_->have_dialog(dialog_id)) {
      LOG(INFO) << "Skip nonjoined " << dialog_id << " from " << dialog_filter_id;
      unknown_dialog_ids.push_back(dialog_id);
      left_dialog_ids.push_back(dialog_id);
    } else {
      // possible if the chat folder has just been edited from another device
      LOG(ERROR) << "Can't find " << dialog_id << " from " << dialog_filter_id;
      unknown_dialog_ids.push_back(dialog_id);
    }
  });

  auto result = dialog_filter->get_chat_folder_object(unknown_dialog_ids);

  if (dialog_filter_id.is_valid()) {
    delete_dialogs_from_filter(dialog_filter, std::move(left_dialog_ids), "get_chat_folder_object");
  }
  return result;
}

void DialogFilterManager::get_recommended_dialog_filters(
    Promise<td_api::object_ptr<td_api::recommendedChatFolders>> &&promise) {
  CHECK(!td_->auth_manager_->is_bot());
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), promise = std::move(promise)](
          Result<vector<telegram_api::object_ptr<telegram_api::dialogFilterSuggested>>> result) mutable {
        send_closure(actor_id, &DialogFilterManager::on_get_recommended_dialog_filters, std::move(result),
                     std::move(promise));
      });
  td_->create_handler<GetSuggestedDialogFiltersQuery>(std::move(query_promise))->send();
}

void DialogFilterManager::on_get_recommended_dialog_filters(
    Result<vector<telegram_api::object_ptr<telegram_api::dialogFilterSuggested>>> result,
    Promise<td_api::object_ptr<td_api::recommendedChatFolders>> &&promise) {
  if (result.is_error()) {
    return promise.set_error(result.move_as_error());
  }
  CHECK(!td_->auth_manager_->is_bot());
  auto suggested_filters = result.move_as_ok();

  MultiPromiseActorSafe mpas{"LoadRecommendedFiltersMultiPromiseActor"};
  mpas.add_promise(Promise<Unit>());
  auto lock = mpas.get_promise();

  vector<RecommendedDialogFilter> filters;
  for (auto &suggested_filter : suggested_filters) {
    RecommendedDialogFilter recommended_dialog_filter;
    recommended_dialog_filter.dialog_filter =
        DialogFilter::get_dialog_filter(std::move(suggested_filter->filter_), false);
    if (recommended_dialog_filter.dialog_filter == nullptr) {
      continue;
    }
    load_dialog_filter(recommended_dialog_filter.dialog_filter.get(), mpas.get_promise());

    recommended_dialog_filter.description = std::move(suggested_filter->description_);
    filters.push_back(std::move(recommended_dialog_filter));
  }

  mpas.add_promise(PromiseCreator::lambda([actor_id = actor_id(this), filters = std::move(filters),
                                           promise = std::move(promise)](Result<Unit> &&result) mutable {
    send_closure(actor_id, &DialogFilterManager::on_load_recommended_dialog_filters, std::move(result),
                 std::move(filters), std::move(promise));
  }));
  lock.set_value(Unit());
}

void DialogFilterManager::on_load_recommended_dialog_filters(
    Result<Unit> &&result, vector<RecommendedDialogFilter> &&filters,
    Promise<td_api::object_ptr<td_api::recommendedChatFolders>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  if (result.is_error()) {
    return promise.set_error(result.move_as_error());
  }
  CHECK(!td_->auth_manager_->is_bot());

  auto chat_folders = transform(filters, [this](const RecommendedDialogFilter &recommended_dialog_filter) {
    return td_api::make_object<td_api::recommendedChatFolder>(
        get_chat_folder_object(recommended_dialog_filter.dialog_filter.get()), recommended_dialog_filter.description);
  });
  recommended_dialog_filters_ = std::move(filters);
  promise.set_value(td_api::make_object<td_api::recommendedChatFolders>(std::move(chat_folders)));
}

void DialogFilterManager::get_dialog_filter(DialogFilterId dialog_filter_id,
                                            Promise<td_api::object_ptr<td_api::chatFolder>> &&promise) {
  CHECK(!td_->auth_manager_->is_bot());
  if (!dialog_filter_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid chat folder identifier specified"));
  }

  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_value(nullptr);
  }

  auto load_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), dialog_filter_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &DialogFilterManager::on_load_dialog_filter, dialog_filter_id, std::move(promise));
      });
  load_dialog_filter(dialog_filter, std::move(load_promise));
}

void DialogFilterManager::on_load_dialog_filter(DialogFilterId dialog_filter_id,
                                                Promise<td_api::object_ptr<td_api::chatFolder>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  promise.set_value(get_chat_folder_object(dialog_filter_id));
}

void DialogFilterManager::load_dialog_filter(const DialogFilter *dialog_filter, Promise<Unit> &&promise) {
  CHECK(!td_->auth_manager_->is_bot());
  vector<InputDialogId> needed_dialog_ids;
  dialog_filter->for_each_dialog([&](const InputDialogId &input_dialog_id) {
    if (!td_->messages_manager_->have_dialog(input_dialog_id.get_dialog_id())) {
      needed_dialog_ids.push_back(input_dialog_id);
    }
  });

  vector<InputDialogId> input_dialog_ids;
  for (const auto &input_dialog_id : needed_dialog_ids) {
    auto dialog_id = input_dialog_id.get_dialog_id();
    // TODO load dialogs asynchronously
    if (!td_->dialog_manager_->have_dialog_force(dialog_id, "load_dialog_filter")) {
      if (dialog_id.get_type() == DialogType::SecretChat) {
        if (td_->dialog_manager_->have_dialog_info_force(dialog_id, "load_dialog_filter")) {
          td_->dialog_manager_->force_create_dialog(dialog_id, "load_dialog_filter");
        }
      } else {
        input_dialog_ids.push_back(input_dialog_id);
      }
    }
  }

  if (!input_dialog_ids.empty()) {
    return load_dialog_filter_dialogs(dialog_filter->get_dialog_filter_id(), std::move(input_dialog_ids),
                                      std::move(promise));
  }

  promise.set_value(Unit());
}

void DialogFilterManager::load_dialog_filter_dialogs(DialogFilterId dialog_filter_id,
                                                     vector<InputDialogId> &&input_dialog_ids,
                                                     Promise<Unit> &&promise) {
  const size_t MAX_SLICE_SIZE = 100;  // server-side limit
  MultiPromiseActorSafe mpas{"GetFilterDialogsOnServerMultiPromiseActor"};
  mpas.add_promise(std::move(promise));
  auto lock = mpas.get_promise();

  for (auto &slice_input_dialog_ids : vector_split(std::move(input_dialog_ids), MAX_SLICE_SIZE)) {
    auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), dialog_filter_id,
                                                 dialog_ids = InputDialogId::get_dialog_ids(slice_input_dialog_ids),
                                                 promise = mpas.get_promise()](Result<Unit> &&result) mutable {
      if (result.is_error()) {
        return promise.set_error(result.move_as_error());
      }
      send_closure(actor_id, &DialogFilterManager::on_load_dialog_filter_dialogs, dialog_filter_id,
                   std::move(dialog_ids), std::move(promise));
    });
    td_->create_handler<GetDialogsQuery>(std::move(query_promise))->send(std::move(slice_input_dialog_ids));
  }

  lock.set_value(Unit());
}

void DialogFilterManager::on_load_dialog_filter_dialogs(DialogFilterId dialog_filter_id, vector<DialogId> &&dialog_ids,
                                                        Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  td::remove_if(dialog_ids, [dialog_manager = td_->dialog_manager_.get()](DialogId dialog_id) {
    return dialog_manager->have_dialog_force(dialog_id, "on_load_dialog_filter_dialogs");
  });
  if (dialog_ids.empty()) {
    LOG(INFO) << "All chats from " << dialog_filter_id << " were loaded";
    return promise.set_value(Unit());
  }

  LOG(INFO) << "Failed to load chats " << dialog_ids << " from " << dialog_filter_id;

  auto old_dialog_filter = get_dialog_filter(dialog_filter_id);
  if (old_dialog_filter == nullptr) {
    return promise.set_value(Unit());
  }
  CHECK(is_update_chat_folders_sent_);

  delete_dialogs_from_filter(old_dialog_filter, std::move(dialog_ids), "on_load_dialog_filter_dialogs");

  promise.set_value(Unit());
}

void DialogFilterManager::load_input_dialog(const InputDialogId &input_dialog_id, Promise<Unit> &&promise) {
  td_->create_handler<GetDialogsQuery>(std::move(promise))->send({input_dialog_id});
}

void DialogFilterManager::delete_dialogs_from_filter(const DialogFilter *dialog_filter, vector<DialogId> &&dialog_ids,
                                                     const char *source) {
  if (dialog_ids.empty()) {
    return;
  }

  bool was_valid = dialog_filter->check_limits().is_ok();
  auto new_dialog_filter = td::make_unique<DialogFilter>(*dialog_filter);
  for (auto dialog_id : dialog_ids) {
    new_dialog_filter->remove_dialog_id(dialog_id);
  }
  if (new_dialog_filter->is_empty(false)) {
    delete_dialog_filter(dialog_filter->get_dialog_filter_id(), vector<DialogId>(), Promise<Unit>());
    return;
  }
  CHECK(!was_valid || new_dialog_filter->check_limits().is_ok());

  if (*new_dialog_filter != *dialog_filter) {
    LOG(INFO) << "Update " << *dialog_filter << " to " << *new_dialog_filter;
    do_edit_dialog_filter(std::move(new_dialog_filter), true, "delete_dialogs_from_filter");
  }
}

const DialogFilter *DialogFilterManager::get_server_dialog_filter(DialogFilterId dialog_filter_id) const {
  CHECK(!disable_get_dialog_filter_);
  for (const auto &dialog_filter : server_dialog_filters_) {
    if (dialog_filter->get_dialog_filter_id() == dialog_filter_id) {
      return dialog_filter.get();
    }
  }
  return nullptr;
}

DialogFilter *DialogFilterManager::get_dialog_filter(DialogFilterId dialog_filter_id) {
  CHECK(!disable_get_dialog_filter_);
  for (auto &dialog_filter : dialog_filters_) {
    if (dialog_filter->get_dialog_filter_id() == dialog_filter_id) {
      return dialog_filter.get();
    }
  }
  return nullptr;
}

const DialogFilter *DialogFilterManager::get_dialog_filter(DialogFilterId dialog_filter_id) const {
  CHECK(!disable_get_dialog_filter_);
  for (const auto &dialog_filter : dialog_filters_) {
    if (dialog_filter->get_dialog_filter_id() == dialog_filter_id) {
      return dialog_filter.get();
    }
  }
  return nullptr;
}

int32 DialogFilterManager::get_server_main_dialog_list_position() const {
  int32 current_position = 0;
  int32 current_server_position = 0;
  if (current_position == main_dialog_list_position_) {
    return current_server_position;
  }
  for (const auto &dialog_filter : dialog_filters_) {
    current_position++;
    if (!dialog_filter->is_empty(true)) {
      current_server_position++;
    }
    if (current_position == main_dialog_list_position_) {
      return current_server_position;
    }
  }
  LOG(WARNING) << "Failed to find server position for " << main_dialog_list_position_ << " in chat folders";
  return current_server_position;
}

double DialogFilterManager::get_dialog_filters_cache_time() {
  return DIALOG_FILTERS_CACHE_TIME * 0.0001 * Random::fast(9000, 11000);
}

void DialogFilterManager::schedule_dialog_filters_reload(double timeout) {
  if (td_->auth_manager_->is_bot()) {
    // just in case
    return;
  }
  if (timeout <= 0) {
    timeout = 0.0;
    if (dialog_filters_updated_date_ != 0) {
      dialog_filters_updated_date_ = 0;
      save_dialog_filters();
    }
  }
  LOG(INFO) << "Schedule reload of chat folders in " << timeout;
  reload_dialog_filters_timeout_.set_callback(std::move(DialogFilterManager::on_reload_dialog_filters_timeout));
  reload_dialog_filters_timeout_.set_callback_data(static_cast<void *>(this));
  reload_dialog_filters_timeout_.set_timeout_in(timeout);
}

void DialogFilterManager::on_reload_dialog_filters_timeout(void *dialog_filter_manager_ptr) {
  if (G()->close_flag()) {
    return;
  }
  auto dialog_filter_manager = static_cast<DialogFilterManager *>(dialog_filter_manager_ptr);
  send_closure_later(dialog_filter_manager->actor_id(dialog_filter_manager),
                     &DialogFilterManager::reload_dialog_filters);
}

void DialogFilterManager::reload_dialog_filters() {
  if (G()->close_flag()) {
    return;
  }
  CHECK(!td_->auth_manager_->is_bot());
  if (are_dialog_filters_being_synchronized_ || are_dialog_filters_being_reloaded_) {
    need_dialog_filters_reload_ = true;
    return;
  }
  LOG(INFO) << "Reload chat folders from server";
  are_dialog_filters_being_reloaded_ = true;
  need_dialog_filters_reload_ = false;
  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this)](Result<telegram_api::object_ptr<telegram_api::messages_dialogFilters>> r_filters) {
        send_closure(actor_id, &DialogFilterManager::on_get_dialog_filters, std::move(r_filters), false);
      });
  td_->create_handler<GetDialogFiltersQuery>(std::move(promise))->send();
}

void DialogFilterManager::on_get_dialog_filter(telegram_api::object_ptr<telegram_api::DialogFilter> filter) {
  CHECK(!td_->auth_manager_->is_bot());
  auto new_server_filter = DialogFilter::get_dialog_filter(std::move(filter), true);
  if (new_server_filter == nullptr) {
    return;
  }
  new_server_filter->sort_input_dialog_ids(td_, "on_get_dialog_filter 1");

  auto dialog_filter_id = new_server_filter->get_dialog_filter_id();
  auto old_filter = get_dialog_filter(dialog_filter_id);
  if (old_filter == nullptr) {
    return;
  }
  bool is_server_changed = false;
  bool is_changed = false;
  for (auto &old_server_filter : server_dialog_filters_) {
    if (old_server_filter->get_dialog_filter_id() == dialog_filter_id && *new_server_filter != *old_server_filter) {
      if (!DialogFilter::are_equivalent(*old_filter, *new_server_filter)) {
        auto new_filter =
            DialogFilter::merge_dialog_filter_changes(old_filter, old_server_filter.get(), new_server_filter.get());
        new_filter->sort_input_dialog_ids(td_, "on_get_dialog_filter");
        if (*new_filter != *old_filter) {
          is_changed = true;
          edit_dialog_filter(std::move(new_filter), "on_get_dialog_filter");
        }
      }
      is_server_changed = true;
      old_server_filter = std::move(new_server_filter);
      break;
    }
  }
  if (!is_server_changed) {
    return;
  }

  if (is_changed || !is_update_chat_folders_sent_) {
    send_update_chat_folders();
  }
  schedule_dialog_filters_reload(get_dialog_filters_cache_time());
  save_dialog_filters();

  if (need_synchronize_dialog_filters()) {
    synchronize_dialog_filters();
  }
}

void DialogFilterManager::on_get_dialog_filters(
    Result<telegram_api::object_ptr<telegram_api::messages_dialogFilters>> r_filters, bool dummy) {
  if (G()->close_flag()) {
    return;
  }

  are_dialog_filters_being_reloaded_ = false;
  CHECK(!td_->auth_manager_->is_bot());
  auto promises = std::move(dialog_filter_reload_queries_);
  dialog_filter_reload_queries_.clear();
  if (r_filters.is_error()) {
    if (!G()->is_expected_error(r_filters.error())) {
      LOG(WARNING) << "Receive error " << r_filters.error() << " for GetDialogFiltersQuery";
    }
    set_promises(promises);  // ignore error
    need_dialog_filters_reload_ = false;
    schedule_dialog_filters_reload(Random::fast(60, 5 * 60));
    return;
  }

  auto dialog_filters = r_filters.move_as_ok();
  auto filters = std::move(dialog_filters->filters_);
  vector<unique_ptr<DialogFilter>> new_server_dialog_filters;
  LOG(INFO) << "Receive chat folders from server: " << to_string(filters);
  std::unordered_set<DialogFilterId, DialogFilterIdHash> new_dialog_filter_ids;
  bool server_are_tags_enabled = dialog_filters->tags_enabled_;
  int32 server_main_dialog_list_position = -1;
  int32 position = 0;
  for (auto &filter : filters) {
    if (filter->get_id() == telegram_api::dialogFilterDefault::ID) {
      if (server_main_dialog_list_position == -1) {
        server_main_dialog_list_position = position;
      } else {
        LOG(ERROR) << "Receive duplicate dialogFilterDefault";
      }
      continue;
    }
    auto dialog_filter = DialogFilter::get_dialog_filter(std::move(filter), true);
    if (dialog_filter == nullptr) {
      continue;
    }
    if (!new_dialog_filter_ids.insert(dialog_filter->get_dialog_filter_id()).second) {
      LOG(ERROR) << "Receive duplicate " << dialog_filter->get_dialog_filter_id();
      continue;
    }

    dialog_filter->sort_input_dialog_ids(td_, "on_get_dialog_filters 1");
    new_server_dialog_filters.push_back(std::move(dialog_filter));
    position++;
  }
  if (server_main_dialog_list_position == -1) {
    LOG(ERROR) << "Receive no dialogFilterDefault";
    server_main_dialog_list_position = 0;
  }
  if (server_main_dialog_list_position != 0 && !td_->option_manager_->get_option_boolean("is_premium")) {
    LOG(INFO) << "Ignore server main chat list position " << server_main_dialog_list_position;
    server_main_dialog_list_position = 0;
  }
  if (server_are_tags_enabled && !td_->option_manager_->get_option_boolean("is_premium")) {
    LOG(INFO) << "Ignore server enabled tags";
    server_are_tags_enabled = false;
  }

  bool is_changed = false;
  dialog_filters_updated_date_ = G()->unix_time();
  if (server_dialog_filters_ != new_server_dialog_filters) {
    LOG(INFO) << "Change server chat folders from "
              << DialogFilter::get_dialog_filter_ids(server_dialog_filters_, server_main_dialog_list_position_)
              << " to "
              << DialogFilter::get_dialog_filter_ids(new_server_dialog_filters, server_main_dialog_list_position);
    FlatHashMap<DialogFilterId, const DialogFilter *, DialogFilterIdHash> old_server_dialog_filters;
    for (const auto &dialog_filter : server_dialog_filters_) {
      old_server_dialog_filters.emplace(dialog_filter->get_dialog_filter_id(), dialog_filter.get());
    }
    for (const auto &new_server_filter : new_server_dialog_filters) {
      auto dialog_filter_id = new_server_filter->get_dialog_filter_id();
      auto old_filter = get_dialog_filter(dialog_filter_id);
      auto it = old_server_dialog_filters.find(dialog_filter_id);
      if (it != old_server_dialog_filters.end()) {
        auto old_server_filter = it->second;
        if (*new_server_filter != *old_server_filter) {
          if (old_filter == nullptr) {
            // the filter was deleted, don't need to edit it
          } else {
            if (DialogFilter::are_equivalent(*old_filter, *new_server_filter)) {  // fast path
              // the filter was edited from this client, nothing to do
            } else {
              auto new_filter =
                  DialogFilter::merge_dialog_filter_changes(old_filter, old_server_filter, new_server_filter.get());
              new_filter->sort_input_dialog_ids(td_, "on_get_dialog_filters");
              if (*new_filter != *old_filter) {
                is_changed = true;
                edit_dialog_filter(std::move(new_filter), "on_get_dialog_filters");
              }
            }
          }
        }
        old_server_dialog_filters.erase(it);
      } else {
        if (old_filter == nullptr) {
          // the filter was added from another client
          is_changed = true;
          add_dialog_filter(make_unique<DialogFilter>(*new_server_filter), false, "on_get_dialog_filters");
        } else {
          // the filter was added from this client
          // after that it could be added from another client, or edited from this client, or edited from another client
          // prefer local value, so do nothing
          // effectively, ignore edits from other clients, if didn't receive UpdateDialogFilterQuery response
        }
      }
    }
    vector<DialogFilterId> left_old_server_dialog_filter_ids;
    for (const auto &dialog_filter : server_dialog_filters_) {
      if (old_server_dialog_filters.count(dialog_filter->get_dialog_filter_id()) == 0) {
        left_old_server_dialog_filter_ids.push_back(dialog_filter->get_dialog_filter_id());
      }
    }
    LOG(INFO) << "Still existing server chat folders: " << left_old_server_dialog_filter_ids;
    for (auto &old_server_filter : old_server_dialog_filters) {
      auto dialog_filter_id = old_server_filter.first;
      // deleted filter
      auto old_filter = get_dialog_filter(dialog_filter_id);
      if (old_filter == nullptr) {
        // the filter was deleted from this client, nothing to do
      } else {
        // the filter was deleted from another client
        // ignore edits done from the current client and just delete the filter
        is_changed = true;
        do_delete_dialog_filter(dialog_filter_id, "on_get_dialog_filters");
      }
    }
    bool is_order_changed = [&] {
      vector<DialogFilterId> new_server_dialog_filter_ids =
          DialogFilter::get_dialog_filter_ids(new_server_dialog_filters, -1);
      CHECK(new_server_dialog_filter_ids.size() >= left_old_server_dialog_filter_ids.size());
      new_server_dialog_filter_ids.resize(left_old_server_dialog_filter_ids.size());
      return new_server_dialog_filter_ids != left_old_server_dialog_filter_ids;
    }();
    if (is_order_changed) {  // if order is changed from this and other clients, prefer order from another client
      vector<DialogFilterId> new_dialog_filter_order;
      for (const auto &new_server_filter : new_server_dialog_filters) {
        auto dialog_filter_id = new_server_filter->get_dialog_filter_id();
        if (get_dialog_filter(dialog_filter_id) != nullptr) {
          new_dialog_filter_order.push_back(dialog_filter_id);
        }
      }
      is_changed = true;
      DialogFilter::set_dialog_filters_order(dialog_filters_, new_dialog_filter_order);
    }

    server_dialog_filters_ = std::move(new_server_dialog_filters);
  }
  if (server_main_dialog_list_position_ != server_main_dialog_list_position) {
    server_main_dialog_list_position_ = server_main_dialog_list_position;

    int32 main_dialog_list_position = -1;
    if (server_main_dialog_list_position == 0) {
      main_dialog_list_position = 0;
    } else {
      int32 current_position = 0;
      int32 current_server_position = 0;
      for (const auto &dialog_filter : dialog_filters_) {
        current_position++;
        if (!dialog_filter->is_empty(true)) {
          current_server_position++;
        }
        if (current_server_position == server_main_dialog_list_position) {
          main_dialog_list_position = current_position;
        }
      }
      if (main_dialog_list_position == -1) {
        LOG(INFO) << "Failed to find server position " << server_main_dialog_list_position << " in chat folders";
        main_dialog_list_position = static_cast<int32>(dialog_filters_.size());
      }
    }

    if (main_dialog_list_position != main_dialog_list_position_) {
      LOG(INFO) << "Change main chat list position from " << main_dialog_list_position_ << " to "
                << main_dialog_list_position;
      main_dialog_list_position_ = main_dialog_list_position;
      is_changed = true;
    }
  }
  if (server_are_tags_enabled_ != server_are_tags_enabled) {
    server_are_tags_enabled_ = server_are_tags_enabled;

    if (server_are_tags_enabled != are_tags_enabled_) {
      LOG(INFO) << "Change are_tags_enabled_ from " << are_tags_enabled_ << " to " << server_are_tags_enabled;
      are_tags_enabled_ = server_are_tags_enabled;
      is_changed = true;
    }
  }
  if (is_changed || !is_update_chat_folders_sent_) {
    send_update_chat_folders();
  }
  schedule_dialog_filters_reload(get_dialog_filters_cache_time());
  save_dialog_filters();

  if (need_synchronize_dialog_filters()) {
    synchronize_dialog_filters();
  }
  set_promises(promises);
}

bool DialogFilterManager::need_synchronize_dialog_filters() const {
  CHECK(!td_->auth_manager_->is_bot());
  size_t server_dialog_filter_count = 0;
  vector<DialogFilterId> dialog_filter_ids;
  for (const auto &dialog_filter : dialog_filters_) {
    if (dialog_filter->is_empty(true)) {
      continue;
    }

    server_dialog_filter_count++;
    auto server_dialog_filter = get_server_dialog_filter(dialog_filter->get_dialog_filter_id());
    if (server_dialog_filter == nullptr || !DialogFilter::are_equivalent(*server_dialog_filter, *dialog_filter)) {
      // need update dialog filter on server
      return true;
    }
    dialog_filter_ids.push_back(dialog_filter->get_dialog_filter_id());
  }
  if (server_dialog_filter_count != server_dialog_filters_.size()) {
    // need delete dialog filter on server
    return true;
  }
  if (dialog_filter_ids != DialogFilter::get_dialog_filter_ids(server_dialog_filters_, -1)) {
    // need reorder dialog filters on server
    return true;
  }
  if (get_server_main_dialog_list_position() != server_main_dialog_list_position_) {
    // need reorder main chat list on server
    return true;
  }
  if (are_tags_enabled_ != server_are_tags_enabled_) {
    // need enable/disable tags
    return true;
  }
  return false;
}

void DialogFilterManager::synchronize_dialog_filters() {
  if (G()->close_flag()) {
    return;
  }
  CHECK(!td_->auth_manager_->is_bot());
  if (are_dialog_filters_being_synchronized_ || are_dialog_filters_being_reloaded_) {
    return;
  }
  if (need_dialog_filters_reload_) {
    return reload_dialog_filters();
  }
  if (!need_synchronize_dialog_filters()) {
    // reload filters to repair their order if the server added new filter to the beginning of the list
    return reload_dialog_filters();
  }

  LOG(INFO) << "Synchronize chat folder changes with server having local "
            << DialogFilter::get_dialog_filter_ids(dialog_filters_, main_dialog_list_position_) << " and server "
            << DialogFilter::get_dialog_filter_ids(server_dialog_filters_, server_main_dialog_list_position_);
  for (const auto &server_dialog_filter : server_dialog_filters_) {
    if (get_dialog_filter(server_dialog_filter->get_dialog_filter_id()) == nullptr) {
      return delete_dialog_filter_on_server(server_dialog_filter->get_dialog_filter_id(),
                                            server_dialog_filter->is_shareable());
    }
  }

  vector<DialogFilterId> dialog_filter_ids;
  for (const auto &dialog_filter : dialog_filters_) {
    if (dialog_filter->is_empty(true)) {
      continue;
    }

    auto server_dialog_filter = get_server_dialog_filter(dialog_filter->get_dialog_filter_id());
    if (server_dialog_filter == nullptr || !DialogFilter::are_equivalent(*server_dialog_filter, *dialog_filter)) {
      return update_dialog_filter_on_server(make_unique<DialogFilter>(*dialog_filter));
    }
    dialog_filter_ids.push_back(dialog_filter->get_dialog_filter_id());
  }

  auto server_main_dialog_list_position = get_server_main_dialog_list_position();
  if (dialog_filter_ids != DialogFilter::get_dialog_filter_ids(server_dialog_filters_, -1) ||
      server_main_dialog_list_position != server_main_dialog_list_position_) {
    return reorder_dialog_filters_on_server(std::move(dialog_filter_ids), server_main_dialog_list_position);
  }

  if (are_tags_enabled_ != server_are_tags_enabled_) {
    return toggle_are_tags_enabled_on_server(are_tags_enabled_);
  }

  UNREACHABLE();
}

void DialogFilterManager::send_update_chat_folders() {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  is_update_chat_folders_sent_ = true;
  send_closure(G()->td(), &Td::send_update, get_update_chat_folders_object());
}

td_api::object_ptr<td_api::updateChatFolders> DialogFilterManager::get_update_chat_folders_object() const {
  CHECK(!td_->auth_manager_->is_bot());
  auto update = td_api::make_object<td_api::updateChatFolders>();
  for (const auto &dialog_filter : dialog_filters_) {
    update->chat_folders_.push_back(dialog_filter->get_chat_folder_info_object());
  }
  update->main_chat_list_position_ = main_dialog_list_position_;
  update->are_tags_enabled_ = are_tags_enabled_;
  return update;
}

void DialogFilterManager::create_dialog_filter(td_api::object_ptr<td_api::chatFolder> filter,
                                               Promise<td_api::object_ptr<td_api::chatFolderInfo>> &&promise) {
  auto max_dialog_filters = clamp(td_->option_manager_->get_option_integer("chat_folder_count_max"),
                                  static_cast<int64>(0), static_cast<int64>(100));
  if (dialog_filters_.size() >= narrow_cast<size_t>(max_dialog_filters)) {
    return promise.set_error(Status::Error(400, "The maximum number of chat folders exceeded"));
  }
  if (!is_update_chat_folders_sent_) {
    return promise.set_error(Status::Error(400, "Chat folders are not synchronized yet"));
  }

  DialogFilterId dialog_filter_id;
  do {
    auto min_id = static_cast<int>(DialogFilterId::min().get());
    auto max_id = static_cast<int>(DialogFilterId::max().get());
    dialog_filter_id = DialogFilterId(static_cast<int32>(Random::fast(min_id, max_id)));
  } while (get_dialog_filter(dialog_filter_id) != nullptr || get_server_dialog_filter(dialog_filter_id) != nullptr);

  TRY_RESULT_PROMISE(promise, dialog_filter,
                     DialogFilter::create_dialog_filter(td_, dialog_filter_id, std::move(filter)));
  if (dialog_filter->is_shareable()) {
    return promise.set_error(Status::Error(400, "Can't create shareable folder"));
  }
  auto chat_folder_info = dialog_filter->get_chat_folder_info_object();

  bool at_beginning = is_recommended_dialog_filter(dialog_filter.get());
  add_dialog_filter(std::move(dialog_filter), at_beginning, "create_dialog_filter");
  if (at_beginning && main_dialog_list_position_ != 0) {
    main_dialog_list_position_++;
  }
  save_dialog_filters();
  send_update_chat_folders();

  synchronize_dialog_filters();
  promise.set_value(std::move(chat_folder_info));
}

void DialogFilterManager::edit_dialog_filter(DialogFilterId dialog_filter_id,
                                             td_api::object_ptr<td_api::chatFolder> filter,
                                             Promise<td_api::object_ptr<td_api::chatFolderInfo>> &&promise) {
  CHECK(!td_->auth_manager_->is_bot());
  auto old_dialog_filter = get_dialog_filter(dialog_filter_id);
  if (old_dialog_filter == nullptr) {
    return promise.set_error(Status::Error(400, "Chat folder not found"));
  }
  CHECK(is_update_chat_folders_sent_);

  TRY_RESULT_PROMISE(promise, new_dialog_filter,
                     DialogFilter::create_dialog_filter(td_, dialog_filter_id, std::move(filter)));
  if (new_dialog_filter->is_shareable() != old_dialog_filter->is_shareable()) {
    return promise.set_error(Status::Error(400, "Can't convert a shareable folder to a non-shareable"));
  }
  new_dialog_filter->update_from(*old_dialog_filter);
  auto chat_folder_info = new_dialog_filter->get_chat_folder_info_object();

  if (*new_dialog_filter == *old_dialog_filter) {
    return promise.set_value(std::move(chat_folder_info));
  }

  do_edit_dialog_filter(std::move(new_dialog_filter), true, "edit_dialog_filter");

  promise.set_value(std::move(chat_folder_info));
}

void DialogFilterManager::do_edit_dialog_filter(unique_ptr<DialogFilter> &&filter, bool need_synchronize,
                                                const char *source) {
  edit_dialog_filter(std::move(filter), source);
  save_dialog_filters();
  send_update_chat_folders();

  if (need_synchronize) {
    synchronize_dialog_filters();
  }
}

void DialogFilterManager::update_dialog_filter_on_server(unique_ptr<DialogFilter> &&dialog_filter) {
  CHECK(!td_->auth_manager_->is_bot());
  CHECK(dialog_filter != nullptr);
  are_dialog_filters_being_synchronized_ = true;
  dialog_filter->remove_secret_chat_dialog_ids();
  auto dialog_filter_id = dialog_filter->get_dialog_filter_id();
  auto input_dialog_filter = dialog_filter->get_input_dialog_filter();

  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), dialog_filter = std::move(dialog_filter)](Result<Unit> result) mutable {
        send_closure(actor_id, &DialogFilterManager::on_update_dialog_filter, std::move(dialog_filter),
                     result.is_error() ? result.move_as_error() : Status::OK());
      });
  td_->create_handler<UpdateDialogFilterQuery>(std::move(promise))
      ->send(dialog_filter_id, std::move(input_dialog_filter));
}

void DialogFilterManager::on_update_dialog_filter(unique_ptr<DialogFilter> dialog_filter, Status result) {
  CHECK(!td_->auth_manager_->is_bot());
  if (result.is_error()) {
    // TODO rollback dialog_filters_ changes if error isn't 429
  } else {
    bool is_edited = false;
    for (auto &server_dialog_filter : server_dialog_filters_) {
      if (server_dialog_filter->get_dialog_filter_id() == dialog_filter->get_dialog_filter_id()) {
        if (*server_dialog_filter != *dialog_filter) {
          server_dialog_filter = std::move(dialog_filter);
        }
        is_edited = true;
        break;
      }
    }

    if (!is_edited) {
      bool at_beginning = is_recommended_dialog_filter(dialog_filter.get());
      if (at_beginning) {
        server_dialog_filters_.insert(server_dialog_filters_.begin(), std::move(dialog_filter));
      } else {
        server_dialog_filters_.push_back(std::move(dialog_filter));
      }
      if (at_beginning && server_main_dialog_list_position_ != 0) {
        server_main_dialog_list_position_++;
      }
    }
    save_dialog_filters();
  }

  are_dialog_filters_being_synchronized_ = false;
  synchronize_dialog_filters();
}

void DialogFilterManager::delete_dialog_filter(DialogFilterId dialog_filter_id, vector<DialogId> leave_dialog_ids,
                                               Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  CHECK(!td_->auth_manager_->is_bot());
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_value(Unit());
  }
  for (auto &leave_dialog_id : leave_dialog_ids) {
    if (!dialog_filter->is_dialog_included(leave_dialog_id)) {
      return promise.set_error(Status::Error(400, "The chat doesn't included in the folder"));
    }
  }
  if (!leave_dialog_ids.empty()) {
    MultiPromiseActorSafe mpas{"LeaveDialogsMultiPromiseActor"};
    mpas.add_promise(PromiseCreator::lambda(
        [actor_id = actor_id(this), dialog_filter_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
          if (result.is_error()) {
            return promise.set_error(result.move_as_error());
          }
          send_closure(actor_id, &DialogFilterManager::delete_dialog_filter, dialog_filter_id, vector<DialogId>(),
                       std::move(promise));
        }));
    auto lock = mpas.get_promise();

    for (auto &leave_dialog_id : leave_dialog_ids) {
      td_->dialog_participant_manager_->leave_dialog(leave_dialog_id, mpas.get_promise());
    }

    lock.set_value(Unit());
    return;
  }

  int32 position = do_delete_dialog_filter(dialog_filter_id, "delete_dialog_filter");
  if (main_dialog_list_position_ > position) {
    main_dialog_list_position_--;
  }
  save_dialog_filters();
  send_update_chat_folders();

  synchronize_dialog_filters();
  promise.set_value(Unit());
}

void DialogFilterManager::delete_dialog_filter_on_server(DialogFilterId dialog_filter_id, bool is_shareable) {
  CHECK(!td_->auth_manager_->is_bot());
  are_dialog_filters_being_synchronized_ = true;
  auto promise = PromiseCreator::lambda([actor_id = actor_id(this), dialog_filter_id](Result<Unit> result) {
    send_closure(actor_id, &DialogFilterManager::on_delete_dialog_filter, dialog_filter_id,
                 result.is_error() ? result.move_as_error() : Status::OK());
  });
  if (is_shareable) {
    td_->create_handler<LeaveChatlistQuery>(std::move(promise))->send(dialog_filter_id);
  } else {
    td_->create_handler<UpdateDialogFilterQuery>(std::move(promise))->send(dialog_filter_id, nullptr);
  }
}

void DialogFilterManager::on_delete_dialog_filter(DialogFilterId dialog_filter_id, Status result) {
  CHECK(!td_->auth_manager_->is_bot());
  if (result.is_error()) {
    // TODO rollback dialog_filters_ changes if error isn't 429
  } else {
    for (auto it = server_dialog_filters_.begin(); it != server_dialog_filters_.end(); ++it) {
      if ((*it)->get_dialog_filter_id() == dialog_filter_id) {
        server_dialog_filters_.erase(it);
        save_dialog_filters();
        break;
      }
    }
  }

  are_dialog_filters_being_synchronized_ = false;
  synchronize_dialog_filters();
}

void DialogFilterManager::get_leave_dialog_filter_suggestions(DialogFilterId dialog_filter_id,
                                                              Promise<td_api::object_ptr<td_api::chats>> &&promise) {
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_error(Status::Error(400, "Chat folder not found"));
  }
  if (!dialog_filter->is_shareable()) {
    return promise.set_value(td_api::make_object<td_api::chats>());
  }
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), dialog_filter_id, promise = std::move(promise)](
                                 Result<vector<telegram_api::object_ptr<telegram_api::Peer>>> &&result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &DialogFilterManager::on_get_leave_dialog_filter_suggestions, dialog_filter_id,
                     result.move_as_ok(), std::move(promise));
      });
  td_->create_handler<GetLeaveChatlistSuggestionsQuery>(std::move(query_promise))->send(dialog_filter_id);
}

void DialogFilterManager::on_get_leave_dialog_filter_suggestions(
    DialogFilterId dialog_filter_id, vector<telegram_api::object_ptr<telegram_api::Peer>> peers,
    Promise<td_api::object_ptr<td_api::chats>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_error(Status::Error(400, "Chat folder not found"));
  }
  if (!dialog_filter->is_shareable()) {
    return promise.set_value(td_api::make_object<td_api::chats>());
  }

  auto dialog_ids = td_->dialog_manager_->get_peers_dialog_ids(std::move(peers));
  td::remove_if(dialog_ids, [&](DialogId dialog_id) { return !dialog_filter->is_dialog_included(dialog_id); });
  promise.set_value(td_->dialog_manager_->get_chats_object(-1, dialog_ids, "on_get_leave_dialog_filter_suggestions"));
}

void DialogFilterManager::reorder_dialog_filters(vector<DialogFilterId> dialog_filter_ids,
                                                 int32 main_dialog_list_position, Promise<Unit> &&promise) {
  CHECK(!td_->auth_manager_->is_bot());

  for (auto dialog_filter_id : dialog_filter_ids) {
    auto dialog_filter = get_dialog_filter(dialog_filter_id);
    if (dialog_filter == nullptr) {
      return promise.set_error(Status::Error(400, "Chat folder not found"));
    }
  }
  std::unordered_set<DialogFilterId, DialogFilterIdHash> new_dialog_filter_ids_set(dialog_filter_ids.begin(),
                                                                                   dialog_filter_ids.end());
  if (new_dialog_filter_ids_set.size() != dialog_filter_ids.size()) {
    return promise.set_error(Status::Error(400, "Duplicate chat folders in the new list"));
  }
  if (main_dialog_list_position < 0 || main_dialog_list_position > static_cast<int32>(dialog_filters_.size())) {
    return promise.set_error(Status::Error(400, "Invalid main chat list position specified"));
  }
  if (!td_->option_manager_->get_option_boolean("is_premium")) {
    main_dialog_list_position = 0;
  }

  if (DialogFilter::set_dialog_filters_order(dialog_filters_, dialog_filter_ids) ||
      main_dialog_list_position != main_dialog_list_position_) {
    main_dialog_list_position_ = main_dialog_list_position;

    save_dialog_filters();
    send_update_chat_folders();

    synchronize_dialog_filters();
  }
  promise.set_value(Unit());
}

void DialogFilterManager::reorder_dialog_filters_on_server(vector<DialogFilterId> dialog_filter_ids,
                                                           int32 main_dialog_list_position) {
  CHECK(!td_->auth_manager_->is_bot());
  are_dialog_filters_being_synchronized_ = true;
  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), dialog_filter_ids, main_dialog_list_position](Result<Unit> result) mutable {
        send_closure(actor_id, &DialogFilterManager::on_reorder_dialog_filters, std::move(dialog_filter_ids),
                     main_dialog_list_position, result.is_error() ? result.move_as_error() : Status::OK());
      });
  td_->create_handler<UpdateDialogFiltersOrderQuery>(std::move(promise))
      ->send(dialog_filter_ids, main_dialog_list_position);
}

void DialogFilterManager::on_reorder_dialog_filters(vector<DialogFilterId> dialog_filter_ids,
                                                    int32 main_dialog_list_position, Status result) {
  CHECK(!td_->auth_manager_->is_bot());
  if (result.is_error()) {
    // TODO rollback dialog_filters_ changes if error isn't 429
  } else {
    if (DialogFilter::set_dialog_filters_order(server_dialog_filters_, std::move(dialog_filter_ids)) ||
        server_main_dialog_list_position_ != main_dialog_list_position) {
      server_main_dialog_list_position_ = main_dialog_list_position;
      save_dialog_filters();
    }
  }

  are_dialog_filters_being_synchronized_ = false;
  synchronize_dialog_filters();
}

void DialogFilterManager::toggle_dialog_filter_tags(bool are_tags_enabled, Promise<Unit> &&promise) {
  if (!td_->option_manager_->get_option_boolean("is_premium")) {
    if (!are_tags_enabled) {
      return promise.set_value(Unit());
    }
    return promise.set_error(Status::Error(400, "Method not available"));
  }

  if (are_tags_enabled_ != are_tags_enabled) {
    are_tags_enabled_ = are_tags_enabled;

    save_dialog_filters();
    send_update_chat_folders();

    synchronize_dialog_filters();
  }
  promise.set_value(Unit());
}

void DialogFilterManager::toggle_are_tags_enabled_on_server(bool are_tags_enabled) {
  CHECK(!td_->auth_manager_->is_bot());
  are_dialog_filters_being_synchronized_ = true;
  auto promise = PromiseCreator::lambda([actor_id = actor_id(this), are_tags_enabled](Result<Unit> result) mutable {
    send_closure(actor_id, &DialogFilterManager::on_toggle_are_tags_enabled, are_tags_enabled,
                 result.is_error() ? result.move_as_error() : Status::OK());
  });
  td_->create_handler<ToggleDialogFilterTagsQuery>(std::move(promise))->send(are_tags_enabled);
}

void DialogFilterManager::on_toggle_are_tags_enabled(bool are_tags_enabled, Status result) {
  CHECK(!td_->auth_manager_->is_bot());
  if (result.is_error()) {
    are_tags_enabled_ = !are_tags_enabled;
  } else {
    if (server_are_tags_enabled_ != are_tags_enabled) {
      server_are_tags_enabled_ = are_tags_enabled;
      save_dialog_filters();
    }
  }

  are_dialog_filters_being_synchronized_ = false;
  synchronize_dialog_filters();
}

void DialogFilterManager::add_dialog_filter(unique_ptr<DialogFilter> dialog_filter, bool at_beginning,
                                            const char *source) {
  if (td_->auth_manager_->is_bot()) {
    // just in case
    return;
  }

  CHECK(dialog_filter != nullptr);
  auto dialog_filter_id = dialog_filter->get_dialog_filter_id();
  LOG(INFO) << "Add " << dialog_filter_id << " from " << source;
  CHECK(get_dialog_filter(dialog_filter_id) == nullptr);
  if (at_beginning) {
    dialog_filters_.insert(dialog_filters_.begin(), std::move(dialog_filter));
  } else {
    dialog_filters_.push_back(std::move(dialog_filter));
  }

  td_->messages_manager_->add_dialog_list_for_dialog_filter(dialog_filter_id);
}

void DialogFilterManager::edit_dialog_filter(unique_ptr<DialogFilter> new_dialog_filter, const char *source) {
  if (td_->auth_manager_->is_bot()) {
    // just in case
    return;
  }

  CHECK(new_dialog_filter != nullptr);
  LOG(INFO) << "Edit " << new_dialog_filter->get_dialog_filter_id() << " from " << source;
  for (auto &old_dialog_filter : dialog_filters_) {
    if (old_dialog_filter->get_dialog_filter_id() == new_dialog_filter->get_dialog_filter_id()) {
      CHECK(*old_dialog_filter != *new_dialog_filter);

      disable_get_dialog_filter_ = true;  // to ensure crash if get_dialog_filter is called

      td_->messages_manager_->edit_dialog_list_for_dialog_filter(old_dialog_filter, std::move(new_dialog_filter),
                                                                 disable_get_dialog_filter_, source);
      return;
    }
  }
  UNREACHABLE();
}

int32 DialogFilterManager::do_delete_dialog_filter(DialogFilterId dialog_filter_id, const char *source) {
  if (td_->auth_manager_->is_bot()) {
    // just in case
    return -1;
  }

  LOG(INFO) << "Delete " << dialog_filter_id << " from " << source;
  for (auto it = dialog_filters_.begin(); it != dialog_filters_.end(); ++it) {
    if ((*it)->get_dialog_filter_id() == dialog_filter_id) {
      auto position = static_cast<int32>(it - dialog_filters_.begin());
      td_->messages_manager_->delete_dialog_list_for_dialog_filter(dialog_filter_id, source);
      dialog_filters_.erase(it);
      return position;
    }
  }
  UNREACHABLE();
  return -1;
}

void DialogFilterManager::save_dialog_filters() {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  DialogFiltersLogEvent log_event;
  log_event.server_are_tags_enabled = server_are_tags_enabled_;
  log_event.are_tags_enabled = are_tags_enabled_;
  log_event.server_main_dialog_list_position = server_main_dialog_list_position_;
  log_event.main_dialog_list_position = main_dialog_list_position_;
  log_event.updated_date = dialog_filters_updated_date_;
  log_event.server_dialog_filters_in = &server_dialog_filters_;
  log_event.dialog_filters_in = &dialog_filters_;

  LOG(INFO) << "Save server chat folders "
            << DialogFilter::get_dialog_filter_ids(server_dialog_filters_, server_main_dialog_list_position_)
            << " and local chat folders "
            << DialogFilter::get_dialog_filter_ids(dialog_filters_, main_dialog_list_position_);

  G()->td_db()->get_binlog_pmc()->set("dialog_filters", log_event_store(log_event).as_slice().str());
}

void DialogFilterManager::get_dialogs_for_dialog_filter_invite_link(
    DialogFilterId dialog_filter_id, Promise<td_api::object_ptr<td_api::chats>> promise) {
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_error(Status::Error(400, "Chat folder not found"));
  }

  auto load_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), dialog_filter_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &DialogFilterManager::do_get_dialogs_for_dialog_filter_invite_link, dialog_filter_id,
                     std::move(promise));
      });
  load_dialog_filter(dialog_filter, std::move(load_promise));
}

void DialogFilterManager::do_get_dialogs_for_dialog_filter_invite_link(
    DialogFilterId dialog_filter_id, Promise<td_api::object_ptr<td_api::chats>> promise) {
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_error(Status::Error(400, "Chat folder not found"));
  }

  promise.set_value(td_->dialog_manager_->get_chats_object(-1, dialog_filter->get_dialogs_for_invite_link(td_),
                                                           "do_get_dialogs_for_dialog_filter_invite_link"));
}

void DialogFilterManager::create_dialog_filter_invite_link(
    DialogFilterId dialog_filter_id, string invite_link_name, vector<DialogId> dialog_ids,
    Promise<td_api::object_ptr<td_api::chatFolderInviteLink>> promise) {
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_error(Status::Error(400, "Chat folder not found"));
  }
  vector<tl_object_ptr<telegram_api::InputPeer>> input_peers;
  input_peers.reserve(dialog_ids.size());
  for (auto &dialog_id : dialog_ids) {
    if (!td_->dialog_manager_->have_dialog_force(dialog_id, "create_dialog_filter_invite_link")) {
      return promise.set_error(Status::Error(400, "Chat not found"));
    }
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      return promise.set_error(Status::Error(400, "Have no access to the chat"));
    }
    input_peers.push_back(std::move(input_peer));
  }
  if (input_peers.empty()) {
    return promise.set_error(Status::Error(400, "At least one chat must be included"));
  }
  td_->create_handler<ExportChatlistInviteQuery>(std::move(promise))
      ->send(dialog_filter_id, invite_link_name, std::move(input_peers));
}

void DialogFilterManager::get_dialog_filter_invite_links(
    DialogFilterId dialog_filter_id, Promise<td_api::object_ptr<td_api::chatFolderInviteLinks>> promise) {
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_error(Status::Error(400, "Chat folder not found"));
  }
  if (!dialog_filter->is_shareable()) {
    return promise.set_value(td_api::make_object<td_api::chatFolderInviteLinks>());
  }
  td_->create_handler<GetExportedChatlistInvitesQuery>(std::move(promise))->send(dialog_filter_id);
}

void DialogFilterManager::edit_dialog_filter_invite_link(
    DialogFilterId dialog_filter_id, string invite_link, string invite_link_name, vector<DialogId> dialog_ids,
    Promise<td_api::object_ptr<td_api::chatFolderInviteLink>> promise) {
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_error(Status::Error(400, "Chat folder not found"));
  }
  vector<tl_object_ptr<telegram_api::InputPeer>> input_peers;
  input_peers.reserve(dialog_ids.size());
  for (auto &dialog_id : dialog_ids) {
    if (!td_->dialog_manager_->have_dialog_force(dialog_id, "edit_dialog_filter_invite_link")) {
      return promise.set_error(Status::Error(400, "Chat not found"));
    }
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      return promise.set_error(Status::Error(400, "Have no access to the chat"));
    }
    input_peers.push_back(std::move(input_peer));
  }
  if (input_peers.empty()) {
    return promise.set_error(Status::Error(400, "At least one chat must be included"));
  }
  td_->create_handler<EditExportedChatlistInviteQuery>(std::move(promise))
      ->send(dialog_filter_id, invite_link, invite_link_name, std::move(input_peers));
}

void DialogFilterManager::delete_dialog_filter_invite_link(DialogFilterId dialog_filter_id, string invite_link,
                                                           Promise<Unit> promise) {
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_error(Status::Error(400, "Chat folder not found"));
  }
  td_->create_handler<DeleteExportedChatlistInviteQuery>(std::move(promise))->send(dialog_filter_id, invite_link);
}

void DialogFilterManager::check_dialog_filter_invite_link(
    const string &invite_link, Promise<td_api::object_ptr<td_api::chatFolderInviteLinkInfo>> &&promise) {
  if (!DialogFilterInviteLink::is_valid_invite_link(invite_link)) {
    return promise.set_error(Status::Error(400, "Wrong invite link"));
  }

  CHECK(!invite_link.empty());
  td_->create_handler<CheckChatlistInviteQuery>(std::move(promise))->send(invite_link);
}

void DialogFilterManager::on_get_chatlist_invite(
    const string &invite_link, telegram_api::object_ptr<telegram_api::chatlists_ChatlistInvite> &&invite_ptr,
    Promise<td_api::object_ptr<td_api::chatFolderInviteLinkInfo>> &&promise) {
  CHECK(invite_ptr != nullptr);
  LOG(INFO) << "Receive information about chat folder invite link " << invite_link << ": " << to_string(invite_ptr);

  td_api::object_ptr<td_api::chatFolderInfo> info;
  vector<telegram_api::object_ptr<telegram_api::Peer>> missing_peers;
  vector<telegram_api::object_ptr<telegram_api::Peer>> already_peers;
  vector<telegram_api::object_ptr<telegram_api::Chat>> chats;
  vector<telegram_api::object_ptr<telegram_api::User>> users;
  switch (invite_ptr->get_id()) {
    case telegram_api::chatlists_chatlistInviteAlready::ID: {
      auto invite = move_tl_object_as<telegram_api::chatlists_chatlistInviteAlready>(invite_ptr);
      DialogFilterId dialog_filter_id = DialogFilterId(invite->filter_id_);
      if (!dialog_filter_id.is_valid()) {
        return promise.set_error(Status::Error(500, "Receive invalid chat folder identifier"));
      }
      auto dialog_filter = get_dialog_filter(dialog_filter_id);
      if (dialog_filter == nullptr) {
        reload_dialog_filters();
        return promise.set_error(Status::Error(500, "Receive unknown chat folder"));
      }
      info = dialog_filter->get_chat_folder_info_object();
      missing_peers = std::move(invite->missing_peers_);
      already_peers = std::move(invite->already_peers_);
      chats = std::move(invite->chats_);
      users = std::move(invite->users_);
      break;
    }
    case telegram_api::chatlists_chatlistInvite::ID: {
      auto invite = move_tl_object_as<telegram_api::chatlists_chatlistInvite>(invite_ptr);
      auto icon_name = DialogFilter::get_icon_name_by_emoji(invite->emoticon_);
      if (icon_name.empty()) {
        icon_name = "Custom";
      }

      auto title = get_formatted_text(nullptr, std::move(invite->title_), true, false, "chatlistInvite");
      keep_only_custom_emoji(title);
      auto name = td_api::make_object<td_api::chatFolderName>(get_formatted_text_object(nullptr, title, true, -1),
                                                              !invite->title_noanimate_);
      info = td_api::make_object<td_api::chatFolderInfo>(
          0, std::move(name), td_api::make_object<td_api::chatFolderIcon>(icon_name), -1, true, false);
      missing_peers = std::move(invite->peers_);
      chats = std::move(invite->chats_);
      users = std::move(invite->users_);
      break;
    }
    default:
      UNREACHABLE();
      break;
  }

  td_->user_manager_->on_get_users(std::move(users), "on_get_chatlist_invite");
  td_->chat_manager_->on_get_chats(std::move(chats), "on_get_chatlist_invite");

  auto missing_dialog_ids = td_->dialog_manager_->get_peers_dialog_ids(std::move(missing_peers), true);
  auto already_dialog_ids = td_->dialog_manager_->get_peers_dialog_ids(std::move(already_peers));
  promise.set_value(td_api::make_object<td_api::chatFolderInviteLinkInfo>(
      std::move(info), td_->dialog_manager_->get_chat_ids_object(missing_dialog_ids, "chatFolderInviteLinkInfo 1"),
      td_->dialog_manager_->get_chat_ids_object(already_dialog_ids, "chatFolderInviteLinkInfo 1")));
}

void DialogFilterManager::add_dialog_filter_by_invite_link(const string &invite_link, vector<DialogId> dialog_ids,
                                                           Promise<Unit> &&promise) {
  if (!DialogFilterInviteLink::is_valid_invite_link(invite_link)) {
    return promise.set_error(Status::Error(400, "Wrong invite link"));
  }
  for (auto dialog_id : dialog_ids) {
    TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Know,
                                                                          "add_dialog_filter_by_invite_link"));
  }

  CHECK(!invite_link.empty());
  td_->create_handler<JoinChatlistInviteQuery>(std::move(promise))->send(invite_link, std::move(dialog_ids));
}

void DialogFilterManager::get_dialog_filter_new_chats(DialogFilterId dialog_filter_id,
                                                      Promise<td_api::object_ptr<td_api::chats>> &&promise) {
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_error(Status::Error(400, "Chat folder not found"));
  }
  if (!dialog_filter->is_shareable()) {
    return promise.set_value(td_api::make_object<td_api::chats>());
  }
  td_->create_handler<GetChatlistUpdatesQuery>(std::move(promise))->send(dialog_filter_id);
}

void DialogFilterManager::add_dialog_filter_new_chats(DialogFilterId dialog_filter_id, vector<DialogId> dialog_ids,
                                                      Promise<Unit> &&promise) {
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return promise.set_error(Status::Error(400, "Chat folder not found"));
  }
  if (!dialog_filter->is_shareable()) {
    return promise.set_error(Status::Error(400, "Chat folder must be shareable"));
  }
  for (auto dialog_id : dialog_ids) {
    TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Know,
                                                                          "add_dialog_filter_new_chats"));
  }

  if (dialog_ids.empty()) {
    td_->create_handler<HideChatlistUpdatesQuery>(std::move(promise))->send(dialog_filter_id);
  } else {
    td_->create_handler<JoinChatlistUpdatesQuery>(std::move(promise))->send(dialog_filter_id, std::move(dialog_ids));
  }
}

void DialogFilterManager::set_dialog_filter_has_my_invite_links(DialogFilterId dialog_filter_id,
                                                                bool has_my_invite_links) {
  auto dialog_filter = get_dialog_filter(dialog_filter_id);
  if (dialog_filter == nullptr) {
    return;
  }
  dialog_filter->set_has_my_invite_links(has_my_invite_links);
}

void DialogFilterManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (have_dialog_filters()) {
    updates.push_back(get_update_chat_folders_object());
  }
}

}  // namespace td
