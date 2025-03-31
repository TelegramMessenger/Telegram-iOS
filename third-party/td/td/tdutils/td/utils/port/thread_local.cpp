//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/thread_local.h"

namespace td {

namespace detail {

static TD_THREAD_LOCAL int32 thread_id_;
static TD_THREAD_LOCAL std::vector<unique_ptr<Destructor>> *thread_local_destructors;

void add_thread_local_destructor(unique_ptr<Destructor> destructor) {
  if (thread_local_destructors == nullptr) {
    thread_local_destructors = new std::vector<unique_ptr<Destructor>>();
  }
  thread_local_destructors->push_back(std::move(destructor));
}

}  // namespace detail

void clear_thread_locals() {
  // ensure that no destructors were added during destructors invocation
  auto to_delete = detail::thread_local_destructors;
  detail::thread_local_destructors = nullptr;
  delete to_delete;
  CHECK(detail::thread_local_destructors == nullptr);
}

void set_thread_id(int32 id) {
  detail::thread_id_ = id;
}

int32 get_thread_id() {
  return detail::thread_id_;
}

}  // namespace td
