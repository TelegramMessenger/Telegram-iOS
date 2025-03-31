//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/Container.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/List.h"
#include "td/utils/logging.h"
#include "td/utils/optional.h"
#include "td/utils/Span.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/VectorQueue.h"

#include <functional>

namespace td {

struct ChainSchedulerBase {
  struct TaskWithParents {
    uint64 task_id{};
    vector<uint64> parents;
  };
};

template <class ExtraT = Unit>
class ChainScheduler final : public ChainSchedulerBase {
 public:
  using TaskId = uint64;
  using ChainId = uint64;

  TaskId create_task(Span<ChainId> chains, ExtraT extra = {});

  ExtraT *get_task_extra(TaskId task_id);

  optional<TaskWithParents> start_next_task();

  void pause_task(TaskId task_id);

  void finish_task(TaskId task_id);

  void reset_task(TaskId task_id);

  template <class F>
  void for_each(F &&f) {
    tasks_.for_each([&f](uint64, Task &task) { f(task.extra); });
  }

  template <class F>
  void for_each_dependent(TaskId task_id, F &&f) {
    auto *task = tasks_.get(task_id);
    CHECK(task != nullptr);
    FlatHashSet<TaskId> visited;
    bool check_for_collisions = task->chains.size() > 1;
    for (TaskChainInfo &task_chain_info : task->chains) {
      ChainInfo &chain_info = *task_chain_info.chain_info;
      chain_info.chain.foreach_child(&task_chain_info.chain_node, [&](TaskId task_id, uint64) {
        if (check_for_collisions && !visited.insert(task_id).second) {
          return;
        }
        f(task_id);
      });
    }
  }

 private:
  struct ChainNode : ListNode {
    TaskId task_id{};
    uint64 generation{};
  };

  class Chain {
   public:
    void add_task(ChainNode *node) {
      head_.put_back(node);
    }

    optional<TaskId> get_first() {
      if (head_.empty()) {
        return {};
      }
      return static_cast<ChainNode &>(*head_.get_next()).task_id;
    }

    optional<TaskId> get_child(ChainNode *chain_node) {
      if (chain_node->get_next() == head_.end()) {
        return {};
      }
      return static_cast<ChainNode &>(*chain_node->get_next()).task_id;
    }
    optional<ChainNode *> get_parent(ChainNode *chain_node) {
      if (chain_node->get_prev() == head_.end()) {
        return {};
      }
      return static_cast<ChainNode *>(chain_node->get_prev());
    }

    void finish_task(ChainNode *node) {
      node->remove();
    }

    bool empty() const {
      return head_.empty();
    }

    void foreach(std::function<void(TaskId, uint64)> f) const {
      for (auto it = head_.begin(); it != head_.end(); it = it->get_next()) {
        auto &node = static_cast<const ChainNode &>(*it);
        f(node.task_id, node.generation);
      }
    }
    void foreach_child(ListNode *start_node, std::function<void(TaskId, uint64)> f) const {
      for (auto it = start_node; it != head_.end(); it = it->get_next()) {
        auto &node = static_cast<const ChainNode &>(*it);
        f(node.task_id, node.generation);
      }
    }

   private:
    ListNode head_;
  };
  struct ChainInfo {
    Chain chain;
    uint32 active_tasks{};
    uint64 generation{1};
  };
  struct TaskChainInfo {
    ChainNode chain_node;
    ChainId chain_id{};
    ChainInfo *chain_info{};
  };
  struct Task {
    enum class State { Pending, Active, Paused } state{State::Pending};
    vector<TaskChainInfo> chains;
    ExtraT extra;
  };
  FlatHashMap<ChainId, unique_ptr<ChainInfo>> chains_;
  FlatHashMap<ChainId, TaskId> limited_tasks_;
  Container<Task> tasks_;
  VectorQueue<TaskId> pending_tasks_;

  ChainInfo &get_chain_info(ChainId chain_id) {
    auto &chain = chains_[chain_id];
    if (chain == nullptr) {
      chain = make_unique<ChainInfo>();
    }
    return *chain;
  }

