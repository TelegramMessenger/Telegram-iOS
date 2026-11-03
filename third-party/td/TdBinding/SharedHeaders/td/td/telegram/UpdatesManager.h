//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/InputGroupCallId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/PtsManager.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"
#include "td/actor/Timeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"
#include "td/utils/tl_storers.h"
#include "td/utils/TlStorerToString.h"

#include <map>
#include <set>
#include <utility>

namespace td {

extern int VERBOSITY_NAME(get_difference);

class Td;

class dummyUpdate final : public telegram_api::Update {
 public:
  static constexpr int32 ID = 1234567891;
  int32 get_id() const final {
    return ID;
  }

  void store(TlStorerUnsafe &s) const final {
    UNREACHABLE();
  }

  void store(TlStorerCalcLength &s) const final {
    UNREACHABLE();
  }

  void store(TlStorerToString &s, const char *field_name) const final {
    s.store_class_begin(field_name, "dummyUpdate");
    s.store_class_end();
  }
};

class updateSentMessage final : public telegram_api::Update {
 public:
  int64 random_id_;
  MessageId message_id_;
  int32 date_;
  int32 ttl_period_;

  updateSentMessage(int64 random_id, MessageId message_id, int32 date, int32 ttl_period)
      : random_id_(random_id), message_id_(message_id), date_(date), ttl_period_(ttl_period) {
  }

  static constexpr int32 ID = 1234567890;
  int32 get_id() const final {
    return ID;
  }

  void store(TlStorerUnsafe &s) const final {
    UNREACHABLE();
  }

  void store(TlStorerCalcLength &s) const final {
    UNREACHABLE();
  }

  void store(TlStorerToString &s, const char *field_name) const final {
    s.store_class_begin(field_name, "updateSentMessage");
    s.store_field("random_id", random_id_);
    s.store_field("message_id", message_id_.get());
    s.store_field("date", date_);
    s.store_field("ttl_period", ttl_period_);
    s.store_class_end();
  }
};

class UpdatesManager final : public Actor {
 public:
  UpdatesManager(Td *td, ActorShared<> parent);

  void on_get_updates(tl_object_ptr<telegram_api::Updates> &&updates_ptr, Promise<Unit> &&promise);

  void add_pending_pts_update(tl_object_ptr<telegram_api::Update> &&update, int32 new_pts, int32 pts_count,
                              double receive_time, Promise<Unit> &&promise, const char *source);

  size_t get_pending_pts_update_count();

  static bool are_empty_updates(const telegram_api::Updates *updates_ptr);

  static FlatHashSet<int64> get_sent_messages_random_ids(const telegram_api::Updates *updates_ptr);

  static const telegram_api::Message *get_message_by_random_id(const telegram_api::Updates *updates_ptr,
                                                               DialogId dialog_id, int64 random_id);

  // [Message, is_scheduled]
  static vector<std::pair<const telegram_api::Message *, bool>> get_new_messages(
      const telegram_api::Updates *updates_ptr);

  static InputGroupCallId get_update_new_group_call_id(const telegram_api::Updates *updates_ptr);

  void process_updates_users_and_chats(telegram_api::Updates *updates_ptr);

  static string extract_join_group_call_presentation_params(telegram_api::Updates *updates_ptr);

  static telegram_api::object_ptr<telegram_api::StoryItem> extract_story(telegram_api::Updates *updates_ptr,
                                                                         DialogId owner_dialog_id);

  static vector<DialogId> get_update_notify_settings_dialog_ids(const telegram_api::Updates *updates_ptr);

  static vector<DialogId> get_chat_dialog_ids(const telegram_api::Updates *updates_ptr);

  static int32 get_update_edit_message_pts(const telegram_api::Updates *updates_ptr, MessageFullId message_full_id);

  void get_difference(const char *source);

  void schedule_get_difference(const char *source);

  void on_update_from_auth_key_id(uint64 auth_key_id);

  void ping_server();

  void notify_speed_limited(bool is_upload);

  bool running_get_difference() const {
    return running_get_difference_;
  }

  void timeout_expired() final;

