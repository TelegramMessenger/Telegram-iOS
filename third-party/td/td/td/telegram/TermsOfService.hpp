//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/TermsOfService.h"

#include "td/telegram/MessageEntity.hpp"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void TermsOfService::store(StorerT &storer) const {
  using td::store;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(show_popup_);
  END_STORE_FLAGS();
  store(id_, storer);
  store(text_, storer);
  store(min_user_age_, storer);
}

template <class ParserT>
void TermsOfService::parse(ParserT &parser) {
  using td::parse;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(show_popup_);
  END_PARSE_FLAGS();
  parse(id_, parser);
  parse(text_, parser);
  parse(min_user_age_, parser);
}

}  // namespace td
