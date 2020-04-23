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

    Copyright 2020 Telegram Systems LLP
*/
#pragma once
#include "refcnt.hpp"
#include "td/actor/PromiseFuture.h"

namespace td {

template <typename S, typename T>
class BinaryPromiseMerger : public CntObject {
  Result<S> first_;
  Result<T> second_;
  Promise<std::pair<S, T>> promise_;
  std::atomic<int> pending_;

 public:
  BinaryPromiseMerger(Promise<std::pair<S, T>> promise) : promise_(std::move(promise)), pending_(2) {
  }
  static std::pair<Promise<S>, Promise<T>> split(Promise<std::pair<S, T>> promise) {
    auto ref = make_ref<BinaryPromiseMerger>(std::move(promise));
    auto& obj = ref.write();
    return std::make_pair(obj.left(), obj.right());
  }

 private:
  Promise<S> left() {
    return [this, self = Ref<BinaryPromiseMerger>(this)](Result<S> res) {
      first_ = std::move(res);
      work();
    };
  }
  Promise<T> right() {
    return [this, self = Ref<BinaryPromiseMerger>(this)](Result<T> res) {
      second_ = std::move(res);
      work();
    };
  }
  void work() {
    if (!--pending_) {
      if (first_.is_error()) {
        promise_.set_error(first_.move_as_error());
      } else if (second_.is_error()) {
        promise_.set_error(second_.move_as_error());
      } else {
        promise_.set_result(std::pair<S, T>(first_.move_as_ok(), second_.move_as_ok()));
      }
    }
  }
};

template <typename S, typename T>
std::pair<Promise<S>, Promise<T>> split_promise(Promise<std::pair<S, T>> promise) {
  return BinaryPromiseMerger<S, T>::split(std::move(promise));
}

}  // namespace td
