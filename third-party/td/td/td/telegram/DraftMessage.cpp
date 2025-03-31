//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DraftMessage.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageSelfDestructType.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/tl_helpers.h"

namespace td {

class SaveDraftMessageQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit SaveDraftMessageQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const unique_ptr<DraftMessage> &draft_message) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      LOG(INFO) << "Can't update draft message because have no write access to " << dialog_id;
      return on_error(Status::Error(400, "PEER_ID_INVALID"));
    }

    int32 flags = 0;
    telegram_api::object_ptr<telegram_api::InputReplyTo> input_reply_to;
    vector<telegram_api::object_ptr<telegram_api::MessageEntity>> input_message_entities;
    telegram_api::object_ptr<telegram_api::InputMedia> media;
    int64 message_effect_id = 0;
    if (draft_message != nullptr) {
      CHECK(!draft_message->is_local());
      input_reply_to = draft_message->message_input_reply_to_.get_input_reply_to(td_, MessageId() /*TODO*/);
      if (input_reply_to != nullptr) {
        flags |= telegram_api::messages_saveDraft::REPLY_TO_MASK;
      }
      if (draft_message->input_message_text_.disable_web_page_preview) {
        flags |= telegram_api::messages_saveDraft::NO_WEBPAGE_MASK;
      } else if (draft_message->input_message_text_.show_above_text) {
        flags |= telegram_api::messages_saveDraft::INVERT_MEDIA_MASK;
      }
      input_message_entities = get_input_message_entities(
          td_->user_manager_.get(), draft_message->input_message_text_.text.entities, "SaveDraftMessageQuery");
      if (!input_message_entities.empty()) {
        flags |= telegram_api::messages_saveDraft::ENTITIES_MASK;
      }
      media = draft_message->input_message_text_.get_input_media_web_page();
      if (media != nullptr) {
        flags |= telegram_api::messages_saveDraft::MEDIA_MASK;
      }
      if (draft_message->message_effect_id_.is_valid()) {
        flags |= telegram_api::messages_saveDraft::EFFECT_MASK;
        message_effect_id = draft_message->message_effect_id_.get();
      }
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_saveDraft(
            flags, false /*ignored*/, false /*ignored*/, std::move(input_reply_to), std::move(input_peer),
            draft_message == nullptr ? string() : draft_message->input_message_text_.text.text,
            std::move(input_message_entities), std::move(media), message_effect_id),
        {{dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_saveDraft>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      return on_error(Status::Error(400, "Save draft failed"));
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.message() == "TOPIC_CLOSED") {
      // when the draft is a reply to a message in a closed topic, server will not allow to save it
      // with the error "TOPIC_CLOSED", but the draft will be kept locally
      return promise_.set_value(Unit());
    }
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SaveDraftMessageQuery") &&
        status.message() != "PEER_ID_INVALID") {
      LOG(ERROR) << "Receive error for SaveDraftMessageQuery: " << status;
    }
    promise_.set_error(std::move(status));
  }
};

class GetAllDraftsQuery final : public Td::ResultHandler {
 public:
  void send() {
    send_query(G()->net_query_creator().create(telegram_api::messages_getAllDrafts()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getAllDrafts>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetAllDraftsQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), Promise<Unit>());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for GetAllDraftsQuery: " << status;
    }
    status.ignore();
  }
};

class ClearAllDraftsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ClearAllDraftsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::messages_clearAllDrafts()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_clearAllDrafts>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(INFO) << "Receive result for ClearAllDraftsQuery: " << result_ptr.ok();
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for ClearAllDraftsQuery: " << status;
    }
    promise_.set_error(std::move(status));
  }
};

class DraftMessageContentVideoNote final : public DraftMessageContent {
 public:
  string path_;
  int32 duration_ = 0;
  int32 length_ = 0;
  MessageSelfDestructType ttl_;

  DraftMessageContentVideoNote() = default;

  DraftMessageContentVideoNote(string &&path, int32 duration, int32 length, MessageSelfDestructType ttl)
      : path_(std::move(path)), duration_(duration), length_(length), ttl_(ttl) {
  }

  DraftMessageContentType get_type() const final {
    return DraftMessageContentType::VideoNote;
  }

