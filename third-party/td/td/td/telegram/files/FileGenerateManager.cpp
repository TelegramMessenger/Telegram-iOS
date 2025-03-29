//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileGenerateManager.h"

#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileLoaderUtils.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/Td.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Parser.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/port/Stat.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"

#include <cmath>
#include <memory>
#include <utility>

namespace td {

class FileGenerateActor : public Actor {
 public:
  virtual void file_generate_write_part(int64 offset, string data, Promise<> promise) {
    LOG(ERROR) << "Receive unexpected file_generate_write_part";
  }
  virtual void file_generate_progress(int64 expected_size, int64 local_prefix_size, Promise<> promise) = 0;
  virtual void file_generate_finish(Status status, Promise<> promise) = 0;
};

class FileDownloadGenerateActor final : public FileGenerateActor {
 public:
  FileDownloadGenerateActor(FileType file_type, FileId file_id, unique_ptr<FileGenerateCallback> callback,
                            ActorShared<> parent)
      : file_type_(file_type), file_id_(file_id), callback_(std::move(callback)), parent_(std::move(parent)) {
  }
  void file_generate_progress(int64 expected_size, int64 local_prefix_size, Promise<> promise) final {
    UNREACHABLE();
  }
  void file_generate_finish(Status status, Promise<> promise) final {
    UNREACHABLE();
  }

 private:
  FileType file_type_;
  FileId file_id_;
  int64 internal_download_id_ = 0;
  unique_ptr<FileGenerateCallback> callback_;
  ActorShared<> parent_;

  void start_up() final {
    LOG(INFO) << "Generate by downloading " << file_id_;
    class Callback final : public FileManager::DownloadCallback {
     public:
      explicit Callback(ActorId<FileDownloadGenerateActor> parent) : parent_(std::move(parent)) {
      }

      // TODO: upload during download

      void on_download_ok(FileId file_id) final {
        send_closure(parent_, &FileDownloadGenerateActor::on_download_ok);
      }
      void on_download_error(FileId file_id, Status error) final {
        send_closure(parent_, &FileDownloadGenerateActor::on_download_error, std::move(error));
      }

     private:
      ActorId<FileDownloadGenerateActor> parent_;
    };

    internal_download_id_ = FileManager::get_internal_download_id();
    send_closure(G()->file_manager(), &FileManager::download, file_id_, internal_download_id_,
                 std::make_shared<Callback>(actor_id(this)), 1, -1, -1, Promise<td_api::object_ptr<td_api::file>>());
  }
  void hangup() final {
    send_closure(G()->file_manager(), &FileManager::cancel_download, file_id_, internal_download_id_, false);
    stop();
  }

  void on_download_ok() {
    send_lambda(G()->file_manager(),
                [file_type = file_type_, file_id = file_id_, callback = std::move(callback_)]() mutable {
                  auto file_view = G()->td().get_actor_unsafe()->file_manager_->get_file_view(file_id);
                  CHECK(!file_view.empty());
                  const auto *full_local_location = file_view.get_full_local_location();
                  if (full_local_location != nullptr) {
                    auto location = *full_local_location;
                    location.file_type_ = file_type;
                    callback->on_ok(std::move(location));
                  } else {
                    LOG(ERROR) << "Expected to have local location";
                    callback->on_error(Status::Error(500, "Unknown"));
                  }
                });
    stop();
  }
  void on_download_error(Status error) {
    callback_->on_error(std::move(error));
    stop();
  }
};

class WebFileDownloadGenerateActor final : public FileGenerateActor {
 public:
  WebFileDownloadGenerateActor(string conversion, unique_ptr<FileGenerateCallback> callback, ActorShared<> parent)
      : conversion_(std::move(conversion)), callback_(std::move(callback)), parent_(std::move(parent)) {
  }
  void file_generate_progress(int64 expected_size, int64 local_prefix_size, Promise<> promise) final {
    UNREACHABLE();
  }
  void file_generate_finish(Status status, Promise<> promise) final {
    UNREACHABLE();
  }

