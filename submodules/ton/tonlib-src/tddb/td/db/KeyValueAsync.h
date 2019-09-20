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

#include "td/actor/actor.h"
#include "td/actor/PromiseFuture.h"

#include "td/db/KeyValue.h"

namespace td {

template <class KeyT, class ValueT>
class KeyValueActor;

template <class KeyT, class ValueT>
class KeyValueAsync {
 public:
  using ActorType = KeyValueActor<KeyT, ValueT>;
  struct GetResult {
    KeyValue::GetStatus status;
    ValueT value;
  };
  KeyValueAsync(std::shared_ptr<KeyValue> key_value);
  void get(KeyT key, Promise<GetResult> promise = {});
  void set(KeyT key, ValueT value, Promise<Unit> promise = {}, double sync_delay = 0);
  void erase(KeyT key, Promise<Unit> promise = {}, double sync_delay = 0);

  KeyValueAsync();
  KeyValueAsync(KeyValueAsync &&);
  KeyValueAsync &operator=(KeyValueAsync &&);
  ~KeyValueAsync();

 private:
  actor::ActorOwn<ActorType> actor_;
};

template <class KeyT, class ValueT>
class KeyValueActor : public actor::Actor {
 public:
  KeyValueActor(std::shared_ptr<KeyValue> key_value) : key_value_(std::move(key_value)) {
  }

  void get(KeyT key, Promise<typename KeyValueAsync<KeyT, ValueT>::GetResult> promise) {
    std::string value;
    auto r_status = key_value_->get(as_slice(key), value);
    if (r_status.is_error()) {
      promise.set_error(r_status.move_as_error());
      return;
    }
    typename KeyValueAsync<KeyT, ValueT>::GetResult result;
    result.status = r_status.move_as_ok();
    if (result.status == KeyValue::GetStatus::Ok) {
      result.value = ValueT(std::move(value));
    }
    promise.set_value(std::move(result));
  }
  void set(KeyT key, ValueT value, Promise<Unit> promise, double sync_delay) {
    schedule_sync(std::move(promise), sync_delay);
    key_value_->set(as_slice(key), as_slice(value));
  }
  void erase(KeyT key, Promise<Unit> promise, double sync_delay) {
    schedule_sync(std::move(promise), sync_delay);
    key_value_->erase(as_slice(key));
  }

 private:
  std::shared_ptr<KeyValue> key_value_;
  std::vector<Promise<Unit>> pending_promises_;
  bool need_sync_ = false;
  bool sync_active_ = false;

  void tear_down() override {
    sync();
  }
  void sync() {
    if (!need_sync_) {
      return;
    }
    need_sync_ = false;
    sync_active_ = false;
    key_value_->commit_transaction();
    for (auto &promise : pending_promises_) {
      promise.set_value(Unit());
    }
    pending_promises_.clear();
  }
  void schedule_sync(Promise<Unit> promise, double sync_delay) {
    if (!need_sync_) {
      key_value_->begin_transaction();
      need_sync_ = true;
    }

    if (!sync_active_) {
      if (sync_delay == 0) {
        send_sync();
      } else {
        alarm_timestamp().relax(Timestamp::in(sync_delay));
      }
    }
    if (promise) {
      pending_promises_.push_back(std::move(promise));
    }
  }
  void alarm() override {
    if (need_sync_ && !sync_active_) {
      send_sync();
    }
  }
  void send_sync() {
    sync_active_ = true;
    alarm_timestamp() = Timestamp::never();
    send_closure(actor_id(this), &KeyValueActor<KeyT, ValueT>::sync);
  }
};

template <class KeyT, class ValueT>
KeyValueAsync<KeyT, ValueT>::KeyValueAsync() = default;
template <class KeyT, class ValueT>
KeyValueAsync<KeyT, ValueT>::KeyValueAsync(KeyValueAsync &&) = default;
template <class KeyT, class ValueT>
KeyValueAsync<KeyT, ValueT> &KeyValueAsync<KeyT, ValueT>::operator=(KeyValueAsync &&) = default;
template <class KeyT, class ValueT>
KeyValueAsync<KeyT, ValueT>::~KeyValueAsync() = default;

template <class KeyT, class ValueT>
KeyValueAsync<KeyT, ValueT>::KeyValueAsync(std::shared_ptr<KeyValue> key_value) {
  actor_ = actor::create_actor<ActorType>("KeyValueActor", std::move(key_value));
}
template <class KeyT, class ValueT>
void KeyValueAsync<KeyT, ValueT>::get(KeyT key, Promise<GetResult> promise) {
  send_closure_later(actor_, &ActorType::get, std::move(key), std::move(promise));
}
template <class KeyT, class ValueT>
void KeyValueAsync<KeyT, ValueT>::set(KeyT key, ValueT value, Promise<Unit> promise, double sync_delay) {
  send_closure_later(actor_, &ActorType::set, std::move(key), std::move(value), std::move(promise), sync_delay);
}
template <class KeyT, class ValueT>
void KeyValueAsync<KeyT, ValueT>::erase(KeyT key, Promise<Unit> promise, double sync_delay) {
  send_closure_later(actor_, &ActorType::erase, std::move(key), std::move(promise), sync_delay);
}

}  // namespace td
