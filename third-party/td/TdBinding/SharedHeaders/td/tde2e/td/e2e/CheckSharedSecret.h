//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/utils.h"

#include "td/utils/optional.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

namespace tde2e_core {

struct CheckSharedSecret {
  td::UInt256 nonce_;
  td::UInt256 nonce_hash_;
  td::optional<td::UInt256> o_other_nonce_hash_;
  td::optional<td::UInt256> o_other_nonce_;

  static CheckSharedSecret create();
  td::UInt256 commit_nonce() const;
  td::Result<td::UInt256> reveal_nonce() const;
  td::Status recive_commit_nonce(const td::UInt256 &other_nonce_hash);
  td::Status receive_reveal_nonce(const td::UInt256 &other_nonce);
  td::Result<td::UInt256> finalize_hash(td::Slice shared_secret) const;
};

}  // namespace tde2e_core
