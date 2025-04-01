//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/DcId.h"
#include "td/telegram/net/DcOptions.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FloodControlStrict.h"
#include "td/utils/logging.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"

#include <limits>

namespace td {

extern int VERBOSITY_NAME(config_recoverer);

using SimpleConfig = tl_object_ptr<telegram_api::help_configSimple>;
struct SimpleConfigResult {
  Result<SimpleConfig> r_config;
  Result<int32> r_http_date;
};

Result<SimpleConfig> decode_config(Slice input);

ActorOwn<> get_simple_config_azure(Promise<SimpleConfigResult> promise, bool prefer_ipv6, Slice domain_name,
                                   bool is_test, int32 scheduler_id);

ActorOwn<> get_simple_config_google_dns(Promise<SimpleConfigResult> promise, bool prefer_ipv6, Slice domain_name,
                                        bool is_test, int32 scheduler_id);

ActorOwn<> get_simple_config_mozilla_dns(Promise<SimpleConfigResult> promise, bool prefer_ipv6, Slice domain_name,
                                         bool is_test, int32 scheduler_id);

ActorOwn<> get_simple_config_firebase_remote_config(Promise<SimpleConfigResult> promise, bool prefer_ipv6,
                                                    Slice domain_name, bool is_test, int32 scheduler_id);

ActorOwn<> get_simple_config_firebase_realtime(Promise<SimpleConfigResult> promise, bool prefer_ipv6, Slice domain_name,
                                               bool is_test, int32 scheduler_id);

ActorOwn<> get_simple_config_firebase_firestore(Promise<SimpleConfigResult> promise, bool prefer_ipv6,
                                                Slice domain_name, bool is_test, int32 scheduler_id);

class ConfigRecoverer;
class ConfigManager final : public NetQueryCallback {
 public:
  explicit ConfigManager(ActorShared<> parent);

  void request_config(bool reopen_sessions);

  void lazy_request_config();

  void reget_config(Promise<Unit> &&promise);

  void get_app_config(Promise<td_api::object_ptr<td_api::JsonValue>> &&promise);

  void reget_app_config(Promise<Unit> &&promise);

  void get_content_settings(Promise<Unit> &&promise);

  void set_content_settings(bool ignore_sensitive_content_restrictions, Promise<Unit> &&promise);

  void on_dc_options_update(DcOptions dc_options);

 private:
  struct AppConfig {
    static constexpr int32 CURRENT_VERSION = 70;
    int32 version_ = 0;
    int32 hash_ = 0;
    telegram_api::object_ptr<telegram_api::JSONValue> config_;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  ActorShared<> parent_;
  int32 config_sent_cnt_{0};
  bool reopen_sessions_after_get_config_{false};
  ActorOwn<ConfigRecoverer> config_recoverer_;
  int ref_cnt_{1};
  Timestamp expire_time_;

  FloodControlStrict lazy_request_flood_control_;

  vector<Promise<Unit>> reget_config_queries_;

  vector<Promise<td_api::object_ptr<td_api::JsonValue>>> get_app_config_queries_;
  vector<Promise<Unit>> reget_app_config_queries_;

  vector<Promise<Unit>> get_content_settings_queries_;
  vector<Promise<Unit>> set_content_settings_queries_[2];
  bool is_set_content_settings_request_sent_ = false;
  bool last_set_content_settings_ = false;

  AppConfig app_config_;

  static constexpr uint64 REFCNT_TOKEN = std::numeric_limits<uint64>::max() - 2;

  void start_up() final;
  void hangup_shared() final;
  void hangup() final;
  void loop() final;
  void try_stop();

  void on_result(NetQueryPtr net_query) final;

  void request_config_from_dc_impl(DcId dc_id, bool reopen_sessions);
  void process_config(tl_object_ptr<telegram_api::config> config);

  void try_request_app_config();

  void process_app_config(telegram_api::object_ptr<telegram_api::JSONValue> &config);

  void do_set_ignore_sensitive_content_restrictions(bool ignore_sensitive_content_restrictions);

  static Timestamp load_config_expire_time();
  static void save_config_expire(Timestamp timestamp);
  static void save_dc_options_update(const DcOptions &dc_options);
  static DcOptions load_dc_options_update();

  ActorShared<> create_reference();
};

}  // namespace td
