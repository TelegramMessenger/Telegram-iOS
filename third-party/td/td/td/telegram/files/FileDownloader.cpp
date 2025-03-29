//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileDownloader.h"

#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileLoaderUtils.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/SecureStorage.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UniqueId.h"

#include "td/utils/as.h"
#include "td/utils/base64.h"
#include "td/utils/buffer.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/path.h"
#include "td/utils/port/Stat.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/UInt.h"

#include <tuple>

namespace td {

FileDownloader::FileDownloader(const FullRemoteFileLocation &remote, const LocalFileLocation &local, int64 size,
                               string name, const FileEncryptionKey &encryption_key, bool is_small,
                               bool need_search_file, int64 offset, int64 limit, unique_ptr<Callback> callback)
    : remote_(remote)
    , local_(local)
    , size_(size)
    , name_(std::move(name))
    , encryption_key_(encryption_key)
    , callback_(std::move(callback))
    , is_small_(is_small)
    , need_search_file_(need_search_file)
    , ordered_flag_(encryption_key_.is_secret())
    , offset_(offset)
    , limit_(limit) {
  if (!encryption_key.empty()) {
    CHECK(offset_ == 0);
  }
}

void FileDownloader::on_error(Status status) {
  fd_.close();
  stop_flag_ = true;
  callback_->on_error(std::move(status));
}

Result<bool> FileDownloader::should_restart_part(Part part, const NetQueryPtr &net_query) {
  // Check if we should use CDN or reupload file to CDN

  if (net_query->is_error()) {
    if (net_query->error().message() == "FILE_TOKEN_INVALID") {
      use_cdn_ = false;
      return true;
    }
    if (net_query->error().message() == "REQUEST_TOKEN_INVALID") {
      return true;
    }
    return false;
  }

  switch (narrow_cast<QueryType>(UniqueId::extract_key(net_query->id()))) {
    case QueryType::Default: {
      if (net_query->ok_tl_constructor() == telegram_api::upload_fileCdnRedirect::ID) {
        TRY_RESULT(file_base, fetch_result<telegram_api::upload_getFile>(net_query->ok()));
        CHECK(file_base->get_id() == telegram_api::upload_fileCdnRedirect::ID);
        auto file = move_tl_object_as<telegram_api::upload_fileCdnRedirect>(file_base);
        LOG(DEBUG) << "Downloading of part " << part.id << " was redirected to " << oneline(to_string(file));

        auto new_cdn_file_token = file->file_token_.as_slice();
        if (cdn_file_token_ == new_cdn_file_token) {
          return true;
        }

        use_cdn_ = true;
        need_check_ = true;
        cdn_file_token_generation_++;
        cdn_file_token_ = new_cdn_file_token.str();
        cdn_dc_id_ = DcId::external(file->dc_id_);
        cdn_encryption_key_ = file->encryption_key_.as_slice().str();
        cdn_encryption_iv_ = file->encryption_iv_.as_slice().str();
        add_hash_info(file->file_hashes_);
        if (cdn_encryption_iv_.size() != 16 || cdn_encryption_key_.size() != 32) {
          return Status::Error("Wrong ctr key or iv size");
        }

        return true;
      }
      return false;
    }
    case QueryType::ReuploadCDN: {
      TRY_RESULT(file_hashes, fetch_result<telegram_api::upload_reuploadCdnFile>(net_query->ok()));
      add_hash_info(file_hashes);
      LOG(DEBUG) << "Part " << part.id << " was reuploaded to CDN";
      return true;
    }
    case QueryType::CDN: {
      if (net_query->ok_tl_constructor() == telegram_api::upload_cdnFileReuploadNeeded::ID) {
        TRY_RESULT(file_base, fetch_result<telegram_api::upload_getCdnFile>(net_query->ok()));
        CHECK(file_base->get_id() == telegram_api::upload_cdnFileReuploadNeeded::ID);
        auto file = move_tl_object_as<telegram_api::upload_cdnFileReuploadNeeded>(file_base);
        LOG(DEBUG) << "Part " << part.id << " must be reuploaded to " << oneline(to_string(file));
        cdn_part_reupload_token_[part.id] = file->request_token_.as_slice().str();
        return true;
      }
      auto it = cdn_part_file_token_generation_.find(part.id);
      CHECK(it != cdn_part_file_token_generation_.end());
      if (it->second != cdn_file_token_generation_) {
        LOG(DEBUG) << "Receive part " << part.id << " with an old file_token";
        return true;
      }
      return false;
    }
    default:
      UNREACHABLE();
  }

  return false;
}

Result<NetQueryPtr> FileDownloader::start_part(Part part, int32 part_count, int64 streaming_offset) {
  if (encryption_key_.is_secret()) {
    part.size = (part.size + 15) & ~15;  // fix for last part
  }
  // auto size = part.size;
  //// sometimes we can ask more than server has, just to check size
  // if (size < parts_manager_.get_part_size()) {
  // size = min(size + 16, parts_manager_.get_part_size());
  // LOG(INFO) << "Ask " << size << " instead of " << part.size;
  //}
  auto size = parts_manager_.get_part_size();
  CHECK(part.size <= size);

  callback_->on_start_download();

  auto net_query_type = is_small_ ? NetQuery::Type::DownloadSmall : NetQuery::Type::Download;
  NetQueryPtr net_query;
  if (!use_cdn_) {
    int32 flags = 0;
#if !TD_EMSCRIPTEN
    // CDN is supported, unless we use domains instead of IPs from a browser
    if (streaming_offset == 0) {
      flags |= telegram_api::upload_getFile::CDN_SUPPORTED_MASK;
    }
#endif
    DcId dc_id = remote_.is_web() ? G()->get_webfile_dc_id() : remote_.get_dc_id();
    auto unique_id = UniqueId::next(UniqueId::Type::Default, static_cast<uint8>(QueryType::Default));
    net_query =
        remote_.is_web()
            ? G()->net_query_creator().create(
                  unique_id, nullptr,
                  telegram_api::upload_getWebFile(remote_.as_input_web_file_location(), narrow_cast<int32>(part.offset),
                                                  narrow_cast<int32>(size)),
                  {}, dc_id, net_query_type, NetQuery::AuthFlag::On)
            : G()->net_query_creator().create(
                  unique_id, nullptr,
                  telegram_api::upload_getFile(flags, false /*ignored*/, false /*ignored*/,
                                               remote_.as_input_file_location(), part.offset, narrow_cast<int32>(size)),
                  {}, dc_id, net_query_type, NetQuery::AuthFlag::On);
  } else {
    if (remote_.is_web()) {
      return Status::Error("Can't download web file from CDN");
    }
    auto it = cdn_part_reupload_token_.find(part.id);
    if (it == cdn_part_reupload_token_.end()) {
      auto query = telegram_api::upload_getCdnFile(BufferSlice(cdn_file_token_), part.offset, narrow_cast<int32>(size));
      cdn_part_file_token_generation_[part.id] = cdn_file_token_generation_;
      net_query =
          G()->net_query_creator().create(UniqueId::next(UniqueId::Type::Default, static_cast<uint8>(QueryType::CDN)),
                                          nullptr, query, {}, cdn_dc_id_, net_query_type, NetQuery::AuthFlag::Off);
    } else {
      auto query = telegram_api::upload_reuploadCdnFile(BufferSlice(cdn_file_token_), BufferSlice(it->second));
      net_query = G()->net_query_creator().create(
          UniqueId::next(UniqueId::Type::Default, static_cast<uint8>(QueryType::ReuploadCDN)), nullptr, query, {},
          remote_.get_dc_id(), net_query_type, NetQuery::AuthFlag::On);
      cdn_part_reupload_token_.erase(it);
    }
  }
  net_query->file_type_ = narrow_cast<int32>(remote_.file_type_);
  return std::move(net_query);
}

Status FileDownloader::check_net_query(NetQueryPtr &net_query) {
  if (net_query->is_error()) {
    auto error = net_query->move_as_error();
    if (FileReferenceManager::is_file_reference_error(error)) {
      VLOG(file_references) << "Receive " << error << " for being downloaded file";
      error = Status::Error(error.code(),
                            PSLICE() << error.message() << "#BASE64" << base64_encode(remote_.get_file_reference()));
    }
    return error;
  }
  return Status::OK();
}

Result<size_t> FileDownloader::process_part(Part part, NetQueryPtr net_query) {
  TRY_STATUS(check_net_query(net_query));

  BufferSlice bytes;
  bool need_cdn_decrypt = false;
  auto query_type = narrow_cast<QueryType>(UniqueId::extract_key(net_query->id()));
  switch (query_type) {
    case QueryType::Default: {
      if (remote_.is_web()) {
        TRY_RESULT(file, fetch_result<telegram_api::upload_getWebFile>(std::move(net_query)));
        bytes = std::move(file->bytes_);
      } else {
        TRY_RESULT(file_base, fetch_result<telegram_api::upload_getFile>(std::move(net_query)));
        CHECK(file_base->get_id() == telegram_api::upload_file::ID);
        auto file = move_tl_object_as<telegram_api::upload_file>(file_base);
        LOG(DEBUG) << "Receive part " << part.id << ": " << to_string(file);
        bytes = std::move(file->bytes_);
      }
      break;
    }
    case QueryType::CDN: {
      TRY_RESULT(file_base, fetch_result<telegram_api::upload_getCdnFile>(std::move(net_query)));
      CHECK(file_base->get_id() == telegram_api::upload_cdnFile::ID);
      auto file = move_tl_object_as<telegram_api::upload_cdnFile>(file_base);
      LOG(DEBUG) << "Receive part " << part.id << " from CDN: " << to_string(file);
      bytes = std::move(file->bytes_);
      need_cdn_decrypt = true;
      break;
    }
    default:
      UNREACHABLE();
  }

  auto padded_size = part.size;
  if (encryption_key_.is_secret()) {
    padded_size = (part.size + 15) & ~15;
  }
  if (bytes.size() > padded_size) {
    return Status::Error("Part size is more than requested");
  }
  if (bytes.empty()) {
    return 0;
  }

  // Encryption
  if (need_cdn_decrypt) {
    CHECK(part.offset % 16 == 0);
    auto offset = narrow_cast<uint32>(part.offset / 16);
    offset =
        ((offset & 0xff) << 24) | ((offset & 0xff00) << 8) | ((offset & 0xff0000) >> 8) | ((offset & 0xff000000) >> 24);

    AesCtrState ctr_state;
    string iv = cdn_encryption_iv_;
    as<uint32>(&iv[12]) = offset;
    ctr_state.init(cdn_encryption_key_, iv);
    ctr_state.decrypt(bytes.as_slice(), bytes.as_mutable_slice());
  }
  if (encryption_key_.is_secret()) {
    LOG_CHECK(next_part_ == part.id) << tag("expected part.id", next_part_) << "!=" << tag("part.id", part.id);
    CHECK(!next_part_stop_);
    next_part_++;
    if (part.size % 16 != 0) {
      next_part_stop_ = true;
    }
    aes_ige_decrypt(as_slice(encryption_key_.key()), as_mutable_slice(encryption_key_.mutable_iv()), bytes.as_slice(),
                    bytes.as_mutable_slice());
  }

  auto slice = bytes.as_slice().substr(0, part.size);
  TRY_STATUS(acquire_fd());
  LOG(INFO) << "Receive " << slice.size() << " bytes at offset " << part.offset << " for \"" << path_ << '"';
  TRY_RESULT(written, fd_.pwrite(slice, part.offset));
  LOG(INFO) << "Written " << written << " bytes";
  // may write less than part.size, when size of downloadable file is unknown
  if (written != slice.size()) {
    return Status::Error("Failed to save file part to the file");
  }
  return written;
}

void FileDownloader::on_progress() {
  if (parts_manager_.ready()) {
    // do not send partial location. will lead to wrong local_size
    return;
  }
  auto ready_size = parts_manager_.get_ready_size();
  if (ready_size == 0 || path_.empty()) {
    return;
  }
  auto part_size = static_cast<int32>(parts_manager_.get_part_size());
  auto size = parts_manager_.get_size_or_zero();
  if (encryption_key_.empty() || encryption_key_.is_secure()) {
    callback_->on_partial_download(
        PartialLocalFileLocation{remote_.file_type_, part_size, path_, "", parts_manager_.get_bitmask(), ready_size},
        size);
  } else if (encryption_key_.is_secret()) {
    UInt256 iv;
    auto ready_part_count = parts_manager_.get_ready_prefix_count();
    if (ready_part_count == next_part_) {
      iv = encryption_key_.mutable_iv();
    } else {
      LOG(FATAL) << tag("ready_part_count", ready_part_count) << tag("next_part", next_part_);
    }
    callback_->on_partial_download(PartialLocalFileLocation{remote_.file_type_, part_size, path_, as_slice(iv).str(),
                                                            parts_manager_.get_bitmask(), ready_size},
                                   size);
  } else {
    UNREACHABLE();
  }
}

Status FileDownloader::process_check_query(NetQueryPtr net_query) {
  has_hash_query_ = false;
  TRY_STATUS(check_net_query(net_query));
  TRY_RESULT(file_hashes, fetch_result<telegram_api::upload_getFileHashes>(std::move(net_query)));
  add_hash_info(file_hashes);
  return Status::OK();
}

Status FileDownloader::check_loop(int64 checked_prefix_size, int64 ready_prefix_size, bool is_ready) {
  if (!need_check_) {
    return Status::OK();
  }
  SCOPE_EXIT {
    try_release_fd();
  };
  bool is_changed = false;
  vector<NetQueryPtr> queries;
  while (checked_prefix_size < ready_prefix_size) {
    //LOG(ERROR) << "NEED TO CHECK: " << checked_prefix_size << "->" << ready_prefix_size - checked_prefix_size;
    HashInfo search_info;
    search_info.offset = checked_prefix_size;
    auto it = hash_info_.upper_bound(search_info);
    if (it != hash_info_.begin()) {
      --it;
    }
    if (it != hash_info_.end() && it->offset <= checked_prefix_size &&
        it->offset + narrow_cast<int64>(it->size) > checked_prefix_size) {
      int64 begin_offset = it->offset;
      int64 end_offset = it->offset + narrow_cast<int64>(it->size);
      if (ready_prefix_size < end_offset) {
        if (!is_ready) {
          break;
        }
        end_offset = ready_prefix_size;
      }
      auto size = narrow_cast<size_t>(end_offset - begin_offset);
      auto slice = BufferSlice(size);
      TRY_STATUS(acquire_fd());
      TRY_RESULT(read_size, fd_.pread(slice.as_mutable_slice(), begin_offset));
      if (size != read_size) {
        return Status::Error("Failed to read file to check hash");
      }
      string hash(32, ' ');
      sha256(slice.as_slice(), hash);

      if (hash != it->hash) {
        if (only_check_) {
          return Status::Error("FILE_DOWNLOAD_RESTART");
        }
        return Status::Error("Hash mismatch");
      }

      checked_prefix_size = end_offset;
      is_changed = true;
      continue;
    }
    if (!has_hash_query_) {
      has_hash_query_ = true;
      auto query = telegram_api::upload_getFileHashes(remote_.as_input_file_location(), checked_prefix_size);
      auto net_query_type = is_small_ ? NetQuery::Type::DownloadSmall : NetQuery::Type::Download;
      auto net_query = G()->net_query_creator().create(query, {}, remote_.get_dc_id(), net_query_type);
      queries.push_back(std::move(net_query));
      break;
    }
    // Should fail?
    break;
  }

  if (is_changed) {
    on_progress();
  }
  for (auto &query : queries) {
    G()->net_query_dispatcher().dispatch_with_callback(
        std::move(query), actor_shared(this, UniqueId::next(UniqueId::Type::Default, COMMON_QUERY_KEY)));
  }
  if (need_check_) {
    parts_manager_.set_need_check();
    parts_manager_.set_checked_prefix_size(checked_prefix_size);
  }

  return Status::OK();
}

void FileDownloader::add_hash_info(const std::vector<telegram_api::object_ptr<telegram_api::fileHash>> &hashes) {
  for (auto &hash : hashes) {
    //LOG(ERROR) << "ADD HASH " << hash->offset_ << "->" << hash->limit_;
    HashInfo hash_info;
    hash_info.size = hash->limit_;
    hash_info.offset = hash->offset_;
    hash_info.hash = hash->hash_.as_slice().str();
    hash_info_.insert(std::move(hash_info));
  }
}

void FileDownloader::try_release_fd() {
  if (!keep_fd_ && !fd_.empty()) {
    fd_.close();
  }
}

Status FileDownloader::acquire_fd() {
  if (fd_.empty()) {
    if (path_.empty()) {
      TRY_RESULT_ASSIGN(std::tie(fd_, path_), open_temp_file(remote_.file_type_));
    } else {
      TRY_RESULT_ASSIGN(fd_, FileFd::open(path_, (only_check_ ? 0 : FileFd::Write) | FileFd::Read));
    }
  }
  return Status::OK();
}

void FileDownloader::set_resource_manager(ActorShared<ResourceManager> resource_manager) {
  resource_manager_ = std::move(resource_manager);
  send_closure(resource_manager_, &ResourceManager::update_resources, resource_state_);
}

void FileDownloader::update_priority(int8 priority) {
  send_closure(resource_manager_, &ResourceManager::update_priority, priority);
}

void FileDownloader::update_resources(const ResourceState &other) {
  resource_state_.update_slave(other);
  VLOG(file_loader) << "Update resources " << resource_state_;
  loop();
}

void FileDownloader::hangup() {
  if (delay_dispatcher_.empty()) {
    stop();
  } else {
    delay_dispatcher_.reset();
  }
}

void FileDownloader::hangup_shared() {
  if (get_link_token() == 1) {
    stop();
  }
}

void FileDownloader::update_downloaded_part(int64 offset, int64 limit, int64 max_resource_limit) {
  if (parts_manager_.get_streaming_offset() != offset) {
    auto begin_part_id = parts_manager_.set_streaming_offset(offset, limit);
    auto new_end_part_id = limit <= 0 ? parts_manager_.get_part_count()
                                      : narrow_cast<int32>((offset + limit - 1) / parts_manager_.get_part_size()) + 1;
    auto max_parts = narrow_cast<int32>(max_resource_limit / parts_manager_.get_part_size());
    auto end_part_id = begin_part_id + td::min(max_parts, new_end_part_id - begin_part_id);
    VLOG(file_loader) << "Protect parts " << begin_part_id << " ... " << end_part_id - 1;
    for (auto &it : part_map_) {
      if (!it.second.second.empty() && !(begin_part_id <= it.second.first.id && it.second.first.id < end_part_id)) {
        VLOG(file_loader) << "Cancel part " << it.second.first.id;
        it.second.second.reset();  // cancel_query(it.second.second);
      }
    }
  } else {
    parts_manager_.set_streaming_limit(limit);
  }
  update_estimated_limit();
  loop();
}

void FileDownloader::start_up() {
  if (local_.type() == LocalFileLocation::Type::Full) {
    return on_error(Status::Error("File is already downloaded"));
  }
  if (encryption_key_.is_secure() && !encryption_key_.has_value_hash()) {
    LOG(ERROR) << "Can't download Secure file with unknown value_hash";
  }
  if (remote_.file_type_ == FileType::SecureEncrypted) {
    size_ = 0;
  }
  int32 part_size = 0;
  Bitmask bitmask{Bitmask::Ones{}, 0};
  if (local_.type() == LocalFileLocation::Type::Partial) {
    const auto &partial = local_.partial();
    path_ = partial.path_;
    auto result_fd = FileFd::open(path_, FileFd::Write | FileFd::Read);
    // TODO: check timestamps..
    if (result_fd.is_ok()) {
      if ((!encryption_key_.is_secret() || partial.iv_.size() == 32) && partial.part_size_ >= 0 &&
          partial.part_size_ <= (1 << 20) && (partial.part_size_ & (partial.part_size_ - 1)) == 0) {
        bitmask = Bitmask(Bitmask::Decode{}, partial.ready_bitmask_);
        if (encryption_key_.is_secret()) {
          encryption_key_.mutable_iv() = as<UInt256>(partial.iv_.data());
          next_part_ = narrow_cast<int32>(bitmask.get_ready_parts(0));
        }
        fd_ = result_fd.move_as_ok();
        part_size = static_cast<int32>(partial.part_size_);
      } else {
        LOG(ERROR) << "Have invalid " << partial;
      }
    }
  }
  if (need_search_file_ && fd_.empty() && size_ > 0 && encryption_key_.empty() && !remote_.is_web()) {
    auto r_path = search_file(remote_.file_type_, name_, size_);
    if (r_path.is_ok()) {
      auto r_fd = FileFd::open(r_path.ok(), FileFd::Read);
      if (r_fd.is_ok()) {
        path_ = r_path.move_as_ok();
        fd_ = r_fd.move_as_ok();
        need_check_ = true;
        only_check_ = true;
        part_size = 128 * (1 << 10);
        bitmask = Bitmask{Bitmask::Ones{}, (size_ + part_size - 1) / part_size};
        LOG(INFO) << "Check hash of local file " << path_;
      }
    }
  }
  try_release_fd();

  auto ready_parts = bitmask.as_vector();
  auto status = parts_manager_.init(size_, size_, true, part_size, ready_parts, false, false);
  LOG(DEBUG) << "Start downloading a file of size " << size_ << ", part size " << part_size << " and "
             << ready_parts.size() << " ready parts: " << status;
  if (status.is_error()) {
    return on_error(std::move(status));
  }
  if (only_check_) {
    parts_manager_.set_checked_prefix_size(0);
  }
  parts_manager_.set_streaming_offset(offset_, limit_);
  if (ordered_flag_) {
    ordered_parts_ = OrderedEventsProcessor<std::pair<Part, NetQueryPtr>>(parts_manager_.get_ready_prefix_count());
  }
  auto file_type = get_main_file_type(remote_.file_type_);
  if (!is_small_ &&
      (file_type == FileType::VideoNote || file_type == FileType::Document || file_type == FileType::VoiceNote ||
       file_type == FileType::Audio || file_type == FileType::Video || file_type == FileType::Animation ||
       file_type == FileType::VideoStory || file_type == FileType::SelfDestructingVideo ||
       file_type == FileType::SelfDestructingVideoNote || file_type == FileType::SelfDestructingVoiceNote ||
       (file_type == FileType::Encrypted && size_ > (1 << 20)))) {
    delay_dispatcher_ = create_actor<DelayDispatcher>("DelayDispatcher", 0.003, actor_shared(this, 1));
    next_delay_ = 0.05;
  }
  resource_state_.set_unit_size(parts_manager_.get_part_size());
  update_estimated_limit();
  on_progress();
  yield();
}

void FileDownloader::loop() {
  if (stop_flag_) {
    return;
  }
  auto status = do_loop();
  if (status.is_error()) {
    if (status.code() == -1) {
      return;
    }
    return on_error(std::move(status));
  }
}

Status FileDownloader::do_loop() {
  TRY_STATUS(check_loop(parts_manager_.get_checked_prefix_size(), parts_manager_.get_unchecked_ready_prefix_size(),
                        parts_manager_.unchecked_ready()));

  if (parts_manager_.may_finish()) {
    TRY_STATUS(parts_manager_.finish());
    fd_.close();
    auto size = parts_manager_.get_size();
    if (encryption_key_.is_secure()) {
      TRY_RESULT(file_path, open_temp_file(remote_.file_type_));
      string tmp_path;
      std::tie(std::ignore, tmp_path) = std::move(file_path);
      TRY_STATUS(secure_storage::decrypt_file(encryption_key_.secret(), encryption_key_.value_hash(), path_, tmp_path));
      unlink(path_).ignore();
      path_ = std::move(tmp_path);
      TRY_RESULT(path_stat, stat(path_));
      size = path_stat.size_;
    }
    string path;
    if (only_check_) {
      path = path_;
    } else {
      TRY_RESULT_ASSIGN(path, create_from_temp(remote_.file_type_, path_, name_));
    }
    callback_->on_ok(FullLocalFileLocation(remote_.file_type_, std::move(path), 0), size, !only_check_);

    LOG(INFO) << "Bad download order rate: "
              << (debug_total_parts_ == 0 ? 0.0 : 100.0 * debug_bad_part_order_ / debug_total_parts_) << "% "
              << debug_bad_part_order_ << '/' << debug_total_parts_ << ' ' << debug_bad_parts_;
    stop_flag_ = true;
    return Status::OK();
  }

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

    TRY_RESULT(query, start_part(part, parts_manager_.get_part_count(), parts_manager_.get_streaming_offset()));
    uint64 unique_id = UniqueId::next();
    part_map_[unique_id] = std::make_pair(part, query->cancel_slot_.get_signal_new());

    auto callback = actor_shared(this, unique_id);
    if (delay_dispatcher_.empty()) {
      G()->net_query_dispatcher().dispatch_with_callback(std::move(query), std::move(callback));
    } else {
      query->debug("sent to DelayDispatcher");
      send_closure(delay_dispatcher_, &DelayDispatcher::send_with_callback_and_delay, std::move(query),
                   std::move(callback), next_delay_);
      next_delay_ = max(next_delay_ * 0.8, 0.003);
    }
  }
  return Status::OK();
}

