//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageOrigin.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Dependencies;
class Td;

class LastForwardedMessageInfo {
  DialogId dialog_id_;
  MessageId message_id_;
  DialogId sender_dialog_id_;
  string sender_name_;
  int32 date_ = 0;
  bool is_outgoing_ = false;

  friend bool operator==(const LastForwardedMessageInfo &lhs, const LastForwardedMessageInfo &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const LastForwardedMessageInfo &last_message_info);

 public:
  LastForwardedMessageInfo() = default;

  LastForwardedMessageInfo(DialogId dialog_id, MessageId message_id, DialogId sender_dialog_id, string sender_name,
                           int32 date, bool is_outgoing)
      : dialog_id_(dialog_id)
      , message_id_(message_id)
      , sender_dialog_id_(sender_dialog_id)
      , sender_name_(std::move(sender_name))
      , date_(date)
      , is_outgoing_(is_outgoing) {
  }

  bool is_empty() const;

  void validate();

  void hide_sender_if_needed(Td *td);

  void add_dependencies(Dependencies &dependencies) const;

  void add_min_user_ids(vector<UserId> &user_ids) const;

  void add_min_channel_ids(vector<ChannelId> &channel_ids) const;

  td_api::object_ptr<td_api::forwardSource> get_forward_source_object(Td *td, bool for_saved_messages,
                                                                      const MessageOrigin &origin,
                                                                      int32 origin_date) const;

  DialogId get_dialog_id() const {
    return dialog_id_;
  }

  MessageFullId get_message_full_id() const {
    return {dialog_id_, message_id_};
  }

  bool has_sender_name() const {
    return !sender_name_.empty();
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

class MessageForwardInfo {
  MessageOrigin origin_;
  int32 date_ = 0;
  LastForwardedMessageInfo last_message_info_;
  string psa_type_;
  bool is_imported_ = false;

  friend bool operator==(const MessageForwardInfo &lhs, const MessageForwardInfo &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MessageForwardInfo &forward_info);

 public:
  MessageForwardInfo() = default;

  MessageForwardInfo(MessageOrigin &&origin, int32 date, LastForwardedMessageInfo &&last_message_info,
                     string &&psa_type, bool is_imported)
      : origin_(std::move(origin))
      , date_(date)
      , last_message_info_(std::move(last_message_info))
      , psa_type_(std::move(psa_type))
      , is_imported_(is_imported) {
    last_message_info_.validate();
  }

  static unique_ptr<MessageForwardInfo> get_message_forward_info(
      Td *td, telegram_api::object_ptr<telegram_api::messageFwdHeader> &&forward_header);

  static unique_ptr<MessageForwardInfo> copy_message_forward_info(Td *td, const MessageForwardInfo &forward_info,
                                                                  LastForwardedMessageInfo &&last_message_info);

  td_api::object_ptr<td_api::messageForwardInfo> get_message_forward_info_object(Td *td, bool for_saved_messages) const;

  td_api::object_ptr<td_api::messageImportInfo> get_message_import_info_object() const;

  void add_dependencies(Dependencies &dependencies) const;

  void add_min_user_ids(vector<UserId> &user_ids) const;

  void add_min_channel_ids(vector<ChannelId> &channel_ids) const;

  static bool need_change_warning(const MessageForwardInfo *lhs, const MessageForwardInfo *rhs, MessageId message_id);

  int32 get_origin_date() const {
    return date_;
  }

  bool is_imported() const {
    return is_imported_;
  }

  const MessageOrigin &get_origin() const {
    return origin_;
  }

  MessageFullId get_origin_message_full_id() const {
    return origin_.get_message_full_id();
  }

  DialogId get_last_dialog_id() const {
    return last_message_info_.get_dialog_id();
  }

  MessageFullId get_last_message_full_id() const {
    return last_message_info_.get_message_full_id();
  }

  bool has_last_sender_name() const {
    return last_message_info_.has_sender_name();
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const LastForwardedMessageInfo &lhs, const LastForwardedMessageInfo &rhs);

bool operator!=(const LastForwardedMessageInfo &lhs, const LastForwardedMessageInfo &rhs);

bool operator==(const MessageForwardInfo &lhs, const MessageForwardInfo &rhs);

bool operator!=(const MessageForwardInfo &lhs, const MessageForwardInfo &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const MessageForwardInfo &forward_info);

StringBuilder &operator<<(StringBuilder &string_builder, const unique_ptr<MessageForwardInfo> &forward_info);

}  // namespace td
