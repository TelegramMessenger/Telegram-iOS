//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/StoryInteractionInfo.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void StoryInteractionInfo::store(StorerT &storer) const {
  using td::store;
  bool has_recent_viewer_user_ids = !recent_viewer_user_ids_.empty();
  bool has_reaction_count = reaction_count_ > 0;
  bool know_has_viewers = true;
  bool has_forward_count = forward_count_ > 0;
  bool has_reaction_counts = !reaction_counts_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_recent_viewer_user_ids);
  STORE_FLAG(has_reaction_count);
  STORE_FLAG(know_has_viewers);
  STORE_FLAG(has_viewers_);
  STORE_FLAG(has_forward_count);
  STORE_FLAG(has_reaction_counts);
  END_STORE_FLAGS();
  store(view_count_, storer);
  if (has_recent_viewer_user_ids) {
    store(recent_viewer_user_ids_, storer);
  }
  if (has_reaction_count) {
    store(reaction_count_, storer);
  }
  if (has_forward_count) {
    store(forward_count_, storer);
  }
  if (has_reaction_counts) {
    store(reaction_counts_, storer);
  }
}

template <class ParserT>
void StoryInteractionInfo::parse(ParserT &parser) {
  using td::parse;
  bool has_recent_viewer_user_ids;
  bool has_reaction_count;
  bool know_has_viewers;
  bool has_forward_count;
  bool has_reaction_counts;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_recent_viewer_user_ids);
  PARSE_FLAG(has_reaction_count);
  PARSE_FLAG(know_has_viewers);
  PARSE_FLAG(has_viewers_);
  PARSE_FLAG(has_forward_count);
  PARSE_FLAG(has_reaction_counts);
  END_PARSE_FLAGS();
  parse(view_count_, parser);
  if (has_recent_viewer_user_ids) {
    parse(recent_viewer_user_ids_, parser);
  }
  if (has_reaction_count) {
    parse(reaction_count_, parser);
  }
  if (has_forward_count) {
    parse(forward_count_, parser);
  }
  if (has_reaction_counts) {
    parse(reaction_counts_, parser);
  }

  if (!know_has_viewers) {
    has_viewers_ = (view_count_ > 0 && !has_recent_viewer_user_ids) || reaction_count_ > 0;
  }
}

}  // namespace td
