//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class MediaAreaCoordinates {
  double x_ = 0.0;
  double y_ = 0.0;
  double width_ = 0.0;
  double height_ = 0.0;
  double rotation_angle_ = 0.0;
  double radius_ = 0.0;

  friend bool operator==(const MediaAreaCoordinates &lhs, const MediaAreaCoordinates &rhs);
  friend bool operator!=(const MediaAreaCoordinates &lhs, const MediaAreaCoordinates &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MediaAreaCoordinates &coordinates);

  void init(double x, double y, double width, double height, double rotation_angle, double radius);

 public:
  MediaAreaCoordinates() = default;

  explicit MediaAreaCoordinates(const telegram_api::object_ptr<telegram_api::mediaAreaCoordinates> &coordinates);

  explicit MediaAreaCoordinates(const td_api::object_ptr<td_api::storyAreaPosition> &position);

  td_api::object_ptr<td_api::storyAreaPosition> get_story_area_position_object() const;

  telegram_api::object_ptr<telegram_api::mediaAreaCoordinates> get_input_media_area_coordinates() const;

  bool is_valid() const {
    return width_ > 0.0 && height_ > 0.0;
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const MediaAreaCoordinates &lhs, const MediaAreaCoordinates &rhs);
bool operator!=(const MediaAreaCoordinates &lhs, const MediaAreaCoordinates &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const MediaAreaCoordinates &coordinates);

}  // namespace td
