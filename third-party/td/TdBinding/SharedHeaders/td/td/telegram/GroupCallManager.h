//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/DialogParticipant.h"
#include "td/telegram/GroupCallId.h"
#include "td/telegram/GroupCallParticipant.h"
#include "td/telegram/GroupCallParticipantOrder.h"
#include "td/telegram/InputGroupCallId.h"
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

class Td;

class GroupCallManager final : public Actor {
 public:
  GroupCallManager(Td *td, ActorShared<> parent);
  GroupCallManager(const GroupCallManager &) = delete;
  GroupCallManager &operator=(const GroupCallManager &) = delete;
  GroupCallManager(GroupCallManager &&) = delete;
  GroupCallManager &operator=(GroupCallManager &&) = delete;
  ~GroupCallManager() final;

  Result<InputGroupCallId> get_input_group_call_id(GroupCallId group_call_id);

  bool is_group_call_being_joined(InputGroupCallId input_group_call_id) const;

  bool is_group_call_joined(InputGroupCallId input_group_call_id) const;

  GroupCallId get_group_call_id(InputGroupCallId input_group_call_id, DialogId dialog_id);

  void get_group_call_join_as(DialogId dialog_id, Promise<td_api::object_ptr<td_api::messageSenders>> &&promise);

  void set_group_call_default_join_as(DialogId dialog_id, DialogId as_dialog_id, Promise<Unit> &&promise);

  void create_voice_chat(DialogId dialog_id, string title, int32 start_date, bool is_rtmp_stream,
                         Promise<GroupCallId> &&promise);

  void get_voice_chat_rtmp_stream_url(DialogId dialog_id, bool revoke,
                                      Promise<td_api::object_ptr<td_api::rtmpUrl>> &&promise);

  void get_group_call(GroupCallId group_call_id, Promise<td_api::object_ptr<td_api::groupCall>> &&promise);

  void on_update_group_call_rights(InputGroupCallId input_group_call_id);

  void reload_group_call(InputGroupCallId input_group_call_id,
                         Promise<td_api::object_ptr<td_api::groupCall>> &&promise);

  void get_group_call_streams(GroupCallId group_call_id,
                              Promise<td_api::object_ptr<td_api::groupCallStreams>> &&promise);

  void get_group_call_stream_segment(GroupCallId group_call_id, int64 time_offset, int32 scale, int32 channel_id,
                                     td_api::object_ptr<td_api::GroupCallVideoQuality> quality,
                                     Promise<string> &&promise);

  void start_scheduled_group_call(GroupCallId group_call_id, Promise<Unit> &&promise);

  void join_group_call(GroupCallId group_call_id, DialogId as_dialog_id, int32 audio_source, string &&payload,
                       bool is_muted, bool is_my_video_enabled, const string &invite_hash, int64 key_fingerprint,
                       Promise<string> &&promise);

  void start_group_call_screen_sharing(GroupCallId group_call_id, int32 audio_source, string &&payload,
                                       Promise<string> &&promise);

  void end_group_call_screen_sharing(GroupCallId group_call_id, Promise<Unit> &&promise);

  void set_group_call_title(GroupCallId group_call_id, string title, Promise<Unit> &&promise);

  void toggle_group_call_is_my_video_paused(GroupCallId group_call_id, bool is_my_video_paused,
                                            Promise<Unit> &&promise);

  void toggle_group_call_is_my_video_enabled(GroupCallId group_call_id, bool is_my_video_enabled,
                                             Promise<Unit> &&promise);

  void toggle_group_call_is_my_presentation_paused(GroupCallId group_call_id, bool is_my_presentation_paused,
                                                   Promise<Unit> &&promise);

  void toggle_group_call_start_subscribed(GroupCallId group_call_id, bool start_subscribed, Promise<Unit> &&promise);

  void toggle_group_call_mute_new_participants(GroupCallId group_call_id, bool mute_new_participants,
                                               Promise<Unit> &&promise);

  void revoke_group_call_invite_link(GroupCallId group_call_id, Promise<Unit> &&promise);

  void invite_group_call_participants(GroupCallId group_call_id, vector<UserId> &&user_ids, Promise<Unit> &&promise);

