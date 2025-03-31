//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileDbId.h"
#include "td/telegram/files/FileDownloadManager.h"
#include "td/telegram/files/FileEncryptionKey.h"
#include "td/telegram/files/FileGenerateManager.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileLoaderUtils.h"
#include "td/telegram/files/FileLoadManager.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/files/FileUploadManager.h"
#include "td/telegram/Location.h"
#include "td/telegram/PhotoSizeSource.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Container.h"
#include "td/utils/Enumerator.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/optional.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/WaitFreeHashMap.h"
#include "td/utils/WaitFreeVector.h"

#include <atomic>
#include <map>
#include <memory>
#include <set>
#include <utility>

namespace td {

extern int VERBOSITY_NAME(update_file);

class FileData;
class FileDbInterface;

enum class FileLocationSource : int8 { None, FromUser, FromBinlog, FromDatabase, FromServer };

struct NewRemoteFileLocation {
  NewRemoteFileLocation() = default;
  NewRemoteFileLocation(RemoteFileLocation remote, FileLocationSource source);
  RemoteFileLocation partial_or_empty() const;
  unique_ptr<PartialRemoteFileLocation> partial;

  //TODO: use RemoteId
  // hardest part is to determine whether we should flush this location to db.
  // probably, will need some generation in RemoteInfo
  optional<FullRemoteFileLocation> full;
  bool is_full_alive{false};  // if false, then we may try to upload this file
  FileLocationSource full_source{FileLocationSource::None};
};

StringBuilder &operator<<(StringBuilder &string_builder, const NewRemoteFileLocation &location);

class FileNode {
 public:
  FileNode(LocalFileLocation local, NewRemoteFileLocation remote, unique_ptr<FullGenerateFileLocation> generate,
           int64 size, int64 expected_size, string remote_name, string url, DialogId owner_dialog_id,
           FileEncryptionKey key, FileId main_file_id, int8 main_file_id_priority)
      : local_(std::move(local))
      , remote_(std::move(remote))
      , generate_(std::move(generate))
      , size_(size)
      , expected_size_(expected_size)
      , remote_name_(std::move(remote_name))
      , url_(std::move(url))
      , owner_dialog_id_(owner_dialog_id)
      , encryption_key_(std::move(key))
      , main_file_id_(main_file_id)
      , main_file_id_priority_(main_file_id_priority) {
    init_ready_size();
    file_ids_.push_back(main_file_id);
  }
  void drop_local_location();
  void set_local_location(const LocalFileLocation &local, int64 prefix_offset, int64 ready_prefix_size);
  void set_new_remote_location(NewRemoteFileLocation remote);
  void delete_partial_remote_location();
  void set_partial_remote_location(PartialRemoteFileLocation remote);

  bool delete_file_reference(Slice file_reference);
  void set_generate_location(unique_ptr<FullGenerateFileLocation> &&generate);
  void set_size(int64 size);
  void set_expected_size(int64 expected_size);
  void set_remote_name(string remote_name);
  void set_url(string url);
  void set_owner_dialog_id(DialogId owner_id);
  void set_encryption_key(FileEncryptionKey key);
  void set_upload_pause(FileUploadId upload_pause);

  void set_download_priority(int8 priority);
  void set_upload_priority(int8 priority);
  void set_generate_priority(int8 download_priority, int8 upload_priority);

  void set_download_offset(int64 download_offset);
  void set_download_limit(int64 download_limit);
  void set_ignore_download_limit(bool ignore_download_limit);

  void on_changed();
  void on_info_changed();
  void on_pmc_changed();

  bool need_info_flush() const;
  bool need_pmc_flush() const;

  void on_pmc_flushed();
  void on_info_flushed();

  int64 get_download_limit() const;

  string suggested_path() const;

 private:
  friend class FileView;
  friend class FileManager;

  static constexpr char PERSISTENT_ID_VERSION_OLD = 2;
  static constexpr char PERSISTENT_ID_VERSION_GENERATED = 3;
  static constexpr char PERSISTENT_ID_VERSION = 4;

  LocalFileLocation local_;
  FileUploadManager::QueryId upload_id_ = 0;
  int64 download_offset_ = 0;
  int64 private_download_limit_ = 0;
  int64 local_ready_prefix_size_ = 0;  // PartialLocal only

  NewRemoteFileLocation remote_;

  FileDownloadManager::QueryId download_id_ = 0;

  unique_ptr<FullGenerateFileLocation> generate_;
  FileGenerateManager::QueryId generate_id_ = 0;

