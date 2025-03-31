//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"

#include <new>
#include <type_traits>
#include <utility>

namespace td {

template <class KeyT, class ValueT, class EqT, class Enable = void>
struct MapNode {
  using first_type = KeyT;
  using second_type = ValueT;
  using public_key_type = KeyT;
  using public_type = MapNode;

  KeyT first{};
  union {
    ValueT second;
  };

  const KeyT &key() const {
    return first;
  }

  MapNode &get_public() {
    return *this;
  }

  const MapNode &get_public() const {
    return *this;
  }

  MapNode() {
  }
  MapNode(KeyT key, ValueT value) : first(std::move(key)) {
    new (&second) ValueT(std::move(value));
    DCHECK(!empty());
  }
  MapNode(const MapNode &) = delete;
  MapNode &operator=(const MapNode &) = delete;
  MapNode(MapNode &&other) noexcept {
    *this = std::move(other);
  }
  void operator=(MapNode &&other) noexcept {
    DCHECK(empty());
    DCHECK(!other.empty());
    first = std::move(other.first);
    other.first = KeyT();
    new (&second) ValueT(std::move(other.second));
    other.second.~ValueT();
  }
  ~MapNode() {
    if (!empty()) {
      second.~ValueT();
    }
  }

  void copy_from(const MapNode &other) {
    DCHECK(empty());
    DCHECK(!other.empty());
    first = other.first;
    new (&second) ValueT(other.second);
  }

  bool empty() const {
    return is_hash_table_key_empty<EqT>(first);
  }

  void clear() {
    DCHECK(!empty());
    first = KeyT();
    second.~ValueT();
    DCHECK(empty());
  }

  template <class... ArgsT>
  void emplace(KeyT key, ArgsT &&...args) {
    DCHECK(empty());
    first = std::move(key);
    new (&second) ValueT(std::forward<ArgsT>(args)...);
    DCHECK(!empty());
  }
};

template <class KeyT, class ValueT, class EqT>
struct MapNode<KeyT, ValueT, EqT, typename std::enable_if_t<(sizeof(KeyT) + sizeof(ValueT) > 28 * sizeof(void *))>> {
  struct Impl {
    using first_type = KeyT;
    using second_type = ValueT;

    KeyT first{};
    union {
      ValueT second;
    };

    template <class InputKeyT, class... ArgsT>
    Impl(InputKeyT &&key, ArgsT &&...args) : first(std::forward<InputKeyT>(key)) {
      new (&second) ValueT(std::forward<ArgsT>(args)...);
      DCHECK(!is_hash_table_key_empty<EqT>(first));
    }
    Impl(const Impl &) = delete;
    Impl &operator=(const Impl &) = delete;
    Impl(Impl &&) = delete;
    Impl &operator=(Impl &&) = delete;
    ~Impl() {
      second.~ValueT();
    }
  };

  using first_type = KeyT;
  using second_type = ValueT;
  using public_key_type = KeyT;
  using public_type = Impl;

  unique_ptr<Impl> impl_;

  const KeyT &key() const {
    DCHECK(!empty());
    return impl_->first;
  }

  Impl &get_public() {
    return *impl_;
  }

  const Impl &get_public() const {
    return *impl_;
  }

  MapNode() {
  }
  MapNode(KeyT key, ValueT value) : impl_(td::make_unique<Impl>(std::move(key), std::move(value))) {
  }

  void copy_from(const MapNode &other) {
    DCHECK(empty());
    DCHECK(!other.empty());
    impl_ = td::make_unique<Impl>(other.impl_->first, other.impl_->second);
  }

  bool empty() const {
    return impl_ == nullptr;
  }

  void clear() {
    DCHECK(!empty());
    impl_ = nullptr;
  }

  template <class... ArgsT>
  void emplace(KeyT key, ArgsT &&...args) {
    DCHECK(empty());
    impl_ = td::make_unique<Impl>(std::move(key), std::forward<ArgsT>(args)...);
  }
};

}  // namespace td
