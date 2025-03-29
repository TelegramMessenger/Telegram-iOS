//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ConfigManager.h"
#include "td/telegram/net/PublicRsaKeySharedMain.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/telegram_api.h"

#include "td/mtproto/AuthData.h"
#include "td/mtproto/DhCallback.h"
#include "td/mtproto/DhHandshake.h"
#include "td/mtproto/Handshake.h"
#include "td/mtproto/HandshakeActor.h"
#include "td/mtproto/Ping.h"
#include "td/mtproto/PingConnection.h"
#include "td/mtproto/ProxySecret.h"
#include "td/mtproto/RawConnection.h"
#include "td/mtproto/RSA.h"
#include "td/mtproto/TlsInit.h"
#include "td/mtproto/TransportType.h"

#include "td/net/GetHostByNameActor.h"
#include "td/net/Socks5.h"
#include "td/net/TransparentProxy.h"

#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"

#include "td/utils/base64.h"
#include "td/utils/BufferedFd.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/HttpDate.h"
#include "td/utils/logging.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Promise.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/tests.h"
#include "td/utils/Time.h"

#include <memory>

TEST(Mtproto, GetHostByNameActor) {
  int threads_n = 1;
  td::ConcurrentScheduler sched(threads_n, 0);

  int cnt = 1;
  td::vector<td::ActorOwn<td::GetHostByNameActor>> actors;
  {
    auto guard = sched.get_main_guard();

    auto run = [&](td::ActorId<td::GetHostByNameActor> actor_id, td::string host, bool prefer_ipv6, bool allow_ok,
                   bool allow_error) {
      auto promise = td::PromiseCreator::lambda([&cnt, &actors, num = cnt, host, allow_ok,
                                                 allow_error](td::Result<td::IPAddress> r_ip_address) {
        if (r_ip_address.is_error() && !allow_error) {
          LOG(ERROR) << num << " \"" << host << "\" " << r_ip_address.error();
        }
        if (r_ip_address.is_ok() && !allow_ok && (r_ip_address.ok().is_ipv6() || r_ip_address.ok().get_ipv4() != 0)) {
          LOG(ERROR) << num << " \"" << host << "\" " << r_ip_address.ok();
        }
        if (--cnt == 0) {
          actors.clear();
          td::Scheduler::instance()->finish();
        }
      });
      cnt++;
      td::send_closure_later(actor_id, &td::GetHostByNameActor::run, host, 443, prefer_ipv6, std::move(promise));
    };

    td::vector<td::string> hosts = {"127.0.0.2",
                                    "1.1.1.1",
                                    "localhost",
                                    "web.telegram.org",
                                    "web.telegram.org.",
                                    "москва.рф",
                                    "",
                                    "%",
                                    " ",
                                    "a",
                                    "\x80",
                                    "[]",
                                    "127.0.0.1.",
                                    "0x12.0x34.0x56.0x78",
                                    "0x7f.001",
                                    "2001:0db8:85a3:0000:0000:8a2e:0370:7334",
                                    "[2001:0db8:85a3:0000:0000:8a2e:0370:7334]",
                                    "[[2001:0db8:85a3:0000:0000:8a2e:0370:7334]]"};
    for (const auto &types :
         {td::vector<td::GetHostByNameActor::ResolverType>{td::GetHostByNameActor::ResolverType::Native},
          td::vector<td::GetHostByNameActor::ResolverType>{td::GetHostByNameActor::ResolverType::Google},
          td::vector<td::GetHostByNameActor::ResolverType>{td::GetHostByNameActor::ResolverType::Google,
                                                           td::GetHostByNameActor::ResolverType::Google,
                                                           td::GetHostByNameActor::ResolverType::Native}}) {
      td::GetHostByNameActor::Options options;
      options.resolver_types = types;
      options.scheduler_id = threads_n;

      auto actor = td::create_actor<td::GetHostByNameActor>("GetHostByNameActor", std::move(options));
      auto actor_id = actor.get();
      actors.push_back(std::move(actor));

      for (auto host : hosts) {
        for (auto prefer_ipv6 : {false, true}) {
          bool allow_ok = host.size() > 2 && host[1] != '[';
          bool allow_both = host == "127.0.0.1." || host == "localhost" || (host == "москва.рф" && prefer_ipv6);
          bool allow_error = !allow_ok || allow_both;
          run(actor_id, host, prefer_ipv6, allow_ok, allow_error);
        }
      }
    }
  }
  cnt--;
  sched.start();
  while (sched.run_main(10)) {
    // empty
  }
  sched.finish();
}

