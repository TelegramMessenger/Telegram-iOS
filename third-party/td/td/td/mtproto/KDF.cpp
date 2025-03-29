//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/KDF.h"

#include "td/utils/as.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/logging.h"

namespace td {
namespace mtproto {

void KDF(Slice auth_key, const UInt128 &msg_key, int X, UInt256 *aes_key, UInt256 *aes_iv) {
  LOG_CHECK(auth_key.size() == 2048 / 8) << auth_key.size();
  const char *auth_key_raw = auth_key.data();
  uint8 buf[48];
  as<UInt128>(buf) = msg_key;
  as<UInt256>(buf + 16) = as<UInt256>(auth_key_raw + X);
  uint8 sha1_a[20];
  sha1(Slice(buf, 48), sha1_a);

  as<UInt128>(buf) = as<UInt128>(auth_key_raw + X + 32);
  as<UInt128>(buf + 16) = msg_key;
  as<UInt128>(buf + 32) = as<UInt128>(auth_key_raw + X + 48);
  uint8 sha1_b[20];
  sha1(Slice(buf, 48), sha1_b);

  as<UInt256>(buf) = as<UInt256>(auth_key_raw + 64 + X);
  as<UInt128>(buf + 32) = msg_key;
  uint8 sha1_c[20];
  sha1(Slice(buf, 48), sha1_c);

  as<UInt128>(buf) = msg_key;
  as<UInt256>(buf + 16) = as<UInt256>(auth_key_raw + 96 + X);
  uint8 sha1_d[20];
  sha1(Slice(buf, 48), sha1_d);

  as<uint64>(aes_key->raw) = as<uint64>(sha1_a);
  as<UInt<96>>(aes_key->raw + 8) = as<UInt<96>>(sha1_b + 8);
  as<UInt<96>>(aes_key->raw + 20) = as<UInt<96>>(sha1_c + 4);

  as<UInt<96>>(aes_iv->raw) = as<UInt<96>>(sha1_a + 8);
  as<uint64>(aes_iv->raw + 12) = as<uint64>(sha1_b);
  as<uint32>(aes_iv->raw + 20) = as<uint32>(sha1_c + 16);
  as<uint64>(aes_iv->raw + 24) = as<uint64>(sha1_d);
}

void tmp_KDF(const UInt128 &server_nonce, const UInt256 &new_nonce, UInt256 *tmp_aes_key, UInt256 *tmp_aes_iv) {
  // tmp_aes_key := SHA1(new_nonce + server_nonce) + substr(SHA1(server_nonce + new_nonce), 0, 12);
  uint8 buf[512 / 8];
  as<UInt256>(buf) = new_nonce;
  as<UInt128>(buf + 32) = server_nonce;
  sha1(Slice(buf, 48), tmp_aes_key->raw);

  as<UInt128>(buf) = server_nonce;
  as<UInt256>(buf + 16) = new_nonce;
  uint8 sha1_server_new[20];
  sha1(Slice(buf, 48), sha1_server_new);
  as<UInt<96>>(tmp_aes_key->raw + 20) = as<UInt<96>>(sha1_server_new);

  // tmp_aes_iv := substr(SHA1(server_nonce + new_nonce), 12, 8) + SHA1(new_nonce + new_nonce) + substr(new_nonce, 0, 4)
  as<uint64>(tmp_aes_iv->raw) = as<uint64>(sha1_server_new + 12);

  as<UInt256>(buf) = new_nonce;
  as<UInt256>(buf + 32) = new_nonce;
  sha1(Slice(buf, 64), tmp_aes_iv->raw + 8);
  as<uint32>(tmp_aes_iv->raw + 28) = as<uint32>(new_nonce.raw);
}

void KDF2(Slice auth_key, const UInt128 &msg_key, int X, UInt256 *aes_key, UInt256 *aes_iv) {
  uint8 buf_raw[36 + 16];
  MutableSlice buf(buf_raw, 36 + 16);
  Slice msg_key_slice = as_slice(msg_key);

  // sha256_a = SHA256 (msg_key + substr(auth_key, x, 36));
  buf.copy_from(msg_key_slice);
  buf.substr(16, 36).copy_from(auth_key.substr(X, 36));
  uint8 sha256_a_raw[32];
  MutableSlice sha256_a(sha256_a_raw, 32);
  sha256(buf, sha256_a);

  // sha256_b = SHA256 (substr(auth_key, 40+x, 36) + msg_key);
  buf.copy_from(auth_key.substr(40 + X, 36));
  buf.substr(36).copy_from(msg_key_slice);
  uint8 sha256_b_raw[32];
  MutableSlice sha256_b(sha256_b_raw, 32);
  sha256(buf, sha256_b);

  // aes_key = substr(sha256_a, 0, 8) + substr(sha256_b, 8, 16) + substr(sha256_a, 24, 8);
  MutableSlice aes_key_slice(aes_key->raw, sizeof(aes_key->raw));
  aes_key_slice.copy_from(sha256_a.substr(0, 8));
  aes_key_slice.substr(8).copy_from(sha256_b.substr(8, 16));
  aes_key_slice.substr(24).copy_from(sha256_a.substr(24, 8));

  // aes_iv = substr(sha256_b, 0, 8) + substr(sha256_a, 8, 16) + substr(sha256_b, 24, 8);
  MutableSlice aes_iv_slice(aes_iv->raw, sizeof(aes_iv->raw));
  aes_iv_slice.copy_from(sha256_b.substr(0, 8));
  aes_iv_slice.substr(8).copy_from(sha256_a.substr(8, 16));
  aes_iv_slice.substr(24).copy_from(sha256_b.substr(24, 8));
}

}  // namespace mtproto
}  // namespace td
