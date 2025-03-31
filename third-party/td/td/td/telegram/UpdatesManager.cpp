//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/UpdatesManager.h"

#include "td/telegram/AccountManager.h"
#include "td/telegram/AnimationsManager.h"
#include "td/telegram/AttachMenuManager.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/AutosaveManager.h"
#include "td/telegram/BoostManager.h"
#include "td/telegram/BusinessConnectionId.h"
#include "td/telegram/BusinessConnectionManager.h"
#include "td/telegram/CallbackQueriesManager.h"
#include "td/telegram/CallManager.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/ChannelType.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/ConfigManager.h"
#include "td/telegram/DialogAction.h"
#include "td/telegram/DialogActionManager.h"
#include "td/telegram/DialogFilterManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogInviteLink.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/DialogParticipant.h"
#include "td/telegram/DialogParticipantManager.h"
#include "td/telegram/DownloadManager.h"
#include "td/telegram/EmojiStatus.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/ForumTopicManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/GroupCallManager.h"
#include "td/telegram/InlineQueriesManager.h"
#include "td/telegram/LanguagePackManager.h"
#include "td/telegram/Location.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageReaction.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/MessageTtl.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/DcOptions.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/NotificationSettingsManager.h"
#include "td/telegram/NotificationSettingsScope.h"
#include "td/telegram/OnlineManager.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/OrderInfo.h"
#include "td/telegram/PaidReactionType.h"
#include "td/telegram/PollId.h"
#include "td/telegram/PollManager.h"
#include "td/telegram/PrivacyManager.h"
#include "td/telegram/PublicDialogType.h"
#include "td/telegram/QuickReplyManager.h"
#include "td/telegram/QuickReplyShortcutId.h"
#include "td/telegram/ReactionListType.h"
#include "td/telegram/ReactionManager.h"
#include "td/telegram/ReactionType.h"
#include "td/telegram/SavedMessagesManager.h"
#include "td/telegram/ScheduledServerMessageId.h"
#include "td/telegram/SecretChatId.h"
#include "td/telegram/SecretChatsManager.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/SpecialStickerSetType.h"
#include "td/telegram/StarAmount.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/StatisticsManager.h"
#include "td/telegram/StickerListType.h"
#include "td/telegram/StickerSetId.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StickerType.h"
#include "td/telegram/StoryId.h"
#include "td/telegram/StoryManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/td_api.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/telegram_api.hpp"
#include "td/telegram/ThemeManager.h"
#include "td/telegram/TimeZoneManager.h"
#include "td/telegram/TranscriptionManager.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/Usernames.h"
#include "td/telegram/WebAppManager.h"
#include "td/telegram/WebPagesManager.h"

#include "td/actor/MultiPromise.h"
#include "td/actor/PromiseFuture.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"

#include <limits>

namespace td {

int VERBOSITY_NAME(get_difference) = VERBOSITY_NAME(INFO);

class GetUpdatesStateQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<telegram_api::updates_state>> promise_;

