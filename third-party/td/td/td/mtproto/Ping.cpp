//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/Ping.h"

#include "td/mtproto/AuthData.h"
#include "td/mtproto/PingConnection.h"
#include "td/mtproto/RawConnection.h"

#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

namespace td {
namespace mtproto {

ActorOwn<> create_ping_actor(Slice actor_name, unique_ptr<RawConnection> raw_connection, unique_ptr<AuthData> auth_data,
                             Promise<unique_ptr<RawConnection>> promise, ActorShared<> parent) {
  class PingActor final : public Actor {
   public:
    PingActor(unique_ptr<RawConnection> raw_connection, unique_ptr<AuthData> auth_data,
              Promise<unique_ptr<RawConnection>> promise, ActorShared<> parent)
        : promise_(std::move(promise)), parent_(std::move(parent)) {
      if (auth_data) {
        ping_connection_ = PingConnection::create_ping_pong(std::move(raw_connection), std::move(auth_data));
      } else {
        ping_connection_ = PingConnection::create_req_pq(std::move(raw_connection), 2);
      }
    }

   private:
    unique_ptr<PingConnection> ping_connection_;
    Promise<unique_ptr<RawConnection>> promise_;
    ActorShared<> parent_;

    void start_up() final {
      Scheduler::subscribe(ping_connection_->get_poll_info().extract_pollable_fd(this));
      set_timeout_in(10);
      yield();
    }

    void hangup() final {
      finish(Status::Error("Canceled"));
      stop();
    }

    void tear_down() final {
      finish(Status::OK());
    }

    void loop() final {
      auto status = ping_connection_->flush();
      if (status.is_error()) {
        finish(std::move(status));
        return stop();
      }
      if (ping_connection_->was_pong()) {
        finish(Status::OK());
        return stop();
      }
    }

    void timeout_expired() final {
      finish(Status::Error("Pong timeout expired"));
      stop();
    }

    void finish(Status status) {
      auto raw_connection = ping_connection_->move_as_raw_connection();
      if (!raw_connection) {
        CHECK(!promise_);
        return;
      }
      Scheduler::unsubscribe(raw_connection->get_poll_info().get_pollable_fd_ref());
      if (promise_) {
        if (status.is_error()) {
          if (raw_connection->stats_callback()) {
            raw_connection->stats_callback()->on_error();
          }
          raw_connection->close();
          promise_.set_error(std::move(status));
        } else {
          raw_connection->extra().rtt = ping_connection_->rtt();
          if (raw_connection->stats_callback()) {
            raw_connection->stats_callback()->on_pong();
          }
          promise_.set_value(std::move(raw_connection));
        }
      } else {
        if (raw_connection->stats_callback()) {
          raw_connection->stats_callback()->on_error();
        }
        raw_connection->close();
      }
    }
  };
  return ActorOwn<>(create_actor<PingActor>(PSLICE() << "PingActor<" << actor_name << ">", std::move(raw_connection),
                                            std::move(auth_data), std::move(promise), std::move(parent)));
}

}  // namespace mtproto
}  // namespace td