 private:
  string conversion_;
  unique_ptr<FileGenerateCallback> callback_;
  ActorShared<> parent_;
  string file_name_;

  class Callback final : public NetQueryCallback {
    ActorId<WebFileDownloadGenerateActor> parent_;

   public:
    explicit Callback(ActorId<WebFileDownloadGenerateActor> parent) : parent_(parent) {
    }

    void on_result(NetQueryPtr query) final {
      send_closure(parent_, &WebFileDownloadGenerateActor::on_result, std::move(query));
    }

    void hangup_shared() final {
      send_closure(parent_, &WebFileDownloadGenerateActor::hangup_shared);
    }
  };
  ActorOwn<NetQueryCallback> net_callback_;

  Result<tl_object_ptr<telegram_api::InputWebFileLocation>> parse_conversion() {
    auto parts = full_split(Slice(conversion_), '#');
    if (parts.size() <= 2 || !parts[0].empty() || !parts.back().empty()) {
      return Status::Error("Wrong conversion");
    }

    if (parts.size() == 6 && parts[1] == "audio_t") {
      // music thumbnail
      if (parts[2].empty() && parts[3].empty()) {
        return Status::Error("Title or performer must be non-empty");
      }
      if (parts[4] != "0" && parts[4] != "1") {
        return Status::Error("Invalid conversion");
      }

      bool is_small = parts[4][0] == '1';
      file_name_ = PSTRING() << "Album cover " << (is_small ? "thumbnail " : "") << "for " << parts[3] << " - "
                             << parts[2] << ".jpg";

      int32 flags = telegram_api::inputWebFileAudioAlbumThumbLocation::TITLE_MASK;
      if (is_small) {
        flags |= telegram_api::inputWebFileAudioAlbumThumbLocation::SMALL_MASK;
      }
      return make_tl_object<telegram_api::inputWebFileAudioAlbumThumbLocation>(flags, false /*ignored*/, nullptr,
                                                                               parts[2].str(), parts[3].str());
    }

    if (parts.size() != 9 || parts[1] != "map") {
      return Status::Error("Wrong conversion");
    }

    TRY_RESULT(zoom, to_integer_safe<int32>(parts[2]));
    TRY_RESULT(x, to_integer_safe<int32>(parts[3]));
    TRY_RESULT(y, to_integer_safe<int32>(parts[4]));
    TRY_RESULT(width, to_integer_safe<int32>(parts[5]));
    TRY_RESULT(height, to_integer_safe<int32>(parts[6]));
    TRY_RESULT(scale, to_integer_safe<int32>(parts[7]));

    if (zoom < 13 || zoom > 20) {
      return Status::Error("Wrong zoom");
    }
    auto size = 256 * (1 << zoom);
    if (x < 0 || x >= size) {
      return Status::Error("Wrong x");
    }
    if (y < 0 || y >= size) {
      return Status::Error("Wrong y");
    }
    if (width < 16 || height < 16 || width > 1024 || height > 1024) {
      return Status::Error("Wrong dimensions");
    }
    if (scale < 1 || scale > 3) {
      return Status::Error("Wrong scale");
    }

    file_name_ = PSTRING() << "map_" << zoom << "_" << x << "_" << y << ".png";

    const double PI = 3.14159265358979323846;
    double longitude = (x + 0.1) * 360.0 / size - 180;
    double latitude = 90 - 360 * std::atan(std::exp(((y + 0.1) / size - 0.5) * 2 * PI)) / PI;

    int64 access_hash = G()->get_location_access_hash(latitude, longitude);
    return make_tl_object<telegram_api::inputWebFileGeoPointLocation>(
        make_tl_object<telegram_api::inputGeoPoint>(0, latitude, longitude, 0), access_hash, width, height, zoom,
        scale);
  }

