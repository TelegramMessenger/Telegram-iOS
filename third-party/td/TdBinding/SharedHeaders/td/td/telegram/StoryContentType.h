//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

namespace td {

// increase StoryContentUnsupported::CURRENT_VERSION each time a new Story content type is added
enum class StoryContentType : int32 { Photo, Video, Unsupported };

StringBuilder &operator<<(StringBuilder &string_builder, StoryContentType content_type);

struct StoryContentTypeHash {
  uint32 operator()(StoryContentType content_type) const {
    return Hash<int32>()(static_cast<int32>(content_type));
  }
};

}  // namespace td
