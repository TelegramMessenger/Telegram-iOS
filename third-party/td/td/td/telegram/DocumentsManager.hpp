//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DocumentsManager.h"

#include "td/telegram/files/FileId.hpp"
#include "td/telegram/PhotoSize.hpp"
#include "td/telegram/Version.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void DocumentsManager::store_document(FileId file_id, StorerT &storer) const {
  const GeneralDocument *document = get_document(file_id);
  CHECK(document != nullptr);
  bool has_file_name = !document->file_name.empty();
  bool has_mime_type = !document->mime_type.empty();
  bool has_minithumbnail = !document->minithumbnail.empty();
  bool has_thumbnail = document->thumbnail.file_id.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_file_name);
  STORE_FLAG(has_mime_type);
  STORE_FLAG(has_minithumbnail);
  STORE_FLAG(has_thumbnail);
  END_STORE_FLAGS();
  if (has_file_name) {
    store(document->file_name, storer);
  }
  if (has_mime_type) {
    store(document->mime_type, storer);
  }
  if (has_minithumbnail) {
    store(document->minithumbnail, storer);
  }
  if (has_thumbnail) {
    store(document->thumbnail, storer);
  }
  store(file_id, storer);
}

template <class ParserT>
FileId DocumentsManager::parse_document(ParserT &parser) {
  auto document = make_unique<GeneralDocument>();
  bool has_file_name;
  bool has_mime_type;
  bool has_minithumbnail;
  bool has_thumbnail;
  if (parser.version() >= static_cast<int32>(Version::AddDocumentFlags)) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_file_name);
    PARSE_FLAG(has_mime_type);
    PARSE_FLAG(has_minithumbnail);
    PARSE_FLAG(has_thumbnail);
    END_PARSE_FLAGS();
  } else {
    has_file_name = true;
    has_mime_type = true;
    has_minithumbnail = parser.version() >= static_cast<int32>(Version::SupportMinithumbnails);
    has_thumbnail = true;
  }
  if (has_file_name) {
    parse(document->file_name, parser);
  }
  if (has_mime_type) {
    parse(document->mime_type, parser);
  }
  if (has_minithumbnail) {
    parse(document->minithumbnail, parser);
  }
  if (has_thumbnail) {
    parse(document->thumbnail, parser);
  }
  parse(document->file_id, parser);
  if (parser.get_error() != nullptr || !document->file_id.is_valid()) {
    return FileId();
  }
  return on_get_document(std::move(document), false);
}

}  // namespace td
