//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ConnectionState.h"
#include "td/telegram/net/NetType.h"

#include "td/mtproto/ConnectionManager.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class StateManager final : public mtproto::ConnectionManager {
 public:
  class Callback {
   public:
    Callback() = default;
    Callback(const Callback &) = delete;
    Callback &operator=(const Callback &) = delete;
    virtual ~Callback() = default;
    virtual bool on_state(ConnectionState state) {
      return true;
    }
    virtual bool on_network(NetType network_type, uint32 generation) {
      return true;
    }
    virtual bool on_online(bool is_online) {
      return true;
    }
    virtual bool on_logging_out(bool is_logging_out) {
      return true;
    }
  };

  explicit StateManager(ActorShared<> parent) : parent_(std::move(parent)) {
  }

  void on_synchronized(bool is_synchronized);

  void on_network_updated();

  void on_network(NetType new_network_type);

  void on_online(bool is_online);

  void on_proxy(bool use_proxy);

  void on_logging_out(bool is_logging_out);

  void add_callback(unique_ptr<Callback> net_callback);

  void wait_first_sync(Promise<> promise);

  void close();

 private:
  ActorShared<> parent_;
  bool sync_flag_ = true;
  bool network_flag_ = true;
  NetType network_type_ = NetType::Unknown;
  uint32 network_generation_ = 1;
  bool online_flag_ = false;
  bool use_proxy_ = false;
  bool is_logging_out_ = false;

  static constexpr double UP_DELAY = 0.05;
  static constexpr double DOWN_DELAY = 0.3;

  ConnectionState pending_state_ = ConnectionState::Empty;
  bool has_timestamp_ = false;
  double pending_timestamp_ = 0;
  ConnectionState flush_state_ = ConnectionState::Empty;

  vector<unique_ptr<Callback>> callbacks_;

  bool was_sync_ = false;
  vector<Promise<>> wait_first_sync_;

  void inc_connect();
  void dec_connect();

  enum class Flag : int32 { Online, State, Network, LoggingOut };
  void notify_flag(Flag flag);

  void start_up() final;
  void loop() final;

  void on_network_soft();
  void do_on_network(NetType new_network_type, bool inc_generation);

  ConnectionState get_real_state() const;
};

}  // namespace td
