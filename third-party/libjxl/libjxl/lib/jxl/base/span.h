// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_BASE_SPAN_H_
#define LIB_JXL_BASE_SPAN_H_

// Span (array view) is a non-owning container that provides cheap "cut"
// operations and could be used as "ArrayLike" data source for PaddedBytes.

#include <stddef.h>

#include "lib/jxl/base/status.h"

namespace jxl {

template <typename T>
class Span {
 public:
  constexpr Span() noexcept : Span(nullptr, 0) {}

  constexpr Span(T* array, size_t length) noexcept
      : ptr_(array), len_(length) {}

  template <size_t N>
  explicit constexpr Span(T (&a)[N]) noexcept : Span(a, N) {}

  template <typename ArrayLike>
  explicit constexpr Span(const ArrayLike& other) noexcept
      : Span(reinterpret_cast<T*>(other.data()), other.size()) {
    static_assert(sizeof(*other.data()) == sizeof(T),
                  "Incompatible type of source.");
  }

  constexpr T* data() const noexcept { return ptr_; }

  constexpr size_t size() const noexcept { return len_; }

  constexpr bool empty() const noexcept { return len_ == 0; }

  constexpr T& operator[](size_t i) const noexcept {
    // MSVC 2015 accepts this as constexpr, but not ptr_[i]
    return *(data() + i);
  }

  void remove_prefix(size_t n) noexcept {
    JXL_ASSERT(size() >= n);
    ptr_ += n;
    len_ -= n;
  }

 private:
  T* ptr_;
  size_t len_;
};

}  // namespace jxl

#endif  // LIB_JXL_BASE_SPAN_H_