TEST(Time, to_unix_time) {
  ASSERT_EQ(0, td::HttpDate::to_unix_time(1970, 1, 1, 0, 0, 0).move_as_ok());
  ASSERT_EQ(60 * 60 + 60 + 1, td::HttpDate::to_unix_time(1970, 1, 1, 1, 1, 1).move_as_ok());
  ASSERT_EQ(24 * 60 * 60, td::HttpDate::to_unix_time(1970, 1, 2, 0, 0, 0).move_as_ok());
  ASSERT_EQ(31 * 24 * 60 * 60, td::HttpDate::to_unix_time(1970, 2, 1, 0, 0, 0).move_as_ok());
  ASSERT_EQ(365 * 24 * 60 * 60, td::HttpDate::to_unix_time(1971, 1, 1, 0, 0, 0).move_as_ok());
  ASSERT_EQ(1562780559, td::HttpDate::to_unix_time(2019, 7, 10, 17, 42, 39).move_as_ok());
}

TEST(Time, parse_http_date) {
  ASSERT_EQ(784887151, td::HttpDate::parse_http_date("Tue, 15 Nov 1994 08:12:31 GMT").move_as_ok());
}

TEST(Mtproto, config) {
  int threads_n = 0;
  td::ConcurrentScheduler sched(threads_n, 0);

  int cnt = 1;
  {
    auto guard = sched.get_main_guard();

    auto run = [&](auto &func, bool is_test) {
      auto promise =
          td::PromiseCreator::lambda([&, num = cnt](td::Result<td::SimpleConfigResult> r_simple_config_result) {
            if (r_simple_config_result.is_ok()) {
              auto simple_config_result = r_simple_config_result.move_as_ok();
              auto date = simple_config_result.r_http_date.is_ok()
                              ? td::to_string(simple_config_result.r_http_date.ok())
                              : (PSTRING() << simple_config_result.r_http_date.error());
              auto config = simple_config_result.r_config.is_ok()
                                ? to_string(simple_config_result.r_config.ok())
                                : (PSTRING() << simple_config_result.r_config.error());
              LOG(ERROR) << num << " " << date << " " << config;
            } else {
              LOG(ERROR) << num << " " << r_simple_config_result.error();
            }
            if (--cnt == 0) {
              td::Scheduler::instance()->finish();
            }
          });
      cnt++;
      func(std::move(promise), false, td::Slice(), is_test, -1).release();
    };

    run(td::get_simple_config_azure, false);
    run(td::get_simple_config_google_dns, false);
    run(td::get_simple_config_mozilla_dns, false);
    run(td::get_simple_config_azure, true);
    run(td::get_simple_config_google_dns, true);
    run(td::get_simple_config_mozilla_dns, true);
    run(td::get_simple_config_firebase_remote_config, false);
    run(td::get_simple_config_firebase_realtime, false);
    run(td::get_simple_config_firebase_firestore, false);
  }
  cnt--;
  if (cnt != 0) {
    sched.start();
    while (sched.run_main(10)) {
      // empty;
    }
    sched.finish();
  }
}

