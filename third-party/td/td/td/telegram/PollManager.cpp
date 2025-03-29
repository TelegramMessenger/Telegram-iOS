//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/PollManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChainId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/OnlineManager.h"
#include "td/telegram/PollId.hpp"
#include "td/telegram/PollManager.hpp"
#include "td/telegram/StateManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogHelper.h"
#include "td/db/SqliteKeyValue.h"
#include "td/db/SqliteKeyValueAsync.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/tl_helpers.h"

#include <algorithm>
#include <limits>

namespace td {

class GetPollResultsQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<telegram_api::Updates>> promise_;
  PollId poll_id_;
  DialogId dialog_id_;
  MessageId message_id_;

 public:
  explicit GetPollResultsQuery(Promise<tl_object_ptr<telegram_api::Updates>> &&promise) : promise_(std::move(promise)) {
  }

  void send(PollId poll_id, MessageFullId message_full_id) {
    poll_id_ = poll_id;
    dialog_id_ = message_full_id.get_dialog_id();
    message_id_ = message_full_id.get_message_id();
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      LOG(INFO) << "Can't reget poll, because have no read access to " << dialog_id_;
      return promise_.set_value(nullptr);
    }

    auto message_id = message_id_.get_server_message_id().get();
    send_query(
        G()->net_query_creator().create(telegram_api::messages_getPollResults(std::move(input_peer), message_id)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getPollResults>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    if (!td_->messages_manager_->on_get_message_error(dialog_id_, message_id_, status, "GetPollResultsQuery")) {
      LOG(ERROR) << "Receive " << status << ", while trying to get results of " << poll_id_;
    }
    promise_.set_error(std::move(status));
  }
};

class GetPollVotersQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<telegram_api::messages_votesList>> promise_;
  PollId poll_id_;
  DialogId dialog_id_;

 public:
  explicit GetPollVotersQuery(Promise<tl_object_ptr<telegram_api::messages_votesList>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(PollId poll_id, MessageFullId message_full_id, BufferSlice &&option, const string &offset, int32 limit) {
    poll_id_ = poll_id;
    dialog_id_ = message_full_id.get_dialog_id();
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      LOG(INFO) << "Can't get poll, because have no read access to " << dialog_id_;
      return promise_.set_error(Status::Error(400, "Chat is not accessible"));
    }

    CHECK(!option.empty());
    int32 flags = telegram_api::messages_getPollVotes::OPTION_MASK;
    if (!offset.empty()) {
      flags |= telegram_api::messages_getPollVotes::OFFSET_MASK;
    }

    auto message_id = message_full_id.get_message_id().get_server_message_id().get();
    send_query(G()->net_query_creator().create(telegram_api::messages_getPollVotes(
        flags, std::move(input_peer), message_id, std::move(option), offset, limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getPollVotes>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetPollVotersQuery") &&
        status.message() != "MESSAGE_ID_INVALID") {
      LOG(ERROR) << "Receive " << status << ", while trying to get voters of " << poll_id_;
    }
    promise_.set_error(std::move(status));
  }
};

class SendVoteQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<telegram_api::Updates>> promise_;
  DialogId dialog_id_;

 public:
  explicit SendVoteQuery(Promise<tl_object_ptr<telegram_api::Updates>> &&promise) : promise_(std::move(promise)) {
  }

  void send(MessageFullId message_full_id, vector<BufferSlice> &&options, PollId poll_id, uint64 generation,
            NetQueryRef *query_ref) {
    dialog_id_ = message_full_id.get_dialog_id();
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      LOG(INFO) << "Can't set poll answer, because have no read access to " << dialog_id_;
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    auto message_id = message_full_id.get_message_id().get_server_message_id().get();
    auto query = G()->net_query_creator().create(
        telegram_api::messages_sendVote(std::move(input_peer), message_id, std::move(options)),
        {{poll_id}, {dialog_id_}});
    *query_ref = query.get_weak();
    send_query(std::move(query));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_sendVote>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SendVoteQuery: " << to_string(result);
    promise_.set_value(std::move(result));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SendVoteQuery");
    promise_.set_error(std::move(status));
  }
};

class StopPollQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit StopPollQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(MessageFullId message_full_id, unique_ptr<ReplyMarkup> &&reply_markup, PollId poll_id) {
    dialog_id_ = message_full_id.get_dialog_id();
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Edit);
    if (input_peer == nullptr) {
      LOG(INFO) << "Can't close poll, because have no edit access to " << dialog_id_;
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = telegram_api::messages_editMessage::MEDIA_MASK;
    auto input_reply_markup = get_input_reply_markup(td_->user_manager_.get(), reply_markup);
    if (input_reply_markup != nullptr) {
      flags |= telegram_api::messages_editMessage::REPLY_MARKUP_MASK;
    }

    auto message_id = message_full_id.get_message_id().get_server_message_id().get();
    auto poll = telegram_api::make_object<telegram_api::poll>(
        poll_id.get(), telegram_api::poll::CLOSED_MASK, false /*ignored*/, false /*ignored*/, false /*ignored*/,
        false /*ignored*/, telegram_api::make_object<telegram_api::textWithEntities>(string(), Auto()), Auto(), 0, 0);
    auto input_media = telegram_api::make_object<telegram_api::inputMediaPoll>(0, std::move(poll),
                                                                               vector<BufferSlice>(), string(), Auto());
    send_query(G()->net_query_creator().create(
        telegram_api::messages_editMessage(flags, false /*ignored*/, false /*ignored*/, std::move(input_peer),
                                           message_id, string(), std::move(input_media), std::move(input_reply_markup),
                                           vector<tl_object_ptr<telegram_api::MessageEntity>>(), 0, 0),
        {{poll_id}, {dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_editMessage>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for StopPollQuery: " << to_string(result);
    td_->updates_manager_->on_get_updates(std::move(result), std::move(promise_));
  }

  void on_error(Status status) final {
    if (!td_->auth_manager_->is_bot() && status.message() == "MESSAGE_NOT_MODIFIED") {
      return promise_.set_value(Unit());
    }
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "StopPollQuery");
    promise_.set_error(std::move(status));
  }
};

PollManager::PollManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  update_poll_timeout_.set_callback(on_update_poll_timeout_callback);
  update_poll_timeout_.set_callback_data(static_cast<void *>(this));

  close_poll_timeout_.set_callback(on_close_poll_timeout_callback);
  close_poll_timeout_.set_callback_data(static_cast<void *>(this));

  unload_poll_timeout_.set_callback(on_unload_poll_timeout_callback);
  unload_poll_timeout_.set_callback_data(static_cast<void *>(this));
}

void PollManager::start_up() {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  class StateCallback final : public StateManager::Callback {
   public:
    explicit StateCallback(ActorId<PollManager> parent) : parent_(std::move(parent)) {
    }
    bool on_online(bool is_online) final {
      if (is_online) {
        send_closure(parent_, &PollManager::on_online);
      }
      return parent_.is_alive();
    }

   private:
    ActorId<PollManager> parent_;
  };
  send_closure(G()->state_manager(), &StateManager::add_callback, make_unique<StateCallback>(actor_id(this)));
}

void PollManager::tear_down() {
  parent_.reset();
}

PollManager::~PollManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), polls_, server_poll_messages_,
                                              other_poll_messages_, reply_poll_counts_, poll_voters_,
                                              loaded_from_database_polls_);
}

void PollManager::on_update_poll_timeout_callback(void *poll_manager_ptr, int64 poll_id_int) {
  if (G()->close_flag()) {
    return;
  }

  auto poll_manager = static_cast<PollManager *>(poll_manager_ptr);
  send_closure_later(poll_manager->actor_id(poll_manager), &PollManager::on_update_poll_timeout, PollId(poll_id_int));
}

void PollManager::on_close_poll_timeout_callback(void *poll_manager_ptr, int64 poll_id_int) {
  if (G()->close_flag()) {
    return;
  }

  auto poll_manager = static_cast<PollManager *>(poll_manager_ptr);
  send_closure_later(poll_manager->actor_id(poll_manager), &PollManager::on_close_poll_timeout, PollId(poll_id_int));
}

void PollManager::on_unload_poll_timeout_callback(void *poll_manager_ptr, int64 poll_id_int) {
  if (G()->close_flag()) {
    return;
  }

  auto poll_manager = static_cast<PollManager *>(poll_manager_ptr);
  send_closure_later(poll_manager->actor_id(poll_manager), &PollManager::on_unload_poll_timeout, PollId(poll_id_int));
}

bool PollManager::is_local_poll_id(PollId poll_id) {
  return poll_id.get() < 0 && poll_id.get() > std::numeric_limits<int32>::min();
}

const PollManager::Poll *PollManager::get_poll(PollId poll_id) const {
  return polls_.get_pointer(poll_id);
}

const PollManager::Poll *PollManager::get_poll(PollId poll_id) {
  auto p = polls_.get_pointer(poll_id);
  if (p != nullptr) {
    schedule_poll_unload(poll_id);
  }
  return p;
}

PollManager::Poll *PollManager::get_poll_editable(PollId poll_id) {
  auto p = polls_.get_pointer(poll_id);
  if (p != nullptr) {
    schedule_poll_unload(poll_id);
  }
  return p;
}

