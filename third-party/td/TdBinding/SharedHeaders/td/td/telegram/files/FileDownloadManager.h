//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileDownloader.h"
#include "td/telegram/files/FileEncryptionKey.h"
#include "td/telegram/files/FileFromBytes.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/files/ResourceManager.h"
#include "td/telegram/net/DcId.h"

#include "td/actor/actor.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Container.h"
#include "td/utils/Status.h"

#include <map>

namespace td {

class FileDownloadManager final : public Actor {
 public:
  using QueryId = uint64;

  class Callback {
   public:
    virtual ~Callback();
    virtual void on_start_download(QueryId query_id) = 0;
    virtual void on_partial_download(QueryId query_id, PartialLocalFileLocation partial_local, int64 size) = 0;
    virtual void on_download_ok(QueryId query_id, FullLocalFileLocation local, int64 size, bool is_new) = 0;
    virtual void on_error(QueryId query_id, Status status) = 0;
  };

  FileDownloadManager(unique_ptr<Callback> callback, ActorShared<> parent);

  void download(QueryId query_id, const FullRemoteFileLocation &remote_location, const LocalFileLocation &local,
                int64 size, string name, const FileEncryptionKey &encryption_key, bool need_search_file, int64 offset,
                int64 limit, int8 priority);

  void update_priority(QueryId query_id, int8 priority);

  void from_bytes(QueryId query_id, FileType type, BufferSlice bytes, string name);

  void cancel(QueryId query_id);

  void update_downloaded_part(QueryId query_id, int64 offset, int64 limit);

 private:
  struct Node {
    QueryId query_id_;
    ActorOwn<FileDownloader> downloader_;
    ActorOwn<FileFromBytes> from_bytes_;
  };
  using NodeId = uint64;

  std::map<DcId, ActorOwn<ResourceManager>> download_resource_manager_map_;
  std::map<DcId, ActorOwn<ResourceManager>> download_small_resource_manager_map_;

  Container<Node> nodes_container_;
  unique_ptr<Callback> callback_;
  ActorShared<> parent_;
  std::map<QueryId, NodeId> query_id_to_node_id_;
  int64 max_download_resource_limit_ = 1 << 21;
  bool stop_flag_ = false;

  void start_up() final;
  void hangup() final;
  void hangup_shared() final;

  void close_node(NodeId node_id);

  void try_stop();

  ActorOwn<ResourceManager> &get_download_resource_manager(bool is_small, DcId dc_id);

  void on_start_download();
  void on_partial_download(PartialLocalFileLocation partial_local, int64 size);
  void on_ok_download(FullLocalFileLocation local, int64 size, bool is_new);
  void on_error(Status status);
  void on_error_impl(NodeId node_id, Status status);

  class FileDownloaderCallback final : public FileDownloader::Callback {
   public:
    explicit FileDownloaderCallback(ActorShared<FileDownloadManager> actor_id) : actor_id_(std::move(actor_id)) {
    }

   private:
    ActorShared<FileDownloadManager> actor_id_;

    void on_start_download() final {
      send_closure(actor_id_, &FileDownloadManager::on_start_download);
    }
    void on_partial_download(PartialLocalFileLocation partial_local, int64 size) final {
      send_closure(actor_id_, &FileDownloadManager::on_partial_download, std::move(partial_local), size);
    }
    void on_ok(FullLocalFileLocation full_local, int64 size, bool is_new) final {
      send_closure(std::move(actor_id_), &FileDownloadManager::on_ok_download, std::move(full_local), size, is_new);
    }
    void on_error(Status status) final {
      send_closure(std::move(actor_id_), &FileDownloadManager::on_error, std::move(status));
    }
  };

  class FileFromBytesCallback final : public FileFromBytes::Callback {
   public:
    explicit FileFromBytesCallback(ActorShared<FileDownloadManager> actor_id) : actor_id_(std::move(actor_id)) {
    }

   private:
    ActorShared<FileDownloadManager> actor_id_;

    void on_ok(const FullLocalFileLocation &full_local, int64 size) final {
      send_closure(std::move(actor_id_), &FileDownloadManager::on_ok_download, full_local, size, true);
    }
    void on_error(Status status) final {
      send_closure(std::move(actor_id_), &FileDownloadManager::on_error, std::move(status));
    }
  };
};

}  // namespace td
