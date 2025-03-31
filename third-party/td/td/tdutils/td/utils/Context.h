//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/thread_local.h"

namespace td {

template <class Impl>
class Context {
 public:
  static Impl *get() {
    return context_;
  }
  class Guard {
   public:
    explicit Guard(Impl *new_context) {
      old_context_ = context_;
      context_ = new_context;
    }
    ~Guard() {
      context_ = old_context_;
    }
    Guard(const Guard &) = delete;
    Guard &operator=(const Guard &) = delete;
    Guard(Guard &&) = delete;
    Guard &operator=(Guard &&) = delete;

   private:
    Impl *old_context_;
  };

 private:
  static TD_THREAD_LOCAL Impl *context_;
};

template <class Impl>
TD_THREAD_LOCAL Impl *Context<Impl>::context_;

}  // namespace td
