//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/StoryId.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct StoryFullId {
 private:
  DialogId dialog_id;
  StoryId story_id;

 public:
  StoryFullId() : dialog_id(), story_id() {
  }

  StoryFullId(DialogId dialog_id, StoryId story_id) : dialog_id(dialog_id), story_id(story_id) {
  }

  bool operator==(const StoryFullId &other) const {
    return dialog_id == other.dialog_id && story_id == other.story_id;
  }

  bool operator!=(const StoryFullId &other) const {
    return !(*this == other);
  }

  DialogId get_dialog_id() const {
    return dialog_id;
  }

  StoryId get_story_id() const {
    return story_id;
  }

  bool is_valid() const {
    return dialog_id.is_valid() && story_id.is_valid();
  }

  bool is_server() const {
    return dialog_id.is_valid() && story_id.is_server();
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    dialog_id.store(storer);
    story_id.store(storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    dialog_id.parse(parser);
    story_id.parse(parser);
  }
};

struct StoryFullIdHash {
  uint32 operator()(StoryFullId story_full_id) const {
    return combine_hashes(DialogIdHash()(story_full_id.get_dialog_id()), StoryIdHash()(story_full_id.get_story_id()));
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, StoryFullId story_full_id) {
  return string_builder << story_full_id.get_story_id() << " in " << story_full_id.get_dialog_id();
}

}  // namespace td
