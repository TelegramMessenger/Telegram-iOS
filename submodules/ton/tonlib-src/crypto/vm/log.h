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
#pragma once

#include "td/utils/logging.h"

#define VM_LOG_IMPL(st, mask)                                                             \
  LOG_IMPL_FULL(get_log_interface(st), get_log_options(st), DEBUG, VERBOSITY_NAME(DEBUG), \
                (get_log_mask(st) & mask) != 0, "")

#define VM_LOG(st) VM_LOG_IMPL(st, 1)
#define VM_LOG_MASK(st, mask) VM_LOG_IMPL(st, mask)

namespace vm {
struct VmLog {
  td::LogInterface *log_interface{td::log_interface};
  td::LogOptions log_options{td::log_options};
  enum { DumpStack = 2 };
  int log_mask{1};
};

template <class State>
td::LogInterface &get_log_interface(State *st) {
  return st ? *st->get_log().log_interface : *::td::log_interface;
}

template <class State>
auto get_log_options(State *st) {
  return st ? st->get_log().log_options : ::td::log_options;
}

template <class State>
auto get_log_mask(State *st) {
  return st ? st->get_log().log_mask : 1;
}

}  // namespace vm
