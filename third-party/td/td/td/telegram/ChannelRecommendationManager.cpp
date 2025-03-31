//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ChannelRecommendationManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/Application.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"

#include "td/db/SqliteKeyValueAsync.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"

namespace td {

class GetChannelRecommendationsQuery final : public Td::ResultHandler {
  Promise<std::pair<int32, vector<tl_object_ptr<telegram_api::Chat>>>> promise_;
  ChannelId channel_id_;

 public:
  explicit GetChannelRecommendationsQuery(
      Promise<std::pair<int32, vector<tl_object_ptr<telegram_api::Chat>>>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id) {
    channel_id_ = channel_id;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(!channel_id.is_valid() || input_channel != nullptr);
    int32 flags = 0;
    if (input_channel != nullptr) {
      flags |= telegram_api::channels_getChannelRecommendations::CHANNEL_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::channels_getChannelRecommendations(flags, std::move(input_channel))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_getChannelRecommendations>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto chats_ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetChannelRecommendationsQuery: " << to_string(chats_ptr);
    switch (chats_ptr->get_id()) {
      case telegram_api::messages_chats::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chats>(chats_ptr);
        auto total_count = static_cast<int32>(chats->chats_.size());
        return promise_.set_value({total_count, std::move(chats->chats_)});
      }
      case telegram_api::messages_chatsSlice::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chatsSlice>(chats_ptr);
        return promise_.set_value({chats->count_, std::move(chats->chats_)});
      }
      default:
        UNREACHABLE();
        return promise_.set_error(Status::Error("Unreachable"));
    }
  }

  void on_error(Status status) final {
    if (channel_id_.is_valid()) {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "GetChannelRecommendationsQuery");
    }
    promise_.set_error(std::move(status));
  }
};

template <class StorerT>
void ChannelRecommendationManager::RecommendedDialogs::store(StorerT &storer) const {
  bool has_dialog_ids = !dialog_ids_.empty();
  bool has_total_count = static_cast<size_t>(total_count_) != dialog_ids_.size();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_dialog_ids);
  STORE_FLAG(has_total_count);
  END_STORE_FLAGS();
  if (has_dialog_ids) {
    td::store(dialog_ids_, storer);
  }
  store_time(next_reload_time_, storer);
  if (has_total_count) {
    td::store(total_count_, storer);
  }
}

template <class ParserT>
void ChannelRecommendationManager::RecommendedDialogs::parse(ParserT &parser) {
  bool has_dialog_ids;
  bool has_total_count;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_dialog_ids);
  PARSE_FLAG(has_total_count);
  END_PARSE_FLAGS();
  if (has_dialog_ids) {
    td::parse(dialog_ids_, parser);
  }
  parse_time(next_reload_time_, parser);
  if (has_total_count) {
    td::parse(total_count_, parser);
  } else {
    total_count_ = static_cast<int32>(dialog_ids_.size());
  }
}

ChannelRecommendationManager::ChannelRecommendationManager(Td *td, ActorShared<> parent)
    : td_(td), parent_(std::move(parent)) {
  if (G()->use_sqlite_pmc() && !G()->use_message_database()) {
    G()->td_db()->get_sqlite_pmc()->erase_by_prefix("channel_recommendations", Auto());
  }
}

void ChannelRecommendationManager::tear_down() {
  parent_.reset();
}

bool ChannelRecommendationManager::is_suitable_recommended_channel(DialogId dialog_id) const {
  if (dialog_id.get_type() != DialogType::Channel) {
    return false;
  }
  return is_suitable_recommended_channel(dialog_id.get_channel_id());
}

bool ChannelRecommendationManager::is_suitable_recommended_channel(ChannelId channel_id) const {
  auto status = td_->chat_manager_->get_channel_status(channel_id);
  return !status.is_member() && td_->chat_manager_->have_input_peer_channel(channel_id, AccessRights::Read);
}

bool ChannelRecommendationManager::are_suitable_recommended_dialogs(
    const RecommendedDialogs &recommended_dialogs) const {
  for (auto recommended_dialog_id : recommended_dialogs.dialog_ids_) {
    if (!is_suitable_recommended_channel(recommended_dialog_id)) {
      return false;
    }
  }
  auto is_premium = td_->option_manager_->get_option_boolean("is_premium");
  auto have_all = recommended_dialogs.dialog_ids_.size() == static_cast<size_t>(recommended_dialogs.total_count_);
  if (!have_all && is_premium) {
    return false;
  }
  return true;
}

