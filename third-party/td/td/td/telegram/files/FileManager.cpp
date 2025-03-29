//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileManager.h"

#include "td/telegram/ConfigManager.h"
#include "td/telegram/DownloadManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileData.h"
#include "td/telegram/files/FileDb.h"
#include "td/telegram/files/FileLoaderUtils.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileLocation.hpp"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/misc.h"
#include "td/telegram/SecureStorage.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/Version.h"

#include "td/actor/SleepActor.h"

#include "td/utils/algorithm.h"
#include "td/utils/base64.h"
#include "td/utils/crypto.h"
#include "td/utils/filesystem.h"
#include "td/utils/format.h"
#include "td/utils/HttpUrl.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/PathView.h"
#include "td/utils/port/Stat.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_parsers.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <numeric>
#include <tuple>
#include <utility>

namespace td {
namespace {
constexpr int64 MAX_FILE_SIZE = static_cast<int64>(4000) << 20;  // 4000MB
}  // namespace

int VERBOSITY_NAME(update_file) = VERBOSITY_NAME(INFO);

StringBuilder &operator<<(StringBuilder &string_builder, FileLocationSource source) {
  switch (source) {
    case FileLocationSource::None:
      return string_builder << "None";
    case FileLocationSource::FromUser:
      return string_builder << "User";
    case FileLocationSource::FromBinlog:
      return string_builder << "Binlog";
    case FileLocationSource::FromDatabase:
      return string_builder << "Database";
    case FileLocationSource::FromServer:
      return string_builder << "Server";
    default:
      UNREACHABLE();
      return string_builder << "Unknown";
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, const NewRemoteFileLocation &location) {
  if (location.is_full_alive) {
    string_builder << "alive ";
  }
  if (location.full) {
    string_builder << location.full.value();
  } else {
    string_builder << "[no location]";
  }
  return string_builder << " from " << location.full_source;
}

StringBuilder &operator<<(StringBuilder &string_builder, FileManager::DownloadQuery::Type type) {
  switch (type) {
    case FileManager::DownloadQuery::Type::DownloadWaitFileReference:
      return string_builder << "DownloadWaitFileReference";
    case FileManager::DownloadQuery::Type::DownloadReloadDialog:
      return string_builder << "DownloadReloadDialog";
    case FileManager::DownloadQuery::Type::Download:
      return string_builder << "Download";
    case FileManager::DownloadQuery::Type::SetContent:
      return string_builder << "SetContent";
    default:
      UNREACHABLE();
      return string_builder << "Unknown";
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, FileManager::UploadQuery::Type type) {
  switch (type) {
    case FileManager::UploadQuery::Type::UploadByHash:
      return string_builder << "UploadByHash";
    case FileManager::UploadQuery::Type::UploadWaitFileReference:
      return string_builder << "UploadWaitFileReference";
    case FileManager::UploadQuery::Type::Upload:
      return string_builder << "Upload";
    default:
      UNREACHABLE();
      return string_builder << "Unknown";
  }
}

NewRemoteFileLocation::NewRemoteFileLocation(RemoteFileLocation remote, FileLocationSource source) {
  switch (remote.type()) {
    case RemoteFileLocation::Type::Empty:
      break;
    case RemoteFileLocation::Type::Partial:
      partial = make_unique<PartialRemoteFileLocation>(remote.partial());
      break;
    case RemoteFileLocation::Type::Full:
      full = remote.full();
      full_source = source;
      is_full_alive = true;
      break;
    default:
      UNREACHABLE();
  }
}

RemoteFileLocation NewRemoteFileLocation::partial_or_empty() const {
  if (partial) {
    return RemoteFileLocation(*partial);
  }
  return {};
}

class FileManager::FileInfoLocal final : public FileManager::FileInfo {
  FullLocalFileLocation location_;
  int64 size_ = 0;
  unique_ptr<PartialRemoteFileLocation> partial_remote_location_;
  FileIdInfo *remote_file_info_ = nullptr;

 public:
  FileInfoLocal(FullLocalFileLocation location, int64 size) : location_(std::move(location)), size_(size) {
  }

  FileInfoType get_file_info_type() const final {
    return FileInfoType::Local;
  }

  FileType get_file_type() const final {
    return location_.file_type_;
  }

  int64 get_local_size() const final {
    return size_;
  }

  int64 get_remote_size() const final {
    if (remote_file_info_ != nullptr) {
      if (remote_file_info_->file_info_ != nullptr) {
        return remote_file_info_->file_info_->get_remote_size();
      }
      return 0;
    }
    if (partial_remote_location_ != nullptr) {
      return partial_remote_location_->ready_size_;
    }
    return 0;
  }

  int64 get_size() const final {
    return size_;
  }

  int64 get_expected_size(bool) const final {
    return size_;
  }

  const FullLocalFileLocation *get_local_location() const final {
    return &location_;
  }

  const FullGenerateFileLocation *get_generate_location() const final {
    return nullptr;
  }

  const FullRemoteFileLocation *get_remote_location() const final {
    if (remote_file_info_ != nullptr && remote_file_info_->file_info_ != nullptr) {
      return remote_file_info_->file_info_->get_remote_location();
    }
    return nullptr;
  }

  const string *get_url() const final {
    return nullptr;
  }

  string get_path() const final {
    return location_.path_;
  }

  string get_suggested_path() const final {
    return location_.path_;
  }

  string get_remote_name() const final {
    return string();
  }

  string get_persistent_file_id() const final {
    return string();
  }

  string get_unique_file_id() const final {
    return string();
  }

  bool can_be_deleted() const final {
    return begins_with(location_.path_, get_files_dir(get_file_type()));
  }

  void set_size(int64 size) final {
    UNREACHABLE();
  }

  void set_expected_size(int64 expected_size) final {
    UNREACHABLE();
  }

  void delete_file_reference(Slice file_reference) final {
    if (remote_file_info_ != nullptr && remote_file_info_->file_info_ != nullptr) {
      remote_file_info_->file_info_->delete_file_reference(file_reference);
    }
  }
};

class FileManager::FileInfoGenerate final : public FileManager::FileInfo {
  FullGenerateFileLocation location_;
  int64 expected_size_ = 0;
  string url_;
  unique_ptr<PartialLocalFileLocation> partial_local_location_;
  unique_ptr<PartialRemoteFileLocation> partial_remote_location_;
  FileIdInfo *local_file_info_ = nullptr;

 public:
  FileInfoGenerate(FullGenerateFileLocation location, int64 expected_size, string url)
      : location_(std::move(location)), expected_size_(expected_size), url_(std::move(url)) {
  }

  FileInfoType get_file_info_type() const final {
    return FileInfoType::Generate;
  }

  FileType get_file_type() const final {
    return location_.file_type_;
  }

  int64 get_local_size() const final {
    if (local_file_info_ != nullptr) {
      if (local_file_info_->file_info_ != nullptr) {
        return local_file_info_->file_info_->get_local_size();
      }
      return 0;
    }
    if (partial_local_location_ != nullptr) {
      return partial_local_location_->ready_size_;
    }
    return 0;
  }

  int64 get_remote_size() const final {
    if (local_file_info_ != nullptr) {
      if (local_file_info_->file_info_ != nullptr) {
        return local_file_info_->file_info_->get_remote_size();
      }
      return 0;
    }
    if (partial_remote_location_ != nullptr) {
      return partial_remote_location_->ready_size_;
    }
    return 0;
  }

  int64 get_size() const final {
    if (local_file_info_ == nullptr) {
      return 0;
    }
    if (local_file_info_->file_info_ != nullptr) {
      return local_file_info_->file_info_->get_size();
    }
    return 0;
  }

  int64 get_expected_size(bool may_guess) const final {
    if (local_file_info_ != nullptr) {
      if (local_file_info_->file_info_ != nullptr) {
        return local_file_info_->file_info_->get_size();
      }
      return 0;
    }
    int64 current_size = 0;
    if (partial_local_location_ != nullptr) {
      current_size = partial_local_location_->ready_size_;
    }
    if (expected_size_ != 0) {
      return max(current_size, expected_size_);
    }
    return may_guess ? current_size * 3 : current_size;
  }

  const FullLocalFileLocation *get_local_location() const final {
    if (local_file_info_ != nullptr && local_file_info_->file_info_ != nullptr) {
      return local_file_info_->file_info_->get_local_location();
    }
    return nullptr;
  }

  const FullGenerateFileLocation *get_generate_location() const final {
    return &location_;
  }

  const FullRemoteFileLocation *get_remote_location() const final {
    if (local_file_info_ != nullptr && local_file_info_->file_info_ != nullptr) {
      return local_file_info_->file_info_->get_remote_location();
    }
    return nullptr;
  }

  const string *get_url() const final {
    return url_.empty() ? nullptr : &url_;
  }

  string get_path() const final {
    if (local_file_info_ != nullptr) {
      if (local_file_info_->file_info_ != nullptr) {
        return local_file_info_->file_info_->get_path();
      }
      return string();
    }
    if (partial_local_location_ != nullptr) {
      return partial_local_location_->path_;
    }
    return string();
  }

  string get_suggested_path() const final {
    if (!url_.empty()) {
      return get_url_file_name(url_);
    }
    return location_.original_path_;
  }

  string get_remote_name() const final {
    return string();
  }

  string get_persistent_file_id() const final {
    if (!url_.empty()) {
      return url_;
    }
    if (FileManager::is_remotely_generated_file(location_.conversion_)) {
      return FileNode::get_persistent_id(location_);
    }
    return string();
  }

  string get_unique_file_id() const final {
    if (FileManager::is_remotely_generated_file(location_.conversion_)) {
      return FileNode::get_unique_id(location_);
    }
    return string();
  }

  bool can_be_deleted() const final {
    if (local_file_info_ != nullptr) {
      if (local_file_info_->file_info_ != nullptr) {
        return local_file_info_->file_info_->can_be_deleted();
      }
      return false;
    }
    return partial_local_location_ != nullptr;
  }

  void set_size(int64 size) final {
    UNREACHABLE();
  }

  void set_expected_size(int64 expected_size) final {
    if (expected_size_ != expected_size) {
      expected_size_ = expected_size;
      on_changed();
    }
  }

  void delete_file_reference(Slice file_reference) final {
    if (local_file_info_ != nullptr && local_file_info_->file_info_ != nullptr) {
      local_file_info_->file_info_->delete_file_reference(file_reference);
    }
  }
};

class FileManager::FileInfoRemote final : public FileManager::FileInfo {
  FullRemoteFileLocation location_;
  int64 size_ = 0;
  int64 expected_size_ = 0;
  string remote_name_;
  string url_;
  unique_ptr<PartialLocalFileLocation> partial_local_location_;
  FileIdInfo *local_file_info_ = nullptr;

 public:
  FileInfoRemote(FullRemoteFileLocation location, int64 size, int64 expected_size, string remote_name, string url)
      : location_(std::move(location))
      , size_(size)
      , expected_size_(expected_size)
      , remote_name_(std::move(remote_name))
      , url_(std::move(url)) {
  }

  FileInfoType get_file_info_type() const final {
    return FileInfoType::Remote;
  }

  FileType get_file_type() const final {
    return location_.file_type_;
  }

  int64 get_local_size() const final {
    if (local_file_info_ != nullptr) {
      if (local_file_info_->file_info_ != nullptr) {
        return local_file_info_->file_info_->get_local_size();
      }
      return 0;
    }
    if (partial_local_location_ != nullptr) {
      return partial_local_location_->ready_size_;
    }
    return 0;
  }

  int64 get_remote_size() const final {
    return size_;
  }

  int64 get_size() const final {
    return size_;
  }

  int64 get_expected_size(bool) const final {
    if (size_ != 0) {
      return size_;
    }
    if (partial_local_location_ != nullptr) {
      return max(partial_local_location_->ready_size_, expected_size_);
    }
    return expected_size_;
  }

  const FullLocalFileLocation *get_local_location() const final {
    if (local_file_info_ != nullptr && local_file_info_->file_info_ != nullptr) {
      return local_file_info_->file_info_->get_local_location();
    }
    return nullptr;
  }

  const FullGenerateFileLocation *get_generate_location() const final {
    return nullptr;
  }

  const FullRemoteFileLocation *get_remote_location() const final {
    return &location_;
  }

  const string *get_url() const final {
    return url_.empty() ? nullptr : &url_;
  }

  string get_path() const final {
    if (local_file_info_ != nullptr) {
      if (local_file_info_->file_info_ != nullptr) {
        return local_file_info_->file_info_->get_path();
      }
      return string();
    }
    if (partial_local_location_ != nullptr) {
      return partial_local_location_->path_;
    }
    return string();
  }

  string get_suggested_path() const final {
    if (!remote_name_.empty()) {
      return remote_name_;
    }
    if (!url_.empty()) {
      return get_url_file_name(url_);
    }
    return string();
  }

  string get_remote_name() const final {
    return remote_name_;
  }

  string get_persistent_file_id() const final {
    return FileNode::get_persistent_id(location_);
  }

  string get_unique_file_id() const final {
    if (location_.is_web()) {
      return string();
    }
    return FileNode::get_unique_id(location_);
  }

  bool can_be_deleted() const final {
    if (local_file_info_ != nullptr) {
      if (local_file_info_->file_info_ != nullptr) {
        return local_file_info_->file_info_->can_be_deleted();
      }
      return false;
    }
    return partial_local_location_ != nullptr;
  }

  void set_size(int64 size) final {
    if (size_ != size) {
      size_ = size;
      on_changed();
    }
  }

  void set_expected_size(int64 expected_size) final {
    UNREACHABLE();
  }

  void delete_file_reference(Slice file_reference) final {
    if (!location_.delete_file_reference(file_reference)) {
      VLOG(file_references) << "Can't delete unmatching file reference " << format::escaped(file_reference) << ", have "
                            << format::escaped(location_.get_file_reference());
    } else {
      on_database_changed();
    }
  }
};

FileNode *FileNodePtr::operator->() const {
  return get();
}

FileNode &FileNodePtr::operator*() const {
  return *get();
}

FileNode *FileNodePtr::get() const {
  auto res = get_unsafe();
  CHECK(res);
  return res;
}

FullRemoteFileLocation *FileNodePtr::get_remote() const {
  return file_manager_->get_remote(file_id_.get_remote());
}

FileNode *FileNodePtr::get_unsafe() const {
  CHECK(file_manager_ != nullptr);
  return file_manager_->get_file_node_raw(file_id_);
}

FileNodePtr::operator bool() const noexcept {
  return file_manager_ != nullptr && get_unsafe() != nullptr;
}

void FileNode::recalc_ready_prefix_size(int64 prefix_offset, int64 ready_prefix_size) {
  if (local_.type() != LocalFileLocation::Type::Partial) {
    return;
  }
  int64 new_local_ready_prefix_size;
  if (download_offset_ == prefix_offset) {
    new_local_ready_prefix_size = ready_prefix_size;
  } else {
    new_local_ready_prefix_size = Bitmask(Bitmask::Decode{}, local_.partial().ready_bitmask_)
                                      .get_ready_prefix_size(download_offset_, local_.partial().part_size_, size_);
  }
  if (new_local_ready_prefix_size != local_ready_prefix_size_) {
    VLOG(update_file) << "File " << main_file_id_ << " has changed local_ready_prefix_size from "
                      << local_ready_prefix_size_ << " to " << new_local_ready_prefix_size;
    local_ready_prefix_size_ = new_local_ready_prefix_size;
    on_info_changed();
  }
}

void FileNode::init_ready_size() {
  if (local_.type() != LocalFileLocation::Type::Partial) {
    return;
  }
  auto &partial = local_.partial();
  auto bitmask = Bitmask(Bitmask::Decode{}, partial.ready_bitmask_);
  local_ready_prefix_size_ = bitmask.get_ready_prefix_size(0, partial.part_size_, size_);
  partial.ready_size_ = bitmask.get_total_size(partial.part_size_, size_);
}

void FileNode::set_download_offset(int64 download_offset) {
  if (download_offset < 0 || download_offset > MAX_FILE_SIZE) {
    return;
  }
  if (download_offset == download_offset_) {
    return;
  }

  VLOG(update_file) << "File " << main_file_id_ << " has changed download_offset from " << download_offset_ << " to "
                    << download_offset;
  download_offset_ = download_offset;
  is_download_offset_dirty_ = true;
  recalc_ready_prefix_size(-1, -1);
  on_info_changed();
}

int64 FileNode::get_download_limit() const {
  if (ignore_download_limit_) {
    return 0;
  }
  return private_download_limit_;
}

void FileNode::update_effective_download_limit(int64 old_download_limit) {
  if (get_download_limit() == old_download_limit) {
    return;
  }

  // There should be no false positives here
  // And in case we turn off ignore_download_limit, set_download_limit will not change effective download limit
  VLOG(update_file) << "File " << main_file_id_ << " has changed download_limit from " << old_download_limit << " to "
                    << get_download_limit() << " (limit=" << private_download_limit_
                    << ";ignore=" << ignore_download_limit_ << ")";
  is_download_limit_dirty_ = true;
}

void FileNode::set_download_limit(int64 download_limit) {
  if (download_limit < 0) {
    return;
  }
  if (download_limit > MAX_FILE_SIZE) {
    download_limit = MAX_FILE_SIZE;
  }
  auto old_download_limit = get_download_limit();
  private_download_limit_ = download_limit;
  update_effective_download_limit(old_download_limit);
}

void FileNode::set_ignore_download_limit(bool ignore_download_limit) {
  auto old_download_limit = get_download_limit();
  ignore_download_limit_ = ignore_download_limit;
  update_effective_download_limit(old_download_limit);
}

void FileNode::drop_local_location() {
  set_local_location(LocalFileLocation(), -1, -1);
}

void FileNode::set_local_location(const LocalFileLocation &local, int64 prefix_offset, int64 ready_prefix_size) {
  if (local_ != local) {
    VLOG(update_file) << "File " << main_file_id_ << " has changed local location";
    local_ = local;

    recalc_ready_prefix_size(prefix_offset, ready_prefix_size);

    on_changed();
  }
}

void FileNode::set_new_remote_location(NewRemoteFileLocation new_remote) {
  if (new_remote.full) {
    if (remote_.full && remote_.full.value() == new_remote.full.value()) {
      if (remote_.full.value().get_access_hash() != new_remote.full.value().get_access_hash() ||
          remote_.full.value().get_file_reference() != new_remote.full.value().get_file_reference() ||
          remote_.full.value().get_source() != new_remote.full.value().get_source()) {
        on_pmc_changed();
      }
    } else {
      VLOG(update_file) << "File " << main_file_id_ << " has changed remote location";
      on_changed();
    }
    remote_.full = new_remote.full;
    remote_.full_source = new_remote.full_source;
    remote_.is_full_alive = new_remote.is_full_alive;
  } else {
    if (remote_.full) {
      VLOG(update_file) << "File " << main_file_id_ << " has lost remote location";
      remote_.full = {};
      remote_.is_full_alive = false;
      remote_.full_source = FileLocationSource::None;
      on_changed();
    }
  }

  if (new_remote.partial) {
    set_partial_remote_location(*new_remote.partial);
  } else {
    delete_partial_remote_location();
  }
}
void FileNode::delete_partial_remote_location() {
  if (remote_.partial) {
    VLOG(update_file) << "File " << main_file_id_ << " has lost partial remote location";
    remote_.partial.reset();
    on_changed();
  }
}

void FileNode::set_partial_remote_location(PartialRemoteFileLocation remote) {
  if (remote_.is_full_alive) {
    VLOG(update_file) << "File " << main_file_id_ << " remote is still alive, so there is NO reason to update partial";
    return;
  }
  if (remote_.partial && *remote_.partial == remote) {
    VLOG(update_file) << "Partial location of " << main_file_id_ << " is NOT changed";
    return;
  }
  if (!remote_.partial && remote.ready_part_count_ == 0) {
    // empty partial remote is equal to empty remote
    VLOG(update_file) << "Partial location of " << main_file_id_
                      << " is still empty, so there is NO reason to update it";
    return;
  }

  VLOG(update_file) << "File " << main_file_id_ << " partial location has changed to " << remote;
  remote_.partial = make_unique<PartialRemoteFileLocation>(std::move(remote));
  on_changed();
}

bool FileNode::delete_file_reference(Slice file_reference) {
  if (!remote_.full) {
    VLOG(file_references) << "Can't delete file reference, because there is no remote location";
    return false;
  }

  if (!remote_.full.value().delete_file_reference(file_reference)) {
    VLOG(file_references) << "Can't delete unmatching file reference " << format::escaped(file_reference) << ", have "
                          << format::escaped(remote_.full.value().get_file_reference());
    return false;
  }

  VLOG(file_references) << "Do delete file reference of main file " << main_file_id_;
  upload_was_update_file_reference_ = false;
  download_was_update_file_reference_ = false;
  on_pmc_changed();
  return true;
}

void FileNode::set_generate_location(unique_ptr<FullGenerateFileLocation> &&generate) {
  bool is_changed = generate_ == nullptr ? generate != nullptr : generate == nullptr || *generate_ != *generate;
  if (is_changed) {
    generate_ = std::move(generate);
    on_pmc_changed();
  }
}

void FileNode::set_size(int64 size) {
  if (size_ != size) {
    VLOG(update_file) << "File " << main_file_id_ << " has changed size to " << size;
    size_ = size;
    on_changed();
  }
}

void FileNode::set_expected_size(int64 expected_size) {
  if (expected_size_ != expected_size) {
    VLOG(update_file) << "File " << main_file_id_ << " has changed expected size to " << expected_size;
    expected_size_ = expected_size;
    on_changed();
  }
}

void FileNode::set_remote_name(string remote_name) {
  if (remote_name_ != remote_name) {
    remote_name_ = std::move(remote_name);
    on_pmc_changed();
  }
}

void FileNode::set_url(string url) {
  if (url_ != url) {
    VLOG(update_file) << "File " << main_file_id_ << " has changed URL to " << url;
    url_ = std::move(url);
    on_changed();
  }
}

void FileNode::set_owner_dialog_id(DialogId owner_id) {
  if (owner_dialog_id_ != owner_id) {
    owner_dialog_id_ = owner_id;
    on_pmc_changed();
  }
}

void FileNode::set_encryption_key(FileEncryptionKey key) {
  if (encryption_key_ != key) {
    encryption_key_ = std::move(key);
    on_pmc_changed();
  }
}

void FileNode::set_upload_pause(FileUploadId upload_pause) {
  if (upload_pause_ != upload_pause) {
    LOG(INFO) << "Change file " << main_file_id_ << " upload_pause from " << upload_pause_ << " to " << upload_pause;
    if (upload_pause_.is_valid() != upload_pause.is_valid()) {
      on_info_changed();
    }
    upload_pause_ = upload_pause;
  }
}

void FileNode::set_download_priority(int8 priority) {
  if ((download_priority_ == 0) != (priority == 0)) {
    VLOG(update_file) << "File " << main_file_id_ << " has changed download priority to " << priority;
    on_info_changed();
  }
  download_priority_ = priority;
}

void FileNode::set_upload_priority(int8 priority) {
  if (!remote_.is_full_alive && (upload_priority_ == 0) != (priority == 0)) {
    VLOG(update_file) << "File " << main_file_id_ << " has changed upload priority to " << priority;
    on_info_changed();
  }
  upload_priority_ = priority;
}

void FileNode::set_generate_priority(int8 download_priority, int8 upload_priority) {
  if ((generate_download_priority_ == 0) != (download_priority == 0) ||
      (generate_upload_priority_ == 0) != (upload_priority == 0)) {
    VLOG(update_file) << "File " << main_file_id_ << " has changed generate priority to " << download_priority << "/"
                      << upload_priority;
    on_info_changed();
  }
  generate_priority_ = max(download_priority, upload_priority);
  generate_download_priority_ = download_priority;
  generate_upload_priority_ = upload_priority;
}

void FileNode::on_changed() {
  on_pmc_changed();
  on_info_changed();
}

void FileNode::on_info_changed() {
  info_changed_flag_ = true;
}

void FileNode::on_pmc_changed() {
  pmc_changed_flag_ = true;
}

bool FileNode::need_info_flush() const {
  return info_changed_flag_;
}

bool FileNode::need_pmc_flush() const {
  if (!pmc_changed_flag_) {
    return false;
  }

  // already in pmc
  if (pmc_id_.is_valid()) {
    return true;
  }

  // We must save encryption key
  if (!encryption_key_.empty()) {
    // && remote_.type() != RemoteFileLocation::Type::Empty
    return true;
  }

  bool has_generate_location = generate_ != nullptr;
  // Do not save "#file_id#" conversion.
  if (has_generate_location && begins_with(generate_->conversion_, "#file_id#")) {
    has_generate_location = false;
  }

  if (remote_.full/* &&
      (has_generate_location || local_.type() != LocalFileLocation::Type::Empty)*/) {
    // we need to always save file sources
    return true;
  }
  if (local_.type() == LocalFileLocation::Type::Full && (has_generate_location || remote_.full || remote_.partial)) {
    return true;
  }

  // TODO: Generate location with constant conversion

  return false;
}

void FileNode::on_pmc_flushed() {
  pmc_changed_flag_ = false;
}
void FileNode::on_info_flushed() {
  info_changed_flag_ = false;
}

string FileNode::suggested_path() const {
  if (!remote_name_.empty()) {
    return remote_name_;
  }
  if (!url_.empty()) {
    auto file_name = get_url_file_name(url_);
    if (!file_name.empty()) {
      return file_name;
    }
  }
  if (generate_ != nullptr) {
    if (!generate_->original_path_.empty()) {
      return generate_->original_path_;
    }
  }
  return local_.file_name().str();
}

/*** FileView ***/
bool FileView::has_full_local_location() const {
  return node_->local_.type() == LocalFileLocation::Type::Full;
}

const FullLocalFileLocation *FileView::get_full_local_location() const {
  if (!has_full_local_location()) {
    return nullptr;
  }
  return &node_->local_.full();
}

bool FileView::has_full_remote_location() const {
  return static_cast<bool>(node_->remote_.full);
}

bool FileView::has_alive_remote_location() const {
  return node_->remote_.is_full_alive;
}

bool FileView::has_active_upload_remote_location() const {
  const auto *main_remote_location = get_main_remote_location();
  if (main_remote_location == nullptr) {
    return false;
  }
  if (!has_alive_remote_location()) {
    return false;
  }
  if (main_remote_location->is_encrypted_any()) {
    return true;
  }
  return main_remote_location->has_file_reference();
}

bool FileView::has_active_download_remote_location() const {
  const auto *full_remote_location = get_full_remote_location();
  if (full_remote_location == nullptr) {
    return false;
  }
  if (full_remote_location->is_encrypted_any()) {
    return true;
  }
  return full_remote_location->has_file_reference();
}

const FullRemoteFileLocation *FileView::get_full_remote_location() const {
  const auto *remote = node_.get_remote();
  if (remote != nullptr) {
    return remote;
  }
  if (!has_full_remote_location()) {
    return nullptr;
  }
  return &node_->remote_.full.value();
}

const FullRemoteFileLocation *FileView::get_main_remote_location() const {
  if (!has_full_remote_location()) {
    return nullptr;
  }
  return &node_->remote_.full.value();
}

bool FileView::has_generate_location() const {
  return node_->generate_ != nullptr;
}

const FullGenerateFileLocation *FileView::get_generate_location() const {
  return node_->generate_.get();
}

int64 FileView::size() const {
  return node_->size_;
}

int64 FileView::get_allocated_local_size() const {
  auto file_path = path();
  if (file_path.empty()) {
    return 0;
  }
  auto r_stat = stat(file_path);
  if (r_stat.is_error()) {
    return 0;
  }
  return r_stat.ok().real_size_;
}

int64 FileNode::expected_size(bool may_guess) const {
  if (size_ != 0) {
    return size_;
  }
  int64 current_size = local_total_size();  // TODO: this is not the best approximation
  if (expected_size_ != 0) {
    return max(current_size, expected_size_);
  }
  if (may_guess && local_.type() == LocalFileLocation::Type::Partial) {
    current_size *= 3;
  }
  return current_size;
}

int64 FileView::expected_size(bool may_guess) const {
  return node_->expected_size(may_guess);
}

bool FileNode::is_downloading() const {
  return download_priority_ != 0 || generate_download_priority_ != 0;
}

bool FileView::is_downloading() const {
  return node_->is_downloading();
}

int64 FileView::download_offset() const {
  return node_->download_offset_;
}

int64 FileNode::downloaded_prefix(int64 offset) const {
  switch (local_.type()) {
    case LocalFileLocation::Type::Empty:
      return 0;
    case LocalFileLocation::Type::Full:
      if (offset < size_) {
        return size_ - offset;
      }
      return 0;
    case LocalFileLocation::Type::Partial:
      if (get_type() == FileType::SecureEncrypted) {
        // File is not decrypted and verified yet
        return 0;
      }
      return Bitmask(Bitmask::Decode{}, local_.partial().ready_bitmask_)
          .get_ready_prefix_size(offset, local_.partial().part_size_, size_);
    default:
      UNREACHABLE();
      return 0;
  }
}

int64 FileView::downloaded_prefix(int64 offset) const {
  return node_->downloaded_prefix(offset);
}

int64 FileNode::local_prefix_size() const {
  switch (local_.type()) {
    case LocalFileLocation::Type::Full:
      return download_offset_ <= size_ ? size_ - download_offset_ : 0;
    case LocalFileLocation::Type::Partial: {
      if (get_type() == FileType::SecureEncrypted) {
        // File is not decrypted and verified yet
        return 0;
      }
      return local_ready_prefix_size_;
    }
    default:
      return 0;
  }
}

int64 FileView::local_prefix_size() const {
  return node_->local_prefix_size();
}

int64 FileNode::local_total_size() const {
  switch (local_.type()) {
    case LocalFileLocation::Type::Empty:
      return 0;
    case LocalFileLocation::Type::Full:
      return size_;
    case LocalFileLocation::Type::Partial:
      return local_.partial().ready_size_;
    default:
      UNREACHABLE();
      return 0;
  }
}

int64 FileView::local_total_size() const {
  return node_->local_total_size();
}

bool FileNode::is_uploading() const {
  return upload_priority_ != 0 || generate_upload_priority_ != 0 || upload_pause_.is_valid();
}

bool FileView::is_uploading() const {
  return node_->is_uploading();
}

int64 FileNode::remote_size() const {
  if (remote_.is_full_alive) {
    return size_;
  }
  if (remote_.partial) {
    return remote_.partial->ready_size_;
  }
  return 0;
}

int64 FileView::remote_size() const {
  return node_->remote_size();
}

string FileNode::path() const {
  switch (local_.type()) {
    case LocalFileLocation::Type::Full:
      return local_.full().path_;
    case LocalFileLocation::Type::Partial:
      return local_.partial().path_;
    default:
      return string();
  }
}

string FileView::path() const {
  return node_->path();
}

bool FileView::has_url() const {
  return get_url() != nullptr;
}

const string *FileView::get_url() const {
  if (node_->url_.empty()) {
    return nullptr;
  }
  return &node_->url_;
}

string FileView::remote_name() const {
  return node_->remote_name_;
}

string FileView::suggested_path() const {
  return node_->suggested_path();
}

DialogId FileView::owner_dialog_id() const {
  return node_->owner_dialog_id_;
}

bool FileView::get_by_hash() const {
  return node_->get_by_hash_;
}

FileView::FileView(ConstFileNodePtr node) : node_(node) {
}

bool FileView::empty() const {
  return !node_;
}

bool FileView::can_download_from_server() const {
  const auto *full_remote_location = get_full_remote_location();
  if (full_remote_location == nullptr) {
    return false;
  }
  if (full_remote_location->file_type_ == FileType::Encrypted && encryption_key().empty()) {
    return false;
  }
  if (full_remote_location->is_web()) {
    return true;
  }
  if (full_remote_location->get_dc_id().is_empty()) {
    return false;
  }
  if (!full_remote_location->is_encrypted_any() && !full_remote_location->has_file_reference() &&
      ((node_->download_id_ == 0 && node_->download_was_update_file_reference_) || !node_->remote_.is_full_alive)) {
    return false;
  }
  return true;
}

bool FileView::can_generate() const {
  return has_generate_location();
}

bool FileNode::can_delete() const {
  if (local_.type() == LocalFileLocation::Type::Full) {
    return begins_with(local_.full().path_, get_files_dir(get_type()));
  }
  return local_.type() == LocalFileLocation::Type::Partial;
}

bool FileView::can_delete() const {
  return node_->can_delete();
}

string FileNode::get_unique_id(const FullGenerateFileLocation &location) {
  return base64url_encode(zero_encode('\xff' + serialize(location)));
}

string FileNode::get_unique_id(const FullRemoteFileLocation &location) {
  return base64url_encode(zero_encode(serialize(location.as_unique())));
}

string FileNode::get_persistent_id(const FullGenerateFileLocation &location) {
  auto binary = serialize(location);

  binary = zero_encode(binary);
  binary.push_back(PERSISTENT_ID_VERSION_GENERATED);
  return base64url_encode(binary);
}

string FileNode::get_persistent_id(const FullRemoteFileLocation &location) {
  auto binary = serialize(location);

  binary = zero_encode(binary);
  binary.push_back(static_cast<char>(narrow_cast<uint8>(Version::Next) - 1));
  binary.push_back(PERSISTENT_ID_VERSION);
  return base64url_encode(binary);
}

string FileNode::get_persistent_file_id() const {
  if (remote_.is_full_alive) {
    return get_persistent_id(remote_.full.value());
  } else if (!url_.empty()) {
    return url_;
  } else if (generate_ != nullptr && FileManager::is_remotely_generated_file(generate_->conversion_)) {
    return get_persistent_id(*generate_);
  }
  return string();
}

string FileNode::get_unique_file_id() const {
  if (remote_.is_full_alive) {
    if (!remote_.full.value().is_web()) {
      return get_unique_id(remote_.full.value());
    }
  } else if (generate_ != nullptr && FileManager::is_remotely_generated_file(generate_->conversion_)) {
    return get_unique_id(*generate_);
  }
  return string();
}

/*** FileManager ***/
static int merge_choose_remote_location(const FullRemoteFileLocation &x, FileLocationSource x_source,
                                        const FullRemoteFileLocation &y, FileLocationSource y_source);

namespace {
void prepare_path_for_pmc(FileType file_type, string &path) {
  path = PathView::relative(path, get_files_base_dir(file_type)).str();
}
}  // namespace

class FileManager::UserDownloadFileCallback final : public FileManager::DownloadCallback {
  FileManager *file_manager_;

 public:
  explicit UserDownloadFileCallback(FileManager *file_manager) : file_manager_(file_manager) {
  }

  void on_download_ok(FileId file_id) final {
    file_manager_->on_user_file_download_finished(file_id);
  }

  void on_download_error(FileId file_id, Status error) final {
    file_manager_->on_user_file_download_finished(file_id);
  }
};

class FileManager::PreliminaryUploadFileCallback final : public UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    // cancel file upload of the file to allow next upload with the same file to succeed
    send_closure(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
  }

  void on_upload_encrypted_ok(FileUploadId file_upload_id,
                              telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file) final {
    // cancel file upload of the file to allow next upload with the same file to succeed
    send_closure(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
  }

  void on_upload_secure_ok(FileUploadId file_upload_id,
                           telegram_api::object_ptr<telegram_api::InputSecureFile> input_file) final {
    // cancel file upload of the file to allow next upload with the same file to succeed
    send_closure(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
  }
};

FileManager::FileManager(unique_ptr<Context> context)
    : user_download_file_callback_(std::make_shared<UserDownloadFileCallback>(this)), context_(std::move(context)) {
  if (G()->use_file_database()) {
    file_db_ = G()->td_db()->get_file_db_shared();
  }

  parent_ = context_->create_reference();
  next_file_id();
  next_file_node_id();

  G()->td_db()->with_db_path([bad_paths = &bad_paths_](CSlice path) { bad_paths->insert(path.str()); });
}

void FileManager::init_actor() {
  file_download_manager_ = create_actor_on_scheduler<FileDownloadManager>(
      "FileDownloadManager", G()->get_slow_net_scheduler_id(), make_unique<FileDownloadManagerCallback>(actor_id(this)),
      context_->create_reference());
  file_load_manager_ = create_actor_on_scheduler<FileLoadManager>("FileLoadManager", G()->get_slow_net_scheduler_id());
  file_upload_manager_ = create_actor_on_scheduler<FileUploadManager>(
      "FileUploadManager", G()->get_slow_net_scheduler_id(), make_unique<FileUploadManagerCallback>(actor_id(this)),
      context_->create_reference());
  file_generate_manager_ = create_actor_on_scheduler<FileGenerateManager>(
      "FileGenerateManager", G()->get_slow_net_scheduler_id(), context_->create_reference());
}

FileManager::~FileManager() {
  Scheduler::instance()->destroy_on_scheduler(
      G()->get_gc_scheduler_id(), remote_location_info_, file_hash_to_file_id_, remote_location_to_file_id_,
      local_location_to_file_id_, generate_location_to_file_id_, file_id_info_, empty_file_ids_, file_nodes_);
}

string FileManager::fix_file_extension(Slice file_name, Slice file_type, Slice file_extension) {
  return PSTRING() << (file_name.empty() ? file_type : file_name) << '.' << file_extension;
}

string FileManager::get_file_name(FileType file_type, Slice path) {
  PathView path_view(path);
  auto file_name = path_view.file_name();
  auto extension = path_view.extension();
  switch (file_type) {
    case FileType::Thumbnail:
      if (extension != "jpg" && extension != "jpeg" && extension != "webp") {
        return fix_file_extension(file_name, "thumbnail", "jpg");
      }
      break;
    case FileType::ProfilePhoto:
    case FileType::Photo:
    case FileType::PhotoStory:
    case FileType::SelfDestructingPhoto:
      if (extension != "jpg" && extension != "jpeg" && extension != "gif" && extension != "png" && extension != "tif" &&
          extension != "bmp") {
        return fix_file_extension(file_name, "photo", "jpg");
      }
      break;
    case FileType::VoiceNote:
    case FileType::SelfDestructingVoiceNote:
      if (extension != "ogg" && extension != "oga" && extension != "mp3" && extension != "mpeg3" &&
          extension != "m4a" && extension != "opus") {
        return fix_file_extension(file_name, "voice", "oga");
      }
      break;
    case FileType::Video:
    case FileType::VideoNote:
    case FileType::SelfDestructingVideo:
    case FileType::SelfDestructingVideoNote:
      if (extension != "mov" && extension != "3gp" && extension != "mpeg4" && extension != "mp4" &&
          extension != "mkv") {
        return fix_file_extension(file_name, "video", "mp4");
      }
      break;
    case FileType::VideoStory:
      if (extension != "mp4") {
        return fix_file_extension(file_name, "video", "mp4");
      }
      break;
    case FileType::Audio:
      if (extension != "ogg" && extension != "oga" && extension != "mp3" && extension != "mpeg3" &&
          extension != "m4a") {
        return fix_file_extension(file_name, "audio", "mp3");
      }
      break;
    case FileType::Wallpaper:
    case FileType::Background:
      if (extension != "jpg" && extension != "jpeg" && extension != "png") {
        return fix_file_extension(file_name, "wallpaper", "jpg");
      }
      break;
    case FileType::Sticker:
      if (extension != "webp" && extension != "tgs" && extension != "webm") {
        return fix_file_extension(file_name, "sticker", "webp");
      }
      break;
    case FileType::Ringtone:
      if (extension != "ogg" && extension != "oga" && extension != "mp3" && extension != "mpeg3") {
        return fix_file_extension(file_name, "notification_sound", "mp3");
      }
      break;
    case FileType::Document:
    case FileType::DocumentAsFile:
    case FileType::Animation:
    case FileType::Encrypted:
    case FileType::Temp:
    case FileType::EncryptedThumbnail:
    case FileType::SecureEncrypted:
    case FileType::SecureDecrypted:
    case FileType::CallLog:
      break;
    default:
      UNREACHABLE();
  }
  return file_name.str();
}

Status FileManager::check_priority(int32 priority) {
  if (1 <= priority && priority <= 32) {
    return Status::OK();
  }
  return Status::Error(400, "Priority must be between 1 and 32");
}

bool FileManager::is_remotely_generated_file(Slice conversion) {
  return begins_with(conversion, "#map#") || begins_with(conversion, "#audio_t#");
}

vector<int> FileManager::get_missing_file_parts(const Status &error) {
  vector<int> result;
  auto error_message = error.message();
  if (begins_with(error_message, "FILE_PART_") && ends_with(error_message, "_MISSING")) {
    auto r_file_part = to_integer_safe<int>(error_message.substr(10, error_message.size() - 18));
    if (r_file_part.is_error() || r_file_part.ok() < 0) {
      LOG(ERROR) << "Receive error " << error;
    } else {
      result.push_back(r_file_part.ok());
    }
  } else if (error_message == "FILE_PART_INVALID" || error_message == "FILE_PART_LENGTH_INVALID") {
    result.push_back(0);
  }
  return result;
}

void FileManager::check_local_location(FileId file_id, bool skip_file_size_checks) {
  auto node = get_sync_file_node(file_id);
  if (node) {
    check_local_location(node, skip_file_size_checks).ignore();
  }
}

void FileManager::check_local_location_async(FileId file_id, bool skip_file_size_checks) {
  auto node = get_sync_file_node(file_id);
  if (node) {
    check_local_location_async(node, skip_file_size_checks, Promise<Unit>());
  }
}

Status FileManager::check_local_location(FileNodePtr node, bool skip_file_size_checks) {
  Status status;
  if (node->local_.type() == LocalFileLocation::Type::Full) {
    auto r_info = check_full_local_location({node->local_.full(), node->size_}, skip_file_size_checks);
    if (r_info.is_error()) {
      status = r_info.move_as_error();
    } else if (bad_paths_.count(r_info.ok().location_.path_) != 0) {
      status = Status::Error(400, "Sending of internal database files is forbidden");
    } else if (r_info.ok().location_ != node->local_.full() || r_info.ok().size_ != node->size_) {
      LOG(ERROR) << "Local location changed from " << node->local_.full() << " with size " << node->size_ << " to "
                 << r_info.ok().location_ << " with size " << r_info.ok().size_;
    }
  } else if (node->local_.type() == LocalFileLocation::Type::Partial) {
    status = check_partial_local_location(node->local_.partial());
  }
  if (status.is_error()) {
    on_failed_check_local_location(node);
  }
  return status;
}

void FileManager::on_failed_check_local_location(FileNodePtr node) {
  send_closure(G()->download_manager(), &DownloadManager::remove_file_if_finished, node->main_file_id_);
  node->drop_local_location();
  try_flush_node(node, "on_failed_check_local_location");
}

void FileManager::check_local_location_async(FileNodePtr node, bool skip_file_size_checks, Promise<Unit> promise) {
  if (node->local_.type() == LocalFileLocation::Type::Empty) {
    return promise.set_value(Unit());
  }

  if (node->local_.type() == LocalFileLocation::Type::Full) {
    send_closure(file_load_manager_, &FileLoadManager::check_full_local_location,
                 FullLocalLocationInfo{node->local_.full(), node->size_}, skip_file_size_checks,
                 PromiseCreator::lambda([actor_id = actor_id(this), file_id = node->main_file_id_,
                                         checked_location = node->local_,
                                         promise = std::move(promise)](Result<FullLocalLocationInfo> result) mutable {
                   send_closure(actor_id, &FileManager::on_check_full_local_location, file_id,
                                std::move(checked_location), std::move(result), std::move(promise));
                 }));
  } else {
    CHECK(node->local_.type() == LocalFileLocation::Type::Partial);
    send_closure(file_load_manager_, &FileLoadManager::check_partial_local_location, node->local_.partial(),
                 PromiseCreator::lambda([actor_id = actor_id(this), file_id = node->main_file_id_,
                                         checked_location = node->local_,
                                         promise = std::move(promise)](Result<Unit> result) mutable {
                   send_closure(actor_id, &FileManager::on_check_partial_local_location, file_id,
                                std::move(checked_location), std::move(result), std::move(promise));
                 }));
  }
}

void FileManager::on_check_full_local_location(FileId file_id, LocalFileLocation checked_location,
                                               Result<FullLocalLocationInfo> r_info, Promise<Unit> promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto node = get_file_node(file_id);
  if (!node) {
    return;
  }
  if (node->local_ != checked_location) {
    LOG(INFO) << "Full location changed while being checked; ignore check result";
    return promise.set_value(Unit());
  }
  Status status;
  if (r_info.is_error()) {
    status = r_info.move_as_error();
  } else if (bad_paths_.count(r_info.ok().location_.path_) != 0) {
    status = Status::Error(400, "Sending of internal database files is forbidden");
  } else if (r_info.ok().location_ != node->local_.full() || r_info.ok().size_ != node->size_) {
    LOG(ERROR) << "Local location changed from " << node->local_.full() << " with size " << node->size_ << " to "
               << r_info.ok().location_ << " with size " << r_info.ok().size_;
  }
  if (status.is_error()) {
    on_failed_check_local_location(node);
    promise.set_error(std::move(status));
  } else {
    promise.set_value(Unit());
  }
}

void FileManager::on_check_partial_local_location(FileId file_id, LocalFileLocation checked_location,
                                                  Result<Unit> result, Promise<Unit> promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto node = get_file_node(file_id);
  CHECK(node);
  if (node->local_ != checked_location) {
    LOG(INFO) << "Partial location changed while being checked; ignore check result";
    return promise.set_value(Unit());
  }
  if (result.is_error()) {
    on_failed_check_local_location(node);
    promise.set_error(result.move_as_error());
  } else {
    promise.set_value(Unit());
  }
}

void FileManager::recheck_full_local_location(FullLocalLocationInfo location_info, bool skip_file_size_checks) {
  auto promise = PromiseCreator::lambda([actor_id = actor_id(this), checked_location = location_info.location_](
                                            Result<FullLocalLocationInfo> result) mutable {
    send_closure(actor_id, &FileManager::on_recheck_full_local_location, std::move(checked_location),
                 std::move(result));
  });
  send_closure(file_load_manager_, &FileLoadManager::check_full_local_location, std::move(location_info),
               skip_file_size_checks, std::move(promise));
}

void FileManager::on_recheck_full_local_location(FullLocalFileLocation checked_location,
                                                 Result<FullLocalLocationInfo> r_info) {
  if (G()->close_flag()) {
    return;
  }

  auto file_id_it = local_location_to_file_id_.find(checked_location);
  if (file_id_it == local_location_to_file_id_.end()) {
    return;
  }
  auto file_id = file_id_it->second;

  on_check_full_local_location(file_id, LocalFileLocation(checked_location), std::move(r_info), Promise<Unit>());
}

bool FileManager::try_fix_partial_local_location(FileNodePtr node) {
  LOG(INFO) << "Trying to fix partial local location";
  if (node->local_.type() != LocalFileLocation::Type::Partial) {
    LOG(INFO) << "   failed - not a partial location";
    return false;
  }
  auto partial = node->local_.partial();
  if (!partial.iv_.empty()) {
    // can't recalc iv_
    LOG(INFO) << "   failed - partial location has nonempty iv";
    return false;
  }
  if (partial.part_size_ >= 512 * (1 << 10) || (partial.part_size_ & (partial.part_size_ - 1)) != 0) {
    LOG(INFO) << "   failed - too big part_size already: " << partial.part_size_;
    return false;
  }
  auto old_part_size = narrow_cast<int32>(partial.part_size_);
  int new_part_size = 512 * (1 << 10);
  auto k = new_part_size / old_part_size;
  Bitmask mask(Bitmask::Decode(), partial.ready_bitmask_);
  auto new_mask = mask.compress(k);

  partial.part_size_ = new_part_size;
  partial.ready_bitmask_ = new_mask.encode();
  partial.ready_size_ = new_mask.get_total_size(partial.part_size_, node->size_);
  node->set_local_location(LocalFileLocation(std::move(partial)), -1, -1);
  LOG(INFO) << "   ok: increase part_size " << old_part_size << "->" << new_part_size;
  return true;
}

FileManager::FileIdInfo *FileManager::get_file_id_info(FileId file_id) {
  CHECK(static_cast<size_t>(file_id.get()) < file_id_info_.size());
  return file_id_info_[file_id.get()].get();
}

FileId FileManager::copy_file_id(FileId file_id, FileType file_type, DialogId owner_dialog_id, const char *source) {
  auto file_view = get_file_view(file_id);
  auto result_file_id = register_generate(file_type, file_view.suggested_path(),
                                          PSTRING() << "#file_id#" << file_id.get(), owner_dialog_id, file_view.size());
  LOG(INFO) << "Copy file " << file_id << " to " << result_file_id << " from " << source;
  return result_file_id;
}

bool FileManager::try_forget_file_id(FileId file_id) {
  auto *info = get_file_id_info(file_id);
  if (info->pin_flag_) {
    LOG(DEBUG) << "Can't forget file " << file_id << ", because it is pinned";
    return false;
  }
  auto file_node = get_file_node(file_id);
  if (file_node->main_file_id_ == file_id) {
    LOG(DEBUG) << "Can't forget main file " << file_id;
    return false;
  }

  LOG(DEBUG) << "Forget file " << file_id;
  bool is_removed = td::remove(file_node->file_ids_, file_id);
  CHECK(is_removed);
  *info = FileIdInfo();
  empty_file_ids_.push_back(file_id.get());
  return true;
}

FileId FileManager::register_empty(FileType type) {
  auto location = FullLocalFileLocation(type, "", 0);
  auto &file_id = local_location_to_file_id_[location];
  if (file_id.is_valid()) {
    return file_id;
  }
  file_id = next_file_id();

  LOG(INFO) << "Register empty file as " << file_id;
  auto file_info = STORE_FILE_INFO ? td::make_unique<FileInfoLocal>(location, 0) : nullptr;
  auto file_node_id = next_file_node_id();
  file_nodes_[file_node_id] =
      td::make_unique<FileNode>(LocalFileLocation(std::move(location)), NewRemoteFileLocation(), nullptr, 0, 0,
                                string(), string(), DialogId(), FileEncryptionKey(), file_id, static_cast<int8>(0));

  auto file_id_info = get_file_id_info(file_id);
  file_id_info->node_id_ = file_node_id;
  file_id_info->file_info_ = std::move(file_info);
  file_id_info->pin_flag_ = true;

  return file_id;
}

void FileManager::on_file_unlink(const FullLocalFileLocation &location) {
  auto it = local_location_to_file_id_.find(location);
  if (it == local_location_to_file_id_.end()) {
    return;
  }
  auto file_id = it->second;
  auto file_node = get_sync_file_node(file_id);
  CHECK(file_node);
  clear_from_pmc(file_node);
  send_closure(G()->download_manager(), &DownloadManager::remove_file_if_finished, file_node->main_file_id_);
  file_node->drop_local_location();
  try_flush_node(file_node, "on_file_unlink");
}

Result<FileId> FileManager::register_local(FullLocalFileLocation location, DialogId owner_dialog_id, int64 size,
                                           bool get_by_hash, bool skip_file_size_checks, FileId merge_file_id) {
  TRY_RESULT(info, check_full_local_location({std::move(location), size}, skip_file_size_checks));
  location = std::move(info.location_);
  size = info.size_;

  if (bad_paths_.count(location.path_) != 0) {
    return Status::Error(400, "Sending of internal database files is forbidden");
  }

  auto &file_id = local_location_to_file_id_[location];
  bool is_new = false;
  if (!file_id.is_valid()) {
    file_id = next_file_id();
    LOG(INFO) << "Register " << location << " as " << file_id;

    auto file_info = STORE_FILE_INFO ? td::make_unique<FileInfoLocal>(location, size) : nullptr;
    auto file_node_id = next_file_node_id();
    auto &node = file_nodes_[file_node_id];
    node = td::make_unique<FileNode>(LocalFileLocation(std::move(location)), NewRemoteFileLocation(), nullptr, size, 0,
                                     string(), string(), owner_dialog_id, FileEncryptionKey(), file_id,
                                     static_cast<int8>(0));
    node->need_load_from_pmc_ = true;
    auto file_id_info = get_file_id_info(file_id);
    file_id_info->node_id_ = file_node_id;
    file_id_info->file_info_ = std::move(file_info);
    is_new = true;
  }

  if (merge_file_id.is_valid()) {
    auto status = merge(file_id, merge_file_id);
    if (status.is_ok()) {
      auto node = get_file_node(file_id);
      auto main_file_id = node->main_file_id_;
      if (main_file_id != file_id) {
        auto *file_info = get_file_id_info(file_id);
        if (is_new && !file_info->pin_flag_) {
          bool is_removed = try_forget_file_id(file_id);
          CHECK(is_removed);
          node = get_file_node(main_file_id);
        }
        file_id = main_file_id;
      }
      try_flush_node(node, "register_local");
    }
    if (is_new) {
      get_file_id_info(file_id)->pin_flag_ = true;
    }
    if (status.is_error()) {
      return std::move(status);
    }
  } else if (is_new) {
    get_file_id_info(file_id)->pin_flag_ = true;
  }
  return file_id;
}

FileId FileManager::register_remote(FullRemoteFileLocation location, FileLocationSource file_location_source,
                                    DialogId owner_dialog_id, int64 size, int64 expected_size, string remote_name) {
  if (size < 0) {
    LOG(ERROR) << "Receive file " << location << " of size " << size;
    size = 0;
  }
  if (expected_size < 0) {
    LOG(ERROR) << "Receive file " << location << " of expected size " << expected_size;
    expected_size = 0;
  }
  auto url = location.get_url();

  FileId file_id;
  FileId merge_file_id;
  int32 remote_key = 0;
  if (context_->keep_exact_remote_location()) {
    file_id = next_file_id();
    RemoteInfo info{location, file_location_source, file_id};
    remote_key = remote_location_info_.add(info);
    auto &stored_info = remote_location_info_.get(remote_key);
    if (stored_info.file_id_ != file_id) {
      merge_file_id = stored_info.file_id_;
      if (merge_choose_remote_location(location, file_location_source, stored_info.remote_,
                                       stored_info.file_location_source_) == 0) {
        stored_info.remote_ = location;
        stored_info.file_location_source_ = file_location_source;
      }
    }
  } else {
    auto &other_id = remote_location_to_file_id_[location];
    if (other_id.is_valid() && get_file_node(other_id)->remote_.full_source == FileLocationSource::FromServer) {
      // if the file has already been received from the server, then we don't need merge or create new file
      // skip merging of dc_id, file_reference, and access_hash
      return other_id;
    }

    file_id = next_file_id();
    if (other_id.empty()) {
      other_id = file_id;
    } else {
      merge_file_id = other_id;
    }
  }

  LOG(INFO) << "Register " << location << " as " << file_id;
  auto file_info =
      STORE_FILE_INFO ? td::make_unique<FileInfoRemote>(location, size, expected_size, remote_name, url) : nullptr;
  auto file_node_id = next_file_node_id();
  auto &node = file_nodes_[file_node_id];
  node = td::make_unique<FileNode>(LocalFileLocation(),
                                   NewRemoteFileLocation(RemoteFileLocation(std::move(location)), file_location_source),
                                   nullptr, size, expected_size, std::move(remote_name), std::move(url),
                                   owner_dialog_id, FileEncryptionKey(), file_id, static_cast<int8>(1));
  auto file_id_info = get_file_id_info(file_id);
  file_id_info->node_id_ = file_node_id;
  file_id_info->file_info_ = std::move(file_info);

  auto main_file_id = file_id;
  if (!merge_file_id.is_valid()) {
    node->need_load_from_pmc_ = true;
    get_file_id_info(main_file_id)->pin_flag_ = true;
  } else {
    // may invalidate node
    merge(file_id, merge_file_id, true).ignore();
    try_flush_node(get_file_node(file_id), "register_remote");

    main_file_id = get_file_node(file_id)->main_file_id_;
    if (main_file_id != file_id) {
      try_forget_file_id(file_id);
    }
  }
  return FileId(main_file_id.get(), remote_key);
}

FileId FileManager::register_url(string url, FileType file_type, DialogId owner_dialog_id) {
  return do_register_generate(td::make_unique<FullGenerateFileLocation>(file_type, url, "#url#"), owner_dialog_id, 0,
                              url);
}

FileId FileManager::register_generate(FileType file_type, string original_path, string conversion,
                                      DialogId owner_dialog_id, int64 expected_size) {
  // add #mtime# into conversion
  if (!original_path.empty() && conversion[0] != '#' && PathView(original_path).is_absolute()) {
    auto file_paths = log_interface->get_file_paths();
    if (!td::contains(file_paths, original_path)) {
      auto r_stat = stat(original_path);
      uint64 mtime = r_stat.is_ok() ? r_stat.ok().mtime_nsec_ : 0;
      conversion = PSTRING() << "#mtime#" << lpad0(to_string(mtime), 20) << '#' << conversion;
    }
  }
  return do_register_generate(
      td::make_unique<FullGenerateFileLocation>(file_type, std::move(original_path), std::move(conversion)),
      owner_dialog_id, max(expected_size, static_cast<int64>(0)), string());
}

FileId FileManager::do_register_generate(unique_ptr<FullGenerateFileLocation> generate, DialogId owner_dialog_id,
                                         int64 expected_size, string url) {
  auto &file_id = generate_location_to_file_id_[*generate];
  if (!file_id.is_valid()) {
    file_id = next_file_id();
    LOG(INFO) << "Register " << *generate << " as " << file_id;

    auto file_node_id = next_file_node_id();
    auto &node = file_nodes_[file_node_id];
    auto file_info = STORE_FILE_INFO ? td::make_unique<FileInfoGenerate>(*generate, expected_size, url) : nullptr;
    node = td::make_unique<FileNode>(LocalFileLocation(), NewRemoteFileLocation(), std::move(generate), 0,
                                     expected_size, string(), std::move(url), owner_dialog_id, FileEncryptionKey(),
                                     file_id, static_cast<int8>(0));
    node->need_load_from_pmc_ = true;

    auto file_id_info = get_file_id_info(file_id);
    file_id_info->node_id_ = file_node_id;
    file_id_info->file_info_ = std::move(file_info);
    file_id_info->pin_flag_ = true;
  }
  return file_id;
}

Result<FileId> FileManager::register_file(FileData &&data, FileLocationSource file_location_source,
                                          const char *source) {
  bool has_remote = data.remote_.type() == RemoteFileLocation::Type::Full;
  bool has_generate = data.generate_ != nullptr;
  if (data.local_.type() == LocalFileLocation::Type::Full) {
    bool is_from_database = file_location_source == FileLocationSource::FromBinlog ||
                            file_location_source == FileLocationSource::FromDatabase;
    if (is_from_database) {
      PathView path_view(data.local_.full().path_);
      if (path_view.is_relative()) {
        data.local_.full().path_ = PSTRING()
                                   << get_files_base_dir(data.local_.full().file_type_) << data.local_.full().path_;
      }
    }

    if (file_location_source != FileLocationSource::FromDatabase) {
      Status status;
      auto r_info = check_full_local_location({data.local_.full(), data.size_}, false);
      if (r_info.is_error()) {
        status = r_info.move_as_error();
      } else if (bad_paths_.count(r_info.ok().location_.path_) != 0) {
        status = Status::Error(400, "Sending of internal database files is forbidden");
      }
      if (status.is_error()) {
        LOG(INFO) << "Invalid " << data.local_.full() << ": " << status << " from " << source;
        data.local_ = LocalFileLocation();
        if (data.remote_.type() == RemoteFileLocation::Type::Partial) {
          data.remote_ = {};
        }

        if (!has_remote && !has_generate) {
          return std::move(status);
        }
      } else {
        data.local_ = LocalFileLocation(std::move(r_info.ok().location_));
        data.size_ = r_info.ok().size_;
      }
    } else {
      // the location has been checked previously, but recheck it just in case
      recheck_full_local_location({data.local_.full(), data.size_}, false);
    }
  }
  bool has_local = data.local_.type() == LocalFileLocation::Type::Full;
  bool has_location = has_local || has_remote || has_generate;
  if (!has_location) {
    return Status::Error(400, "No location");
  }

  if (data.size_ < 0) {
    LOG(ERROR) << "Receive file of size " << data.size_ << " from " << source;
    data.size_ = 0;
  }
  if (data.expected_size_ < 0) {
    LOG(ERROR) << "Receive file of expected size " << data.expected_size_ << " from " << source;
    data.expected_size_ = 0;
  }

  if (data.remote_.type() == RemoteFileLocation::Type::Partial) {
    auto &partial = data.remote_.partial();
    auto part_size = static_cast<int64>(partial.part_size_);
    auto ready_part_count = partial.ready_part_count_;
    auto remote_ready_size = partial.ready_size_;
    partial.ready_size_ = max(part_size * ready_part_count, remote_ready_size);
    if (data.size_ != 0 && data.size_ < partial.ready_size_) {
      partial.ready_size_ = data.size_;
    }
  }

  FileId file_id = next_file_id();

  LOG(INFO) << "Register file data " << data << " as " << file_id << " from " << source;
  // create FileNode
  auto file_node_id = next_file_node_id();
  auto &node = file_nodes_[file_node_id];
  node = td::make_unique<FileNode>(std::move(data.local_), NewRemoteFileLocation(data.remote_, file_location_source),
                                   std::move(data.generate_), data.size_, data.expected_size_,
                                   std::move(data.remote_name_), std::move(data.url_), data.owner_dialog_id_,
                                   std::move(data.encryption_key_), file_id, static_cast<int8>(has_remote));
  node->pmc_id_ = FileDbId(data.pmc_id_);
  auto file_id_info = get_file_id_info(file_id);
  file_id_info->node_id_ = file_node_id;

  FileView file_view(get_file_node(file_id));

  vector<FileId> to_merge;
  auto register_location = [&](const auto &location, auto &mp) -> FileId * {
    auto &other_id = mp[location];
    if (other_id.empty()) {
      other_id = file_id;
      return &other_id;
    } else {
      to_merge.push_back(other_id);
      return nullptr;
    }
  };
  bool new_remote = false;
  FileId *new_remote_file_id = nullptr;
  int32 remote_key = 0;
  const auto *full_remote_location = file_view.get_full_remote_location();
  if (full_remote_location != nullptr) {
    if (context_->keep_exact_remote_location()) {
      RemoteInfo info{*full_remote_location, file_location_source, file_id};
      remote_key = remote_location_info_.add(info);
      auto &stored_info = remote_location_info_.get(remote_key);
      if (stored_info.file_id_ == file_id) {
        get_file_id_info(file_id)->pin_flag_ = true;
        new_remote = true;
      } else {
        to_merge.push_back(stored_info.file_id_);
        if (merge_choose_remote_location(*full_remote_location, file_location_source, stored_info.remote_,
                                         stored_info.file_location_source_) == 0) {
          stored_info.remote_ = *full_remote_location;
          stored_info.file_location_source_ = file_location_source;
        }
      }
    } else {
      new_remote_file_id = register_location(*full_remote_location, remote_location_to_file_id_);
      new_remote = new_remote_file_id != nullptr;
    }
  }
  FileId *new_local_file_id = nullptr;
  const auto *full_local_location = file_view.get_full_local_location();
  if (full_local_location != nullptr) {
    new_local_file_id = register_location(*full_local_location, local_location_to_file_id_);
  }
  FileId *new_generate_file_id = nullptr;
  const auto *generate_location = file_view.get_generate_location();
  if (generate_location != nullptr) {
    new_generate_file_id = register_location(*generate_location, generate_location_to_file_id_);
  }
  td::unique(to_merge);

  int new_cnt = new_remote + (new_local_file_id != nullptr) + (new_generate_file_id != nullptr);
  if (data.pmc_id_ == 0 && new_cnt > 0) {
    node->need_load_from_pmc_ = true;
  }
  bool no_sync_merge = to_merge.size() == 1 && new_cnt == 0;
  for (auto id : to_merge) {
    // may invalidate node
    merge(file_id, id, no_sync_merge).ignore();
  }

  try_flush_node(get_file_node(file_id), "register_file");
  auto main_file_id = get_file_node(file_id)->main_file_id_;
  if (main_file_id != file_id) {
    if (new_remote_file_id != nullptr) {
      *new_remote_file_id = main_file_id;
    }
    if (new_local_file_id != nullptr) {
      *new_local_file_id = main_file_id;
    }
    if (new_generate_file_id != nullptr) {
      *new_generate_file_id = main_file_id;
    }
    try_forget_file_id(file_id);
  }
  if (new_cnt > 0) {
    get_file_id_info(main_file_id)->pin_flag_ = true;
  }

  if (!data.file_source_ids_.empty()) {
    VLOG(file_references) << "Loaded " << data.file_source_ids_ << " for file " << main_file_id << " from " << source;
    for (auto file_source_id : data.file_source_ids_) {
      CHECK(file_source_id.is_valid());
      context_->add_file_source(main_file_id, file_source_id, "register_file");
    }
  }
  return FileId(main_file_id.get(), remote_key);
}

// 0 -- choose x
// 1 -- choose y
// 2 -- choose any
static int merge_choose_local_location(const LocalFileLocation &x, const LocalFileLocation &y) {
  auto x_type = static_cast<int32>(x.type());
  auto y_type = static_cast<int32>(y.type());
  if (x_type != y_type) {
    return x_type < y_type;
  }
  return 2;
}

static int merge_choose_file_source_location(FileLocationSource x, FileLocationSource y) {
  return static_cast<int>(x) < static_cast<int>(y);
}

static int merge_choose_remote_location(const FullRemoteFileLocation &x, FileLocationSource x_source,
                                        const FullRemoteFileLocation &y, FileLocationSource y_source) {
  LOG(INFO) << "Choose between " << x << " from " << x_source << " and " << y << " from " << y_source;
  if (x.is_web() != y.is_web()) {
    return x.is_web();  // prefer non-web
  }
  auto x_ref = x.has_file_reference();
  auto y_ref = y.has_file_reference();
  if (x_ref || y_ref) {
    if (x_ref != y_ref) {
      return !x_ref;
    }
    if (x.get_file_reference() != y.get_file_reference()) {
      return merge_choose_file_source_location(x_source, y_source);
    }
  }
  if ((x.get_access_hash() != y.get_access_hash() || x.get_source() != y.get_source()) &&
      (x_source != y_source || x.is_web() || x.get_id() == y.get_id())) {
    return merge_choose_file_source_location(x_source, y_source);
  }
  return 2;
}

static int merge_choose_remote_location(const NewRemoteFileLocation &x, const NewRemoteFileLocation &y) {
  if (x.is_full_alive != y.is_full_alive) {
    return !x.is_full_alive;
  }
  if (x.is_full_alive) {
    return merge_choose_remote_location(x.full.value(), x.full_source, y.full.value(), y.full_source);
  }
  if (!x.partial != !y.partial) {
    return !x.partial;
  }
  return 2;
}

static int merge_choose_generate_location(const unique_ptr<FullGenerateFileLocation> &x,
                                          const unique_ptr<FullGenerateFileLocation> &y) {
  int x_empty = (x == nullptr);
  int y_empty = (y == nullptr);
  if (x_empty != y_empty) {
    return x_empty ? 1 : 0;
  }
  if (!x_empty && *x != *y) {
    bool x_has_mtime = begins_with(x->conversion_, "#mtime#");
    bool y_has_mtime = begins_with(y->conversion_, "#mtime#");
    if (x_has_mtime != y_has_mtime) {
      return x_has_mtime ? 0 : 1;
    }
    return x->conversion_ >= y->conversion_
               ? 0
               : 1;  // the bigger conversion, the bigger mtime or at least more stable choice
  }
  return 2;
}

// -1 -- error
static int merge_choose_size(int64 x, int64 y) {
  if (x == 0) {
    return 1;
  }
  if (y == 0) {
    return 0;
  }
  if (x != y) {
    return -1;
  }
  return 2;
}

static int merge_choose_expected_size(int64 x, int64 y) {
  if (x == 0) {
    return 1;
  }
  if (y == 0) {
    return 0;
  }
  return 2;
}

static int merge_choose_name(Slice x, Slice y) {
  if (x.empty() != y.empty()) {
    return x.empty() > y.empty();
  }
  return 2;
}

static int merge_choose_owner(DialogId x, DialogId y) {
  if (x.is_valid() != y.is_valid()) {
    return x.is_valid() < y.is_valid();
  }
  return 2;
}

static int merge_choose_main_file_id(FileId a, int8 a_priority, FileId b, int8 b_priority) {
  if (a_priority != b_priority) {
    return a_priority < b_priority;
  }
  return a.get() > b.get();
}

static int merge_choose_encryption_key(const FileEncryptionKey &a, const FileEncryptionKey &b) {
  if (a.empty() != b.empty()) {
    return a.empty() > b.empty();
  }
  if (a != b) {
    return -1;
  }
  return 2;
}

void FileManager::do_cancel_download(FileNodePtr node) {
  if (node->download_id_ == 0) {
    return;
  }
  send_closure(file_download_manager_, &FileDownloadManager::cancel, node->download_id_);
  node->download_id_ = 0;
  node->is_download_started_ = false;
  node->download_was_update_file_reference_ = false;
  node->set_download_priority(0);
}

void FileManager::do_cancel_upload(FileNodePtr node) {
  if (node->upload_id_ == 0) {
    return;
  }
  send_closure(file_upload_manager_, &FileUploadManager::cancel, node->upload_id_);
  node->upload_id_ = 0;
  node->upload_was_update_file_reference_ = false;
  node->set_upload_priority(0);
}

void FileManager::do_cancel_generate(FileNodePtr node) {
  if (node->generate_id_ == 0) {
    return;
  }
  send_closure(file_generate_manager_, &FileGenerateManager::cancel, node->generate_id_);
  node->generate_id_ = 0;
  node->generate_was_update_ = false;
  node->set_generate_priority(0, 0);
}

Status FileManager::merge(FileId x_file_id, FileId y_file_id, bool no_sync) {
  if (!x_file_id.is_valid()) {
    return Status::Error(400, "First file_id is invalid");
  }
  FileNodePtr x_node = no_sync ? get_file_node(x_file_id) : get_sync_file_node(x_file_id);
  if (!x_node) {
    return Status::Error(
        400, PSLICE() << "Can't merge files. First identifier is invalid: " << x_file_id << " and " << y_file_id);
  }

  if (!y_file_id.is_valid()) {
    LOG(DEBUG) << "Old file is invalid";
    return Status::OK();
  }
  FileNodePtr y_node = get_file_node(y_file_id);
  if (!y_node) {
    return Status::Error(
        400, PSLICE() << "Can't merge files. Second identifier is invalid: " << x_file_id << " and " << y_file_id);
  }

  if (x_node.get() == y_node.get()) {
    if (x_file_id != y_file_id) {
      LOG(DEBUG) << "New file " << x_file_id << " and old file " << y_file_id << " are already merged";
    }
    try_flush_node_info(x_node, "merge 1");
    return Status::OK();
  }

  LOG(INFO) << "Merge new file " << x_file_id << " and old file " << y_file_id;
  if (x_node->remote_.full && y_node->remote_.full && !x_node->remote_.full.value().is_web() &&
      !y_node->remote_.full.value().is_web() && y_node->remote_.is_full_alive &&
      x_node->remote_.full_source == FileLocationSource::FromServer &&
      y_node->remote_.full_source == FileLocationSource::FromServer &&
      x_node->remote_.full.value().get_dc_id() != y_node->remote_.full.value().get_dc_id()) {
    LOG(ERROR) << "File remote location was changed from " << y_node->remote_.full.value() << " to "
               << x_node->remote_.full.value();
  }

  bool drop_last_successful_force_reupload_time = x_node->last_successful_force_reupload_time_ <= 0 &&
                                                  x_node->remote_.full &&
                                                  x_node->remote_.full_source == FileLocationSource::FromServer;

  auto count_local = [](auto &node) {
    return std::accumulate(node->file_ids_.begin(), node->file_ids_.end(), 0,
                           [](const auto &x, const auto &y) { return x + (y.get_remote() != 0); });
  };
  auto x_local_file_ids = count_local(x_node);
  auto y_local_file_ids = count_local(y_node);
  if (x_local_file_ids + y_local_file_ids > 100) {
  }

  if (y_node->file_ids_.size() >= 100 || x_node->file_ids_.size() >= 100) {
    LOG(INFO) << "Merge files with " << x_local_file_ids << '/' << x_node->file_ids_.size() << " and "
              << y_local_file_ids << '/' << y_node->file_ids_.size() << " file IDs";
  }

  FileNodePtr nodes[] = {x_node, y_node, x_node};
  FileNodeId node_ids[] = {get_file_id_info(x_file_id)->node_id_, get_file_id_info(y_file_id)->node_id_};
  int trusted_by_source = merge_choose_file_source_location(x_node->remote_.full_source, y_node->remote_.full_source);

  int local_i = merge_choose_local_location(x_node->local_, y_node->local_);
  int remote_i = merge_choose_remote_location(x_node->remote_, y_node->remote_);
  int generate_i = merge_choose_generate_location(x_node->generate_, y_node->generate_);
  int size_i = merge_choose_size(x_node->size_, y_node->size_);
  int expected_size_i = merge_choose_expected_size(x_node->expected_size_, y_node->expected_size_);
  int remote_name_i = merge_choose_name(x_node->remote_name_, y_node->remote_name_);
  int url_i = merge_choose_name(x_node->url_, y_node->url_);
  int owner_i = merge_choose_owner(x_node->owner_dialog_id_, y_node->owner_dialog_id_);
  int encryption_key_i = merge_choose_encryption_key(x_node->encryption_key_, y_node->encryption_key_);
  int main_file_id_i = merge_choose_main_file_id(x_node->main_file_id_, x_node->main_file_id_priority_,
                                                 y_node->main_file_id_, y_node->main_file_id_priority_);

  if (size_i == -1) {
    try_flush_node_info(x_node, "merge 2");
    try_flush_node_info(y_node, "merge 3");
    return Status::Error(400, PSLICE() << "Can't merge files " << x_node->local_ << '/' << x_node->remote_ << " and "
                                       << y_node->local_ << '/' << y_node->remote_
                                       << ". Different size: " << x_node->size_ << " and " << y_node->size_);
  }
  if (encryption_key_i == -1) {
    if (nodes[remote_i]->remote_.full && nodes[local_i]->local_.type() != LocalFileLocation::Type::Partial) {
      LOG(ERROR) << "Different encryption key in files, but lets choose same key as remote location";
      encryption_key_i = remote_i;
    } else {
      try_flush_node_info(x_node, "merge 4");
      try_flush_node_info(y_node, "merge 5");
      return Status::Error(400, "Can't merge files. Different encryption keys");
    }
  }

  // prefer more trusted source
  if (remote_name_i == 2) {
    remote_name_i = trusted_by_source;
  }
  if (url_i == 2) {
    url_i = trusted_by_source;
  }
  if (expected_size_i == 2) {
    expected_size_i = trusted_by_source;
  }

  int node_i =
      std::make_tuple(y_node->pmc_id_.is_valid(), x_node->pmc_id_, y_node->file_ids_.size(), main_file_id_i == 1) >
      std::make_tuple(x_node->pmc_id_.is_valid(), y_node->pmc_id_, x_node->file_ids_.size(), main_file_id_i == 0);

  auto other_node_i = 1 - node_i;
  FileNodePtr node = nodes[node_i];
  FileNodePtr other_node = nodes[other_node_i];
  auto file_view = FileView(node);

  LOG(DEBUG) << "Have x_node->pmc_id_ = " << x_node->pmc_id_.get() << ", y_node->pmc_id_ = " << y_node->pmc_id_.get()
             << ", x_node_size = " << x_node->file_ids_.size() << ", y_node_size = " << y_node->file_ids_.size()
             << ", node_i = " << node_i << ", local_i = " << local_i << ", remote_i = " << remote_i
             << ", generate_i = " << generate_i << ", size_i = " << size_i << ", remote_name_i = " << remote_name_i
             << ", url_i = " << url_i << ", owner_i = " << owner_i << ", encryption_key_i = " << encryption_key_i
             << ", main_file_id_i = " << main_file_id_i << ", trusted_by_source = " << trusted_by_source
             << ", x_source = " << x_node->remote_.full_source << ", y_source = " << y_node->remote_.full_source;
  if (local_i == other_node_i) {
    do_cancel_download(node);
    node->set_download_offset(other_node->download_offset_);
    node->set_local_location(other_node->local_, other_node->download_offset_, other_node->local_ready_prefix_size_);
    node->download_id_ = other_node->download_id_;
    node->download_was_update_file_reference_ = other_node->download_was_update_file_reference_;
    node->is_download_started_ |= other_node->is_download_started_;
    node->set_download_priority(other_node->download_priority_);
    other_node->download_id_ = 0;
    other_node->download_was_update_file_reference_ = false;
    other_node->is_download_started_ = false;
    other_node->download_priority_ = 0;
    other_node->download_offset_ = 0;
    other_node->local_ready_prefix_size_ = 0;

    //do_cancel_generate(node);
    //node->set_generate_location(std::move(other_node->generate_));
    //node->generate_id_ = other_node->generate_id_;
    //node->set_generate_priority(other_node->generate_download_priority_, other_node->generate_upload_priority_);
    //other_node->generate_id_ = 0;
    //other_node->generate_was_update_ = false;
    //other_node->generate_priority_ = 0;
    //other_node->generate_download_priority_ = 0;
    //other_node->generate_upload_priority_ = 0;
  } else {
    do_cancel_download(other_node);
    //do_cancel_generate(other_node);
  }

  if (remote_i == other_node_i) {
    do_cancel_upload(node);
    node->set_new_remote_location(std::move(other_node->remote_));
    node->upload_id_ = other_node->upload_id_;
    node->upload_was_update_file_reference_ = other_node->upload_was_update_file_reference_;
    node->set_upload_priority(other_node->upload_priority_);
    node->set_upload_pause(other_node->upload_pause_);
    other_node->upload_id_ = 0;
    other_node->upload_was_update_file_reference_ = false;
    other_node->upload_priority_ = 0;
    other_node->upload_pause_ = FileUploadId();
  } else {
    do_cancel_upload(other_node);
  }

  if (generate_i == other_node_i) {
    do_cancel_generate(node);
    node->set_generate_location(std::move(other_node->generate_));
    node->generate_id_ = other_node->generate_id_;
    node->set_generate_priority(other_node->generate_download_priority_, other_node->generate_upload_priority_);
    other_node->generate_id_ = 0;
    other_node->generate_priority_ = 0;
    other_node->generate_download_priority_ = 0;
    other_node->generate_upload_priority_ = 0;
  } else {
    do_cancel_generate(other_node);
  }

  if (size_i == other_node_i) {
    node->set_size(other_node->size_);
  }

  if (expected_size_i == other_node_i) {
    node->set_expected_size(other_node->expected_size_);
  }

  if (remote_name_i == other_node_i) {
    node->set_remote_name(other_node->remote_name_);
  }

  if (url_i == other_node_i) {
    node->set_url(other_node->url_);
  }

  if (owner_i == other_node_i) {
    node->set_owner_dialog_id(other_node->owner_dialog_id_);
  }

  if (encryption_key_i == other_node_i) {
    node->set_encryption_key(other_node->encryption_key_);
    nodes[node_i]->set_encryption_key(nodes[encryption_key_i]->encryption_key_);
  }
  node->need_load_from_pmc_ |= other_node->need_load_from_pmc_;
  node->can_search_locally_ &= other_node->can_search_locally_;
  node->upload_prefer_small_ |= other_node->upload_prefer_small_;

  if (drop_last_successful_force_reupload_time) {
    node->last_successful_force_reupload_time_ = -1e10;
  } else if (other_node->last_successful_force_reupload_time_ > node->last_successful_force_reupload_time_) {
    node->last_successful_force_reupload_time_ = other_node->last_successful_force_reupload_time_;
  }

  if (main_file_id_i == other_node_i) {
    context_->on_merge_files(other_node->main_file_id_, node->main_file_id_);
    node->main_file_id_ = other_node->main_file_id_;
    node->main_file_id_priority_ = other_node->main_file_id_priority_;
  } else {
    context_->on_merge_files(node->main_file_id_, other_node->main_file_id_);
  }

  bool send_updates_flag = false;
  auto other_pmc_id = other_node->pmc_id_;
  append(node->file_ids_, other_node->file_ids_);

  for (auto file_id : other_node->file_ids_) {
    auto file_id_info = get_file_id_info(file_id);
    CHECK(file_id_info->node_id_ == node_ids[other_node_i]);
    file_id_info->node_id_ = node_ids[node_i];
  }
  other_node = {};

  if (send_updates_flag) {
    // node might not changed, but other_node might changed, so we need to send update anyway
    VLOG(update_file) << "File " << node->main_file_id_ << " has been merged";
    node->on_info_changed();
  }

  if (node->file_ids_.size() > (static_cast<size_t>(1) << file_node_size_warning_exp_)) {
    LOG(WARNING) << "File of type " << file_view.get_type() << " has " << node->file_ids_.size() << " file identifiers";
    file_node_size_warning_exp_++;
  }

  // Check if some download/upload queries are ready
  for (auto file_id : vector<FileId>(node->file_ids_)) {
    if (file_view.has_full_local_location()) {
      finish_downloads(file_id, Status::OK());
    }
    if (file_view.has_active_upload_remote_location()) {
      finish_uploads(file_id, Status::OK());
    }
  }

  file_nodes_[node_ids[other_node_i]] = nullptr;

  run_generate(node);
  run_download(node, false);
  run_upload(node, {});

  if (other_pmc_id.is_valid()) {
    // node might not changed, but we need to merge nodes in pmc anyway
    node->on_pmc_changed();
  }
  try_flush_node_full(node, node_i != remote_i, node_i != local_i, node_i != generate_i, other_pmc_id);

  return Status::OK();
}

void FileManager::try_merge_documents(FileId new_file_id, FileId old_file_id) {
  if (!old_file_id.is_valid() || !new_file_id.is_valid()) {
    return;
  }
  FileView old_file_view = get_file_view(old_file_id);
  FileView new_file_view = get_file_view(new_file_id);
  // if file type has changed, but file size remains the same, we are trying to update local location of the new
  // file with the old local location
  if (old_file_view.has_full_local_location() && !new_file_view.has_full_local_location() &&
      old_file_view.size() != 0 && old_file_view.size() == new_file_view.size()) {
    auto old_file_type = old_file_view.get_type();
    auto new_file_type = new_file_view.get_type();

    if (is_document_file_type(old_file_type) && is_document_file_type(new_file_type)) {
      const auto *old_location = old_file_view.get_full_local_location();
      auto r_file_id =
          register_local(FullLocalFileLocation(new_file_type, old_location->path_, old_location->mtime_nsec_),
                         DialogId(), old_file_view.size());
      if (r_file_id.is_ok()) {
        LOG_STATUS(merge(new_file_id, r_file_id.ok()));
      }
    }
  }
}

void FileManager::add_file_source(FileId file_id, FileSourceId file_source_id, const char *source) {
  auto node = get_sync_file_node(file_id);  // synchronously load the file to preload known file sources
  if (!node) {
    return;
  }

  CHECK(file_source_id.is_valid());
  if (context_->add_file_source(node->main_file_id_, file_source_id, source)) {
    node->on_pmc_changed();
    try_flush_node_pmc(node, "add_file_source");
  }
}

void FileManager::remove_file_source(FileId file_id, FileSourceId file_source_id, const char *source) {
  auto node = get_sync_file_node(file_id);  // synchronously load the file to preload known file sources
  if (!node) {
    return;
  }

  CHECK(file_source_id.is_valid());
  if (context_->remove_file_source(node->main_file_id_, file_source_id, source)) {
    node->on_pmc_changed();
    try_flush_node_pmc(node, "remove_file_source");
  }
}

void FileManager::change_files_source(FileSourceId file_source_id, const vector<FileId> &old_file_ids,
                                      const vector<FileId> &new_file_ids, const char *source) {
  if (old_file_ids == new_file_ids) {
    return;
  }
  CHECK(file_source_id.is_valid());

  auto old_main_file_ids = get_main_file_ids(old_file_ids);
  auto new_main_file_ids = get_main_file_ids(new_file_ids);
  for (auto file_id : old_main_file_ids) {
    auto it = new_main_file_ids.find(file_id);
    if (it == new_main_file_ids.end()) {
      remove_file_source(file_id, file_source_id, source);
    } else {
      new_main_file_ids.erase(it);
    }
  }
  for (auto file_id : new_main_file_ids) {
    add_file_source(file_id, file_source_id, source);
  }
}

void FileManager::on_file_reference_repaired(FileId file_id, FileSourceId file_source_id, Result<Unit> &&result,
                                             Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto file_view = get_file_view(file_id);
  CHECK(!file_view.empty());
  if (result.is_ok() &&
      (!file_view.has_active_upload_remote_location() || !file_view.has_active_download_remote_location())) {
    result = Status::Error("No active remote location");
  }
  if (result.is_error() && result.error().code() != 429 && result.error().code() < 500) {
    VLOG(file_references) << "Invalid " << file_source_id << " " << result.error();
    remove_file_source(file_id, file_source_id, "on_file_reference_repaired");
  }
  promise.set_result(std::move(result));
}

FlatHashSet<FileId, FileIdHash> FileManager::get_main_file_ids(const vector<FileId> &file_ids) {
  FlatHashSet<FileId, FileIdHash> result;
  for (auto file_id : file_ids) {
    auto node = get_file_node(file_id);
    if (node) {
      result.insert(node->main_file_id_);
    }
  }
  return result;
}

void FileManager::try_flush_node_full(FileNodePtr node, bool new_remote, bool new_local, bool new_generate,
                                      FileDbId other_pmc_id) {
  if (node->need_pmc_flush()) {
    if (file_db_) {
      load_from_pmc(node, true, true, true);
      flush_to_pmc(node, new_remote, new_local, new_generate, "try_flush_node_full");
      if (other_pmc_id.is_valid() && node->pmc_id_ != other_pmc_id) {
        file_db_->set_file_data_ref(other_pmc_id, node->pmc_id_);
      }
    }
    node->on_pmc_flushed();
  }

  try_flush_node_info(node, "try_flush_node_full");
}

void FileManager::try_flush_node(FileNodePtr node, const char *source) {
  try_flush_node_pmc(node, source);
  try_flush_node_info(node, source);
}

void FileManager::try_flush_node_pmc(FileNodePtr node, const char *source) {
  if (node->need_pmc_flush()) {
    if (file_db_) {
      load_from_pmc(node, true, true, true);
      flush_to_pmc(node, false, false, false, source);
    }
    node->on_pmc_flushed();
  }
}

void FileManager::try_flush_node_info(FileNodePtr node, const char *source) {
  if (node->need_info_flush()) {
    for (auto file_id : vector<FileId>(node->file_ids_)) {
      VLOG(update_file) << "Send UpdateFile about file " << file_id << " from " << source;
      context_->on_file_updated(file_id);
      get_file_id_info(file_id)->pin_flag_ = true;
      auto it = file_download_requests_.find(file_id);
      if (it != file_download_requests_.end()) {
        for (auto &download_info : it->second.internal_downloads_) {
          CHECK(download_info.second.download_callback_ != nullptr);
          download_info.second.download_callback_->on_progress(file_id);
        }
      }
    }
    node->on_info_flushed();
  }
}

void FileManager::clear_from_pmc(FileNodePtr node) {
  if (!file_db_) {
    return;
  }
  if (node->pmc_id_.empty()) {
    return;
  }

  LOG(INFO) << "Delete files " << node->file_ids_ << " from pmc";
  FileData data;
  auto file_view = FileView(node);
  if (file_view.has_full_local_location()) {
    data.local_ = node->local_;
    prepare_path_for_pmc(data.local_.full().file_type_, data.local_.full().path_);
  }
  if (file_view.has_full_remote_location()) {
    data.remote_ = RemoteFileLocation(*node->remote_.full);
  }
  if (file_view.has_generate_location()) {
    data.generate_ = make_unique<FullGenerateFileLocation>(*node->generate_);
  }
  file_db_->clear_file_data(node->pmc_id_, data);
  node->pmc_id_ = FileDbId();
}

void FileManager::flush_to_pmc(FileNodePtr node, bool new_remote, bool new_local, bool new_generate,
                               const char *source) {
  if (!file_db_) {
    return;
  }
  FileView file_view(node);
  bool create_flag = false;
  if (node->pmc_id_.empty()) {
    create_flag = true;
    node->pmc_id_ = file_db_->get_next_file_db_id();
  }

  FileData data;
  data.pmc_id_ = node->pmc_id_.get();
  data.local_ = node->local_;
  if (data.local_.type() == LocalFileLocation::Type::Full) {
    prepare_path_for_pmc(data.local_.full().file_type_, data.local_.full().path_);
  }
  if (node->remote_.full) {
    data.remote_ = RemoteFileLocation(node->remote_.full.value());
  } else if (node->remote_.partial) {
    data.remote_ = RemoteFileLocation(*node->remote_.partial);
  }
  if (node->generate_ != nullptr && !begins_with(node->generate_->conversion_, "#file_id#")) {
    data.generate_ = make_unique<FullGenerateFileLocation>(*node->generate_);
  }

  // TODO: not needed when GenerateLocation has constant conversion
  if (data.remote_.type() != RemoteFileLocation::Type::Full && data.local_.type() != LocalFileLocation::Type::Full) {
    data.local_ = LocalFileLocation();
    data.remote_ = RemoteFileLocation();
  }
  if (data.remote_.type() != RemoteFileLocation::Type::Full && node->encryption_key_.is_secure()) {
    data.remote_ = RemoteFileLocation();
  }

  data.size_ = node->size_;
  data.expected_size_ = node->expected_size_;
  data.remote_name_ = node->remote_name_;
  data.encryption_key_ = node->encryption_key_;
  data.url_ = node->url_;
  data.owner_dialog_id_ = node->owner_dialog_id_;
  data.file_source_ids_ = context_->get_some_file_sources(file_view.get_main_file_id());
  VLOG(file_references) << "Save file " << file_view.get_main_file_id() << " to database with " << data.file_source_ids_
                        << " from " << source;

  file_db_->set_file_data(node->pmc_id_, data, (create_flag || new_remote), (create_flag || new_local),
                          (create_flag || new_generate));
}

FileNode *FileManager::get_file_node_raw(FileId file_id, FileNodeId *file_node_id) {
  if (file_id.get() <= 0 || file_id.get() >= static_cast<int32>(file_id_info_.size())) {
    return nullptr;
  }
  FileNodeId node_id = file_id_info_[file_id.get()]->node_id_;
  if (node_id == 0) {
    return nullptr;
  }
  if (file_node_id != nullptr) {
    *file_node_id = node_id;
  }
  return file_nodes_[node_id].get();
}

FileNodePtr FileManager::get_sync_file_node(FileId file_id) {
  auto file_node = get_file_node(file_id);
  if (!file_node) {
    return {};
  }
  load_from_pmc(file_node, true, true, true);
  return file_node;
}

void FileManager::load_from_pmc(FileNodePtr node, bool new_remote, bool new_local, bool new_generate) {
  if (!node->need_load_from_pmc_) {
    return;
  }
  node->need_load_from_pmc_ = false;
  if (!file_db_) {
    return;
  }
  auto file_id = node->main_file_id_;
  auto file_view = get_file_view(file_id);
  CHECK(!file_view.empty());

  FullRemoteFileLocation remote;
  FullLocalFileLocation local;
  FullGenerateFileLocation generate;
  if (new_remote) {
    const auto *full_remote_location = file_view.get_full_remote_location();
    if (full_remote_location != nullptr) {
      remote = *full_remote_location;
    } else {
      new_remote = false;
    }
  }
  if (new_local) {
    const auto *full_local_location = file_view.get_full_local_location();
    if (full_local_location != nullptr) {
      local = *full_local_location;
      prepare_path_for_pmc(local.file_type_, local.path_);
    } else {
      new_local = false;
    }
  }
  if (new_generate) {
    const auto *generate_location = file_view.get_generate_location();
    if (generate_location != nullptr) {
      generate = *generate_location;
    } else {
      new_generate = false;
    }
  }

  LOG(DEBUG) << "Load from pmc file " << file_id << '/' << file_view.get_main_file_id()
             << ", new_remote = " << new_remote << ", new_local = " << new_local << ", new_generate = " << new_generate;
  auto load = [&](auto location, const char *source) {
    TRY_RESULT(file_data, file_db_->get_file_data_sync(location));
    TRY_RESULT(new_file_id, register_file(std::move(file_data), FileLocationSource::FromDatabase, source));
    TRY_STATUS(merge(file_id, new_file_id));  // merge manually to keep merge parameters order
    return Status::OK();
  };
  if (new_remote) {
    load(remote, "load remote from database").ignore();
  }
  if (new_local) {
    load(local, "load local from database").ignore();
  }
  if (new_generate) {
    load(generate, "load generate from database").ignore();
  }
}

bool FileManager::set_encryption_key(FileId file_id, FileEncryptionKey key) {
  auto node = get_sync_file_node(file_id);
  if (!node) {
    return false;
  }
  auto file_view = FileView(node);
  if (file_view.has_full_local_location() && file_view.has_full_remote_location()) {
    return false;
  }
  if (!node->encryption_key_.empty()) {
    return false;
  }
  node->set_encryption_key(std::move(key));
  try_flush_node_pmc(node, "set_encryption_key");
  return true;
}

bool FileManager::set_content(FileId file_id, BufferSlice bytes) {
  if (G()->get_option_boolean("ignore_inline_thumbnails")) {
    return false;
  }

  auto node = get_sync_file_node(file_id);
  if (!node) {
    return false;
  }

  if (node->local_.type() == LocalFileLocation::Type::Full) {
    // There was no download so we don't need an update
    return true;
  }

  do_cancel_download(node);

  class Callback final : public DownloadCallback {
   public:
    void on_download_ok(FileId file_id) final {
      LOG(INFO) << "Successfully saved content of " << file_id;
    }
    void on_download_error(FileId file_id, Status error) final {
      LOG(INFO) << "Failed to save content of " << file_id << ": " << error;
    }
  };

  int8 priority = 10;
  auto internal_download_id = get_internal_download_id();
  auto &requests = file_download_requests_[file_id];
  auto &download_info = requests.internal_downloads_[internal_download_id];
  download_info.download_priority_ = priority;
  download_info.download_callback_ = std::make_shared<Callback>();

  node->set_download_priority(priority);

  FileDownloadManager::QueryId query_id =
      download_queries_.create(DownloadQuery{file_id, DownloadQuery::Type::SetContent});
  node->download_id_ = query_id;
  node->is_download_started_ = true;
  send_closure(file_download_manager_, &FileDownloadManager::from_bytes, query_id,
               node->remote_.full.value().file_type_, std::move(bytes), node->suggested_path());
  return true;
}

void FileManager::get_content(FileId file_id, Promise<BufferSlice> promise) {
  auto node = get_sync_file_node(file_id);
  if (!node) {
    return promise.set_error(Status::Error("Unknown file_id"));
  }
  check_local_location(node, true).ignore();

  auto file_view = FileView(node);
  const auto *full_local_location = file_view.get_full_local_location();
  if (full_local_location == nullptr) {
    return promise.set_error(Status::Error("No local location"));
  }

  send_closure(file_load_manager_, &FileLoadManager::get_content, full_local_location->path_, std::move(promise));
}

void FileManager::read_file_part(FileId file_id, int64 offset, int64 count, int left_tries,
                                 Promise<td_api::object_ptr<td_api::filePart>> promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (!file_id.is_valid()) {
    return promise.set_error(Status::Error(400, "File identifier is invalid"));
  }
  auto node = get_sync_file_node(file_id);
  if (!node) {
    return promise.set_error(Status::Error(400, "File not found"));
  }
  if (offset < 0) {
    return promise.set_error(Status::Error(400, "Parameter offset must be non-negative"));
  }
  if (count < 0) {
    return promise.set_error(Status::Error(400, "Parameter count must be non-negative"));
  }

  auto file_view = FileView(node);

  if (count == 0) {
    count = file_view.downloaded_prefix(offset);
    if (count == 0) {
      return promise.set_value(td_api::make_object<td_api::filePart>());
    }
  } else if (file_view.downloaded_prefix(offset) < count) {
    // TODO this check is safer to do in another thread
    return promise.set_error(Status::Error(400, "There is not enough downloaded bytes in the file to read"));
  }
  if (count >= static_cast<int64>(std::numeric_limits<size_t>::max() / 2 - 1)) {
    return promise.set_error(Status::Error(400, "Part length is too big"));
  }

  const string *path = nullptr;
  bool is_partial = false;
  const auto *full_local_location = file_view.get_full_local_location();
  if (full_local_location != nullptr) {
    path = &full_local_location->path_;
    if (!begins_with(*path, get_files_dir(file_view.get_type()))) {
      return promise.set_error(Status::Error(400, "File is not inside the cache"));
    }
  } else {
    CHECK(node->local_.type() == LocalFileLocation::Type::Partial);
    path = &node->local_.partial().path_;
    is_partial = true;
  }

  auto read_file_part_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), file_id, offset, count, left_tries, is_partial,
                              promise = std::move(promise)](Result<string> r_bytes) mutable {
        if (r_bytes.is_error()) {
          LOG(INFO) << "Failed to read file bytes: " << r_bytes.error();
          if (left_tries == 1 || !is_partial) {
            return promise.set_error(Status::Error(400, "Failed to read the file"));
          }

          // the temporary file could be moved from temp to persistent directory
          // we need to wait for the corresponding update and repeat the reading
          create_actor<SleepActor>("RepeatReadFilePartActor", 0.01,
                                   PromiseCreator::lambda([actor_id, file_id, offset, count, left_tries,
                                                           promise = std::move(promise)](Unit) mutable {
                                     send_closure(actor_id, &FileManager::read_file_part, file_id, offset, count,
                                                  left_tries - 1, std::move(promise));
                                   }))
              .release();
        } else {
          auto result = td_api::make_object<td_api::filePart>();
          result->data_ = r_bytes.move_as_ok();
          promise.set_value(std::move(result));
        }
      });
  send_closure(file_load_manager_, &FileLoadManager::read_file_part, *path, offset, count,
               std::move(read_file_part_promise));
}

void FileManager::delete_file(FileId file_id, Promise<Unit> promise, const char *source) {
  LOG(INFO) << "Trying to delete file " << file_id << " from " << source;
  auto node = get_sync_file_node(file_id);
  if (!node) {
    return promise.set_value(Unit());
  }

  auto file_view = FileView(node);

  send_closure(G()->download_manager(), &DownloadManager::remove_file_if_finished, file_view.get_main_file_id());
  string path;
  if (file_view.has_full_local_location()) {
    if (begins_with(file_view.get_full_local_location()->path_, get_files_dir(file_view.get_type()))) {
      clear_from_pmc(node);
      if (context_->need_notify_on_new_files()) {
        context_->on_new_file(-file_view.size(), -file_view.get_allocated_local_size(), -1);
      }
      path = std::move(node->local_.full().path_);
    }
  } else {
    if (file_view.get_type() == FileType::Encrypted) {
      clear_from_pmc(node);
    }
    if (node->local_.type() == LocalFileLocation::Type::Partial) {
      path = std::move(node->local_.partial().path_);
    }
  }

  if (path.empty()) {
    return promise.set_value(Unit());
  }

  LOG(INFO) << "Unlink file " << file_id << " at " << path;
  node->drop_local_location();
  try_flush_node(node, "delete_file");
  send_closure(file_load_manager_, &FileLoadManager::unlink_file, path, std::move(promise));
}

int64 FileManager::get_internal_download_id() {
  return ++internal_load_id_;
}

int64 FileManager::get_internal_upload_id() {
  return ++internal_load_id_;
}

void FileManager::download_file(FileId file_id, int32 priority, int64 offset, int64 limit, bool synchronous,
                                Promise<td_api::object_ptr<td_api::file>> &&promise) {
  TRY_STATUS_PROMISE(promise, check_priority(priority));
  if (offset < 0) {
    return promise.set_error(Status::Error(400, "Download offset must be non-negative"));
  }
  if (limit < 0) {
    return promise.set_error(Status::Error(400, "Download limit must be non-negative"));
  }

  auto file_view = get_file_view(file_id);
  if (file_view.empty()) {
    return promise.set_error(Status::Error(400, "File not found"));
  }

  auto info_it = pending_user_file_downloads_.find(file_id);
  UserFileDownloadInfo *info = info_it == pending_user_file_downloads_.end() ? nullptr : &info_it->second;
  if (info != nullptr && (offset != info->offset_ || limit != info->limit_)) {
    // we can't have two pending user requests with different offset and limit, so cancel all previous requests
    auto promises = std::move(info->promises_);
    if (!synchronous) {
      pending_user_file_downloads_.erase(info_it);
    } else {
      info->promises_.clear();
    }
    fail_promises(promises, Status::Error(200, "Canceled by another downloadFile request"));
  }
  if (synchronous) {
    if (info == nullptr) {
      info = &pending_user_file_downloads_[file_id];
    }
    info->offset_ = offset;
    info->limit_ = limit;
    info->promises_.push_back(std::move(promise));

    download(file_id, 0, user_download_file_callback_, priority, offset, limit);
  } else {
    download(file_id, 0, user_download_file_callback_, priority, offset, limit, std::move(promise));
  }
}

void FileManager::on_user_file_download_finished(FileId file_id) {
  auto it = pending_user_file_downloads_.find(file_id);
  if (it == pending_user_file_downloads_.end()) {
    return;
  }
  auto offset = it->second.offset_;
  auto limit = it->second.limit_;
  if (limit == 0) {
    limit = std::numeric_limits<int64>::max();
  }
  auto promises = std::move(it->second.promises_);
  pending_user_file_downloads_.erase(it);

  for (auto &promise : promises) {
    auto file_object = get_file_object(file_id);
    CHECK(file_object != nullptr);
    auto download_offset = file_object->local_->download_offset_;
    auto downloaded_size = file_object->local_->downloaded_prefix_size_;
    auto file_size = file_object->size_;
    if (file_object->local_->is_downloading_completed_ ||
        (download_offset <= offset && download_offset + downloaded_size >= offset &&
         ((file_size != 0 && download_offset + downloaded_size == file_size) ||
          download_offset + downloaded_size - offset >= limit))) {
      promise.set_value(std::move(file_object));
    } else {
      promise.set_error(Status::Error(400, "File download has failed or was canceled"));
    }
  }
}

void FileManager::download(FileId file_id, int64 internal_download_id, std::shared_ptr<DownloadCallback> callback,
                           int32 new_priority, int64 offset, int64 limit,
                           Promise<td_api::object_ptr<td_api::file>> promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  CHECK(callback != nullptr);
  CHECK(new_priority > 0);

  auto node = get_sync_file_node(file_id);
  if (!node) {
    LOG(INFO) << "File " << file_id << " not found";
    auto error = Status::Error(400, "File not found");
    callback->on_download_error(file_id, error.clone());
    return promise.set_error(std::move(error));
  }
  if (node->local_.type() == LocalFileLocation::Type::Empty) {
    return download_impl(file_id, internal_download_id, std::move(callback), new_priority, offset, limit, Status::OK(),
                         std::move(promise));
  }

  LOG(INFO) << "Asynchronously check location of file " << file_id << " before downloading";
  auto check_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), file_id, internal_download_id, callback = std::move(callback),
                              new_priority, offset, limit, promise = std::move(promise)](Result<Unit> result) mutable {
        Status check_status;
        if (result.is_error()) {
          check_status = result.move_as_error();
        }
        send_closure(actor_id, &FileManager::download_impl, file_id, internal_download_id, std::move(callback),
                     new_priority, offset, limit, std::move(check_status), std::move(promise));
      });
  check_local_location_async(node, true, std::move(check_promise));
}