bool PollManager::have_poll(PollId poll_id) const {
  return get_poll(poll_id) != nullptr;
}

void PollManager::notify_on_poll_update(PollId poll_id) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  if (server_poll_messages_.count(poll_id) > 0) {
    server_poll_messages_[poll_id].foreach([&](const MessageFullId &message_full_id) {
      td_->messages_manager_->on_external_update_message_content(message_full_id, "notify_on_poll_update 1");
    });
  }

  if (other_poll_messages_.count(poll_id) > 0) {
    other_poll_messages_[poll_id].foreach([&](const MessageFullId &message_full_id) {
      td_->messages_manager_->on_external_update_message_content(message_full_id, "notify_on_poll_update 2");
    });
  }
}

string PollManager::get_poll_database_key(PollId poll_id) {
  return PSTRING() << "poll" << poll_id.get();
}

void PollManager::save_poll(const Poll *poll, PollId poll_id) {
  CHECK(!is_local_poll_id(poll_id));
  poll->was_saved_ = true;

  if (!G()->use_message_database()) {
    return;
  }

  LOG(INFO) << "Save " << poll_id << " to database";
  CHECK(poll != nullptr);
  G()->td_db()->get_sqlite_pmc()->set(get_poll_database_key(poll_id), log_event_store(*poll).as_slice().str(), Auto());
}

void PollManager::on_load_poll_from_database(PollId poll_id, string value) {
  CHECK(poll_id.is_valid());
  loaded_from_database_polls_.insert(poll_id);

  LOG(INFO) << "Successfully loaded " << poll_id << " of size " << value.size() << " from database";
  //  G()->td_db()->get_sqlite_pmc()->erase(get_poll_database_key(poll_id), Auto());
  //  return;

  CHECK(!have_poll(poll_id));
  if (!value.empty()) {
    auto poll = make_unique<Poll>();
    if (log_event_parse(*poll, value).is_error()) {
      return;
    }
    for (const auto &recent_voter_min_channel : poll->recent_voter_min_channels_) {
      LOG(INFO) << "Add min voted " << recent_voter_min_channel.first;
      td_->chat_manager_->add_min_channel(recent_voter_min_channel.first, recent_voter_min_channel.second);
    }
    Dependencies dependencies;
    for (auto dialog_id : poll->recent_voter_dialog_ids_) {
      dependencies.add_message_sender_dependencies(dialog_id);
    }
    if (!dependencies.resolve_force(td_, "on_load_poll_from_database")) {
      poll->recent_voter_dialog_ids_.clear();
      poll->recent_voter_min_channels_.clear();
    }
    if (!poll->is_closed_ && poll->close_date_ != 0) {
      if (poll->close_date_ <= G()->server_time()) {
        poll->is_closed_ = true;
      } else {
        CHECK(!is_local_poll_id(poll_id));
        if (!G()->close_flag()) {
          close_poll_timeout_.set_timeout_in(poll_id.get(), poll->close_date_ - G()->server_time() + 1e-3);
        }
      }
    }
    polls_[poll_id] = std::move(poll);
  }
}

bool PollManager::have_poll_force(PollId poll_id) {
  return get_poll_force(poll_id) != nullptr;
}

PollManager::Poll *PollManager::get_poll_force(PollId poll_id) {
  auto poll = get_poll_editable(poll_id);
  if (poll != nullptr) {
    return poll;
  }
  if (!G()->use_message_database()) {
    return nullptr;
  }
  if (!poll_id.is_valid() || loaded_from_database_polls_.count(poll_id)) {
    return nullptr;
  }

  LOG(INFO) << "Trying to load " << poll_id << " from database";
  on_load_poll_from_database(poll_id, G()->td_db()->get_sqlite_sync_pmc()->get(get_poll_database_key(poll_id)));
  return get_poll_editable(poll_id);
}

void PollManager::remove_unallowed_entities(FormattedText &text) {
  td::remove_if(text.entities, [](MessageEntity &entity) { return entity.type != MessageEntity::Type::CustomEmoji; });
}

td_api::object_ptr<td_api::pollOption> PollManager::get_poll_option_object(const PollOption &poll_option) {
  return td_api::make_object<td_api::pollOption>(get_formatted_text_object(nullptr, poll_option.text_, true, -1),
                                                 poll_option.voter_count_, 0, poll_option.is_chosen_, false);
}

vector<int32> PollManager::get_vote_percentage(const vector<int32> &voter_counts, int32 total_voter_count) {
  int32 sum = 0;
  for (auto voter_count : voter_counts) {
    CHECK(0 <= voter_count);
    CHECK(voter_count <= std::numeric_limits<int32>::max() - sum);
    sum += voter_count;
  }
  if (total_voter_count > sum) {
    if (sum != 0) {
      LOG(ERROR) << "Have total_voter_count = " << total_voter_count << ", but votes sum = " << sum << ": "
                 << voter_counts;
    }
    total_voter_count = sum;
  }

  vector<int32> result(voter_counts.size(), 0);
  if (total_voter_count == 0) {
    return result;
  }
  if (total_voter_count != sum) {
    // just round to the nearest
    for (size_t i = 0; i < result.size(); i++) {
      result[i] =
          static_cast<int32>((static_cast<int64>(voter_counts[i]) * 200 + total_voter_count) / total_voter_count / 2);
    }
    return result;
  }

  // make sure that options with equal votes have equal percent and total sum is less than 100%
  int32 percent_sum = 0;
  vector<int32> gap(voter_counts.size(), 0);
  for (size_t i = 0; i < result.size(); i++) {
    auto multiplied_voter_count = static_cast<int64>(voter_counts[i]) * 100;
    result[i] = static_cast<int32>(multiplied_voter_count / total_voter_count);
    CHECK(0 <= result[i] && result[i] <= 100);
    gap[i] = static_cast<int32>(static_cast<int64>(result[i] + 1) * total_voter_count - multiplied_voter_count);
    CHECK(0 <= gap[i] && gap[i] <= total_voter_count);
    percent_sum += result[i];
  }
  CHECK(0 <= percent_sum && percent_sum <= 100);
  if (percent_sum == 100) {
    return result;
  }

  // now we need to choose up to (100 - percent_sum) options with a minimum total gap, such that
  // any two options with the same voter_count are chosen or not chosen simultaneously
  struct Option {
    int32 pos = -1;
    int32 count = 0;
  };
  FlatHashMap<int32, Option> options;
  for (size_t i = 0; i < result.size(); i++) {
    auto &option = options[voter_counts[i] + 1];
    if (option.pos == -1) {
      option.pos = narrow_cast<int32>(i);
    }
    option.count++;
  }
  vector<Option> sorted_options;
  for (const auto &it : options) {
    const auto &option = it.second;
    auto pos = option.pos;
    if (gap[pos] > total_voter_count / 2) {
      // do not round to wrong direction
      continue;
    }
    if (total_voter_count % 2 == 0 && gap[pos] == total_voter_count / 2 && result[pos] >= 50) {
      // round halves to the 50%
      continue;
    }
    sorted_options.push_back(option);
  }
  std::sort(sorted_options.begin(), sorted_options.end(), [&](const Option &lhs, const Option &rhs) {
    if (gap[lhs.pos] != gap[rhs.pos]) {
      // prefer options with smallest gap
      return gap[lhs.pos] < gap[rhs.pos];
    }
    if (lhs.count != rhs.count) {
      // prefer more popular options
      return lhs.count > rhs.count;
    }
    return lhs.pos < rhs.pos;  // prefer the first encountered option
  });

  // dynamic programming or brute force can give perfect result, but for now we use simple gready approach
  int32 left_percent = 100 - percent_sum;
  for (auto option : sorted_options) {
    if (option.count <= left_percent) {
      left_percent -= option.count;

      auto pos = option.pos;
      for (size_t i = 0; i < result.size(); i++) {
        if (voter_counts[i] == voter_counts[pos]) {
          result[i]++;
        }
      }
      if (left_percent == 0) {
        break;
      }
    }
  }
  return result;
}

td_api::object_ptr<td_api::poll> PollManager::get_poll_object(PollId poll_id) const {
  auto poll = get_poll(poll_id);
  CHECK(poll != nullptr);
  return get_poll_object(poll_id, poll);
}