void ChannelRecommendationManager::get_recommended_channels(Promise<td_api::object_ptr<td_api::chats>> &&promise) {
  bool use_database = true;
  if (are_recommended_channels_inited_) {
    if (are_suitable_recommended_dialogs(recommended_channels_)) {
      auto next_reload_time = recommended_channels_.next_reload_time_;
      promise.set_value(td_->dialog_manager_->get_chats_object(
          recommended_channels_.total_count_, recommended_channels_.dialog_ids_, "get_recommended_channels"));
      if (next_reload_time > Time::now()) {
        return;
      }
      promise = {};
    } else {
      LOG(INFO) << "Drop cache for recommended chats";
      are_recommended_channels_inited_ = false;
      if (G()->use_message_database()) {
        G()->td_db()->get_sqlite_pmc()->erase(get_recommended_channels_database_key(), Auto());
      }
    }
    use_database = false;
  }
  load_recommended_channels(use_database, std::move(promise));
}

string ChannelRecommendationManager::get_recommended_channels_database_key() {
  return "recommended_channels";
}

void ChannelRecommendationManager::load_recommended_channels(bool use_database,
                                                             Promise<td_api::object_ptr<td_api::chats>> &&promise) {
  get_recommended_channels_queries_.push_back(std::move(promise));
  if (get_recommended_channels_queries_.size() == 1) {
    if (G()->use_message_database() && use_database) {
      G()->td_db()->get_sqlite_pmc()->get(
          get_recommended_channels_database_key(), PromiseCreator::lambda([actor_id = actor_id(this)](string value) {
            send_closure(actor_id, &ChannelRecommendationManager::on_load_recommended_channels_from_database,
                         std::move(value));
          }));
    } else {
      reload_recommended_channels();
    }
  }
}

void ChannelRecommendationManager::fail_load_recommended_channels_queries(Status &&error) {
  CHECK(!get_recommended_channels_queries_.empty());
  fail_promises(get_recommended_channels_queries_, std::move(error));
}

void ChannelRecommendationManager::finish_load_recommended_channels_queries(int32 total_count,
                                                                            vector<DialogId> dialog_ids) {
  are_recommended_channels_inited_ = true;
  auto promises = std::move(get_recommended_channels_queries_);
  CHECK(!promises.empty());
  for (auto &promise : promises) {
    if (promise) {
      promise.set_value(
          td_->dialog_manager_->get_chats_object(total_count, dialog_ids, "finish_load_recommended_channels_queries"));
    }
  }
}

void ChannelRecommendationManager::on_load_recommended_channels_from_database(string value) {
  if (G()->close_flag()) {
    return fail_load_recommended_channels_queries(G()->close_status());
  }

  if (value.empty()) {
    return reload_recommended_channels();
  }
  if (log_event_parse(recommended_channels_, value).is_error()) {
    recommended_channels_ = {};
    G()->td_db()->get_sqlite_pmc()->erase(get_recommended_channels_database_key(), Auto());
    return reload_recommended_channels();
  }
  Dependencies dependencies;
  for (auto dialog_id : recommended_channels_.dialog_ids_) {
    dependencies.add_dialog_and_dependencies(dialog_id);
  }
  if (!dependencies.resolve_force(td_, "on_load_recommended_channels_from_database") ||
      !are_suitable_recommended_dialogs(recommended_channels_)) {
    recommended_channels_ = {};
    G()->td_db()->get_sqlite_pmc()->erase(get_recommended_channels_database_key(), Auto());
    return reload_recommended_channels();
  }

  auto next_reload_time = recommended_channels_.next_reload_time_;
  finish_load_recommended_channels_queries(recommended_channels_.total_count_, recommended_channels_.dialog_ids_);

  if (next_reload_time <= Time::now()) {
    load_recommended_channels(false, Auto());
  }
}

void ChannelRecommendationManager::reload_recommended_channels() {
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this)](Result<std::pair<int32, vector<tl_object_ptr<telegram_api::Chat>>>> &&result) {
        send_closure(actor_id, &ChannelRecommendationManager::on_get_recommended_channels, std::move(result));
      });
  td_->create_handler<GetChannelRecommendationsQuery>(std::move(query_promise))->send(ChannelId());
}

