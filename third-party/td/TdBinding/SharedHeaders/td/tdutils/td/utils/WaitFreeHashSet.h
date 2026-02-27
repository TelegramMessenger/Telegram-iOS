//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/HashTableUtils.h"

#include <functional>

namespace td {

template <class KeyT, class HashT = Hash<KeyT>, class EqT = std::equal_to<KeyT>>
class WaitFreeHashSet {
  static constexpr size_t MAX_STORAGE_COUNT = 1 << 8;
  static_assert((MAX_STORAGE_COUNT & (MAX_STORAGE_COUNT - 1)) == 0, "");
  static constexpr uint32 DEFAULT_STORAGE_SIZE = 1 << 12;

  FlatHashSet<KeyT, HashT, EqT> default_set_;
  struct WaitFreeStorage {
    WaitFreeHashSet sets_[MAX_STORAGE_COUNT];
  };
  unique_ptr<WaitFreeStorage> wait_free_storage_;
  uint32 hash_mult_ = 1;
  uint32 max_storage_size_ = DEFAULT_STORAGE_SIZE;

  uint32 get_wait_free_index(const KeyT &key) const {
    return randomize_hash(HashT()(key) * hash_mult_) & (MAX_STORAGE_COUNT - 1);
  }

  WaitFreeHashSet &get_wait_free_storage(const KeyT &key) {
    return wait_free_storage_->sets_[get_wait_free_index(key)];
  }

  const WaitFreeHashSet &get_wait_free_storage(const KeyT &key) const {
    return wait_free_storage_->sets_[get_wait_free_index(key)];
  }

  void split_storage() {
    CHECK(wait_free_storage_ == nullptr);
    wait_free_storage_ = make_unique<WaitFreeStorage>();
    uint32 next_hash_mult = hash_mult_ * 1000000007;
    for (uint32 i = 0; i < MAX_STORAGE_COUNT; i++) {
      auto &set = wait_free_storage_->sets_[i];
      set.hash_mult_ = next_hash_mult;
      set.max_storage_size_ = DEFAULT_STORAGE_SIZE + i * next_hash_mult % DEFAULT_STORAGE_SIZE;
    }
    for (auto &it : default_set_) {
      get_wait_free_storage(it).insert(it);
    }
    default_set_.clear();
  }

 public:
  bool insert(const KeyT &key) {
    if (wait_free_storage_ != nullptr) {
      return get_wait_free_storage(key).insert(key);
    }

    auto result = default_set_.insert(key).second;
    if (default_set_.size() == max_storage_size_) {
      split_storage();
    }
    return result;
  }

  size_t count(const KeyT &key) const {
    if (wait_free_storage_ != nullptr) {
      return get_wait_free_storage(key).count(key);
    }

    return default_set_.count(key);
  }

  size_t erase(const KeyT &key) {
    if (wait_free_storage_ != nullptr) {
      return get_wait_free_storage(key).erase(key);
    }

    return default_set_.erase(key);
  }

  void foreach(const std::function<void(const KeyT &key)> &callback) const {
    if (wait_free_storage_ == nullptr) {
      for (auto &it : default_set_) {
        callback(it);
      }
      return;
    }

    for (auto &it : wait_free_storage_->sets_) {
      it.foreach(callback);
    }
  }

  KeyT get_random() const {
    if (wait_free_storage_ != nullptr) {
      for (size_t i = 0; i < MAX_STORAGE_COUNT; i++) {
        if (!wait_free_storage_->sets_[i].empty()) {
          return wait_free_storage_->sets_[i].get_random();
        }
      }
      // no need to explicitly return KeyT()
    }

    if (default_set_.empty()) {
      return KeyT();
    }
    return *default_set_.begin();
  }

  size_t calc_size() const {
    if (wait_free_storage_ == nullptr) {
      return default_set_.size();
    }

    size_t result = 0;
    for (size_t i = 0; i < MAX_STORAGE_COUNT; i++) {
      result += wait_free_storage_->sets_[i].calc_size();
    }
    return result;
  }

  bool empty() const {
    if (wait_free_storage_ == nullptr) {
      return default_set_.empty();
    }

    for (size_t i = 0; i < MAX_STORAGE_COUNT; i++) {
      if (!wait_free_storage_->sets_[i].empty()) {
        return false;
      }
    }
    return true;
  }
};

}  // namespace td
