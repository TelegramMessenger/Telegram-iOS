//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashMapChunks.h"
#include "td/utils/FlatHashTable.h"
#include "td/utils/format.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/logging.h"
#include "td/utils/MapNode.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tests.h"
#include "td/utils/Time.h"
#include "td/utils/VectorQueue.h"

#ifdef SCOPE_EXIT
#undef SCOPE_EXIT
#endif

#include <absl/container/flat_hash_map.h>
#include <absl/hash/hash.h>
#include <algorithm>
#include <benchmark/benchmark.h>
#include <folly/container/F14Map.h>
#include <functional>
#include <map>
#include <random>
#include <unordered_map>
#include <utility>

template <class TableT>
static void reserve(TableT &table, std::size_t size) {
  table.reserve(size);
}

template <class A, class B>
static void reserve(std::map<A, B> &table, std::size_t size) {
}

template <class KeyT, class ValueT>
class NoOpTable {
 public:
  using key_type = KeyT;
  using value_type = std::pair<const KeyT, ValueT>;
  template <class It>
  NoOpTable(It begin, It end) {
  }

  ValueT &operator[](const KeyT &) const {
    static ValueT dummy;
    return dummy;
  }

  KeyT find(const KeyT &key) const {
    return key;
  }
};

template <class KeyT, class ValueT>
class VectorTable {
 public:
  using key_type = KeyT;
  using value_type = std::pair<const KeyT, ValueT>;
  template <class It>
  VectorTable(It begin, It end) : table_(begin, end) {
  }

  ValueT &operator[](const KeyT &needle) {
    auto it = find(needle);
    if (it == table_.end()) {
      table_.emplace_back(needle, ValueT{});
      return table_.back().second;
    }
    return it->second;
  }
  auto find(const KeyT &needle) {
    return std::find_if(table_.begin(), table_.end(), [&](auto &key) { return key.first == needle; });
  }

 private:
  using KeyValue = value_type;
  td::vector<KeyValue> table_;
};

template <class KeyT, class ValueT>
class SortedVectorTable {
 public:
  using key_type = KeyT;
  using value_type = std::pair<KeyT, ValueT>;
  template <class It>
  SortedVectorTable(It begin, It end) : table_(begin, end) {
    std::sort(table_.begin(), table_.end());
  }

  ValueT &operator[](const KeyT &needle) {
    auto it = std::lower_bound(table_.begin(), table_.end(), needle,
                               [](const auto &l, const auto &r) { return l.first < r; });
    if (it == table_.end() || it->first != needle) {
      it = table_.insert(it, {needle, ValueT{}});
    }
    return it->second;
  }

  auto find(const KeyT &needle) {
    auto it = std::lower_bound(table_.begin(), table_.end(), needle,
                               [](const auto &l, const auto &r) { return l.first < r; });
    if (it != table_.end() && it->first == needle) {
      return it;
    }
    return table_.end();
  }

 private:
  using KeyValue = value_type;
  td::vector<KeyValue> table_;
};

template <class KeyT, class ValueT, class HashT = td::Hash<KeyT>>
class SimpleHashTable {
 public:
  using key_type = KeyT;
  using value_type = std::pair<KeyT, ValueT>;
  template <class It>
  SimpleHashTable(It begin, It end) {
    nodes_.resize((end - begin) * 2);
    for (; begin != end; ++begin) {
      insert(begin->first, begin->second);
    }
  }

  ValueT &operator[](const KeyT &needle) {
    UNREACHABLE();
  }

  ValueT *find(const KeyT &needle) {
    auto hash = HashT()(needle);
    std::size_t i = hash % nodes_.size();
    while (true) {
      if (nodes_[i].key == needle) {
        return &nodes_[i].value;
      }
      if (nodes_[i].hash == 0) {
        return nullptr;
      }
      i++;
      if (i == nodes_.size()) {
        i = 0;
      }
    }
  }

 private:
  using KeyValue = value_type;
  struct Node {
    std::size_t hash{0};
    KeyT key;
    ValueT value;
  };
  td::vector<Node> nodes_;

  void insert(KeyT key, ValueT value) {
    auto hash = HashT()(key);
    std::size_t i = hash % nodes_.size();
    while (true) {
      if (nodes_[i].hash == 0 || (nodes_[i].hash == hash && nodes_[i].key == key)) {
        nodes_[i].value = value;
        nodes_[i].key = key;
        nodes_[i].hash = hash;
        return;
      }
      i++;
      if (i == nodes_.size()) {
        i = 0;
      }
    }
  }
};

