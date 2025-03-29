//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ConfigManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/ConnectionState.h"
#include "td/telegram/Global.h"
#include "td/telegram/JsonValue.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/AuthDataShared.h"
#include "td/telegram/net/ConnectionCreator.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/net/DcOptions.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/net/NetType.h"
#include "td/telegram/net/PublicRsaKeySharedMain.h"
#include "td/telegram/net/Session.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/Premium.h"
#include "td/telegram/ReactionType.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/SuggestedAction.h"
#include "td/telegram/SuggestedActionManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/TranscriptionManager.h"
#include "td/telegram/UserManager.h"

#include "td/mtproto/AuthData.h"
#include "td/mtproto/AuthKey.h"
#include "td/mtproto/RawConnection.h"
#include "td/mtproto/RSA.h"
#include "td/mtproto/TransportType.h"

#if !TD_EMSCRIPTEN  //FIXME
#include "td/net/SslCtx.h"
#include "td/net/Wget.h"
#endif

#include "td/net/HttpQuery.h"

#include "td/actor/actor.h"

#include "td/utils/algorithm.h"
#include "td/utils/base64.h"
#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/emoji.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/format.h"
#include "td/utils/HttpDate.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/UInt.h"

#include <algorithm>
#include <functional>
#include <memory>
#include <utility>