void FileManager::download_impl(FileId file_id, int64 internal_download_id, std::shared_ptr<DownloadCallback> callback,
                                int32 new_priority, int64 offset, int64 limit, Status check_status,
                                Promise<td_api::object_ptr<td_api::file>> promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  LOG(INFO) << "Download file " << file_id << " with priority " << new_priority << " and internal identifier "
            << internal_download_id;
  auto node = get_file_node(file_id);
  CHECK(node);

  if (check_status.is_error()) {
    LOG(WARNING) << "Need to redownload file " << file_id << ": " << check_status;
  }
  if (node->local_.type() == LocalFileLocation::Type::Full) {
    LOG(INFO) << "File " << file_id << " is already downloaded";
    callback->on_download_ok(file_id);
    return promise.set_value(get_file_object(file_id));
  }

  FileView file_view(node);
  if (!file_view.can_download_from_server() && !file_view.can_generate()) {
    LOG(INFO) << "File " << file_id << " can't be downloaded";
    auto error = Status::Error(400, "Can't download or generate the file");
    callback->on_download_error(file_id, error.clone());
    return promise.set_error(std::move(error));
  }

  auto &requests = file_download_requests_[file_id];
  if (internal_download_id != 0) {
    CHECK(offset == -1);
    CHECK(limit == -1);
    auto &download_info = requests.internal_downloads_[internal_download_id];
    CHECK(download_info.download_callback_ == nullptr);
    download_info.download_priority_ = narrow_cast<int8>(new_priority);
    download_info.download_callback_ = std::move(callback);
    download_info.download_callback_->on_progress(file_id);
  } else {
    node->set_download_offset(offset);
    node->set_download_limit(limit);
    requests.user_offset_ = offset;
    requests.user_limit_ = limit;
    requests.user_download_priority_ = narrow_cast<int8>(new_priority);
  }

  run_generate(node);
  run_download(node, true);

  try_flush_node(node, "download");
  promise.set_value(get_file_object(file_id));
}

