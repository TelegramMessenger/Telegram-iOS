//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"

#include "td/utils/common.h"

namespace td {
namespace mtproto {

class ConnectionManager : public Actor {
 public:
  class ConnectionToken {
   public:
    ConnectionToken() = default;
    explicit ConnectionToken(ActorShared<ConnectionManager> connection_manager)
        : connection_manager_(std::move(connection_manager)) {
    }
    ConnectionToken(const ConnectionToken &) = delete;
    ConnectionToken &operator=(const ConnectionToken &) = delete;
    ConnectionToken(ConnectionToken &&) = default;
    ConnectionToken &operator=(ConnectionToken &&other) noexcept {
      reset();
      connection_manager_ = std::move(other.connection_manager_);
      return *this;
    }
    ~ConnectionToken() {
      reset();
    }

    void reset() {
      if (!connection_manager_.empty()) {
        send_closure(connection_manager_, &ConnectionManager::dec_connect);
        connection_manager_.reset();
      }
    }

    bool empty() const {
      return connection_manager_.empty();
    }

   private:
    ActorShared<ConnectionManager> connection_manager_;
  };

  static ConnectionToken connection(ActorId<ConnectionManager> connection_manager) {
    return connection_impl(connection_manager, 1);
  }
  static ConnectionToken connection_proxy(ActorId<ConnectionManager> connection_manager) {
    return connection_impl(connection_manager, 2);
  }

 protected:
  uint32 connect_cnt_ = 0;
  uint32 connect_proxy_cnt_ = 0;

 private:
  void inc_connect();
  void dec_connect();

  static ConnectionToken connection_impl(ActorId<ConnectionManager> connection_manager, int mode);
};

}  // namespace mtproto
}  // namespace td
