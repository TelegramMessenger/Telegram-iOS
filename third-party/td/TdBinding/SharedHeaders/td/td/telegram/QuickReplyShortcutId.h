//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <type_traits>

namespace td {

class QuickReplyShortcutId {
  int32 id = 0;

 public:
  static constexpr int32 MAX_SERVER_SHORTCUT_ID = 1999999999;

  QuickReplyShortcutId() = default;

  explicit constexpr QuickReplyShortcutId(int32 quick_reply_shortcut_id) : id(quick_reply_shortcut_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int32>::value>>
  QuickReplyShortcutId(T quick_reply_shortcut_id) = delete;

  int32 get() const {
    return id;
  }

  static vector<int32> get_input_quick_reply_shortcut_ids(
      const vector<QuickReplyShortcutId> &quick_reply_shortcut_ids) {
    vector<int32> input_quick_reply_shortcut_ids;
    input_quick_reply_shortcut_ids.reserve(quick_reply_shortcut_ids.size());
    for (auto &quick_reply_shortcut_id : quick_reply_shortcut_ids) {
      input_quick_reply_shortcut_ids.emplace_back(quick_reply_shortcut_id.get());
    }
    return input_quick_reply_shortcut_ids;
  }

  static vector<QuickReplyShortcutId> get_quick_reply_shortcut_ids(const vector<int32> &shortcut_ids) {
    vector<QuickReplyShortcutId> quick_reply_shortcut_ids;
    quick_reply_shortcut_ids.reserve(shortcut_ids.size());
    for (auto &shortcut_id : shortcut_ids) {
      quick_reply_shortcut_ids.emplace_back(shortcut_id);
    }
    return quick_reply_shortcut_ids;
  }

  bool operator==(const QuickReplyShortcutId &other) const {
    return id == other.id;
  }

  bool operator!=(const QuickReplyShortcutId &other) const {
    return id != other.id;
  }

  bool is_valid() const {
    return id > 0;
  }

  bool is_server() const {
    return id > 0 && id <= MAX_SERVER_SHORTCUT_ID;
  }

  bool is_local() const {
    return id > MAX_SERVER_SHORTCUT_ID;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_int(id);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    id = parser.fetch_int();
  }
};

struct QuickReplyShortcutIdHash {
  uint32 operator()(QuickReplyShortcutId quick_reply_shortcut_id) const {
    return Hash<int32>()(quick_reply_shortcut_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, QuickReplyShortcutId quick_reply_shortcut_id) {
  return string_builder << "shortcut " << quick_reply_shortcut_id.get();
}

}  // namespace td
