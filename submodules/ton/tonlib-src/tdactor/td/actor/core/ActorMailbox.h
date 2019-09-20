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

#include "td/actor/core/ActorMessage.h"
#include "td/utils/MpscLinkQueue.h"

namespace td {
namespace actor {
namespace core {
class ActorMailbox {
 public:
  ActorMailbox() = default;
  ActorMailbox(const ActorMailbox &) = delete;
  ActorMailbox &operator=(const ActorMailbox &) = delete;
  ActorMailbox(ActorMailbox &&other) = delete;
  ActorMailbox &operator=(ActorMailbox &&other) = delete;
  ~ActorMailbox() {
    clear();
  }
  void push(ActorMessage message) {
    queue_.push(std::move(message));
  }
  void push_unsafe(ActorMessage message) {
    queue_.push_unsafe(std::move(message));
  }

  td::MpscLinkQueue<ActorMessage>::Reader &reader() {
    return reader_;
  }

  void pop_all() {
    queue_.pop_all(reader_);
  }
  void pop_all_unsafe() {
    queue_.pop_all_unsafe(reader_);
  }

  void clear() {
    pop_all();
    while (reader_.read()) {
      // skip
    }
  }

 private:
  td::MpscLinkQueue<ActorMessage> queue_;
  td::MpscLinkQueue<ActorMessage>::Reader reader_;
};
}  // namespace core
}  // namespace actor
}  // namespace td
