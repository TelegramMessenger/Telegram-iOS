//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ReactionType.h"

#include "td/telegram/misc.h"

#include "td/utils/algorithm.h"
#include "td/utils/as.h"
#include "td/utils/base64.h"
#include "td/utils/crypto.h"
#include "td/utils/emoji.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/utf8.h"

namespace td {

static int64 get_custom_emoji_id(const string &reaction) {
  auto r_decoded = base64_decode(Slice(&reaction[1], reaction.size() - 1));
  CHECK(r_decoded.is_ok());
  CHECK(r_decoded.ok().size() == 8);
  return as<int64>(r_decoded.ok().c_str());
}

static string get_custom_emoji_string(int64 custom_emoji_id) {
  char s[8];
  as<int64>(&s) = custom_emoji_id;
  return PSTRING() << '#' << base64_encode(Slice(s, 8));
}

ReactionType::ReactionType(string &&emoji) : reaction_(std::move(emoji)) {
}

ReactionType::ReactionType(const telegram_api::object_ptr<telegram_api::Reaction> &reaction) {
  if (reaction == nullptr) {
    return;
  }
  switch (reaction->get_id()) {
    case telegram_api::reactionEmpty::ID:
      break;
    case telegram_api::reactionEmoji::ID:
      reaction_ = static_cast<const telegram_api::reactionEmoji *>(reaction.get())->emoticon_;
      if (is_custom_reaction() || is_paid_reaction()) {
        reaction_ = string();
      }
      break;
    case telegram_api::reactionCustomEmoji::ID:
      reaction_ =
          get_custom_emoji_string(static_cast<const telegram_api::reactionCustomEmoji *>(reaction.get())->document_id_);
      break;
    case telegram_api::reactionPaid::ID:
      reaction_ = "$";
      break;
    default:
      UNREACHABLE();
      break;
  }
}

ReactionType::ReactionType(const td_api::object_ptr<td_api::ReactionType> &type) {
  if (type == nullptr) {
    return;
  }
  switch (type->get_id()) {
    case td_api::reactionTypeEmoji::ID: {
      const string &emoji = static_cast<const td_api::reactionTypeEmoji *>(type.get())->emoji_;
      if (!check_utf8(emoji)) {
        break;
      }
      reaction_ = emoji;
      if (is_custom_reaction() || is_paid_reaction()) {
        reaction_ = string();
        break;
      }
      break;
    }
    case td_api::reactionTypeCustomEmoji::ID:
      reaction_ =
          get_custom_emoji_string(static_cast<const td_api::reactionTypeCustomEmoji *>(type.get())->custom_emoji_id_);
      break;
    case td_api::reactionTypePaid::ID:
      reaction_ = "$";
      break;
    default:
      UNREACHABLE();
      break;
  }
}

ReactionType ReactionType::paid() {
  ReactionType reaction_type;
  reaction_type.reaction_ = "$";
  return reaction_type;
}

vector<ReactionType> ReactionType::get_reaction_types(
    const vector<telegram_api::object_ptr<telegram_api::Reaction>> &reactions) {
  return transform(reactions, [](const auto &reaction) { return ReactionType(reaction); });
}

vector<ReactionType> ReactionType::get_reaction_types(
    const vector<td_api::object_ptr<td_api::ReactionType>> &reactions) {
  return transform(reactions, [](const auto &reaction) { return ReactionType(reaction); });
}

vector<telegram_api::object_ptr<telegram_api::Reaction>> ReactionType::get_input_reactions(
    const vector<ReactionType> &reaction_types) {
  return transform(reaction_types,
                   [](const ReactionType &reaction_type) { return reaction_type.get_input_reaction(); });
}

vector<td_api::object_ptr<td_api::ReactionType>> ReactionType::get_reaction_types_object(
    const vector<ReactionType> &reaction_types, bool paid_reactions_available) {
  vector<td_api::object_ptr<td_api::ReactionType>> result;
  result.reserve(reaction_types.size() + (paid_reactions_available ? 1 : 0));
  if (paid_reactions_available) {
    result.push_back(paid().get_reaction_type_object());
  }
  for (auto &reaction_type : reaction_types) {
    result.push_back(reaction_type.get_reaction_type_object());
  }
  return result;
}

telegram_api::object_ptr<telegram_api::Reaction> ReactionType::get_input_reaction() const {
  if (is_empty()) {
    return telegram_api::make_object<telegram_api::reactionEmpty>();
  }
  if (is_custom_reaction()) {
    return telegram_api::make_object<telegram_api::reactionCustomEmoji>(get_custom_emoji_id(reaction_));
  }
  if (is_paid_reaction()) {
    return telegram_api::make_object<telegram_api::reactionPaid>();
  }
  return telegram_api::make_object<telegram_api::reactionEmoji>(reaction_);
}

td_api::object_ptr<td_api::ReactionType> ReactionType::get_reaction_type_object() const {
  if (is_empty()) {
    return nullptr;
  }
  if (is_custom_reaction()) {
    return td_api::make_object<td_api::reactionTypeCustomEmoji>(get_custom_emoji_id(reaction_));
  }
  if (is_paid_reaction()) {
    return td_api::make_object<td_api::reactionTypePaid>();
  }
  return td_api::make_object<td_api::reactionTypeEmoji>(reaction_);
}

td_api::object_ptr<td_api::updateDefaultReactionType> ReactionType::get_update_default_reaction_type() const {
  if (is_empty()) {
    return nullptr;
  }
  return td_api::make_object<td_api::updateDefaultReactionType>(get_reaction_type_object());
}

uint64 ReactionType::get_hash() const {
  if (is_custom_reaction()) {
    return static_cast<uint64>(get_custom_emoji_id(reaction_));
  } else {
    return get_md5_string_hash(remove_emoji_selectors(reaction_));
  }
}

bool ReactionType::is_custom_reaction() const {
  return reaction_[0] == '#';
}

bool ReactionType::is_paid_reaction() const {
  return reaction_ == "$";
}

bool ReactionType::is_active_reaction(
    const FlatHashMap<ReactionType, size_t, ReactionTypeHash> &active_reaction_pos) const {
  return !is_empty() && (is_custom_reaction() || is_paid_reaction() || active_reaction_pos.count(*this) > 0);
}

bool operator<(const ReactionType &lhs, const ReactionType &rhs) {
  if (lhs.is_paid_reaction()) {
    return !rhs.is_paid_reaction();
  }
  if (rhs.is_paid_reaction()) {
    return false;
  }
  return lhs.reaction_ < rhs.reaction_;
}

bool operator==(const ReactionType &lhs, const ReactionType &rhs) {
  return lhs.reaction_ == rhs.reaction_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const ReactionType &reaction_type) {
  if (reaction_type.is_empty()) {
    return string_builder << "empty reaction";
  }
  if (reaction_type.is_custom_reaction()) {
    return string_builder << "custom reaction " << get_custom_emoji_id(reaction_type.reaction_);
  }
  if (reaction_type.is_paid_reaction()) {
    return string_builder << "paid reaction";
  }
  return string_builder << "reaction " << reaction_type.reaction_;
}

int64 get_reaction_types_hash(const vector<ReactionType> &reaction_types) {
  vector<uint64> numbers;
  for (auto &reaction_type : reaction_types) {
    if (reaction_type.is_custom_reaction()) {
      auto custom_emoji_id = static_cast<uint64>(get_custom_emoji_id(reaction_type.get_string()));
      numbers.push_back(custom_emoji_id >> 32);
      numbers.push_back(custom_emoji_id & 0xFFFFFFFF);
    } else {
      if (reaction_type.is_paid_reaction()) {
        LOG(ERROR) << "Have paid reaction";
      }
      auto emoji = remove_emoji_selectors(reaction_type.get_string());
      unsigned char hash[16];
      md5(emoji, {hash, sizeof(hash)});
      auto get = [hash](int num) {
        return static_cast<uint32>(hash[num]);
      };

      numbers.push_back(0);
      numbers.push_back(static_cast<int32>((get(0) << 24) + (get(1) << 16) + (get(2) << 8) + get(3)));
    }
  }
  return get_vector_hash(numbers);
}

}  // namespace td
