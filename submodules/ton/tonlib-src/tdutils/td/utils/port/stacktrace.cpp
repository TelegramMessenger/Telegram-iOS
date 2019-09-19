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
#include "td/utils/port/stacktrace.h"

#include "td/utils/port/signals.h"

#if __GLIBC__
#include <execinfo.h>
#endif

#if TD_LINUX || TD_FREEBSD
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#if TD_LINUX
#include <sys/prctl.h>
#endif
#endif

namespace td {

namespace {

void print_backtrace(void) {
#if __GLIBC__
  void *buffer[128];
  int nptrs = backtrace(buffer, 128);
  signal_safe_write("------- Stack Backtrace -------\n", false);
  backtrace_symbols_fd(buffer, nptrs, 2);
  signal_safe_write("-------------------------------\n", false);
#endif
}

void print_backtrace_gdb(void) {
#if TD_LINUX || TD_FREEBSD
  char pid_buf[30];
  char *pid_buf_begin = pid_buf + sizeof(pid_buf);
  pid_t pid = getpid();
  *--pid_buf_begin = '\0';
  do {
    *--pid_buf_begin = static_cast<char>(pid % 10 + '0');
    pid /= 10;
  } while (pid > 0);

  char name_buf[512];
  ssize_t res = readlink("/proc/self/exe", name_buf, 511);  // TODO works only under Linux
  if (res >= 0) {
    name_buf[res] = 0;

#if TD_LINUX
    if (prctl(PR_SET_DUMPABLE, 1, 0, 0, 0) < 0) {
      signal_safe_write("Can't set dumpable\n");
      return;
    }
#if defined(PR_SET_PTRACER)
    // We can't use event fd because we are in a signal handler
    int fds[2];
    bool need_set_ptracer = true;
    if (pipe(fds) < 0) {
      need_set_ptracer = false;
      signal_safe_write("Can't create a pipe\n");
    }
#endif
#endif

    int child_pid = fork();
    if (child_pid < 0) {
      signal_safe_write("Can't fork() to run gdb\n");
      return;
    }
    if (!child_pid) {
#if TD_LINUX && defined(PR_SET_PTRACER)
      if (need_set_ptracer) {
        char c;
        if (read(fds[0], &c, 1) < 0) {
          signal_safe_write("Failed to read from pipe\n");
        }
      }
#endif
      dup2(2, 1);  // redirect output to stderr
      execlp("gdb", "gdb", "--batch", "-n", "-ex", "thread", "-ex", "thread apply all bt full", name_buf, pid_buf_begin,
             nullptr);
      return;
    } else {
#if TD_LINUX && defined(PR_SET_PTRACER)
      if (need_set_ptracer) {
        if (prctl(PR_SET_PTRACER, child_pid, 0, 0, 0) < 0) {
          signal_safe_write("Can't set ptracer\n");
        }
        if (write(fds[1], "a", 1) != 1) {
          signal_safe_write("Can't write to pipe\n");
        }
      }
#endif
      waitpid(child_pid, nullptr, 0);
    }
  } else {
    signal_safe_write("Can't get name of executable file to pass to gdb\n");
  }
#endif
}

}  // namespace

void Stacktrace::print_to_stderr(const PrintOptions &options) {
  if (options.use_gdb) {
    print_backtrace_gdb();
  }
  print_backtrace();
}

}  // namespace td
