//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileData.h"

#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/FileReferenceManager.hpp"
#include "td/telegram/files/FileEncryptionKey.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileLocation.hpp"
#include "td/telegram/Global.h"
#include "td/telegram/Td.h"
#include "td/telegram/Version.h"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/misc.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void FileData::store(StorerT &storer) const {
  using ::td::store;
  bool has_owner_dialog_id = owner_dialog_id_.is_valid();
  bool has_expected_size = size_ == 0 && expected_size_ != 0;
  bool encryption_key_is_secure = encryption_key_.is_secure();
  bool has_sources = !file_source_ids_.empty();
  bool has_version = true;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_owner_dialog_id);
  STORE_FLAG(has_expected_size);
  STORE_FLAG(encryption_key_is_secure);
  STORE_FLAG(has_sources);
  STORE_FLAG(has_version);
  END_STORE_FLAGS();

  if (has_version) {
    store(static_cast<int32>(Version::Next) - 1, storer);
  }
  if (has_owner_dialog_id) {
    store(owner_dialog_id_, storer);
  }
  store(pmc_id_, storer);
  store(remote_, storer);
  store(local_, storer);
  auto generate = generate_ == nullptr ? GenerateFileLocation() : GenerateFileLocation(*generate_);
  store(generate, storer);
  if (has_expected_size) {
    store(expected_size_, storer);
  } else {
    store(size_, storer);
  }
  store(remote_name_, storer);
  store(url_, storer);
  store(encryption_key_, storer);
  if (has_sources) {
    auto td = G()->td().get_actor_unsafe();
    store(narrow_cast<int32>(file_source_ids_.size()), storer);
    for (auto file_source_id : file_source_ids_) {
      td->file_reference_manager_->store_file_source(file_source_id, storer);
    }
  }
}

template <class ParserT>
void FileData::parse(ParserT &parser, bool register_file_sources) {
  using ::td::parse;
  bool has_owner_dialog_id;
  bool has_expected_size;
  bool encryption_key_is_secure;
  bool has_sources;
  bool has_version;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_owner_dialog_id);
  PARSE_FLAG(has_expected_size);
  PARSE_FLAG(encryption_key_is_secure);
  PARSE_FLAG(has_sources);
  PARSE_FLAG(has_version);
  END_PARSE_FLAGS();
  if (parser.get_error()) {
    return;
  }

  int32 version = 0;
  if (has_version) {
    parse(version, parser);
  }
  parser.set_version(version);
  if (has_owner_dialog_id) {
    parse(owner_dialog_id_, parser);
  }
  parse(pmc_id_, parser);
  parse(remote_, parser);
  parse(local_, parser);
  GenerateFileLocation generate;
  parse(generate, parser);
  if (generate.type() == GenerateFileLocation::Type::Full) {
    generate_ = make_unique<FullGenerateFileLocation>(generate.full());
  } else {
    generate_ = nullptr;
  }
  if (has_expected_size) {
    parse(expected_size_, parser);
  } else {
    parse(size_, parser);
  }
  parse(remote_name_, parser);
  parse(url_, parser);
  encryption_key_.parse(encryption_key_is_secure ? FileEncryptionKey::Type::Secure : FileEncryptionKey::Type::Secret,
                        parser);
  if (has_sources && register_file_sources) {
    Td *td = G()->td().get_actor_unsafe();
    int32 file_source_count;
    parse(file_source_count, parser);
    if (0 < file_source_count && file_source_count < 5) {
      for (int i = 0; i < file_source_count; i++) {
        if (parser.get_error()) {
          return;
        }
        auto file_source_id = td->file_reference_manager_->parse_file_source(td, parser);
        if (file_source_id.is_valid() && !td::contains(file_source_ids_, file_source_id)) {
          file_source_ids_.push_back(file_source_id);
        }
      }
    } else {
      parser.set_error("Wrong number of file source identifiers");
    }
  }
}

}  // namespace td