template <typename TableT>
static void BM_Get(benchmark::State &state) {
  std::size_t n = state.range(0);
  constexpr std::size_t BATCH_SIZE = 1024;
  td::Random::Xorshift128plus rnd(123);
  using Key = typename TableT::key_type;
  using Value = typename TableT::value_type::second_type;
  using KeyValue = std::pair<Key, Value>;
  td::vector<KeyValue> data;
  td::vector<Key> keys;

  TableT table;
  for (std::size_t i = 0; i < n; i++) {
    auto key = rnd();
    auto value = rnd();
    data.emplace_back(key, value);
    table.emplace(key, value);
    keys.push_back(key);
  }

  std::size_t key_i = 0;
  td::rand_shuffle(td::as_mutable_span(keys), rnd);
  auto next_key = [&] {
    key_i++;
    if (key_i == data.size()) {
      key_i = 0;
    }
    return keys[key_i];
  };

  while (state.KeepRunningBatch(BATCH_SIZE)) {
    for (std::size_t i = 0; i < BATCH_SIZE; i++) {
      benchmark::DoNotOptimize(table.find(next_key()));
    }
  }
}

template <typename TableT>
static void BM_find_same(benchmark::State &state) {
  td::Random::Xorshift128plus rnd(123);
  TableT table;
  constexpr std::size_t N = 100000;
  constexpr std::size_t BATCH_SIZE = 1024;
  reserve(table, N);

  for (std::size_t i = 0; i < N; i++) {
    table.emplace(rnd(), i);
  }

  auto key = td::Random::secure_uint64();
  table[key] = 123;

  while (state.KeepRunningBatch(BATCH_SIZE)) {
    for (std::size_t i = 0; i < BATCH_SIZE; i++) {
      benchmark::DoNotOptimize(table.find(key));
    }
  }
}

template <typename TableT>
static void BM_emplace_same(benchmark::State &state) {
  td::Random::Xorshift128plus rnd(123);
  TableT table;
  constexpr std::size_t N = 100000;
  constexpr std::size_t BATCH_SIZE = 1024;
  reserve(table, N);

  for (std::size_t i = 0; i < N; i++) {
    table.emplace(rnd(), i);
  }

  auto key = 123743;
  table[key] = 123;

  while (state.KeepRunningBatch(BATCH_SIZE)) {
    for (std::size_t i = 0; i < BATCH_SIZE; i++) {
      benchmark::DoNotOptimize(table.emplace(key + (i & 15) * 100, 43784932));
    }
  }
}

template <typename TableT>
static void BM_emplace_string(benchmark::State &state) {
  td::Random::Xorshift128plus rnd(123);
  TableT table;
  constexpr std::size_t N = 100000;
  constexpr std::size_t BATCH_SIZE = 1024;
  reserve(table, N);

  for (std::size_t i = 0; i < N; i++) {
    table.emplace(td::to_string(rnd()), i);
  }

  table["0"] = 123;
  td::vector<td::string> strings;
  for (std::size_t i = 0; i < 16; i++) {
    strings.emplace_back(1, static_cast<char>('0' + i));
  }

  while (state.KeepRunningBatch(BATCH_SIZE)) {
    for (std::size_t i = 0; i < BATCH_SIZE; i++) {
      benchmark::DoNotOptimize(table.emplace(strings[i & 15], 43784932));
    }
  }
}

template <class K, class V, class FunctT>
static void table_remove_if(absl::flat_hash_map<K, V> &table, FunctT &&func) {
  for (auto it = table.begin(); it != table.end();) {
    if (func(*it)) {
      auto copy = it;
      ++it;
      table.erase(copy);
    } else {
      ++it;
    }
  }
}

template <typename TableT>
static void BM_remove_if(benchmark::State &state) {
  constexpr std::size_t N = 100000;
  constexpr std::size_t BATCH_SIZE = N;

  TableT table;
  reserve(table, N);
  while (state.KeepRunningBatch(BATCH_SIZE)) {
    state.PauseTiming();
    td::Random::Xorshift128plus rnd(123);
    for (std::size_t i = 0; i < N; i++) {
      table.emplace(rnd(), i);
    }
    state.ResumeTiming();

    using td::table_remove_if;
    table_remove_if(table, [](auto &it) { return it.second % 2 == 0; });
  }
}

