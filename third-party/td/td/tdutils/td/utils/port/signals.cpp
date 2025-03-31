//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/signals.h"

#include "td/utils/port/config.h"
#include "td/utils/port/stacktrace.h"
#include "td/utils/port/StdStreams.h"

#include "td/utils/common.h"
#include "td/utils/format.h"

#if TD_PORT_POSIX
#include <signal.h>
#include <sys/mman.h>
#include <unistd.h>
#endif
#if TD_PORT_WINDOWS
#include <csignal>
#endif

#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <limits>

namespace td {

#if TD_PORT_POSIX && !TD_DARWIN_TV_OS && !TD_DARWIN_WATCH_OS
static Status protect_memory(void *addr, size_t len) {
  if (mprotect(addr, len, PROT_NONE) != 0) {
    return OS_ERROR("mprotect failed");
  }
  return Status::OK();
}
#endif

Status setup_signals_alt_stack() {
#if TD_PORT_POSIX && !TD_DARWIN_TV_OS && !TD_DARWIN_WATCH_OS
  auto page_size = getpagesize();
  auto stack_size = (MINSIGSTKSZ + 16 * page_size - 1) / page_size * page_size;

  void *stack = mmap(nullptr, stack_size + 2 * page_size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
  if (stack == MAP_FAILED) {
    return OS_ERROR("Mmap failed");
  }

  TRY_STATUS(protect_memory(stack, page_size));
  TRY_STATUS(protect_memory(static_cast<char *>(stack) + stack_size + page_size, page_size));

  stack_t signal_stack;
  signal_stack.ss_sp = static_cast<char *>(stack) + page_size;
  signal_stack.ss_size = stack_size;
  signal_stack.ss_flags = 0;

  if (sigaltstack(&signal_stack, nullptr) != 0) {
    return OS_ERROR("sigaltstack failed");
  }
#endif
  return Status::OK();
}

#if TD_PORT_POSIX
static void set_handler(struct sigaction &act, decltype(act.sa_handler) handler) {
  act.sa_handler = handler;
}
static void set_handler(struct sigaction &act, decltype(act.sa_sigaction) handler) {
  act.sa_sigaction = handler;
  act.sa_flags |= SA_SIGINFO;
}
template <class F>
static Status set_signal_handler_impl(vector<int> &&signals, F func) {
  struct sigaction act;
  std::memset(&act, '\0', sizeof(act));

  sigemptyset(&act.sa_mask);
  for (auto signal : signals) {
    sigaddset(&act.sa_mask, signal);
  }
  act.sa_flags = SA_RESTART | SA_ONSTACK;
  set_handler(act, func);

  for (auto signal : signals) {
    if (sigaction(signal, &act, nullptr) != 0) {
      return OS_ERROR("sigaction failed");
    }
  }
  return Status::OK();
}

static vector<int> get_native_signals(SignalType type) {
  switch (type) {
    case SignalType::Abort:
      return {SIGABRT, SIGXCPU, SIGXFSZ};
    case SignalType::Error:
      return {SIGILL, SIGFPE, SIGBUS, SIGSEGV, SIGSYS};
    case SignalType::Quit:
      return {SIGINT, SIGTERM, SIGQUIT};
    case SignalType::Pipe:
      return {SIGPIPE};
    case SignalType::HangUp:
      return {SIGHUP};
    case SignalType::User:
      return {SIGUSR1, SIGUSR2};
    case SignalType::Other:
      return {SIGTRAP, SIGALRM, SIGVTALRM, SIGPROF, SIGTSTP, SIGTTIN, SIGTTOU};
    default:
      return {};
  }
}
#elif TD_PORT_WINDOWS
using signal_handler = void (*)(int sig);
static signal_handler signal_handlers[NSIG] = {};

static void signal_handler_func(int sig) {
  std::signal(sig, signal_handler_func);
  auto handler = signal_handlers[sig];
  handler(sig);
}

static Status set_signal_handler_impl(vector<int> &&signals, void (*func)(int sig)) {
  for (auto signal : signals) {
    CHECK(0 <= signal && signal < NSIG);
    if (func != SIG_IGN && func != SIG_DFL) {
      signal_handlers[signal] = func;
      func = signal_handler_func;
    }
    if (std::signal(signal, func) == SIG_ERR) {
      return Status::Error("Failed to set signal handler");
    }
  }
  return Status::OK();
}

static vector<int> get_native_signals(SignalType type) {
  switch (type) {
    case SignalType::Abort:
      return {SIGABRT};
    case SignalType::Error:
      return {SIGILL, SIGFPE, SIGSEGV};
    case SignalType::Quit:
      return {SIGINT, SIGTERM};
    case SignalType::Pipe:
      return {};
    case SignalType::HangUp:
      return {};
    case SignalType::User:
      return {};
    case SignalType::Other:
      return {};
    default:
      return {};
  }
}
#endif

Status set_signal_handler(SignalType type, void (*func)(int sig)) {
  return set_signal_handler_impl(get_native_signals(type), func == nullptr ? SIG_DFL : func);
}

using extended_signal_handler = void (*)(int sig, void *addr);
static extended_signal_handler extended_signal_handlers[NSIG] = {};

#if TD_PORT_POSIX
static void siginfo_handler(int signum, siginfo_t *info, void *data) {
  auto handler = extended_signal_handlers[signum];
  handler(signum, info->si_addr);
}
#elif TD_PORT_WINDOWS
static void siginfo_handler(int signum) {
  auto handler = extended_signal_handlers[signum];
  handler(signum, nullptr);
}
#endif

Status set_extended_signal_handler(SignalType type, extended_signal_handler func) {
  CHECK(func != nullptr);
  auto signals = get_native_signals(type);
  for (auto signal : signals) {
    if (0 <= signal && signal < NSIG) {
      extended_signal_handlers[signal] = func;
    } else {
      UNREACHABLE();
    }
  }
  return set_signal_handler_impl(std::move(signals), siginfo_handler);
}

Status set_real_time_signal_handler(int real_time_signal_number, void (*func)(int)) {
#ifdef SIGRTMIN
  CHECK(SIGRTMIN + real_time_signal_number <= SIGRTMAX);
  return set_signal_handler_impl({SIGRTMIN + real_time_signal_number}, func == nullptr ? SIG_DFL : func);
#else
  return Status::OK();
#endif
}

Status ignore_signal(SignalType type) {
  return set_signal_handler_impl(get_native_signals(type), SIG_IGN);
}

static void signal_safe_append_int(char **s, Slice name, int number) {
  if (number < 0) {
    number = std::numeric_limits<int>::max();
  }

  *--*s = ' ';
  *--*s = ']';

  do {
    *--*s = static_cast<char>(number % 10 + '0');
    number /= 10;
  } while (number > 0);

  *--*s = ' ';

  for (auto pos = static_cast<int>(name.size()) - 1; pos >= 0; pos--) {
    *--*s = name[pos];
  }

  *--*s = '[';
}

static void signal_safe_write_data(Slice data) {
#if TD_PORT_POSIX
  while (!data.empty()) {
    auto res = write(2, data.begin(), data.size());
    if (res < 0 && errno == EINTR) {
      continue;
    }
    if (res <= 0) {
      break;
    }

    if (res > 0) {
      data.remove_prefix(res);
    }
  }
#elif TD_PORT_WINDOWS
#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP | WINAPI_PARTITION_SYSTEM)
  HANDLE stderr_handle = GetStdHandle(STD_ERROR_HANDLE);
  DWORD bytes_written;
  WriteFile(stderr_handle, data.data(), static_cast<DWORD>(data.size()), &bytes_written, nullptr);
#else
// there is no stderr
#endif
#endif
}

static int get_process_id() {
#if TD_PORT_POSIX
  return getpid();
#elif TD_PORT_WINDOWS
  return GetCurrentProcessId();
#endif
}

void signal_safe_write(Slice data, bool add_header) {
  auto old_errno = errno;

  if (add_header) {
    constexpr size_t HEADER_BUF_SIZE = 100;
    char header[HEADER_BUF_SIZE];
    char *header_end = header + HEADER_BUF_SIZE;
    char *header_begin = header_end;

    signal_safe_append_int(&header_begin, "time", static_cast<int>(std::time(nullptr)));
    signal_safe_append_int(&header_begin, "pid", get_process_id());

    signal_safe_write_data(Slice(header_begin, header_end));
  }

  signal_safe_write_data(data);

  errno = old_errno;
}

void signal_safe_write_signal_number(int sig, bool add_header) {
  char buf[100];
  char *end = buf + sizeof(buf);
  char *ptr = end;
  *--ptr = '\n';
  do {
    *--ptr = static_cast<char>(sig % 10 + '0');
    sig /= 10;
  } while (sig != 0);

  ptr -= 8;
  std::memcpy(ptr, "Signal: ", 8);
  signal_safe_write(Slice(ptr, end), add_header);
}

void signal_safe_write_pointer(void *p, bool add_header) {
  auto addr = reinterpret_cast<std::uintptr_t>(p);
  char buf[100];
  char *end = buf + sizeof(buf);
  char *ptr = end;
  *--ptr = '\n';
  do {
    *--ptr = format::hex_digit(addr % 16);
    addr /= 16;
  } while (addr != 0);
  *--ptr = 'x';
  *--ptr = '0';
  ptr -= 9;
  std::memcpy(ptr, "Address: ", 9);
  signal_safe_write(Slice(ptr, end), add_header);
}

static void block_stdin() {
#if TD_PORT_POSIX
  Stdin().get_native_fd().set_is_blocking(true).ignore();
#endif
}

static void default_failure_signal_handler(int sig) {
  Stacktrace::init();
  signal_safe_write_signal_number(sig);

  Stacktrace::PrintOptions options;
  options.use_gdb = true;
  Stacktrace::print_to_stderr(options);

  block_stdin();
  _Exit(EXIT_FAILURE);
}

Status set_default_failure_signal_handler() {
#if TD_PORT_POSIX
  Stdin();  // init static variables before atexit
  std::atexit(block_stdin);
#endif
  TRY_STATUS(setup_signals_alt_stack());
  TRY_STATUS(set_signal_handler(SignalType::Abort, default_failure_signal_handler));
  TRY_STATUS(set_signal_handler(SignalType::Error, default_failure_signal_handler));
  return Status::OK();
}

}  // namespace td
