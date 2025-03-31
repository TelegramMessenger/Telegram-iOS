//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Venue.h"

#include "td/telegram/misc.h"
#include "td/telegram/secret_api.h"

namespace td {

Venue::Venue(Td *td, const tl_object_ptr<telegram_api::GeoPoint> &geo_point_ptr, string title, string address,
             string provider, string id, string type)
    : location_(td, geo_point_ptr)
    , title_(std::move(title))
    , address_(std::move(address))
    , provider_(std::move(provider))
    , id_(std::move(id))
    , type_(std::move(type)) {
}

Venue::Venue(Location location, string title, string address, string provider, string id, string type)
    : location_(location)
    , title_(std::move(title))
    , address_(std::move(address))
    , provider_(std::move(provider))
    , id_(std::move(id))
    , type_(std::move(type)) {
}

Venue::Venue(const tl_object_ptr<td_api::venue> &venue)
    : location_(venue->location_)
    , title_(venue->title_)
    , address_(venue->address_)
    , provider_(venue->provider_)
    , id_(venue->id_)
    , type_(venue->type_) {
}

bool Venue::empty() const {
  return location_.empty();
}

Location &Venue::location() {
  return location_;
}

const Location &Venue::location() const {
  return location_;
}

tl_object_ptr<td_api::venue> Venue::get_venue_object() const {
  return make_tl_object<td_api::venue>(location_.get_location_object(), title_, address_, provider_, id_, type_);
}

tl_object_ptr<telegram_api::inputMediaVenue> Venue::get_input_media_venue() const {
  return make_tl_object<telegram_api::inputMediaVenue>(location_.get_input_geo_point(), title_, address_, provider_,
                                                       id_, type_);
}

SecretInputMedia Venue::get_secret_input_media_venue() const {
  return SecretInputMedia{nullptr,
                          make_tl_object<secret_api::decryptedMessageMediaVenue>(
                              location_.get_latitude(), location_.get_longitude(), title_, address_, provider_, id_)};
}

tl_object_ptr<telegram_api::inputBotInlineMessageMediaVenue> Venue::get_input_bot_inline_message_media_venue(
    tl_object_ptr<telegram_api::ReplyMarkup> &&reply_markup) const {
  int32 flags = 0;
  if (reply_markup != nullptr) {
    flags |= telegram_api::inputBotInlineMessageMediaVenue::REPLY_MARKUP_MASK;
  }
  return make_tl_object<telegram_api::inputBotInlineMessageMediaVenue>(
      flags, location_.get_input_geo_point(), title_, address_, provider_, id_, type_, std::move(reply_markup));
}

telegram_api::object_ptr<telegram_api::mediaAreaVenue> Venue::get_input_media_area_venue(
    telegram_api::object_ptr<telegram_api::mediaAreaCoordinates> &&coordinates) const {
  return telegram_api::make_object<telegram_api::mediaAreaVenue>(std::move(coordinates), location_.get_fake_geo_point(),
                                                                 title_, address_, provider_, id_, type_);
}

bool operator==(const Venue &lhs, const Venue &rhs) {
  return lhs.location_ == rhs.location_ && lhs.title_ == rhs.title_ && lhs.address_ == rhs.address_ &&
         lhs.provider_ == rhs.provider_ && lhs.id_ == rhs.id_ && lhs.type_ == rhs.type_;
}

bool operator!=(const Venue &lhs, const Venue &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const Venue &venue) {
  return string_builder << "Venue[location = " << venue.location_ << ", title = " << venue.title_
                        << ", address = " << venue.address_ << ", provider = " << venue.provider_
                        << ", ID = " << venue.id_ << ", type = " << venue.type_ << "]";
}

Result<Venue> process_input_message_venue(tl_object_ptr<td_api::InputMessageContent> &&input_message_content) {
  CHECK(input_message_content != nullptr);
  CHECK(input_message_content->get_id() == td_api::inputMessageVenue::ID);
  auto venue = std::move(static_cast<td_api::inputMessageVenue *>(input_message_content.get())->venue_);
  if (venue == nullptr) {
    return Status::Error(400, "Venue must be non-empty");
  }

  if (!clean_input_string(venue->title_)) {
    return Status::Error(400, "Venue title must be encoded in UTF-8");
  }
  if (!clean_input_string(venue->address_)) {
    return Status::Error(400, "Venue address must be encoded in UTF-8");
  }
  if (!clean_input_string(venue->provider_)) {
    return Status::Error(400, "Venue provider must be encoded in UTF-8");
  }
  if (!clean_input_string(venue->id_)) {
    return Status::Error(400, "Venue identifier must be encoded in UTF-8");
  }
  if (!clean_input_string(venue->type_)) {
    return Status::Error(400, "Venue type must be encoded in UTF-8");
  }

  Venue result(venue);
  if (result.empty()) {
    return Status::Error(400, "Wrong venue location specified");
  }

  return result;
}

}  // namespace td
