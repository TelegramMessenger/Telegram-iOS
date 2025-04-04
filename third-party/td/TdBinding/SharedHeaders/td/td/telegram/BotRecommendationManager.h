//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class Td;

class BotRecommendationManager final : public Actor {
 public:
  BotRecommendationManager(Td *td, ActorShared<> parent);

  void get_bot_recommendations(UserId bot_user_id, bool return_local,
                               Promise<td_api::object_ptr<td_api::users>> &&users_promise,
                               Promise<td_api::object_ptr<td_api::count>> &&count_promise);

  void open_bot_recommended_bot(UserId bot_user_id, UserId opened_bot_user_id, Promise<Unit> &&promise);

 private:
  static constexpr int32 BOT_RECOMMENDATIONS_CACHE_TIME = 86400;  // some reasonable limit

  struct RecommendedBots {
    int32 total_count_ = 0;
    vector<UserId> bot_user_ids_;
    double next_reload_time_ = 0.0;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  void tear_down() final;

  bool is_suitable_recommended_bot(UserId bot_user_id) const;

  bool are_suitable_recommended_bots(const RecommendedBots &recommended_bots) const;

  string get_bot_recommendations_database_key(UserId bot_user_id);

  void load_bot_recommendations(UserId bot_user_id, bool use_database, bool return_local,
                                Promise<td_api::object_ptr<td_api::users>> &&users_promise,
                                Promise<td_api::object_ptr<td_api::count>> &&count_promise);

  void fail_load_bot_recommendations_queries(UserId bot_user_id, Status &&error);

  void finish_load_bot_recommendations_queries(UserId bot_user_id, int32 total_count, vector<UserId> bot_user_ids);

  void on_load_bot_recommendations_from_database(UserId bot_user_id, string value);

  void reload_bot_recommendations(UserId bot_user_id);

  void on_get_bot_recommendations(UserId bot_user_id,
                                  Result<telegram_api::object_ptr<telegram_api::users_Users>> &&r_users);

  Td *td_;
  ActorShared<> parent_;

  FlatHashMap<UserId, RecommendedBots, UserIdHash> bot_recommended_bots_;
  FlatHashMap<UserId, vector<Promise<td_api::object_ptr<td_api::users>>>, UserIdHash> get_bot_recommendations_queries_;
  FlatHashMap<UserId, vector<Promise<td_api::object_ptr<td_api::count>>>, UserIdHash>
      get_bot_recommendation_count_queries_[2];
};

}  // namespace td