  int64 size_ = 0;
  int64 expected_size_ = 0;
  string remote_name_;
  string url_;
  DialogId owner_dialog_id_;
  FileEncryptionKey encryption_key_;
  FileDbId pmc_id_;
  vector<FileId> file_ids_;

  FileId main_file_id_;

  double last_successful_force_reupload_time_ = -1e10;

  FileUploadId upload_pause_;

  int8 upload_priority_ = 0;
  int8 download_priority_ = 0;
  int8 generate_priority_ = 0;

  int8 generate_download_priority_ = 0;
  int8 generate_upload_priority_ = 0;

  int8 main_file_id_priority_ = 0;

  bool is_download_offset_dirty_ = false;
  bool is_download_limit_dirty_ = false;

  bool get_by_hash_{false};
  bool can_search_locally_{true};
  bool need_reload_photo_{false};

  bool is_download_started_ = false;
  bool generate_was_update_ = false;

  bool need_load_from_pmc_ = false;

  bool pmc_changed_flag_{false};
  bool info_changed_flag_{false};

  bool upload_was_update_file_reference_{false};
  bool download_was_update_file_reference_{false};

  bool upload_prefer_small_{false};

  bool ignore_download_limit_{false};

  void init_ready_size();

  void recalc_ready_prefix_size(int64 prefix_offset, int64 ready_prefix_size);

  void update_effective_download_limit(int64 old_download_limit);

  string get_persistent_file_id() const;

  string get_unique_file_id() const;

  static string get_unique_id(const FullGenerateFileLocation &location);
  static string get_unique_id(const FullRemoteFileLocation &location);

  static string get_persistent_id(const FullGenerateFileLocation &location);
  static string get_persistent_id(const FullRemoteFileLocation &location);

  FileType get_type() const {
    if (local_.type() == LocalFileLocation::Type::Full) {
      return local_.full().file_type_;
    }
    if (remote_.full) {
      return remote_.full.value().file_type_;
    }
    if (generate_ != nullptr) {
      return generate_->file_type_;
    }
    return FileType::Temp;
  }

  int64 expected_size(bool may_guess = false) const;
  bool is_downloading() const;
  int64 downloaded_prefix(int64 offset) const;
  int64 local_prefix_size() const;
  int64 local_total_size() const;
  bool is_uploading() const;
  int64 remote_size() const;
  string path() const;
  bool can_delete() const;
};

class FileManager;

class FileNodePtr {
 public:
  FileNodePtr() = default;
  FileNodePtr(FileId file_id, FileManager *file_manager) : file_id_(file_id), file_manager_(file_manager) {
  }

  FileNode *operator->() const;
  FileNode &operator*() const;
  FileNode *get() const;
  FullRemoteFileLocation *get_remote() const;
  explicit operator bool() const noexcept;

 private:
  FileId file_id_;
  FileManager *file_manager_ = nullptr;
  FileNode *get_unsafe() const;
};

class ConstFileNodePtr {
 public:
  ConstFileNodePtr() = default;
  ConstFileNodePtr(FileNodePtr file_node_ptr) : file_node_ptr_(file_node_ptr) {
  }

  const FileNode *operator->() const {
    return file_node_ptr_.operator->();
  }
  const FileNode &operator*() const {
    return file_node_ptr_.operator*();
  }

  explicit operator bool() const noexcept {
    return static_cast<bool>(file_node_ptr_);
  }
  const FullRemoteFileLocation *get_remote() const {
    return file_node_ptr_.get_remote();
  }

  const FileNode *get() const {
    return file_node_ptr_.get();
  }

 private:
  FileNodePtr file_node_ptr_;
};

class FileView {
 public:
  FileView() = default;
  explicit FileView(ConstFileNodePtr node);

  bool empty() const;

  bool has_full_local_location() const;

  const FullLocalFileLocation *get_full_local_location() const;

  bool has_generate_location() const;

  const FullGenerateFileLocation *get_generate_location() const;

  bool has_full_remote_location() const;

  bool has_alive_remote_location() const;

  bool has_active_upload_remote_location() const;

  bool has_active_download_remote_location() const;

  const FullRemoteFileLocation *get_full_remote_location() const;

  const FullRemoteFileLocation *get_main_remote_location() const;

  bool has_url() const;

  const string *get_url() const;

  string remote_name() const;

  string suggested_path() const;

  DialogId owner_dialog_id() const;

  bool get_by_hash() const;

