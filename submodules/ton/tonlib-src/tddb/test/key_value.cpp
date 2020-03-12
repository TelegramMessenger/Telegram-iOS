/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "td/utils/tests.h"

#include "td/db/KeyValueAsync.h"
#include "td/db/KeyValue.h"
#include "td/db/RocksDb.h"

#include "td/utils/benchmark.h"
#include "td/utils/buffer.h"
#include "td/utils/optional.h"
#include "td/utils/UInt.h"

TEST(KeyValue, simple) {
  td::Slice db_name = "testdb";
  td::RocksDb::destroy(db_name).ignore();

  std::unique_ptr<td::KeyValue> kv = std::make_unique<td::RocksDb>(td::RocksDb::open(db_name.str()).move_as_ok());
  auto set_value = [&](td::Slice key, td::Slice value) { kv->set(key, value); };
  auto ensure_value = [&](td::Slice key, td::Slice value) {
    std::string kv_value;
    auto status = kv->get(key, kv_value).move_as_ok();
    ASSERT_EQ(td::int32(status), td::int32(td::KeyValue::GetStatus::Ok));
    ASSERT_EQ(kv_value, value);
  };
  auto ensure_no_value = [&](td::Slice key) {
    std::string kv_value;
    auto status = kv->get(key, kv_value).move_as_ok();
    ASSERT_EQ(td::int32(status), td::int32(td::KeyValue::GetStatus::NotFound));
  };

  ensure_no_value("A");
  set_value("A", "HELLO");
  ensure_value("A", "HELLO");

  td::UInt128 x;
  std::fill(as_slice(x).begin(), as_slice(x).end(), '1');
  x.raw[5] = 0;
  set_value(as_slice(x), as_slice(x));
  ensure_value(as_slice(x), as_slice(x));

  kv.reset();
  kv = std::make_unique<td::RocksDb>(td::RocksDb::open(db_name.str()).move_as_ok());
  ensure_value("A", "HELLO");
  ensure_value(as_slice(x), as_slice(x));
};

TEST(KeyValue, async_simple) {
  td::Slice db_name = "testdb";
  td::RocksDb::destroy(db_name).ignore();

  td::actor::Scheduler scheduler({6});
  auto watcher = td::create_shared_destructor([] { td::actor::SchedulerContext::get()->stop(); });

  class Worker : public td::actor::Actor {
   public:
    Worker(std::shared_ptr<td::Destructor> watcher, std::string db_name)
        : watcher_(std::move(watcher)), db_name_(std::move(db_name)) {
    }
    void start_up() override {
      loop();
    }
    void tear_down() override {
    }
    void loop() override {
      if (!kv_) {
        kv_ = td::KeyValueAsync<td::UInt128, td::BufferSlice>(
            std::make_unique<td::RocksDb>(td::RocksDb::open(db_name_).move_as_ok()));
        set_start_at_ = td::Timestamp::now();
      }
      if (next_set_ && next_set_.is_in_past()) {
        for (size_t i = 0; i < 10 && left_cnt_ > 0; i++, left_cnt_--) {
          do_set();
        }
        if (left_cnt_ > 0) {
          next_set_ = td::Timestamp::in(0.001);
          alarm_timestamp() = next_set_;
        } else {
          next_set_ = td::Timestamp::never();
          set_finish_at_ = td::Timestamp::now();
        }
      }
    }

   private:
    std::shared_ptr<td::Destructor> watcher_;
    td::optional<td::KeyValueAsync<td::UInt128, td::BufferSlice>> kv_;
    std::string db_name_;
    int left_cnt_ = 10000;
    int pending_cnt_ = left_cnt_;
    td::Timestamp next_set_ = td::Timestamp::now();
    td::Timestamp set_start_at_;
    td::Timestamp set_finish_at_;

    void do_set() {
      td::UInt128 key;
      td::Random::secure_bytes(as_slice(key));
      td::BufferSlice data(1024);
      td::Random::secure_bytes(as_slice(data));
      kv_.value().set(key, std::move(data), [actor_id = actor_id(this)](td::Result<td::Unit> res) {
        res.ensure();
        send_closure(actor_id, &Worker::on_stored);
      });
    }

    void on_stored() {
      pending_cnt_--;
      if (pending_cnt_ == 0) {
        auto now = td::Timestamp::now();
        LOG(ERROR) << (now.at() - set_finish_at_.at());
        LOG(ERROR) << (set_finish_at_.at() - set_start_at_.at());
        stop();
      }
    }
  };

  scheduler.run_in_context([watcher = std::move(watcher), &db_name]() mutable {
    td::actor::create_actor<Worker>("Worker", watcher, db_name.str()).release();
    watcher.reset();
  });

  scheduler.run();
};

