//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/CheckSharedSecret.h"

#include "td/utils/crypto.h"

#include <utility>

namespace tde2e_core {

CheckSharedSecret CheckSharedSecret::create() {
  CheckSharedSecret result;
  result.nonce_ = generate_nonce();
  td::sha256(result.nonce_.as_slice(), result.nonce_hash_.as_mutable_slice());
  return result;
}

td::UInt256 CheckSharedSecret::commit_nonce() const {
  return nonce_hash_;
}

td::Result<td::UInt256> CheckSharedSecret::reveal_nonce() const {
  if (!o_other_nonce_hash_) {
    return td::Status::Error("Cannot reveal nonce before other nonce hash is known");
  }
  return nonce_;
}

td::Status CheckSharedSecret::recive_commit_nonce(const td::UInt256 &other_nonce_hash) {
  if (o_other_nonce_hash_) {
    return td::Status::Error("Already received other nonce hash");
  }
  o_other_nonce_hash_ = other_nonce_hash;
  return td::Status::OK();
}

td::Status CheckSharedSecret::receive_reveal_nonce(const td::UInt256 &other_nonce) {
  if (!o_other_nonce_hash_) {
    return td::Status::Error("Cannot  receive nonce before nonce hash");
  }
  td::UInt256 expected_nonce_hash;
  td::sha256(other_nonce.as_slice(), expected_nonce_hash.as_mutable_slice());
  if (expected_nonce_hash != *o_other_nonce_hash_) {
    return td::Status::Error("Other nonce hash is different from the expected one");
  }
  o_other_nonce_ = other_nonce;
  return td::Status::OK();
}

td::Result<td::UInt256> CheckSharedSecret::finalize_hash(td::Slice shared_secret) const {
  if (!o_other_nonce_) {
    return td::Status::Error("Cannot calculate hash before other nonce is known");
  }
  td::UInt256 a = nonce_;
  td::UInt256 b = *o_other_nonce_;
  if (b < a) {
    std::swap(a, b);
  }
  td::Sha256State state;
  state.init();
  state.feed(shared_secret);
  state.feed(a.as_slice());
  state.feed(b.as_slice());

  td::UInt256 hash;
  state.extract(hash.as_mutable_slice());

  return hash;
}

}  // namespace tde2e_core
