//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

#include <cstring>
#include <utility>

namespace td {

namespace detail {

template <class SliceT>
class ParserImpl {
 public:
  explicit ParserImpl(SliceT data) : ptr_(data.begin()), end_(data.end()), status_() {
  }
  ParserImpl(ParserImpl &&other) noexcept : ptr_(other.ptr_), end_(other.end_), status_(std::move(other.status_)) {
    other.clear();
  }
  ParserImpl &operator=(ParserImpl &&other) noexcept {
    if (&other == this) {
      return *this;
    }
    ptr_ = other.ptr_;
    end_ = other.end_;
    status_ = std::move(other.status_);
    other.clear();
    return *this;
  }
  ParserImpl(const ParserImpl &) = delete;
  ParserImpl &operator=(const ParserImpl &) = delete;
  ~ParserImpl() = default;

  bool empty() const {
    return ptr_ == end_;
  }
  void clear() {
    ptr_ = SliceT().begin();
    end_ = ptr_;
    status_ = Status::OK();
  }

  SliceT read_till_nofail(char c) {
    if (status_.is_error()) {
      return SliceT();
    }
    auto till = static_cast<decltype(ptr_)>(std::memchr(ptr_, c, end_ - ptr_));
    if (till == nullptr) {
      till = end_;
    }
    SliceT result(ptr_, till);
    ptr_ = till;
    return result;
  }

  SliceT read_till_nofail(Slice str) {
    if (status_.is_error()) {
      return SliceT();
    }
    auto best_till = end_;
    for (auto c : str) {
      auto till = static_cast<decltype(ptr_)>(std::memchr(ptr_, c, end_ - ptr_));
      if (till != nullptr && till < best_till) {
        best_till = till;
      }
    }
    SliceT result(ptr_, best_till);
    ptr_ = best_till;
    return result;
  }

  template <class F>
  SliceT read_while(const F &f) {
    auto save_ptr = ptr_;
    while (ptr_ != end_ && f(*ptr_)) {
      ptr_++;
    }
    return SliceT(save_ptr, ptr_);
  }
  SliceT read_all() {
    auto save_ptr = ptr_;
    ptr_ = end_;
    return SliceT(save_ptr, ptr_);
  }

  SliceT read_till(char c) {
    if (status_.is_error()) {
      return SliceT();
    }
    SliceT res = read_till_nofail(c);
    if (ptr_ == end_ || ptr_[0] != c) {
      status_ = Status::Error(PSLICE() << "Read till '" << c << "' failed");
      return SliceT();
    }
    return res;
  }

  char peek_char() {
    if (ptr_ == end_) {
      return 0;
    }
    return *ptr_;
  }

  char *ptr() {
    return ptr_;
  }

  void skip_nofail(char c) {
    if (ptr_ != end_ && ptr_[0] == c) {
      ptr_++;
    }
  }
  void skip(char c) {
    if (status_.is_error()) {
      return;
    }
    if (ptr_ == end_ || ptr_[0] != c) {
      status_ = Status::Error(PSLICE() << "Skip '" << c << "' failed");
      return;
    }
    ptr_++;
  }
  bool try_skip(char c) {
    if (ptr_ != end_ && ptr_[0] == c) {
      ptr_++;
      return true;
    }
    return false;
  }

  bool try_skip(Slice prefix) {
    if (prefix.size() > static_cast<size_t>(end_ - ptr_) || prefix != Slice(ptr_, prefix.size())) {
      return false;
    }
    advance(prefix.size());
    return true;
  }

  void skip_till_not(Slice str) {
    while (ptr_ != end_) {
      if (std::memchr(str.data(), *ptr_, str.size()) == nullptr) {
        break;
      }
      ptr_++;
    }
  }
  void skip_whitespaces() {
    skip_till_not(" \t\r\n");
  }
  SliceT read_word() {
    skip_whitespaces();
    return read_till_nofail(" \t\r\n");
  }

  SliceT data() const {
    return SliceT(ptr_, end_);
  }

  Status &status() {
    return status_;
  }

  void advance(size_t diff) {
    ptr_ += diff;
    CHECK(ptr_ <= end_);
  }

 private:
  decltype(std::declval<SliceT>().begin()) ptr_;
  decltype(std::declval<SliceT>().end()) end_;
  Status status_;
};

}  // namespace detail

using Parser = detail::ParserImpl<MutableSlice>;
using ConstParser = detail::ParserImpl<Slice>;

}  // namespace td
