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
#include "td/telegram/InputGroupCall.h"
#include "td/telegram/InputGroupCallId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"

#include "td/e2e/e2e_api.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <utility>

namespace td {

struct GroupCallJoinParameters;
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

  void create_video_chat(DialogId dialog_id, string title, int32 start_date, bool is_rtmp_stream,
                         Promise<GroupCallId> &&promise);

  void create_group_call(td_api::object_ptr<td_api::groupCallJoinParameters> &&join_parameters,
                         Promise<td_api::object_ptr<td_api::groupCallInfo>> &&promise);

  void get_video_chat_rtmp_stream_url(DialogId dialog_id, bool revoke,
                                      Promise<td_api::object_ptr<td_api::rtmpUrl>> &&promise);

  void get_group_call(GroupCallId group_call_id, Promise<td_api::object_ptr<td_api::groupCall>> &&promise);

  void on_update_group_call_rights(InputGroupCallId input_group_call_id);

  void reload_group_call(InputGroupCallId input_group_call_id,
                         Promise<td_api::object_ptr<td_api::groupCall>> &&promise);

  void get_group_call_streams(GroupCallId group_call_id,
                              Promise<td_api::object_ptr<td_api::videoChatStreams>> &&promise);

  void get_group_call_stream_segment(GroupCallId group_call_id, int64 time_offset, int32 scale, int32 channel_id,
                                     td_api::object_ptr<td_api::GroupCallVideoQuality> quality,
                                     Promise<string> &&promise);

  void start_scheduled_group_call(GroupCallId group_call_id, Promise<Unit> &&promise);

  void join_group_call(td_api::object_ptr<td_api::InputGroupCall> &&api_input_group_call,
                       td_api::object_ptr<td_api::groupCallJoinParameters> &&join_parameters,
                       Promise<td_api::object_ptr<td_api::groupCallInfo>> &&promise);

  void join_video_chat(GroupCallId group_call_id, DialogId as_dialog_id,
                       td_api::object_ptr<td_api::groupCallJoinParameters> &&join_parameters, const string &invite_hash,
                       Promise<string> &&promise);

  void encrypt_group_call_data(GroupCallId group_call_id,
                               td_api::object_ptr<td_api::GroupCallDataChannel> &&data_channel, string &&data,
                               int32 unencrypted_prefix_size, Promise<string> &&promise);