  td_api::object_ptr<td_api::InputMessageContent> get_draft_input_message_content_object() const final {
    return td_api::make_object<td_api::inputMessageVideoNote>(td_api::make_object<td_api::inputFileLocal>(path_),
                                                              nullptr, duration_, length_,
                                                              ttl_.get_message_self_destruct_type_object());
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    bool has_path = !path_.empty();
    bool has_duration = duration_ != 0;
    bool has_length = length_ != 0;
    bool has_ttl = ttl_.is_valid();
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_path);
    STORE_FLAG(has_duration);
    STORE_FLAG(has_length);
    STORE_FLAG(has_ttl);
    END_STORE_FLAGS();
    if (has_path) {
      td::store(path_, storer);
    }
    if (has_duration) {
      td::store(duration_, storer);
    }
    if (has_length) {
      td::store(length_, storer);
    }
    if (has_ttl) {
      td::store(ttl_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    bool has_path;
    bool has_duration;
    bool has_length;
    bool has_ttl;
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_path);
    PARSE_FLAG(has_duration);
    PARSE_FLAG(has_length);
    PARSE_FLAG(has_ttl);
    END_PARSE_FLAGS();
    if (has_path) {
      td::parse(path_, parser);
    }
    if (has_duration) {
      td::parse(duration_, parser);
    }
    if (has_length) {
      td::parse(length_, parser);
    }
    if (has_ttl) {
      td::parse(ttl_, parser);
    }
  }
};

class DraftMessageContentVoiceNote final : public DraftMessageContent {
 public:
  string path_;
  int32 duration_ = 0;
  string waveform_;
  MessageSelfDestructType ttl_;

  DraftMessageContentVoiceNote() = default;

  DraftMessageContentVoiceNote(string &&path, int32 duration, string &&waveform, MessageSelfDestructType ttl)
      : path_(std::move(path)), duration_(duration), waveform_(std::move(waveform)), ttl_(ttl) {
  }

  DraftMessageContentType get_type() const final {
    return DraftMessageContentType::VoiceNote;
  }

  td_api::object_ptr<td_api::InputMessageContent> get_draft_input_message_content_object() const final {
    return td_api::make_object<td_api::inputMessageVoiceNote>(td_api::make_object<td_api::inputFileLocal>(path_),
                                                              duration_, waveform_, nullptr,
                                                              ttl_.get_message_self_destruct_type_object());
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    bool has_path = !path_.empty();
    bool has_duration = duration_ != 0;
    bool has_waveform = !waveform_.empty();
    bool has_ttl = ttl_.is_valid();
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_path);
    STORE_FLAG(has_duration);
    STORE_FLAG(has_waveform);
    STORE_FLAG(has_ttl);
    END_STORE_FLAGS();
    if (has_path) {
      td::store(path_, storer);
    }
    if (has_duration) {
      td::store(duration_, storer);
    }
    if (has_waveform) {
      td::store(waveform_, storer);
    }
    if (has_ttl) {
      td::store(ttl_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    bool has_path;
    bool has_duration;
    bool has_waveform;
    bool has_ttl;
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_path);
    PARSE_FLAG(has_duration);
    PARSE_FLAG(has_waveform);
    PARSE_FLAG(has_ttl);
    END_PARSE_FLAGS();
    if (has_path) {
      td::parse(path_, parser);
    }
    if (has_duration) {
      td::parse(duration_, parser);
    }
    if (has_waveform) {
      td::parse(waveform_, parser);
    }
    if (has_ttl) {
      td::parse(ttl_, parser);
    }
  }
};

template <class StorerT>
static void store(const DraftMessageContent *content, StorerT &storer) {
  CHECK(content != nullptr);

  auto content_type = content->get_type();
  store(content_type, storer);

  switch (content_type) {
    case DraftMessageContentType::VideoNote: {
      const auto *video_note = static_cast<const DraftMessageContentVideoNote *>(content);
      video_note->store(storer);
      break;
    }
    case DraftMessageContentType::VoiceNote: {
      const auto *voice_note = static_cast<const DraftMessageContentVoiceNote *>(content);
      voice_note->store(storer);
      break;
    }
    default:
      UNREACHABLE();
  }
}

void store_draft_message_content(const DraftMessageContent *content, LogEventStorerCalcLength &storer) {
  store(content, storer);
}

void store_draft_message_content(const DraftMessageContent *content, LogEventStorerUnsafe &storer) {
  store(content, storer);
}

