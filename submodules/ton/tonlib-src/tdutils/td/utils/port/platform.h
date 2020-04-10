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
    // iOS/watchOS/tvOS
    #if TARGET_OS_IOS
      #define TD_DARWIN_IOS 1
    #elif TARGET_OS_TV
      #define TD_DARWIN_TV_OS 1
    #elif TARGET_OS_WATCH
      #define TD_DARWIN_WATCH_OS 1
    #else
      #warning "Probably unsupported Apple iPhone platform. Feel free to try to compile"
    #endif
  #elif TARGET_OS_MAC
    // Other kinds of macOS
    #define TD_DARWIN_MAC 1
  #else
    #warning "Probably unsupported Apple platform. Feel free to try to compile"
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
#elif defined(__unix__)  // all unices not caught above
  #warning "Probably unsupported Unix platform. Feel free to try to compile"
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
  #warning "Probably unsupported compiler. Feel free to try to compile"
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

// Also no atomic operations on std::shared_ptr when clang __has_feature(cxx_atomic) is defined and zero
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
