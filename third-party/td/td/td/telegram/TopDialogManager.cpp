//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/TopDialogManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/actor/PromiseFuture.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/tl_helpers.h"

#include <algorithm>
#include <cmath>
#include <iterator>

namespace td {

class GetTopPeersQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::contacts_TopPeers>> promise_;

 public:
  explicit GetTopPeersQuery(Promise<telegram_api::object_ptr<telegram_api::contacts_TopPeers>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(int64 hash) {
    int32 flags =
        telegram_api::contacts_getTopPeers::CORRESPONDENTS_MASK | telegram_api::contacts_getTopPeers::BOTS_PM_MASK |
        telegram_api::contacts_getTopPeers::BOTS_INLINE_MASK | telegram_api::contacts_getTopPeers::GROUPS_MASK |
        telegram_api::contacts_getTopPeers::CHANNELS_MASK | telegram_api::contacts_getTopPeers::PHONE_CALLS_MASK |
        telegram_api::contacts_getTopPeers::FORWARD_USERS_MASK |
        telegram_api::contacts_getTopPeers::FORWARD_CHATS_MASK | telegram_api::contacts_getTopPeers::BOTS_APP_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::contacts_getTopPeers(flags, false /*ignored*/, false /*ignored*/, false /*ignored*/,
                                           false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
                                           false /*ignored*/, false /*ignored*/, 0 /*offset*/, 100 /*limit*/, hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_getTopPeers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ToggleTopPeersQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ToggleTopPeersQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(bool is_enabled) {
    send_query(G()->net_query_creator().create(telegram_api::contacts_toggleTopPeers(is_enabled)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_toggleTopPeers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ResetTopPeerRatingQuery final : public Td::ResultHandler {
  DialogId dialog_id_;

 public:
  void send(TopDialogCategory category, DialogId dialog_id) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::contacts_resetTopPeerRating(get_input_top_peer_category(category), std::move(input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_resetTopPeerRating>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    // ignore the result
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ResetTopPeerRatingQuery")) {
      LOG(INFO) << "Receive error for ResetTopPeerRatingQuery: " << status;
    }
  }
};

TopDialogManager::TopDialogManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void TopDialogManager::update_is_enabled(bool is_enabled) {
  if (td_->auth_manager_ == nullptr || !td_->auth_manager_->is_authorized() || td_->auth_manager_->is_bot()) {
    return;
  }

  if (set_is_enabled(is_enabled)) {
    G()->td_db()->get_binlog_pmc()->set("top_peers_enabled", is_enabled ? "1" : "0");
    send_toggle_top_peers(is_enabled);

    loop();
  }
}

bool TopDialogManager::set_is_enabled(bool is_enabled) {
  if (is_enabled_ == is_enabled) {
    return false;
  }

  LOG(DEBUG) << "Change top chats is_enabled to " << is_enabled;
  is_enabled_ = is_enabled;
  try_start();
  return true;
}

void TopDialogManager::send_toggle_top_peers(bool is_enabled) {
  if (G()->close_flag()) {
    return;
  }

  if (have_toggle_top_peers_query_) {
    have_pending_toggle_top_peers_query_ = true;
    pending_toggle_top_peers_query_ = is_enabled;
    return;
  }

  LOG(DEBUG) << "Send toggle top peers query to " << is_enabled;
  have_toggle_top_peers_query_ = true;

  auto promise = PromiseCreator::lambda([actor_id = actor_id(this), is_enabled](Result<Unit> result) {
    send_closure(actor_id, &TopDialogManager::on_toggle_top_peers, is_enabled, std::move(result));
  });
  td_->create_handler<ToggleTopPeersQuery>(std::move(promise))->send(is_enabled);
}

void TopDialogManager::on_toggle_top_peers(bool is_enabled, Result<Unit> &&result) {
  CHECK(have_toggle_top_peers_query_);
  have_toggle_top_peers_query_ = false;

  if (have_pending_toggle_top_peers_query_) {
    have_pending_toggle_top_peers_query_ = false;
    if (pending_toggle_top_peers_query_ != is_enabled) {
      send_toggle_top_peers(pending_toggle_top_peers_query_);
      return;
    }
  }

  if (result.is_ok()) {
    // everything is synchronized
    G()->td_db()->get_binlog_pmc()->erase("top_peers_enabled");
  } else {
    // let's resend the query forever
    send_toggle_top_peers(is_enabled);
  }
  loop();
}

void TopDialogManager::on_dialog_used(TopDialogCategory category, DialogId dialog_id, int32 date) {
  CHECK(!td_->auth_manager_->is_bot());
  if (!is_enabled_) {
    return;
  }
  auto pos = static_cast<size_t>(category);
  CHECK(pos < by_category_.size());
  auto &top_dialogs = by_category_[pos];

  top_dialogs.is_dirty = true;
  auto it = std::find_if(top_dialogs.dialogs.begin(), top_dialogs.dialogs.end(),
                         [&](auto &top_dialog) { return top_dialog.dialog_id == dialog_id; });
  if (it == top_dialogs.dialogs.end()) {
    TopDialog top_dialog;
    top_dialog.dialog_id = dialog_id;
    top_dialogs.dialogs.push_back(top_dialog);
    it = top_dialogs.dialogs.end() - 1;
  }

  auto delta = rating_add(date, top_dialogs.rating_timestamp);
  it->rating += delta;
  while (it != top_dialogs.dialogs.begin()) {
    auto next = std::prev(it);
    if (*next < *it) {
      break;
    }
    std::swap(*next, *it);
    it = next;
  }

  LOG(INFO) << "Update " << get_top_dialog_category_name(category) << " rating of " << dialog_id << " by " << delta;

  if (!first_unsync_change_) {
    first_unsync_change_ = Timestamp::now_cached();
  }
  loop();
}

void TopDialogManager::remove_dialog(TopDialogCategory category, DialogId dialog_id, Promise<Unit> &&promise) {
  if (category == TopDialogCategory::Size) {
    return promise.set_error(Status::Error(400, "Top chat category must be non-empty"));
  }
  TRY_STATUS_PROMISE(promise,
                     td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read, "remove_dialog"));
  CHECK(!td_->auth_manager_->is_bot());
  if (!is_enabled_) {
    return promise.set_value(Unit());
  }

  if (category == TopDialogCategory::ForwardUsers && dialog_id.get_type() != DialogType::User) {
    category = TopDialogCategory::ForwardChats;
  }

  auto pos = static_cast<size_t>(category);
  CHECK(pos < by_category_.size());
  auto &top_dialogs = by_category_[pos];

  td_->create_handler<ResetTopPeerRatingQuery>()->send(category, dialog_id);

  auto it = std::find_if(top_dialogs.dialogs.begin(), top_dialogs.dialogs.end(),
                         [&](auto &top_dialog) { return top_dialog.dialog_id == dialog_id; });
  if (it == top_dialogs.dialogs.end()) {
    return promise.set_value(Unit());
  }

  top_dialogs.is_dirty = true;
  top_dialogs.dialogs.erase(it);
  if (!first_unsync_change_) {
    first_unsync_change_ = Timestamp::now_cached();
  }
  loop();
  promise.set_value(Unit());
}

void TopDialogManager::get_top_dialogs(TopDialogCategory category, int32 limit,
                                       Promise<td_api::object_ptr<td_api::chats>> &&promise) {
  if (category == TopDialogCategory::Size) {
    return promise.set_error(Status::Error(400, "Top chat category must be non-empty"));
  }
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Limit must be positive"));
  }
  if (!is_enabled_) {
    return promise.set_error(Status::Error(400, "Top chat computation is disabled"));
  }

  GetTopDialogsQuery query;
  query.category = category;
  query.limit = static_cast<size_t>(limit);
  query.promise = std::move(promise);
  pending_get_top_dialogs_.push_back(std::move(query));
  loop();
}

int TopDialogManager::is_top_dialog(TopDialogCategory category, size_t limit, DialogId dialog_id) const {
  CHECK(category != TopDialogCategory::Size);
  CHECK(category != TopDialogCategory::ForwardUsers);
  CHECK(limit > 0);
  CHECK(!td_->auth_manager_->is_bot());
  if (!is_enabled_) {
    return 0;
  }

  vector<DialogId> dialog_ids;
  auto pos = static_cast<size_t>(category);
  CHECK(pos < by_category_.size());
  const auto &dialogs = by_category_[pos].dialogs;
  for (size_t i = 0; i < limit && i < dialogs.size(); i++) {
    if (dialogs[i].dialog_id == dialog_id) {
      return 1;
    }
  }
  return is_synchronized_ ? 0 : -1;
}

void TopDialogManager::update_rating_e_decay() {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  rating_e_decay_ = narrow_cast<int32>(G()->get_option_integer("rating_e_decay", rating_e_decay_));
}

template <class StorerT>
void store(const TopDialogManager::TopDialog &top_dialog, StorerT &storer) {
  using ::td::store;
  store(top_dialog.dialog_id, storer);
  store(top_dialog.rating, storer);
}

template <class ParserT>
void parse(TopDialogManager::TopDialog &top_dialog, ParserT &parser) {
  using ::td::parse;
  parse(top_dialog.dialog_id, parser);
  parse(top_dialog.rating, parser);
}

template <class StorerT>
void store(const TopDialogManager::TopDialogs &top_dialogs, StorerT &storer) {
  using ::td::store;
  store(top_dialogs.rating_timestamp, storer);
  store(top_dialogs.dialogs, storer);
}

template <class ParserT>
void parse(TopDialogManager::TopDialogs &top_dialogs, ParserT &parser) {
  using ::td::parse;
  parse(top_dialogs.rating_timestamp, parser);
  parse(top_dialogs.dialogs, parser);
}

double TopDialogManager::rating_add(double now, double rating_timestamp) const {
  return std::exp((now - rating_timestamp) / rating_e_decay_);
}

double TopDialogManager::current_rating_add(double server_time, double rating_timestamp) const {
  return rating_add(server_time, rating_timestamp);
}

void TopDialogManager::normalize_rating() {
  auto server_time = G()->server_time();
  for (auto &top_dialogs : by_category_) {
    auto div_by = current_rating_add(server_time, top_dialogs.rating_timestamp);
    top_dialogs.rating_timestamp = server_time;
    for (auto &dialog : top_dialogs.dialogs) {
      dialog.rating /= div_by;
    }
    top_dialogs.is_dirty = true;
  }
  db_sync_state_ = SyncState::None;
}

void TopDialogManager::do_get_top_dialogs(GetTopDialogsQuery &&query) {
  vector<DialogId> dialog_ids;
  if (query.category != TopDialogCategory::ForwardUsers) {
    auto pos = static_cast<size_t>(query.category);
    CHECK(pos < by_category_.size());
    dialog_ids = transform(by_category_[pos].dialogs, [](const auto &x) { return x.dialog_id; });
  } else {
    // merge ForwardUsers and ForwardChats
    auto &users = by_category_[static_cast<size_t>(TopDialogCategory::ForwardUsers)];
    auto &chats = by_category_[static_cast<size_t>(TopDialogCategory::ForwardChats)];
    size_t users_pos = 0;
    size_t chats_pos = 0;
    while (users_pos < users.dialogs.size() || chats_pos < chats.dialogs.size()) {
      if (chats_pos == chats.dialogs.size() ||
          (users_pos < users.dialogs.size() && users.dialogs[users_pos] < chats.dialogs[chats_pos])) {
        dialog_ids.push_back(users.dialogs[users_pos++].dialog_id);
      } else {
        dialog_ids.push_back(chats.dialogs[chats_pos++].dialog_id);
      }
    }
  }

  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), query = std::move(query)](Result<vector<DialogId>> r_dialog_ids) mutable {
        if (r_dialog_ids.is_error()) {
          return query.promise.set_error(r_dialog_ids.move_as_error());
        }
        send_closure(actor_id, &TopDialogManager::on_load_dialogs, std::move(query), r_dialog_ids.move_as_ok());
      });
  send_closure(td_->messages_manager_actor_, &MessagesManager::load_dialogs, std::move(dialog_ids), std::move(promise));
}

void TopDialogManager::on_load_dialogs(GetTopDialogsQuery &&query, vector<DialogId> &&dialog_ids) {
  auto limit = std::min({query.limit, MAX_TOP_DIALOGS_LIMIT, dialog_ids.size()});
  vector<DialogId> result;
  result.reserve(limit);
  for (auto dialog_id : dialog_ids) {
    if (dialog_id.get_type() == DialogType::User) {
      auto user_id = dialog_id.get_user_id();
      if (td_->user_manager_->is_user_deleted(user_id)) {
        LOG(INFO) << "Skip deleted " << user_id;
        continue;
      }
      if (td_->user_manager_->get_my_id() == user_id) {
        LOG(INFO) << "Skip self " << user_id;
        continue;
      }
      if (query.category == TopDialogCategory::BotInline || query.category == TopDialogCategory::BotPM) {
        auto r_bot_info = td_->user_manager_->get_bot_data(user_id);
        if (r_bot_info.is_error()) {
          LOG(INFO) << "Skip not a bot " << user_id;
          continue;
        }
        if (query.category == TopDialogCategory::BotInline &&
            (r_bot_info.ok().username.empty() || !r_bot_info.ok().is_inline)) {
          LOG(INFO) << "Skip not inline bot " << user_id;
          continue;
        }
      }
    }

    result.push_back(dialog_id);
    if (result.size() == limit) {
      break;
    }
  }

  query.promise.set_value(
      td_->dialog_manager_->get_chats_object(-1, std::move(result), "TopDialogManager::on_load_dialogs"));
}

void TopDialogManager::do_get_top_peers() {
  std::vector<uint64> peer_ids;
  for (auto &category : by_category_) {
    for (auto &top_dialog : category.dialogs) {
      auto dialog_id = top_dialog.dialog_id;
      switch (dialog_id.get_type()) {
        case DialogType::User:
          peer_ids.push_back(dialog_id.get_user_id().get());
          break;
        case DialogType::Chat:
          peer_ids.push_back(dialog_id.get_chat_id().get());
          break;
        case DialogType::Channel:
          peer_ids.push_back(dialog_id.get_channel_id().get());
          break;
        default:
          break;
      }
    }
  }
  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this)](Result<telegram_api::object_ptr<telegram_api::contacts_TopPeers>> result) {
        send_closure(actor_id, &TopDialogManager::on_get_top_peers, std::move(result));
      });
  td_->create_handler<GetTopPeersQuery>(std::move(promise))->send(get_vector_hash(peer_ids));
}