void parse_draft_message_content(unique_ptr<DraftMessageContent> &content, LogEventParser &parser) {
  DraftMessageContentType type;
  parse(type, parser);
  switch (type) {
    case DraftMessageContentType::VideoNote: {
      unique_ptr<DraftMessageContentVideoNote> video_note;
      parse(video_note, parser);
      content = std::move(video_note);
      break;
    }
    case DraftMessageContentType::VoiceNote: {
      unique_ptr<DraftMessageContentVoiceNote> voice_note;
      parse(voice_note, parser);
      content = std::move(voice_note);
      break;
    }
    default:
      parser.set_error("Wrong draft content type");
  }
}

DraftMessage::DraftMessage() = default;

DraftMessage::~DraftMessage() = default;

bool DraftMessage::need_clear_local(MessageContentType content_type) const {
  if (!is_local()) {
    return false;
  }
  switch (local_content_->get_type()) {
    case DraftMessageContentType::VideoNote:
      return content_type == MessageContentType::VideoNote;
    case DraftMessageContentType::VoiceNote:
      return content_type == MessageContentType::VoiceNote;
    default:
      UNREACHABLE();
      return false;
  }
}

bool DraftMessage::need_update_to(const DraftMessage &other, bool from_update) const {
  if (is_local()) {
    return !from_update || other.is_local();
  }
  if (message_input_reply_to_ == other.message_input_reply_to_ && input_message_text_ == other.input_message_text_ &&
      message_effect_id_ == other.message_effect_id_) {
    return date_ < other.date_;
  } else {
    return !from_update || date_ <= other.date_;
  }
}

void DraftMessage::add_dependencies(Dependencies &dependencies) const {
  message_input_reply_to_.add_dependencies(dependencies);
  input_message_text_.add_dependencies(dependencies);
}

td_api::object_ptr<td_api::draftMessage> DraftMessage::get_draft_message_object(Td *td) const {
  td_api::object_ptr<td_api::InputMessageContent> input_message_content;
  if (local_content_ != nullptr) {
    input_message_content = local_content_->get_draft_input_message_content_object();
  } else {
    input_message_content = input_message_text_.get_input_message_text_object(td->user_manager_.get());
  }
  return td_api::make_object<td_api::draftMessage>(message_input_reply_to_.get_input_message_reply_to_object(td), date_,
                                                   std::move(input_message_content), message_effect_id_.get());
}

DraftMessage::DraftMessage(Td *td, telegram_api::object_ptr<telegram_api::draftMessage> &&draft_message) {
  CHECK(draft_message != nullptr);
  date_ = draft_message->date_;
  message_input_reply_to_ = MessageInputReplyTo(td, std::move(draft_message->reply_to_));
  auto draft_text = get_formatted_text(td->user_manager_.get(), std::move(draft_message->message_),
                                       std::move(draft_message->entities_), true, true, "DraftMessage");
  string web_page_url;
  bool force_small_media = false;
  bool force_large_media = false;
  if (draft_message->media_ != nullptr) {
    if (draft_message->media_->get_id() != telegram_api::inputMediaWebPage::ID) {
      LOG(ERROR) << "Receive draft message with " << to_string(draft_message->media_);
    } else {
      auto media = telegram_api::move_object_as<telegram_api::inputMediaWebPage>(draft_message->media_);
      web_page_url = std::move(media->url_);
      if (web_page_url.empty()) {
        LOG(ERROR) << "Have no URL in a draft with manual link preview";
      }
      force_small_media = media->force_small_media_;
      force_large_media = media->force_large_media_;
    }
  }
  input_message_text_ = InputMessageText(std::move(draft_text), std::move(web_page_url), draft_message->no_webpage_,
                                         force_small_media, force_large_media, draft_message->invert_media_, false);
  message_effect_id_ = MessageEffectId(draft_message->effect_);
}

