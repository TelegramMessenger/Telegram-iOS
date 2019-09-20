/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
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
  // ensure that no destructors were added during destructors invokation
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
