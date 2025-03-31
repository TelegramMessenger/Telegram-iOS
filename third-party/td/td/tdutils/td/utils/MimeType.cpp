//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/MimeType.h"

#include "td/utils/logging.h"

const char *extension_to_mime_type(const char *extension, size_t extension_len);  // auto-generated
const char *mime_type_to_extension(const char *mime_type, size_t mime_type_len);  // auto-generated

namespace td {

string MimeType::to_extension(Slice mime_type, Slice default_value) {
  if (mime_type.empty()) {
    return default_value.str();
  }

  const char *result = ::mime_type_to_extension(mime_type.data(), mime_type.size());
  if (result != nullptr) {
    return result;
  }

  LOG(INFO) << "Unknown file MIME type " << mime_type;
  return default_value.str();
}

string MimeType::from_extension(Slice extension, Slice default_value) {
  if (extension.empty()) {
    return default_value.str();
  }

  const char *result = ::extension_to_mime_type(extension.data(), extension.size());
  if (result != nullptr) {
    return result;
  }

  LOG(INFO) << "Unknown file extension " << extension;
  return default_value.str();
}

}  // namespace td