std::shared_ptr<FileManager::DownloadCallback> FileManager::extract_download_callback(FileId file_id,
                                                                                      int64 internal_download_id) {
  auto it = file_download_requests_.find(file_id);
  if (it == file_download_requests_.end()) {
    return nullptr;
  }
  std::shared_ptr<DownloadCallback> callback;
  if (internal_download_id != 0) {
    auto download_info_it = it->second.internal_downloads_.find(internal_download_id);
    if (download_info_it == it->second.internal_downloads_.end()) {
      return nullptr;
    }
    callback = std::move(download_info_it->second.download_callback_);
    it->second.internal_downloads_.erase(download_info_it);
  } else {
    if (it->second.user_download_priority_ == 0) {
      return nullptr;
    }
    callback = user_download_file_callback_;
    it->second.user_download_priority_ = 0;
    it->second.user_offset_ = 0;
    it->second.user_limit_ = 0;
  }
  if (it->second.user_download_priority_ == 0 && it->second.internal_downloads_.empty()) {
    file_download_requests_.erase(it);
  }
  return callback;
}

void FileManager::finish_downloads(FileId file_id, const Status &status) {
  auto it = file_download_requests_.find(file_id);
  if (it == file_download_requests_.end()) {
    return;
  }
  vector<std::shared_ptr<DownloadCallback>> callbacks;
  for (auto &download_info : it->second.internal_downloads_) {
    callbacks.push_back(std::move(download_info.second.download_callback_));
  }
  if (it->second.user_download_priority_ != 0) {
    callbacks.push_back(user_download_file_callback_);
  }
  file_download_requests_.erase(it);

  for (auto &callback : callbacks) {
    CHECK(callback != nullptr);
    if (status.is_ok()) {
      callback->on_download_ok(file_id);
    } else {
      callback->on_download_error(file_id, status.clone());
    }
  }
}

