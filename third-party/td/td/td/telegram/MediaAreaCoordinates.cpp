//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MediaAreaCoordinates.h"

#include "td/utils/misc.h"

#include <cmath>

namespace td {

static double fix_double(double &value, double min_value = 0.0, double max_value = 100.0) {
  if (!std::isfinite(value)) {
    return 0.0;
  }
  return clamp(value, min_value, max_value);
}

void MediaAreaCoordinates::init(double x, double y, double width, double height, double rotation_angle, double radius) {
  x_ = fix_double(x);
  y_ = fix_double(y);
  width_ = fix_double(width);
  height_ = fix_double(height);
  rotation_angle_ = fix_double(rotation_angle, -360.0, 360.0);
  if (rotation_angle_ < 0) {
    rotation_angle_ += 360.0;
  }
  radius_ = fix_double(radius);
}

MediaAreaCoordinates::MediaAreaCoordinates(
    const telegram_api::object_ptr<telegram_api::mediaAreaCoordinates> &coordinates) {
  if (coordinates == nullptr) {
    return;
  }
  init(coordinates->x_, coordinates->y_, coordinates->w_, coordinates->h_, coordinates->rotation_,
       coordinates->radius_);
}

MediaAreaCoordinates::MediaAreaCoordinates(const td_api::object_ptr<td_api::storyAreaPosition> &position) {
  if (position == nullptr) {
    return;
  }

  init(position->x_percentage_, position->y_percentage_, position->width_percentage_, position->height_percentage_,
       position->rotation_angle_, position->corner_radius_percentage_);
}

td_api::object_ptr<td_api::storyAreaPosition> MediaAreaCoordinates::get_story_area_position_object() const {
  CHECK(is_valid());
  return td_api::make_object<td_api::storyAreaPosition>(x_, y_, width_, height_, rotation_angle_, radius_);
}

telegram_api::object_ptr<telegram_api::mediaAreaCoordinates> MediaAreaCoordinates::get_input_media_area_coordinates()
    const {
  CHECK(is_valid());
  int32 flags = 0;
  if (radius_ > 0) {
    flags |= telegram_api::mediaAreaCoordinates::RADIUS_MASK;
  }
  return telegram_api::make_object<telegram_api::mediaAreaCoordinates>(flags, x_, y_, width_, height_, rotation_angle_,
                                                                       radius_);
}

bool operator==(const MediaAreaCoordinates &lhs, const MediaAreaCoordinates &rhs) {
  return std::abs(lhs.x_ - rhs.x_) < 1e-6 && std::abs(lhs.y_ - rhs.y_) < 1e-6 &&
         std::abs(lhs.width_ - rhs.width_) < 1e-6 && std::abs(lhs.height_ - rhs.height_) < 1e-6 &&
         std::abs(lhs.rotation_angle_ - rhs.rotation_angle_) < 1e-6 && std::abs(lhs.radius_ - rhs.radius_) < 1e-6;
}

bool operator!=(const MediaAreaCoordinates &lhs, const MediaAreaCoordinates &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const MediaAreaCoordinates &coordinates) {
  return string_builder << "StoryAreaPosition[" << coordinates.x_ << ", " << coordinates.y_ << ", "
                        << coordinates.width_ << ", " << coordinates.height_ << ", " << coordinates.rotation_angle_
                        << ", " << coordinates.radius_ << ']';
}

}  // namespace td