 private:
  static constexpr int32 FORCED_GET_DIFFERENCE_PTS_DIFF = 100000;
  static constexpr int32 GAP_TIMEOUT_UPDATE_COUNT = 20;
  static constexpr double MIN_UNFILLED_GAP_TIME = 0.05;
  static constexpr double MAX_UNFILLED_GAP_TIME = 0.7;
  static constexpr double MAX_PTS_SAVE_DELAY = 0.05;
  static constexpr double UPDATE_APPLY_WARNING_TIME = 0.1;
  static constexpr bool DROP_PTS_UPDATES = false;
  static constexpr const char *AFTER_GET_DIFFERENCE_SOURCE = "after get difference";

  class OnUpdate {
    UpdatesManager *updates_manager_;
    telegram_api::object_ptr<telegram_api::Update> &update_;
    mutable Promise<Unit> promise_;

   public:
    OnUpdate(UpdatesManager *updates_manager, telegram_api::object_ptr<telegram_api::Update> &update,
             Promise<Unit> &&promise)
        : updates_manager_(updates_manager), update_(update), promise_(std::move(promise)) {
    }

    template <class T>
    void operator()(T &obj) const {
      CHECK(&*update_ == &obj);
      updates_manager_->on_update(move_tl_object_as<T>(update_), std::move(promise_));
    }
  };

  class PendingPtsUpdate {
   public:
    mutable tl_object_ptr<telegram_api::Update> update;
    int32 pts;
    int32 pts_count;
    double receive_time;
    mutable Promise<Unit> promise;

    PendingPtsUpdate(tl_object_ptr<telegram_api::Update> &&update, int32 pts, int32 pts_count, double receive_time,
                     Promise<Unit> &&promise)
        : update(std::move(update))
        , pts(pts)
        , pts_count(pts_count)
        , receive_time(receive_time)
        , promise(std::move(promise)) {
    }

    bool operator<(const PendingPtsUpdate &other) const {
      if (pts != other.pts) {
        return pts < other.pts;
      }
      return other.pts_count < pts_count;
    }
  };

  class PendingSeqUpdates {
   public:
    int32 seq_begin;
    int32 seq_end;
    int32 date;
    double receive_time;
    mutable vector<tl_object_ptr<telegram_api::Update>> updates;
    mutable Promise<Unit> promise;

    PendingSeqUpdates(int32 seq_begin, int32 seq_end, int32 date, double receive_time,
                      vector<tl_object_ptr<telegram_api::Update>> &&updates, Promise<Unit> &&promise)
        : seq_begin(seq_begin)
        , seq_end(seq_end)
        , date(date)
        , receive_time(receive_time)
        , updates(std::move(updates))
        , promise(std::move(promise)) {
    }

    bool operator<(const PendingSeqUpdates &other) const {
      if (seq_begin != other.seq_begin) {
        return seq_begin < other.seq_begin;
      }
      return other.seq_end < seq_end;
    }
  };

  class PendingQtsUpdate {
   public:
    double receive_time = 0.0;
    tl_object_ptr<telegram_api::Update> update;
    vector<Promise<Unit>> promises;
  };

  Td *td_;
  ActorShared<> parent_;
  int32 ref_cnt_ = 1;

  PtsManager pts_manager_;
  PtsManager qts_manager_;
  int32 date_ = 0;
  int32 seq_ = 0;
  string date_source_ = "nowhere";

  double last_pts_save_time_ = 0;
  double last_qts_save_time_ = 0;
  int32 pending_pts_ = 0;
  int32 pending_qts_ = 0;

  int32 pts_short_gap_ = 0;
  int32 pts_fixed_short_gap_ = 0;
  int32 pts_gap_ = 0;
  int32 pts_diff_ = 0;
  int32 last_fetched_pts_ = 0;

  int32 qts_gap_ = 0;
  int32 qts_diff_ = 0;

  int64 being_processed_updates_ = 0;

  int32 short_update_date_ = 0;

  int32 accumulated_pts_count_ = 0;
  int32 accumulated_pts_ = -1;
  double last_pts_jump_warning_time_ = 0;
  double last_pts_gap_time_ = 0;

  std::multiset<PendingPtsUpdate> pending_pts_updates_;    // updates waiting PTS gap fill
  std::multiset<PendingPtsUpdate> postponed_pts_updates_;  // updates waiting the end of getDifference