void FileManager::cancel_download(FileId file_id, int64 internal_download_id, bool only_if_pending) {
  if (G()->close_flag()) {
    return;
  }

  auto node = get_sync_file_node(file_id);
  if (!node) {
    return;
  }
  if (only_if_pending && node->is_download_started_) {
    LOG(INFO) << "File " << file_id << " is being downloaded";
    return;
  }

  auto callback = extract_download_callback(file_id, internal_download_id);
  if (callback == nullptr) {
    return;
  }

  LOG(INFO) << "Cancel download of file " << file_id;
  callback->on_download_error(file_id, Status::Error(200, "Canceled"));

  run_generate(node);
  run_download(node, true);

  try_flush_node(node, "cancel_download");
}

void FileManager::run_download(FileNodePtr node, bool force_update_priority) {
  int8 priority = 0;
  bool ignore_download_limit = false;
  for (auto file_id : node->file_ids_) {
    auto it = file_download_requests_.find(file_id);
    if (it != file_download_requests_.end()) {
      if (it->second.user_download_priority_ > priority) {
        priority = it->second.user_download_priority_;
      }
      for (auto &download_info : it->second.internal_downloads_) {
        if (download_info.second.download_priority_ > priority) {
          priority = download_info.second.download_priority_;
        }
        ignore_download_limit = true;
      }
    }
  }

  auto old_priority = node->download_priority_;

  if (priority == 0) {
    node->set_download_priority(priority);
    if (old_priority != 0) {
      LOG(INFO) << "Cancel downloading of file " << node->main_file_id_;
      do_cancel_download(node);
    }
    return;
  }

  if (node->need_load_from_pmc_) {
    LOG(INFO) << "Skip run_download, because file " << node->main_file_id_ << " needs to be loaded from PMC";
    return;
  }
  if (node->generate_id_) {
    LOG(INFO) << "Skip run_download, because file " << node->main_file_id_ << " is being generated";
    return;
  }
  auto file_view = FileView(node);
  if (!file_view.can_download_from_server()) {
    LOG(INFO) << "Skip run_download, because file " << node->main_file_id_ << " can't be downloaded from server";
    return;
  }
  node->set_download_priority(priority);
  node->set_ignore_download_limit(ignore_download_limit);
  bool need_update_offset = node->is_download_offset_dirty_;
  node->is_download_offset_dirty_ = false;

  bool need_update_limit = node->is_download_limit_dirty_;
  node->is_download_limit_dirty_ = false;

  if (old_priority != 0) {
    LOG(INFO) << "Update download offset and limits of file " << node->main_file_id_;
    CHECK(node->download_id_ != 0);
    if (force_update_priority || priority != old_priority) {
      send_closure(file_download_manager_, &FileDownloadManager::update_priority, node->download_id_, priority);
    }
    if (need_update_limit || need_update_offset) {
      auto download_offset = node->download_offset_;
      auto download_limit = node->get_download_limit();
      if (file_view.is_encrypted_any()) {
        CHECK(download_offset <= MAX_FILE_SIZE);
        CHECK(download_limit <= MAX_FILE_SIZE);
        download_limit += download_offset;
        download_offset = 0;
      }
      send_closure(file_download_manager_, &FileDownloadManager::update_downloaded_part, node->download_id_,
                   download_offset, download_limit);
    }
    return;
  }

  CHECK(node->download_id_ == 0);
  CHECK(!node->file_ids_.empty());
  auto file_id = node->main_file_id_;

  if (node->need_reload_photo_ && file_view.may_reload_photo()) {
    LOG(INFO) << "Reload photo from file " << node->main_file_id_;
    FileDownloadManager::QueryId query_id =
        download_queries_.create(DownloadQuery{file_id, DownloadQuery::Type::DownloadReloadDialog});
    node->download_id_ = query_id;
    context_->reload_photo(file_view.get_full_remote_location()->get_source(),
                           PromiseCreator::lambda([actor_id = actor_id(this), query_id, file_id](Result<Unit> res) {
                             Status error;
                             if (res.is_ok()) {
                               error = Status::Error("FILE_DOWNLOAD_ID_INVALID");
                             } else {
                               error = res.move_as_error();
                             }
                             VLOG(file_references)
                                 << "Receive result from reload photo for file " << file_id << ": " << error;
                             send_closure(actor_id, &FileManager::on_download_error, query_id, std::move(error));
                           }));
    node->need_reload_photo_ = false;
    return;
  }

  // If file reference is needed
  if (!file_view.has_active_download_remote_location()) {
    VLOG(file_references) << "Do not have valid file_reference for file " << file_id;
    FileDownloadManager::QueryId query_id =
        download_queries_.create(DownloadQuery{file_id, DownloadQuery::Type::DownloadWaitFileReference});
    node->download_id_ = query_id;
    if (node->download_was_update_file_reference_) {
      return on_download_error(query_id, Status::Error("Can't download file: have no valid file reference"));
    }
    node->download_was_update_file_reference_ = true;

    context_->repair_file_reference(
        file_id, PromiseCreator::lambda([actor_id = actor_id(this), query_id, file_id](Result<Unit> res) {
          Status error;
          if (res.is_ok()) {
            error = Status::Error("FILE_DOWNLOAD_RESTART_WITH_FILE_REFERENCE");
          } else {
            error = res.move_as_error();
          }
          VLOG(file_references) << "Receive result from FileSourceManager for file " << file_id << ": " << error;
          send_closure(actor_id, &FileManager::on_download_error, query_id, std::move(error));
        }));
    return;
  }

  FileDownloadManager::QueryId query_id =
      download_queries_.create(DownloadQuery{file_id, DownloadQuery::Type::Download});
  node->download_id_ = query_id;
  node->is_download_started_ = false;
  LOG(INFO) << "Run download of file " << file_id << " of size " << node->size_ << " from "
            << node->remote_.full.value() << " with suggested name " << node->suggested_path() << " and encryption key "
            << node->encryption_key_;
  auto download_offset = node->download_offset_;
  auto download_limit = node->get_download_limit();
  if (file_view.is_encrypted_any()) {
    CHECK(download_offset <= MAX_FILE_SIZE);
    CHECK(download_limit <= MAX_FILE_SIZE);
    download_limit += download_offset;
    download_offset = 0;
  }
  send_closure(file_download_manager_, &FileDownloadManager::download, query_id, node->remote_.full.value(),
               node->local_, node->size_, node->suggested_path(), node->encryption_key_, node->can_search_locally_,
               download_offset, download_limit, priority);
}

