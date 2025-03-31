//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileUploadManager.h"

#include "td/telegram/Global.h"

#include "td/utils/common.h"

namespace td {

FileUploadManager::Callback::~Callback() = default;

FileUploadManager::FileUploadManager(unique_ptr<Callback> callback, ActorShared<> parent)
    : callback_(std::move(callback)), parent_(std::move(parent)) {
}

void FileUploadManager::start_up() {
  constexpr int64 MAX_UPLOAD_RESOURCE_LIMIT = 4 << 20;
  upload_resource_manager_ = create_actor<ResourceManager>(
      "UploadResourceManager", MAX_UPLOAD_RESOURCE_LIMIT,
      !G()->keep_media_order() ? ResourceManager::Mode::Greedy : ResourceManager::Mode::Baseline);
}

void FileUploadManager::upload(QueryId query_id, const LocalFileLocation &local_location,
                               const RemoteFileLocation &remote_location, int64 expected_size,
                               const FileEncryptionKey &encryption_key, int8 priority, vector<int> bad_parts) {
  if (stop_flag_) {
    return;
  }
  NodeId node_id = nodes_container_.create(Node());
  Node *node = nodes_container_.get(node_id);
  CHECK(node);
  node->query_id_ = query_id;
  auto callback = make_unique<FileUploaderCallback>(actor_shared(this, node_id));
  node->uploader_ = create_actor<FileUploader>("Uploader", local_location, remote_location, expected_size,
                                               encryption_key, std::move(bad_parts), std::move(callback));
  send_closure(upload_resource_manager_, &ResourceManager::register_worker,
               ActorShared<FileLoaderActor>(node->uploader_.get(), static_cast<uint64>(-1)), priority);
  bool is_inserted = query_id_to_node_id_.emplace(query_id, node_id).second;
  CHECK(is_inserted);
}

void FileUploadManager::upload_by_hash(QueryId query_id, const FullLocalFileLocation &local_location, int64 size,
                                       int8 priority) {
  if (stop_flag_) {
    return;
  }
  NodeId node_id = nodes_container_.create(Node());
  Node *node = nodes_container_.get(node_id);
  CHECK(node);
  node->query_id_ = query_id;
  auto callback = make_unique<FileHashUploaderCallback>(actor_shared(this, node_id));
  node->hash_uploader_ = create_actor<FileHashUploader>("HashUploader", local_location, size, std::move(callback));
  send_closure(upload_resource_manager_, &ResourceManager::register_worker,
               ActorShared<FileLoaderActor>(node->hash_uploader_.get(), static_cast<uint64>(-1)), priority);
  bool is_inserted = query_id_to_node_id_.emplace(query_id, node_id).second;
  CHECK(is_inserted);
}

void FileUploadManager::update_priority(QueryId query_id, int8 priority) {
  if (stop_flag_) {
    return;
  }
  auto it = query_id_to_node_id_.find(query_id);
  if (it == query_id_to_node_id_.end()) {
    return;
  }
  auto node = nodes_container_.get(it->second);
  if (node == nullptr) {
    return;
  }
  if (!node->uploader_.empty()) {
    send_closure(node->uploader_, &FileLoaderActor::update_priority, priority);
  } else {
    send_closure(node->hash_uploader_, &FileLoaderActor::update_priority, priority);
  }
}

void FileUploadManager::cancel(QueryId query_id) {
  if (stop_flag_) {
    return;
  }
  auto it = query_id_to_node_id_.find(query_id);
  if (it == query_id_to_node_id_.end()) {
    return;
  }
  on_error_impl(it->second, Status::Error(-1, "Canceled"));
}

void FileUploadManager::update_local_file_location(QueryId query_id, const LocalFileLocation &local) {
  if (stop_flag_) {
    return;
  }
  auto it = query_id_to_node_id_.find(query_id);
  if (it == query_id_to_node_id_.end()) {
    return;
  }
  auto node = nodes_container_.get(it->second);
  if (node == nullptr || node->uploader_.empty()) {
    return;
  }
  send_closure(node->uploader_, &FileUploader::update_local_file_location, local);
}

void FileUploadManager::hangup() {
  nodes_container_.for_each([](auto query_id, auto &node) {
    node.uploader_.reset();
    node.hash_uploader_.reset();
  });
  upload_resource_manager_.reset();
  stop_flag_ = true;
  try_stop();
}

void FileUploadManager::on_hash(string hash) {
  auto node_id = get_link_token();
  auto node = nodes_container_.get(node_id);
  if (node == nullptr) {
    return;
  }
  if (!stop_flag_) {
    callback_->on_hash(node->query_id_, std::move(hash));
  }
}

void FileUploadManager::on_partial_upload(PartialRemoteFileLocation partial_remote) {
  auto node_id = get_link_token();
  auto node = nodes_container_.get(node_id);
  if (node == nullptr) {
    return;
  }
  if (!stop_flag_) {
    callback_->on_partial_upload(node->query_id_, std::move(partial_remote));
  }
}

void FileUploadManager::on_ok_upload(FileType file_type, PartialRemoteFileLocation remote) {
  auto node_id = get_link_token();
  auto node = nodes_container_.get(node_id);
  if (node == nullptr) {
    return;
  }
  if (!stop_flag_) {
    callback_->on_upload_ok(node->query_id_, file_type, std::move(remote));
  }
  close_node(node_id);
}

void FileUploadManager::on_ok_upload_full(FullRemoteFileLocation remote) {
  auto node_id = get_link_token();
  auto node = nodes_container_.get(node_id);
  if (node == nullptr) {
    return;
  }
  if (!stop_flag_) {
    callback_->on_upload_full_ok(node->query_id_, std::move(remote));
  }
  close_node(node_id);
}

void FileUploadManager::on_error(Status status) {
  auto node_id = get_link_token();
  on_error_impl(node_id, std::move(status));
}

void FileUploadManager::on_error_impl(NodeId node_id, Status status) {
  auto node = nodes_container_.get(node_id);
  if (node == nullptr) {
    status.ignore();
    return;
  }
  if (!stop_flag_) {
    callback_->on_error(node->query_id_, std::move(status));
  }
  close_node(node_id);
}

void FileUploadManager::hangup_shared() {
  auto node_id = get_link_token();
  on_error_impl(node_id, Status::Error(-1, "Canceled"));
}

void FileUploadManager::try_stop() {
  if (stop_flag_ && nodes_container_.empty()) {
    stop();
  }
}

void FileUploadManager::close_node(NodeId node_id) {
  auto node = nodes_container_.get(node_id);
  CHECK(node);
  query_id_to_node_id_.erase(node->query_id_);
  nodes_container_.erase(node_id);
  try_stop();
}

}  // namespace td
