//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

#include <memory>

#if TD_HAVE_OPENSSL

namespace td {

class Ed25519 {
 public:
  class PublicKey {
   public:
    static constexpr size_t LENGTH = 32;

    PublicKey() = default;
    explicit PublicKey(SecureString octet_string);
    PublicKey(const PublicKey &other) : octet_string_(other.octet_string_.copy()) {
    }
    PublicKey(PublicKey &&) noexcept = default;
    PublicKey &operator=(const PublicKey &other) {
      CHECK(octet_string_.empty());
      octet_string_ = other.octet_string_.copy();
      return *this;
    }
    PublicKey &operator=(PublicKey &&) noexcept = delete;
    ~PublicKey() = default;

    SecureString as_octet_string() const;

    UInt256 as_uint256() const {
      UInt256 result;
      CHECK(octet_string_.size() == result.as_slice().size());
      result.as_mutable_slice().copy_from(octet_string_);
      return result;
    }

    static Result<PublicKey> from_slice(Slice slice) {
      if (slice.size() != LENGTH) {
        return Status::Error("Invalid slice size");
      }
      return PublicKey(SecureString(slice));
    }

    Status verify_signature(Slice data, Slice signature) const;

    bool operator==(const PublicKey &other) const {
      return octet_string_ == other.octet_string_;
    }

    bool operator!=(const PublicKey &other) const {
      return octet_string_ != other.octet_string_;
    }

   private:
    SecureString octet_string_;
  };

  struct PreparedPrivateKey;

  class PrivateKey {
   public:
    static constexpr size_t LENGTH = 32;

    explicit PrivateKey(SecureString octet_string);

    Result<std::shared_ptr<const PreparedPrivateKey>> prepare() const;

    SecureString as_octet_string() const;

    Result<PublicKey> get_public_key() const;

    Result<SecureString> sign(Slice data) const;

    static Result<SecureString> sign(const PreparedPrivateKey &prepared_private_key, Slice data);

    Result<SecureString> as_pem(Slice password) const;

    static Result<PrivateKey> from_pem(Slice pem, Slice password);

   private:
    SecureString octet_string_;
  };

  static Result<PrivateKey> generate_private_key();

  static Result<SecureString> compute_shared_secret(const PublicKey &public_key, const PrivateKey &private_key);

  static Result<SecureString> get_public_key(Slice private_key);
};

}  // namespace td

#endif
