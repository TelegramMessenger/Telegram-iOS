//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/StringBuilder.h"

namespace td {

class InputDialogId {
  DialogId dialog_id;
  int64 access_hash = 0;

 public:
  InputDialogId() = default;

  explicit constexpr InputDialogId(DialogId dialog_id) : dialog_id(dialog_id) {
  }

  explicit InputDialogId(const tl_object_ptr<telegram_api::InputPeer> &input_peer);

  static vector<InputDialogId> get_input_dialog_ids(const vector<tl_object_ptr<telegram_api::InputPeer>> &input_peers,
                                                    FlatHashSet<DialogId, DialogIdHash> *added_dialog_ids = nullptr);

  static vector<DialogId> get_dialog_ids(const vector<InputDialogId> &input_dialog_ids);

  static vector<telegram_api::object_ptr<telegram_api::InputDialogPeer>> get_input_dialog_peers(
      const vector<InputDialogId> &input_dialog_ids);

  static vector<telegram_api::object_ptr<telegram_api::InputPeer>> get_input_peers(
      const vector<InputDialogId> &input_dialog_ids);

  static bool are_equivalent(const vector<InputDialogId> &lhs, const vector<InputDialogId> &rhs);

  static bool contains(const vector<InputDialogId> &input_dialog_ids, DialogId dialog_id);

  static bool remove(vector<InputDialogId> &input_dialog_ids, DialogId dialog_id);

  bool operator==(const InputDialogId &other) const {
    return dialog_id == other.dialog_id && access_hash == other.access_hash;
  }

  bool operator!=(const InputDialogId &other) const {
    return !(*this == other);
  }

  bool is_valid() const {
    return dialog_id.is_valid();
  }

  DialogId get_dialog_id() const {
    return dialog_id;
  }

  tl_object_ptr<telegram_api::InputPeer> get_input_peer() const;

  template <class StorerT>
  void store(StorerT &storer) const {
    dialog_id.store(storer);
    storer.store_long(access_hash);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    dialog_id.parse(parser);
    access_hash = parser.fetch_long();
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, InputDialogId input_dialog_id) {
  return string_builder << "input " << input_dialog_id.get_dialog_id();
}

}  // namespace td
