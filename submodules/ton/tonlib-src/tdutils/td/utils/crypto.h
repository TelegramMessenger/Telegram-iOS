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

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/SharedSlice.h"
#include "td/utils/Status.h"

namespace td {

uint64 pq_factorize(uint64 pq);

#if TD_HAVE_OPENSSL
void init_crypto();

int pq_factorize(Slice pq_str, string *p_str, string *q_str);

void aes_ige_encrypt(Slice aes_key, MutableSlice aes_iv, Slice from, MutableSlice to);
void aes_ige_decrypt(Slice aes_key, MutableSlice aes_iv, Slice from, MutableSlice to);

void aes_cbc_encrypt(Slice aes_key, MutableSlice aes_iv, Slice from, MutableSlice to);
void aes_cbc_decrypt(Slice aes_key, MutableSlice aes_iv, Slice from, MutableSlice to);

class AesCtrState {
 public:
  AesCtrState();
  AesCtrState(const AesCtrState &from) = delete;
  AesCtrState &operator=(const AesCtrState &from) = delete;
  AesCtrState(AesCtrState &&from);
  AesCtrState &operator=(AesCtrState &&from);
  ~AesCtrState();

  void init(Slice key, Slice iv);

  void encrypt(Slice from, MutableSlice to);

  void decrypt(Slice from, MutableSlice to);

 private:
  class Impl;
  unique_ptr<Impl> ctx_;
};

class AesCbcState {
 public:
  AesCbcState(Slice key256, Slice iv128);

  void encrypt(Slice from, MutableSlice to);
  void decrypt(Slice from, MutableSlice to);

 private:
  SecureString key_;
  SecureString iv_;
};

void sha1(Slice data, unsigned char output[20]);

void sha256(Slice data, MutableSlice output);

void sha512(Slice data, MutableSlice output);

string sha256(Slice data) TD_WARN_UNUSED_RESULT;

string sha512(Slice data) TD_WARN_UNUSED_RESULT;

class Sha256State {
 public:
  Sha256State();
  Sha256State(const Sha256State &other) = delete;
  Sha256State &operator=(const Sha256State &other) = delete;
  Sha256State(Sha256State &&other);
  Sha256State &operator=(Sha256State &&other);
  ~Sha256State();

  void init();

  void feed(Slice data);

  void extract(MutableSlice dest, bool destroy = false);

 private:
  class Impl;
  unique_ptr<Impl> impl_;
  bool is_inited_ = false;
};

void md5(Slice input, MutableSlice output);

void pbkdf2_sha256(Slice password, Slice salt, int iteration_count, MutableSlice dest);
void pbkdf2_sha512(Slice password, Slice salt, int iteration_count, MutableSlice dest);

void hmac_sha256(Slice key, Slice message, MutableSlice dest);
void hmac_sha512(Slice key, Slice message, MutableSlice dest);

// Interface may be improved
Result<BufferSlice> rsa_encrypt_pkcs1_oaep(Slice public_key, Slice data);
Result<BufferSlice> rsa_decrypt_pkcs1_oaep(Slice private_key, Slice data);

void init_openssl_threads();
#endif

#if TD_HAVE_ZLIB
uint32 crc32(Slice data);
#endif

#if TD_HAVE_CRC32C
uint32 crc32c(Slice data);
uint32 crc32c_extend(uint32 old_crc, Slice data);
uint32 crc32c_extend(uint32 old_crc, uint32 new_crc, size_t data_size);
#endif

uint64 crc64(Slice data);
uint16 crc16(Slice data);

}  // namespace td
