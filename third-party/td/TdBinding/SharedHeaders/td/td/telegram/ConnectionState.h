//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"

namespace td {

enum class ConnectionState : int32 { WaitingForNetwork, ConnectingToProxy, Connecting, Updating, Ready, Empty };

td_api::object_ptr<td_api::updateConnectionState> get_update_connection_state_object(ConnectionState state);

}  // namespace td
