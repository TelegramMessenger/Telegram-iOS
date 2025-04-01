//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogFilterId.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <limits>
#include <type_traits>

namespace td {

class DialogListId {
  int64 id = 0;

  static constexpr int64 FILTER_ID_SHIFT = static_cast<int64>(1) << 32;

 public:
  DialogListId() = default;

  explicit DialogListId(int64 dialog_list_id) : id(dialog_list_id) {
    if (is_folder() && get_folder_id() != FolderId::archive()) {
      id = FolderId::main().get();
    } else if (is_filter()) {
      CHECK(get_filter_id().is_valid());
    }
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int32>::value>>
  DialogListId(T dialog_list_id) = delete;

  explicit DialogListId(DialogFilterId dialog_filter_id) : id(dialog_filter_id.get() + FILTER_ID_SHIFT) {
  }
  explicit DialogListId(FolderId folder_id) : id(folder_id.get()) {
  }

  explicit DialogListId(const td_api::object_ptr<td_api::ChatList> &chat_list) {
    if (chat_list == nullptr) {
      CHECK(id == FolderId::main().get());
      return;
    }
    switch (chat_list->get_id()) {
      case td_api::chatListArchive::ID:
        id = FolderId::archive().get();
        break;
      case td_api::chatListMain::ID:
        CHECK(id == FolderId::main().get());
        break;
      case td_api::chatListFolder::ID: {
        DialogFilterId filter_id(static_cast<const td_api::chatListFolder *>(chat_list.get())->chat_folder_id_);
        if (filter_id.is_valid()) {
          *this = DialogListId(filter_id);
        }
        break;
      }
      default:
        UNREACHABLE();
        break;
    }
  }

  td_api::object_ptr<td_api::ChatList> get_chat_list_object() const {
    if (is_folder()) {
      auto folder_id = get_folder_id();
      if (folder_id == FolderId::archive()) {
        return td_api::make_object<td_api::chatListArchive>();
      }
      return td_api::make_object<td_api::chatListMain>();
    }
    if (is_filter()) {
      return td_api::make_object<td_api::chatListFolder>(get_filter_id().get());
    }
    UNREACHABLE();
    return nullptr;
  }

  int64 get() const {
    return id;
  }

  bool operator==(const DialogListId &other) const {
    return id == other.id;
  }

  bool operator!=(const DialogListId &other) const {
    return id != other.id;
  }

  bool is_folder() const {
    return std::numeric_limits<int32>::min() <= id && id <= std::numeric_limits<int32>::max();
  }

  bool is_filter() const {
    return std::numeric_limits<int32>::min() + FILTER_ID_SHIFT <= id &&
           id <= std::numeric_limits<int32>::max() + FILTER_ID_SHIFT;
  }

  FolderId get_folder_id() const {
    CHECK(is_folder());
    return FolderId(static_cast<int32>(id));
  }

  DialogFilterId get_filter_id() const {
    CHECK(is_filter());
    return DialogFilterId(static_cast<int32>(id - FILTER_ID_SHIFT));
  }
};

struct DialogListIdHash {
  uint32 operator()(DialogListId dialog_list_id) const {
    return Hash<int64>()(dialog_list_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, DialogListId dialog_list_id) {
  if (dialog_list_id.is_folder()) {
    auto folder_id = dialog_list_id.get_folder_id();
    if (folder_id == FolderId::archive()) {
      return string_builder << "Archive chat list";
    }
    if (folder_id == FolderId::main()) {
      return string_builder << "Main chat list";
    }
    return string_builder << "chat list " << folder_id;
  }
  if (dialog_list_id.is_filter()) {
    return string_builder << "chat list " << dialog_list_id.get_filter_id();
  }
  return string_builder << "unknown chat list " << dialog_list_id.get();
}

}  // namespace td