  void get_group_call_invite_link(GroupCallId group_call_id, bool can_self_unmute, Promise<string> &&promise);

  void toggle_group_call_recording(GroupCallId group_call_id, bool is_enabled, string title, bool record_video,
                                   bool use_portrait_orientation, Promise<Unit> &&promise);

  void set_group_call_participant_is_speaking(GroupCallId group_call_id, int32 audio_source, bool is_speaking,
                                              Promise<Unit> &&promise, int32 date = 0);

  void toggle_group_call_participant_is_muted(GroupCallId group_call_id, DialogId dialog_id, bool is_muted,
                                              Promise<Unit> &&promise);

  void set_group_call_participant_volume_level(GroupCallId group_call_id, DialogId dialog_id, int32 volume_level,
                                               Promise<Unit> &&promise);

  void toggle_group_call_participant_is_hand_raised(GroupCallId group_call_id, DialogId dialog_id, bool is_hand_raised,
                                                    Promise<Unit> &&promise);

  void load_group_call_participants(GroupCallId group_call_id, int32 limit, Promise<Unit> &&promise);

  void leave_group_call(GroupCallId group_call_id, Promise<Unit> &&promise);

  void discard_group_call(GroupCallId group_call_id, Promise<Unit> &&promise);

  void on_update_dialog_about(DialogId dialog_id, const string &about, bool from_server);

  void on_update_group_call_connection(string &&connection_params);

  void on_update_group_call(tl_object_ptr<telegram_api::GroupCall> group_call_ptr, DialogId dialog_id);

  void on_user_speaking_in_group_call(GroupCallId group_call_id, DialogId dialog_id, bool is_muted_by_admin, int32 date,
                                      bool is_recursive = false);

  void on_get_group_call_participants(InputGroupCallId input_group_call_id,
                                      tl_object_ptr<telegram_api::phone_groupParticipants> &&participants, bool is_load,
                                      const string &offset);

  void on_update_group_call_participants(InputGroupCallId input_group_call_id,
                                         vector<tl_object_ptr<telegram_api::groupCallParticipant>> &&participants,
                                         int32 version, bool is_recursive = false);

  void process_join_group_call_response(InputGroupCallId input_group_call_id, uint64 generation,
                                        tl_object_ptr<telegram_api::Updates> &&updates, Promise<Unit> &&promise);

  void process_join_group_call_presentation_response(InputGroupCallId input_group_call_id, uint64 generation,
                                                     tl_object_ptr<telegram_api::Updates> &&updates, Status status);

 private:
  struct GroupCall;
  struct GroupCallParticipants;
  struct GroupCallRecentSpeakers;
  struct PendingJoinRequest;

  static constexpr int32 RECENT_SPEAKER_TIMEOUT = 60 * 60;
  static constexpr int32 UPDATE_GROUP_CALL_PARTICIPANT_ORDER_TIMEOUT = 10;
  static constexpr int32 CHECK_GROUP_CALL_IS_JOINED_TIMEOUT = 10;
  static constexpr size_t MAX_TITLE_LENGTH = 64;  // server side limit for group call/call record title length

  void tear_down() final;

  static void on_update_group_call_participant_order_timeout_callback(void *group_call_manager_ptr,
                                                                      int64 group_call_id_int);

  void on_update_group_call_participant_order_timeout(GroupCallId group_call_id);

  static void on_check_group_call_is_joined_timeout_callback(void *group_call_manager_ptr, int64 group_call_id_int);

  void on_check_group_call_is_joined_timeout(GroupCallId group_call_id);

  static void on_pending_send_speaking_action_timeout_callback(void *group_call_manager_ptr, int64 group_call_id_int);

  void on_send_speaking_action_timeout(GroupCallId group_call_id);

  static void on_recent_speaker_update_timeout_callback(void *group_call_manager_ptr, int64 group_call_id_int);

  void on_recent_speaker_update_timeout(GroupCallId group_call_id);

  static void on_sync_participants_timeout_callback(void *group_call_manager_ptr, int64 group_call_id_int);

  void on_sync_participants_timeout(GroupCallId group_call_id);

  GroupCallId get_next_group_call_id(InputGroupCallId input_group_call_id);

  GroupCall *add_group_call(InputGroupCallId input_group_call_id, DialogId dialog_id);

