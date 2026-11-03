//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include <array>
#include <cstddef>
#include <functional>

constexpr std::size_t BACKTRACE_SHIFT = 1;
constexpr std::size_t BACKTRACE_HASHED_LENGTH = 6;
constexpr std::size_t BACKTRACE_LENGTH = 10;

using Backtrace = std::array<void *, BACKTRACE_LENGTH>;
struct AllocInfo {
  Backtrace backtrace;
  std::size_t size;
};

bool is_memprof_on();
std::size_t get_ht_size();
double get_fast_backtrace_success_rate();
void dump_alloc(const std::function<void(const AllocInfo &)> &func);
std::size_t get_used_memory_size();
