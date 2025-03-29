//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileEncryptionKey.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileLocation.hpp"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Version.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tl_helpers.h"

#include <limits>

namespace td {

enum class FileStoreType : int32 { Empty, Url, Generate, Local, Remote };

template <class StorerT>
void FileManager::store_file(FileId file_id, StorerT &storer, int32 ttl) const {
  auto file_store_type = FileStoreType::Empty;
  auto file_view = get_file_view(file_id);
  if (file_view.empty() || ttl <= 0) {
  } else if (file_view.has_full_remote_location()) {
    file_store_type = FileStoreType::Remote;
  } else if (file_view.has_url()) {
    file_store_type = FileStoreType::Url;
  } else if (file_view.has_generate_location()) {
    file_store_type = FileStoreType::Generate;
  } else if (file_view.has_full_local_location()) {
    file_store_type = FileStoreType::Local;
  }

  store(file_store_type, storer);

  bool has_encryption_key = false;
  bool has_expected_size =
      file_store_type == FileStoreType::Remote && file_view.size() == 0 && file_view.expected_size() != 0;
  bool has_secure_key = false;
  int64 size = 0;
  bool has_64bit_size = false;
  if (file_store_type != FileStoreType::Empty) {
    has_encryption_key = !file_view.empty() && file_view.is_encrypted_secret();
    has_secure_key = !file_view.empty() && file_view.is_encrypted_secure();
    if (file_store_type != FileStoreType::Url) {
      size = has_expected_size || file_store_type == FileStoreType::Generate ? file_view.expected_size()
                                                                             : file_view.size();
      has_64bit_size = (size > std::numeric_limits<int32>::max());
    }
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_encryption_key);
    STORE_FLAG(has_expected_size);
    STORE_FLAG(has_secure_key);
    STORE_FLAG(has_64bit_size);
    END_STORE_FLAGS();
  }

  switch (file_store_type) {
    case FileStoreType::Empty:
      break;
    case FileStoreType::Url:
      store(file_view.get_type(), storer);
      store(*file_view.get_url(), storer);
      store(file_view.owner_dialog_id(), storer);
      break;
    case FileStoreType::Remote: {
      const auto *full_remote_location = file_view.get_full_remote_location();
      store(*full_remote_location, storer);
      if (has_64bit_size) {
        store(size, storer);
      } else {
        store(narrow_cast<int32>(size), storer);
      }
      store(file_view.remote_name(), storer);
      store(file_view.owner_dialog_id(), storer);
      break;
    }
    case FileStoreType::Local: {
      store(*file_view.get_full_local_location(), storer);
      if (has_64bit_size) {
        store(size, storer);
      } else {
        store(narrow_cast<int32>(size), storer);
      }
      store(static_cast<int32>(file_view.get_by_hash()), storer);
      store(file_view.owner_dialog_id(), storer);
      break;
    }
    case FileStoreType::Generate: {
      auto generate_location = *file_view.get_generate_location();
      FileId from_file_id;
      bool have_file_id = false;
      if (generate_location.conversion_ == "#_file_id#") {
        break;
      } else if (begins_with(generate_location.conversion_, "#file_id#")) {
        // It is not the best possible way to serialize file_id
        from_file_id =
            FileId(to_integer<int32>(Slice(generate_location.conversion_).remove_prefix(Slice("#file_id#").size())), 0);
        generate_location.conversion_ = "#_file_id#";
        have_file_id = true;
      }
      store(generate_location, storer);
      if (has_64bit_size) {
        store(size, storer);
      } else {
        store(narrow_cast<int32>(size), storer);
        store(static_cast<int32>(0), storer);  // legacy
      }
      store(file_view.owner_dialog_id(), storer);

      if (have_file_id) {
        store_file(from_file_id, storer, ttl - 1);
      }
      break;
    }
    default:
      UNREACHABLE();
  }
  if (has_encryption_key || has_secure_key) {
    store(file_view.encryption_key(), storer);
  }
}

