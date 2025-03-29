//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/AccountManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/DeviceTokenManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/net/NetQueryCreator.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogHelper.h"

#include "td/utils/algorithm.h"
#include "td/utils/base64.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/tl_helpers.h"

#include <algorithm>

namespace td {

static td_api::object_ptr<td_api::SessionType> get_session_type_object(
    const tl_object_ptr<telegram_api::authorization> &authorization) {
  auto contains = [](const string &str, const char *substr) {
    return str.find(substr) != string::npos;
  };

  const string &app_name = authorization->app_name_;
  auto device_model = to_lower(authorization->device_model_);
  auto platform = to_lower(authorization->platform_);
  auto system_version = to_lower(authorization->system_version_);

  if (device_model.find("xbox") != string::npos) {
    return td_api::make_object<td_api::sessionTypeXbox>();
  }

  bool is_web = [&] {
    CSlice web_name("Web");
    auto pos = app_name.find(web_name.c_str());
    if (pos == string::npos) {
      return false;
    }

    auto next_character = app_name[pos + web_name.size()];
    return !('a' <= next_character && next_character <= 'z');
  }();

  if (is_web) {
    if (contains(device_model, "brave")) {
      return td_api::make_object<td_api::sessionTypeBrave>();
    } else if (contains(device_model, "vivaldi")) {
      return td_api::make_object<td_api::sessionTypeVivaldi>();
    } else if (contains(device_model, "opera") || contains(device_model, "opr")) {
      return td_api::make_object<td_api::sessionTypeOpera>();
    } else if (contains(device_model, "edg")) {
      return td_api::make_object<td_api::sessionTypeEdge>();
    } else if (contains(device_model, "chrome")) {
      return td_api::make_object<td_api::sessionTypeChrome>();
    } else if (contains(device_model, "firefox") || contains(device_model, "fxios")) {
      return td_api::make_object<td_api::sessionTypeFirefox>();
    } else if (contains(device_model, "safari")) {
      return td_api::make_object<td_api::sessionTypeSafari>();
    }
  }

  if (begins_with(platform, "android") || contains(system_version, "android")) {
    return td_api::make_object<td_api::sessionTypeAndroid>();
  } else if (begins_with(platform, "windows") || contains(system_version, "windows")) {
    return td_api::make_object<td_api::sessionTypeWindows>();
  } else if (begins_with(platform, "ubuntu") || contains(system_version, "ubuntu")) {
    return td_api::make_object<td_api::sessionTypeUbuntu>();
  } else if (begins_with(platform, "linux") || contains(system_version, "linux")) {
    return td_api::make_object<td_api::sessionTypeLinux>();
  }

  auto is_ios = begins_with(platform, "ios") || contains(system_version, "ios");
  auto is_macos = begins_with(platform, "macos") || contains(system_version, "macos");
  if (is_ios && contains(device_model, "iphone")) {
    return td_api::make_object<td_api::sessionTypeIphone>();
  } else if (is_ios && contains(device_model, "ipad")) {
    return td_api::make_object<td_api::sessionTypeIpad>();
  } else if (is_macos && contains(device_model, "mac")) {
    return td_api::make_object<td_api::sessionTypeMac>();
  } else if (is_ios || is_macos) {
    return td_api::make_object<td_api::sessionTypeApple>();
  }

  return td_api::make_object<td_api::sessionTypeUnknown>();
}

static td_api::object_ptr<td_api::session> convert_authorization_object(
    tl_object_ptr<telegram_api::authorization> &&authorization) {
  CHECK(authorization != nullptr);
  return td_api::make_object<td_api::session>(
      authorization->hash_, authorization->current_, authorization->password_pending_, authorization->unconfirmed_,
      !authorization->encrypted_requests_disabled_, !authorization->call_requests_disabled_,
      get_session_type_object(authorization), authorization->api_id_, authorization->app_name_,
      authorization->app_version_, authorization->official_app_, authorization->device_model_, authorization->platform_,
      authorization->system_version_, authorization->date_created_, authorization->date_active_, authorization->ip_,
      authorization->country_);
}

class SetDefaultHistoryTtlQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetDefaultHistoryTtlQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int32 account_ttl) {
    send_query(G()->net_query_creator().create(telegram_api::messages_setDefaultHistoryTTL(account_ttl), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_setDefaultHistoryTTL>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    if (!result) {
      return on_error(Status::Error(500, "Internal Server Error: failed to set default message TTL"));
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetDefaultHistoryTtlQuery final : public Td::ResultHandler {
  Promise<int32> promise_;

 public:
  explicit GetDefaultHistoryTtlQuery(Promise<int32> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::messages_getDefaultHistoryTTL()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getDefaultHistoryTTL>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetDefaultHistoryTtlQuery: " << to_string(ptr);

    promise_.set_value(std::move(ptr->period_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetAccountTtlQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetAccountTtlQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int32 account_ttl) {
    send_query(G()->net_query_creator().create(
        telegram_api::account_setAccountTTL(make_tl_object<telegram_api::accountDaysTTL>(account_ttl)), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_setAccountTTL>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    if (!result) {
      return on_error(Status::Error(500, "Internal Server Error: failed to set account TTL"));
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetAccountTtlQuery final : public Td::ResultHandler {
  Promise<int32> promise_;

 public:
  explicit GetAccountTtlQuery(Promise<int32> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_getAccountTTL()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getAccountTTL>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetAccountTtlQuery: " << to_string(ptr);

    promise_.set_value(std::move(ptr->days_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class AcceptLoginTokenQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::session>> promise_;

 public:
  explicit AcceptLoginTokenQuery(Promise<td_api::object_ptr<td_api::session>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &login_token) {
    send_query(G()->net_query_creator().create(telegram_api::auth_acceptLoginToken(BufferSlice(login_token))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::auth_acceptLoginToken>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(DEBUG) << "Receive result for AcceptLoginTokenQuery: " << to_string(result_ptr.ok());
    promise_.set_value(convert_authorization_object(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetAuthorizationsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::sessions>> promise_;

 public:
  explicit GetAuthorizationsQuery(Promise<td_api::object_ptr<td_api::sessions>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_getAuthorizations()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getAuthorizations>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetAuthorizationsQuery: " << to_string(ptr);

    auto ttl_days = ptr->authorization_ttl_days_;
    if (ttl_days <= 0 || ttl_days > 366) {
      LOG(ERROR) << "Receive invalid inactive sessions TTL " << ttl_days;
      ttl_days = 180;
    }

    auto results = td_api::make_object<td_api::sessions>(
        transform(std::move(ptr->authorizations_), convert_authorization_object), ttl_days);
    std::sort(results->sessions_.begin(), results->sessions_.end(),
              [](const td_api::object_ptr<td_api::session> &lhs, const td_api::object_ptr<td_api::session> &rhs) {
                if (lhs->is_current_ != rhs->is_current_) {
                  return lhs->is_current_;
                }
                if (lhs->is_password_pending_ != rhs->is_password_pending_) {
                  return lhs->is_password_pending_;
                }
                if (lhs->is_unconfirmed_ != rhs->is_unconfirmed_) {
                  return lhs->is_unconfirmed_;
                }
                return lhs->last_active_date_ > rhs->last_active_date_;
              });
    for (auto &session : results->sessions_) {
      if (!session->is_current_ && !session->is_unconfirmed_) {
        td_->account_manager_->on_confirm_authorization(session->id_);
      }
    }

    promise_.set_value(std::move(results));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ResetAuthorizationQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ResetAuthorizationQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int64 authorization_id) {
    send_query(G()->net_query_creator().create(telegram_api::account_resetAuthorization(authorization_id)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_resetAuthorization>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(WARNING, !result) << "Failed to terminate session";
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ResetAuthorizationsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ResetAuthorizationsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::auth_resetAuthorizations()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::auth_resetAuthorizations>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(WARNING, !result) << "Failed to terminate all sessions";
    send_closure(td_->device_token_manager_, &DeviceTokenManager::reregister_device);
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ChangeAuthorizationSettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ChangeAuthorizationSettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int64 hash, bool set_encrypted_requests_disabled, bool encrypted_requests_disabled,
            bool set_call_requests_disabled, bool call_requests_disabled, bool confirm) {
    int32 flags = 0;
    if (set_encrypted_requests_disabled) {
      flags |= telegram_api::account_changeAuthorizationSettings::ENCRYPTED_REQUESTS_DISABLED_MASK;
    }
    if (set_call_requests_disabled) {
      flags |= telegram_api::account_changeAuthorizationSettings::CALL_REQUESTS_DISABLED_MASK;
    }
    if (confirm) {
      flags |= telegram_api::account_changeAuthorizationSettings::CONFIRMED_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::account_changeAuthorizationSettings(flags, false /*ignored*/, hash, encrypted_requests_disabled,
                                                          call_requests_disabled),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_changeAuthorizationSettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(WARNING, !result) << "Failed to change session settings";
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetAuthorizationTtlQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetAuthorizationTtlQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int32 authorization_ttl_days) {
    send_query(
        G()->net_query_creator().create(telegram_api::account_setAuthorizationTTL(authorization_ttl_days), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_setAuthorizationTTL>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(WARNING, !result) << "Failed to set inactive session TTL";
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetWebAuthorizationsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::connectedWebsites>> promise_;

 public:
  explicit GetWebAuthorizationsQuery(Promise<td_api::object_ptr<td_api::connectedWebsites>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_getWebAuthorizations()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getWebAuthorizations>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetWebAuthorizationsQuery: " << to_string(ptr);

    td_->user_manager_->on_get_users(std::move(ptr->users_), "GetWebAuthorizationsQuery");

    auto results = td_api::make_object<td_api::connectedWebsites>();
    results->websites_.reserve(ptr->authorizations_.size());
    for (auto &authorization : ptr->authorizations_) {
      CHECK(authorization != nullptr);
      UserId bot_user_id(authorization->bot_id_);
      if (!bot_user_id.is_valid()) {
        LOG(ERROR) << "Receive invalid bot " << bot_user_id;
        bot_user_id = UserId();
      }

      results->websites_.push_back(td_api::make_object<td_api::connectedWebsite>(
          authorization->hash_, authorization->domain_,
          td_->user_manager_->get_user_id_object(bot_user_id, "GetWebAuthorizationsQuery"), authorization->browser_,
          authorization->platform_, authorization->date_created_, authorization->date_active_, authorization->ip_,
          authorization->region_));
    }

    promise_.set_value(std::move(results));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ResetWebAuthorizationQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ResetWebAuthorizationQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int64 hash) {
    send_query(G()->net_query_creator().create(telegram_api::account_resetWebAuthorization(hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_resetWebAuthorization>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(WARNING, !result) << "Failed to disconnect website";
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ResetWebAuthorizationsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ResetWebAuthorizationsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_resetWebAuthorizations()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_resetWebAuthorizations>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(WARNING, !result) << "Failed to disconnect all websites";
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ExportContactTokenQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::userLink>> promise_;

 public:
  explicit ExportContactTokenQuery(Promise<td_api::object_ptr<td_api::userLink>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::contacts_exportContactToken()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_exportContactToken>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ExportContactTokenQuery: " << to_string(ptr);
    promise_.set_value(td_api::make_object<td_api::userLink>(
        ptr->url_, td::max(static_cast<int32>(ptr->expires_ - G()->unix_time()), static_cast<int32>(1))));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ImportContactTokenQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::user>> promise_;

 public:
  explicit ImportContactTokenQuery(Promise<td_api::object_ptr<td_api::user>> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &token) {
    send_query(G()->net_query_creator().create(telegram_api::contacts_importContactToken(token)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_importContactToken>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto user = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for ImportContactTokenQuery: " << to_string(user);

    auto user_id = UserManager::get_user_id(user);
    td_->user_manager_->on_get_user(std::move(user), "ImportContactTokenQuery");
    promise_.set_value(td_->user_manager_->get_user_object(user_id));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class InvalidateSignInCodesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit InvalidateSignInCodesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<string> &&codes) {
    send_query(G()->net_query_creator().create(telegram_api::account_invalidateSignInCodes(std::move(codes))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_invalidateSignInCodes>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(DEBUG) << "Receive result for InvalidateSignInCodesQuery: " << result_ptr.ok();
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    LOG(DEBUG) << "Receive error for InvalidateSignInCodesQuery: " << status;
    promise_.set_error(std::move(status));
  }
};

class AccountManager::UnconfirmedAuthorization {
  int64 hash_ = 0;
  int32 date_ = 0;
  string device_;
  string location_;

 public:
  UnconfirmedAuthorization() = default;
  UnconfirmedAuthorization(int64 hash, int32 date, string &&device, string &&location)
      : hash_(hash), date_(date), device_(std::move(device)), location_(std::move(location)) {
  }

  int64 get_hash() const {
    return hash_;
  }

  int32 get_date() const {
    return date_;
  }

  td_api::object_ptr<td_api::unconfirmedSession> get_unconfirmed_session_object() const {
    return td_api::make_object<td_api::unconfirmedSession>(hash_, date_, device_, location_);
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    END_STORE_FLAGS();
    td::store(hash_, storer);
    td::store(date_, storer);
    td::store(device_, storer);
    td::store(location_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    END_PARSE_FLAGS();
    td::parse(hash_, parser);
    td::parse(date_, parser);
    td::parse(device_, parser);
    td::parse(location_, parser);
  }
};

class AccountManager::UnconfirmedAuthorizations {
  vector<UnconfirmedAuthorization> authorizations_;

  static int32 get_authorization_autoconfirm_period() {
    return narrow_cast<int32>(G()->get_option_integer("authorization_autoconfirm_period", 604800));
  }

 public:
  bool is_empty() const {
    return authorizations_.empty();
  }

  bool add_authorization(UnconfirmedAuthorization &&unconfirmed_authorization, bool &is_first_changed) {
    if (unconfirmed_authorization.get_hash() == 0) {
      LOG(ERROR) << "Receive empty unconfirmed authorization";
      return false;
    }
    for (const auto &authorization : authorizations_) {
      if (authorization.get_hash() == unconfirmed_authorization.get_hash()) {
        return false;
      }
    }
    auto it = authorizations_.begin();
    while (it != authorizations_.end() && it->get_date() <= unconfirmed_authorization.get_date()) {
      ++it;
    }
    is_first_changed = it == authorizations_.begin();
    authorizations_.insert(it, std::move(unconfirmed_authorization));
    return true;
  }

  bool delete_authorization(int64 hash, bool &is_first_changed) {
    auto it = authorizations_.begin();
    while (it != authorizations_.end() && it->get_hash() != hash) {
      ++it;
    }
    if (it == authorizations_.end()) {
      return false;
    }
    is_first_changed = it == authorizations_.begin();
    authorizations_.erase(it);
    return true;
  }

  bool delete_expired_authorizations() {
    auto up_to_date = G()->unix_time() - get_authorization_autoconfirm_period();
    auto it = authorizations_.begin();
    while (it != authorizations_.end() && it->get_date() <= up_to_date) {
      ++it;
    }
    if (it == authorizations_.begin()) {
      return false;
    }
    authorizations_.erase(authorizations_.begin(), it);
    return true;
  }

  int32 get_next_authorization_expire_date() const {
    CHECK(!authorizations_.empty());
    return authorizations_[0].get_date() + get_authorization_autoconfirm_period();
  }

  td_api::object_ptr<td_api::unconfirmedSession> get_first_unconfirmed_session_object() const {
    CHECK(!authorizations_.empty());
    return authorizations_[0].get_unconfirmed_session_object();
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    CHECK(!authorizations_.empty());
    td::store(authorizations_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(authorizations_, parser);
  }
};

AccountManager::AccountManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

AccountManager::~AccountManager() = default;

void AccountManager::start_up() {
  auto unconfirmed_authorizations_log_event_string =
      G()->td_db()->get_binlog_pmc()->get(get_unconfirmed_authorizations_key());
  if (!unconfirmed_authorizations_log_event_string.empty()) {
    log_event_parse(unconfirmed_authorizations_, unconfirmed_authorizations_log_event_string).ensure();
    CHECK(unconfirmed_authorizations_ != nullptr);
    if (delete_expired_unconfirmed_authorizations()) {
      save_unconfirmed_authorizations();
    }
    if (unconfirmed_authorizations_ != nullptr) {
      update_unconfirmed_authorization_timeout(false);
      send_update_unconfirmed_session();
      get_active_sessions(Auto());
    }
  }
}

void AccountManager::timeout_expired() {
  update_unconfirmed_authorization_timeout(true);
  if (unconfirmed_authorizations_ != nullptr) {
    get_active_sessions(Auto());
  }
}

void AccountManager::tear_down() {
  parent_.reset();
}

class AccountManager::SetDefaultHistoryTtlOnServerLogEvent {
 public:
  int32 message_ttl_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(message_ttl_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(message_ttl_, parser);
  }
};

void AccountManager::set_default_history_ttl_on_server(int32 message_ttl, uint64 log_event_id,
                                                       Promise<Unit> &&promise) {
  if (log_event_id == 0) {
    SetDefaultHistoryTtlOnServerLogEvent log_event{message_ttl};
    log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::SetDefaultHistoryTtlOnServer,
                              get_log_event_storer(log_event));
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  td_->create_handler<SetDefaultHistoryTtlQuery>(std::move(promise))->send(message_ttl);
}

void AccountManager::set_default_message_ttl(int32 message_ttl, Promise<Unit> &&promise) {
  set_default_history_ttl_on_server(message_ttl, 0, std::move(promise));
}

void AccountManager::get_default_message_ttl(Promise<int32> &&promise) {
  td_->create_handler<GetDefaultHistoryTtlQuery>(std::move(promise))->send();
}

class AccountManager::SetAccountTtlOnServerLogEvent {
 public:
  int32 account_ttl_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(account_ttl_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(account_ttl_, parser);
  }
};

void AccountManager::set_account_ttl_on_server(int32 account_ttl, uint64 log_event_id, Promise<Unit> &&promise) {
  if (log_event_id == 0) {
    SetAccountTtlOnServerLogEvent log_event{account_ttl};
    log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::SetAccountTtlOnServer,
                              get_log_event_storer(log_event));
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  td_->create_handler<SetAccountTtlQuery>(std::move(promise))->send(account_ttl);
}

void AccountManager::set_account_ttl(int32 account_ttl, Promise<Unit> &&promise) {
  set_account_ttl_on_server(account_ttl, 0, std::move(promise));
}

void AccountManager::get_account_ttl(Promise<int32> &&promise) {
  td_->create_handler<GetAccountTtlQuery>(std::move(promise))->send();
}

void AccountManager::confirm_qr_code_authentication(const string &link,
                                                    Promise<td_api::object_ptr<td_api::session>> &&promise) {
  Slice prefix("tg://login?token=");
  if (!begins_with(to_lower(link), prefix)) {
    return promise.set_error(Status::Error(400, "AUTH_TOKEN_INVALID"));
  }
  auto r_token = base64url_decode(Slice(link).substr(prefix.size()));
  if (r_token.is_error()) {
    return promise.set_error(Status::Error(400, "AUTH_TOKEN_INVALID"));
  }
  td_->create_handler<AcceptLoginTokenQuery>(std::move(promise))->send(r_token.ok());
}

void AccountManager::get_active_sessions(Promise<td_api::object_ptr<td_api::sessions>> &&promise) {
  td_->create_handler<GetAuthorizationsQuery>(std::move(promise))->send();
}

class AccountManager::ResetAuthorizationOnServerLogEvent {
 public:
  int64 hash_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(hash_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(hash_, parser);
  }
};

void AccountManager::reset_authorization_on_server(int64 hash, uint64 log_event_id, Promise<Unit> &&promise) {
  if (log_event_id == 0) {
    ResetAuthorizationOnServerLogEvent log_event{hash};
    log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ResetAuthorizationOnServer,
                              get_log_event_storer(log_event));
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  td_->create_handler<ResetAuthorizationQuery>(std::move(promise))->send(hash);
}

void AccountManager::terminate_session(int64 session_id, Promise<Unit> &&promise) {
  on_confirm_authorization(session_id);
  reset_authorization_on_server(session_id, 0, std::move(promise));
}

class AccountManager::ResetAuthorizationsOnServerLogEvent {
 public:
  template <class StorerT>
  void store(StorerT &storer) const {
  }

  template <class ParserT>
  void parse(ParserT &parser) {
  }
};

void AccountManager::reset_authorizations_on_server(uint64 log_event_id, Promise<Unit> &&promise) {
  if (log_event_id == 0) {
    ResetAuthorizationsOnServerLogEvent log_event;
    log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ResetAuthorizationsOnServer,
                              get_log_event_storer(log_event));
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  td_->create_handler<ResetAuthorizationsQuery>(std::move(promise))->send();
}

void AccountManager::terminate_all_other_sessions(Promise<Unit> &&promise) {
  if (unconfirmed_authorizations_ != nullptr) {
    unconfirmed_authorizations_ = nullptr;
    update_unconfirmed_authorization_timeout(false);
    send_update_unconfirmed_session();
    save_unconfirmed_authorizations();
  }
  reset_authorizations_on_server(0, std::move(promise));
}

class AccountManager::ChangeAuthorizationSettingsOnServerLogEvent {
 public:
  int64 hash_;
  bool set_encrypted_requests_disabled_;
  bool encrypted_requests_disabled_;
  bool set_call_requests_disabled_;
  bool call_requests_disabled_;
  bool confirm_;

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(set_encrypted_requests_disabled_);
    STORE_FLAG(encrypted_requests_disabled_);
    STORE_FLAG(set_call_requests_disabled_);
    STORE_FLAG(call_requests_disabled_);
    STORE_FLAG(confirm_);
    END_STORE_FLAGS();
    td::store(hash_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(set_encrypted_requests_disabled_);
    PARSE_FLAG(encrypted_requests_disabled_);
    PARSE_FLAG(set_call_requests_disabled_);
    PARSE_FLAG(call_requests_disabled_);
    PARSE_FLAG(confirm_);
    END_PARSE_FLAGS();
    td::parse(hash_, parser);
  }
};

void AccountManager::change_authorization_settings_on_server(int64 hash, bool set_encrypted_requests_disabled,
                                                             bool encrypted_requests_disabled,
                                                             bool set_call_requests_disabled,
                                                             bool call_requests_disabled, bool confirm,
                                                             uint64 log_event_id, Promise<Unit> &&promise) {
  if (log_event_id == 0) {
    ChangeAuthorizationSettingsOnServerLogEvent log_event{hash,
                                                          set_encrypted_requests_disabled,
                                                          encrypted_requests_disabled,
                                                          set_call_requests_disabled,
                                                          call_requests_disabled,
                                                          confirm};
    log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ChangeAuthorizationSettingsOnServer,
                              get_log_event_storer(log_event));
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  td_->create_handler<ChangeAuthorizationSettingsQuery>(std::move(promise))
      ->send(hash, set_encrypted_requests_disabled, encrypted_requests_disabled, set_call_requests_disabled,
             call_requests_disabled, confirm);
}

void AccountManager::confirm_session(int64 session_id, Promise<Unit> &&promise) {
  if (!on_confirm_authorization(session_id)) {
    // the authorization can be from the list of active authorizations, but the update could have been lost
    // return promise.set_value(Unit());
  }
  change_authorization_settings_on_server(session_id, false, false, false, false, true, 0, std::move(promise));
}

void AccountManager::toggle_session_can_accept_calls(int64 session_id, bool can_accept_calls, Promise<Unit> &&promise) {
  change_authorization_settings_on_server(session_id, false, false, true, !can_accept_calls, false, 0,
                                          std::move(promise));
}

void AccountManager::toggle_session_can_accept_secret_chats(int64 session_id, bool can_accept_secret_chats,
                                                            Promise<Unit> &&promise) {
  change_authorization_settings_on_server(session_id, true, !can_accept_secret_chats, false, false, false, 0,
                                          std::move(promise));
}

class AccountManager::SetAuthorizationTtlOnServerLogEvent {
 public:
  int32 authorization_ttl_days_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(authorization_ttl_days_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(authorization_ttl_days_, parser);
  }
};

void AccountManager::set_authorization_ttl_on_server(int32 authorization_ttl_days, uint64 log_event_id,
                                                     Promise<Unit> &&promise) {
  if (log_event_id == 0) {
    SetAuthorizationTtlOnServerLogEvent log_event{authorization_ttl_days};
    log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::SetAuthorizationTtlOnServer,
                              get_log_event_storer(log_event));
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  td_->create_handler<SetAuthorizationTtlQuery>(std::move(promise))->send(authorization_ttl_days);
}

void AccountManager::set_inactive_session_ttl_days(int32 authorization_ttl_days, Promise<Unit> &&promise) {
  set_authorization_ttl_on_server(authorization_ttl_days, 0, std::move(promise));
}

void AccountManager::get_connected_websites(Promise<td_api::object_ptr<td_api::connectedWebsites>> &&promise) {
  td_->create_handler<GetWebAuthorizationsQuery>(std::move(promise))->send();
}

class AccountManager::ResetWebAuthorizationOnServerLogEvent {
 public:
  int64 hash_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(hash_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(hash_, parser);
  }
};

void AccountManager::reset_web_authorization_on_server(int64 hash, uint64 log_event_id, Promise<Unit> &&promise) {
  if (log_event_id == 0) {
    ResetWebAuthorizationOnServerLogEvent log_event{hash};
    log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ResetWebAuthorizationOnServer,
                              get_log_event_storer(log_event));
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  td_->create_handler<ResetWebAuthorizationQuery>(std::move(promise))->send(hash);
}

void AccountManager::disconnect_website(int64 website_id, Promise<Unit> &&promise) {
  reset_web_authorization_on_server(website_id, 0, std::move(promise));
}

class AccountManager::ResetWebAuthorizationsOnServerLogEvent {
 public:
  template <class StorerT>
  void store(StorerT &storer) const {
  }

  template <class ParserT>
  void parse(ParserT &parser) {
  }
};

void AccountManager::reset_web_authorizations_on_server(uint64 log_event_id, Promise<Unit> &&promise) {
  if (log_event_id == 0) {
    ResetWebAuthorizationsOnServerLogEvent log_event;
    log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ResetWebAuthorizationsOnServer,
                              get_log_event_storer(log_event));
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  td_->create_handler<ResetWebAuthorizationsQuery>(std::move(promise))->send();
}

void AccountManager::disconnect_all_websites(Promise<Unit> &&promise) {
  reset_web_authorizations_on_server(0, std::move(promise));
}

void AccountManager::get_user_link(Promise<td_api::object_ptr<td_api::userLink>> &&promise) {
  td_->user_manager_->get_me(
      PromiseCreator::lambda([actor_id = actor_id(this), promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          send_closure(actor_id, &AccountManager::get_user_link_impl, std::move(promise));
        }
      }));
}

void AccountManager::get_user_link_impl(Promise<td_api::object_ptr<td_api::userLink>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  auto username = td_->user_manager_->get_user_first_username(td_->user_manager_->get_my_id());
  if (!username.empty()) {
    return promise.set_value(
        td_api::make_object<td_api::userLink>(LinkManager::get_public_dialog_link(username, Slice(), false, true), 0));
  }
  td_->create_handler<ExportContactTokenQuery>(std::move(promise))->send();
}

void AccountManager::import_contact_token(const string &token, Promise<td_api::object_ptr<td_api::user>> &&promise) {
  td_->create_handler<ImportContactTokenQuery>(std::move(promise))->send(token);
}

class AccountManager::InvalidateSignInCodesOnServerLogEvent {
 public:
  vector<string> authentication_codes_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(authentication_codes_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(authentication_codes_, parser);
  }
};

void AccountManager::invalidate_sign_in_codes_on_server(vector<string> authentication_codes, uint64 log_event_id) {
  if (log_event_id == 0) {
    InvalidateSignInCodesOnServerLogEvent log_event{authentication_codes};
    log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::InvalidateSignInCodesOnServer,
                              get_log_event_storer(log_event));
  }

  td_->create_handler<InvalidateSignInCodesQuery>(get_erase_log_event_promise(log_event_id))
      ->send(std::move(authentication_codes));
}

void AccountManager::invalidate_authentication_codes(vector<string> &&authentication_codes) {
  invalidate_sign_in_codes_on_server(std::move(authentication_codes), 0);
}

void AccountManager::on_new_unconfirmed_authorization(int64 hash, int32 date, string &&device, string &&location) {
  if (td_->auth_manager_->is_bot()) {
    LOG(ERROR) << "Receive unconfirmed session by a bot";
    return;
  }
  auto unix_time = G()->unix_time();
  if (date > unix_time + 1) {
    LOG(ERROR) << "Receive new session at " << date << ", but the current time is " << unix_time;
    date = unix_time + 1;
  }
  if (unconfirmed_authorizations_ == nullptr) {
    unconfirmed_authorizations_ = make_unique<UnconfirmedAuthorizations>();
  }
  bool is_first_changed = false;
  if (unconfirmed_authorizations_->add_authorization({hash, date, std::move(device), std::move(location)},
                                                     is_first_changed)) {
    CHECK(!unconfirmed_authorizations_->is_empty());
    if (is_first_changed) {
      update_unconfirmed_authorization_timeout(false);
      send_update_unconfirmed_session();
    }
    save_unconfirmed_authorizations();
  }
}

bool AccountManager::on_confirm_authorization(int64 hash) {
  bool is_first_changed = false;
  if (unconfirmed_authorizations_ != nullptr &&
      unconfirmed_authorizations_->delete_authorization(hash, is_first_changed)) {
    if (unconfirmed_authorizations_->is_empty()) {
      unconfirmed_authorizations_ = nullptr;
    }
    if (is_first_changed) {
      update_unconfirmed_authorization_timeout(false);
      send_update_unconfirmed_session();
    }
    save_unconfirmed_authorizations();
    return true;
  }
  return false;
}

string AccountManager::get_unconfirmed_authorizations_key() {
  return "new_authorizations";
}

void AccountManager::save_unconfirmed_authorizations() const {
  if (unconfirmed_authorizations_ == nullptr) {
    G()->td_db()->get_binlog_pmc()->erase(get_unconfirmed_authorizations_key());
  } else {
    G()->td_db()->get_binlog_pmc()->set(get_unconfirmed_authorizations_key(),
                                        log_event_store(unconfirmed_authorizations_).as_slice().str());
  }
}

bool AccountManager::delete_expired_unconfirmed_authorizations() {
  if (unconfirmed_authorizations_ != nullptr && unconfirmed_authorizations_->delete_expired_authorizations()) {
    if (unconfirmed_authorizations_->is_empty()) {
      unconfirmed_authorizations_ = nullptr;
    }
    return true;
  }
  return false;
}

void AccountManager::update_unconfirmed_authorization_timeout(bool is_external) {
  if (delete_expired_unconfirmed_authorizations() && is_external) {
    send_update_unconfirmed_session();
    save_unconfirmed_authorizations();
  }
  if (unconfirmed_authorizations_ == nullptr) {
    cancel_timeout();
  } else {
    set_timeout_in(min(unconfirmed_authorizations_->get_next_authorization_expire_date() - G()->unix_time() + 1, 3600));
  }
}

td_api::object_ptr<td_api::updateUnconfirmedSession> AccountManager::get_update_unconfirmed_session() const {
  if (unconfirmed_authorizations_ == nullptr) {
    return td_api::make_object<td_api::updateUnconfirmedSession>(nullptr);
  }
  return td_api::make_object<td_api::updateUnconfirmedSession>(
      unconfirmed_authorizations_->get_first_unconfirmed_session_object());
}

void AccountManager::send_update_unconfirmed_session() const {
  send_closure(G()->td(), &Td::send_update, get_update_unconfirmed_session());
}

void AccountManager::on_binlog_events(vector<BinlogEvent> &&events) {
  if (G()->close_flag()) {
    return;
  }
  for (auto &event : events) {
    switch (event.type_) {
      case LogEvent::HandlerType::ChangeAuthorizationSettingsOnServer: {
        ChangeAuthorizationSettingsOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        change_authorization_settings_on_server(
            log_event.hash_, log_event.set_encrypted_requests_disabled_, log_event.encrypted_requests_disabled_,
            log_event.set_call_requests_disabled_, log_event.call_requests_disabled_, log_event.confirm_, event.id_,
            Auto());
        break;
      }
      case LogEvent::HandlerType::InvalidateSignInCodesOnServer: {
        InvalidateSignInCodesOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        invalidate_sign_in_codes_on_server(std::move(log_event.authentication_codes_), event.id_);
        break;
      }
      case LogEvent::HandlerType::ResetAuthorizationOnServer: {
        ResetAuthorizationOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        reset_authorization_on_server(log_event.hash_, event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::ResetAuthorizationsOnServer: {
        ResetAuthorizationsOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        reset_authorizations_on_server(event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::ResetWebAuthorizationOnServer: {
        ResetWebAuthorizationOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        reset_web_authorization_on_server(log_event.hash_, event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::ResetWebAuthorizationsOnServer: {
        ResetWebAuthorizationsOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        reset_web_authorizations_on_server(event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::SetAccountTtlOnServer: {
        SetAccountTtlOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        set_account_ttl_on_server(log_event.account_ttl_, event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::SetAuthorizationTtlOnServer: {
        SetAuthorizationTtlOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        set_authorization_ttl_on_server(log_event.authorization_ttl_days_, event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::SetDefaultHistoryTtlOnServer: {
        SetDefaultHistoryTtlOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        set_default_history_ttl_on_server(log_event.message_ttl_, event.id_, Auto());
        break;
      }
      default:
        LOG(FATAL) << "Unsupported log event type " << event.type_;
    }
  }
}

void AccountManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (unconfirmed_authorizations_ != nullptr) {
    updates.push_back(get_update_unconfirmed_session());
  }
}

}  // namespace td
