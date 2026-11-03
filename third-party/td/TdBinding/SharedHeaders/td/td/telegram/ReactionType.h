//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct ReactionTypeHash;

class ReactionType {
  string reaction_;

  friend bool operator<(const ReactionType &lhs, const ReactionType &rhs);

  friend bool operator==(const ReactionType &lhs, const ReactionType &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const ReactionType &reaction_type);

  friend struct ReactionTypeHash;

 public:
  ReactionType() = default;

  explicit ReactionType(string &&emoji);

  explicit ReactionType(const telegram_api::object_ptr<telegram_api::Reaction> &reaction);

  explicit ReactionType(const td_api::object_ptr<td_api::ReactionType> &type);

  static ReactionType paid();

  static vector<ReactionType> get_reaction_types(
      const vector<telegram_api::object_ptr<telegram_api::Reaction>> &reactions);

  static vector<ReactionType> get_reaction_types(const vector<td_api::object_ptr<td_api::ReactionType>> &reactions);

  static vector<telegram_api::object_ptr<telegram_api::Reaction>> get_input_reactions(
      const vector<ReactionType> &reaction_types);

  static vector<td_api::object_ptr<td_api::ReactionType>> get_reaction_types_object(
      const vector<ReactionType> &reaction_types, bool paid_reactions_available);

  telegram_api::object_ptr<telegram_api::Reaction> get_input_reaction() const;

  td_api::object_ptr<td_api::ReactionType> get_reaction_type_object() const;

  td_api::object_ptr<td_api::updateDefaultReactionType> get_update_default_reaction_type() const;

  uint64 get_hash() const;

  bool is_custom_reaction() const;

  bool is_paid_reaction() const;

  bool is_active_reaction(const FlatHashMap<ReactionType, size_t, ReactionTypeHash> &active_reaction_pos) const;

  bool is_empty() const {
    return reaction_.empty();
  }

  const string &get_string() const {
    return reaction_;
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

struct ReactionTypeHash {
  uint32 operator()(const ReactionType &reaction_type) const {
    return Hash<string>()(reaction_type.reaction_);
  }
};

bool operator<(const ReactionType &lhs, const ReactionType &rhs);

bool operator==(const ReactionType &lhs, const ReactionType &rhs);

inline bool operator!=(const ReactionType &lhs, const ReactionType &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const ReactionType &reaction_type);

int64 get_reaction_types_hash(const vector<ReactionType> &reaction_types);

}  // namespace td
