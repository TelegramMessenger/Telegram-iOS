//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/int_types.h"
#include "td/utils/port/platform.h"

#include <type_traits>

namespace td {

template <class FunctionT>
struct member_function_class;

template <class ReturnType, class Type, class... Args>
struct member_function_class<ReturnType (Type::*)(Args...)> {
  using type = Type;
  static constexpr size_t argument_count() {
    return sizeof...(Args);
  }
};

template <class FunctionT>
using member_function_class_t = typename member_function_class<FunctionT>::type;

template <class FunctionT>
constexpr size_t member_function_argument_count() {
  return member_function_class<FunctionT>::argument_count();
}

// there is no std::is_trivially_copyable in libstdc++ before 5.0
#if __GLIBCXX__
#if TD_CLANG || (TD_GCC && __GNUC__ >= 5)  // but clang >= 3.0 and g++ >= 5.0 supports __is_trivially_copyable
#define TD_IS_TRIVIALLY_COPYABLE(T) __is_trivially_copyable(T)
#else
#define TD_IS_TRIVIALLY_COPYABLE(T) __has_trivial_copy(T)
#endif
#else
#define TD_IS_TRIVIALLY_COPYABLE(T) ::std::is_trivially_copyable<T>::value
#endif

}  // namespace td
