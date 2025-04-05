//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/AuthData.h"
#include "td/mtproto/RawConnection.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"

namespace td {
namespace mtproto {

ActorOwn<> create_ping_actor(Slice actor_name, unique_ptr<RawConnection> raw_connection, unique_ptr<AuthData> auth_data,
                             Promise<unique_ptr<RawConnection>> promise, ActorShared<> parent);

}  // namespace mtproto
}  // namespace td
