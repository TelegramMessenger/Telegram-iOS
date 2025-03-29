//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/binlog/Binlog.h"
#include "td/db/binlog/ConcurrentBinlog.h"
#include "td/db/BinlogKeyValue.h"
#include "td/db/DbKey.h"
#include "td/db/SeqKeyValue.h"
#include "td/db/SqliteConnectionSafe.h"
#include "td/db/SqliteDb.h"
#include "td/db/SqliteKeyValueAsync.h"
#include "td/db/SqliteKeyValueSafe.h"

#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"

#include "td/utils/benchmark.h"
#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

#include <memory>

template <class KeyValueT>
class TdKvBench final : public td::Benchmark {
  td::unique_ptr<td::ConcurrentScheduler> scheduler_;
  td::string name_;

 public:
  explicit TdKvBench(td::string name) {
    name_ = std::move(name);
  }

  td::string get_description() const final {
    return name_;
  }

  class Main final : public td::Actor {
   public:
    explicit Main(int n) : n_(n) {
    }

   private:
    void loop() final {
      KeyValueT::destroy("test_tddb").ignore();

      class Worker final : public Actor {
       public:
        Worker(int n, td::string db_name) : n_(n) {
          kv_.init(db_name).ensure();
        }

       private:
        void loop() final {
          for (int i = 0; i < n_; i++) {
            kv_.set(td::to_string(i % 10), td::to_string(i));
          }
          td::Scheduler::instance()->finish();
        }
        int n_;
        KeyValueT kv_;
      };
      td::create_actor_on_scheduler<Worker>("Worker", 0, n_, "test_tddb").release();
    }
    int n_;
  };

  void start_up_n(int n) final {
    scheduler_ = td::make_unique<td::ConcurrentScheduler>(1, 0);
    scheduler_->create_actor_unsafe<Main>(1, "Main", n).release();
  }

  void run(int n) final {
    scheduler_->start();
    while (scheduler_->run_main(10)) {
      // empty
    }
    scheduler_->finish();
  }

  void tear_down() final {
    scheduler_.reset();
  }
};

template <bool is_encrypted = false>
class SqliteKVBench final : public td::Benchmark {
  td::SqliteDb db;
  td::string get_description() const final {
    return PSTRING() << "SqliteKV " << td::tag("is_encrypted", is_encrypted);
  }
  void start_up() final {
    td::string path = "testdb.sqlite";
    td::SqliteDb::destroy(path).ignore();
    if (is_encrypted) {
      db = td::SqliteDb::change_key(path, true, td::DbKey::password("cucumber"), td::DbKey::empty()).move_as_ok();
    } else {
      db = td::SqliteDb::open_with_key(path, true, td::DbKey::empty()).move_as_ok();
    }
    db.exec("PRAGMA encoding=\"UTF-8\"").ensure();
    db.exec("PRAGMA synchronous=NORMAL").ensure();
    db.exec("PRAGMA journal_mode=WAL").ensure();
    db.exec("PRAGMA temp_store=MEMORY").ensure();
    db.exec("DROP TABLE IF EXISTS KV").ensure();
    db.exec("CREATE TABLE IF NOT EXISTS KV (k BLOB PRIMARY KEY, v BLOB)").ensure();
  }
  void run(int n) final {
    auto stmt = db.get_statement("REPLACE INTO KV (k, v) VALUES(?1, ?2)").move_as_ok();
    db.exec("BEGIN TRANSACTION").ensure();
    for (int i = 0; i < n; i++) {
      auto key = td::to_string(i % 10);
      auto value = td::to_string(i);
      stmt.bind_blob(1, key).ensure();
      stmt.bind_blob(2, value).ensure();
      stmt.step().ensure();
      CHECK(!stmt.can_step());
      stmt.reset();

      if (i % 10 == 0) {
        db.exec("COMMIT TRANSACTION").ensure();
        db.exec("BEGIN TRANSACTION").ensure();
      }
    }
    db.exec("COMMIT TRANSACTION").ensure();
  }
};

