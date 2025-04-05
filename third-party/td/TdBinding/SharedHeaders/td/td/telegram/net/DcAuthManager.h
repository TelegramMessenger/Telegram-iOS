//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/AuthDataShared.h"
#include "td/telegram/net/AuthKeyState.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/net/NetQuery.h"

#include "td/actor/actor.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Promise.h"

#include <memory>

namespace td {

extern int VERBOSITY_NAME(dc);

class DcAuthManager final : public NetQueryCallback {
 public:
  explicit DcAuthManager(ActorShared<> parent);

  void add_dc(std::shared_ptr<AuthDataShared> auth_data);
  void update_main_dc(DcId new_main_dc_id);
  void destroy(Promise<> promise);

  void check_authorization_is_ok();

 private:
  struct DcInfo {
    DcId dc_id;
    std::shared_ptr<AuthDataShared> shared_auth_data;
    AuthKeyState auth_key_state;

    enum class State : int32 { Waiting, Export, Import, BeforeOk, Ok };
    State state = State::Waiting;
    uint64 wait_id = 0;
    int64 export_id = 0;
    BufferSlice export_bytes;
  };

  ActorShared<> parent_;

  std::vector<DcInfo> dcs_;
  DcId main_dc_id_;
  bool need_check_authorization_is_ok_{false};
  bool close_flag_{false};
  bool need_destroy_auth_key_{false};
  Promise<Unit> destroy_promise_;

  DcInfo &get_dc(int32 dc_id);
  DcInfo *find_dc(int32 dc_id);

  void update_auth_key_state();

  void on_result(NetQueryPtr net_query) final;
  void dc_loop(DcInfo &dc);

  void destroy_loop();
  void loop() final;
};

}  // namespace td
