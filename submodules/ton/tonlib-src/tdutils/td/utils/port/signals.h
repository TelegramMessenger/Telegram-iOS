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

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

Status setup_signals_alt_stack() TD_WARN_UNUSED_RESULT;

enum class SignalType { Abort, Error, Quit, Pipe, HangUp, User, Other };

Status set_signal_handler(SignalType type, void (*func)(int sig)) TD_WARN_UNUSED_RESULT;

Status set_extended_signal_handler(SignalType type, void (*func)(int sig, void *addr)) TD_WARN_UNUSED_RESULT;

Status set_runtime_signal_handler(int runtime_signal_number, void (*func)(int sig)) TD_WARN_UNUSED_RESULT;

Status ignore_signal(SignalType type) TD_WARN_UNUSED_RESULT;

// writes data to the standard error stream in a signal-safe way
void signal_safe_write(Slice data, bool add_header = true);

void signal_safe_write_signal_number(int sig, bool add_header = true);

void signal_safe_write_pointer(void *p, bool add_header = true);

Status set_default_failure_signal_handler();

}  // namespace td
