//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileEncryptionKey.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileSourceId.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/StringBuilder.h"

namespace td {

class FileData {
 public:
  DialogId owner_dialog_id_;
  uint64 pmc_id_ = 0;
  RemoteFileLocation remote_;
  LocalFileLocation local_;
  unique_ptr<FullGenerateFileLocation> generate_;
  int64 size_ = 0;
  int64 expected_size_ = 0;
  string remote_name_;
  string url_;
  FileEncryptionKey encryption_key_;
  vector<FileSourceId> file_source_ids_;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser, bool register_file_sources);
};

inline StringBuilder &operator<<(StringBuilder &sb, const FileData &file_data) {
  sb << "[" << tag("remote_name", file_data.remote_name_) << " " << tag("size", file_data.size_)
     << tag("expected_size", file_data.expected_size_) << " " << file_data.encryption_key_;
  if (!file_data.url_.empty()) {
    sb << tag("url", file_data.url_);
  }
  if (file_data.local_.type() == LocalFileLocation::Type::Full) {
    sb << " local " << file_data.local_.full();
  }
  if (file_data.generate_ != nullptr) {
    sb << " generate " << *file_data.generate_;
  }
  if (file_data.remote_.type() == RemoteFileLocation::Type::Full) {
    sb << " remote " << file_data.remote_.full();
  }
  sb << ", sources = " << file_data.file_source_ids_;
  return sb << "]";
}

}  // namespace td
