//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Global.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/SecretInputMedia.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

class Td;

class Location {
  bool is_empty_ = true;
  double latitude_ = 0.0;
  double longitude_ = 0.0;
  double horizontal_accuracy_ = 0.0;
  mutable int64 access_hash_ = 0;

  friend bool operator==(const Location &lhs, const Location &rhs);
  friend bool operator!=(const Location &lhs, const Location &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const Location &location);

  void init(Td *td, double latitude, double longitude, double horizontal_accuracy, int64 access_hash);

  static double fix_accuracy(double accuracy);

 public:
  Location() = default;

  Location(Td *td, double latitude, double longitude, double horizontal_accuracy, int64 access_hash);

  explicit Location(const tl_object_ptr<secret_api::decryptedMessageMediaGeoPoint> &geo_point);

  Location(Td *td, const tl_object_ptr<telegram_api::GeoPoint> &geo_point_ptr);

  explicit Location(const tl_object_ptr<td_api::location> &location);

  bool empty() const;

  bool is_valid_map_point() const;

  tl_object_ptr<td_api::location> get_location_object() const;

  tl_object_ptr<telegram_api::InputGeoPoint> get_input_geo_point() const;

  telegram_api::object_ptr<telegram_api::GeoPoint> get_fake_geo_point() const;

  tl_object_ptr<telegram_api::inputMediaGeoPoint> get_input_media_geo_point() const;

  double get_latitude() const {
    return latitude_;
  }

  double get_longitude() const {
    return longitude_;
  }

  int64 get_access_hash() const {
    return access_hash_;
  }

  void set_access_hash(int64 access_hash) const {
    access_hash_ = access_hash;
  }

  SecretInputMedia get_secret_input_media_geo_point() const;

  template <class StorerT>
  void store(StorerT &storer) const {
    using td::store;
    bool has_access_hash = access_hash_ != 0;
    bool has_horizontal_accuracy = horizontal_accuracy_ > 0.0;
    BEGIN_STORE_FLAGS();
    STORE_FLAG(is_empty_);
    STORE_FLAG(has_access_hash);
    STORE_FLAG(has_horizontal_accuracy);
    END_STORE_FLAGS();
    store(latitude_, storer);
    store(longitude_, storer);
    if (has_access_hash) {
      store(access_hash_, storer);
    }
    if (has_horizontal_accuracy) {
      store(horizontal_accuracy_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    using td::parse;
    bool has_access_hash;
    bool has_horizontal_accuracy;
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(is_empty_);
    PARSE_FLAG(has_access_hash);
    PARSE_FLAG(has_horizontal_accuracy);
    END_PARSE_FLAGS();
    parse(latitude_, parser);
    parse(longitude_, parser);
    if (has_access_hash) {
      parse(access_hash_, parser);
      G()->add_location_access_hash(latitude_, longitude_, access_hash_);
    }
    if (has_horizontal_accuracy) {
      parse(horizontal_accuracy_, parser);
    }
  }
};

bool operator==(const Location &lhs, const Location &rhs);
bool operator!=(const Location &lhs, const Location &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const Location &location);

struct InputMessageLocation {
  Location location;
  int32 live_period;
  int32 heading;
  int32 proximity_alert_radius;

  InputMessageLocation(Location &&location, int32 live_period, int32 heading, int32 proximity_alert_radius)
      : location(std::move(location))
      , live_period(live_period)
      , heading(heading)
      , proximity_alert_radius(proximity_alert_radius) {
  }
};
Result<InputMessageLocation> process_input_message_location(
    td_api::object_ptr<td_api::InputMessageContent> &&input_message_content) TD_WARN_UNUSED_RESULT;

}  // namespace td
