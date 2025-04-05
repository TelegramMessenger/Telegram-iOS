//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/DialogAdministrator.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogInviteLink.h"
#include "td/telegram/DialogParticipant.h"
#include "td/telegram/DialogParticipantFilter.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <utility>

namespace td {

class ChannelParticipantFilter;

class Td;

class DialogParticipantManager final : public Actor {
 public:
  DialogParticipantManager(Td *td, ActorShared<> parent);
  DialogParticipantManager(const DialogParticipantManager &) = delete;
  DialogParticipantManager &operator=(const DialogParticipantManager &) = delete;
  DialogParticipantManager(DialogParticipantManager &&) = delete;
  DialogParticipantManager &operator=(DialogParticipantManager &&) = delete;
  ~DialogParticipantManager() final;

  void update_user_online_member_count(UserId user_id);

  void update_dialog_online_member_count(const vector<DialogParticipant> &participants, DialogId dialog_id,
                                         bool is_from_server);

  void on_update_dialog_online_member_count(DialogId dialog_id, int32 online_member_count, bool is_from_server);

  void add_cached_channel_participants(ChannelId channel_id, const vector<UserId> &added_user_ids,
                                       UserId inviter_user_id, int32 date);

  void delete_cached_channel_participant(ChannelId channel_id, UserId deleted_user_id);

  void update_cached_channel_participant_status(ChannelId channel_id, UserId user_id,
                                                const DialogParticipantStatus &status);

  void on_dialog_opened(DialogId dialog_id);

  void on_dialog_closed(DialogId dialog_id);

  void fix_pending_join_requests(DialogId dialog_id, int32 &pending_join_request_count,
                                 vector<UserId> &pending_join_request_user_ids) const;

  void get_dialog_join_requests(DialogId dialog_id, const string &invite_link, const string &query,
                                td_api::object_ptr<td_api::chatJoinRequest> offset_request, int32 limit,
                                Promise<td_api::object_ptr<td_api::chatJoinRequests>> &&promise);

  void process_dialog_join_request(DialogId dialog_id, UserId user_id, bool approve, Promise<Unit> &&promise);

  void process_dialog_join_requests(DialogId dialog_id, const string &invite_link, bool approve,
                                    Promise<Unit> &&promise);

  void speculative_update_dialog_administrators(DialogId dialog_id, UserId user_id,
                                                const DialogParticipantStatus &new_status,
                                                const DialogParticipantStatus &old_status);

  void on_update_dialog_administrators(DialogId dialog_id, vector<DialogAdministrator> &&administrators,
                                       bool have_access, bool from_database);

  void get_dialog_administrators(DialogId dialog_id, Promise<td_api::object_ptr<td_api::chatAdministrators>> &&promise);

  void reload_dialog_administrators(DialogId dialog_id, const vector<DialogAdministrator> &dialog_administrators,
                                    Promise<td_api::object_ptr<td_api::chatAdministrators>> &&promise);

  void on_update_bot_stopped(UserId user_id, int32 date, bool is_stopped, bool force = false);

  void on_update_chat_participant(ChatId chat_id, UserId user_id, int32 date, DialogInviteLink invite_link,
                                  bool via_join_request,
                                  telegram_api::object_ptr<telegram_api::ChatParticipant> old_participant,
                                  telegram_api::object_ptr<telegram_api::ChatParticipant> new_participant);

  void on_update_channel_participant(ChannelId channel_id, UserId user_id, int32 date, DialogInviteLink invite_link,
                                     bool via_join_request, bool via_dialog_filter_invite_link,
                                     telegram_api::object_ptr<telegram_api::ChannelParticipant> old_participant,
                                     telegram_api::object_ptr<telegram_api::ChannelParticipant> new_participant);

  void on_update_chat_invite_requester(DialogId dialog_id, UserId user_id, string about, int32 date,
                                       DialogInviteLink invite_link);

  void get_dialog_participant(DialogId dialog_id, DialogId participant_dialog_id,
                              Promise<td_api::object_ptr<td_api::chatMember>> &&promise);

  void get_channel_participant(ChannelId channel_id, DialogId participant_dialog_id,
                               Promise<DialogParticipant> &&promise);

  void get_channel_participants(ChannelId channel_id, td_api::object_ptr<td_api::SupergroupMembersFilter> &&filter,
                                string additional_query, int32 offset, int32 limit, int32 additional_limit,
                                Promise<DialogParticipants> &&promise);

  void search_dialog_participants(DialogId dialog_id, const string &query, int32 limit, DialogParticipantFilter filter,
                                  Promise<DialogParticipants> &&promise);

  static Promise<td_api::object_ptr<td_api::failedToAddMembers>> wrap_failed_to_add_members_promise(
      Promise<Unit> &&promise);

  void add_dialog_participant(DialogId dialog_id, UserId user_id, int32 forward_limit,
                              Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise);

