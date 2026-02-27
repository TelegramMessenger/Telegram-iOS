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
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class BackgroundFill {
  int32 top_color_ = 0;
  int32 bottom_color_ = 0;
  int32 rotation_angle_ = 0;
  int32 third_color_ = -1;
  int32 fourth_color_ = -1;

  BackgroundFill() = default;
  explicit BackgroundFill(int32 solid_color) : top_color_(solid_color), bottom_color_(solid_color) {
  }
  BackgroundFill(int32 top_color, int32 bottom_color, int32 rotation_angle)
      : top_color_(top_color), bottom_color_(bottom_color), rotation_angle_(rotation_angle) {
    if (get_type() != Type::Gradient) {
      rotation_angle_ = 0;
    }
  }
  BackgroundFill(int32 first_color, int32 second_color, int32 third_color, int32 fourth_color)
      : top_color_(first_color), bottom_color_(second_color), third_color_(third_color), fourth_color_(fourth_color) {
  }

  explicit BackgroundFill(const telegram_api::wallPaperSettings *settings);

  static Result<BackgroundFill> get_background_fill(const td_api::BackgroundFill *fill);

  string get_link(bool is_first) const;

  td_api::object_ptr<td_api::BackgroundFill> get_background_fill_object() const;

  enum class Type : int32 { Solid, Gradient, FreeformGradient };
  Type get_type() const {
    if (third_color_ != -1) {
      return Type::FreeformGradient;
    }
    if (top_color_ == bottom_color_) {
      return Type::Solid;
    }
    return Type::Gradient;
  }

  friend bool operator==(const BackgroundFill &lhs, const BackgroundFill &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BackgroundFill &fill);

  friend class BackgroundType;

  static Result<BackgroundFill> get_background_fill(Slice name);

  bool is_dark() const;
};

bool operator==(const BackgroundFill &lhs, const BackgroundFill &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const BackgroundFill &fill);

class BackgroundType {
  enum class Type : int32 { Wallpaper, Pattern, Fill, ChatTheme };
  Type type_ = Type::Fill;
  bool is_blurred_ = false;
  bool is_moving_ = false;
  int32 intensity_ = 0;
  BackgroundFill fill_;
  string theme_name_;

  friend bool operator==(const BackgroundType &lhs, const BackgroundType &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BackgroundType &type);

  BackgroundType(bool is_blurred, bool is_moving, int32 dark_theme_dimming)
      : type_(Type::Wallpaper), is_blurred_(is_blurred), is_moving_(is_moving), intensity_(dark_theme_dimming) {
  }
  BackgroundType(bool is_moving, BackgroundFill &&fill, int32 intensity)
      : type_(Type::Pattern), is_moving_(is_moving), intensity_(intensity), fill_(std::move(fill)) {
  }
  BackgroundType(BackgroundFill &&fill, int32 dark_theme_dimming)
      : type_(Type::Fill), intensity_(dark_theme_dimming), fill_(std::move(fill)) {
  }
  explicit BackgroundType(string theme_name) : type_(Type::ChatTheme), theme_name_(std::move(theme_name)) {
  }

 public:
  BackgroundType() = default;

  BackgroundType(bool has_no_file, bool is_pattern, telegram_api::object_ptr<telegram_api::wallPaperSettings> settings);

  static Result<BackgroundType> get_background_type(const td_api::BackgroundType *background_type,
                                                    int32 dark_theme_dimming);

  static Result<BackgroundType> get_local_background_type(Slice name);

  static bool is_background_name_local(Slice name);

  bool has_file() const {
    return type_ == Type::Wallpaper || type_ == Type::Pattern;
  }

  bool has_gradient_fill() const {
    return type_ == Type::Fill && fill_.get_type() != BackgroundFill::Type::Solid;
  }

  string get_mime_type() const;

  void apply_parameters_from_link(Slice name);

  string get_link(bool is_first = true) const;

  bool has_equal_type(const BackgroundType &other) const {
    return type_ == other.type_;
  }

  td_api::object_ptr<td_api::BackgroundType> get_background_type_object() const;

  telegram_api::object_ptr<telegram_api::wallPaperSettings> get_input_wallpaper_settings() const;

  bool is_dark() const {
    CHECK(type_ == Type::Fill);
    return fill_.is_dark();
  }

  int32 get_dark_theme_dimming() const {
    if (type_ == Type::Pattern) {
      return 0;
    }
    return intensity_;
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const BackgroundType &lhs, const BackgroundType &rhs);

inline bool operator!=(const BackgroundType &lhs, const BackgroundType &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const BackgroundType &type);

}  // namespace td
