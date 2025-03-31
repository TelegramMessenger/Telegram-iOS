//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogFilter.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void DialogFilter::store(StorerT &storer) const {
  using td::store;
  bool has_pinned_dialog_ids = !pinned_dialog_ids_.empty();
  bool has_included_dialog_ids = !included_dialog_ids_.empty();
  bool has_excluded_dialog_ids = !excluded_dialog_ids_.empty();
  bool has_color_id = color_id_ != -1;
  bool has_title_entities = !title_.entities.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(exclude_muted_);
  STORE_FLAG(exclude_read_);
  STORE_FLAG(exclude_archived_);
  STORE_FLAG(include_contacts_);
  STORE_FLAG(include_non_contacts_);
  STORE_FLAG(include_bots_);
  STORE_FLAG(include_groups_);
  STORE_FLAG(include_channels_);
  STORE_FLAG(has_pinned_dialog_ids);
  STORE_FLAG(has_included_dialog_ids);
  STORE_FLAG(has_excluded_dialog_ids);
  STORE_FLAG(is_shareable_);
  STORE_FLAG(has_my_invites_);
  STORE_FLAG(has_color_id);
  STORE_FLAG(has_title_entities);
  STORE_FLAG(animate_title_);
  END_STORE_FLAGS();
  store(dialog_filter_id_, storer);
  store(title_.text, storer);
  if (has_title_entities) {
    store(title_.entities, storer);
  }
  store(emoji_, storer);
  if (has_pinned_dialog_ids) {
    store(pinned_dialog_ids_, storer);
  }
  if (has_included_dialog_ids) {
    store(included_dialog_ids_, storer);
  }
  if (has_excluded_dialog_ids) {
    store(excluded_dialog_ids_, storer);
  }
  if (has_color_id) {
    store(color_id_, storer);
  }
}

template <class ParserT>
void DialogFilter::parse(ParserT &parser) {
  using td::parse;
  bool has_pinned_dialog_ids;
  bool has_included_dialog_ids;
  bool has_excluded_dialog_ids;
  bool has_color_id;
  bool has_title_entities;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(exclude_muted_);
  PARSE_FLAG(exclude_read_);
  PARSE_FLAG(exclude_archived_);
  PARSE_FLAG(include_contacts_);
  PARSE_FLAG(include_non_contacts_);
  PARSE_FLAG(include_bots_);
  PARSE_FLAG(include_groups_);
  PARSE_FLAG(include_channels_);
  PARSE_FLAG(has_pinned_dialog_ids);
  PARSE_FLAG(has_included_dialog_ids);
  PARSE_FLAG(has_excluded_dialog_ids);
  PARSE_FLAG(is_shareable_);
  PARSE_FLAG(has_my_invites_);
  PARSE_FLAG(has_color_id);
  PARSE_FLAG(has_title_entities);
  PARSE_FLAG(animate_title_);
  END_PARSE_FLAGS();
  parse(dialog_filter_id_, parser);
  parse(title_.text, parser);
  if (has_title_entities) {
    parse(title_.entities, parser);
    keep_only_custom_emoji(title_);
  }
  parse(emoji_, parser);
  if (has_pinned_dialog_ids) {
    parse(pinned_dialog_ids_, parser);
  }
  if (has_included_dialog_ids) {
    parse(included_dialog_ids_, parser);
  }
  if (has_excluded_dialog_ids) {
    parse(excluded_dialog_ids_, parser);
  }
  if (has_color_id) {
    parse(color_id_, parser);
  } else {
    color_id_ = -1;
  }
}

}  // namespace td
