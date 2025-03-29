//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/ResourceManager.h"

#include "td/telegram/files/FileLoaderUtils.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/ScopeGuard.h"

#include <algorithm>

namespace td {

void ResourceManager::register_worker(ActorShared<FileLoaderActor> callback, int8 priority) {
  auto node_id = nodes_container_.create();
  auto *node_ptr = nodes_container_.get(node_id);
  *node_ptr = make_unique<Node>();
  auto *node = (*node_ptr).get();
  CHECK(node);
  node->node_id = node_id;
  node->callback_ = std::move(callback);

  add_node(node_id, priority);
  send_closure(node->callback_, &FileLoaderActor::set_resource_manager, actor_shared(this, node_id));
}

void ResourceManager::update_priority(int8 priority) {
  if (stop_flag_) {
    return;
  }
  auto node_id = get_link_token();
  if (!remove_node(node_id)) {
    return;
  }
  add_node(node_id, priority);
}

void ResourceManager::update_resources(const ResourceState &resource_state) {
  if (stop_flag_) {
    return;
  }
  auto node_id = get_link_token();
  auto node_ptr = nodes_container_.get(node_id);
  if (node_ptr == nullptr) {
    return;
  }
  auto node = (*node_ptr).get();
  CHECK(node);
  VLOG(file_loader) << "Before total: " << resource_state_ << "; node " << node_id << ": " << node->resource_state_;
  resource_state_ -= node->resource_state_;
  node->resource_state_.update_master(resource_state);
  resource_state_ += node->resource_state_;
  VLOG(file_loader) << "After total: " << resource_state_ << "; node " << node_id << ": " << node->resource_state_;

  if (mode_ == Mode::Greedy) {
    add_to_heap(node);
  }
  loop();
}

void ResourceManager::hangup() {
  stop_flag_ = true;
  loop();
}

void ResourceManager::hangup_shared() {
  auto node_id = get_link_token();
  auto node_ptr = nodes_container_.get(node_id);
  if (node_ptr == nullptr) {
    return;
  }
  auto node = (*node_ptr).get();
  CHECK(node);
  if (node->in_heap()) {
    by_estimated_extra_.erase(node->as_heap_node());
  }
  resource_state_ -= node->resource_state_;
  remove_node(node_id);
  nodes_container_.erase(node_id);
  loop();
}

void ResourceManager::add_to_heap(Node *node) {
  auto *heap_node = node->as_heap_node();
  auto key = node->resource_state_.estimated_extra();
  if (heap_node->in_heap()) {
    if (key != 0) {
      by_estimated_extra_.fix(key, heap_node);
    } else {
      by_estimated_extra_.erase(heap_node);
    }
  } else {
    if (key != 0) {
      by_estimated_extra_.insert(key, heap_node);
    }
  }
}

bool ResourceManager::satisfy_node(NodeId file_node_id) {
  auto file_node_ptr = nodes_container_.get(file_node_id);
  CHECK(file_node_ptr);
  auto file_node = (*file_node_ptr).get();
  CHECK(file_node);
  auto part_size = narrow_cast<int64>(file_node->resource_state_.unit_size());
  auto need = file_node->resource_state_.estimated_extra();
  VLOG(file_loader) << tag("need", need) << tag("part_size", part_size);
  need = (need + part_size - 1) / part_size * part_size;
  VLOG(file_loader) << tag("need", need);
  if (need == 0) {
    return true;
  }
  auto give = resource_state_.unused();
  give = min(need, give);
  give -= give % part_size;
  VLOG(file_loader) << tag("give", give);
  if (give == 0) {
    return false;
  }
  resource_state_.start_use(give);
  file_node->resource_state_.update_limit(give);
  send_closure(file_node->callback_, &FileLoaderActor::update_resources, file_node->resource_state_);
  return true;
}

void ResourceManager::loop() {
  if (stop_flag_) {
    if (nodes_container_.empty()) {
      stop();
    }
    return;
  }
  auto active_limit = resource_state_.active_limit();
  resource_state_.update_limit(max_resource_limit_ - active_limit);
  LOG(INFO) << tag("unused", resource_state_.unused());

  if (mode_ == Mode::Greedy) {
    std::vector<Node *> to_add;
    while (!by_estimated_extra_.empty()) {
      auto *node = Node::from_heap_node(by_estimated_extra_.pop());
      SCOPE_EXIT {
        to_add.push_back(node);
      };
      if (!satisfy_node(node->node_id)) {
        break;
      }
    }
    for (auto *node : to_add) {
      add_to_heap(node);
    }
  } else if (mode_ == Mode::Baseline) {
    // plain
    for (auto &it : to_xload_) {
      auto file_node_id = it.second;
      if (!satisfy_node(file_node_id)) {
        break;
      }
    }
  }
}

void ResourceManager::add_node(NodeId node_id, int8 priority) {
  if (priority >= 0) {
    auto it = std::find_if(to_xload_.begin(), to_xload_.end(), [&](auto &x) { return x.first <= priority; });
    to_xload_.insert(it, std::make_pair(priority, node_id));
  } else {
    auto it = std::find_if(to_xload_.begin(), to_xload_.end(), [&](auto &x) { return x.first < -priority; });
    to_xload_.insert(it, std::make_pair(narrow_cast<int8>(-priority), node_id));
  }
}

bool ResourceManager::remove_node(NodeId node_id) {
  auto it = std::find_if(to_xload_.begin(), to_xload_.end(), [&](auto &x) { return x.second == node_id; });
  if (it != to_xload_.end()) {
    to_xload_.erase(it);
    return true;
  }
  return false;
}

}  // namespace td