void TopDialogManager::on_get_top_peers(Result<telegram_api::object_ptr<telegram_api::contacts_TopPeers>> result) {
  normalize_rating();  // once a day too

  if (result.is_error()) {
    last_server_sync_ = Timestamp::in(SERVER_SYNC_RESEND_DELAY - SERVER_SYNC_DELAY);
    loop();
    return;
  }

  last_server_sync_ = Timestamp::now();
  server_sync_state_ = SyncState::Ok;
  is_synchronized_ = true;

  auto top_peers_parent = result.move_as_ok();
  LOG(DEBUG) << "Receive contacts_getTopPeers result: " << to_string(top_peers_parent);
  switch (top_peers_parent->get_id()) {
    case telegram_api::contacts_topPeersNotModified::ID:
      // nothing to do
      break;
    case telegram_api::contacts_topPeersDisabled::ID:
      G()->set_option_boolean("disable_top_chats", true);
      set_is_enabled(false);  // apply immediately
      break;
    case telegram_api::contacts_topPeers::ID: {
      G()->set_option_empty("disable_top_chats");
      set_is_enabled(true);  // apply immediately
      auto top_peers = move_tl_object_as<telegram_api::contacts_topPeers>(std::move(top_peers_parent));

      td_->user_manager_->on_get_users(std::move(top_peers->users_), "on get top chats");
      td_->chat_manager_->on_get_chats(std::move(top_peers->chats_), "on get top chats");
      for (auto &category : top_peers->categories_) {
        auto dialog_category = get_top_dialog_category(category->category_);
        auto pos = static_cast<size_t>(dialog_category);
        CHECK(pos < by_category_.size());
        auto &top_dialogs = by_category_[pos];

        top_dialogs.is_dirty = true;
        top_dialogs.dialogs.clear();
        for (auto &top_peer : category->peers_) {
          TopDialog top_dialog;
          top_dialog.dialog_id = DialogId(top_peer->peer_);
          top_dialog.rating = top_peer->rating_;
          top_dialogs.dialogs.push_back(std::move(top_dialog));
        }
      }
      db_sync_state_ = SyncState::None;
      break;
    }
    default:
      UNREACHABLE();
  }

  G()->td_db()->get_binlog_pmc()->set("top_dialogs_ts", to_string(static_cast<uint32>(Clocks::system())));
  loop();
}