TEST(Mtproto, encrypted_config) {
  td::string data =
      "   hO//tt \b\n\tiwPVovorKtIYtQ8y2ik7CqfJiJ4pJOCLRa4fBmNPixuRPXnBFF/3mTAAZoSyHq4SNylGHz0Cv1/"
      "FnWWdEV+BPJeOTk+ARHcNkuJBt0CqnfcVCoDOpKqGyq0U31s2MOpQvHgAG+Tlpg02syuH0E4dCGRw5CbJPARiynteb9y5fT5x/"
      "kmdp6BMR5tWQSQF0liH16zLh8BDSIdiMsikdcwnAvBwdNhRqQBqGx9MTh62MDmlebjtczE9Gz0z5cscUO2yhzGdphgIy6SP+"
      "bwaqLWYF0XdPGjKLMUEJW+rou6fbL1t/EUXPtU0XmQAnO0Fh86h+AqDMOe30N4qKrPQ==   ";
  td::telegram_api::object_ptr<td::telegram_api::help_configSimple> config = td::decode_config(data).move_as_ok();
}

class TestPingActor final : public td::Actor {
 public:
  TestPingActor(td::IPAddress ip_address, td::Status *result) : ip_address_(ip_address), result_(result) {
  }

 private:
  td::IPAddress ip_address_;
  td::unique_ptr<td::mtproto::PingConnection> ping_connection_;
  td::Status *result_;
  bool is_inited_ = false;

  void start_up() final {
    auto r_socket = td::SocketFd::open(ip_address_);
    if (r_socket.is_error()) {
      LOG(ERROR) << "Failed to open socket: " << r_socket.error();
      return stop();
    }

    ping_connection_ = td::mtproto::PingConnection::create_req_pq(
        td::mtproto::RawConnection::create(
            ip_address_, td::BufferedFd<td::SocketFd>(r_socket.move_as_ok()),
            td::mtproto::TransportType{td::mtproto::TransportType::Tcp, 0, td::mtproto::ProxySecret()}, nullptr),
        3);

    td::Scheduler::subscribe(ping_connection_->get_poll_info().extract_pollable_fd(this));
    is_inited_ = true;
    set_timeout_in(10);
    yield();
  }

  void tear_down() final {
    if (is_inited_) {
      td::Scheduler::unsubscribe_before_close(ping_connection_->get_poll_info().get_pollable_fd_ref());
    }
    td::Scheduler::instance()->finish();
  }

  void loop() final {
    auto status = ping_connection_->flush();
    if (status.is_error()) {
      *result_ = std::move(status);
      return stop();
    }
    if (ping_connection_->was_pong()) {
      LOG(INFO) << "Receive pong";
      return stop();
    }
  }

  void timeout_expired() final {
    *result_ = td::Status::Error("Timeout expired");
    stop();
  }
};

static td::IPAddress get_default_ip_address() {
  td::IPAddress ip_address;
#if TD_EMSCRIPTEN
  ip_address.init_host_port("venus.web.telegram.org/apiws", 443).ensure();
#else
  ip_address.init_ipv4_port("149.154.167.40", 80).ensure();
#endif
  return ip_address;
}

static td::int32 get_default_dc_id() {
  return 10002;
}

class Mtproto_ping final : public td::Test {
 public:
  using Test::Test;
  bool step() final {
    if (!is_inited_) {
      sched_.create_actor_unsafe<TestPingActor>(0, "Pinger", get_default_ip_address(), &result_).release();
      sched_.start();
      is_inited_ = true;
    }

    bool ret = sched_.run_main(10);
    if (ret) {
      return true;
    }
    sched_.finish();
    if (result_.is_error()) {
      LOG(ERROR) << result_;
    }
    return false;
  }

 private:
  bool is_inited_ = false;
  td::ConcurrentScheduler sched_{0, 0};
  td::Status result_;
};
td::RegisterTest<Mtproto_ping> mtproto_ping("Mtproto_ping");

class HandshakeContext final : public td::mtproto::AuthKeyHandshakeContext {
 public:
  td::mtproto::DhCallback *get_dh_callback() final {
    return nullptr;
  }
  td::mtproto::PublicRsaKeyInterface *get_public_rsa_key_interface() final {
    return public_rsa_key_.get();
  }

 private:
  std::shared_ptr<td::mtproto::PublicRsaKeyInterface> public_rsa_key_ = td::PublicRsaKeySharedMain::create(true);
};

class HandshakeTestActor final : public td::Actor {
 public:
  HandshakeTestActor(td::int32 dc_id, td::Status *result) : dc_id_(dc_id), result_(result) {
  }

