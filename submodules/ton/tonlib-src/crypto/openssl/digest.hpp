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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once
#include <assert.h>

#include <openssl/evp.h>
#include <openssl/opensslv.h>

#include "td/utils/Slice.h"

namespace digest {
struct OpensslEVP_SHA1 {
  enum { digest_bytes = 20 };
  static const EVP_MD *get_evp() {
    return EVP_sha1();
  }
};

struct OpensslEVP_SHA256 {
  enum { digest_bytes = 32 };
  static const EVP_MD *get_evp() {
    return EVP_sha256();
  }
};

struct OpensslEVP_SHA512 {
  enum { digest_bytes = 64 };
  static const EVP_MD *get_evp() {
    return EVP_sha512();
  }
};

template <typename H>
class HashCtx {
  EVP_MD_CTX *ctx{nullptr};
  void init();
  void clear();

 public:
  enum { digest_bytes = H::digest_bytes };
  HashCtx() {
    init();
  }
  HashCtx(const void *data, std::size_t len) {
    init();
    feed(data, len);
  }
  ~HashCtx() {
    clear();
  }
  void reset();
  void feed(const void *data, std::size_t len);
  void feed(td::Slice slice) {
    feed(slice.data(), slice.size());
  }
  std::size_t extract(unsigned char buffer[digest_bytes]);
  std::size_t extract(td::MutableSlice slice);
  std::string extract();
};

template <typename H>
void HashCtx<H>::init() {
  ctx = EVP_MD_CTX_create();
  reset();
}

template <typename H>
void HashCtx<H>::reset() {
  EVP_DigestInit_ex(ctx, H::get_evp(), 0);
}

template <typename H>
void HashCtx<H>::clear() {
  EVP_MD_CTX_destroy(ctx);
  ctx = nullptr;
}

template <typename H>
void HashCtx<H>::feed(const void *data, std::size_t len) {
  EVP_DigestUpdate(ctx, data, len);
}

template <typename H>
std::size_t HashCtx<H>::extract(unsigned char buffer[digest_bytes]) {
  unsigned olen = 0;
  EVP_DigestFinal_ex(ctx, buffer, &olen);
  assert(olen == digest_bytes);
  return olen;
}

template <typename H>
std::size_t HashCtx<H>::extract(td::MutableSlice slice) {
  return extract(slice.ubegin());
}

template <typename H>
std::string HashCtx<H>::extract() {
  unsigned char buffer[digest_bytes];
  unsigned olen = 0;
  EVP_DigestFinal_ex(ctx, buffer, &olen);
  assert(olen == digest_bytes);
  return std::string((char *)buffer, olen);
}

typedef HashCtx<OpensslEVP_SHA1> SHA1;
typedef HashCtx<OpensslEVP_SHA256> SHA256;
typedef HashCtx<OpensslEVP_SHA512> SHA512;

template <typename T>
std::size_t hash_str(unsigned char buffer[T::digest_bytes], const void *data, std::size_t size) {
  T hasher(data, size);
  return hasher.extract(buffer);
}

template <typename T>
std::size_t hash_two_str(unsigned char buffer[T::digest_bytes], const void *data1, std::size_t size1, const void *data2,
                         std::size_t size2) {
  T hasher(data1, size1);
  hasher.feed(data2, size2);
  return hasher.extract(buffer);
}

template <typename T>
std::string hash_str(const void *data, std::size_t size) {
  T hasher(data, size);
  return hasher.extract();
}

template <typename T>
std::string hash_two_str(const void *data1, std::size_t size1, const void *data2, std::size_t size2) {
  T hasher(data1, size1);
  hasher.feed(data2, size2);
  return hasher.extract();
}
}  // namespace digest
