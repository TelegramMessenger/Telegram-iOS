//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/actor/MultiPromise.h"

#include "td/utils/logging.h"

namespace td {

void MultiPromiseActor::add_promise(Promise<Unit> &&promise) {
  promises_.emplace_back(std::move(promise));
  LOG(DEBUG) << "Add promise #" << promises_.size() << " to " << name_;
}

Promise<Unit> MultiPromiseActor::get_promise() {
  if (empty()) {
    register_actor(name_, this).release();
  }
  CHECK(!promises_.empty());

  PromiseActor<Unit> promise;
  FutureActor<Unit> future;
  init_promise_future(&promise, &future);

  future.set_event(EventCreator::raw(actor_id(), nullptr));
  futures_.emplace_back(std::move(future));
  LOG(DEBUG) << "Get promise #" << futures_.size() << " for " << name_;
  return create_promise_from_promise_actor(std::move(promise));
}

void MultiPromiseActor::raw_event(const Event::Raw &event) {
  received_results_++;
  LOG(DEBUG) << "Receive result #" << received_results_ << " out of " << futures_.size() << " for " << name_;
  if (received_results_ == futures_.size()) {
    if (!ignore_errors_) {
      for (auto &future : futures_) {
        auto result = future.move_as_result();
        if (result.is_error()) {
          return set_result(result.move_as_error());
        }
      }
    }
    return set_result(Unit());
  }
}

void MultiPromiseActor::set_ignore_errors(bool ignore_errors) {
  ignore_errors_ = ignore_errors;
}

void MultiPromiseActor::set_result(Result<Unit> &&result) {
  result_ = std::move(result);
  stop();
}

void MultiPromiseActor::tear_down() {
  LOG(DEBUG) << "Set result for " << promises_.size() << " promises in " << name_;

  // MultiPromiseActor should be cleared before it begins to send out result
  auto promises_copy = std::move(promises_);
  promises_.clear();
  auto futures_copy = std::move(futures_);
  futures_.clear();
  received_results_ = 0;
  auto result = std::move(result_);
  result_ = Unit();

  if (!promises_copy.empty()) {
    for (size_t i = 0; i + 1 < promises_copy.size(); i++) {
      promises_copy[i].set_result(result.clone());
    }
    promises_copy.back().set_result(std::move(result));
  }
}

size_t MultiPromiseActor::promise_count() const {
  return promises_.size();
}

void MultiPromiseActorSafe::add_promise(Promise<Unit> &&promise) {
  multi_promise_->add_promise(std::move(promise));
}

Promise<Unit> MultiPromiseActorSafe::get_promise() {
  return multi_promise_->get_promise();
}

void MultiPromiseActorSafe::set_ignore_errors(bool ignore_errors) {
  multi_promise_->set_ignore_errors(ignore_errors);
}

size_t MultiPromiseActorSafe::promise_count() const {
  return multi_promise_->promise_count();
}

MultiPromiseActorSafe::~MultiPromiseActorSafe() {
  if (!multi_promise_->empty()) {
    register_existing_actor(std::move(multi_promise_)).release();
  }
}

}  // namespace td
