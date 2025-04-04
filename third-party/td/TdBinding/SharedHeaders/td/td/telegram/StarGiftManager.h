//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/StarGiftId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/Promise.h"
#include "td/utils/WaitFreeHashMap.h"

#include <utility>

namespace td {

class StarGift;
class Td;

class StarGiftManager final : public Actor {
 public:
  StarGiftManager(Td *td, ActorShared<> parent);
  StarGiftManager(const StarGiftManager &) = delete;
  StarGiftManager &operator=(const StarGiftManager &) = delete;
  StarGiftManager(StarGiftManager &&) = delete;
  StarGiftManager &operator=(StarGiftManager &&) = delete;
  ~StarGiftManager() final;

  void get_gift_payment_options(Promise<td_api::object_ptr<td_api::gifts>> &&promise);

  void on_get_star_gift(const StarGift &star_gift, bool from_server);

  void send_gift(int64 gift_id, DialogId dialog_id, td_api::object_ptr<td_api::formattedText> text, bool is_private,
                 bool pay_for_upgrade, Promise<Unit> &&promise);

  void convert_gift(StarGiftId star_gift_id, Promise<Unit> &&promise);

  void save_gift(StarGiftId star_gift_id, bool is_saved, Promise<Unit> &&promise);

  void set_dialog_pinned_gifts(DialogId dialog_id, const vector<StarGiftId> &star_gift_ids, Promise<Unit> &&promise);

  void toggle_chat_star_gift_notifications(DialogId dialog_id, bool are_enabled, Promise<Unit> &&promise);

  void get_gift_upgrade_preview(int64 gift_id, Promise<td_api::object_ptr<td_api::giftUpgradePreview>> &&promise);

  void upgrade_gift(StarGiftId star_gift_id, bool keep_original_details, int64 star_count,
                    Promise<td_api::object_ptr<td_api::upgradeGiftResult>> &&promise);

  void transfer_gift(StarGiftId star_gift_id, DialogId receiver_dialog_id, int64 star_count, Promise<Unit> &&promise);

  void get_saved_star_gifts(DialogId dialog_id, bool exclude_unsaved, bool exclude_saved, bool exclude_unlimited,
                            bool exclude_limited, bool exclude_unique, bool sort_by_value, const string &offset,
                            int32 limit, Promise<td_api::object_ptr<td_api::receivedGifts>> &&promise);

  void get_saved_star_gift(StarGiftId star_gift_id, Promise<td_api::object_ptr<td_api::receivedGift>> &&promise);

  void get_upgraded_gift(const string &name, Promise<td_api::object_ptr<td_api::upgradedGift>> &&promise);

  void get_star_gift_withdrawal_url(StarGiftId star_gift_id, const string &password, Promise<string> &&promise);

  void register_gift(MessageFullId message_full_id, const char *source);

  void unregister_gift(MessageFullId message_full_id, const char *source);

 private:
  void start_up() final;

  void tear_down() final;

  void send_get_star_gift_withdrawal_url_query(
      StarGiftId star_gift_id, telegram_api::object_ptr<telegram_api::InputCheckPasswordSRP> input_check_password,
      Promise<string> &&promise);

  double get_gift_message_polling_timeout() const;

  static void on_update_gift_message_timeout_callback(void *star_gift_manager_ptr, int64 message_number);

  void on_update_gift_message_timeout(int64 message_number);

  void on_update_gift_message(MessageFullId message_full_id);

  void on_online();

  void on_dialog_gift_transferred(DialogId from_dialog_id, DialogId to_dialog_id, Promise<Unit> &&promise);

  Td *td_;
  ActorShared<> parent_;

  FlatHashMap<int64, std::pair<int64, int64>> gift_prices_;

  int64 gift_message_count_ = 0;
  WaitFreeHashMap<MessageFullId, int64, MessageFullIdHash> gift_full_message_ids_;
  WaitFreeHashMap<int64, MessageFullId> gift_full_message_ids_by_id_;
  FlatHashSet<MessageFullId, MessageFullIdHash> being_reloaded_gift_messages_;
  MultiTimeout update_gift_message_timeout_{"UpdateGiftMessageTimeout"};
};

}  // namespace td
