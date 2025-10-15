//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/NetQuery.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"

#include <utility>

namespace td {

class NetQueryVerifier final : public Actor {
 public:
  explicit NetQueryVerifier(ActorShared<> parent) : parent_(std::move(parent)) {
  }

  void verify(NetQueryPtr query, string nonce);

  void check_recaptcha(NetQueryPtr query, string action, string recaptcha_key_id);

  void set_verification_token(int64 query_id, string &&token, Promise<Unit> &&promise);

 private:
  void tear_down() final;

  ActorShared<> parent_;

  struct Query {
    enum class Type : int32 { Verification, Recaptcha };
    Type type_ = Type::Verification;
    string nonce_or_action_;
    string recaptcha_key_id_;
  };

  FlatHashMap<int64, std::pair<NetQueryPtr, Query>> queries_;
  int64 next_query_id_ = 1;
};

}  // namespace td