td_api::object_ptr<td_api::poll> PollManager::get_poll_object(PollId poll_id, const Poll *poll) const {
  vector<td_api::object_ptr<td_api::pollOption>> poll_options;
  auto it = pending_answers_.find(poll_id);
  int32 voter_count_diff = 0;
  if (it == pending_answers_.end() || (it->second.is_finished_ && poll->was_saved_)) {
    poll_options = transform(poll->options_, get_poll_option_object);
  } else {
    const auto &chosen_options = it->second.options_;
    LOG(INFO) << "Have pending chosen options " << chosen_options << " in " << poll_id;
    for (auto &poll_option : poll->options_) {
      auto is_being_chosen = td::contains(chosen_options, poll_option.data_);
      if (poll_option.is_chosen_) {
        voter_count_diff = -1;
      }
      poll_options.push_back(td_api::make_object<td_api::pollOption>(
          get_formatted_text_object(nullptr, poll_option.text_, true, -1),
          poll_option.voter_count_ - static_cast<int32>(poll_option.is_chosen_), 0, false, is_being_chosen));
    }
  }

  auto total_voter_count = poll->total_voter_count_ + voter_count_diff;
  bool is_voted = false;
  for (auto &poll_option : poll_options) {
    is_voted |= poll_option->is_chosen_;
  }
  if (!is_voted && !poll->is_closed_ && !td_->auth_manager_->is_bot()) {
    // hide the voter counts
    for (auto &poll_option : poll_options) {
      poll_option->voter_count_ = 0;
    }
  } else {
    // calculate vote percentage and fix total_voter_count
    auto voter_counts = transform(poll_options, [](auto &poll_option) { return poll_option->voter_count_; });
    auto voter_count_sum = 0;
    for (auto voter_count : voter_counts) {
      if (total_voter_count < voter_count) {
        LOG(ERROR) << "Fix total voter count from " << poll->total_voter_count_ << " + " << voter_count_diff << " to "
                   << voter_count << " in " << poll_id;
        total_voter_count = voter_count;
      }
      voter_count_sum += voter_count;
    }
    if (voter_count_sum < total_voter_count && voter_count_sum != 0) {
      LOG(ERROR) << "Fix total voter count from " << poll->total_voter_count_ << " + " << voter_count_diff << " to "
                 << voter_count_sum << " in " << poll_id;
      total_voter_count = voter_count_sum;
    }

    auto vote_percentage = get_vote_percentage(voter_counts, total_voter_count);
    CHECK(poll_options.size() == vote_percentage.size());
    for (size_t i = 0; i < poll_options.size(); i++) {
      poll_options[i]->vote_percentage_ = vote_percentage[i];
    }
  }
  td_api::object_ptr<td_api::PollType> poll_type;
  if (poll->is_quiz_) {
    auto correct_option_id = is_local_poll_id(poll_id) ? -1 : poll->correct_option_id_;
    poll_type = td_api::make_object<td_api::pollTypeQuiz>(
        correct_option_id,
        get_formatted_text_object(nullptr, is_local_poll_id(poll_id) ? FormattedText() : poll->explanation_, true, -1));
  } else {
    poll_type = td_api::make_object<td_api::pollTypeRegular>(poll->allow_multiple_answers_);
  }

  auto open_period = poll->open_period_;
  auto close_date = poll->close_date_;
  if (open_period != 0 && close_date == 0) {
    close_date = G()->unix_time() + open_period;
  }
  if (open_period == 0 && close_date != 0) {
    auto now = G()->unix_time();
    if (close_date < now + 5) {
      close_date = 0;
    } else {
      open_period = close_date - now;
    }
  }
  if (poll->is_closed_) {
    open_period = 0;
    close_date = 0;
  }

  vector<td_api::object_ptr<td_api::MessageSender>> recent_voters;
  for (auto dialog_id : poll->recent_voter_dialog_ids_) {
    auto recent_voter = get_min_message_sender_object(td_, dialog_id, "get_poll_object");
    if (recent_voter != nullptr) {
      recent_voters.push_back(std::move(recent_voter));
    }
  }
  return td_api::make_object<td_api::poll>(poll_id.get(), get_formatted_text_object(nullptr, poll->question_, true, -1),
                                           std::move(poll_options), total_voter_count, std::move(recent_voters),
                                           poll->is_anonymous_, std::move(poll_type), open_period, close_date,
                                           poll->is_closed_);
}

telegram_api::object_ptr<telegram_api::pollAnswer> PollManager::get_input_poll_option(const PollOption &poll_option) {
  return telegram_api::make_object<telegram_api::pollAnswer>(
      get_input_text_with_entities(nullptr, poll_option.text_, "get_input_poll_option"),
      BufferSlice(poll_option.data_));
}

PollId PollManager::create_poll(FormattedText &&question, vector<FormattedText> &&options, bool is_anonymous,
                                bool allow_multiple_answers, bool is_quiz, int32 correct_option_id,
                                FormattedText &&explanation, int32 open_period, int32 close_date, bool is_closed) {
  remove_unallowed_entities(question);
  for (auto &option : options) {
    remove_unallowed_entities(option);
  }
  auto poll = make_unique<Poll>();
  poll->question_ = std::move(question);
  int pos = '0';
  for (auto &option_text : options) {
    PollOption option;
    option.text_ = std::move(option_text);
    option.data_ = string(1, narrow_cast<char>(pos++));
    poll->options_.push_back(std::move(option));
  }
  poll->is_anonymous_ = is_anonymous;
  poll->allow_multiple_answers_ = allow_multiple_answers;
  poll->is_quiz_ = is_quiz;
  poll->correct_option_id_ = correct_option_id;
  poll->explanation_ = std::move(explanation);
  poll->open_period_ = open_period;
  poll->close_date_ = close_date;
  poll->is_closed_ = is_closed;

  PollId poll_id(--current_local_poll_id_);
  CHECK(is_local_poll_id(poll_id));
  polls_.set(poll_id, std::move(poll));
  return poll_id;
}

void PollManager::register_poll(PollId poll_id, MessageFullId message_full_id, const char *source) {
  CHECK(have_poll(poll_id));
  if (message_full_id.get_message_id().is_scheduled() || !message_full_id.get_message_id().is_server()) {
    other_poll_messages_[poll_id].insert(message_full_id);
    if (!G()->close_flag()) {
      unload_poll_timeout_.cancel_timeout(poll_id.get());
    }
    return;
  }
  LOG(INFO) << "Register " << poll_id << " from " << message_full_id << " from " << source;
  server_poll_messages_[poll_id].insert(message_full_id);
  auto poll = get_poll(poll_id);
  CHECK(poll != nullptr);
  if (!td_->auth_manager_->is_bot() && !is_local_poll_id(poll_id) &&
      !(poll->is_closed_ && poll->is_updated_after_close_) && !G()->close_flag()) {
    update_poll_timeout_.add_timeout_in(poll_id.get(), 0);
  }
  if (!G()->close_flag()) {
    unload_poll_timeout_.cancel_timeout(poll_id.get());
  }
}

void PollManager::unregister_poll(PollId poll_id, MessageFullId message_full_id, const char *source) {
  CHECK(have_poll(poll_id));
  if (message_full_id.get_message_id().is_scheduled() || !message_full_id.get_message_id().is_server()) {
    auto &message_ids = other_poll_messages_[poll_id];
    auto is_deleted = message_ids.erase(message_full_id) > 0;
    LOG_CHECK(is_deleted) << source << ' ' << poll_id << ' ' << message_full_id;
    if (is_local_poll_id(poll_id)) {
      CHECK(message_ids.empty());
      forget_local_poll(poll_id);
    }
    if (message_ids.empty()) {
      other_poll_messages_.erase(poll_id);

      schedule_poll_unload(poll_id);
    }
    return;
  }
  LOG(INFO) << "Unregister " << poll_id << " from " << message_full_id << " from " << source;
  auto &message_ids = server_poll_messages_[poll_id];
  auto is_deleted = message_ids.erase(message_full_id) > 0;
  LOG_CHECK(is_deleted) << source << ' ' << poll_id << ' ' << message_full_id;
  if (is_local_poll_id(poll_id)) {
    CHECK(message_ids.empty());
    forget_local_poll(poll_id);
  }
  if (message_ids.empty()) {
    server_poll_messages_.erase(poll_id);
    if (!G()->close_flag()) {
      update_poll_timeout_.cancel_timeout(poll_id.get(), "unregister_poll");
    }

    schedule_poll_unload(poll_id);
  }
}

void PollManager::register_reply_poll(PollId poll_id) {
  CHECK(have_poll(poll_id));
  CHECK(!is_local_poll_id(poll_id));
  LOG(INFO) << "Register replied " << poll_id;
  reply_poll_counts_[poll_id]++;
  if (!G()->close_flag()) {
    unload_poll_timeout_.cancel_timeout(poll_id.get());
  }
}

void PollManager::unregister_reply_poll(PollId poll_id) {
  CHECK(have_poll(poll_id));
  CHECK(!is_local_poll_id(poll_id));
  LOG(INFO) << "Unregister replied " << poll_id;
  auto &count = reply_poll_counts_[poll_id];
  CHECK(count > 0);
  count--;
  if (count == 0) {
    reply_poll_counts_.erase(poll_id);
    schedule_poll_unload(poll_id);
  }
}

bool PollManager::can_unload_poll(PollId poll_id) {
  if (G()->close_flag()) {
    return false;
  }
  if (is_local_poll_id(poll_id) || server_poll_messages_.count(poll_id) != 0 ||
      other_poll_messages_.count(poll_id) != 0 || reply_poll_counts_.count(poll_id) != 0 ||
      pending_answers_.count(poll_id) != 0 || being_closed_polls_.count(poll_id) != 0) {
    return false;
  }

  auto it = poll_voters_.find(poll_id);
  if (it != poll_voters_.end() && !it->second.empty()) {
    for (auto &voters : it->second) {
      if (!voters.pending_queries_.empty()) {
        return false;
      }
    }
  }

  return true;
}

void PollManager::schedule_poll_unload(PollId poll_id) {
  if (can_unload_poll(poll_id)) {
    unload_poll_timeout_.set_timeout_in(poll_id.get(), UNLOAD_POLL_DELAY);
  }
}

