//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

struct Document {
  // append only
  enum class Type : int32 { Unknown, Animation, Audio, General, Sticker, Video, VideoNote, VoiceNote };

  Type type = Type::Unknown;
  FileId file_id;

  Document() = default;
  Document(Type type, FileId file_id) : type(type), file_id(file_id) {
  }

  bool empty() const {
    return type == Type::Unknown;
  }

  vector<FileId> get_file_ids(const Td *td) const;

  void append_file_ids(const Td *td, vector<FileId> &file_ids) const;
};

bool operator==(const Document &lhs, const Document &rhs);

bool operator!=(const Document &lhs, const Document &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const Document::Type &document_type);

StringBuilder &operator<<(StringBuilder &string_builder, const Document &document);

}  // namespace td