  void add_dialog_participants(DialogId dialog_id, const vector<UserId> &user_ids,
                               Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise);

  void set_dialog_participant_status(DialogId dialog_id, DialogId participant_dialog_id,
                                     td_api::object_ptr<td_api::ChatMemberStatus> &&chat_member_status,
                                     Promise<Unit> &&promise);

  void ban_dialog_participant(DialogId dialog_id, DialogId participant_dialog_id, int32 banned_until_date,
                              bool revoke_messages, Promise<Unit> &&promise);

  void leave_dialog(DialogId dialog_id, Promise<Unit> &&promise);

  void on_set_channel_participant_status(ChannelId channel_id, DialogId participant_dialog_id,
                                         DialogParticipantStatus status);

  bool have_channel_participant_cache(ChannelId channel_id) const;

  void add_channel_participant_to_cache(ChannelId channel_id, const DialogParticipant &dialog_participant,
                                        bool allow_replace);

  void drop_channel_participant_cache(ChannelId channel_id);

  struct CanTransferOwnershipResult {
    enum class Type : uint8 { Ok, PasswordNeeded, PasswordTooFresh, SessionTooFresh };
    Type type = Type::Ok;
    int32 retry_after = 0;
  };
  void can_transfer_ownership(Promise<CanTransferOwnershipResult> &&promise);

  static td_api::object_ptr<td_api::CanTransferOwnershipResult> get_can_transfer_ownership_result_object(
      CanTransferOwnershipResult result);

  void transfer_dialog_ownership(DialogId dialog_id, UserId user_id, const string &password, Promise<Unit> &&promise);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  static constexpr int32 ONLINE_MEMBER_COUNT_CACHE_EXPIRE_TIME = 30 * 60;

  static constexpr int32 ONLINE_MEMBER_COUNT_UPDATE_TIME = 5 * 60;

  static constexpr int32 CHANNEL_PARTICIPANT_CACHE_TIME = 1800;  // some reasonable limit

  static constexpr int32 MAX_GET_CHANNEL_PARTICIPANTS = 200;  // server side limit

  void tear_down() final;

  static void on_update_dialog_online_member_count_timeout_callback(void *dialog_participant_manager_ptr,
                                                                    int64 dialog_id_int);

  void set_dialog_online_member_count(DialogId dialog_id, int32 online_member_count, bool is_from_server,
                                      const char *source);

  void on_update_dialog_online_member_count_timeout(DialogId dialog_id);

  void send_update_chat_online_member_count(DialogId dialog_id, int32 online_member_count) const;

  Status can_manage_dialog_join_requests(DialogId dialog_id);

  td_api::object_ptr<td_api::chatAdministrators> get_chat_administrators_object(
      const vector<DialogAdministrator> &dialog_administrators);

  static string get_dialog_administrators_database_key(DialogId dialog_id);

  void on_load_dialog_administrators_from_database(DialogId dialog_id, string value,
                                                   Promise<td_api::object_ptr<td_api::chatAdministrators>> &&promise);

  void on_load_administrator_users_finished(DialogId dialog_id, vector<DialogAdministrator> administrators,
                                            Result<Unit> result,
                                            Promise<td_api::object_ptr<td_api::chatAdministrators>> &&promise);

  void on_reload_dialog_administrators(DialogId dialog_id,
                                       Promise<td_api::object_ptr<td_api::chatAdministrators>> &&promise);

  void send_update_chat_member(DialogId dialog_id, UserId agent_user_id, int32 date,
                               const DialogInviteLink &invite_link, bool via_join_request,
                               bool via_dialog_filter_invite_link, const DialogParticipant &old_dialog_participant,
                               const DialogParticipant &new_dialog_participant);

  void do_get_dialog_participant(DialogId dialog_id, DialogId participant_dialog_id,
                                 Promise<DialogParticipant> &&promise);

  void finish_get_dialog_participant(DialogParticipant &&dialog_participant,
                                     Promise<td_api::object_ptr<td_api::chatMember>> &&promise);

  void finish_get_channel_participant(ChannelId channel_id, DialogId participant_dialog_id,
                                      DialogParticipant &&dialog_participant, Promise<DialogParticipant> &&promise);

  std::pair<int32, vector<DialogId>> search_among_dialogs(const vector<DialogId> &dialog_ids, const string &query,
                                                          int32 limit) const;

  DialogParticipants search_private_chat_participants(UserId peer_user_id, const string &query, int32 limit,
                                                      DialogParticipantFilter filter) const;

  void search_chat_participants(ChatId chat_id, const string &query, int32 limit, DialogParticipantFilter filter,
                                Promise<DialogParticipants> &&promise);

  void do_search_chat_participants(ChatId chat_id, const string &query, int32 limit, DialogParticipantFilter filter,
                                   Promise<DialogParticipants> &&promise);