Result<unique_ptr<DraftMessage>> DraftMessage::get_draft_message(
    Td *td, DialogId dialog_id, MessageId top_thread_message_id,
    td_api::object_ptr<td_api::draftMessage> &&draft_message) {
  if (draft_message == nullptr) {
    return nullptr;
  }

  auto result = make_unique<DraftMessage>();
  result->message_input_reply_to_ = td->messages_manager_->create_message_input_reply_to(
      dialog_id, top_thread_message_id, std::move(draft_message->reply_to_), true);
  result->message_effect_id_ = MessageEffectId(draft_message->effect_id_);

  auto input_message_content = std::move(draft_message->input_message_text_);
  if (input_message_content != nullptr) {
    switch (input_message_content->get_id()) {
      case td_api::inputMessageText::ID: {
        TRY_RESULT(input_message_text,
                   process_input_message_text(td, dialog_id, std::move(input_message_content), false, true));
        result->input_message_text_ = std::move(input_message_text);
        break;
      }
      case td_api::inputMessageVideoNote::ID: {
        auto video_note = td_api::move_object_as<td_api::inputMessageVideoNote>(input_message_content);
        if (video_note->video_note_ == nullptr || video_note->video_note_->get_id() != td_api::inputFileLocal::ID) {
          return Status::Error(400, "Invalid video message file specified");
        }
        TRY_RESULT(ttl,
                   MessageSelfDestructType::get_message_self_destruct_type(std::move(video_note->self_destruct_type_)));
        result->local_content_ = td::make_unique<DraftMessageContentVideoNote>(
            std::move(static_cast<td_api::inputFileLocal *>(video_note->video_note_.get())->path_),
            video_note->duration_, video_note->length_, ttl);
        break;
      }
      case td_api::inputMessageVoiceNote::ID: {
        auto voice_note = td_api::move_object_as<td_api::inputMessageVoiceNote>(input_message_content);
        if (voice_note->voice_note_ == nullptr || voice_note->voice_note_->get_id() != td_api::inputFileLocal::ID) {
          return Status::Error(400, "Invalid voice message file specified");
        }
        TRY_RESULT(ttl,
                   MessageSelfDestructType::get_message_self_destruct_type(std::move(voice_note->self_destruct_type_)));
        result->local_content_ = td::make_unique<DraftMessageContentVoiceNote>(
            std::move(static_cast<td_api::inputFileLocal *>(voice_note->voice_note_.get())->path_),
            voice_note->duration_, std::move(voice_note->waveform_), ttl);
        break;
      }
      default:
        return Status::Error(400, "Input message content type must be InputMessageText");
    }
  }

  if (!result->message_input_reply_to_.is_valid() && result->input_message_text_.is_empty() &&
      result->local_content_ == nullptr) {
    return nullptr;
  }

  result->date_ = G()->unix_time();
  return std::move(result);
}

bool is_local_draft_message(const unique_ptr<DraftMessage> &draft_message) {
  if (draft_message == nullptr) {
    return false;
  }
  return draft_message->is_local();
}

bool need_update_draft_message(const unique_ptr<DraftMessage> &old_draft_message,
                               const unique_ptr<DraftMessage> &new_draft_message, bool from_update) {
  if (new_draft_message == nullptr) {
    return old_draft_message != nullptr;
  }
  if (old_draft_message == nullptr) {
    return true;
  }
  return old_draft_message->need_update_to(*new_draft_message, from_update);
}

void add_draft_message_dependencies(Dependencies &dependencies, const unique_ptr<DraftMessage> &draft_message) {
  if (draft_message == nullptr) {
    return;
  }
  draft_message->add_dependencies(dependencies);
}

td_api::object_ptr<td_api::draftMessage> get_draft_message_object(Td *td,
                                                                  const unique_ptr<DraftMessage> &draft_message) {
  if (draft_message == nullptr) {
    return nullptr;
  }
  return draft_message->get_draft_message_object(td);
}

unique_ptr<DraftMessage> get_draft_message(Td *td,
                                           telegram_api::object_ptr<telegram_api::DraftMessage> &&draft_message_ptr) {
  if (draft_message_ptr == nullptr) {
    return nullptr;
  }
  switch (draft_message_ptr->get_id()) {
    case telegram_api::draftMessageEmpty::ID:
      return nullptr;
    case telegram_api::draftMessage::ID:
      return td::make_unique<DraftMessage>(td,
                                           telegram_api::move_object_as<telegram_api::draftMessage>(draft_message_ptr));
    default:
      UNREACHABLE();
      return nullptr;
  }
}

void save_draft_message(Td *td, DialogId dialog_id, const unique_ptr<DraftMessage> &draft_message,
                        Promise<Unit> &&promise) {
  td->create_handler<SaveDraftMessageQuery>(std::move(promise))->send(dialog_id, draft_message);
}

void load_all_draft_messages(Td *td) {
  td->create_handler<GetAllDraftsQuery>()->send();
}

void clear_all_draft_messages(Td *td, Promise<Unit> &&promise) {
  td->create_handler<ClearAllDraftsQuery>(std::move(promise))->send();
}

}  // namespace td
