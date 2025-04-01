//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileId.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

namespace td {

class FileUploadId {
  FileId file_id_;
  int64 internal_upload_id_ = 0;

 public:
  FileUploadId() = default;

  FileUploadId(FileId file_id, int64 internal_upload_id) : file_id_(file_id), internal_upload_id_(internal_upload_id) {
  }

  bool is_valid() const {
    return file_id_.is_valid();
  }

  FileId get_file_id() const {
    return file_id_;
  }

  int64 get_internal_upload_id() const {
    return internal_upload_id_;
  }

  bool operator==(const FileUploadId &other) const {
    return file_id_ == other.file_id_ && internal_upload_id_ == other.internal_upload_id_;
  }

  bool operator!=(const FileUploadId &other) const {
    return !(*this == other);
  }
};

struct FileUploadIdHash {
  uint32 operator()(FileUploadId file_id) const {
    return combine_hashes(FileIdHash()(file_id.get_file_id()), Hash<int64>()(file_id.get_internal_upload_id()));
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, FileUploadId file_upload_id) {
  return string_builder << "file " << file_upload_id.get_file_id() << '+' << file_upload_id.get_internal_upload_id();
}

}  // namespace td
