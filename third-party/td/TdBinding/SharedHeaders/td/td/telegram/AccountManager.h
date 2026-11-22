//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

struct BinlogEvent;

class Td;

class AccountManager final : public Actor {
 public:
  AccountManager(Td *td, ActorShared<> parent);
  AccountManager(const AccountManager &) = delete;
  AccountManager &operator=(const AccountManager &) = delete;
  AccountManager(AccountManager &&) = delete;
  AccountManager &operator=(AccountManager &&) = delete;
  ~AccountManager() final;

  void set_default_message_ttl(int32 message_ttl, Promise<Unit> &&promise);

  void get_default_message_ttl(Promise<int32> &&promise);

  void set_account_ttl(int32 account_ttl, Promise<Unit> &&promise);

  void get_account_ttl(Promise<int32> &&promise);

  void confirm_qr_code_authentication(const string &link, Promise<td_api::object_ptr<td_api::session>> &&promise);

  void get_active_sessions(Promise<td_api::object_ptr<td_api::sessions>> &&promise);

  void terminate_session(int64 session_id, Promise<Unit> &&promise);

  void terminate_all_other_sessions(Promise<Unit> &&promise);

  void confirm_session(int64 session_id, Promise<Unit> &&promise);

  void toggle_session_can_accept_calls(int64 session_id, bool can_accept_calls, Promise<Unit> &&promise);

  void toggle_session_can_accept_secret_chats(int64 session_id, bool can_accept_secret_chats, Promise<Unit> &&promise);

  void set_inactive_session_ttl_days(int32 authorization_ttl_days, Promise<Unit> &&promise);

  void get_connected_websites(Promise<td_api::object_ptr<td_api::connectedWebsites>> &&promise);

  void disconnect_website(int64 website_id, Promise<Unit> &&promise);

  void disconnect_all_websites(Promise<Unit> &&promise);

  void get_user_link(Promise<td_api::object_ptr<td_api::userLink>> &&promise);

  void import_contact_token(const string &token, Promise<td_api::object_ptr<td_api::user>> &&promise);

  void invalidate_authentication_codes(vector<string> &&authentication_codes);

  void update_unconfirmed_authorization_timeout(bool is_external);

  void on_new_unconfirmed_authorization(int64 hash, int32 date, string &&device, string &&location);

  bool on_confirm_authorization(int64 hash);

  void on_binlog_events(vector<BinlogEvent> &&events);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  class UnconfirmedAuthorization;
  class UnconfirmedAuthorizations;

  class ChangeAuthorizationSettingsOnServerLogEvent;
  class InvalidateSignInCodesOnServerLogEvent;
  class ResetAuthorizationOnServerLogEvent;
  class ResetAuthorizationsOnServerLogEvent;
  class ResetWebAuthorizationOnServerLogEvent;
  class ResetWebAuthorizationsOnServerLogEvent;
  class SetAccountTtlOnServerLogEvent;
  class SetAuthorizationTtlOnServerLogEvent;
  class SetDefaultHistoryTtlOnServerLogEvent;

  void start_up() final;

  void timeout_expired() final;

  void tear_down() final;

  void get_user_link_impl(Promise<td_api::object_ptr<td_api::userLink>> &&promise);

  static string get_unconfirmed_authorizations_key();

  void save_unconfirmed_authorizations() const;

  bool delete_expired_unconfirmed_authorizations();

  td_api::object_ptr<td_api::updateUnconfirmedSession> get_update_unconfirmed_session() const;

  void send_update_unconfirmed_session() const;

  void change_authorization_settings_on_server(int64 hash, bool set_encrypted_requests_disabled,
                                               bool encrypted_requests_disabled, bool set_call_requests_disabled,
                                               bool call_requests_disabled, bool confirm, uint64 log_event_id,
                                               Promise<Unit> &&promise);

  void invalidate_sign_in_codes_on_server(vector<string> authentication_codes, uint64 log_event_id);

  void reset_authorization_on_server(int64 hash, uint64 log_event_id, Promise<Unit> &&promise);

  void reset_authorizations_on_server(uint64 log_event_id, Promise<Unit> &&promise);

  void reset_web_authorization_on_server(int64 hash, uint64 log_event_id, Promise<Unit> &&promise);

  void reset_web_authorizations_on_server(uint64 log_event_id, Promise<Unit> &&promise);

  void set_account_ttl_on_server(int32 account_ttl, uint64 log_event_id, Promise<Unit> &&promise);

  void set_authorization_ttl_on_server(int32 authorization_ttl_days, uint64 log_event_id, Promise<Unit> &&promise);

  void set_default_history_ttl_on_server(int32 message_ttl, uint64 log_event_id, Promise<Unit> &&promise);

  Td *td_;
  ActorShared<> parent_;

  unique_ptr<UnconfirmedAuthorizations> unconfirmed_authorizations_;
};

}  // namespace td
