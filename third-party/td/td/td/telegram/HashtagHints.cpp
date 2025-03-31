//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/HashtagHints.h"

#include "td/telegram/Global.h"
#include "td/telegram/TdDb.h"

#include "td/db/SqliteKeyValueAsync.h"

#include "td/utils/HashTableUtils.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/utf8.h"

namespace td {

HashtagHints::HashtagHints(string mode, char first_character, ActorShared<> parent)
    : mode_(std::move(mode)), first_character_(first_character), parent_(std::move(parent)) {
}

void HashtagHints::start_up() {
  if (G()->use_sqlite_pmc()) {  // TODO hashtag hints should not depend on use_sqlite_pmc
    G()->td_db()->get_sqlite_pmc()->get(get_key(),
                                        PromiseCreator::lambda([actor_id = actor_id(this)](Result<string> res) {
                                          send_closure(actor_id, &HashtagHints::from_db, std::move(res), false);
                                        }));
  }
}

void HashtagHints::hashtag_used(const string &hashtag) {
  if (!sync_with_db_) {
    return;
  }
  hashtag_used_impl(hashtag);
  G()->td_db()->get_sqlite_pmc()->set(get_key(), serialize(keys_to_strings(hints_.search_empty(101).second)),
                                      Promise<Unit>());
}

void HashtagHints::remove_hashtag(string hashtag, Promise<Unit> promise) {
  if (!sync_with_db_) {
    return promise.set_value(Unit());
  }
  if (hashtag[0] == first_character_) {
    hashtag = hashtag.substr(1);
  }
  auto key = Hash<string>()(hashtag);
  if (hints_.has_key(key)) {
    hints_.remove(key);
    G()->td_db()->get_sqlite_pmc()->set(get_key(), serialize(keys_to_strings(hints_.search_empty(101).second)),
                                        Promise<Unit>());
    promise.set_value(Unit());  // set promise explicitly, because sqlite_pmc waits for too long before setting promise
  } else {
    promise.set_value(Unit());
  }
}

void HashtagHints::clear(Promise<Unit> promise) {
  if (!sync_with_db_) {
    return promise.set_value(Unit());
  }
  hints_ = {};
  G()->td_db()->get_sqlite_pmc()->set(get_key(), serialize(vector<string>()), Promise<Unit>());
  promise.set_value(Unit());
}

void HashtagHints::query(const string &prefix, int32 limit, Promise<vector<string>> promise) {
  if (!sync_with_db_) {
    promise.set_value(vector<string>());
    return;
  }

  auto query = Slice(prefix).substr(prefix[0] == first_character_ ? 1 : 0);
  auto result = query.empty() ? hints_.search_empty(limit) : hints_.search(query, limit);
  promise.set_value(keys_to_strings(result.second));
}

string HashtagHints::get_key() const {
  return "hashtag_hints#" + mode_;
}

void HashtagHints::hashtag_used_impl(const string &hashtag) {
  if (!check_utf8(hashtag)) {
    LOG(ERROR) << "Trying to add invalid UTF-8 hashtag \"" << hashtag << '"';
    return;
  }

  auto key = Hash<string>()(hashtag);
  hints_.add(key, hashtag);
  hints_.set_rating(key, -++counter_);
}

void HashtagHints::from_db(Result<string> data, bool dummy) {
  if (G()->close_flag()) {
    return;
  }

  sync_with_db_ = true;
  if (data.is_error() || data.ok().empty()) {
    return;
  }
  vector<string> hashtags;
  auto status = unserialize(hashtags, data.ok());
  if (status.is_error()) {
    LOG(ERROR) << "Failed to unserialize hashtag hints: " << status;
    return;
  }

  for (auto it = hashtags.rbegin(); it != hashtags.rend(); ++it) {
    hashtag_used_impl(*it);
  }
}

vector<string> HashtagHints::keys_to_strings(const vector<int64> &keys) {
  vector<string> result;
  result.reserve(keys.size());
  for (auto &it : keys) {
    result.push_back(hints_.key_to_string(it));
  }
  return result;
}

}  // namespace td
