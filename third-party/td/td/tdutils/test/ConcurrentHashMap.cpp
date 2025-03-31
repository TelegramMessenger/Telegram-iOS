//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/benchmark.h"
#include "td/utils/common.h"
#include "td/utils/ConcurrentHashTable.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/misc.h"
#include "td/utils/port/Mutex.h"
#include "td/utils/port/thread.h"
#include "td/utils/SpinLock.h"
#include "td/utils/tests.h"

#include <atomic>

#if !TD_THREAD_UNSUPPORTED

#if TD_HAVE_ABSL
#include <absl/container/flat_hash_map.h>
#else
#include <unordered_map>
#endif

#if TD_WITH_LIBCUCKOO
#include <third-party/libcuckoo/libcuckoo/cuckoohash_map.hh>
#endif

#if TD_WITH_JUNCTION
#include <junction/ConcurrentMap_Grampa.h>
#include <junction/ConcurrentMap_Leapfrog.h>
#include <junction/ConcurrentMap_Linear.h>
#endif

// Non resizable HashMap. Just an example
template <class KeyT, class ValueT>
class ArrayHashMap {
 public:
  explicit ArrayHashMap(std::size_t n) : array_(n) {
  }
  static td::string get_name() {
    return "ArrayHashMap";
  }
  KeyT empty_key() const {
    return KeyT{};
  }

  void insert(KeyT key, ValueT value) {
    array_.with_value(key, true, [&](auto &node_value) { node_value.store(value, std::memory_order_release); });
  }
  ValueT find(KeyT key, ValueT value) {
    array_.with_value(key, false, [&](auto &node_value) { value = node_value.load(std::memory_order_acquire); });
    return value;
  }

 private:
  td::AtomicHashArray<KeyT, std::atomic<ValueT>> array_;
};

template <class KeyT, class ValueT>
class ConcurrentHashMapMutex {
 public:
  explicit ConcurrentHashMapMutex(std::size_t) {
  }
  static td::string get_name() {
    return "ConcurrentHashMapMutex";
  }
  void insert(KeyT key, ValueT value) {
    auto guard = mutex_.lock();
    hash_map_.emplace(key, value);
  }
  ValueT find(KeyT key, ValueT default_value) {
    auto guard = mutex_.lock();
    auto it = hash_map_.find(key);
    if (it == hash_map_.end()) {
      return default_value;
    }
    return it->second;
  }

 private:
  td::Mutex mutex_;
#if TD_HAVE_ABSL
  absl::flat_hash_map<KeyT, ValueT> hash_map_;
#else
  std::unordered_map<KeyT, ValueT, td::Hash<KeyT>> hash_map_;
#endif
};

template <class KeyT, class ValueT>
class ConcurrentHashMapSpinlock {
 public:
  explicit ConcurrentHashMapSpinlock(size_t) {
  }
  static td::string get_name() {
    return "ConcurrentHashMapSpinlock";
  }
  void insert(KeyT key, ValueT value) {
    auto guard = spinlock_.lock();
    hash_map_.emplace(key, value);
  }
  ValueT find(KeyT key, ValueT default_value) {
    auto guard = spinlock_.lock();
    auto it = hash_map_.find(key);
    if (it == hash_map_.end()) {
      return default_value;
    }
    return it->second;
  }

 private:
  td::SpinLock spinlock_;
#if TD_HAVE_ABSL
  absl::flat_hash_map<KeyT, ValueT> hash_map_;
#else
  std::unordered_map<KeyT, ValueT, td::Hash<KeyT>> hash_map_;
#endif
};

#if TD_WITH_LIBCUCKOO
template <class KeyT, class ValueT>
class ConcurrentHashMapLibcuckoo {
 public:
  explicit ConcurrentHashMapLibcuckoo(size_t) {
  }
  static td::string get_name() {
    return "ConcurrentHashMapLibcuckoo";
  }
  void insert(KeyT key, ValueT value) {
    hash_map_.insert(key, value);
  }
  ValueT find(KeyT key, ValueT default_value) {
    hash_map_.find(key, default_value);
    return default_value;
  }