namespace td {

int VERBOSITY_NAME(config_recoverer) = VERBOSITY_NAME(INFO);

Result<SimpleConfig> decode_config(Slice input) {
  static auto rsa = mtproto::RSA::from_pem_public_key(
                        "-----BEGIN RSA PUBLIC KEY-----\n"
                        "MIIBCgKCAQEAyr+18Rex2ohtVy8sroGP\n"
                        "BwXD3DOoKCSpjDqYoXgCqB7ioln4eDCFfOBUlfXUEvM/fnKCpF46VkAftlb4VuPD\n"
                        "eQSS/ZxZYEGqHaywlroVnXHIjgqoxiAd192xRGreuXIaUKmkwlM9JID9WS2jUsTp\n"
                        "zQ91L8MEPLJ/4zrBwZua8W5fECwCCh2c9G5IzzBm+otMS/YKwmR1olzRCyEkyAEj\n"
                        "XWqBI9Ftv5eG8m0VkBzOG655WIYdyV0HfDK/NWcvGqa0w/nriMD6mDjKOryamw0O\n"
                        "P9QuYgMN0C9xMW9y8SmP4h92OAWodTYgY1hZCxdv6cs5UnW9+PWvS+WIbkh+GaWY\n"
                        "xwIDAQAB\n"
                        "-----END RSA PUBLIC KEY-----\n")
                        .move_as_ok();

  if (input.size() < 344 || input.size() > 1024) {
    return Status::Error(PSLICE() << "Invalid " << tag("length", input.size()));
  }

  auto data_base64 = base64_filter(input);
  if (data_base64.size() != 344) {
    return Status::Error(PSLICE() << "Invalid " << tag("length", data_base64.size()) << " after base64_filter");
  }
  TRY_RESULT(data_rsa, base64_decode(data_base64));
  if (data_rsa.size() != 256) {
    return Status::Error(PSLICE() << "Invalid " << tag("length", data_rsa.size()) << " after base64_decode");
  }

  MutableSlice data_rsa_slice(data_rsa);
  rsa.decrypt_signature(data_rsa_slice, data_rsa_slice);

  MutableSlice data_cbc = data_rsa_slice.substr(32);
  UInt256 key;
  UInt128 iv;
  as_mutable_slice(key).copy_from(data_rsa_slice.substr(0, 32));
  as_mutable_slice(iv).copy_from(data_rsa_slice.substr(16, 16));
  aes_cbc_decrypt(as_slice(key), as_mutable_slice(iv), data_cbc, data_cbc);

  CHECK(data_cbc.size() == 224);
  string hash(32, ' ');
  sha256(data_cbc.substr(0, 208), MutableSlice(hash));
  if (data_cbc.substr(208) != Slice(hash).substr(0, 16)) {
    return Status::Error("SHA256 mismatch");
  }

  TlParser len_parser{data_cbc};
  int len = len_parser.fetch_int();
  if (len < 8 || len > 208) {
    return Status::Error(PSLICE() << "Invalid " << tag("data length", len) << " after aes_cbc_decrypt");
  }
  int constructor_id = len_parser.fetch_int();
  if (constructor_id != telegram_api::help_configSimple::ID) {
    return Status::Error(PSLICE() << "Wrong " << tag("constructor", format::as_hex(constructor_id)));
  }
  BufferSlice raw_config(data_cbc.substr(8, len - 8));
  TlBufferParser parser{&raw_config};
  auto config = telegram_api::help_configSimple::fetch(parser);
  parser.fetch_end();
  TRY_STATUS(parser.get_status());
  return std::move(config);
}

static ActorOwn<> get_simple_config_impl(Promise<SimpleConfigResult> promise, int32 scheduler_id, string url,
                                         string host, std::vector<std::pair<string, string>> headers, bool prefer_ipv6,
                                         std::function<Result<string>(HttpQuery &)> get_config,
                                         string content = string(), string content_type = string()) {
  VLOG(config_recoverer) << "Request simple config from " << url;
#if TD_EMSCRIPTEN  // FIXME
  return ActorOwn<>();
#else
  const int timeout = 10;
  const int ttl = 3;
  headers.emplace_back("Host", std::move(host));
  headers.emplace_back("User-Agent",
                       "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) "
                       "Chrome/77.0.3865.90 Safari/537.36");
  return ActorOwn<>(create_actor_on_scheduler<Wget>(
      "Wget", scheduler_id,
      PromiseCreator::lambda([get_config = std::move(get_config),
                              promise = std::move(promise)](Result<unique_ptr<HttpQuery>> r_query) mutable {
        promise.set_result([&]() -> Result<SimpleConfigResult> {
          TRY_RESULT(http_query, std::move(r_query));
          SimpleConfigResult res;
          res.r_http_date = HttpDate::parse_http_date(http_query->get_header("date").str());
          auto r_config = get_config(*http_query);
          if (r_config.is_error()) {
            res.r_config = r_config.move_as_error();
          } else {
            res.r_config = decode_config(r_config.ok());
          }
          return std::move(res);
        }());
      }),
      std::move(url), std::move(headers), timeout, ttl, prefer_ipv6, SslCtx::VerifyPeer::Off, std::move(content),
      std::move(content_type)));
#endif
}

ActorOwn<> get_simple_config_azure(Promise<SimpleConfigResult> promise, bool prefer_ipv6, Slice domain_name,
                                   bool is_test, int32 scheduler_id) {
  string url = PSTRING() << "https://software-download.microsoft.com/" << (is_test ? "test" : "prod")
                         << "v2/config.txt";
  return get_simple_config_impl(std::move(promise), scheduler_id, std::move(url), "tcdnb.azureedge.net", {},
                                prefer_ipv6,
                                [](HttpQuery &http_query) -> Result<string> { return http_query.content_.str(); });
}

static ActorOwn<> get_simple_config_dns(Slice address, Slice host, Promise<SimpleConfigResult> promise,
                                        bool prefer_ipv6, Slice domain_name, bool is_test, int32 scheduler_id) {
  if (domain_name.empty()) {
    domain_name = is_test ? Slice("tapv3.stel.com") : Slice("apv3.stel.com");
  }
  auto get_config = [](HttpQuery &http_query) -> Result<string> {
    auto get_data = [](JsonValue &answer) -> Result<string> {
      auto &answer_array = answer.get_array();
      vector<string> parts;
      for (auto &answer_part : answer_array) {
        if (answer_part.type() != JsonValue::Type::Object) {
          return Status::Error("Expected JSON object");
        }
        auto &data_object = answer_part.get_object();
        TRY_RESULT(part, data_object.get_required_string_field("data"));
        parts.push_back(std::move(part));
      }
      if (parts.size() != 2) {
        return Status::Error("Expected data in two parts");
      }
      string data;
      if (parts[0].size() < parts[1].size()) {
        data = parts[1] + parts[0];
      } else {
        data = parts[0] + parts[1];
      }
      return data;
    };
    if (!http_query.get_arg("Answer").empty()) {
      VLOG(config_recoverer) << "Receive DNS response " << http_query.get_arg("Answer");
      TRY_RESULT(answer, json_decode(http_query.get_arg("Answer")));
      if (answer.type() != JsonValue::Type::Array) {
        return Status::Error("Expected JSON array");
      }
      return get_data(answer);
    } else {
      VLOG(config_recoverer) << "Receive DNS response " << http_query.content_;
      TRY_RESULT(json, json_decode(http_query.content_));
      if (json.type() != JsonValue::Type::Object) {
        return Status::Error("Expected JSON object");
      }
      auto &answer_object = json.get_object();
      TRY_RESULT(answer, answer_object.extract_required_field("Answer", JsonValue::Type::Array));
      return get_data(answer);
    }
  };
  return get_simple_config_impl(
      std::move(promise), scheduler_id,
      PSTRING() << "https://" << address << "?name=" << url_encode(domain_name) << "&type=TXT", host.str(),
      {{"Accept", "application/dns-json"}}, prefer_ipv6, std::move(get_config));
}

ActorOwn<> get_simple_config_google_dns(Promise<SimpleConfigResult> promise, bool prefer_ipv6, Slice domain_name,
                                        bool is_test, int32 scheduler_id) {
  return get_simple_config_dns("dns.google/resolve", "dns.google", std::move(promise), prefer_ipv6, domain_name,
                               is_test, scheduler_id);
}

ActorOwn<> get_simple_config_mozilla_dns(Promise<SimpleConfigResult> promise, bool prefer_ipv6, Slice domain_name,
                                         bool is_test, int32 scheduler_id) {
  return get_simple_config_dns("mozilla.cloudflare-dns.com/dns-query", "mozilla.cloudflare-dns.com", std::move(promise),
                               prefer_ipv6, domain_name, is_test, scheduler_id);
}

static string generate_firebase_remote_config_payload() {
  unsigned char buf[17];
  Random::secure_bytes(buf, sizeof(buf));
  buf[0] = static_cast<unsigned char>((buf[0] & 0xF0) | 0x07);
  auto app_instance_id = base64url_encode(Slice(buf, sizeof(buf)));
  app_instance_id.resize(22);
  return PSTRING() << "{\"app_id\":\"1:560508485281:web:4ee13a6af4e84d49e67ae0\",\"app_instance_id\":\""
                   << app_instance_id << "\"}";
}

ActorOwn<> get_simple_config_firebase_remote_config(Promise<SimpleConfigResult> promise, bool prefer_ipv6,
                                                    Slice domain_name, bool is_test, int32 scheduler_id) {
  if (is_test) {
    promise.set_error(Status::Error(400, "Test config is not supported"));
    return ActorOwn<>();
  }

  static const string payload = generate_firebase_remote_config_payload();
  string url =
      "https://firebaseremoteconfig.googleapis.com/v1/projects/peak-vista-421/namespaces/"
      "firebase:fetch?key=AIzaSyC2-kAkpDsroixRXw-sTw-Wfqo4NxjMwwM";
  auto get_config = [](HttpQuery &http_query) -> Result<string> {
    TRY_RESULT(json, json_decode(http_query.get_arg("entries")));
    if (json.type() != JsonValue::Type::Object) {
      return Status::Error("Expected JSON object");
    }
    auto &entries_object = json.get_object();
    TRY_RESULT(config, entries_object.get_required_string_field("ipconfigv3"));
    return std::move(config);
  };
  return get_simple_config_impl(std::move(promise), scheduler_id, std::move(url), "firebaseremoteconfig.googleapis.com",
                                {}, prefer_ipv6, std::move(get_config), payload, "application/json");
}

ActorOwn<> get_simple_config_firebase_realtime(Promise<SimpleConfigResult> promise, bool prefer_ipv6, Slice domain_name,
                                               bool is_test, int32 scheduler_id) {
  if (is_test) {
    promise.set_error(Status::Error(400, "Test config is not supported"));
    return ActorOwn<>();
  }

  string url = "https://reserve-5a846.firebaseio.com/ipconfigv3.json";
  auto get_config = [](HttpQuery &http_query) -> Result<string> {
    return http_query.get_arg("content").str();
  };
  return get_simple_config_impl(std::move(promise), scheduler_id, std::move(url), "reserve-5a846.firebaseio.com", {},
                                prefer_ipv6, std::move(get_config));
}

ActorOwn<> get_simple_config_firebase_firestore(Promise<SimpleConfigResult> promise, bool prefer_ipv6,
                                                Slice domain_name, bool is_test, int32 scheduler_id) {
  if (is_test) {
    promise.set_error(Status::Error(400, "Test config is not supported"));
    return ActorOwn<>();
  }

  string url = "https://www.google.com/v1/projects/reserve-5a846/databases/(default)/documents/ipconfig/v3";
  auto get_config = [](HttpQuery &http_query) -> Result<string> {
    TRY_RESULT(json, json_decode(http_query.get_arg("fields")));
    if (json.type() != JsonValue::Type::Object) {
      return Status::Error("Expected JSON object");
    }
    auto &json_object = json.get_object();
    TRY_RESULT(data, json_object.extract_required_field("data", JsonValue::Type::Object));
    auto &data_object = data.get_object();
    TRY_RESULT(config, data_object.get_required_string_field("stringValue"));
    return std::move(config);
  };
  return get_simple_config_impl(std::move(promise), scheduler_id, std::move(url), "firestore.googleapis.com", {},
                                prefer_ipv6, std::move(get_config));
}

static ActorOwn<> get_full_config(DcOption option, Promise<tl_object_ptr<telegram_api::config>> promise,
                                  ActorShared<> parent) {
  class SessionCallback final : public Session::Callback {
   public:
    SessionCallback(ActorShared<> parent, DcOption option) : parent_(std::move(parent)), option_(std::move(option)) {
    }
    void on_failed() final {
    }
    void on_closed() final {
    }
    void request_raw_connection(unique_ptr<mtproto::AuthData> auth_data,
                                Promise<unique_ptr<mtproto::RawConnection>> promise) final {
      request_raw_connection_cnt_++;
      VLOG(config_recoverer) << "Request full config from " << option_.get_ip_address()
                             << ", try = " << request_raw_connection_cnt_;
      if (request_raw_connection_cnt_ <= 2) {
        send_closure(G()->connection_creator(), &ConnectionCreator::request_raw_connection_by_ip,
                     option_.get_ip_address(),
                     mtproto::TransportType{mtproto::TransportType::ObfuscatedTcp,
                                            narrow_cast<int16>(option_.get_dc_id().get_raw_id()), option_.get_secret()},
                     std::move(promise));
      } else {
        // Delay all queries except first forever
        delay_forever_.push_back(std::move(promise));
      }
    }
    void on_tmp_auth_key_updated(mtproto::AuthKey auth_key) final {
      // nop
    }
    void on_server_salt_updated(std::vector<mtproto::ServerSalt> server_salts) final {
      // nop
    }
    void on_update(BufferSlice &&update, uint64 auth_key_id) final {
      // nop
    }
    void on_result(NetQueryPtr net_query) final {
      G()->net_query_dispatcher().dispatch(std::move(net_query));
    }

   private:
    ActorShared<> parent_;
    DcOption option_;
    size_t request_raw_connection_cnt_{0};
    std::vector<Promise<unique_ptr<mtproto::RawConnection>>> delay_forever_;
  };

  class SimpleAuthData final : public AuthDataShared {
   public:
    explicit SimpleAuthData(DcId dc_id)
        : dc_id_(dc_id), public_rsa_key_(PublicRsaKeySharedMain::create(G()->is_test_dc())) {
    }
    DcId dc_id() const final {
      return dc_id_;
    }
    const std::shared_ptr<mtproto::PublicRsaKeyInterface> &public_rsa_key() final {
      return public_rsa_key_;
    }
    mtproto::AuthKey get_auth_key() final {
      string dc_key = G()->td_db()->get_binlog_pmc()->get(auth_key_key());

      mtproto::AuthKey res;
      if (!dc_key.empty()) {
        unserialize(res, dc_key).ensure();
      }
      return res;
    }
    void set_auth_key(const mtproto::AuthKey &auth_key) final {
      G()->td_db()->get_binlog_pmc()->set(auth_key_key(), serialize(auth_key));

      //notify();
    }
    void update_server_time_difference(double diff, bool force) final {
      G()->update_server_time_difference(diff, force);
    }
    double get_server_time_difference() final {
      return G()->get_server_time_difference();
    }
    void add_auth_key_listener(unique_ptr<Listener> listener) final {
      CHECK(listener != nullptr);
      if (listener->notify()) {
        auth_key_listeners_.push_back(std::move(listener));
      }
    }

    void set_future_salts(const std::vector<mtproto::ServerSalt> &future_salts) final {
      G()->td_db()->get_binlog_pmc()->set(future_salts_key(), serialize(future_salts));
    }

    std::vector<mtproto::ServerSalt> get_future_salts() final {
      string future_salts = G()->td_db()->get_binlog_pmc()->get(future_salts_key());
      std::vector<mtproto::ServerSalt> res;
      if (!future_salts.empty()) {
        unserialize(res, future_salts).ensure();
      }
      return res;
    }

   private:
    DcId dc_id_;
    std::shared_ptr<mtproto::PublicRsaKeyInterface> public_rsa_key_;
    vector<unique_ptr<Listener>> auth_key_listeners_;
    /*
    void notify() {
      td::remove_if(auth_key_listeners_, [&](auto &listener) {
        CHECK(listener != nullptr);
        return !listener->notify();
      });
    }
    */
    string auth_key_key() const {
      return PSTRING() << "config_recovery_auth" << dc_id().get_raw_id();
    }

    string future_salts_key() const {
      return PSTRING() << "config_recovery_salt" << dc_id().get_raw_id();
    }
  };

  class GetConfigActor final : public NetQueryCallback {
   public:
    GetConfigActor(DcOption option, Promise<tl_object_ptr<telegram_api::config>> promise, ActorShared<> parent)
        : option_(std::move(option)), promise_(std::move(promise)), parent_(std::move(parent)) {
    }

   private:
    void start_up() final {
      auto auth_data = std::make_shared<SimpleAuthData>(option_.get_dc_id());
      int32 raw_dc_id = option_.get_dc_id().get_raw_id();
      auto session_callback = make_unique<SessionCallback>(actor_shared(this, 1), std::move(option_));

      int32 int_dc_id = raw_dc_id;
      if (G()->is_test_dc()) {
        int_dc_id += 10000;
      }
      session_ = create_actor<Session>(
          "ConfigSession", std::move(session_callback), std::move(auth_data), raw_dc_id, int_dc_id,
          false /*is_primary*/, false /*is_main*/, true /*use_pfs*/, false /*persist_tmp_auth_key*/, false /*is_cdn*/,
          false /*need_destroy_auth_key*/, mtproto::AuthKey(), std::vector<mtproto::ServerSalt>());
      auto query = G()->net_query_creator().create_unauth(telegram_api::help_getConfig(), DcId::empty());
      query->total_timeout_limit_ = 60 * 60 * 24;
      query->set_callback(actor_shared(this));
      query->dispatch_ttl_ = 0;
      send_closure(session_, &Session::send, std::move(query));
      set_timeout_in(10);
    }
    void on_result(NetQueryPtr query) final {
      promise_.set_result(fetch_result<telegram_api::help_getConfig>(std::move(query)));
    }
    void hangup_shared() final {
      if (get_link_token() == 1) {
        if (promise_) {
          promise_.set_error(Status::Error("Failed"));
        }
        stop();
      }
    }
    void hangup() final {
      session_.reset();
    }
    void timeout_expired() final {
      promise_.set_error(Status::Error("Timeout expired"));
      session_.reset();
    }

    DcOption option_;
    ActorOwn<Session> session_;
    Promise<tl_object_ptr<telegram_api::config>> promise_;
    ActorShared<> parent_;
  };

  return ActorOwn<>(
      create_actor<GetConfigActor>("GetConfigActor", std::move(option), std::move(promise), std::move(parent)));
}

class ConfigRecoverer final : public Actor {
 public:
  explicit ConfigRecoverer(ActorShared<> parent) : parent_(std::move(parent)) {
    connecting_since_ = Time::now();
  }

  void on_dc_options_update(DcOptions dc_options) {
    dc_options_update_ = std::move(dc_options);
    update_dc_options();
    loop();
  }

 private:
  void on_network(bool has_network, uint32 network_generation) {
    has_network_ = has_network;
    if (network_generation_ != network_generation) {
      if (has_network_) {
        has_network_since_ = Time::now_cached();
      }
    }
    loop();
  }
  void on_online(bool is_online) {
    if (is_online_ == is_online) {
      return;
    }

    is_online_ = is_online;
    if (is_online) {
      if (simple_config_.dc_options.empty()) {
        simple_config_expires_at_ = 0;
      }
      if (full_config_ == nullptr) {
        full_config_expires_at_ = 0;
      }
    }
    loop();
  }
  void on_connecting(bool is_connecting) {
    VLOG(config_recoverer) << "On connecting " << is_connecting;
    if (is_connecting && !is_connecting_) {
      connecting_since_ = Time::now_cached();
    }
    is_connecting_ = is_connecting;
    loop();
  }

