//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/e2e_errors.h"
#include "td/e2e/utils.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#ifndef ENGINE
#include "td/utils/SliceBuilder.h"
#endif
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

#include <atomic>
#include <memory>
#include <mutex>
#include <optional>
#include <tuple>
#include <type_traits>
#include <utility>

namespace tde2e_core {

template <typename T, bool IsMutable, bool HasHash>
struct TypeInfo {
  using type = T;
  static constexpr bool is_mutable = IsMutable;
  static constexpr bool has_hash = HasHash;
};

template <typename T, typename...>
struct TypeIndex;
template <typename T, typename First, typename... Rest>
struct TypeIndex<T, First, Rest...> {
  static constexpr size_t value = std::is_same<T, typename First::type>::value ? 0 : 1 + TypeIndex<T, Rest...>::value;
};
template <typename T>
struct TypeIndex<T> {
  static constexpr size_t value = 0;
};
template <typename T, typename...>
struct TypeInfoFor;
template <typename T, typename First, typename... Rest>
struct TypeInfoFor<T, First, Rest...> {
  using type =
      std::conditional_t<std::is_same<T, typename First::type>::value, First, typename TypeInfoFor<T, Rest...>::type>;
};
template <typename T>
struct TypeInfoFor<T> {
  using type = void;
};

template <typename T>
struct MutableValue {
  MutableValue(T value) : value(std::move(value)) {
  }
  T value;
  mutable std::mutex mutex;
};

struct MutexUnlockDeleter {
  std::shared_ptr<void> value_ptr;
  std::unique_lock<std::mutex> lock;

  MutexUnlockDeleter(MutexUnlockDeleter &&other) : value_ptr(std::move(other.value_ptr)), lock(std::move(other.lock)) {
  }
  template <typename T>
  MutexUnlockDeleter(std::shared_ptr<MutableValue<T>> ptr, std::unique_lock<std::mutex> &&l)
      : value_ptr(std::move(ptr)), lock(std::move(l)) {
  }

  template <typename T>
  void operator()(T * /*unused*/) {
  }
};

template <typename TypeInfo>
struct TypeStorage {
  using T = typename TypeInfo::type;
  using ValueType = std::conditional_t<TypeInfo::is_mutable, MutableValue<T>, T>;
  using ValueRef = std::shared_ptr<ValueType>;

  struct Entry {
    Entry(std::optional<td::UInt256> o_hash, ValueRef value) : o_hash(std::move(o_hash)), value(std::move(value)) {
    }
    std::optional<td::UInt256> o_hash;
    ValueRef value;
  };

  td::FlatHashMap<td::int64, Entry> values;
  td::FlatHashMap<td::UInt256, td::int64, UInt256Hash> hash_to_id;
  mutable std::mutex map_mutex;
};

template <typename T>
using SharedRef = std::shared_ptr<const T>;
template <typename T>
using UniqueRef = std::unique_ptr<T, MutexUnlockDeleter>;

template <typename... TypeInfos>
class Container {
  using StoragesTuple = std::tuple<TypeStorage<TypeInfos>...>;
  StoragesTuple storages_;
  std::atomic<td::int64> next_id{1};

  template <typename T>
  auto &get_storage() {
    constexpr size_t index = TypeIndex<T, TypeInfos...>::value;
    return std::get<index>(storages_);
  }

  template <typename T>
  const auto &get_storage() const {
    constexpr size_t index = TypeIndex<T, TypeInfos...>::value;
    return std::get<index>(storages_);
  }

 public:
  using Id = td::int64;

  template <typename T, typename... Args>
  Id emplace(Args &&...args) {
    return try_build<T>({}, [&]() -> td::Result<T> { return T(std::forward<Args>(args)...); }).move_as_ok();
  }
  template <typename T, typename... Args>
  Id try_emplace(td::UInt256 hash, Args &&...args) {
    return try_build<T>(hash, [&]() -> td::Result<T> { return T(std::forward<Args>(args)...); }).move_as_ok();
  }

