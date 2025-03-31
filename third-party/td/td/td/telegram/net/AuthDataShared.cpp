//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/AuthDataShared.h"

#include "td/telegram/Global.h"
#include "td/telegram/net/AuthKeyState.h"
#include "td/telegram/TdDb.h"

#include "td/utils/algorithm.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/port/RwMutex.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

class AuthDataSharedImpl final : public AuthDataShared {
 public:
  AuthDataSharedImpl(DcId dc_id, std::shared_ptr<mtproto::PublicRsaKeyInterface> public_rsa_key,
                     std::shared_ptr<Guard> guard)
      : dc_id_(dc_id), public_rsa_key_(std::move(public_rsa_key)), guard_(std::move(guard)) {
    log_auth_key(get_auth_key());
  }

  DcId dc_id() const final {
    return dc_id_;
  }

  const std::shared_ptr<mtproto::PublicRsaKeyInterface> &public_rsa_key() final {
    return public_rsa_key_;
  }

  static mtproto::AuthKey get_auth_key_for_dc(DcId dc_id) {
    string dc_key = G()->td_db()->get_binlog_pmc()->get(get_auth_key_binlog_key(dc_id));

    mtproto::AuthKey res;
    if (!dc_key.empty()) {
      unserialize(res, dc_key).ensure();
    }
    return res;
  }

  mtproto::AuthKey get_auth_key() final {
    return get_auth_key_for_dc(dc_id_);
  }

  void set_auth_key(const mtproto::AuthKey &auth_key) final {
    G()->td_db()->get_binlog_pmc()->set(get_auth_key_binlog_key(dc_id_), serialize(auth_key));
    log_auth_key(auth_key);

    notify();
  }

  // TODO: extract it from G()
  void update_server_time_difference(double diff, bool force) final {
    G()->update_server_time_difference(diff, force);
  }

  double get_server_time_difference() final {
    return G()->get_server_time_difference();
  }

  void add_auth_key_listener(unique_ptr<Listener> listener) final {
    CHECK(listener != nullptr);
    if (listener->notify()) {
      auto lock = rw_mutex_.lock_write();
      auth_key_listeners_.push_back(std::move(listener));
    }
  }

  void set_future_salts(const std::vector<mtproto::ServerSalt> &future_salts) final {
    G()->td_db()->get_binlog_pmc()->set(get_future_salts_binlog_key(dc_id_), serialize(future_salts));
  }

  std::vector<mtproto::ServerSalt> get_future_salts() final {
    string future_salts = G()->td_db()->get_binlog_pmc()->get(get_future_salts_binlog_key(dc_id_));
    std::vector<mtproto::ServerSalt> res;
    if (!future_salts.empty()) {
      unserialize(res, future_salts).ensure();
    }
    return res;
  }

 private:
  DcId dc_id_;
  std::vector<unique_ptr<Listener>> auth_key_listeners_;
  std::shared_ptr<mtproto::PublicRsaKeyInterface> public_rsa_key_;
  std::shared_ptr<Guard> guard_;
  RwMutex rw_mutex_;

  static string get_auth_key_binlog_key(DcId dc_id) {
    return PSTRING() << "auth" << dc_id.get_raw_id();
  }

  static string get_future_salts_binlog_key(DcId dc_id) {
    return PSTRING() << "salt" << dc_id.get_raw_id();
  }

  void notify() {
    auto lock = rw_mutex_.lock_write();
    td::remove_if(auth_key_listeners_, [&](auto &listener) {
      CHECK(listener != nullptr);
      return !listener->notify();
    });
  }

  void log_auth_key(const mtproto::AuthKey &auth_key) {
    auto salts = get_future_salts();
    int64 last_used = 0;
    if (!salts.empty()) {
      last_used = static_cast<int64>(salts[0].valid_until);
    }
    LOG(WARNING) << dc_id_ << " " << tag("auth_key_id", auth_key.id()) << tag("state", get_auth_key_state(auth_key))
                 << tag("created_at", static_cast<int64>(auth_key.created_at())) << tag("last_used", last_used);
  }
};

mtproto::AuthKey AuthDataShared::get_auth_key_for_dc(DcId dc_id) {
  return AuthDataSharedImpl::get_auth_key_for_dc(dc_id);
}

std::shared_ptr<AuthDataShared> AuthDataShared::create(DcId dc_id,
                                                       std::shared_ptr<mtproto::PublicRsaKeyInterface> public_rsa_key,
                                                       std::shared_ptr<Guard> guard) {
  return std::make_shared<AuthDataSharedImpl>(dc_id, std::move(public_rsa_key), std::move(guard));
}

}  // namespace td
