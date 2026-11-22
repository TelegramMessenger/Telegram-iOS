//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Location.h"
#include "td/telegram/MediaAreaCoordinates.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/ReactionType.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/Venue.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

#include <utility>

namespace td {

class Dependencies;
class Td;

class MediaArea {
  struct GeoPointAddress {
    string country_iso2_;
    string state_;
    string city_;
    string street_;

    bool is_empty() const {
      return country_iso2_.empty();
    }

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  enum class Type : int32 { None, Location, Venue, Reaction, Message, Url, Weather, StarGift };
  Type type_ = Type::None;
  MediaAreaCoordinates coordinates_;
  Location location_;
  GeoPointAddress address_;
  Venue venue_;
  MessageFullId message_full_id_;
  int64 input_query_id_ = 0;
  string input_result_id_;
  ReactionType reaction_type_;
  string url_;
  double temperature_ = 0.0;
  int32 color_ = 0;
  bool is_dark_ = false;
  bool is_flipped_ = false;
  bool is_old_message_ = false;

  friend bool operator==(const MediaArea &lhs, const MediaArea &rhs);
  friend bool operator!=(const MediaArea &lhs, const MediaArea &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MediaArea &media_area);

  telegram_api::object_ptr<telegram_api::MediaArea> get_input_media_area(const Td *td) const;

 public:
  MediaArea() = default;

  MediaArea(Td *td, telegram_api::object_ptr<telegram_api::MediaArea> &&media_area_ptr);

  MediaArea(Td *td, td_api::object_ptr<td_api::inputStoryArea> &&input_story_area,
            const vector<MediaArea> &old_media_areas);

  bool has_reaction_type(const ReactionType &reaction_type) const;

  td_api::object_ptr<td_api::storyArea> get_story_area_object(
      Td *td, const vector<std::pair<ReactionType, int32>> &reaction_counts) const;

  static vector<telegram_api::object_ptr<telegram_api::MediaArea>> get_input_media_areas(
      const Td *td, const vector<MediaArea> &media_areas);

  bool is_valid() const {
    return type_ != Type::None;
  }

  void add_dependencies(Dependencies &dependencies) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const MediaArea &lhs, const MediaArea &rhs);
bool operator!=(const MediaArea &lhs, const MediaArea &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const MediaArea &media_area);

}  // namespace td
