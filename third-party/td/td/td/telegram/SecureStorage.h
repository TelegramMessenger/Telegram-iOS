//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

namespace td {
// Types
// Password
// Secret - 32 bytes with sum % 255 == 239
// EncryptedSecret - encrypted secret
// ValueHash - 32 bytes, sha256 from value
//
// ValueFull = ValueText? ValueData? ValueFile* = [Value]
// Value = ValueText | ValueData | ValueFile
//
// ValueMeta = random_prefix, secret, hash
//
// Helpers
//   calc_aes_cbc_state :: ValueSecret -> ValueHash -> AesCbcState
//
// Encryption.
// To encrypt data:
//   RandomPrefix, ValueSecret, Value:
//   calc_value_hash :: RandomPrefix -> Value -> ValueHash
//   do_encrypt :: RandomPrefix -> Value -> AesCbcState -> EncryptedValue // async
//   encrypt :: (ValueSecret, RandomPrefix, Value) -> (EncryptedValue, ValueHash)
//
// To decrypt data:
//   ValueSecret, ValueHash, EncryptedValue
//   do_decrypt :: EncryptedValue -> AesCbcState -> (RandomPrefix, Value, ValueHash) // async
//   decrypt :: (ValueSecret, ValueHash, EncryptedValue) -> Value
//
// To encrypt FullValue:
//   ValueSecret, [(RandomPrefix, Value)]
//   (ValueSecret, [(RandomPrefix, Value)]) -> [(ValueSecret, RandomPrefix, Value)]
//   [(ValueSecret, RandomPrefix, Value)] -> [(EncryptedValue, ValueHash)]
//

namespace secure_storage {
// Helpers
class ValueHash {
 public:
  explicit ValueHash(UInt256 hash) : hash_(hash) {
  }
  static Result<ValueHash> create(Slice data);
  Slice as_slice() const {
    return ::td::as_slice(hash_);
  }

 private:
  UInt256 hash_;
};

class DataView {
 public:
  DataView() = default;
  DataView(const DataView &) = delete;
  DataView &operator=(const DataView &) = delete;
  DataView(DataView &&) = delete;
  DataView &operator=(DataView &&) = delete;

  virtual int64 size() const = 0;
  virtual Result<BufferSlice> pread(int64 offset, int64 size) const = 0;
  virtual ~DataView() = default;
};

class BufferSliceDataView final : public DataView {
 public:
  explicit BufferSliceDataView(BufferSlice buffer_slice);
  int64 size() const final;
  Result<BufferSlice> pread(int64 offset, int64 size) const final;

 private:
  BufferSlice buffer_slice_;
};

class ConcatDataView final : public DataView {
 public:
  ConcatDataView(const DataView &left, const DataView &right);
  int64 size() const final;
  Result<BufferSlice> pread(int64 offset, int64 size) const final;

 private:
  const DataView &left_;
  const DataView &right_;
};

AesCbcState calc_aes_cbc_state_pbkdf2(Slice secret, Slice salt);
AesCbcState calc_aes_cbc_state_sha512(Slice seed);
Result<ValueHash> calc_value_hash(const DataView &data_view);
ValueHash calc_value_hash(Slice data);
BufferSlice gen_random_prefix(int64 data_size);

class Password {
 public:
  explicit Password(std::string password);
  Slice as_slice() const;

 private:
  std::string password_;
};

class EncryptedSecret;

enum class EnryptionAlgorithm : int32 { Sha512, Pbkdf2 };

class Secret {
 public:
  static Result<Secret> create(Slice secret);
  static Secret create_new();

  Slice as_slice() const;
  EncryptedSecret encrypt(Slice key, Slice salt, EnryptionAlgorithm algorithm);

  int64 get_hash() const;
  Secret clone() const;

  static constexpr size_t size() {
    return sizeof(secret_.raw);
  }

 private:
  Secret(UInt256 secret, int64 hash);
  UInt256 secret_;
  int64 hash_;
};

class EncryptedSecret {
 public:
  static Result<EncryptedSecret> create(Slice encrypted_secret);
  Result<Secret> decrypt(Slice key, Slice salt, EnryptionAlgorithm algorithm);
  Slice as_slice() const;

 private:
  explicit EncryptedSecret(UInt256 encrypted_secret);
  UInt256 encrypted_secret_;
};

// Decryption
class Decryptor {
 public:
  explicit Decryptor(AesCbcState aes_cbc_state);
  Result<BufferSlice> append(BufferSlice data);
  Result<ValueHash> finish();

 private:
  AesCbcState aes_cbc_state_;
  Sha256State sha256_state_;
  bool skipped_prefix_{false};
  size_t to_skip_{0};
};

// Encryption
class Encryptor final : public DataView {
 public:
  Encryptor(AesCbcState aes_cbc_state, const DataView &data_view);
  int64 size() const final;
  Result<BufferSlice> pread(int64 offset, int64 size) const final;

 private:
  mutable AesCbcState aes_cbc_state_;
  mutable int64 current_offset_{0};
  const DataView &data_view_;
};

// Main functions

//   decrypt :: (ValueSecret, ValueHash, EncryptedValue) -> Value
//   encrypt :: (ValueSecret, RandomPrefix, Value) -> (EncryptedValue, ValueHash)

struct EncryptedValue {
  BufferSlice data;
  ValueHash hash;
};

Result<EncryptedValue> encrypt_value(const Secret &secret, Slice data);

Result<BufferSlice> decrypt_value(const Secret &secret, const ValueHash &hash, Slice data);

Result<ValueHash> encrypt_file(const Secret &secret, const string &src, const string &dest);

Status decrypt_file(const Secret &secret, const ValueHash &hash, const string &src, const string &dest);

}  // namespace secure_storage
}  // namespace td
