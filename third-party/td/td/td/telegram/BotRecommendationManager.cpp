//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BotRecommendationManager.h"

#include "td/telegram/Application.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/UserManager.h"

#include "td/db/SqliteKeyValueAsync.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"

namespace td {

class GetBotRecommendationsQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::users_Users>> promise_;
  UserId bot_user_id_;

 public:
  explicit GetBotRecommendationsQuery(Promise<telegram_api::object_ptr<telegram_api::users_Users>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(UserId bot_user_id) {
    bot_user_id_ = bot_user_id;

    auto r_bot_input_user = td_->user_manager_->get_input_user(bot_user_id);
    if (r_bot_input_user.is_error()) {
      return on_error(r_bot_input_user.move_as_error());
    }
    send_query(
        G()->net_query_creator().create(telegram_api::bots_getBotRecommendations(r_bot_input_user.move_as_ok())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_getBotRecommendations>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetBotRecommendationsQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

template <class StorerT>
void BotRecommendationManager::RecommendedBots::store(StorerT &storer) const {
  bool has_bot_user_ids = !bot_user_ids_.empty();
  bool has_total_count = static_cast<size_t>(total_count_) != bot_user_ids_.size();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_bot_user_ids);
  STORE_FLAG(has_total_count);
  END_STORE_FLAGS();
  if (has_bot_user_ids) {
    td::store(bot_user_ids_, storer);
  }
  store_time(next_reload_time_, storer);
  if (has_total_count) {
    td::store(total_count_, storer);
  }
}

template <class ParserT>
void BotRecommendationManager::RecommendedBots::parse(ParserT &parser) {
  bool has_bot_user_ids;
  bool has_total_count;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_bot_user_ids);
  PARSE_FLAG(has_total_count);
  END_PARSE_FLAGS();
  if (has_bot_user_ids) {
    td::parse(bot_user_ids_, parser);
  }
  parse_time(next_reload_time_, parser);
  if (has_total_count) {
    td::parse(total_count_, parser);
  } else {
    total_count_ = static_cast<int32>(bot_user_ids_.size());
  }
}

BotRecommendationManager::BotRecommendationManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void BotRecommendationManager::tear_down() {
  parent_.reset();
}

bool BotRecommendationManager::is_suitable_recommended_bot(UserId bot_user_id) const {
  return td_->user_manager_->is_user_bot(bot_user_id);
}

bool BotRecommendationManager::are_suitable_recommended_bots(const RecommendedBots &recommended_bots) const {
  for (auto recommended_bot_user_id : recommended_bots.bot_user_ids_) {
    if (!is_suitable_recommended_bot(recommended_bot_user_id)) {
      return false;
    }
  }
  auto is_premium = td_->option_manager_->get_option_boolean("is_premium");
  auto have_all = recommended_bots.bot_user_ids_.size() == static_cast<size_t>(recommended_bots.total_count_);
  if (!have_all && is_premium) {
    return false;
  }
  return true;
}

void BotRecommendationManager::get_bot_recommendations(UserId bot_user_id, bool return_local,
                                                       Promise<td_api::object_ptr<td_api::users>> &&users_promise,
                                                       Promise<td_api::object_ptr<td_api::count>> &&count_promise) {
  auto r_bot_input_user = td_->user_manager_->get_input_user(bot_user_id);
  if (r_bot_input_user.is_error()) {
    if (users_promise) {
      users_promise.set_error(r_bot_input_user.error().clone());
    }
    if (count_promise) {
      count_promise.set_error(r_bot_input_user.error().clone());
    }
    return;
  }
  if (!td_->user_manager_->is_user_bot(bot_user_id)) {
    if (users_promise) {
      users_promise.set_error(Status::Error(400, "Bot not found"));
    }
    if (count_promise) {
      count_promise.set_error(Status::Error(400, "Bot not found"));
    }
    return;
  }
  bool use_database = true;
  auto it = bot_recommended_bots_.find(bot_user_id);
  if (it != bot_recommended_bots_.end()) {
    if (are_suitable_recommended_bots(it->second)) {
      auto next_reload_time = it->second.next_reload_time_;
      if (users_promise) {
        users_promise.set_value(
            td_->user_manager_->get_users_object(it->second.total_count_, it->second.bot_user_ids_));
      }
      if (count_promise) {
        count_promise.set_value(td_api::make_object<td_api::count>(it->second.total_count_));
      }
      if (next_reload_time > Time::now()) {
        return;
      }
      users_promise = {};
      count_promise = {};
    } else {
      LOG(INFO) << "Drop cache for similar bots of " << bot_user_id;
      bot_recommended_bots_.erase(it);
      if (G()->use_message_database()) {
        G()->td_db()->get_sqlite_pmc()->erase(get_bot_recommendations_database_key(bot_user_id), Auto());
      }
    }
    use_database = false;
  }
  load_bot_recommendations(bot_user_id, use_database, return_local, std::move(users_promise), std::move(count_promise));
}

string BotRecommendationManager::get_bot_recommendations_database_key(UserId bot_user_id) {
  return PSTRING() << "bot_recommendations" << bot_user_id.get();
}

void BotRecommendationManager::load_bot_recommendations(UserId bot_user_id, bool use_database, bool return_local,
                                                        Promise<td_api::object_ptr<td_api::users>> &&users_promise,
                                                        Promise<td_api::object_ptr<td_api::count>> &&count_promise) {
  if (count_promise) {
    get_bot_recommendation_count_queries_[return_local][bot_user_id].push_back(std::move(count_promise));
  }
  auto &queries = get_bot_recommendations_queries_[bot_user_id];
  queries.push_back(std::move(users_promise));
  if (queries.size() == 1) {
    if (G()->use_message_database() && use_database) {
      G()->td_db()->get_sqlite_pmc()->get(
          get_bot_recommendations_database_key(bot_user_id),
          PromiseCreator::lambda([actor_id = actor_id(this), bot_user_id](string value) {
            send_closure(actor_id, &BotRecommendationManager::on_load_bot_recommendations_from_database, bot_user_id,
                         std::move(value));
          }));
    } else {
      reload_bot_recommendations(bot_user_id);
    }
  }
}

void BotRecommendationManager::fail_load_bot_recommendations_queries(UserId bot_user_id, Status &&error) {
  for (int return_local = 0; return_local < 2; return_local++) {
    auto it = get_bot_recommendation_count_queries_[return_local].find(bot_user_id);
    if (it != get_bot_recommendation_count_queries_[return_local].end()) {
      auto promises = std::move(it->second);
      CHECK(!promises.empty());
      get_bot_recommendation_count_queries_[return_local].erase(it);
      fail_promises(promises, error.clone());
    }
  }
  auto it = get_bot_recommendations_queries_.find(bot_user_id);
  CHECK(it != get_bot_recommendations_queries_.end());
  auto promises = std::move(it->second);
  CHECK(!promises.empty());
  get_bot_recommendations_queries_.erase(it);
  fail_promises(promises, std::move(error));
}

void BotRecommendationManager::finish_load_bot_recommendations_queries(UserId bot_user_id, int32 total_count,
                                                                       vector<UserId> bot_user_ids) {
  for (int return_local = 0; return_local < 2; return_local++) {
    auto it = get_bot_recommendation_count_queries_[return_local].find(bot_user_id);
    if (it != get_bot_recommendation_count_queries_[return_local].end()) {
      auto promises = std::move(it->second);
      CHECK(!promises.empty());
      get_bot_recommendation_count_queries_[return_local].erase(it);
      for (auto &promise : promises) {
        promise.set_value(td_api::make_object<td_api::count>(total_count));
      }
    }
  }
  auto it = get_bot_recommendations_queries_.find(bot_user_id);
  CHECK(it != get_bot_recommendations_queries_.end());
  auto promises = std::move(it->second);
  CHECK(!promises.empty());
  get_bot_recommendations_queries_.erase(it);
  for (auto &promise : promises) {
    if (promise) {
      promise.set_value(td_->user_manager_->get_users_object(total_count, bot_user_ids));
    }
  }
}

void BotRecommendationManager::on_load_bot_recommendations_from_database(UserId bot_user_id, string value) {
  if (G()->close_flag()) {
    return fail_load_bot_recommendations_queries(bot_user_id, G()->close_status());
  }

  if (value.empty()) {
    return reload_bot_recommendations(bot_user_id);
  }
  auto &recommended_bots = bot_recommended_bots_[bot_user_id];
  if (log_event_parse(recommended_bots, value).is_error()) {
    bot_recommended_bots_.erase(bot_user_id);
    G()->td_db()->get_sqlite_pmc()->erase(get_bot_recommendations_database_key(bot_user_id), Auto());
    return reload_bot_recommendations(bot_user_id);
  }
  Dependencies dependencies;
  for (auto user_id : recommended_bots.bot_user_ids_) {
    dependencies.add(user_id);
  }
  if (!dependencies.resolve_force(td_, "on_load_bot_recommendations_from_database") ||
      !are_suitable_recommended_bots(recommended_bots)) {
    bot_recommended_bots_.erase(bot_user_id);
    G()->td_db()->get_sqlite_pmc()->erase(get_bot_recommendations_database_key(bot_user_id), Auto());
    return reload_bot_recommendations(bot_user_id);
  }

  auto next_reload_time = recommended_bots.next_reload_time_;
  finish_load_bot_recommendations_queries(bot_user_id, recommended_bots.total_count_, recommended_bots.bot_user_ids_);

  if (next_reload_time <= Time::now()) {
    load_bot_recommendations(bot_user_id, false, false, Auto(), Auto());
  }
}

void BotRecommendationManager::reload_bot_recommendations(UserId bot_user_id) {
  auto it = get_bot_recommendation_count_queries_[1].find(bot_user_id);
  if (it != get_bot_recommendation_count_queries_[1].end()) {
    auto promises = std::move(it->second);
    CHECK(!promises.empty());
    get_bot_recommendation_count_queries_[1].erase(it);
    for (auto &promise : promises) {
      promise.set_value(td_api::make_object<td_api::count>(-1));
    }
  }
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), bot_user_id](Result<telegram_api::object_ptr<telegram_api::users_Users>> &&result) {
        send_closure(actor_id, &BotRecommendationManager::on_get_bot_recommendations, bot_user_id, std::move(result));
      });
  td_->create_handler<GetBotRecommendationsQuery>(std::move(query_promise))->send(bot_user_id);
}