 private:
  td::int32 dc_id_ = 0;
  td::Status *result_;
  bool wait_for_raw_connection_ = false;
  td::unique_ptr<td::mtproto::RawConnection> raw_connection_;
  bool wait_for_handshake_ = false;
  td::unique_ptr<td::mtproto::AuthKeyHandshake> handshake_;
  td::Status status_;
  bool wait_for_result_ = false;

  void tear_down() final {
    if (raw_connection_) {
      raw_connection_->close();
    }
    finish(td::Status::Error("Interrupted"));
  }
  void loop() final {
    if (!wait_for_raw_connection_ && !raw_connection_) {
      auto ip_address = get_default_ip_address();
      auto r_socket = td::SocketFd::open(ip_address);
      if (r_socket.is_error()) {
        finish(td::Status::Error(PSTRING() << "Failed to open socket: " << r_socket.error()));
        return stop();
      }

      raw_connection_ = td::mtproto::RawConnection::create(
          ip_address, td::BufferedFd<td::SocketFd>(r_socket.move_as_ok()),
          td::mtproto::TransportType{td::mtproto::TransportType::Tcp, 0, td::mtproto::ProxySecret()}, nullptr);
    }
    if (!wait_for_handshake_ && !handshake_) {
      handshake_ = td::make_unique<td::mtproto::AuthKeyHandshake>(dc_id_, 3600);
    }
    if (raw_connection_ && handshake_) {
      if (wait_for_result_) {
        wait_for_result_ = false;
        if (status_.is_error()) {
          finish(std::move(status_));
          return stop();
        }
        if (!handshake_->is_ready_for_finish()) {
          finish(td::Status::Error("Key is not ready.."));
          return stop();
        }
        finish(td::Status::OK());
        return stop();
      }

      wait_for_result_ = true;
      td::create_actor<td::mtproto::HandshakeActor>(
          "HandshakeActor", std::move(handshake_), std::move(raw_connection_), td::make_unique<HandshakeContext>(),
          10.0,
          td::PromiseCreator::lambda(
              [actor_id = actor_id(this)](td::Result<td::unique_ptr<td::mtproto::RawConnection>> raw_connection) {
                td::send_closure(actor_id, &HandshakeTestActor::on_connection, std::move(raw_connection), 1);
              }),
          td::PromiseCreator::lambda(
              [actor_id = actor_id(this)](td::Result<td::unique_ptr<td::mtproto::AuthKeyHandshake>> handshake) {
                td::send_closure(actor_id, &HandshakeTestActor::on_handshake, std::move(handshake), 1);
              }))
          .release();
      wait_for_raw_connection_ = true;
      wait_for_handshake_ = true;
    }
  }

  void on_connection(td::Result<td::unique_ptr<td::mtproto::RawConnection>> r_raw_connection, bool dummy) {
    CHECK(wait_for_raw_connection_);
    wait_for_raw_connection_ = false;
    if (r_raw_connection.is_ok()) {
      raw_connection_ = r_raw_connection.move_as_ok();
      status_ = td::Status::OK();
    } else {
      status_ = r_raw_connection.move_as_error();
    }
    // TODO: save error
    loop();
  }

  void on_handshake(td::Result<td::unique_ptr<td::mtproto::AuthKeyHandshake>> r_handshake, bool dummy) {
    CHECK(wait_for_handshake_);
    wait_for_handshake_ = false;
    CHECK(r_handshake.is_ok());
    handshake_ = r_handshake.move_as_ok();
    loop();
  }

  void finish(td::Status status) {
    if (!result_) {
      return;
    }
    *result_ = std::move(status);
    result_ = nullptr;
    td::Scheduler::instance()->finish();
  }
};

class Mtproto_handshake final : public td::Test {
 public:
  using Test::Test;
  bool step() final {
    if (!is_inited_) {
      sched_.create_actor_unsafe<HandshakeTestActor>(0, "HandshakeTestActor", get_default_dc_id(), &result_).release();
      sched_.start();
      is_inited_ = true;
    }

    bool ret = sched_.run_main(10);
    if (ret) {
      return true;
    }
    sched_.finish();
    if (result_.is_error()) {
      LOG(ERROR) << result_;
    }
    return false;
  }