  void decrypt_group_call_data(GroupCallId group_call_id, DialogId participant_dialog_id,
                               td_api::object_ptr<td_api::GroupCallDataChannel> &&data_channel, string &&data,
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

  void invite_group_call_participant(GroupCallId group_call_id, UserId user_id, bool is_video,
                                     Promise<td_api::object_ptr<td_api::InviteGroupCallParticipantResult>> &&promise);

  void decline_group_call_invitation(MessageFullId message_full_id, Promise<Unit> &&promise);

  void delete_group_call_participants(GroupCallId group_call_id, const vector<int64> &user_ids, bool is_ban,
                                      Promise<Unit> &&promise);

  void do_delete_group_call_participants(InputGroupCallId input_group_call_id, vector<int64> user_ids, bool is_ban,
                                         Promise<Unit> &&promise);

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

  void get_group_call_participants(td_api::object_ptr<td_api::InputGroupCall> input_group_call, int32 limit,
                                   Promise<td_api::object_ptr<td_api::groupCallParticipants>> &&promise);

  void load_group_call_participants(GroupCallId group_call_id, int32 limit, Promise<Unit> &&promise);

  void leave_group_call(GroupCallId group_call_id, Promise<Unit> &&promise);

  void discard_group_call(GroupCallId group_call_id, Promise<Unit> &&promise);

  void on_update_dialog_about(DialogId dialog_id, const string &about, bool from_server);

  void on_update_group_call_connection(string &&connection_params);

  void on_update_group_call_chain_blocks(InputGroupCallId input_group_call_id, int32 sub_chain_id,
                                         vector<string> &&blocks, int32 next_offset);

  void on_update_group_call(tl_object_ptr<telegram_api::GroupCall> group_call_ptr, DialogId dialog_id);

  void on_user_speaking_in_group_call(GroupCallId group_call_id, DialogId dialog_id, bool is_muted_by_admin, int32 date,
                                      bool is_recursive = false);

  void on_get_group_call_participants(InputGroupCallId input_group_call_id,
                                      tl_object_ptr<telegram_api::phone_groupParticipants> &&participants, bool is_load,
                                      const string &offset);

  void on_update_group_call_participants(InputGroupCallId input_group_call_id,
                                         vector<tl_object_ptr<telegram_api::groupCallParticipant>> &&participants,
                                         int32 version, bool is_recursive = false);

  void process_join_video_chat_response(InputGroupCallId input_group_call_id, uint64 generation,
                                        tl_object_ptr<telegram_api::Updates> &&updates, Promise<Unit> &&promise);

  void process_join_group_call_presentation_response(InputGroupCallId input_group_call_id, uint64 generation,
                                                     tl_object_ptr<telegram_api::Updates> &&updates, Status status);

  void register_group_call(MessageFullId message_full_id, const char *source);

  void unregister_group_call(MessageFullId message_full_id, const char *source);

 private:
  struct GroupCall;
  struct GroupCallParticipants;
  struct GroupCallRecentSpeakers;
  struct PendingJoinRequest;
  struct PendingJoinPresentationRequest;

  static constexpr int32 RECENT_SPEAKER_TIMEOUT = 60 * 60;
  static constexpr int32 UPDATE_GROUP_CALL_PARTICIPANT_ORDER_TIMEOUT = 10;
  static constexpr int32 CHECK_GROUP_CALL_IS_JOINED_TIMEOUT = 10;
  static constexpr int32 GROUP_CALL_BLOCK_POLL_TIMEOUT = 10;
  static constexpr size_t MAX_TITLE_LENGTH = 64;  // server-side limit for group call/call record title length
  static constexpr size_t BLOCK_POLL_COUNT = 100;

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

  static void on_update_group_call_timeout_callback(void *group_call_manager_ptr, int64 call_id);

  void on_update_group_call_timeout(int64 call_id);

  static void on_poll_group_call_blocks_timeout_callback(void *group_call_manager_ptr, int64 call_id);

  void on_poll_group_call_blocks_timeout(int64 call_id);

  void on_update_group_call_message(int64 call_id);

  GroupCallId get_next_group_call_id(InputGroupCallId input_group_call_id);

  GroupCall *add_group_call(InputGroupCallId input_group_call_id, DialogId dialog_id);

  const GroupCall *get_group_call(InputGroupCallId input_group_call_id) const;
  GroupCall *get_group_call(InputGroupCallId input_group_call_id);

  Status can_join_group_calls(DialogId dialog_id) const;

  Status can_manage_group_calls(DialogId dialog_id) const;

  bool can_manage_group_call(InputGroupCallId input_group_call_id, bool allow_owned) const;

  bool can_manage_group_call(const GroupCall *group_call, bool allow_owned) const;

  bool get_group_call_can_self_unmute(InputGroupCallId input_group_call_id) const;

  bool get_group_call_joined_date_asc(InputGroupCallId input_group_call_id) const;

  void on_video_chat_created(DialogId dialog_id, InputGroupCallId input_group_call_id, Promise<GroupCallId> &&promise);

  void finish_get_group_call(InputGroupCallId input_group_call_id,
                             Result<tl_object_ptr<telegram_api::phone_groupCall>> &&result);

  void finish_get_group_call_streams(InputGroupCallId input_group_call_id, int32 audio_source,
                                     Result<td_api::object_ptr<td_api::videoChatStreams>> &&result,
                                     Promise<td_api::object_ptr<td_api::videoChatStreams>> &&promise);

  void finish_get_group_call_stream_segment(InputGroupCallId input_group_call_id, int32 audio_source,
                                            Result<string> &&result, Promise<string> &&promise);

  void finish_check_group_call_is_joined(InputGroupCallId input_group_call_id, int32 audio_source,
                                         Result<Unit> &&result);

  void sync_conference_call_participants(InputGroupCallId input_group_call_id,
                                         vector<int64> &&blockchain_participant_ids);

  void on_sync_conference_call_participants(InputGroupCallId input_group_call_id,
                                            vector<int64> &&blockchain_participant_ids,
                                            vector<int64> &&server_participant_ids);

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

  bool need_group_call_participants(InputGroupCallId input_group_call_id, const GroupCall *group_call) const;

  bool process_pending_group_call_participant_updates(InputGroupCallId input_group_call_id);

  bool is_my_audio_source(InputGroupCallId input_group_call_id, const GroupCall *group_call, int32 audio_source) const;

  void on_create_group_call(int32 random_id, Result<telegram_api::object_ptr<telegram_api::Updates>> &&r_updates,
                            Promise<td_api::object_ptr<td_api::groupCallInfo>> &&promise);

  void on_get_group_call_join_payload(InputGroupCallId input_group_call_id, string &&payload);

  void on_create_group_call_finished(InputGroupCallId input_group_call_id, bool is_join,
                                     Promise<td_api::object_ptr<td_api::groupCallInfo>> &&promise);

  void sync_group_call_participants(InputGroupCallId input_group_call_id);

  void on_sync_group_call_participants(InputGroupCallId input_group_call_id,
                                       Result<tl_object_ptr<telegram_api::phone_groupCall>> &&result);

  static GroupCallParticipantOrder get_real_participant_order(bool my_can_self_unmute,
                                                              const GroupCallParticipant &participant,
                                                              const GroupCallParticipants *participants);

  void process_my_group_call_participant(InputGroupCallId input_group_call_id, GroupCallParticipant &&participant);

  void process_group_call_participants(InputGroupCallId group_call_id,
                                       vector<tl_object_ptr<telegram_api::groupCallParticipant>> &&participants,
                                       int32 version, const string &offset, bool is_load, bool is_sync);

  static bool update_group_call_participant_can_be_muted(bool can_manage, const GroupCallParticipants *participants,
                                                         GroupCallParticipant &participant, bool force_is_admin);

  void update_group_call_participants_can_be_muted(InputGroupCallId input_group_call_id, bool can_manage,
                                                   GroupCallParticipants *participants, bool force_is_admin);

  void update_group_call_participants_order(InputGroupCallId input_group_call_id, bool my_can_self_unmute,
                                            GroupCallParticipants *participants, const char *source);

  // returns participant_count_diff and video_participant_count_diff
  std::pair<int32, int32> process_group_call_participant(InputGroupCallId group_call_id,
                                                         GroupCallParticipant &&participant);

  void on_add_group_call_participant(InputGroupCallId input_group_call_id, DialogId participant_dialog_id);

  void on_remove_group_call_participant(InputGroupCallId input_group_call_id, DialogId participant_dialog_id);

  void try_load_group_call_administrators(InputGroupCallId input_group_call_id, DialogId dialog_id);

  void finish_load_group_call_administrators(InputGroupCallId input_group_call_id, Result<DialogParticipants> &&result);

  void try_join_group_call(InputGroupCall &&input_group_call, GroupCallJoinParameters &&join_parameters,
                           Promise<td_api::object_ptr<td_api::groupCallInfo>> &&promise);

  void do_join_group_call(InputGroupCall &&input_group_call, GroupCallJoinParameters &&join_parameters,
                          telegram_api::object_ptr<telegram_api::Updates> updates,
                          Promise<td_api::object_ptr<td_api::groupCallInfo>> &&promise);

  void on_join_group_call(InputGroupCall &&input_group_call, GroupCallJoinParameters &&join_parameters,
                          const tde2e_api::PrivateKeyId &private_key_id, const tde2e_api::PublicKeyId &public_key_id,
                          Result<telegram_api::object_ptr<telegram_api::Updates>> &&r_updates,
                          Promise<td_api::object_ptr<td_api::groupCallInfo>> &&promise);

  void process_join_group_call_response(InputGroupCallId input_group_call_id, bool is_join, int32 audio_source,
                                        const tde2e_api::PrivateKeyId &private_key_id,
                                        const tde2e_api::PublicKeyId &public_key_id,
                                        telegram_api::object_ptr<telegram_api::Updates> &&updates,
                                        Promise<td_api::object_ptr<td_api::groupCallInfo>> &&promise);

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

  void on_call_state_updated(GroupCall *group_call, const char *source);

  void set_blockchain_participant_ids(GroupCall *group_call, vector<int64> participant_ids);

  static vector<string> get_emojis_fingerprint(const GroupCall *group_call);

  void on_call_verification_state_updated(GroupCall *group_call);

  void send_outbound_group_call_blockchain_messages(GroupCall *group_call);

  void poll_group_call_blocks(GroupCall *group_call, int32 sub_chain_id);

  void on_poll_group_call_blocks(InputGroupCallId input_group_call_id, int32 sub_chain_id);

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

  struct BeingCreatedCall {
    bool is_join_ = false;
    tde2e_api::PrivateKeyId private_key_id_{};
    tde2e_api::PublicKeyId public_key_id_{};
    int32 audio_source_ = 0;
  };
  FlatHashMap<int32, BeingCreatedCall> being_created_group_calls_;
  FlatHashMap<InputGroupCallId, string, InputGroupCallIdHash> group_call_join_payloads_;

  struct BeingJoinedCallBlocks {
    bool is_inited_[2];
    vector<string> blocks_[2];
    int32 next_offset_[2];
  };
  FlatHashMap<InputGroupCallId, BeingJoinedCallBlocks, InputGroupCallIdHash> being_joined_call_blocks_;

  string pending_group_call_join_params_;

  FlatHashMap<InputGroupCall, InputGroupCallId, InputGroupCallHash> real_input_group_call_ids_;

  FlatHashMap<InputGroupCallId, unique_ptr<GroupCallParticipants>, InputGroupCallIdHash> group_call_participants_;
  FlatHashMap<DialogId, vector<InputGroupCallId>, DialogIdHash> participant_id_to_group_call_id_;

  FlatHashMap<GroupCallId, unique_ptr<GroupCallRecentSpeakers>, GroupCallIdHash> group_call_recent_speakers_;

  FlatHashMap<InputGroupCallId, vector<Promise<td_api::object_ptr<td_api::groupCall>>>, InputGroupCallIdHash>
      load_group_call_queries_;

  FlatHashMap<InputGroupCallId, unique_ptr<PendingJoinRequest>, InputGroupCallIdHash> pending_join_requests_;
  FlatHashMap<InputGroupCallId, unique_ptr<PendingJoinPresentationRequest>, InputGroupCallIdHash>
      pending_join_presentation_requests_;
  uint64 join_group_request_generation_ = 0;

  FlatHashMap<MessageFullId, int64, MessageFullIdHash> group_call_messages_;
  FlatHashMap<int64, MessageFullId> group_call_message_full_ids_;
  int64 current_call_id_ = 0;

  uint64 toggle_recording_generation_ = 0;

  uint64 toggle_is_muted_generation_ = 0;

  uint64 set_volume_level_generation_ = 0;

  uint64 toggle_is_hand_raised_generation_ = 0;

  MultiTimeout update_group_call_participant_order_timeout_{"UpdateGroupCallParticipantOrderTimeout"};
  MultiTimeout check_group_call_is_joined_timeout_{"CheckGroupCallIsJoinedTimeout"};
  MultiTimeout pending_send_speaking_action_timeout_{"PendingSendSpeakingActionTimeout"};
  MultiTimeout recent_speaker_update_timeout_{"RecentSpeakerUpdateTimeout"};
  MultiTimeout sync_participants_timeout_{"SyncParticipantsTimeout"};
  MultiTimeout update_group_call_timeout_{"UpdateGroupCallTimeout"};
  MultiTimeout poll_group_call_blocks_timeout_{"PollGroupCallBlocksTimeout"};
};

}  // namespace td