class FileManager::ForceUploadActor final : public Actor {
 public:
  ForceUploadActor(FileManager *file_manager, FileUploadId file_upload_id,
                   std::shared_ptr<FileManager::UploadCallback> callback, int32 new_priority, uint64 upload_order,
                   bool prefer_small, ActorShared<> parent)
      : file_manager_(file_manager)
      , file_upload_id_(file_upload_id)
      , callback_(std::move(callback))
      , new_priority_(new_priority)
      , upload_order_(upload_order)
      , prefer_small_(prefer_small)
      , parent_(std::move(parent)) {
  }

 private:
  FileManager *file_manager_;
  FileUploadId file_upload_id_;
  std::shared_ptr<FileManager::UploadCallback> callback_;
  int32 new_priority_;
  uint64 upload_order_;
  bool prefer_small_;
  ActorShared<> parent_;
  bool is_active_{false};
  int attempt_{0};

  class UploadCallback final : public FileManager::UploadCallback {
   public:
    explicit UploadCallback(ActorId<ForceUploadActor> callback) : callback_(std::move(callback)) {
    }

    void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
      send_closure(std::move(callback_), &ForceUploadActor::on_upload_ok, std::move(input_file));
    }

    void on_upload_encrypted_ok(FileUploadId file_upload_id,
                                telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file) final {
      send_closure(std::move(callback_), &ForceUploadActor::on_upload_encrypted_ok, std::move(input_file));
    }

    void on_upload_secure_ok(FileUploadId file_upload_id,
                             telegram_api::object_ptr<telegram_api::InputSecureFile> input_file) final {
      send_closure(std::move(callback_), &ForceUploadActor::on_upload_secure_ok, std::move(input_file));
    }

    void on_upload_error(FileUploadId file_upload_id, Status error) final {
      send_closure(std::move(callback_), &ForceUploadActor::on_upload_error, std::move(error));
    }

    ~UploadCallback() final {
      if (callback_.empty()) {
        return;
      }
      send_closure(std::move(callback_), &ForceUploadActor::on_upload_error, Status::Error(200, "Canceled"));
    }