 private:
  bool is_inited_ = false;
  td::ConcurrentScheduler sched_{0, 0};
  td::Status result_;
};
td::RegisterTest<Mtproto_handshake> mtproto_handshake("Mtproto_handshake");

class Socks5TestActor final : public td::Actor {
 public:
  void start_up() final {
    auto promise =
        td::PromiseCreator::lambda([actor_id = actor_id(this)](td::Result<td::BufferedFd<td::SocketFd>> res) {
          td::send_closure(actor_id, &Socks5TestActor::on_result, std::move(res), false);
        });

    class Callback final : public td::TransparentProxy::Callback {
     public:
      explicit Callback(td::Promise<td::BufferedFd<td::SocketFd>> promise) : promise_(std::move(promise)) {
      }
      void set_result(td::Result<td::BufferedFd<td::SocketFd>> result) final {
        promise_.set_result(std::move(result));
      }
      void on_connected() final {
      }

     private:
      td::Promise<td::BufferedFd<td::SocketFd>> promise_;
    };

    td::IPAddress socks5_ip;
    socks5_ip.init_ipv4_port("131.191.89.104", 43077).ensure();
    td::IPAddress mtproto_ip_address = get_default_ip_address();

    auto r_socket = td::SocketFd::open(socks5_ip);
    if (r_socket.is_error()) {
      return promise.set_error(td::Status::Error(PSTRING() << "Failed to open socket: " << r_socket.error()));
    }
    td::create_actor<td::Socks5>("Socks5", r_socket.move_as_ok(), mtproto_ip_address, "", "",
                                 td::make_unique<Callback>(std::move(promise)), actor_shared(this))
        .release();
  }

 private:
  void on_result(td::Result<td::BufferedFd<td::SocketFd>> res, bool dummy) {
    res.ensure();
    td::Scheduler::instance()->finish();
  }
};

TEST(Mtproto, socks5) {
  return;
  int threads_n = 0;
  td::ConcurrentScheduler sched(threads_n, 0);

  sched.create_actor_unsafe<Socks5TestActor>(0, "Socks5TestActor").release();
  sched.start();
  while (sched.run_main(10)) {
    // empty;
  }
  sched.finish();
}