  static bool check_phone_number_rules(Slice phone_number, Slice rules) {
    if (rules.empty() || phone_number.empty()) {
      return true;
    }

    bool found = false;
    for (auto prefix : full_split(rules, ',')) {
      if (prefix.empty()) {
        found = true;
      } else if (prefix[0] == '+' && begins_with(phone_number, prefix.substr(1))) {
        found = true;
      } else if (prefix[0] == '-' && begins_with(phone_number, prefix.substr(1))) {
        return false;
      } else {
        LOG(ERROR) << "Invalid prefix rule " << prefix;
      }
    }
    return found;
  }

  void on_simple_config(Result<SimpleConfigResult> r_simple_config_result, bool dummy) {
    simple_config_query_.reset();
    dc_options_i_ = 0;

    SimpleConfigResult cfg;
    if (r_simple_config_result.is_error()) {
      cfg.r_http_date = r_simple_config_result.error().clone();
      cfg.r_config = r_simple_config_result.move_as_error();
    } else {
      cfg = r_simple_config_result.move_as_ok();
    }

    if (cfg.r_http_date.is_ok() && (date_option_i_ == 0 || cfg.r_config.is_error())) {
      G()->update_dns_time_difference(cfg.r_http_date.ok() - Time::now());
    } else if (cfg.r_config.is_ok()) {
      G()->update_dns_time_difference(cfg.r_config.ok()->date_ - Time::now());
    }
    date_option_i_ = (date_option_i_ + 1) % 2;

    do_on_simple_config(std::move(cfg.r_config));
    update_dc_options();
    loop();
  }

  void do_on_simple_config(Result<SimpleConfig> r_simple_config) {
    if (r_simple_config.is_ok()) {
      auto config = r_simple_config.move_as_ok();
      VLOG(config_recoverer) << "Receive raw " << to_string(config);
      if (config->expires_ >= G()->unix_time()) {
        string phone_number = G()->get_option_string("my_phone_number");
        simple_config_.dc_options.clear();

        for (auto &rule : config->rules_) {
          if (check_phone_number_rules(phone_number, rule->phone_prefix_rules_) && DcId::is_valid(rule->dc_id_)) {
            DcId dc_id = DcId::internal(rule->dc_id_);
            for (auto &ip_port : rule->ips_) {
              DcOption option(dc_id, *ip_port);
              if (option.is_valid()) {
                simple_config_.dc_options.push_back(std::move(option));
              }
            }
          }
        }
        VLOG(config_recoverer) << "Receive SimpleConfig " << simple_config_;
      } else {
        VLOG(config_recoverer) << "Config has expired at " << config->expires_;
      }

      simple_config_expires_at_ = get_config_expire_time();
      simple_config_at_ = Time::now_cached();
      for (size_t i = 1; i < simple_config_.dc_options.size(); i++) {
        std::swap(simple_config_.dc_options[i], simple_config_.dc_options[Random::fast(0, static_cast<int>(i))]);
      }
    } else {
      VLOG(config_recoverer) << "Get SimpleConfig error " << r_simple_config.error();
      simple_config_ = DcOptions();
      simple_config_expires_at_ = get_failed_config_expire_time();
    }
  }

  void on_full_config(Result<tl_object_ptr<telegram_api::config>> r_full_config, bool dummy) {
    full_config_query_.reset();
    if (r_full_config.is_ok()) {
      full_config_ = r_full_config.move_as_ok();
      VLOG(config_recoverer) << "Receive " << to_string(full_config_);
      full_config_expires_at_ = get_config_expire_time();
      send_closure(G()->connection_creator(), &ConnectionCreator::on_dc_options, DcOptions(full_config_->dc_options_));
    } else {
      VLOG(config_recoverer) << "Failed to get config: " << r_full_config.error();
      full_config_ = nullptr;
      full_config_expires_at_ = get_failed_config_expire_time();
    }
    loop();
  }

  static bool expect_blocking() {
    return G()->get_option_boolean("expect_blocking", true);
  }

  double get_config_expire_time() const {
    auto offline_delay = is_online_ ? 0 : 5 * 60;
    auto expire_time = expect_blocking() ? Random::fast(2 * 60, 3 * 60) : Random::fast(20 * 60, 30 * 60);
    return Time::now() + offline_delay + expire_time;
  }

  double get_failed_config_expire_time() const {
    auto offline_delay = is_online_ ? 0 : 5 * 60;
    auto expire_time = expect_blocking() ? Random::fast(5, 7) : Random::fast(15, 30);
    return Time::now() + offline_delay + expire_time;
  }

  bool is_connecting_{false};
  double connecting_since_{0};

  bool is_online_{false};

  bool has_network_{false};
  double has_network_since_{0};
  uint32 network_generation_{0};

  DcOptions simple_config_;
  double simple_config_expires_at_{0};
  double simple_config_at_{0};
  ActorOwn<> simple_config_query_;

  DcOptions dc_options_update_;

  DcOptions dc_options_;  // dc_options_update_ + simple_config_
  double dc_options_at_{0};
  size_t dc_options_i_{0};

  size_t date_option_i_{0};

  tl_object_ptr<telegram_api::config> full_config_;
  double full_config_expires_at_{0};
  ActorOwn<> full_config_query_;

  uint32 ref_cnt_{1};
  bool close_flag_{false};
  uint32 simple_config_turn_{0};

  ActorShared<> parent_;

  void hangup_shared() final {
    ref_cnt_--;
    try_stop();
  }
  void hangup() final {
    ref_cnt_--;
    close_flag_ = true;
    full_config_query_.reset();
    simple_config_query_.reset();
    try_stop();
  }

  void try_stop() {
    if (ref_cnt_ == 0) {
      stop();
    }
  }

  double max_connecting_delay() const {
    return expect_blocking() ? 5 : 20;
  }

  void loop() final {
    if (close_flag_) {
      return;
    }
    if (Session::is_high_loaded()) {
      VLOG(config_recoverer) << "Skip config recoverer under high load";
      set_timeout_in(Random::fast(200, 300));
      return;
    }

    if (is_connecting_) {
      VLOG(config_recoverer) << "Failed to connect for " << Time::now() - connecting_since_ << " seconds";
    } else {
      VLOG(config_recoverer) << "Successfully connected in " << Time::now() - connecting_since_ << " seconds";
    }

    Timestamp wakeup_timestamp;
    auto check_timeout = [&](Timestamp timestamp) {
      if (timestamp.at() < Time::now_cached()) {
        return true;
      }
      wakeup_timestamp.relax(timestamp);
      return false;
    };

    bool has_connecting_problem =
        is_connecting_ && check_timeout(Timestamp::at(connecting_since_ + max_connecting_delay()));
    bool is_valid_simple_config = !check_timeout(Timestamp::at(simple_config_expires_at_));
    if (!is_valid_simple_config && !simple_config_.dc_options.empty()) {
      simple_config_ = DcOptions();
      update_dc_options();
    }
    bool need_simple_config = has_connecting_problem && !is_valid_simple_config && simple_config_query_.empty();
    bool has_dc_options = !dc_options_.dc_options.empty();
    bool is_valid_full_config = !check_timeout(Timestamp::at(full_config_expires_at_));
    bool need_full_config = has_connecting_problem && has_dc_options && !is_valid_full_config &&
                            full_config_query_.empty() &&
                            check_timeout(Timestamp::at(dc_options_at_ + (expect_blocking() ? 5 : 10)));
    if (need_simple_config) {
      ref_cnt_++;
      VLOG(config_recoverer) << "Ask simple config with turn " << simple_config_turn_;
      auto promise = PromiseCreator::lambda([self = actor_shared(this)](Result<SimpleConfigResult> r_simple_config) {
        send_closure(self, &ConfigRecoverer::on_simple_config, std::move(r_simple_config), false);
      });
      auto get_simple_config = [&] {
        switch (simple_config_turn_ % 10) {
          case 6:
            return get_simple_config_azure;
          case 2:
            return get_simple_config_firebase_remote_config;
          case 4:
            return get_simple_config_firebase_firestore;
          case 9:
            return get_simple_config_firebase_realtime;
          case 0:
          case 3:
          case 8:
            return get_simple_config_google_dns;
          case 1:
          case 5:
          case 7:
          default:
            return get_simple_config_mozilla_dns;
        }
      }();
      simple_config_query_ = get_simple_config(std::move(promise), G()->get_option_boolean("prefer_ipv6"),
                                               G()->get_option_string("dc_txt_domain_name"), G()->is_test_dc(),
                                               G()->get_gc_scheduler_id());
      simple_config_turn_++;
    }

    if (need_full_config) {
      ref_cnt_++;
      VLOG(config_recoverer) << "Ask full config with dc_options_i_ = " << dc_options_i_;
      full_config_query_ = get_full_config(
          dc_options_.dc_options[dc_options_i_],
          PromiseCreator::lambda(
              [actor_id = actor_id(this)](Result<tl_object_ptr<telegram_api::config>> r_full_config) {
                send_closure(actor_id, &ConfigRecoverer::on_full_config, std::move(r_full_config), false);
              }),
          actor_shared(this));
      dc_options_i_ = (dc_options_i_ + 1) % dc_options_.dc_options.size();
    }

    if (wakeup_timestamp) {
      VLOG(config_recoverer) << "Wakeup in " << format::as_time(wakeup_timestamp.in());
      set_timeout_at(wakeup_timestamp.at());
    }
  }

  void start_up() final {
    class StateCallback final : public StateManager::Callback {
     public:
      explicit StateCallback(ActorId<ConfigRecoverer> parent) : parent_(std::move(parent)) {
      }
      bool on_state(ConnectionState state) final {
        send_closure(parent_, &ConfigRecoverer::on_connecting, state == ConnectionState::Connecting);
        return parent_.is_alive();
      }
      bool on_network(NetType network_type, uint32 network_generation) final {
        send_closure(parent_, &ConfigRecoverer::on_network, network_type != NetType::None, network_generation);
        return parent_.is_alive();
      }
      bool on_online(bool online_flag) final {
        send_closure(parent_, &ConfigRecoverer::on_online, online_flag);
        return parent_.is_alive();
      }

     private:
      ActorId<ConfigRecoverer> parent_;
    };
    send_closure(G()->state_manager(), &StateManager::add_callback, make_unique<StateCallback>(actor_id(this)));
  }

