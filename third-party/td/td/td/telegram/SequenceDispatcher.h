//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/NetQuery.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"

#include <limits>

namespace td {

class SequenceDispatcher final : public NetQueryCallback {
 public:
  class Parent : public Actor {
   public:
    virtual void ready_to_close() = 0;
    virtual void on_result() = 0;
  };
  SequenceDispatcher() = default;
  explicit SequenceDispatcher(ActorShared<Parent> parent) : parent_(std::move(parent)) {
  }
  void send_with_callback(NetQueryPtr query, ActorShared<NetQueryCallback> callback);
  void on_result(NetQueryPtr query) final;
  void close_silent();

 private:
  enum class State : int32 { Start, Wait, Finish, Dummy };
  struct Data {
    State state_;
    NetQueryRef net_query_ref_;
    NetQueryPtr query_;
    ActorShared<NetQueryCallback> callback_;
    uint64 generation_;
    int32 total_timeout_;
    int32 last_timeout_;
  };

  ActorShared<Parent> parent_;
  size_t id_offset_ = 1;
  vector<Data> data_;
  size_t finish_i_ = 0;  // skip state_ == State::Finish
  size_t next_i_ = 0;
  size_t last_sent_i_ = std::numeric_limits<size_t>::max();
  uint64 generation_ = 1;
  uint32 session_rand_ = Random::secure_int32();

  static constexpr int32 MAX_SIMULTANEOUS_WAIT = 10;
  uint32 wait_cnt_ = 0;

  void check_timeout(Data &data);

  void try_resend_query(Data &data, NetQueryPtr query);
  Data &data_from_token();
  void on_resend_ok(NetQueryPtr query);
  void on_resend_error();
  void do_resend(Data &data);
  void do_finish(Data &data);

  void loop() final;
  void try_shrink();

  void timeout_expired() final;
  void hangup() final;
  void tear_down() final;
};

class MultiSequenceDispatcherOld final : public SequenceDispatcher::Parent {
 public:
  void send(NetQueryPtr query);
  static ActorOwn<MultiSequenceDispatcherOld> create(Slice name) {
    return create_actor<MultiSequenceDispatcherOld>(name);
  }

 private:
  struct Data {
    int32 cnt_;
    ActorOwn<SequenceDispatcher> dispatcher_;
  };
  FlatHashMap<uint64, Data> dispatchers_;
  void on_result() final;
  void ready_to_close() final;
};

class MultiSequenceDispatcher : public NetQueryCallback {
 public:
  virtual void send(NetQueryPtr query) = 0;
  static ActorOwn<MultiSequenceDispatcher> create(Slice name);
};

}  // namespace td
