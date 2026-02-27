// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_BASE_STATUS_H_
#define LIB_JXL_BASE_STATUS_H_

// Error handling: Status return type + helper macros.

#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <type_traits>
#include <utility>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/sanitizer_definitions.h"

#if JXL_ADDRESS_SANITIZER || JXL_MEMORY_SANITIZER || JXL_THREAD_SANITIZER
#include "sanitizer/common_interface_defs.h"  // __sanitizer_print_stack_trace
#endif                                        // defined(*_SANITIZER)

namespace jxl {

// Uncomment to abort when JXL_FAILURE or JXL_STATUS with a fatal error is
// reached:
// #define JXL_CRASH_ON_ERROR

#ifndef JXL_ENABLE_ASSERT
#define JXL_ENABLE_ASSERT 1
#endif

#ifndef JXL_ENABLE_CHECK
#define JXL_ENABLE_CHECK 1
#endif

// Pass -DJXL_DEBUG_ON_ERROR at compile time to print debug messages when a
// function returns JXL_FAILURE or calls JXL_NOTIFY_ERROR. Note that this is
// irrelevant if you also pass -DJXL_CRASH_ON_ERROR.
#if defined(JXL_DEBUG_ON_ERROR) || defined(JXL_CRASH_ON_ERROR)
#undef JXL_DEBUG_ON_ERROR
#define JXL_DEBUG_ON_ERROR 1
#else  // JXL_DEBUG_ON_ERROR || JXL_CRASH_ON_ERROR
#ifdef NDEBUG
#define JXL_DEBUG_ON_ERROR 0
#else  // NDEBUG
#define JXL_DEBUG_ON_ERROR 1
#endif  // NDEBUG
#endif  // JXL_DEBUG_ON_ERROR || JXL_CRASH_ON_ERROR

// Pass -DJXL_DEBUG_ON_ALL_ERROR at compile time to print debug messages on
// all error (fatal and non-fatal) status. This implies JXL_DEBUG_ON_ERROR.
#if defined(JXL_DEBUG_ON_ALL_ERROR)
#undef JXL_DEBUG_ON_ALL_ERROR
#define JXL_DEBUG_ON_ALL_ERROR 1
// JXL_DEBUG_ON_ALL_ERROR implies JXL_DEBUG_ON_ERROR too.
#undef JXL_DEBUG_ON_ERROR
#define JXL_DEBUG_ON_ERROR 1
#else  // JXL_DEBUG_ON_ALL_ERROR
#define JXL_DEBUG_ON_ALL_ERROR 0
#endif  // JXL_DEBUG_ON_ALL_ERROR

// The Verbose level for the library
#ifndef JXL_DEBUG_V_LEVEL
#define JXL_DEBUG_V_LEVEL 0
#endif  // JXL_DEBUG_V_LEVEL

// Pass -DJXL_DEBUG_ON_ABORT={0,1} to force disable/enable the debug messages on
// JXL_ASSERT, JXL_CHECK and JXL_ABORT.
#ifndef JXL_DEBUG_ON_ABORT
#define JXL_DEBUG_ON_ABORT JXL_DEBUG_ON_ERROR
#endif  // JXL_DEBUG_ON_ABORT

// Print a debug message on standard error. You should use the JXL_DEBUG macro
// instead of calling Debug directly. This function returns false, so it can be
// used as a return value in JXL_FAILURE.
JXL_FORMAT(1, 2)
inline JXL_NOINLINE bool Debug(const char* format, ...) {
  va_list args;
  va_start(args, format);
  vfprintf(stderr, format, args);
  va_end(args);
  return false;
}

// Print a debug message on standard error if "enabled" is true. "enabled" is
// normally a macro that evaluates to 0 or 1 at compile time, so the Debug
// function is never called and optimized out in release builds. Note that the
// arguments are compiled but not evaluated when enabled is false. The format
// string must be a explicit string in the call, for example:
//   JXL_DEBUG(JXL_DEBUG_MYMODULE, "my module message: %d", some_var);
// Add a header at the top of your module's .cc or .h file (depending on whether
// you have JXL_DEBUG calls from the .h as well) like this:
//   #ifndef JXL_DEBUG_MYMODULE
//   #define JXL_DEBUG_MYMODULE 0
//   #endif JXL_DEBUG_MYMODULE
#define JXL_DEBUG_TMP(format, ...) \
  ::jxl::Debug(("%s:%d: " format "\n"), __FILE__, __LINE__, ##__VA_ARGS__)

#define JXL_DEBUG(enabled, format, ...)     \
  do {                                      \
    if (enabled) {                          \
      JXL_DEBUG_TMP(format, ##__VA_ARGS__); \
    }                                       \
  } while (0)

// JXL_DEBUG version that prints the debug message if the global verbose level
// defined at compile time by JXL_DEBUG_V_LEVEL is greater or equal than the
// passed level.
#define JXL_DEBUG_V(level, format, ...) \
  JXL_DEBUG(level <= JXL_DEBUG_V_LEVEL, format, ##__VA_ARGS__)

// Warnings (via JXL_WARNING) are enabled by default in debug builds (opt and
// debug).
#ifdef JXL_DEBUG_WARNING
#undef JXL_DEBUG_WARNING
#define JXL_DEBUG_WARNING 1
#else  // JXL_DEBUG_WARNING
#ifdef NDEBUG
#define JXL_DEBUG_WARNING 0
#else  // JXL_DEBUG_WARNING
#define JXL_DEBUG_WARNING 1
#endif  // NDEBUG
#endif  // JXL_DEBUG_WARNING
#define JXL_WARNING(format, ...) \
  JXL_DEBUG(JXL_DEBUG_WARNING, format, ##__VA_ARGS__)

// Exits the program after printing a stack trace when possible.
JXL_NORETURN inline JXL_NOINLINE bool Abort() {
#if JXL_ADDRESS_SANITIZER || JXL_MEMORY_SANITIZER || JXL_THREAD_SANITIZER
  // If compiled with any sanitizer print a stack trace. This call doesn't crash
  // the program, instead the trap below will crash it also allowing gdb to
  // break there.
  __sanitizer_print_stack_trace();
#endif  // *_SANITIZER)

#if JXL_COMPILER_MSVC
  __debugbreak();
  abort();
#else
  __builtin_trap();
#endif
}

// Exits the program after printing file/line plus a formatted string.
#define JXL_ABORT(format, ...)                                              \
  ((JXL_DEBUG_ON_ABORT) && ::jxl::Debug(("%s:%d: JXL_ABORT: " format "\n"), \
                                        __FILE__, __LINE__, ##__VA_ARGS__), \
   ::jxl::Abort())

// Use this for code paths that are unreachable unless the code would change
// to make it reachable, in which case it will print a warning and abort in
// debug builds. In release builds no code is produced for this, so only use
// this if this path is really unreachable.
#define JXL_UNREACHABLE(format, ...)                                   \
  do {                                                                 \
    if (JXL_DEBUG_WARNING) {                                           \
      ::jxl::Debug(("%s:%d: JXL_UNREACHABLE: " format "\n"), __FILE__, \
                   __LINE__, ##__VA_ARGS__);                           \
      ::jxl::Abort();                                                  \
    } else {                                                           \
      JXL_UNREACHABLE_BUILTIN;                                         \
    }                                                                  \
  } while (0)

// Does not guarantee running the code, use only for debug mode checks.
#if JXL_ENABLE_ASSERT
#define JXL_ASSERT(condition)                                      \
  do {                                                             \
    if (!(condition)) {                                            \
      JXL_DEBUG(JXL_DEBUG_ON_ABORT, "JXL_ASSERT: %s", #condition); \
      ::jxl::Abort();                                              \
    }                                                              \
  } while (0)
#else
#define JXL_ASSERT(condition) \
  do {                        \
  } while (0)
#endif

// Define JXL_IS_DEBUG_BUILD that denotes asan, msan and other debug builds,
// but not opt or release.
#ifndef JXL_IS_DEBUG_BUILD
#if !defined(NDEBUG) || defined(ADDRESS_SANITIZER) ||         \
    defined(MEMORY_SANITIZER) || defined(THREAD_SANITIZER) || \
    defined(__clang_analyzer__)
#define JXL_IS_DEBUG_BUILD 1
#else
#define JXL_IS_DEBUG_BUILD 0
#endif
#endif  //  JXL_IS_DEBUG_BUILD

// Same as above, but only runs in debug builds (builds where NDEBUG is not
// defined). This is useful for slower asserts that we want to run more rarely
// than usual. These will run on asan, msan and other debug builds, but not in
// opt or release.
#if JXL_IS_DEBUG_BUILD
#define JXL_DASSERT(condition)                                      \
  do {                                                              \
    if (!(condition)) {                                             \
      JXL_DEBUG(JXL_DEBUG_ON_ABORT, "JXL_DASSERT: %s", #condition); \
      ::jxl::Abort();                                               \
    }                                                               \
  } while (0)
#else
#define JXL_DASSERT(condition) \
  do {                         \
  } while (0)
#endif

// Always runs the condition, so can be used for non-debug calls.
#if JXL_ENABLE_CHECK
#define JXL_CHECK(condition)                                      \
  do {                                                            \
    if (!(condition)) {                                           \
      JXL_DEBUG(JXL_DEBUG_ON_ABORT, "JXL_CHECK: %s", #condition); \
      ::jxl::Abort();                                             \
    }                                                             \
  } while (0)
#else
#define JXL_CHECK(condition) \
  do {                       \
    (void)(condition);       \
  } while (0)
#endif

// A jxl::Status value from a StatusCode or Status which prints a debug message
// when enabled.
#define JXL_STATUS(status, format, ...)                                        \
  ::jxl::StatusMessage(::jxl::Status(status), "%s:%d: " format "\n", __FILE__, \
                       __LINE__, ##__VA_ARGS__)

// Notify of an error but discard the resulting Status value. This is only
// useful for debug builds or when building with JXL_CRASH_ON_ERROR.
#define JXL_NOTIFY_ERROR(format, ...)                                      \
  (void)JXL_STATUS(::jxl::StatusCode::kGenericError, "JXL_ERROR: " format, \
                   ##__VA_ARGS__)

// An error Status with a message. The JXL_STATUS() macro will return a Status
// object with a kGenericError code, but the comma operator helps with
// clang-tidy inference and potentially with optimizations.
#define JXL_FAILURE(format, ...)                                              \
  ((void)JXL_STATUS(::jxl::StatusCode::kGenericError, "JXL_FAILURE: " format, \
                    ##__VA_ARGS__),                                           \
   ::jxl::Status(::jxl::StatusCode::kGenericError))

// Always evaluates the status exactly once, so can be used for non-debug calls.
// Returns from the current context if the passed Status expression is an error
// (fatal or non-fatal). The return value is the passed Status.
#define JXL_RETURN_IF_ERROR(status)                                       \
  do {                                                                    \
    ::jxl::Status jxl_return_if_error_status = (status);                  \
    if (!jxl_return_if_error_status) {                                    \
      (void)::jxl::StatusMessage(                                         \
          jxl_return_if_error_status,                                     \
          "%s:%d: JXL_RETURN_IF_ERROR code=%d: %s\n", __FILE__, __LINE__, \
          static_cast<int>(jxl_return_if_error_status.code()), #status);  \
      return jxl_return_if_error_status;                                  \
    }                                                                     \
  } while (0)

// As above, but without calling StatusMessage. Intended for bundles (see
// fields.h), which have numerous call sites (-> relevant for code size) and do
// not want to generate excessive messages when decoding partial headers.
#define JXL_QUIET_RETURN_IF_ERROR(status)                \
  do {                                                   \
    ::jxl::Status jxl_return_if_error_status = (status); \
    if (!jxl_return_if_error_status) {                   \
      return jxl_return_if_error_status;                 \
    }                                                    \
  } while (0)

enum class StatusCode : int32_t {
  // Non-fatal errors (negative values).
  kNotEnoughBytes = -1,

  // The only non-error status code.
  kOk = 0,

  // Fatal-errors (positive values)
  kGenericError = 1,
};

// Drop-in replacement for bool that raises compiler warnings if not used
// after being returned from a function. Example:
// Status LoadFile(...) { return true; } is more compact than
// bool JXL_MUST_USE_RESULT LoadFile(...) { return true; }
// In case of error, the status can carry an extra error code in its value which
// is split between fatal and non-fatal error codes.
class JXL_MUST_USE_RESULT Status {
 public:
  // We want implicit constructor from bool to allow returning "true" or "false"
  // on a function when using Status. "true" means kOk while "false" means a
  // generic fatal error.
  // NOLINTNEXTLINE(google-explicit-constructor)
  constexpr Status(bool ok)
      : code_(ok ? StatusCode::kOk : StatusCode::kGenericError) {}

  // NOLINTNEXTLINE(google-explicit-constructor)
  constexpr Status(StatusCode code) : code_(code) {}

  // We also want implicit cast to bool to check for return values of functions.
  // NOLINTNEXTLINE(google-explicit-constructor)
  constexpr operator bool() const { return code_ == StatusCode::kOk; }

  constexpr StatusCode code() const { return code_; }

  // Returns whether the status code is a fatal error.
  constexpr bool IsFatalError() const {
    return static_cast<int32_t>(code_) > 0;
  }

 private:
  StatusCode code_;
};

// Helper function to create a Status and print the debug message or abort when
// needed.
inline JXL_FORMAT(2, 3) Status
    StatusMessage(const Status status, const char* format, ...) {
  // This block will be optimized out when JXL_DEBUG_ON_ERROR and
  // JXL_DEBUG_ON_ALL_ERROR are both disabled.
  if ((JXL_DEBUG_ON_ERROR && status.IsFatalError()) ||
      (JXL_DEBUG_ON_ALL_ERROR && !status)) {
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
  }
#ifdef JXL_CRASH_ON_ERROR
  // JXL_CRASH_ON_ERROR means to Abort() only on non-fatal errors.
  if (status.IsFatalError()) {
    Abort();
  }
#endif  // JXL_CRASH_ON_ERROR
  return status;
}

template <typename T>
class JXL_MUST_USE_RESULT StatusOr {
  static_assert(!std::is_convertible<StatusCode, T>::value &&
                    !std::is_convertible<T, StatusCode>::value,
                "You cannot make a StatusOr with a type convertible from or to "
                "StatusCode");
  static_assert(std::is_move_constructible<T>::value &&
                    std::is_move_assignable<T>::value,
                "T must be move constructible and move assignable");

 public:
  // NOLINTNEXTLINE(google-explicit-constructor)
  StatusOr(StatusCode code) : code_(code) {
    JXL_ASSERT(code_ != StatusCode::kOk);
  }

  // NOLINTNEXTLINE(google-explicit-constructor)
  StatusOr(Status status) : StatusOr(status.code()) {}

  // NOLINTNEXTLINE(google-explicit-constructor)
  StatusOr(T&& value) : code_(StatusCode::kOk) {
    new (&storage_.data_) T(std::move(value));
  }

  StatusOr(StatusOr&& other) noexcept {
    if (other.ok()) {
      new (&storage_.data_) T(std::move(other.storage_.data_));
    }
    code_ = other.code_;
  }

  StatusOr& operator=(StatusOr&& other) noexcept {
    if (this == &other) return *this;
    if (ok() && other.ok()) {
      storage_.data_ = std::move(other.storage_.data_);
    } else if (other.ok()) {
      new (&storage_.data_) T(std::move(other.storage_.data_));
    } else if (ok()) {
      storage_.data_.~T();
    }
    code_ = other.code_;
    return *this;
  }

  StatusOr(const StatusOr&) = delete;
  StatusOr operator=(const StatusOr&) = delete;

  bool ok() const { return code_ == StatusCode::kOk; }
  Status status() const { return code_; }

  // Only call this if you are absolutely sure that `ok()` is true.
  // Ideally, never call this manually and rely on JXL_ASSIGN_OR_RETURN.
  T value() && {
    JXL_ASSERT(ok());
    return std::move(storage_.data_);
  }

  ~StatusOr() {
    if (code_ == StatusCode::kOk) {
      storage_.data_.~T();
    }
  }

 private:
  union Storage {
    char dummy_;
    T data_;
    Storage() {}
    ~Storage() {}
  } storage_;

  StatusCode code_;
};

#define JXL_ASSIGN_OR_RETURN(lhs, statusor) \
  PRIVATE_JXL_ASSIGN_OR_RETURN_IMPL(        \
      assign_or_return_temporary_variable##__LINE__, lhs, statusor)

// NOLINTBEGIN(bugprone-macro-parentheses)
#define PRIVATE_JXL_ASSIGN_OR_RETURN_IMPL(name, lhs, statusor) \
  auto name = std::move(statusor);                             \
  JXL_RETURN_IF_ERROR(name.status());                          \
  lhs = std::move(name).value();
// NOLINTEND(bugprone-macro-parentheses)

}  // namespace jxl

#endif  // LIB_JXL_BASE_STATUS_H_
