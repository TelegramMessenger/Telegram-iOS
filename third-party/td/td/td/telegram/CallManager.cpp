//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/CallManager.h"

#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"

#include <limits>

namespace td {

CallManager::CallManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void CallManager::tear_down() {
  parent_.reset();
}

CallId CallManager::get_call_id(int64 call_id) {
  auto it = call_info_.find(call_id);
  if (it == call_info_.end()) {
    return CallId();
  }
  return it->second.call_id;
}

void CallManager::update_call(telegram_api::object_ptr<telegram_api::updatePhoneCall> call) {
  auto call_id = [phone_call = call->phone_call_.get()] {
    switch (phone_call->get_id()) {
      case telegram_api::phoneCallEmpty::ID:
        return static_cast<const telegram_api::phoneCallEmpty *>(phone_call)->id_;
      case telegram_api::phoneCallWaiting::ID:
        return static_cast<const telegram_api::phoneCallWaiting *>(phone_call)->id_;
      case telegram_api::phoneCallRequested::ID:
        return static_cast<const telegram_api::phoneCallRequested *>(phone_call)->id_;
      case telegram_api::phoneCallAccepted::ID:
        return static_cast<const telegram_api::phoneCallAccepted *>(phone_call)->id_;
      case telegram_api::phoneCall::ID:
        return static_cast<const telegram_api::phoneCall *>(phone_call)->id_;
      case telegram_api::phoneCallDiscarded::ID:
        return static_cast<const telegram_api::phoneCallDiscarded *>(phone_call)->id_;
      default:
        UNREACHABLE();
        return static_cast<int64>(0);
    }
  }();
  LOG(DEBUG) << "Receive UpdateCall for " << call_id;

  auto &info = call_info_[call_id];

  if (!info.call_id.is_valid() && call->phone_call_->get_id() == telegram_api::phoneCallRequested::ID) {
    info.call_id = create_call_actor();
  }

  if (!info.call_id.is_valid()) {
    LOG(INFO) << "Call identifier is not valid for " << call_id << ", postpone update " << to_string(call);
    info.updates.push_back(std::move(call));
    return;
  }

  auto actor = get_call_actor(info.call_id);
  if (actor.empty()) {
    LOG(INFO) << "Drop update: " << to_string(call);
  }
  send_closure(actor, &CallActor::update_call, std::move(call->phone_call_));
}

void CallManager::update_call_signaling_data(int64 call_id, string data) {
  auto info_it = call_info_.find(call_id);
  if (info_it == call_info_.end() || !info_it->second.call_id.is_valid()) {
    LOG(INFO) << "Ignore signaling data for " << call_id;
    return;
  }

  auto actor = get_call_actor(info_it->second.call_id);
  if (actor.empty()) {
    LOG(INFO) << "Ignore signaling data for " << info_it->second.call_id;
    return;
  }
  send_closure(actor, &CallActor::update_call_signaling_data, std::move(data));
}

void CallManager::create_call(UserId user_id, CallProtocol &&protocol, bool is_video, GroupCallId group_call_id,
                              Promise<CallId> promise) {
  TRY_STATUS_PROMISE(promise, td_->user_manager_->get_input_user(user_id));
  LOG(INFO) << "Create call with " << user_id;
  auto call_id = create_call_actor();
  auto actor = get_call_actor(call_id);
  CHECK(!actor.empty());
  auto safe_promise = SafePromise<CallId>(std::move(promise), Status::Error(400, "Call not found"));
  send_closure(actor, &CallActor::create_call, user_id, std::move(protocol), is_video, group_call_id,
               std::move(safe_promise));
}

void CallManager::accept_call(CallId call_id, CallProtocol &&protocol, Promise<Unit> promise) {
  auto actor = get_call_actor(call_id);
  if (actor.empty()) {
    return promise.set_error(Status::Error(400, "Call not found"));
  }
  auto safe_promise = SafePromise<Unit>(std::move(promise), Status::Error(400, "Call not found"));
  send_closure(actor, &CallActor::accept_call, std::move(protocol), std::move(safe_promise));
}

void CallManager::send_call_signaling_data(CallId call_id, string &&data, Promise<Unit> promise) {
  auto actor = get_call_actor(call_id);
  if (actor.empty()) {
    return promise.set_error(Status::Error(400, "Call not found"));
  }
  auto safe_promise = SafePromise<Unit>(std::move(promise), Status::Error(400, "Call not found"));
  send_closure(actor, &CallActor::send_call_signaling_data, std::move(data), std::move(safe_promise));
}

void CallManager::discard_call(CallId call_id, bool is_disconnected, int32 duration, bool is_video, int64 connection_id,
                               Promise<Unit> promise) {
  auto actor = get_call_actor(call_id);
  if (actor.empty()) {
    return promise.set_error(Status::Error(400, "Call not found"));
  }
  auto safe_promise = SafePromise<Unit>(std::move(promise), Status::Error(400, "Call not found"));
  send_closure(actor, &CallActor::discard_call, is_disconnected, duration, is_video, connection_id,
               std::move(safe_promise));
}

void CallManager::rate_call(CallId call_id, int32 rating, string comment,
                            vector<td_api::object_ptr<td_api::CallProblem>> &&problems, Promise<Unit> promise) {
  auto actor = get_call_actor(call_id);
  if (actor.empty()) {
    return promise.set_error(Status::Error(400, "Call not found"));
  }
  auto safe_promise = SafePromise<Unit>(std::move(promise), Status::Error(400, "Call not found"));
  send_closure(actor, &CallActor::rate_call, rating, std::move(comment), std::move(problems), std::move(safe_promise));
}

void CallManager::send_call_debug_information(CallId call_id, string data, Promise<Unit> promise) {
  auto actor = get_call_actor(call_id);
  if (actor.empty()) {
    return promise.set_error(Status::Error(400, "Call not found"));
  }
  auto safe_promise = SafePromise<Unit>(std::move(promise), Status::Error(400, "Call not found"));
  send_closure(actor, &CallActor::send_call_debug_information, std::move(data), std::move(safe_promise));
}

void CallManager::send_call_log(CallId call_id, td_api::object_ptr<td_api::InputFile> log_file, Promise<Unit> promise) {
  auto actor = get_call_actor(call_id);
  if (actor.empty()) {
    return promise.set_error(Status::Error(400, "Call not found"));
  }
  auto safe_promise = SafePromise<Unit>(std::move(promise), Status::Error(400, "Call not found"));
  send_closure(actor, &CallActor::send_call_log, std::move(log_file), std::move(safe_promise));
}

void CallManager::create_conference_call(CallId call_id, Promise<Unit> promise) {
  auto actor = get_call_actor(call_id);
  if (actor.empty()) {
    return promise.set_error(Status::Error(400, "Call not found"));
  }
  auto safe_promise = SafePromise<Unit>(std::move(promise), Status::Error(400, "Call not found"));
  send_closure(actor, &CallActor::create_conference_call, std::move(safe_promise));
}

CallId CallManager::create_call_actor() {
  if (next_call_id_ == std::numeric_limits<int32>::max()) {
    next_call_id_ = 1;
  }
  auto id = CallId(next_call_id_++);
  CHECK(id.is_valid());
  auto it_flag = id_to_actor_.emplace(id, ActorOwn<CallActor>());
  CHECK(it_flag.second);
  LOG(INFO) << "Create CallActor: " << id;
  auto main_promise = PromiseCreator::lambda([actor_id = actor_id(this), id](Result<int64> call_id) {
    send_closure(actor_id, &CallManager::set_call_id, id, std::move(call_id));
  });
  it_flag.first->second = create_actor<CallActor>(PSLICE() << "Call " << id.get(), td_, id,
                                                  actor_shared(this, id.get()), std::move(main_promise));
  return id;
}

void CallManager::set_call_id(CallId call_id, Result<int64> r_server_call_id) {
  if (r_server_call_id.is_error()) {
    return;
  }
  auto server_call_id = r_server_call_id.move_as_ok();
  auto &call_info = call_info_[server_call_id];
  CHECK(!call_info.call_id.is_valid() || call_info.call_id == call_id);
  call_info.call_id = call_id;
  auto actor = get_call_actor(call_id);
  if (actor.empty()) {
    return;
  }
  for (auto &update : call_info.updates) {
    send_closure(actor, &CallActor::update_call, std::move(update->phone_call_));
  }
  call_info.updates.clear();
}

ActorId<CallActor> CallManager::get_call_actor(CallId call_id) {
  auto it = id_to_actor_.find(call_id);
  if (it == id_to_actor_.end()) {
    return ActorId<CallActor>();
  }
  return it->second.get();
}

void CallManager::hangup() {
  close_flag_ = true;
  for (auto &it : id_to_actor_) {
    LOG(INFO) << "Ask to close CallActor " << it.first.get();
    it.second.reset();
  }
  if (id_to_actor_.empty()) {
    stop();
  }
}

void CallManager::hangup_shared() {
  auto token = narrow_cast<int32>(get_link_token());
  auto it = id_to_actor_.find(CallId(token));
  CHECK(it != id_to_actor_.end());
  LOG(INFO) << "Closed CallActor " << it->first.get();
  it->second.release();
  id_to_actor_.erase(it);
  if (close_flag_ && id_to_actor_.empty()) {
    stop();
  }
}

}  // namespace td
