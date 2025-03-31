//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BackgroundInfo.h"
#include "td/telegram/BackgroundManager.h"
#include "td/telegram/BackgroundType.hpp"
#include "td/telegram/Td.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void BackgroundInfo::store(StorerT &storer) const {
  storer.context()->td().get_actor_unsafe()->background_manager_->store_background(background_id_, storer);
  td::store(background_type_, storer);
}

template <class ParserT>
void BackgroundInfo::parse(ParserT &parser) {
  parser.context()->td().get_actor_unsafe()->background_manager_->parse_background(background_id_, parser);
  td::parse(background_type_, parser);
}

}  // namespace td
