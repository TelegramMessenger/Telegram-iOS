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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include <array>
#include <cstddef>
#include <functional>

constexpr std::size_t BACKTRACE_SHIFT = 2;
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
