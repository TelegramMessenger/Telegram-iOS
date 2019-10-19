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

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include <atomic>
#include <memory>

namespace td {

namespace detail {
struct RawCancellationToken {
  std::atomic<bool> is_cancelled_{false};
};
}  // namespace detail

class CancellationToken {
 public:
  explicit operator bool() const {
    // Empty CancellationToken is never cancelled
    if (!token_) {
      return false;
    }
    return token_->is_cancelled_.load(std::memory_order_acquire);
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
  CancellationTokenSource(CancellationTokenSource &&other) : token_(std::move(other.token_)) {
  }
  CancellationTokenSource &operator=(CancellationTokenSource &&other) {
    cancel();
    token_ = std::move(other.token_);
    return *this;
  }
  CancellationTokenSource(const CancellationTokenSource &other) = delete;
  CancellationTokenSource &operator=(const CancellationTokenSource &other) = delete;
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
    token_->is_cancelled_.store(true, std::memory_order_release);
    token_.reset();
  }

 private:
  std::shared_ptr<detail::RawCancellationToken> token_;
};

}  // namespace td
