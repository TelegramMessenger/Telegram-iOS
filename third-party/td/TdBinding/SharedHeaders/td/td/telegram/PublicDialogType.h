//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

namespace td {

enum class PublicDialogType : int32 { HasUsername, IsLocationBased, ForPersonalDialog };

inline PublicDialogType get_public_dialog_type(const td_api::object_ptr<td_api::PublicChatType> &type) {
  if (type == nullptr || type->get_id() == td_api::publicChatTypeHasUsername::ID) {
    return PublicDialogType::HasUsername;
  }
  return PublicDialogType::IsLocationBased;
}

}  // namespace td
