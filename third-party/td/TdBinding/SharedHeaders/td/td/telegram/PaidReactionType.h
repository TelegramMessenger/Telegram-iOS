//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Dependencies;
class Td;

class PaidReactionType {
  enum class Type : int32 { Regular, Anonymous, Dialog };
  Type type_ = Type::Regular;
  DialogId dialog_id_;

  friend bool operator==(const PaidReactionType &lhs, const PaidReactionType &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const PaidReactionType &paid_reaction_type);

 public:
  PaidReactionType() = default;

  PaidReactionType(Td *td, const telegram_api::object_ptr<telegram_api::PaidReactionPrivacy> &reaction);

  PaidReactionType(Td *td, const td_api::object_ptr<td_api::PaidReactionType> &type);

  static PaidReactionType legacy(bool is_anonymous);

  static PaidReactionType dialog(DialogId dialog_id);

  telegram_api::object_ptr<telegram_api::PaidReactionPrivacy> get_input_paid_reaction_privacy(Td *td) const;

  td_api::object_ptr<td_api::PaidReactionType> get_paid_reaction_type_object(Td *td) const;

  td_api::object_ptr<td_api::updateDefaultPaidReactionType> get_update_default_paid_reaction_type(Td *td) const;

  bool is_valid() const {
    return type_ == Type::Dialog ? dialog_id_.is_valid() : true;
  }

  DialogId get_dialog_id(DialogId my_dialog_id) const;

  void add_dependencies(Dependencies &dependencies) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const PaidReactionType &lhs, const PaidReactionType &rhs);

inline bool operator!=(const PaidReactionType &lhs, const PaidReactionType &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const PaidReactionType &paid_reaction_type);

}  // namespace td