   private:
    ActorId<ForceUploadActor> callback_;
  };

  void on_upload_ok(telegram_api::object_ptr<telegram_api::InputFile> input_file) {
    is_active_ = false;
    if (input_file || is_ready()) {
      callback_->on_upload_ok(file_upload_id_, std::move(input_file));
      on_ok();
    } else {
      loop();
    }
  }

  void on_upload_encrypted_ok(telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file) {
    is_active_ = false;
    if (input_file || is_ready()) {
      callback_->on_upload_encrypted_ok(file_upload_id_, std::move(input_file));
      on_ok();
    } else {
      loop();
    }
  }

  void on_upload_secure_ok(telegram_api::object_ptr<telegram_api::InputSecureFile> input_file) {
    is_active_ = false;
    if (input_file || is_ready()) {
      callback_->on_upload_secure_ok(file_upload_id_, std::move(input_file));
      on_ok();
    } else {
      loop();
    }
  }

  bool is_ready() const {
    return !G()->close_flag() &&
           file_manager_->get_file_view(file_upload_id_.get_file_id()).has_active_upload_remote_location();
  }

  void on_ok() {
    callback_.reset();
    send_closure(G()->file_manager(), &FileManager::on_force_reupload_success, file_upload_id_.get_file_id());
    stop();
  }

  void on_upload_error(Status error) {
    if (attempt_ == 2) {
      callback_->on_upload_error(file_upload_id_, std::move(error));
      callback_.reset();
      stop();
    } else {
      is_active_ = false;
      loop();
    }
  }

  auto create_callback() {
    return std::make_shared<UploadCallback>(actor_id(this));
  }

  void loop() final {
    if (is_active_) {
      return;
    }
    if (G()->close_flag()) {
      return stop();
    }

    is_active_ = true;
    attempt_++;
    send_closure(G()->file_manager(), &FileManager::resume_upload, file_upload_id_, vector<int>(), create_callback(),
                 new_priority_, upload_order_, attempt_ == 2, prefer_small_);
  }

  void tear_down() final {
    if (callback_) {
      callback_->on_upload_error(file_upload_id_, Status::Error(200, "Canceled"));
    }
  }
};

void FileManager::on_force_reupload_success(FileId file_id) {
  auto node = get_sync_file_node(file_id);
  CHECK(node);
  if (!node->remote_.is_full_alive) {  // do not update for multiple simultaneous uploads
    node->last_successful_force_reupload_time_ = Time::now();
  }
}

void FileManager::resume_upload(FileUploadId file_upload_id, vector<int> bad_parts,
                                std::shared_ptr<UploadCallback> callback, int32 new_priority, uint64 upload_order,
                                bool force, bool prefer_small) {
  if (G()->close_flag()) {
    return;
  }
  CHECK(callback != nullptr);
  CHECK(new_priority > 0);

  auto node = get_sync_file_node(file_upload_id.get_file_id());
  if (!node) {
    LOG(INFO) << "Uploaded " << file_upload_id << " not found";
    callback->on_upload_error(file_upload_id, Status::Error(400, "File not found"));
    return;
  }

  if (bad_parts.size() == 1 && bad_parts[0] == -1) {
    if (node->last_successful_force_reupload_time_ >= Time::now() - 60) {
      LOG(INFO) << "Recently reuploaded " << file_upload_id << ", do not try again";
      callback->on_upload_error(file_upload_id, Status::Error(400, "Failed to reupload file"));
      return;
    }

    create_actor<ForceUploadActor>("ForceUploadActor", this, file_upload_id, std::move(callback), new_priority,
                                   upload_order, prefer_small, context_->create_reference())
        .release();
    return;
  }
  LOG(INFO) << "Resume upload of " << file_upload_id << " with priority " << new_priority << " and force = " << force;

  if (force) {
    node->remote_.is_full_alive = false;
  }
  if (prefer_small) {
    node->upload_prefer_small_ = true;
  }
  if (node->upload_pause_ == file_upload_id) {
    node->set_upload_pause(FileUploadId());
  }
  SCOPE_EXIT {
    try_flush_node(node, "resume_upload");
  };
  FileView file_view(node);
  if (file_view.has_active_upload_remote_location() && can_reuse_remote_file(file_view.get_type())) {
    LOG(INFO) << "Upload of " << file_upload_id << " has already been completed";
    callback->on_upload_ok(file_upload_id, nullptr);
    return;
  }

  if (file_view.has_full_local_location()) {
    auto status = check_local_location(node, false);
    if (status.is_error()) {
      LOG(INFO) << "Full local location of " << file_upload_id << " for upload is invalid: " << status;
    }
  }

  if (!file_view.has_full_local_location() && !file_view.has_generate_location() &&
      !file_view.has_alive_remote_location()) {
    LOG(INFO) << "Can't upload " << file_upload_id;
    callback->on_upload_error(
        file_upload_id, Status::Error(400, "Need full local (or generate, or inactive remote) location for upload"));
    return;
  }
  if (file_view.get_type() == FileType::Thumbnail &&
      (!file_view.has_full_local_location() && file_view.can_download_from_server())) {
    // TODO
    callback->on_upload_error(file_upload_id, Status::Error(400, "Failed to upload thumbnail without local location"));
    return;
  }

  LOG(INFO) << "Change upload priority of " << file_upload_id << " to " << new_priority << " with callback "
            << callback.get();
  auto &requests = file_upload_requests_[file_upload_id.get_file_id()];
  auto internal_upload_id = file_upload_id.get_internal_upload_id();
  if (internal_upload_id != 0) {
    auto &upload_info = requests.internal_uploads_[internal_upload_id];
    CHECK(upload_info.upload_callback_ == nullptr);
    upload_info.upload_order_ = upload_order;
    upload_info.upload_priority_ = narrow_cast<int8>(new_priority);
    upload_info.upload_callback_ = std::move(callback);
  } else {
    requests.user_upload_priority_ = narrow_cast<int8>(new_priority);
  }

  run_generate(node);
  run_upload(node, std::move(bad_parts));
}

bool FileManager::delete_partial_remote_location(FileUploadId file_upload_id) {
  auto node = get_sync_file_node(file_upload_id.get_file_id());
  if (!node) {
    LOG(INFO) << "Wrong " << file_upload_id;
    return false;
  }
  if (node->upload_pause_ == file_upload_id) {
    node->set_upload_pause(FileUploadId());
  }
  SCOPE_EXIT {
    try_flush_node(node, "delete_partial_remote_location");
  };
  if (node->remote_.is_full_alive) {
    LOG(INFO) << "Upload isn't needed for " << file_upload_id;
    return true;
  }

  node->delete_partial_remote_location();

  auto callback = extract_upload_callback(file_upload_id);
  if (callback != nullptr) {
    callback->on_upload_error(file_upload_id, Status::Error(200, "Canceled"));
  }

  if (node->local_.type() != LocalFileLocation::Type::Full) {
    // TODO local location isn't actually required for upload
    LOG(INFO) << "Need full local location to upload " << file_upload_id;
    return false;
  }

  auto status = check_local_location(node, false);
  if (status.is_error()) {
    LOG(INFO) << "Need full local location to upload " << file_upload_id << ": " << status;
    return false;
  }

  run_upload(node, vector<int>());
  return true;
}

void FileManager::delete_partial_remote_location_if_needed(FileUploadId file_upload_id, const Status &error) {
  if (error.code() != 429 && error.code() < 500 && !G()->close_flag()) {
    delete_partial_remote_location(file_upload_id);
  } else {
    cancel_upload(file_upload_id);
  }
}

void FileManager::delete_file_reference(FileId file_id, Slice file_reference) {
  VLOG(file_references) << "Delete file reference of file " << file_id << " "
                        << tag("reference_base64", base64_encode(file_reference));
  auto node = get_sync_file_node(file_id);
  if (!node) {
    LOG(ERROR) << "Wrong file identifier " << file_id;
    return;
  }
  node->delete_file_reference(file_reference);
  auto remote = get_remote(file_id.get_remote());
  if (remote != nullptr) {
    VLOG(file_references) << "Do delete file reference of remote file " << file_id;
    if (remote->delete_file_reference(file_reference)) {
      VLOG(file_references) << "Successfully deleted file reference of remote file " << file_id;
      node->upload_was_update_file_reference_ = false;
      node->download_was_update_file_reference_ = false;
      node->on_pmc_changed();
    }
  }
  try_flush_node_pmc(node, "delete_file_reference");
}

void FileManager::external_file_generate_write_part(int64 generation_id, int64 offset, string data, Promise<> promise) {
  send_closure(file_generate_manager_, &FileGenerateManager::external_file_generate_write_part,
               static_cast<FileGenerateManager::QueryId>(generation_id), offset, std::move(data), std::move(promise));
}

void FileManager::external_file_generate_progress(int64 generation_id, int64 expected_size, int64 local_prefix_size,
                                                  Promise<> promise) {
  send_closure(file_generate_manager_, &FileGenerateManager::external_file_generate_progress,
               static_cast<FileGenerateManager::QueryId>(generation_id), expected_size, local_prefix_size,
               std::move(promise));
}

void FileManager::external_file_generate_finish(int64 generation_id, Status status, Promise<> promise) {
  send_closure(file_generate_manager_, &FileGenerateManager::external_file_generate_finish,
               static_cast<FileGenerateManager::QueryId>(generation_id), std::move(status), std::move(promise));
}

void FileManager::run_generate(FileNodePtr node) {
  FileView file_view(node);
  if (!file_view.can_generate()) {
    // LOG(INFO) << "Skip run_generate, because file " << node->main_file_id_ << " can't be generated";
    return;
  }
  if (node->need_load_from_pmc_) {
    LOG(INFO) << "Skip run_generate, because file " << node->main_file_id_ << " needs to be loaded from PMC";
    return;
  }
  if (file_view.has_full_local_location()) {
    LOG(INFO) << "Skip run_generate, because file " << node->main_file_id_ << " has local location";
    return;
  }
  if (file_view.can_download_from_server()) {
    LOG(INFO) << "Skip run_generate, because file " << node->main_file_id_ << " can be downloaded from server";
    return;
  }

  int8 download_priority = 0;
  int8 upload_priority = 0;
  FileId file_id = node->main_file_id_;
  for (auto id : node->file_ids_) {
    {
      auto it = file_download_requests_.find(id);
      if (it != file_download_requests_.end()) {
        if (it->second.user_download_priority_ > download_priority) {
          download_priority = it->second.user_download_priority_;
        }
        for (auto &download_info : it->second.internal_downloads_) {
          if (download_info.second.download_priority_ > download_priority) {
            download_priority = download_info.second.download_priority_;
          }
        }
        if (download_priority > upload_priority) {
          file_id = id;
        }
      }
    }
    {
      auto it = file_upload_requests_.find(id);
      if (it != file_upload_requests_.end()) {
        if (it->second.user_upload_priority_ > upload_priority) {
          upload_priority = it->second.user_upload_priority_;
        }
        for (auto &upload_info : it->second.internal_uploads_) {
          if (upload_info.second.upload_priority_ > upload_priority) {
            upload_priority = upload_info.second.upload_priority_;
          }
        }
        if (upload_priority > download_priority) {
          file_id = id;
        }
      }
    }
  }

  auto old_priority = node->generate_priority_;
  node->set_generate_priority(download_priority, upload_priority);

  if (node->generate_priority_ == 0) {
    if (old_priority != 0) {
      LOG(INFO) << "Cancel file " << file_id << " generation";
      do_cancel_generate(node);
    }
    return;
  }

  if (old_priority != 0) {
    LOG(INFO) << "TODO: change file " << file_id << " generation priority";
    return;
  }

  FileGenerateManager::QueryId query_id = generate_queries_.create(GenerateQuery{file_id});
  node->generate_id_ = query_id;
  send_closure(file_generate_manager_, &FileGenerateManager::generate_file, query_id, *node->generate_, node->local_,
               node->suggested_path(), [file_manager = this, query_id] {
                 class Callback final : public FileGenerateCallback {
                   ActorId<FileManager> actor_;
                   uint64 query_id_;

                  public:
                   Callback(ActorId<FileManager> actor, FileGenerateManager::QueryId query_id)
                       : actor_(std::move(actor)), query_id_(query_id) {
                   }
                   void on_partial_generate(PartialLocalFileLocation partial_local, int64 expected_size) final {
                     send_closure(actor_, &FileManager::on_partial_generate, query_id_, std::move(partial_local),
                                  expected_size);
                   }
                   void on_ok(FullLocalFileLocation local) final {
                     send_closure(actor_, &FileManager::on_generate_ok, query_id_, std::move(local));
                   }
                   void on_error(Status error) final {
                     send_closure(actor_, &FileManager::on_generate_error, query_id_, std::move(error));
                   }
                 };
                 return make_unique<Callback>(file_manager->actor_id(file_manager), query_id);
               }());

  LOG(INFO) << "File " << file_id << " generate request has sent to FileGenerateManager";
}

void FileManager::run_upload(FileNodePtr node, vector<int> bad_parts) {
  int8 priority = 0;
  FileId file_id = node->main_file_id_;
  for (auto id : node->file_ids_) {
    auto it = file_upload_requests_.find(id);
    if (it != file_upload_requests_.end()) {
      if (it->second.user_upload_priority_ > priority) {
        priority = it->second.user_upload_priority_;
        file_id = id;
      }
      for (auto &upload_info : it->second.internal_uploads_) {
        if (upload_info.second.upload_priority_ > priority) {
          priority = upload_info.second.upload_priority_;
          file_id = id;
        }
      }
    }
  }

  auto old_priority = node->upload_priority_;

  if (priority == 0) {
    node->set_upload_priority(0);
    if (old_priority != 0) {
      LOG(INFO) << "Cancel file " << file_id << " uploading";
      do_cancel_upload(node);
    }
    return;
  }

  if (node->need_load_from_pmc_) {
    LOG(INFO) << "File " << node->main_file_id_ << " needs to be loaded from database before upload";
    return;
  }
  if (node->upload_pause_.is_valid()) {
    LOG(INFO) << "File " << node->main_file_id_ << " upload is paused: " << node->upload_pause_;
    return;
  }

  FileView file_view(node);
  if (!file_view.has_full_local_location() && !file_view.has_full_remote_location()) {
    if (node->get_by_hash_ || node->generate_id_ == 0 || !node->generate_was_update_) {
      LOG(INFO) << "Have no local location for file: get_by_hash = " << node->get_by_hash_
                << ", generate_id = " << node->generate_id_ << ", generate_was_update = " << node->generate_was_update_;
      return;
    }
    auto generate_location = file_view.get_generate_location();
    if (generate_location != nullptr && generate_location->file_type_ == FileType::SecureEncrypted) {
      // Can't upload secure file before its size is known
      LOG(INFO) << "Can't upload secure file " << node->main_file_id_ << " before it's size is known";
      return;
    }
  }

  node->set_upload_priority(priority);

  auto generate_location = file_view.get_generate_location();
  auto full_local_location = file_view.get_full_local_location();

  // create encryption key if necessary
  if (((generate_location != nullptr && generate_location->file_type_ == FileType::Encrypted) ||
       (full_local_location != nullptr && full_local_location->file_type_ == FileType::Encrypted)) &&
      file_view.encryption_key().empty()) {
    CHECK(!node->file_ids_.empty());
    bool success = set_encryption_key(node->file_ids_[0], FileEncryptionKey::create());
    LOG_IF(FATAL, !success) << "Failed to set encryption key for file " << file_id;
  }

  // create encryption key if necessary
  if (full_local_location != nullptr && full_local_location->file_type_ == FileType::SecureEncrypted &&
      file_view.encryption_key().empty()) {
    CHECK(!node->file_ids_.empty());
    bool success = set_encryption_key(node->file_ids_[0], FileEncryptionKey::create_secure_key());
    LOG_IF(FATAL, !success) << "Failed to set encryption key for file " << file_id;
  }

  if (old_priority != 0) {
    LOG(INFO) << "File " << file_id << " is already uploading";
    CHECK(node->upload_id_ != 0);
    send_closure(file_upload_manager_, &FileUploadManager::update_priority, node->upload_id_,
                 narrow_cast<int8>(-priority));
    return;
  }

  CHECK(node->upload_id_ == 0);
  if (file_view.has_alive_remote_location() && !file_view.has_active_upload_remote_location() &&
      can_reuse_remote_file(file_view.get_type()) && !node->upload_was_update_file_reference_) {
    FileUploadManager::QueryId query_id =
        upload_queries_.create(UploadQuery{file_id, UploadQuery::Type::UploadWaitFileReference});
    node->upload_id_ = query_id;
    node->upload_was_update_file_reference_ = true;

    context_->repair_file_reference(node->main_file_id_,
                                    PromiseCreator::lambda([actor_id = actor_id(this), query_id](Result<Unit> res) {
                                      send_closure(actor_id, &FileManager::on_upload_error, query_id,
                                                   Status::Error("FILE_UPLOAD_RESTART_WITH_FILE_REFERENCE"));
                                    }));
    return;
  }

  if (!node->remote_.partial && node->get_by_hash_) {
    LOG(INFO) << "Get file " << node->main_file_id_ << " by hash";
    FileUploadManager::QueryId query_id = upload_queries_.create(UploadQuery{file_id, UploadQuery::Type::UploadByHash});
    node->upload_id_ = query_id;

    send_closure(file_upload_manager_, &FileUploadManager::upload_by_hash, query_id, node->local_.full(), node->size_,
                 narrow_cast<int8>(-priority));
    return;
  }

  auto new_priority = narrow_cast<int8>(bad_parts.empty() ? -priority : priority);
  td::remove_if(bad_parts, [](auto part_id) { return part_id < 0; });

  auto expected_size = file_view.expected_size(true);
  if (node->upload_prefer_small_ && (10 << 20) < expected_size && expected_size < (30 << 20)) {
    expected_size = 10 << 20;
  }

  FileUploadManager::QueryId query_id = upload_queries_.create(UploadQuery{file_id, UploadQuery::Type::Upload});
  node->upload_id_ = query_id;
  send_closure(file_upload_manager_, &FileUploadManager::upload, query_id, node->local_,
               node->remote_.partial_or_empty(), expected_size, node->encryption_key_, new_priority,
               std::move(bad_parts));

  LOG(INFO) << "File " << file_id << " upload request has sent to FileUploadManager";
}

void FileManager::upload(FileUploadId file_upload_id, std::shared_ptr<UploadCallback> callback, int32 new_priority,
                         uint64 upload_order) {
  return resume_upload(file_upload_id, vector<int>(), std::move(callback), new_priority, upload_order);
}

std::shared_ptr<FileManager::UploadCallback> FileManager::extract_upload_callback(FileUploadId file_upload_id) {
  auto it = file_upload_requests_.find(file_upload_id.get_file_id());
  if (it == file_upload_requests_.end()) {
    return nullptr;
  }
  std::shared_ptr<UploadCallback> callback;
  auto internal_upload_id = file_upload_id.get_internal_upload_id();
  if (internal_upload_id != 0) {
    auto upload_info_it = it->second.internal_uploads_.find(internal_upload_id);
    if (upload_info_it == it->second.internal_uploads_.end()) {
      return nullptr;
    }
    callback = std::move(upload_info_it->second.upload_callback_);
    it->second.internal_uploads_.erase(upload_info_it);
  } else {
    if (it->second.user_upload_priority_ == 0) {
      return nullptr;
    }
    callback = std::make_shared<PreliminaryUploadFileCallback>();
    it->second.user_upload_priority_ = 0;
  }
  if (it->second.user_upload_priority_ == 0 && it->second.internal_uploads_.empty()) {
    file_upload_requests_.erase(it);
  }
  return callback;
}

void FileManager::finish_uploads(FileId file_id, const Status &status) {
  auto it = file_upload_requests_.find(file_id);
  if (it == file_upload_requests_.end()) {
    return;
  }
  vector<std::pair<int64, std::shared_ptr<UploadCallback>>> callbacks;
  for (auto &upload_info : it->second.internal_uploads_) {
    callbacks.emplace_back(upload_info.first, std::move(upload_info.second.upload_callback_));
  }
  if (it->second.user_upload_priority_ != 0) {
    callbacks.emplace_back(0, std::make_shared<PreliminaryUploadFileCallback>());
  }
  file_upload_requests_.erase(it);

  for (auto &callback : callbacks) {
    CHECK(callback.second != nullptr);
    if (status.is_ok()) {
      callback.second->on_upload_ok({file_id, callback.first}, nullptr);
    } else {
      callback.second->on_upload_error({file_id, callback.first}, status.clone());
    }
  }
}

void FileManager::cancel_upload(FileUploadId file_upload_id) {
  if (G()->close_flag()) {
    return;
  }

  auto node = get_sync_file_node(file_upload_id.get_file_id());
  if (!node) {
    return;
  }

  LOG(INFO) << "Cancel upload of " << file_upload_id;

  if (node->upload_pause_ == file_upload_id) {
    node->set_upload_pause(FileUploadId());
  }

  auto callback = extract_upload_callback(file_upload_id);
  if (callback != nullptr) {
    callback->on_upload_error(file_upload_id, Status::Error(200, "Canceled"));
  }

  run_generate(node);
  run_upload(node, {});
  try_flush_node(node, "cancel_upload");
}

static bool is_background_type(FileType type) {
  return type == FileType::Wallpaper || type == FileType::Background;
}

Result<FileId> FileManager::from_persistent_id(CSlice persistent_id, FileType file_type) {
  if (persistent_id.find('.') != string::npos) {
    auto r_http_url = parse_url(persistent_id);
    if (r_http_url.is_error()) {
      return Status::Error(400, PSLICE() << "Invalid file HTTP URL specified: " << r_http_url.error().message());
    }
    auto url = r_http_url.ok().get_url();
    if (!clean_input_string(url)) {
      return Status::Error(400, "URL must be in UTF-8");
    }
    return register_url(std::move(url), file_type, DialogId());
  }

  auto r_binary = base64url_decode(persistent_id);
  if (r_binary.is_error()) {
    return Status::Error(400, PSLICE() << "Wrong remote file identifier specified: " << r_binary.error().message());
  }
  auto binary = r_binary.move_as_ok();
  if (binary.empty()) {
    return Status::Error(400, "Remote file identifier must be non-empty");
  }
  if (binary.back() == FileNode::PERSISTENT_ID_VERSION_OLD) {
    return from_persistent_id_v2(binary, file_type);
  }
  if (binary.back() == FileNode::PERSISTENT_ID_VERSION) {
    return from_persistent_id_v3(binary, file_type);
  }
  if (binary.back() == FileNode::PERSISTENT_ID_VERSION_GENERATED) {
    return from_persistent_id_generated(binary, file_type);
  }
  return Status::Error(400, "Wrong remote file identifier specified: can't unserialize it. Wrong last symbol");
}

Result<FileId> FileManager::from_persistent_id_generated(Slice binary, FileType file_type) {
  binary.remove_suffix(1);
  auto decoded_binary = zero_decode(binary);
  FullGenerateFileLocation generate_location;
  auto status = unserialize(generate_location, decoded_binary);
  if (status.is_error()) {
    return Status::Error(400, "Wrong remote file identifier specified: can't unserialize it");
  }
  auto real_file_type = generate_location.file_type_;
  if ((real_file_type != file_type && file_type != FileType::Temp) ||
      (real_file_type != FileType::Thumbnail && real_file_type != FileType::EncryptedThumbnail)) {
    return Status::Error(400, PSLICE() << "Can't use file of type " << real_file_type << " as " << file_type);
  }
  if (!is_remotely_generated_file(generate_location.conversion_)) {
    return Status::Error(400, "Unexpected conversion type");
  }
  return do_register_generate(make_unique<FullGenerateFileLocation>(std::move(generate_location)), DialogId(), 0,
                              string());
}