  template <typename T, typename F>
  td::Result<Id> try_build(std::optional<td::UInt256> o_hash, F &&f) {
    using TI = typename TypeInfoFor<T, TypeInfos...>::type;
    auto &storage = get_storage<T>();

    if constexpr (TI::has_hash) {
      if (o_hash) {
        std::unique_lock map_lock(storage.map_mutex);
        auto it = storage.hash_to_id.find(*o_hash);
        if (it != storage.hash_to_id.end()) {
          return it->second;
        }
      }
    } else {
      CHECK(!o_hash);
    }

    TRY_RESULT(value, f());

    std::unique_lock map_lock(storage.map_mutex);
    if constexpr (TI::has_hash) {
      if (o_hash) {
        auto it = storage.hash_to_id.find(*o_hash);
        if (it != storage.hash_to_id.end()) {
          return it->second;
        }
      }
    }

    auto id = next_id.fetch_add(1, std::memory_order_relaxed);
    if constexpr (TI::is_mutable) {
      auto value_ptr = std::make_shared<MutableValue<T>>(std::move(value));
      storage.values.emplace(id, o_hash, value_ptr);
    } else {
      auto value_ptr = std::make_shared<T>(std::move(value));
      storage.values.emplace(id, o_hash, value_ptr);
    }

    if constexpr (TI::has_hash) {
      if (o_hash) {
        storage.hash_to_id.emplace(*o_hash, id);
      }
    }
    return id;
  }

  template <typename T>
  td::Result<SharedRef<T>> get_shared(Id id) const {
    using TI = typename TypeInfoFor<T, TypeInfos...>::type;
    static_assert(!TI::is_mutable, "Use get_mutable for mutable types");
    const auto &storage = get_storage<T>();

    std::unique_lock map_lock(storage.map_mutex);
    auto it = storage.values.find(id);
    if (it == storage.values.end()) {
      return td::Status::Error(static_cast<int>(tde2e_api::ErrorCode::InvalidId), PSLICE()
                                                                                      << "Invalid identifier = " << id);
    }
    return it->second.value;
  }

  template <typename T>
  td::Result<UniqueRef<T>> get_unique(Id id) {
    using TI = typename TypeInfoFor<T, TypeInfos...>::type;
    static_assert(TI::is_mutable, "Use get_shared for immutable types");
    auto &storage = get_storage<T>();

    std::unique_lock map_lock(storage.map_mutex);
    auto it = storage.values.find(id);
    if (it == storage.values.end()) {
      return td::Status::Error(static_cast<int>(tde2e_api::ErrorCode::InvalidId), PSLICE()
                                                                                      << "Invalid identifier = " << id);
    }

    auto value_ref = it->second.value;
    std::unique_lock value_lock(value_ref->mutex);
    auto value_ptr = &value_ref->value;

    return std::unique_ptr<T, MutexUnlockDeleter>(value_ptr,
                                                  MutexUnlockDeleter(std::move(value_ref), std::move(value_lock)));
  }

  template <typename T>
  td::Status destroy(std::optional<Id> o_id) {
    auto &storage = get_storage<T>();
    std::scoped_lock<std::mutex> lock(storage.map_mutex);
    if (o_id) {
      auto it = storage.values.find(*o_id);
      if (it == storage.values.end()) {
        return td::Status::Error(static_cast<int>(tde2e_api::ErrorCode::InvalidInput), "Unknown key identifier");
      }
      if (it->second.o_hash) {
        storage.hash_to_id.erase(*it->second.o_hash);
      }
      storage.values.erase(it);
      return td::Status::OK();
    }
    storage.hash_to_id.clear();
    storage.values.clear();
    return td::Status::OK();
  }
};

template <class T, class S>
td::Result<SharedRef<T>> convert(SharedRef<S> from) {
  if (std::holds_alternative<T>(*from)) {
    return SharedRef<T>(from, &std::get<T>(*from));
  }
  return td::Status::Error(static_cast<int>(tde2e_api::ErrorCode::UnknownError), "TODO");
}

template <class T, class S>
td::Result<UniqueRef<T>> convert(UniqueRef<S> from) {
  if (std::holds_alternative<T>(*from)) {
    auto value_ptr = &std::get<T>(*from);
    return UniqueRef<T>(value_ptr, std::move(from.get_deleter()));
  }
  return td::Status::Error(static_cast<int>(tde2e_api::ErrorCode::UnknownError), "TODO");
}

}  // namespace tde2e_core
