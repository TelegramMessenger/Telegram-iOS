//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileEncryptionKey.h"
#include "td/telegram/files/FileLoaderActor.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/files/PartsManager.h"
#include "td/telegram/files/ResourceManager.h"
#include "td/telegram/files/ResourceState.h"
#include "td/telegram/net/NetQuery.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

#include <map>
#include <utility>

namespace td {

class FileUploader final : public FileLoaderActor {
 public:
  class Callback {
   public:
    Callback() = default;
    Callback(const Callback &) = delete;
    Callback &operator=(const Callback &) = delete;
    virtual void on_hash(string hash) = 0;
    virtual void on_partial_upload(PartialRemoteFileLocation partial_remote) = 0;
    virtual void on_ok(FileType file_type, PartialRemoteFileLocation partial_remote) = 0;
    virtual void on_error(Status status) = 0;
    virtual ~Callback() = default;
  };

  FileUploader(const LocalFileLocation &local, const RemoteFileLocation &remote, int64 expected_size,
               const FileEncryptionKey &encryption_key, std::vector<int> bad_parts, unique_ptr<Callback> callback);

  void update_local_file_location(const LocalFileLocation &local);

 private:
  LocalFileLocation local_;
  RemoteFileLocation remote_;
  int64 expected_size_;
  FileEncryptionKey encryption_key_;
  vector<int> bad_parts_;
  unique_ptr<Callback> callback_;
  int64 local_size_ = 0;
  bool local_is_ready_ = false;
  FileType file_type_ = FileType::Temp;

  vector<UInt256> iv_map_;
  UInt256 iv_;
  string generate_iv_;
  int64 generate_offset_ = 0;
  int64 next_offset_ = 0;

  FileFd fd_;
  string fd_path_;
  int64 file_id_ = 0;
  bool is_temp_ = false;
  bool big_flag_ = false;
  bool keep_fd_ = false;
  bool stop_flag_ = false;

  ActorShared<ResourceManager> resource_manager_;
  ResourceState resource_state_;
  PartsManager parts_manager_;
  std::map<uint64, std::pair<Part, ActorShared<>>> part_map_;

  void set_resource_manager(ActorShared<ResourceManager> resource_manager) final;

  void update_priority(int8 priority) final;

  void update_resources(const ResourceState &other) final;

  void on_error(Status status);

  Result<NetQueryPtr> start_part(Part part, int32 part_count) TD_WARN_UNUSED_RESULT;

  Result<size_t> process_part(Part part, NetQueryPtr net_query) TD_WARN_UNUSED_RESULT;

  void on_progress();

  struct PrefixInfo {
    int64 size = -1;
    bool is_ready = false;
  };
  Result<PrefixInfo> on_update_local_location(const LocalFileLocation &location, int64 file_size) TD_WARN_UNUSED_RESULT;

  Status generate_iv_map();

  void try_release_fd();

  Status acquire_fd() TD_WARN_UNUSED_RESULT;

  void start_up() final;

  void loop() final;

  Status do_loop();

  void tear_down() final;

  void update_estimated_limit();

  void on_result(NetQueryPtr query) final;

  void on_part_query(Part part, NetQueryPtr query);

  void on_common_query(NetQueryPtr query);

  Status try_on_part_query(Part part, NetQueryPtr query);
};

}  // namespace td
