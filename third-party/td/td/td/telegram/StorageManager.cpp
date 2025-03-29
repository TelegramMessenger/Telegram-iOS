//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StorageManager.h"

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileGcWorker.h"
#include "td/telegram/files/FileStatsWorker.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/TdDb.h"

#include "td/db/SqliteDb.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/port/Stat.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/Time.h"

namespace td {

tl_object_ptr<td_api::databaseStatistics> DatabaseStats::get_database_statistics_object() const {
  return make_tl_object<td_api::databaseStatistics>(debug);
}

StorageManager::StorageManager(ActorShared<> parent, int32 scheduler_id)
    : parent_(std::move(parent)), scheduler_id_(scheduler_id) {
}

void StorageManager::start_up() {
  load_last_gc_timestamp();
  schedule_next_gc();

  load_fast_stat();
}

void StorageManager::on_new_file(int64 size, int64 real_size, int32 cnt) {
  LOG(INFO) << "Add " << cnt << " file of size " << size << " with real size " << real_size
            << " to fast storage statistics";
  fast_stat_.cnt += cnt;
#if TD_WINDOWS
  auto add_size = size;
#else
  auto add_size = real_size;
#endif
  fast_stat_.size += add_size;

  if (fast_stat_.cnt < 0 || fast_stat_.size < 0) {
    LOG(ERROR) << "Wrong fast stat after adding size " << add_size << " and cnt " << cnt;
    fast_stat_ = FileTypeStat();
  }
  save_fast_stat();
}

void StorageManager::get_storage_stats(bool need_all_files, int32 dialog_limit, Promise<FileStats> promise) {
  if (is_closed_) {
    return promise.set_error(Global::request_aborted_error());
  }
  if (!pending_storage_stats_.empty()) {
    if (stats_dialog_limit_ == dialog_limit && need_all_files == stats_need_all_files_) {
      pending_storage_stats_.emplace_back(std::move(promise));
      return;
    }
    //TODO group same queries
    close_stats_worker();
  }
  if (!pending_run_gc_[0].empty() || !pending_run_gc_[1].empty()) {
    close_gc_worker();
  }
  stats_dialog_limit_ = dialog_limit;
  stats_need_all_files_ = need_all_files;
  pending_storage_stats_.emplace_back(std::move(promise));

  create_stats_worker();
  send_closure(stats_worker_, &FileStatsWorker::get_stats, need_all_files, stats_dialog_limit_ != 0,
               PromiseCreator::lambda(
                   [actor_id = actor_id(this), stats_generation = stats_generation_](Result<FileStats> file_stats) {
                     send_closure(actor_id, &StorageManager::on_file_stats, std::move(file_stats), stats_generation);
                   }));
}

void StorageManager::get_storage_stats_fast(Promise<FileStatsFast> promise) {
  promise.set_value(FileStatsFast(fast_stat_.size, fast_stat_.cnt, get_database_size(),
                                  get_language_pack_database_size(), get_log_size()));
}

void StorageManager::get_database_stats(Promise<DatabaseStats> promise) {
  //TODO: use another thread
  auto r_stats = G()->td_db()->get_stats();
  if (r_stats.is_error()) {
    promise.set_error(r_stats.move_as_error());
  } else {
    promise.set_value(DatabaseStats(r_stats.move_as_ok()));
  }
}

void StorageManager::update_use_storage_optimizer() {
  schedule_next_gc();
}

void StorageManager::run_gc(FileGcParameters parameters, bool return_deleted_file_statistics,
                            Promise<FileStats> promise) {
  if (is_closed_) {
    return promise.set_error(Global::request_aborted_error());
  }
  if (!pending_run_gc_[0].empty() || !pending_run_gc_[1].empty()) {
    close_gc_worker();
  }

  bool split_by_owner_dialog_id = !parameters.owner_dialog_ids_.empty() ||
                                  !parameters.exclude_owner_dialog_ids_.empty() || parameters.dialog_limit_ != 0;
  get_storage_stats(
      true /*need_all_files*/, split_by_owner_dialog_id,
      PromiseCreator::lambda(
          [actor_id = actor_id(this), parameters = std::move(parameters)](Result<FileStats> file_stats) mutable {
            send_closure(actor_id, &StorageManager::on_all_files, std::move(parameters), std::move(file_stats));
          }));

  //NB: get_storage_stats will cancel all garbage collection queries, so promise needs to be added after the call
  pending_run_gc_[return_deleted_file_statistics].push_back(std::move(promise));
}

void StorageManager::on_file_stats(Result<FileStats> r_file_stats, uint32 generation) {
  if (generation != stats_generation_) {
    return;
  }
  if (r_file_stats.is_error()) {
    fail_promises(pending_storage_stats_, r_file_stats.move_as_error());
    return;
  }

  update_fast_stats(r_file_stats.ok());
  send_stats(r_file_stats.move_as_ok(), stats_dialog_limit_, std::move(pending_storage_stats_));
}

void StorageManager::create_stats_worker() {
  CHECK(!is_closed_);
  if (stats_worker_.empty()) {
    stats_worker_ =
        create_actor_on_scheduler<FileStatsWorker>("FileStatsWorker", scheduler_id_, create_reference(),
                                                   stats_cancellation_token_source_.get_cancellation_token());
  }
}

void StorageManager::on_all_files(FileGcParameters gc_parameters, Result<FileStats> r_file_stats) {
  int32 dialog_limit = gc_parameters.dialog_limit_;
  if (is_closed_ && r_file_stats.is_ok()) {
    r_file_stats = Global::request_aborted_error();
  }
  if (r_file_stats.is_error()) {
    return on_gc_finished(dialog_limit, r_file_stats.move_as_error());
  }

  create_gc_worker();

  send_closure(gc_worker_, &FileGcWorker::run_gc, std::move(gc_parameters), r_file_stats.ok_ref().get_all_files(),
               !G()->get_option_string("my_phone_number").empty(),
               PromiseCreator::lambda([actor_id = actor_id(this), dialog_limit](Result<FileGcResult> r_file_gc_result) {
                 send_closure(actor_id, &StorageManager::on_gc_finished, dialog_limit, std::move(r_file_gc_result));
               }));
}

int64 StorageManager::get_file_size(CSlice path) {
  auto r_info = stat(path);
  if (r_info.is_error()) {
    return 0;
  }

  auto size = r_info.ok().real_size_;
  LOG(DEBUG) << "Add file \"" << path << "\" of size " << size << " to fast storage statistics";
  return size;
}

int64 StorageManager::get_database_size() {
  int64 size = 0;
  G()->td_db()->with_db_path([&size](CSlice path) { size += get_file_size(path); });
  return size;
}

int64 StorageManager::get_language_pack_database_size() {
  int64 size = 0;
  auto path = G()->get_option_string("language_pack_database_path");
  if (!path.empty()) {
    SqliteDb::with_db_path(path, [&size](CSlice path) { size += get_file_size(path); });
  }
  return size;
}

int64 StorageManager::get_log_size() {
  int64 size = 0;
  for (auto &log_path : log_interface->get_file_paths()) {
    size += get_file_size(log_path);
  }
  return size;
}

void StorageManager::create_gc_worker() {
  CHECK(!is_closed_);
  if (gc_worker_.empty()) {
    gc_worker_ = create_actor_on_scheduler<FileGcWorker>("FileGcWorker", scheduler_id_, create_reference(),
                                                         gc_cancellation_token_source_.get_cancellation_token());
  }
}

void StorageManager::on_gc_finished(int32 dialog_limit, Result<FileGcResult> r_file_gc_result) {
  if (r_file_gc_result.is_error()) {
    if (r_file_gc_result.error().code() != 500) {
      LOG(ERROR) << "GC failed: " << r_file_gc_result.error();
    }
    auto promises = std::move(pending_run_gc_[0]);
    append(promises, std::move(pending_run_gc_[1]));
    pending_run_gc_[0].clear();
    pending_run_gc_[1].clear();
    fail_promises(promises, r_file_gc_result.move_as_error());
    return;
  }

  update_fast_stats(r_file_gc_result.ok().kept_file_stats_);

  auto kept_file_promises = std::move(pending_run_gc_[0]);
  auto removed_file_promises = std::move(pending_run_gc_[1]);
  send_stats(std::move(r_file_gc_result.ok_ref().kept_file_stats_), dialog_limit, std::move(kept_file_promises));
  send_stats(std::move(r_file_gc_result.ok_ref().removed_file_stats_), dialog_limit, std::move(removed_file_promises));
}

void StorageManager::save_fast_stat() {
  G()->td_db()->get_binlog_pmc()->set("fast_file_stat", log_event_store(fast_stat_).as_slice().str());
}

void StorageManager::load_fast_stat() {
  auto status = log_event_parse(fast_stat_, G()->td_db()->get_binlog_pmc()->get("fast_file_stat"));
  if (status.is_error()) {
    fast_stat_ = FileTypeStat();
  }
  LOG(INFO) << "Loaded fast storage statistics with " << fast_stat_.cnt << " files of total size " << fast_stat_.size;
}

void StorageManager::update_fast_stats(const FileStats &stats) {
  fast_stat_ = stats.get_total_nontemp_stat();
  LOG(INFO) << "Recalculate fast storage statistics to " << fast_stat_.cnt << " files of total size "
            << fast_stat_.size;
  save_fast_stat();
}

void StorageManager::send_stats(FileStats &&stats, int32 dialog_limit, std::vector<Promise<FileStats>> &&promises) {
  if (promises.empty()) {
    return;
  }

  stats.apply_dialog_limit(dialog_limit);
  auto dialog_ids = stats.get_dialog_ids();

  auto promise = PromiseCreator::lambda(
      [promises = std::move(promises), stats = std::move(stats)](vector<DialogId> dialog_ids) mutable {
        stats.apply_dialog_ids(dialog_ids);
        auto size = promises.size();
        size--;
        for (size_t i = 0; i < size; i++) {
          if (promises[i]) {
            promises[i].set_value(FileStats(stats));
          }
        }
        promises[size].set_value(std::move(stats));
      });

  send_closure(G()->messages_manager(), &MessagesManager::load_dialogs, std::move(dialog_ids), std::move(promise));
}

ActorShared<> StorageManager::create_reference() {
  ref_cnt_++;
  return actor_shared(this, 1);
}

void StorageManager::hangup_shared() {
  ref_cnt_--;
  if (ref_cnt_ == 0) {
    stop();
  }
}

void StorageManager::close_stats_worker() {
  fail_promises(pending_storage_stats_, Global::request_aborted_error());
  stats_generation_++;
  stats_worker_.reset();
  stats_cancellation_token_source_.cancel();
}

void StorageManager::close_gc_worker() {
  auto promises = std::move(pending_run_gc_[0]);
  append(promises, std::move(pending_run_gc_[1]));
  pending_run_gc_[0].clear();
  pending_run_gc_[1].clear();
  fail_promises(promises, Global::request_aborted_error());
  gc_worker_.reset();
  gc_cancellation_token_source_.cancel();
}

void StorageManager::hangup() {
  is_closed_ = true;
  close_stats_worker();
  close_gc_worker();
  hangup_shared();
}

uint32 StorageManager::load_last_gc_timestamp() {
  last_gc_timestamp_ = to_integer<uint32>(G()->td_db()->get_binlog_pmc()->get("files_gc_ts"));
  return last_gc_timestamp_;
}

void StorageManager::save_last_gc_timestamp() {
  last_gc_timestamp_ = static_cast<uint32>(Clocks::system());
  G()->td_db()->get_binlog_pmc()->set("files_gc_ts", to_string(last_gc_timestamp_));
}

void StorageManager::schedule_next_gc() {
  if (!G()->get_option_boolean("use_storage_optimizer")) {
    next_gc_at_ = 0;
    cancel_timeout();
    LOG(INFO) << "No next file clean up is scheduled";
    return;
  }
  auto sys_time = static_cast<uint32>(Clocks::system());

  auto next_gc_at = last_gc_timestamp_ + GC_EACH;
  if (next_gc_at < sys_time) {
    next_gc_at = sys_time;
  }
  if (next_gc_at > sys_time + GC_EACH) {
    next_gc_at = sys_time + GC_EACH;
  }
  next_gc_at += Random::fast(GC_DELAY, GC_DELAY + GC_RAND_DELAY);
  CHECK(next_gc_at >= sys_time);
  auto next_gc_in = next_gc_at - sys_time;

  LOG(INFO) << "Schedule next file clean up in " << next_gc_in;
  next_gc_at_ = Time::now() + next_gc_in;
  set_timeout_at(next_gc_at_);
}

void StorageManager::timeout_expired() {
  if (next_gc_at_ == 0) {
    return;
  }
  if (!pending_run_gc_[0].empty() || !pending_run_gc_[1].empty() || !pending_storage_stats_.empty()) {
    set_timeout_in(60);
    return;
  }
  next_gc_at_ = 0;
  run_gc({}, false, PromiseCreator::lambda([actor_id = actor_id(this)](Result<FileStats> r_stats) {
           if (!r_stats.is_error() || r_stats.error().code() != 500) {
             // do not save garbage collection timestamp if request was canceled
             send_closure(actor_id, &StorageManager::save_last_gc_timestamp);
           }
           send_closure(actor_id, &StorageManager::schedule_next_gc);
         }));
}

}  // namespace td
