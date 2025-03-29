//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/td_json_client.h"
#include "td/telegram/td_log.h"

#include "td/actor/ConcurrentScheduler.h"

#include <emscripten.h>

extern "C" {

EMSCRIPTEN_KEEPALIVE double td_emscripten_create_client_id() {
  return td_create_client_id();
}

EMSCRIPTEN_KEEPALIVE void td_emscripten_send(double client_id, const char *query) {
  td_send(static_cast<int>(client_id), query);
}

EMSCRIPTEN_KEEPALIVE const char *td_emscripten_receive() {
  return td_receive(0);
}

EMSCRIPTEN_KEEPALIVE const char *td_emscripten_execute(const char *query) {
  return td_execute(query);
}

EMSCRIPTEN_KEEPALIVE double td_emscripten_get_timeout() {
  return td::ConcurrentScheduler::emscripten_get_main_timeout();
}
}

int main() {
  emscripten_exit_with_live_runtime();
}
