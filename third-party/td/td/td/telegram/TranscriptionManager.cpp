//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/TranscriptionManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/VideoNotesManager.h"
#include "td/telegram/VoiceNotesManager.h"

#include "td/utils/logging.h"
#include "td/utils/tl_helpers.h"

namespace td {

void TranscriptionManager::TrialParameters::update_left_tries() {
  if (next_reset_date_ <= G()->unix_time()) {
    next_reset_date_ = 0;
    left_tries_ = weekly_number_;
  } else if (left_tries_ > weekly_number_) {
    left_tries_ = weekly_number_;
  }
}

template <class StorerT>
void TranscriptionManager::TrialParameters::store(StorerT &storer) const {
  bool has_weekly_number = weekly_number_ != 0;
  bool has_duration_max = duration_max_ != 0;
  bool has_left_tries = left_tries_ != 0;
  bool has_next_reset_date = next_reset_date_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_weekly_number);
  STORE_FLAG(has_duration_max);
  STORE_FLAG(has_left_tries);
  STORE_FLAG(has_next_reset_date);
  END_STORE_FLAGS();
  if (has_weekly_number) {
    td::store(weekly_number_, storer);
  }
  if (has_duration_max) {
    td::store(duration_max_, storer);
  }
  if (has_left_tries) {
    td::store(left_tries_, storer);
  }
  if (has_next_reset_date) {
    td::store(next_reset_date_, storer);
  }
}

template <class ParserT>
void TranscriptionManager::TrialParameters::parse(ParserT &parser) {
  bool has_weekly_number;
  bool has_duration_max;
  bool has_left_tries;
  bool has_next_reset_date;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_weekly_number);
  PARSE_FLAG(has_duration_max);
  PARSE_FLAG(has_left_tries);
  PARSE_FLAG(has_next_reset_date);
  END_PARSE_FLAGS();
  if (has_weekly_number) {
    td::parse(weekly_number_, parser);
  }
  if (has_duration_max) {
    td::parse(duration_max_, parser);
  }
  if (has_left_tries) {
    td::parse(left_tries_, parser);
  }
  if (has_next_reset_date) {
    td::parse(next_reset_date_, parser);
  }
}

bool operator==(const TranscriptionManager::TrialParameters &lhs, const TranscriptionManager::TrialParameters &rhs) {
  return lhs.weekly_number_ == rhs.weekly_number_ && lhs.duration_max_ == rhs.duration_max_ &&
         lhs.left_tries_ == rhs.left_tries_ && lhs.next_reset_date_ == rhs.next_reset_date_;
}

TranscriptionManager::TranscriptionManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  load_trial_parameters();

  pending_audio_transcription_timeout_.set_callback(on_pending_audio_transcription_timeout_callback);
  pending_audio_transcription_timeout_.set_callback_data(static_cast<void *>(td_));
}

TranscriptionManager::~TranscriptionManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), voice_messages_, message_file_ids_);
}

void TranscriptionManager::tear_down() {
  parent_.reset();
}

void TranscriptionManager::on_pending_audio_transcription_timeout_callback(void *td, int64 transcription_id) {
  if (G()->close_flag()) {
    return;
  }
  CHECK(td != nullptr);
  if (!static_cast<Td *>(td)->auth_manager_->is_authorized()) {
    return;
  }

  auto transcription_manager = static_cast<Td *>(td)->transcription_manager_.get();
  send_closure_later(transcription_manager->actor_id(transcription_manager),
                     &TranscriptionManager::on_pending_audio_transcription_failed, transcription_id,
                     Status::Error(500, "Timeout expired"));
}

string TranscriptionManager::get_trial_parameters_database_key() {
  return "speech_recognition_trial";
}

void TranscriptionManager::load_trial_parameters() {
  if (!td_->auth_manager_->is_authorized() || td_->auth_manager_->is_bot()) {
    return;
  }

  auto log_event_string = G()->td_db()->get_binlog_pmc()->get(get_trial_parameters_database_key());
  if (!log_event_string.empty()) {
    auto status = log_event_parse(trial_parameters_, log_event_string);
    if (status.is_ok()) {
      trial_parameters_.update_left_tries();
    } else {
      LOG(ERROR) << "Failed to parse speech recognition trial parameters from binlog: " << status;
      trial_parameters_ = TrialParameters();
      save_trial_parameters();
    }
  }
  send_update_speech_recognition_trial();
  set_speech_recognition_trial_timeout();
}

