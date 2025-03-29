//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Location.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/Td.h"

#include <cmath>
#include <limits>

namespace td {

double Location::fix_accuracy(double accuracy) {
  if (!std::isfinite(accuracy) || accuracy <= 0.0) {
    return 0.0;
  }
  if (accuracy >= 1500.0) {
    return 1500.0;
  }
  return accuracy;
}

void Location::init(Td *td, double latitude, double longitude, double horizontal_accuracy, int64 access_hash) {
  if (std::isfinite(latitude) && std::isfinite(longitude) && std::abs(latitude) <= 90 && std::abs(longitude) <= 180) {
    is_empty_ = false;
    latitude_ = latitude;
    longitude_ = longitude;
    horizontal_accuracy_ = fix_accuracy(horizontal_accuracy);
    access_hash_ = access_hash;
    if (td != nullptr && !td->auth_manager_->is_bot()) {
      G()->add_location_access_hash(latitude_, longitude_, access_hash_);
    }
  }
}

Location::Location(Td *td, double latitude, double longitude, double horizontal_accuracy, int64 access_hash) {
  init(td, latitude, longitude, horizontal_accuracy, access_hash);
}

Location::Location(const tl_object_ptr<secret_api::decryptedMessageMediaGeoPoint> &geo_point)
    : Location(nullptr, geo_point->lat_, geo_point->long_, 0.0, 0) {
}

Location::Location(Td *td, const tl_object_ptr<telegram_api::GeoPoint> &geo_point_ptr) {
  if (geo_point_ptr == nullptr) {
    return;
  }
  switch (geo_point_ptr->get_id()) {
    case telegram_api::geoPointEmpty::ID:
      break;
    case telegram_api::geoPoint::ID: {
      auto geo_point = static_cast<const telegram_api::geoPoint *>(geo_point_ptr.get());
      init(td, geo_point->lat_, geo_point->long_, geo_point->accuracy_radius_, geo_point->access_hash_);
      break;
    }
    default:
      UNREACHABLE();
      break;
  }
}

Location::Location(const tl_object_ptr<td_api::location> &location) {
  if (location == nullptr) {
    return;
  }

  init(nullptr, location->latitude_, location->longitude_, location->horizontal_accuracy_, 0);
}

bool Location::empty() const {
  return is_empty_;
}

bool Location::is_valid_map_point() const {
  const double MAX_VALID_MAP_LATITUDE = 85.05112877;
  return !empty() && std::abs(latitude_) <= MAX_VALID_MAP_LATITUDE;
}

tl_object_ptr<td_api::location> Location::get_location_object() const {
  if (empty()) {
    return nullptr;
  }
  return make_tl_object<td_api::location>(latitude_, longitude_, horizontal_accuracy_);
}

tl_object_ptr<telegram_api::InputGeoPoint> Location::get_input_geo_point() const {
  if (empty()) {
    return make_tl_object<telegram_api::inputGeoPointEmpty>();
  }

  int32 flags = 0;
  if (horizontal_accuracy_ > 0) {
    flags |= telegram_api::inputGeoPoint::ACCURACY_RADIUS_MASK;
  }

  return make_tl_object<telegram_api::inputGeoPoint>(flags, latitude_, longitude_,
                                                     static_cast<int32>(std::ceil(horizontal_accuracy_)));
}

telegram_api::object_ptr<telegram_api::GeoPoint> Location::get_fake_geo_point() const {
  if (empty()) {
    return make_tl_object<telegram_api::geoPointEmpty>();
  }

  int32 flags = 0;
  if (horizontal_accuracy_ > 0) {
    flags |= telegram_api::geoPoint::ACCURACY_RADIUS_MASK;
  }
  return telegram_api::make_object<telegram_api::geoPoint>(flags, longitude_, latitude_, 0,
                                                           static_cast<int32>(std::ceil(horizontal_accuracy_)));
}

tl_object_ptr<telegram_api::inputMediaGeoPoint> Location::get_input_media_geo_point() const {
  return make_tl_object<telegram_api::inputMediaGeoPoint>(get_input_geo_point());
}

SecretInputMedia Location::get_secret_input_media_geo_point() const {
  return SecretInputMedia{nullptr, make_tl_object<secret_api::decryptedMessageMediaGeoPoint>(latitude_, longitude_)};
}

bool operator==(const Location &lhs, const Location &rhs) {
  if (lhs.is_empty_) {
    return rhs.is_empty_;
  }
  return !rhs.is_empty_ && std::abs(lhs.latitude_ - rhs.latitude_) < 1e-6 &&
         std::abs(lhs.longitude_ - rhs.longitude_) < 1e-6 &&
         std::abs(lhs.horizontal_accuracy_ - rhs.horizontal_accuracy_) < 1e-6;
}

bool operator!=(const Location &lhs, const Location &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const Location &location) {
  if (location.empty()) {
    return string_builder << "Location[empty]";
  }
  return string_builder << "Location[latitude = " << location.latitude_ << ", longitude = " << location.longitude_
                        << ", accuracy = " << location.horizontal_accuracy_ << "]";
}

Result<InputMessageLocation> process_input_message_location(
    tl_object_ptr<td_api::InputMessageContent> &&input_message_content) {
  CHECK(input_message_content != nullptr);
  CHECK(input_message_content->get_id() == td_api::inputMessageLocation::ID);
  auto input_location = static_cast<const td_api::inputMessageLocation *>(input_message_content.get());

  Location location(input_location->location_);
  if (location.empty()) {
    return Status::Error(400, "Wrong location specified");
  }

  constexpr int32 MIN_LIVE_LOCATION_PERIOD = 60;     // seconds, server side limit
  constexpr int32 MAX_LIVE_LOCATION_PERIOD = 86400;  // seconds, server side limit

  auto period = input_location->live_period_;
  if (period != 0 && period != std::numeric_limits<int32>::max() &&
      (period < MIN_LIVE_LOCATION_PERIOD || period > MAX_LIVE_LOCATION_PERIOD)) {
    return Status::Error(400, "Wrong live location period specified");
  }

  constexpr int32 MIN_LIVE_LOCATION_HEADING = 1;    // degrees, server side limit
  constexpr int32 MAX_LIVE_LOCATION_HEADING = 360;  // degrees, server side limit

  auto heading = input_location->heading_;
  if (heading != 0 && (heading < MIN_LIVE_LOCATION_HEADING || heading > MAX_LIVE_LOCATION_HEADING)) {
    return Status::Error(400, "Wrong live location heading specified");
  }

  constexpr int32 MAX_PROXIMITY_ALERT_RADIUS = 100000;  // meters, server side limit
  auto proximity_alert_radius = input_location->proximity_alert_radius_;
  if (proximity_alert_radius < 0 || proximity_alert_radius > MAX_PROXIMITY_ALERT_RADIUS) {
    return Status::Error(400, "Wrong live location proximity alert radius specified");
  }

  return InputMessageLocation(std::move(location), period, heading, proximity_alert_radius);
}

}  // namespace td
