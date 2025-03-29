//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StoryContentType.h"

namespace td {

StringBuilder &operator<<(StringBuilder &string_builder, StoryContentType content_type) {
  switch (content_type) {
    case StoryContentType::Photo:
      return string_builder << "Photo";
    case StoryContentType::Video:
      return string_builder << "Video";
    case StoryContentType::Unsupported:
      return string_builder << "Unsupported";
    default:
      return string_builder << "Invalid type " << static_cast<int32>(content_type);
  }
}

}  // namespace td
