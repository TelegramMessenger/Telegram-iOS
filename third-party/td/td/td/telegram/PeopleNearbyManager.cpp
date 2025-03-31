//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/PeopleNearbyManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"

namespace td {

PeopleNearbyManager::PeopleNearbyManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  if (!td_->auth_manager_->is_bot()) {
    G()->td_db()->get_binlog_pmc()->erase("location_visibility_expire_date");
    G()->td_db()->get_binlog_pmc()->erase("pending_location_visibility_expire_date");
  }
}

void PeopleNearbyManager::tear_down() {
  parent_.reset();
}

}  // namespace td
