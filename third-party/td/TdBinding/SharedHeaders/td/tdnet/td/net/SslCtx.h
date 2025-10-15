//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

namespace detail {
class SslCtxImpl;
}  // namespace detail

class SslCtx {
 public:
  SslCtx();
  SslCtx(const SslCtx &other);
  SslCtx &operator=(const SslCtx &other);
  SslCtx(SslCtx &&) noexcept;
  SslCtx &operator=(SslCtx &&) noexcept;
  ~SslCtx();

  static void init_openssl();

  enum class VerifyPeer { On, Off };

  static Result<SslCtx> create(CSlice cert_file, VerifyPeer verify_peer);

  void *get_openssl_ctx() const;

  explicit operator bool() const noexcept {
    return static_cast<bool>(impl_);
  }

 private:
  unique_ptr<detail::SslCtxImpl> impl_;

  explicit SslCtx(unique_ptr<detail::SslCtxImpl> impl);
};

}  // namespace td
