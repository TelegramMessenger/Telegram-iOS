//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageThreadDb.h"

#include "td/telegram/Version.h"

#include "td/db/SqliteConnectionSafe.h"
#include "td/db/SqliteDb.h"
#include "td/db/SqliteStatement.h"

#include "td/actor/actor.h"
#include "td/actor/SchedulerLocalStorage.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Time.h"

namespace td {
// NB: must happen inside a transaction
Status init_message_thread_db(SqliteDb &db, int32 version) {
  LOG(INFO) << "Init message thread database " << tag("version", version);

  // Check if database exists
  TRY_RESULT(has_table, db.has_table("threads"));
  if (!has_table) {
    version = 0;
  }

  if (version > current_db_version()) {
    TRY_STATUS(drop_message_thread_db(db, version));
    version = 0;
  }

  if (version == 0) {
    LOG(INFO) << "Create new message thread database";
    TRY_STATUS(
        db.exec("CREATE TABLE IF NOT EXISTS threads (dialog_id INT8, thread_id INT8, thread_order INT8, data BLOB, "
                "PRIMARY KEY (dialog_id, thread_id))"));
    TRY_STATUS(
        db.exec("CREATE INDEX IF NOT EXISTS dialog_threads_by_thread_order ON threads (dialog_id, thread_order)"));
    version = current_db_version();
  }

  return Status::OK();
}

// NB: must happen inside a transaction
Status drop_message_thread_db(SqliteDb &db, int version) {
  if (version > current_db_version()) {
    LOG(WARNING) << "Drop message_thread_db " << tag("version", version)
                 << tag("current_db_version", current_db_version());
  }
  return db.exec("DROP TABLE IF EXISTS threads");
}

class MessageThreadDbImpl final : public MessageThreadDbSyncInterface {
 public:
  explicit MessageThreadDbImpl(SqliteDb db) : db_(std::move(db)) {
    init().ensure();
  }

  Status init() {
    TRY_RESULT_ASSIGN(add_thread_stmt_, db_.get_statement("INSERT OR REPLACE INTO threads VALUES(?1, ?2, ?3, ?4)"));
    TRY_RESULT_ASSIGN(delete_thread_stmt_,
                      db_.get_statement("DELETE FROM threads WHERE dialog_id = ?1 AND thread_id = ?2"));
    TRY_RESULT_ASSIGN(delete_all_dialog_threads_stmt_, db_.get_statement("DELETE FROM threads WHERE dialog_id = ?1"));
    TRY_RESULT_ASSIGN(get_thread_stmt_,
                      db_.get_statement("SELECT data FROM threads WHERE dialog_id = ?1 AND thread_id = ?2"));
    TRY_RESULT_ASSIGN(get_threads_stmt_,
                      db_.get_statement("SELECT data, dialog_id, thread_id, thread_order FROM threads WHERE dialog_id "
                                        "= ?1 AND thread_order < ?2 ORDER BY thread_order DESC LIMIT ?3"));

    // LOG(ERROR) << delete_thread_stmt_.explain().ok();
    // LOG(ERROR) << delete_all_dialog_threads_stmt_.explain().ok();
    // LOG(ERROR) << get_thread_stmt_.explain().ok();
    // LOG(ERROR) << get_threads_stmt_.explain().ok();
    // LOG(FATAL) << "EXPLAINED";

    return Status::OK();
  }

  void add_message_thread(DialogId dialog_id, MessageId top_thread_message_id, int64 order, BufferSlice data) final {
    SCOPE_EXIT {
      add_thread_stmt_.reset();
    };
    add_thread_stmt_.bind_int64(1, dialog_id.get()).ensure();
    add_thread_stmt_.bind_int64(2, top_thread_message_id.get()).ensure();
    add_thread_stmt_.bind_int64(3, order).ensure();
    add_thread_stmt_.bind_blob(4, data.as_slice()).ensure();
    add_thread_stmt_.step().ensure();
  }

  void delete_message_thread(DialogId dialog_id, MessageId top_thread_message_id) final {
    SCOPE_EXIT {
      delete_thread_stmt_.reset();
    };
    delete_thread_stmt_.bind_int64(1, dialog_id.get()).ensure();
    delete_thread_stmt_.bind_int64(2, top_thread_message_id.get()).ensure();
    delete_thread_stmt_.step().ensure();
  }

  void delete_all_dialog_message_threads(DialogId dialog_id) final {
    SCOPE_EXIT {
      delete_all_dialog_threads_stmt_.reset();
    };
    delete_all_dialog_threads_stmt_.bind_int64(1, dialog_id.get()).ensure();
    delete_all_dialog_threads_stmt_.step().ensure();
  }