TEST(Mtproto, notifications) {
  td::vector<td::string> pushes = {
      "eyJwIjoiSkRnQ3NMRWxEaWhyVWRRN1pYM3J1WVU4TlRBMFhMb0N6UWRNdzJ1cWlqMkdRbVR1WXVvYXhUeFJHaG1QQm8yVElYZFBzX2N3b2RIb3lY"
      "b2drVjM1dVl0UzdWeElNX1FNMDRKMG1mV3ZZWm4zbEtaVlJ0aFVBNGhYUWlaN0pfWDMyZDBLQUlEOWgzRnZwRjNXUFRHQWRaVkdFYzg3bnFPZ3hD"
      "NUNMRkM2SU9fZmVqcEpaV2RDRlhBWWpwc1k2aktrbVNRdFZ1MzE5ZW04UFVieXZudFpfdTNud2hjQ0czMk96TGp4S1kyS1lzU21JZm1GMzRmTmw1"
      "QUxaa2JvY2s2cE5rZEdrak9qYmRLckJyU0ZtWU8tQ0FsRE10dEplZFFnY1U5bVJQdU80b1d2NG5sb1VXS19zSlNTaXdIWEZyb1pWTnZTeFJ0Z1dN"
      "ZyJ9",
      "eyJwIjoiSkRnQ3NMRWxEaWlZby1GRWJndk9WaTFkUFdPVmZndzBBWHYwTWNzWDFhWEtNZC03T1Q2WWNfT0taRURHZDJsZ0h0WkhMSllyVG50RE95"
      "TkY1aXJRQlZ4UUFLQlRBekhPTGZIS3BhQXdoaWd5b3NQd0piWnJVV2xRWmh4eEozUFUzZjBNRTEwX0xNT0pFN0xsVUFaY2dabUNaX2V1QmNPZWNK"
      "VERxRkpIRGZjN2pBOWNrcFkyNmJRT2dPUEhCeHlEMUVrNVdQcFpLTnlBODVuYzQ1eHFPdERqcU5aVmFLU3pKb2VIcXBQMnJqR29kN2M5YkxsdGd5"
      "Q0NGd2NBU3dJeDc3QWNWVXY1UnVZIn0"};
  td::string key =
      "uBa5yu01a-nJJeqsR3yeqMs6fJLYXjecYzFcvS6jIwS3nefBIr95LWrTm-IbRBNDLrkISz1Sv0KYpDzhU8WFRk1D0V_"
      "qyO7XsbDPyrYxRBpGxofJUINSjb1uCxoSdoh1_F0UXEA2fWWKKVxL0DKUQssZfbVj3AbRglsWpH-jDK1oc6eBydRiS3i4j-"
      "H0yJkEMoKRgaF9NaYI4u26oIQ-Ez46kTVU-R7e3acdofOJKm7HIKan_5ZMg82Dvec2M6vc_"
      "I54Vs28iBx8IbBO1y5z9WSScgW3JCvFFKP2MXIu7Jow5-cpUx6jXdzwRUb9RDApwAFKi45zpv8eb3uPCDAmIQ";
  td::vector<td::string> decrypted_payloads = {
      "eyJsb2Nfa2V5IjoiTUVTU0FHRV9URVhUIiwibG9jX2FyZ3MiOlsiQXJzZW55IFNtaXJub3YiLCJhYmNkZWZnIl0sImN1c3RvbSI6eyJtc2dfaWQi"
      "OiI1OTAwNDciLCJmcm9tX2lkIjoiNjI4MTQifSwiYmFkZ2UiOiI0MDkifQ",
      "eyJsb2Nfa2V5IjoiIiwibG9jX2FyZ3MiOltdLCJjdXN0b20iOnsiY2hhbm5lbF9pZCI6IjExNzY4OTU0OTciLCJtYXhfaWQiOiIxMzU5In0sImJh"
      "ZGdlIjoiMCJ9"};
  key = td::base64url_decode(key).move_as_ok();

  for (size_t i = 0; i < pushes.size(); i++) {
    auto push = td::base64url_decode(pushes[i]).move_as_ok();
    auto decrypted_payload = td::base64url_decode(decrypted_payloads[i]).move_as_ok();

    auto key_id = td::mtproto::DhHandshake::calc_key_id(key);
    ASSERT_EQ(key_id, td::NotificationManager::get_push_receiver_id(push).ok());
    ASSERT_EQ(decrypted_payload, td::NotificationManager::decrypt_push(key_id, key, push).ok());
  }
}

class FastPingTestActor final : public td::Actor {
 public:
  explicit FastPingTestActor(td::Status *result) : result_(result) {
  }

 private:
  td::Status *result_;
  td::unique_ptr<td::mtproto::RawConnection> connection_;
  td::unique_ptr<td::mtproto::AuthKeyHandshake> handshake_;
  td::ActorOwn<> fast_ping_;
  int iteration_{0};

