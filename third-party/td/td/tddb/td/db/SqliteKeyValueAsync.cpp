//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/SqliteKeyValueAsync.h"

#include "td/db/SqliteKeyValue.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/optional.h"
#include "td/utils/Time.h"

namespace td {

class SqliteKeyValueAsync final : public SqliteKeyValueAsyncInterface {
 public:
  explicit SqliteKeyValueAsync(std::shared_ptr<SqliteKeyValueSafe> kv_safe, int32 scheduler_id = -1) {
    impl_ = create_actor_on_scheduler<Impl>("KV", scheduler_id, std::move(kv_safe));
  }
  void set(string key, string value, Promise<Unit> promise) final {
    send_closure_later(impl_, &Impl::set, std::move(key), std::move(value), std::move(promise));
  }
  void set_all(FlatHashMap<string, string> key_values, Promise<Unit> promise) final {
    send_closure_later(impl_, &Impl::set_all, std::move(key_values), std::move(promise));
  }
  void erase(string key, Promise<Unit> promise) final {
    send_closure_later(impl_, &Impl::erase, std::move(key), std::move(promise));
  }
  void erase_by_prefix(string key_prefix, Promise<Unit> promise) final {
    send_closure_later(impl_, &Impl::erase_by_prefix, std::move(key_prefix), std::move(promise));
  }
  void get(string key, Promise<string> promise) final {
    send_closure_later(impl_, &Impl::get, std::move(key), std::move(promise));
  }
  void close(Promise<Unit> promise) final {
    send_closure_later(impl_, &Impl::close, std::move(promise));
  }

 private:
  class Impl final : public Actor {
   public:
    explicit Impl(std::shared_ptr<SqliteKeyValueSafe> kv_safe) : kv_safe_(std::move(kv_safe)) {
    }

    void set(string key, string value, Promise<Unit> promise) {
      auto it = buffer_.find(key);
      if (it != buffer_.end()) {
        it->second = std::move(value);
      } else {
        CHECK(!key.empty());
        buffer_.emplace(std::move(key), std::move(value));
      }
      if (promise) {
        buffer_promises_.push_back(std::move(promise));
      }
      cnt_++;
      do_flush(false /*force*/);
    }

    void set_all(FlatHashMap<string, string> key_values, Promise<Unit> promise) {
      do_flush(true /*force*/);
      kv_->set_all(key_values);
      promise.set_value(Unit());
    }

    void erase(string key, Promise<Unit> promise) {
      auto it = buffer_.find(key);
      if (it != buffer_.end()) {
        it->second = optional<string>();
      } else {
        CHECK(!key.empty());
        buffer_.emplace(std::move(key), optional<string>());
      }
      if (promise) {
        buffer_promises_.push_back(std::move(promise));
      }
      cnt_++;
      do_flush(false /*force*/);
    }

    void erase_by_prefix(string key_prefix, Promise<Unit> promise) {
      do_flush(true /*force*/);
      kv_->erase_by_prefix(key_prefix);
      promise.set_value(Unit());
    }

    void get(const string &key, Promise<string> promise) {
      auto it = buffer_.find(key);
      if (it != buffer_.end()) {
        return promise.set_value(it->second ? it->second.value() : "");
      }
      promise.set_value(kv_->get(key));
    }

    void close(Promise<Unit> promise) {
      do_flush(true /*force*/);
      kv_safe_.reset();
      kv_ = nullptr;
      stop();
      promise.set_value(Unit());
    }

   private:
    std::shared_ptr<SqliteKeyValueSafe> kv_safe_;
    SqliteKeyValue *kv_ = nullptr;

    static constexpr double MAX_PENDING_QUERIES_DELAY = 0.01;
    static constexpr size_t MAX_PENDING_QUERIES_COUNT = 100;
    FlatHashMap<string, optional<string>> buffer_;
    vector<Promise<Unit>> buffer_promises_;
    size_t cnt_ = 0;

    double wakeup_at_ = 0;
    void do_flush(bool force) {
      if (buffer_.empty()) {
        return;
      }

      if (!force) {
        auto now = Time::now_cached();
        if (wakeup_at_ == 0) {
          wakeup_at_ = now + MAX_PENDING_QUERIES_DELAY;
        }
        if (now < wakeup_at_ && cnt_ < MAX_PENDING_QUERIES_COUNT) {
          set_timeout_at(wakeup_at_);
          return;
        }
      }

      wakeup_at_ = 0;
      cnt_ = 0;

      kv_->begin_write_transaction().ensure();
      for (auto &it : buffer_) {
        if (it.second) {
          kv_->set(it.first, it.second.value());
        } else {
          kv_->erase(it.first);
        }
      }
      kv_->commit_transaction().ensure();
      buffer_.clear();
      set_promises(buffer_promises_);
    }

    void timeout_expired() final {
      do_flush(false /*force*/);
    }

    void start_up() final {
      kv_ = &kv_safe_->get();
    }
  };
  ActorOwn<Impl> impl_;
};

unique_ptr<SqliteKeyValueAsyncInterface> create_sqlite_key_value_async(std::shared_ptr<SqliteKeyValueSafe> kv,
                                                                       int32 scheduler_id) {
  return td::make_unique<SqliteKeyValueAsync>(std::move(kv), scheduler_id);
}

}  // namespace td