  FileId get_main_file_id() const {
    return node_->main_file_id_;
  }

  int64 size() const;
  int64 expected_size(bool may_guess = false) const;
  bool is_downloading() const;
  int64 download_offset() const;
  int64 downloaded_prefix(int64 offset) const;
  int64 local_prefix_size() const;
  int64 local_total_size() const;
  bool is_uploading() const;
  int64 remote_size() const;
  string path() const;

  int64 get_allocated_local_size() const;

  bool can_download_from_server() const;
  bool can_generate() const;
  bool can_delete() const;

  FileType get_type() const {
    return node_->get_type();
  }
  bool is_encrypted_secret() const {
    return get_type() == FileType::Encrypted;
  }
  bool is_encrypted_secure() const {
    return get_type() == FileType::SecureEncrypted;
  }
  bool is_secure() const {
    auto type = get_type();
    return type == FileType::SecureEncrypted || type == FileType::SecureDecrypted;
  }
  bool is_encrypted_any() const {
    auto type = get_type();
    return type == FileType::Encrypted || type == FileType::SecureEncrypted;
  }
  bool is_encrypted() const {
    auto type = get_type();
    return type == FileType::Encrypted || type == FileType::SecureEncrypted || type == FileType::SecureDecrypted;
  }
  const FileEncryptionKey &encryption_key() const {
    return node_->encryption_key_;
  }

  bool may_reload_photo() const {
    const auto *full_remote_location = get_full_remote_location();
    if (full_remote_location == nullptr) {
      return false;
    }
    if (!full_remote_location->is_photo()) {
      return false;
    }
    auto type = full_remote_location->get_source().get_type("may_reload_photo");
    return type != PhotoSizeSource::Type::Legacy && type != PhotoSizeSource::Type::FullLegacy &&
           type != PhotoSizeSource::Type::Thumbnail;
  }

  string get_unique_file_id() const {
    if (!empty()) {
      return node_->get_unique_file_id();
    }
    return string();
  }

 private:
  ConstFileNodePtr node_{};
};

class FileManager final : public Actor {
 public:
  class DownloadCallback {
   public:
    DownloadCallback() = default;
    DownloadCallback(const DownloadCallback &) = delete;
    DownloadCallback &operator=(const DownloadCallback &) = delete;
    virtual ~DownloadCallback() = default;
    virtual void on_progress(FileId file_id) {
    }

    virtual void on_download_ok(FileId file_id) = 0;
    virtual void on_download_error(FileId file_id, Status error) = 0;
  };

  class UploadCallback {
   public:
    UploadCallback() = default;
    UploadCallback(const UploadCallback &) = delete;
    UploadCallback &operator=(const UploadCallback &) = delete;
    virtual ~UploadCallback() = default;

    // After on_upload_ok all uploads of this file will be paused till merge, delete_partial_remote_location or
    // explicit upload request with the same file_id.
    // Also, upload may be resumed after some other merge.
    virtual void on_upload_ok(FileUploadId file_upload_id,
                              telegram_api::object_ptr<telegram_api::InputFile> input_file) = 0;

    virtual void on_upload_encrypted_ok(FileUploadId file_upload_id,
                                        telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file) {
      UNREACHABLE();
    }

    virtual void on_upload_secure_ok(FileUploadId file_upload_id,
                                     telegram_api::object_ptr<telegram_api::InputSecureFile> input_file) {
      UNREACHABLE();
    }

    virtual void on_upload_error(FileUploadId file_upload_id, Status error) = 0;
  };

  class Context {
   public:
    virtual bool need_notify_on_new_files() = 0;

    virtual void on_new_file(int64 size, int64 real_size, int32 cnt) = 0;

    virtual void on_file_updated(FileId size) = 0;

    virtual bool add_file_source(FileId file_id, FileSourceId file_source_id, const char *source) = 0;

    virtual bool remove_file_source(FileId file_id, FileSourceId file_source_id, const char *source) = 0;

    virtual void on_merge_files(FileId to_file_id, FileId from_file_id) = 0;

    virtual vector<FileSourceId> get_some_file_sources(FileId file_id) = 0;

    virtual void repair_file_reference(FileId file_id, Promise<Unit> promise) = 0;

    virtual void reload_photo(PhotoSizeSource source, Promise<Unit> promise) = 0;

    virtual bool keep_exact_remote_location() = 0;

    virtual ActorShared<> create_reference() = 0;

