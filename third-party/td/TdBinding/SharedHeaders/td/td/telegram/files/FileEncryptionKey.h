//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/UInt.h"

namespace td {

namespace secure_storage {
class Secret;
class ValueHash;
}  // namespace secure_storage

struct FileEncryptionKey {
  enum class Type : int32 { None, Secret, Secure };

  FileEncryptionKey() = default;

  FileEncryptionKey(Slice key, Slice iv);

  explicit FileEncryptionKey(const secure_storage::Secret &secret);

  bool is_secret() const {
    return type_ == Type::Secret;
  }

  bool is_secure() const {
    return type_ == Type::Secure;
  }

  static FileEncryptionKey create();

  static FileEncryptionKey create_secure_key();

  const UInt256 &key() const;

  Slice key_slice() const;

  secure_storage::Secret secret() const;

  bool has_value_hash() const;

  void set_value_hash(const secure_storage::ValueHash &value_hash);

  secure_storage::ValueHash value_hash() const;

  UInt256 &mutable_iv();

  Slice iv_slice() const;

  int32 calc_fingerprint() const;

  bool empty() const {
    return key_iv_.empty();
  }

  size_t size() const {
    return key_iv_.size();
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(key_iv_, storer);
  }
  template <class ParserT>
  void parse(Type type, ParserT &parser) {
    td::parse(key_iv_, parser);
    if (key_iv_.empty()) {
      type_ = Type::None;
    } else {
      if (type_ == Type::Secure) {
        if (key_iv_.size() != 64) {
          LOG(ERROR) << "Have wrong key size " << key_iv_.size();
        }
      }
      type_ = type;
    }
  }

  friend bool operator==(const FileEncryptionKey &lhs, const FileEncryptionKey &rhs) {
    return lhs.key_iv_ == rhs.key_iv_;
  }

 private:
  string key_iv_;  // TODO wrong alignment is possible
  Type type_ = Type::None;
};

inline bool operator!=(const FileEncryptionKey &lhs, const FileEncryptionKey &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const FileEncryptionKey &key);

}  // namespace td
