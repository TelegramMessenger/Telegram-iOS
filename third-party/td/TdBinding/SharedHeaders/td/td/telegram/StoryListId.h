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

class StoryListId {
  enum class Type : int32 { None = -1, Main, Archive };
  Type type_ = Type::None;

  friend struct StoryListIdHash;

  explicit StoryListId(Type type) : type_(type) {
  }

 public:
  StoryListId() = default;

  explicit StoryListId(const td_api::object_ptr<td_api::StoryList> &story_list) {
    if (story_list == nullptr) {
      return;
    }
    switch (story_list->get_id()) {
      case td_api::storyListMain::ID:
        type_ = Type::Main;
        break;
      case td_api::storyListArchive::ID:
        type_ = Type::Archive;
        break;
      default:
        UNREACHABLE();
    }
  }

  static StoryListId main() {
    return StoryListId(Type::Main);
  }

  static StoryListId archive() {
    return StoryListId(Type::Archive);
  }

  td_api::object_ptr<td_api::StoryList> get_story_list_object() const {
    switch (type_) {
      case Type::None:
        return nullptr;
      case Type::Main:
        return td_api::make_object<td_api::storyListMain>();
      case Type::Archive:
        return td_api::make_object<td_api::storyListArchive>();
      default:
        UNREACHABLE();
    }
  }

  bool is_valid() const {
    return type_ == Type::Main || type_ == Type::Archive;
  }

  bool operator==(const StoryListId &other) const {
    return type_ == other.type_;
  }

  bool operator!=(const StoryListId &other) const {
    return type_ != other.type_;
  }
};

struct StoryListIdHash {
  uint32 operator()(StoryListId story_list_id) const {
    return Hash<int32>()(static_cast<int32>(story_list_id.type_));
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, StoryListId story_list_id) {
  if (story_list_id == StoryListId::main()) {
    return string_builder << "MainStoryList";
  }
  if (story_list_id == StoryListId::archive()) {
    return string_builder << "ArchiveStoryList";
  }
  return string_builder << "InvalidStoryList";
}

}  // namespace td
