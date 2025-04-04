//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileGcWorker.h"
#include "td/telegram/files/FileStats.h"
#include "td/telegram/files/FileStatsWorker.h"
#include "td/telegram/td_api.h"

#include "td/actor/actor.h"

#include "td/utils/CancellationToken.h"
#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

struct DatabaseStats {
  string debug;
  DatabaseStats() = default;
  explicit DatabaseStats(string debug) : debug(std::move(debug)) {
  }
  tl_object_ptr<td_api::databaseStatistics> get_database_statistics_object() const;
};

class StorageManager final : public Actor {
 public:
  StorageManager(ActorShared<> parent, int32 scheduler_id);
  void get_storage_stats(bool need_all_files, int32 dialog_limit, Promise<FileStats> promise);
  void get_storage_stats_fast(Promise<FileStatsFast> promise);
  void get_database_stats(Promise<DatabaseStats> promise);
  void run_gc(FileGcParameters parameters, bool return_deleted_file_statistics, Promise<FileStats> promise);
  void update_use_storage_optimizer();

  void on_new_file(int64 size, int64 real_size, int32 cnt);

 private:
  static constexpr int32 GC_EACH = 60 * 60 * 24;  // 1 day
  static constexpr int32 GC_DELAY = 60;
  static constexpr int32 GC_RAND_DELAY = 60 * 15;

  ActorShared<> parent_;

  int32 scheduler_id_;

  // get stats
  ActorOwn<FileStatsWorker> stats_worker_;
  std::vector<Promise<FileStats>> pending_storage_stats_;
  uint32 stats_generation_{0};
  int32 stats_dialog_limit_{0};
  bool stats_need_all_files_{false};

  FileTypeStat fast_stat_;

  CancellationTokenSource stats_cancellation_token_source_;
  CancellationTokenSource gc_cancellation_token_source_;

  void on_file_stats(Result<FileStats> r_file_stats, uint32 generation);
  void create_stats_worker();
  void update_fast_stats(const FileStats &stats);
  static void send_stats(FileStats &&stats, int32 dialog_limit, std::vector<Promise<FileStats>> &&promises);

  void save_fast_stat();
  void load_fast_stat();
  static int64 get_database_size();
  static int64 get_language_pack_database_size();
  static int64 get_log_size();
  static int64 get_file_size(CSlice path);

  // RefCnt
  int32 ref_cnt_{1};
  bool is_closed_{false};
  ActorShared<> create_reference();
  void start_up() final;
  void hangup_shared() final;
  void hangup() final;

  // Gc
  ActorOwn<FileGcWorker> gc_worker_;
  std::vector<Promise<FileStats>> pending_run_gc_[2];

  uint32 last_gc_timestamp_ = 0;
  double next_gc_at_ = 0;

  void on_all_files(FileGcParameters gc_parameters, Result<FileStats> r_file_stats);
  void create_gc_worker();
  void on_gc_finished(int32 dialog_limit, Result<FileGcResult> r_file_gc_result);

  void close_stats_worker();
  void close_gc_worker();

  uint32 load_last_gc_timestamp();
  void save_last_gc_timestamp();
  void schedule_next_gc();

  void timeout_expired() final;
};

}  // namespace td