    Context() = default;
    Context(const Context &) = delete;
    Context &operator=(const Context &) = delete;
    virtual ~Context() = default;
  };

  explicit FileManager(unique_ptr<Context> context);
  FileManager(const FileManager &) = delete;
  FileManager &operator=(const FileManager &) = delete;
  FileManager(FileManager &&) = delete;
  FileManager &operator=(FileManager &&) = delete;
  ~FileManager() final;

  static Status check_priority(int32 priority);

  static bool is_remotely_generated_file(Slice conversion);

  static vector<int> get_missing_file_parts(const Status &error);

  void init_actor();

  FileId copy_file_id(FileId file_id, FileType file_type, DialogId owner_dialog_id, const char *source);

  void on_file_unlink(const FullLocalFileLocation &location);

  FileId register_empty(FileType type);

  Result<FileId> register_local(FullLocalFileLocation location, DialogId owner_dialog_id, int64 size,
                                bool get_by_hash = false, bool skip_file_size_checks = false,
                                FileId merge_file_id = FileId()) TD_WARN_UNUSED_RESULT;

  FileId register_remote(FullRemoteFileLocation location, FileLocationSource file_location_source,
                         DialogId owner_dialog_id, int64 size, int64 expected_size,
                         string remote_name) TD_WARN_UNUSED_RESULT;

  FileId register_generate(FileType file_type, string original_path, string conversion, DialogId owner_dialog_id,
                           int64 expected_size) TD_WARN_UNUSED_RESULT;

  Status merge(FileId x_file_id, FileId y_file_id, bool no_sync = false);

  void try_merge_documents(FileId new_file_id, FileId old_file_id);

  void add_file_source(FileId file_id, FileSourceId file_source_id, const char *source);

  void remove_file_source(FileId file_id, FileSourceId file_source_id, const char *source);

  void change_files_source(FileSourceId file_source_id, const vector<FileId> &old_file_ids,
                           const vector<FileId> &new_file_ids, const char *source);

  void on_file_reference_repaired(FileId file_id, FileSourceId file_source_id, Result<Unit> &&result,
                                  Promise<Unit> &&promise);

  bool set_encryption_key(FileId file_id, FileEncryptionKey key);
  bool set_content(FileId file_id, BufferSlice bytes);

  void check_local_location(FileId file_id, bool skip_file_size_checks);
  void check_local_location_async(FileId file_id, bool skip_file_size_checks);

  static int64 get_internal_download_id();

  void download_file(FileId file_id, int32 priority, int64 offset, int64 limit, bool synchronous,
                     Promise<td_api::object_ptr<td_api::file>> &&promise);

  void download(FileId file_id, int64 internal_download_id, std::shared_ptr<DownloadCallback> callback,
                int32 new_priority, int64 offset, int64 limit,
                Promise<td_api::object_ptr<td_api::file>> promise = Promise<td_api::object_ptr<td_api::file>>());

  void cancel_download(FileId file_id, int64 internal_download_id, bool only_if_pending);

  static int64 get_internal_upload_id();

  void upload(FileUploadId file_upload_id, std::shared_ptr<UploadCallback> callback, int32 new_priority,
              uint64 upload_order);

  void resume_upload(FileUploadId file_upload_id, vector<int> bad_parts, std::shared_ptr<UploadCallback> callback,
                     int32 new_priority, uint64 upload_order, bool force = false, bool prefer_small = false);

  void cancel_upload(FileUploadId file_upload_id);

  bool delete_partial_remote_location(FileUploadId file_upload_id);

  void delete_partial_remote_location_if_needed(FileUploadId file_upload_id, const Status &error);

  void delete_file_reference(FileId file_id, Slice file_reference);

  void get_content(FileId file_id, Promise<BufferSlice> promise);

  void preliminary_upload_file(const td_api::object_ptr<td_api::InputFile> &input_file, FileType file_type,
                               int32 priority, Promise<td_api::object_ptr<td_api::file>> &&promise);

  Result<string> get_suggested_file_name(FileId file_id, const string &directory);

  void read_file_part(FileId file_id, int64 offset, int64 count, int left_tries,
                      Promise<td_api::object_ptr<td_api::filePart>> promise);

  void delete_file(FileId file_id, Promise<Unit> promise, const char *source);

  void external_file_generate_write_part(int64 generation_id, int64 offset, string data, Promise<> promise);
  void external_file_generate_progress(int64 generation_id, int64 expected_size, int64 local_prefix_size,
                                       Promise<> promise);
  void external_file_generate_finish(int64 generation_id, Status status, Promise<> promise);