bool PollManager::get_poll_is_closed(PollId poll_id) const {
  auto poll = get_poll(poll_id);
  CHECK(poll != nullptr);
  return poll->is_closed_;
}

bool PollManager::get_poll_is_anonymous(PollId poll_id) const {
  auto poll = get_poll(poll_id);
  CHECK(poll != nullptr);
  return poll->is_anonymous_;
}

string PollManager::get_poll_search_text(PollId poll_id) const {
  auto poll = get_poll(poll_id);
  CHECK(poll != nullptr);

  string result = poll->question_.text;
  for (auto &option : poll->options_) {
    result += ' ';
    result += option.text_.text;
  }
  return result;
}

void PollManager::set_poll_answer(PollId poll_id, MessageFullId message_full_id, vector<int32> &&option_ids,
                                  Promise<Unit> &&promise) {
  td::unique(option_ids);

  if (is_local_poll_id(poll_id)) {
    return promise.set_error(Status::Error(400, "Poll can't be answered"));
  }

  auto poll = get_poll(poll_id);
  CHECK(poll != nullptr);
  if (poll->is_closed_) {
    return promise.set_error(Status::Error(400, "Can't answer closed poll"));
  }
  if (!poll->allow_multiple_answers_ && option_ids.size() > 1) {
    return promise.set_error(Status::Error(400, "Can't choose more than 1 option in the poll"));
  }
  if (poll->is_quiz_ && option_ids.empty()) {
    return promise.set_error(Status::Error(400, "Can't retract vote in a quiz"));
  }
  if (poll->is_quiz_ && pending_answers_.count(poll_id) != 0) {
    return promise.set_error(Status::Error(400, "Can't revote in a quiz"));
  }

  FlatHashMap<uint64, int> affected_option_ids;
  vector<string> options;
  for (auto &option_id : option_ids) {
    auto index = static_cast<size_t>(option_id);
    if (index >= poll->options_.size()) {
      return promise.set_error(Status::Error(400, "Invalid option ID specified"));
    }
    options.push_back(poll->options_[index].data_);

    affected_option_ids[index + 1]++;
  }
  for (size_t option_index = 0; option_index < poll->options_.size(); option_index++) {
    if (poll->options_[option_index].is_chosen_) {
      if (poll->is_quiz_) {
        return promise.set_error(Status::Error(400, "Can't revote in a quiz"));
      }
      affected_option_ids[option_index + 1]++;
    }
  }
  for (const auto &it : affected_option_ids) {
    if (it.second == 1) {
      invalidate_poll_option_voters(poll, poll_id, static_cast<size_t>(it.first - 1));
    }
  }

  do_set_poll_answer(poll_id, message_full_id, std::move(options), 0, std::move(promise));
}

class PollManager::SetPollAnswerLogEvent {
 public:
  PollId poll_id_;
  MessageFullId message_full_id_;
  vector<string> options_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(poll_id_, storer);
    td::store(message_full_id_, storer);
    td::store(options_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(poll_id_, parser);
    td::parse(message_full_id_, parser);
    td::parse(options_, parser);
  }
};

void PollManager::do_set_poll_answer(PollId poll_id, MessageFullId message_full_id, vector<string> &&options,
                                     uint64 log_event_id, Promise<Unit> &&promise) {
  LOG(INFO) << "Set answer in " << poll_id << " from " << message_full_id;
  if (!poll_id.is_valid() || !message_full_id.get_dialog_id().is_valid() ||
      !message_full_id.get_message_id().is_valid()) {
    CHECK(log_event_id != 0);
    LOG(ERROR) << "Invalid SetPollAnswer log event";
    binlog_erase(G()->td_db()->get_binlog(), log_event_id);
    return;
  }
  if (!G()->close_flag()) {
    unload_poll_timeout_.cancel_timeout(poll_id.get());
  }

  auto &pending_answer = pending_answers_[poll_id];
  if (!pending_answer.promises_.empty() && pending_answer.options_ == options) {
    pending_answer.promises_.push_back(std::move(promise));
    return;
  }

  if (pending_answer.log_event_id_ != 0 && log_event_id != 0) {
    LOG(ERROR) << "Duplicate SetPollAnswer log event: " << pending_answer.log_event_id_ << " and " << log_event_id;
    binlog_erase(G()->td_db()->get_binlog(), log_event_id);
    return;
  }
  if (log_event_id == 0 && G()->use_message_database()) {
    SetPollAnswerLogEvent log_event;
    log_event.poll_id_ = poll_id;
    log_event.message_full_id_ = message_full_id;
    log_event.options_ = options;
    auto storer = get_log_event_storer(log_event);
    if (pending_answer.generation_ == 0 || pending_answer.is_finished_) {
      CHECK(pending_answer.log_event_id_ == 0);
      log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::SetPollAnswer, storer);
      LOG(INFO) << "Add set poll answer log event " << log_event_id;
      CHECK(log_event_id != 0);
    } else {
      CHECK(pending_answer.log_event_id_ != 0);
      log_event_id = pending_answer.log_event_id_;
      auto new_log_event_id =
          binlog_rewrite(G()->td_db()->get_binlog(), log_event_id, LogEvent::HandlerType::SetPollAnswer, storer);
      LOG(INFO) << "Rewrite set poll answer log event " << log_event_id << " with " << new_log_event_id;
    }
  }

  if (!pending_answer.promises_.empty()) {
    CHECK(!pending_answer.query_ref_.empty());
    cancel_query(pending_answer.query_ref_);
    pending_answer.query_ref_ = NetQueryRef();

    auto promises = std::move(pending_answer.promises_);
    pending_answer.promises_.clear();
    for (auto &old_promise : promises) {
      old_promise.set_value(Unit());
    }
  }

  vector<BufferSlice> sent_options;
  for (auto &option : options) {
    sent_options.emplace_back(option);
  }

  auto generation = ++current_generation_;

  pending_answer.options_ = std::move(options);
  pending_answer.promises_.push_back(std::move(promise));
  pending_answer.generation_ = generation;
  pending_answer.log_event_id_ = log_event_id;
  pending_answer.is_finished_ = false;

  notify_on_poll_update(poll_id);

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), poll_id, generation](Result<tl_object_ptr<telegram_api::Updates>> &&result) {
        send_closure(actor_id, &PollManager::on_set_poll_answer, poll_id, generation, std::move(result));
      });
  td_->create_handler<SendVoteQuery>(std::move(query_promise))
      ->send(message_full_id, std::move(sent_options), poll_id, generation, &pending_answer.query_ref_);
}

void PollManager::on_set_poll_answer(PollId poll_id, uint64 generation,
                                     Result<tl_object_ptr<telegram_api::Updates>> &&result) {
  if (G()->close_flag() && result.is_error()) {
    // request will be re-sent after restart
    return;
  }
  auto it = pending_answers_.find(poll_id);
  if (it == pending_answers_.end()) {
    // can happen if this is an answer with mismatched generation and server has ignored invoke-after
    return;
  }

  auto &pending_answer = it->second;
  CHECK(!pending_answer.promises_.empty());
  if (pending_answer.generation_ != generation) {
    return;
  }

  if (pending_answer.log_event_id_ != 0) {
    LOG(INFO) << "Delete set poll answer log event " << pending_answer.log_event_id_;
    binlog_erase(G()->td_db()->get_binlog(), pending_answer.log_event_id_);
    pending_answer.log_event_id_ = 0;
  }

  pending_answer.is_finished_ = true;

  auto poll = get_poll(poll_id);
  if (poll != nullptr) {
    poll->was_saved_ = false;
  }
  if (result.is_ok()) {
    td_->updates_manager_->on_get_updates(
        result.move_as_ok(),
        PromiseCreator::lambda([actor_id = actor_id(this), poll_id, generation](Result<Unit> &&result) mutable {
          send_closure(actor_id, &PollManager::on_set_poll_answer_finished, poll_id, Unit(), generation);
        }));
  } else {
    on_set_poll_answer_finished(poll_id, result.move_as_error(), generation);
  }
}

void PollManager::on_set_poll_answer_finished(PollId poll_id, Result<Unit> &&result, uint64 generation) {
  auto it = pending_answers_.find(poll_id);
  if (it == pending_answers_.end()) {
    return;
  }

  auto &pending_answer = it->second;
  CHECK(!pending_answer.promises_.empty());
  if (pending_answer.generation_ != generation) {
    return;
  }
  CHECK(pending_answer.is_finished_);

  auto promises = std::move(pending_answer.promises_);
  pending_answers_.erase(it);

  if (!G()->close_flag()) {
    auto poll = get_poll(poll_id);
    if (poll != nullptr && !poll->was_saved_) {
      // no updates were sent during updates processing, so send them
      // poll wasn't changed, so there is no reason to actually save it
      if (!(poll->is_closed_ && poll->is_updated_after_close_)) {
        LOG(INFO) << "Schedule updating of " << poll_id << " soon";
        update_poll_timeout_.set_timeout_in(poll_id.get(), 0.0);
      }

      notify_on_poll_update(poll_id);
      poll->was_saved_ = true;
    }
  }

  LOG(INFO) << "Finish to set answer for " << poll_id;

  if (result.is_ok()) {
    set_promises(promises);
  } else {
    fail_promises(promises, result.move_as_error());
  }
}