  void update_dc_options() {
    auto new_dc_options = simple_config_.dc_options;
    new_dc_options.insert(new_dc_options.begin(), dc_options_update_.dc_options.begin(),
                          dc_options_update_.dc_options.end());
    if (new_dc_options != dc_options_.dc_options) {
      dc_options_.dc_options = std::move(new_dc_options);
      dc_options_i_ = 0;
      dc_options_at_ = Time::now();
    }
  }
};

template <class StorerT>
void ConfigManager::AppConfig::store(StorerT &storer) const {
  td::store(version_, storer);
  td::store(hash_, storer);
  config_->store(storer);
}

template <class ParserT>
void ConfigManager::AppConfig::parse(ParserT &parser) {
  td::parse(version_, parser);
  if (version_ != CURRENT_VERSION) {
    return parser.set_error("Invalid config version");
  }
  td::parse(hash_, parser);
  auto buffer = parser.template fetch_string_raw<BufferSlice>(parser.get_left_len());
  TlBufferParser buffer_parser{&buffer};
  config_ = telegram_api::jsonObject::fetch(buffer_parser);
  buffer_parser.fetch_end();
  if (buffer_parser.get_error() != nullptr) {
    return parser.set_error(buffer_parser.get_error());
  }
}

ConfigManager::ConfigManager(ActorShared<> parent) : parent_(std::move(parent)) {
  lazy_request_flood_control_.add_limit(20, 1);

  if (log_event_parse(app_config_, G()->td_db()->get_binlog_pmc()->get("app_config")).is_error()) {
    app_config_ = AppConfig();
  }
}

void ConfigManager::start_up() {
  config_recoverer_ = create_actor<ConfigRecoverer>("Recoverer", create_reference());
  send_closure(config_recoverer_, &ConfigRecoverer::on_dc_options_update, load_dc_options_update());

  auto expire_time = load_config_expire_time();
  auto auth_manager = G()->td().get_actor_unsafe()->auth_manager_.get();
  bool reload_config_on_restart = auth_manager == nullptr || !auth_manager->is_bot();
  if (expire_time.is_in_past() || reload_config_on_restart) {
    request_config(false);
  } else {
    expire_time_ = expire_time;
    set_timeout_in(expire_time_.in());
  }
}

ActorShared<> ConfigManager::create_reference() {
  ref_cnt_++;
  return actor_shared(this, REFCNT_TOKEN);
}

void ConfigManager::hangup_shared() {
  LOG_CHECK(get_link_token() == REFCNT_TOKEN) << "Receive link token " << get_link_token();
  ref_cnt_--;
  try_stop();
}

void ConfigManager::hangup() {
  ref_cnt_--;
  config_recoverer_.reset();
  try_stop();
}

void ConfigManager::loop() {
  if (expire_time_ && expire_time_.is_in_past()) {
    request_config(reopen_sessions_after_get_config_);
    expire_time_ = {};
  }
}

void ConfigManager::try_stop() {
  if (ref_cnt_ == 0) {
    stop();
  }
}

void ConfigManager::request_config(bool reopen_sessions) {
  if (G()->close_flag()) {
    return;
  }

  if (config_sent_cnt_ != 0 && !reopen_sessions) {
    return;
  }

  lazy_request_flood_control_.add_event(Time::now());
  request_config_from_dc_impl(DcId::main(), reopen_sessions);
}

void ConfigManager::lazy_request_config() {
  if (G()->close_flag()) {
    return;
  }

  if (config_sent_cnt_ != 0) {
    return;
  }

  expire_time_.relax(Timestamp::at(lazy_request_flood_control_.get_wakeup_at()));
  set_timeout_at(expire_time_.at());
}

void ConfigManager::reget_config(Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  reget_config_queries_.push_back(std::move(promise));
  if (reget_config_queries_.size() != 1) {
    return;
  }

  request_config_from_dc_impl(DcId::main(), false);
}

void ConfigManager::try_request_app_config() {
  if (get_app_config_queries_.size() + reget_app_config_queries_.size() != 1) {
    return;
  }

  auto query = G()->net_query_creator().create_unauth(telegram_api::help_getAppConfig(app_config_.hash_));
  query->total_timeout_limit_ = 60 * 60 * 24;
  G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this, 1));
}

void ConfigManager::get_app_config(Promise<td_api::object_ptr<td_api::JsonValue>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto auth_manager = G()->td().get_actor_unsafe()->auth_manager_.get();
  if (auth_manager != nullptr && auth_manager->is_bot()) {
    return promise.set_value(nullptr);
  }

  get_app_config_queries_.push_back(std::move(promise));
  try_request_app_config();
}

void ConfigManager::reget_app_config(Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto auth_manager = G()->td().get_actor_unsafe()->auth_manager_.get();
  if (auth_manager != nullptr && auth_manager->is_bot()) {
    return promise.set_value(Unit());
  }

  reget_app_config_queries_.push_back(std::move(promise));
  try_request_app_config();
}

void ConfigManager::get_content_settings(Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto auth_manager = G()->td().get_actor_unsafe()->auth_manager_.get();
  if (auth_manager == nullptr || !auth_manager->is_authorized() || auth_manager->is_bot()) {
    return promise.set_value(Unit());
  }

  get_content_settings_queries_.push_back(std::move(promise));
  if (get_content_settings_queries_.size() == 1) {
    G()->net_query_dispatcher().dispatch_with_callback(
        G()->net_query_creator().create(telegram_api::account_getContentSettings()), actor_shared(this, 2));
  }
}

void ConfigManager::set_content_settings(bool ignore_sensitive_content_restrictions, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  last_set_content_settings_ = ignore_sensitive_content_restrictions;
  auto &queries = set_content_settings_queries_[ignore_sensitive_content_restrictions];
  queries.push_back(std::move(promise));
  if (!is_set_content_settings_request_sent_) {
    is_set_content_settings_request_sent_ = true;
    int32 flags = 0;
    if (ignore_sensitive_content_restrictions) {
      flags |= telegram_api::account_setContentSettings::SENSITIVE_ENABLED_MASK;
    }
    G()->net_query_dispatcher().dispatch_with_callback(
        G()->net_query_creator().create(telegram_api::account_setContentSettings(flags, false /*ignored*/)),
        actor_shared(this, 3 + static_cast<uint64>(ignore_sensitive_content_restrictions)));
  }
}

void ConfigManager::on_dc_options_update(DcOptions dc_options) {
  save_dc_options_update(dc_options);
  if (!dc_options.dc_options.empty()) {
    expire_time_ = Timestamp::now();
    save_config_expire(expire_time_);
    set_timeout_in(expire_time_.in());
  }
  send_closure(config_recoverer_, &ConfigRecoverer::on_dc_options_update, std::move(dc_options));
}

void ConfigManager::request_config_from_dc_impl(DcId dc_id, bool reopen_sessions) {
  config_sent_cnt_++;
  reopen_sessions_after_get_config_ |= reopen_sessions;
  auto query = G()->net_query_creator().create_unauth(telegram_api::help_getConfig(), dc_id);
  query->total_timeout_limit_ = 60 * 60 * 24;
  G()->net_query_dispatcher().dispatch_with_callback(std::move(query),
                                                     actor_shared(this, 8 + static_cast<uint64>(reopen_sessions)));
}

void ConfigManager::do_set_ignore_sensitive_content_restrictions(bool ignore_sensitive_content_restrictions) {
  if (G()->have_option("ignore_sensitive_content_restrictions") &&
      G()->get_option_boolean("ignore_sensitive_content_restrictions") == ignore_sensitive_content_restrictions) {
    return;
  }
  G()->set_option_boolean("ignore_sensitive_content_restrictions", ignore_sensitive_content_restrictions);
  reget_app_config(Auto());
}

void ConfigManager::on_result(NetQueryPtr net_query) {
  auto token = get_link_token();
  if (token == 3 || token == 4) {
    is_set_content_settings_request_sent_ = false;
    bool ignore_sensitive_content_restrictions = (token == 4);
    auto result_ptr = fetch_result<telegram_api::account_setContentSettings>(std::move(net_query));
    if (result_ptr.is_error()) {
      fail_promises(set_content_settings_queries_[ignore_sensitive_content_restrictions], result_ptr.move_as_error());
    } else {
      if (G()->get_option_boolean("can_ignore_sensitive_content_restrictions") &&
          last_set_content_settings_ == ignore_sensitive_content_restrictions) {
        do_set_ignore_sensitive_content_restrictions(ignore_sensitive_content_restrictions);
      }

      set_promises(set_content_settings_queries_[ignore_sensitive_content_restrictions]);
    }

    if (!set_content_settings_queries_[!ignore_sensitive_content_restrictions].empty()) {
      if (ignore_sensitive_content_restrictions == last_set_content_settings_) {
        set_promises(set_content_settings_queries_[!ignore_sensitive_content_restrictions]);
      } else {
        set_content_settings(!ignore_sensitive_content_restrictions, Auto());
      }
    }
    return;
  }
  if (token == 2) {
    auto result_ptr = fetch_result<telegram_api::account_getContentSettings>(std::move(net_query));
    if (result_ptr.is_error()) {
      fail_promises(get_content_settings_queries_, result_ptr.move_as_error());
      return;
    }

    auto result = result_ptr.move_as_ok();
    do_set_ignore_sensitive_content_restrictions(result->sensitive_enabled_);
    G()->set_option_boolean("can_ignore_sensitive_content_restrictions", result->sensitive_can_change_);

    set_promises(get_content_settings_queries_);
    return;
  }
  if (token == 1) {
    auto promises = std::move(get_app_config_queries_);
    get_app_config_queries_.clear();
    auto unit_promises = std::move(reget_app_config_queries_);
    reget_app_config_queries_.clear();
    CHECK(!promises.empty() || !unit_promises.empty());
    auto result_ptr = fetch_result<telegram_api::help_getAppConfig>(std::move(net_query));
    if (result_ptr.is_error()) {
      fail_promises(promises, result_ptr.error().clone());
      fail_promises(unit_promises, result_ptr.move_as_error());
      return;
    }

    auto app_config_ptr = result_ptr.move_as_ok();
    if (app_config_ptr->get_id() == telegram_api::help_appConfigNotModified::ID) {
      if (app_config_.version_ == 0) {
        LOG(ERROR) << "Receive appConfigNotModified";
        fail_promises(promises, Status::Error(500, "Receive unexpected response"));
        fail_promises(unit_promises, Status::Error(500, "Receive unexpected response"));
        return;
      }
      CHECK(app_config_.config_ != nullptr);
    } else {
      CHECK(app_config_ptr->get_id() == telegram_api::help_appConfig::ID);
      auto app_config = telegram_api::move_object_as<telegram_api::help_appConfig>(app_config_ptr);
      process_app_config(app_config->config_);
      app_config_.version_ = AppConfig::CURRENT_VERSION;
      app_config_.hash_ = app_config->hash_;
      app_config_.config_ = std::move(app_config->config_);
      CHECK(app_config_.config_ != nullptr);
      G()->td_db()->get_binlog_pmc()->set("app_config", log_event_store(app_config_).as_slice().str());
    }
    G()->get_option_manager()->update_premium_options();
    for (auto &promise : promises) {
      promise.set_value(convert_json_value_object(app_config_.config_));
    }
    set_promises(unit_promises);
    return;
  }

  CHECK(token == 8 || token == 9);
  CHECK(config_sent_cnt_ > 0);
  config_sent_cnt_--;
  auto r_config = fetch_result<telegram_api::help_getConfig>(std::move(net_query));
  if (r_config.is_error()) {
    if (!G()->close_flag()) {
      LOG(WARNING) << "Failed to get config: " << r_config.error();
      expire_time_ = Timestamp::in(60.0);  // try again in a minute
      set_timeout_in(expire_time_.in());
    }
    fail_promises(reget_config_queries_, r_config.move_as_error());
  } else {
    on_dc_options_update(DcOptions());
    process_config(r_config.move_as_ok());
    if (token == 9) {
      G()->net_query_dispatcher().update_mtproto_header();
      reopen_sessions_after_get_config_ = false;
    }
    set_promises(reget_config_queries_);
  }
}