void TopDialogManager::do_save_top_dialogs() {
  LOG(INFO) << "Save top chats";
  for (size_t top_dialog_category_i = 0; top_dialog_category_i < by_category_.size(); top_dialog_category_i++) {
    auto &top_dialogs = by_category_[top_dialog_category_i];
    if (!top_dialogs.is_dirty) {
      continue;
    }
    top_dialogs.is_dirty = false;

    if (G()->use_chat_info_database()) {
      auto top_dialog_category = TopDialogCategory(top_dialog_category_i);
      auto key = PSTRING() << "top_dialogs#" << get_top_dialog_category_name(top_dialog_category);
      G()->td_db()->get_binlog_pmc()->set(key, log_event_store(top_dialogs).as_slice().str());
    }
  }
  db_sync_state_ = SyncState::Ok;
  first_unsync_change_ = Timestamp();
}

void TopDialogManager::start_up() {
  init();
}

void TopDialogManager::tear_down() {
  parent_.reset();
}

void TopDialogManager::init() {
  if (td_->auth_manager_ == nullptr || !td_->auth_manager_->is_authorized()) {
    return;
  }

  is_enabled_ = !G()->get_option_boolean("disable_top_chats");
  update_rating_e_decay();

  string need_update_top_peers = G()->td_db()->get_binlog_pmc()->get("top_peers_enabled");
  if (!need_update_top_peers.empty()) {
    send_toggle_top_peers(need_update_top_peers[0] == '1');
  }

  try_start();
  loop();
}

