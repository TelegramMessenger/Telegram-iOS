//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MediaArea.h"
#include "td/telegram/MediaAreaCoordinates.hpp"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void MediaArea::GeoPointAddress::store(StorerT &storer) const {
  bool has_country_iso2 = !country_iso2_.empty();
  bool has_state = !state_.empty();
  bool has_city = !city_.empty();
  bool has_street = !street_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_country_iso2);
  STORE_FLAG(has_state);
  STORE_FLAG(has_city);
  STORE_FLAG(has_street);
  END_STORE_FLAGS();
  if (has_country_iso2) {
    td::store(country_iso2_, storer);
  }
  if (has_state) {
    td::store(state_, storer);
  }
  if (has_city) {
    td::store(city_, storer);
  }
  if (has_street) {
    td::store(street_, storer);
  }
}

template <class ParserT>
void MediaArea::GeoPointAddress::parse(ParserT &parser) {
  bool has_country_iso2;
  bool has_state;
  bool has_city;
  bool has_street;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_country_iso2);
  PARSE_FLAG(has_state);
  PARSE_FLAG(has_city);
  PARSE_FLAG(has_street);
  END_PARSE_FLAGS();
  if (has_country_iso2) {
    td::parse(country_iso2_, parser);
  }
  if (has_state) {
    td::parse(state_, parser);
  }
  if (has_city) {
    td::parse(city_, parser);
  }
  if (has_street) {
    td::parse(street_, parser);
  }
}

template <class StorerT>
void MediaArea::store(StorerT &storer) const {
  using td::store;
  bool has_input_query_id = input_query_id_ != 0;
  bool has_address = !address_.is_empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_input_query_id);
  STORE_FLAG(is_dark_);
  STORE_FLAG(is_flipped_);
  STORE_FLAG(is_old_message_);
  STORE_FLAG(has_address);
  END_STORE_FLAGS();
  store(type_, storer);
  store(coordinates_, storer);
  switch (type_) {
    case Type::Location:
      store(location_, storer);
      break;
    case Type::Venue:
      store(venue_, storer);
      if (has_input_query_id) {
        store(input_query_id_, storer);
        store(input_result_id_, storer);
      }
      break;
    case Type::Reaction:
      store(reaction_type_, storer);
      break;
    case Type::Message:
      store(message_full_id_, storer);
      break;
    case Type::Url:
      store(url_, storer);
      break;
    case Type::Weather:
      store(temperature_, storer);
      store(url_, storer);
      store(color_, storer);
      break;
    case Type::StarGift:
      store(url_, storer);
      break;
    default:
      UNREACHABLE();
  }
  if (has_address) {
    store(address_, storer);
  }
}

template <class ParserT>
void MediaArea::parse(ParserT &parser) {
  using td::parse;
  bool has_input_query_id;
  bool has_address;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_input_query_id);
  PARSE_FLAG(is_dark_);
  PARSE_FLAG(is_flipped_);
  PARSE_FLAG(is_old_message_);
  PARSE_FLAG(has_address);
  END_PARSE_FLAGS();
  parse(type_, parser);
  parse(coordinates_, parser);
  switch (type_) {
    case Type::Location:
      parse(location_, parser);
      break;
    case Type::Venue:
      parse(venue_, parser);
      if (has_input_query_id) {
        parse(input_query_id_, parser);
        parse(input_result_id_, parser);
      }
      break;
    case Type::Reaction:
      parse(reaction_type_, parser);
      break;
    case Type::Message:
      parse(message_full_id_, parser);
      break;
    case Type::Url:
      parse(url_, parser);
      break;
    case Type::Weather:
      parse(temperature_, parser);
      parse(url_, parser);
      parse(color_, parser);
      break;
    case Type::StarGift:
      parse(url_, parser);
      break;
    default:
      parser.set_error("Load invalid area type");
  }
  if (has_address) {
    parse(address_, parser);
  }
}

}  // namespace td
