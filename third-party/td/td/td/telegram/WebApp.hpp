//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/WebApp.h"

#include "td/telegram/AnimationsManager.h"
#include "td/telegram/AnimationsManager.hpp"
#include "td/telegram/Photo.hpp"
#include "td/telegram/Td.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void WebApp::store(StorerT &storer) const {
  using td::store;
  bool has_animation = animation_file_id_.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_animation);
  END_STORE_FLAGS();
  store(id_, storer);
  store(access_hash_, storer);
  store(short_name_, storer);
  store(title_, storer);
  store(description_, storer);
  store(photo_, storer);
  if (has_animation) {
    storer.context()->td().get_actor_unsafe()->animations_manager_->store_animation(animation_file_id_, storer);
  }
  store(hash_, storer);
}

template <class ParserT>
void WebApp::parse(ParserT &parser) {
  using td::parse;
  bool has_animation;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_animation);
  END_PARSE_FLAGS();
  parse(id_, parser);
  parse(access_hash_, parser);
  parse(short_name_, parser);
  parse(title_, parser);
  parse(description_, parser);
  parse(photo_, parser);
  if (has_animation) {
    animation_file_id_ = parser.context()->td().get_actor_unsafe()->animations_manager_->parse_animation(parser);
  }
  parse(hash_, parser);
}

}  // namespace td
