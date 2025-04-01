//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/HazardPointers.h"
#include "td/utils/logging.h"
#include "td/utils/port/thread_local.h"

#include <atomic>
#include <condition_variable>
#include <mutex>

namespace td {

// AtomicHashArray<KeyT, ValueT>
// Building block for other concurrent hash maps
//
// Support one operation:
//  template <class F>
//  bool with_value(KeyT key, bool should_create, F &&func);
//
//  Finds slot for key, and call func(value)
//  Creates slot if should_create is true.
//  Returns true if func was called.
//
//  Concurrent calls with the same key may result in concurrent calls to func(value)
//  It is responsibility of the caller to handle such races.
//
//  Key should already be random
//  It is responsibility of the caller to provide unique random key.
//  One may use injective hash function, or handle collisions in some other way.

template <class KeyT, class ValueT>
class AtomicHashArray {
 public:
  explicit AtomicHashArray(size_t n) : nodes_(n) {
  }
  struct Node {
    std::atomic<KeyT> key{KeyT{}};
    ValueT value{};
  };
  size_t size() const {
    return nodes_.size();
  }
  Node &node_at(size_t i) {
    return nodes_[i];
  }
  static KeyT empty_key() {
    return KeyT{};
  }

  template <class F>
  bool with_value(KeyT key, bool should_create, F &&f) {
    DCHECK(key != empty_key());
    auto pos = static_cast<size_t>(key) % nodes_.size();
    auto n = td::min(td::max(static_cast<size_t>(300), nodes_.size() / 16 + 2), nodes_.size());

    for (size_t i = 0; i < n; i++) {
      pos++;
      if (pos >= nodes_.size()) {
        pos = 0;
      }
      auto &node = nodes_[pos];
      while (true) {
        auto node_key = node.key.load(std::memory_order_acquire);
        if (node_key == empty_key()) {
          if (!should_create) {
            return false;
          }
          KeyT expected_key = empty_key();
          if (node.key.compare_exchange_strong(expected_key, key, std::memory_order_relaxed,
                                               std::memory_order_relaxed)) {
            f(node.value);
            return true;
          }
        } else if (node_key == key) {
          f(node.value);
          return true;
        } else {
          break;
        }
      }
    }
    return false;
  }

 private:
  std::vector<Node> nodes_;
};

// Simple concurrent hash map with multiple limitations
template <class KeyT, class ValueT>
class ConcurrentHashMap {
  using HashMap = AtomicHashArray<KeyT, std::atomic<ValueT>>;
  static HazardPointers<HashMap> hp_;

 public:
  explicit ConcurrentHashMap(size_t n = 32) {
    n = 1;
    hash_map_.store(make_unique<HashMap>(n).release());
  }
  ConcurrentHashMap(const ConcurrentHashMap &) = delete;
  ConcurrentHashMap &operator=(const ConcurrentHashMap &) = delete;
  ConcurrentHashMap(ConcurrentHashMap &&) = delete;
  ConcurrentHashMap &operator=(ConcurrentHashMap &&) = delete;
  ~ConcurrentHashMap() {
    unique_ptr<HashMap>(hash_map_.load()).reset();
  }

  static std::string get_name() {
    return "ConcurrentHashMap";
  }

  static KeyT empty_key() {
    return KeyT{};
  }
  static ValueT empty_value() {
    return ValueT{};
  }
  static ValueT migrate_value() {
    return (ValueT)(1);  // c-style conversion because reinterpret_cast<int>(1) is CE in MSVC
  }

  ValueT insert(KeyT key, ValueT value) {
    CHECK(key != empty_key());
    CHECK(value != migrate_value());
    typename HazardPointers<HashMap>::Holder holder(hp_, get_thread_id(), 0);
    while (true) {
      auto hash_map = holder.protect(hash_map_);
      if (!hash_map) {
        do_migrate(nullptr);
        continue;
      }

      bool ok = false;
      ValueT inserted_value;
      hash_map->with_value(key, true, [&](auto &node_value) {
        ValueT expected_value = this->empty_value();
        if (node_value.compare_exchange_strong(expected_value, value, std::memory_order_release,
                                               std::memory_order_acquire)) {
          ok = true;
          inserted_value = value;
        } else {
          if (expected_value == this->migrate_value()) {
            ok = false;
          } else {
            ok = true;
            inserted_value = expected_value;
          }
        }
      });
      if (ok) {
        return inserted_value;
      }
      do_migrate(hash_map);
    }
  }