Result<FileId> FileManager::from_persistent_id_v23(Slice binary, FileType file_type, int32 version) {
  if (version < 0 || version >= static_cast<int32>(Version::Next)) {
    return Status::Error(400, "Invalid remote file identifier");
  }
  auto decoded_binary = zero_decode(binary);
  FullRemoteFileLocation remote_location;
  log_event::WithVersion<TlParser> parser(decoded_binary);
  parser.set_version(version);
  parse(remote_location, parser);
  parser.fetch_end();
  auto status = parser.get_status();
  if (status.is_error()) {
    return Status::Error(400, "Wrong remote file identifier specified: can't unserialize it");
  }
  auto &real_file_type = remote_location.file_type_;
  if (is_document_file_type(real_file_type) && is_document_file_type(file_type)) {
    real_file_type = file_type;
  } else if (is_background_type(real_file_type) && is_background_type(file_type)) {
    // type of file matches, but real type is in the stored remote location
  } else if (real_file_type != file_type && file_type != FileType::Temp) {
    return Status::Error(400, PSLICE() << "Can't use file of type " << real_file_type << " as " << file_type);
  }
  return register_remote(std::move(remote_location), FileLocationSource::FromUser, DialogId(), 0, 0, string());
}

Result<FileId> FileManager::from_persistent_id_v2(Slice binary, FileType file_type) {
  binary.remove_suffix(1);
  return from_persistent_id_v23(binary, file_type, 0);
}

Result<FileId> FileManager::from_persistent_id_v3(Slice binary, FileType file_type) {
  binary.remove_suffix(1);
  if (binary.empty()) {
    return Status::Error(400, "Invalid remote file identifier");
  }
  int32 version = static_cast<uint8>(binary.back());
  binary.remove_suffix(1);
  return from_persistent_id_v23(binary, file_type, version);
}

FileView FileManager::get_file_view(FileId file_id) const {
  auto file_node = get_file_node(file_id);
  if (!file_node) {
    return FileView();
  }
  return FileView(file_node);
}

FileView FileManager::get_sync_file_view(FileId file_id) {
  auto file_node = get_sync_file_node(file_id);
  if (!file_node) {
    return FileView();
  }
  return FileView(file_node);
}

td_api::object_ptr<td_api::file> FileManager::get_file_object(FileId file_id) {
  auto file_node_ptr = get_sync_file_node(file_id);
  if (!file_node_ptr) {
    return td_api::make_object<td_api::file>(0, 0, 0, td_api::make_object<td_api::localFile>(),
                                             td_api::make_object<td_api::remoteFile>());
  }

  const FileNode *file_node = file_node_ptr.get();
  string persistent_file_id = file_node->get_persistent_file_id();
  string unique_file_id = file_node->get_unique_file_id();
  bool is_downloading_completed = file_node->local_.type() == LocalFileLocation::Type::Full;
  bool is_uploading_completed = !persistent_file_id.empty();
  auto size = file_node->size_;
  auto download_offset = file_node->download_offset_;
  auto expected_size = file_node->expected_size();
  auto local_prefix_size = file_node->local_prefix_size();
  auto local_total_size = file_node->local_total_size();
  auto remote_size = file_node->remote_size();
  string path = file_node->path();
  bool can_be_deleted = file_node->can_delete();

  auto file_view = FileView(file_node_ptr);
  bool can_be_downloaded = file_view.can_download_from_server() || file_view.can_generate();

  return td_api::make_object<td_api::file>(
      file_id.get(), size, expected_size,
      td_api::make_object<td_api::localFile>(std::move(path), can_be_downloaded, can_be_deleted,
                                             file_node->is_downloading(), is_downloading_completed, download_offset,
                                             local_prefix_size, local_total_size),
      td_api::make_object<td_api::remoteFile>(std::move(persistent_file_id), std::move(unique_file_id),
                                              file_node->is_uploading(), is_uploading_completed, remote_size));
}

vector<int32> FileManager::get_file_ids_object(const vector<FileId> &file_ids) {
  return transform(file_ids, [](FileId file_id) { return file_id.get(); });
}

Result<FileId> FileManager::check_input_file_id(FileType type, Result<FileId> result, bool is_encrypted,
                                                bool allow_zero, bool is_secure) {
  TRY_RESULT(file_id, std::move(result));
  if (allow_zero && !file_id.is_valid()) {
    return FileId();
  }

  auto file_node = get_sync_file_node(file_id);  // we need full data about sent files
  if (!file_node) {
    return Status::Error(400, "File not found");
  }
  auto file_view = FileView(file_node);
  FileType real_type = file_view.get_type();
  LOG(INFO) << "Checking file " << file_id << " of type " << type << "/" << real_type;
  if (!is_encrypted && !is_secure) {
    if (real_type != type && !(real_type == FileType::Temp && file_view.has_url()) &&
        !(is_document_file_type(real_type) && is_document_file_type(type)) &&
        !(is_background_type(real_type) && is_background_type(type)) &&
        !(file_view.is_encrypted() && type == FileType::Ringtone) &&
        !(real_type == FileType::PhotoStory && type == FileType::Photo) &&
        !(real_type == FileType::Photo && type == FileType::PhotoStory)) {
      // TODO: send encrypted file to unencrypted chat
      return Status::Error(400, PSLICE() << "Can't use file of type " << real_type << " as " << type);
    }
  }

  const auto *full_remote_location = file_view.get_full_remote_location();
  if (full_remote_location == nullptr) {
    return file_node->main_file_id_;
  }

  int32 remote_id = file_id.get_remote();
  if (remote_id == 0 && context_->keep_exact_remote_location()) {
    RemoteInfo info{*full_remote_location, FileLocationSource::FromUser, file_id};
    remote_id = remote_location_info_.add(info);
    if (remote_location_info_.get(remote_id).file_id_ == file_id) {
      get_file_id_info(file_id)->pin_flag_ = true;
    }
  }
  return FileId(file_node->main_file_id_.get(), remote_id);
}

Result<FileId> FileManager::get_input_thumbnail_file_id(const tl_object_ptr<td_api::InputFile> &thumbnail_input_file,
                                                        DialogId owner_dialog_id, bool is_encrypted) {
  if (thumbnail_input_file == nullptr) {
    return Status::Error(400, "inputThumbnail not specified");
  }

  switch (thumbnail_input_file->get_id()) {
    case td_api::inputFileLocal::ID: {
      const string &path = static_cast<const td_api::inputFileLocal *>(thumbnail_input_file.get())->path_;
      return register_local(
          FullLocalFileLocation(is_encrypted ? FileType::EncryptedThumbnail : FileType::Thumbnail, path, 0),
          owner_dialog_id, 0, false);
    }
    case td_api::inputFileId::ID:
      return Status::Error(400, "InputFileId is not supported for thumbnails");
    case td_api::inputFileRemote::ID:
      return Status::Error(400, "InputFileRemote is not supported for thumbnails");
    case td_api::inputFileGenerated::ID: {
      auto *generated_thumbnail = static_cast<const td_api::inputFileGenerated *>(thumbnail_input_file.get());
      return register_generate(is_encrypted ? FileType::EncryptedThumbnail : FileType::Thumbnail,
                               generated_thumbnail->original_path_, generated_thumbnail->conversion_, owner_dialog_id,
                               generated_thumbnail->expected_size_);
    }
    default:
      UNREACHABLE();
      return Status::Error(500, "Unreachable");
  }
}

Result<FileId> FileManager::get_input_file_id(FileType type, const tl_object_ptr<td_api::InputFile> &file,
                                              DialogId owner_dialog_id, bool allow_zero, bool is_encrypted,
                                              bool get_by_hash, bool is_secure, bool force_reuse) {
  if (file == nullptr) {
    if (allow_zero) {
      return FileId();
    }
    return Status::Error(400, "InputFile is not specified");
  }

  if (is_encrypted || is_secure) {
    get_by_hash = false;
  }

  auto new_type = is_encrypted ? FileType::Encrypted : (is_secure ? FileType::SecureEncrypted : type);

  auto r_file_id = [&]() -> Result<FileId> {
    switch (file->get_id()) {
      case td_api::inputFileLocal::ID: {
        const string &path = static_cast<const td_api::inputFileLocal *>(file.get())->path_;
        if (allow_zero && path.empty()) {
          return FileId();
        }
        string hash;
        if (G()->get_option_boolean("reuse_uploaded_photos_by_hash") &&
            get_main_file_type(new_type) == FileType::Photo) {
          auto r_stat = stat(path);
          if (r_stat.is_ok() && r_stat.ok().size_ > 0 && r_stat.ok().size_ < 11000000) {
            auto r_file_content = read_file_str(path, r_stat.ok().size_);
            if (r_file_content.is_ok()) {
              hash = sha256(r_file_content.ok());
              auto file_id = file_hash_to_file_id_.get(hash);
              LOG(INFO) << "Found file " << file_id << " by hash " << hex_encode(hash);
              if (file_id.is_valid()) {
                auto file_node = get_file_node(file_id);
                auto file_view = FileView(file_node);
                if (!file_view.empty()) {
                  if (force_reuse) {
                    return file_id;
                  }
                  const auto *full_remote_location = file_view.get_full_remote_location();
                  if (full_remote_location != nullptr && !full_remote_location->is_web()) {
                    return file_id;
                  }
                  if (file_view.is_uploading()) {
                    CHECK(file_node);
                    LOG(DEBUG) << "File " << file_id << " is still uploading: " << file_node->upload_priority_ << ' '
                               << file_node->generate_upload_priority_ << ' ' << file_node->upload_pause_;
                    hash.clear();
                  }
                } else {
                  LOG(DEBUG) << "File " << file_id << " isn't found";
                }
              }
            }
          }
        }
        TRY_RESULT(file_id, register_local(FullLocalFileLocation(new_type, path, 0), owner_dialog_id, 0, get_by_hash));
        if (!hash.empty()) {
          file_hash_to_file_id_.set(hash, file_id);
        }
        return file_id;
      }
      case td_api::inputFileId::ID: {
        FileId file_id(static_cast<const td_api::inputFileId *>(file.get())->id_, 0);
        if (!file_id.is_valid()) {
          return FileId();
        }
        return file_id;
      }
      case td_api::inputFileRemote::ID: {
        const string &file_persistent_id = static_cast<const td_api::inputFileRemote *>(file.get())->id_;
        if (allow_zero && file_persistent_id.empty()) {
          return FileId();
        }
        return from_persistent_id(file_persistent_id, type);
      }
      case td_api::inputFileGenerated::ID: {
        auto *generated_file = static_cast<const td_api::inputFileGenerated *>(file.get());
        return register_generate(new_type, generated_file->original_path_, generated_file->conversion_, owner_dialog_id,
                                 generated_file->expected_size_);
      }
      default:
        UNREACHABLE();
        return FileId();
    }
  }();

  return check_input_file_id(type, std::move(r_file_id), is_encrypted, allow_zero, is_secure);
}

Result<FileId> FileManager::get_map_thumbnail_file_id(Location location, int32 zoom, int32 width, int32 height,
                                                      int32 scale, DialogId owner_dialog_id) {
  if (!location.is_valid_map_point()) {
    return Status::Error(400, "Invalid location specified");
  }
  if (zoom < 13 || zoom > 20) {
    return Status::Error(400, "Wrong zoom");
  }
  if (width < 16 || width > 1024) {
    return Status::Error(400, "Wrong width");
  }
  if (height < 16 || height > 1024) {
    return Status::Error(400, "Wrong height");
  }
  if (scale < 1 || scale > 3) {
    return Status::Error(400, "Wrong scale");
  }

  const double PI = 3.14159265358979323846;
  double sin_latitude = std::sin(location.get_latitude() * PI / 180);
  int32 size = 256 * (1 << zoom);
  auto x = static_cast<int32>((location.get_longitude() + 180) / 360 * size);
  auto y = static_cast<int32>((0.5 - std::log((1 + sin_latitude) / (1 - sin_latitude)) / (4 * PI)) * size);
  x = clamp(x, 0, size - 1);  // just in case
  y = clamp(y, 0, size - 1);  // just in case

  string conversion = PSTRING() << "#map#" << zoom << '#' << x << '#' << y << '#' << width << '#' << height << '#'
                                << scale << '#';
  return register_generate(
      owner_dialog_id.get_type() == DialogType::SecretChat ? FileType::EncryptedThumbnail : FileType::Thumbnail,
      string(), std::move(conversion), owner_dialog_id, 0);
}

Result<FileId> FileManager::get_audio_thumbnail_file_id(string title, string performer, bool is_small,
                                                        DialogId owner_dialog_id) {
  if (!clean_input_string(title)) {
    return Status::Error(400, "Title must be encoded in UTF-8");
  }
  if (!clean_input_string(performer)) {
    return Status::Error(400, "Performer must be encoded in UTF-8");
  }
  for (auto &c : title) {
    if (c == '\n' || c == '#') {
      c = ' ';
    }
  }
  for (auto &c : performer) {
    if (c == '\n' || c == '#') {
      c = ' ';
    }
  }
  title = trim(title);
  performer = trim(performer);
  if (title.empty() && performer.empty()) {
    return Status::Error(400, "Title or performer must be non-empty");
  }

  string conversion = PSTRING() << "#audio_t#" << title << '#' << performer << '#' << (is_small ? '1' : '0') << '#';
  return register_generate(
      owner_dialog_id.get_type() == DialogType::SecretChat ? FileType::EncryptedThumbnail : FileType::Thumbnail,
      string(), std::move(conversion), owner_dialog_id, 0);
}

FileType FileManager::guess_file_type(const tl_object_ptr<td_api::InputFile> &file) {
  if (file == nullptr) {
    return FileType::Temp;
  }

  switch (file->get_id()) {
    case td_api::inputFileLocal::ID:
      return guess_file_type_by_path(static_cast<const td_api::inputFileLocal *>(file.get())->path_);
    case td_api::inputFileId::ID: {
      FileId file_id(static_cast<const td_api::inputFileId *>(file.get())->id_, 0);
      auto file_view = get_file_view(file_id);
      if (file_view.empty()) {
        return FileType::Temp;
      }
      return file_view.get_type();
    }
    case td_api::inputFileRemote::ID: {
      const string &file_persistent_id = static_cast<const td_api::inputFileRemote *>(file.get())->id_;
      Result<FileId> r_file_id = from_persistent_id(file_persistent_id, FileType::Temp);
      if (r_file_id.is_error()) {
        return FileType::Temp;
      }
      auto file_view = get_file_view(r_file_id.ok());
      if (file_view.empty()) {
        return FileType::Temp;
      }
      return file_view.get_type();
    }
    case td_api::inputFileGenerated::ID:
      return guess_file_type_by_path(static_cast<const td_api::inputFileGenerated *>(file.get())->original_path_);
    default:
      UNREACHABLE();
      return FileType::Temp;
  }
}

vector<tl_object_ptr<telegram_api::InputDocument>> FileManager::get_input_documents(const vector<FileId> &file_ids) {
  vector<tl_object_ptr<telegram_api::InputDocument>> result;
  result.reserve(file_ids.size());
  for (auto file_id : file_ids) {
    auto file_view = get_file_view(file_id);
    CHECK(!file_view.empty());
    const auto *full_remote_location = file_view.get_full_remote_location();
    CHECK(full_remote_location != nullptr);
    CHECK(!full_remote_location->is_web());
    result.push_back(full_remote_location->as_input_document());
  }
  return result;
}

bool FileManager::extract_was_uploaded(const telegram_api::object_ptr<telegram_api::InputMedia> &input_media) {
  if (input_media == nullptr) {
    return false;
  }

  auto input_media_id = input_media->get_id();
  if (input_media_id == telegram_api::inputMediaPaidMedia::ID) {
    auto &extended_media = static_cast<const telegram_api::inputMediaPaidMedia *>(input_media.get())->extended_media_;
    if (extended_media.size() > 1u) {
      for (auto &media : extended_media) {
        CHECK(!extract_was_uploaded(media));
      }
      return false;
    }
    CHECK(extended_media.size() == 1u);
    return extract_was_uploaded(extended_media[0]);
  }
  return input_media_id == telegram_api::inputMediaUploadedPhoto::ID ||
         input_media_id == telegram_api::inputMediaUploadedDocument::ID;
}

bool FileManager::extract_was_thumbnail_uploaded(
    const telegram_api::object_ptr<telegram_api::InputMedia> &input_media) {
  if (input_media == nullptr) {
    return false;
  }
  switch (input_media->get_id()) {
    case telegram_api::inputMediaUploadedDocument::ID:
      return static_cast<const telegram_api::inputMediaUploadedDocument *>(input_media.get())->thumb_ != nullptr;
    case telegram_api::inputMediaPaidMedia::ID: {
      auto &extended_media = static_cast<const telegram_api::inputMediaPaidMedia *>(input_media.get())->extended_media_;
      if (extended_media.size() > 1u) {
        for (auto &media : extended_media) {
          CHECK(!extract_was_thumbnail_uploaded(media));
        }
        return false;
      }
      CHECK(extended_media.size() == 1u);
      return extract_was_thumbnail_uploaded(extended_media[0]);
    }
    default:
      return false;
  }
}

string FileManager::extract_file_reference(const telegram_api::object_ptr<telegram_api::InputMedia> &input_media) {
  if (input_media == nullptr) {
    return string();
  }

  switch (input_media->get_id()) {
    case telegram_api::inputMediaDocument::ID:
      return extract_file_reference(static_cast<const telegram_api::inputMediaDocument *>(input_media.get())->id_);
    case telegram_api::inputMediaPhoto::ID:
      return extract_file_reference(static_cast<const telegram_api::inputMediaPhoto *>(input_media.get())->id_);
    case telegram_api::inputMediaPaidMedia::ID:
      UNREACHABLE();
      return string();
    case telegram_api::inputMediaUploadedDocument::ID: {
      auto uploaded_document = static_cast<const telegram_api::inputMediaUploadedDocument *>(input_media.get());
      if (uploaded_document->file_->get_id() != telegram_api::inputFileStoryDocument::ID) {
        return string();
      }
      return extract_file_reference(
          static_cast<const telegram_api::inputFileStoryDocument *>(uploaded_document->file_.get())->id_);
    }
    default:
      return string();
  }
}

vector<string> FileManager::extract_file_references(
    const telegram_api::object_ptr<telegram_api::InputMedia> &input_media) {
  if (input_media == nullptr) {
    return {};
  }
  switch (input_media->get_id()) {
    case telegram_api::inputMediaDocument::ID:
    case telegram_api::inputMediaPhoto::ID:
      return {extract_file_reference(input_media)};
    case telegram_api::inputMediaPaidMedia::ID:
      return transform(static_cast<const telegram_api::inputMediaPaidMedia *>(input_media.get())->extended_media_,
                       [](const telegram_api::object_ptr<telegram_api::InputMedia> &media) {
                         return extract_file_reference(media);
                       });
    default:
      return {};
  }
}

string FileManager::extract_cover_file_reference(
    const telegram_api::object_ptr<telegram_api::InputMedia> &input_media) {
  if (input_media == nullptr) {
    return string();
  }

  switch (input_media->get_id()) {
    case telegram_api::inputMediaDocument::ID:
      return extract_file_reference(
          static_cast<const telegram_api::inputMediaDocument *>(input_media.get())->video_cover_);
    case telegram_api::inputMediaDocumentExternal::ID:
      return extract_file_reference(
          static_cast<const telegram_api::inputMediaDocumentExternal *>(input_media.get())->video_cover_);
    case telegram_api::inputMediaUploadedDocument::ID:
      return extract_file_reference(
          static_cast<const telegram_api::inputMediaUploadedDocument *>(input_media.get())->video_cover_);
    case telegram_api::inputMediaPaidMedia::ID:
      UNREACHABLE();
      return string();
    default:
      return string();
  }
}

vector<string> FileManager::extract_cover_file_references(
    const telegram_api::object_ptr<telegram_api::InputMedia> &input_media) {
  if (input_media == nullptr) {
    return {};
  }
  switch (input_media->get_id()) {
    case telegram_api::inputMediaDocument::ID:
    case telegram_api::inputMediaDocumentExternal::ID:
    case telegram_api::inputMediaUploadedDocument::ID:
      return {extract_cover_file_reference(input_media)};
    case telegram_api::inputMediaPaidMedia::ID:
      return transform(static_cast<const telegram_api::inputMediaPaidMedia *>(input_media.get())->extended_media_,
                       [](const telegram_api::object_ptr<telegram_api::InputMedia> &media) {
                         return extract_cover_file_reference(media);
                       });
    default:
      return {};
  }
}

string FileManager::extract_file_reference(
    const telegram_api::object_ptr<telegram_api::InputDocument> &input_document) {
  if (input_document == nullptr || input_document->get_id() != telegram_api::inputDocument::ID) {
    return string();
  }

  return static_cast<const telegram_api::inputDocument *>(input_document.get())->file_reference_.as_slice().str();
}

string FileManager::extract_file_reference(const telegram_api::object_ptr<telegram_api::InputPhoto> &input_photo) {
  if (input_photo == nullptr || input_photo->get_id() != telegram_api::inputPhoto::ID) {
    return string();
  }

  return static_cast<const telegram_api::inputPhoto *>(input_photo.get())->file_reference_.as_slice().str();
}

bool FileManager::extract_was_uploaded(const telegram_api::object_ptr<telegram_api::InputChatPhoto> &input_chat_photo) {
  return input_chat_photo != nullptr && input_chat_photo->get_id() == telegram_api::inputChatUploadedPhoto::ID;
}

string FileManager::extract_file_reference(
    const telegram_api::object_ptr<telegram_api::InputChatPhoto> &input_chat_photo) {
  if (input_chat_photo == nullptr || input_chat_photo->get_id() != telegram_api::inputChatPhoto::ID) {
    return string();
  }

  return extract_file_reference(static_cast<const telegram_api::inputChatPhoto *>(input_chat_photo.get())->id_);
}

FileId FileManager::next_file_id() {
  if (!empty_file_ids_.empty()) {
    auto res = empty_file_ids_.back();
    empty_file_ids_.pop_back();
    return FileId{res, 0};
  }
  CHECK(file_id_info_.size() <= static_cast<size_t>(std::numeric_limits<int32>::max()));
  FileId res(static_cast<int32>(file_id_info_.size()), 0);
  file_id_info_.push_back(make_unique<FileIdInfo>());
  return res;
}

FileManager::FileNodeId FileManager::next_file_node_id() {
  CHECK(file_nodes_.size() <= static_cast<size_t>(std::numeric_limits<FileNodeId>::max()));
  auto res = static_cast<FileNodeId>(file_nodes_.size());
  file_nodes_.emplace_back(nullptr);
  return res;
}

void FileManager::on_start_download(FileDownloadManager::QueryId query_id) {
  if (is_closed_) {
    return;
  }

  auto query = download_queries_.get(query_id);
  CHECK(query != nullptr);

  auto file_id = query->file_id_;
  auto file_node = get_file_node(file_id);
  LOG(DEBUG) << "Receive on_start_download for file " << file_id;
  if (!file_node) {
    return;
  }
  if (file_node->download_id_ != query_id) {
    return;
  }

  LOG(DEBUG) << "Start to download part of file " << file_id;
  file_node->is_download_started_ = true;
}

