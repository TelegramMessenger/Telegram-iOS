//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ConnectionState.h"

#include "td/utils/logging.h"

namespace td {

static td_api::object_ptr<td_api::ConnectionState> get_connection_state_object(ConnectionState state) {
  switch (state) {
    case ConnectionState::Empty:
      UNREACHABLE();
      return nullptr;
    case ConnectionState::WaitingForNetwork:
      return td_api::make_object<td_api::connectionStateWaitingForNetwork>();
    case ConnectionState::ConnectingToProxy:
      return td_api::make_object<td_api::connectionStateConnectingToProxy>();
    case ConnectionState::Connecting:
      return td_api::make_object<td_api::connectionStateConnecting>();
    case ConnectionState::Updating:
      return td_api::make_object<td_api::connectionStateUpdating>();
    case ConnectionState::Ready:
      return td_api::make_object<td_api::connectionStateReady>();
    default:
      LOG(FATAL) << "State = " << static_cast<int32>(state);
      return nullptr;
  }
}

td_api::object_ptr<td_api::updateConnectionState> get_update_connection_state_object(ConnectionState state) {
  return td_api::make_object<td_api::updateConnectionState>(get_connection_state_object(state));
}

}  // namespace td