void ChannelRecommendationManager::on_get_recommended_channels(
    Result<std::pair<int32, vector<tl_object_ptr<telegram_api::Chat>>>> &&r_chats) {
  G()->ignore_result_if_closing(r_chats);

  if (r_chats.is_error()) {
    return fail_load_recommended_channels_queries(r_chats.move_as_error());
  }

  auto chats = r_chats.move_as_ok();
  auto total_count = chats.first;
  auto channel_ids = td_->chat_manager_->get_channel_ids(std::move(chats.second), "on_get_recommended_channels");
  vector<DialogId> dialog_ids;
  if (total_count < static_cast<int32>(channel_ids.size())) {
    LOG(ERROR) << "Receive total_count = " << total_count << " and " << channel_ids.size() << " recommended chats";
    total_count = static_cast<int32>(channel_ids.size());
  }
  for (auto recommended_channel_id : channel_ids) {
    auto recommended_dialog_id = DialogId(recommended_channel_id);
    td_->dialog_manager_->force_create_dialog(recommended_dialog_id, "on_get_recommended_channels");
    if (is_suitable_recommended_channel(recommended_channel_id)) {
      dialog_ids.push_back(recommended_dialog_id);
    } else {
      total_count--;
    }
  }
  recommended_channels_.total_count_ = total_count;
  recommended_channels_.dialog_ids_ = dialog_ids;
  recommended_channels_.next_reload_time_ = Time::now() + CHANNEL_RECOMMENDATIONS_CACHE_TIME;

  if (G()->use_message_database()) {
    G()->td_db()->get_sqlite_pmc()->set(get_recommended_channels_database_key(),
                                        log_event_store(recommended_channels_).as_slice().str(), Promise<Unit>());
  }

  finish_load_recommended_channels_queries(total_count, std::move(dialog_ids));
}

void ChannelRecommendationManager::get_channel_recommendations(
    DialogId dialog_id, bool return_local, Promise<td_api::object_ptr<td_api::chats>> &&chats_promise,
    Promise<td_api::object_ptr<td_api::count>> &&count_promise) {
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "get_channel_recommendations")) {
    if (chats_promise) {
      chats_promise.set_error(Status::Error(400, "Chat not found"));
    }
    if (count_promise) {
      count_promise.set_error(Status::Error(400, "Chat not found"));
    }
    return;
  }
  if (dialog_id.get_type() != DialogType::Channel) {
    if (chats_promise) {
      chats_promise.set_value(td_api::make_object<td_api::chats>());
    }
    if (count_promise) {
      count_promise.set_value(td_api::make_object<td_api::count>(0));
    }
    return;
  }
  auto channel_id = dialog_id.get_channel_id();
  if (!td_->chat_manager_->is_broadcast_channel(channel_id) ||
      td_->chat_manager_->get_input_channel(channel_id) == nullptr) {
    if (chats_promise) {
      chats_promise.set_value(td_api::make_object<td_api::chats>());
    }
    if (count_promise) {
      count_promise.set_value(td_api::make_object<td_api::count>(0));
    }
    return;
  }
  bool use_database = true;
  auto it = channel_recommended_dialogs_.find(channel_id);
  if (it != channel_recommended_dialogs_.end()) {
    if (are_suitable_recommended_dialogs(it->second)) {
      auto next_reload_time = it->second.next_reload_time_;
      if (chats_promise) {
        chats_promise.set_value(td_->dialog_manager_->get_chats_object(it->second.total_count_, it->second.dialog_ids_,
                                                                       "get_channel_recommendations"));
      }
      if (count_promise) {
        count_promise.set_value(td_api::make_object<td_api::count>(it->second.total_count_));
      }
      if (next_reload_time > Time::now()) {
        return;
      }
      chats_promise = {};
      count_promise = {};
    } else {
      LOG(INFO) << "Drop cache for similar chats of " << dialog_id;
      channel_recommended_dialogs_.erase(it);
      if (G()->use_message_database()) {
        G()->td_db()->get_sqlite_pmc()->erase(get_channel_recommendations_database_key(channel_id), Auto());
      }
    }
    use_database = false;
  }
  load_channel_recommendations(channel_id, use_database, return_local, std::move(chats_promise),
                               std::move(count_promise));
}

string ChannelRecommendationManager::get_channel_recommendations_database_key(ChannelId channel_id) {
  return PSTRING() << "channel_recommendations" << channel_id.get();
}

