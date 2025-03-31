//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/BigNum.h"
#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {
namespace mtproto {

class RSA {
 public:
  RSA clone() const;
  int64 get_fingerprint() const;
  size_t size() const;

  bool encrypt(Slice from, MutableSlice to) const;

  void decrypt_signature(Slice from, MutableSlice to) const;

  static Result<RSA> from_pem_public_key(Slice pem);

 private:
  RSA(BigNum n, BigNum e);
  BigNum n_;
  BigNum e_;
};

class PublicRsaKeyInterface {
 public:
  virtual ~PublicRsaKeyInterface() = default;

  struct RsaKey {
    RSA rsa;
    int64 fingerprint;
  };
  virtual Result<RsaKey> get_rsa_key(const vector<int64> &fingerprints) = 0;

  virtual void drop_keys() = 0;
};

}  // namespace mtproto
}  // namespace td