void PollManager::invalidate_poll_voters(const Poll *poll, PollId poll_id) {
  if (poll->is_anonymous_) {
    return;
  }

  auto it = poll_voters_.find(poll_id);
  if (it == poll_voters_.end()) {
    return;
  }

  for (auto &voters : it->second) {
    voters.was_invalidated_ = true;
  }
}

void PollManager::invalidate_poll_option_voters(const Poll *poll, PollId poll_id, size_t option_index) {
  if (poll->is_anonymous_) {
    return;
  }

  auto it = poll_voters_.find(poll_id);
  if (it == poll_voters_.end()) {
    return;
  }

  auto &poll_voters = it->second;
  CHECK(poll_voters.size() == poll->options_.size());
  CHECK(option_index < poll_voters.size());
  poll_voters[option_index].was_invalidated_ = true;
}

PollManager::PollOptionVoters &PollManager::get_poll_option_voters(const Poll *poll, PollId poll_id, int32 option_id) {
  auto &poll_voters = poll_voters_[poll_id];
  if (poll_voters.empty()) {
    poll_voters.resize(poll->options_.size());
  }
  auto index = narrow_cast<size_t>(option_id);
  CHECK(index < poll_voters.size());
  return poll_voters[index];
}

td_api::object_ptr<td_api::messageSenders> PollManager::get_poll_voters_object(
    int32 total_count, const vector<DialogId> &voter_dialog_ids) const {
  auto result = td_api::make_object<td_api::messageSenders>();
  result->total_count_ = total_count;
  for (auto dialog_id : voter_dialog_ids) {
    auto message_sender = get_min_message_sender_object(td_, dialog_id, "get_poll_voters_object");
    if (message_sender != nullptr) {
      result->senders_.push_back(std::move(message_sender));
    }
  }
  return result;
}

void PollManager::get_poll_voters(PollId poll_id, MessageFullId message_full_id, int32 option_id, int32 offset,
                                  int32 limit, Promise<td_api::object_ptr<td_api::messageSenders>> &&promise) {
  if (is_local_poll_id(poll_id)) {
    return promise.set_error(Status::Error(400, "Poll results can't be received"));
  }
  if (offset < 0) {
    return promise.set_error(Status::Error(400, "Invalid offset specified"));
  }
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_GET_POLL_VOTERS) {
    limit = MAX_GET_POLL_VOTERS;
  }

  auto poll = get_poll(poll_id);
  CHECK(poll != nullptr);
  if (option_id < 0 || static_cast<size_t>(option_id) >= poll->options_.size()) {
    return promise.set_error(Status::Error(400, "Invalid option ID specified"));
  }
  if (poll->is_anonymous_) {
    return promise.set_error(Status::Error(400, "Poll is anonymous"));
  }

  auto &voters = get_poll_option_voters(poll, poll_id, option_id);
  if (voters.pending_queries_.empty() && voters.was_invalidated_ && offset == 0) {
    voters.voter_dialog_ids_.clear();
    voters.next_offset_.clear();
    voters.was_invalidated_ = false;
  }

  auto cur_offset = narrow_cast<int32>(voters.voter_dialog_ids_.size());

  if (offset > cur_offset) {
    return promise.set_error(Status::Error(400, "Too big offset specified; voters can be received only consequently"));
  }
  if (offset < cur_offset) {
    vector<DialogId> result;
    for (int32 i = offset; i != cur_offset && i - offset < limit; i++) {
      result.push_back(voters.voter_dialog_ids_[i]);
    }
    return promise.set_value(
        get_poll_voters_object(max(poll->options_[option_id].voter_count_, cur_offset), std::move(result)));
  }

  if (poll->options_[option_id].voter_count_ == 0 || (voters.next_offset_.empty() && cur_offset > 0)) {
    return promise.set_value(get_poll_voters_object(0, vector<DialogId>()));
  }

  voters.pending_queries_.push_back(std::move(promise));
  if (voters.pending_queries_.size() > 1) {
    return;
  }

  unload_poll_timeout_.cancel_timeout(poll_id.get());

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), poll_id, option_id, offset = voters.next_offset_,
                              limit](Result<tl_object_ptr<telegram_api::messages_votesList>> &&result) mutable {
        send_closure(actor_id, &PollManager::on_get_poll_voters, poll_id, option_id, std::move(offset), limit,
                     std::move(result));
      });
  td_->create_handler<GetPollVotersQuery>(std::move(query_promise))
      ->send(poll_id, message_full_id, BufferSlice(poll->options_[option_id].data_), voters.next_offset_,
             max(limit, 10));
}

void PollManager::on_get_poll_voters(PollId poll_id, int32 option_id, string offset, int32 limit,
                                     Result<tl_object_ptr<telegram_api::messages_votesList>> &&result) {
  G()->ignore_result_if_closing(result);

  auto poll = get_poll(poll_id);
  CHECK(poll != nullptr);
  if (option_id < 0 || static_cast<size_t>(option_id) >= poll->options_.size()) {
    LOG(ERROR) << "Can't process voters for option " << option_id << " in " << poll_id << ", because it has only "
               << poll->options_.size() << " options";
    return;
  }
  if (poll->is_anonymous_) {
    // just in case
    result = Status::Error(400, "Poll is anonymous");
  }

  auto &voters = get_poll_option_voters(poll, poll_id, option_id);
  if (voters.next_offset_ != offset) {
    LOG(ERROR) << "Expected results for option " << option_id << " in " << poll_id << " with offset "
               << voters.next_offset_ << ", but received with " << offset;
    return;
  }
  auto promises = std::move(voters.pending_queries_);
  if (promises.empty()) {
    LOG(ERROR) << "Have no waiting promises for option " << option_id << " in " << poll_id;
    return;
  }
  if (result.is_error()) {
    fail_promises(promises, result.move_as_error());
    return;
  }

  auto vote_list = result.move_as_ok();
  td_->user_manager_->on_get_users(std::move(vote_list->users_), "on_get_poll_voters");
  td_->chat_manager_->on_get_chats(std::move(vote_list->chats_), "on_get_poll_voters");

  voters.next_offset_ = std::move(vote_list->next_offset_);
  if (poll->options_[option_id].voter_count_ != vote_list->count_) {
    ++current_generation_;
    update_poll_timeout_.set_timeout_in(poll_id.get(), 0.0);
  }

  vector<DialogId> dialog_ids;
  for (auto &peer_vote : vote_list->votes_) {
    DialogId dialog_id;
    switch (peer_vote->get_id()) {
      case telegram_api::messagePeerVote::ID: {
        auto voter = telegram_api::move_object_as<telegram_api::messagePeerVote>(peer_vote);
        if (voter->option_ != poll->options_[option_id].data_) {
          continue;
        }

        dialog_id = DialogId(voter->peer_);
        break;
      }
      case telegram_api::messagePeerVoteInputOption::ID: {
        auto voter = telegram_api::move_object_as<telegram_api::messagePeerVoteInputOption>(peer_vote);
        dialog_id = DialogId(voter->peer_);
        break;
      }
      case telegram_api::messagePeerVoteMultiple::ID: {
        auto voter = telegram_api::move_object_as<telegram_api::messagePeerVoteMultiple>(peer_vote);
        if (!td::contains(voter->options_, poll->options_[option_id].data_)) {
          continue;
        }

        dialog_id = DialogId(voter->peer_);
        break;
      }
      default:
        UNREACHABLE();
    }
    if (dialog_id.is_valid()) {
      dialog_ids.push_back(dialog_id);
    } else {
      LOG(ERROR) << "Receive " << dialog_id << " as voter in " << poll_id;
    }
  }
  append(voters.voter_dialog_ids_, dialog_ids);
  if (static_cast<int32>(dialog_ids.size()) > limit) {
    dialog_ids.resize(limit);
  }
  auto known_voter_count = narrow_cast<int32>(voters.voter_dialog_ids_.size());
  if (voters.next_offset_.empty() && known_voter_count != vote_list->count_) {
    // invalidate_poll_option_voters(poll, poll_id, option_id);
    voters.was_invalidated_ = true;
  }

  for (auto &promise : promises) {
    promise.set_value(get_poll_voters_object(max(vote_list->count_, known_voter_count), vector<DialogId>(dialog_ids)));
  }
}

void PollManager::stop_poll(PollId poll_id, MessageFullId message_full_id, unique_ptr<ReplyMarkup> &&reply_markup,
                            Promise<Unit> &&promise) {
  if (is_local_poll_id(poll_id)) {
    LOG(ERROR) << "Receive local " << poll_id << " from " << message_full_id << " in stop_poll";
    stop_local_poll(poll_id);
    promise.set_value(Unit());
    return;
  }
  auto poll = get_poll_editable(poll_id);
  CHECK(poll != nullptr);
  if (poll->is_closed_) {
    promise.set_value(Unit());
    return;
  }

  ++current_generation_;

  poll->is_closed_ = true;
  save_poll(poll, poll_id);
  notify_on_poll_update(poll_id);

  do_stop_poll(poll_id, message_full_id, std::move(reply_markup), 0, std::move(promise));
}