 public:
  explicit GetUpdatesStateQuery(Promise<tl_object_ptr<telegram_api::updates_state>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::updates_getState()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::updates_getState>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class PingServerQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<telegram_api::updates_state>> promise_;

 public:
  explicit PingServerQuery(Promise<tl_object_ptr<telegram_api::updates_state>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::updates_getState()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::updates_getState>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class InitSessionQuery final : public Td::ResultHandler {
 public:
  void send() {
    send_query(G()->net_query_creator().create(telegram_api::help_getCdnConfig()));
  }

  void on_result(BufferSlice) final {
  }

  void on_error(Status) final {
  }
};

class GetDifferenceQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<telegram_api::updates_Difference>> promise_;

 public:
  explicit GetDifferenceQuery(Promise<tl_object_ptr<telegram_api::updates_Difference>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(int32 pts, int32 date, int32 qts) {
    send_query(G()->net_query_creator().create(telegram_api::updates_getDifference(0, pts, 0, 0, date, qts, 0)));
  }

  void on_result(BufferSlice packet) final {
    VLOG(get_difference) << "Receive getDifference result of size " << packet.size();
    auto result_ptr = fetch_result<telegram_api::updates_getDifference>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ConfirmPtsQtsQuery final : public Td::ResultHandler {
 public:
  void send(int32 pts, int32 qts) {
    int32 flags =
        telegram_api::updates_getDifference::PTS_LIMIT_MASK | telegram_api::updates_getDifference::QTS_LIMIT_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::updates_getDifference(flags, pts, 1, 0, std::numeric_limits<int32>::max(), qts, 1)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::updates_getDifference>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Failed to confirm PTS/QTS: " << status;
    }
  }
};

class GetPtsUpdateQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<telegram_api::updates_Difference>> promise_;

 public:
  explicit GetPtsUpdateQuery(Promise<tl_object_ptr<telegram_api::updates_Difference>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(int32 pts) {
    int32 flags =
        telegram_api::updates_getDifference::PTS_LIMIT_MASK | telegram_api::updates_getDifference::QTS_LIMIT_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::updates_getDifference(flags, pts, 1, 0, std::numeric_limits<int32>::max(), 0, 0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::updates_getDifference>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

UpdatesManager::UpdatesManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  last_pts_save_time_ = last_qts_save_time_ = Time::now() - 2 * MAX_PTS_SAVE_DELAY;

  if (!td_->auth_manager_->is_authorized() || !td_->auth_manager_->is_bot()) {
    skipped_postponed_updates_after_start_ = 0;
  }
}

void UpdatesManager::tear_down() {
  parent_.reset();

  LOG(DEBUG) << "Have " << being_processed_updates_ << " unprocessed updates to apply";
}

void UpdatesManager::start_up() {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  class StateCallback final : public StateManager::Callback {
   public:
    explicit StateCallback(ActorId<UpdatesManager> parent) : parent_(std::move(parent)) {
    }
    bool on_online(bool is_online) final {
      if (is_online) {
        send_closure(parent_, &UpdatesManager::try_reload_data);
      }
      return parent_.is_alive();
    }

   private:
    ActorId<UpdatesManager> parent_;
  };
  send_closure(G()->state_manager(), &StateManager::add_callback, make_unique<StateCallback>(actor_id(this)));

  next_data_reload_time_ = Time::now() - 1;
}

void UpdatesManager::hangup_shared() {
  ref_cnt_--;
  if (ref_cnt_ == 0) {
    stop();
  }
}

void UpdatesManager::hangup() {
  pending_pts_updates_.clear();
  postponed_pts_updates_.clear();
  postponed_updates_.clear();
  pending_seq_updates_.clear();
  pending_qts_updates_.clear();

  hangup_shared();
}

ActorShared<UpdatesManager> UpdatesManager::create_reference() {
  ref_cnt_++;
  return actor_shared(this, 1);
}

void UpdatesManager::check_pts_gap(void *td) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(td != nullptr);
  static_cast<Td *>(td)->updates_manager_.get()->repair_pts_gap();
}

void UpdatesManager::repair_pts_gap() {
  if (!td_->auth_manager_->is_authorized() || running_get_difference_ || !postponed_pts_updates_.empty()) {
    return;
  }
  auto pts = get_pts() + 1;
  if (pending_pts_updates_.empty()) {
    return;
  }
  auto it = pending_pts_updates_.begin();
  if (it->pts != pts + it->pts_count) {
    return;
  }
  if (last_fetched_pts_ == pts) {
    VLOG(get_difference) << "Don't fetch again update with PTS = " << pts;
    return;
  }
  last_fetched_pts_ = pts;

  VLOG(get_difference) << "Fetch update with PTS = " << pts;
  pts_short_gap_++;
  auto promise =
      PromiseCreator::lambda([pts](Result<telegram_api::object_ptr<telegram_api::updates_Difference>> result) {
        if (result.is_ok()) {
          send_closure(G()->updates_manager(), &UpdatesManager::on_get_pts_update, pts, result.move_as_ok());
        }
      });
  td_->create_handler<GetPtsUpdateQuery>(std::move(promise))->send(pts - 1);
}

void UpdatesManager::fill_pts_gap(void *td) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(td != nullptr);
  auto updates_manager = static_cast<Td *>(td)->updates_manager_.get();
  if (updates_manager->expect_pts_gap_) {
    updates_manager->expect_pts_gap_ = false;
    return fill_gap(td, string());
  }

  auto min_pts = std::numeric_limits<int32>::max();
  auto min_pts_count = 0;
  const telegram_api::Update *first_update = nullptr;
  auto max_pts = 0;
  if (!updates_manager->pending_pts_updates_.empty()) {
    auto &min_update = *updates_manager->pending_pts_updates_.begin();
    if (min_update.pts < min_pts) {
      min_pts = min_update.pts;
      min_pts_count = min_update.pts_count;
      first_update = min_update.update.get();
    }
    max_pts = max(max_pts, updates_manager->pending_pts_updates_.rbegin()->pts);
  }
  if (!updates_manager->postponed_pts_updates_.empty()) {
    auto &min_update = *updates_manager->postponed_pts_updates_.begin();
    if (min_update.pts < min_pts) {
      min_pts = min_update.pts;
      min_pts_count = min_update.pts_count;
      first_update = min_update.update.get();
    }
    max_pts = max(max_pts, updates_manager->postponed_pts_updates_.rbegin()->pts);
  }
  updates_manager->pts_gap_++;
  fill_gap(td, PSTRING() << "PTS from " << updates_manager->get_pts() << " to " << min_pts << "(-" << min_pts_count
                         << ")-" << max_pts << ' '
                         << (first_update == nullptr ? string() : oneline(to_string(*first_update))));
}

void UpdatesManager::fill_seq_gap(void *td) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(td != nullptr);
  auto updates_manager = static_cast<Td *>(td)->updates_manager_.get();
  auto min_seq = std::numeric_limits<int32>::max();
  auto max_seq = 0;
  if (!updates_manager->pending_seq_updates_.empty()) {
    min_seq = updates_manager->pending_seq_updates_.begin()->seq_begin;
    max_seq = updates_manager->pending_seq_updates_.rbegin()->seq_end;
  }
  fill_gap(td, PSTRING() << "seq from " << updates_manager->seq_ << " to " << min_seq << '-' << max_seq);
}

void UpdatesManager::fill_qts_gap(void *td) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(td != nullptr);
  auto updates_manager = static_cast<Td *>(td)->updates_manager_.get();
  auto min_qts = std::numeric_limits<int32>::max();
  auto max_qts = 0;
  if (!updates_manager->pending_qts_updates_.empty()) {
    min_qts = updates_manager->pending_qts_updates_.begin()->first;
    max_qts = updates_manager->pending_qts_updates_.rbegin()->first;
  }
  updates_manager->qts_gap_++;
  fill_gap(td, PSTRING() << "QTS from " << updates_manager->get_qts() << " to " << min_qts << '-' << max_qts);
}

void UpdatesManager::fill_get_difference_gap(void *td) {
  fill_gap(td, string());
}

void UpdatesManager::fill_gap(void *td, const string &source) {
  if (G()->close_flag()) {
    return;
  }
  CHECK(td != nullptr);
  if (!static_cast<Td *>(td)->auth_manager_->is_authorized()) {
    return;
  }
  auto updates_manager = static_cast<Td *>(td)->updates_manager_.get();

  if (!source.empty() && !updates_manager->running_get_difference_) {
    auto auth_key_id = updates_manager->get_most_unused_auth_key_id();
    uint64 update_count = 0;
    double active_time = 0.0;
    double delay_time = 0.0;
    if (auth_key_id != 0) {
      auto now = Time::now();
      auto &info = updates_manager->session_infos_[auth_key_id];
      update_count = info.update_count;
      active_time = now - info.first_update_time;
      delay_time = now - info.last_update_time;
    }

    LOG(WARNING) << "Filling gap in " << source
                 << " by running getDifference. Receive no updates from session with auth key " << auth_key_id
                 << " for " << delay_time << " seconds, active for " << active_time << " seconds and having "
                 << update_count << " received updates";
  }

  updates_manager->get_difference("fill_gap");
}

void UpdatesManager::get_difference(const char *source) {
  if (G()->close_flag() || !td_->auth_manager_->is_authorized()) {
    return;
  }
  if (get_pts() == -1) {
    init_state();
    return;
  }

  if (running_get_difference_) {
    VLOG(get_difference) << "Skip running getDifference from " << source << " because it is already running";
    return;
  }

  run_get_difference(false, source);
}

void UpdatesManager::run_get_difference(bool is_recursive, const char *source) {
  CHECK(get_pts() != -1);
  CHECK(td_->auth_manager_->is_authorized());
  CHECK(!running_get_difference_);

  running_get_difference_ = true;

  int32 pts = get_pts();
  int32 date = get_date();
  int32 qts = get_qts();
  if (pts < 0) {
    pts = 0;
  }

  VLOG(get_difference) << "-----BEGIN GET DIFFERENCE----- from " << source << " with PTS = " << pts << ", QTS = " << qts
                       << ", date = " << date;

  before_get_difference(false);

  if (!is_recursive) {
    min_postponed_update_pts_ = 0;
    min_postponed_update_qts_ = 0;
  }

  auto promise = PromiseCreator::lambda([](Result<tl_object_ptr<telegram_api::updates_Difference>> result) {
    if (result.is_ok()) {
      send_closure(G()->updates_manager(), &UpdatesManager::on_get_difference, result.move_as_ok());
    } else {
      send_closure(G()->updates_manager(), &UpdatesManager::on_failed_get_difference, result.move_as_error());
    }
  });
  td_->create_handler<GetDifferenceQuery>(std::move(promise))->send(pts, date, qts);
  last_confirmed_pts_ = pts;
  last_confirmed_qts_ = qts;
}

void UpdatesManager::before_get_difference(bool is_initial) {
  // may be called many times before after_get_difference is called
  send_closure(G()->state_manager(), &StateManager::on_synchronized, false);

  td_->messages_manager_->before_get_difference();

  vector<Promise<Unit>> promises;
  if (can_postpone_updates()) {
    for (auto &update : pending_pts_updates_) {
      postponed_pts_updates_.emplace(std::move(update.update), update.pts, update.pts_count, update.receive_time,
                                     std::move(update.promise));
    }
  } else {
    for (auto &update : pending_pts_updates_) {
      promises.push_back(std::move(update.promise));
    }
  }
  set_promises(promises);

  drop_all_pending_pts_updates();

  send_closure_later(td_->notification_manager_actor_, &NotificationManager::before_get_difference);

  if (get_difference_start_time_ <= 0) {
    get_difference_start_time_ = Time::now();
  }
}

Promise<> UpdatesManager::add_pts(int32 pts) {
  auto id = pts_manager_.add_pts(pts);
  return create_event_promise(self_closure(this, &UpdatesManager::on_pts_ack, id));
}

Promise<> UpdatesManager::add_qts(int32 qts) {
  auto id = qts_manager_.add_pts(qts);
  return create_event_promise(self_closure(this, &UpdatesManager::on_qts_ack, id));
}

void UpdatesManager::on_pts_ack(PtsManager::PtsId ack_token) {
  auto old_pts = pts_manager_.db_pts();
  auto new_pts = pts_manager_.finish(ack_token);
  if (old_pts != new_pts) {
    save_pts(new_pts);
  }
}

void UpdatesManager::on_qts_ack(PtsManager::PtsId ack_token) {
  auto old_qts = qts_manager_.db_pts();
  auto new_qts = qts_manager_.finish(ack_token);
  if (old_qts != new_qts) {
    save_qts(new_qts);
  }
}

void UpdatesManager::save_pts(int32 pts) {
  if (pts == std::numeric_limits<int32>::max()) {
    G()->td_db()->get_binlog_pmc()->erase("updates.pts");
    last_pts_save_time_ -= 2 * MAX_PTS_SAVE_DELAY;
    pending_pts_ = 0;
  } else if (!td_->ignore_background_updates()) {
    auto now = Time::now();
    auto delay = last_pts_save_time_ + MAX_PTS_SAVE_DELAY - now;
    if (delay <= 0 || !td_->auth_manager_->is_bot()) {
      last_pts_save_time_ = now;
      pending_pts_ = 0;
      G()->td_db()->get_binlog_pmc()->set("updates.pts", to_string(pts));
    } else {
      pending_pts_ = pts;
      if (!has_timeout()) {
        set_timeout_in(delay);
      }
    }
  }
}

void UpdatesManager::save_qts(int32 qts) {
  if (!td_->ignore_background_updates()) {
    auto now = Time::now();
    auto delay = last_qts_save_time_ + MAX_PTS_SAVE_DELAY - now;
    if (delay <= 0 || !td_->auth_manager_->is_bot()) {
      last_qts_save_time_ = now;
      pending_qts_ = 0;
      G()->td_db()->get_binlog_pmc()->set("updates.qts", to_string(qts));
    } else {
      pending_qts_ = qts;
      if (!has_timeout()) {
        set_timeout_in(delay);
      }
    }
  }
}

void UpdatesManager::timeout_expired() {
  if (pending_pts_ != 0) {
    last_pts_save_time_ -= 2 * MAX_PTS_SAVE_DELAY;
    save_pts(pending_pts_);
    CHECK(pending_pts_ == 0);
  }
  if (pending_qts_ != 0) {
    last_qts_save_time_ -= 2 * MAX_PTS_SAVE_DELAY;
    save_qts(pending_qts_);
    CHECK(pending_qts_ == 0);
  }
}

Promise<> UpdatesManager::set_pts(int32 pts, const char *source) {
  if (pts == std::numeric_limits<int32>::max()) {
    LOG(WARNING) << "Update PTS from " << get_pts() << " to -1 from " << source;
    save_pts(pts);  // drop saved PTS value
    auto result = add_pts(pts);
    init_state();
    return result;
  }
  Promise<> result;
  auto old_pts = get_pts();
  if (pts > old_pts || (0 < pts && pts < old_pts - 1000009)) {  // PTS can only go up or drop cardinally
    if (pts < old_pts - 1000009) {
      LOG(WARNING) << "PTS decreases from " << old_pts << " to " << pts << " from " << source;
    } else {
      LOG(INFO) << "Update PTS from " << old_pts << " to " << pts << " from " << source;
      if (old_pts > 0) {
        pts_diff_ += pts - old_pts;
        if (pts_diff_ >= 1000000) {
          if (pts_gap_ > 0 || pts_short_gap_ > 0) {
            LOG(WARNING) << "Fixed " << pts_gap_ << " PTS gaps and " << pts_fixed_short_gap_ << " short gaps up to PTS "
                         << pts << " by sending " << pts_short_gap_ << " requests";
            pts_short_gap_ = 0;
            pts_fixed_short_gap_ = 0;
            pts_gap_ = 0;
          }
          pts_diff_ = 0;
        }
      }
    }

    result = add_pts(pts);
    if (last_confirmed_pts_ < get_pts() - FORCED_GET_DIFFERENCE_PTS_DIFF && last_confirmed_pts_ != 0) {
      confirm_pts_qts(get_qts());
    }
  } else if (pts < get_pts() && (pts > 1 || td_->option_manager_->get_option_integer("session_count") <= 1)) {
    LOG(ERROR) << "Receive wrong PTS = " << pts << " from " << source << ". Current PTS = " << get_pts();
  }
  return result;
}

void UpdatesManager::set_date(int32 date, bool from_update, string date_source) {
  if (date > date_) {
    LOG(INFO) << "Update date to " << date;
    if (from_update && false) {  // date in updates is decreased by the server
      date--;

      if (date == date_) {
        return;
      }
    }
    auto now = G()->unix_time();
    if (date_ > now + 1) {
      LOG(ERROR) << "Receive wrong by " << (date_ - now) << " date = " << date_ << " from " << date_source;
      date_ = now;
      if (date_ <= date) {
        return;
      }
    }

    date_ = date;
    date_source_ = std::move(date_source);
    if (!td_->ignore_background_updates()) {
      G()->td_db()->get_binlog_pmc()->set("updates.date", to_string(date));
    }
  } else if (date < date_) {
    if (from_update) {
      date++;

      if (date == date_) {
        return;
      }
    }
    LOG(ERROR) << "Receive wrong by " << (date_ - date) << " date = " << date << " from " << date_source
               << ". Current date = " << date_ << " from " << date_source_;
  }
}

bool UpdatesManager::is_acceptable_user(UserId user_id) const {
  return td_->user_manager_->have_user_force(user_id, "is_acceptable_user") && td_->user_manager_->have_user(user_id);
}

bool UpdatesManager::is_acceptable_chat(ChatId chat_id) const {
  return td_->chat_manager_->have_chat_force(chat_id, "is_acceptable_chat");
}

bool UpdatesManager::is_acceptable_channel(ChannelId channel_id) const {
  return td_->chat_manager_->have_channel_force(channel_id, "is_acceptable_channel");
}

bool UpdatesManager::is_acceptable_peer(const tl_object_ptr<telegram_api::Peer> &peer) const {
  if (peer == nullptr) {
    return true;
  }

  DialogId dialog_id(peer);
  switch (dialog_id.get_type()) {
    case DialogType::User:
      if (!is_acceptable_user(dialog_id.get_user_id())) {
        return false;
      }
      break;
    case DialogType::Chat:
      if (!is_acceptable_chat(dialog_id.get_chat_id())) {
        return false;
      }
      break;
    case DialogType::Channel:
      if (!is_acceptable_channel(dialog_id.get_channel_id())) {
        return false;
      }
      break;
    case DialogType::None:
      return false;
    case DialogType::SecretChat:
    default:
      UNREACHABLE();
      return false;
  }
  return true;
}

bool UpdatesManager::is_acceptable_message_entities(
    const vector<tl_object_ptr<telegram_api::MessageEntity>> &message_entities) const {
  for (auto &entity : message_entities) {
    if (entity->get_id() == telegram_api::messageEntityMentionName::ID) {
      auto entity_mention_name = static_cast<const telegram_api::messageEntityMentionName *>(entity.get());
      UserId user_id(entity_mention_name->user_id_);
      if (!is_acceptable_user(user_id) || td_->user_manager_->get_input_user(user_id).is_error()) {
        return false;
      }
    }
  }
  return true;
}

bool UpdatesManager::is_acceptable_reply_markup(const tl_object_ptr<telegram_api::ReplyMarkup> &reply_markup) const {
  if (reply_markup == nullptr || reply_markup->get_id() != telegram_api::replyInlineMarkup::ID) {
    return true;
  }
  for (const auto &row : static_cast<const telegram_api::replyInlineMarkup *>(reply_markup.get())->rows_) {
    for (const auto &button : row->buttons_) {
      if (button->get_id() == telegram_api::keyboardButtonUserProfile::ID) {
        auto user_profile_button = static_cast<const telegram_api::keyboardButtonUserProfile *>(button.get());
        UserId user_id(user_profile_button->user_id_);
        if (!is_acceptable_user(user_id) || td_->user_manager_->get_input_user(user_id).is_error()) {
          return false;
        }
      }
    }
  }
  return true;
}

bool UpdatesManager::is_acceptable_message_reply_header(
    const telegram_api::object_ptr<telegram_api::MessageReplyHeader> &header) const {
  if (header == nullptr) {
    return true;
  }

  switch (header->get_id()) {
    case telegram_api::messageReplyHeader::ID: {
      auto reply_header = static_cast<const telegram_api::messageReplyHeader *>(header.get());
      return is_acceptable_peer(reply_header->reply_to_peer_id_) &&
             is_acceptable_message_forward_header(reply_header->reply_from_) &&
             is_acceptable_message_entities(reply_header->quote_entities_) &&
             is_acceptable_message_media(reply_header->reply_media_);
    }
    case telegram_api::messageReplyStoryHeader::ID: {
      auto reply_header = static_cast<const telegram_api::messageReplyStoryHeader *>(header.get());
      return is_acceptable_peer(reply_header->peer_);
    }
    default:
      UNREACHABLE();
      return true;
  }
}

bool UpdatesManager::is_acceptable_message_forward_header(
    const telegram_api::object_ptr<telegram_api::messageFwdHeader> &header) const {
  if (header == nullptr) {
    return true;
  }

  if (!is_acceptable_peer(header->from_id_)) {
    return false;
  }
  if (!is_acceptable_peer(header->saved_from_peer_)) {
    return false;
  }
  return true;
}

bool UpdatesManager::is_acceptable_message_media(
    const telegram_api::object_ptr<telegram_api::MessageMedia> &media_ptr) const {
  if (media_ptr == nullptr) {
    return true;
  }
  switch (media_ptr->get_id()) {
    case telegram_api::messageMediaContact::ID: {
      auto message_media = static_cast<const telegram_api::messageMediaContact *>(media_ptr.get());
      UserId user_id(message_media->user_id_);
      return user_id == UserId() || is_acceptable_user(user_id);
    }
    case telegram_api::messageMediaStory::ID: {
      auto message_media = static_cast<const telegram_api::messageMediaStory *>(media_ptr.get());
      return is_acceptable_peer(message_media->peer_);
    }
    case telegram_api::messageMediaGiveaway::ID: {
      auto message_media = static_cast<const telegram_api::messageMediaGiveaway *>(media_ptr.get());
      for (auto channel_id : message_media->channels_) {
        if (!is_acceptable_channel(ChannelId(channel_id))) {
          return false;
        }
      }
      return true;
    }
    case telegram_api::messageMediaGiveawayResults::ID: {
      auto message_media = static_cast<const telegram_api::messageMediaGiveawayResults *>(media_ptr.get());
      if (!is_acceptable_channel(ChannelId(message_media->channel_id_))) {
        return false;
      }
      for (auto user_id : message_media->winners_) {
        if (!is_acceptable_user(UserId(user_id))) {
          return false;
        }
      }
      return true;
    }
    case telegram_api::messageMediaPoll::ID:
      /*
      // the users and chats are always min, so no need to check
      auto message_media_poll = static_cast<const telegram_api::messageMediaPoll *>(media_ptr.get());
      for (auto recent_voter : message_media_poll->results_->recent_voters_) {
        if (!is_acceptable_peer(recent_voter)) {
          return false;
        }
      }
      */
      return true;
    case telegram_api::messageMediaWebPage::ID:
      /*
      // the channel is always min, so no need to check
      auto message_media_web_page = static_cast<const telegram_api::messageMediaWebPage *>(media_ptr.get());
      if (message_media_web_page->webpage_->get_id() == telegram_api::webPage::ID) {
        auto web_page = static_cast<const telegram_api::webPage *>(message_media_web_page->webpage_.get());
        if (web_page->cached_page_ != nullptr) {
          const vector<tl_object_ptr<telegram_api::PageBlock>> *page_blocks = nullptr;
          downcast_call(*web_page->cached_page_, [&page_blocks](auto &page) { page_blocks = &page.blocks_; });
          CHECK(page_blocks != nullptr);
          for (auto &page_block : *page_blocks) {
            if (page_block->get_id() == telegram_api::pageBlockChannel::ID) {
              auto page_block_channel = static_cast<const telegram_api::pageBlockChannel *>(page_block.get());
              auto channel_id = ChatManager::get_channel_id(page_block_channel->channel_);
              if (channel_id.is_valid()) {
                if (!is_acceptable_channel(channel_id)) {
                  return false;
                }
              } else {
                LOG(ERROR) << "Receive wrong channel " << to_string(page_block_channel->channel_);
              }
            }
          }
        }
      }
      */
      return true;
    default:
      return true;
  }
}

bool UpdatesManager::is_acceptable_message(const telegram_api::Message *message_ptr) const {
  CHECK(message_ptr != nullptr);
  int32 constructor_id = message_ptr->get_id();

  switch (constructor_id) {
    case telegram_api::messageEmpty::ID:
      return true;
    case telegram_api::message::ID: {
      auto message = static_cast<const telegram_api::message *>(message_ptr);

      if (!is_acceptable_peer(message->peer_id_)) {
        return false;
      }
      if (!is_acceptable_peer(message->from_id_)) {
        return false;
      }

      if (!is_acceptable_message_reply_header(message->reply_to_)) {
        return false;
      }
      if (!is_acceptable_message_forward_header(message->fwd_from_)) {
        return false;
      }

      UserId via_bot_user_id(message->via_bot_id_);
      if (via_bot_user_id != UserId() && !is_acceptable_user(via_bot_user_id)) {
        return false;
      }

      if (!is_acceptable_message_entities(message->entities_)) {
        return false;
      }

      if (!is_acceptable_message_media(message->media_)) {
        return false;
      }

      /*
      // the dialogs are always min, so no need to check
      if (message->replies_ != nullptr) {
        for (auto &peer : message->replies_->recent_repliers_) {
          if (!is_acceptable_peer(peer)) {
            return false;
          }
        }
      }
      */

      break;
    }
    case telegram_api::messageService::ID: {
      auto message = static_cast<const telegram_api::messageService *>(message_ptr);

      if (!is_acceptable_peer(message->peer_id_)) {
        return false;
      }
      if (!is_acceptable_peer(message->from_id_)) {
        return false;
      }

      const telegram_api::MessageAction *action = message->action_.get();
      CHECK(action != nullptr);

      switch (action->get_id()) {
        case telegram_api::messageActionEmpty::ID:
        case telegram_api::messageActionChatEditTitle::ID:
        case telegram_api::messageActionChatEditPhoto::ID:
        case telegram_api::messageActionChatDeletePhoto::ID:
        case telegram_api::messageActionCustomAction::ID:
        case telegram_api::messageActionBotAllowed::ID:
        case telegram_api::messageActionHistoryClear::ID:
        case telegram_api::messageActionChannelCreate::ID:
        case telegram_api::messageActionPinMessage::ID:
        case telegram_api::messageActionGameScore::ID:
        case telegram_api::messageActionPhoneCall::ID:
        case telegram_api::messageActionPaymentSent::ID:
        case telegram_api::messageActionPaymentSentMe::ID:
        case telegram_api::messageActionScreenshotTaken::ID:
        case telegram_api::messageActionSecureValuesSent::ID:
        case telegram_api::messageActionSecureValuesSentMe::ID:
        case telegram_api::messageActionContactSignUp::ID:
        case telegram_api::messageActionGroupCall::ID:
        case telegram_api::messageActionGroupCallScheduled::ID:
        case telegram_api::messageActionSetChatTheme::ID:
        case telegram_api::messageActionChatJoinedByRequest::ID:
        case telegram_api::messageActionWebViewDataSentMe::ID:
        case telegram_api::messageActionWebViewDataSent::ID:
        case telegram_api::messageActionGiftPremium::ID:
        case telegram_api::messageActionTopicCreate::ID:
        case telegram_api::messageActionTopicEdit::ID:
        case telegram_api::messageActionSuggestProfilePhoto::ID:
        case telegram_api::messageActionSetChatWallPaper::ID:
        case telegram_api::messageActionGiveawayLaunch::ID:
        case telegram_api::messageActionGiveawayResults::ID:
        case telegram_api::messageActionBoostApply::ID:
        case telegram_api::messageActionRequestedPeerSentMe::ID:
        case telegram_api::messageActionGiftStars::ID:
        case telegram_api::messageActionPrizeStars::ID:
        case telegram_api::messageActionStarGift::ID:
        case telegram_api::messageActionStarGiftUnique::ID:
          break;
        case telegram_api::messageActionChatCreate::ID: {
          auto chat_create = static_cast<const telegram_api::messageActionChatCreate *>(action);
          for (auto &user : chat_create->users_) {
            if (!is_acceptable_user(UserId(user))) {
              return false;
            }
          }
          break;
        }
        case telegram_api::messageActionChatAddUser::ID: {
          auto chat_add_user = static_cast<const telegram_api::messageActionChatAddUser *>(action);
          for (auto &user : chat_add_user->users_) {
            if (!is_acceptable_user(UserId(user))) {
              return false;
            }
          }
          break;
        }
        case telegram_api::messageActionChatJoinedByLink::ID:
          // inviter_id_ isn't used
          break;
        case telegram_api::messageActionChatDeleteUser::ID: {
          auto chat_delete_user = static_cast<const telegram_api::messageActionChatDeleteUser *>(action);
          if (!is_acceptable_user(UserId(chat_delete_user->user_id_))) {
            return false;
          }
          break;
        }
        case telegram_api::messageActionChatMigrateTo::ID: {
          auto chat_migrate_to = static_cast<const telegram_api::messageActionChatMigrateTo *>(action);
          if (!is_acceptable_channel(ChannelId(chat_migrate_to->channel_id_))) {
            return false;
          }
          break;
        }
        case telegram_api::messageActionChannelMigrateFrom::ID: {
          auto channel_migrate_from = static_cast<const telegram_api::messageActionChannelMigrateFrom *>(action);
          if (!is_acceptable_chat(ChatId(channel_migrate_from->chat_id_))) {
            return false;
          }
          break;
        }
        case telegram_api::messageActionGeoProximityReached::ID: {
          auto geo_proximity_reached = static_cast<const telegram_api::messageActionGeoProximityReached *>(action);
          if (!is_acceptable_peer(geo_proximity_reached->from_id_)) {
            return false;
          }
          if (!is_acceptable_peer(geo_proximity_reached->to_id_)) {
            return false;
          }
          break;
        }
        case telegram_api::messageActionInviteToGroupCall::ID: {
          auto invite_to_group_call = static_cast<const telegram_api::messageActionInviteToGroupCall *>(action);
          for (auto &user : invite_to_group_call->users_) {
            if (!is_acceptable_user(UserId(user))) {
              return false;
            }
          }
          break;
        }
        case telegram_api::messageActionSetMessagesTTL::ID: {
          auto set_messages_ttl = static_cast<const telegram_api::messageActionSetMessagesTTL *>(action);
          if (set_messages_ttl->auto_setting_from_ != 0 &&
              !is_acceptable_user(UserId(set_messages_ttl->auto_setting_from_))) {
            return false;
          }
          break;
        }
        case telegram_api::messageActionRequestedPeer::ID: {
          auto requested_peer = static_cast<const telegram_api::messageActionRequestedPeer *>(action);
          if (!td_->auth_manager_->is_bot()) {
            for (auto &peer : requested_peer->peers_) {
              if (!is_acceptable_peer(peer)) {
                return false;
              }
            }
          }
          break;
        }
        case telegram_api::messageActionGiftCode::ID: {
          auto gift_code = static_cast<const telegram_api::messageActionGiftCode *>(action);
          if (!is_acceptable_peer(gift_code->boost_peer_)) {
            return false;
          }
          break;
        }
        case telegram_api::messageActionPaymentRefunded::ID: {
          auto payment_refunded = static_cast<const telegram_api::messageActionPaymentRefunded *>(action);
          if (!is_acceptable_peer(payment_refunded->peer_)) {
            return false;
          }
          break;
        }
        default:
          UNREACHABLE();
          return false;
      }
      break;
    }
    default:
      UNREACHABLE();
      return false;
  }

  return true;
}

bool UpdatesManager::is_acceptable_update(const telegram_api::Update *update) const {
  if (update == nullptr) {
    return true;
  }
  int32 id = update->get_id();
  const telegram_api::Message *message = nullptr;
  if (id == telegram_api::updateNewMessage::ID) {
    message = static_cast<const telegram_api::updateNewMessage *>(update)->message_.get();
  }
  if (id == telegram_api::updateNewChannelMessage::ID) {
    message = static_cast<const telegram_api::updateNewChannelMessage *>(update)->message_.get();
  }
  if (id == telegram_api::updateNewScheduledMessage::ID) {
    message = static_cast<const telegram_api::updateNewScheduledMessage *>(update)->message_.get();
  }
  if (id == telegram_api::updateEditMessage::ID) {
    message = static_cast<const telegram_api::updateEditMessage *>(update)->message_.get();
  }
  if (id == telegram_api::updateEditChannelMessage::ID) {
    message = static_cast<const telegram_api::updateEditChannelMessage *>(update)->message_.get();
  }
  if (message != nullptr) {
    return is_acceptable_message(message);
  }

  return true;
}

void UpdatesManager::on_get_updates(tl_object_ptr<telegram_api::Updates> &&updates_ptr, Promise<Unit> &&promise) {
  send_closure_later(actor_id(this), &UpdatesManager::on_get_updates_impl, std::move(updates_ptr), std::move(promise));
}

void UpdatesManager::on_get_updates_impl(telegram_api::object_ptr<telegram_api::Updates> updates_ptr,
                                         Promise<Unit> promise) {
  CHECK(updates_ptr != nullptr);
  promise = PromiseCreator::lambda(
      [promise = std::move(promise), update_ids = get_update_ids(updates_ptr.get())](Result<Unit> result) mutable {
        if (!G()->close_flag() && result.is_error()) {
          LOG(ERROR) << "Failed to process updates " << update_ids << ": " << result.error();
        }
        promise.set_value(Unit());
      });

  auto updates_type = updates_ptr->get_id();
  if (updates_type != telegram_api::updateShort::ID) {
    LOG(INFO) << "Receive " << to_string(updates_ptr);
  }
  if (!td_->auth_manager_->is_authorized()) {
    if (updates_type == telegram_api::updateShort::ID && !G()->close_flag()) {
      auto &update = static_cast<telegram_api::updateShort *>(updates_ptr.get())->update_;
      auto update_id = update->get_id();
      if (update_id == telegram_api::updateLoginToken::ID) {
        td_->auth_manager_->on_update_login_token();
        return promise.set_value(Unit());
      }

      switch (update_id) {
        case telegram_api::updateServiceNotification::ID:
        case telegram_api::updateDcOptions::ID:
        case telegram_api::updateConfig::ID:
        case telegram_api::updateLangPackTooLong::ID:
        case telegram_api::updateLangPack::ID:
          LOG(INFO) << "Apply without authorization " << to_string(updates_ptr);
          downcast_call(*update, OnUpdate(this, update, std::move(promise)));
          return;
        default:
          break;
      }
    }
    LOG(INFO) << "Ignore received before authorization or after logout " << to_string(updates_ptr);
    return promise.set_value(Unit());
  }

  switch (updates_type) {
    case telegram_api::updatesTooLong::ID:
      get_difference("updatesTooLong");
      promise.set_value(Unit());
      break;
    case telegram_api::updateShortMessage::ID: {
      auto update = telegram_api::move_object_as<telegram_api::updateShortMessage>(updates_ptr);
      auto from_id = update->out_ ? td_->user_manager_->get_my_id().get() : update->user_id_;
      auto message = telegram_api::make_object<telegram_api::message>(
          0 /*unused*/, update->out_, update->mentioned_, update->media_unread_, update->silent_, false, false, false,
          false, false, false, false, false, 0, false, update->id_,
          telegram_api::make_object<telegram_api::peerUser>(from_id), 0,
          telegram_api::make_object<telegram_api::peerUser>(update->user_id_), nullptr, std::move(update->fwd_from_),
          update->via_bot_id_, 0, std::move(update->reply_to_), update->date_, update->message_, nullptr, nullptr,
          std::move(update->entities_), 0, 0, nullptr, 0, string(), 0, nullptr, Auto(), update->ttl_period_, 0, 0,
          nullptr, 0, 0);
      on_pending_update(telegram_api::make_object<telegram_api::updateNewMessage>(std::move(message), update->pts_,
                                                                                  update->pts_count_),
                        0, std::move(promise), "telegram_api::updateShortMessage");
      break;
    }
    case telegram_api::updateShortChatMessage::ID: {
      auto update = telegram_api::move_object_as<telegram_api::updateShortChatMessage>(updates_ptr);
      auto message = telegram_api::make_object<telegram_api::message>(
          0 /*unused*/, update->out_, update->mentioned_, update->media_unread_, update->silent_, false, false, false,
          false, false, false, false, false, 0, false, update->id_,
          telegram_api::make_object<telegram_api::peerUser>(update->from_id_), 0,
          telegram_api::make_object<telegram_api::peerChat>(update->chat_id_), nullptr, std::move(update->fwd_from_),
          update->via_bot_id_, 0, std::move(update->reply_to_), update->date_, update->message_, nullptr, nullptr,
          std::move(update->entities_), 0, 0, nullptr, 0, string(), 0, nullptr, Auto(), update->ttl_period_, 0, 0,
          nullptr, 0, 0);
      on_pending_update(telegram_api::make_object<telegram_api::updateNewMessage>(std::move(message), update->pts_,
                                                                                  update->pts_count_),
                        0, std::move(promise), "telegram_api::updateShortChatMessage");
      break;
    }
    case telegram_api::updateShort::ID: {
      auto update = telegram_api::move_object_as<telegram_api::updateShort>(updates_ptr);
      LOG(DEBUG) << "Receive " << oneline(to_string(update));
      if (!is_acceptable_update(update->update_.get())) {
        LOG(ERROR) << "Receive unacceptable short update: " << oneline(to_string(update));
        promise.set_value(Unit());
        return get_difference("unacceptable short update");
      }
      short_update_date_ = update->date_;
      downcast_call(*update->update_, OnUpdate(this, update->update_, std::move(promise)));
      short_update_date_ = 0;
      break;
    }
    case telegram_api::updatesCombined::ID: {
      auto updates = telegram_api::move_object_as<telegram_api::updatesCombined>(updates_ptr);
      td_->user_manager_->on_get_users(std::move(updates->users_), "updatesCombined");
      td_->chat_manager_->on_get_chats(std::move(updates->chats_), "updatesCombined");
      on_pending_updates(std::move(updates->updates_), updates->seq_start_, updates->seq_, updates->date_, Time::now(),
                         std::move(promise), "telegram_api::updatesCombined");
      break;
    }
    case telegram_api::updates::ID: {
      auto updates = telegram_api::move_object_as<telegram_api::updates>(updates_ptr);
      string source_str;
      const char *source = "updates";
      if (updates->updates_.size() == 1 && updates->updates_[0] != nullptr) {
        source_str = PSTRING() << "update " << updates->updates_[0]->get_id();
        source = source_str.c_str();
      }
      td_->user_manager_->on_get_users(std::move(updates->users_), source);
      td_->chat_manager_->on_get_chats(std::move(updates->chats_), source);
      on_pending_updates(std::move(updates->updates_), updates->seq_, updates->seq_, updates->date_, Time::now(),
                         std::move(promise), "telegram_api::updates");
      break;
    }
    case telegram_api::updateShortSentMessage::ID:
      LOG(ERROR) << "Receive " << oneline(to_string(updates_ptr));
      get_difference("updateShortSentMessage");
      promise.set_value(Unit());
      break;
    default:
      UNREACHABLE();
  }
}

void UpdatesManager::on_failed_get_updates_state(Status &&error) {
  if (G()->close_flag() || !td_->auth_manager_->is_authorized()) {
    return;
  }
  if (error.code() != 401) {
    LOG(ERROR) << "Receive updates.getState error: " << error;
  }

  running_get_difference_ = false;
  schedule_get_difference("on_failed_get_updates_state");
}

void UpdatesManager::on_failed_get_difference(Status &&error) {
  if (G()->close_flag() || !td_->auth_manager_->is_authorized()) {
    return;
  }
  if (error.code() != 401) {
    LOG(ERROR) << "Receive updates.getDifference error: " << error;
  }

  running_get_difference_ = false;
  schedule_get_difference("on_failed_get_difference");

  if (error.message() == Slice("PERSISTENT_TIMESTAMP_INVALID")) {
    set_pts(std::numeric_limits<int32>::max(), "PERSISTENT_TIMESTAMP_INVALID").set_value(Unit());
  }
}

void UpdatesManager::schedule_get_difference(const char *source) {
  if (G()->close_flag() || !td_->auth_manager_->is_authorized()) {
    return;
  }
  if (!retry_timeout_.has_timeout()) {
    LOG(WARNING) << "Schedule getDifference in " << retry_time_ << " seconds with PTS = " << get_pts()
                 << ", QTS = " << get_qts() << ", date = " << get_date() << " from " << source;
    retry_timeout_.set_callback(std::move(fill_get_difference_gap));
    retry_timeout_.set_callback_data(static_cast<void *>(td_));
    retry_timeout_.set_timeout_in(retry_time_);
    retry_time_ *= 2;
    if (retry_time_ > 60) {
      retry_time_ = Random::fast(60, 80);
    }
  } else {
    VLOG(get_difference) << "Schedule getDifference from " << source;
  }
}

void UpdatesManager::on_get_updates_state(tl_object_ptr<telegram_api::updates_state> &&state, const char *source) {
  CHECK(state != nullptr);

  VLOG(get_difference) << "Receive " << oneline(to_string(state)) << " from " << source;
  // TODO use state->unread_count;

  if (get_pts() == std::numeric_limits<int32>::max()) {
    LOG(WARNING) << "Restore PTS to " << state->pts_;
    // restoring right PTS
    CHECK(pending_pts_updates_.empty());
    auto real_running_get_difference = running_get_difference_;
    running_get_difference_ = false;
    process_postponed_pts_updates();  // drop all updates with old PTS
    running_get_difference_ = real_running_get_difference;
    pts_manager_.init(state->pts_);
    last_confirmed_pts_ = get_pts();
    last_pts_save_time_ = Time::now() - 2 * MAX_PTS_SAVE_DELAY;
    save_pts(state->pts_);
  } else {
    string full_source = "on_get_updates_state " + oneline(to_string(state)) + " from " + source;
    set_pts(state->pts_, full_source.c_str()).set_value(Unit());
    set_date(state->date_, false, std::move(full_source));
    add_qts(state->qts_).set_value(Unit());

    seq_ = state->seq_;
  }

  if (running_get_difference_) {  // called from getUpdatesState
    running_get_difference_ = false;
    after_get_difference();
  }
}

const vector<tl_object_ptr<telegram_api::Update>> *UpdatesManager::get_updates(
    const telegram_api::Updates *updates_ptr) {
  switch (updates_ptr->get_id()) {
    case telegram_api::updatesTooLong::ID:
    case telegram_api::updateShortMessage::ID:
    case telegram_api::updateShortChatMessage::ID:
    case telegram_api::updateShort::ID:
    case telegram_api::updateShortSentMessage::ID:
      LOG(ERROR) << "Receive " << oneline(to_string(*updates_ptr)) << " instead of updates";
      return nullptr;
    case telegram_api::updatesCombined::ID:
      return &static_cast<const telegram_api::updatesCombined *>(updates_ptr)->updates_;
    case telegram_api::updates::ID:
      return &static_cast<const telegram_api::updates *>(updates_ptr)->updates_;
    default:
      UNREACHABLE();
      return nullptr;
  }
}

vector<tl_object_ptr<telegram_api::Update>> *UpdatesManager::get_updates(telegram_api::Updates *updates_ptr) {
  return const_cast<vector<tl_object_ptr<telegram_api::Update>> *>(
      get_updates(static_cast<const telegram_api::Updates *>(updates_ptr)));
}

bool UpdatesManager::are_empty_updates(const telegram_api::Updates *updates_ptr) {
  switch (updates_ptr->get_id()) {
    case telegram_api::updatesTooLong::ID:
    case telegram_api::updateShortSentMessage::ID:
      return true;
    case telegram_api::updateShortMessage::ID:
    case telegram_api::updateShortChatMessage::ID:
    case telegram_api::updateShort::ID:
      return false;
    case telegram_api::updatesCombined::ID:
      return static_cast<const telegram_api::updatesCombined *>(updates_ptr)->updates_.empty();
    case telegram_api::updates::ID:
      return static_cast<const telegram_api::updates *>(updates_ptr)->updates_.empty();
    default:
      UNREACHABLE();
      return true;
  }
}

FlatHashSet<int64> UpdatesManager::get_sent_messages_random_ids(const telegram_api::Updates *updates_ptr) {
  FlatHashSet<int64> random_ids;
  auto updates = get_updates(updates_ptr);
  if (updates != nullptr) {
    auto new_messages = get_new_messages(updates_ptr);
    for (auto &update : *updates) {
      if (update->get_id() == telegram_api::updateMessageID::ID) {
        auto update_message_id = static_cast<const telegram_api::updateMessageID *>(update.get());
        int64 random_id = update_message_id->random_id_;
        if (random_id != 0) {
          bool found_message = false;
          for (auto message : new_messages) {
            MessageId message_id = MessageId::get_message_id(message.first, message.second);
            if (message.second) {
              found_message |= message_id.is_valid_scheduled() &&
                               message_id.get_scheduled_server_message_id().get() == update_message_id->id_;
            } else {
              found_message |=
                  message_id.is_valid() && message_id.get_server_message_id().get() == update_message_id->id_;
            }
          }
          if (found_message && !random_ids.insert(random_id).second) {
            LOG(ERROR) << "Receive twice updateMessageID for " << random_id;
          }
        }
      }
    }
  }
  return random_ids;
}

const telegram_api::Message *UpdatesManager::get_message_by_random_id(const telegram_api::Updates *updates_ptr,
                                                                      DialogId dialog_id, int64 random_id) {
  auto updates = get_updates(updates_ptr);
  if (updates == nullptr) {
    return nullptr;
  }

  int32 message_id = 0;
  for (auto &update : *updates) {
    if (update->get_id() == telegram_api::updateMessageID::ID) {
      auto update_message_id = static_cast<const telegram_api::updateMessageID *>(update.get());
      if (update_message_id->random_id_ == random_id) {
        if (message_id != 0 || update_message_id->id_ == 0) {
          return nullptr;
        }
        message_id = update_message_id->id_;
      }
    }
  }
  if (message_id == 0) {
    return nullptr;
  }

  const telegram_api::Message *result = nullptr;
  MessageFullId message_full_id(dialog_id, MessageId(ServerMessageId(message_id)));
  for (auto &update : *updates) {
    auto constructor_id = update->get_id();
    const tl_object_ptr<telegram_api::Message> *message = nullptr;
    if (constructor_id == telegram_api::updateNewMessage::ID) {
      message = &static_cast<const telegram_api::updateNewMessage *>(update.get())->message_;
    } else if (constructor_id == telegram_api::updateNewChannelMessage::ID) {
      message = &static_cast<const telegram_api::updateNewChannelMessage *>(update.get())->message_;
    }
    if (message != nullptr && MessageFullId::get_message_full_id(*message, false) == message_full_id) {
      if (result != nullptr) {
        return nullptr;
      }
      result = message->get();
    }
  }
  return result;
}

bool UpdatesManager::is_additional_service_message(const telegram_api::Message *message) {
  if (message->get_id() != telegram_api::messageService::ID) {
    return false;
  }
  auto action_id = static_cast<const telegram_api::messageService *>(message)->action_->get_id();
  return action_id == telegram_api::messageActionSetMessagesTTL::ID;
}

vector<std::pair<const telegram_api::Message *, bool>> UpdatesManager::get_new_messages(
    const telegram_api::Updates *updates_ptr) {
  vector<std::pair<const telegram_api::Message *, bool>> messages;
  auto updates = get_updates(updates_ptr);
  if (updates != nullptr) {
    for (auto &update : *updates) {
      const telegram_api::Message *message = nullptr;
      bool is_scheduled = false;
      auto constructor_id = update->get_id();
      if (constructor_id == telegram_api::updateNewMessage::ID) {
        message = static_cast<const telegram_api::updateNewMessage *>(update.get())->message_.get();
      } else if (constructor_id == telegram_api::updateNewChannelMessage::ID) {
        message = static_cast<const telegram_api::updateNewChannelMessage *>(update.get())->message_.get();
      } else if (constructor_id == telegram_api::updateNewScheduledMessage::ID) {
        message = static_cast<const telegram_api::updateNewScheduledMessage *>(update.get())->message_.get();
        is_scheduled = true;
      }

      if (message != nullptr && !is_additional_service_message(message)) {
        messages.emplace_back(message, is_scheduled);
      }
    }
  }
  return messages;
}

vector<InputGroupCallId> UpdatesManager::get_update_new_group_call_ids(const telegram_api::Updates *updates_ptr) {
  vector<InputGroupCallId> input_group_call_ids;
  auto updates = get_updates(updates_ptr);
  if (updates != nullptr) {
    for (auto &update : *updates) {
      InputGroupCallId input_group_call_id;
      if (update->get_id() == telegram_api::updateGroupCall::ID) {
        auto group_call_ptr = static_cast<const telegram_api::updateGroupCall *>(update.get())->call_.get();
        if (group_call_ptr->get_id() == telegram_api::groupCall::ID) {
          auto group_call = static_cast<const telegram_api::groupCall *>(group_call_ptr);
          input_group_call_id = InputGroupCallId(group_call->id_, group_call->access_hash_);
        }
      }

      if (input_group_call_id.is_valid()) {
        input_group_call_ids.push_back(input_group_call_id);
      }
    }
  }
  return input_group_call_ids;
}

string UpdatesManager::extract_join_group_call_presentation_params(telegram_api::Updates *updates_ptr) {
  auto updates = get_updates(updates_ptr);
  for (auto it = updates->begin(); it != updates->end(); ++it) {
    auto *update = it->get();
    if (update->get_id() == telegram_api::updateGroupCallConnection::ID &&
        static_cast<const telegram_api::updateGroupCallConnection *>(update)->presentation_) {
      string result = std::move(static_cast<telegram_api::updateGroupCallConnection *>(update)->params_->data_);
      updates->erase(it);
      return result;
    }
  }
  return string();
}

vector<DialogId> UpdatesManager::get_update_notify_settings_dialog_ids(const telegram_api::Updates *updates_ptr) {
  vector<DialogId> dialog_ids;
  auto updates = get_updates(updates_ptr);
  if (updates != nullptr) {
    dialog_ids.reserve(updates->size());
    for (auto &update : *updates) {
      DialogId dialog_id;
      if (update->get_id() == telegram_api::updateNotifySettings::ID) {
        auto notify_peer = static_cast<const telegram_api::updateNotifySettings *>(update.get())->peer_.get();
        if (notify_peer->get_id() == telegram_api::notifyPeer::ID) {
          dialog_id = DialogId(static_cast<const telegram_api::notifyPeer *>(notify_peer)->peer_);
        }
      }

      if (dialog_id.is_valid()) {
        dialog_ids.push_back(dialog_id);
      } else {
        LOG(ERROR) << "Receive unexpected " << to_string(update);
      }
    }
  }
  return dialog_ids;
}

vector<int32> UpdatesManager::get_update_ids(const telegram_api::Updates *updates_ptr) {
  const vector<tl_object_ptr<telegram_api::Update>> *updates = nullptr;
  auto updates_type = updates_ptr->get_id();
  switch (updates_type) {
    case telegram_api::updatesTooLong::ID:
    case telegram_api::updateShortMessage::ID:
    case telegram_api::updateShortChatMessage::ID:
    case telegram_api::updateShortSentMessage::ID:
      return {updates_type};
    case telegram_api::updateShort::ID: {
      const auto *update = static_cast<const telegram_api::updateShort *>(updates_ptr)->update_.get();
      if (update != nullptr) {
        return {update->get_id()};
      }
      return {updates_type};
    }
    case telegram_api::updatesCombined::ID:
      updates = &static_cast<const telegram_api::updatesCombined *>(updates_ptr)->updates_;
      break;
    case telegram_api::updates::ID:
      updates = &static_cast<const telegram_api::updates *>(updates_ptr)->updates_;
      break;
    default:
      UNREACHABLE();
  }

  vector<int32> result;
  result.reserve(updates->size());
  for (auto &update : *updates) {
    if (update != nullptr) {
      result.push_back(update->get_id());
    }
  }
  return result;
}

vector<DialogId> UpdatesManager::get_chat_dialog_ids(const telegram_api::Updates *updates_ptr) {
  const vector<tl_object_ptr<telegram_api::Chat>> *chats = nullptr;
  switch (updates_ptr->get_id()) {
    case telegram_api::updatesTooLong::ID:
    case telegram_api::updateShortMessage::ID:
    case telegram_api::updateShortChatMessage::ID:
    case telegram_api::updateShort::ID:
    case telegram_api::updateShortSentMessage::ID:
      LOG(ERROR) << "Receive " << oneline(to_string(*updates_ptr)) << " instead of updates";
      break;
    case telegram_api::updatesCombined::ID:
      chats = &static_cast<const telegram_api::updatesCombined *>(updates_ptr)->chats_;
      break;
    case telegram_api::updates::ID:
      chats = &static_cast<const telegram_api::updates *>(updates_ptr)->chats_;
      break;
    default:
      UNREACHABLE();
  }

  if (chats == nullptr) {
    return {};
  }

  vector<DialogId> dialog_ids;
  dialog_ids.reserve(chats->size());
  for (const auto &chat : *chats) {
    auto dialog_id = ChatManager::get_dialog_id(chat);
    if (dialog_id.is_valid()) {
      dialog_ids.push_back(dialog_id);
    } else {
      LOG(ERROR) << "Can't find identifier of " << oneline(to_string(chat));
    }
  }
  if (dialog_ids.size() > 1) {
    td::remove(dialog_ids, DialogId(ChatManager::get_unsupported_channel_id()));
  }
  return dialog_ids;
}

int32 UpdatesManager::get_update_edit_message_pts(const telegram_api::Updates *updates_ptr,
                                                  MessageFullId message_full_id) {
  int32 pts = 0;
  auto updates = get_updates(updates_ptr);
  if (updates != nullptr) {
    for (auto &update_ptr : *updates) {
      int32 update_pts = [&] {
        switch (update_ptr->get_id()) {
          case telegram_api::updateEditMessage::ID: {
            auto update = static_cast<const telegram_api::updateEditMessage *>(update_ptr.get());
            if (MessageFullId::get_message_full_id(update->message_, false) == message_full_id) {
              return update->pts_;
            }
            return 0;
          }
          case telegram_api::updateEditChannelMessage::ID: {
            auto update = static_cast<const telegram_api::updateEditChannelMessage *>(update_ptr.get());
            if (MessageFullId::get_message_full_id(update->message_, false) == message_full_id) {
              return update->pts_;
            }
            return 0;
          }
          case telegram_api::updateNewScheduledMessage::ID: {
            auto update = static_cast<const telegram_api::updateNewScheduledMessage *>(update_ptr.get());
            auto new_message_full_id = MessageFullId::get_message_full_id(update->message_, true);
            if (new_message_full_id.get_dialog_id() == message_full_id.get_dialog_id()) {
              auto new_message_id = new_message_full_id.get_message_id();
              auto old_message_id = message_full_id.get_message_id();
              if (new_message_id.is_valid_scheduled() && new_message_id.is_scheduled_server() &&
                  old_message_id.is_valid_scheduled() && old_message_id.is_scheduled_server() &&
                  old_message_id.get_scheduled_server_message_id() ==
                      new_message_id.get_scheduled_server_message_id()) {
                return -2;
              }
            }
            return 0;
          }
          default:
            return 0;
        }
      }();
      if (update_pts != 0) {
        if (pts == 0) {
          pts = update_pts;
        } else {
          pts = -1;
        }
      }
    }
  }
  if (pts == -1) {
    LOG(ERROR) << "Receive multiple edit message updates in " << to_string(*updates_ptr);
    pts = 0;
  } else if (pts == 0) {
    LOG(ERROR) << "Receive no edit message updates for " << message_full_id << " in " << to_string(*updates_ptr);
  }
  return pts;
}

void UpdatesManager::init_state() {
  if (G()->close_flag() || !td_->auth_manager_->is_authorized()) {
    return;
  }

  bool drop_state = get_pts() == -1 && td_->can_ignore_background_updates() && td_->auth_manager_->is_bot() &&
                    td_->option_manager_->get_option_integer("since_last_open") >= 2 * 86400;

  auto pmc = G()->td_db()->get_binlog_pmc();
  if (td_->ignore_background_updates() || drop_state) {
    // just in case
    pmc->erase("updates.pts");
    pmc->erase("updates.qts");
    pmc->erase("updates.date");
  }
  string pts_str = pmc->get("updates.pts");
  if (pts_str.empty()) {
    if (!running_get_difference_) {
      running_get_difference_ = true;

      before_get_difference(true);

      auto promise = PromiseCreator::lambda([](Result<tl_object_ptr<telegram_api::updates_state>> result) {
        if (result.is_ok()) {
          send_closure(G()->updates_manager(), &UpdatesManager::on_get_updates_state, result.move_as_ok(),
                       "GetUpdatesStateQuery");
        } else {
          send_closure(G()->updates_manager(), &UpdatesManager::on_failed_get_updates_state, result.move_as_error());
        }
      });
      td_->create_handler<GetUpdatesStateQuery>(std::move(promise))->send();
    }
    return;
  }
  pts_manager_.init(to_integer<int32>(pts_str));
  last_confirmed_pts_ = get_pts();
  qts_manager_.init(to_integer<int32>(pmc->get("updates.qts")));
  last_confirmed_qts_ = get_qts();
  date_ = to_integer<int32>(pmc->get("updates.date"));
  date_source_ = "database";
  LOG(DEBUG) << "Init: " << get_pts() << " " << get_qts() << " " << date_;

  get_difference("init_state");
}

uint64 UpdatesManager::get_most_unused_auth_key_id() {
  uint64 min_auth_key_id = 0;
  double min_time = Time::now();
  for (auto &it : session_infos_) {
    if (it.second.last_update_time < min_time) {
      min_time = it.second.last_update_time;
      min_auth_key_id = it.first;
    }
  }
  return min_auth_key_id;
}

void UpdatesManager::on_update_from_auth_key_id(uint64 auth_key_id) {
  if (auth_key_id == 0) {
    return;
  }

  auto &info = session_infos_[auth_key_id];
  auto now = Time::now();
  info.last_update_time = now;
  if (info.update_count++ == 0) {
    info.first_update_time = now;
    while (session_infos_.size() >
           static_cast<size_t>(max(narrow_cast<int32>(G()->get_option_integer("session_count")), 1))) {
      auto unused_auth_key_id = get_most_unused_auth_key_id();
      LOG(INFO) << "Delete statistics for auth key " << unused_auth_key_id;
      session_infos_.erase(unused_auth_key_id);
    }
  }
}

void UpdatesManager::ping_server() {
  if (is_ping_sent_) {
    return;
  }
  is_ping_sent_ = true;
  auto promise = PromiseCreator::lambda([](Result<tl_object_ptr<telegram_api::updates_state>> result) {
    auto state = result.is_ok() ? result.move_as_ok() : nullptr;
    send_closure(G()->updates_manager(), &UpdatesManager::on_server_pong, std::move(state));
  });
  td_->create_handler<PingServerQuery>(std::move(promise))->send();
}

void UpdatesManager::on_server_pong(tl_object_ptr<telegram_api::updates_state> &&state) {
  LOG(INFO) << "Receive " << oneline(to_string(state));
  is_ping_sent_ = false;
  if (state == nullptr || state->pts_ > get_pts() || state->seq_ > seq_) {
    get_difference("on server pong");
  }
}

void UpdatesManager::notify_speed_limited(bool is_upload) {
  if (Time::now() < next_notify_speed_limited_[is_upload]) {
    return;
  }
  next_notify_speed_limited_[is_upload] =
      Time::now() +
      static_cast<double>(td_->option_manager_->get_option_integer("upload_premium_speedup_notify_period"));
  send_closure(G()->td(), &Td::send_update, td_api::make_object<td_api::updateSpeedLimitNotification>(is_upload));
}

void UpdatesManager::process_get_difference_updates(
    vector<tl_object_ptr<telegram_api::Message>> &&new_messages,
    vector<tl_object_ptr<telegram_api::EncryptedMessage>> &&new_encrypted_messages,
    vector<tl_object_ptr<telegram_api::Update>> &&other_updates) {
  VLOG(get_difference) << "In get difference receive " << new_messages.size() << " messages, "
                       << new_encrypted_messages.size() << " encrypted messages and " << other_updates.size()
                       << " other updates";
  for (auto &update : other_updates) {
    auto constructor_id = update->get_id();
    if (constructor_id == telegram_api::updateMessageID::ID) {
      // in getDifference updateMessageID can't be received for scheduled messages
      LOG(INFO) << "Receive update about sent message " << to_string(update);
      auto update_message_id = move_tl_object_as<telegram_api::updateMessageID>(update);
      td_->messages_manager_->on_update_message_id(update_message_id->random_id_,
                                                   MessageId(ServerMessageId(update_message_id->id_)), "getDifference");
      CHECK(!running_get_difference_);
    }

    if (constructor_id == telegram_api::updateStoryID::ID) {
      LOG(INFO) << "Receive update about sent story " << to_string(update);
      auto update_story_id = move_tl_object_as<telegram_api::updateStoryID>(update);
      td_->story_manager_->on_update_story_id(update_story_id->random_id_, StoryId(update_story_id->id_),
                                              "getDifference");
      CHECK(!running_get_difference_);
    }

    if (constructor_id == telegram_api::updateEncryption::ID) {
      on_update(move_tl_object_as<telegram_api::updateEncryption>(update), Promise<Unit>());
      CHECK(!running_get_difference_);
    }

    if (constructor_id == telegram_api::updateFolderPeers::ID) {
      auto update_folder_peers = move_tl_object_as<telegram_api::updateFolderPeers>(update);
      if (update_folder_peers->pts_count_ != 0) {
        LOG(ERROR) << "Receive updateFolderPeers with pts_count = " << update_folder_peers->pts_count_;
        update_folder_peers->pts_count_ = 0;
      }
      update_folder_peers->pts_ = 0;
      on_update(std::move(update_folder_peers), Promise<Unit>());
      CHECK(!running_get_difference_);
    }

    if (constructor_id == telegram_api::updateUser::ID) {
      update = nullptr;
    }

    if (constructor_id == telegram_api::updateChat::ID) {
      update = nullptr;
    }

    if (constructor_id == telegram_api::updateChannel::ID) {
      update = nullptr;
    }

    /*
        // TODO can't apply it here, because dialog may not be created yet
        // process updateReadHistoryInbox before new messages
        if (constructor_id == telegram_api::updateReadHistoryInbox::ID) {
          static_cast<telegram_api::updateReadHistoryInbox *>(update.get())->still_unread_count_ = -1;
          process_pts_update(std::move(update));
          CHECK(!running_get_difference_);
        }
    */
  }

  for (auto &message : new_messages) {
    // channel messages must not be received in this vector
    td_->messages_manager_->on_get_message(std::move(message), true, false, false, "get difference");
    CHECK(!running_get_difference_);
  }

  for (auto &encrypted_message : new_encrypted_messages) {
    send_closure(td_->secret_chats_manager_, &SecretChatsManager::on_new_message, std::move(encrypted_message),
                 Promise<Unit>());
  }

  process_updates(std::move(other_updates), true, Promise<Unit>());
}

void UpdatesManager::on_get_difference(tl_object_ptr<telegram_api::updates_Difference> &&difference_ptr) {
  if (G()->close_flag() || !td_->auth_manager_->is_authorized()) {
    return;
  }

  VLOG(get_difference) << "----- END  GET DIFFERENCE-----";
  running_get_difference_ = false;

  LOG(DEBUG) << "Result of get difference: " << to_string(difference_ptr);

  CHECK(difference_ptr != nullptr);
  switch (difference_ptr->get_id()) {
    case telegram_api::updates_differenceEmpty::ID: {
      auto difference = move_tl_object_as<telegram_api::updates_differenceEmpty>(difference_ptr);
      set_date(difference->date_, false, "on_get_difference_empty");
      seq_ = difference->seq_;

      process_pending_qts_updates();
      if (!pending_qts_updates_.empty()) {
        LOG(WARNING) << "Drop " << pending_qts_updates_.size() << " pending QTS updates after receive empty difference";
        auto pending_qts_updates = std::move(pending_qts_updates_);
        pending_qts_updates_.clear();

        for (auto &pending_update : pending_qts_updates) {
          set_promises(pending_update.second.promises);
        }
      }

      process_pending_seq_updates();
      if (!pending_seq_updates_.empty()) {
        LOG(WARNING) << "Drop " << pending_seq_updates_.size() << " pending seq updates after receive empty difference";
        auto pending_seq_updates = std::move(pending_seq_updates_);
        pending_seq_updates_.clear();

        for (auto &pending_update : pending_seq_updates) {
          pending_update.promise.set_value(Unit());
        }
      }
      break;
    }
    case telegram_api::updates_difference::ID: {
      auto difference = move_tl_object_as<telegram_api::updates_difference>(difference_ptr);
      VLOG(get_difference) << "In get difference receive " << difference->users_.size() << " users and "
                           << difference->chats_.size() << " chats";
      td_->user_manager_->on_get_users(std::move(difference->users_), "updates.difference");
      td_->chat_manager_->on_get_chats(std::move(difference->chats_), "updates.difference");

      if (get_difference_retry_count_ <= 5) {
        for (const auto &message : difference->new_messages_) {
          if (MessagesManager::is_invalid_poll_message(message.get())) {
            get_difference_retry_count_++;
            LOG(ERROR) << "Receive invalid poll message in updates.difference after " << get_difference_retry_count_
                       << " tries";
            return run_get_difference(true, "reget difference");
          }
        }
      }

      process_get_difference_updates(std::move(difference->new_messages_),
                                     std::move(difference->new_encrypted_messages_),
                                     std::move(difference->other_updates_));
      if (running_get_difference_) {
        LOG(ERROR) << "Get difference has run while processing get difference updates";
        break;
      }

      on_get_updates_state(std::move(difference->state_), "get difference");
      break;
    }
    case telegram_api::updates_differenceSlice::ID: {
      auto difference = move_tl_object_as<telegram_api::updates_differenceSlice>(difference_ptr);
      bool is_pts_changed = have_update_pts_changed(difference->other_updates_);
      if (difference->intermediate_state_->pts_ >= get_pts() && get_pts() != std::numeric_limits<int32>::max() &&
          difference->intermediate_state_->date_ >= date_ && difference->intermediate_state_->qts_ == get_qts() &&
          !is_pts_changed) {
        // TODO send new getDifference request and apply difference slice only after that
      }

      VLOG(get_difference) << "In get difference receive " << difference->users_.size() << " users and "
                           << difference->chats_.size() << " chats";
      td_->user_manager_->on_get_users(std::move(difference->users_), "updates.differenceSlice");
      td_->chat_manager_->on_get_chats(std::move(difference->chats_), "updates.differenceSlice");

      if (get_difference_retry_count_ <= 5) {
        for (const auto &message : difference->new_messages_) {
          if (MessagesManager::is_invalid_poll_message(message.get())) {
            get_difference_retry_count_++;
            LOG(ERROR) << "Receive invalid poll message in updates.differenceSlice after "
                       << get_difference_retry_count_ << " tries";
            return run_get_difference(true, "reget difference");
          }
        }
      }

      process_get_difference_updates(std::move(difference->new_messages_),
                                     std::move(difference->new_encrypted_messages_),
                                     std::move(difference->other_updates_));
      if (running_get_difference_) {
        if (!is_pts_changed) {
          LOG(ERROR) << "Get difference has run while processing get difference updates";
        }
        break;
      }
      CHECK(!is_pts_changed);

      auto old_pts = get_pts();
      auto old_date = get_date();
      auto old_qts = get_qts();
      on_get_updates_state(std::move(difference->intermediate_state_), "get difference slice");

      process_postponed_pts_updates();
      process_pending_qts_updates();

      auto new_pts = get_pts();
      auto new_date = get_date();
      auto new_qts = get_qts();
      if (old_pts != std::numeric_limits<int32>::max() && new_date == old_date &&
          (new_pts == old_pts || (min_postponed_update_pts_ != 0 && new_pts >= min_postponed_update_pts_)) &&
          (new_qts == old_qts || (min_postponed_update_qts_ != 0 && new_qts >= min_postponed_update_qts_))) {
        VLOG(get_difference) << "Switch back from getDifference to update processing";
        break;
      }

      if (new_pts != -1) {  // just in case
        run_get_difference(true, "on updates_differenceSlice");
      }
      break;
    }
    case telegram_api::updates_differenceTooLong::ID: {
      if (td_->option_manager_->get_option_integer("session_count") <= 1) {
        LOG(ERROR) << "Receive differenceTooLong";
      }
      // TODO
      auto difference = move_tl_object_as<telegram_api::updates_differenceTooLong>(difference_ptr);
      set_pts(difference->pts_, "differenceTooLong").set_value(Unit());
      get_difference("on updates_differenceTooLong");
      break;
    }
    default:
      UNREACHABLE();
  }

  get_difference_retry_count_ = 0;

  if (!running_get_difference_) {
    after_get_difference();
  }
}

void UpdatesManager::on_get_pts_update(int32 pts,
                                       telegram_api::object_ptr<telegram_api::updates_Difference> difference_ptr) {
  if (G()->close_flag() || !td_->auth_manager_->is_authorized()) {
    return;
  }
  LOG(DEBUG) << "Receive update with PTS " << pts << ": " << to_string(difference_ptr);
  if (get_pts() != pts - 1 || running_get_difference_ || !postponed_pts_updates_.empty() ||
      pending_pts_updates_.empty() || pending_pts_updates_.begin()->pts > pts + 1 ||
      pending_pts_updates_.begin()->pts != pts + pending_pts_updates_.begin()->pts_count) {
    return;
  }

  switch (difference_ptr->get_id()) {
    case telegram_api::updates_difference::ID: {
      auto difference = move_tl_object_as<telegram_api::updates_difference>(difference_ptr);
      difference_ptr = telegram_api::make_object<telegram_api::updates_differenceSlice>(
          std::move(difference->new_messages_), std::move(difference->new_encrypted_messages_),
          std::move(difference->other_updates_), std::move(difference->chats_), std::move(difference->users_),
          std::move(difference->state_));
    }
    // fallthrough
    case telegram_api::updates_differenceSlice::ID: {
      auto difference = move_tl_object_as<telegram_api::updates_differenceSlice>(difference_ptr);

      if (have_update_pts_changed(difference->other_updates_)) {
        return;
      }

      td_->user_manager_->on_get_users(std::move(difference->users_), "on_get_pts_update");
      td_->chat_manager_->on_get_chats(std::move(difference->chats_), "on_get_pts_update");

      for (auto &message : difference->new_messages_) {
        difference->other_updates_.push_back(
            telegram_api::make_object<telegram_api::updateNewMessage>(std::move(message), pts, 1));
      }
      telegram_api::object_ptr<telegram_api::Update> *update_ptr = nullptr;
      size_t update_count = 0;
      for (auto &update : difference->other_updates_) {
        auto constructor_id = update->get_id();
        if (constructor_id == telegram_api::updateMessageID::ID) {
          // in getDifference updateMessageID can't be received for scheduled messages
          LOG(INFO) << "Receive update about sent message " << to_string(update);
          auto update_message_id = move_tl_object_as<telegram_api::updateMessageID>(update);
          td_->messages_manager_->on_update_message_id(
              update_message_id->random_id_, MessageId(ServerMessageId(update_message_id->id_)), "on_get_pts_update");
          continue;
        }
        if (constructor_id == telegram_api::updateDeleteMessages::ID) {
          auto *update_delete_messages = static_cast<const telegram_api::updateDeleteMessages *>(update.get());
          if (update_delete_messages->pts_count_ != 0 || update_delete_messages->messages_.size() != 1) {
            LOG(ERROR) << "Receive in getDifference " << to_string(update);
          }
        }

        update_ptr = &update;
        update_count++;
      }

      if (!difference->new_encrypted_messages_.empty() || update_count != 1) {
        LOG(ERROR) << "Receive unexpected updates with PTS " << pts << ": " << to_string(difference);
        break;
      }

      CHECK(update_ptr != nullptr);
      VLOG(get_difference) << "Repair update with PTS " << pts;
      pts_fixed_short_gap_++;
      add_pending_pts_update(std::move(*update_ptr), pts, 1, Time::now(), Promise<Unit>(), "on_get_pts_update");
      break;
    }
    case telegram_api::updates_differenceEmpty::ID:
    case telegram_api::updates_differenceTooLong::ID: {
      LOG(ERROR) << "Receive " << oneline(to_string(difference_ptr)) << " for request with PTS = " << pts - 1
                 << ", but have pending " << oneline(to_string(pending_pts_updates_.begin()->update))
                 << " with PTS = " << pending_pts_updates_.begin()->pts;
      break;
      default:
        UNREACHABLE();
    }
  }
}

void UpdatesManager::confirm_pts_qts(int32 qts) {
  int32 pts = get_pts();
  if (pts < 0) {
    pts = 0;
  }

  td_->create_handler<ConfirmPtsQtsQuery>()->send(pts, qts);

  last_confirmed_pts_ = pts;
  last_confirmed_qts_ = qts;
}

void UpdatesManager::after_get_difference() {
  CHECK(!running_get_difference_);

  retry_timeout_.cancel_timeout();
  retry_time_ = 1;

  skipped_postponed_updates_after_start_ = 0;
  td_->option_manager_->set_option_empty("since_last_open");

  // cancels qts_gap_timeout_ if needed, can apply some updates received during getDifference,
  // but missed in getDifference
  process_pending_qts_updates();

  // cancels seq_gap_timeout_ if needed, can apply some updates received during getDifference,
  // but missed in getDifference
  process_pending_seq_updates();

  if (running_get_difference_) {
    return;
  }

  if (!postponed_updates_.empty()) {
    auto begin_time = Time::now();
    auto chunk_count = postponed_updates_.size();
    VLOG(get_difference) << "Begin to apply " << chunk_count << " postponed update chunks";
    size_t total_update_count = 0;
    while (!postponed_updates_.empty()) {
      auto it = postponed_updates_.begin();
      auto updates = std::move(it->updates);
      auto updates_seq_begin = it->seq_begin;
      auto updates_seq_end = it->seq_end;
      auto receive_time = it->receive_time;
      auto promise = std::move(it->promise);
      // ignore it->date, because it may be too old
      postponed_updates_.erase(it);
      auto update_count = updates.size();
      on_pending_updates(std::move(updates), updates_seq_begin, updates_seq_end, 0, receive_time, std::move(promise),
                         "postponed updates");
      if (running_get_difference_) {
        VLOG(get_difference) << "Finish to apply postponed updates with " << postponed_updates_.size()
                             << " updates left after applied " << total_update_count
                             << " updates, because forced to run getDifference";
        return;
      }
      total_update_count += update_count;
    }
    VLOG(get_difference) << "Finished to apply " << total_update_count << " postponed updates";
    auto passed_time = Time::now() - begin_time;
    if (passed_time >= UPDATE_APPLY_WARNING_TIME) {
      LOG(WARNING) << "Applied " << total_update_count << " updates in " << chunk_count << " chunks in " << passed_time
                   << " seconds after postponing them for " << (Time::now() - get_difference_start_time_) << " seconds";
    }
  }

  if (!postponed_pts_updates_.empty()) {  // must be before td_->messages_manager_->after_get_difference()
    auto postponed_updates = std::move(postponed_pts_updates_);
    postponed_pts_updates_.clear();

    auto begin_time = Time::now();
    auto update_count = postponed_updates.size();
    auto old_pts = get_pts();
    VLOG(get_difference) << "Begin to apply " << postponed_updates.size()
                         << " postponed PTS updates with PTS = " << get_pts();
    for (auto &postponed_update : postponed_updates) {
      auto &update = postponed_update;
      add_pending_pts_update(std::move(update.update), update.pts, update.pts_count, update.receive_time,
                             std::move(update.promise), AFTER_GET_DIFFERENCE_SOURCE);
      CHECK(!running_get_difference_);
    }
    VLOG(get_difference) << "After applying postponed PTS updates have PTS = " << get_pts()
                         << ", max_pts = " << accumulated_pts_ << " and " << pending_pts_updates_.size() << " + "
                         << postponed_pts_updates_.size() << " pending PTS updates";
    auto passed_time = Time::now() - begin_time;
    if (passed_time >= UPDATE_APPLY_WARNING_TIME) {
      LOG(WARNING) << "Updated PTS from " << old_pts << " to " << get_pts() << " and applied " << update_count
                   << " PTS updates in " << passed_time << " seconds after postponing them for "
                   << (Time::now() - get_difference_start_time_) << " seconds";
    }
  }

  send_closure(td_->download_manager_actor_, &DownloadManager::after_get_difference);
  td_->inline_queries_manager_->after_get_difference();
  td_->messages_manager_->after_get_difference();
  send_closure_later(td_->notification_manager_actor_, &NotificationManager::after_get_difference);
  send_closure(G()->state_manager(), &StateManager::on_synchronized, true);
  get_difference_start_time_ = 0.0;

  try_reload_data();
}

void UpdatesManager::schedule_data_reload() {
  if (data_reload_timeout_.has_timeout()) {
    return;
  }

  auto timeout = next_data_reload_time_ - Time::now();
  LOG(INFO) << "Schedule data reload in " << timeout;
  data_reload_timeout_.set_callback(std::move(try_reload_data_static));
  data_reload_timeout_.set_callback_data(static_cast<void *>(td_));
  data_reload_timeout_.set_timeout_in(timeout);
}

void UpdatesManager::try_reload_data_static(void *td) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(td != nullptr);
  static_cast<Td *>(td)->updates_manager_->try_reload_data();
}

void UpdatesManager::try_reload_data() {
  if (!td_->auth_manager_->is_authorized() || td_->auth_manager_->is_bot() || running_get_difference_ ||
      !td_->online_manager_->is_online()) {
    return;
  }

  auto now = Time::now();
  if (now < next_data_reload_time_) {
    schedule_data_reload();
    return;
  }
  next_data_reload_time_ = now + 365 * 86400;

  auto promise = PromiseCreator::lambda([actor_id = actor_id(this)](Result<td_api::object_ptr<td_api::chats>>) {
    send_closure(actor_id, &UpdatesManager::on_data_reloaded);
  });

  LOG(INFO) << "Reload data";
  td_->animations_manager_->reload_saved_animations(true);
  td_->autosave_manager_->reload_autosave_settings();
  td_->chat_manager_->reload_created_public_dialogs(PublicDialogType::HasUsername, std::move(promise));
  td_->chat_manager_->reload_created_public_dialogs(PublicDialogType::IsLocationBased, Auto());
  td_->chat_manager_->reload_created_public_dialogs(PublicDialogType::ForPersonalDialog, Auto());
  get_default_emoji_statuses(td_, Auto());
  get_default_channel_emoji_statuses(td_, Auto());
  get_recent_emoji_statuses(td_, Auto());
  get_upgraded_gift_emoji_statuses(td_, Auto());
  reload_paid_reaction_privacy(td_);
  td_->notification_settings_manager_->reload_saved_ringtones(Auto());
  td_->notification_settings_manager_->send_get_reaction_notification_settings_query(Auto());
  td_->notification_settings_manager_->send_get_scope_notification_settings_query(NotificationSettingsScope::Private,
                                                                                  Auto());
  td_->notification_settings_manager_->send_get_scope_notification_settings_query(NotificationSettingsScope::Group,
                                                                                  Auto());
  td_->notification_settings_manager_->send_get_scope_notification_settings_query(NotificationSettingsScope::Channel,
                                                                                  Auto());
  td_->quick_reply_manager_->reload_quick_reply_shortcuts();
  td_->reaction_manager_->reload_reactions();
  td_->reaction_manager_->reload_message_effects();
  for (int32 type = 0; type < MAX_REACTION_LIST_TYPE; type++) {
    auto reaction_list_type = static_cast<ReactionListType>(type);
    td_->reaction_manager_->reload_reaction_list(reaction_list_type, "try_reload_data");
  }
  td_->star_manager_->reload_owned_star_count();
  for (int32 type = 0; type < MAX_STICKER_TYPE; type++) {
    auto sticker_type = static_cast<StickerType>(type);
    td_->stickers_manager_->get_installed_sticker_sets(sticker_type, Auto());
    td_->stickers_manager_->get_featured_sticker_sets(sticker_type, 0, 1000, Auto());
  }
  td_->stickers_manager_->get_recent_stickers(false, Auto());
  td_->stickers_manager_->get_recent_stickers(true, Auto());
  td_->stickers_manager_->get_favorite_stickers(Auto());
  td_->stickers_manager_->reload_special_sticker_set_by_type(SpecialStickerSetType::animated_emoji());
  td_->stickers_manager_->reload_special_sticker_set_by_type(SpecialStickerSetType::animated_emoji_click());
  td_->stickers_manager_->reload_special_sticker_set_by_type(SpecialStickerSetType::premium_gifts());
  td_->stickers_manager_->reload_special_sticker_set_by_type(SpecialStickerSetType::generic_animations());
  td_->stickers_manager_->reload_special_sticker_set_by_type(SpecialStickerSetType::default_statuses());
  td_->stickers_manager_->reload_special_sticker_set_by_type(SpecialStickerSetType::default_channel_statuses());
  td_->stickers_manager_->reload_special_sticker_set_by_type(SpecialStickerSetType::default_topic_icons());
  td_->stickers_manager_->get_default_custom_emoji_stickers(StickerListType::DialogPhoto, true, Auto());
  td_->stickers_manager_->get_default_custom_emoji_stickers(StickerListType::UserProfilePhoto, true, Auto());
  td_->stickers_manager_->get_default_custom_emoji_stickers(StickerListType::Background, true, Auto());
  td_->stickers_manager_->get_sticker_list_emoji_statuses(StickerListType::DisallowedChannelEmojiStatus, true, Auto());
  td_->story_manager_->reload_active_stories();
  td_->story_manager_->reload_all_read_stories();
  td_->theme_manager_->reload_accent_colors();
  td_->theme_manager_->reload_chat_themes();
  td_->theme_manager_->reload_profile_accent_colors();
  td_->time_zone_manager_->reload_time_zones(Auto());
  td_->user_manager_->reload_contact_birthdates(false);

  schedule_data_reload();
}

void UpdatesManager::on_data_reloaded() {
  if (G()->close_flag()) {
    return;
  }

  next_data_reload_time_ = Time::now() + Random::fast(3000, 4200);
  data_reload_timeout_.cancel_timeout();
  schedule_data_reload();
}

void UpdatesManager::on_pending_updates(vector<tl_object_ptr<telegram_api::Update>> &&updates, int32 seq_begin,
                                        int32 seq_end, int32 date, double receive_time, Promise<Unit> &&promise,
                                        const char *source) {
  if (get_pts() == -1) {
    init_state();
  }

  if (!td_->auth_manager_->is_authorized()) {
    LOG(INFO) << "Ignore updates received before authorization or after logout";
    return promise.set_value(Unit());
  }

  //  for (auto &update : updates) {
  //    LOG(WARNING) << "Receive update " << to_string(update.get());
  //  }

  if (seq_begin < 0 || seq_end < 0 || date < 0 || seq_end < seq_begin) {
    LOG(ERROR) << "Wrong updates parameters seq_begin = " << seq_begin << ", seq_end = " << seq_end
               << ", date = " << date << " from " << source;
    get_difference("on wrong updates in on_pending_updates");
    return promise.set_value(Unit());
  }

  for (auto &update : updates) {
    if (update != nullptr) {
      switch (update->get_id()) {
        case telegram_api::updateUserTyping::ID:
        case telegram_api::updateChatUserTyping::ID:
        case telegram_api::updateChannelUserTyping::ID:
        case telegram_api::updateEncryptedChatTyping::ID:
        case telegram_api::updateLoginToken::ID:
        case telegram_api::updateDcOptions::ID:
        case telegram_api::updateConfig::ID:
        case telegram_api::updateServiceNotification::ID:
        case telegram_api::updateLangPackTooLong::ID:
        case telegram_api::updateLangPack::ID:
          short_update_date_ = date == 0 ? G()->unix_time() : date;
          LOG(INFO) << "Process short " << oneline(to_string(update));
          // don't need promise for short update
          downcast_call(*update, OnUpdate(this, update, Promise<Unit>()));
          short_update_date_ = 0;
          update = nullptr;
          break;
        default:
          break;
      }
    }
  }

  bool need_postpone = running_get_difference_ /*|| string(source) != string("postponed updates")*/;
  bool can_postpone = can_postpone_updates();
  if (!need_postpone) {
    for (auto &update : updates) {
      if (!is_acceptable_update(update.get())) {
        CHECK(update != nullptr);
        int32 id = update->get_id();
        const tl_object_ptr<telegram_api::Message> *message_ptr = nullptr;
        int32 pts = 0;
        if (id == telegram_api::updateNewChannelMessage::ID) {
          auto update_new_channel_message = static_cast<const telegram_api::updateNewChannelMessage *>(update.get());
          message_ptr = &update_new_channel_message->message_;
          pts = update_new_channel_message->pts_;
        }
        if (id == telegram_api::updateEditChannelMessage::ID) {
          auto update_edit_channel_message = static_cast<const telegram_api::updateEditChannelMessage *>(update.get());
          message_ptr = &update_edit_channel_message->message_;
          pts = update_edit_channel_message->pts_;
        }

        // for channels we can try to replace unacceptable update with updateChannelTooLong
        if (message_ptr != nullptr) {
          auto dialog_id = DialogId::get_message_dialog_id(*message_ptr);
          if (dialog_id.get_type() == DialogType::Channel) {
            auto channel_id = dialog_id.get_channel_id();
            if (td_->chat_manager_->have_channel_force(channel_id, source)) {
              if (td_->messages_manager_->is_old_channel_update(dialog_id, pts)) {
                // the update will be ignored anyway, so there is no reason to replace it or force get_difference
                LOG(INFO) << "Allow an outdated unacceptable update from " << source;
                continue;
              }
              if ((*message_ptr)->get_id() != telegram_api::messageService::ID) {
                // don't replace service messages, because they can be about bot's kicking
                LOG(INFO) << "Replace update about new message with updateChannelTooLong in " << dialog_id;
                update = telegram_api::make_object<telegram_api::updateChannelTooLong>(
                    telegram_api::updateChannelTooLong::PTS_MASK, channel_id.get(), pts);
                continue;
              }
            }
          } else {
            LOG(ERROR) << "Update is not from a channel: " << to_string(update);
          }
        }

        get_difference("on unacceptable updates in on_pending_updates");
        return promise.set_value(Unit());
      }
    }
  }

  if (date > 0 && updates.size() == 1 && updates[0] != nullptr &&
      updates[0]->get_id() == telegram_api::updateReadHistoryOutbox::ID) {
    auto update = static_cast<const telegram_api::updateReadHistoryOutbox *>(updates[0].get());
    DialogId dialog_id(update->peer_);
    if (dialog_id.get_type() == DialogType::User) {
      auto user_id = dialog_id.get_user_id();
      if (user_id.is_valid()) {
        td_->user_manager_->on_update_user_local_was_online(user_id, date);
      }
    }
  }

  size_t ordinary_new_message_count = 0;
  size_t scheduled_new_message_count = 0;
  size_t update_message_id_count = 0;
  size_t update_count = 0;
  for (auto &update : updates) {
    if (update != nullptr) {
      auto constructor_id = update->get_id();
      if (constructor_id == telegram_api::updateMessageID::ID) {
        update_message_id_count++;
      } else {
        update_count++;
        if (constructor_id == telegram_api::updateNewMessage::ID ||
            constructor_id == telegram_api::updateNewChannelMessage::ID) {
          ordinary_new_message_count++;
        } else if (constructor_id == telegram_api::updateNewScheduledMessage::ID) {
          scheduled_new_message_count++;
        }
      }
    }
  }

  if (update_message_id_count != 0 && ordinary_new_message_count != 0 && scheduled_new_message_count != 0) {
    LOG(ERROR) << "Receive mixed message types in updates:";
    for (auto &update : updates) {
      LOG(ERROR) << "Update: " << oneline(to_string(update));
    }
    if (!running_get_difference_) {
      schedule_get_difference("on_get_wrong_updates");
    }
    return promise.set_value(Unit());
  }

  MultiPromiseActorSafe mpas{"OnPendingUpdatesMultiPromiseActor"};
  Promise<Unit> lock;
  auto use_mpas = need_postpone || update_count != 1;
  auto get_promise = [&] {
    if (use_mpas) {
      return mpas.get_promise();
    } else {
      CHECK(update_count != 0);
      update_count--;
      return std::move(promise);
    }
  };
  if (use_mpas) {
    being_processed_updates_++;
    mpas.add_promise([actor_id = create_reference(), promise = std::move(promise)](Result<Unit> &&result) mutable {
      send_closure(actor_id, &UpdatesManager::on_pending_updates_processed, std::move(result), std::move(promise));
    });
    lock = get_promise();
  }
  SCOPE_EXIT {
    if (!use_mpas && update_count == 1) {
      promise.set_value(Unit());
    }
  };

  for (auto &update : updates) {
    if (update != nullptr) {
      LOG(INFO) << "Receive from " << source << " pending " << to_string(update);
      int32 id = update->get_id();
      if (id == telegram_api::updateMessageID::ID) {
        auto sent_message_update = move_tl_object_as<telegram_api::updateMessageID>(update);
        MessageId message_id;
        if (ordinary_new_message_count != 0) {
          message_id = MessageId(ServerMessageId(sent_message_update->id_));
        } else if (scheduled_new_message_count != 0) {
          message_id = MessageId(ScheduledServerMessageId(sent_message_update->id_), std::numeric_limits<int32>::max());
        }
        if (!td_->messages_manager_->on_update_message_id(sent_message_update->random_id_, message_id, source)) {
          for (auto &debug_update : updates) {
            LOG(ERROR) << "Update: " << oneline(to_string(debug_update));
          }
        }
        update = nullptr;
      }
      if (id == telegram_api::updateStoryID::ID) {
        auto update_story_id = move_tl_object_as<telegram_api::updateStoryID>(update);
        td_->story_manager_->on_update_story_id(update_story_id->random_id_, StoryId(update_story_id->id_), source);
        update = nullptr;
      }
      if (id == telegram_api::updateFolderPeers::ID) {
        on_update(move_tl_object_as<telegram_api::updateFolderPeers>(update), get_promise());
        update = nullptr;
      }
      if (id == telegram_api::updateEncryption::ID) {
        on_update(move_tl_object_as<telegram_api::updateEncryption>(update), get_promise());
        update = nullptr;
      }
      // check that if getDifference wasn't run than it isn't run still
      CHECK(need_postpone || !running_get_difference_);
    }
  }

  for (auto &update : updates) {
    if (update != nullptr) {
      if (is_pts_update(update.get())) {
        if (running_get_difference_ && can_postpone) {
          auto pts = get_update_pts(update.get());
          if (pts != 0 && (min_postponed_update_pts_ == 0 || pts < min_postponed_update_pts_)) {
            min_postponed_update_pts_ = pts;
          }
        }
        downcast_call(*update, OnUpdate(this, update, get_promise()));
        update = nullptr;
      } else if (is_qts_update(update.get())) {
        if (running_get_difference_ && can_postpone) {
          auto qts = get_update_qts(update.get());
          if (qts != 0 && (min_postponed_update_qts_ == 0 || qts < min_postponed_update_qts_)) {
            min_postponed_update_qts_ = qts;
          }
        }
        downcast_call(*update, OnUpdate(this, update, get_promise()));
        update = nullptr;
      } else if (is_channel_pts_update(update.get())) {
        downcast_call(*update, OnUpdate(this, update, get_promise()));
        update = nullptr;
      }
    }
  }

  if (seq_begin == 0 && seq_end == 0) {
    bool have_updates = false;
    for (auto &update : updates) {
      if (update != nullptr) {
        have_updates = true;
        break;
      }
    }
    if (!have_updates) {
      LOG(INFO) << "All updates were processed";
      return lock.set_value(Unit());
    }
  }

  if (!use_mpas && update_count == 1) {
    // still need to process the only update
    lock = std::move(promise);  // now we can use lock as the last promise
    update_count = 0;
  }
  if (need_postpone || running_get_difference_) {
    LOG(INFO) << "Postpone " << updates.size() << " updates [" << seq_begin << ", " << seq_end
              << "] with date = " << date << " from " << source;
    if (!need_postpone) {
      LOG(ERROR) << "Run get difference while applying updates from " << source;
    }
    if (can_postpone) {
      postponed_updates_.emplace(seq_begin, seq_end, date, receive_time, std::move(updates), std::move(lock));
    } else {
      lock.set_value(Unit());
    }
    return;
  }

  if (seq_begin == 0 || seq_begin == seq_ + 1) {
    LOG(INFO) << "Process " << updates.size() << " updates [" << seq_begin << ", " << seq_end
              << "] with date = " << date << " from " << source;
    process_seq_updates(seq_end, date, std::move(updates), std::move(lock));
    process_pending_seq_updates();
    return;
  }

  if (seq_begin <= seq_) {
    if (seq_ >= (1 << 30) && seq_begin < seq_ - (1 << 30)) {
      set_seq_gap_timeout(0.001);
    }
    if (seq_end > seq_) {
      LOG(ERROR) << "Receive updates with seq_begin = " << seq_begin << ", seq_end = " << seq_end
                 << ", but seq = " << seq_ << " from " << source;
    } else {
      LOG(INFO) << "Receive old updates with seq_begin = " << seq_begin << ", seq_end = " << seq_end
                << ", but seq = " << seq_ << " from " << source;
    }
    return lock.set_value(Unit());
  }

  LOG(INFO) << "Gap in seq has found. Receive " << updates.size() << " updates [" << seq_begin << ", " << seq_end
            << "] from " << source << ", but seq = " << seq_;

  if (can_postpone_updates()) {
    pending_seq_updates_.emplace(seq_begin, seq_end, date, receive_time, std::move(updates), std::move(lock));
  } else {
    lock.set_value(Unit());
  }

  set_seq_gap_timeout(receive_time + MAX_UNFILLED_GAP_TIME - Time::now());
}

void UpdatesManager::on_pending_updates_processed(Result<Unit> result, Promise<Unit> promise) {
  being_processed_updates_--;
  promise.set_result(std::move(result));
}

void UpdatesManager::add_pending_qts_update(tl_object_ptr<telegram_api::Update> &&update, int32 qts,
                                            Promise<Unit> &&promise) {
  CHECK(update != nullptr);
  if (qts <= 1) {
    LOG(ERROR) << "Receive wrong QTS " << qts << " in " << oneline(to_string(update));
    schedule_get_difference("wrong QTS");
    promise.set_value(Unit());
    return;
  }

  int32 old_qts = get_qts();
  LOG(INFO) << "Process update with QTS = " << qts << ", current QTS = " << old_qts;
  if (qts < old_qts - 1000009) {
    LOG(WARNING) << "Restore QTS after QTS overflow from " << old_qts << " to " << qts << " by "
                 << oneline(to_string(update));
    add_qts(qts - 1).set_value(Unit());
    CHECK(get_qts() == qts - 1);
    old_qts = qts - 1;
    last_confirmed_qts_ = get_qts();
  }

  if (qts <= old_qts) {
    LOG(INFO) << "Skip already applied update with QTS = " << qts;
    promise.set_value(Unit());
    return;
  }

  if (running_get_difference_ || (qts - 1 > old_qts && old_qts > 0)) {
    LOG(INFO) << "Postpone update with QTS = " << qts;
    if (!running_get_difference_ && pending_qts_updates_.empty()) {
      set_qts_gap_timeout(MAX_UNFILLED_GAP_TIME);
    }
    if (!can_postpone_updates()) {
      return promise.set_value(Unit());
    }
    auto &pending_update = pending_qts_updates_[qts];
    if (pending_update.update != nullptr) {
      LOG(WARNING) << "Receive duplicate update with QTS = " << qts;
    } else {
      pending_update.receive_time = Time::now();
    }
    pending_update.update = std::move(update);
    pending_update.promises.push_back(std::move(promise));
    return;
  }

  process_qts_update(std::move(update), qts, std::move(promise));
  process_pending_qts_updates();
}

void UpdatesManager::process_updates(vector<tl_object_ptr<telegram_api::Update>> &&updates, bool force_apply,
                                     Promise<Unit> &&promise) {
  int32 update_count = 0;
  for (auto &update : updates) {
    if (update != nullptr) {
      update_count++;
    }
  }
  if (update_count == 0) {
    return promise.set_value(Unit());
  }

  MultiPromiseActorSafe mpas{"OnProcessUpdatesMultiPromiseActor"};
  Promise<Unit> lock;
  auto use_mpas = update_count != 1;
  auto get_promise = [&] {
    if (use_mpas) {
      return mpas.get_promise();
    } else {
      CHECK(update_count != 0);
      update_count--;
      return std::move(promise);
    }
  };
  if (use_mpas) {
    mpas.add_promise(std::move(promise));
    lock = get_promise();
  }
  SCOPE_EXIT {
    if (!use_mpas && update_count == 1) {
      promise.set_value(Unit());
    }
  };

  /*
    for (auto &update : updates) {
      if (update != nullptr) {
        // TODO can't apply it here, because dialog may not be created yet
        // process updateReadChannelInbox before updateNewChannelMessage
        auto constructor_id = update->get_id();
        if (constructor_id == telegram_api::updateReadChannelInbox::ID) {
          on_update(move_tl_object_as<telegram_api::updateReadChannelInbox>(update), get_promise());
        }
      }
    }
  */

  tl_object_ptr<telegram_api::updatePtsChanged> update_pts_changed;
  for (auto &update : updates) {
    if (update != nullptr) {
      // process updateNewChannelMessage first
      auto constructor_id = update->get_id();
      if (constructor_id == telegram_api::updateNewChannelMessage::ID) {
        on_update(move_tl_object_as<telegram_api::updateNewChannelMessage>(update), get_promise());
        continue;
      }

      // process updateNewScheduledMessage first
      if (constructor_id == telegram_api::updateNewScheduledMessage::ID) {
        on_update(move_tl_object_as<telegram_api::updateNewScheduledMessage>(update), get_promise());
        continue;
      }

      // updateGroupCallConnection must be processed before updateGroupCall
      if (constructor_id == telegram_api::updateGroupCallConnection::ID) {
        on_update(move_tl_object_as<telegram_api::updateGroupCallConnection>(update), get_promise());
        continue;
      }

      // updatePtsChanged forces get difference, so process it last
      if (constructor_id == telegram_api::updatePtsChanged::ID) {
        update_pts_changed = move_tl_object_as<telegram_api::updatePtsChanged>(update);
        continue;
      }
    }
  }
  if (force_apply) {
    for (auto &update : updates) {
      if (update != nullptr) {
        if (is_pts_update(update.get())) {
          auto constructor_id = update->get_id();
          if (constructor_id == telegram_api::updateWebPage::ID) {
            auto update_web_page = move_tl_object_as<telegram_api::updateWebPage>(update);
            td_->web_pages_manager_->on_get_web_page(std::move(update_web_page->webpage_), DialogId());
            continue;
          }

          CHECK(constructor_id != telegram_api::updateFolderPeers::ID);

          if (constructor_id == telegram_api::updateReadHistoryInbox::ID) {
            static_cast<telegram_api::updateReadHistoryInbox *>(update.get())->still_unread_count_ = -1;
          }

          process_pts_update(std::move(update));
          CHECK(update == nullptr);
        } else if (is_qts_update(update.get())) {
          process_qts_update(std::move(update), 0, get_promise());
          CHECK(update == nullptr);
        } else if (update->get_id() == telegram_api::updateChannelTooLong::ID) {
          td_->messages_manager_->on_update_channel_too_long(
              move_tl_object_as<telegram_api::updateChannelTooLong>(update), true);
        }
      }
    }
  }
  for (auto &update : updates) {
    if (update != nullptr) {
      LOG(INFO) << "Process update " << to_string(update);
      downcast_call(*update, OnUpdate(this, update, get_promise()));
      CHECK(!running_get_difference_);
    }
  }
  if (update_pts_changed != nullptr) {
    on_update(std::move(update_pts_changed), get_promise());
  }
  lock.set_value(Unit());
}

void UpdatesManager::process_pts_update(tl_object_ptr<telegram_api::Update> &&update) {
  CHECK(update != nullptr);

  // TODO need to save all updates that can change result of running queries not associated with PTS (for example
  // getHistory) and apply the updates to results of the queries

  if (!check_pts_update(update)) {
    LOG(ERROR) << "Receive wrong PTS update: " << oneline(to_string(update));
    update = nullptr;
    return;
  }

  // must be called only during getDifference
  CHECK(pending_pts_updates_.empty());
  CHECK(accumulated_pts_ == -1);

  td_->messages_manager_->process_pts_update(std::move(update));
}

void UpdatesManager::add_pending_pts_update(tl_object_ptr<telegram_api::Update> &&update, int32 new_pts,
                                            int32 pts_count, double receive_time, Promise<Unit> &&promise,
                                            const char *source) {
  // do not try to run getDifference from this function
  CHECK(update != nullptr);
  CHECK(source != nullptr);
  LOG(INFO) << "Receive from " << source << " with pts_count = " << pts_count << " pending " << to_string(update);
  if (pts_count < 0 || new_pts <= pts_count) {
    LOG(ERROR) << "Receive update with wrong PTS = " << new_pts << " or pts_count = " << pts_count << " from " << source
               << ": " << oneline(to_string(update));
    return promise.set_value(Unit());
  }

  // TODO need to save all updates that can change result of running queries not associated with PTS (for example
  // getHistory) and apply them to result of this queries

  if (!check_pts_update(update)) {
    LOG(ERROR) << "Receive wrong PTS update from " << source << ": " << oneline(to_string(update));
    return promise.set_value(Unit());
  }

  if (DROP_PTS_UPDATES && Slice(source) != Slice("on_get_pts_update")) {
    set_pts_gap_timeout(1.0);
    return promise.set_value(Unit());
  }

  int32 old_pts = get_pts();
  if (new_pts < old_pts - 99 && source != AFTER_GET_DIFFERENCE_SOURCE) {
    bool need_restore_pts = new_pts < old_pts - 19999;
    auto now = Time::now();
    if (old_pts == 2100000000 && new_pts < 1100000000 && pts_count <= 10000 &&
        td_->option_manager_->get_option_integer("session_count") > 1) {
      set_pts(1, "restore PTS").set_value(Unit());
      old_pts = get_pts();
      set_pts_gap_timeout(0.001);
      return promise.set_value(Unit());
    } else if (now > last_pts_jump_warning_time_ + 1 && need_restore_pts &&
               !(old_pts == std::numeric_limits<int32>::max() && running_get_difference_)) {
      LOG(ERROR) << "Restore PTS after delete_first_messages from " << old_pts << " to " << new_pts
                 << " is disabled, pts_count = " << pts_count << ", update is from " << source << ": "
                 << oneline(to_string(update));
      last_pts_jump_warning_time_ = now;
    }
    if (need_restore_pts) {
      set_pts_gap_timeout(0.001);
    }
  }

  if (new_pts <= old_pts || (old_pts >= 1 && new_pts - (1 << 30) > old_pts)) {
    td_->messages_manager_->skip_old_pending_pts_update(std::move(update), new_pts, old_pts, pts_count, source);
    return promise.set_value(Unit());
  }
  if (source == AFTER_GET_DIFFERENCE_SOURCE && old_pts >= 1 && new_pts - (1 << 21) > old_pts) {
    LOG(ERROR) << "Ignore update " << oneline(to_string(update)) << ", because current PTS is " << old_pts;
    return promise.set_value(Unit());
  }

  if (running_get_difference_ || !postponed_pts_updates_.empty()) {
    LOG(INFO) << "Save pending update received while running getDifference from " << source;
    postpone_pts_update(std::move(update), new_pts, pts_count, receive_time, std::move(promise));
    return;
  }

  // is_acceptable_update check was skipped for postponed PTS updates
  if (source == AFTER_GET_DIFFERENCE_SOURCE && !is_acceptable_update(update.get())) {
    LOG(INFO) << "Postpone again unacceptable pending update";
    postpone_pts_update(std::move(update), new_pts, pts_count, receive_time, std::move(promise));
    set_pts_gap_timeout(0.001);
    return;
  }

  if (old_pts > new_pts - pts_count) {
    LOG(WARNING) << "Have old_pts (= " << old_pts << ") + pts_count (= " << pts_count << ") > new_pts (= " << new_pts
                 << "). Logged in " << td_->option_manager_->get_option_integer("authorization_date")
                 << ". Update from " << source << " = " << oneline(to_string(update));
    postpone_pts_update(std::move(update), new_pts, pts_count, receive_time, std::move(promise));
    set_pts_gap_timeout(0.001);
    return;
  }

  accumulated_pts_count_ += pts_count;
  if (new_pts > accumulated_pts_) {
    accumulated_pts_ = new_pts;
  }

  if (old_pts > accumulated_pts_ - accumulated_pts_count_) {
    LOG(WARNING) << "Have old_pts (= " << old_pts << ") + accumulated_pts_count (= " << accumulated_pts_count_
                 << ") > accumulated_pts (= " << accumulated_pts_ << "). new_pts = " << new_pts
                 << ", pts_count = " << pts_count << ". Logged in "
                 << td_->option_manager_->get_option_integer("authorization_date") << ". Update from " << source
                 << " = " << oneline(to_string(update));
    postpone_pts_update(std::move(update), new_pts, pts_count, receive_time, std::move(promise));
    set_pts_gap_timeout(0.001);
    return;
  }

  LOG_IF(INFO, pts_count == 0 && update->get_id() != dummyUpdate::ID) << "Skip useless update " << to_string(update);

  if (pending_pts_updates_.empty() && old_pts == accumulated_pts_ - accumulated_pts_count_ &&
      !pts_gap_timeout_.has_timeout()) {
    if (pts_count > 0) {
      td_->messages_manager_->process_pts_update(std::move(update));

      set_pts(accumulated_pts_, "process pending updates fast path")
          .set_value(Unit());  // TODO can't set until data are really stored on persistent storage
      accumulated_pts_count_ = 0;
      accumulated_pts_ = -1;
    } else {
      LOG(DEBUG) << "There is no need to process the update";
    }
    promise.set_value(Unit());
    return;
  }

  if (pts_count == 0 && receive_time < Time::now() - MAX_UNFILLED_GAP_TIME && update->get_id() == dummyUpdate::ID) {
    // don't warn about fetching of affected history
    expect_pts_gap_ = true;
  }

  pending_pts_updates_.emplace(std::move(update), new_pts, pts_count, receive_time, std::move(promise));

  if (old_pts < accumulated_pts_ - accumulated_pts_count_) {
    if (old_pts == new_pts - pts_count) {
      // can't apply all updates, but can apply this and probably some other updates
      process_pending_pts_updates();
    } else {
      LOG(DEBUG) << "Can't process PTS updates, because current PTS = " << old_pts << ", new PTS = " << new_pts
                 << ", pts_count = " << pts_count << ", maximum known PTS = " << accumulated_pts_
                 << ", accumulated_pts_count = " << accumulated_pts_count_;
      set_pts_gap_timeout(max(receive_time + MAX_UNFILLED_GAP_TIME - Time::now(), 0.001));
    }
    return;
  }

  CHECK(old_pts == accumulated_pts_ - accumulated_pts_count_);
  process_all_pending_pts_updates();
}

size_t UpdatesManager::get_pending_pts_update_count() {
  return postponed_pts_updates_.size() + pending_pts_updates_.size();
}

void UpdatesManager::postpone_pts_update(tl_object_ptr<telegram_api::Update> &&update, int32 pts, int32 pts_count,
                                         double receive_time, Promise<Unit> &&promise) {
  if (!can_postpone_updates() || (pts_count > 1 && td_->option_manager_->get_option_integer("session_count") <= 1)) {
    return promise.set_value(Unit());
  }
  postponed_pts_updates_.emplace(std::move(update), pts, pts_count, receive_time, std::move(promise));
}

void UpdatesManager::process_seq_updates(int32 seq_end, int32 date,
                                         vector<tl_object_ptr<telegram_api::Update>> &&updates,
                                         Promise<Unit> &&promise) {
  string serialized_updates;
  if (date && seq_end) {
    serialized_updates = PSTRING() << "process_seq_updates [seq_ = " << seq_ << ", seq_end = " << seq_end << "]: ";
    // TODO remove after bugs will be fixed
    for (auto &update : updates) {
      if (update != nullptr) {
        serialized_updates += oneline(to_string(update));
      }
    }
  }
  process_updates(std::move(updates), false, std::move(promise));
  if (seq_end) {
    seq_ = seq_end;
  }
  if (date && seq_end) {
    set_date(date, true, std::move(serialized_updates));
  }
}

void UpdatesManager::process_qts_update(tl_object_ptr<telegram_api::Update> &&update_ptr, int32 qts,
                                        Promise<Unit> &&promise) {
  LOG(DEBUG) << "Process " << to_string(update_ptr);
  if (last_confirmed_qts_ < qts - FORCED_GET_DIFFERENCE_PTS_DIFF && last_confirmed_qts_ != 0) {
    confirm_pts_qts(qts);
  }
  qts_diff_++;
  if (qts_diff_ >= 1000000) {
    LOG(WARNING) << "Fixed " << qts_gap_ << " QTS gaps up to QTS " << qts;
    qts_gap_ = 0;
    qts_diff_ = 0;
  }
  auto constructor_id = update_ptr->get_id();
  if (constructor_id == telegram_api::updateNewEncryptedMessage::ID) {
    auto update = move_tl_object_as<telegram_api::updateNewEncryptedMessage>(update_ptr);
    send_closure(td_->secret_chats_manager_, &SecretChatsManager::on_new_message, std::move(update->message_),
                 add_qts(qts));
  } else if (td_->auth_manager_->is_bot()) {
    switch (constructor_id) {
      case telegram_api::updateMessagePollVote::ID: {
        auto update = move_tl_object_as<telegram_api::updateMessagePollVote>(update_ptr);
        td_->poll_manager_->on_get_poll_vote(PollId(update->poll_id_), DialogId(update->peer_),
                                             std::move(update->options_));
        break;
      }
      case telegram_api::updateBotStopped::ID: {
        auto update = move_tl_object_as<telegram_api::updateBotStopped>(update_ptr);
        td_->dialog_participant_manager_->on_update_bot_stopped(UserId(update->user_id_), update->date_,
                                                                update->stopped_);
        break;
      }
      case telegram_api::updateChatParticipant::ID: {
        auto update = move_tl_object_as<telegram_api::updateChatParticipant>(update_ptr);
        bool via_join_request =
            update->invite_ != nullptr && update->invite_->get_id() == telegram_api::chatInvitePublicJoinRequests::ID;
        td_->dialog_participant_manager_->on_update_chat_participant(
            ChatId(update->chat_id_), UserId(update->actor_id_), update->date_,
            DialogInviteLink(std::move(update->invite_), true, true, "updateChatParticipant"), via_join_request,
            std::move(update->prev_participant_), std::move(update->new_participant_));
        break;
      }
      case telegram_api::updateChannelParticipant::ID: {
        auto update = move_tl_object_as<telegram_api::updateChannelParticipant>(update_ptr);
        bool via_join_request =
            update->invite_ != nullptr && update->invite_->get_id() == telegram_api::chatInvitePublicJoinRequests::ID;
        td_->dialog_participant_manager_->on_update_channel_participant(
            ChannelId(update->channel_id_), UserId(update->actor_id_), update->date_,
            DialogInviteLink(std::move(update->invite_), true, true, "updateChannelParticipant"), via_join_request,
            update->via_chatlist_, std::move(update->prev_participant_), std::move(update->new_participant_));
        break;
      }
      case telegram_api::updateBotChatInviteRequester::ID: {
        auto update = move_tl_object_as<telegram_api::updateBotChatInviteRequester>(update_ptr);
        td_->dialog_participant_manager_->on_update_chat_invite_requester(
            DialogId(update->peer_), UserId(update->user_id_), std::move(update->about_), update->date_,
            DialogInviteLink(std::move(update->invite_), true, true, "updateBotChatInviteRequester"));
        break;
      }
      case telegram_api::updateBotChatBoost::ID: {
        auto update = move_tl_object_as<telegram_api::updateBotChatBoost>(update_ptr);
        td_->boost_manager_->on_update_dialog_boost(DialogId(update->peer_), std::move(update->boost_));
        break;
      }
      case telegram_api::updateBotMessageReaction::ID: {
        auto update = move_tl_object_as<telegram_api::updateBotMessageReaction>(update_ptr);
        auto dialog_id = DialogId(update->peer_);
        auto message_id = MessageId(ServerMessageId(update->msg_id_));
        auto date = update->date_;
        auto actor_dialog_id = DialogId(update->actor_);
        auto old_reaction_types = ReactionType::get_reaction_types(update->old_reactions_);
        auto new_reaction_types = ReactionType::get_reaction_types(update->new_reactions_);
        if (!dialog_id.is_valid() || !message_id.is_valid() || !actor_dialog_id.is_valid() || date <= 0 ||
            old_reaction_types == new_reaction_types) {
          LOG(ERROR) << "Receive invalid updateBotMessageReaction for " << MessageFullId{dialog_id, message_id}
                     << " by " << actor_dialog_id << " at " << date << ": " << old_reaction_types << " -> "
                     << new_reaction_types;
          break;
        }

        td_->dialog_manager_->force_create_dialog(dialog_id, "on_update_bot_message_reaction", true);
        send_closure(G()->td(), &Td::send_update,
                     td_api::make_object<td_api::updateMessageReaction>(
                         td_->dialog_manager_->get_chat_id_object(dialog_id, "updateMessageReaction"), message_id.get(),
                         get_message_sender_object(td_, actor_dialog_id, "updateMessageReaction"), date,
                         ReactionType::get_reaction_types_object(old_reaction_types, false),
                         ReactionType::get_reaction_types_object(new_reaction_types, false)));
        break;
      }
      case telegram_api::updateBotMessageReactions::ID: {
        auto update = move_tl_object_as<telegram_api::updateBotMessageReactions>(update_ptr);
        auto dialog_id = DialogId(update->peer_);
        auto message_id = MessageId(ServerMessageId(update->msg_id_));
        auto date = update->date_;
        if (!dialog_id.is_valid() || !message_id.is_valid() || date <= 0) {
          LOG(ERROR) << "Receive invalid " << to_string(update);
          break;
        }
        vector<td_api::object_ptr<td_api::messageReaction>> message_reactions;
        for (const auto &reaction_count : update->reactions_) {
          auto reaction_type = ReactionType(reaction_count->reaction_);
          if (reaction_type.is_empty() || reaction_count->count_ <= 0) {
            LOG(ERROR) << "Receive invalid reaction in updateBotMessageReactions for "
                       << MessageFullId{dialog_id, message_id} << " at " << date << ": " << to_string(reaction_count);
            continue;
          }
          message_reactions.push_back(td_api::make_object<td_api::messageReaction>(
              reaction_type.get_reaction_type_object(), reaction_count->count_, false, nullptr, Auto()));
        }
        td_->dialog_manager_->force_create_dialog(dialog_id, "on_update_bot_message_reactions", true);
        send_closure(G()->td(), &Td::send_update,
                     td_api::make_object<td_api::updateMessageReactions>(
                         td_->dialog_manager_->get_chat_id_object(dialog_id, "updateMessageReactions"),
                         message_id.get(), date, std::move(message_reactions)));
        break;
      }
      case telegram_api::updateBotPurchasedPaidMedia::ID: {
        auto update = move_tl_object_as<telegram_api::updateBotPurchasedPaidMedia>(update_ptr);
        auto user_id = UserId(update->user_id_);
        if (!user_id.is_valid()) {
          LOG(ERROR) << "Receive invalid " << to_string(update);
          break;
        }
        send_closure(
            G()->td(), &Td::send_update,
            td_api::make_object<td_api::updatePaidMediaPurchased>(
                td_->user_manager_->get_user_id_object(user_id, "updatePaidMediaPurchased"), update->payload_));
        break;
      }
      case telegram_api::updateBotBusinessConnect::ID: {
        auto update = move_tl_object_as<telegram_api::updateBotBusinessConnect>(update_ptr);
        td_->business_connection_manager_->on_update_bot_business_connect(std::move(update->connection_));
        break;
      }
      case telegram_api::updateBotNewBusinessMessage::ID: {
        auto update = move_tl_object_as<telegram_api::updateBotNewBusinessMessage>(update_ptr);
        td_->business_connection_manager_->on_update_bot_new_business_message(
            BusinessConnectionId(std::move(update->connection_id_)), std::move(update->message_),
            std::move(update->reply_to_message_));
        break;
      }
      case telegram_api::updateBotEditBusinessMessage::ID: {
        auto update = move_tl_object_as<telegram_api::updateBotEditBusinessMessage>(update_ptr);
        td_->business_connection_manager_->on_update_bot_edit_business_message(
            BusinessConnectionId(std::move(update->connection_id_)), std::move(update->message_),
            std::move(update->reply_to_message_));
        break;
      }
      case telegram_api::updateBotDeleteBusinessMessage::ID: {
        auto update = move_tl_object_as<telegram_api::updateBotDeleteBusinessMessage>(update_ptr);
        td_->business_connection_manager_->on_update_bot_delete_business_messages(
            BusinessConnectionId(std::move(update->connection_id_)), DialogId(update->peer_),
            std::move(update->messages_));
        break;
      }
      default:
        UNREACHABLE();
        break;
    }
    add_qts(qts).set_value(Unit());
  } else {
    add_qts(qts).set_value(Unit());
    LOG(ERROR) << "Receive " << to_string(update_ptr);
    update_ptr = nullptr;
  }
  promise.set_value(Unit());
}

void UpdatesManager::process_all_pending_pts_updates() {
  auto begin_time = Time::now();
  for (auto &update : pending_pts_updates_) {
    td_->messages_manager_->process_pts_update(std::move(update.update));
    update.promise.set_value(Unit());
  }

  if (last_pts_gap_time_ != 0) {
    auto begin_diff = begin_time - last_pts_gap_time_;
    auto diff = Time::now() - last_pts_gap_time_;
    last_pts_gap_time_ = 0;
    if (diff > 0.1) {
      VLOG(get_difference) << "Gap in PTS from " << accumulated_pts_ - accumulated_pts_count_ << " to "
                           << accumulated_pts_ << " has been filled in " << begin_diff << '-' << diff << " seconds";
    }
  }

  set_pts(accumulated_pts_, "process_all_pending_pts_updates")
      .set_value(Unit());  // TODO can't set until updates are stored on persistent storage
  drop_all_pending_pts_updates();
}

void UpdatesManager::drop_all_pending_pts_updates() {
  accumulated_pts_count_ = 0;
  accumulated_pts_ = -1;
  min_pts_gap_timeout_.cancel_timeout();
  pts_gap_timeout_.cancel_timeout();
  pending_pts_updates_.clear();
}

void UpdatesManager::process_postponed_pts_updates() {
  if (postponed_pts_updates_.empty()) {
    return;
  }

  auto begin_time = Time::now();
  auto initial_pts = get_pts();
  auto old_pts = initial_pts;
  int32 skipped_update_count = 0;
  int32 applied_update_count = 0;
  auto update_it = postponed_pts_updates_.begin();
  while (update_it != postponed_pts_updates_.end()) {
    auto new_pts = update_it->pts;
    auto pts_count = update_it->pts_count;
    if (new_pts <= old_pts || (old_pts >= 1 && new_pts - (1 << 30) > old_pts)) {
      skipped_update_count++;
      td_->messages_manager_->skip_old_pending_pts_update(std::move(update_it->update), new_pts, old_pts, pts_count,
                                                          "process_postponed_pts_updates");
      update_it->promise.set_value(Unit());
      update_it = postponed_pts_updates_.erase(update_it);
      continue;
    }

    if (Time::now() - begin_time >= UPDATE_APPLY_WARNING_TIME) {
      // the updates will be applied or skipped later; reget the remaining updates through getDifference
      break;
    }

    auto last_update_it = update_it;
    for (int32 i = 1; true; i++) {
      ++last_update_it;
      if (old_pts == new_pts - pts_count) {
        // the updates can be applied
        break;
      }
      if (old_pts > new_pts - pts_count || last_update_it == postponed_pts_updates_.end() ||
          i == GAP_TIMEOUT_UPDATE_COUNT) {
        // the updates can't be applied
        VLOG(get_difference) << "Can't apply " << i << " next postponed updates with PTS " << update_it->pts << '-'
                             << new_pts << ", because their pts_count is " << pts_count << " instead of expected "
                             << new_pts - old_pts;
        last_update_it = update_it;
        break;
      }

      new_pts = last_update_it->pts;
      pts_count += last_update_it->pts_count;
    }

    if (last_update_it == update_it) {
      // the updates will be applied or skipped later
      break;
    }
    CHECK(old_pts == new_pts - pts_count);

    while (update_it != last_update_it) {
      if (update_it->pts_count > 0) {
        applied_update_count++;
        td_->messages_manager_->process_pts_update(std::move(update_it->update));
      }
      update_it->promise.set_value(Unit());
      update_it = postponed_pts_updates_.erase(update_it);
    }
    old_pts = new_pts;
  }
  if (old_pts != initial_pts) {
    set_pts(old_pts, "process_postponed_pts_updates")
        .set_value(Unit());  // TODO can't set until data are really stored on persistent storage
  }
  CHECK(!running_get_difference_);
  if (skipped_update_count + applied_update_count > 0) {
    VLOG(get_difference) << "PTS has changed from " << initial_pts << " to " << old_pts << " after skipping "
                         << skipped_update_count << ", applying " << applied_update_count << " and keeping "
                         << postponed_pts_updates_.size() << " postponed updates";
  }

  auto passed_time = Time::now() - begin_time;
  if (passed_time >= UPDATE_APPLY_WARNING_TIME) {
    LOG(WARNING) << "PTS has changed from " << initial_pts << " to " << old_pts << " after skipping "
                 << skipped_update_count << ", applying " << applied_update_count << " and keeping "
                 << postponed_pts_updates_.size() << " postponed for " << (Time::now() - get_difference_start_time_)
                 << " seconds updates in " << passed_time << " seconds";
  }
}

void UpdatesManager::process_pending_pts_updates() {
  if (pending_pts_updates_.empty()) {
    return;
  }

  auto begin_time = Time::now();
  auto initial_pts = get_pts();
  int32 applied_update_count = 0;
  while (!pending_pts_updates_.empty()) {
    auto update_it = pending_pts_updates_.begin();
    auto &update = *update_it;
    if (get_pts() != update.pts - update.pts_count) {
      // the updates will be applied or skipped later
      break;
    }

    applied_update_count++;
    if (update.pts_count > 0) {
      td_->messages_manager_->process_pts_update(std::move(update.update));
      set_pts(update.pts, "process_pending_pts_updates")
          .set_value(Unit());  // TODO can't set until data are really stored on persistent storage

      if (accumulated_pts_ != -1) {
        CHECK(update.pts <= accumulated_pts_);
        CHECK(accumulated_pts_count_ >= update.pts_count);
        accumulated_pts_count_ -= update.pts_count;
      }
    } else {
      LOG(INFO) << "Skip because of pts_count == 0 " << to_string(update.update);
    }
    update.promise.set_value(Unit());
    pending_pts_updates_.erase(update_it);
  }
  if (applied_update_count > 0) {
    min_pts_gap_timeout_.cancel_timeout();
    pts_gap_timeout_.cancel_timeout();
  }
  if (!pending_pts_updates_.empty()) {
    // if still have a gap, reset timeout
    auto update_it = pending_pts_updates_.begin();
    double receive_time = update_it->receive_time;
    for (size_t i = 0; i < GAP_TIMEOUT_UPDATE_COUNT; i++) {
      if (++update_it == pending_pts_updates_.end()) {
        break;
      }
      receive_time = min(receive_time, update_it->receive_time);
    }
    set_pts_gap_timeout(max(receive_time + MAX_UNFILLED_GAP_TIME - Time::now(), 0.001));
  }

  auto passed_time = Time::now() - begin_time;
  if (passed_time >= UPDATE_APPLY_WARNING_TIME) {
    LOG(WARNING) << "PTS has changed from " << initial_pts << " to " << get_pts() << " after applying "
                 << applied_update_count << " and keeping " << pending_pts_updates_.size() << " pending updates in "
                 << passed_time << " seconds";
  }
}

void UpdatesManager::process_pending_seq_updates() {
  if (!pending_seq_updates_.empty()) {
    LOG(DEBUG) << "Trying to process " << pending_seq_updates_.size() << " pending seq updates";
    // must not return, because in case of seq overflow there are no pending seq updates
  }

  auto begin_time = Time::now();
  int32 initial_seq = seq_;
  int32 applied_update_count = 0;
  while (!pending_seq_updates_.empty() && !running_get_difference_) {
    auto update_it = pending_seq_updates_.begin();
    auto &update = *update_it;
    auto seq_begin = update.seq_begin;
    if (seq_begin - 1 > seq_ && seq_begin - (1 << 30) <= seq_) {
      // the updates will be applied later
      break;
    }

    applied_update_count++;
    auto seq_end = update.seq_end;
    if (seq_begin - 1 == seq_) {
      process_seq_updates(seq_end, update.date, std::move(update.updates), std::move(update.promise));
    } else {
      // old update
      CHECK(seq_begin != 0);
      if (seq_begin <= seq_ && seq_ < seq_end) {
        LOG(ERROR) << "Receive updates with seq_begin = " << seq_begin << ", seq_end = " << seq_end
                   << ", but seq = " << seq_;
      }
      update.promise.set_value(Unit());
    }
    pending_seq_updates_.erase(update_it);
  }
  if (pending_seq_updates_.empty() || applied_update_count > 0) {
    seq_gap_timeout_.cancel_timeout();
  }
  if (!pending_seq_updates_.empty()) {
    // if still have a gap, reset timeout
    auto update_it = pending_seq_updates_.begin();
    double receive_time = update_it->receive_time;
    for (size_t i = 0; i < GAP_TIMEOUT_UPDATE_COUNT; i++) {
      if (++update_it == pending_seq_updates_.end()) {
        break;
      }
      receive_time = min(receive_time, update_it->receive_time);
    }
    set_seq_gap_timeout(receive_time + MAX_UNFILLED_GAP_TIME - Time::now());
  }

  auto passed_time = Time::now() - begin_time;
  if (passed_time >= UPDATE_APPLY_WARNING_TIME) {
    LOG(WARNING) << "Seq has changed from " << initial_seq << " to " << seq_ << " after applying "
                 << applied_update_count << " and keeping " << pending_seq_updates_.size() << " pending updates in "
                 << passed_time << " seconds";
  }
}

void UpdatesManager::process_pending_qts_updates() {
  if (pending_qts_updates_.empty()) {
    return;
  }

  LOG(DEBUG) << "Process " << pending_qts_updates_.size() << " pending QTS updates";
  auto begin_time = Time::now();
  auto initial_qts = get_qts();
  int32 applied_update_count = 0;
  while (!pending_qts_updates_.empty()) {
    CHECK(!running_get_difference_);
    auto update_it = pending_qts_updates_.begin();
    auto qts = update_it->first;
    auto old_qts = get_qts();
    if (qts - 1 > old_qts && qts - (1 << 30) <= old_qts) {
      // the update will be applied later
      break;
    }
    auto promise = PromiseCreator::lambda(
        [promises = std::move(update_it->second.promises)](Unit) mutable { set_promises(promises); });
    applied_update_count++;
    if (qts == old_qts + 1) {
      process_qts_update(std::move(update_it->second.update), qts, std::move(promise));
    } else {
      promise.set_value(Unit());
    }
    pending_qts_updates_.erase(update_it);
  }

  if (applied_update_count > 0) {
    qts_gap_timeout_.cancel_timeout();
  }
  if (!pending_qts_updates_.empty()) {
    // if still have a gap, reset timeout
    auto update_it = pending_qts_updates_.begin();
    double receive_time = update_it->second.receive_time;
    for (size_t i = 0; i < GAP_TIMEOUT_UPDATE_COUNT; i++) {
      if (++update_it == pending_qts_updates_.end()) {
        break;
      }
      receive_time = min(receive_time, update_it->second.receive_time);
    }
    set_qts_gap_timeout(receive_time + MAX_UNFILLED_GAP_TIME - Time::now());
  }
  CHECK(!running_get_difference_);

  auto passed_time = Time::now() - begin_time;
  if (passed_time >= UPDATE_APPLY_WARNING_TIME) {
    LOG(WARNING) << "QTS has changed from " << initial_qts << " to " << get_qts() << " after applying "
                 << applied_update_count << " and keeping " << pending_qts_updates_.size() << " pending updates in "
                 << passed_time << " seconds";
  }
}

void UpdatesManager::set_pts_gap_timeout(double timeout) {
  if (!pts_gap_timeout_.has_timeout() || timeout < pts_gap_timeout_.get_timeout()) {
    LOG(DEBUG) << "Set PTS gap timeout in " << timeout;
    if (timeout > 2 * MIN_UNFILLED_GAP_TIME) {
      min_pts_gap_timeout_.set_callback(std::move(check_pts_gap));
      min_pts_gap_timeout_.set_callback_data(static_cast<void *>(td_));
      min_pts_gap_timeout_.set_timeout_in(MIN_UNFILLED_GAP_TIME);
    }

    pts_gap_timeout_.set_callback(std::move(fill_pts_gap));
    pts_gap_timeout_.set_callback_data(static_cast<void *>(td_));
    pts_gap_timeout_.set_timeout_in(timeout);
    last_pts_gap_time_ = Time::now();
  }
}

void UpdatesManager::set_seq_gap_timeout(double timeout) {
  if (!seq_gap_timeout_.has_timeout() || timeout < seq_gap_timeout_.get_timeout()) {
    LOG(DEBUG) << "Set seq gap timeout in " << timeout;
    seq_gap_timeout_.set_callback(std::move(fill_seq_gap));
    seq_gap_timeout_.set_callback_data(static_cast<void *>(td_));
    seq_gap_timeout_.set_timeout_in(timeout);
  }
}

void UpdatesManager::set_qts_gap_timeout(double timeout) {
  if (!qts_gap_timeout_.has_timeout() || timeout < qts_gap_timeout_.get_timeout()) {
    LOG(DEBUG) << "Set QTS gap timeout in " << timeout;
    qts_gap_timeout_.set_callback(std::move(fill_qts_gap));
    qts_gap_timeout_.set_callback_data(static_cast<void *>(td_));
    qts_gap_timeout_.set_timeout_in(timeout);
  }
}

void UpdatesManager::on_pending_update(tl_object_ptr<telegram_api::Update> update, int32 seq, Promise<Unit> &&promise,
                                       const char *source) {
  vector<tl_object_ptr<telegram_api::Update>> updates;
  updates.push_back(std::move(update));
  on_pending_updates(std::move(updates), seq, seq, 0, Time::now(), std::move(promise), source);
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateNewMessage> update, Promise<Unit> &&promise) {
  int new_pts = update->pts_;
  int pts_count = update->pts_count_;
  add_pending_pts_update(std::move(update), new_pts, pts_count, Time::now(), std::move(promise), "updateNewMessage");
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateNewChannelMessage> update, Promise<Unit> &&promise) {
  DialogId dialog_id = DialogId::get_message_dialog_id(update->message_);
  int new_pts = update->pts_;
  int pts_count = update->pts_count_;
  td_->messages_manager_->add_pending_channel_update(dialog_id, std::move(update), new_pts, pts_count,
                                                     std::move(promise), "updateNewChannelMessage");
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateMessageID> update, Promise<Unit> &&promise) {
  LOG(ERROR) << "Receive not in getDifference and not in on_pending_updates " << to_string(update);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateReadMessagesContents> update,
                               Promise<Unit> &&promise) {
  int new_pts = update->pts_;
  int pts_count = update->pts_count_;
  add_pending_pts_update(std::move(update), new_pts, pts_count, Time::now(), std::move(promise),
                         "updateReadMessagesContents");
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateEditMessage> update, Promise<Unit> &&promise) {
  int new_pts = update->pts_;
  int pts_count = update->pts_count_;
  add_pending_pts_update(std::move(update), new_pts, pts_count, Time::now(), std::move(promise), "updateEditMessage");
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDeleteMessages> update, Promise<Unit> &&promise) {
  int new_pts = update->pts_;
  int pts_count = update->pts_count_;
  if (update->messages_.empty()) {
    add_pending_pts_update(make_tl_object<dummyUpdate>(), new_pts, pts_count, Time::now(), Promise<Unit>(),
                           "updateDeleteMessages");
    promise.set_value(Unit());
  } else {
    add_pending_pts_update(std::move(update), new_pts, pts_count, Time::now(), std::move(promise),
                           "updateDeleteMessages");
  }
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateReadHistoryInbox> update, Promise<Unit> &&promise) {
  int new_pts = update->pts_;
  int pts_count = update->pts_count_;
  add_pending_pts_update(std::move(update), new_pts, pts_count, Time::now(), std::move(promise),
                         "updateReadHistoryInbox");
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateReadHistoryOutbox> update, Promise<Unit> &&promise) {
  int new_pts = update->pts_;
  int pts_count = update->pts_count_;
  add_pending_pts_update(std::move(update), new_pts, pts_count, Time::now(), std::move(promise),
                         "updateReadHistoryOutbox");
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateServiceNotification> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_service_notification(std::move(update), true, Promise<Unit>());
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChat> update, Promise<Unit> &&promise) {
  td_->dialog_manager_->on_dialog_info_full_invalidated(DialogId(ChatId(update->chat_id_)));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateReadChannelInbox> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_read_channel_inbox(std::move(update));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateReadChannelOutbox> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_read_channel_outbox(std::move(update));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannelReadMessagesContents> update,
                               Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_read_channel_messages_contents(std::move(update));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannelTooLong> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_channel_too_long(std::move(update), false);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannel> update, Promise<Unit> &&promise) {
  td_->chat_manager_->invalidate_channel_full(ChannelId(update->channel_id_), false, "updateChannel");
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateEditChannelMessage> update, Promise<Unit> &&promise) {
  DialogId dialog_id = DialogId::get_message_dialog_id(update->message_);
  int new_pts = update->pts_;
  int pts_count = update->pts_count_;
  td_->messages_manager_->add_pending_channel_update(dialog_id, std::move(update), new_pts, pts_count,
                                                     std::move(promise), "updateEditChannelMessage");
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDeleteChannelMessages> update,
                               Promise<Unit> &&promise) {
  DialogId dialog_id(ChannelId(update->channel_id_));
  int new_pts = update->pts_;
  int pts_count = update->pts_count_;
  td_->messages_manager_->add_pending_channel_update(dialog_id, std::move(update), new_pts, pts_count,
                                                     std::move(promise), "updateDeleteChannelMessages");
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannelMessageViews> update, Promise<Unit> &&promise) {
  ChannelId channel_id(update->channel_id_);
  if (!channel_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << channel_id;
  } else {
    DialogId dialog_id(channel_id);
    td_->messages_manager_->on_update_message_view_count({dialog_id, MessageId(ServerMessageId(update->id_))},
                                                         update->views_);
  }
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannelMessageForwards> update,
                               Promise<Unit> &&promise) {
  ChannelId channel_id(update->channel_id_);
  if (!channel_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << channel_id;
  } else {
    DialogId dialog_id(channel_id);
    td_->messages_manager_->on_update_message_forward_count({dialog_id, MessageId(ServerMessageId(update->id_))},
                                                            update->forwards_);
  }
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannelAvailableMessages> update,
                               Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_channel_max_unavailable_message_id(
      ChannelId(update->channel_id_), MessageId(ServerMessageId(update->available_min_id_)),
      "updateChannelAvailableMessages");
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannelViewForumAsMessages> update,
                               Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_dialog_view_as_messages(DialogId(ChannelId(update->channel_id_)), update->enabled_);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateReadChannelDiscussionInbox> update,
                               Promise<Unit> &&promise) {
  auto last_read_inbox_message_id = MessageId(ServerMessageId(update->read_max_id_));
  if (!last_read_inbox_message_id.is_valid()) {
    LOG(ERROR) << "Receive " << to_string(update);
    return;
  }
  td_->messages_manager_->on_update_read_message_comments(DialogId(ChannelId(update->channel_id_)),
                                                          MessageId(ServerMessageId(update->top_msg_id_)), MessageId(),
                                                          last_read_inbox_message_id, MessageId(), -1);
  if (update->broadcast_id_ != 0) {
    td_->messages_manager_->on_update_read_message_comments(DialogId(ChannelId(update->broadcast_id_)),
                                                            MessageId(ServerMessageId(update->broadcast_post_)),
                                                            MessageId(), last_read_inbox_message_id, MessageId(), -1);
  }
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateReadChannelDiscussionOutbox> update,
                               Promise<Unit> &&promise) {
  auto last_read_outbox_message_id = MessageId(ServerMessageId(update->read_max_id_));
  if (!last_read_outbox_message_id.is_valid()) {
    LOG(ERROR) << "Receive " << to_string(update);
    return;
  }
  td_->messages_manager_->on_update_read_message_comments(DialogId(ChannelId(update->channel_id_)),
                                                          MessageId(ServerMessageId(update->top_msg_id_)), MessageId(),
                                                          MessageId(), last_read_outbox_message_id, -1);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannelPinnedTopic> update, Promise<Unit> &&promise) {
  td_->forum_topic_manager_->on_update_forum_topic_is_pinned(
      DialogId(ChannelId(update->channel_id_)), MessageId(ServerMessageId(update->topic_id_)), update->pinned_);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannelPinnedTopics> update, Promise<Unit> &&promise) {
  vector<MessageId> top_thread_message_ids;
  for (auto &server_message_id : update->order_) {
    auto message_id = MessageId(ServerMessageId(server_message_id));
    if (!message_id.is_valid()) {
      LOG(ERROR) << "Receive " << to_string(update);
      break;
    }
    top_thread_message_ids.push_back(message_id);
  }
  td_->forum_topic_manager_->on_update_pinned_forum_topics(DialogId(ChannelId(update->channel_id_)),
                                                           std::move(top_thread_message_ids));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePinnedMessages> update, Promise<Unit> &&promise) {
  int new_pts = update->pts_;
  int pts_count = update->pts_count_;
  add_pending_pts_update(std::move(update), new_pts, pts_count, Time::now(), std::move(promise),
                         "updatePinnedMessages");
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePinnedChannelMessages> update,
                               Promise<Unit> &&promise) {
  DialogId dialog_id(ChannelId(update->channel_id_));
  int new_pts = update->pts_;
  int pts_count = update->pts_count_;
  td_->messages_manager_->add_pending_channel_update(dialog_id, std::move(update), new_pts, pts_count,
                                                     std::move(promise), "updatePinnedChannelMessages");
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateNotifySettings> update, Promise<Unit> &&promise) {
  switch (update->peer_->get_id()) {
    case telegram_api::notifyPeer::ID: {
      auto notify_peer = static_cast<const telegram_api::notifyPeer *>(update->peer_.get());
      DialogId dialog_id(notify_peer->peer_);
      if (dialog_id.is_valid()) {
        td_->messages_manager_->on_update_dialog_notify_settings(dialog_id, std::move(update->notify_settings_),
                                                                 "updateNotifySettings");
      } else {
        LOG(ERROR) << "Receive wrong " << to_string(update);
      }
      break;
    }
    case telegram_api::notifyUsers::ID:
      td_->notification_settings_manager_->on_update_scope_notify_settings(NotificationSettingsScope::Private,
                                                                           std::move(update->notify_settings_));
      break;
    case telegram_api::notifyChats::ID:
      td_->notification_settings_manager_->on_update_scope_notify_settings(NotificationSettingsScope::Group,
                                                                           std::move(update->notify_settings_));
      break;
    case telegram_api::notifyBroadcasts::ID:
      td_->notification_settings_manager_->on_update_scope_notify_settings(NotificationSettingsScope::Channel,
                                                                           std::move(update->notify_settings_));
      break;
    case telegram_api::notifyForumTopic::ID: {
      auto notify_peer = static_cast<const telegram_api::notifyForumTopic *>(update->peer_.get());
      DialogId dialog_id(notify_peer->peer_);
      auto top_thread_message_id = MessageId(ServerMessageId(notify_peer->top_msg_id_));
      if (dialog_id.is_valid() && top_thread_message_id.is_valid()) {
        td_->forum_topic_manager_->on_update_forum_topic_notify_settings(
            dialog_id, top_thread_message_id, std::move(update->notify_settings_), "updateNotifySettings");
      } else {
        LOG(ERROR) << "Receive wrong " << to_string(update);
      }
      break;
    }
    default:
      UNREACHABLE();
  }
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePeerSettings> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_get_peer_settings(DialogId(update->peer_), std::move(update->settings_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePeerHistoryTTL> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_dialog_message_ttl(DialogId(update->peer_), MessageTtl(update->ttl_period_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePeerLocated> update, Promise<Unit> &&promise) {
  // shouldn't be sent by the server
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateWebPage> update, Promise<Unit> &&promise) {
  td_->web_pages_manager_->on_get_web_page(std::move(update->webpage_), DialogId());
  add_pending_pts_update(make_tl_object<dummyUpdate>(), update->pts_, update->pts_count_, Time::now(), Promise<Unit>(),
                         "updateWebPage");
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannelWebPage> update, Promise<Unit> &&promise) {
  td_->web_pages_manager_->on_get_web_page(std::move(update->webpage_), DialogId());
  DialogId dialog_id(ChannelId(update->channel_id_));
  td_->messages_manager_->add_pending_channel_update(dialog_id, make_tl_object<dummyUpdate>(), update->pts_,
                                                     update->pts_count_, Promise<Unit>(), "updateChannelWebPage");
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateMessageReactions> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_message_reactions(
      {DialogId(update->peer_), MessageId(ServerMessageId(update->msg_id_))}, std::move(update->reactions_),
      std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateRecentReactions> update, Promise<Unit> &&promise) {
  td_->reaction_manager_->reload_reaction_list(ReactionListType::Recent, "updateRecentReactions");
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateSavedReactionTags> update, Promise<Unit> &&promise) {
  td_->reaction_manager_->on_update_saved_reaction_tags(Promise<Unit>());
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePaidReactionPrivacy> update, Promise<Unit> &&promise) {
  td_->reaction_manager_->on_update_default_paid_reaction_type(PaidReactionType(td_, update->private_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateAttachMenuBots> update, Promise<Unit> &&promise) {
  td_->attach_menu_manager_->reload_attach_menu_bots(std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateWebViewResultSent> update, Promise<Unit> &&promise) {
  td_->web_app_manager_->close_web_view(update->query_id_, std::move(promise));
  send_closure(G()->td(), &Td::send_update, td_api::make_object<td_api::updateWebAppMessageSent>(update->query_id_));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateFolderPeers> update, Promise<Unit> &&promise) {
  for (auto &folder_peer : update->folder_peers_) {
    DialogId dialog_id(folder_peer->peer_);
    FolderId folder_id(folder_peer->folder_id_);
    td_->messages_manager_->on_update_dialog_folder_id(dialog_id, folder_id);
  }

  if (update->pts_ > 0) {
    add_pending_pts_update(make_tl_object<dummyUpdate>(), update->pts_, update->pts_count_, Time::now(),
                           Promise<Unit>(), "updateFolderPeers");
  }
  promise.set_value(Unit());
}

int32 UpdatesManager::get_short_update_date() const {
  int32 now = G()->unix_time();
  if (short_update_date_ > 0) {
    return min(short_update_date_, now);
  }
  return now;
}

bool UpdatesManager::have_update_pts_changed(const vector<tl_object_ptr<telegram_api::Update>> &updates) {
  for (auto &update : updates) {
    CHECK(update != nullptr);
    if (update->get_id() == telegram_api::updatePtsChanged::ID) {
      return true;
    }
  }
  return false;
}

bool UpdatesManager::check_pts_update_dialog_id(DialogId dialog_id) {
  switch (dialog_id.get_type()) {
    case DialogType::User:
    case DialogType::Chat:
      return true;
    case DialogType::Channel:
    case DialogType::SecretChat:
    case DialogType::None:
      return false;
    default:
      UNREACHABLE();
      return false;
  }
}

bool UpdatesManager::check_pts_update(const tl_object_ptr<telegram_api::Update> &update) {
  CHECK(update != nullptr);
  switch (update->get_id()) {
    case dummyUpdate::ID:
    case updateSentMessage::ID:
    case telegram_api::updateReadMessagesContents::ID:
    case telegram_api::updateDeleteMessages::ID:
      return true;
    case telegram_api::updateNewMessage::ID: {
      auto update_new_message = static_cast<const telegram_api::updateNewMessage *>(update.get());
      return check_pts_update_dialog_id(DialogId::get_message_dialog_id(update_new_message->message_));
    }
    case telegram_api::updateReadHistoryInbox::ID: {
      auto update_read_history_inbox = static_cast<const telegram_api::updateReadHistoryInbox *>(update.get());
      return check_pts_update_dialog_id(DialogId(update_read_history_inbox->peer_));
    }
    case telegram_api::updateReadHistoryOutbox::ID: {
      auto update_read_history_outbox = static_cast<const telegram_api::updateReadHistoryOutbox *>(update.get());
      return check_pts_update_dialog_id(DialogId(update_read_history_outbox->peer_));
    }
    case telegram_api::updateEditMessage::ID: {
      auto update_edit_message = static_cast<const telegram_api::updateEditMessage *>(update.get());
      return check_pts_update_dialog_id(DialogId::get_message_dialog_id(update_edit_message->message_));
    }
    case telegram_api::updatePinnedMessages::ID: {
      auto update_pinned_messages = static_cast<const telegram_api::updatePinnedMessages *>(update.get());
      return check_pts_update_dialog_id(DialogId(update_pinned_messages->peer_));
    }
    default:
      return false;
  }
}

bool UpdatesManager::is_pts_update(const telegram_api::Update *update) {
  switch (update->get_id()) {
    case telegram_api::updateNewMessage::ID:
    case telegram_api::updateReadMessagesContents::ID:
    case telegram_api::updateEditMessage::ID:
    case telegram_api::updateDeleteMessages::ID:
    case telegram_api::updateReadHistoryInbox::ID:
    case telegram_api::updateReadHistoryOutbox::ID:
    case telegram_api::updateWebPage::ID:
    case telegram_api::updatePinnedMessages::ID:
    case telegram_api::updateFolderPeers::ID:
      return true;
    default:
      return false;
  }
}

int32 UpdatesManager::get_update_pts(const telegram_api::Update *update) {
  switch (update->get_id()) {
    case telegram_api::updateNewMessage::ID:
      return static_cast<const telegram_api::updateNewMessage *>(update)->pts_;
    case telegram_api::updateReadMessagesContents::ID:
      return static_cast<const telegram_api::updateReadMessagesContents *>(update)->pts_;
    case telegram_api::updateEditMessage::ID:
      return static_cast<const telegram_api::updateEditMessage *>(update)->pts_;
    case telegram_api::updateDeleteMessages::ID:
      return static_cast<const telegram_api::updateDeleteMessages *>(update)->pts_;
    case telegram_api::updateReadHistoryInbox::ID:
      return static_cast<const telegram_api::updateReadHistoryInbox *>(update)->pts_;
    case telegram_api::updateReadHistoryOutbox::ID:
      return static_cast<const telegram_api::updateReadHistoryOutbox *>(update)->pts_;
    case telegram_api::updateWebPage::ID:
      return static_cast<const telegram_api::updateWebPage *>(update)->pts_;
    case telegram_api::updatePinnedMessages::ID:
      return static_cast<const telegram_api::updatePinnedMessages *>(update)->pts_;
    case telegram_api::updateFolderPeers::ID:
      return static_cast<const telegram_api::updateFolderPeers *>(update)->pts_;
    default:
      return 0;
  }
}

bool UpdatesManager::is_qts_update(const telegram_api::Update *update) {
  switch (update->get_id()) {
    case telegram_api::updateNewEncryptedMessage::ID:
    case telegram_api::updateMessagePollVote::ID:
    case telegram_api::updateBotStopped::ID:
    case telegram_api::updateChatParticipant::ID:
    case telegram_api::updateChannelParticipant::ID:
    case telegram_api::updateBotChatInviteRequester::ID:
    case telegram_api::updateBotChatBoost::ID:
    case telegram_api::updateBotMessageReaction::ID:
    case telegram_api::updateBotMessageReactions::ID:
    case telegram_api::updateBotBusinessConnect::ID:
    case telegram_api::updateBotNewBusinessMessage::ID:
    case telegram_api::updateBotEditBusinessMessage::ID:
    case telegram_api::updateBotDeleteBusinessMessage::ID:
    case telegram_api::updateBotPurchasedPaidMedia::ID:
      return true;
    default:
      return false;
  }
}

int32 UpdatesManager::get_update_qts(const telegram_api::Update *update) {
  switch (update->get_id()) {
    case telegram_api::updateNewEncryptedMessage::ID:
      return static_cast<const telegram_api::updateNewEncryptedMessage *>(update)->qts_;
    case telegram_api::updateMessagePollVote::ID:
      return static_cast<const telegram_api::updateMessagePollVote *>(update)->qts_;
    case telegram_api::updateBotStopped::ID:
      return static_cast<const telegram_api::updateBotStopped *>(update)->qts_;
    case telegram_api::updateChatParticipant::ID:
      return static_cast<const telegram_api::updateChatParticipant *>(update)->qts_;
    case telegram_api::updateChannelParticipant::ID:
      return static_cast<const telegram_api::updateChannelParticipant *>(update)->qts_;
    case telegram_api::updateBotChatInviteRequester::ID:
      return static_cast<const telegram_api::updateBotChatInviteRequester *>(update)->qts_;
    case telegram_api::updateBotChatBoost::ID:
      return static_cast<const telegram_api::updateBotChatBoost *>(update)->qts_;
    case telegram_api::updateBotMessageReaction::ID:
      return static_cast<const telegram_api::updateBotMessageReaction *>(update)->qts_;
    case telegram_api::updateBotMessageReactions::ID:
      return static_cast<const telegram_api::updateBotMessageReactions *>(update)->qts_;
    case telegram_api::updateBotBusinessConnect::ID:
      return static_cast<const telegram_api::updateBotBusinessConnect *>(update)->qts_;
    case telegram_api::updateBotNewBusinessMessage::ID:
      return static_cast<const telegram_api::updateBotNewBusinessMessage *>(update)->qts_;
    case telegram_api::updateBotEditBusinessMessage::ID:
      return static_cast<const telegram_api::updateBotEditBusinessMessage *>(update)->qts_;
    case telegram_api::updateBotDeleteBusinessMessage::ID:
      return static_cast<const telegram_api::updateBotDeleteBusinessMessage *>(update)->qts_;
    case telegram_api::updateBotPurchasedPaidMedia::ID:
      return static_cast<const telegram_api::updateBotPurchasedPaidMedia *>(update)->qts_;
    default:
      return 0;
  }
}

bool UpdatesManager::is_channel_pts_update(const telegram_api::Update *update) {
  switch (update->get_id()) {
    case telegram_api::updateNewChannelMessage::ID:
    case telegram_api::updateEditChannelMessage::ID:
    case telegram_api::updateDeleteChannelMessages::ID:
    case telegram_api::updatePinnedChannelMessages::ID:
      return true;
    default:
      return false;
  }
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateUserTyping> update, Promise<Unit> &&promise) {
  DialogId dialog_id(UserId(update->user_id_));
  td_->dialog_action_manager_->on_dialog_action(dialog_id, MessageId(), dialog_id,
                                                DialogAction(std::move(update->action_)), get_short_update_date());
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChatUserTyping> update, Promise<Unit> &&promise) {
  td_->dialog_action_manager_->on_dialog_action(DialogId(ChatId(update->chat_id_)), MessageId(),
                                                DialogId(update->from_id_), DialogAction(std::move(update->action_)),
                                                get_short_update_date());
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannelUserTyping> update, Promise<Unit> &&promise) {
  td_->dialog_action_manager_->on_dialog_action(
      DialogId(ChannelId(update->channel_id_)), MessageId(ServerMessageId(update->top_msg_id_)),
      DialogId(update->from_id_), DialogAction(std::move(update->action_)), get_short_update_date());
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateEncryptedChatTyping> update, Promise<Unit> &&promise) {
  SecretChatId secret_chat_id(update->chat_id_);
  UserId user_id = td_->user_manager_->get_secret_chat_user_id(secret_chat_id);
  td_->dialog_action_manager_->on_dialog_action(DialogId(secret_chat_id), MessageId(), DialogId(user_id),
                                                DialogAction::get_typing_action(), get_short_update_date());
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateUserStatus> update, Promise<Unit> &&promise) {
  td_->user_manager_->on_update_user_online(UserId(update->user_id_), std::move(update->status_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateUserName> update, Promise<Unit> &&promise) {
  td_->user_manager_->on_update_user_name(UserId(update->user_id_), std::move(update->first_name_),
                                          std::move(update->last_name_),
                                          Usernames{string(), std::move(update->usernames_)});
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateUserPhone> update, Promise<Unit> &&promise) {
  td_->user_manager_->on_update_user_phone_number(UserId(update->user_id_), std::move(update->phone_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateUser> update, Promise<Unit> &&promise) {
  td_->user_manager_->invalidate_user_full(UserId(update->user_id_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateUserEmojiStatus> update, Promise<Unit> &&promise) {
  td_->user_manager_->on_update_user_emoji_status(UserId(update->user_id_), std::move(update->emoji_status_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateRecentEmojiStatuses> update, Promise<Unit> &&promise) {
  get_recent_emoji_statuses(td_, Auto());
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePeerBlocked> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_dialog_is_blocked(DialogId(update->peer_id_), update->blocked_,
                                                      update->blocked_my_stories_from_);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotCommands> update, Promise<Unit> &&promise) {
  td_->dialog_manager_->on_update_dialog_bot_commands(DialogId(update->peer_), UserId(update->bot_id_),
                                                      std::move(update->commands_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotMenuButton> update, Promise<Unit> &&promise) {
  td_->user_manager_->on_update_bot_menu_button(UserId(update->bot_id_), std::move(update->button_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChatParticipants> update, Promise<Unit> &&promise) {
  td_->chat_manager_->on_get_chat_participants(std::move(update->participants_), true);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChatParticipantAdd> update, Promise<Unit> &&promise) {
  td_->chat_manager_->on_update_chat_add_user(ChatId(update->chat_id_), UserId(update->inviter_id_),
                                              UserId(update->user_id_), update->date_, update->version_);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChatParticipantAdmin> update,
                               Promise<Unit> &&promise) {
  td_->chat_manager_->on_update_chat_edit_administrator(ChatId(update->chat_id_), UserId(update->user_id_),
                                                        update->is_admin_, update->version_);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChatParticipantDelete> update,
                               Promise<Unit> &&promise) {
  td_->chat_manager_->on_update_chat_delete_user(ChatId(update->chat_id_), UserId(update->user_id_), update->version_);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChatDefaultBannedRights> update,
                               Promise<Unit> &&promise) {
  DialogId dialog_id(update->peer_);
  auto version = update->version_;
  switch (dialog_id.get_type()) {
    case DialogType::Chat:
      td_->chat_manager_->on_update_chat_default_permissions(
          dialog_id.get_chat_id(), RestrictedRights(update->default_banned_rights_, ChannelType::Unknown), version);
      break;
    case DialogType::Channel:
      LOG_IF(ERROR, version != 0) << "Receive version " << version << " in " << dialog_id;
      td_->chat_manager_->on_update_channel_default_permissions(
          dialog_id.get_channel_id(), RestrictedRights(update->default_banned_rights_, ChannelType::Megagroup));
      break;
    case DialogType::None:
    case DialogType::User:
    case DialogType::SecretChat:
    default:
      LOG(ERROR) << "Receive updateChatDefaultBannedRights in " << dialog_id;
      break;
  }
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDraftMessage> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_dialog_draft_message(
      DialogId(update->peer_), MessageId(ServerMessageId(update->top_msg_id_)), std::move(update->draft_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDialogPinned> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_dialog_is_pinned(FolderId(update->folder_id_), DialogId(update->peer_),
                                                     update->pinned_);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePinnedDialogs> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_pinned_dialogs(FolderId(update->folder_id_));  // TODO use update->order_
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateSavedDialogPinned> update, Promise<Unit> &&promise) {
  td_->saved_messages_manager_->reload_pinned_saved_messages_topics();
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePinnedSavedDialogs> update, Promise<Unit> &&promise) {
  td_->saved_messages_manager_->reload_pinned_saved_messages_topics();
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDialogUnreadMark> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_dialog_is_marked_as_unread(DialogId(update->peer_), update->unread_);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDialogFilter> update, Promise<Unit> &&promise) {
  td_->dialog_filter_manager_->on_update_dialog_filters(std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDialogFilters> update, Promise<Unit> &&promise) {
  td_->dialog_filter_manager_->on_update_dialog_filters(std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDialogFilterOrder> update, Promise<Unit> &&promise) {
  td_->dialog_filter_manager_->on_update_dialog_filters(std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDcOptions> update, Promise<Unit> &&promise) {
  send_closure(G()->config_manager(), &ConfigManager::on_dc_options_update, DcOptions(update->dc_options_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotInlineQuery> update, Promise<Unit> &&promise) {
  td_->inline_queries_manager_->on_new_query(update->query_id_, UserId(update->user_id_), Location(td_, update->geo_),
                                             std::move(update->peer_type_), update->query_, update->offset_);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotInlineSend> update, Promise<Unit> &&promise) {
  td_->inline_queries_manager_->on_chosen_result(UserId(update->user_id_), Location(td_, update->geo_), update->query_,
                                                 update->id_, std::move(update->msg_id_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotCallbackQuery> update, Promise<Unit> &&promise) {
  td_->callback_queries_manager_->on_new_query(update->query_id_, UserId(update->user_id_), DialogId(update->peer_),
                                               MessageId(ServerMessageId(update->msg_id_)), std::move(update->data_),
                                               update->chat_instance_, std::move(update->game_short_name_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateInlineBotCallbackQuery> update,
                               Promise<Unit> &&promise) {
  td_->callback_queries_manager_->on_new_inline_query(update->query_id_, UserId(update->user_id_),
                                                      std::move(update->msg_id_), std::move(update->data_),
                                                      update->chat_instance_, std::move(update->game_short_name_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBusinessBotCallbackQuery> update,
                               Promise<Unit> &&promise) {
  td_->callback_queries_manager_->on_new_business_query(
      update->query_id_, UserId(update->user_id_), std::move(update->connection_id_), std::move(update->message_),
      std::move(update->reply_to_message_), std::move(update->data_), update->chat_instance_);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateFavedStickers> update, Promise<Unit> &&promise) {
  td_->stickers_manager_->reload_favorite_stickers(true);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateSavedGifs> update, Promise<Unit> &&promise) {
  td_->animations_manager_->reload_saved_animations(true);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateConfig> update, Promise<Unit> &&promise) {
  send_closure(td_->config_manager_, &ConfigManager::request_config, false);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePtsChanged> update, Promise<Unit> &&promise) {
  if (td_->option_manager_->get_option_integer("session_count") > 1) {
    auto old_pts = get_pts();
    auto new_pts = 1;
    if (old_pts != new_pts) {
      LOG(WARNING) << "PTS changes from " << old_pts << " from updatePtsChanged";
      save_pts(new_pts);
      add_pts(new_pts).set_value(Unit());
      get_difference("updatePtsChanged");
    }
  } else {
    set_pts(std::numeric_limits<int32>::max(), "updatePtsChanged").set_value(Unit());
  }
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateEncryption> update, Promise<Unit> &&promise) {
  send_closure(td_->secret_chats_manager_, &SecretChatsManager::on_update_chat, std::move(update));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateNewEncryptedMessage> update, Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateEncryptedMessagesRead> update,
                               Promise<Unit> &&promise) {
  td_->messages_manager_->read_secret_chat_outbox(SecretChatId(update->chat_id_), update->max_date_, update->date_);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePrivacy> update, Promise<Unit> &&promise) {
  td_->privacy_manager_->on_update_privacy(std::move(update));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateNewStickerSet> update, Promise<Unit> &&promise) {
  td_->stickers_manager_->on_get_messages_sticker_set(StickerSetId(), std::move(update->stickerset_), true,
                                                      "updateNewStickerSet");
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateStickerSets> update, Promise<Unit> &&promise) {
  auto sticker_type = get_sticker_type(update->masks_, update->emojis_);
  td_->stickers_manager_->on_update_sticker_sets(sticker_type);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateStickerSetsOrder> update, Promise<Unit> &&promise) {
  auto sticker_type = get_sticker_type(update->masks_, update->emojis_);
  td_->stickers_manager_->on_update_sticker_sets_order(sticker_type,
                                                       StickersManager::convert_sticker_set_ids(update->order_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateMoveStickerSetToTop> update, Promise<Unit> &&promise) {
  auto sticker_type = get_sticker_type(update->masks_, update->emojis_);
  td_->stickers_manager_->on_update_move_sticker_set_to_top(sticker_type, StickerSetId(update->stickerset_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateReadFeaturedStickers> update,
                               Promise<Unit> &&promise) {
  td_->stickers_manager_->reload_featured_sticker_sets(StickerType::Regular, true);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateReadFeaturedEmojiStickers> update,
                               Promise<Unit> &&promise) {
  td_->stickers_manager_->reload_featured_sticker_sets(StickerType::CustomEmoji, true);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateRecentStickers> update, Promise<Unit> &&promise) {
  td_->stickers_manager_->reload_recent_stickers(false, true);
  td_->stickers_manager_->reload_recent_stickers(true, true);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotShippingQuery> update, Promise<Unit> &&promise) {
  UserId user_id(update->user_id_);
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive shipping query from invalid " << user_id;
  } else {
    CHECK(update->shipping_address_ != nullptr);

    send_closure(
        G()->td(), &Td::send_update,
        make_tl_object<td_api::updateNewShippingQuery>(
            update->query_id_, td_->user_manager_->get_user_id_object(user_id, "updateNewShippingQuery"),
            update->payload_.as_slice().str(),
            get_address_object(get_address(std::move(update->shipping_address_)))));  // TODO use convert_address
  }
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotPrecheckoutQuery> update, Promise<Unit> &&promise) {
  UserId user_id(update->user_id_);
  if (!user_id.is_valid()) {
    LOG(ERROR) << "Receive pre-checkout query from invalid " << user_id;
  } else if (update->total_amount_ <= 0 || !check_currency_amount(update->total_amount_)) {
    LOG(ERROR) << "Receive pre-checkout query with invalid total amount " << update->total_amount_;
  } else {
    send_closure(G()->td(), &Td::send_update,
                 make_tl_object<td_api::updateNewPreCheckoutQuery>(
                     update->query_id_, td_->user_manager_->get_user_id_object(user_id, "updateNewPreCheckoutQuery"),
                     update->currency_, update->total_amount_, update->payload_.as_slice().str(),
                     update->shipping_option_id_, get_order_info_object(get_order_info(std::move(update->info_)))));
  }
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotWebhookJSON> update, Promise<Unit> &&promise) {
  send_closure(G()->td(), &Td::send_update, make_tl_object<td_api::updateNewCustomEvent>(update->data_->data_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotWebhookJSONQuery> update, Promise<Unit> &&promise) {
  send_closure(G()->td(), &Td::send_update,
               make_tl_object<td_api::updateNewCustomQuery>(update->query_id_, update->data_->data_, update->timeout_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePhoneCall> update, Promise<Unit> &&promise) {
  send_closure(G()->call_manager(), &CallManager::update_call, std::move(update));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePhoneCallSignalingData> update,
                               Promise<Unit> &&promise) {
  send_closure(G()->call_manager(), &CallManager::update_call_signaling_data, update->phone_call_id_,
               update->data_.as_slice().str());
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateGroupCallConnection> update, Promise<Unit> &&promise) {
  if (update->presentation_) {
    LOG(ERROR) << "Receive unexpected updateGroupCallConnection";
  } else {
    send_closure(G()->group_call_manager(), &GroupCallManager::on_update_group_call_connection,
                 std::move(update->params_->data_));
  }
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateGroupCall> update, Promise<Unit> &&promise) {
  DialogId dialog_id(ChatId(update->chat_id_));
  if (dialog_id != DialogId() && !td_->dialog_manager_->have_dialog_force(dialog_id, "updateGroupCall")) {
    dialog_id = DialogId(ChannelId(update->chat_id_));
    if (!td_->dialog_manager_->have_dialog_force(dialog_id, "updateGroupCall")) {
      dialog_id = DialogId();
    }
  }
  send_closure(G()->group_call_manager(), &GroupCallManager::on_update_group_call, std::move(update->call_), dialog_id);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateGroupCallParticipants> update,
                               Promise<Unit> &&promise) {
  send_closure(G()->group_call_manager(), &GroupCallManager::on_update_group_call_participants,
               InputGroupCallId(update->call_), std::move(update->participants_), update->version_, false);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateContactsReset> update, Promise<Unit> &&promise) {
  td_->user_manager_->on_update_contacts_reset();
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateLangPackTooLong> update, Promise<Unit> &&promise) {
  send_closure(G()->language_pack_manager(), &LanguagePackManager::on_language_pack_too_long,
               std::move(update->lang_code_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateLangPack> update, Promise<Unit> &&promise) {
  send_closure(G()->language_pack_manager(), &LanguagePackManager::on_update_language_pack,
               std::move(update->difference_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateGeoLiveViewed> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_live_location_viewed(
      {DialogId(update->peer_), MessageId(ServerMessageId(update->msg_id_))});
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateMessageExtendedMedia> update,
                               Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_message_extended_media(
      {DialogId(update->peer_), MessageId(ServerMessageId(update->msg_id_))}, std::move(update->extended_media_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateMessagePoll> update, Promise<Unit> &&promise) {
  td_->poll_manager_->on_get_poll(PollId(update->poll_id_), std::move(update->poll_), std::move(update->results_),
                                  "updateMessagePoll");
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateMessagePollVote> update, Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateNewScheduledMessage> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_get_message(std::move(update->message_), true, false, true, "updateNewScheduledMessage");
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDeleteScheduledMessages> update,
                               Promise<Unit> &&promise) {
  vector<ScheduledServerMessageId> message_ids = transform(update->messages_, [](int32 scheduled_server_message_id) {
    return ScheduledServerMessageId(scheduled_server_message_id);
  });
  auto dialog_id = DialogId(update->peer_);
  td_->messages_manager_->on_update_delete_scheduled_messages(dialog_id, std::move(message_ids));
  if (!td_->auth_manager_->is_bot()) {
    for (auto message_id : update->sent_messages_) {
      td_->messages_manager_->on_update_message_video_published(
          {DialogId(dialog_id), MessageId(ServerMessageId(message_id))});
    }
  }
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateLoginToken> update, Promise<Unit> &&promise) {
  LOG(INFO) << "Ignore updateLoginToken after authorization";
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotStopped> update, Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChatParticipant> update, Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateChannelParticipant> update, Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotChatInviteRequester> update,
                               Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotChatBoost> update, Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotMessageReaction> update, Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotMessageReactions> update, Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotPurchasedPaidMedia> update,
                               Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateTheme> update, Promise<Unit> &&promise) {
  td_->theme_manager_->on_update_theme(std::move(update->theme_), std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePeerWallpaper> update, Promise<Unit> &&promise) {
  auto dialog_id = DialogId(update->peer_);
  if (dialog_id.get_type() == DialogType::User) {
    td_->user_manager_->on_update_user_wallpaper_overridden(dialog_id.get_user_id(), update->wallpaper_overridden_);
  }
  td_->messages_manager_->on_update_dialog_background(dialog_id, std::move(update->wallpaper_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updatePendingJoinRequests> update, Promise<Unit> &&promise) {
  td_->messages_manager_->on_update_dialog_pending_join_requests(DialogId(update->peer_), update->requests_pending_,
                                                                 std::move(update->recent_requesters_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateSavedRingtones> update, Promise<Unit> &&promise) {
  td_->notification_settings_manager_->reload_saved_ringtones(std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateTranscribedAudio> update, Promise<Unit> &&promise) {
  td_->transcription_manager_->on_update_transcribed_audio(std::move(update));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateAutoSaveSettings> update, Promise<Unit> &&promise) {
  td_->autosave_manager_->reload_autosave_settings();
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateStory> update, Promise<Unit> &&promise) {
  td_->story_manager_->on_get_story(DialogId(update->peer_), std::move(update->story_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateReadStories> update, Promise<Unit> &&promise) {
  td_->story_manager_->on_update_read_stories(DialogId(update->peer_), StoryId(update->max_id_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateStoriesStealthMode> update, Promise<Unit> &&promise) {
  td_->story_manager_->on_update_story_stealth_mode(std::move(update->stealth_mode_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateSentStoryReaction> update, Promise<Unit> &&promise) {
  td_->story_manager_->on_update_story_chosen_reaction_type(DialogId(update->peer_), StoryId(update->story_id_),
                                                            ReactionType(update->reaction_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateStoryID> update, Promise<Unit> &&promise) {
  LOG(ERROR) << "Receive not in getDifference and not in on_pending_updates " << to_string(update);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateNewAuthorization> update, Promise<Unit> &&promise) {
  if (update->unconfirmed_) {
    td_->account_manager_->on_new_unconfirmed_authorization(update->hash_, update->date_, std::move(update->device_),
                                                            std::move(update->location_));
  } else {
    td_->account_manager_->on_confirm_authorization(update->hash_);
  }
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateSmsJob> update, Promise<Unit> &&promise) {
  LOG(ERROR) << "Receive " << to_string(update);
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateQuickReplies> update, Promise<Unit> &&promise) {
  td_->quick_reply_manager_->reload_quick_reply_shortcuts();
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateNewQuickReply> update, Promise<Unit> &&promise) {
  td_->quick_reply_manager_->reload_quick_reply_shortcuts();
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDeleteQuickReply> update, Promise<Unit> &&promise) {
  td_->quick_reply_manager_->reload_quick_reply_shortcuts();
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateQuickReplyMessage> update, Promise<Unit> &&promise) {
  td_->quick_reply_manager_->update_quick_reply_message(std::move(update->message_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateDeleteQuickReplyMessages> update,
                               Promise<Unit> &&promise) {
  vector<MessageId> message_ids;
  for (auto message : update->messages_) {
    message_ids.push_back(MessageId(ServerMessageId(message)));
  }
  td_->quick_reply_manager_->delete_quick_reply_messages_from_updates(QuickReplyShortcutId(update->shortcut_id_),
                                                                      std::move(message_ids));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotBusinessConnect> update, Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotNewBusinessMessage> update,
                               Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotEditBusinessMessage> update,
                               Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBotDeleteBusinessMessage> update,
                               Promise<Unit> &&promise) {
  auto qts = update->qts_;
  add_pending_qts_update(std::move(update), qts, std::move(promise));
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateBroadcastRevenueTransactions> update,
                               Promise<Unit> &&promise) {
  td_->statistics_manager_->on_update_dialog_revenue_transactions(DialogId(update->peer_),
                                                                  std::move(update->balances_));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateStarsBalance> update, Promise<Unit> &&promise) {
  td_->star_manager_->on_update_owned_star_amount(StarAmount(std::move(update->balance_), true));
  promise.set_value(Unit());
}

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateStarsRevenueStatus> update, Promise<Unit> &&promise) {
  td_->star_manager_->on_update_stars_revenue_status(std::move(update));
  promise.set_value(Unit());
}

// unsupported updates

void UpdatesManager::on_update(tl_object_ptr<telegram_api::updateNewStoryReaction> update, Promise<Unit> &&promise) {
  promise.set_value(Unit());
}

}  // namespace td
