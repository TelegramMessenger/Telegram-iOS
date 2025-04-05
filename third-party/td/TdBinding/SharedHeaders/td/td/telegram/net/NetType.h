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

enum class NetType : int8 { Other, WiFi, Mobile, MobileRoaming, Size, None, Unknown };

inline NetType get_net_type(const tl_object_ptr<td_api::NetworkType> &net_type) {
  if (net_type == nullptr) {
    return NetType::Other;
  }

  switch (net_type->get_id()) {
    case td_api::networkTypeOther::ID:
      return NetType::Other;
    case td_api::networkTypeWiFi::ID:
      return NetType::WiFi;
    case td_api::networkTypeMobile::ID:
      return NetType::Mobile;
    case td_api::networkTypeMobileRoaming::ID:
      return NetType::MobileRoaming;
    case td_api::networkTypeNone::ID:
      return NetType::None;
    default:
      UNREACHABLE();
  }
}

inline tl_object_ptr<td_api::NetworkType> get_network_type_object(NetType net_type) {
  switch (net_type) {
    case NetType::Other:
      return make_tl_object<td_api::networkTypeOther>();
    case NetType::WiFi:
      return make_tl_object<td_api::networkTypeWiFi>();
    case NetType::Mobile:
      return make_tl_object<td_api::networkTypeMobile>();
    case NetType::MobileRoaming:
      return make_tl_object<td_api::networkTypeMobileRoaming>();
    default:
      UNREACHABLE();
  }
}

}  // namespace td