class PollManager::StopPollLogEvent {
 public:
  PollId poll_id_;
  MessageFullId message_full_id_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(poll_id_, storer);
    td::store(message_full_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(poll_id_, parser);
    td::parse(message_full_id_, parser);
  }
};

void PollManager::do_stop_poll(PollId poll_id, MessageFullId message_full_id, unique_ptr<ReplyMarkup> &&reply_markup,
                               uint64 log_event_id, Promise<Unit> &&promise) {
  LOG(INFO) << "Stop " << poll_id << " from " << message_full_id;
  CHECK(poll_id.is_valid());

  if (log_event_id == 0 && G()->use_message_database() && reply_markup == nullptr) {
    StopPollLogEvent log_event{poll_id, message_full_id};
    log_event_id =
        binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::StopPoll, get_log_event_storer(log_event));
  }

  unload_poll_timeout_.cancel_timeout(poll_id.get());

  bool is_inserted = being_closed_polls_.insert(poll_id).second;
  CHECK(is_inserted);
  auto new_promise = PromiseCreator::lambda([actor_id = actor_id(this), poll_id, message_full_id, log_event_id,
                                             promise = std::move(promise)](Result<Unit> result) mutable {
    send_closure(actor_id, &PollManager::on_stop_poll_finished, poll_id, message_full_id, log_event_id,
                 std::move(result), std::move(promise));
  });

  td_->create_handler<StopPollQuery>(std::move(new_promise))->send(message_full_id, std::move(reply_markup), poll_id);
}

void PollManager::on_stop_poll_finished(PollId poll_id, MessageFullId message_full_id, uint64 log_event_id,
                                        Result<Unit> &&result, Promise<Unit> &&promise) {
  being_closed_polls_.erase(poll_id);

  if (log_event_id != 0 && !G()->close_flag()) {
    binlog_erase(G()->td_db()->get_binlog(), log_event_id);
  }

  if (td_->auth_manager_->is_bot()) {
    if ((server_poll_messages_.count(poll_id) > 0 && server_poll_messages_[poll_id].count(message_full_id) > 0) ||
        (other_poll_messages_.count(poll_id) > 0 && other_poll_messages_[poll_id].count(message_full_id) > 0)) {
      td_->messages_manager_->on_external_update_message_content(message_full_id, "on_stop_poll_finished");
    }
  }

  promise.set_result(std::move(result));
}

void PollManager::stop_local_poll(PollId poll_id) {
  CHECK(is_local_poll_id(poll_id));
  auto poll = get_poll_editable(poll_id);
  CHECK(poll != nullptr);
  if (poll->is_closed_) {
    return;
  }

  poll->is_closed_ = true;
  notify_on_poll_update(poll_id);
}

double PollManager::get_polling_timeout() const {
  double result = td_->online_manager_->is_online() ? 60 : 30 * 60;
  return result * Random::fast(70, 100) * 0.01;
}

void PollManager::on_update_poll_timeout(PollId poll_id) {
  if (G()->close_flag()) {
    return;
  }
  CHECK(!td_->auth_manager_->is_bot());
  CHECK(!is_local_poll_id(poll_id));

  auto poll = get_poll(poll_id);
  if (poll == nullptr || (poll->is_closed_ && poll->is_updated_after_close_)) {
    return;
  }
  if (pending_answers_.count(poll_id) > 0) {
    LOG(INFO) << "Skip fetching results of " << poll_id << ", because it is being voted now";
    return;
  }

  if (server_poll_messages_.count(poll_id) == 0) {
    return;
  }

  auto message_full_id = server_poll_messages_[poll_id].get_random();
  LOG(INFO) << "Fetching results of " << poll_id << " from " << message_full_id;
  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), poll_id, generation = current_generation_](
                                                  Result<tl_object_ptr<telegram_api::Updates>> &&result) {
    send_closure(actor_id, &PollManager::on_get_poll_results, poll_id, generation, std::move(result));
  });
  td_->create_handler<GetPollResultsQuery>(std::move(query_promise))->send(poll_id, message_full_id);
}

void PollManager::on_close_poll_timeout(PollId poll_id) {
  if (G()->close_flag()) {
    return;
  }
  CHECK(!is_local_poll_id(poll_id));

  auto poll = get_poll_editable(poll_id);
  if (poll == nullptr || poll->is_closed_ || poll->close_date_ == 0) {
    return;
  }

  LOG(INFO) << "Trying to close " << poll_id << " by timer";
  if (poll->close_date_ <= G()->server_time()) {
    poll->is_closed_ = true;
    save_poll(poll, poll_id);
    notify_on_poll_update(poll_id);

    // don't send updatePoll for bots, because there is no way to guarantee it

    if (!td_->auth_manager_->is_bot()) {
      update_poll_timeout_.set_timeout_in(poll_id.get(), 1.0);
    }
  } else {
    close_poll_timeout_.set_timeout_in(poll_id.get(), poll->close_date_ - G()->server_time() + 1e-3);
  }
}

void PollManager::on_unload_poll_timeout(PollId poll_id) {
  if (G()->close_flag()) {
    return;
  }
  if (is_local_poll_id(poll_id)) {
    LOG(INFO) << "Forget " << poll_id;

    auto is_deleted = polls_.erase(poll_id) > 0;
    CHECK(is_deleted);

    CHECK(poll_voters_.count(poll_id) == 0);
    CHECK(loaded_from_database_polls_.count(poll_id) == 0);
    return;
  }

  if (!can_unload_poll(poll_id)) {
    return;
  }
  if (!have_poll(poll_id)) {
    return;
  }

  LOG(INFO) << "Unload " << poll_id;

  update_poll_timeout_.cancel_timeout(poll_id.get(), "on_unload_poll_timeout");
  close_poll_timeout_.cancel_timeout(poll_id.get());

  auto is_deleted = polls_.erase(poll_id) > 0;
  CHECK(is_deleted);

  poll_voters_.erase(poll_id);
  loaded_from_database_polls_.erase(poll_id);
  unload_poll_timeout_.cancel_timeout(poll_id.get());
}

void PollManager::forget_local_poll(PollId poll_id) {
  if (G()->close_flag()) {
    return;
  }
  CHECK(is_local_poll_id(poll_id));
  unload_poll_timeout_.set_timeout_in(poll_id.get(), UNLOAD_POLL_DELAY);
}

void PollManager::on_get_poll_results(PollId poll_id, uint64 generation,
                                      Result<tl_object_ptr<telegram_api::Updates>> result) {
  G()->ignore_result_if_closing(result);

  auto poll = get_poll(poll_id);
  if (poll == nullptr) {
    return;
  }
  if (result.is_error()) {
    if (!(poll->is_closed_ && poll->is_updated_after_close_) && !G()->close_flag() && !td_->auth_manager_->is_bot()) {
      auto timeout = get_polling_timeout();
      LOG(INFO) << "Schedule updating of " << poll_id << " in " << timeout;
      update_poll_timeout_.add_timeout_in(poll_id.get(), timeout);
    }
    return;
  }
  if (result.ok() == nullptr) {
    return;
  }
  if (generation != current_generation_) {
    LOG(INFO) << "Receive possibly outdated result of " << poll_id << ", reget it";
    if (!(poll->is_closed_ && poll->is_updated_after_close_) && !G()->close_flag() && !td_->auth_manager_->is_bot()) {
      update_poll_timeout_.set_timeout_in(poll_id.get(), 0.0);
    }
    return;
  }

  td_->updates_manager_->on_get_updates(result.move_as_ok(), Promise<Unit>());
}

void PollManager::on_online() {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  server_poll_messages_.foreach([&](const PollId &poll_id, WaitFreeHashSet<MessageFullId, MessageFullIdHash> &) {
    if (update_poll_timeout_.has_timeout(poll_id.get())) {
      auto timeout = Random::fast(3, 30);
      LOG(INFO) << "Schedule updating of " << poll_id << " in " << timeout;
      update_poll_timeout_.set_timeout_in(poll_id.get(), timeout);
    }
  });
}

PollId PollManager::dup_poll(DialogId dialog_id, PollId poll_id) {
  auto poll = get_poll(poll_id);
  CHECK(poll != nullptr);

  auto question = poll->question_;
  ::td::remove_unallowed_entities(td_, question, dialog_id);
  auto options = transform(poll->options_, [](auto &option) { return option.text_; });
  for (auto &option : options) {
    ::td::remove_unallowed_entities(td_, option, dialog_id);
  }
  auto explanation = poll->explanation_;
  ::td::remove_unallowed_entities(td_, explanation, dialog_id);
  return create_poll(std::move(question), std::move(options), poll->is_anonymous_, poll->allow_multiple_answers_,
                     poll->is_quiz_, poll->correct_option_id_, std::move(explanation), poll->open_period_,
                     poll->open_period_ == 0 ? 0 : G()->unix_time(), false);
}

bool PollManager::has_input_media(PollId poll_id) const {
  auto poll = get_poll(poll_id);
  CHECK(poll != nullptr);
  return !poll->is_quiz_ || poll->correct_option_id_ >= 0;
}

