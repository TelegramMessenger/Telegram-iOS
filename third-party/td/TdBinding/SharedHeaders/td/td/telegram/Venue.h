//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Location.h"
#include "td/telegram/SecretInputMedia.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/Version.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

class Td;

class Venue {
  Location location_;
  string title_;
  string address_;
  string provider_;
  string id_;
  string type_;

  friend bool operator==(const Venue &lhs, const Venue &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const Venue &venue);

 public:
  Venue() = default;

  Venue(Td *td, const tl_object_ptr<telegram_api::GeoPoint> &geo_point_ptr, string title, string address,
        string provider, string id, string type);

  Venue(Location location, string title, string address, string provider, string id, string type);

  explicit Venue(const tl_object_ptr<td_api::venue> &venue);

  bool empty() const;

  bool is_same(const string &provider, const string &id) const {
    return provider_ == provider && id_ == id;
  }

  Location &location();

  const Location &location() const;

  tl_object_ptr<td_api::venue> get_venue_object() const;

  tl_object_ptr<telegram_api::inputMediaVenue> get_input_media_venue() const;

  SecretInputMedia get_secret_input_media_venue() const;

  tl_object_ptr<telegram_api::inputBotInlineMessageMediaVenue> get_input_bot_inline_message_media_venue(
      tl_object_ptr<telegram_api::ReplyMarkup> &&reply_markup) const;

  telegram_api::object_ptr<telegram_api::mediaAreaVenue> get_input_media_area_venue(
      telegram_api::object_ptr<telegram_api::mediaAreaCoordinates> &&coordinates) const;

  template <class StorerT>
  void store(StorerT &storer) const {
    using td::store;
    store(location_, storer);
    store(title_, storer);
    store(address_, storer);
    store(provider_, storer);
    store(id_, storer);
    store(type_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    using td::parse;
    parse(location_, parser);
    parse(title_, parser);
    parse(address_, parser);
    parse(provider_, parser);
    parse(id_, parser);
    if (parser.version() >= static_cast<int32>(Version::AddVenueType)) {
      parse(type_, parser);
    }
  }
};

bool operator==(const Venue &lhs, const Venue &rhs);
bool operator!=(const Venue &lhs, const Venue &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const Venue &venue);

Result<Venue> process_input_message_venue(td_api::object_ptr<td_api::InputMessageContent> &&input_message_content)
    TD_WARN_UNUSED_RESULT;

}  // namespace td