  Result<FileId> from_persistent_id(CSlice persistent_id, FileType file_type) TD_WARN_UNUSED_RESULT;
  FileView get_file_view(FileId file_id) const;
  FileView get_sync_file_view(FileId file_id);
  td_api::object_ptr<td_api::file> get_file_object(FileId file_id);
  vector<int32> get_file_ids_object(const vector<FileId> &file_ids);

  Result<FileId> get_input_thumbnail_file_id(const tl_object_ptr<td_api::InputFile> &thumbnail_input_file,
                                             DialogId owner_dialog_id, bool is_encrypted) TD_WARN_UNUSED_RESULT;
  Result<FileId> get_input_file_id(FileType type, const tl_object_ptr<td_api::InputFile> &file,
                                   DialogId owner_dialog_id, bool allow_zero, bool is_encrypted,
                                   bool get_by_hash = false, bool is_secure = false,
                                   bool force_reuse = false) TD_WARN_UNUSED_RESULT;

  Result<FileId> get_map_thumbnail_file_id(Location location, int32 zoom, int32 width, int32 height, int32 scale,
                                           DialogId owner_dialog_id) TD_WARN_UNUSED_RESULT;

  Result<FileId> get_audio_thumbnail_file_id(string title, string performer, bool is_small,
                                             DialogId owner_dialog_id) TD_WARN_UNUSED_RESULT;

  FileType guess_file_type(const tl_object_ptr<td_api::InputFile> &file);

  vector<tl_object_ptr<telegram_api::InputDocument>> get_input_documents(const vector<FileId> &file_ids);

  static bool extract_was_uploaded(const telegram_api::object_ptr<telegram_api::InputMedia> &input_media);

  static bool extract_was_thumbnail_uploaded(const telegram_api::object_ptr<telegram_api::InputMedia> &input_media);

  static string extract_file_reference(const telegram_api::object_ptr<telegram_api::InputMedia> &input_media);

  static vector<string> extract_file_references(const telegram_api::object_ptr<telegram_api::InputMedia> &input_media);

  static string extract_cover_file_reference(const telegram_api::object_ptr<telegram_api::InputMedia> &input_media);

  static vector<string> extract_cover_file_references(
      const telegram_api::object_ptr<telegram_api::InputMedia> &input_media);

  static string extract_file_reference(const telegram_api::object_ptr<telegram_api::InputDocument> &input_document);

  static string extract_file_reference(const telegram_api::object_ptr<telegram_api::InputPhoto> &input_photo);

  static bool extract_was_uploaded(const telegram_api::object_ptr<telegram_api::InputChatPhoto> &input_chat_photo);

  static string extract_file_reference(const telegram_api::object_ptr<telegram_api::InputChatPhoto> &input_chat_photo);

  template <class StorerT>
  void store_file(FileId file_id, StorerT &storer, int32 ttl = 5) const;

  template <class ParserT>
  FileId parse_file(ParserT &parser);

 private:
  static constexpr bool STORE_FILE_INFO = false;

  class FileDownloadManagerCallback final : public FileDownloadManager::Callback {
   public:
    explicit FileDownloadManagerCallback(ActorId<FileManager> actor_id) : actor_id_(std::move(actor_id)) {
    }

   private:
    ActorId<FileManager> actor_id_;

    void on_start_download(FileDownloadManager::QueryId query_id) final {
      send_closure(actor_id_, &FileManager::on_start_download, query_id);
    }

    void on_partial_download(FileDownloadManager::QueryId query_id, PartialLocalFileLocation partial_local,
                             int64 size) final {
      send_closure(actor_id_, &FileManager::on_partial_download, query_id, std::move(partial_local), size);
    }

    void on_download_ok(FileDownloadManager::QueryId query_id, FullLocalFileLocation local, int64 size,
                        bool is_new) final {
      send_closure(actor_id_, &FileManager::on_download_ok, query_id, std::move(local), size, is_new);
    }

    void on_error(FileDownloadManager::QueryId query_id, Status status) final {
      send_closure(actor_id_, &FileManager::on_download_error, query_id, std::move(status));
    }
  };
  class FileUploadManagerCallback final : public FileUploadManager::Callback {
   public:
    explicit FileUploadManagerCallback(ActorId<FileManager> actor_id) : actor_id_(std::move(actor_id)) {
    }

   private:
    ActorId<FileManager> actor_id_;

