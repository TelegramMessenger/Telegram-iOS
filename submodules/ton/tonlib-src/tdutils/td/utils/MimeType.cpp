/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
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
