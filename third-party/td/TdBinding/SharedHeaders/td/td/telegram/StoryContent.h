//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/StoryContentType.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

class Dependencies;
class Td;

class StoryContent {
 public:
  StoryContent() = default;
  StoryContent(const StoryContent &) = default;
  StoryContent &operator=(const StoryContent &) = default;
  StoryContent(StoryContent &&) = default;
  StoryContent &operator=(StoryContent &&) = default;

  virtual StoryContentType get_type() const = 0;
  virtual ~StoryContent() = default;
};

void store_story_content(const StoryContent *content, LogEventStorerCalcLength &storer);

void store_story_content(const StoryContent *content, LogEventStorerUnsafe &storer);

void parse_story_content(unique_ptr<StoryContent> &content, LogEventParser &parser);

void add_story_content_dependencies(Dependencies &dependencies, const StoryContent *story_content);

unique_ptr<StoryContent> get_story_content(Td *td, telegram_api::object_ptr<telegram_api::MessageMedia> &&media_ptr,
                                           DialogId owner_dialog_id);

Result<unique_ptr<StoryContent>> get_input_story_content(
    Td *td, td_api::object_ptr<td_api::InputStoryContent> &&input_story_content, DialogId owner_dialog_id);

telegram_api::object_ptr<telegram_api::InputMedia> get_story_content_input_media(
    Td *td, const StoryContent *content, telegram_api::object_ptr<telegram_api::InputFile> input_file);

telegram_api::object_ptr<telegram_api::InputMedia> get_story_content_document_input_media(Td *td,
                                                                                          const StoryContent *content,
                                                                                          double main_frame_timestamp);

void compare_story_contents(Td *td, const StoryContent *old_content, const StoryContent *new_content,
                            bool &is_content_changed, bool &need_update);

void merge_story_contents(Td *td, const StoryContent *old_content, StoryContent *new_content, DialogId dialog_id,
                          bool &is_content_changed, bool &need_update);

unique_ptr<StoryContent> copy_story_content(const StoryContent *content);

td_api::object_ptr<td_api::StoryContent> get_story_content_object(Td *td, const StoryContent *content);

FileId get_story_content_any_file_id(const StoryContent *content);

vector<FileId> get_story_content_file_ids(const Td *td, const StoryContent *content);

int32 get_story_content_duration(const Td *td, const StoryContent *content);

}  // namespace td
