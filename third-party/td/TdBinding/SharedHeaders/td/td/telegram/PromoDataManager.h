//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

class Td;

class PromoDataManager final : public Actor {
 public:
  PromoDataManager(Td *td, ActorShared<> parent);

  void init();

  void reload_promo_data();

  void remove_sponsored_dialog();

  void hide_promo_data(DialogId dialog_id);

 private:
  void tear_down() final;

  void start_up() final;

  void timeout_expired() final;

  void on_get_promo_data(Result<telegram_api::object_ptr<telegram_api::help_PromoData>> r_promo_data, bool dummy);

  void schedule_get_promo_data(int32 expires_in);

  Td *td_;
  ActorShared<> parent_;

  bool is_inited_ = false;
  bool reloading_promo_data_ = false;
  bool need_reload_promo_data_ = false;
};

}  // namespace td