  ValueT find(KeyT key, ValueT value) {
    typename HazardPointers<HashMap>::Holder holder(hp_, get_thread_id(), 0);
    while (true) {
      auto hash_map = holder.protect(hash_map_);
      if (!hash_map) {
        do_migrate(nullptr);
        continue;
      }

      bool has_value = hash_map->with_value(
          key, false, [&](auto &node_value) { value = node_value.load(std::memory_order_acquire); });
      if (!has_value || value != migrate_value()) {
        return value;
      }
      do_migrate(hash_map);
    }
  }

  template <class F>
  void for_each(F &&f) {
    auto hash_map = hash_map_.load();
    CHECK(hash_map);
    auto size = hash_map->size();
    for (size_t i = 0; i < size; i++) {
      auto &node = hash_map->node_at(i);
      auto key = node.key.load(std::memory_order_relaxed);
      auto value = node.value.load(std::memory_order_relaxed);

      if (key != empty_key()) {
        CHECK(value != migrate_value());
        if (value != empty_value()) {
          f(key, value);
        }
      }
    }
  }

 private:
  // use no padding intentionally
  std::atomic<HashMap *> hash_map_{nullptr};

  std::mutex migrate_mutex_;
  std::condition_variable migrate_cv_;

  int migrate_cnt_{0};
  int migrate_generation_{0};
  HashMap *migrate_from_hash_map_{nullptr};
  HashMap *migrate_to_hash_map_{nullptr};
  struct Task {
    size_t begin;
    size_t end;
    bool empty() const {
      return begin >= end;
    }
    size_t size() const {
      if (empty()) {
        return 0;
      }
      return end - begin;
    }
  };

  struct TaskCreator {
    size_t chunk_size;
    size_t size;
    std::atomic<size_t> pos{0};
    Task create() {
      auto i = pos++;
      auto begin = i * chunk_size;
      auto end = begin + chunk_size;
      if (end > size) {
        end = size;
      }
      return {begin, end};
    }
  };
  TaskCreator task_creator;

  void do_migrate(HashMap *ptr) {
    //LOG(ERROR) << "In do_migrate: " << ptr;
    std::unique_lock<std::mutex> lock(migrate_mutex_);
    if (hash_map_.load() != ptr) {
      return;
    }
    init_migrate();
    CHECK(!ptr || migrate_from_hash_map_ == ptr);
    migrate_cnt_++;
    auto migrate_generation = migrate_generation_;
    lock.unlock();

    run_migrate();

    lock.lock();
    migrate_cnt_--;
    if (migrate_cnt_ == 0) {
      finish_migrate();
    }
    migrate_cv_.wait(lock, [&] { return migrate_generation_ != migrate_generation; });
  }

  void finish_migrate() {
    //LOG(ERROR) << "In finish_migrate";
    hash_map_.store(migrate_to_hash_map_);
    hp_.retire(get_thread_id(), migrate_from_hash_map_);
    migrate_from_hash_map_ = nullptr;
    migrate_to_hash_map_ = nullptr;
    migrate_generation_++;
    migrate_cv_.notify_all();
  }

  void init_migrate() {
    if (migrate_from_hash_map_ != nullptr) {
      return;
    }
    //LOG(ERROR) << "In init_migrate";
    CHECK(migrate_cnt_ == 0);
    migrate_generation_++;
    migrate_from_hash_map_ = hash_map_.exchange(nullptr);
    auto new_size = migrate_from_hash_map_->size() * 2;
    migrate_to_hash_map_ = make_unique<HashMap>(new_size).release();
    task_creator.chunk_size = 100;
    task_creator.size = migrate_from_hash_map_->size();
    task_creator.pos = 0;
  }

  void run_migrate() {
    //LOG(ERROR) << "In run_migrate";
    size_t cnt = 0;
    while (true) {
      auto task = task_creator.create();
      cnt += task.size();
      if (task.empty()) {
        break;
      }
      run_task(task);
    }
    //LOG(ERROR) << "In run_migrate " << cnt;
  }

  void run_task(Task task) {
    for (auto i = task.begin; i < task.end; i++) {
      auto &node = migrate_from_hash_map_->node_at(i);
      auto old_value = node.value.exchange(migrate_value(), std::memory_order_acq_rel);
      if (old_value == 0) {
        continue;
      }
      auto node_key = node.key.load(std::memory_order_relaxed);
      auto ok = migrate_to_hash_map_->with_value(
          node_key, true, [&](auto &node_value) { node_value.store(old_value, std::memory_order_relaxed); });
      LOG_CHECK(ok) << "Migration overflow";
    }
  }
};

template <class KeyT, class ValueT>
HazardPointers<typename ConcurrentHashMap<KeyT, ValueT>::HashMap> ConcurrentHashMap<KeyT, ValueT>::hp_(64);

}  // namespace td
