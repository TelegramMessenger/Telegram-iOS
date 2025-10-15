//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Location.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

class Td;

class DialogLocation {
  Location location_;
  string address_;

  friend bool operator==(const DialogLocation &lhs, const DialogLocation &rhs);
  friend bool operator!=(const DialogLocation &lhs, const DialogLocation &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const DialogLocation &location);

 public:
  DialogLocation() = default;

  DialogLocation(Td *td, telegram_api::object_ptr<telegram_api::ChannelLocation> &&channel_location_ptr);

  DialogLocation(Td *td, telegram_api::object_ptr<telegram_api::businessLocation> &&business_location);

  explicit DialogLocation(td_api::object_ptr<td_api::chatLocation> &&chat_location);

  explicit DialogLocation(td_api::object_ptr<td_api::businessLocation> &&business_location);

  bool empty() const;

  td_api::object_ptr<td_api::chatLocation> get_chat_location_object() const;

  td_api::object_ptr<td_api::businessLocation> get_business_location_object() const;

  telegram_api::object_ptr<telegram_api::InputGeoPoint> get_input_geo_point() const;

  const string &get_address() const;

  template <class StorerT>
  void store(StorerT &storer) const {
    using td::store;
    store(location_, storer);
    store(address_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    using td::parse;
    parse(location_, parser);
    parse(address_, parser);
  }
};

bool operator==(const DialogLocation &lhs, const DialogLocation &rhs);
bool operator!=(const DialogLocation &lhs, const DialogLocation &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const DialogLocation &location);

}  // namespace td
