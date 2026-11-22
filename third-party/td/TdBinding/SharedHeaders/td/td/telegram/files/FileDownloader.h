//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DelayDispatcher.h"
#include "td/telegram/files/FileEncryptionKey.h"
#include "td/telegram/files/FileLoaderActor.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/PartsManager.h"
#include "td/telegram/files/ResourceManager.h"
#include "td/telegram/files/ResourceState.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/OrderedEventsProcessor.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/Status.h"

#include <map>
#include <set>
#include <utility>

namespace td {

class FileDownloader final : public FileLoaderActor {
 public:
  class Callback {
   public:
    Callback() = default;
    Callback(const Callback &) = delete;
    Callback &operator=(const Callback &) = delete;
    virtual void on_start_download() = 0;
    virtual void on_partial_download(PartialLocalFileLocation partial_local, int64 size) = 0;
    virtual void on_ok(FullLocalFileLocation full_local, int64 size, bool is_new) = 0;
    virtual void on_error(Status status) = 0;
    virtual ~Callback() = default;
  };

  FileDownloader(const FullRemoteFileLocation &remote, const LocalFileLocation &local, int64 size, string name,
                 const FileEncryptionKey &encryption_key, bool is_small, bool need_search_file, int64 offset,
                 int64 limit, unique_ptr<Callback> callback);

  void update_downloaded_part(int64 offset, int64 limit, int64 max_resource_limit);

  // Should just implement all parent pure virtual methods.
  // Must not call any of them...
 private:
  enum class QueryType : uint8 { Default = 1, CDN, ReuploadCDN };
  FullRemoteFileLocation remote_;
  LocalFileLocation local_;
  int64 size_;
  string name_;
  FileEncryptionKey encryption_key_;
  unique_ptr<Callback> callback_;
  bool only_check_{false};

  string path_;
  FileFd fd_;

  int32 next_part_ = 0;
  bool next_part_stop_ = false;
  bool is_small_ = false;
  bool need_search_file_ = false;
  bool ordered_flag_ = false;
  bool keep_fd_ = false;
  int64 offset_ = 0;
  int64 limit_ = 0;

  bool use_cdn_ = false;
  DcId cdn_dc_id_;
  string cdn_encryption_key_;
  string cdn_encryption_iv_;
  string cdn_file_token_;
  int32 cdn_file_token_generation_{0};
  std::map<int32, string> cdn_part_reupload_token_;
  std::map<int32, int32> cdn_part_file_token_generation_;

  bool need_check_ = false;
  struct HashInfo {
    int64 offset;
    size_t size;
    string hash;
    bool operator<(const HashInfo &other) const {
      return offset < other.offset;
    }
  };
  std::set<HashInfo> hash_info_;
  bool has_hash_query_ = false;

  static constexpr uint8 COMMON_QUERY_KEY = 2;
  bool stop_flag_ = false;
  ActorShared<ResourceManager> resource_manager_;
  ResourceState resource_state_;
  PartsManager parts_manager_;
  std::map<uint64, std::pair<Part, ActorShared<>>> part_map_;
  OrderedEventsProcessor<std::pair<Part, NetQueryPtr>> ordered_parts_;
  ActorOwn<DelayDispatcher> delay_dispatcher_;
  double next_delay_ = 0;

  uint32 debug_total_parts_ = 0;
  uint32 debug_bad_part_order_ = 0;
  std::vector<int32> debug_bad_parts_;

  void hangup() final;

  void hangup_shared() final;

  void on_error(Status status);

  Result<bool> should_restart_part(Part part, const NetQueryPtr &net_query) TD_WARN_UNUSED_RESULT;

  Status process_check_query(NetQueryPtr net_query);

  Status check_loop(int64 checked_prefix_size, int64 ready_prefix_size, bool is_ready);

  Result<NetQueryPtr> start_part(Part part, int32 part_count, int64 streaming_offset) TD_WARN_UNUSED_RESULT;

  Result<size_t> process_part(Part part, NetQueryPtr net_query) TD_WARN_UNUSED_RESULT;

  void add_hash_info(const std::vector<telegram_api::object_ptr<telegram_api::fileHash>> &hashes);

  void try_release_fd();

  Status acquire_fd() TD_WARN_UNUSED_RESULT;

  Status check_net_query(NetQueryPtr &net_query);

  void set_resource_manager(ActorShared<ResourceManager> resource_manager) final;

  void update_priority(int8 priority) final;

  void update_resources(const ResourceState &other) final;

  void start_up() final;
  void loop() final;
  Status do_loop();
  void tear_down() final;

  void update_estimated_limit();
  void on_progress();

  void on_result(NetQueryPtr query) final;
  void on_part_query(Part part, NetQueryPtr query);
  void on_common_query(NetQueryPtr query);
  Status try_on_part_query(Part part, NetQueryPtr query);
};

}  // namespace td