  BufferSlice get_message_thread(DialogId dialog_id, MessageId top_thread_message_id) final {
    SCOPE_EXIT {
      get_thread_stmt_.reset();
    };

    get_thread_stmt_.bind_int64(1, dialog_id.get()).ensure();
    get_thread_stmt_.bind_int64(2, top_thread_message_id.get()).ensure();
    get_thread_stmt_.step().ensure();
    if (!get_thread_stmt_.has_row()) {
      return BufferSlice();
    }
    return BufferSlice(get_thread_stmt_.view_blob(0));
  }

  MessageThreadDbMessageThreads get_message_threads(DialogId dialog_id, int64 offset_order, int32 limit) final {
    SCOPE_EXIT {
      get_threads_stmt_.reset();
    };

    get_threads_stmt_.bind_int64(1, dialog_id.get()).ensure();
    get_threads_stmt_.bind_int64(2, offset_order).ensure();
    get_threads_stmt_.bind_int32(3, limit).ensure();

    MessageThreadDbMessageThreads result;
    result.next_order = offset_order;
    get_threads_stmt_.step().ensure();
    while (get_threads_stmt_.has_row()) {
      BufferSlice data(get_threads_stmt_.view_blob(0));
      result.next_order = get_threads_stmt_.view_int64(3);
      LOG(INFO) << "Load thread of " << MessageId(get_threads_stmt_.view_int64(2)) << " in "
                << DialogId(get_threads_stmt_.view_int64(1)) << " with order " << result.next_order;
      result.message_threads.emplace_back(std::move(data));
      get_threads_stmt_.step().ensure();
    }
    return result;
  }

  Status begin_write_transaction() final {
    return db_.begin_write_transaction();
  }

  Status commit_transaction() final {
    return db_.commit_transaction();
  }

 private:
  SqliteDb db_;

  SqliteStatement add_thread_stmt_;
  SqliteStatement delete_thread_stmt_;
  SqliteStatement delete_all_dialog_threads_stmt_;
  SqliteStatement get_thread_stmt_;
  SqliteStatement get_threads_stmt_;
};

std::shared_ptr<MessageThreadDbSyncSafeInterface> create_message_thread_db_sync(
    std::shared_ptr<SqliteConnectionSafe> sqlite_connection) {
  class MessageThreadDbSyncSafe final : public MessageThreadDbSyncSafeInterface {
   public:
    explicit MessageThreadDbSyncSafe(std::shared_ptr<SqliteConnectionSafe> sqlite_connection)
        : lsls_db_([safe_connection = std::move(sqlite_connection)] {
          return make_unique<MessageThreadDbImpl>(safe_connection->get().clone());
        }) {
    }
    MessageThreadDbSyncInterface &get() final {
      return *lsls_db_.get();
    }

   private:
    LazySchedulerLocalStorage<unique_ptr<MessageThreadDbSyncInterface>> lsls_db_;
  };
  return std::make_shared<MessageThreadDbSyncSafe>(std::move(sqlite_connection));
}

class MessageThreadDbAsync final : public MessageThreadDbAsyncInterface {
 public:
  MessageThreadDbAsync(std::shared_ptr<MessageThreadDbSyncSafeInterface> sync_db, int32 scheduler_id) {
    impl_ = create_actor_on_scheduler<Impl>("MessageThreadDbActor", scheduler_id, std::move(sync_db));
  }

  void add_message_thread(DialogId dialog_id, MessageId top_thread_message_id, int64 order, BufferSlice data,
                          Promise<Unit> promise) final {
    send_closure(impl_, &Impl::add_message_thread, dialog_id, top_thread_message_id, order, std::move(data),
                 std::move(promise));
  }

  void delete_message_thread(DialogId dialog_id, MessageId top_thread_message_id, Promise<Unit> promise) final {
    send_closure(impl_, &Impl::delete_message_thread, dialog_id, top_thread_message_id, std::move(promise));
  }

  void delete_all_dialog_message_threads(DialogId dialog_id, Promise<Unit> promise) final {
    send_closure(impl_, &Impl::delete_all_dialog_message_threads, dialog_id, std::move(promise));
  }

  void get_message_thread(DialogId dialog_id, MessageId top_thread_message_id, Promise<BufferSlice> promise) final {
    send_closure_later(impl_, &Impl::get_message_thread, dialog_id, top_thread_message_id, std::move(promise));
  }

  void get_message_threads(DialogId dialog_id, int64 offset_order, int32 limit,
                           Promise<MessageThreadDbMessageThreads> promise) final {
    send_closure_later(impl_, &Impl::get_message_threads, dialog_id, offset_order, limit, std::move(promise));
  }

