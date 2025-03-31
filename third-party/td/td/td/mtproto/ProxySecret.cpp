//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/ProxySecret.h"

#include "td/utils/base64.h"
#include "td/utils/misc.h"

namespace td {
namespace mtproto {

Result<ProxySecret> ProxySecret::from_link(Slice encoded_secret, bool truncate_if_needed) {
  auto r_decoded = hex_decode(encoded_secret);
  if (r_decoded.is_error()) {
    r_decoded = base64url_decode(encoded_secret);
  }
  if (r_decoded.is_error()) {
    r_decoded = base64_decode(encoded_secret);
  }
  if (r_decoded.is_error()) {
    return Status::Error(400, "Wrong proxy secret");
  }
  return from_binary(r_decoded.ok(), truncate_if_needed);
}

Result<ProxySecret> ProxySecret::from_binary(Slice raw_unchecked_secret, bool truncate_if_needed) {
  if (raw_unchecked_secret.size() > 17 + MAX_DOMAIN_LENGTH) {
    if (truncate_if_needed) {
      raw_unchecked_secret.truncate(17 + MAX_DOMAIN_LENGTH);
    } else {
      return Status::Error(400, "Too long secret");
    }
  }
  if (raw_unchecked_secret.size() == 16 ||
      (raw_unchecked_secret.size() == 17 && static_cast<unsigned char>(raw_unchecked_secret[0]) == 0xdd) ||
      (raw_unchecked_secret.size() >= 18 && static_cast<unsigned char>(raw_unchecked_secret[0]) == 0xee)) {
    return from_raw(raw_unchecked_secret);
  }
  if (raw_unchecked_secret.size() < 16) {
    return Status::Error(400, "Wrong proxy secret");
  }
  return Status::Error(400, "Unsupported proxy secret");
}

string ProxySecret::get_encoded_secret() const {
  if (emulate_tls()) {
    return base64url_encode(secret_);
  }
  return hex_encode(secret_);
}

}  // namespace mtproto
}  // namespace td
