//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileId.h"
#include "td/telegram/MessageContentType.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/TranscriptionInfo.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"
#include "td/actor/Timeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <functional>
#include <utility>

namespace td {

class Td;

class TranscriptionManager final : public Actor {
 public:
  TranscriptionManager(Td *td, ActorShared<> parent);
  TranscriptionManager(const TranscriptionManager &) = delete;
  TranscriptionManager &operator=(const TranscriptionManager &) = delete;
  TranscriptionManager(TranscriptionManager &&) = delete;
  TranscriptionManager &operator=(TranscriptionManager &&) = delete;
  ~TranscriptionManager() final;

  void on_update_trial_parameters(int32 weekly_number, int32 duration_max, int32 cooldown_until);

  void register_voice(FileId file_id, MessageContentType content_type, MessageFullId message_full_id,
                      const char *source);

  void unregister_voice(FileId file_id, MessageContentType content_type, MessageFullId message_full_id,
                        const char *source);

  void recognize_speech(MessageFullId message_full_id, Promise<Unit> &&promise);

  void on_transcription_completed(FileId file_id);

  void rate_speech_recognition(MessageFullId message_full_id, bool is_good, Promise<Unit> &&promise);

  void on_update_transcribed_audio(telegram_api::object_ptr<telegram_api::updateTranscribedAudio> &&update);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  static constexpr int32 AUDIO_TRANSCRIPTION_TIMEOUT = 60;

  struct TrialParameters {
    int32 weekly_number_ = 0;
    int32 duration_max_ = 0;
    int32 left_tries_ = 0;
    int32 next_reset_date_ = 0;

    void update_left_tries();

    td_api::object_ptr<td_api::updateSpeechRecognitionTrial> get_update_speech_recognition_trial_object() const;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  friend bool operator==(const TrialParameters &lhs, const TrialParameters &rhs);

  void tear_down() final;

  static void on_pending_audio_transcription_timeout_callback(void *td, int64 transcription_id);

  static string get_trial_parameters_database_key();

  void load_trial_parameters();

  void set_trial_parameters(TrialParameters new_trial_parameters);

  void set_speech_recognition_trial_timeout();

  static void trial_parameters_timeout_static(void *td);

  void on_trial_parameters_timeout();

  void save_trial_parameters();

  void send_update_speech_recognition_trial() const;

  td_api::object_ptr<td_api::updateSpeechRecognitionTrial> get_update_speech_recognition_trial_object() const;

  using FileInfo = std::pair<MessageContentType, FileId>;

  TranscriptionInfo *get_transcription_info(const FileInfo &file_info, bool allow_creation);

  void on_transcribed_audio(FileInfo file_info,
                            Result<telegram_api::object_ptr<telegram_api::messages_transcribedAudio>> r_audio);

  using TranscribedAudioHandler =
      std::function<void(Result<telegram_api::object_ptr<telegram_api::updateTranscribedAudio>>)>;
  void subscribe_to_transcribed_audio_updates(int64 transcription_id, TranscribedAudioHandler on_update);

  void on_transcribed_audio_update(FileInfo file_info, bool is_initial,
                                   Result<telegram_api::object_ptr<telegram_api::updateTranscribedAudio>> r_update);

  void on_transcription_updated(FileId file_id);

  void on_pending_audio_transcription_failed(int64 transcription_id, Status &&error);

  Td *td_;
  ActorShared<> parent_;

  TrialParameters trial_parameters_;
  Timeout trial_parameters_timeout_;

  FlatHashMap<int64, TranscribedAudioHandler> pending_audio_transcriptions_;
  MultiTimeout pending_audio_transcription_timeout_{"PendingAudioTranscriptionTimeout"};

  FlatHashMap<FileId, FlatHashSet<MessageFullId, MessageFullIdHash>, FileIdHash> voice_messages_;
  FlatHashMap<MessageFullId, FileInfo, MessageFullIdHash> message_file_ids_;
};

}  // namespace td