void ConfigManager::save_dc_options_update(const DcOptions &dc_options) {
  if (dc_options.dc_options.empty()) {
    G()->td_db()->get_binlog_pmc()->erase("dc_options_update");
    return;
  }
  G()->td_db()->get_binlog_pmc()->set("dc_options_update", log_event_store(dc_options).as_slice().str());
}

DcOptions ConfigManager::load_dc_options_update() {
  auto log_event_dc_options = G()->td_db()->get_binlog_pmc()->get("dc_options_update");
  DcOptions dc_options;
  if (!log_event_dc_options.empty()) {
    log_event_parse(dc_options, log_event_dc_options).ensure();
  }
  return dc_options;
}

Timestamp ConfigManager::load_config_expire_time() {
  auto expires_in = to_integer<int32>(G()->td_db()->get_binlog_pmc()->get("config_expire")) - Clocks::system();

  if (expires_in < 0 || expires_in > 60 * 60 /* 1 hour */) {
    return Timestamp::now();
  } else {
    return Timestamp::in(expires_in);
  }
}

void ConfigManager::save_config_expire(Timestamp timestamp) {
  G()->td_db()->get_binlog_pmc()->set("config_expire", to_string(static_cast<int>(Clocks::system() + timestamp.in())));
}

void ConfigManager::process_config(tl_object_ptr<telegram_api::config> config) {
  bool is_from_main_dc = G()->net_query_dispatcher().get_main_dc_id().get_value() == config->this_dc_;

  LOG(INFO) << to_string(config);
  auto reload_in = clamp(config->expires_ - config->date_, 60, 86400);
  save_config_expire(Timestamp::in(reload_in));
  reload_in -= Random::fast(0, reload_in / 5);
  if (!is_from_main_dc) {
    reload_in = 0;
  }
  expire_time_ = Timestamp::in(reload_in);
  set_timeout_at(expire_time_.at());
  LOG_IF(ERROR, config->test_mode_ != G()->is_test_dc()) << "Wrong parameter is_test";

  OptionManager &options = *G()->get_option_manager();

  // Do not save dc_options in config, because it will be interpreted and saved by ConnectionCreator.
  DcOptions dc_options(config->dc_options_);
  std::stable_sort(dc_options.dc_options.begin(), dc_options.dc_options.end(),
                   [](const DcOption &lhs, const DcOption &rhs) {
                     if (lhs.get_dc_id() != rhs.get_dc_id()) {
                       return lhs.get_dc_id() < rhs.get_dc_id();
                     }
                     return !lhs.is_ipv6() && rhs.is_ipv6();
                   });
  send_closure(G()->connection_creator(), &ConnectionCreator::on_dc_options, std::move(dc_options));

  options.set_option_integer("recent_stickers_limit", config->stickers_recent_limit_);
  options.set_option_integer("channels_read_media_period", config->channels_read_media_period_);

  send_closure(G()->link_manager(), &LinkManager::update_autologin_token, std::move(config->autologin_token_));

  options.set_option_boolean("test_mode", config->test_mode_);
  options.set_option_integer("forwarded_message_count_max", config->forwarded_count_max_);
  options.set_option_integer("basic_group_size_max", config->chat_size_max_);
  options.set_option_integer("supergroup_size_max", config->megagroup_size_max_);
  if (is_from_main_dc || !options.have_option("expect_blocking")) {
    options.set_option_boolean("expect_blocking", config->blocked_mode_);
  }
  if (is_from_main_dc || !options.have_option("dc_txt_domain_name")) {
    options.set_option_string("dc_txt_domain_name", config->dc_txt_domain_name_);
  }
  if (is_from_main_dc || !options.have_option("t_me_url")) {
    auto url = config->me_url_prefix_;
    if (!url.empty()) {
      if (url.back() != '/') {
        url.push_back('/');
      }
      options.set_option_string("t_me_url", url);
    }
  }
  if (is_from_main_dc) {
    options.set_option_integer("webfile_dc_id", config->webfile_dc_id_);
    if (config->tmp_sessions_ > 1) {
      options.set_option_integer("session_count", config->tmp_sessions_);
    } else {
      options.set_option_empty("session_count");
    }
    if (!config->suggested_lang_code_.empty() || config->lang_pack_version_ > 0 ||
        config->base_lang_pack_version_ > 0) {
      options.set_option_string("suggested_language_pack_id", config->suggested_lang_code_);
      options.set_option_integer("language_pack_version", config->lang_pack_version_);
      options.set_option_integer("base_language_pack_version", config->base_lang_pack_version_);
    } else {
      options.set_option_empty("suggested_language_pack_id");
      options.set_option_empty("language_pack_version");
      options.set_option_empty("base_language_pack_version");
    }
  }

  if (is_from_main_dc) {
    options.set_option_integer("edit_time_limit", config->edit_time_limit_);
    options.set_option_boolean("revoke_pm_inbox", config->revoke_pm_inbox_);
    options.set_option_integer("revoke_time_limit", config->revoke_time_limit_);
    options.set_option_integer("revoke_pm_time_limit", config->revoke_pm_time_limit_);

    options.set_option_integer("rating_e_decay", config->rating_e_decay_);
  }
  options.set_option_integer("call_ring_timeout_ms", config->call_ring_timeout_ms_);
  options.set_option_integer("call_connect_timeout_ms", config->call_connect_timeout_ms_);
  options.set_option_integer("call_packet_timeout_ms", config->call_packet_timeout_ms_);
  options.set_option_integer("call_receive_timeout_ms", config->call_receive_timeout_ms_);

  options.set_option_integer("message_text_length_max", clamp(config->message_length_max_, 4096, 1000000));
  options.set_option_integer("message_caption_length_max", clamp(config->caption_length_max_, 1024, 1000000));

  if (config->gif_search_username_.empty()) {
    options.set_option_empty("animation_search_bot_username");
  } else {
    options.set_option_string("animation_search_bot_username", config->gif_search_username_);
  }
  if (!options.have_option("venue_search_bot_username")) {
    if (config->venue_search_username_.empty()) {
      options.set_option_empty("venue_search_bot_username");
    } else {
      options.set_option_string("venue_search_bot_username", config->venue_search_username_);
    }
  }
  if (config->img_search_username_.empty()) {
    options.set_option_empty("photo_search_bot_username");
  } else {
    options.set_option_string("photo_search_bot_username", config->img_search_username_);
  }

  auto fix_timeout_ms = [](int32 timeout_ms) {
    return clamp(timeout_ms, 1000, 86400 * 1000);
  };

  options.set_option_integer("online_update_period_ms", fix_timeout_ms(config->online_update_period_ms_));

  options.set_option_integer("online_cloud_timeout_ms", fix_timeout_ms(config->online_cloud_timeout_ms_));
  options.set_option_integer("notification_cloud_delay_ms", fix_timeout_ms(config->notify_cloud_delay_ms_));
  options.set_option_integer("notification_default_delay_ms", fix_timeout_ms(config->notify_default_delay_ms_));

  if (is_from_main_dc && !options.have_option("default_reaction_need_sync")) {
    ReactionType reaction_type(config->reactions_default_);
    if (!reaction_type.is_empty() && !reaction_type.is_paid_reaction()) {
      options.set_option_string("default_reaction", reaction_type.get_string());
    }
  }

  // delete outdated options
  options.set_option_empty("suggested_language_code");
  options.set_option_empty("chat_big_size");
  options.set_option_empty("group_size_max");
  options.set_option_empty("saved_gifs_limit");
  options.set_option_empty("sessions_count");
  options.set_option_empty("forwarded_messages_count_max");
  options.set_option_empty("broadcast_size_max");
  options.set_option_empty("group_chat_size_max");
  options.set_option_empty("chat_size_max");
  options.set_option_empty("megagroup_size_max");
  options.set_option_empty("offline_blur_timeout_ms");
  options.set_option_empty("offline_idle_timeout_ms");
  options.set_option_empty("notify_cloud_delay_ms");
  options.set_option_empty("notify_default_delay_ms");
  options.set_option_empty("large_chat_size");
  options.set_option_empty("calls_enabled");

  // TODO implement online status updates
  //  options.set_option_integer("offline_blur_timeout_ms", config->offline_blur_timeout_ms_);
  //  options.set_option_integer("offline_idle_timeout_ms", config->offline_idle_timeout_ms_);

  //  options.set_option_integer("push_chat_period_ms", config->push_chat_period_ms_);
  //  options.set_option_integer("push_chat_limit", config->push_chat_limit_);

  if (is_from_main_dc) {
    reget_app_config(Auto());
    if (!options.have_option("can_ignore_sensitive_content_restrictions") ||
        !options.have_option("ignore_sensitive_content_restrictions")) {
      get_content_settings(Auto());
    }
  }
}