  void on_get_channel_participants(
      ChannelId channel_id, ChannelParticipantFilter &&filter, int32 offset, int32 limit, string additional_query,
      int32 additional_limit,
      telegram_api::object_ptr<telegram_api::channels_channelParticipants> &&channel_participants,
      Promise<DialogParticipants> &&promise);

  void set_chat_participant_status(ChatId chat_id, UserId user_id, DialogParticipantStatus status, bool is_recursive,
                                   Promise<Unit> &&promise);

  void add_chat_participant(ChatId chat_id, UserId user_id, int32 forward_limit,
                            Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise);

  void send_edit_chat_admin_query(ChatId chat_id, UserId user_id, bool is_administrator, Promise<Unit> &&promise);

  void delete_chat_participant(ChatId chat_id, UserId user_id, bool revoke_messages, Promise<Unit> &&promise);

  void add_channel_participant(ChannelId channel_id, UserId user_id, const DialogParticipantStatus &old_status,
                               Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise);

  void on_join_channel(ChannelId channel_id, bool was_speculatively_updated, DialogParticipantStatus &&old_status,
                       DialogParticipantStatus &&new_status, Result<Unit> &&result);

  void add_channel_participants(ChannelId channel_id, const vector<UserId> &user_ids,
                                Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise);

  void set_channel_participant_status(ChannelId channel_id, DialogId participant_dialog_id,
                                      td_api::object_ptr<td_api::ChatMemberStatus> &&chat_member_status,
                                      Promise<Unit> &&promise);

  void set_channel_participant_status_impl(ChannelId channel_id, DialogId participant_dialog_id,
                                           DialogParticipantStatus new_status, DialogParticipantStatus old_status,
                                           Promise<Unit> &&promise);

  void promote_channel_participant(ChannelId channel_id, UserId user_id, const DialogParticipantStatus &new_status,
                                   const DialogParticipantStatus &old_status, Promise<Unit> &&promise);

  void restrict_channel_participant(ChannelId channel_id, DialogId participant_dialog_id,
                                    DialogParticipantStatus &&new_status, DialogParticipantStatus &&old_status,
                                    Promise<Unit> &&promise);

  void speculative_add_channel_user(ChannelId channel_id, UserId user_id, const DialogParticipantStatus &new_status,
                                    const DialogParticipantStatus &old_status);

  void update_channel_participant_status_cache(ChannelId channel_id, DialogId participant_dialog_id,
                                               DialogParticipantStatus &&dialog_participant_status);

  const DialogParticipant *get_channel_participant_from_cache(ChannelId channel_id, DialogId participant_dialog_id);

  static void on_channel_participant_cache_timeout_callback(void *dialog_participant_manager_ptr,
                                                            int64 channel_id_long);

  void on_channel_participant_cache_timeout(ChannelId channel_id);

  void set_cached_channel_participants(ChannelId channel_id, vector<DialogParticipant> participants);

  void drop_cached_channel_participants(ChannelId channel_id);

  void update_channel_online_member_count(ChannelId channel_id, bool is_from_server);

  void transfer_channel_ownership(ChannelId channel_id, UserId user_id,
                                  tl_object_ptr<telegram_api::InputCheckPasswordSRP> input_check_password,
                                  Promise<Unit> &&promise);

  struct OnlineMemberCountInfo {
    int32 online_member_count = 0;
    double update_time = 0;
    bool is_update_sent = false;
  };
  FlatHashMap<DialogId, OnlineMemberCountInfo, DialogIdHash> dialog_online_member_counts_;

  struct UserOnlineMemberDialogs {
    FlatHashMap<DialogId, int32, DialogIdHash> online_member_dialogs_;  // dialog_id -> time
  };
  FlatHashMap<UserId, unique_ptr<UserOnlineMemberDialogs>, UserIdHash> user_online_member_dialogs_;

  FlatHashMap<DialogId, vector<DialogAdministrator>, DialogIdHash> dialog_administrators_;

  // bot-administrators only
  struct ChannelParticipantInfo {
    DialogParticipant participant_;

    int32 last_access_date_ = 0;
  };
  struct ChannelParticipants {
    FlatHashMap<DialogId, ChannelParticipantInfo, DialogIdHash> participants_;
  };
  FlatHashMap<ChannelId, ChannelParticipants, ChannelIdHash> channel_participants_;

  FlatHashMap<ChannelId, vector<DialogParticipant>, ChannelIdHash> cached_channel_participants_;

  FlatHashMap<ChannelId, vector<Promise<td_api::object_ptr<td_api::failedToAddMembers>>>, ChannelIdHash>
      join_channel_queries_;

  MultiTimeout update_dialog_online_member_count_timeout_{"UpdateDialogOnlineMemberCountTimeout"};
  MultiTimeout channel_participant_cache_timeout_{"ChannelParticipantCacheTimeout"};

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
