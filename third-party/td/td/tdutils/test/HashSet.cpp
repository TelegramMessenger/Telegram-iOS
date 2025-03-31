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
#include "td/utils/FlatHashSet.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/logging.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/tests.h"

#include <algorithm>
#include <array>
#include <random>
#include <unordered_map>
#include <unordered_set>
#include <utility>

template <class T>
static auto extract_kv(const T &reference) {
  auto expected = td::transform(reference, [](auto &it) { return std::make_pair(it.first, it.second); });
  std::sort(expected.begin(), expected.end());
  return expected;
}

template <class T>
static auto extract_k(const T &reference) {
  auto expected = td::transform(reference, [](auto &it) { return it; });
  std::sort(expected.begin(), expected.end());
  return expected;
}

TEST(FlatHashMapChunks, basic) {
  td::FlatHashMapChunks<int, int> kv;
  kv[5] = 3;
  ASSERT_EQ(3, kv[5]);
  kv[3] = 4;
  ASSERT_EQ(4, kv[3]);
}

TEST(FlatHashMap, probing) {
  auto test = [](int buckets, int elements) {
    CHECK(buckets >= elements);
    td::vector<bool> data(buckets, false);
    std::random_device rnd;
    std::mt19937 mt(rnd());
    std::uniform_int_distribution<td::int32> d(0, buckets - 1);
    for (int i = 0; i < elements; i++) {
      int pos = d(mt);
      while (data[pos]) {
        pos++;
        if (pos == buckets) {
          pos = 0;
        }
      }
      data[pos] = true;
    }
    int max_chain = 0;
    int cur_chain = 0;
    for (auto x : data) {
      if (x) {
        cur_chain++;
        max_chain = td::max(max_chain, cur_chain);
      } else {
        cur_chain = 0;
      }
    }
    LOG(INFO) << "Buckets=" << buckets << " elements=" << elements << " max_chain=" << max_chain;
  };
  test(8192, static_cast<int>(8192 * 0.8));
  test(8192, static_cast<int>(8192 * 0.6));
  test(8192, static_cast<int>(8192 * 0.3));
}

struct A {
  int a;
};

struct AHash {
  td::uint32 operator()(A a) const {
    return td::Hash<int>()(a.a);
  }
};

static bool operator==(const A &lhs, const A &rhs) {
  return lhs.a == rhs.a;
}

TEST(FlatHashSet, init) {
  td::FlatHashSet<td::Slice, td::SliceHash> s{"1", "22", "333", "4444"};
  ASSERT_TRUE(s.size() == 4);
  td::string str("1");
  ASSERT_TRUE(s.count(str) == 1);
  ASSERT_TRUE(s.count("1") == 1);
  ASSERT_TRUE(s.count("22") == 1);
  ASSERT_TRUE(s.count("333") == 1);
  ASSERT_TRUE(s.count("4444") == 1);
  ASSERT_TRUE(s.count("4") == 0);
  ASSERT_TRUE(s.count("222") == 0);
  ASSERT_TRUE(s.count("") == 0);
}

TEST(FlatHashSet, foreach) {
  td::FlatHashSet<A, AHash> s;
  for (auto it : s) {
    LOG(ERROR) << it.a;
  }
  s.insert({1});
  LOG(INFO) << s.begin()->a;
}

TEST(FlatHashSet, TL) {
  td::FlatHashSet<int> s;
  int N = 100000;
  for (int i = 0; i < 10000000; i++) {
    s.insert((i + N / 2) % N + 1);
    s.erase(i % N + 1);
  }
}

