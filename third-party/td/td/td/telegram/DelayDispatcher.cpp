//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DelayDispatcher.h"

#include "td/telegram/Global.h"
#include "td/telegram/net/NetQueryDispatcher.h"

namespace td {

void DelayDispatcher::send_with_callback(NetQueryPtr query, ActorShared<NetQueryCallback> callback) {
  send_with_callback_and_delay(std::move(query), std::move(callback), default_delay_);
}

void DelayDispatcher::send_with_callback_and_delay(NetQueryPtr query, ActorShared<NetQueryCallback> callback,
                                                   double delay) {
  queue_.push({std::move(query), std::move(callback), delay});
  loop();
}

void DelayDispatcher::loop() {
  if (!wakeup_at_.is_in_past()) {
    set_timeout_at(wakeup_at_.at());
    return;
  }

  if (queue_.empty()) {
    return;
  }

  auto query = std::move(queue_.front());
  queue_.pop();
  G()->net_query_dispatcher().dispatch_with_callback(std::move(query.net_query), std::move(query.callback));

  wakeup_at_ = Timestamp::in(query.delay);

  if (queue_.empty()) {
    return;
  }

  set_timeout_at(wakeup_at_.at());
}

void DelayDispatcher::close_silent() {
  while (!queue_.empty()) {
    auto query = std::move(queue_.front());
    queue_.pop();
    query.net_query->clear();
  }
  stop();
}

void DelayDispatcher::tear_down() {
  while (!queue_.empty()) {
    auto query = std::move(queue_.front());
    queue_.pop();
    query.net_query->set_error(Global::request_aborted_error());
    send_closure(std::move(query.callback), &NetQueryCallback::on_result, std::move(query.net_query));
  }
  parent_.reset();
}

}  // namespace td