template <class ParserT>
FileId FileManager::parse_file(ParserT &parser) {
  if (parser.version() < static_cast<int32>(Version::StoreFileId)) {
    return FileId();
  }

  FileStoreType file_store_type;
  parse(file_store_type, parser);

  bool has_encryption_key = false;
  bool has_expected_size = false;
  bool has_secure_key = false;
  bool has_64bit_size = false;
  if (file_store_type != FileStoreType::Empty) {
    if (parser.version() >= static_cast<int32>(Version::StoreFileEncryptionKey)) {
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_encryption_key);
      PARSE_FLAG(has_expected_size);
      PARSE_FLAG(has_secure_key);
      PARSE_FLAG(has_64bit_size);
      END_PARSE_FLAGS();
    }
  }

  auto file_id = [&] {
    switch (file_store_type) {
      case FileStoreType::Empty:
        return FileId();
      case FileStoreType::Remote: {
        FullRemoteFileLocation full_remote_location;
        parse(full_remote_location, parser);
        int64 stored_size;
        if (has_64bit_size) {
          parse(stored_size, parser);
        } else {
          int32 int_size;
          parse(int_size, parser);
          stored_size = int_size;
          if (stored_size < 0) {
            stored_size += static_cast<int64>(1) << 32;
          }
        }
        int64 size = has_expected_size ? 0 : stored_size;
        int64 expected_size = has_expected_size ? stored_size : 0;
        string name;
        parse(name, parser);
        DialogId owner_dialog_id;
        if (parser.version() >= static_cast<int32>(Version::StoreFileOwnerId)) {
          parse(owner_dialog_id, parser);
        }
        return register_remote(full_remote_location, FileLocationSource::FromBinlog, owner_dialog_id, size,
                               expected_size, name);
      }
      case FileStoreType::Local: {
        FullLocalFileLocation full_local_location;
        parse(full_local_location, parser);
        int64 size;
        if (has_64bit_size) {
          parse(size, parser);
        } else {
          int32 int_size;
          parse(int_size, parser);
          size = int_size;
          if (size < 0) {
            size += static_cast<int64>(1) << 32;
          }
        }
        int32 get_by_hash;
        parse(get_by_hash, parser);
        DialogId owner_dialog_id;
        if (parser.version() >= static_cast<int32>(Version::StoreFileOwnerId)) {
          parse(owner_dialog_id, parser);
        }
        auto r_file_id = register_local(full_local_location, owner_dialog_id, size, get_by_hash != 0);
        if (r_file_id.is_ok()) {
          return r_file_id.move_as_ok();
        }
        LOG(ERROR) << "Can't resend local file " << full_local_location << " of size " << size << " owned by "
                   << owner_dialog_id;
        return register_empty(full_local_location.file_type_);
      }
      case FileStoreType::Generate: {
        FullGenerateFileLocation full_generated_location;
        parse(full_generated_location, parser);
        int64 expected_size;
        if (has_64bit_size) {
          parse(expected_size, parser);
        } else {
          int32 int_size;
          parse(int_size, parser);
          expected_size = int_size;
          if (expected_size < 0) {
            expected_size += static_cast<int64>(1) << 32;
          }
          int32 zero;
          parse(zero, parser);
        }
        DialogId owner_dialog_id;
        if (parser.version() >= static_cast<int32>(Version::StoreFileOwnerId)) {
          parse(owner_dialog_id, parser);
        }
        if (begins_with(full_generated_location.conversion_, "#file_id#")) {
          LOG(ERROR) << "Can't resend message with '#file_id#...' location";
          return register_empty(full_generated_location.file_type_);
        }
        if (full_generated_location.conversion_ == "#_file_id#") {
          auto file_id = parse_file(parser);
          if (file_id.empty()) {
            return register_empty(full_generated_location.file_type_);
          }
          full_generated_location.conversion_ = PSTRING() << "#file_id#" << file_id.get();
        }

        return register_generate(full_generated_location.file_type_, full_generated_location.original_path_,
                                 full_generated_location.conversion_, owner_dialog_id, expected_size);
      }
      case FileStoreType::Url: {
        FileType type;
        string url;
        parse(type, parser);
        parse(url, parser);
        DialogId owner_dialog_id;
        if (parser.version() >= static_cast<int32>(Version::StoreFileOwnerId)) {
          parse(owner_dialog_id, parser);
        }
        return register_url(url, type, owner_dialog_id);
      }
    }
    return FileId();
  }();

  if (has_encryption_key || has_secure_key) {
    auto encryption_key_type = has_encryption_key ? FileEncryptionKey::Type::Secret : FileEncryptionKey::Type::Secure;
    FileEncryptionKey encryption_key;
    encryption_key.parse(encryption_key_type, parser);
    set_encryption_key(file_id, std::move(encryption_key));
  }

  return file_id;
}

}  // namespace td