  void try_start_task(TaskId task_id) {
    auto *task = tasks_.get(task_id);
    CHECK(task != nullptr);
    if (task->state != Task::State::Pending) {
      return;
    }
    for (TaskChainInfo &task_chain_info : task->chains) {
      auto o_parent = task_chain_info.chain_info->chain.get_parent(&task_chain_info.chain_node);

      if (o_parent) {
        if (o_parent.value()->generation != task_chain_info.chain_info->generation) {
          return;
        }
      }

      if (task_chain_info.chain_info->active_tasks >= 10) {
        limited_tasks_[task_chain_info.chain_id] = task_id;
        return;
      }
    }

    do_start_task(task_id, task);
  }

  void do_start_task(TaskId task_id, Task *task) {
    for (TaskChainInfo &task_chain_info : task->chains) {
      ChainInfo &chain_info = get_chain_info(task_chain_info.chain_id);
      chain_info.active_tasks++;
      task_chain_info.chain_node.generation = chain_info.generation;
    }
    task->state = Task::State::Active;

    pending_tasks_.push(task_id);
    for_each_child(task, [&](TaskId task_id) { try_start_task(task_id); });
  }

  template <class F>
  void for_each_child(Task *task, F &&f) {
    for (TaskChainInfo &task_chain_info : task->chains) {
      ChainInfo &chain_info = *task_chain_info.chain_info;
      auto o_child = chain_info.chain.get_child(&task_chain_info.chain_node);
      if (o_child) {
        f(o_child.value());
      }
    }
  }

  void inactivate_task(TaskId task_id, bool failed) {
    LOG(DEBUG) << "Inactivate " << task_id << " " << (failed ? "failed" : "finished");
    auto *task = tasks_.get(task_id);
    CHECK(task != nullptr);
    bool was_active = task->state == Task::State::Active;
    task->state = Task::State::Pending;
    for (TaskChainInfo &task_chain_info : task->chains) {
      ChainInfo &chain_info = *task_chain_info.chain_info;
      if (was_active) {
        chain_info.active_tasks--;
      }
      if (was_active && failed) {
        chain_info.generation = td::max(chain_info.generation, task_chain_info.chain_node.generation + 1);
      }

      auto it = limited_tasks_.find(task_chain_info.chain_id);
      if (it != limited_tasks_.end()) {
        auto limited_task_id = it->second;
        limited_tasks_.erase(it);
        if (limited_task_id != task_id) {
          try_start_task_later(limited_task_id);
        }
      }

      auto o_first = chain_info.chain.get_first();
      if (o_first) {
        auto first_task_id = o_first.unwrap();
        if (first_task_id != task_id) {
          try_start_task_later(first_task_id);
        }
      }
    }
  }

  void finish_chain_task(TaskChainInfo &task_chain_info) {
    auto &chain = task_chain_info.chain_info->chain;
    chain.finish_task(&task_chain_info.chain_node);
    if (chain.empty()) {
      chains_.erase(task_chain_info.chain_id);
    }
  }

  vector<TaskId> to_start_;

  void try_start_task_later(TaskId task_id) {
    LOG(DEBUG) << "Start later " << task_id;
    to_start_.push_back(task_id);
  }

  void flush_try_start_task() {
    auto moved_to_start = std::move(to_start_);
    for (auto task_id : moved_to_start) {
      try_start_task(task_id);
    }
    CHECK(to_start_.empty());
  }

