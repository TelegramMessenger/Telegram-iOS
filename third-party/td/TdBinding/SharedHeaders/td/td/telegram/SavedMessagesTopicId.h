//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Dependencies;
class MessageForwardInfo;
class Td;

class SavedMessagesTopicId {
  DialogId dialog_id_;

  friend struct SavedMessagesTopicIdHash;

  friend bool operator==(const SavedMessagesTopicId &lhs, const SavedMessagesTopicId &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, SavedMessagesTopicId saved_messages_topic_id);

  bool have_input_peer(Td *td) const;

 public:
  SavedMessagesTopicId() = default;

  explicit SavedMessagesTopicId(DialogId dialog_id) : dialog_id_(dialog_id) {
  }

  SavedMessagesTopicId(DialogId my_dialog_id, const MessageForwardInfo *message_forward_info,
                       DialogId real_forward_from_dialog_id);

  bool is_valid() const {
    return dialog_id_.is_valid();
  }

  Status is_valid_status(Td *td) const;

  Status is_valid_in(Td *td, DialogId dialog_id) const;

  bool is_author_hidden() const;

  int64 get_unique_id() const {
    return dialog_id_.get();
  }

  td_api::object_ptr<td_api::SavedMessagesTopicType> get_saved_messages_topic_type_object(const Td *td) const;

  telegram_api::object_ptr<telegram_api::InputPeer> get_input_peer(const Td *td) const;

  telegram_api::object_ptr<telegram_api::InputDialogPeer> get_input_dialog_peer(const Td *td) const;

  void add_dependencies(Dependencies &dependencies) const;

  template <class StorerT>
  void store(StorerT &storer) const {
    dialog_id_.store(storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    dialog_id_.parse(parser);
  }
};

struct SavedMessagesTopicIdHash {
  uint32 operator()(SavedMessagesTopicId saved_messages_topic_id) const {
    return DialogIdHash()(saved_messages_topic_id.dialog_id_);
  }
};

inline bool operator==(const SavedMessagesTopicId &lhs, const SavedMessagesTopicId &rhs) {
  return lhs.dialog_id_ == rhs.dialog_id_;
}

inline bool operator!=(const SavedMessagesTopicId &lhs, const SavedMessagesTopicId &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, SavedMessagesTopicId saved_messages_topic_id);

}  // namespace td