template <typename TableT>
static void BM_erase_all_with_begin(benchmark::State &state) {
  constexpr std::size_t N = 100000;
  constexpr std::size_t BATCH_SIZE = N;

  TableT table;
  td::Random::Xorshift128plus rnd(123);
  while (state.KeepRunningBatch(BATCH_SIZE)) {
    for (std::size_t i = 0; i < BATCH_SIZE; i++) {
      table.emplace(rnd() + 1, i);
    }
    while (!table.empty()) {
      table.erase(table.begin());
    }
  }
}

template <typename TableT>
static void BM_cache(benchmark::State &state) {
  constexpr std::size_t N = 1000;
  constexpr std::size_t BATCH_SIZE = 1000000;

  TableT table;
  td::Random::Xorshift128plus rnd(123);
  td::VectorQueue<td::uint64> keys;
  while (state.KeepRunningBatch(BATCH_SIZE)) {
    for (std::size_t i = 0; i < BATCH_SIZE; i++) {
      auto key = rnd() + 1;
      keys.push(key);
      table.emplace(key, i);
      if (table.size() > N) {
        table.erase(keys.pop());
      }
    }
  }
}

template <typename TableT>
static void BM_cache2(benchmark::State &state) {
  constexpr std::size_t N = 1000;
  constexpr std::size_t BATCH_SIZE = 1000000;

  TableT table;
  td::Random::Xorshift128plus rnd(123);
  td::VectorQueue<td::uint64> keys;
  while (state.KeepRunningBatch(BATCH_SIZE)) {
    for (std::size_t i = 0; i < BATCH_SIZE; i++) {
      auto key = rnd() + 1;
      keys.push(key);
      table.emplace(key, i);
      if (table.size() > N) {
        table.erase(keys.pop_rand(rnd));
      }
    }
  }
}

template <typename TableT>
static void BM_cache3(benchmark::State &state) {
  std::size_t N = state.range(0);
  constexpr std::size_t BATCH_SIZE = 1000000;

  TableT table;
  td::Random::Xorshift128plus rnd(123);
  td::VectorQueue<td::uint64> keys;
  std::size_t step = 20;
  while (state.KeepRunningBatch(BATCH_SIZE)) {
    for (std::size_t i = 0; i < BATCH_SIZE; i += step) {
      auto key = rnd() + 1;
      keys.push(key);
      table.emplace(key, i);

      for (std::size_t j = 1; j < step; j++) {
        auto key_to_find = keys.data()[rnd() % keys.size()];
        benchmark::DoNotOptimize(table.find(key_to_find));
      }

      if (table.size() > N) {
        table.erase(keys.pop_rand(rnd));
      }
    }
  }
}

template <typename TableT>
static void BM_remove_if_slow(benchmark::State &state) {
  constexpr std::size_t N = 5000;
  constexpr std::size_t BATCH_SIZE = 500000;

  TableT table;
  td::Random::Xorshift128plus rnd(123);
  for (std::size_t i = 0; i < N; i++) {
    table.emplace(rnd() + 1, i);
  }
  auto first_key = table.begin()->first;
  {
    std::size_t cnt = 0;
    using td::table_remove_if;
    table_remove_if(table, [&cnt, n = N](auto &) {
      cnt += 2;
      return cnt <= n;
    });
  }
  while (state.KeepRunningBatch(BATCH_SIZE)) {
    for (std::size_t i = 0; i < BATCH_SIZE; i++) {
      table.emplace(first_key, i);
      table.erase(first_key);
    }
  }
}

template <typename TableT>
static void BM_remove_if_slow_old(benchmark::State &state) {
  constexpr std::size_t N = 100000;
  constexpr std::size_t BATCH_SIZE = 5000000;

  TableT table;
  while (state.KeepRunningBatch(BATCH_SIZE)) {
    td::Random::Xorshift128plus rnd(123);
    for (std::size_t i = 0; i < BATCH_SIZE; i++) {
      table.emplace(rnd() + 1, i);
      if (table.size() > N) {
        std::size_t cnt = 0;
        using td::table_remove_if;
        table_remove_if(table, [&cnt, n = N](auto &) {
          cnt += 2;
          return cnt <= n;
        });
      }
    }
  }
}