class KeyValueBenchmark : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "kv transation benchmark";
  }

  void start_up() override {
    td::RocksDb::destroy("ttt");
    db_ = td::RocksDb::open("ttt").move_as_ok();
  }
  void tear_down() override {
    db_ = {};
  }
  void run(int n) override {
    for (int i = 0; i < n; i++) {
      db_.value().begin_transaction();
      db_.value().set(PSLICE() << i, PSLICE() << i);
      db_.value().commit_transaction();
    }
  }

 private:
  td::optional<td::RocksDb> db_;
};

TEST(KeyValue, Bench) {
  td::bench(KeyValueBenchmark());
}

TEST(KeyValue, Stress) {
  return;
  td::Slice db_name = "testdb";
  size_t N = 20;
  auto db_name_i = [&](size_t i) { return PSTRING() << db_name << i; };
  for (size_t i = 0; i < N; i++) {
    td::RocksDb::destroy(db_name_i(i)).ignore();
  }

  td::actor::Scheduler scheduler({6});
  auto watcher = td::create_shared_destructor([] { td::actor::SchedulerContext::get()->stop(); });

  class Worker : public td::actor::Actor {
   public:
    Worker(std::shared_ptr<td::Destructor> watcher, std::string db_name)
        : watcher_(std::move(watcher)), db_name_(std::move(db_name)) {
    }
    void start_up() override {
      loop();
    }
    void tear_down() override {
    }
    void loop() override {
      if (stat_at_.is_in_past()) {
        stat_at_ = td::Timestamp::in(10);
        LOG(ERROR) << db_->stats();
      }
      if (!kv_) {
        db_ = std::make_shared<td::RocksDb>(td::RocksDb::open(db_name_).move_as_ok());
        kv_ = td::KeyValueAsync<td::UInt128, td::BufferSlice>(db_);
        set_start_at_ = td::Timestamp::now();
      }
      if (next_set_ && next_set_.is_in_past()) {
        for (size_t i = 0; i < 10 && left_cnt_ > 0; i++, left_cnt_--) {
          do_set();
        }
        if (left_cnt_ > 0) {
          next_set_ = td::Timestamp::in(0.01);
          alarm_timestamp() = next_set_;
        } else {
          next_set_ = td::Timestamp::never();
          set_finish_at_ = td::Timestamp::now();
        }
      }
    }

   private:
    std::shared_ptr<td::Destructor> watcher_;
    std::shared_ptr<td::RocksDb> db_;
    td::optional<td::KeyValueAsync<td::UInt128, td::BufferSlice>> kv_;
    std::string db_name_;
    int left_cnt_ = 1000000000;
    int pending_cnt_ = left_cnt_;
    td::Timestamp next_set_ = td::Timestamp::now();
    td::Timestamp set_start_at_;
    td::Timestamp set_finish_at_;
    td::Timestamp stat_at_ = td::Timestamp::in(10);

    void do_set() {
      td::UInt128 key = td::UInt128::zero();
      td::Random::secure_bytes(as_slice(key).substr(0, 1));
      td::BufferSlice data(1024);
      td::Random::secure_bytes(as_slice(data));
      kv_.value().set(key, std::move(data), [actor_id = actor_id(this)](td::Result<td::Unit> res) {
        res.ensure();
        send_closure(actor_id, &Worker::on_stored);
      });
    }

    void on_stored() {
      pending_cnt_--;
      if (pending_cnt_ == 0) {
        auto now = td::Timestamp::now();
        LOG(ERROR) << (now.at() - set_finish_at_.at());
        LOG(ERROR) << (set_finish_at_.at() - set_start_at_.at());
        stop();
      }
    }
  };
  scheduler.run_in_context([watcher = std::move(watcher), &db_name_i, &N]() mutable {
    for (size_t i = 0; i < N; i++) {
      td::actor::create_actor<Worker>("Worker", watcher, db_name_i(i)).release();
    }
    watcher.reset();
  });

  scheduler.run();
}
