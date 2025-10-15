//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/SuggestedAction.h"
#include "td/telegram/td_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class Td;

class SuggestedActionManager final : public Actor {
 public:
  SuggestedActionManager(Td *td, ActorShared<> parent);

  void update_suggested_actions(vector<SuggestedAction> &&suggested_actions);

  void hide_suggested_action(SuggestedAction suggested_action);

  void dismiss_suggested_action(SuggestedAction suggested_action, Promise<Unit> &&promise);

  void remove_dialog_suggested_action(SuggestedAction action);

  void set_dialog_pending_suggestions(DialogId dialog_id, vector<string> &&pending_suggestions);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  void start_up() final;

  void hangup() final;

  void tear_down() final;

  static string get_suggested_actions_database_key();

  void save_suggested_actions();

  void on_dismiss_suggested_action(SuggestedAction suggested_action, Result<Unit> &&result);

  Td *td_;
  ActorShared<> parent_;

  vector<SuggestedAction> suggested_actions_;
  FlatHashMap<DialogId, vector<SuggestedAction>, DialogIdHash> dialog_suggested_actions_;
  FlatHashMap<SuggestedAction, vector<Promise<Unit>>, SuggestedActionHash> dismiss_suggested_action_queries_;
};

}  // namespace td