template <typename TableT>
static void benchmark_create(td::Slice name) {
  td::Random::Xorshift128plus rnd(123);
  {
    constexpr std::size_t N = 10000000;
    TableT table;
    reserve(table, N);
    auto start = td::Timestamp::now();
    for (std::size_t i = 0; i < N; i++) {
      table.emplace(rnd(), i);
    }
    auto end = td::Timestamp::now();
    LOG(INFO) << name << ": create " << N << " elements: " << td::format::as_time(end.at() - start.at());

    double res = 0;
    td::vector<std::pair<std::size_t, td::format::Time>> pauses;
    for (std::size_t i = 0; i < N; i++) {
      auto emplace_start = td::Timestamp::now();
      table.emplace(rnd(), i);
      auto emplace_end = td::Timestamp::now();
      auto pause = emplace_end.at() - emplace_start.at();
      res = td::max(pause, res);
      if (pause > 0.001) {
        pauses.emplace_back(i, td::format::as_time(pause));
      }
    }

    LOG(INFO) << name << ": create another " << N << " elements, max pause = " << td::format::as_time(res) << " "
              << pauses;
  }
}

struct CacheMissNode {
  td::uint32 data{};
  char padding[64 - sizeof(data)];
};

class IterateFast {
 public:
  static td::uint32 iterate(CacheMissNode *ptr, std::size_t max_shift) {
    td::uint32 res = 1;
    for (std::size_t i = 0; i < max_shift; i++) {
      if (ptr[i].data % max_shift != 0) {
        res *= ptr[i].data;
      } else {
        res /= ptr[i].data;
      }
    }
    return res;
  }
};

class IterateSlow {
 public:
  static td::uint32 iterate(CacheMissNode *ptr, std::size_t max_shift) {
    td::uint32 res = 1;
    for (std::size_t i = 0;; i++) {
      if (ptr[i].data % max_shift != 0) {
        res *= ptr[i].data;
      } else {
        break;
      }
    }
    return res;
  }
};

template <class F>
static void BM_cache_miss(benchmark::State &state) {
  td::uint32 max_shift = state.range(0);
  bool flag = state.range(1);
  std::random_device rd;
  std::mt19937 rnd(rd());
  int N = 50000000;
  td::vector<CacheMissNode> nodes(N);
  td::uint32 i = 0;
  for (auto &node : nodes) {
    if (flag) {
      node.data = i++ % max_shift;
    } else {
      node.data = rnd();
    }
  }

  td::vector<int> positions(N);
  std::uniform_int_distribution<td::uint32> rnd_pos(0, N - 1000);
  for (auto &pos : positions) {
    pos = rnd_pos(rnd);
    if (flag) {
      pos = pos / max_shift * max_shift + 1;
    }
  }

  while (state.KeepRunningBatch(positions.size())) {
    for (const auto pos : positions) {
      auto *ptr = &nodes[pos];
      auto res = F::iterate(ptr, max_shift);
      benchmark::DoNotOptimize(res);
    }
  }
}

static td::uint64 equal_mask_slow(td::uint8 *bytes, td::uint8 needle) {
  td::uint64 mask = 0;
  for (int i = 0; i < 16; i++) {
    mask |= (bytes[i] == needle) << i;
  }
  return mask;
}

template <class MaskT>
static void BM_mask(benchmark::State &state) {
  std::size_t BATCH_SIZE = 1024;
  td::vector<td::uint8> bytes(BATCH_SIZE + 16);
  for (auto &b : bytes) {
    b = static_cast<td::uint8>(td::Random::fast(0, 17));
  }

  while (state.KeepRunningBatch(BATCH_SIZE)) {
    for (std::size_t i = 0; i < BATCH_SIZE; i++) {
      benchmark::DoNotOptimize(MaskT::equal_mask(bytes.data() + i, 17));
    }
  }
}

BENCHMARK_TEMPLATE(BM_mask, td::MaskPortable);
#ifdef __aarch64__
BENCHMARK_TEMPLATE(BM_mask, td::MaskNeonFolly);
BENCHMARK_TEMPLATE(BM_mask, td::MaskNeon);
#endif
#if TD_SSE2
BENCHMARK_TEMPLATE(BM_mask, td::MaskSse2);
#endif

template <class KeyT, class ValueT, class HashT = td::Hash<KeyT>, class EqT = std::equal_to<KeyT>>
using FlatHashMapImpl = td::FlatHashTable<td::MapNode<KeyT, ValueT, EqT>, HashT, EqT>;

#define FOR_EACH_TABLE(F)  \
  F(FlatHashMapImpl)       \
  F(td::FlatHashMapChunks) \
  F(folly::F14FastMap)     \
  F(absl::flat_hash_map)   \
  F(std::unordered_map)    \
  F(std::map)