  std::multiset<PendingSeqUpdates> postponed_updates_;    // updates received during getDifference
  std::multiset<PendingSeqUpdates> pending_seq_updates_;  // updates with too big seq

  std::map<int32, PendingQtsUpdate> pending_qts_updates_;  // updates with too big QTS

  Timeout min_pts_gap_timeout_;
  Timeout pts_gap_timeout_;

  Timeout seq_gap_timeout_;

  Timeout qts_gap_timeout_;

  int32 retry_time_ = 1;
  Timeout retry_timeout_;

  double next_data_reload_time_ = 0.0;
  Timeout data_reload_timeout_;

  bool is_ping_sent_ = false;

  bool expect_pts_gap_ = false;
  bool running_get_difference_ = false;
  int32 skipped_postponed_updates_after_start_ = 50000;
  int32 last_confirmed_pts_ = 0;
  int32 last_confirmed_qts_ = 0;
  int32 min_postponed_update_pts_ = 0;
  int32 min_postponed_update_qts_ = 0;
  double get_difference_start_time_ = 0;  // time from which we started to get difference without success
  int32 get_difference_retry_count_ = 0;

  struct SessionInfo {
    uint64 update_count = 0;
    double first_update_time = 0.0;
    double last_update_time = 0.0;
  };
  FlatHashMap<uint64, SessionInfo> session_infos_;

  double next_notify_speed_limited_[2] = {0.0, 0.0};

  void start_up() final;

  void tear_down() final;

  void hangup_shared() final;

  void hangup() final;

  ActorShared<UpdatesManager> create_reference();

  int32 get_pts() const {
    return pts_manager_.mem_pts();
  }
  int32 get_qts() const {
    return qts_manager_.mem_pts();
  }
  int32 get_date() const {
    return date_;
  }

  Promise<> set_pts(int32 pts, const char *source) TD_WARN_UNUSED_RESULT;
  Promise<> add_pts(int32 pts);
  void on_pts_ack(PtsManager::PtsId ack_token);
  void save_pts(int32 pts);

  Promise<> add_qts(int32 qts);
  void on_qts_ack(PtsManager::PtsId ack_token);
  void save_qts(int32 qts);

  bool can_postpone_updates() {
    if (skipped_postponed_updates_after_start_ == 0) {
      return true;
    }
    skipped_postponed_updates_after_start_--;
    return false;
  }

  void set_date(int32 date, bool from_update, string date_source);

  int32 get_short_update_date() const;

  void init_state();

  void on_get_updates_state(tl_object_ptr<telegram_api::updates_state> &&state, const char *source);

  void on_get_updates_impl(tl_object_ptr<telegram_api::Updates> updates_ptr, Promise<Unit> promise);

  void on_server_pong(tl_object_ptr<telegram_api::updates_state> &&state);

  void on_get_difference(tl_object_ptr<telegram_api::updates_Difference> &&difference_ptr);

  void process_get_difference_updates(vector<tl_object_ptr<telegram_api::Message>> &&new_messages,
                                      vector<tl_object_ptr<telegram_api::EncryptedMessage>> &&new_encrypted_messages,
                                      vector<tl_object_ptr<telegram_api::Update>> &&other_updates);

  void on_pending_update(tl_object_ptr<telegram_api::Update> update, int32 seq, Promise<Unit> &&promise,
                         const char *source);

  void add_pending_qts_update(tl_object_ptr<telegram_api::Update> &&update, int32 qts, Promise<Unit> &&promise);

  void on_pending_updates(vector<tl_object_ptr<telegram_api::Update>> &&updates, int32 seq_begin, int32 seq_end,
                          int32 date, double receive_time, Promise<Unit> &&promise, const char *source);

  void on_pending_updates_processed(Result<Unit> result, Promise<Unit> promise);

  void process_updates(vector<tl_object_ptr<telegram_api::Update>> &&updates, bool force_apply,
                       Promise<Unit> &&promise);

  void postpone_pts_update(tl_object_ptr<telegram_api::Update> &&update, int32 pts, int32 pts_count,
                           double receive_time, Promise<Unit> &&promise);

