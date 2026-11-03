//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

// clang-format off

/*** Platform macros ***/
#if defined(_WIN32) || defined(_WINDOWS) // _WINDOWS is defined by CMake
  #if defined(__cplusplus_winrt)
    #define TD_WINRT 1
  #endif
  #if defined(__cplusplus_cli)
    #define TD_CLI 1
  #endif
  #define TD_WINDOWS 1
#elif defined(__APPLE__)
  #include "TargetConditionals.h"
  #if TARGET_OS_IPHONE
    // iOS/iPadOS/watchOS/tvOS
    #if TARGET_OS_IOS
      #define TD_DARWIN_IOS 1
    #elif TARGET_OS_TV
      #define TD_DARWIN_TV_OS 1
    #elif TARGET_OS_VISION
      #define TD_DARWIN_VISION_OS 1
    #elif TARGET_OS_WATCH
      #define TD_DARWIN_WATCH_OS 1
    #else
      #define TD_DARWIN_UNKNOWN 1
    #endif
  #elif TARGET_OS_MAC
    // Other kinds of macOS
    #define TD_DARWIN_MAC 1
  #else
    #define TD_DARWIN_UNKNOWN 1
  #endif
  #define TD_DARWIN 1
#elif defined(ANDROID) || defined(__ANDROID__)
  #define TD_ANDROID 1
#elif defined(TIZEN_DEPRECATION)
  #define TD_TIZEN 1
#elif defined(__linux__)
  #define TD_LINUX 1
#elif defined(__FreeBSD__)
  #define TD_FREEBSD 1
#elif defined(__OpenBSD__)
  #define TD_OPENBSD 1
#elif defined(__NetBSD__)
  #define TD_NETBSD 1
#elif defined(__CYGWIN__)
  #define TD_CYGWIN 1
#elif defined(__EMSCRIPTEN__)
  #define TD_EMSCRIPTEN 1
#elif defined(__sun)
  #define TD_SOLARIS 1
  // TD_ILLUMOS can be already defined by CMake
#elif defined(__unix__)  // all unices not caught above
  #define TD_UNIX_UNKNOWN 1
  #define TD_CYGWIN 1
#else
  #error "Probably unsupported platform. Feel free to remove the error and try to recompile"
#endif

#if defined(__ICC) || defined(__INTEL_COMPILER)
  #define TD_INTEL 1
#elif defined(__clang__)
  #define TD_CLANG 1
#elif defined(__GNUC__) || defined(__GNUG__)
  #define TD_GCC 1
#elif defined(_MSC_VER)
  #define TD_MSVC 1
#else
  #define TD_COMPILER_UNKNOWN 1
#endif

#if TD_GCC || TD_CLANG || TD_INTEL
  #define TD_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
  #define TD_ATTRIBUTE_FORMAT_PRINTF(from, to) __attribute__((format(printf, from, to)))
#else
  #define TD_WARN_UNUSED_RESULT
  #define TD_ATTRIBUTE_FORMAT_PRINTF(from, to)
#endif

#if TD_MSVC
  #define TD_UNUSED __pragma(warning(suppress : 4100))
#elif TD_CLANG || TD_GCC || TD_INTEL
  #define TD_UNUSED __attribute__((unused))
#else
  #define TD_UNUSED
#endif

#define TD_HAVE_ATOMIC_SHARED_PTR 1

// No atomic operations on std::shared_ptr in libstdc++ before 5.0
// see https://gcc.gnu.org/bugzilla/show_bug.cgi?id=57250
#ifdef __GLIBCXX__
  #undef TD_HAVE_ATOMIC_SHARED_PTR
#endif

// Also, no atomic operations on std::shared_ptr when clang __has_feature(cxx_atomic) is defined and zero
#if defined(__has_feature)
  #if !__has_feature(cxx_atomic)
    #undef TD_HAVE_ATOMIC_SHARED_PTR
  #endif
#endif

#ifdef TD_HAVE_ATOMIC_SHARED_PTR // unfortunately we can't check for __GLIBCXX__ here, it is not defined yet
  #undef TD_HAVE_ATOMIC_SHARED_PTR
#endif

#define TD_CONCURRENCY_PAD 128

#if !TD_WINDOWS && defined(__SIZEOF_INT128__)
#define TD_HAVE_INT128 1
#endif

// clang-format on
