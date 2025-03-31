//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/TranscriptionInfo.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"

namespace td {

class TranscribeAudioQuery final : public Td::ResultHandler {
  DialogId dialog_id_;
  std::function<void(Result<telegram_api::object_ptr<telegram_api::messages_transcribedAudio>>)> handler_;

 public:
  void send(MessageFullId message_full_id,
            std::function<void(Result<telegram_api::object_ptr<telegram_api::messages_transcribedAudio>>)> &&handler) {
    dialog_id_ = message_full_id.get_dialog_id();
    handler_ = std::move(handler);
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    auto query = G()->net_query_creator().create(telegram_api::messages_transcribeAudio(
        std::move(input_peer), message_full_id.get_message_id().get_server_message_id().get()));
    query->total_timeout_limit_ = 8;
    send_query(std::move(query));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_transcribeAudio>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for TranscribeAudioQuery: " << to_string(result);
    handler_(std::move(result));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "TranscribeAudioQuery");
    handler_(std::move(status));
  }
};

class RateTranscribedAudioQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit RateTranscribedAudioQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(MessageFullId message_full_id, int64 transcription_id, bool is_good) {
    dialog_id_ = message_full_id.get_dialog_id();
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_rateTranscribedAudio(
        std::move(input_peer), message_full_id.get_message_id().get_server_message_id().get(), transcription_id,
        is_good)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_rateTranscribedAudio>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(INFO) << "Receive result for RateTranscribedAudioQuery: " << result;
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "RateTranscribedAudioQuery");
    promise_.set_error(std::move(status));
  }
};

bool TranscriptionInfo::recognize_speech(
    Td *td, MessageFullId message_full_id, Promise<Unit> &&promise,
    std::function<void(Result<telegram_api::object_ptr<telegram_api::messages_transcribedAudio>>)> &&handler) {
  if (is_transcribed_) {
    promise.set_value(Unit());
    return false;
  }
  speech_recognition_queries_.push_back(std::move(promise));
  if (speech_recognition_queries_.size() == 1) {
    last_transcription_error_ = Status::OK();
    td->create_handler<TranscribeAudioQuery>()->send(message_full_id, std::move(handler));
    return true;
  }
  return false;
}

vector<Promise<Unit>> TranscriptionInfo::on_final_transcription(string &&text, int64 transcription_id) {
  CHECK(!is_transcribed_);
  CHECK(transcription_id_ == 0 || transcription_id_ == transcription_id);
  CHECK(transcription_id != 0);
  transcription_id_ = transcription_id;
  is_transcribed_ = true;
  text_ = std::move(text);
  last_transcription_error_ = Status::OK();

  CHECK(!speech_recognition_queries_.empty());
  auto promises = std::move(speech_recognition_queries_);
  speech_recognition_queries_.clear();

  return promises;
}

bool TranscriptionInfo::on_partial_transcription(string &&text, int64 transcription_id) {
  CHECK(!is_transcribed_);
  CHECK(transcription_id_ == 0 || transcription_id_ == transcription_id);
  CHECK(transcription_id != 0);
  bool is_changed = text_ != text;
  transcription_id_ = transcription_id;
  text_ = std::move(text);
  last_transcription_error_ = Status::OK();

  return is_changed;
}

vector<Promise<Unit>> TranscriptionInfo::on_failed_transcription(Status &&error) {
  CHECK(!is_transcribed_);
  transcription_id_ = 0;
  text_.clear();
  last_transcription_error_ = std::move(error);

  CHECK(!speech_recognition_queries_.empty());
  auto promises = std::move(speech_recognition_queries_);
  speech_recognition_queries_.clear();
  return promises;
}

void TranscriptionInfo::rate_speech_recognition(Td *td, MessageFullId message_full_id, bool is_good,
                                                Promise<Unit> &&promise) const {
  if (!is_transcribed_) {
    return promise.set_value(Unit());
  }
  CHECK(transcription_id_ != 0);
  td->create_handler<RateTranscribedAudioQuery>(std::move(promise))->send(message_full_id, transcription_id_, is_good);
}

unique_ptr<TranscriptionInfo> TranscriptionInfo::copy_if_transcribed(const unique_ptr<TranscriptionInfo> &info) {
  if (info == nullptr || !info->is_transcribed_) {
    return nullptr;
  }
  auto result = make_unique<TranscriptionInfo>();
  result->is_transcribed_ = true;
  result->transcription_id_ = info->transcription_id_;
  result->text_ = info->text_;
  return result;
}

bool TranscriptionInfo::update_from(unique_ptr<TranscriptionInfo> &old_info, unique_ptr<TranscriptionInfo> &&new_info) {
  if (new_info == nullptr || !new_info->is_transcribed_) {
    return false;
  }
  CHECK(new_info->transcription_id_ != 0);
  CHECK(new_info->last_transcription_error_.is_ok());
  CHECK(new_info->speech_recognition_queries_.empty());
  if (old_info == nullptr) {
    old_info = std::move(new_info);
    return true;
  }
  if (old_info->transcription_id_ != 0 || !old_info->speech_recognition_queries_.empty()) {
    return false;
  }
  CHECK(!old_info->is_transcribed_);
  old_info = std::move(new_info);
  return true;
}

td_api::object_ptr<td_api::SpeechRecognitionResult> TranscriptionInfo::get_speech_recognition_result_object() const {
  if (is_transcribed_) {
    return td_api::make_object<td_api::speechRecognitionResultText>(text_);
  }
  if (!speech_recognition_queries_.empty()) {
    return td_api::make_object<td_api::speechRecognitionResultPending>(text_);
  }
  if (last_transcription_error_.is_error()) {
    return td_api::make_object<td_api::speechRecognitionResultError>(td_api::make_object<td_api::error>(
        last_transcription_error_.code(), last_transcription_error_.message().str()));
  }
  return nullptr;
}

}  // namespace td
