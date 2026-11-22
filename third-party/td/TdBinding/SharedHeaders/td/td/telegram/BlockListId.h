//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

namespace td {

class BlockListId {
  enum class Type : int32 { None = -1, Main, Stories };
  Type type_ = Type::None;

  friend struct BlockListIdHash;

  explicit BlockListId(Type type) : type_(type) {
  }

 public:
  BlockListId() = default;

  BlockListId(bool is_blocked, bool is_blocked_for_stories)
      : type_(is_blocked ? Type::Main : (is_blocked_for_stories ? Type::Stories : Type::None)) {
  }

  explicit BlockListId(const td_api::object_ptr<td_api::BlockList> &block_list) {
    if (block_list == nullptr) {
      return;
    }
    switch (block_list->get_id()) {
      case td_api::blockListMain::ID:
        type_ = Type::Main;
        break;
      case td_api::blockListStories::ID:
        type_ = Type::Stories;
        break;
      default:
        UNREACHABLE();
    }
  }

  static BlockListId main() {
    return BlockListId(Type::Main);
  }

  static BlockListId stories() {
    return BlockListId(Type::Stories);
  }

  td_api::object_ptr<td_api::BlockList> get_block_list_object() const {
    switch (type_) {
      case Type::None:
        return nullptr;
      case Type::Main:
        return td_api::make_object<td_api::blockListMain>();
      case Type::Stories:
        return td_api::make_object<td_api::blockListStories>();
      default:
        UNREACHABLE();
    }
  }

  bool is_valid() const {
    return type_ == Type::Main || type_ == Type::Stories;
  }

  bool operator==(const BlockListId &other) const {
    return type_ == other.type_;
  }

  bool operator!=(const BlockListId &other) const {
    return type_ != other.type_;
  }
};

struct BlockListIdHash {
  uint32 operator()(BlockListId block_list_id) const {
    return Hash<int32>()(static_cast<int32>(block_list_id.type_));
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, BlockListId block_list_id) {
  if (block_list_id == BlockListId::main()) {
    return string_builder << "MainBlockList";
  }
  if (block_list_id == BlockListId::stories()) {
    return string_builder << "StoriesBlockList";
  }
  return string_builder << "InvalidBlockList";
}

}  // namespace td
