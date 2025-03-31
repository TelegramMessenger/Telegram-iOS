//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/ConnectionManager.h"

namespace td {
namespace mtproto {

void ConnectionManager::inc_connect() {
  auto &cnt = get_link_token() == 1 ? connect_cnt_ : connect_proxy_cnt_;
  cnt++;
  if (cnt == 1) {
    loop();
  }
}

void ConnectionManager::dec_connect() {
  auto &cnt = get_link_token() == 1 ? connect_cnt_ : connect_proxy_cnt_;
  CHECK(cnt > 0);
  cnt--;
  if (cnt == 0) {
    loop();
  }
}

ConnectionManager::ConnectionToken ConnectionManager::connection_impl(ActorId<ConnectionManager> connection_manager,
                                                                      int mode) {
  auto actor = ActorShared<ConnectionManager>(connection_manager, mode);
  send_closure(actor, &ConnectionManager::inc_connect);
  return ConnectionToken(std::move(actor));
}

}  // namespace mtproto
}  // namespace td
