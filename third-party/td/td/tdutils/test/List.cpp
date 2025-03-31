//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/List.h"
#include "td/utils/MovableValue.h"
#include "td/utils/port/thread.h"
#include "td/utils/Random.h"
#include "td/utils/tests.h"
#include "td/utils/TsList.h"

#include <atomic>
#include <mutex>
#include <set>
#include <utility>

struct ListData {
  td::MovableValue<td::uint64> value_;
  td::MovableValue<bool> in_list_;

  ListData() = default;
  ListData(td::uint64 value, bool in_list) : value_(value), in_list_(in_list) {
  }
};

struct TrieNode final : public td::ListNode {
  TrieNode() = default;
  explicit TrieNode(ListData data) : data_(std::move(data)) {
  }

  ListData data_;
};

static ListData &get_data(TrieNode &node) {
  return node.data_;
}

static ListData &get_data(td::TsListNode<ListData> &node) {
  return node.get_data_unsafe();
}

static std::unique_lock<std::mutex> lock(td::ListNode &node) {
  return {};
}

static std::unique_lock<std::mutex> lock(td::TsListNode<ListData> &node) {
  return node.lock();
}

template <class ListNodeT, class ListRootT, class NodeT>
static void do_run_list_test(ListRootT &root, std::atomic<td::uint64> &id) {
  td::vector<NodeT> nodes;

  td::Random::Xorshift128plus rnd(123);

  auto next_id = [&] {
    return ++id;
  };
  auto add_node = [&] {
    if (nodes.size() >= 20) {
      return;
    }
    nodes.push_back(NodeT({next_id(), false}));
  };
  auto pop_node = [&] {
    if (nodes.empty()) {
      return;
    }
    nodes.pop_back();
  };
  auto random_node_index = [&] {
    CHECK(!nodes.empty());
    return rnd.fast(0, static_cast<int>(nodes.size()) - 1);
  };

  auto link_node = [&] {
    if (nodes.empty()) {
      return;
    }
    auto i = random_node_index();
    nodes[i].remove();
    get_data(nodes[i]) = ListData(next_id(), true);
    root.put(&nodes[i]);
  };
  auto unlink_node = [&] {
    if (nodes.empty()) {
      return;
    }
    auto i = random_node_index();
    nodes[i].remove();
    get_data(nodes[i]).in_list_ = false;
  };
  auto swap_nodes = [&] {
    if (nodes.empty()) {
      return;
    }
    auto i = random_node_index();
    auto j = random_node_index();
    std::swap(nodes[i], nodes[j]);
  };
  auto set_node = [&] {
    if (nodes.empty()) {
      return;
    }
    auto i = random_node_index();
    auto j = random_node_index();
    nodes[i] = std::move(nodes[j]);
  };
  auto validate = [&] {
    std::multiset<td::uint64> in_list;
    std::multiset<td::uint64> not_in_list;
    for (auto &node : nodes) {
      if (get_data(node).in_list_.get()) {
        in_list.insert(get_data(node).value_.get());
      } else {
        not_in_list.insert(get_data(node).value_.get());
      }
    }
    auto guard = lock(root);
    for (auto *begin = root.begin(), *end = root.end(); begin != end; begin = begin->get_next()) {
      auto &data = get_data(*static_cast<NodeT *>(begin));
      CHECK(data.in_list_.get());
      CHECK(data.value_.get() != 0);
      auto it = in_list.find(data.value_.get());
      if (it != in_list.end()) {
        in_list.erase(it);
      } else {
        ASSERT_EQ(0u, not_in_list.count(data.value_.get()));
      }
    }
    ASSERT_EQ(0u, in_list.size());
  };
  td::RandomSteps steps(
      {{add_node, 3}, {pop_node, 1}, {unlink_node, 1}, {link_node, 3}, {swap_nodes, 1}, {set_node, 1}, {validate, 1}});
  for (int i = 0; i < 10000; i++) {
    steps.step(rnd);
  }
}

TEST(Misc, List) {
  td::ListNode root;
  std::atomic<td::uint64> id{0};
  for (std::size_t i = 0; i < 4; i++) {
    do_run_list_test<td::ListNode, td::ListNode, TrieNode>(root, id);
  }
}

TEST(Misc, TsList) {
  td::TsList<ListData> root;
  std::atomic<td::uint64> id{0};
  for (std::size_t i = 0; i < 4; i++) {
    do_run_list_test<td::TsListNode<ListData>, td::TsList<ListData>, td::TsListNode<ListData>>(root, id);
  }
}

#if !TD_THREAD_UNSUPPORTED
TEST(Misc, TsListConcurrent) {
  td::TsList<ListData> root;
  td::vector<td::thread> threads;
  std::atomic<td::uint64> id{0};
  for (std::size_t i = 0; i < 4; i++) {
    threads.emplace_back(
        [&] { do_run_list_test<td::TsListNode<ListData>, td::TsList<ListData>, td::TsListNode<ListData>>(root, id); });
  }
}
#endif
