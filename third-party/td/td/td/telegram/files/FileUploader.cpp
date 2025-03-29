//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileUploader.h"

#include "td/telegram/files/FileLoaderUtils.h"
#include "td/telegram/Global.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/SecureStorage.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UniqueId.h"

#include "td/utils/buffer.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/path.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"

namespace td {

FileUploader::FileUploader(const LocalFileLocation &local, const RemoteFileLocation &remote, int64 expected_size,
                           const FileEncryptionKey &encryption_key, std::vector<int> bad_parts,
                           unique_ptr<Callback> callback)
    : local_(local)
    , remote_(remote)
    , expected_size_(expected_size)
    , encryption_key_(encryption_key)
    , bad_parts_(std::move(bad_parts))
    , callback_(std::move(callback)) {
  if (encryption_key_.is_secret()) {
    iv_ = encryption_key_.mutable_iv();
    generate_iv_ = encryption_key_.iv_slice().str();
  }
  if (remote_.type() == RemoteFileLocation::Type::Partial && encryption_key_.is_secure() &&
      remote_.partial().part_count_ != remote_.partial().ready_part_count_) {
    remote_ = RemoteFileLocation{};
  }
}

void FileUploader::start_up() {
  if (remote_.type() == RemoteFileLocation::Type::Full) {
    return on_error(Status::Error("File is already uploaded"));
  }

  // file_size is needed only for partial local locations, but for uploaded partial files
  // size is yet unknown or local location is full, so we can always pass 0 here
  auto r_prefix_info = on_update_local_location(local_, 0);
  if (r_prefix_info.is_error()) {
    return on_error(r_prefix_info.move_as_error());
  }

  int offset = 0;
  int part_size = 0;
  if (remote_.type() == RemoteFileLocation::Type::Partial) {
    const auto &partial = remote_.partial();
    file_id_ = partial.file_id_;
    part_size = partial.part_size_;
    big_flag_ = partial.is_big_ != 0;
    offset = partial.ready_part_count_;
  } else {
    file_id_ = Random::secure_int64();
    big_flag_ = is_file_big(file_type_, expected_size_);
  }

  vector<bool> ok(offset, true);
  for (auto bad_id : bad_parts_) {
    if (bad_id >= 0 && bad_id < offset) {
      ok[bad_id] = false;
    }
  }
  vector<int> ready_parts;
  for (int i = 0; i < offset; i++) {
    if (ok[i]) {
      ready_parts.push_back(i);
    }
  }
  if (!ok.empty() && !ok[0]) {
    ready_parts.clear();
    part_size = 0;
    remote_ = RemoteFileLocation();
    file_id_ = Random::secure_int64();
    big_flag_ = is_file_big(file_type_, expected_size_);
  }

  LOG(DEBUG) << "Init file uploader for " << remote_ << " with offset = " << offset << " and part size = " << part_size;

  auto expected_size = max(local_size_, expected_size_);

  // Two cases when FILE_UPLOAD_RESTART will happen
  // 1. File is ready, size is final. But there are more uploaded parts than size of the file
  // pm.init(1, 100000, true, 10, {0, 1, 2}, false, true).ensure_error();
  // This error is definitely ok, because we are using actual size of the file on disk (mtime is checked by
  // somebody else). And actual size could change arbitrarily.
  //
  // 2. File size is not final, and some parts ending after known file size were uploaded
  // pm.init(0, 100000, false, 10, {0, 1, 2}, false, true).ensure_error();
  // This can happen only if file state became inconsistent at some point. For example, local location was deleted,
  // but partial remote location was kept. This is possible, but probably should be fixed.
  auto status = parts_manager_.init(local_size_, expected_size, local_is_ready_, part_size, ready_parts, true, true);
  LOG(DEBUG) << "Start uploading a file of size " << local_size_ << " with expected "
             << (local_is_ready_ ? "exact" : "approximate") << " size " << expected_size << ", part size " << part_size
             << " and " << ready_parts.size() << " ready parts: " << status;
  if (status.is_error()) {
    return on_error(std::move(status));
  }
  resource_state_.set_unit_size(parts_manager_.get_part_size());
  update_estimated_limit();
  on_progress();
  yield();
}

Result<FileUploader::PrefixInfo> FileUploader::on_update_local_location(const LocalFileLocation &location,
                                                                        int64 file_size) {
  SCOPE_EXIT {
    try_release_fd();
  };

  if (encryption_key_.is_secure() && !fd_path_.empty()) {
    return Status::Error("Can't change local location for Secure file");
  }

  string path;
  int64 local_size = -1;
  bool local_is_ready = false;
  if (location.type() == LocalFileLocation::Type::Empty ||
      (location.type() == LocalFileLocation::Type::Partial && encryption_key_.is_secure())) {
    path = "";
    local_size = 0;
    file_type_ = FileType::Temp;
  } else if (location.type() == LocalFileLocation::Type::Partial) {
    path = location.partial().path_;
    local_size = Bitmask(Bitmask::Decode{}, location.partial().ready_bitmask_)
                     .get_ready_prefix_size(0, location.partial().part_size_, file_size);
    file_type_ = location.partial().file_type_;
  } else {
    path = location.full().path_;
    if (path.empty()) {
      return Status::Error("FullLocalFileLocation with empty path");
    }
    local_is_ready = true;
    file_type_ = location.full().file_type_;
  }

  LOG(INFO) << "In FileUploader::on_update_local_location with " << location << ". Have path = \"" << path
            << "\", local_size = " << local_size << ", local_is_ready = " << local_is_ready
            << " and file type = " << file_type_;

  bool is_temp = false;
  if (encryption_key_.is_secure() && local_is_ready && remote_.type() == RemoteFileLocation::Type::Empty) {
    TRY_RESULT(file_fd_path, open_temp_file(FileType::Temp));
    file_fd_path.first.close();
    auto new_path = std::move(file_fd_path.second);
    TRY_RESULT(hash, secure_storage::encrypt_file(encryption_key_.secret(), path, new_path));
    LOG(INFO) << "ENCRYPT " << path << " " << new_path;
    callback_->on_hash(hash.as_slice().str());
    path = new_path;
    is_temp = true;
  }

  if (!path.empty() && (path != fd_path_ || fd_.empty())) {
    auto res_fd = FileFd::open(path, FileFd::Read);

    // Race: partial location could be already deleted. Just ignore such locations
    if (res_fd.is_error()) {
      if (location.type() == LocalFileLocation::Type::Partial) {
        LOG(INFO) << "Ignore partial local location: " << res_fd.error();
        PrefixInfo info;
        info.size = local_size_;
        info.is_ready = local_is_ready_;
        return info;
      }
      return res_fd.move_as_error();
    }

    fd_.close();
    fd_ = res_fd.move_as_ok();
    fd_path_ = path;
    is_temp_ = is_temp;
  }
  if (local_is_ready) {
    CHECK(!fd_.empty());
    TRY_RESULT_ASSIGN(local_size, fd_.get_size());
    LOG(INFO) << "Set file local_size to " << local_size;
    if (local_size == 0) {
      return Status::Error("Can't upload empty file");
    }
  } else if (!fd_.empty()) {
    TRY_RESULT(real_local_size, fd_.get_size());
    if (real_local_size < local_size) {
      LOG(ERROR) << tag("real_local_size", real_local_size) << " < " << tag("local_size", local_size);
      PrefixInfo info;
      info.size = local_size_;
      info.is_ready = local_is_ready_;
      return info;
    }
  }

  local_size_ = local_size;
  if (expected_size_ < local_size_ && (expected_size_ != (10 << 20) || local_size_ >= (30 << 20))) {
    expected_size_ = local_size_;
  }
  local_is_ready_ = local_is_ready;

  PrefixInfo info;
  info.size = local_size_;
  info.is_ready = local_is_ready_;
  return info;
}

void FileUploader::on_error(Status status) {
  fd_.close();
  if (is_temp_) {
    LOG(INFO) << "UNLINK " << fd_path_;
    unlink(fd_path_).ignore();
  }
  stop_flag_ = true;
  callback_->on_error(std::move(status));
}

Status FileUploader::generate_iv_map() {
  LOG(INFO) << "Generate iv_map " << generate_offset_ << " " << local_size_;
  auto part_size = parts_manager_.get_part_size();
  auto encryption_key = FileEncryptionKey(encryption_key_.key_slice(), generate_iv_);
  BufferSlice bytes(part_size);
  if (iv_map_.empty()) {
    iv_map_.push_back(encryption_key.mutable_iv());
  }
  CHECK(!fd_.empty());
  for (; generate_offset_ + static_cast<int64>(part_size) < local_size_;
       generate_offset_ += static_cast<int64>(part_size)) {
    TRY_RESULT(read_size, fd_.pread(bytes.as_mutable_slice(), generate_offset_));
    if (read_size != part_size) {
      return Status::Error("Failed to read file part (for iv_map)");
    }
    aes_ige_encrypt(as_slice(encryption_key.key()), as_mutable_slice(encryption_key.mutable_iv()), bytes.as_slice(),
                    bytes.as_mutable_slice());
    iv_map_.push_back(encryption_key.mutable_iv());
  }
  generate_iv_ = encryption_key.iv_slice().str();
  return Status::OK();
}

Result<NetQueryPtr> FileUploader::start_part(Part part, int32 part_count) {
  auto padded_size = part.size;
  if (encryption_key_.is_secret()) {
    padded_size = (padded_size + 15) & ~15;
  }
  BufferSlice bytes(padded_size);
  TRY_RESULT(size, fd_.pread(bytes.as_mutable_slice().truncate(part.size), part.offset));
  if (encryption_key_.is_secret()) {
    Random::secure_bytes(bytes.as_mutable_slice().substr(part.size));
    if (next_offset_ == part.offset) {
      aes_ige_encrypt(as_slice(encryption_key_.key()), as_mutable_slice(iv_), bytes.as_slice(),
                      bytes.as_mutable_slice());
      next_offset_ += static_cast<int64>(bytes.size());
    } else {
      if (part.id >= static_cast<int32>(iv_map_.size())) {
        TRY_STATUS(generate_iv_map());
      }
      CHECK(part.id < static_cast<int32>(iv_map_.size()) && part.id >= 0);
      auto iv = iv_map_[part.id];
      aes_ige_encrypt(as_slice(encryption_key_.key()), as_mutable_slice(iv), bytes.as_slice(),
                      bytes.as_mutable_slice());
    }
  }

  if (size != part.size) {
    return Status::Error("Failed to read file part");
  }

  NetQueryPtr net_query;
  if (big_flag_) {
    auto query =
        telegram_api::upload_saveBigFilePart(file_id_, part.id, local_is_ready_ ? part_count : -1, std::move(bytes));
    net_query = G()->net_query_creator().create(query, {}, DcId::main(), NetQuery::Type::Upload);
  } else {
    auto query = telegram_api::upload_saveFilePart(file_id_, part.id, std::move(bytes));
    net_query = G()->net_query_creator().create(query, {}, DcId::main(), NetQuery::Type::Upload);
  }
  net_query->file_type_ = narrow_cast<int32>(file_type_);
  return std::move(net_query);
}

Result<size_t> FileUploader::process_part(Part part, NetQueryPtr net_query) {
  Result<bool> result = [&] {
    if (big_flag_) {
      return fetch_result<telegram_api::upload_saveBigFilePart>(std::move(net_query));
    } else {
      return fetch_result<telegram_api::upload_saveFilePart>(std::move(net_query));
    }
  }();
  if (result.is_error()) {
    return result.move_as_error();
  }
  if (!result.ok()) {
    // TODO: it is possible
    return Status::Error(500, "Internal Server Error during file upload");
  }
  return part.size;
}

void FileUploader::on_progress() {
  auto part_count = parts_manager_.get_part_count();
  auto part_size = static_cast<int32>(parts_manager_.get_part_size());
  auto ready_part_count = parts_manager_.get_ready_prefix_count();
  callback_->on_partial_upload(PartialRemoteFileLocation{file_id_, part_count, part_size, ready_part_count, big_flag_,
                                                         parts_manager_.get_ready_size()});
  if (parts_manager_.ready()) {
    callback_->on_ok(file_type_, PartialRemoteFileLocation{file_id_, part_count, part_size, ready_part_count, big_flag_,
                                                           local_size_});
  }
}

void FileUploader::try_release_fd() {
  if (!keep_fd_ && !fd_.empty()) {
    fd_.close();
  }
}

Status FileUploader::acquire_fd() {
  if (fd_.empty()) {
    TRY_RESULT_ASSIGN(fd_, FileFd::open(fd_path_, FileFd::Read));
  }
  return Status::OK();
}

void FileUploader::set_resource_manager(ActorShared<ResourceManager> resource_manager) {
  resource_manager_ = std::move(resource_manager);
  send_closure(resource_manager_, &ResourceManager::update_resources, resource_state_);
}

void FileUploader::update_priority(int8 priority) {
  send_closure(resource_manager_, &ResourceManager::update_priority, priority);
}

void FileUploader::update_resources(const ResourceState &other) {
  resource_state_.update_slave(other);
  VLOG(file_loader) << "Update resources " << resource_state_;
  loop();
}

void FileUploader::update_local_file_location(const LocalFileLocation &local) {
  auto r_prefix_info = on_update_local_location(local, parts_manager_.get_size_or_zero());
  if (r_prefix_info.is_error()) {
    return on_error(r_prefix_info.move_as_error());
  }
  auto prefix_info = r_prefix_info.move_as_ok();
  auto status = parts_manager_.set_known_prefix(prefix_info.size, prefix_info.is_ready);
  if (status.is_error()) {
    return on_error(std::move(status));
  }
  loop();
}

void FileUploader::loop() {
  if (stop_flag_) {
    return;
  }
  auto status = do_loop();
  if (status.is_error()) {
    if (status.code() == -1) {
      return;
    }
    on_error(std::move(status));
  }
}

Status FileUploader::do_loop() {
  if (parts_manager_.may_finish()) {
    TRY_STATUS(parts_manager_.finish());
    fd_.close();
    if (is_temp_) {
      LOG(INFO) << "UNLINK " << fd_path_;
      unlink(fd_path_).ignore();
    }
    stop_flag_ = true;
    return Status::OK();
  }

  auto status = acquire_fd();
  if (status.is_error()) {
    if (!local_is_ready_) {
      return Status::Error(-1, "Can't open temporary file");
    }
    return status;
  }

  SCOPE_EXIT {
    try_release_fd();
  };
  while (true) {
    if (resource_state_.unused() < narrow_cast<int64>(parts_manager_.get_part_size())) {
      VLOG(file_loader) << "Receive only " << resource_state_.unused() << " resource";
      break;
    }
    TRY_RESULT(part, parts_manager_.start_part());
    if (part.size == 0) {
      break;
    }
    VLOG(file_loader) << "Start part " << tag("id", part.id) << tag("size", part.size);
    resource_state_.start_use(static_cast<int64>(part.size));

    TRY_RESULT(query, start_part(part, parts_manager_.get_part_count()));
    uint64 unique_id = UniqueId::next();
    part_map_[unique_id] = std::make_pair(part, query->cancel_slot_.get_signal_new());

    G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this, unique_id));
  }
  return Status::OK();
}