void ConfigManager::process_app_config(tl_object_ptr<telegram_api::JSONValue> &config) {
  CHECK(config != nullptr);
  LOG(INFO) << "Receive app config " << to_string(config);

  vector<string> autologin_domains;
  vector<string> url_auth_domains;
  vector<string> whitelisted_domains;

  vector<tl_object_ptr<telegram_api::jsonObjectValue>> new_values;
  string ignored_restriction_reasons;
  string restriction_add_platforms;
  vector<string> dice_emojis;
  FlatHashMap<string, size_t> dice_emoji_index;
  FlatHashMap<string, string> dice_emoji_success_value;
  vector<string> emoji_sounds;
  string animation_search_provider;
  string animation_search_emojis;
  vector<SuggestedAction> suggested_actions;
  vector<string> dismissed_suggestions;
  bool can_archive_and_mute_new_chats_from_unknown_users = false;
  int32 chat_read_mark_expire_period = 0;
  int32 chat_read_mark_size_threshold = 0;
  double animated_emoji_zoom = 0.0;
  int32 reactions_uniq_max = 0;
  vector<string> premium_features;
  auto &premium_limit_keys = get_premium_limit_keys();
  string premium_bot_username;
  string premium_invoice_slug;
  bool is_premium_available = false;
  int32 stickers_premium_by_emoji_num = 0;
  int32 stickers_normal_by_emoji_per_premium_num = 2;
  int32 telegram_antispam_group_size_min = 100;
  int32 topics_pinned_limit = -1;
  vector<string> fragment_prefixes;
  bool premium_gift_attach_menu_icon = false;
  bool premium_gift_text_field_icon = false;
  int32 dialog_filter_update_period = 300;
  // bool archive_all_stories = false;
  int32 story_viewers_expire_period = 86400;
  int64 stories_changelog_user_id = UserManager::get_service_notifications_user_id().get();
  int32 transcribe_audio_trial_weekly_number = 0;
  int32 transcribe_audio_trial_duration_max = 0;
  int32 transcribe_audio_trial_cooldown_until = 0;
  vector<string> business_features;
  string premium_manage_subscription_url;
  bool need_premium_for_new_chat_privacy = true;
  bool channel_revenue_withdrawal_enabled = false;
  bool can_edit_fact_check = false;
  vector<string> starref_start_param_prefixes;
  if (config->get_id() == telegram_api::jsonObject::ID) {
    for (auto &key_value : static_cast<telegram_api::jsonObject *>(config.get())->value_) {
      Slice key = key_value->key_;
      telegram_api::JSONValue *value = key_value->value_.get();
      if (key == "default_emoji_statuses_stickerset_id" || key == "forum_upgrade_participants_min" ||
          key == "getfile_experimental_params" || key == "message_animated_emoji_max" ||
          key == "stickers_emoji_cache_time" || key == "stories_export_nopublic_link" || key == "test" ||
          key == "upload_max_fileparts_default" || key == "upload_max_fileparts_premium" ||
          key == "wallet_blockchain_name" || key == "wallet_config" || key == "wallet_enabled" ||
          key == "channel_color_level_min") {
        continue;
      }
      if (key == "ignore_restriction_reasons") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto reasons = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &reason : reasons) {
            auto reason_name = get_json_value_string(std::move(reason), key);
            if (!reason_name.empty() && reason_name.find(',') == string::npos) {
              if (!ignored_restriction_reasons.empty()) {
                ignored_restriction_reasons += ',';
              }
              ignored_restriction_reasons += reason_name;
            } else {
              LOG(ERROR) << "Receive unexpected restriction reason " << reason_name;
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected ignore_restriction_reasons " << to_string(*value);
        }
        continue;
      }
      if (key == "restriction_add_platforms") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto platforms = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &platform : platforms) {
            auto platform_name = get_json_value_string(std::move(platform), key);
            if (!platform_name.empty() && platform_name.find(',') == string::npos) {
              if (!restriction_add_platforms.empty()) {
                restriction_add_platforms += ',';
              }
              restriction_add_platforms += platform_name;
            } else {
              LOG(ERROR) << "Receive unexpected restriction platform " << platform_name;
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected restriction_add_platforms " << to_string(*value);
        }
        continue;
      }
      if (key == "emojies_animated_zoom") {
        animated_emoji_zoom = get_json_value_double(std::move(key_value->value_), key);
        continue;
      }
      if (key == "emojies_send_dice") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto emojis = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &emoji : emojis) {
            auto emoji_text = get_json_value_string(std::move(emoji), key);
            if (!emoji_text.empty()) {
              dice_emoji_index[emoji_text] = dice_emojis.size();
              dice_emojis.push_back(emoji_text);
            } else {
              LOG(ERROR) << "Receive empty dice emoji";
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected emojies_send_dice " << to_string(*value);
        }
        continue;
      }
      if (key == "emojies_send_dice_success") {
        if (value->get_id() == telegram_api::jsonObject::ID) {
          auto success_values = std::move(static_cast<telegram_api::jsonObject *>(value)->value_);
          for (auto &success_value : success_values) {
            CHECK(success_value != nullptr);
            if (!success_value->key_.empty() && success_value->value_->get_id() == telegram_api::jsonObject::ID) {
              int32 dice_value = -1;
              int32 frame_start = -1;
              for (auto &dice_key_value :
                   static_cast<telegram_api::jsonObject *>(success_value->value_.get())->value_) {
                if (dice_key_value->value_->get_id() != telegram_api::jsonNumber::ID) {
                  continue;
                }
                auto current_value = get_json_value_int(std::move(dice_key_value->value_), Slice());
                if (dice_key_value->key_ == "value") {
                  dice_value = current_value;
                }
                if (dice_key_value->key_ == "frame_start") {
                  frame_start = current_value;
                }
              }
              if (dice_value < 0 || frame_start < 0) {
                LOG(ERROR) << "Receive unexpected dice success value " << to_string(success_value);
              } else {
                dice_emoji_success_value[success_value->key_] = PSTRING() << dice_value << ':' << frame_start;
              }
            } else {
              LOG(ERROR) << "Receive unexpected dice success value " << to_string(success_value);
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected emojies_send_dice_success " << to_string(*value);
        }
        continue;
      }
      if (key == "emojies_sounds") {
        if (value->get_id() == telegram_api::jsonObject::ID) {
          auto sounds = std::move(static_cast<telegram_api::jsonObject *>(value)->value_);
          for (auto &sound : sounds) {
            CHECK(sound != nullptr);
            if (sound->value_->get_id() == telegram_api::jsonObject::ID) {
              string id;
              string access_hash;
              string file_reference_base64;
              for (auto &sound_key_value : static_cast<telegram_api::jsonObject *>(sound->value_.get())->value_) {
                if (sound_key_value->value_->get_id() != telegram_api::jsonString::ID) {
                  continue;
                }
                auto current_value = get_json_value_string(std::move(sound_key_value->value_), Slice());
                if (sound_key_value->key_ == "id") {
                  id = std::move(current_value);
                } else if (sound_key_value->key_ == "access_hash") {
                  access_hash = std::move(current_value);
                } else if (sound_key_value->key_ == "file_reference_base64") {
                  file_reference_base64 = std::move(current_value);
                }
              }
              if (to_integer_safe<int64>(id).is_error() || to_integer_safe<int64>(access_hash).is_error() ||
                  !is_base64url(file_reference_base64) || !is_emoji(sound->key_)) {
                LOG(ERROR) << "Receive unexpected sound value " << to_string(sound);
              } else {
                emoji_sounds.push_back(sound->key_);
                emoji_sounds.push_back(PSTRING() << id << ':' << access_hash << ':' << file_reference_base64);
              }
            } else {
              LOG(ERROR) << "Receive unexpected emoji sound " << to_string(sound);
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected emojies_sounds " << to_string(*value);
        }
        continue;
      }
      if (key == "gif_search_branding") {
        animation_search_provider = get_json_value_string(std::move(key_value->value_), key);
        continue;
      }
      if (key == "gif_search_emojies") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto emojis = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &emoji : emojis) {
            auto emoji_str = get_json_value_string(std::move(emoji), key);
            if (!emoji_str.empty() && emoji_str.find(',') == string::npos) {
              if (!animation_search_emojis.empty()) {
                animation_search_emojis += ',';
              }
              animation_search_emojis += emoji_str;
            } else {
              LOG(ERROR) << "Receive unexpected animation search emoji " << emoji_str;
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected gif_search_emojies " << to_string(*value);
        }
        continue;
      }
      if (key == "pending_suggestions" || key == "dismissed_suggestions") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto actions = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          auto otherwise_relogin_days = G()->get_option_integer("otherwise_relogin_days");
          for (auto &action : actions) {
            auto action_str = get_json_value_string(std::move(action), key);
            if (key == "dismissed_suggestions") {
              dismissed_suggestions.push_back(action_str);
              continue;
            }
            SuggestedAction suggested_action(action_str);
            if (!suggested_action.is_empty()) {
              if (otherwise_relogin_days > 0 &&
                  suggested_action == SuggestedAction{SuggestedAction::Type::SetPassword}) {
                LOG(INFO) << "Skip SetPassword suggested action";
              } else {
                suggested_actions.push_back(suggested_action);
              }
            } else {
              LOG(ERROR) << "Receive unsupported suggested action " << action_str;
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected pending_suggestions " << to_string(*value);
        }
        continue;
      }
      if (key == "autoarchive_setting_available") {
        can_archive_and_mute_new_chats_from_unknown_users = get_json_value_bool(std::move(key_value->value_), key);
        continue;
      }
      if (key == "autologin_domains") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto domains = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &domain : domains) {
            autologin_domains.push_back(get_json_value_string(std::move(domain), key));
          }
        } else {
          LOG(ERROR) << "Receive unexpected autologin_domains " << to_string(*value);
        }
        continue;
      }
      if (key == "url_auth_domains") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto domains = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &domain : domains) {
            url_auth_domains.push_back(get_json_value_string(std::move(domain), key));
          }
        } else {
          LOG(ERROR) << "Receive unexpected url_auth_domains " << to_string(*value);
        }
        continue;
      }
      if (key == "whitelisted_domains") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto domains = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &domain : domains) {
            whitelisted_domains.push_back(get_json_value_string(std::move(domain), key));
          }
        } else {
          LOG(ERROR) << "Receive unexpected whitelisted_domains " << to_string(*value);
        }
        continue;
      }
      if (key == "round_video_encoding") {
        if (value->get_id() == telegram_api::jsonObject::ID) {
          auto video_note_settings = std::move(static_cast<telegram_api::jsonObject *>(value)->value_);
          for (auto &video_note_setting : video_note_settings) {
            CHECK(video_note_setting != nullptr);
            if (video_note_setting->key_ != "diameter" && video_note_setting->key_ != "video_bitrate" &&
                video_note_setting->key_ != "audio_bitrate" && video_note_setting->key_ != "max_size") {
              continue;
            }
            if (video_note_setting->value_->get_id() == telegram_api::jsonNumber::ID) {
              auto setting_value = get_json_value_int(std::move(video_note_setting->value_), Slice());
              if (setting_value > 0) {
                if (video_note_setting->key_ == "diameter") {
                  G()->set_option_integer("suggested_video_note_length", setting_value);
                }
                if (video_note_setting->key_ == "video_bitrate") {
                  G()->set_option_integer("suggested_video_note_video_bitrate", setting_value);
                }
                if (video_note_setting->key_ == "audio_bitrate") {
                  G()->set_option_integer("suggested_video_note_audio_bitrate", setting_value);
                }
                if (video_note_setting->key_ == "max_size") {
                  G()->set_option_integer("video_note_size_max", setting_value);
                }
              }
            } else {
              LOG(ERROR) << "Receive unexpected video note setting " << to_string(video_note_setting);
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected round_video_encoding " << to_string(*value);
        }
        continue;
      }
      if (key == "chat_read_mark_expire_period") {
        chat_read_mark_expire_period = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "chat_read_mark_size_threshold") {
        chat_read_mark_size_threshold = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "reactions_uniq_max") {
        reactions_uniq_max = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "ringtone_duration_max") {
        auto setting_value = get_json_value_int(std::move(key_value->value_), key);
        G()->set_option_integer("notification_sound_duration_max", setting_value);
        continue;
      }
      if (key == "ringtone_size_max") {
        auto setting_value = get_json_value_int(std::move(key_value->value_), key);
        G()->set_option_integer("notification_sound_size_max", setting_value);
        continue;
      }
      if (key == "ringtone_saved_count_max") {
        auto setting_value = get_json_value_int(std::move(key_value->value_), key);
        G()->set_option_integer("notification_sound_count_max", setting_value);
        continue;
      }
      if (key == "premium_promo_order") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto features = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &feature : features) {
            auto premium_feature = get_json_value_string(std::move(feature), key);
            if (!td::contains(premium_feature, ',')) {
              premium_features.push_back(std::move(premium_feature));
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected premium_promo_order " << to_string(*value);
        }
        continue;
      }
      bool is_premium_limit_key = false;
      for (auto premium_limit_key : premium_limit_keys) {
        if (begins_with(key, premium_limit_key)) {
          auto suffix = key.substr(premium_limit_key.size());
          if (suffix == "_limit_default" || suffix == "_limit_premium") {
            auto setting_value = get_json_value_int(std::move(key_value->value_), key);
            if (setting_value > 0) {
              G()->set_option_integer(key, setting_value);
            } else {
              LOG(ERROR) << "Receive invalid value " << setting_value << " for " << key;
            }
            is_premium_limit_key = true;
            break;
          }
        }
      }
      if (is_premium_limit_key) {
        continue;
      }
      if (key == "premium_bot_username") {
        premium_bot_username = get_json_value_string(std::move(key_value->value_), key);
        continue;
      }
      if (key == "premium_invoice_slug") {
        premium_invoice_slug = get_json_value_string(std::move(key_value->value_), key);
        continue;
      }
      if (key == "premium_purchase_blocked") {
        is_premium_available = !get_json_value_bool(std::move(key_value->value_), key);
        continue;
      }
      if (key == "stickers_premium_by_emoji_num") {
        stickers_premium_by_emoji_num = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "stickers_normal_by_emoji_per_premium_num") {
        stickers_normal_by_emoji_per_premium_num = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "reactions_user_max_default" || key == "reactions_user_max_premium") {
        auto setting_value = get_json_value_int(std::move(key_value->value_), key);
        G()->set_option_integer(key, setting_value);
        continue;
      }
      if (key == "telegram_antispam_user_id") {
        auto setting_value = get_json_value_long(std::move(key_value->value_), key);
        G()->set_option_integer("anti_spam_bot_user_id", setting_value);
        continue;
      }
      if (key == "telegram_antispam_group_size_min") {
        telegram_antispam_group_size_min = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "fragment_prefixes") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto prefixes = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &prefix : prefixes) {
            auto prefix_text = get_json_value_string(std::move(prefix), key);
            clean_phone_number(prefix_text);
            if (!prefix_text.empty()) {
              fragment_prefixes.push_back(prefix_text);
            } else {
              LOG(ERROR) << "Receive an invalid Fragment prefix";
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected fragment_prefixes " << to_string(*value);
        }
        continue;
      }
      if (key == "hidden_members_group_size_min") {
        auto setting_value = get_json_value_int(std::move(key_value->value_), key);
        G()->set_option_integer("hidden_members_group_size_min", setting_value);
        continue;
      }
      if (key == "topics_pinned_limit") {
        topics_pinned_limit = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "premium_gift_attach_menu_icon") {
        premium_gift_attach_menu_icon = get_json_value_bool(std::move(key_value->value_), key);
        continue;
      }
      if (key == "premium_gift_text_field_icon") {
        premium_gift_text_field_icon = get_json_value_bool(std::move(key_value->value_), key);
        continue;
      }
      if (key == "chatlist_update_period") {
        dialog_filter_update_period = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "stories_all_hidden") {
        // archive_all_stories = get_json_value_bool(std::move(key_value->value_), key);
        continue;
      }
      if (key == "story_viewers_expire_period") {
        story_viewers_expire_period = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "stories_changelog_user_id") {
        stories_changelog_user_id = get_json_value_long(std::move(key_value->value_), key);
        continue;
      }
      if (key == "stories_venue_search_username") {
        G()->set_option_string("venue_search_bot_username", get_json_value_string(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stories_stealth_past_period") {
        G()->set_option_integer("story_stealth_mode_past_period",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stories_stealth_future_period") {
        G()->set_option_integer("story_stealth_mode_future_period",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stories_stealth_cooldown_period") {
        G()->set_option_integer("story_stealth_mode_cooldown_period",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stories_entities") {
        G()->set_option_boolean("need_premium_for_story_caption_entities",
                                get_json_value_string(std::move(key_value->value_), key) == "premium");
        continue;
      }
      if (key == "authorization_autoconfirm_period") {
        G()->set_option_integer("authorization_autoconfirm_period",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "giveaway_add_peers_max") {
        G()->set_option_integer("giveaway_additional_chat_count_max",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "giveaway_countries_max") {
        G()->set_option_integer("giveaway_country_count_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "giveaway_boosts_per_premium") {
        G()->set_option_integer("giveaway_boost_count_per_premium",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "giveaway_period_max") {
        G()->set_option_integer("giveaway_duration_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "boosts_per_sent_gift") {
        G()->set_option_integer("premium_gift_boost_count", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "quote_length_max") {
        G()->set_option_integer("message_reply_quote_length_max",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "transcribe_audio_trial_weekly_number") {
        transcribe_audio_trial_weekly_number = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "transcribe_audio_trial_duration_max") {
        transcribe_audio_trial_duration_max = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "transcribe_audio_trial_cooldown_until") {
        transcribe_audio_trial_cooldown_until = get_json_value_int(std::move(key_value->value_), key);
        continue;
      }
      if (key == "boosts_channel_level_max") {
        G()->set_option_integer("chat_boost_level_max", max(0, get_json_value_int(std::move(key_value->value_), key)));
        continue;
      }
      if (key == "reactions_in_chat_max") {
        G()->set_option_integer("chat_available_reaction_count_max",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "channel_bg_icon_level_min" || key == "channel_custom_wallpaper_level_min" ||
          key == "channel_emoji_status_level_min" || key == "channel_profile_bg_icon_level_min" ||
          key == "channel_restrict_sponsored_level_min" || key == "channel_wallpaper_level_min" ||
          key == "pm_read_date_expire_period" || key == "group_transcribe_level_min" ||
          key == "group_emoji_stickers_level_min" || key == "group_profile_bg_icon_level_min" ||
          key == "group_emoji_status_level_min" || key == "group_wallpaper_level_min" ||
          key == "group_custom_wallpaper_level_min") {
        G()->set_option_integer(key, get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "quick_replies_limit") {
        G()->set_option_integer("quick_reply_shortcut_count_max",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "quick_reply_messages_limit") {
        G()->set_option_integer("quick_reply_shortcut_message_count_max",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "intro_title_length_limit") {
        G()->set_option_integer("business_start_page_title_length_max",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "intro_description_length_limit") {
        G()->set_option_integer("business_start_page_message_length_max",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "business_promo_order") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto features = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &feature : features) {
            auto business_feature = get_json_value_string(std::move(feature), key);
            if (!td::contains(business_feature, ',')) {
              business_features.push_back(std::move(business_feature));
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected business_promo_order " << to_string(*value);
        }
        continue;
      }
      if (key == "new_noncontact_peers_require_premium_without_ownpremium") {
        need_premium_for_new_chat_privacy = !get_json_value_bool(std::move(key_value->value_), key);
        continue;
      }
      if (key == "channel_revenue_withdrawal_enabled") {
        channel_revenue_withdrawal_enabled = get_json_value_bool(std::move(key_value->value_), key);
        continue;
      }
      if (key == "upload_premium_speedup_download") {
        G()->set_option_integer("premium_download_speedup", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "upload_premium_speedup_upload") {
        G()->set_option_integer("premium_upload_speedup", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "upload_premium_speedup_notify_period") {
        G()->set_option_integer(key, get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "business_chat_links_limit") {
        G()->set_option_integer("business_chat_link_count_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "premium_manage_subscription_url") {
        premium_manage_subscription_url = get_json_value_string(std::move(key_value->value_), key);
        continue;
      }
      if (key == "stories_pinned_to_top_count_max") {
        G()->set_option_integer("pinned_story_count_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "can_edit_factcheck") {
        can_edit_fact_check = get_json_value_bool(std::move(key_value->value_), key);
        continue;
      }
      if (key == "factcheck_length_limit") {
        G()->set_option_integer("fact_check_length_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stars_revenue_withdrawal_min") {
        G()->set_option_integer("star_withdrawal_count_min", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stories_area_url_max") {
        G()->set_option_integer("story_link_area_count_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stars_paid_post_amount_max") {
        G()->set_option_integer("paid_media_message_star_count_max",
                                clamp(get_json_value_int(std::move(key_value->value_), key), 0, 1000000));
        continue;
      }
      if (key == "web_app_allowed_protocols") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          vector<string> protocol_names;
          auto protocols = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &protocol : protocols) {
            auto protocol_name = get_json_value_string(std::move(protocol), key);
            if (!td::contains(protocol_name, ' ')) {
              protocol_names.push_back(std::move(protocol_name));
            }
          }
          G()->set_option_string("web_app_allowed_protocols", implode(protocol_names, ' '));
        } else {
          LOG(ERROR) << "Receive unexpected web_app_allowed_protocols " << to_string(*value);
        }
        continue;
      }
      if (key == "weather_search_username") {
        G()->set_option_string("weather_bot_username", get_json_value_string(std::move(key_value->value_), key));
        continue;
      }
      if (key == "bot_preview_medias_max") {
        G()->set_option_integer("bot_media_preview_count_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "story_weather_preload") {
        G()->set_option_boolean("can_preload_weather", get_json_value_bool(std::move(key_value->value_), key));
        continue;
      }
      if (key == "ton_proxy_address") {
        G()->set_option_string("ton_proxy_address", get_json_value_string(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stars_gifts_enabled") {
        G()->set_option_boolean("can_gift_stars", get_json_value_bool(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stars_paid_reaction_amount_max") {
        G()->set_option_integer("paid_reaction_star_count_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stars_subscription_amount_max") {
        G()->set_option_integer("subscription_star_count_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stars_usd_sell_rate_x1000") {
        G()->set_option_integer("usd_to_thousand_star_rate", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stars_usd_withdraw_rate_x1000") {
        G()->set_option_integer("thousand_star_to_usd_rate", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stargifts_message_length_max") {
        G()->set_option_integer("gift_text_length_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stargifts_convert_period_max") {
        G()->set_option_integer("gift_sell_period", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "starref_start_param_prefixes") {
        if (value->get_id() == telegram_api::jsonArray::ID) {
          auto prefixes = std::move(static_cast<telegram_api::jsonArray *>(value)->value_);
          for (auto &prefix : prefixes) {
            auto prefix_text = get_json_value_string(std::move(prefix), key);
            if (!prefix_text.empty() && prefix_text.find(' ') == string::npos) {
              fragment_prefixes.push_back(prefix_text);
            } else {
              LOG(ERROR) << "Receive an invalid affiliate program link prefix";
            }
          }
        } else {
          LOG(ERROR) << "Receive unexpected starref_start_param_prefixes " << to_string(*value);
        }
        continue;
      }
      if (key == "video_ignore_alt_documents") {
        G()->set_option_boolean("video_ignore_alt_documents", get_json_value_bool(std::move(key_value->value_), key));
        continue;
      }
      if (key == "starref_min_commission_permille") {
        G()->set_option_integer("affiliate_program_commission_per_mille_min",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "starref_max_commission_permille") {
        G()->set_option_integer("affiliate_program_commission_per_mille_max",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "bot_verification_description_length_limit") {
        G()->set_option_integer("bot_verification_custom_description_length_max",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "ton_blockchain_explorer_url") {
        G()->set_option_string("ton_blockchain_explorer_url", get_json_value_string(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stars_paid_messages_available") {
        G()->set_option_boolean("can_enable_paid_messages", get_json_value_bool(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stars_paid_message_amount_max") {
        G()->set_option_integer("paid_message_star_count_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stars_paid_message_commission_permille") {
        G()->set_option_integer("paid_message_earnings_per_mille",
                                get_json_value_int(std::move(key_value->value_), key));
        continue;
      }
      if (key == "stargifts_pinned_to_top_limit") {
        G()->set_option_integer("pinned_gift_count_max", get_json_value_int(std::move(key_value->value_), key));
        continue;
      }

      new_values.push_back(std::move(key_value));
    }
  } else {
    LOG(ERROR) << "Receive wrong app config " << to_string(config);
  }
  config = make_tl_object<telegram_api::jsonObject>(std::move(new_values));

  send_closure(G()->link_manager(), &LinkManager::update_autologin_domains, std::move(autologin_domains),
               std::move(url_auth_domains), std::move(whitelisted_domains));

  send_closure(G()->transcription_manager(), &TranscriptionManager::on_update_trial_parameters,
               transcribe_audio_trial_weekly_number, transcribe_audio_trial_duration_max,
               transcribe_audio_trial_cooldown_until);

  Global &options = *G();

  if (ignored_restriction_reasons.empty()) {
    options.set_option_empty("ignored_restriction_reasons");

    if (options.get_option_boolean("ignore_sensitive_content_restrictions", true) ||
        options.get_option_boolean("can_ignore_sensitive_content_restrictions", true)) {
      get_content_settings(Auto());
    }
  } else {
    options.set_option_string("ignored_restriction_reasons", ignored_restriction_reasons);

    if (!options.get_option_boolean("can_ignore_sensitive_content_restrictions") ||
        !options.get_option_boolean("ignore_sensitive_content_restrictions")) {
      get_content_settings(Auto());
    }
  }
  if (restriction_add_platforms.empty()) {
    options.set_option_empty("restriction_add_platforms");
  } else {
    options.set_option_string("restriction_add_platforms", restriction_add_platforms);
  }

  if (!dice_emojis.empty()) {
    vector<string> dice_success_values(dice_emojis.size());
    for (auto &it : dice_emoji_success_value) {
      auto dice_emoji_it = dice_emoji_index.find(it.first);
      if (dice_emoji_it == dice_emoji_index.end()) {
        LOG(ERROR) << "Can't find emoji " << it.first;
        continue;
      }
      dice_success_values[dice_emoji_it->second] = it.second;
    }
    options.set_option_string("dice_success_values", implode(dice_success_values, ','));
    options.set_option_string("dice_emojis", implode(dice_emojis, '\x01'));
  }

  options.set_option_string("fragment_prefixes", implode(fragment_prefixes, ','));

  if (starref_start_param_prefixes.empty()) {
    options.set_option_empty("starref_start_param_prefixes");
  } else {
    options.set_option_string("starref_start_param_prefixes", implode(starref_start_param_prefixes, ' '));
  }

  options.set_option_string("emoji_sounds", implode(emoji_sounds, ','));

  if (animated_emoji_zoom <= 0 || animated_emoji_zoom > 2.0) {
    options.set_option_empty("animated_emoji_zoom");
  } else {
    options.set_option_integer("animated_emoji_zoom", static_cast<int64>(animated_emoji_zoom * 1e9));
  }
  if (animation_search_provider.empty()) {
    options.set_option_empty("animation_search_provider");
  } else {
    options.set_option_string("animation_search_provider", animation_search_provider);
  }
  if (animation_search_emojis.empty()) {
    options.set_option_empty("animation_search_emojis");
  } else {
    options.set_option_string("animation_search_emojis", animation_search_emojis);
  }
  if (!can_archive_and_mute_new_chats_from_unknown_users) {
    options.set_option_empty("can_archive_and_mute_new_chats_from_unknown_users");
  } else {
    options.set_option_boolean("can_archive_and_mute_new_chats_from_unknown_users",
                               can_archive_and_mute_new_chats_from_unknown_users);
  }
  if (chat_read_mark_expire_period <= 0) {
    options.set_option_empty("chat_read_mark_expire_period");
  } else {
    options.set_option_integer("chat_read_mark_expire_period", chat_read_mark_expire_period);
  }
  if (chat_read_mark_size_threshold <= 0) {
    options.set_option_empty("chat_read_mark_size_threshold");
  } else {
    options.set_option_integer("chat_read_mark_size_threshold", chat_read_mark_size_threshold);
  }
  if (reactions_uniq_max <= 0 || reactions_uniq_max == 11) {
    options.set_option_empty("reactions_uniq_max");
  } else {
    options.set_option_integer("reactions_uniq_max", reactions_uniq_max);
  }
  if (telegram_antispam_group_size_min >= 0) {
    options.set_option_integer("aggressive_anti_spam_supergroup_member_count_min", telegram_antispam_group_size_min);
  }
  if (dialog_filter_update_period > 0) {
    options.set_option_integer("chat_folder_new_chats_update_period", dialog_filter_update_period);
  }
  if (td::contains(dismissed_suggestions, "BIRTHDAY_CONTACTS_TODAY")) {
    options.set_option_boolean("dismiss_birthday_contact_today", true);
  } else {
    options.set_option_empty("dismiss_birthday_contact_today");
  }

  if (!is_premium_available) {
    premium_bot_username.clear();  // just in case
    premium_invoice_slug.clear();  // just in case
    premium_features.clear();      // just in case
    business_features.clear();     // just in case
    options.set_option_empty("is_premium_available");
  } else {
    options.set_option_boolean("is_premium_available", is_premium_available);
  }
  options.set_option_string("premium_features", implode(premium_features, ','));
  options.set_option_string("business_features", implode(business_features, ','));
  if (premium_bot_username.empty()) {
    options.set_option_empty("premium_bot_username");
  } else {
    options.set_option_string("premium_bot_username", premium_bot_username);
  }
  if (premium_invoice_slug.empty()) {
    options.set_option_empty("premium_invoice_slug");
  } else {
    options.set_option_string("premium_invoice_slug", premium_invoice_slug);
  }
  if (topics_pinned_limit >= 0) {
    options.set_option_integer("pinned_forum_topic_count_max", topics_pinned_limit);
  } else {
    options.set_option_empty("pinned_forum_topic_count_max");
  }

  if (premium_gift_attach_menu_icon) {
    options.set_option_boolean("gift_premium_from_attachment_menu", premium_gift_attach_menu_icon);
  } else {
    options.set_option_empty("gift_premium_from_attachment_menu");
  }
  if (premium_gift_text_field_icon) {
    options.set_option_boolean("gift_premium_from_input_field", premium_gift_text_field_icon);
  } else {
    options.set_option_empty("gift_premium_from_input_field");
  }
  if (stories_changelog_user_id != UserManager::get_service_notifications_user_id().get()) {
    options.set_option_integer("stories_changelog_user_id", stories_changelog_user_id);
  } else {
    options.set_option_empty("stories_changelog_user_id");
  }
  if (can_edit_fact_check) {
    options.set_option_boolean("can_edit_fact_check", can_edit_fact_check);
  } else {
    options.set_option_empty("can_edit_fact_check");
  }

  if (story_viewers_expire_period >= 0) {
    options.set_option_integer("story_viewers_expiration_delay", story_viewers_expire_period);
  }

  if (!options.get_option_boolean("need_synchronize_archive_all_stories")) {
    // options.set_option_boolean("archive_all_stories", archive_all_stories);
  }
  options.set_option_empty("archive_all_stories");

  options.set_option_integer("stickers_premium_by_emoji_num", stickers_premium_by_emoji_num);
  options.set_option_integer("stickers_normal_by_emoji_per_premium_num", stickers_normal_by_emoji_per_premium_num);

  options.set_option_boolean("can_withdraw_chat_revenue", channel_revenue_withdrawal_enabled);
  options.set_option_boolean("need_premium_for_new_chat_privacy", need_premium_for_new_chat_privacy);

  options.set_option_empty("default_ton_blockchain_config");
  options.set_option_empty("default_ton_blockchain_name");
  options.set_option_empty("story_viewers_expire_period");

  if (premium_manage_subscription_url.empty()) {
    G()->set_option_empty("premium_manage_subscription_url");
  } else {
    G()->set_option_string("premium_manage_subscription_url", premium_manage_subscription_url);
  }

  // do not update suggested actions while changing content settings
  if (!is_set_content_settings_request_sent_) {
    send_closure(G()->suggested_action_manager(), &SuggestedActionManager::update_suggested_actions,
                 std::move(suggested_actions));
  }
}

}  // namespace td