//BENCHMARK(BM_cache_miss<IterateSlow>)->Ranges({{1, 16}, {0, 1}});
//BENCHMARK(BM_cache_miss<IterateFast>)->Ranges({{1, 16}, {0, 1}});
//BENCHMARK_TEMPLATE(BM_Get, VectorTable<td::uint64, td::uint64>)->Range(1, 1 << 26);
//BENCHMARK_TEMPLATE(BM_Get, SortedVectorTable<td::uint64, td::uint64>)->Range(1, 1 << 26);
//BENCHMARK_TEMPLATE(BM_Get, NoOpTable<td::uint64, td::uint64>)->Range(1, 1 << 26);

#define REGISTER_GET_BENCHMARK(HT) BENCHMARK_TEMPLATE(BM_Get, HT<td::uint64, td::uint64>)->Range(1, 1 << 23);

#define REGISTER_FIND_BENCHMARK(HT)                                                                                 \
  BENCHMARK_TEMPLATE(BM_find_same, HT<td::uint64, td::uint64>)                                                      \
      ->ComputeStatistics("max", [](const td::vector<double> &v) { return *std::max_element(v.begin(), v.end()); }) \
      ->ComputeStatistics("min", [](const td::vector<double> &v) { return *std::min_element(v.begin(), v.end()); }) \
      ->Repetitions(20)                                                                                             \
      ->DisplayAggregatesOnly(true);

#define REGISTER_REMOVE_IF_BENCHMARK(HT) BENCHMARK_TEMPLATE(BM_remove_if, HT<td::uint64, td::uint64>);
#define REGISTER_EMPLACE_BENCHMARK(HT) BENCHMARK_TEMPLATE(BM_emplace_same, HT<td::uint64, td::uint64>);
#define REGISTER_EMPLACE_STRING_BENCHMARK(HT) BENCHMARK_TEMPLATE(BM_emplace_string, HT<td::string, td::uint64>);
#define REGISTER_CACHE_BENCHMARK(HT) BENCHMARK_TEMPLATE(BM_cache, HT<td::uint64, td::uint64>);
#define REGISTER_CACHE2_BENCHMARK(HT) BENCHMARK_TEMPLATE(BM_cache2, HT<td::uint64, td::uint64>);
#define REGISTER_CACHE3_BENCHMARK(HT) BENCHMARK_TEMPLATE(BM_cache3, HT<td::uint64, td::uint64>)->Range(1, 1 << 23);
#define REGISTER_ERASE_ALL_BENCHMARK(HT) BENCHMARK_TEMPLATE(BM_erase_all_with_begin, HT<td::uint64, td::uint64>);
#define REGISTER_REMOVE_IF_SLOW_BENCHMARK(HT) BENCHMARK_TEMPLATE(BM_remove_if_slow, HT<td::uint64, td::uint64>);
#define REGISTER_REMOVE_IF_SLOW_OLD_BENCHMARK(HT) BENCHMARK_TEMPLATE(BM_remove_if_slow_old, HT<td::uint64, td::uint64>);

FOR_EACH_TABLE(REGISTER_GET_BENCHMARK)
FOR_EACH_TABLE(REGISTER_CACHE3_BENCHMARK)
FOR_EACH_TABLE(REGISTER_CACHE2_BENCHMARK)
FOR_EACH_TABLE(REGISTER_CACHE_BENCHMARK)
FOR_EACH_TABLE(REGISTER_REMOVE_IF_BENCHMARK)
FOR_EACH_TABLE(REGISTER_EMPLACE_BENCHMARK)
FOR_EACH_TABLE(REGISTER_EMPLACE_STRING_BENCHMARK)
FOR_EACH_TABLE(REGISTER_ERASE_ALL_BENCHMARK)
FOR_EACH_TABLE(REGISTER_FIND_BENCHMARK)
FOR_EACH_TABLE(REGISTER_REMOVE_IF_SLOW_OLD_BENCHMARK)
FOR_EACH_TABLE(REGISTER_REMOVE_IF_SLOW_BENCHMARK)

#define RUN_CREATE_BENCHMARK(HT) benchmark_create<HT<td::uint64, td::uint64>>(#HT);

int main(int argc, char **argv) {
  //  FOR_EACH_TABLE(RUN_CREATE_BENCHMARK);

  benchmark::Initialize(&argc, argv);
  benchmark::RunSpecifiedBenchmarks();
  benchmark::Shutdown();
}
