//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/MpscLinkQueue.h"
#include "td/utils/port/thread.h"
#include "td/utils/tests.h"

class NodeX final : public td::MpscLinkQueueImpl::Node {
 public:
  explicit NodeX(int value) : value_(value) {
  }
  td::MpscLinkQueueImpl::Node *to_mpsc_link_queue_node() {
    return static_cast<td::MpscLinkQueueImpl::Node *>(this);
  }
  static NodeX *from_mpsc_link_queue_node(td::MpscLinkQueueImpl::Node *node) {
    return static_cast<NodeX *>(node);
  }
  int value() {
    return value_;
  }

 private:
  int value_;
};
using QueueNode = td::MpscLinkQueueUniquePtrNode<NodeX>;

static QueueNode create_node(int value) {
  return QueueNode(td::make_unique<NodeX>(value));
}

TEST(MpscLinkQueue, one_thread) {
  td::MpscLinkQueue<QueueNode> queue;

  {
    queue.push(create_node(1));
    queue.push(create_node(2));
    queue.push(create_node(3));
    td::MpscLinkQueue<QueueNode>::Reader reader;
    queue.pop_all(reader);
    queue.push(create_node(4));
    queue.pop_all(reader);
    std::vector<int> v;
    while (auto node = reader.read()) {
      v.push_back(node.value().value());
    }
    LOG_CHECK((v == std::vector<int>{1, 2, 3, 4})) << v;

    v.clear();
    queue.push(create_node(5));
    queue.pop_all(reader);
    while (auto node = reader.read()) {
      v.push_back(node.value().value());
    }
    LOG_CHECK((v == std::vector<int>{5})) << v;
  }

  {
    queue.push_unsafe(create_node(3));
    queue.push_unsafe(create_node(2));
    queue.push_unsafe(create_node(1));
    queue.push_unsafe(create_node(0));
    td::MpscLinkQueue<QueueNode>::Reader reader;
    queue.pop_all_unsafe(reader);
    std::vector<int> v;
    while (auto node = reader.read()) {
      v.push_back(node.value().value());
    }
    LOG_CHECK((v == std::vector<int>{3, 2, 1, 0})) << v;
  }
}

#if !TD_THREAD_UNSUPPORTED
TEST(MpscLinkQueue, multi_thread) {
  td::MpscLinkQueue<QueueNode> queue;
  int threads_n = 10;
  int queries_n = 1000000;
  std::vector<int> next_value(threads_n);
  std::vector<td::thread> threads(threads_n);
  int thread_i = 0;
  for (auto &thread : threads) {
    thread = td::thread([&, id = thread_i] {
      for (int i = 0; i < queries_n; i++) {
        queue.push(create_node(i * threads_n + id));
      }
    });
    thread_i++;
  }

  int active_threads = threads_n;

  td::MpscLinkQueue<QueueNode>::Reader reader;
  while (active_threads) {
    queue.pop_all(reader);
    while (auto value = reader.read()) {
      auto x = value.value().value();
      auto thread_id = x % threads_n;
      x /= threads_n;
      CHECK(next_value[thread_id] == x);
      next_value[thread_id]++;
      if (x + 1 == queries_n) {
        active_threads--;
      }
    }
  }

  for (auto &thread : threads) {
    thread.join();
  }
}
#endif
