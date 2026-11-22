//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/StoryFullId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

class StatisticsManager final : public Actor {
 public:
  StatisticsManager(Td *td, ActorShared<> parent);

  void get_channel_statistics(DialogId dialog_id, bool is_dark,
                              Promise<td_api::object_ptr<td_api::ChatStatistics>> &&promise);

  void get_dialog_revenue_statistics(DialogId dialog_id, bool is_dark,
                                     Promise<td_api::object_ptr<td_api::chatRevenueStatistics>> &&promise);

  void get_dialog_revenue_withdrawal_url(DialogId dialog_id, const string &password, Promise<string> &&promise);

  void get_dialog_revenue_transactions(DialogId dialog_id, int32 offset, int32 limit,
                                       Promise<td_api::object_ptr<td_api::chatRevenueTransactions>> &&promise);

  void on_update_dialog_revenue_transactions(DialogId dialog_id,
                                             telegram_api::object_ptr<telegram_api::broadcastRevenueBalances> balances);

  void get_channel_message_statistics(MessageFullId message_full_id, bool is_dark,
                                      Promise<td_api::object_ptr<td_api::messageStatistics>> &&promise);

  void get_channel_story_statistics(StoryFullId message_full_id, bool is_dark,
                                    Promise<td_api::object_ptr<td_api::storyStatistics>> &&promise);

  void load_statistics_graph(DialogId dialog_id, string token, int64 x,
                             Promise<td_api::object_ptr<td_api::StatisticalGraph>> &&promise);

  void get_message_public_forwards(MessageFullId message_full_id, string offset, int32 limit,
                                   Promise<td_api::object_ptr<td_api::publicForwards>> &&promise);

  void get_story_public_forwards(StoryFullId story_full_id, string offset, int32 limit,
                                 Promise<td_api::object_ptr<td_api::publicForwards>> &&promise);

  void on_get_public_forwards(telegram_api::object_ptr<telegram_api::stats_publicForwards> &&public_forwards,
                              Promise<td_api::object_ptr<td_api::publicForwards>> &&promise);

  void get_channel_differences_if_needed(telegram_api::object_ptr<telegram_api::stats_publicForwards> &&public_forwards,
                                         Promise<td_api::object_ptr<td_api::publicForwards>> promise,
                                         const char *source);

  static td_api::object_ptr<td_api::StatisticalGraph> convert_stats_graph(
      telegram_api::object_ptr<telegram_api::StatsGraph> obj);

 private:
  void tear_down() final;

  void send_get_channel_stats_query(DcId dc_id, ChannelId channel_id, bool is_dark,
                                    Promise<td_api::object_ptr<td_api::ChatStatistics>> &&promise);

  void send_get_channel_message_stats_query(DcId dc_id, MessageFullId message_full_id, bool is_dark,
                                            Promise<td_api::object_ptr<td_api::messageStatistics>> &&promise);

  void send_get_channel_story_stats_query(DcId dc_id, StoryFullId story_full_id, bool is_dark,
                                          Promise<td_api::object_ptr<td_api::storyStatistics>> &&promise);

  void send_load_async_graph_query(DcId dc_id, string token, int64 x,
                                   Promise<td_api::object_ptr<td_api::StatisticalGraph>> &&promise);

  void send_get_message_public_forwards_query(DcId dc_id, MessageFullId message_full_id, string offset, int32 limit,
                                              Promise<td_api::object_ptr<td_api::publicForwards>> &&promise);

  void send_get_story_public_forwards_query(DcId dc_id, StoryFullId story_full_id, string offset, int32 limit,
                                            Promise<td_api::object_ptr<td_api::publicForwards>> &&promise);

  void send_get_dialog_revenue_withdrawal_url_query(
      DialogId dialog_id, telegram_api::object_ptr<telegram_api::InputCheckPasswordSRP> input_check_password,
      Promise<string> &&promise);

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