  const GroupCall *get_group_call(InputGroupCallId input_group_call_id) const;
  GroupCall *get_group_call(InputGroupCallId input_group_call_id);

  Status can_join_group_calls(DialogId dialog_id) const;

  Status can_manage_group_calls(DialogId dialog_id) const;

  bool can_manage_group_call(InputGroupCallId input_group_call_id) const;

  bool get_group_call_can_self_unmute(InputGroupCallId input_group_call_id) const;

  bool get_group_call_joined_date_asc(InputGroupCallId input_group_call_id) const;

  void on_voice_chat_created(DialogId dialog_id, InputGroupCallId input_group_call_id, Promise<GroupCallId> &&promise);

  void finish_get_group_call(InputGroupCallId input_group_call_id,
                             Result<tl_object_ptr<telegram_api::phone_groupCall>> &&result);

  void finish_get_group_call_streams(InputGroupCallId input_group_call_id, int32 audio_source,
                                     Result<td_api::object_ptr<td_api::groupCallStreams>> &&result,
                                     Promise<td_api::object_ptr<td_api::groupCallStreams>> &&promise);

  void finish_get_group_call_stream_segment(InputGroupCallId input_group_call_id, int32 audio_source,
                                            Result<string> &&result, Promise<string> &&promise);

  void finish_check_group_call_is_joined(InputGroupCallId input_group_call_id, int32 audio_source,
                                         Result<Unit> &&result);

  static const string &get_group_call_title(const GroupCall *group_call);

  static bool get_group_call_is_joined(const GroupCall *group_call);

  static bool get_group_call_start_subscribed(const GroupCall *group_call);

  static bool get_group_call_is_my_video_paused(const GroupCall *group_call);

  static bool get_group_call_is_my_video_enabled(const GroupCall *group_call);

  static bool get_group_call_is_my_presentation_paused(const GroupCall *group_call);

  static bool get_group_call_mute_new_participants(const GroupCall *group_call);

  static int32 get_group_call_record_start_date(const GroupCall *group_call);

  static bool get_group_call_is_video_recorded(const GroupCall *group_call);

  static bool get_group_call_has_recording(const GroupCall *group_call);

  static bool get_group_call_can_enable_video(const GroupCall *group_call);

  static bool is_group_call_active(const GroupCall *group_call);

  bool need_group_call_participants(InputGroupCallId input_group_call_id) const;

  static bool need_group_call_participants(const GroupCall *group_call);

  bool process_pending_group_call_participant_updates(InputGroupCallId input_group_call_id);

  bool is_my_audio_source(InputGroupCallId input_group_call_id, const GroupCall *group_call, int32 audio_source) const;

  void sync_group_call_participants(InputGroupCallId input_group_call_id);

  void on_sync_group_call_participants(InputGroupCallId input_group_call_id,
                                       Result<tl_object_ptr<telegram_api::phone_groupCall>> &&result);

  static GroupCallParticipantOrder get_real_participant_order(bool can_self_unmute,
                                                              const GroupCallParticipant &participant,
                                                              const GroupCallParticipants *participants);

  void process_my_group_call_participant(InputGroupCallId input_group_call_id, GroupCallParticipant &&participant);

  void process_group_call_participants(InputGroupCallId group_call_id,
                                       vector<tl_object_ptr<telegram_api::groupCallParticipant>> &&participants,
                                       int32 version, const string &offset, bool is_load, bool is_sync);

  static bool update_group_call_participant_can_be_muted(bool can_manage, const GroupCallParticipants *participants,
                                                         GroupCallParticipant &participant);

  void update_group_call_participants_can_be_muted(InputGroupCallId input_group_call_id, bool can_manage,
                                                   GroupCallParticipants *participants);

  void update_group_call_participants_order(InputGroupCallId input_group_call_id, bool can_self_unmute,
                                            GroupCallParticipants *participants, const char *source);

  // returns participant_count_diff and video_participant_count_diff
  std::pair<int32, int32> process_group_call_participant(InputGroupCallId group_call_id,
                                                         GroupCallParticipant &&participant);

  void on_add_group_call_participant(InputGroupCallId input_group_call_id, DialogId participant_dialog_id);

