//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/TopDialogCategory.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"

#include <array>
#include <utility>

namespace td {

class Td;

class TopDialogManager final : public Actor {
 public:
  TopDialogManager(Td *td, ActorShared<> parent);

  void init();

  void on_dialog_used(TopDialogCategory category, DialogId dialog_id, int32 date);

  void remove_dialog(TopDialogCategory category, DialogId dialog_id, Promise<Unit> &&promise);

  void get_top_dialogs(TopDialogCategory category, int32 limit, Promise<td_api::object_ptr<td_api::chats>> &&promise);

  int is_top_dialog(TopDialogCategory category, size_t limit, DialogId dialog_id) const;

  void update_rating_e_decay();

  void update_is_enabled(bool is_enabled);

 private:
  static constexpr size_t MAX_TOP_DIALOGS_LIMIT = 30;
  static constexpr int32 SERVER_SYNC_DELAY = 86400;      // seconds
  static constexpr int32 SERVER_SYNC_RESEND_DELAY = 60;  // seconds
  static constexpr int32 DB_SYNC_DELAY = 5;              // seconds

  Td *td_;
  ActorShared<> parent_;

  bool is_enabled_ = true;
  bool is_synchronized_ = false;
  int32 rating_e_decay_ = 241920;

  bool have_toggle_top_peers_query_ = false;
  bool have_pending_toggle_top_peers_query_ = false;
  bool pending_toggle_top_peers_query_ = false;
  bool was_first_sync_{false};
  enum class SyncState : int32 { None, Pending, Ok };
  SyncState db_sync_state_ = SyncState::None;
  Timestamp first_unsync_change_;
  SyncState server_sync_state_ = SyncState::None;
  Timestamp last_server_sync_;

  struct GetTopDialogsQuery {
    TopDialogCategory category;
    size_t limit;
    Promise<td_api::object_ptr<td_api::chats>> promise;
  };
  vector<GetTopDialogsQuery> pending_get_top_dialogs_;

  struct TopDialog {
    DialogId dialog_id;
    double rating = 0;
    bool operator<(const TopDialog &other) const {
      return std::make_pair(-rating, dialog_id.get()) < std::make_pair(-other.rating, other.dialog_id.get());
    }
  };

  struct TopDialogs {
    bool is_dirty = false;
    double rating_timestamp = 0;
    vector<TopDialog> dialogs;
  };
  template <class StorerT>
  friend void store(const TopDialog &top_dialog, StorerT &storer);
  template <class ParserT>
  friend void parse(TopDialog &top_dialog, ParserT &parser);
  template <class StorerT>
  friend void store(const TopDialogs &top_dialogs, StorerT &storer);
  template <class ParserT>
  friend void parse(TopDialogs &top_dialogs, ParserT &parser);

  std::array<TopDialogs, static_cast<size_t>(TopDialogCategory::Size)> by_category_;

  double rating_add(double now, double rating_timestamp) const;
  double current_rating_add(double server_time, double rating_timestamp) const;
  void normalize_rating();

  bool set_is_enabled(bool is_enabled);

  void send_toggle_top_peers(bool is_enabled);

  void on_toggle_top_peers(bool is_enabled, Result<Unit> &&result);

  void do_get_top_dialogs(GetTopDialogsQuery &&query);

  void on_load_dialogs(GetTopDialogsQuery &&query, vector<DialogId> &&dialog_ids);

  void do_get_top_peers();

  void do_save_top_dialogs();

  void on_first_sync();

  void on_get_top_peers(Result<telegram_api::object_ptr<telegram_api::contacts_TopPeers>> result);

  void try_start();

  void start_up() final;

  void loop() final;

  void tear_down() final;
};

}  // namespace td