tl_object_ptr<telegram_api::InputMedia> PollManager::get_input_media(PollId poll_id) const {
  auto poll = get_poll(poll_id);
  CHECK(poll != nullptr);

  int32 poll_flags = 0;
  if (!poll->is_anonymous_) {
    poll_flags |= telegram_api::poll::PUBLIC_VOTERS_MASK;
  }
  if (poll->allow_multiple_answers_) {
    poll_flags |= telegram_api::poll::MULTIPLE_CHOICE_MASK;
  }
  if (poll->is_quiz_) {
    poll_flags |= telegram_api::poll::QUIZ_MASK;
  }
  if (poll->open_period_ != 0) {
    poll_flags |= telegram_api::poll::CLOSE_PERIOD_MASK;
  }
  if (poll->close_date_ != 0) {
    poll_flags |= telegram_api::poll::CLOSE_DATE_MASK;
  }
  if (poll->is_closed_) {
    poll_flags |= telegram_api::poll::CLOSED_MASK;
  }

  int32 flags = 0;
  vector<BufferSlice> correct_answers;
  if (poll->is_quiz_) {
    flags |= telegram_api::inputMediaPoll::CORRECT_ANSWERS_MASK;
    CHECK(poll->correct_option_id_ >= 0);
    CHECK(static_cast<size_t>(poll->correct_option_id_) < poll->options_.size());
    correct_answers.push_back(BufferSlice(poll->options_[poll->correct_option_id_].data_));

    if (!poll->explanation_.text.empty()) {
      flags |= telegram_api::inputMediaPoll::SOLUTION_MASK;
    }
  }
  return telegram_api::make_object<telegram_api::inputMediaPoll>(
      flags,
      telegram_api::make_object<telegram_api::poll>(
          0, poll_flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
          get_input_text_with_entities(nullptr, poll->question_, "get_input_media_poll"),
          transform(poll->options_, get_input_poll_option), poll->open_period_, poll->close_date_),
      std::move(correct_answers), poll->explanation_.text,
      get_input_message_entities(td_->user_manager_.get(), poll->explanation_.entities, "get_input_media_poll"));
}

vector<PollManager::PollOption> PollManager::get_poll_options(
    vector<telegram_api::object_ptr<telegram_api::pollAnswer>> &&poll_options) {
  return transform(std::move(poll_options), [](telegram_api::object_ptr<telegram_api::pollAnswer> &&poll_option) {
    PollOption option;
    option.text_ = get_formatted_text(nullptr, std::move(poll_option->text_), true, true, "get_poll_options");
    remove_unallowed_entities(option.text_);
    option.data_ = poll_option->option_.as_slice().str();
    return option;
  });
}

