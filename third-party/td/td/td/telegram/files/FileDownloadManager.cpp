//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileDownloadManager.h"

#include "td/telegram/Global.h"
#include "td/telegram/net/NetQueryDispatcher.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/SliceBuilder.h"

namespace td {

FileDownloadManager::Callback::~Callback() = default;

FileDownloadManager::FileDownloadManager(unique_ptr<Callback> callback, ActorShared<> parent)
    : callback_(std::move(callback)), parent_(std::move(parent)) {
}

void FileDownloadManager::start_up() {
  if (G()->get_option_boolean("is_premium")) {
    max_download_resource_limit_ *= 8;
  }
}

ActorOwn<ResourceManager> &FileDownloadManager::get_download_resource_manager(bool is_small, DcId dc_id) {
  auto &actor = is_small ? download_small_resource_manager_map_[dc_id] : download_resource_manager_map_[dc_id];
  if (actor.empty()) {
    actor = create_actor<ResourceManager>(
        PSLICE() << "DownloadResourceManager " << tag("is_small", is_small) << tag("dc_id", dc_id),
        max_download_resource_limit_, ResourceManager::Mode::Baseline);
  }
  return actor;
}

void FileDownloadManager::download(QueryId query_id, const FullRemoteFileLocation &remote_location,
                                   const LocalFileLocation &local, int64 size, string name,
                                   const FileEncryptionKey &encryption_key, bool need_search_file, int64 offset,
                                   int64 limit, int8 priority) {
  if (stop_flag_) {
    return;
  }
  NodeId node_id = nodes_container_.create(Node());
  Node *node = nodes_container_.get(node_id);
  CHECK(node);
  node->query_id_ = query_id;
  auto callback = make_unique<FileDownloaderCallback>(actor_shared(this, node_id));
  bool is_small = size < 20 * 1024;
  node->downloader_ =
      create_actor<FileDownloader>("Downloader", remote_location, local, size, std::move(name), encryption_key,
                                   is_small, need_search_file, offset, limit, std::move(callback));
  DcId dc_id = remote_location.is_web() ? G()->get_webfile_dc_id() : remote_location.get_dc_id();
  auto &resource_manager = get_download_resource_manager(is_small, dc_id);
  send_closure(resource_manager, &ResourceManager::register_worker,
               ActorShared<FileLoaderActor>(node->downloader_.get(), static_cast<uint64>(-1)), priority);
  bool is_inserted = query_id_to_node_id_.emplace(query_id, node_id).second;
  CHECK(is_inserted);
}

void FileDownloadManager::update_priority(QueryId query_id, int8 priority) {
  if (stop_flag_) {
    return;
  }
  auto it = query_id_to_node_id_.find(query_id);
  if (it == query_id_to_node_id_.end()) {
    return;
  }
  auto node = nodes_container_.get(it->second);
  if (node == nullptr || node->downloader_.empty()) {
    return;
  }
  send_closure(node->downloader_, &FileLoaderActor::update_priority, priority);
}

void FileDownloadManager::from_bytes(QueryId query_id, FileType type, BufferSlice bytes, string name) {
  if (stop_flag_) {
    return;
  }
  NodeId node_id = nodes_container_.create(Node());
  Node *node = nodes_container_.get(node_id);
  CHECK(node);
  node->query_id_ = query_id;
  auto callback = make_unique<FileFromBytesCallback>(actor_shared(this, node_id));
  node->from_bytes_ =
      create_actor<FileFromBytes>("FromBytes", type, std::move(bytes), std::move(name), std::move(callback));
  bool is_inserted = query_id_to_node_id_.emplace(query_id, node_id).second;
  CHECK(is_inserted);
}

void FileDownloadManager::cancel(QueryId query_id) {
  if (stop_flag_) {
    return;
  }
  auto it = query_id_to_node_id_.find(query_id);
  if (it == query_id_to_node_id_.end()) {
    return;
  }
  on_error_impl(it->second, Status::Error(-1, "Canceled"));
}

void FileDownloadManager::update_downloaded_part(QueryId query_id, int64 offset, int64 limit) {
  if (stop_flag_) {
    return;
  }
  auto it = query_id_to_node_id_.find(query_id);
  if (it == query_id_to_node_id_.end()) {
    return;
  }
  auto node = nodes_container_.get(it->second);
  if (node == nullptr || node->downloader_.empty()) {
    return;
  }
  send_closure(node->downloader_, &FileDownloader::update_downloaded_part, offset, limit, max_download_resource_limit_);
}

void FileDownloadManager::hangup() {
  nodes_container_.for_each([](auto query_id, auto &node) {
    node.downloader_.reset();
    node.from_bytes_.reset();
  });
  for (auto &it : download_resource_manager_map_) {
    it.second.reset();
  }
  for (auto &it : download_small_resource_manager_map_) {
    it.second.reset();
  }
  stop_flag_ = true;
  try_stop();
}

void FileDownloadManager::on_start_download() {
  auto node_id = get_link_token();
  auto node = nodes_container_.get(node_id);
  if (node == nullptr) {
    return;
  }
  if (!stop_flag_) {
    callback_->on_start_download(node->query_id_);
  }
}

void FileDownloadManager::on_partial_download(PartialLocalFileLocation partial_local, int64 size) {
  auto node_id = get_link_token();
  auto node = nodes_container_.get(node_id);
  if (node == nullptr) {
    return;
  }
  if (!stop_flag_) {
    callback_->on_partial_download(node->query_id_, std::move(partial_local), size);
  }
}

void FileDownloadManager::on_ok_download(FullLocalFileLocation local, int64 size, bool is_new) {
  auto node_id = get_link_token();
  auto node = nodes_container_.get(node_id);
  if (node == nullptr) {
    return;
  }
  if (!stop_flag_) {
    callback_->on_download_ok(node->query_id_, std::move(local), size, is_new);
  }
  close_node(node_id);
}

void FileDownloadManager::on_error(Status status) {
  auto node_id = get_link_token();
  on_error_impl(node_id, std::move(status));
}

void FileDownloadManager::on_error_impl(NodeId node_id, Status status) {
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

void FileDownloadManager::hangup_shared() {
  auto node_id = get_link_token();
  on_error_impl(node_id, Status::Error(-1, "Canceled"));
}

void FileDownloadManager::try_stop() {
  if (stop_flag_ && nodes_container_.empty()) {
    stop();
  }
}

void FileDownloadManager::close_node(NodeId node_id) {
  auto node = nodes_container_.get(node_id);
  CHECK(node);
  query_id_to_node_id_.erase(node->query_id_);
  nodes_container_.erase(node_id);
  try_stop();
}

}  // namespace td