  void start_up() final {
    auto r_input_web_file = parse_conversion();
    if (r_input_web_file.is_error()) {
      LOG(ERROR) << "Can't parse " << conversion_ << ": " << r_input_web_file.error();
      return on_error(r_input_web_file.move_as_error());
    }

    net_callback_ = create_actor<Callback>("WebFileDownloadGenerateCallback", actor_id(this));

    LOG(INFO) << "Download " << conversion_;
    auto query =
        G()->net_query_creator().create(telegram_api::upload_getWebFile(r_input_web_file.move_as_ok(), 0, 1 << 20), {},
                                        G()->get_webfile_dc_id(), NetQuery::Type::DownloadSmall);
    G()->net_query_dispatcher().dispatch_with_callback(std::move(query), {net_callback_.get(), 0});
  }

  void on_result(NetQueryPtr query) {
    auto r_result = process_result(std::move(query));
    if (r_result.is_error()) {
      return on_error(r_result.move_as_error());
    }

    callback_->on_ok(r_result.ok());
    stop();
  }

  Result<FullLocalFileLocation> process_result(NetQueryPtr query) {
    TRY_RESULT(web_file, fetch_result<telegram_api::upload_getWebFile>(std::move(query)));

    if (static_cast<size_t>(web_file->size_) != web_file->bytes_.size()) {
      LOG(ERROR) << "Failed to download web file of size " << web_file->size_;
      return Status::Error("File is too big");
    }

    return save_file_bytes(FileType::Thumbnail, std::move(web_file->bytes_), file_name_);
  }

  void on_error(Status error) {
    callback_->on_error(std::move(error));
    stop();
  }

  void hangup_shared() final {
    on_error(Status::Error(-1, "Canceled"));
  }
};

class FileExternalGenerateActor final : public FileGenerateActor {
 public:
  FileExternalGenerateActor(FileGenerateManager::QueryId query_id, const FullGenerateFileLocation &generate_location,
                            const LocalFileLocation &local_location, string name,
                            unique_ptr<FileGenerateCallback> callback, ActorShared<> parent)
      : query_id_(query_id)
      , generate_location_(generate_location)
      , local_(local_location)
      , name_(std::move(name))
      , callback_(std::move(callback))
      , parent_(std::move(parent)) {
  }

  void file_generate_write_part(int64 offset, string data, Promise<> promise) final {
    check_status(do_file_generate_write_part(offset, data), std::move(promise));
  }

  void file_generate_progress(int64 expected_size, int64 local_prefix_size, Promise<> promise) final {
    check_status(do_file_generate_progress(expected_size, local_prefix_size), std::move(promise));
  }

  void file_generate_finish(Status status, Promise<> promise) final {
    if (status.is_error()) {
      check_status(std::move(status));
      return promise.set_value(Unit());
    }

    check_status(do_file_generate_finish(), std::move(promise));
  }

 private:
  FileGenerateManager::QueryId query_id_;
  FullGenerateFileLocation generate_location_;
  LocalFileLocation local_;
  string name_;
  string path_;
  unique_ptr<FileGenerateCallback> callback_;
  ActorShared<> parent_;

  void start_up() final {
    if (local_.type() == LocalFileLocation::Type::Full) {
      callback_->on_ok(local_.full());
      callback_.reset();
      return stop();
    }

    if (local_.type() == LocalFileLocation::Type::Partial) {
      const auto &partial = local_.partial();
      path_ = partial.path_;
      LOG(INFO) << "Unlink partially generated file at " << path_;
      unlink(path_).ignore();
    } else {
      auto r_file_path = open_temp_file(generate_location_.file_type_);
      if (r_file_path.is_error()) {
        return check_status(r_file_path.move_as_error());
      }
      auto file_path = r_file_path.move_as_ok();
      file_path.first.close();
      path_ = file_path.second;
    }
    send_closure(
        G()->td(), &Td::send_update,
        make_tl_object<td_api::updateFileGenerationStart>(
            static_cast<int64>(query_id_), generate_location_.original_path_, path_, generate_location_.conversion_));
  }
  void hangup() final {
    check_status(Status::Error(-1, "Canceled"));
  }

