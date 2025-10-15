//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/misc.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

struct EncryptedFile {
  int64 id_ = 0;
  int64 access_hash_ = 0;
  int64 size_ = 0;
  int32 dc_id_ = 0;
  int32 key_fingerprint_ = 0;

  EncryptedFile() = default;
  EncryptedFile(int64 id, int64 access_hash, int64 size, int32 dc_id, int32 key_fingerprint)
      : id_(id), access_hash_(access_hash), size_(size), dc_id_(dc_id), key_fingerprint_(key_fingerprint) {
    CHECK(size_ >= 0);
  }

  static unique_ptr<EncryptedFile> get_encrypted_file(tl_object_ptr<telegram_api::EncryptedFile> file_ptr) {
    if (file_ptr == nullptr || file_ptr->get_id() != telegram_api::encryptedFile::ID) {
      return nullptr;
    }
    auto file = move_tl_object_as<telegram_api::encryptedFile>(file_ptr);
    if (file->size_ < 0) {
      return nullptr;
    }
    return make_unique<EncryptedFile>(file->id_, file->access_hash_, file->size_, file->dc_id_, file->key_fingerprint_);
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    using td::store;
    bool has_64bit_size = (size_ >= (static_cast<int64>(1) << 31));
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_64bit_size);
    END_STORE_FLAGS();
    store(id_, storer);
    store(access_hash_, storer);
    if (has_64bit_size) {
      store(size_, storer);
    } else {
      store(narrow_cast<int32>(size_), storer);
    }
    store(dc_id_, storer);
    store(key_fingerprint_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    using td::parse;
    bool has_64bit_size;
    BEGIN_PARSE_FLAGS();
    constexpr int32 OLD_MAGIC = 0x473d738a;
    if (flags_parse == OLD_MAGIC) {
      flags_parse = 0;
    }
    PARSE_FLAG(has_64bit_size);
    END_PARSE_FLAGS();
    parse(id_, parser);
    parse(access_hash_, parser);
    if (has_64bit_size) {
      parse(size_, parser);
    } else {
      int32 int_size;
      parse(int_size, parser);
      size_ = int_size;
    }
    parse(dc_id_, parser);
    parse(key_fingerprint_, parser);
  }
};

inline StringBuilder &operator<<(StringBuilder &sb, const EncryptedFile &file) {
  return sb << "[" << tag("id", file.id_) << tag("access_hash", file.access_hash_) << tag("size", file.size_)
            << tag("dc_id", file.dc_id_) << tag("key_fingerprint", file.key_fingerprint_) << "]";
}

}  // namespace td