  void start_up() final {
    // Run handshake to create key and salt
    auto ip_address = get_default_ip_address();
    auto r_socket = td::SocketFd::open(ip_address);
    if (r_socket.is_error()) {
      *result_ = td::Status::Error(PSTRING() << "Failed to open socket: " << r_socket.error());
      return stop();
    }

    auto raw_connection = td::mtproto::RawConnection::create(
        ip_address, td::BufferedFd<td::SocketFd>(r_socket.move_as_ok()),
        td::mtproto::TransportType{td::mtproto::TransportType::Tcp, 0, td::mtproto::ProxySecret()}, nullptr);
    auto handshake = td::make_unique<td::mtproto::AuthKeyHandshake>(get_default_dc_id(), 60 * 100 /*temp*/);
    td::create_actor<td::mtproto::HandshakeActor>(
        "HandshakeActor", std::move(handshake), std::move(raw_connection), td::make_unique<HandshakeContext>(), 10.0,
        td::PromiseCreator::lambda(
            [actor_id = actor_id(this)](td::Result<td::unique_ptr<td::mtproto::RawConnection>> raw_connection) {
              td::send_closure(actor_id, &FastPingTestActor::on_connection, std::move(raw_connection), 1);
            }),
        td::PromiseCreator::lambda(
            [actor_id = actor_id(this)](td::Result<td::unique_ptr<td::mtproto::AuthKeyHandshake>> handshake) {
              td::send_closure(actor_id, &FastPingTestActor::on_handshake, std::move(handshake), 1);
            }))
        .release();
  }

  void on_connection(td::Result<td::unique_ptr<td::mtproto::RawConnection>> r_raw_connection, bool dummy) {
    if (r_raw_connection.is_error()) {
      *result_ = r_raw_connection.move_as_error();
      LOG(INFO) << "Receive " << *result_ << " instead of a connection";
      return stop();
    }
    connection_ = r_raw_connection.move_as_ok();
    loop();
  }

  void on_handshake(td::Result<td::unique_ptr<td::mtproto::AuthKeyHandshake>> r_handshake, bool dummy) {
    if (r_handshake.is_error()) {
      *result_ = r_handshake.move_as_error();
      LOG(INFO) << "Receive " << *result_ << " instead of a handshake";
      return stop();
    }
    handshake_ = r_handshake.move_as_ok();
    loop();
  }

  void on_raw_connection(td::Result<td::unique_ptr<td::mtproto::RawConnection>> r_connection) {
    if (r_connection.is_error()) {
      *result_ = r_connection.move_as_error();
      LOG(INFO) << "Receive " << *result_ << " instead of a handshake";
      return stop();
    }
    connection_ = r_connection.move_as_ok();
    LOG(INFO) << "RTT: " << connection_->extra().rtt;
    connection_->extra().rtt = 0;
    loop();
  }

  void loop() final {
    if (handshake_ && connection_) {
      LOG(INFO) << "Iteration " << iteration_;
      if (iteration_ == 6) {
        return stop();
      }
      td::unique_ptr<td::mtproto::AuthData> auth_data;
      if (iteration_ % 2 == 0) {
        auth_data = td::make_unique<td::mtproto::AuthData>();
        auth_data->set_tmp_auth_key(handshake_->get_auth_key());
        auth_data->reset_server_time_difference(handshake_->get_server_time_diff());
        auth_data->set_server_salt(handshake_->get_server_salt(), td::Time::now());
        auth_data->set_future_salts({td::mtproto::ServerSalt{0u, 1e20, 1e30}}, td::Time::now());
        auth_data->set_use_pfs(true);
        td::uint64 session_id = 0;
        do {
          td::Random::secure_bytes(reinterpret_cast<td::uint8 *>(&session_id), sizeof(session_id));
        } while (session_id == 0);
        auth_data->set_session_id(session_id);
      }
      iteration_++;
      fast_ping_ = create_ping_actor(
          td::Slice(), std::move(connection_), std::move(auth_data),
          td::PromiseCreator::lambda(
              [actor_id = actor_id(this)](td::Result<td::unique_ptr<td::mtproto::RawConnection>> r_raw_connection) {
                td::send_closure(actor_id, &FastPingTestActor::on_raw_connection, std::move(r_raw_connection));
              }),
          td::ActorShared<>());
    }
  }

  void tear_down() final {
    td::Scheduler::instance()->finish();
  }
};

class Mtproto_FastPing final : public td::Test {
 public:
  using Test::Test;
  bool step() final {
    if (!is_inited_) {
      sched_.create_actor_unsafe<FastPingTestActor>(0, "FastPingTestActor", &result_).release();
      sched_.start();
      is_inited_ = true;
    }

    bool ret = sched_.run_main(10);
    if (ret) {
      return true;
    }
    sched_.finish();
    if (result_.is_error()) {
      LOG(ERROR) << result_;
    }
    return false;
  }