TEST(FlatHashMap, basic) {
  {
    td::FlatHashMap<td::int32, int> map;
    map[1] = 2;
    ASSERT_EQ(2, map[1]);
    ASSERT_EQ(1, map.find(1)->first);
    ASSERT_EQ(2, map.find(1)->second);
    // ASSERT_EQ(1, map.find(1)->key());
    // ASSERT_EQ(2, map.find(1)->value());
    for (auto &kv : map) {
      ASSERT_EQ(1, kv.first);
      ASSERT_EQ(2, kv.second);
    }
    map.erase(map.find(1));
  }

  td::FlatHashMap<td::int32, std::array<td::unique_ptr<td::string>, 10>> x;
  auto y = std::move(x);
  x[12];
  x.erase(x.find(12));

  {
    td::FlatHashMap<td::int32, td::string> map = {{1, "hello"}, {2, "world"}};
    ASSERT_EQ("hello", map[1]);
    ASSERT_EQ("world", map[2]);
    ASSERT_EQ(2u, map.size());
    ASSERT_EQ("", map[3]);
    ASSERT_EQ(3u, map.size());
  }

  {
    td::FlatHashMap<td::int32, td::string> map = {{1, "hello"}, {1, "world"}};
    ASSERT_EQ("hello", map[1]);
    ASSERT_EQ(1u, map.size());
  }

  using KV = td::FlatHashMap<td::string, td::string>;
  using Data = td::vector<std::pair<td::string, td::string>>;
  auto data = Data{{"a", "b"}, {"c", "d"}};
  { ASSERT_EQ(Data{}, extract_kv(KV())); }

  {
    KV kv;
    for (auto &pair : data) {
      kv.emplace(pair.first, pair.second);
    }
    ASSERT_EQ(data, extract_kv(kv));

    KV moved_kv(std::move(kv));
    ASSERT_EQ(data, extract_kv(moved_kv));
    ASSERT_EQ(Data{}, extract_kv(kv));
    ASSERT_TRUE(kv.empty());
    kv = std::move(moved_kv);
    ASSERT_EQ(data, extract_kv(kv));

    KV assign_moved_kv;
    assign_moved_kv = std::move(kv);
    ASSERT_EQ(data, extract_kv(assign_moved_kv));
    ASSERT_EQ(Data{}, extract_kv(kv));
    ASSERT_TRUE(kv.empty());
    kv = std::move(assign_moved_kv);

    KV it_copy_kv;
    for (auto &pair : kv) {
      it_copy_kv.emplace(pair.first, pair.second);
    }
    ASSERT_EQ(data, extract_kv(it_copy_kv));
  }

  {
    KV kv;
    ASSERT_TRUE(kv.empty());
    ASSERT_EQ(0u, kv.size());
    for (auto &pair : data) {
      kv.emplace(pair.first, pair.second);
    }
    ASSERT_TRUE(!kv.empty());
    ASSERT_EQ(2u, kv.size());

    ASSERT_EQ("a", kv.find("a")->first);
    ASSERT_EQ("b", kv.find("a")->second);
    kv.find("a")->second = "c";
    ASSERT_EQ("c", kv.find("a")->second);
    ASSERT_EQ("c", kv["a"]);

    ASSERT_EQ(0u, kv.count("x"));
    ASSERT_EQ(1u, kv.count("a"));
  }
  {
    KV kv;
    kv["d"];
    ASSERT_EQ((Data{{"d", ""}}), extract_kv(kv));
    kv.erase(kv.find("d"));
    ASSERT_EQ(Data{}, extract_kv(kv));
  }
}

TEST(FlatHashMap, remove_if_basic) {
  td::Random::Xorshift128plus rnd(123);

  constexpr int TESTS_N = 1000;
  constexpr int MAX_TABLE_SIZE = 1000;
  for (int test_i = 0; test_i < TESTS_N; test_i++) {
    std::unordered_map<td::uint64, td::uint64, td::Hash<td::uint64>> reference;
    td::FlatHashMap<td::uint64, td::uint64> table;
    int N = rnd.fast(1, MAX_TABLE_SIZE);
    for (int i = 0; i < N; i++) {
      auto key = rnd();
      auto value = i;
      reference[key] = value;
      table[key] = value;
    }
    ASSERT_EQ(extract_kv(reference), extract_kv(table));

    td::vector<std::pair<td::uint64, td::uint64>> kv;
    td::table_remove_if(table, [&](auto &it) {
      kv.emplace_back(it.first, it.second);
      return it.second % 2 == 0;
    });
    std::sort(kv.begin(), kv.end());
    ASSERT_EQ(extract_kv(reference), kv);

    td::table_remove_if(reference, [](auto &it) { return it.second % 2 == 0; });
    ASSERT_EQ(extract_kv(reference), extract_kv(table));
  }
}

