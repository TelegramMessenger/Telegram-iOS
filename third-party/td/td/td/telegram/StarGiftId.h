//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class StarGiftId {
  enum class Type : int32 { Empty, ForUser, ForDialog };
  Type type_ = Type::Empty;

  ServerMessageId server_message_id_;

  DialogId dialog_id_;
  int64 saved_id_ = 0;

  friend bool operator==(const StarGiftId &lhs, const StarGiftId &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const StarGiftId &star_gift_id);

 public:
  StarGiftId() = default;

  explicit StarGiftId(ServerMessageId server_message_id);

  StarGiftId(DialogId dialog_id, int64 saved_id);

  explicit StarGiftId(const string &star_gift_id);

  bool is_empty() const {
    return type_ == Type::Empty;
  }

  bool is_valid() const {
    return type_ != Type::Empty;
  }

  telegram_api::object_ptr<telegram_api::InputSavedStarGift> get_input_saved_star_gift(Td *td) const;

  string get_star_gift_id() const;

  DialogId get_dialog_id(const Td *td) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StarGiftId &lhs, const StarGiftId &rhs);

inline bool operator!=(const StarGiftId &lhs, const StarGiftId &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const StarGiftId &star_gift_id);

}  // namespace td
