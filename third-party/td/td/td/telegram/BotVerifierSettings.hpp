//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BotVerifierSettings.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void BotVerifierSettings::store(StorerT &storer) const {
  bool has_description = !description_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_description);
  STORE_FLAG(can_modify_custom_description_);
  END_STORE_FLAGS();
  td::store(icon_, storer);
  td::store(company_, storer);
  if (has_description) {
    td::store(description_, storer);
  }
}

template <class ParserT>
void BotVerifierSettings::parse(ParserT &parser) {
  bool has_description;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_description);
  PARSE_FLAG(can_modify_custom_description_);
  END_PARSE_FLAGS();
  td::parse(icon_, parser);
  td::parse(company_, parser);
  if (has_description) {
    td::parse(description_, parser);
  }
}

}  // namespace td