 private:
  bool is_inited_ = false;
  td::ConcurrentScheduler sched_{0, 0};
  td::Status result_;
};
td::RegisterTest<Mtproto_FastPing> mtproto_fastping("Mtproto_FastPing");

TEST(Mtproto, Grease) {
  td::string s(10000, '0');
  td::mtproto::Grease::init(s);
  for (auto c : s) {
    CHECK((c & 0xF) == 0xA);
  }
  for (size_t i = 1; i < s.size(); i += 2) {
    CHECK(s[i] != s[i - 1]);
  }
}

TEST(Mtproto, TlsTransport) {
  int threads_n = 1;
  td::ConcurrentScheduler sched(threads_n, 0);
  {
    auto guard = sched.get_main_guard();
    class RunTest final : public td::Actor {
      void start_up() final {
        class Callback final : public td::TransparentProxy::Callback {
         public:
          void set_result(td::Result<td::BufferedFd<td::SocketFd>> result) final {
            if (result.is_ok()) {
              LOG(ERROR) << "Unexpectedly succeeded to connect to MTProto proxy";
            } else if (result.error().message() != "Response hash mismatch") {
              LOG(ERROR) << "Receive unexpected result " << result.error();
            }
            td::Scheduler::instance()->finish();
          }
          void on_connected() final {
          }
        };

        const td::string domain = "www.google.com";
        td::IPAddress ip_address;
        auto resolve_status = ip_address.init_host_port(domain, 443);
        if (resolve_status.is_error()) {
          LOG(ERROR) << resolve_status;
          td::Scheduler::instance()->finish();
          return;
        }
        auto r_socket = td::SocketFd::open(ip_address);
        if (r_socket.is_error()) {
          LOG(ERROR) << "Failed to open socket: " << r_socket.error();
          td::Scheduler::instance()->finish();
          return;
        }
        td::create_actor<td::mtproto::TlsInit>("TlsInit", r_socket.move_as_ok(), domain, "0123456789secret",
                                               td::make_unique<Callback>(), td::ActorShared<>(),
                                               td::Clocks::system() - td::Time::now())
            .release();
      }
    };
    td::create_actor<RunTest>("RunTest").release();
  }

  sched.start();
  while (sched.run_main(10)) {
    // empty
  }
  sched.finish();
}

TEST(Mtproto, RSA) {
  auto pem = td::Slice(
      "-----BEGIN RSA PUBLIC KEY-----\n"
      "MIIBCgKCAQEAr4v4wxMDXIaMOh8bayF/NyoYdpcysn5EbjTIOZC0RkgzsRj3SGlu\n"
      "52QSz+ysO41dQAjpFLgxPVJoOlxXokaOq827IfW0bGCm0doT5hxtedu9UCQKbE8j\n"
      "lDOk+kWMXHPZFJKWRgKgTu9hcB3y3Vk+JFfLpq3d5ZB48B4bcwrRQnzkx5GhWOFX\n"
      "x73ZgjO93eoQ2b/lDyXxK4B4IS+hZhjzezPZTI5upTRbs5ljlApsddsHrKk6jJNj\n"
      "8Ygs/ps8e6ct82jLXbnndC9s8HjEvDvBPH9IPjv5JUlmHMBFZ5vFQIfbpo0u0+1P\n"
      "n6bkEi5o7/ifoyVv2pAZTRwppTz0EuXD8QIDAQAB\n"
      "-----END RSA PUBLIC KEY-----");
  auto rsa = td::mtproto::RSA::from_pem_public_key(pem).move_as_ok();
  ASSERT_EQ(-7596991558377038078, rsa.get_fingerprint());
  ASSERT_EQ(256u, rsa.size());

  td::string to(256, '\0');
  rsa.encrypt(pem.substr(0, 256), to);
  ASSERT_EQ("U2nJEtB2AgpHrm3HB0yhpTQgb0wbesi9Pv/W1v/vULU=", td::base64_encode(td::sha256(to)));
}
