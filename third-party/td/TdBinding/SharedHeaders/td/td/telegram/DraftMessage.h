//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/InputMessageText.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/MessageContentType.h"
#include "td/telegram/MessageEffectId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageInputReplyTo.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class Dependencies;
class Td;

enum class DraftMessageContentType : int32 { VideoNote, VoiceNote };

class DraftMessageContent {
 public:
  DraftMessageContent() = default;
  DraftMessageContent(const DraftMessageContent &) = default;
  DraftMessageContent &operator=(const DraftMessageContent &) = default;
  DraftMessageContent(DraftMessageContent &&) = default;
  DraftMessageContent &operator=(DraftMessageContent &&) = default;

  virtual DraftMessageContentType get_type() const = 0;

  virtual td_api::object_ptr<td_api::InputMessageContent> get_draft_input_message_content_object() const = 0;

  virtual ~DraftMessageContent() = default;
};

class DraftMessage {
  int32 date_ = 0;
  MessageInputReplyTo message_input_reply_to_;
  InputMessageText input_message_text_;
  unique_ptr<DraftMessageContent> local_content_;
  MessageEffectId message_effect_id_;

  friend class SaveDraftMessageQuery;

 public:
  DraftMessage();
  DraftMessage(Td *td, telegram_api::object_ptr<telegram_api::draftMessage> &&draft_message);
  DraftMessage(const DraftMessage &) = delete;
  DraftMessage &operator=(const DraftMessage &) = delete;
  DraftMessage(DraftMessage &&) = delete;
  DraftMessage &operator=(DraftMessage &&) = delete;
  ~DraftMessage();

  int32 get_date() const {
    return date_;
  }

  bool is_local() const {
    return local_content_ != nullptr;
  }

  bool need_clear_local(MessageContentType content_type) const;

  bool need_update_to(const DraftMessage &other, bool from_update) const;

  void add_dependencies(Dependencies &dependencies) const;

  td_api::object_ptr<td_api::draftMessage> get_draft_message_object(Td *td) const;

  static Result<unique_ptr<DraftMessage>> get_draft_message(Td *td, DialogId dialog_id, MessageId top_thread_message_id,
                                                            td_api::object_ptr<td_api::draftMessage> &&draft_message);

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

void store_draft_message_content(const DraftMessageContent *content, LogEventStorerCalcLength &storer);

void store_draft_message_content(const DraftMessageContent *content, LogEventStorerUnsafe &storer);

void parse_draft_message_content(unique_ptr<DraftMessageContent> &content, LogEventParser &parser);

bool is_local_draft_message(const unique_ptr<DraftMessage> &draft_message);

bool need_update_draft_message(const unique_ptr<DraftMessage> &old_draft_message,
                               const unique_ptr<DraftMessage> &new_draft_message, bool from_update);

void add_draft_message_dependencies(Dependencies &dependencies, const unique_ptr<DraftMessage> &draft_message);

td_api::object_ptr<td_api::draftMessage> get_draft_message_object(Td *td,
                                                                  const unique_ptr<DraftMessage> &draft_message);

unique_ptr<DraftMessage> get_draft_message(Td *td,
                                           telegram_api::object_ptr<telegram_api::DraftMessage> &&draft_message_ptr);

void save_draft_message(Td *td, DialogId dialog_id, const unique_ptr<DraftMessage> &draft_message,
                        Promise<Unit> &&promise);

void load_all_draft_messages(Td *td);

void clear_all_draft_messages(Td *td, Promise<Unit> &&promise);

}  // namespace td