  void process_pts_update(tl_object_ptr<telegram_api::Update> &&update);

  void process_seq_updates(int32 seq_end, int32 date, vector<tl_object_ptr<telegram_api::Update>> &&updates,
                           Promise<Unit> &&promise);

  void process_qts_update(tl_object_ptr<telegram_api::Update> &&update_ptr, int32 qts, Promise<Unit> &&promise);

  void process_all_pending_pts_updates();

  void drop_all_pending_pts_updates();

  void process_postponed_pts_updates();

  void process_pending_pts_updates();

  void process_pending_seq_updates();

  void process_pending_qts_updates();

  static void check_pts_gap(void *td);

  static void fill_pts_gap(void *td);

  static void fill_seq_gap(void *td);

  static void fill_qts_gap(void *td);

  static void fill_get_difference_gap(void *td);

  static void fill_gap(void *td, const string &source);

  void repair_pts_gap();

  void on_get_pts_update(int32 pts, telegram_api::object_ptr<telegram_api::updates_Difference> difference_ptr);

  void set_pts_gap_timeout(double timeout);

  void set_seq_gap_timeout(double timeout);

  void set_qts_gap_timeout(double timeout);

  void run_get_difference(bool is_recursive, const char *source);

  void confirm_pts_qts(int32 qts);

  void on_failed_get_updates_state(Status &&error);

  void on_failed_get_difference(Status &&error);

  void before_get_difference(bool is_initial);

  void after_get_difference();

  void schedule_data_reload();

  static void try_reload_data_static(void *td);

  void try_reload_data();

  void on_data_reloaded();

  uint64 get_most_unused_auth_key_id();

  static vector<int32> get_update_ids(const telegram_api::Updates *updates_ptr);

  static bool have_update_pts_changed(const vector<tl_object_ptr<telegram_api::Update>> &updates);

  static bool check_pts_update_dialog_id(DialogId dialog_id);

  static bool check_pts_update(const tl_object_ptr<telegram_api::Update> &update);

  static bool is_pts_update(const telegram_api::Update *update);

  static int32 get_update_pts(const telegram_api::Update *update);

  static bool is_qts_update(const telegram_api::Update *update);

  static int32 get_update_qts(const telegram_api::Update *update);

  static bool is_channel_pts_update(const telegram_api::Update *update);

  static bool is_additional_service_message(const telegram_api::Message *message);

  static const vector<tl_object_ptr<telegram_api::Update>> *get_updates(const telegram_api::Updates *updates_ptr);

  static vector<tl_object_ptr<telegram_api::Update>> *get_updates(telegram_api::Updates *updates_ptr);

  bool is_acceptable_user(UserId user_id) const;

  bool is_acceptable_chat(ChatId chat_id) const;

  bool is_acceptable_channel(ChannelId channel_id) const;

  bool is_acceptable_peer(const tl_object_ptr<telegram_api::Peer> &peer) const;

  bool is_acceptable_message_entities(const vector<tl_object_ptr<telegram_api::MessageEntity>> &message_entities) const;

  bool is_acceptable_reply_markup(const tl_object_ptr<telegram_api::ReplyMarkup> &reply_markup) const;

  bool is_acceptable_message_reply_header(
      const telegram_api::object_ptr<telegram_api::MessageReplyHeader> &header) const;

  bool is_acceptable_message_forward_header(
      const telegram_api::object_ptr<telegram_api::messageFwdHeader> &header) const;

  bool is_acceptable_message_media(const telegram_api::object_ptr<telegram_api::MessageMedia> &media_ptr) const;

  bool is_acceptable_message(const telegram_api::Message *message_ptr) const;

  bool is_acceptable_update(const telegram_api::Update *update) const;