void TranscriptionManager::save_trial_parameters() {
  G()->td_db()->get_binlog_pmc()->set(get_trial_parameters_database_key(),
                                      log_event_store(trial_parameters_).as_slice().str());
}

void TranscriptionManager::on_update_trial_parameters(int32 weekly_number, int32 duration_max, int32 cooldown_until) {
  if (!td_->auth_manager_->is_authorized()) {
    return;
  }
  CHECK(!td_->auth_manager_->is_bot());
  TrialParameters new_trial_parameters;
  new_trial_parameters.weekly_number_ = max(0, weekly_number);
  new_trial_parameters.duration_max_ = max(0, duration_max);
  new_trial_parameters.next_reset_date_ = cooldown_until > 0 ? cooldown_until : trial_parameters_.next_reset_date_;
  new_trial_parameters.left_tries_ = trial_parameters_.left_tries_;
  set_trial_parameters(new_trial_parameters);
}

void TranscriptionManager::set_trial_parameters(TrialParameters new_trial_parameters) {
  new_trial_parameters.update_left_tries();
  if (new_trial_parameters == trial_parameters_) {
    return;
  }

  trial_parameters_ = std::move(new_trial_parameters);
  send_update_speech_recognition_trial();
  set_speech_recognition_trial_timeout();
  save_trial_parameters();
}

void TranscriptionManager::set_speech_recognition_trial_timeout() {
  if (trial_parameters_.next_reset_date_ == 0) {
    trial_parameters_timeout_.cancel_timeout();
  } else {
    trial_parameters_timeout_.set_callback(std::move(trial_parameters_timeout_static));
    trial_parameters_timeout_.set_callback_data(static_cast<void *>(td_));
    trial_parameters_timeout_.set_timeout_in(trial_parameters_.next_reset_date_ - G()->unix_time() + 1);
  }
}

void TranscriptionManager::trial_parameters_timeout_static(void *td) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(td != nullptr);
  static_cast<Td *>(td)->transcription_manager_->on_trial_parameters_timeout();
}

void TranscriptionManager::on_trial_parameters_timeout() {
  if (!td_->auth_manager_->is_authorized()) {
    return;
  }
  CHECK(!td_->auth_manager_->is_bot());
  set_trial_parameters(trial_parameters_);
}

void TranscriptionManager::send_update_speech_recognition_trial() const {
  send_closure(G()->td(), &Td::send_update, get_update_speech_recognition_trial_object());
}

td_api::object_ptr<td_api::updateSpeechRecognitionTrial>
TranscriptionManager::get_update_speech_recognition_trial_object() const {
  CHECK(td_->auth_manager_->is_authorized());
  CHECK(!td_->auth_manager_->is_bot());
  return trial_parameters_.get_update_speech_recognition_trial_object();
}

td_api::object_ptr<td_api::updateSpeechRecognitionTrial>
TranscriptionManager::TrialParameters::get_update_speech_recognition_trial_object() const {
  return td_api::make_object<td_api::updateSpeechRecognitionTrial>(duration_max_, weekly_number_, left_tries_,
                                                                   next_reset_date_);
}

void TranscriptionManager::register_voice(FileId file_id, MessageContentType content_type,
                                          MessageFullId message_full_id, const char *source) {
  if (td_->auth_manager_->is_bot() || message_full_id.get_message_id().is_scheduled() ||
      !message_full_id.get_message_id().is_server() ||
      message_full_id.get_dialog_id().get_type() == DialogType::SecretChat) {
    return;
  }
  LOG(INFO) << "Register voice " << file_id << " from " << message_full_id << " from " << source;
  CHECK(file_id.is_valid());
  bool is_inserted = voice_messages_[file_id].emplace(message_full_id).second;
  LOG_CHECK(is_inserted) << source << ' ' << file_id << ' ' << message_full_id;
  is_inserted = message_file_ids_.emplace(message_full_id, FileInfo(content_type, file_id)).second;
  CHECK(is_inserted);
}

