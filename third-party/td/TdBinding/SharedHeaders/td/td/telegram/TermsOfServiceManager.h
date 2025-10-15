//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/TermsOfService.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <utility>

namespace td {

class Td;

class TermsOfServiceManager final : public Actor {
 public:
  TermsOfServiceManager(Td *td, ActorShared<> parent);

  void init();

  void accept_terms_of_service(string &&terms_of_service_id, Promise<Unit> &&promise);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  void tear_down() final;

  void start_up() final;

  void timeout_expired() final;

  void schedule_get_terms_of_service(int32 expires_in);

  void get_terms_of_service(Promise<std::pair<int32, TermsOfService>> promise);

  td_api::object_ptr<td_api::updateTermsOfService> get_update_terms_of_service_object() const;

  void on_get_terms_of_service(Result<std::pair<int32, TermsOfService>> result, bool dummy);

  void on_accept_terms_of_service(Promise<Unit> &&promise);

  Td *td_;
  ActorShared<> parent_;

  TermsOfService pending_terms_of_service_;

  bool is_inited_ = false;
};

}  // namespace td
