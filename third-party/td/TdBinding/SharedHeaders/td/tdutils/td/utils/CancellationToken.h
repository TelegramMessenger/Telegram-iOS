//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include <atomic>
#include <memory>

namespace td {

namespace detail {
struct RawCancellationToken {
  std::atomic<bool> is_canceled_{false};
};
}  // namespace detail

class CancellationToken {
 public:
  explicit operator bool() const noexcept {
    // empty CancellationToken is never canceled
    if (!token_) {
      return false;
    }
    return token_->is_canceled_.load(std::memory_order_acquire);
  }
  CancellationToken() = default;
  explicit CancellationToken(std::shared_ptr<detail::RawCancellationToken> token) : token_(std::move(token)) {
  }

 private:
  std::shared_ptr<detail::RawCancellationToken> token_;
};

class CancellationTokenSource {
 public:
  CancellationTokenSource() = default;
  CancellationTokenSource(CancellationTokenSource &&other) noexcept : token_(std::move(other.token_)) {
  }
  CancellationTokenSource &operator=(CancellationTokenSource &&other) noexcept {
    cancel();
    token_ = std::move(other.token_);
    return *this;
  }
  CancellationTokenSource(const CancellationTokenSource &) = delete;
  CancellationTokenSource &operator=(const CancellationTokenSource &) = delete;
  ~CancellationTokenSource() {
    cancel();
  }

  CancellationToken get_cancellation_token() {
    if (!token_) {
      token_ = std::make_shared<detail::RawCancellationToken>();
    }
    return CancellationToken(token_);
  }
  void cancel() {
    if (!token_) {
      return;
    }
    token_->is_canceled_.store(true, std::memory_order_release);
    token_.reset();
  }

 private:
  std::shared_ptr<detail::RawCancellationToken> token_;
};

}  // namespace td
