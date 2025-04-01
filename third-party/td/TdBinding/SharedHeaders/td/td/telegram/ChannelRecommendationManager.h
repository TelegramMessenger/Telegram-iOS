//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <utility>

namespace td {

class Td;

class ChannelRecommendationManager final : public Actor {
 public:
  ChannelRecommendationManager(Td *td, ActorShared<> parent);

  void get_recommended_channels(Promise<td_api::object_ptr<td_api::chats>> &&promise);

  void get_channel_recommendations(DialogId dialog_id, bool return_local,
                                   Promise<td_api::object_ptr<td_api::chats>> &&chats_promise,
                                   Promise<td_api::object_ptr<td_api::count>> &&count_promise);

  void open_channel_recommended_channel(DialogId dialog_id, DialogId opened_dialog_id, Promise<Unit> &&promise);

 private:
  static constexpr int32 CHANNEL_RECOMMENDATIONS_CACHE_TIME = 86400;  // some reasonable limit

  struct RecommendedDialogs {
    int32 total_count_ = 0;
    vector<DialogId> dialog_ids_;
    double next_reload_time_ = 0.0;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  void tear_down() final;

  bool is_suitable_recommended_channel(DialogId dialog_id) const;

  bool is_suitable_recommended_channel(ChannelId channel_id) const;

  bool are_suitable_recommended_dialogs(const RecommendedDialogs &recommended_dialogs) const;

  static string get_recommended_channels_database_key();

  void load_recommended_channels(bool use_database, Promise<td_api::object_ptr<td_api::chats>> &&promise);

  void fail_load_recommended_channels_queries(Status &&error);

  void finish_load_recommended_channels_queries(int32 total_count, vector<DialogId> dialog_ids);

  void on_load_recommended_channels_from_database(string value);

  void reload_recommended_channels();

  void on_get_recommended_channels(Result<std::pair<int32, vector<tl_object_ptr<telegram_api::Chat>>>> &&r_chats);

  static string get_channel_recommendations_database_key(ChannelId channel_id);

  void load_channel_recommendations(ChannelId channel_id, bool use_database, bool return_local,
                                    Promise<td_api::object_ptr<td_api::chats>> &&chats_promise,
                                    Promise<td_api::object_ptr<td_api::count>> &&count_promise);

  void fail_load_channel_recommendations_queries(ChannelId channel_id, Status &&error);

  void finish_load_channel_recommendations_queries(ChannelId channel_id, int32 total_count,
                                                   vector<DialogId> dialog_ids);

  void on_load_channel_recommendations_from_database(ChannelId channel_id, string value);

  void reload_channel_recommendations(ChannelId channel_id);

  void on_get_channel_recommendations(
      ChannelId channel_id, Result<std::pair<int32, vector<telegram_api::object_ptr<telegram_api::Chat>>>> &&r_chats);

  FlatHashMap<ChannelId, RecommendedDialogs, ChannelIdHash> channel_recommended_dialogs_;
  FlatHashMap<ChannelId, vector<Promise<td_api::object_ptr<td_api::chats>>>, ChannelIdHash>
      get_channel_recommendations_queries_;
  FlatHashMap<ChannelId, vector<Promise<td_api::object_ptr<td_api::count>>>, ChannelIdHash>
      get_channel_recommendation_count_queries_[2];

  RecommendedDialogs recommended_channels_;
  vector<Promise<td_api::object_ptr<td_api::chats>>> get_recommended_channels_queries_;
  bool are_recommended_channels_inited_ = false;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
