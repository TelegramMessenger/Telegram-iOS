//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/RSA.h"

#include "td/mtproto/mtproto_api.h"

#include "td/utils/as.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/misc.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/tl_storers.h"

#include <openssl/bio.h>
#include <openssl/bn.h>
#include <openssl/opensslv.h>
#include <openssl/pem.h>
#if OPENSSL_VERSION_NUMBER < 0x30000000L || defined(LIBRESSL_VERSION_NUMBER)
#include <openssl/rsa.h>
#endif

namespace td {
namespace mtproto {

RSA::RSA(BigNum n, BigNum e) : n_(std::move(n)), e_(std::move(e)) {
}

RSA RSA::clone() const {
  return RSA(n_.clone(), e_.clone());
}

Result<RSA> RSA::from_pem_public_key(Slice pem) {
  init_crypto();

  auto *bio =
      BIO_new_mem_buf(const_cast<void *>(static_cast<const void *>(pem.ubegin())), narrow_cast<int32>(pem.size()));
  if (bio == nullptr) {
    return Status::Error("Cannot create BIO");
  }
  SCOPE_EXIT {
    BIO_free(bio);
  };

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  EVP_PKEY *rsa = PEM_read_bio_PUBKEY(bio, nullptr, nullptr, nullptr);
#else
  auto rsa = PEM_read_bio_RSAPublicKey(bio, nullptr, nullptr, nullptr);
#endif
  if (rsa == nullptr) {
    return Status::Error("Error while reading RSA public key");
  }
  SCOPE_EXIT {
#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
    EVP_PKEY_free(rsa);
#else
    RSA_free(rsa);
#endif
  };

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  if (!EVP_PKEY_is_a(rsa, "RSA")) {
    return Status::Error("Key is not an RSA key");
  }
  if (EVP_PKEY_size(rsa) != 256) {
    return Status::Error("EVP_PKEY_size != 256");
  }
#else
  if (RSA_size(rsa) != 256) {
    return Status::Error("RSA_size != 256");
  }
#endif

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  BIGNUM *n_num = nullptr;
  BIGNUM *e_num = nullptr;

  int res = EVP_PKEY_get_bn_param(rsa, "n", &n_num);
  CHECK(res == 1 && n_num != nullptr);
  res = EVP_PKEY_get_bn_param(rsa, "e", &e_num);
  CHECK(res == 1 && e_num != nullptr);

  auto n = static_cast<void *>(n_num);
  auto e = static_cast<void *>(e_num);
#else
  const BIGNUM *n_num;
  const BIGNUM *e_num;

#if OPENSSL_VERSION_NUMBER >= 0x10100000L
  RSA_get0_key(rsa, &n_num, &e_num, nullptr);
#else
  n_num = rsa->n;
  e_num = rsa->e;
#endif

  auto n = static_cast<void *>(BN_dup(n_num));
  auto e = static_cast<void *>(BN_dup(e_num));
  if (n == nullptr || e == nullptr) {
    return Status::Error("Cannot dup BIGNUM");
  }
#endif

  return RSA(BigNum::from_raw(n), BigNum::from_raw(e));
}

int64 RSA::get_fingerprint() const {
  // string objects are necessary, because mtproto_api::rsa_public_key contains Slice inside
  string n_str = n_.to_binary();
  string e_str = e_.to_binary();
  mtproto_api::rsa_public_key public_key(n_str, e_str);
  size_t size = tl_calc_length(public_key);
  std::vector<unsigned char> tmp(size);
  size = tl_store_unsafe(public_key, tmp.data());
  CHECK(size == tmp.size());
  unsigned char key_sha1[20];
  sha1(Slice(tmp.data(), tmp.size()), key_sha1);
  return as<int64>(key_sha1 + 12);
}

size_t RSA::size() const {
  // Checked in RSA::from_pem_public_key step
  return 256;
}

bool RSA::encrypt(Slice from, MutableSlice to) const {
  CHECK(from.size() == 256);
  CHECK(to.size() == 256);
  int bits = n_.get_num_bits();
  CHECK(bits >= 2041 && bits <= 2048);

  BigNum x = BigNum::from_binary(from);
  if (BigNum::compare(x, n_) >= 0) {
    return false;
  }

  BigNumContext ctx;
  BigNum y;
  BigNum::mod_exp(y, x, e_, n_, ctx);
  to.copy_from(y.to_binary(256));
  return true;
}

void RSA::decrypt_signature(Slice from, MutableSlice to) const {
  CHECK(from.size() == 256);
  BigNumContext ctx;
  BigNum x = BigNum::from_binary(from);
  BigNum y;
  BigNum::mod_exp(y, x, e_, n_, ctx);
  to.copy_from(y.to_binary(256));
}

}  // namespace mtproto
}  // namespace td
