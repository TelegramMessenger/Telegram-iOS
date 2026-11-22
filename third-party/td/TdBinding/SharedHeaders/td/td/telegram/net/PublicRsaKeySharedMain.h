//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/RSA.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

#include <memory>

namespace td {

class PublicRsaKeySharedMain final : public mtproto::PublicRsaKeyInterface {
 public:
  explicit PublicRsaKeySharedMain(vector<RsaKey> &&keys) : keys_(std::move(keys)) {
  }

  static std::shared_ptr<PublicRsaKeySharedMain> create(bool is_test);

  Result<RsaKey> get_rsa_key(const vector<int64> &fingerprints) final;

  void drop_keys() final;

 private:
  vector<RsaKey> keys_;
};

}  // namespace td
