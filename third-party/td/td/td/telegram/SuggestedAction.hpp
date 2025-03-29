//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/SuggestedAction.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void SuggestedAction::store(StorerT &storer) const {
  bool has_dialog_id = dialog_id_ != DialogId();
  bool has_otherwise_relogin_days = otherwise_relogin_days_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_dialog_id);
  STORE_FLAG(has_otherwise_relogin_days);
  END_STORE_FLAGS();
  td::store(type_, storer);
  if (has_dialog_id) {
    td::store(dialog_id_, storer);
  }
  if (has_otherwise_relogin_days) {
    td::store(otherwise_relogin_days_, storer);
  }
}

template <class ParserT>
void SuggestedAction::parse(ParserT &parser) {
  bool has_dialog_id;
  bool has_otherwise_relogin_days;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_dialog_id);
  PARSE_FLAG(has_otherwise_relogin_days);
  END_PARSE_FLAGS();
  td::parse(type_, parser);
  if (has_dialog_id) {
    td::parse(dialog_id_, parser);
  }
  if (has_otherwise_relogin_days) {
    td::parse(otherwise_relogin_days_, parser);
  }
}

}  // namespace td
