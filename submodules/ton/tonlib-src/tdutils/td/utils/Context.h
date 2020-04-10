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
