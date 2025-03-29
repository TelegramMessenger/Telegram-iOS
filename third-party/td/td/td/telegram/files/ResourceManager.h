//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileLoaderActor.h"
#include "td/telegram/files/ResourceState.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Container.h"
#include "td/utils/Heap.h"

#include <utility>

namespace td {

class ResourceManager final : public Actor {
 public:
  enum class Mode : int32 { Baseline, Greedy };
  ResourceManager(int64 max_resource_limit, Mode mode) : max_resource_limit_(max_resource_limit), mode_(mode) {
  }
  // use through ActorShared
  void update_priority(int8 priority);
  void update_resources(const ResourceState &resource_state);

  void register_worker(ActorShared<FileLoaderActor> callback, int8 priority);

 private:
  int64 max_resource_limit_ = 0;
  Mode mode_;

  using NodeId = uint64;
  struct Node final : public HeapNode {
    NodeId node_id = 0;

    ResourceState resource_state_;
    ActorShared<FileLoaderActor> callback_;

    HeapNode *as_heap_node() {
      return static_cast<HeapNode *>(this);
    }
    static Node *from_heap_node(HeapNode *heap_node) {
      return static_cast<Node *>(heap_node);
    }
  };

  Container<unique_ptr<Node>> nodes_container_;
  vector<std::pair<int8, NodeId>> to_xload_;
  KHeap<int64> by_estimated_extra_;
  ResourceState resource_state_;

  ActorShared<> parent_;
  bool stop_flag_ = false;

  void hangup() final;

  void hangup_shared() final;

  void loop() final;

  void add_to_heap(Node *node);
  bool satisfy_node(NodeId file_node_id);
  void add_node(NodeId node_id, int8 priority);
  bool remove_node(NodeId node_id);
};

}  // namespace td