  template <class ExtraTT>
  friend StringBuilder &operator<<(StringBuilder &sb, ChainScheduler<ExtraTT> &scheduler);
};

template <class ExtraT>
typename ChainScheduler<ExtraT>::TaskId ChainScheduler<ExtraT>::create_task(Span<ChainId> chains, ExtraT extra) {
  auto task_id = tasks_.create();
  Task &task = *tasks_.get(task_id);
  task.extra = std::move(extra);
  task.chains = transform(chains, [&](ChainId chain_id) {
    CHECK(chain_id != 0);
    TaskChainInfo task_chain_info;
    ChainInfo &chain_info = get_chain_info(chain_id);
    task_chain_info.chain_id = chain_id;
    task_chain_info.chain_info = &chain_info;
    task_chain_info.chain_node.task_id = task_id;
    task_chain_info.chain_node.generation = 0;
    return task_chain_info;
  });

  for (TaskChainInfo &task_chain_info : task.chains) {
    ChainInfo &chain_info = *task_chain_info.chain_info;
    chain_info.chain.add_task(&task_chain_info.chain_node);
  }

  try_start_task(task_id);
  return task_id;
}

// TODO: return reference
template <class ExtraT>
ExtraT *ChainScheduler<ExtraT>::get_task_extra(TaskId task_id) {  // may return nullptr
  auto *task = tasks_.get(task_id);
  if (task == nullptr) {
    return nullptr;
  }
  return &task->extra;
}

template <class ExtraT>
optional<ChainSchedulerBase::TaskWithParents> ChainScheduler<ExtraT>::start_next_task() {
  if (pending_tasks_.empty()) {
    return {};
  }
  auto task_id = pending_tasks_.pop();
  TaskWithParents res;
  res.task_id = task_id;
  auto *task = tasks_.get(task_id);
  CHECK(task != nullptr);
  for (TaskChainInfo &task_chain_info : task->chains) {
    Chain &chain = task_chain_info.chain_info->chain;
    auto o_parent = chain.get_parent(&task_chain_info.chain_node);
    if (o_parent) {
      res.parents.push_back(o_parent.value()->task_id);
    }
  }
  return res;
}

template <class ExtraT>
void ChainScheduler<ExtraT>::finish_task(TaskId task_id) {
  auto *task = tasks_.get(task_id);
  CHECK(task != nullptr);
  CHECK(to_start_.empty());

  inactivate_task(task_id, false);

  for_each_child(task, [&](TaskId task_id) { try_start_task_later(task_id); });

  for (TaskChainInfo &task_chain_info : task->chains) {
    finish_chain_task(task_chain_info);
  }

  tasks_.erase(task_id);
  flush_try_start_task();
}

template <class ExtraT>
void ChainScheduler<ExtraT>::reset_task(TaskId task_id) {
  CHECK(to_start_.empty());
  auto *task = tasks_.get(task_id);
  CHECK(task != nullptr);
  inactivate_task(task_id, true);
  try_start_task_later(task_id);
  flush_try_start_task();
}

template <class ExtraT>
void ChainScheduler<ExtraT>::pause_task(TaskId task_id) {
  auto *task = tasks_.get(task_id);
  CHECK(task != nullptr);
  inactivate_task(task_id, true);
  task->state = Task::State::Paused;
  flush_try_start_task();
}

template <class ExtraT>
StringBuilder &operator<<(StringBuilder &sb, ChainScheduler<ExtraT> &scheduler) {
  // 1 print chains
  sb << '\n';
  for (auto &it : scheduler.chains_) {
    CHECK(it.second != nullptr);
    sb << "ChainId{" << it.first << "}";
    sb << " active_cnt = " << it.second->active_tasks;
    sb << " g = " << it.second->generation;
    sb << ':';
    it.second->chain.foreach([&](typename ChainScheduler<ExtraT>::TaskId task_id, uint64 generation) {
      sb << ' ' << *scheduler.get_task_extra(task_id) << ':' << generation;
    });
    sb << '\n';
  }
  scheduler.tasks_.for_each([&](uint64, typename ChainScheduler<ExtraT>::Task &task) {
    sb << "Task: " << task.extra;
    sb << " state = " << static_cast<int>(task.state);
    for (auto &task_chain_info : task.chains) {
      sb << " g = " << task_chain_info.chain_node.generation;
      if (task_chain_info.chain_info->generation != task_chain_info.chain_node.generation) {
        sb << " chain_g = " << task_chain_info.chain_info->generation;
      }
    }
    sb << '\n';
  });
  return sb;
}

}  // namespace td
