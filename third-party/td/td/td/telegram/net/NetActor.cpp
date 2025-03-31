//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/NetActor.h"

#include "td/telegram/Global.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/Td.h"

namespace td {

NetActor::NetActor() : td_(static_cast<Td *>(G()->td().get_actor_unsafe())) {
}

void NetActor::set_parent(ActorShared<> parent) {
  parent_ = std::move(parent);
}

void NetActor::on_result(NetQueryPtr query) {
  CHECK(query->is_ready());
  if (query->is_ok()) {
    on_result(query->move_as_ok());
  } else {
    on_error(query->move_as_error());
  }
  on_result_finish();
}

void NetActor::send_query(NetQueryPtr query) {
  G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this));
}

}  // namespace td