void TranscriptionManager::unregister_voice(FileId file_id, MessageContentType content_type,
                                            MessageFullId message_full_id, const char *source) {
  if (td_->auth_manager_->is_bot() || message_full_id.get_message_id().is_scheduled() ||
      !message_full_id.get_message_id().is_server() ||
      message_full_id.get_dialog_id().get_type() == DialogType::SecretChat) {
    return;
  }
  LOG(INFO) << "Unregister voice " << file_id << " from " << message_full_id << " from " << source;
  CHECK(file_id.is_valid());
  auto &message_full_ids = voice_messages_[file_id];
  auto is_deleted = message_full_ids.erase(message_full_id) > 0;
  LOG_CHECK(is_deleted) << source << ' ' << file_id << ' ' << message_full_id;
  if (message_full_ids.empty()) {
    voice_messages_.erase(file_id);
  }
  is_deleted = message_file_ids_.erase(message_full_id) > 0;
  CHECK(is_deleted);
}

TranscriptionInfo *TranscriptionManager::get_transcription_info(const FileInfo &file_info, bool allow_creation) {
  switch (file_info.first) {
    case MessageContentType::VideoNote:
      return td_->video_notes_manager_->get_video_note_transcription_info(file_info.second, allow_creation);
    case MessageContentType::VoiceNote:
      return td_->voice_notes_manager_->get_voice_note_transcription_info(file_info.second, allow_creation);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

void TranscriptionManager::recognize_speech(MessageFullId message_full_id, Promise<Unit> &&promise) {
  if (!td_->messages_manager_->have_message_force(message_full_id, "recognize_speech")) {
    return promise.set_error(Status::Error(400, "Message not found"));
  }

  auto it = message_file_ids_.find(message_full_id);
  if (it == message_file_ids_.end()) {
    return promise.set_error(Status::Error(400, "Message can't be transcribed"));
  }

  auto *transcription_info = get_transcription_info(it->second, true);
  auto handler = [actor_id = actor_id(this), file_info = it->second](
                     Result<telegram_api::object_ptr<telegram_api::messages_transcribedAudio>> r_audio) {
    send_closure(actor_id, &TranscriptionManager::on_transcribed_audio, file_info, std::move(r_audio));
  };
  if (transcription_info->recognize_speech(td_, message_full_id, std::move(promise), std::move(handler))) {
    on_transcription_updated(it->second.second);
  }
}

void TranscriptionManager::on_transcribed_audio(
    FileInfo file_info, Result<telegram_api::object_ptr<telegram_api::messages_transcribedAudio>> r_audio) {
  if (G()->close_flag() || !td_->auth_manager_->is_authorized()) {
    return;
  }
  if (r_audio.is_error()) {
    auto retry_after = Global::get_retry_after(r_audio.error());
    on_transcribed_audio_update(file_info, true, r_audio.move_as_error());
    if (retry_after > 0 && trial_parameters_.left_tries_ > 0) {
      TrialParameters new_trial_parameters = trial_parameters_;
      new_trial_parameters.next_reset_date_ = G()->unix_time() + retry_after;
      new_trial_parameters.left_tries_ = 0;
      set_trial_parameters(new_trial_parameters);
    }
    return;
  }
  auto audio = r_audio.move_as_ok();
  if (audio->transcription_id_ == 0) {
    return on_transcribed_audio_update(file_info, true, Status::Error(500, "Receive no transcription identifier"));
  }
  auto update = telegram_api::make_object<telegram_api::updateTranscribedAudio>();
  update->text_ = std::move(audio->text_);
  update->transcription_id_ = audio->transcription_id_;
  update->pending_ = audio->pending_;
  on_transcribed_audio_update(file_info, true, std::move(update));

  if ((audio->flags_ & telegram_api::messages_transcribedAudio::TRIAL_REMAINS_NUM_MASK) != 0) {
    TrialParameters new_trial_parameters = trial_parameters_;
    new_trial_parameters.next_reset_date_ = max(0, audio->trial_remains_until_date_);
    new_trial_parameters.left_tries_ = audio->trial_remains_num_;
    set_trial_parameters(new_trial_parameters);
  }
}

void TranscriptionManager::on_transcribed_audio_update(
    FileInfo file_info, bool is_initial,
    Result<telegram_api::object_ptr<telegram_api::updateTranscribedAudio>> r_update) {
  if (G()->close_flag() || !td_->auth_manager_->is_authorized()) {
    return;
  }

  auto *transcription_info = get_transcription_info(file_info, false);
  CHECK(transcription_info != nullptr);
  if (r_update.is_error()) {
    auto promises = transcription_info->on_failed_transcription(r_update.move_as_error());
    on_transcription_updated(file_info.second);
    set_promises(promises);
    return;
  }
  auto update = r_update.move_as_ok();
  auto transcription_id = update->transcription_id_;
  if (!update->pending_) {
    auto promises = transcription_info->on_final_transcription(std::move(update->text_), transcription_id);
    on_transcription_completed(file_info.second);
    set_promises(promises);
  } else {
    auto is_changed = transcription_info->on_partial_transcription(std::move(update->text_), transcription_id);
    if (is_changed) {
      on_transcription_updated(file_info.second);
    }

    if (is_initial) {
      subscribe_to_transcribed_audio_updates(
          transcription_id, [actor_id = actor_id(this), file_info](
                                Result<telegram_api::object_ptr<telegram_api::updateTranscribedAudio>> r_update) {
            send_closure(actor_id, &TranscriptionManager::on_transcribed_audio_update, file_info, false,
                         std::move(r_update));
          });
    }
  }
}

void TranscriptionManager::on_transcription_updated(FileId file_id) {
  auto it = voice_messages_.find(file_id);
  if (it != voice_messages_.end()) {
    for (const auto &message_full_id : it->second) {
      td_->messages_manager_->on_external_update_message_content(message_full_id, "on_transcription_updated");
    }
  }
}

void TranscriptionManager::on_transcription_completed(FileId file_id) {
  auto it = voice_messages_.find(file_id);
  if (it != voice_messages_.end()) {
    for (const auto &message_full_id : it->second) {
      td_->messages_manager_->on_update_message_content(message_full_id);
    }
  }
}

void TranscriptionManager::rate_speech_recognition(MessageFullId message_full_id, bool is_good,
                                                   Promise<Unit> &&promise) {
  if (!td_->messages_manager_->have_message_force(message_full_id, "rate_speech_recognition")) {
    return promise.set_error(Status::Error(400, "Message not found"));
  }

  auto it = message_file_ids_.find(message_full_id);
  if (it == message_file_ids_.end()) {
    return promise.set_error(Status::Error(400, "Message can't be transcribed"));
  }

  const auto *transcription_info = get_transcription_info(it->second, false);
  if (transcription_info == nullptr) {
    return promise.set_value(Unit());
  }
  transcription_info->rate_speech_recognition(td_, message_full_id, is_good, std::move(promise));
}

void TranscriptionManager::subscribe_to_transcribed_audio_updates(int64 transcription_id,
                                                                  TranscribedAudioHandler on_update) {
  CHECK(transcription_id != 0);
  if (pending_audio_transcriptions_.count(transcription_id) != 0) {
    on_pending_audio_transcription_failed(transcription_id,
                                          Status::Error(500, "Receive duplicate speech recognition identifier"));
  }
  bool is_inserted = pending_audio_transcriptions_.emplace(transcription_id, std::move(on_update)).second;
  CHECK(is_inserted);
  pending_audio_transcription_timeout_.set_timeout_in(transcription_id, AUDIO_TRANSCRIPTION_TIMEOUT);
}

void TranscriptionManager::on_update_transcribed_audio(
    telegram_api::object_ptr<telegram_api::updateTranscribedAudio> &&update) {
  auto it = pending_audio_transcriptions_.find(update->transcription_id_);
  if (it == pending_audio_transcriptions_.end()) {
    return;
  }
  // flags_, peer_ and msg_id_ must not be used
  if (!update->pending_) {
    auto on_update = std::move(it->second);
    pending_audio_transcriptions_.erase(it);
    pending_audio_transcription_timeout_.cancel_timeout(update->transcription_id_);
    on_update(std::move(update));
  } else {
    it->second(std::move(update));
  }
}

void TranscriptionManager::on_pending_audio_transcription_failed(int64 transcription_id, Status &&error) {
  if (G()->close_flag()) {
    return;
  }
  auto it = pending_audio_transcriptions_.find(transcription_id);
  if (it == pending_audio_transcriptions_.end()) {
    return;
  }
  auto on_update = std::move(it->second);
  pending_audio_transcriptions_.erase(it);
  pending_audio_transcription_timeout_.cancel_timeout(transcription_id);

  on_update(std::move(error));
}

void TranscriptionManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (!td_->auth_manager_->is_authorized() || td_->auth_manager_->is_bot()) {
    return;
  }

  updates.push_back(get_update_speech_recognition_trial_object());
}

}  // namespace td