  Status do_file_generate_write_part(int64 offset, const string &data) {
    if (offset < 0) {
      return Status::Error("Wrong offset specified");
    }

    auto size = data.size();
    TRY_RESULT(fd, FileFd::open(path_, FileFd::Create | FileFd::Write));
    TRY_RESULT(written, fd.pwrite(data, offset));
    if (written != size) {
      return Status::Error(PSLICE() << "Failed to write file: written " << written << " bytes instead of " << size);
    }
    return Status::OK();
  }

  Status do_file_generate_progress(int64 expected_size, int64 local_prefix_size) {
    if (local_prefix_size < 0) {
      return Status::Error(400, "Invalid local prefix size");
    }
    callback_->on_partial_generate(PartialLocalFileLocation{generate_location_.file_type_, local_prefix_size, path_, "",
                                                            Bitmask(Bitmask::Ones{}, 1).encode(), local_prefix_size},
                                   expected_size);
    return Status::OK();
  }

  Status do_file_generate_finish() {
    TRY_RESULT(perm_path, create_from_temp(generate_location_.file_type_, path_, name_));
    callback_->on_ok(FullLocalFileLocation(generate_location_.file_type_, std::move(perm_path), 0));
    callback_.reset();
    stop();
    return Status::OK();
  }

  void check_status(Status status, Promise<> promise = Promise<>()) {
    if (promise) {
      if (status.is_ok() || status.code() == -1) {
        promise.set_value(Unit());
      } else {
        promise.set_error(Status::Error(400, status.message()));
      }
    }

    if (status.is_error()) {
      LOG(INFO) << "Unlink partially generated file at " << path_ << " because of " << status;
      unlink(path_).ignore();
      callback_->on_error(std::move(status));
      callback_.reset();
      stop();
    }
  }

