//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/SecureValue.h"

#include "td/telegram/files/FileId.hpp"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void store(DatedFile file, StorerT &storer) {
  store(file.file_id, storer);
  store(file.date, storer);
}

template <class ParserT>
void parse(DatedFile &file, ParserT &parser) {
  parse(file.file_id, parser);
  parse(file.date, parser);
}

template <class StorerT>
void store(EncryptedSecureFile file, StorerT &storer) {
  store(file.file, storer);
  store(file.file_hash, storer);
  store(file.encrypted_secret, storer);
}

template <class ParserT>
void parse(EncryptedSecureFile &file, ParserT &parser) {
  parse(file.file, parser);
  parse(file.file_hash, parser);
  parse(file.encrypted_secret, parser);
}

template <class StorerT>
void store(const EncryptedSecureData &data, StorerT &storer) {
  store(data.data, storer);
  store(data.hash, storer);
  store(data.encrypted_secret, storer);
}

template <class ParserT>
void parse(EncryptedSecureData &data, ParserT &parser) {
  parse(data.data, parser);
  parse(data.hash, parser);
  parse(data.encrypted_secret, parser);
}

template <class StorerT>
void store(const EncryptedSecureCredentials &credentials, StorerT &storer) {
  store(credentials.data, storer);
  store(credentials.hash, storer);
  store(credentials.encrypted_secret, storer);
}

template <class ParserT>
void parse(EncryptedSecureCredentials &credentials, ParserT &parser) {
  parse(credentials.data, parser);
  parse(credentials.hash, parser);
  parse(credentials.encrypted_secret, parser);
}

template <class StorerT>
void store(const EncryptedSecureValue &value, StorerT &storer) {
  bool has_data_hash = !value.data.hash.empty();
  bool has_files = !value.files.empty();
  bool has_front_side = value.front_side.file.file_id.is_valid();
  bool has_reverse_side = value.reverse_side.file.file_id.is_valid();
  bool has_selfie = value.selfie.file.file_id.is_valid();
  bool has_hash = !value.hash.empty();
  bool has_translations = !value.translations.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_data_hash);
  STORE_FLAG(has_files);
  STORE_FLAG(has_front_side);
  STORE_FLAG(has_reverse_side);
  STORE_FLAG(has_selfie);
  STORE_FLAG(has_hash);
  STORE_FLAG(has_translations);
  END_STORE_FLAGS();
  store(value.type, storer);
  if (has_data_hash) {
    store(value.data, storer);
  } else {
    store(value.data.data, storer);
  }
  if (has_files) {
    store(value.files, storer);
  }
  if (has_front_side) {
    store(value.front_side, storer);
  }
  if (has_reverse_side) {
    store(value.reverse_side, storer);
  }
  if (has_selfie) {
    store(value.selfie, storer);
  }
  if (has_hash) {
    store(value.hash, storer);
  }
  if (has_translations) {
    store(value.translations, storer);
  }
}

template <class ParserT>
void parse(EncryptedSecureValue &value, ParserT &parser) {
  bool has_data_hash;
  bool has_files;
  bool has_front_side;
  bool has_reverse_side;
  bool has_selfie;
  bool has_hash;
  bool has_translations;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_data_hash);
  PARSE_FLAG(has_files);
  PARSE_FLAG(has_front_side);
  PARSE_FLAG(has_reverse_side);
  PARSE_FLAG(has_selfie);
  PARSE_FLAG(has_hash);
  PARSE_FLAG(has_translations);
  END_PARSE_FLAGS();
  parse(value.type, parser);
  if (has_data_hash) {
    parse(value.data, parser);
  } else {
    parse(value.data.data, parser);
  }
  if (has_files) {
    parse(value.files, parser);
  }
  if (has_front_side) {
    parse(value.front_side, parser);
  }
  if (has_reverse_side) {
    parse(value.reverse_side, parser);
  }
  if (has_selfie) {
    parse(value.selfie, parser);
  }
  if (has_hash) {
    parse(value.hash, parser);
  }
  if (has_translations) {
    parse(value.translations, parser);
  }
}

}  // namespace td
