/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "td/actor/core/ActorExecuteContext.h"

#include "td/utils/MpscLinkQueue.h"

namespace td {
namespace actor {
namespace core {
class ActorMessageImpl : private MpscLinkQueueImpl::Node {
 public:
  ActorMessageImpl() = default;
  ActorMessageImpl(const ActorMessageImpl &) = delete;
  ActorMessageImpl &operator=(const ActorMessageImpl &) = delete;
  ActorMessageImpl(ActorMessageImpl &&other) = delete;
  ActorMessageImpl &operator=(ActorMessageImpl &&other) = delete;

  virtual ~ActorMessageImpl() = default;
  virtual void run() = 0;

 private:
  friend class ActorMessage;

  // ActorMessage <--> MpscLintQueue::Node
  // Each actor's mailbox will be a queue
  static ActorMessageImpl *from_mpsc_link_queue_node(MpscLinkQueueImpl::Node *node) {
    return static_cast<ActorMessageImpl *>(node);
  }
  MpscLinkQueueImpl::Node *to_mpsc_link_queue_node() {
    return static_cast<MpscLinkQueueImpl::Node *>(this);
  }

  uint64 link_token_{EmptyLinkToken};
  bool is_big_{false};
};

class ActorMessage {
 public:
  ActorMessage() = default;
  explicit ActorMessage(std::unique_ptr<ActorMessageImpl> impl) : impl_(std::move(impl)) {
  }
  void run() {
    CHECK(impl_);
    impl_->run();
  }
  explicit operator bool() {
    return bool(impl_);
  }
  friend class ActorMailbox;

  void set_link_token(uint64 link_token) {
    impl_->link_token_ = link_token;
  }
  uint64 get_link_token() const {
    return impl_->link_token_;
  }
  bool is_big() const {
    return impl_->is_big_;
  }
  void set_big() {
    impl_->is_big_ = true;
  }

 private:
  std::unique_ptr<ActorMessageImpl> impl_;

  template <class T>
  friend class td::MpscLinkQueue;

  static ActorMessage from_mpsc_link_queue_node(MpscLinkQueueImpl::Node *node) {
    return ActorMessage(std::unique_ptr<ActorMessageImpl>(ActorMessageImpl::from_mpsc_link_queue_node(node)));
  }
  MpscLinkQueueImpl::Node *to_mpsc_link_queue_node() {
    return impl_.release()->to_mpsc_link_queue_node();
  }
};
}  // namespace core
}  // namespace actor
}  // namespace td