PollId PollManager::on_get_poll(PollId poll_id, tl_object_ptr<telegram_api::poll> &&poll_server,
                                tl_object_ptr<telegram_api::pollResults> &&poll_results, const char *source) {
  bool is_bot = td_->auth_manager_->is_bot();
  bool need_update_poll = poll_id.is_valid() && is_bot;
  if (!poll_id.is_valid() && poll_server != nullptr) {
    poll_id = PollId(poll_server->id_);
  }
  if (!poll_id.is_valid() || is_local_poll_id(poll_id)) {
    LOG(ERROR) << "Receive " << poll_id << " from " << source << ": " << oneline(to_string(poll_server)) << " "
               << oneline(to_string(poll_results));
    return PollId();
  }
  if (poll_server != nullptr && poll_server->id_ != poll_id.get()) {
    LOG(ERROR) << "Receive poll " << poll_server->id_ << " instead of " << poll_id << " from " << source;
    return PollId();
  }
  constexpr size_t MAX_POLL_OPTIONS = 10;  // server-side limit
  if (poll_server != nullptr &&
      (poll_server->answers_.size() <= 1 || poll_server->answers_.size() > 10 * MAX_POLL_OPTIONS)) {
    LOG(ERROR) << "Receive " << poll_id << " from " << source
               << " with wrong number of answers: " << to_string(poll_server);
    return PollId();
  }
  if (poll_server != nullptr) {
    FlatHashSet<Slice, SliceHash> option_data;
    for (auto &answer : poll_server->answers_) {
      if (answer->option_.empty()) {
        LOG(ERROR) << "Receive " << poll_id << " from " << source
                   << " with an empty option data: " << to_string(poll_server);
        return PollId();
      }
      option_data.insert(answer->option_.as_slice());
    }
    if (option_data.size() != poll_server->answers_.size()) {
      LOG(ERROR) << "Receive " << poll_id << " from " << source
                 << " with duplicate options: " << to_string(poll_server);
      return PollId();
    }
  }

  auto poll = get_poll_force(poll_id);
  bool is_changed = false;
  bool need_save_to_database = false;
  if (poll == nullptr) {
    if (poll_server == nullptr) {
      LOG(INFO) << "Ignore " << poll_id << ", because have no data about it";
      return PollId();
    }

    auto p = make_unique<Poll>();
    poll = p.get();
    polls_.set(poll_id, std::move(p));
  } else if (poll_results != nullptr && poll_results->min_ && pending_answers_.count(poll_id) != 0) {
    LOG(INFO) << "Ignore being answered min-" << poll_id;
    return poll_id;
  }

  CHECK(poll != nullptr);

  bool poll_server_is_closed = false;
  if (poll_server != nullptr) {
    string correct_option_data;
    if (poll->correct_option_id_ != -1) {
      CHECK(0 <= poll->correct_option_id_ && poll->correct_option_id_ < static_cast<int32>(poll->options_.size()));
      correct_option_data = poll->options_[poll->correct_option_id_].data_;
    }
    bool are_options_changed = false;
    if (poll->options_.size() != poll_server->answers_.size()) {
      poll->options_ = get_poll_options(std::move(poll_server->answers_));
      are_options_changed = true;
    } else {
      auto options = get_poll_options(std::move(poll_server->answers_));
      for (size_t i = 0; i < options.size(); i++) {
        if (poll->options_[i].text_ != options[i].text_) {
          poll->options_[i].text_ = std::move(options[i].text_);
          is_changed = true;
        }
        if (poll->options_[i].data_ != options[i].data_) {
          poll->options_[i].data_ = std::move(options[i].data_);
          poll->options_[i].voter_count_ = 0;
          poll->options_[i].is_chosen_ = false;
          are_options_changed = true;
        }
      }
    }
    if (are_options_changed) {
      if (!correct_option_data.empty()) {
        poll->correct_option_id_ = -1;
        for (size_t i = 0; i < poll->options_.size(); i++) {
          if (poll->options_[i].data_ == correct_option_data) {
            poll->correct_option_id_ = static_cast<int32>(i);
            break;
          }
        }
      }
      auto it = poll_voters_.find(poll_id);
      if (it != poll_voters_.end()) {
        for (auto &voters : it->second) {
          fail_promises(voters.pending_queries_, Status::Error(500, "The poll was changed"));
        }
        poll_voters_.erase(it);
      }
      is_changed = true;
    }
    auto question = get_formatted_text(nullptr, std::move(poll_server->question_), true, true, "on_get_poll");
    remove_unallowed_entities(question);
    if (poll->question_ != question) {
      poll->question_ = std::move(question);
      is_changed = true;
    }
    poll_server_is_closed = (poll_server->flags_ & telegram_api::poll::CLOSED_MASK) != 0;
    if (poll_server_is_closed && !poll->is_closed_) {
      poll->is_closed_ = poll_server_is_closed;
      is_changed = true;
    }
    if (poll_server_is_closed && !poll->is_updated_after_close_) {
      poll->is_updated_after_close_ = true;
      is_changed = true;
    }
    int32 open_period = poll_server->close_period_;
    int32 close_date = poll_server->close_date_;
    if (close_date == 0 || open_period == 0) {
      close_date = 0;
      open_period = 0;
    }
    if (open_period != poll->open_period_) {
      poll->open_period_ = open_period;
      if (!poll->is_closed_) {
        is_changed = true;
      } else {
        need_save_to_database = true;
      }
    }
    if (close_date != poll->close_date_) {
      poll->close_date_ = close_date;
      if (!poll->is_closed_) {
        is_changed = true;
        if (close_date != 0) {
          if (close_date <= G()->server_time()) {
            poll->is_closed_ = true;
          } else if (!G()->close_flag()) {
            close_poll_timeout_.set_timeout_in(poll_id.get(), close_date - G()->server_time() + 1e-3);
          }
        } else if (!G()->close_flag()) {
          close_poll_timeout_.cancel_timeout(poll_id.get());
        }
      } else {
        need_save_to_database = true;
      }
    }
    bool is_anonymous = (poll_server->flags_ & telegram_api::poll::PUBLIC_VOTERS_MASK) == 0;
    if (is_anonymous != poll->is_anonymous_) {
      poll->is_anonymous_ = is_anonymous;
      is_changed = true;
    }
    bool allow_multiple_answers = (poll_server->flags_ & telegram_api::poll::MULTIPLE_CHOICE_MASK) != 0;
    bool is_quiz = (poll_server->flags_ & telegram_api::poll::QUIZ_MASK) != 0;
    if (is_quiz && allow_multiple_answers) {
      LOG(ERROR) << "Receive quiz " << poll_id << " from " << source << " allowing multiple answers";
      allow_multiple_answers = false;
    }
    if (allow_multiple_answers != poll->allow_multiple_answers_) {
      poll->allow_multiple_answers_ = allow_multiple_answers;
      is_changed = true;
    }
    if (is_quiz != poll->is_quiz_) {
      poll->is_quiz_ = is_quiz;
      is_changed = true;
    }
  }

  CHECK(poll_results != nullptr);
  bool is_min = poll_results->min_;
  bool has_total_voters = (poll_results->flags_ & telegram_api::pollResults::TOTAL_VOTERS_MASK) != 0;
  if (has_total_voters && poll_results->total_voters_ != poll->total_voter_count_) {
    poll->total_voter_count_ = poll_results->total_voters_;
    if (poll->total_voter_count_ < 0) {
      LOG(ERROR) << "Receive " << poll->total_voter_count_ << " voters in " << poll_id << " from " << source;
      poll->total_voter_count_ = 0;
    }
    is_changed = true;
  }
  int32 correct_option_id = -1;
  for (auto &poll_result : poll_results->results_) {
    Slice data = poll_result->option_.as_slice();
    for (size_t option_index = 0; option_index < poll->options_.size(); option_index++) {
      auto &option = poll->options_[option_index];
      if (option.data_ != data) {
        continue;
      }
      if (!is_min) {
        bool is_chosen = poll_result->chosen_;
        if (is_chosen != option.is_chosen_) {
          option.is_chosen_ = is_chosen;
          is_changed = true;
        }
      }
      if (!is_min || poll_server_is_closed) {
        bool is_correct = poll_result->correct_;
        if (is_correct) {
          if (correct_option_id != -1) {
            LOG(ERROR) << "Receive more than 1 correct answers " << correct_option_id << " and " << option_index
                       << " in " << poll_id << " from " << source;
          }
          correct_option_id = static_cast<int32>(option_index);
        }
      } else {
        correct_option_id = poll->correct_option_id_;
      }

      if (poll_result->voters_ < 0) {
        LOG(ERROR) << "Receive " << poll_result->voters_ << " voters for an option in " << poll_id << " from "
                   << source;
        poll_result->voters_ = 0;
      }
      if (option.is_chosen_ && poll_result->voters_ == 0) {
        LOG(ERROR) << "Receive 0 voters for the chosen option " << option_index << " in " << poll_id << " from "
                   << source;
        poll_result->voters_ = 1;
      }
      if (poll_result->voters_ > poll->total_voter_count_) {
        LOG(ERROR) << "Have only " << poll->total_voter_count_ << " poll voters, but there are " << poll_result->voters_
                   << " voters for an option in " << poll_id << " from " << source;
        poll->total_voter_count_ = poll_result->voters_;
      }
      auto max_voter_count = std::numeric_limits<int32>::max() / narrow_cast<int32>(poll->options_.size()) - 2;
      if (poll_result->voters_ > max_voter_count) {
        LOG(ERROR) << "Have too many " << poll_result->voters_ << " poll voters for an option in " << poll_id
                   << " from " << source;
        poll_result->voters_ = max_voter_count;
      }
      if (poll_result->voters_ != option.voter_count_) {
        invalidate_poll_option_voters(poll, poll_id, option_index);
        option.voter_count_ = poll_result->voters_;
        is_changed = true;
      }
    }
  }
  if (!poll_results->results_.empty() && has_total_voters) {
    int32 max_total_voter_count = 0;
    for (auto &option : poll->options_) {
      max_total_voter_count += option.voter_count_;
    }
    if (poll->total_voter_count_ > max_total_voter_count && max_total_voter_count != 0) {
      LOG(ERROR) << "Have only " << max_total_voter_count << " total poll voters, but there are "
                 << poll->total_voter_count_ << " voters in " << poll_id << " from " << source;
      poll->total_voter_count_ = max_total_voter_count;
    }
  }

  auto explanation = get_formatted_text(td_->user_manager_.get(), std::move(poll_results->solution_),
                                        std::move(poll_results->solution_entities_), true, false, source);
  if (poll->is_quiz_) {
    if (poll->correct_option_id_ != correct_option_id) {
      if (correct_option_id == -1 && poll->correct_option_id_ != -1) {
        LOG(ERROR) << "Can't change correct option of " << poll_id << " from " << poll->correct_option_id_ << " to "
                   << correct_option_id << " from " << source;
      } else {
        poll->correct_option_id_ = correct_option_id;
        is_changed = true;
      }
    }
    if (poll->explanation_ != explanation && (!is_min || poll_server_is_closed)) {
      if (explanation.text.empty() && !poll->explanation_.text.empty()) {
        LOG(ERROR) << "Can't change known " << poll_id << " explanation to empty from " << source;
      } else {
        poll->explanation_ = std::move(explanation);
        is_changed = true;
      }
    }
  } else {
    if (correct_option_id != -1) {
      LOG(ERROR) << "Receive correct option " << correct_option_id << " in non-quiz " << poll_id << " from " << source;
    }
    if (!explanation.text.empty()) {
      LOG(ERROR) << "Receive explanation " << explanation << " in non-quiz " << poll_id << " from " << source;
    }
  }

  vector<DialogId> recent_voter_dialog_ids;
  if (!is_bot) {
    for (auto &peer_id : poll_results->recent_voters_) {
      DialogId dialog_id(peer_id);
      if (dialog_id.is_valid()) {
        recent_voter_dialog_ids.push_back(dialog_id);
      } else {
        LOG(ERROR) << "Receive " << dialog_id << " as recent voter in " << poll_id << " from " << source;
      }
    }
  }
  if (poll->is_anonymous_ && !recent_voter_dialog_ids.empty()) {
    LOG(ERROR) << "Receive anonymous " << poll_id << " with recent voters " << recent_voter_dialog_ids << " from "
               << source;
    recent_voter_dialog_ids.clear();
  }
  if (recent_voter_dialog_ids != poll->recent_voter_dialog_ids_) {
    poll->recent_voter_dialog_ids_ = std::move(recent_voter_dialog_ids);
    invalidate_poll_voters(poll, poll_id);
    is_changed = true;
  }

  if (!is_bot && !poll->is_closed_ && !G()->close_flag()) {
    auto timeout = get_polling_timeout();
    LOG(INFO) << "Schedule updating of " << poll_id << " in " << timeout;
    update_poll_timeout_.set_timeout_in(poll_id.get(), timeout);
  }
  if (is_changed || need_save_to_database) {
    save_poll(poll, poll_id);
  }
  if (is_changed) {
    notify_on_poll_update(poll_id);
  }
  if (need_update_poll && (is_changed || (poll->is_closed_ && being_closed_polls_.erase(poll_id) != 0))) {
    send_closure(G()->td(), &Td::send_update, td_api::make_object<td_api::updatePoll>(get_poll_object(poll_id, poll)));

    schedule_poll_unload(poll_id);
  }
  return poll_id;
}

void PollManager::on_get_poll_vote(PollId poll_id, DialogId dialog_id, vector<BufferSlice> &&options) {
  if (!poll_id.is_valid()) {
    LOG(ERROR) << "Receive updateMessagePollVote about invalid " << poll_id;
    return;
  }
  if (!dialog_id.is_valid()) {
    LOG(ERROR) << "Receive updateMessagePollVote from invalid " << dialog_id;
    return;
  }
  CHECK(td_->auth_manager_->is_bot());

  vector<int32> option_ids;
  for (auto &option : options) {
    auto slice = option.as_slice();
    if (slice.size() != 1 || slice[0] < '0' || slice[0] > '9') {
      LOG(INFO) << "Receive updateMessagePollVote with unexpected option \"" << format::escaped(slice) << '"';
      return;
    }
    option_ids.push_back(static_cast<int32>(slice[0] - '0'));
  }

  send_closure(
      G()->td(), &Td::send_update,
      td_api::make_object<td_api::updatePollAnswer>(
          poll_id.get(), get_message_sender_object(td_, dialog_id, "on_get_poll_vote"), std::move(option_ids)));
}

void PollManager::on_binlog_events(vector<BinlogEvent> &&events) {
  if (G()->close_flag()) {
    return;
  }
  bool have_old_message_database = G()->use_message_database() && !G()->td_db()->was_dialog_db_created();
  for (auto &event : events) {
    switch (event.type_) {
      case LogEvent::HandlerType::SetPollAnswer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        SetPollAnswerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.message_full_id_.get_dialog_id();

        Dependencies dependencies;
        dependencies.add_dialog_dependencies(dialog_id);  // do not load the dialog itself
        dependencies.resolve_force(td_, "SetPollAnswerLogEvent");

        do_set_poll_answer(log_event.poll_id_, log_event.message_full_id_, std::move(log_event.options_), event.id_,
                           Auto());
        break;
      }
      case LogEvent::HandlerType::StopPoll: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        StopPollLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.message_full_id_.get_dialog_id();

        Dependencies dependencies;
        dependencies.add_dialog_dependencies(dialog_id);  // do not load the dialog itself
        dependencies.resolve_force(td_, "StopPollLogEvent");

        do_stop_poll(log_event.poll_id_, log_event.message_full_id_, nullptr, event.id_, Auto());
        break;
      }
      default:
        LOG(FATAL) << "Unsupported log event type " << event.type_;
    }
  }
}

}  // namespace td