void BotRecommendationManager::on_get_bot_recommendations(
    UserId bot_user_id, Result<telegram_api::object_ptr<telegram_api::users_Users>> &&r_users) {
  G()->ignore_result_if_closing(r_users);

  if (r_users.is_error()) {
    return fail_load_bot_recommendations_queries(bot_user_id, r_users.move_as_error());
  }
  auto users_ptr = r_users.move_as_ok();

  int32 total_count = 0;
  vector<telegram_api::object_ptr<telegram_api::User>> users;
  switch (users_ptr->get_id()) {
    case telegram_api::users_users::ID: {
      auto users_obj = telegram_api::move_object_as<telegram_api::users_users>(users_ptr);
      users = std::move(users_obj->users_);
      total_count = static_cast<int32>(users.size());
      break;
    }
    case telegram_api::users_usersSlice::ID: {
      auto users_obj = telegram_api::move_object_as<telegram_api::users_usersSlice>(users_ptr);
      users = std::move(users_obj->users_);
      total_count = users_obj->count_;
      if (total_count < static_cast<int32>(users.size())) {
        LOG(ERROR) << "Receive total_count = " << total_count << " and " << users.size() << " similar bots for "
                   << bot_user_id;
        total_count = static_cast<int32>(users.size());
      }
      break;
    }
    default:
      UNREACHABLE();
  }

  auto recommended_bot_user_ids = td_->user_manager_->get_user_ids(std::move(users), "on_get_bot_recommendations");
  vector<UserId> bot_user_ids;
  for (auto recommended_bot_user_id : recommended_bot_user_ids) {
    if (is_suitable_recommended_bot(recommended_bot_user_id)) {
      bot_user_ids.push_back(recommended_bot_user_id);
    } else {
      total_count--;
    }
  }
  auto &recommended_bots = bot_recommended_bots_[bot_user_id];
  recommended_bots.total_count_ = total_count;
  recommended_bots.bot_user_ids_ = bot_user_ids;
  recommended_bots.next_reload_time_ = Time::now() + BOT_RECOMMENDATIONS_CACHE_TIME;

  if (G()->use_message_database()) {
    G()->td_db()->get_sqlite_pmc()->set(get_bot_recommendations_database_key(bot_user_id),
                                        log_event_store(recommended_bots).as_slice().str(), Promise<Unit>());
  }

  finish_load_bot_recommendations_queries(bot_user_id, total_count, std::move(bot_user_ids));
}

void BotRecommendationManager::open_bot_recommended_bot(UserId bot_user_id, UserId opened_bot_user_id,
                                                        Promise<Unit> &&promise) {
  if (!td_->user_manager_->is_user_bot(bot_user_id) || !td_->user_manager_->is_user_bot(opened_bot_user_id)) {
    return promise.set_error(Status::Error(400, "Bot not found"));
  }
  vector<telegram_api::object_ptr<telegram_api::jsonObjectValue>> data;
  data.push_back(telegram_api::make_object<telegram_api::jsonObjectValue>(
      "ref_bot_id", telegram_api::make_object<telegram_api::jsonString>(to_string(bot_user_id.get()))));
  data.push_back(telegram_api::make_object<telegram_api::jsonObjectValue>(
      "open_bot_id", telegram_api::make_object<telegram_api::jsonString>(to_string(opened_bot_user_id.get()))));
  save_app_log(td_, "bots.open_recommended_bot", DialogId(),
               telegram_api::make_object<telegram_api::jsonObject>(std::move(data)), std::move(promise));
}

}  // namespace td