void TopDialogManager::try_start() {
  was_first_sync_ = false;
  first_unsync_change_ = Timestamp();
  server_sync_state_ = SyncState::None;
  last_server_sync_ = Timestamp();

  if (td_->auth_manager_->is_bot()) {
    return;
  }

  LOG(DEBUG) << "Init is enabled: " << is_enabled_;

  auto di_top_dialogs_ts = G()->td_db()->get_binlog_pmc()->get("top_dialogs_ts");
  if (!di_top_dialogs_ts.empty()) {
    last_server_sync_ = Timestamp::in(to_integer<uint32>(di_top_dialogs_ts) - Clocks::system());
    if (last_server_sync_.is_in_past()) {
      server_sync_state_ = SyncState::Ok;
    }
    is_synchronized_ = G()->use_chat_info_database();
  }

  if (is_enabled_ && G()->use_chat_info_database()) {
    for (size_t top_dialog_category_i = 0; top_dialog_category_i < by_category_.size(); top_dialog_category_i++) {
      auto top_dialog_category = TopDialogCategory(top_dialog_category_i);
      auto key = PSTRING() << "top_dialogs#" << get_top_dialog_category_name(top_dialog_category);
      auto value = G()->td_db()->get_binlog_pmc()->get(key);

      auto &top_dialogs = by_category_[top_dialog_category_i];
      top_dialogs.is_dirty = false;
      if (value.empty()) {
        continue;
      }
      log_event_parse(top_dialogs, value).ensure();
    }
    normalize_rating();
  } else {
    G()->td_db()->get_binlog_pmc()->erase_by_prefix("top_dialogs#");
    for (auto &top_dialogs : by_category_) {
      top_dialogs = {};
    }
  }
  db_sync_state_ = SyncState::Ok;

  send_closure(G()->state_manager(), &StateManager::wait_first_sync,
               create_event_promise(self_closure(this, &TopDialogManager::on_first_sync)));
}