  void close(Promise<Unit> promise) final {
    send_closure_later(impl_, &Impl::close, std::move(promise));
  }

  void force_flush() final {
    send_closure_later(impl_, &Impl::force_flush);
  }

 private:
  class Impl final : public Actor {
   public:
    explicit Impl(std::shared_ptr<MessageThreadDbSyncSafeInterface> sync_db_safe)
        : sync_db_safe_(std::move(sync_db_safe)) {
    }

    void add_message_thread(DialogId dialog_id, MessageId top_thread_message_id, int64 order, BufferSlice data,
                            Promise<Unit> promise) {
      add_write_query([this, dialog_id, top_thread_message_id, order, data = std::move(data),
                       promise = std::move(promise)](Unit) mutable {
        sync_db_->add_message_thread(dialog_id, top_thread_message_id, order, std::move(data));
        on_write_result(std::move(promise));
      });
    }

    void delete_message_thread(DialogId dialog_id, MessageId top_thread_message_id, Promise<Unit> promise) {
      add_write_query([this, dialog_id, top_thread_message_id, promise = std::move(promise)](Unit) mutable {
        sync_db_->delete_message_thread(dialog_id, top_thread_message_id);
        on_write_result(std::move(promise));
      });
    }

    void delete_all_dialog_message_threads(DialogId dialog_id, Promise<Unit> promise) {
      add_write_query([this, dialog_id, promise = std::move(promise)](Unit) mutable {
        sync_db_->delete_all_dialog_message_threads(dialog_id);
        on_write_result(std::move(promise));
      });
    }

    void on_write_result(Promise<Unit> &&promise) {
      // We are inside a transaction and don't know how to handle errors
      finished_writes_.push_back(std::move(promise));
    }

    void get_message_thread(DialogId dialog_id, MessageId top_thread_message_id, Promise<BufferSlice> promise) {
      add_read_query();
      promise.set_result(sync_db_->get_message_thread(dialog_id, top_thread_message_id));
    }

    void get_message_threads(DialogId dialog_id, int64 offset_order, int32 limit,
                             Promise<MessageThreadDbMessageThreads> promise) {
      add_read_query();
      promise.set_result(sync_db_->get_message_threads(dialog_id, offset_order, limit));
    }

    void close(Promise<> promise) {
      do_flush();
      sync_db_safe_.reset();
      sync_db_ = nullptr;
      promise.set_value(Unit());
      stop();
    }

    void force_flush() {
      do_flush();
      LOG(INFO) << "MessageThreadDb flushed";
    }

   private:
    std::shared_ptr<MessageThreadDbSyncSafeInterface> sync_db_safe_;
    MessageThreadDbSyncInterface *sync_db_ = nullptr;

    static constexpr size_t MAX_PENDING_QUERIES_COUNT{50};
    static constexpr double MAX_PENDING_QUERIES_DELAY{0.01};

    //NB: order is important, destructor of pending_writes_ will change finished_writes_
    vector<Promise<Unit>> finished_writes_;
    vector<Promise<Unit>> pending_writes_;  // TODO use Action
    double wakeup_at_ = 0;

    template <class F>
    void add_write_query(F &&f) {
      pending_writes_.push_back(PromiseCreator::lambda(std::forward<F>(f)));
      if (pending_writes_.size() > MAX_PENDING_QUERIES_COUNT) {
        do_flush();
        wakeup_at_ = 0;
      } else if (wakeup_at_ == 0) {
        wakeup_at_ = Time::now_cached() + MAX_PENDING_QUERIES_DELAY;
      }
      if (wakeup_at_ != 0) {
        set_timeout_at(wakeup_at_);
      }
    }

    void add_read_query() {
      do_flush();
    }

    void do_flush() {
      if (pending_writes_.empty()) {
        return;
      }
      sync_db_->begin_write_transaction().ensure();
      set_promises(pending_writes_);
      sync_db_->commit_transaction().ensure();
      set_promises(finished_writes_);
      cancel_timeout();
    }

    void timeout_expired() final {
      do_flush();
    }

    void start_up() final {
      sync_db_ = &sync_db_safe_->get();
    }
  };
  ActorOwn<Impl> impl_;
};

std::shared_ptr<MessageThreadDbAsyncInterface> create_message_thread_db_async(
    std::shared_ptr<MessageThreadDbSyncSafeInterface> sync_db, int32 scheduler_id) {
  return std::make_shared<MessageThreadDbAsync>(std::move(sync_db), scheduler_id);
}

}  // namespace td