  void on_remove_group_call_participant(InputGroupCallId input_group_call_id, DialogId participant_dialog_id);

  void try_load_group_call_administrators(InputGroupCallId input_group_call_id, DialogId dialog_id);

  void finish_load_group_call_administrators(InputGroupCallId input_group_call_id, Result<DialogParticipants> &&result);

  int32 cancel_join_group_call_request(InputGroupCallId input_group_call_id, GroupCall *group_call);

  int32 cancel_join_group_call_presentation_request(InputGroupCallId input_group_call_id);

  bool on_join_group_call_response(InputGroupCallId input_group_call_id, string json_response);

  void finish_join_group_call(InputGroupCallId input_group_call_id, uint64 generation, Status error);

  void process_group_call_after_join_requests(InputGroupCallId input_group_call_id, const char *source);

  GroupCallParticipants *add_group_call_participants(InputGroupCallId input_group_call_id, const char *source);

  GroupCallParticipant *get_group_call_participant(InputGroupCallId input_group_call_id, DialogId dialog_id,
                                                   const char *source);

  GroupCallParticipant *get_group_call_participant(GroupCallParticipants *group_call_participants,
                                                   DialogId dialog_id) const;

  void send_edit_group_call_title_query(InputGroupCallId input_group_call_id, const string &title);

  void on_edit_group_call_title(InputGroupCallId input_group_call_id, const string &title, Result<Unit> &&result);

  void send_toggle_group_call_start_subscription_query(InputGroupCallId input_group_call_id, bool start_subscribed);

  void on_toggle_group_call_start_subscription(InputGroupCallId input_group_call_id, bool start_subscribed,
                                               Result<Unit> &&result);

  void send_toggle_group_call_is_my_video_paused_query(InputGroupCallId input_group_call_id, DialogId as_dialog_id,
                                                       bool is_my_video_paused);

  void on_toggle_group_call_is_my_video_paused(InputGroupCallId input_group_call_id, bool is_my_video_paused,
                                               Result<Unit> &&result);

  void send_toggle_group_call_is_my_video_enabled_query(InputGroupCallId input_group_call_id, DialogId as_dialog_id,
                                                        bool is_my_video_enabled);

  void on_toggle_group_call_is_my_video_enabled(InputGroupCallId input_group_call_id, bool is_my_video_enabled,
                                                Result<Unit> &&result);

  void send_toggle_group_call_is_my_presentation_paused_query(InputGroupCallId input_group_call_id,
                                                              DialogId as_dialog_id, bool is_my_presentation_paused);

  void on_toggle_group_call_is_my_presentation_paused(InputGroupCallId input_group_call_id,
                                                      bool is_my_presentation_paused, Result<Unit> &&result);

  void send_toggle_group_call_mute_new_participants_query(InputGroupCallId input_group_call_id,
                                                          bool mute_new_participants);

  void on_toggle_group_call_mute_new_participants(InputGroupCallId input_group_call_id, bool mute_new_participants,
                                                  Result<Unit> &&result);

  void send_toggle_group_call_recording_query(InputGroupCallId input_group_call_id, bool is_enabled,
                                              const string &title, bool record_video, bool use_portrait_orientation,
                                              uint64 generation);

  void on_toggle_group_call_recording(InputGroupCallId input_group_call_id, uint64 generation, Result<Unit> &&result);

  void on_toggle_group_call_participant_is_muted(InputGroupCallId input_group_call_id, DialogId dialog_id,
                                                 uint64 generation, Promise<Unit> &&promise);

  void on_set_group_call_participant_volume_level(InputGroupCallId input_group_call_id, DialogId dialog_id,
                                                  uint64 generation, Promise<Unit> &&promise);

  void on_toggle_group_call_participant_is_hand_raised(InputGroupCallId input_group_call_id, DialogId dialog_id,
                                                       uint64 generation, Promise<Unit> &&promise);

  void on_group_call_left(InputGroupCallId input_group_call_id, int32 audio_source, bool need_rejoin);

  void on_group_call_left_impl(GroupCall *group_call, bool need_rejoin, const char *source);

  InputGroupCallId update_group_call(const tl_object_ptr<telegram_api::GroupCall> &group_call_ptr, DialogId dialog_id);

