//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageFullId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <functional>

namespace td {

class Td;

class TranscriptionInfo {
  bool is_transcribed_ = false;
  int64 transcription_id_ = 0;
  string text_;

  // temporary state
  Status last_transcription_error_;
  vector<Promise<Unit>> speech_recognition_queries_;

 public:
  bool is_transcribed() const {
    return is_transcribed_;
  }

  bool recognize_speech(
      Td *td, MessageFullId message_full_id, Promise<Unit> &&promise,
      std::function<void(Result<telegram_api::object_ptr<telegram_api::messages_transcribedAudio>>)> &&handler);

  vector<Promise<Unit>> on_final_transcription(string &&text, int64 transcription_id);

  bool on_partial_transcription(string &&text, int64 transcription_id);

  vector<Promise<Unit>> on_failed_transcription(Status &&error);

  void rate_speech_recognition(Td *td, MessageFullId message_full_id, bool is_good, Promise<Unit> &&promise) const;

  static unique_ptr<TranscriptionInfo> copy_if_transcribed(const unique_ptr<TranscriptionInfo> &info);

  static bool update_from(unique_ptr<TranscriptionInfo> &old_info, unique_ptr<TranscriptionInfo> &&new_info);

  td_api::object_ptr<td_api::SpeechRecognitionResult> get_speech_recognition_result_object() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

}  // namespace td