void FileUploader::tear_down() {
  for (auto &it : part_map_) {
    it.second.second.reset();  // cancel_query(it.second.second);
  }
}

void FileUploader::update_estimated_limit() {
  if (stop_flag_) {
    return;
  }
  auto estimated_extra = parts_manager_.get_estimated_extra();
  resource_state_.update_estimated_limit(estimated_extra);
  VLOG(file_loader) << "Update estimated limit " << estimated_extra;
  if (!resource_manager_.empty()) {
    keep_fd_ = narrow_cast<uint64>(resource_state_.active_limit()) >= parts_manager_.get_part_size();
    try_release_fd();
    send_closure(resource_manager_, &ResourceManager::update_resources, resource_state_);
  }
}

void FileUploader::on_result(NetQueryPtr query) {
  if (stop_flag_) {
    return;
  }
  auto unique_id = get_link_token();
  auto it = part_map_.find(unique_id);
  if (it == part_map_.end()) {
    LOG(ERROR) << "Receive result for unknown part";
    return;
  }

  Part part = it->second.first;
  it->second.second.release();
  CHECK(query->is_ready());
  part_map_.erase(it);

  bool should_restart = query->is_error() && query->error().code() == NetQuery::Error::Canceled;
  if (should_restart) {
    VLOG(file_loader) << "Restart part " << tag("id", part.id) << tag("size", part.size);
    resource_state_.stop_use(static_cast<int64>(part.size));
    parts_manager_.on_part_failed(part.id);
  } else {
    on_part_query(part, std::move(query));
  }
  update_estimated_limit();
  loop();
}

void FileUploader::on_part_query(Part part, NetQueryPtr query) {
  if (stop_flag_) {
    // important for secret files
    return;
  }
  auto status = try_on_part_query(part, std::move(query));
  if (status.is_error()) {
    on_error(std::move(status));
  }
}

Status FileUploader::try_on_part_query(Part part, NetQueryPtr query) {
  TRY_RESULT(size, process_part(part, std::move(query)));
  VLOG(file_loader) << "Ok part " << tag("id", part.id) << tag("size", part.size);
  resource_state_.stop_use(static_cast<int64>(part.size));
  TRY_STATUS(parts_manager_.on_part_ok(part.id, part.size, size));
  on_progress();
  return Status::OK();
}

}  // namespace td