static td::Status init_db(td::SqliteDb &db) {
  TRY_STATUS(db.exec("PRAGMA encoding=\"UTF-8\""));
  TRY_STATUS(db.exec("PRAGMA journal_mode=WAL"));

  TRY_STATUS(db.exec("PRAGMA synchronous=NORMAL"));
  TRY_STATUS(db.exec("PRAGMA temp_store=MEMORY"));
  // TRY_STATUS(db.exec("PRAGMA secure_delete=1"));

  return td::Status::OK();
}

class SqliteKeyValueAsyncBench final : public td::Benchmark {
 public:
  td::string get_description() const final {
    return "SqliteKeyValueAsync";
  }
  void start_up() final {
    do_start_up().ensure();
    scheduler_->start();
  }
  void run(int n) final {
    auto guard = scheduler_->get_main_guard();

    for (int i = 0; i < n; i++) {
      auto key = td::to_string(i % 10);
      auto value = td::to_string(i);
      sqlite_kv_async_->set(key, value, td::Auto());
    }
  }
  void tear_down() final {
    scheduler_->run_main(0.1);
    {
      auto guard = scheduler_->get_main_guard();
      sqlite_kv_async_.reset();
      sqlite_kv_safe_.reset();
      sql_connection_->close_and_destroy();
    }

    scheduler_->finish();
    scheduler_.reset();
  }

 private:
  td::unique_ptr<td::ConcurrentScheduler> scheduler_;
  std::shared_ptr<td::SqliteConnectionSafe> sql_connection_;
  std::shared_ptr<td::SqliteKeyValueSafe> sqlite_kv_safe_;
  td::unique_ptr<td::SqliteKeyValueAsyncInterface> sqlite_kv_async_;

  td::Status do_start_up() {
    scheduler_ = td::make_unique<td::ConcurrentScheduler>(1, 0);

    auto guard = scheduler_->get_main_guard();

    td::string sql_db_name = "testdb.sqlite";
    td::SqliteDb::destroy(sql_db_name).ignore();
    td::SqliteDb::open_with_key(sql_db_name, true, td::DbKey::empty()).move_as_ok();

    sql_connection_ = std::make_shared<td::SqliteConnectionSafe>(sql_db_name, td::DbKey::empty());
    auto &db = sql_connection_->get();
    TRY_STATUS(init_db(db));

    sqlite_kv_safe_ = std::make_shared<td::SqliteKeyValueSafe>("common", sql_connection_);
    sqlite_kv_async_ = create_sqlite_key_value_async(sqlite_kv_safe_, 0);

    return td::Status::OK();
  }
};

class SeqKvBench final : public td::Benchmark {
  td::string get_description() const final {
    return "SeqKvBench";
  }

  td::SeqKeyValue kv;
  void run(int n) final {
    for (int i = 0; i < n; i++) {
      kv.set(PSLICE() << i % 10, PSLICE() << i);
    }
  }
};

template <bool is_encrypted = false>
class BinlogKeyValueBench final : public td::Benchmark {
  td::string get_description() const final {
    return PSTRING() << "BinlogKeyValue " << td::tag("is_encrypted", is_encrypted);
  }

  td::BinlogKeyValue<td::Binlog> kv;
  void start_up() final {
    td::SqliteDb::destroy("test_binlog").ignore();
    kv.init("test_binlog", is_encrypted ? td::DbKey::password("cucumber") : td::DbKey::empty()).ensure();
  }
  void run(int n) final {
    for (int i = 0; i < n; i++) {
      kv.set(td::to_string(i % 10), td::to_string(i));
    }
  }
};

int main() {
  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(WARNING));
  bench(TdKvBench<td::BinlogKeyValue<td::Binlog>>("BinlogKeyValue<Binlog>"));
  bench(TdKvBench<td::BinlogKeyValue<td::ConcurrentBinlog>>("BinlogKeyValue<ConcurrentBinlog>"));

  bench(BinlogKeyValueBench<true>());
  bench(BinlogKeyValueBench<false>());
  bench(SqliteKVBench<false>());
  bench(SqliteKVBench<true>());
  bench(SqliteKeyValueAsyncBench());
  bench(SeqKvBench());
}