void FileManager::on_partial_download(FileDownloadManager::QueryId query_id, PartialLocalFileLocation partial_local,
                                      int64 size) {
  if (is_closed_) {
    return;
  }

  auto query = download_queries_.get(query_id);
  CHECK(query != nullptr);

  auto file_id = query->file_id_;
  LOG(DEBUG) << "Receive on_partial_download for file " << file_id << " with " << partial_local
             << " and size = " << size;
  auto file_node = get_file_node(file_id);
  if (!file_node) {
    return;
  }
  if (file_node->download_id_ != query_id) {
    return;
  }

  if (size != 0) {
    FileView file_view(file_node);
    if (!file_view.is_encrypted_secure()) {
      file_node->set_size(size);
    }
  }
  file_node->set_local_location(LocalFileLocation(std::move(partial_local)), -1, -1 /* TODO */);
  try_flush_node(file_node, "on_partial_download");
}

void FileManager::on_hash(FileUploadManager::QueryId query_id, string hash) {
  if (is_closed_) {
    return;
  }

  auto query = upload_queries_.get(query_id);
  CHECK(query != nullptr);

  auto file_id = query->file_id_;

  auto file_node = get_file_node(file_id);
  LOG(DEBUG) << "Receive on_hash for file " << file_id;
  if (!file_node) {
    return;
  }
  if (file_node->upload_id_ != query_id) {
    return;
  }

  file_node->encryption_key_.set_value_hash(secure_storage::ValueHash::create(hash).move_as_ok());
}

void FileManager::on_partial_upload(FileUploadManager::QueryId query_id, PartialRemoteFileLocation partial_remote) {
  if (is_closed_) {
    return;
  }

  auto query = upload_queries_.get(query_id);
  CHECK(query != nullptr);

  auto file_id = query->file_id_;
  auto file_node = get_file_node(file_id);
  LOG(DEBUG) << "Receive on_partial_upload for file " << file_id << " with " << partial_remote;
  if (!file_node) {
    LOG(ERROR) << "Can't find being uploaded file " << file_id;
    return;
  }
  if (file_node->upload_id_ != query_id) {
    LOG(DEBUG) << "Upload identifier of file " << file_id << " is " << file_node->upload_id_ << " instead of "
               << query_id;
    return;
  }

  file_node->set_partial_remote_location(std::move(partial_remote));
  try_flush_node(file_node, "on_partial_upload");
}

void FileManager::on_download_ok(FileDownloadManager::QueryId query_id, FullLocalFileLocation local, int64 size,
                                 bool is_new) {
  if (is_closed_) {
    return;
  }

  DownloadQuery query;
  bool was_active;
  std::tie(query, was_active) = finish_download_query(query_id);
  auto file_id = query.file_id_;
  LOG(INFO) << "ON DOWNLOAD OK of " << (is_new ? "new" : "checked") << " file " << file_id << " of size " << size;
  auto r_new_file_id = register_local(std::move(local), DialogId(), size, false, true, file_id);
  Status status = Status::OK();
  if (r_new_file_id.is_error()) {
    status = Status::Error(PSLICE() << "Can't register local file after download: " << r_new_file_id.error().message());
  } else {
    if (is_new && context_->need_notify_on_new_files()) {
      context_->on_new_file(size, get_file_view(r_new_file_id.ok()).get_allocated_local_size(), 1);
    }
  }
  if (status.is_error()) {
    LOG(ERROR) << status.message();
    return on_download_error_impl(get_file_node(file_id), query.type_, was_active, std::move(status));
  }
}

void FileManager::on_upload_ok(FileUploadManager::QueryId query_id, FileType file_type,
                               PartialRemoteFileLocation partial_remote) {
  if (is_closed_) {
    return;
  }

  CHECK(partial_remote.ready_part_count_ == partial_remote.part_count_);
  auto some_file_id = finish_upload_query(query_id).first.file_id_;
  LOG(INFO) << "ON UPLOAD OK file " << some_file_id;

  auto file_node = get_file_node(some_file_id);
  if (!file_node) {
    return;
  }

  FileUploadId file_upload_id;
  uint64 file_id_upload_order{std::numeric_limits<uint64>::max()};
  for (auto id : file_node->file_ids_) {
    auto it = file_upload_requests_.find(id);
    if (it != file_upload_requests_.end()) {
      if (it->second.user_upload_priority_ != 0) {
        file_upload_id = FileUploadId{id, 0};
      } else {
        for (auto &upload_info : it->second.internal_uploads_) {
          if (upload_info.second.upload_order_ < file_id_upload_order) {
            file_upload_id = FileUploadId{id, upload_info.first};
            file_id_upload_order = upload_info.second.upload_order_;
          }
        }
      }
    }
  }
  if (!file_upload_id.get_file_id().is_valid()) {
    return;
  }
  auto callback = extract_upload_callback(file_upload_id);
  CHECK(callback != nullptr);

  LOG(INFO) << "Found being uploaded " << file_upload_id;

  FileView file_view(file_node);
  string file_name = get_file_name(file_type, file_view.suggested_path());

  if (file_view.is_encrypted_secret()) {
    telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file;
    if (partial_remote.is_big_) {
      input_file = telegram_api::make_object<telegram_api::inputEncryptedFileBigUploaded>(
          partial_remote.file_id_, partial_remote.part_count_, file_view.encryption_key().calc_fingerprint());
    } else {
      input_file = telegram_api::make_object<telegram_api::inputEncryptedFileUploaded>(
          partial_remote.file_id_, partial_remote.part_count_, "", file_view.encryption_key().calc_fingerprint());
    }
    file_node->set_upload_pause(file_upload_id);
    callback->on_upload_encrypted_ok(file_upload_id, std::move(input_file));
  } else if (file_view.is_secure()) {
    telegram_api::object_ptr<telegram_api::InputSecureFile> input_file;
    input_file = telegram_api::make_object<telegram_api::inputSecureFileUploaded>(
        partial_remote.file_id_, partial_remote.part_count_, "" /*md5*/, BufferSlice() /*file_hash*/,
        BufferSlice() /*encrypted_secret*/);
    file_node->set_upload_pause(file_upload_id);
    callback->on_upload_secure_ok(file_upload_id, std::move(input_file));
  } else {
    telegram_api::object_ptr<telegram_api::InputFile> input_file;
    if (partial_remote.is_big_) {
      input_file = telegram_api::make_object<telegram_api::inputFileBig>(
          partial_remote.file_id_, partial_remote.part_count_, std::move(file_name));
    } else {
      input_file = telegram_api::make_object<telegram_api::inputFile>(
          partial_remote.file_id_, partial_remote.part_count_, std::move(file_name), "");
    }
    file_node->set_upload_pause(file_upload_id);
    callback->on_upload_ok(file_upload_id, std::move(input_file));
  }
  // don't flush node info, because nothing actually changed
}

// for upload by hash
void FileManager::on_upload_full_ok(FileUploadManager::QueryId query_id, FullRemoteFileLocation remote) {
  if (is_closed_) {
    return;
  }

  auto file_id = finish_upload_query(query_id).first.file_id_;
  LOG(INFO) << "ON UPLOAD FULL OK for file " << file_id;
  auto new_file_id = register_remote(std::move(remote), FileLocationSource::FromServer, DialogId(), 0, 0, "");
  LOG_STATUS(merge(new_file_id, file_id));
}

void FileManager::on_partial_generate(FileGenerateManager::QueryId query_id, PartialLocalFileLocation partial_local,
                                      int64 expected_size) {
  if (is_closed_) {
    return;
  }

  auto query = generate_queries_.get(query_id);
  CHECK(query != nullptr);

  auto file_id = query->file_id_;
  auto file_node = get_file_node(file_id);
  LOG(DEBUG) << "Receive on_partial_generate for file " << file_id << ": " << partial_local.path_ << " "
             << partial_local.ready_size_;
  if (!file_node) {
    return;
  }
  if (file_node->generate_id_ != query_id) {
    return;
  }
  file_node->set_local_location(LocalFileLocation(partial_local), -1, -1 /* TODO */);
  // TODO check for size and local_size, abort generation if needed
  if (expected_size > 0) {
    file_node->set_expected_size(expected_size);
  }
  if (!file_node->generate_was_update_) {
    file_node->generate_was_update_ = true;
    run_upload(file_node, {});
  }
  if (file_node->upload_id_ != 0) {
    send_closure(file_upload_manager_, &FileUploadManager::update_local_file_location, file_node->upload_id_,
                 LocalFileLocation(std::move(partial_local)));
  }

  try_flush_node(file_node, "on_partial_generate");
}

void FileManager::on_generate_ok(FileGenerateManager::QueryId query_id, FullLocalFileLocation local) {
  if (is_closed_) {
    return;
  }

  GenerateQuery query;
  bool was_active;
  std::tie(query, was_active) = finish_generate_query(query_id);
  auto generate_file_id = query.file_id_;

  LOG(INFO) << "Receive on_generate_ok for file " << generate_file_id << ": " << local;
  auto file_node = get_file_node(generate_file_id);
  if (!file_node) {
    return;
  }

  auto old_upload_id = file_node->upload_id_;

  auto r_new_file_id = register_local(local, DialogId(), 0, false, false, generate_file_id);
  file_node = get_file_node(generate_file_id);
  if (r_new_file_id.is_error()) {
    return on_generate_error_impl(
        file_node, was_active,
        Status::Error(PSLICE() << "Can't register local file after generate: " << r_new_file_id.error()));
  }
  CHECK(file_node);

  FileView file_view(file_node);
  if (context_->need_notify_on_new_files()) {
    auto generate_location = file_view.get_generate_location();
    if (generate_location == nullptr || !begins_with(generate_location->conversion_, "#file_id#")) {
      context_->on_new_file(file_view.size(), file_view.get_allocated_local_size(), 1);
    }
  }

  run_upload(file_node, {});

  if (was_active) {
    if (old_upload_id != 0 && old_upload_id == file_node->upload_id_) {
      send_closure(file_upload_manager_, &FileUploadManager::update_local_file_location, file_node->upload_id_,
                   LocalFileLocation(std::move(local)));
    }
  }
}

void FileManager::on_download_error(FileDownloadManager::QueryId query_id, Status status) {
  if (is_closed_) {
    return;
  }

  DownloadQuery query;
  bool was_active;
  std::tie(query, was_active) = finish_download_query(query_id);
  auto node = get_file_node(query.file_id_);
  if (!node) {
    LOG(ERROR) << "Can't find file node for " << query.file_id_ << " " << status;
    return;
  }
  on_download_error_impl(node, query.type_, was_active, std::move(status));
}

void FileManager::on_generate_error(FileGenerateManager::QueryId query_id, Status status) {
  if (is_closed_) {
    return;
  }

  GenerateQuery query;
  bool was_active;
  std::tie(query, was_active) = finish_generate_query(query_id);
  auto node = get_file_node(query.file_id_);
  if (!node) {
    LOG(ERROR) << "Can't find file node for " << query.file_id_ << " " << status;
    return;
  }
  on_generate_error_impl(node, was_active, std::move(status));
}

void FileManager::on_upload_error(FileUploadManager::QueryId query_id, Status status) {
  if (is_closed_) {
    return;
  }

  UploadQuery query;
  bool was_active;
  std::tie(query, was_active) = finish_upload_query(query_id);
  auto node = get_file_node(query.file_id_);
  if (!node) {
    LOG(ERROR) << "Can't find file node for " << query.file_id_ << " " << status;
    return;
  }

  if (query.type_ == UploadQuery::Type::UploadByHash && !G()->close_flag()) {
    LOG(INFO) << "Upload By Hash failed: " << status << ", restart upload";
    node->get_by_hash_ = false;
    return run_upload(node, {});
  }
  on_upload_error_impl(node, query.type_, was_active, std::move(status));
}

void FileManager::on_download_error_impl(FileNodePtr node, DownloadQuery::Type type, bool was_active, Status status) {
  SCOPE_EXIT {
    try_flush_node(node, "on_error_impl");
  };

  if ((status.message() == "FILE_ID_INVALID" || status.message() == "LOCATION_INVALID") &&
      FileView(node).may_reload_photo()) {
    node->need_reload_photo_ = true;
    return run_download(node, true);
  }

  if (FileReferenceManager::is_file_reference_error(status)) {
    string file_reference;
    Slice prefix = "#BASE64";
    Slice error_message = status.message();
    auto pos = error_message.rfind('#');
    if (pos < error_message.size() && begins_with(error_message.substr(pos), prefix)) {
      auto r_file_reference = base64_decode(error_message.substr(pos + prefix.size()));
      if (r_file_reference.is_ok()) {
        file_reference = r_file_reference.move_as_ok();
      } else {
        LOG(ERROR) << "Can't decode file reference from error " << status << ": " << r_file_reference.error();
      }
    } else {
      LOG(ERROR) << "Unexpected error, file_reference will be deleted just in case " << status;
    }
    CHECK(!node->file_ids_.empty());
    delete_file_reference(node->file_ids_.back(), file_reference);
    return run_download(node, true);
  }

  if (begins_with(status.message(), "FILE_DOWNLOAD_RESTART")) {
    if (ends_with(status.message(), "WITH_FILE_REFERENCE")) {
      node->download_was_update_file_reference_ = true;
      return run_download(node, true);
    } else if (ends_with(status.message(), "INCREASE_PART_SIZE")) {
      if (try_fix_partial_local_location(node)) {
        return run_download(node, true);
      }
    } else {
      node->can_search_locally_ = false;
      return run_download(node, true);
    }
  }

  if (status.message() == "MTPROTO_CLUSTER_INVALID") {
    send_closure(G()->config_manager(), &ConfigManager::request_config, true);
    return run_download(node, true);
  }

  if (!was_active) {
    return;
  }

  if (G()->close_flag() && (status.code() < 400 || (status.code() == Global::request_aborted_error().code() &&
                                                    status.message() == Global::request_aborted_error().message()))) {
    status = Global::request_aborted_error();
  } else {
    if (status.code() != -1) {
      LOG(WARNING) << "Failed to " << type << " file " << node->main_file_id_ << " of type "
                   << FileView(node).get_type() << ": " << status;
    }
    if (status.code() == 0 && node->local_.type() == LocalFileLocation::Type::Partial &&
        !begins_with(status.message(), "FILE_DOWNLOAD_ID_INVALID") &&
        !begins_with(status.message(), "FILE_DOWNLOAD_LIMIT")) {
      // Remove partial location
      CSlice path = node->local_.partial().path_;
      if (begins_with(path, get_files_temp_dir(FileType::SecureDecrypted)) ||
          begins_with(path, get_files_temp_dir(FileType::Video))) {
        LOG(INFO) << "Unlink file " << path;
        send_closure(file_load_manager_, &FileLoadManager::unlink_file, std::move(node->local_.partial().path_),
                     Promise<Unit>());
        node->drop_local_location();
      }
    }
    status = Status::Error(400, status.message());
  }

  on_file_load_error(node, std::move(status));
}

void FileManager::on_generate_error_impl(FileNodePtr node, bool was_active, Status status) {
  SCOPE_EXIT {
    try_flush_node(node, "on_generate_error_impl");
  };
  if (begins_with(status.message(), "FILE_GENERATE_LOCATION_INVALID")) {
    node->set_generate_location(nullptr);
  }
  if (!was_active) {
    return;
  }

  if (G()->close_flag() && (status.code() < 400 || (status.code() == Global::request_aborted_error().code() &&
                                                    status.message() == Global::request_aborted_error().message()))) {
    status = Global::request_aborted_error();
  } else {
    if (status.code() != -1 && node->generate_ != nullptr) {
      LOG(WARNING) << "Failed to generate file " << node->main_file_id_ << " with " << *node->generate_ << ": "
                   << status;
    }
    if (status.code() == 0) {
      // Remove partial locations
      if (node->local_.type() == LocalFileLocation::Type::Partial) {
        // the file itself has already been deleted
        node->drop_local_location();
      }
      node->delete_partial_remote_location();
    }
    status = Status::Error(400, status.message());
  }

  on_file_load_error(node, std::move(status));
}

void FileManager::on_upload_error_impl(FileNodePtr node, UploadQuery::Type type, bool was_active, Status status) {
  SCOPE_EXIT {
    try_flush_node(node, "on_upload_error_impl");
  };

  if (status.message() == "FILE_PART_INVALID") {
    bool has_partial_small_location = node->remote_.partial && !node->remote_.partial->is_big_;
    FileView file_view(node);
    auto expected_size = file_view.expected_size(true);
    bool should_be_big_location = is_file_big(file_view.get_type(), expected_size);

    node->delete_partial_remote_location();
    if (has_partial_small_location && should_be_big_location) {
      return run_upload(node, {});
    }

    LOG(ERROR) << "Failed to upload file " << node->main_file_id_ << ": unexpected " << status
               << ", is_small = " << has_partial_small_location << ", should_be_big = " << should_be_big_location
               << ", expected size = " << expected_size;
  }

  if (begins_with(status.message(), "FILE_UPLOAD_RESTART")) {
    if (ends_with(status.message(), "WITH_FILE_REFERENCE")) {
      node->upload_was_update_file_reference_ = true;
    } else {
      node->delete_partial_remote_location();
    }
    return run_upload(node, {});
  }

  if (!was_active) {
    return;
  }

  if (G()->close_flag() && (status.code() < 400 || (status.code() == Global::request_aborted_error().code() &&
                                                    status.message() == Global::request_aborted_error().message()))) {
    status = Global::request_aborted_error();
  } else {
    if (status.code() != -1) {
      LOG(WARNING) << "Failed to " << type << " file " << node->main_file_id_ << " of type "
                   << FileView(node).get_type() << ": " << status;
    }
    if (status.code() == 0) {
      node->delete_partial_remote_location();
    }
    status = Status::Error(400, status.message());
  }

  on_file_load_error(node, std::move(status));
}

void FileManager::on_file_load_error(FileNodePtr node, Status status) {
  // Stop everything on error
  do_cancel_generate(node);
  do_cancel_download(node);
  do_cancel_upload(node);

  for (auto file_id : vector<FileId>(node->file_ids_)) {
    finish_downloads(file_id, status);
    finish_uploads(file_id, status);
  }
}

std::pair<FileManager::DownloadQuery, bool> FileManager::finish_download_query(FileDownloadManager::QueryId query_id) {
  auto query = download_queries_.get(query_id);
  CHECK(query != nullptr);
  auto res = *query;
  download_queries_.erase(query_id);

  auto node = get_file_node(res.file_id_);
  if (node && node->download_id_ == query_id) {
    node->download_id_ = 0;
    node->download_was_update_file_reference_ = false;
    node->is_download_started_ = false;
    node->set_download_priority(0);
    return std::make_pair(res, true);
  }
  return std::make_pair(res, false);
}

std::pair<FileManager::GenerateQuery, bool> FileManager::finish_generate_query(FileGenerateManager::QueryId query_id) {
  auto query = generate_queries_.get(query_id);
  CHECK(query != nullptr);
  auto res = *query;
  generate_queries_.erase(query_id);

  auto node = get_file_node(res.file_id_);
  if (node && node->generate_id_ == query_id) {
    node->generate_id_ = 0;
    node->generate_was_update_ = false;
    node->set_generate_priority(0, 0);
    return std::make_pair(res, true);
  }
  return std::make_pair(res, false);
}

std::pair<FileManager::UploadQuery, bool> FileManager::finish_upload_query(FileUploadManager::QueryId query_id) {
  auto query = upload_queries_.get(query_id);
  CHECK(query != nullptr);
  auto res = *query;
  upload_queries_.erase(query_id);

  auto node = get_file_node(res.file_id_);
  if (node && node->upload_id_ == query_id) {
    node->upload_id_ = 0;
    node->upload_was_update_file_reference_ = false;
    node->set_upload_priority(0);
    return std::make_pair(res, true);
  }
  return std::make_pair(res, false);
}

FullRemoteFileLocation *FileManager::get_remote(int32 key) {
  if (key == 0 || !context_->keep_exact_remote_location()) {
    return nullptr;
  }
  return &remote_location_info_.get(key).remote_;
}

void FileManager::preliminary_upload_file(const td_api::object_ptr<td_api::InputFile> &input_file, FileType file_type,
                                          int32 priority, Promise<td_api::object_ptr<td_api::file>> &&promise) {
  TRY_STATUS_PROMISE(promise, check_priority(priority));

  bool is_secret = file_type == FileType::Encrypted || file_type == FileType::EncryptedThumbnail;
  bool is_secure = file_type == FileType::SecureEncrypted;
  auto r_file_id =
      get_input_file_id(file_type, input_file, DialogId(), false, is_secret, !is_secure && !is_secret, is_secure);
  if (r_file_id.is_error()) {
    return promise.set_error(Status::Error(r_file_id.error().code(), r_file_id.error().message()));
  }
  auto file_id = r_file_id.ok();

  upload({file_id, 0}, std::make_shared<PreliminaryUploadFileCallback>(), priority, 0);

  promise.set_value(get_file_object(file_id));
}

Result<string> FileManager::get_suggested_file_name(FileId file_id, const string &directory) {
  if (!file_id.is_valid()) {
    return Status::Error(400, "Invalid file identifier");
  }
  auto node = get_sync_file_node(file_id);
  if (!node) {
    return Status::Error(400, "Wrong file identifier");
  }

  return ::td::get_suggested_file_name(directory, PathView(node->suggested_path()).file_name());
}

void FileManager::hangup() {
  file_db_.reset();
  file_generate_manager_.reset();
  file_download_manager_.reset();
  file_upload_manager_.reset();
  while (!download_queries_.empty()) {
    auto query_ids = download_queries_.ids();
    for (auto query_id : query_ids) {
      DownloadQuery query;
      bool was_active;
      std::tie(query, was_active) = finish_download_query(static_cast<FileDownloadManager::QueryId>(query_id));
      auto node = get_file_node(query.file_id_);
      if (node) {
        on_download_error_impl(node, query.type_, was_active, Global::request_aborted_error());
      }
    }
  }
  while (!generate_queries_.empty()) {
    auto query_ids = generate_queries_.ids();
    for (auto query_id : query_ids) {
      GenerateQuery query;
      bool was_active;
      std::tie(query, was_active) = finish_generate_query(static_cast<FileGenerateManager::QueryId>(query_id));
      auto node = get_file_node(query.file_id_);
      if (node) {
        on_generate_error_impl(node, was_active, Global::request_aborted_error());
      }
    }
  }
  while (!upload_queries_.empty()) {
    auto query_ids = upload_queries_.ids();
    for (auto query_id : query_ids) {
      UploadQuery query;
      bool was_active;
      std::tie(query, was_active) = finish_upload_query(static_cast<FileUploadManager::QueryId>(query_id));
      auto node = get_file_node(query.file_id_);
      if (node) {
        on_upload_error_impl(node, query.type_, was_active, Global::request_aborted_error());
      }
    }
  }
  is_closed_ = true;
  stop();
}

void FileManager::tear_down() {
  parent_.reset();

  LOG(DEBUG) << "Have " << file_id_info_.size() << " files with " << file_nodes_.size() << " file nodes, "
             << local_location_to_file_id_.size() << " local locations and " << remote_location_info_.size()
             << " remote locations to free";
}

std::atomic<int64> FileManager::internal_load_id_;

}  // namespace td
