//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileEncryptionKey.h"

#include "td/telegram/SecureStorage.h"

#include "td/utils/as.h"
#include "td/utils/crypto.h"
#include "td/utils/Random.h"

namespace td {

FileEncryptionKey::FileEncryptionKey(Slice key, Slice iv) : key_iv_(key.size() + iv.size(), '\0'), type_(Type::Secret) {
  if (key.size() != 32 || iv.size() != 32) {
    LOG(ERROR) << "Wrong key/iv sizes: " << key.size() << " " << iv.size();
    type_ = Type::None;
    return;
  }
  CHECK(key_iv_.size() == 64);
  MutableSlice(key_iv_).copy_from(key);
  MutableSlice(key_iv_).substr(key.size()).copy_from(iv);
}

FileEncryptionKey::FileEncryptionKey(const secure_storage::Secret &secret) : type_(Type::Secure) {
  key_iv_ = secret.as_slice().str();
}

FileEncryptionKey FileEncryptionKey::create() {
  FileEncryptionKey res;
  res.key_iv_.resize(64);
  Random::secure_bytes(res.key_iv_);
  res.type_ = Type::Secret;
  return res;
}
FileEncryptionKey FileEncryptionKey::create_secure_key() {
  return FileEncryptionKey(secure_storage::Secret::create_new());
}

const UInt256 &FileEncryptionKey::key() const {
  CHECK(is_secret());
  CHECK(key_iv_.size() == 64);
  return *reinterpret_cast<const UInt256 *>(key_iv_.data());
}
Slice FileEncryptionKey::key_slice() const {
  CHECK(is_secret());
  CHECK(key_iv_.size() == 64);
  return Slice(key_iv_.data(), 32);
}
secure_storage::Secret FileEncryptionKey::secret() const {
  CHECK(is_secure());
  return secure_storage::Secret::create(Slice(key_iv_).truncate(32)).move_as_ok();
}

bool FileEncryptionKey::has_value_hash() const {
  CHECK(is_secure());
  return key_iv_.size() > secure_storage::Secret::size();
}

void FileEncryptionKey::set_value_hash(const secure_storage::ValueHash &value_hash) {
  key_iv_.resize(secure_storage::Secret::size() + value_hash.as_slice().size());
  MutableSlice(key_iv_).remove_prefix(secure_storage::Secret::size()).copy_from(value_hash.as_slice());
}

secure_storage::ValueHash FileEncryptionKey::value_hash() const {
  CHECK(has_value_hash());
  return secure_storage::ValueHash::create(Slice(key_iv_).remove_prefix(secure_storage::Secret::size())).move_as_ok();
}

UInt256 &FileEncryptionKey::mutable_iv() {
  CHECK(is_secret());
  CHECK(key_iv_.size() == 64);
  return *reinterpret_cast<UInt256 *>(&key_iv_[0] + 32);
}
Slice FileEncryptionKey::iv_slice() const {
  CHECK(is_secret());
  CHECK(key_iv_.size() == 64);
  return Slice(key_iv_.data() + 32, 32);
}

int32 FileEncryptionKey::calc_fingerprint() const {
  CHECK(is_secret());
  char buf[16];
  md5(key_iv_, {buf, sizeof(buf)});
  return as<int32>(buf) ^ as<int32>(buf + 4);
}

StringBuilder &operator<<(StringBuilder &string_builder, const FileEncryptionKey &key) {
  if (key.is_secret()) {
    return string_builder << "SecretKey{" << key.size() << "}";
  }
  if (key.is_secure()) {
    return string_builder << "SecureKey{" << key.size() << "}";
  }
  return string_builder << "NoKey{}";
}

}  // namespace td