void TopDialogManager::on_first_sync() {
  was_first_sync_ = true;
  loop();
}

void TopDialogManager::loop() {
  if (G()->close_flag() || td_->auth_manager_->is_bot()) {
    return;
  }

  if (!pending_get_top_dialogs_.empty() && (is_synchronized_ || !is_enabled_)) {
    for (auto &query : pending_get_top_dialogs_) {
      do_get_top_dialogs(std::move(query));
    }
    pending_get_top_dialogs_.clear();
  }

  // server sync
  Timestamp server_sync_timeout;
  if (server_sync_state_ == SyncState::Ok) {
    server_sync_timeout = pending_get_top_dialogs_.empty() ? Timestamp::at(last_server_sync_.at() + SERVER_SYNC_DELAY)
                                                           : Timestamp::now_cached();
    if (server_sync_timeout.is_in_past()) {
      server_sync_state_ = SyncState::None;
    }
  }

  Timestamp wakeup_timeout;
  if (server_sync_state_ == SyncState::Ok) {
    wakeup_timeout.relax(server_sync_timeout);
  } else if (server_sync_state_ == SyncState::None && (was_first_sync_ || !pending_get_top_dialogs_.empty())) {
    server_sync_state_ = SyncState::Pending;
    do_get_top_peers();
  }

  if (is_enabled_) {
    // database sync
    Timestamp db_sync_timeout;
    if (db_sync_state_ == SyncState::Ok) {
      if (first_unsync_change_) {
        db_sync_timeout = Timestamp::at(first_unsync_change_.at() + DB_SYNC_DELAY);
        if (db_sync_timeout.is_in_past()) {
          db_sync_state_ = SyncState::None;
        }
      }
    }

    if (db_sync_state_ == SyncState::Ok) {
      wakeup_timeout.relax(db_sync_timeout);
    } else if (db_sync_state_ == SyncState::None) {
      if (server_sync_state_ == SyncState::Ok) {
        do_save_top_dialogs();
      }
    }
  }

  if (wakeup_timeout) {
    LOG(INFO) << "Wakeup in: " << wakeup_timeout.in();
    set_timeout_at(wakeup_timeout.at());
  } else {
    LOG(INFO) << "Wakeup: never";
    cancel_timeout();
  }
}

}  // namespace td
