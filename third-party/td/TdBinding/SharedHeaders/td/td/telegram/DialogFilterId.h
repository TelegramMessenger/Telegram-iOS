//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <type_traits>

namespace td {

class DialogFilterId {
  int32 id = 0;

 public:
  DialogFilterId() = default;

  explicit constexpr DialogFilterId(int32 dialog_filter_id) : id(dialog_filter_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int32>::value>>
  DialogFilterId(T dialog_filter_id) = delete;

  static constexpr DialogFilterId min() {
    return DialogFilterId(static_cast<int32>(2));
  }
  static constexpr DialogFilterId max() {
    return DialogFilterId(static_cast<int32>(255));
  }

  bool is_valid() const {
    // don't check max() for greater future flexibility
    return id >= min().get();
  }

  int32 get() const {
    return id;
  }

  telegram_api::object_ptr<telegram_api::inputChatlistDialogFilter> get_input_chatlist() const {
    return telegram_api::make_object<telegram_api::inputChatlistDialogFilter>(id);
  }

  bool operator==(const DialogFilterId &other) const {
    return id == other.id;
  }

  bool operator!=(const DialogFilterId &other) const {
    return id != other.id;
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

struct DialogFilterIdHash {
  uint32 operator()(DialogFilterId dialog_filter_id) const {
    return Hash<int32>()(dialog_filter_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, DialogFilterId dialog_filter_id) {
  return string_builder << "folder " << dialog_filter_id.get();
}

}  // namespace td
