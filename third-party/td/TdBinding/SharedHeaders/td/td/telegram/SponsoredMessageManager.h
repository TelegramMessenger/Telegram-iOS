//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class Td;

class SponsoredMessageManager final : public Actor {
 public:
  SponsoredMessageManager(Td *td, ActorShared<> parent);
  SponsoredMessageManager(const SponsoredMessageManager &) = delete;
  SponsoredMessageManager &operator=(const SponsoredMessageManager &) = delete;
  SponsoredMessageManager(SponsoredMessageManager &&) = delete;
  SponsoredMessageManager &operator=(SponsoredMessageManager &&) = delete;
  ~SponsoredMessageManager() final;

  void get_dialog_sponsored_messages(DialogId dialog_id,
                                     Promise<td_api::object_ptr<td_api::sponsoredMessages>> &&promise);

  void view_sponsored_message(DialogId dialog_id, MessageId sponsored_message_id);

  void click_sponsored_message(DialogId dialog_id, MessageId sponsored_message_id, bool is_media_click,
                               bool from_fullscreen, Promise<Unit> &&promise);

  void report_sponsored_message(DialogId dialog_id, MessageId sponsored_message_id, const string &option_id,
                                Promise<td_api::object_ptr<td_api::ReportChatSponsoredMessageResult>> &&promise);

 private:
  struct SponsoredMessage;
  struct SponsoredMessageInfo;
  struct DialogSponsoredMessages;

  void tear_down() final;

  static void on_delete_cached_sponsored_messages_timeout_callback(void *sponsored_message_manager_ptr,
                                                                   int64 dialog_id_int);

  void delete_cached_sponsored_messages(DialogId dialog_id);

  td_api::object_ptr<td_api::messageSponsor> get_message_sponsor_object(
      const SponsoredMessage &sponsored_message) const;

  td_api::object_ptr<td_api::sponsoredMessage> get_sponsored_message_object(
      DialogId dialog_id, const SponsoredMessage &sponsored_message) const;

  td_api::object_ptr<td_api::sponsoredMessages> get_sponsored_messages_object(
      DialogId dialog_id, const DialogSponsoredMessages &sponsored_messages) const;

  void on_get_dialog_sponsored_messages(
      DialogId dialog_id, Result<telegram_api::object_ptr<telegram_api::messages_SponsoredMessages>> &&result);

  FlatHashMap<DialogId, unique_ptr<DialogSponsoredMessages>, DialogIdHash> dialog_sponsored_messages_;

  MessageId current_sponsored_message_id_ = MessageId::max();

  MultiTimeout delete_cached_sponsored_messages_timeout_{"DeleteCachedSponsoredMessagesTimeout"};

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
