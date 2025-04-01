//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/ServerMessageId.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <limits>

namespace td {

class DialogDate {
  int64 order;
  DialogId dialog_id;

 public:
  DialogDate(int64 order, DialogId dialog_id) : order(order), dialog_id(dialog_id) {
  }

  bool operator<(const DialogDate &other) const {
    return order > other.order || (order == other.order && dialog_id.get() > other.dialog_id.get());
  }

  bool operator<=(const DialogDate &other) const {
    return order >= other.order && (order != other.order || dialog_id.get() >= other.dialog_id.get());
  }

  bool operator==(const DialogDate &other) const {
    return order == other.order && dialog_id == other.dialog_id;
  }

  bool operator!=(const DialogDate &other) const {
    return order != other.order || dialog_id != other.dialog_id;
  }

  int64 get_order() const {
    return order;
  }
  DialogId get_dialog_id() const {
    return dialog_id;
  }
  int32 get_date() const {
    return static_cast<int32>((order >> 32) & 0x7FFFFFFF);
  }
  MessageId get_message_id() const {
    return MessageId(ServerMessageId(static_cast<int32>(order & 0x7FFFFFFF)));
  }
};

const DialogDate MIN_DIALOG_DATE(std::numeric_limits<int64>::max(), DialogId());
const DialogDate MAX_DIALOG_DATE(0, DialogId());
const int64 DEFAULT_ORDER = -1;

struct DialogDateHash {
  uint32 operator()(const DialogDate &dialog_date) const {
    return combine_hashes(Hash<int64>()(dialog_date.get_order()), DialogIdHash()(dialog_date.get_dialog_id()));
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, DialogDate dialog_date) {
  return string_builder << "[" << dialog_date.get_order() << ", " << dialog_date.get_dialog_id().get() << "]";
}

}  // namespace td
