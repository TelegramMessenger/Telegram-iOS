#include <openssl/evp.h>

#include "openssl/digest_td.h"

#include <openssl/opensslv.h>

namespace digest {
const EVP_MD *OpensslEVP_SHA1::get_evp() {
  return EVP_sha1();
}

const EVP_MD *OpensslEVP_SHA256::get_evp() {
  return EVP_sha256();
}

const EVP_MD *OpensslEVP_SHA512::get_evp() {
  return EVP_sha512();
}

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
}  // namespace digest
