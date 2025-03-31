//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/TranscriptionInfo.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void TranscriptionInfo::store(StorerT &storer) const {
  CHECK(is_transcribed());
  td::store(transcription_id_, storer);
  td::store(text_, storer);
}

template <class ParserT>
void TranscriptionInfo::parse(ParserT &parser) {
  is_transcribed_ = true;
  td::parse(transcription_id_, parser);
  td::parse(text_, parser);
  CHECK(transcription_id_ != 0);
}

}  // namespace td