    void on_partial_upload(FileUploadManager::QueryId query_id, PartialRemoteFileLocation partial_remote) final {
      send_closure(actor_id_, &FileManager::on_partial_upload, query_id, std::move(partial_remote));
    }

    void on_hash(FileUploadManager::QueryId query_id, string hash) final {
      send_closure(actor_id_, &FileManager::on_hash, query_id, std::move(hash));
    }

    void on_upload_ok(FileUploadManager::QueryId query_id, FileType file_type, PartialRemoteFileLocation remote) final {
      send_closure(actor_id_, &FileManager::on_upload_ok, query_id, file_type, std::move(remote));
    }

    void on_upload_full_ok(FileUploadManager::QueryId query_id, FullRemoteFileLocation remote) final {
      send_closure(actor_id_, &FileManager::on_upload_full_ok, query_id, std::move(remote));
    }

    void on_error(FileUploadManager::QueryId query_id, Status status) final {
      send_closure(actor_id_, &FileManager::on_upload_error, query_id, std::move(status));
    }
  };

  class PreliminaryUploadFileCallback;

  Result<FileId> check_input_file_id(FileType type, Result<FileId> result, bool is_encrypted, bool allow_zero,
                                     bool is_secure) TD_WARN_UNUSED_RESULT;

  FileId do_register_generate(unique_ptr<FullGenerateFileLocation> generate, DialogId owner_dialog_id,
                              int64 expected_size, string url) TD_WARN_UNUSED_RESULT;

  FileId register_url(string url, FileType file_type, DialogId owner_dialog_id);

  Result<FileId> register_file(FileData &&data, FileLocationSource file_location_source, const char *source);

  using FileNodeId = int32;

  struct DownloadQuery {
    FileId file_id_;
    enum class Type : int32 {
      DownloadWaitFileReference,
      DownloadReloadDialog,
      Download,
      SetContent,
    } type_;
  };
  friend StringBuilder &operator<<(StringBuilder &string_builder, DownloadQuery::Type type);

  struct GenerateQuery {
    FileId file_id_;
  };

  struct UploadQuery {
    FileId file_id_;
    enum class Type : int32 {
      UploadByHash,
      UploadWaitFileReference,
      Upload,
    } type_;
  };
  friend StringBuilder &operator<<(StringBuilder &string_builder, UploadQuery::Type type);

  enum class FileInfoType : int32 { Local, Generate, Remote };

  class FileInfo {
    bool is_info_changed_ = false;
    bool is_database_changed_ = false;

   protected:
    void on_info_changed() {
      is_info_changed_ = true;
    }

    void on_database_changed() {
      is_database_changed_ = true;
    }

    void on_changed() {
      is_info_changed_ = true;
      is_database_changed_ = true;
    }

   public:
    FileInfo() = default;
    FileInfo(const FileInfo &) = delete;
    FileInfo &operator=(const FileInfo &) = delete;
    FileInfo(FileInfo &&) = delete;
    FileInfo &operator=(FileInfo &&) = delete;
    virtual ~FileInfo() = default;

    bool need_info_flush() {
      auto result = is_info_changed_;
      is_info_changed_ = false;
      return result;
    }

    bool need_database_flush() {
      auto result = is_database_changed_;
      is_database_changed_ = false;
      return result;
    }

    virtual FileInfoType get_file_info_type() const = 0;

    virtual FileType get_file_type() const = 0;

    virtual int64 get_local_size() const = 0;

    virtual int64 get_remote_size() const = 0;

    virtual int64 get_size() const = 0;

    virtual int64 get_expected_size(bool may_guess) const = 0;

    virtual const FullLocalFileLocation *get_local_location() const = 0;

    virtual const FullGenerateFileLocation *get_generate_location() const = 0;

    virtual const FullRemoteFileLocation *get_remote_location() const = 0;

    virtual const string *get_url() const = 0;

    virtual string get_path() const = 0;

    virtual string get_suggested_path() const = 0;

    virtual string get_remote_name() const = 0;

    virtual string get_persistent_file_id() const = 0;

    virtual string get_unique_file_id() const = 0;

    virtual bool can_be_deleted() const = 0;

    virtual void set_size(int64 size) = 0;

    virtual void set_expected_size(int64 expected_size) = 0;

    virtual void delete_file_reference(Slice file_reference) = 0;
  };

  class FileInfoLocal;
  class FileInfoGenerate;
  class FileInfoRemote;

