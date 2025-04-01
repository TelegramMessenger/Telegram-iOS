//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Hints.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class HashtagHints final : public Actor {
 public:
  HashtagHints(string mode, char first_character, ActorShared<> parent);

  void hashtag_used(const string &hashtag);

  void remove_hashtag(string hashtag, Promise<Unit> promise);

  void clear(Promise<Unit> promise);

  void query(const string &prefix, int32 limit, Promise<vector<string>> promise);

 private:
  string mode_;
  Hints hints_;
  char first_character_ = '#';
  bool sync_with_db_ = false;
  int64 counter_ = 0;

  ActorShared<> parent_;

  string get_key() const;

  void start_up() final;

  void hashtag_used_impl(const string &hashtag);
  void from_db(Result<string> data, bool dummy);
  vector<string> keys_to_strings(const vector<int64> &keys);
};

}  // namespace td