void ChannelRecommendationManager::load_channel_recommendations(
    ChannelId channel_id, bool use_database, bool return_local,
    Promise<td_api::object_ptr<td_api::chats>> &&chats_promise,
    Promise<td_api::object_ptr<td_api::count>> &&count_promise) {
  if (count_promise) {
    get_channel_recommendation_count_queries_[return_local][channel_id].push_back(std::move(count_promise));
  }
  auto &queries = get_channel_recommendations_queries_[channel_id];
  queries.push_back(std::move(chats_promise));
  if (queries.size() == 1) {
    if (G()->use_message_database() && use_database) {
      G()->td_db()->get_sqlite_pmc()->get(
          get_channel_recommendations_database_key(channel_id),
          PromiseCreator::lambda([actor_id = actor_id(this), channel_id](string value) {
            send_closure(actor_id, &ChannelRecommendationManager::on_load_channel_recommendations_from_database,
                         channel_id, std::move(value));
          }));
    } else {
      reload_channel_recommendations(channel_id);
    }
  }
}

void ChannelRecommendationManager::fail_load_channel_recommendations_queries(ChannelId channel_id, Status &&error) {
  for (int return_local = 0; return_local < 2; return_local++) {
    auto it = get_channel_recommendation_count_queries_[return_local].find(channel_id);
    if (it != get_channel_recommendation_count_queries_[return_local].end()) {
      auto promises = std::move(it->second);
      CHECK(!promises.empty());
      get_channel_recommendation_count_queries_[return_local].erase(it);
      fail_promises(promises, error.clone());
    }
  }
  auto it = get_channel_recommendations_queries_.find(channel_id);
  CHECK(it != get_channel_recommendations_queries_.end());
  auto promises = std::move(it->second);
  CHECK(!promises.empty());
  get_channel_recommendations_queries_.erase(it);
  fail_promises(promises, std::move(error));
}

void ChannelRecommendationManager::finish_load_channel_recommendations_queries(ChannelId channel_id, int32 total_count,
                                                                               vector<DialogId> dialog_ids) {
  for (int return_local = 0; return_local < 2; return_local++) {
    auto it = get_channel_recommendation_count_queries_[return_local].find(channel_id);
    if (it != get_channel_recommendation_count_queries_[return_local].end()) {
      auto promises = std::move(it->second);
      CHECK(!promises.empty());
      get_channel_recommendation_count_queries_[return_local].erase(it);
      for (auto &promise : promises) {
        promise.set_value(td_api::make_object<td_api::count>(total_count));
      }
    }
  }
  auto it = get_channel_recommendations_queries_.find(channel_id);
  CHECK(it != get_channel_recommendations_queries_.end());
  auto promises = std::move(it->second);
  CHECK(!promises.empty());
  get_channel_recommendations_queries_.erase(it);
  for (auto &promise : promises) {
    if (promise) {
      promise.set_value(td_->dialog_manager_->get_chats_object(total_count, dialog_ids,
                                                               "finish_load_channel_recommendations_queries"));
    }
  }
}

void ChannelRecommendationManager::on_load_channel_recommendations_from_database(ChannelId channel_id, string value) {
  if (G()->close_flag()) {
    return fail_load_channel_recommendations_queries(channel_id, G()->close_status());
  }

  if (value.empty()) {
    return reload_channel_recommendations(channel_id);
  }
  auto &recommended_dialogs = channel_recommended_dialogs_[channel_id];
  if (log_event_parse(recommended_dialogs, value).is_error()) {
    channel_recommended_dialogs_.erase(channel_id);
    G()->td_db()->get_sqlite_pmc()->erase(get_channel_recommendations_database_key(channel_id), Auto());
    return reload_channel_recommendations(channel_id);
  }
  Dependencies dependencies;
  for (auto dialog_id : recommended_dialogs.dialog_ids_) {
    dependencies.add_dialog_and_dependencies(dialog_id);
  }
  if (!dependencies.resolve_force(td_, "on_load_channel_recommendations_from_database") ||
      !are_suitable_recommended_dialogs(recommended_dialogs)) {
    channel_recommended_dialogs_.erase(channel_id);
    G()->td_db()->get_sqlite_pmc()->erase(get_channel_recommendations_database_key(channel_id), Auto());
    return reload_channel_recommendations(channel_id);
  }

  auto next_reload_time = recommended_dialogs.next_reload_time_;
  finish_load_channel_recommendations_queries(channel_id, recommended_dialogs.total_count_,
                                              recommended_dialogs.dialog_ids_);

  if (next_reload_time <= Time::now()) {
    load_channel_recommendations(channel_id, false, false, Auto(), Auto());
  }
}