  struct FileIdInfo {
    FileNodeId node_id_{0};
    unique_ptr<FileInfo> file_info_;
    bool pin_flag_{false};
  };

  struct UserFileDownloadInfo {
    int64 offset_ = -1;
    int64 limit_ = -1;
    vector<Promise<td_api::object_ptr<td_api::file>>> promises_;
  };
  FlatHashMap<FileId, UserFileDownloadInfo, FileIdHash> pending_user_file_downloads_;

  class UserDownloadFileCallback;

  std::shared_ptr<UserDownloadFileCallback> user_download_file_callback_;

  struct FileDownloadInfo {
    int8 download_priority_ = 0;
    std::shared_ptr<DownloadCallback> download_callback_;
  };
  struct FileDownloadRequests {
    int8 user_download_priority_ = 0;
    int64 user_offset_ = 0;
    int64 user_limit_ = 0;
    FlatHashMap<int64, FileDownloadInfo> internal_downloads_;
  };
  FlatHashMap<FileId, FileDownloadRequests, FileIdHash> file_download_requests_;

  struct FileUploadInfo {
    int8 upload_priority_{0};
    uint64 upload_order_{0};
    std::shared_ptr<UploadCallback> upload_callback_;
  };
  struct FileUploadRequests {
    int8 user_upload_priority_{0};
    FlatHashMap<int64, FileUploadInfo> internal_uploads_;
  };
  FlatHashMap<FileId, FileUploadRequests, FileIdHash> file_upload_requests_;

  class ForceUploadActor;

  ActorShared<> parent_;
  unique_ptr<Context> context_;
  std::shared_ptr<FileDbInterface> file_db_;

  FileIdInfo *get_file_id_info(FileId file_id);

  struct RemoteInfo {
    // mutable is set to to enable changing of access hash
    mutable FullRemoteFileLocation remote_;
    mutable FileLocationSource file_location_source_;
    FileId file_id_;
    bool operator==(const RemoteInfo &other) const {
      return remote_ == other.remote_;
    }
    bool operator<(const RemoteInfo &other) const {
      return remote_ < other.remote_;
    }
  };
  Enumerator<RemoteInfo> remote_location_info_;

  WaitFreeHashMap<string, FileId> file_hash_to_file_id_;

  std::map<FullRemoteFileLocation, FileId> remote_location_to_file_id_;
  std::map<FullLocalFileLocation, FileId> local_location_to_file_id_;
  std::map<FullGenerateFileLocation, FileId> generate_location_to_file_id_;

  WaitFreeVector<unique_ptr<FileIdInfo>> file_id_info_;
  WaitFreeVector<int32> empty_file_ids_;
  WaitFreeVector<unique_ptr<FileNode>> file_nodes_;
  ActorOwn<FileDownloadManager> file_download_manager_;
  ActorOwn<FileLoadManager> file_load_manager_;
  ActorOwn<FileUploadManager> file_upload_manager_;
  ActorOwn<FileGenerateManager> file_generate_manager_;

  Container<DownloadQuery> download_queries_;
  Container<GenerateQuery> generate_queries_;
  Container<UploadQuery> upload_queries_;

  static std::atomic<int64> internal_load_id_;

  bool is_closed_ = false;

  std::set<std::string> bad_paths_;

  int file_node_size_warning_exp_ = 10;

  FileId next_file_id();
  FileNodeId next_file_node_id();
  int32 next_pmc_file_id();
  bool try_forget_file_id(FileId file_id);

  void on_user_file_download_finished(FileId file_id);

  void download_impl(FileId file_id, int64 internal_download_id, std::shared_ptr<DownloadCallback> callback,
                     int32 new_priority, int64 offset, int64 limit, Status check_status,
                     Promise<td_api::object_ptr<td_api::file>> promise);

  std::shared_ptr<DownloadCallback> extract_download_callback(FileId file_id, int64 internal_download_id);

  void finish_downloads(FileId file_id, const Status &status);

  std::shared_ptr<UploadCallback> extract_upload_callback(FileUploadId file_upload_id);

  void finish_uploads(FileId file_id, const Status &status);

  Status check_local_location(FileNodePtr node, bool skip_file_size_checks);
  void on_failed_check_local_location(FileNodePtr node);
  void check_local_location_async(FileNodePtr node, bool skip_file_size_checks, Promise<Unit> promise);
  void on_check_full_local_location(FileId file_id, LocalFileLocation checked_location,
                                    Result<FullLocalLocationInfo> r_info, Promise<Unit> promise);
  void on_check_partial_local_location(FileId file_id, LocalFileLocation checked_location, Result<Unit> result,
                                       Promise<Unit> promise);
  void recheck_full_local_location(FullLocalLocationInfo location_info, bool skip_file_size_checks);
  void on_recheck_full_local_location(FullLocalFileLocation checked_location, Result<FullLocalLocationInfo> r_info);

