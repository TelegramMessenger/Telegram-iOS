//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/config.h"

#include "td/utils/common.h"
#include "td/utils/Destructor.h"

#include <memory>
#include <utility>

namespace td {

// clang-format off
#if TD_GCC || TD_CLANG
  #define TD_THREAD_LOCAL __thread
#elif TD_INTEL || TD_MSVC
  #define TD_THREAD_LOCAL thread_local
#else
  #warning "TD_THREAD_LOCAL is not defined, trying 'thread_local'"
  #define TD_THREAD_LOCAL thread_local
#endif
// clang-format on

// If raw_ptr is not nullptr, allocate T as in std::make_unique<T>(args...) and store pointer into raw_ptr
template <class T, class P, class... ArgsT>
bool init_thread_local(P &raw_ptr, ArgsT &&...args);

// Destroy all thread locals, and store nullptr into corresponding pointers
void clear_thread_locals();

void set_thread_id(int32 id);

int32 get_thread_id();

namespace detail {
void add_thread_local_destructor(unique_ptr<Destructor> destructor);

template <class T, class P, class... ArgsT>
void do_init_thread_local(P &raw_ptr, ArgsT &&...args) {
  auto ptr = std::make_unique<T>(std::forward<ArgsT>(args)...);
  raw_ptr = ptr.get();

  detail::add_thread_local_destructor(create_destructor([ptr = std::move(ptr), &raw_ptr]() mutable {
    ptr.reset();
    raw_ptr = nullptr;
  }));
}
}  // namespace detail

template <class T, class P, class... ArgsT>
bool init_thread_local(P &raw_ptr, ArgsT &&...args) {
  if (likely(raw_ptr != nullptr)) {
    return false;
  }
  detail::do_init_thread_local<T>(raw_ptr, std::forward<ArgsT>(args)...);
  return true;
}

}  // namespace td