  void tear_down() final {
    send_closure(G()->td(), &Td::send_update,
                 make_tl_object<td_api::updateFileGenerationStop>(static_cast<int64>(query_id_)));
  }
};

FileGenerateManager::Query::~Query() = default;
FileGenerateManager::Query::Query(Query &&) noexcept = default;
FileGenerateManager::Query &FileGenerateManager::Query::operator=(Query &&) noexcept = default;

static Status check_mtime(std::string &conversion, CSlice original_path) {
  if (original_path.empty()) {
    return Status::OK();
  }
  ConstParser parser(conversion);
  if (!parser.try_skip("#mtime#")) {
    return Status::OK();
  }
  auto mtime_str = parser.read_till('#');
  parser.skip('#');
  while (mtime_str.size() >= 2 && mtime_str[0] == '0') {
    mtime_str.remove_prefix(1);
  }
  auto r_mtime = to_integer_safe<uint64>(mtime_str);
  if (parser.status().is_error() || r_mtime.is_error()) {
    return Status::OK();
  }
  auto expected_mtime = r_mtime.move_as_ok();
  conversion = parser.read_all().str();
  auto r_stat = stat(original_path);
  uint64 actual_mtime = r_stat.is_ok() ? r_stat.ok().mtime_nsec_ : 0;
  if (are_modification_times_equal(expected_mtime, actual_mtime)) {
    LOG(DEBUG) << "File \"" << original_path << "\" modification time " << actual_mtime << " matches";
    return Status::OK();
  }
  return Status::Error(PSLICE() << "FILE_GENERATE_LOCATION_INVALID: File \"" << original_path
                                << "\" was modified: " << tag("expected modification time", expected_mtime)
                                << tag("actual modification time", actual_mtime));
}

void FileGenerateManager::generate_file(QueryId query_id, FullGenerateFileLocation generate_location,
                                        const LocalFileLocation &local_location, string name,
                                        unique_ptr<FileGenerateCallback> callback) {
  LOG(INFO) << "Begin to generate file with " << generate_location;
  auto mtime_status = check_mtime(generate_location.conversion_, generate_location.original_path_);
  if (mtime_status.is_error()) {
    return callback->on_error(std::move(mtime_status));
  }

  CHECK(query_id != 0);
  auto it_flag = query_id_to_query_.emplace(query_id, Query{});
  LOG_CHECK(it_flag.second) << "Query identifier must be unique";
  auto parent = actor_shared(this, query_id);

  Slice file_id_query = "#file_id#";
  Slice conversion = generate_location.conversion_;

  auto &query = it_flag.first->second;
  if (begins_with(conversion, file_id_query)) {
    auto file_id = FileId(to_integer<int32>(conversion.substr(file_id_query.size())), 0);
    query.worker_ = create_actor<FileDownloadGenerateActor>("FileDownloadGenerateActor", generate_location.file_type_,
                                                            file_id, std::move(callback), std::move(parent));
  } else if (FileManager::is_remotely_generated_file(conversion) && generate_location.original_path_.empty()) {
    query.worker_ = create_actor<WebFileDownloadGenerateActor>("WebFileDownloadGenerateActor",
                                                               std::move(generate_location.conversion_),
                                                               std::move(callback), std::move(parent));
  } else {
    query.worker_ = create_actor<FileExternalGenerateActor>("FileExternalGenerationActor", query_id, generate_location,
                                                            local_location, std::move(name), std::move(callback),
                                                            std::move(parent));
  }
}

void FileGenerateManager::cancel(QueryId query_id) {
  auto it = query_id_to_query_.find(query_id);
  if (it == query_id_to_query_.end()) {
    return;
  }
  it->second.worker_.reset();
}

void FileGenerateManager::external_file_generate_write_part(QueryId query_id, int64 offset, string data,
                                                            Promise<> promise) {
  auto it = query_id_to_query_.find(query_id);
  if (it == query_id_to_query_.end()) {
    return promise.set_error(Status::Error(400, "Unknown generation_id"));
  }
  auto safe_promise = SafePromise<>(std::move(promise), Status::Error(400, "Generation has already been finished"));
  send_closure(it->second.worker_, &FileGenerateActor::file_generate_write_part, offset, std::move(data),
               std::move(safe_promise));
}

void FileGenerateManager::external_file_generate_progress(QueryId query_id, int64 expected_size,
                                                          int64 local_prefix_size, Promise<> promise) {
  auto it = query_id_to_query_.find(query_id);
  if (it == query_id_to_query_.end()) {
    return promise.set_error(Status::Error(400, "Unknown generation_id"));
  }
  auto safe_promise = SafePromise<>(std::move(promise), Status::Error(400, "Generation has already been finished"));
  send_closure(it->second.worker_, &FileGenerateActor::file_generate_progress, expected_size, local_prefix_size,
               std::move(safe_promise));
}

void FileGenerateManager::external_file_generate_finish(QueryId query_id, Status status, Promise<> promise) {
  auto it = query_id_to_query_.find(query_id);
  if (it == query_id_to_query_.end()) {
    return promise.set_error(Status::Error(400, "Unknown generation_id"));
  }
  auto safe_promise = SafePromise<>(std::move(promise), Status::Error(400, "Generation has already been finished"));
  send_closure(it->second.worker_, &FileGenerateActor::file_generate_finish, std::move(status),
               std::move(safe_promise));
}

void FileGenerateManager::do_cancel(QueryId query_id) {
  query_id_to_query_.erase(query_id);
}

void FileGenerateManager::hangup_shared() {
  do_cancel(get_link_token());
  loop();
}

void FileGenerateManager::hangup() {
  close_flag_ = true;
  for (auto &it : query_id_to_query_) {
    it.second.worker_.reset();
  }
  loop();
}

void FileGenerateManager::loop() {
  if (close_flag_ && query_id_to_query_.empty()) {
    stop();
  }
}

}  // namespace td
