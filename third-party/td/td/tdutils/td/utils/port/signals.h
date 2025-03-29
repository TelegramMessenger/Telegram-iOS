//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

Status setup_signals_alt_stack() TD_WARN_UNUSED_RESULT;

enum class SignalType { Abort, Error, Quit, Pipe, HangUp, User, Other };

Status set_signal_handler(SignalType type, void (*func)(int sig)) TD_WARN_UNUSED_RESULT;

Status set_extended_signal_handler(SignalType type, void (*func)(int sig, void *addr)) TD_WARN_UNUSED_RESULT;

Status set_real_time_signal_handler(int real_time_signal_number, void (*func)(int sig)) TD_WARN_UNUSED_RESULT;

Status ignore_signal(SignalType type) TD_WARN_UNUSED_RESULT;

// writes data to the standard error stream in a signal-safe way
void signal_safe_write(Slice data, bool add_header = true);

void signal_safe_write_signal_number(int sig, bool add_header = true);

void signal_safe_write_pointer(void *p, bool add_header = true);

Status set_default_failure_signal_handler();

}  // namespace td