void FileDownloader::tear_down() {
  for (auto &it : part_map_) {
    it.second.second.reset();  // cancel_query(it.second.second);
  }
  ordered_parts_.clear([](auto &&part) { part.second->clear(); });
  if (!delay_dispatcher_.empty()) {
    send_closure(std::move(delay_dispatcher_), &DelayDispatcher::close_silent);
  }
}

void FileDownloader::update_estimated_limit() {
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

void FileDownloader::on_result(NetQueryPtr query) {
  if (stop_flag_) {
    return;
  }
  auto unique_id = get_link_token();
  if (UniqueId::extract_key(unique_id) == COMMON_QUERY_KEY) {
    auto status = process_check_query(std::move(query));
    if (status.is_error()) {
      on_error(std::move(status));
    } else {
      loop();
    }
    return;
  }
  auto it = part_map_.find(unique_id);
  if (it == part_map_.end()) {
    LOG(WARNING) << "Receive result for unknown part";
    return;
  }

  Part part = it->second.first;
  it->second.second.release();
  CHECK(query->is_ready());
  part_map_.erase(it);

  bool next = false;
  auto status = [&] {
    TRY_RESULT(should_restart, should_restart_part(part, query));
    if (query->is_error() && query->error().code() == NetQuery::Error::Canceled) {
      should_restart = true;
    }
    if (should_restart) {
      VLOG(file_loader) << "Restart part " << tag("id", part.id) << tag("size", part.size);
      resource_state_.stop_use(static_cast<int64>(part.size));
      parts_manager_.on_part_failed(part.id);
    } else {
      next = true;
    }
    return Status::OK();
  }();
  if (status.is_error()) {
    return on_error(std::move(status));
  }

  if (next) {
    if (ordered_flag_) {
      auto seq_no = part.id;
      ordered_parts_.add(
          seq_no, std::make_pair(part, std::move(query)),
          [this](uint64 seq_no, std::pair<Part, NetQueryPtr> &&p) { on_part_query(p.first, std::move(p.second)); });
    } else {
      on_part_query(part, std::move(query));
    }
  }
  update_estimated_limit();
  loop();
}

void FileDownloader::on_part_query(Part part, NetQueryPtr query) {
  if (stop_flag_) {
    // important for secret files
    return;
  }
  auto status = try_on_part_query(part, std::move(query));
  if (status.is_error()) {
    on_error(std::move(status));
  }
}

Status FileDownloader::try_on_part_query(Part part, NetQueryPtr query) {
  TRY_RESULT(size, process_part(part, std::move(query)));
  VLOG(file_loader) << "Ok part " << tag("id", part.id) << tag("size", part.size);
  resource_state_.stop_use(static_cast<int64>(part.size));
  auto old_ready_prefix_count = parts_manager_.get_unchecked_ready_prefix_count();
  TRY_STATUS(parts_manager_.on_part_ok(part.id, part.size, size));
  auto new_ready_prefix_count = parts_manager_.get_unchecked_ready_prefix_count();
  debug_total_parts_++;
  if (old_ready_prefix_count == new_ready_prefix_count) {
    debug_bad_parts_.push_back(part.id);
    debug_bad_part_order_++;
  }
  on_progress();
  return Status::OK();
}

}  // namespace td