  void on_update(tl_object_ptr<telegram_api::updateNewMessage> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateMessageID> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateReadMessagesContents> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateEditMessage> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateDeleteMessages> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateReadHistoryInbox> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateReadHistoryOutbox> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateNotifySettings> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updatePeerSettings> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updatePeerHistoryTTL> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updatePeerLocated> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateWebPage> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChannelWebPage> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateMessageReactions> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateRecentReactions> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateSavedReactionTags> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updatePaidReactionPrivacy> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateAttachMenuBots> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateWebViewResultSent> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateFolderPeers> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateUserTyping> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChatUserTyping> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChannelUserTyping> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateEncryptedChatTyping> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateUserStatus> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateUserName> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateUserPhone> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateUser> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateUserEmojiStatus> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateRecentEmojiStatuses> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updatePeerBlocked> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateBotCommands> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateBotMenuButton> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateChatParticipants> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChatParticipantAdd> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChatParticipantAdmin> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChatParticipantDelete> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateChatDefaultBannedRights> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateServiceNotification> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateDcOptions> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateChat> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateNewChannelMessage> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateReadChannelInbox> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateReadChannelOutbox> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChannelReadMessagesContents> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChannelTooLong> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChannel> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateEditChannelMessage> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateDeleteChannelMessages> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChannelMessageViews> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChannelMessageForwards> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChannelAvailableMessages> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChannelViewForumAsMessages> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateReadChannelDiscussionInbox> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateReadChannelDiscussionOutbox> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateChannelPinnedTopic> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChannelPinnedTopics> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updatePinnedMessages> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updatePinnedChannelMessages> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateDraftMessage> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateDialogPinned> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updatePinnedDialogs> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateDialogUnreadMark> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateSavedDialogPinned> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updatePinnedSavedDialogs> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateDialogFilter> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateDialogFilters> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateDialogFilterOrder> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateBotInlineQuery> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateBotInlineSend> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateBotCallbackQuery> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateInlineBotCallbackQuery> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateBusinessBotCallbackQuery> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateFavedStickers> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateSavedGifs> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateConfig> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updatePtsChanged> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updatePrivacy> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateEncryption> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateNewEncryptedMessage> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateEncryptedMessagesRead> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateNewStickerSet> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateStickerSets> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateStickerSetsOrder> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateMoveStickerSetToTop> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateReadFeaturedStickers> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateReadFeaturedEmojiStickers> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateRecentStickers> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateBotShippingQuery> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateBotPrecheckoutQuery> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateBotWebhookJSON> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateBotWebhookJSONQuery> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updatePhoneCall> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updatePhoneCallSignalingData> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateGroupCallConnection> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateGroupCallChainBlocks> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateGroupCall> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateGroupCallParticipants> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateContactsReset> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateLangPackTooLong> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateLangPack> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateGeoLiveViewed> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateMessageExtendedMedia> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateMessagePoll> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateMessagePollVote> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateNewScheduledMessage> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateDeleteScheduledMessages> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateLoginToken> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateSentPhoneCode> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateBotStopped> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChatParticipant> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateChannelParticipant> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateBotChatInviteRequester> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateBotChatBoost> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateBotMessageReaction> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateBotMessageReactions> update, Promise<Unit> &&promise);
  void on_update(tl_object_ptr<telegram_api::updateBotPurchasedPaidMedia> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateTheme> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updatePeerWallpaper> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updatePendingJoinRequests> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateSavedRingtones> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateTranscribedAudio> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateAutoSaveSettings> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateStory> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateReadStories> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateStoriesStealthMode> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateSentStoryReaction> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateStoryID> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateNewAuthorization> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateSmsJob> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateQuickReplies> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateNewQuickReply> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateDeleteQuickReply> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateQuickReplyMessage> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateDeleteQuickReplyMessages> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateBotBusinessConnect> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateBotNewBusinessMessage> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateBotEditBusinessMessage> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateBotDeleteBusinessMessage> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateBroadcastRevenueTransactions> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateStarsBalance> update, Promise<Unit> &&promise);

  void on_update(tl_object_ptr<telegram_api::updateStarsRevenueStatus> update, Promise<Unit> &&promise);

  // unsupported updates

  void on_update(tl_object_ptr<telegram_api::updateNewStoryReaction> update, Promise<Unit> &&promise);
};

}  // namespace td
