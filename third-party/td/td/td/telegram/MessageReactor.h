//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MinChannel.h"
#include "td/telegram/PaidReactionType.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/unique_value_ptr.h"

namespace td {

class Dependencies;

class Td;

class MessageReactor {
  DialogId dialog_id_;  // self for anonymous reactions by the current user
  unique_value_ptr<MinChannel> min_channel_;
  int32 count_ = 0;
  bool is_top_ = false;
  bool is_me_ = false;
  bool is_anonymous_ = false;

  friend bool operator<(const MessageReactor &lhs, const MessageReactor &rhs);

  friend bool operator==(const MessageReactor &lhs, const MessageReactor &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MessageReactor &reactor);

 public:
  MessageReactor() = default;

  MessageReactor(Td *td, telegram_api::object_ptr<telegram_api::messageReactor> &&reactor);

  MessageReactor(DialogId dialog_id, int32 count, bool is_anonymous)
      : dialog_id_(dialog_id), count_(count), is_me_(true), is_anonymous_(is_anonymous) {
  }

  bool is_valid() const {
    return count_ > 0 && (is_me_ ? dialog_id_.is_valid() : (dialog_id_.is_valid() || is_anonymous_) && is_top_);
  }

  bool is_me() const {
    return is_me_;
  }

  bool is_anonymous() const {
    return is_anonymous_;
  }

  PaidReactionType get_paid_reaction_type(DialogId my_dialog_id) const;

  bool fix_is_me(DialogId my_dialog_id);

  void add_count(int32 count, DialogId reactor_dialog_id, DialogId my_dialog_id) {
    count_ += count;
    if (reactor_dialog_id == DialogId()) {
      dialog_id_ = my_dialog_id;
      is_anonymous_ = true;
    } else {
      dialog_id_ = reactor_dialog_id;
      is_anonymous_ = false;
    }
  }

  td_api::object_ptr<td_api::paidReactor> get_paid_reactor_object(Td *td) const;

  void add_min_channel(Td *td) const;

  void add_dependencies(Dependencies &dependencies) const;

  static void fix_message_reactors(vector<MessageReactor> &reactors, bool need_warning);

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator<(const MessageReactor &lhs, const MessageReactor &rhs);

bool operator==(const MessageReactor &lhs, const MessageReactor &rhs);

inline bool operator!=(const MessageReactor &lhs, const MessageReactor &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageReactor &reactor);

}  // namespace td
