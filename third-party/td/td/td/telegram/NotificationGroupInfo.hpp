//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/NotificationGroupInfo.h"
#include "td/telegram/Version.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void NotificationGroupInfo::store(StorerT &storer) const {
  using td::store;
  store(group_id_, storer);
  store(last_notification_date_, storer);
  store(last_notification_id_, storer);
  store(max_removed_notification_id_, storer);
  store(max_removed_object_id_, storer);
}

template <class ParserT>
void NotificationGroupInfo::parse(ParserT &parser) {
  using td::parse;
  parse(group_id_, parser);
  parse(last_notification_date_, parser);
  parse(last_notification_id_, parser);
  parse(max_removed_notification_id_, parser);
  if (parser.version() >= static_cast<int32>(Version::AddNotificationGroupInfoMaxRemovedMessageId)) {
    parse(max_removed_object_id_, parser);
  }
}

}  // namespace td
