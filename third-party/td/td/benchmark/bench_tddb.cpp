//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogId.h"
#include "td/telegram/MessageDb.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/NotificationId.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/UserId.h"

#include "td/db/DbKey.h"
#include "td/db/SqliteConnectionSafe.h"
#include "td/db/SqliteDb.h"

#include "td/actor/ConcurrentScheduler.h"

#include "td/utils/benchmark.h"
#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Promise.h"
#include "td/utils/Random.h"
#include "td/utils/Status.h"

#include <memory>

static td::Status init_db(td::SqliteDb &db) {
  TRY_STATUS(db.exec("PRAGMA encoding=\"UTF-8\""));
  TRY_STATUS(db.exec("PRAGMA synchronous=NORMAL"));
  TRY_STATUS(db.exec("PRAGMA journal_mode=WAL"));
  TRY_STATUS(db.exec("PRAGMA temp_store=MEMORY"));
  TRY_STATUS(db.exec("PRAGMA secure_delete=1"));
  return td::Status::OK();
}

class MessageDbBench final : public td::Benchmark {
 public:
  td::string get_description() const final {
    return "MessageDb";
  }
  void start_up() final {
    LOG(ERROR) << "START UP";
    do_start_up().ensure();
    scheduler_->start();
  }
  void run(int n) final {
    auto guard = scheduler_->get_main_guard();
    for (int i = 0; i < n; i += 20) {
      auto dialog_id = td::DialogId(td::UserId(static_cast<td::int64>(td::Random::fast(1, 100))));
      auto message_id_raw = td::Random::fast(1, 100000);
      for (int j = 0; j < 20; j++) {
        auto message_id = td::MessageId{td::ServerMessageId{message_id_raw + j}};
        auto unique_message_id = td::ServerMessageId{i + 1};
        auto sender_dialog_id = td::DialogId(td::UserId(static_cast<td::int64>(td::Random::fast(1, 1000))));
        auto random_id = i + 1;
        auto ttl_expires_at = 0;
        auto data = td::BufferSlice(td::Random::fast(100, 299));

        // use async on same thread.
        message_db_async_->add_message({dialog_id, message_id}, unique_message_id, sender_dialog_id, random_id,
                                       ttl_expires_at, 0, 0, "", td::NotificationId(), td::MessageId(), std::move(data),
                                       td::Promise<>());
      }
    }
  }
  void tear_down() final {
    scheduler_->run_main(0.1);
    {
      auto guard = scheduler_->get_main_guard();
      sql_connection_.reset();
      message_db_sync_safe_.reset();
      message_db_async_.reset();
    }

    scheduler_->finish();
    scheduler_.reset();
    LOG(ERROR) << "TEAR DOWN";
  }

 private:
  td::unique_ptr<td::ConcurrentScheduler> scheduler_;
  std::shared_ptr<td::SqliteConnectionSafe> sql_connection_;
  std::shared_ptr<td::MessageDbSyncSafeInterface> message_db_sync_safe_;
  std::shared_ptr<td::MessageDbAsyncInterface> message_db_async_;

  td::Status do_start_up() {
    scheduler_ = td::make_unique<td::ConcurrentScheduler>(1, 0);

    auto guard = scheduler_->get_main_guard();

    td::string sql_db_name = "testdb.sqlite";
    sql_connection_ = std::make_shared<td::SqliteConnectionSafe>(sql_db_name, td::DbKey::empty());
    auto &db = sql_connection_->get();
    TRY_STATUS(init_db(db));

    db.exec("BEGIN TRANSACTION").ensure();
    // version == 0 ==> db will be destroyed
    TRY_STATUS(init_message_db(db, 0));
    db.exec("COMMIT TRANSACTION").ensure();

    message_db_sync_safe_ = td::create_message_db_sync(sql_connection_);
    message_db_async_ = td::create_message_db_async(message_db_sync_safe_, 0);
    return td::Status::OK();
  }
};

int main() {
  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(WARNING));
  td::bench(MessageDbBench());
}
