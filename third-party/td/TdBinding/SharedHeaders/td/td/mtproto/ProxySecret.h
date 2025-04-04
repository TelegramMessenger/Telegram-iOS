//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {
namespace mtproto {

class ProxySecret {
 public:
  static constexpr size_t MAX_DOMAIN_LENGTH = 182;  // must be small enough to not overflow TLS-hello length

  static Result<ProxySecret> from_link(Slice encoded_secret, bool truncate_if_needed = false);

  static Result<ProxySecret> from_binary(Slice raw_unchecked_secret, bool truncate_if_needed = false);

  static ProxySecret from_raw(Slice raw_secret) {
    ProxySecret result;
    result.secret_ = raw_secret.str();
    return result;
  }

  Slice get_raw_secret() const {
    return secret_;
  }

  Slice get_proxy_secret() const {
    Slice proxy_secret(secret_);
    if (proxy_secret.size() >= 17) {
      return proxy_secret.substr(1, 16);
    }
    return proxy_secret;
  }

  string get_encoded_secret() const;

  bool use_random_padding() const {
    return secret_.size() >= 17;
  }

  bool emulate_tls() const {
    return secret_.size() >= 17 && static_cast<unsigned char>(secret_[0]) == 0xee;
  }

  string get_domain() const {
    CHECK(emulate_tls());
    return secret_.substr(17);
  }

 private:
  friend bool operator==(const ProxySecret &lhs, const ProxySecret &rhs) {
    return lhs.secret_ == rhs.secret_;
  }
  string secret_;
};

inline bool operator!=(const ProxySecret &lhs, const ProxySecret &rhs) {
  return !(lhs == rhs);
}

}  // namespace mtproto
}  // namespace td
