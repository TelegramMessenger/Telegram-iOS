//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"

#include <utility>

namespace td {

class Td;

class CommonDialogManager final : public Actor {
 public:
  CommonDialogManager(Td *td, ActorShared<> parent);
  CommonDialogManager(const CommonDialogManager &) = delete;
  CommonDialogManager &operator=(const CommonDialogManager &) = delete;
  CommonDialogManager(CommonDialogManager &&) = delete;
  CommonDialogManager &operator=(CommonDialogManager &&) = delete;
  ~CommonDialogManager() final;

  void on_get_common_dialogs(UserId user_id, int64 offset_chat_id, vector<tl_object_ptr<telegram_api::Chat>> &&chats,
                             int32 total_count);

  void drop_common_dialogs_cache(UserId user_id);

  std::pair<int32, vector<DialogId>> get_common_dialogs(UserId user_id, DialogId offset_dialog_id, int32 limit,
                                                        bool force, Promise<Unit> &&promise);

 private:
  void tear_down() final;

  static constexpr int32 MAX_GET_DIALOGS = 100;  // server side limit

  struct CommonDialogs {
    vector<DialogId> dialog_ids;
    double receive_time = 0;
    int32 total_count = 0;
    bool is_outdated = false;
  };
  FlatHashMap<UserId, CommonDialogs, UserIdHash> found_common_dialogs_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
