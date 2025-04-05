//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/HashTableUtils.h"

#include <functional>

namespace td {

template <class KeyT, class ValueT, class HashT = Hash<KeyT>, class EqT = std::equal_to<KeyT>>
class WaitFreeHashMap {
  static constexpr size_t MAX_STORAGE_COUNT = 1 << 8;
  static_assert((MAX_STORAGE_COUNT & (MAX_STORAGE_COUNT - 1)) == 0, "");
  static constexpr uint32 DEFAULT_STORAGE_SIZE = 1 << 12;

  FlatHashMap<KeyT, ValueT, HashT, EqT> default_map_;
  struct WaitFreeStorage {
    WaitFreeHashMap maps_[MAX_STORAGE_COUNT];
  };
  unique_ptr<WaitFreeStorage> wait_free_storage_;
  uint32 hash_mult_ = 1;
  uint32 max_storage_size_ = DEFAULT_STORAGE_SIZE;

  uint32 get_wait_free_index(const KeyT &key) const {
    return randomize_hash(HashT()(key) * hash_mult_) & (MAX_STORAGE_COUNT - 1);
  }

  WaitFreeHashMap &get_wait_free_storage(const KeyT &key) {
    return wait_free_storage_->maps_[get_wait_free_index(key)];
  }

  const WaitFreeHashMap &get_wait_free_storage(const KeyT &key) const {
    return wait_free_storage_->maps_[get_wait_free_index(key)];
  }

  void split_storage() {
    CHECK(wait_free_storage_ == nullptr);
    wait_free_storage_ = make_unique<WaitFreeStorage>();
    uint32 next_hash_mult = hash_mult_ * 1000000007;
    for (uint32 i = 0; i < MAX_STORAGE_COUNT; i++) {
      auto &map = wait_free_storage_->maps_[i];
      map.hash_mult_ = next_hash_mult;
      map.max_storage_size_ = DEFAULT_STORAGE_SIZE + i * next_hash_mult % DEFAULT_STORAGE_SIZE;
    }
    for (auto &it : default_map_) {
      get_wait_free_storage(it.first).set(it.first, std::move(it.second));
    }
    default_map_.clear();
  }

 public:
  void set(const KeyT &key, ValueT value) {
    if (wait_free_storage_ != nullptr) {
      return get_wait_free_storage(key).set(key, std::move(value));
    }

    default_map_[key] = std::move(value);
    if (default_map_.size() == max_storage_size_) {
      split_storage();
    }
  }

  ValueT get(const KeyT &key) const {
    if (wait_free_storage_ != nullptr) {
      return get_wait_free_storage(key).get(key);
    }

    auto it = default_map_.find(key);
    if (it == default_map_.end()) {
      return {};
    }
    return it->second;
  }

  size_t count(const KeyT &key) const {
    if (wait_free_storage_ != nullptr) {
      return get_wait_free_storage(key).count(key);
    }

    return default_map_.count(key);
  }

  // specialization for WaitFreeHashMap<..., unique_ptr<T>>
  template <class T = ValueT>
  typename T::element_type *get_pointer(const KeyT &key) {
    if (wait_free_storage_ != nullptr) {
      return get_wait_free_storage(key).get_pointer(key);
    }

    auto it = default_map_.find(key);
    if (it == default_map_.end()) {
      return nullptr;
    }
    return it->second.get();
  }

  template <class T = ValueT>
  const typename T::element_type *get_pointer(const KeyT &key) const {
    if (wait_free_storage_ != nullptr) {
      return get_wait_free_storage(key).get_pointer(key);
    }

    auto it = default_map_.find(key);
    if (it == default_map_.end()) {
      return nullptr;
    }
    return it->second.get();
  }

  ValueT &operator[](const KeyT &key) {
    if (wait_free_storage_ == nullptr) {
      ValueT &result = default_map_[key];
      if (default_map_.size() != max_storage_size_) {
        return result;
      }

      split_storage();
    }

    return get_wait_free_storage(key)[key];
  }

  size_t erase(const KeyT &key) {
    if (wait_free_storage_ != nullptr) {
      return get_wait_free_storage(key).erase(key);
    }

    return default_map_.erase(key);
  }

  void foreach(const std::function<void(const KeyT &key, ValueT &value)> &callback) {
    if (wait_free_storage_ == nullptr) {
      for (auto &it : default_map_) {
        callback(it.first, it.second);
      }
      return;
    }

    for (auto &it : wait_free_storage_->maps_) {
      it.foreach(callback);
    }
  }

  void foreach(const std::function<void(const KeyT &key, const ValueT &value)> &callback) const {
    if (wait_free_storage_ == nullptr) {
      for (auto &it : default_map_) {
        callback(it.first, it.second);
      }
      return;
    }

    for (auto &it : wait_free_storage_->maps_) {
      it.foreach(callback);
    }
  }

  size_t calc_size() const {
    if (wait_free_storage_ == nullptr) {
      return default_map_.size();
    }

    size_t result = 0;
    for (size_t i = 0; i < MAX_STORAGE_COUNT; i++) {
      result += wait_free_storage_->maps_[i].calc_size();
    }
    return result;
  }

  bool empty() const {
    if (wait_free_storage_ == nullptr) {
      return default_map_.empty();
    }

    for (size_t i = 0; i < MAX_STORAGE_COUNT; i++) {
      if (!wait_free_storage_->maps_[i].empty()) {
        return false;
      }
    }
    return true;
  }
};

}  // namespace td