void ChannelRecommendationManager::reload_channel_recommendations(ChannelId channel_id) {
  auto it = get_channel_recommendation_count_queries_[1].find(channel_id);
  if (it != get_channel_recommendation_count_queries_[1].end()) {
    auto promises = std::move(it->second);
    CHECK(!promises.empty());
    get_channel_recommendation_count_queries_[1].erase(it);
    for (auto &promise : promises) {
      promise.set_value(td_api::make_object<td_api::count>(-1));
    }
  }
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), channel_id](
                                 Result<std::pair<int32, vector<tl_object_ptr<telegram_api::Chat>>>> &&result) {
        send_closure(actor_id, &ChannelRecommendationManager::on_get_channel_recommendations, channel_id,
                     std::move(result));
      });
  td_->create_handler<GetChannelRecommendationsQuery>(std::move(query_promise))->send(channel_id);
}

void ChannelRecommendationManager::on_get_channel_recommendations(
    ChannelId channel_id, Result<std::pair<int32, vector<tl_object_ptr<telegram_api::Chat>>>> &&r_chats) {
  G()->ignore_result_if_closing(r_chats);

  if (r_chats.is_error()) {
    return fail_load_channel_recommendations_queries(channel_id, r_chats.move_as_error());
  }

  auto chats = r_chats.move_as_ok();
  auto total_count = chats.first;
  auto channel_ids = td_->chat_manager_->get_channel_ids(std::move(chats.second), "on_get_channel_recommendations");
  vector<DialogId> dialog_ids;
  if (total_count < static_cast<int32>(channel_ids.size())) {
    LOG(ERROR) << "Receive total_count = " << total_count << " and " << channel_ids.size() << " similar chats for "
               << channel_id;
    total_count = static_cast<int32>(channel_ids.size());
  }
  for (auto recommended_channel_id : channel_ids) {
    auto recommended_dialog_id = DialogId(recommended_channel_id);
    td_->dialog_manager_->force_create_dialog(recommended_dialog_id, "on_get_channel_recommendations");
    if (is_suitable_recommended_channel(recommended_channel_id)) {
      dialog_ids.push_back(recommended_dialog_id);
    } else {
      total_count--;
    }
  }
  auto &recommended_dialogs = channel_recommended_dialogs_[channel_id];
  recommended_dialogs.total_count_ = total_count;
  recommended_dialogs.dialog_ids_ = dialog_ids;
  recommended_dialogs.next_reload_time_ = Time::now() + CHANNEL_RECOMMENDATIONS_CACHE_TIME;

  if (G()->use_message_database()) {
    G()->td_db()->get_sqlite_pmc()->set(get_channel_recommendations_database_key(channel_id),
                                        log_event_store(recommended_dialogs).as_slice().str(), Promise<Unit>());
  }

  finish_load_channel_recommendations_queries(channel_id, total_count, std::move(dialog_ids));
}

void ChannelRecommendationManager::open_channel_recommended_channel(DialogId dialog_id, DialogId opened_dialog_id,
                                                                    Promise<Unit> &&promise) {
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "open_channel_recommended_channel") ||
      !td_->dialog_manager_->have_dialog_force(opened_dialog_id, "open_channel_recommended_channel")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }
  if (dialog_id.get_type() != DialogType::Channel || opened_dialog_id.get_type() != DialogType::Channel) {
    return promise.set_error(Status::Error(400, "Invalid chat specified"));
  }
  vector<telegram_api::object_ptr<telegram_api::jsonObjectValue>> data;
  data.push_back(telegram_api::make_object<telegram_api::jsonObjectValue>(
      "ref_channel_id", make_tl_object<telegram_api::jsonString>(to_string(dialog_id.get_channel_id().get()))));
  data.push_back(telegram_api::make_object<telegram_api::jsonObjectValue>(
      "open_channel_id", make_tl_object<telegram_api::jsonString>(to_string(opened_dialog_id.get_channel_id().get()))));
  save_app_log(td_, "channels.open_recommended_channel", DialogId(),
               telegram_api::make_object<telegram_api::jsonObject>(std::move(data)), std::move(promise));
}

}  // namespace td
