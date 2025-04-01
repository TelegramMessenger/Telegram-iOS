//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessRecipients.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class BusinessConnectedBot {
 public:
  BusinessConnectedBot() = default;

  explicit BusinessConnectedBot(telegram_api::object_ptr<telegram_api::connectedBot> connected_bot);

  explicit BusinessConnectedBot(td_api::object_ptr<td_api::businessConnectedBot> connected_bot);

  td_api::object_ptr<td_api::businessConnectedBot> get_business_connected_bot_object(Td *td) const;

  bool is_valid() const {
    return user_id_.is_valid();
  }

  UserId get_user_id() const {
    return user_id_;
  }

  const BusinessRecipients &get_recipients() const {
    return recipients_;
  }

  bool get_can_reply() const {
    return can_reply_;
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  UserId user_id_;
  BusinessRecipients recipients_;
  bool can_reply_ = false;

  friend bool operator==(const BusinessConnectedBot &lhs, const BusinessConnectedBot &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BusinessConnectedBot &connected_bot);
};

bool operator==(const BusinessConnectedBot &lhs, const BusinessConnectedBot &rhs);

inline bool operator!=(const BusinessConnectedBot &lhs, const BusinessConnectedBot &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessConnectedBot &connected_bot);

}  // namespace td
