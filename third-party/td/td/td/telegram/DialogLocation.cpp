//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogLocation.h"

#include "td/telegram/misc.h"

namespace td {

DialogLocation::DialogLocation(Td *td, telegram_api::object_ptr<telegram_api::ChannelLocation> &&channel_location_ptr) {
  if (channel_location_ptr != nullptr && channel_location_ptr->get_id() == telegram_api::channelLocation::ID) {
    auto channel_location = static_cast<telegram_api::channelLocation *>(channel_location_ptr.get());
    location_ = Location(td, channel_location->geo_point_);
    address_ = std::move(channel_location->address_);
  }
}

DialogLocation::DialogLocation(Td *td, telegram_api::object_ptr<telegram_api::businessLocation> &&business_location) {
  if (business_location != nullptr) {
    location_ = Location(td, business_location->geo_point_);
    address_ = std::move(business_location->address_);
  }
}

DialogLocation::DialogLocation(td_api::object_ptr<td_api::chatLocation> &&chat_location) {
  if (chat_location != nullptr) {
    location_ = Location(chat_location->location_);
    address_ = std::move(chat_location->address_);
    if (!clean_input_string(address_)) {
      address_.clear();
    }
  }
}

DialogLocation::DialogLocation(td_api::object_ptr<td_api::businessLocation> &&business_location) {
  if (business_location != nullptr) {
    location_ = Location(business_location->location_);
    address_ = std::move(business_location->address_);
    if (!clean_input_string(address_)) {
      address_.clear();
    }
  }
}

bool DialogLocation::empty() const {
  return location_.empty();
}

td_api::object_ptr<td_api::chatLocation> DialogLocation::get_chat_location_object() const {
  if (empty()) {
    return nullptr;
  }
  return td_api::make_object<td_api::chatLocation>(location_.get_location_object(), address_);
}

td_api::object_ptr<td_api::businessLocation> DialogLocation::get_business_location_object() const {
  if (empty() && address_.empty()) {
    return nullptr;
  }
  return td_api::make_object<td_api::businessLocation>(location_.get_location_object(), address_);
}

telegram_api::object_ptr<telegram_api::InputGeoPoint> DialogLocation::get_input_geo_point() const {
  return location_.get_input_geo_point();
}

const string &DialogLocation::get_address() const {
  return address_;
}

bool operator==(const DialogLocation &lhs, const DialogLocation &rhs) {
  return lhs.location_ == rhs.location_ && lhs.address_ == rhs.address_;
}

bool operator!=(const DialogLocation &lhs, const DialogLocation &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const DialogLocation &location) {
  return string_builder << "DialogLocation[location = " << location.location_ << ", address = " << location.address_
                        << "]";
}

}  // namespace td