  static bool try_fix_partial_local_location(FileNodePtr node);
  void try_flush_node_full(FileNodePtr node, bool new_remote, bool new_local, bool new_generate, FileDbId other_pmc_id);
  void try_flush_node(FileNodePtr node, const char *source);
  void try_flush_node_info(FileNodePtr node, const char *source);
  void try_flush_node_pmc(FileNodePtr node, const char *source);
  void clear_from_pmc(FileNodePtr node);
  void flush_to_pmc(FileNodePtr node, bool new_remote, bool new_local, bool new_generate, const char *source);
  void load_from_pmc(FileNodePtr node, bool new_remote, bool new_local, bool new_generate);

  Result<FileId> from_persistent_id_generated(Slice binary, FileType file_type);
  Result<FileId> from_persistent_id_v2(Slice binary, FileType file_type);
  Result<FileId> from_persistent_id_v3(Slice binary, FileType file_type);
  Result<FileId> from_persistent_id_v23(Slice binary, FileType file_type, int32 version);

  static string fix_file_extension(Slice file_name, Slice file_type, Slice file_extension);
  string get_file_name(FileType file_type, Slice path);

  ConstFileNodePtr get_file_node(FileId file_id) const {
    return ConstFileNodePtr{FileNodePtr{file_id, const_cast<FileManager *>(this)}};
  }
  FileNodePtr get_file_node(FileId file_id) {
    return FileNodePtr{file_id, this};
  }
  FileNode *get_file_node_raw(FileId file_id, FileNodeId *file_node_id = nullptr);

  FileNodePtr get_sync_file_node(FileId file_id);

  void on_force_reupload_success(FileId file_id);

  void do_cancel_download(FileNodePtr node);
  void do_cancel_upload(FileNodePtr node);
  void do_cancel_generate(FileNodePtr node);
  void run_upload(FileNodePtr node, vector<int> bad_parts);
  void run_download(FileNodePtr node, bool force_update_priority);
  void run_generate(FileNodePtr node);

  void on_start_download(FileDownloadManager::QueryId query_id);
  void on_partial_download(FileDownloadManager::QueryId query_id, PartialLocalFileLocation partial_local, int64 size);
  void on_download_ok(FileDownloadManager::QueryId query_id, FullLocalFileLocation local, int64 size, bool is_new);
  void on_download_error(FileDownloadManager::QueryId query_id, Status status);
  void on_download_error_impl(FileNodePtr node, DownloadQuery::Type type, bool was_active, Status status);

  void on_hash(FileUploadManager::QueryId query_id, string hash);
  void on_partial_upload(FileUploadManager::QueryId query_id, PartialRemoteFileLocation partial_remote);
  void on_upload_ok(FileUploadManager::QueryId query_id, FileType file_type, PartialRemoteFileLocation partial_remote);
  void on_upload_full_ok(FileUploadManager::QueryId query_id, FullRemoteFileLocation remote);
  void on_upload_error(FileUploadManager::QueryId query_id, Status status);
  void on_upload_error_impl(FileNodePtr node, UploadQuery::Type type, bool was_active, Status status);

  void on_partial_generate(FileGenerateManager::QueryId, PartialLocalFileLocation partial_local, int64 expected_size);
  void on_generate_ok(FileGenerateManager::QueryId, FullLocalFileLocation local);
  void on_generate_error(FileGenerateManager::QueryId query_id, Status status);
  void on_generate_error_impl(FileNodePtr node, bool was_active, Status status);

  void on_file_load_error(FileNodePtr node, Status status);

  std::pair<DownloadQuery, bool> finish_download_query(FileDownloadManager::QueryId query_id);

  std::pair<GenerateQuery, bool> finish_generate_query(FileGenerateManager::QueryId query_id);

  std::pair<UploadQuery, bool> finish_upload_query(FileUploadManager::QueryId query_id);

  FullRemoteFileLocation *get_remote(int32 key);

  FlatHashSet<FileId, FileIdHash> get_main_file_ids(const vector<FileId> &file_ids);

  void hangup() final;
  void tear_down() final;

  friend class FileNodePtr;
};

}  // namespace td
