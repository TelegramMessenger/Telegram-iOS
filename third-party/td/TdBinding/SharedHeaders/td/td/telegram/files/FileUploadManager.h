//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileEncryptionKey.h"
#include "td/telegram/files/FileHashUploader.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/files/FileUploader.h"
#include "td/telegram/files/ResourceManager.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Container.h"
#include "td/utils/Status.h"

#include <map>

namespace td {

class FileUploadManager final : public Actor {
 public:
  using QueryId = uint64;

  class Callback {
   public:
    virtual ~Callback();
    virtual void on_partial_upload(QueryId query_id, PartialRemoteFileLocation partial_remote) = 0;
    virtual void on_hash(QueryId query_id, string hash) = 0;
    virtual void on_upload_ok(QueryId query_id, FileType file_type, PartialRemoteFileLocation remote) = 0;
    virtual void on_upload_full_ok(QueryId query_id, FullRemoteFileLocation remote) = 0;
    virtual void on_error(QueryId query_id, Status status) = 0;
  };

  FileUploadManager(unique_ptr<Callback> callback, ActorShared<> parent);

  void upload(QueryId query_id, const LocalFileLocation &local_location, const RemoteFileLocation &remote_location,
              int64 expected_size, const FileEncryptionKey &encryption_key, int8 priority, vector<int> bad_parts);

  void upload_by_hash(QueryId query_id, const FullLocalFileLocation &local_location, int64 size, int8 priority);

  void update_priority(QueryId query_id, int8 priority);

  void cancel(QueryId query_id);

  void update_local_file_location(QueryId query_id, const LocalFileLocation &local);

 private:
  struct Node {
    QueryId query_id_;
    ActorOwn<FileUploader> uploader_;
    ActorOwn<FileHashUploader> hash_uploader_;
  };
  using NodeId = uint64;

  ActorOwn<ResourceManager> upload_resource_manager_;

  Container<Node> nodes_container_;
  unique_ptr<Callback> callback_;
  ActorShared<> parent_;
  std::map<QueryId, NodeId> query_id_to_node_id_;
  bool stop_flag_ = false;

  void start_up() final;
  void hangup() final;
  void hangup_shared() final;

  void close_node(NodeId node_id);

  void try_stop();

  void on_partial_upload(PartialRemoteFileLocation partial_remote);
  void on_hash(string hash);
  void on_ok_upload(FileType file_type, PartialRemoteFileLocation remote);
  void on_ok_upload_full(FullRemoteFileLocation remote);
  void on_error(Status status);
  void on_error_impl(NodeId node_id, Status status);

  class FileUploaderCallback final : public FileUploader::Callback {
   public:
    explicit FileUploaderCallback(ActorShared<FileUploadManager> actor_id) : actor_id_(std::move(actor_id)) {
    }

   private:
    ActorShared<FileUploadManager> actor_id_;

    void on_hash(string hash) final {
      send_closure(actor_id_, &FileUploadManager::on_hash, std::move(hash));
    }
    void on_partial_upload(PartialRemoteFileLocation partial_remote) final {
      send_closure(actor_id_, &FileUploadManager::on_partial_upload, std::move(partial_remote));
    }
    void on_ok(FileType file_type, PartialRemoteFileLocation partial_remote) final {
      send_closure(std::move(actor_id_), &FileUploadManager::on_ok_upload, file_type, std::move(partial_remote));
    }
    void on_error(Status status) final {
      send_closure(std::move(actor_id_), &FileUploadManager::on_error, std::move(status));
    }
  };

  class FileHashUploaderCallback final : public FileHashUploader::Callback {
   public:
    explicit FileHashUploaderCallback(ActorShared<FileUploadManager> actor_id) : actor_id_(std::move(actor_id)) {
    }

   private:
    ActorShared<FileUploadManager> actor_id_;

    void on_ok(FullRemoteFileLocation remote) final {
      send_closure(std::move(actor_id_), &FileUploadManager::on_ok_upload_full, std::move(remote));
    }
    void on_error(Status status) final {
      send_closure(std::move(actor_id_), &FileUploadManager::on_error, std::move(status));
    }
  };
};

}  // namespace td
