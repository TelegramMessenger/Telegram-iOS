//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessBotRights.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void BusinessBotRights::store(StorerT &storer) const {
  BEGIN_STORE_FLAGS();
  STORE_FLAG(can_reply_);
  STORE_FLAG(can_read_messages_);
  STORE_FLAG(can_delete_sent_messages_);
  STORE_FLAG(can_delete_received_messages_);
  STORE_FLAG(can_edit_name_);
  STORE_FLAG(can_edit_bio_);
  STORE_FLAG(can_edit_profile_photo_);
  STORE_FLAG(can_edit_username_);
  STORE_FLAG(can_view_gifts_);
  STORE_FLAG(can_sell_gifts_);
  STORE_FLAG(can_change_gift_settings_);
  STORE_FLAG(can_transfer_and_upgrade_gifts_);
  STORE_FLAG(can_transfer_stars_);
  STORE_FLAG(can_manage_stories_);
  END_STORE_FLAGS();
}

template <class ParserT>
void BusinessBotRights::parse(ParserT &parser) {
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(can_reply_);
  PARSE_FLAG(can_read_messages_);
  PARSE_FLAG(can_delete_sent_messages_);
  PARSE_FLAG(can_delete_received_messages_);
  PARSE_FLAG(can_edit_name_);
  PARSE_FLAG(can_edit_bio_);
  PARSE_FLAG(can_edit_profile_photo_);
  PARSE_FLAG(can_edit_username_);
  PARSE_FLAG(can_view_gifts_);
  PARSE_FLAG(can_sell_gifts_);
  PARSE_FLAG(can_change_gift_settings_);
  PARSE_FLAG(can_transfer_and_upgrade_gifts_);
  PARSE_FLAG(can_transfer_stars_);
  PARSE_FLAG(can_manage_stories_);
  END_PARSE_FLAGS();
}

}  // namespace td