static constexpr size_t MAX_TABLE_SIZE = 1000;
TEST(FlatHashMap, stress_test) {
  td::Random::Xorshift128plus rnd(123);
  size_t max_table_size = MAX_TABLE_SIZE;  // dynamic value
  std::unordered_map<td::uint64, td::uint64, td::Hash<td::uint64>> ref;
  td::FlatHashMap<td::uint64, td::uint64> tbl;

  auto validate = [&] {
    ASSERT_EQ(ref.empty(), tbl.empty());
    ASSERT_EQ(ref.size(), tbl.size());
    ASSERT_EQ(extract_kv(ref), extract_kv(tbl));
    for (auto &kv : ref) {
      auto tbl_it = tbl.find(kv.first);
      ASSERT_TRUE(tbl_it != tbl.end());
      ASSERT_EQ(kv.second, tbl_it->second);
    }
  };

  td::vector<td::RandomSteps::Step> steps;
  auto add_step = [&](td::Slice step_name, td::uint32 weight, auto f) {
    auto g = [&, f = std::move(f)] {
      //ASSERT_EQ(ref.size(), tbl.size());
      f();
      ASSERT_EQ(ref.size(), tbl.size());
      //validate();
    };
    steps.emplace_back(td::RandomSteps::Step{std::move(g), weight});
  };

  auto gen_key = [&] {
    auto key = rnd() % 4000 + 1;
    return key;
  };

  add_step("Reset hash table", 1, [&] {
    validate();
    td::reset_to_empty(ref);
    td::reset_to_empty(tbl);
    max_table_size = rnd.fast(1, MAX_TABLE_SIZE);
  });
  add_step("Clear hash table", 1, [&] {
    validate();
    ref.clear();
    tbl.clear();
    max_table_size = rnd.fast(1, MAX_TABLE_SIZE);
  });

  add_step("Insert random value", 1000, [&] {
    if (tbl.size() > max_table_size) {
      return;
    }
    auto key = gen_key();
    auto value = rnd();
    ref[key] = value;
    tbl[key] = value;
    ASSERT_EQ(ref[key], tbl[key]);
  });

  add_step("Emplace random value", 1000, [&] {
    if (tbl.size() > max_table_size) {
      return;
    }
    auto key = gen_key();
    auto value = rnd();
    auto ref_it = ref.emplace(key, value);
    auto tbl_it = tbl.emplace(key, value);
    ASSERT_EQ(ref_it.second, tbl_it.second);
    ASSERT_EQ(key, tbl_it.first->first);
  });

  add_step("empty operator[]", 1000, [&] {
    if (tbl.size() > max_table_size) {
      return;
    }
    auto key = gen_key();
    ASSERT_EQ(ref[key], tbl[key]);
  });

  add_step("reserve", 10, [&] { tbl.reserve(static_cast<size_t>(rnd() % max_table_size)); });

  add_step("find", 1000, [&] {
    auto key = gen_key();
    auto ref_it = ref.find(key);
    auto tbl_it = tbl.find(key);
    ASSERT_EQ(ref_it == ref.end(), tbl_it == tbl.end());
    if (ref_it != ref.end()) {
      ASSERT_EQ(ref_it->first, tbl_it->first);
      ASSERT_EQ(ref_it->second, tbl_it->second);
    }
  });

  add_step("find_and_erase", 100, [&] {
    auto key = gen_key();
    auto ref_it = ref.find(key);
    auto tbl_it = tbl.find(key);
    ASSERT_EQ(ref_it == ref.end(), tbl_it == tbl.end());
    if (ref_it != ref.end()) {
      ref.erase(ref_it);
      tbl.erase(tbl_it);
    }
  });

  add_step("remove_if", 5, [&] {
    auto mul = rnd();
    auto bit = rnd() % 64;
    auto condition = [&](auto &it) {
      return (((it.second * mul) >> bit) & 1) == 0;
    };
    td::table_remove_if(tbl, condition);
    td::table_remove_if(ref, condition);
  });

  td::RandomSteps runner(std::move(steps));
  for (size_t i = 0; i < 1000000; i++) {
    runner.step(rnd);
  }
}

TEST(FlatHashSet, stress_test) {
  td::vector<td::RandomSteps::Step> steps;
  auto add_step = [&steps](td::Slice, td::uint32 weight, auto f) {
    steps.emplace_back(td::RandomSteps::Step{std::move(f), weight});
  };

  td::Random::Xorshift128plus rnd(123);
  size_t max_table_size = MAX_TABLE_SIZE;  // dynamic value
  std::unordered_set<td::uint64, td::Hash<td::uint64>> ref;
  td::FlatHashSet<td::uint64> tbl;

  auto validate = [&] {
    ASSERT_EQ(ref.empty(), tbl.empty());
    ASSERT_EQ(ref.size(), tbl.size());
    ASSERT_EQ(extract_k(ref), extract_k(tbl));
  };
  auto gen_key = [&] {
    auto key = rnd() % 4000 + 1;
    return key;
  };

  add_step("Reset hash table", 1, [&] {
    validate();
    td::reset_to_empty(ref);
    td::reset_to_empty(tbl);
    max_table_size = rnd.fast(1, MAX_TABLE_SIZE);
  });
  add_step("Clear hash table", 1, [&] {
    validate();
    ref.clear();
    tbl.clear();
    max_table_size = rnd.fast(1, MAX_TABLE_SIZE);
  });

  add_step("Insert random value", 1000, [&] {
    if (tbl.size() > max_table_size) {
      return;
    }
    auto key = gen_key();
    ref.insert(key);
    tbl.insert(key);
  });

  add_step("reserve", 10, [&] { tbl.reserve(static_cast<size_t>(rnd() % max_table_size)); });

  add_step("find", 1000, [&] {
    auto key = gen_key();
    auto ref_it = ref.find(key);
    auto tbl_it = tbl.find(key);
    ASSERT_EQ(ref_it == ref.end(), tbl_it == tbl.end());
    if (ref_it != ref.end()) {
      ASSERT_EQ(*ref_it, *tbl_it);
    }
  });

  add_step("find_and_erase", 100, [&] {
    auto key = gen_key();
    auto ref_it = ref.find(key);
    auto tbl_it = tbl.find(key);
    ASSERT_EQ(ref_it == ref.end(), tbl_it == tbl.end());
    if (ref_it != ref.end()) {
      ref.erase(ref_it);
      tbl.erase(tbl_it);
    }
  });

  add_step("remove_if", 5, [&] {
    auto mul = rnd();
    auto bit = rnd() % 64;
    auto condition = [&](auto &it) {
      return (((it * mul) >> bit) & 1) == 0;
    };
    td::table_remove_if(tbl, condition);
    td::table_remove_if(ref, condition);
  });

  td::RandomSteps runner(std::move(steps));
  for (size_t i = 0; i < 10000000; i++) {
    runner.step(rnd);
  }
}
