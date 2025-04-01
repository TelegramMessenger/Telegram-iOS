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

namespace td {

class InputGroupCallId {
  int64 group_call_id = 0;
  int64 access_hash = 0;

 public:
  InputGroupCallId() = default;

  explicit InputGroupCallId(const tl_object_ptr<telegram_api::inputGroupCall> &input_group_call);

  InputGroupCallId(int64 group_call_id, int64 access_hash) : group_call_id(group_call_id), access_hash(access_hash) {
  }

  bool operator==(const InputGroupCallId &other) const {
    return group_call_id == other.group_call_id;
  }

  bool operator!=(const InputGroupCallId &other) const {
    return !(*this == other);
  }

  bool is_identical(const InputGroupCallId &other) const {
    return group_call_id == other.group_call_id && access_hash == other.access_hash;
  }

  bool is_valid() const {
    return group_call_id != 0;
  }

  uint32 get_hash() const {
    return Hash<int64>()(group_call_id);
  }

  tl_object_ptr<telegram_api::inputGroupCall> get_input_group_call() const;

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_long(group_call_id);
    storer.store_long(access_hash);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    group_call_id = parser.fetch_long();
    access_hash = parser.fetch_long();
  }

  friend StringBuilder &operator<<(StringBuilder &string_builder, InputGroupCallId input_group_call_id);
};

struct InputGroupCallIdHash {
  uint32 operator()(InputGroupCallId input_group_call_id) const {
    return input_group_call_id.get_hash();
  }
};

}  // namespace td
