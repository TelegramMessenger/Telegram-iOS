//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#if USE_MEMPROF
#include "memprof/memprof_stat.h"
#endif

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashMapChunks.h"
#include "td/utils/FlatHashTable.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/logging.h"
#include "td/utils/MapNode.h"
#include "td/utils/misc.h"
#include "td/utils/port/Stat.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"

#ifdef SCOPE_EXIT
#undef SCOPE_EXIT
#endif

#include <absl/container/flat_hash_map.h>
#include <array>
#include <folly/container/F14Map.h>
#include <functional>
#include <map>
#include <unordered_map>

static int mem_stat_i = -1;
static int mem_stat_cur = 0;

static bool use_memprof() {
#if USE_MEMPROF
  return mem_stat_i < 0 && is_memprof_on();
#else
  return mem_stat_i < 0;
#endif
}

static td::uint64 get_memory() {
#if USE_MEMPROF
  if (use_memprof()) {
    return get_used_memory_size();
  }
#endif
  CHECK(!use_memprof());
  return td::mem_stat().ok().resident_size_;
}

template <class T>
class Generator {
 public:
  T next() {
    UNREACHABLE();
  }
  static size_t dyn_size() {
    UNREACHABLE();
  }
};

template <class T>
class IntGenerator {
 public:
  T next() {
    return ++value;
  }
  static size_t dyn_size() {
    return 0;
  }

 private:
  T value{};
};

template <>
class Generator<td::int32> final : public IntGenerator<td::int32> {};
template <>
class Generator<td::int64> final : public IntGenerator<td::int64> {};

template <class T>
class Generator<td::unique_ptr<T>> {
 public:
  td::unique_ptr<T> next() {
    return td::make_unique<T>();
  }
  static std::size_t dyn_size() {
    return sizeof(T);
  }
};

template <class T, class KeyT, class ValueT>
static void measure(td::StringBuilder &sb, td::Slice name, td::Slice key_name, td::Slice value_name) {
  mem_stat_cur++;
  if (mem_stat_i >= 0 && mem_stat_cur != mem_stat_i) {
    return;
  }
  sb << name << "<" << key_name << "," << value_name << "> " << (use_memprof() ? "memprof" : "os") << "\n";
  std::size_t ideal_size = sizeof(KeyT) + sizeof(ValueT) + Generator<ValueT>::dyn_size();

  sb << "\tempty:" << sizeof(T);
  struct Stat {
    int pi;
    double min_ratio;
    double max_ratio;
  };
  td::vector<Stat> stat;
  stat.reserve(1024);
  for (std::size_t size : {1000000u}) {
    Generator<KeyT> key_generator;
    Generator<ValueT> value_generator;
    auto start_mem = get_memory();
    T ht;
    auto ratio = [&] {
      auto end_mem = get_memory();
      auto used_mem = end_mem - start_mem;
      return static_cast<double>(used_mem) / (static_cast<double>(ideal_size) * static_cast<double>(ht.size()));
    };
    double min_ratio;
    double max_ratio;
    auto reset = [&] {
      min_ratio = 1e100;
      max_ratio = 0;
    };
    auto update = [&] {
      auto x = ratio();
      min_ratio = td::min(min_ratio, x);
      max_ratio = td::max(max_ratio, x);
    };
    reset();

    int p = 10;
    int pi = 1;
    for (std::size_t i = 0; i < size; i++) {
      ht.emplace(key_generator.next(), value_generator.next());
      update();
      if ((i + 1) % p == 0) {
        stat.push_back(Stat{pi, min_ratio, max_ratio});
        reset();
        pi++;
        p *= 10;
      }
    }
  }
  for (auto &s : stat) {
    sb << " 10^" << s.pi << ":" << s.min_ratio << "->" << s.max_ratio;
  }
  sb << '\n';
}

template <std::size_t size>
using Bytes = std::array<char, size>;

template <template <typename... Args> class T>
void print_memory_stats(td::Slice name) {
  td::string big_buff(1 << 16, '\0');
  td::StringBuilder sb(big_buff, false);
#define MEASURE(KeyT, ValueT) measure<T<KeyT, ValueT>, KeyT, ValueT>(sb, name, #KeyT, #ValueT);
  MEASURE(td::int32, td::int32);
  MEASURE(td::int64, td::unique_ptr<Bytes<360>>);
  if (!sb.as_cslice().empty()) {
    LOG(PLAIN) << '\n' << sb.as_cslice() << '\n';
  }
}

template <class KeyT, class ValueT, class HashT = td::Hash<KeyT>, class EqT = std::equal_to<KeyT>>
using FlatHashMapImpl = td::FlatHashTable<td::MapNode<KeyT, ValueT>, HashT, EqT>;

#define FOR_EACH_TABLE(F) \
  F(FlatHashMapImpl)      \
  F(folly::F14FastMap)    \
  F(absl::flat_hash_map)  \
  F(std::unordered_map)   \
  F(std::map)
#define BENCHMARK_MEMORY(T) print_memory_stats<T>(#T);

int main(int argc, const char *argv[]) {
  // Usage:
  //  % benchmark/memory-hashset-os 0
  //  Number of benchmarks = 10
  //  % for i in {1..10}; do ./benchmark/memory-hashset-os $i; done
  if (argc > 1) {
    mem_stat_i = td::to_integer<td::int32>(td::Slice(argv[1]));
  }
  FOR_EACH_TABLE(BENCHMARK_MEMORY);
  if (mem_stat_i <= 0) {
    LOG(PLAIN) << "Number of benchmarks = " << mem_stat_cur << "\n";
  }
}
