//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/CallActor.h"
#include "td/telegram/CallId.h"
#include "td/telegram/GroupCallId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <map>

namespace td {

class Td;

class CallManager final : public Actor {
 public:
  CallManager(Td *td, ActorShared<> parent);

  CallId get_call_id(int64 call_id);

  void update_call(telegram_api::object_ptr<telegram_api::updatePhoneCall> call);

  void update_call_signaling_data(int64 call_id, string data);

  void create_call(UserId user_id, CallProtocol &&protocol, bool is_video, GroupCallId group_call_id,
                   Promise<CallId> promise);

  void accept_call(CallId call_id, CallProtocol &&protocol, Promise<Unit> promise);

  void send_call_signaling_data(CallId call_id, string &&data, Promise<Unit> promise);

  void discard_call(CallId call_id, bool is_disconnected, int32 duration, bool is_video, int64 connection_id,
                    Promise<Unit> promise);

  void rate_call(CallId call_id, int32 rating, string comment,
                 vector<td_api::object_ptr<td_api::CallProblem>> &&problems, Promise<Unit> promise);

  void send_call_debug_information(CallId call_id, string data, Promise<Unit> promise);

  void send_call_log(CallId call_id, td_api::object_ptr<td_api::InputFile> log_file, Promise<Unit> promise);

  void create_conference_call(CallId call_id, Promise<Unit> promise);

 private:
  bool close_flag_ = false;

  Td *td_;
  ActorShared<> parent_;

  struct CallInfo {
    CallId call_id{0};
    vector<telegram_api::object_ptr<telegram_api::updatePhoneCall>> updates;
  };
  std::map<int64, CallInfo> call_info_;
  int32 next_call_id_{1};
  FlatHashMap<CallId, ActorOwn<CallActor>, CallIdHash> id_to_actor_;

  ActorId<CallActor> get_call_actor(CallId call_id);
  CallId create_call_actor();
  void set_call_id(CallId call_id, Result<int64> r_server_call_id);

  void hangup() final;
  void hangup_shared() final;
  void tear_down() final;
};
}  // namespace td