 private:
  cuckoohash_map<KeyT, ValueT> hash_map_;
};
#endif

#if TD_WITH_JUNCTION
template <class KeyT, class ValueT>
class ConcurrentHashMapJunction {
 public:
  explicit ConcurrentHashMapJunction(std::size_t size) : hash_map_() {
  }
  static td::string get_name() {
    return "ConcurrentHashMapJunction";
  }
  void insert(KeyT key, ValueT value) {
    hash_map_.assign(key, value);
  }
  ValueT find(KeyT key, ValueT default_value) {
    return hash_map_.get(key);
  }

  ConcurrentHashMapJunction(const ConcurrentHashMapJunction &) = delete;
  ConcurrentHashMapJunction &operator=(const ConcurrentHashMapJunction &) = delete;
  ConcurrentHashMapJunction(ConcurrentHashMapJunction &&) = delete;
  ConcurrentHashMapJunction &operator=(ConcurrentHashMapJunction &&) = delete;
  ~ConcurrentHashMapJunction() {
    junction::DefaultQSBR.flush();
  }

 private:
  junction::ConcurrentMap_Leapfrog<KeyT, ValueT> hash_map_;
};
#endif

template <class HashMap>
class HashMapBenchmark final : public td::Benchmark {
  struct Query {
    int key;
    int value;
  };
  td::vector<Query> queries;
  td::unique_ptr<HashMap> hash_map;

  std::size_t threads_n = 16;
  static constexpr std::size_t MUL = 7273;  //1000000000 + 7;
  int n_ = 0;

 public:
  explicit HashMapBenchmark(std::size_t threads_n) : threads_n(threads_n) {
  }
  td::string get_description() const final {
    return HashMap::get_name();
  }
  void start_up_n(int n) final {
    n *= static_cast<int>(threads_n);
    n_ = n;
    hash_map = td::make_unique<HashMap>(n * 2);
  }

  void run(int n) final {
    n = n_;
    for (int count = 0; count < 1000; count++) {
      td::vector<td::thread> threads;

      for (std::size_t i = 0; i < threads_n; i++) {
        std::size_t l = n * i / threads_n;
        std::size_t r = n * (i + 1) / threads_n;
        threads.emplace_back([l, r, this] {
          for (size_t i = l; i < r; i++) {
            auto x = td::narrow_cast<int>((i + 1) * MUL % n_) + 3;
            auto y = td::narrow_cast<int>(i + 2);
            hash_map->insert(x, y);
          }
        });
      }
      for (auto &thread : threads) {
        thread.join();
      }
    }
  }

  void tear_down() final {
    for (int i = 0; i < n_; i++) {
      auto x = td::narrow_cast<int>((i + 1) * MUL % n_) + 3;
      auto y = td::narrow_cast<int>(i + 2);
      ASSERT_EQ(y, hash_map->find(x, -1));
    }
    queries.clear();
    hash_map.reset();
  }
};

template <class HashMap>
static void bench_hash_map() {
  td::bench(HashMapBenchmark<HashMap>(16));
  td::bench(HashMapBenchmark<HashMap>(1));
}

TEST(ConcurrentHashMap, Benchmark) {
  bench_hash_map<td::ConcurrentHashMap<td::int32, td::int32>>();
  bench_hash_map<ArrayHashMap<td::int32, td::int32>>();
  bench_hash_map<ConcurrentHashMapSpinlock<td::int32, td::int32>>();
  bench_hash_map<ConcurrentHashMapMutex<td::int32, td::int32>>();
#if TD_WITH_LIBCUCKOO
  bench_hash_map<ConcurrentHashMapLibcuckoo<td::int32, td::int32>>();
#endif
#if TD_WITH_JUNCTION
  bench_hash_map<ConcurrentHashMapJunction<td::int32, td::int32>>();
#endif
}

#endif
