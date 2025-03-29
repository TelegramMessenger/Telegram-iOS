//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/tests.h"

#include "td/utils/common.h"
#include "td/utils/Heap.h"
#include "td/utils/Random.h"
#include "td/utils/Span.h"

#include <cstdio>
#include <set>
#include <utility>

TEST(Heap, sort_random_perm) {
  int n = 1000000;

  td::vector<int> v(n);
  for (int i = 0; i < n; i++) {
    v[i] = i;
  }
  td::Random::Xorshift128plus rnd(123);
  td::rand_shuffle(td::as_mutable_span(v), rnd);
  td::vector<td::HeapNode> nodes(n);
  td::KHeap<int> kheap;
  for (int i = 0; i < n; i++) {
    kheap.insert(v[i], &nodes[i]);
  }
  for (int i = 0; i < n; i++) {
    ASSERT_EQ(i, kheap.top_key());
    kheap.pop();
  }
}

class CheckedHeap {
 public:
  void set_max_size(int max_size) {
    nodes.resize(max_size);
    free_ids.resize(max_size);
    rev_ids.resize(max_size);
    for (int i = 0; i < max_size; i++) {
      free_ids[i] = max_size - i - 1;
      nodes[i].value = i;
    }
  }

  static void xx(int key, const td::HeapNode *heap_node) {
    const Node *node = static_cast<const Node *>(heap_node);
    std::fprintf(stderr, "(%d;%d)", node->key, node->value);
  }

  void check() const {
    for (auto p : set_heap) {
      std::fprintf(stderr, "(%d;%d)", p.first, p.second);
    }
    std::fprintf(stderr, "\n");
    kheap.for_each(xx);
    std::fprintf(stderr, "\n");
    kheap.check();
  }

  int random_id() const {
    CHECK(!empty());
    return ids[td::Random::fast(0, static_cast<int>(ids.size() - 1))];
  }

  std::size_t size() const {
    return ids.size();
  }

  bool empty() const {
    return ids.empty();
  }

  int top_key() const {
    CHECK(!empty());
    int res = set_heap.begin()->first;
    ASSERT_EQ(set_heap.size(), kheap.size());
    ASSERT_EQ(res, kheap.top_key());
    return res;
  }

  int insert(int key) {
    int id;
    if (free_ids.empty()) {
      UNREACHABLE();
      id = static_cast<int>(nodes.size());
      nodes.emplace_back(key, id);
      rev_ids.push_back(-1);
    } else {
      id = free_ids.back();
      free_ids.pop_back();
      nodes[id].key = key;
    }
    rev_ids[id] = static_cast<int>(ids.size());
    ids.push_back(id);
    kheap.insert(key, &nodes[id]);
    set_heap.emplace(key, id);
    return id;
  }

  void fix_key(int new_key, int id) {
    set_heap.erase(std::make_pair(nodes[id].key, id));
    nodes[id].key = new_key;
    kheap.fix(new_key, &nodes[id]);
    set_heap.emplace(new_key, id);
  }

  void erase(int id) {
    int pos = rev_ids[id];
    CHECK(pos != -1);
    ids[pos] = ids.back();
    rev_ids[ids[pos]] = pos;
    ids.pop_back();
    rev_ids[id] = -1;
    free_ids.push_back(id);

    kheap.erase(&nodes[id]);
    set_heap.erase(std::make_pair(nodes[id].key, id));
  }

  void pop() {
    CHECK(!empty());
    Node *node = static_cast<Node *>(kheap.pop());
    int id = node->value;
    ASSERT_EQ(node->key, set_heap.begin()->first);

    int pos = rev_ids[id];
    CHECK(pos != -1);
    ids[pos] = ids.back();
    rev_ids[ids[pos]] = pos;
    ids.pop_back();
    rev_ids[id] = -1;
    free_ids.push_back(id);

    set_heap.erase(std::make_pair(nodes[id].key, id));
  }

 private:
  struct Node final : public td::HeapNode {
    Node() = default;
    Node(int key, int value) : key(key), value(value) {
    }
    int key = 0;
    int value = 0;
  };
  td::vector<int> ids;
  td::vector<int> rev_ids;
  td::vector<int> free_ids;
  td::vector<Node> nodes;
  std::set<std::pair<int, int>> set_heap;
  td::KHeap<int> kheap;
};

TEST(Heap, random_events) {
  CheckedHeap heap;
  heap.set_max_size(1000);
  for (int i = 0; i < 300000; i++) {
    if (!heap.empty()) {
      heap.top_key();
    }

    int x = td::Random::fast(0, 4);
    if (heap.empty() || (x < 2 && heap.size() < 1000)) {
      heap.insert(td::Random::fast(0, 99));
    } else if (x < 3) {
      heap.fix_key(td::Random::fast(0, 99), heap.random_id());
    } else if (x < 4) {
      heap.erase(heap.random_id());
    } else if (x < 5) {
      heap.pop();
    }
    // heap.check();
  }
}