  void on_receive_group_call_version(InputGroupCallId input_group_call_id, int32 version, bool immediate_sync = false);

  void on_participant_speaking_in_group_call(InputGroupCallId input_group_call_id,
                                             const GroupCallParticipant &participant);

  void remove_recent_group_call_speaker(InputGroupCallId input_group_call_id, DialogId dialog_id);

  void on_group_call_recent_speakers_updated(const GroupCall *group_call, GroupCallRecentSpeakers *recent_speakers);

  DialogId set_group_call_participant_is_speaking_by_source(InputGroupCallId input_group_call_id, int32 audio_source,
                                                            bool is_speaking, int32 date);

  bool try_clear_group_call_participants(InputGroupCallId input_group_call_id);

  bool set_group_call_participant_count(GroupCall *group_call, int32 count, const char *source,
                                        bool force_update = false);

  bool set_group_call_unmuted_video_count(GroupCall *group_call, int32 count, const char *source);

  void update_group_call_dialog(const GroupCall *group_call, const char *source, bool force);

  vector<td_api::object_ptr<td_api::groupCallRecentSpeaker>> get_recent_speakers(const GroupCall *group_call,
                                                                                 bool for_update);

  static tl_object_ptr<td_api::updateGroupCall> get_update_group_call_object(
      const GroupCall *group_call, vector<td_api::object_ptr<td_api::groupCallRecentSpeaker>> recent_speakers);

  static tl_object_ptr<td_api::groupCall> get_group_call_object(
      const GroupCall *group_call, vector<td_api::object_ptr<td_api::groupCallRecentSpeaker>> recent_speakers);

  tl_object_ptr<td_api::updateGroupCallParticipant> get_update_group_call_participant_object(
      GroupCallId group_call_id, const GroupCallParticipant &participant);

  void send_update_group_call(const GroupCall *group_call, const char *source);

  void send_update_group_call_participant(GroupCallId group_call_id, const GroupCallParticipant &participant,
                                          const char *source);

  void send_update_group_call_participant(InputGroupCallId input_group_call_id, const GroupCallParticipant &participant,
                                          const char *source);

  Td *td_;
  ActorShared<> parent_;

  GroupCallId max_group_call_id_;

  vector<InputGroupCallId> input_group_call_ids_;

  FlatHashMap<InputGroupCallId, unique_ptr<GroupCall>, InputGroupCallIdHash> group_calls_;

  string pending_group_call_join_params_;

  FlatHashMap<InputGroupCallId, unique_ptr<GroupCallParticipants>, InputGroupCallIdHash> group_call_participants_;
  FlatHashMap<DialogId, vector<InputGroupCallId>, DialogIdHash> participant_id_to_group_call_id_;

  FlatHashMap<GroupCallId, unique_ptr<GroupCallRecentSpeakers>, GroupCallIdHash> group_call_recent_speakers_;

  FlatHashMap<InputGroupCallId, vector<Promise<td_api::object_ptr<td_api::groupCall>>>, InputGroupCallIdHash>
      load_group_call_queries_;

  FlatHashMap<InputGroupCallId, unique_ptr<PendingJoinRequest>, InputGroupCallIdHash> pending_join_requests_;
  FlatHashMap<InputGroupCallId, unique_ptr<PendingJoinRequest>, InputGroupCallIdHash>
      pending_join_presentation_requests_;
  uint64 join_group_request_generation_ = 0;

  uint64 toggle_recording_generation_ = 0;

  uint64 toggle_is_muted_generation_ = 0;

  uint64 set_volume_level_generation_ = 0;

  uint64 toggle_is_hand_raised_generation_ = 0;

  MultiTimeout update_group_call_participant_order_timeout_{"UpdateGroupCallParticipantOrderTimeout"};
  MultiTimeout check_group_call_is_joined_timeout_{"CheckGroupCallIsJoinedTimeout"};
  MultiTimeout pending_send_speaking_action_timeout_{"PendingSendSpeakingActionTimeout"};
  MultiTimeout recent_speaker_update_timeout_{"RecentSpeakerUpdateTimeout"};
  MultiTimeout sync_participants_timeout_{"SyncParticipantsTimeout"};
};

}  // namespace td
