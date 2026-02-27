//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"

#include <type_traits>
#include <utility>

namespace td {

template <class KeyT, class EqT, class Enable = void>
struct SetNode {
  using public_key_type = KeyT;
  using public_type = const KeyT;
  using second_type = KeyT;  // TODO: remove second_type?

  KeyT first;

  const KeyT &key() const {
    return first;
  }

  const KeyT &get_public() {
    return first;
  }

  SetNode() : first() {
  }
  explicit SetNode(KeyT key) : first(std::move(key)) {
  }
  SetNode(const SetNode &) = delete;
  SetNode &operator=(const SetNode &) = delete;
  SetNode(SetNode &&other) noexcept {
    *this = std::move(other);
  }
  void operator=(SetNode &&other) noexcept {
    DCHECK(empty());
    DCHECK(!other.empty());
    first = std::move(other.first);
    other.first = KeyT();
  }
  ~SetNode() = default;

  void copy_from(const SetNode &other) {
    DCHECK(empty());
    first = other.first;
    DCHECK(!empty());
  }

  bool empty() const {
    return is_hash_table_key_empty<EqT>(first);
  }

  void clear() {
    first = KeyT();
    DCHECK(empty());
  }

  void emplace(KeyT key) {
    first = std::move(key);
  }
};

template <class KeyT, class EqT>
struct SetNode<KeyT, EqT, typename std::enable_if_t<(sizeof(KeyT) > 28 * sizeof(void *))>> {
  struct Impl {
    using second_type = KeyT;

    KeyT first;

    template <class InputKeyT>
    explicit Impl(InputKeyT &&key) : first(std::forward<InputKeyT>(key)) {
      DCHECK(!is_hash_table_key_empty<EqT>(first));
    }
    Impl(const Impl &) = delete;
    Impl &operator=(const Impl &) = delete;
    Impl(Impl &&) = delete;
    Impl &operator=(Impl &&) = delete;
  };

  using public_key_type = KeyT;
  using public_type = const KeyT;
  using second_type = KeyT;  // TODO: remove second_type?

  unique_ptr<Impl> impl_;

  const KeyT &key() const {
    DCHECK(!empty());
    return impl_->first;
  }

  const KeyT &get_public() {
    DCHECK(!empty());
    return impl_->first;
  }

  SetNode() : impl_() {
  }
  explicit SetNode(KeyT key) : impl_(td::make_unique<Impl>(std::move(key))) {
  }

  void copy_from(const SetNode &other) {
    DCHECK(empty());
    impl_ = td::make_unique<Impl>(other.impl_->first);
    DCHECK(!empty());
  }

  bool empty() const {
    return impl_ == nullptr;
  }

  void clear() {
    DCHECK(!empty());
    impl_ = nullptr;
  }

  void emplace(KeyT key) {
    DCHECK(empty());
    impl_ = td::make_unique<Impl>(std::move(key));
  }
};

}  // namespace td
