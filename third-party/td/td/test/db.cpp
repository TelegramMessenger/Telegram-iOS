//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "data.h"

#include "td/db/binlog/BinlogHelper.h"
#include "td/db/binlog/ConcurrentBinlog.h"
#include "td/db/BinlogKeyValue.h"
#include "td/db/DbKey.h"
#include "td/db/SeqKeyValue.h"
#include "td/db/SqliteConnectionSafe.h"
#include "td/db/SqliteDb.h"
#include "td/db/SqliteKeyValue.h"
#include "td/db/SqliteKeyValueSafe.h"
#include "td/db/TsSeqKeyValue.h"

#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"

#include "td/utils/base64.h"
#include "td/utils/common.h"
#include "td/utils/filesystem.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/logging.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/thread.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tests.h"

#include <limits>
#include <map>
#include <memory>

template <class ContainerT>
static typename ContainerT::value_type &rand_elem(ContainerT &cont) {
  CHECK(0 < cont.size() && cont.size() <= static_cast<std::size_t>(std::numeric_limits<int>::max()));
  return cont[td::Random::fast(0, static_cast<int>(cont.size()) - 1)];
}

TEST(DB, binlog_encryption_bug) {
  td::CSlice binlog_name = "test_binlog";
  td::Binlog::destroy(binlog_name).ignore();

  auto cucumber = td::DbKey::password("cucu'\"mb er");
  auto empty = td::DbKey::empty();
  {
    td::Binlog binlog;
    binlog
        .init(
            binlog_name.str(), [&](const td::BinlogEvent &x) {}, cucumber)
        .ensure();
  }
  {
    td::Binlog binlog;
    binlog
        .init(
            binlog_name.str(), [&](const td::BinlogEvent &x) {}, cucumber)
        .ensure();
  }
  td::Binlog::destroy(binlog_name).ignore();
}

TEST(DB, binlog_encryption) {
  td::CSlice binlog_name = "test_binlog";
  td::Binlog::destroy(binlog_name).ignore();

  auto hello = td::DbKey::raw_key(td::string(32, 'A'));
  auto cucumber = td::DbKey::password("cucu'\"mb er");
  auto empty = td::DbKey::empty();
  auto long_data = td::string(10000, 'Z');
  {
    td::Binlog binlog;
    binlog.init(binlog_name.str(), [](const td::BinlogEvent &x) {}).ensure();
    binlog.add_raw_event(td::BinlogEvent::create_raw(binlog.next_event_id(), 1, 0, td::create_storer("AAAA")),
                         td::BinlogDebugInfo{__FILE__, __LINE__});
    binlog.add_raw_event(td::BinlogEvent::create_raw(binlog.next_event_id(), 1, 0, td::create_storer("BBBB")),
                         td::BinlogDebugInfo{__FILE__, __LINE__});
    binlog.add_raw_event(td::BinlogEvent::create_raw(binlog.next_event_id(), 1, 0, td::create_storer(long_data)),
                         td::BinlogDebugInfo{__FILE__, __LINE__});
    LOG(INFO) << "SET PASSWORD";
    binlog.change_key(cucumber);
    binlog.change_key(hello);
    LOG(INFO) << "OK";
    binlog.add_raw_event(td::BinlogEvent::create_raw(binlog.next_event_id(), 1, 0, td::create_storer("CCCC")),
                         td::BinlogDebugInfo{__FILE__, __LINE__});
    binlog.close().ensure();
  }

  td::Binlog::destroy(binlog_name).ignore();
  return;

  auto add_suffix = [&] {
    auto fd = td::FileFd::open(binlog_name, td::FileFd::Flags::Write | td::FileFd::Flags::Append).move_as_ok();
    fd.write("abacabadaba").ensure();
  };

  add_suffix();

  {
    td::vector<td::string> v;
    LOG(INFO) << "RESTART";
    td::Binlog binlog;
    binlog
        .init(
            binlog_name.str(), [&](const td::BinlogEvent &x) { v.push_back(x.get_data().str()); }, hello)
        .ensure();
    CHECK(v == td::vector<td::string>({"AAAA", "BBBB", long_data, "CCCC"}));
  }

  add_suffix();

  {
    td::vector<td::string> v;
    LOG(INFO) << "RESTART";
    td::Binlog binlog;
    auto status = binlog.init(
        binlog_name.str(), [&](const td::BinlogEvent &x) { v.push_back(x.get_data().str()); }, cucumber);
    CHECK(status.is_error());
  }

  add_suffix();

  {
    td::vector<td::string> v;
    LOG(INFO) << "RESTART";
    td::Binlog binlog;
    auto status = binlog.init(
        binlog_name.str(), [&](const td::BinlogEvent &x) { v.push_back(x.get_data().str()); }, cucumber, hello);
    CHECK(v == td::vector<td::string>({"AAAA", "BBBB", long_data, "CCCC"}));
  }

  td::Binlog::destroy(binlog_name).ignore();
}

TEST(DB, sqlite_lfs) {
  td::string path = "test_sqlite_db";
  td::SqliteDb::destroy(path).ignore();
  auto db = td::SqliteDb::open_with_key(path, true, td::DbKey::empty()).move_as_ok();
  db.exec("PRAGMA journal_mode=WAL").ensure();
  db.exec("PRAGMA user_version").ensure();
  td::SqliteDb::destroy(path).ignore();
}

TEST(DB, sqlite_encryption) {
  td::string path = "test_sqlite_db";
  td::SqliteDb::destroy(path).ignore();

  auto empty = td::DbKey::empty();
  auto cucumber = td::DbKey::password("cucu'\"mb er");
  auto tomato = td::DbKey::raw_key(td::string(32, 'a'));

  {
    auto db = td::SqliteDb::open_with_key(path, true, empty).move_as_ok();
    db.set_user_version(123).ensure();
    auto kv = td::SqliteKeyValue();
    kv.init_with_connection(db.clone(), "kv").ensure();
    kv.set("a", "b");
  }
  td::SqliteDb::open_with_key(path, false, cucumber).ensure_error();

  td::SqliteDb::change_key(path, false, cucumber, empty).ensure();
  td::SqliteDb::change_key(path, false, cucumber, empty).ensure();

  td::SqliteDb::open_with_key(path, false, tomato).ensure_error();
  {
    auto db = td::SqliteDb::open_with_key(path, false, cucumber).move_as_ok();
    auto kv = td::SqliteKeyValue();
    kv.init_with_connection(db.clone(), "kv").ensure();
    CHECK(kv.get("a") == "b");
    CHECK(db.user_version().ok() == 123);
  }

  td::SqliteDb::change_key(path, false, tomato, cucumber).ensure();
  td::SqliteDb::change_key(path, false, tomato, cucumber).ensure();

  td::SqliteDb::open_with_key(path, false, cucumber).ensure_error();
  {
    auto db = td::SqliteDb::open_with_key(path, false, tomato).move_as_ok();
    auto kv = td::SqliteKeyValue();
    kv.init_with_connection(db.clone(), "kv").ensure();
    CHECK(kv.get("a") == "b");
    CHECK(db.user_version().ok() == 123);
  }

  td::SqliteDb::change_key(path, false, empty, tomato).ensure();
  td::SqliteDb::change_key(path, false, empty, tomato).ensure();

  {
    auto db = td::SqliteDb::open_with_key(path, false, empty).move_as_ok();
    auto kv = td::SqliteKeyValue();
    kv.init_with_connection(db.clone(), "kv").ensure();
    CHECK(kv.get("a") == "b");
    CHECK(db.user_version().ok() == 123);
  }
  td::SqliteDb::open_with_key(path, false, cucumber).ensure_error();
  td::SqliteDb::destroy(path).ignore();
}

TEST(DB, sqlite_encryption_migrate_v3) {
  td::string path = "test_sqlite_db";
  td::SqliteDb::destroy(path).ignore();
  auto cucumber = td::DbKey::password("cucumber");
  auto empty = td::DbKey::empty();
  if (false) {
    // sqlite_sample_db was generated by the following code using SQLCipher based on SQLite 3.15.2
    {
      auto db = td::SqliteDb::change_key(path, true, cucumber, empty).move_as_ok();
      db.set_user_version(123).ensure();
      auto kv = td::SqliteKeyValue();
      kv.init_with_connection(db.clone(), "kv").ensure();
      kv.set("hello", "world");
    }
    LOG(ERROR) << td::base64_encode(td::read_file(path).move_as_ok());
  }
  td::write_file(path, td::base64_decode(td::Slice(sqlite_sample_db_v3, sqlite_sample_db_v3_size)).move_as_ok())
      .ensure();
  {
    auto db = td::SqliteDb::open_with_key(path, true, cucumber).move_as_ok();
    auto kv = td::SqliteKeyValue();
    kv.init_with_connection(db.clone(), "kv").ensure();
    CHECK(kv.get("hello") == "world");
    CHECK(db.user_version().ok() == 123);
  }
  td::SqliteDb::destroy(path).ignore();
}

TEST(DB, sqlite_encryption_migrate_v4) {
  td::string path = "test_sqlite_db";
  td::SqliteDb::destroy(path).ignore();
  auto cucumber = td::DbKey::password("cucu'\"mb er");
  auto empty = td::DbKey::empty();
  if (false) {
    // sqlite_sample_db was generated by the following code using SQLCipher 4.4.0
    {
      auto db = td::SqliteDb::change_key(path, true, cucumber, empty).move_as_ok();
      db.set_user_version(123).ensure();
      auto kv = td::SqliteKeyValue();
      kv.init_with_connection(db.clone(), "kv").ensure();
      kv.set("hello", "world");
    }
    LOG(ERROR) << td::base64_encode(td::read_file(path).move_as_ok());
  }
  td::write_file(path, td::base64_decode(td::Slice(sqlite_sample_db_v4, sqlite_sample_db_v4_size)).move_as_ok())
      .ensure();
  {
    auto r_db = td::SqliteDb::open_with_key(path, true, cucumber);
    if (r_db.is_error()) {
      LOG(ERROR) << r_db.error();
      return;
    }
    auto db = r_db.move_as_ok();
    auto kv = td::SqliteKeyValue();
    auto status = kv.init_with_connection(db.clone(), "kv");
    if (status.is_error()) {
      LOG(ERROR) << status;
    } else {
      CHECK(kv.get("hello") == "world");
      CHECK(db.user_version().ok() == 123);
    }
  }
  td::SqliteDb::destroy(path).ignore();
}

using SeqNo = td::uint64;
struct DbQuery {
  enum class Type { Get, Set, Erase, EraseBatch } type = Type::Get;
  SeqNo tid = 0;
  td::string key;
  td::string value;

  // for EraseBatch
  td::vector<td::string> erased_keys;
};

static td::StringBuilder &operator<<(td::StringBuilder &string_builder, const DbQuery &query) {
  string_builder << "seq_no = " << query.tid << ": ";
  switch (query.type) {
    case DbQuery::Type::Get:
      return string_builder << "Get " << query.key << " = " << query.value;
    case DbQuery::Type::Set:
      return string_builder << "Set " << query.key << " = " << query.value;
    case DbQuery::Type::Erase:
      return string_builder << "Del " << query.key;
    case DbQuery::Type::EraseBatch:
      return string_builder << "Del " << query.erased_keys;
    default:
      UNREACHABLE();
      return string_builder;
  }
}

template <class ImplT>
class QueryHandler {
 public:
  ImplT &impl() {
    return impl_;
  }
  void do_query(DbQuery &query) {
    switch (query.type) {
      case DbQuery::Type::Get:
        query.value = impl_.get(query.key);
        return;
      case DbQuery::Type::Set:
        impl_.set(query.key, query.value);
        query.tid = 1;
        return;
      case DbQuery::Type::Erase:
        impl_.erase(query.key);
        query.tid = 1;
        return;
      case DbQuery::Type::EraseBatch:
        impl_.erase_batch(query.erased_keys);
        query.tid = 1;
        return;
    }
  }

 private:
  ImplT impl_;
};

template <class ImplT>
class SeqQueryHandler {
 public:
  ImplT &impl() {
    return impl_;
  }
  void do_query(DbQuery &query) {
    switch (query.type) {
      case DbQuery::Type::Get:
        query.value = impl_.get(query.key);
        return;
      case DbQuery::Type::Set:
        query.tid = impl_.set(query.key, query.value);
        return;
      case DbQuery::Type::Erase:
        query.tid = impl_.erase(query.key);
        return;
      case DbQuery::Type::EraseBatch:
        query.tid = impl_.erase_batch(query.erased_keys);
        return;
    }
  }

 private:
  ImplT impl_;
};

class SqliteKV {
 public:
  td::string get(const td::string &key) {
    return kv_->get().get(key);
  }
  SeqNo set(const td::string &key, const td::string &value) {
    kv_->get().set(key, value);
    return 0;
  }
  SeqNo erase(const td::string &key) {
    kv_->get().erase(key);
    return 0;
  }
  SeqNo erase_batch(td::vector<td::string> keys) {
    for (auto &key : keys) {
      kv_->get().erase(key);
    }
    return 0;
  }
  td::Status init(const td::string &name) {
    auto sql_connection = std::make_shared<td::SqliteConnectionSafe>(name, td::DbKey::empty());
    kv_ = std::make_shared<td::SqliteKeyValueSafe>("kv", sql_connection);
    return td::Status::OK();
  }
  void close() {
    kv_.reset();
  }

 private:
  std::shared_ptr<td::SqliteKeyValueSafe> kv_;
};

class BaselineKV {
 public:
  td::string get(const td::string &key) {
    return map_[key];
  }
  SeqNo set(const td::string &key, td::string value) {
    map_[key] = std::move(value);
    return ++current_tid_;
  }
  SeqNo erase(const td::string &key) {
    map_.erase(key);
    return ++current_tid_;
  }
  SeqNo erase_batch(td::vector<td::string> keys) {
    for (auto &key : keys) {
      map_.erase(key);
    }
    SeqNo result = current_tid_ + 1;
    current_tid_ += map_.size();
    return result;
  }

 private:
  std::map<td::string, td::string> map_;
  SeqNo current_tid_ = 0;
};

TEST(DB, key_value) {
  td::vector<td::string> keys;
  td::vector<td::string> values;

  for (int i = 0; i < 100; i++) {
    keys.push_back(td::rand_string('a', 'b', td::Random::fast(1, 10)));
  }
  for (int i = 0; i < 10; i++) {
    values.push_back(td::rand_string('a', 'b', td::Random::fast(1, 10)));
  }

  int queries_n = 1000;
  td::vector<DbQuery> queries(queries_n);
  for (auto &q : queries) {
    int op = td::Random::fast(0, 3);
    const auto &key = rand_elem(keys);
    if (op == 0) {
      q.type = DbQuery::Type::Get;
      q.key = key;
    } else if (op == 1) {
      q.type = DbQuery::Type::Erase;
      q.key = key;
    } else if (op == 2) {
      q.type = DbQuery::Type::Set;
      q.key = key;
      q.value = rand_elem(values);
    } else if (op == 3) {
      q.type = DbQuery::Type::EraseBatch;
      q.erased_keys.resize(td::Random::fast(0, 3));
      for (auto &erased_key : q.erased_keys) {
        erased_key = rand_elem(keys);
      }
    }
  }

  QueryHandler<BaselineKV> baseline;
  QueryHandler<td::SeqKeyValue> kv;
  QueryHandler<td::TsSeqKeyValue> ts_kv;
  QueryHandler<td::BinlogKeyValue<td::Binlog>> new_kv;

  td::CSlice new_kv_name = "test_new_kv";
  td::Binlog::destroy(new_kv_name).ignore();
  new_kv.impl().init(new_kv_name.str()).ensure();

  QueryHandler<td::SqliteKeyValue> sqlite_kv;
  td::CSlice path = "test_sqlite_kv";
  td::SqliteDb::destroy(path).ignore();
  auto db = td::SqliteDb::open_with_key(path, true, td::DbKey::empty()).move_as_ok();
  sqlite_kv.impl().init_with_connection(std::move(db), "KV").ensure();

  int cnt = 0;
  for (auto &q : queries) {
    DbQuery a = q;
    DbQuery b = q;
    DbQuery c = q;
    DbQuery d = q;
    DbQuery e = q;
    baseline.do_query(a);
    kv.do_query(b);
    ts_kv.do_query(c);
    sqlite_kv.do_query(d);
    new_kv.do_query(e);
    ASSERT_EQ(a.value, b.value);
    ASSERT_EQ(a.value, c.value);
    ASSERT_EQ(a.value, d.value);
    ASSERT_EQ(a.value, e.value);
    if (cnt++ % 200 == 0) {
      new_kv.impl().init(new_kv_name.str()).ensure();
    }
  }
  td::SqliteDb::destroy(path).ignore();
  td::Binlog::destroy(new_kv_name).ignore();
}

TEST(DB, key_value_set_all) {
  td::vector<td::string> keys;
  td::vector<td::string> values;

  for (int i = 0; i < 100; i++) {
    keys.push_back(td::rand_string('a', 'b', td::Random::fast(1, 10)));
  }
  for (int i = 0; i < 10; i++) {
    values.push_back(td::rand_string('a', 'b', td::Random::fast(1, 10)));
  }

  td::SqliteKeyValue sqlite_kv;
  td::CSlice sqlite_kv_name = "test_sqlite_kv";
  td::SqliteDb::destroy(sqlite_kv_name).ignore();
  auto db = td::SqliteDb::open_with_key(sqlite_kv_name, true, td::DbKey::empty()).move_as_ok();
  sqlite_kv.init_with_connection(std::move(db), "KV").ensure();

  BaselineKV kv;

  int queries_n = 100;
  while (queries_n-- > 0) {
    int cnt = td::Random::fast(0, 10);
    td::FlatHashMap<td::string, td::string> key_values;
    for (int i = 0; i < cnt; i++) {
      auto key = rand_elem(keys);
      auto value = rand_elem(values);
      key_values[key] = value;
      kv.set(key, value);
    }

    sqlite_kv.set_all(key_values);

    for (auto &key : keys) {
      CHECK(kv.get(key) == sqlite_kv.get(key));
    }
  }
  td::SqliteDb::destroy(sqlite_kv_name).ignore();
}

#if !TD_THREAD_UNSUPPORTED
TEST(DB, thread_key_value) {
  td::vector<td::string> keys;
  td::vector<td::string> values;

  for (int i = 0; i < 100; i++) {
    keys.push_back(td::rand_string('a', 'b', td::Random::fast(1, 10)));
  }
  for (int i = 0; i < 1000; i++) {
    values.push_back(td::rand_string('a', 'b', td::Random::fast(1, 10)));
  }

  int threads_n = 4;
  int queries_n = 10000;

  td::vector<td::vector<DbQuery>> queries(threads_n, td::vector<DbQuery>(queries_n));
  for (auto &qs : queries) {
    for (auto &q : qs) {
      int op = td::Random::fast(0, 10);
      const auto &key = rand_elem(keys);
      if (op == 0) {
        q.type = DbQuery::Type::Erase;
        q.key = key;
      } else if (op == 1) {
        q.type = DbQuery::Type::EraseBatch;
        q.erased_keys.resize(td::Random::fast(0, 3));
        for (auto &erased_key : q.erased_keys) {
          erased_key = rand_elem(keys);
        }
      } else if (op <= 6) {
        q.type = DbQuery::Type::Set;
        q.key = key;
        q.value = rand_elem(values);
      } else {
        q.type = DbQuery::Type::Get;
        q.key = key;
      }
    }
  }

  QueryHandler<BaselineKV> baseline;
  SeqQueryHandler<td::TsSeqKeyValue> ts_kv;

  td::vector<td::thread> threads(threads_n);
  td::vector<td::vector<DbQuery>> res(threads_n);
  for (int i = 0; i < threads_n; i++) {
    threads[i] = td::thread([&ts_kv, &queries, &res, i] {
      for (auto q : queries[i]) {
        ts_kv.do_query(q);
        res[i].push_back(q);
      }
    });
  }
  for (auto &thread : threads) {
    thread.join();
  }

  td::vector<std::size_t> pos(threads_n);
  while (true) {
    bool was = false;
    for (int i = 0; i < threads_n; i++) {
      auto p = pos[i];
      if (p == res[i].size()) {
        continue;
      }
      auto &q = res[i][p];
      if (q.tid == 0) {
        if (q.type == DbQuery::Type::Get) {
          auto nq = q;
          baseline.do_query(nq);
          if (nq.value == q.value) {
            was = true;
            pos[i]++;
          }
        } else {
          was = true;
          pos[i]++;
        }
      }
    }
    if (was) {
      continue;
    }

    int best = -1;
    SeqNo best_tid = 0;
    for (int i = 0; i < threads_n; i++) {
      auto p = pos[i];
      if (p == res[i].size()) {
        continue;
      }
      was = true;
      auto &q = res[i][p];
      if (q.tid != 0) {
        if (best == -1 || q.tid < best_tid) {
          best = i;
          best_tid = q.tid;
        }
      }
    }
    if (!was) {
      break;
    }
    ASSERT_TRUE(best != -1);
    baseline.do_query(res[best][pos[best]]);
    pos[best]++;
  }
}
#endif

TEST(DB, persistent_key_value) {
  using KeyValue = td::BinlogKeyValue<td::ConcurrentBinlog>;
  // using KeyValue = td::SqliteKeyValue;
  td::vector<td::string> keys;
  td::vector<td::string> values;
  td::CSlice path = "test_pmc";
  td::Binlog::destroy(path).ignore();
  td::SqliteDb::destroy(path).ignore();

  for (int i = 0; i < 100; i++) {
    keys.push_back(td::rand_string('a', 'b', td::Random::fast(1, 10)));
  }
  for (int i = 0; i < 1000; i++) {
    values.push_back(td::rand_string('a', 'b', td::Random::fast(1, 10)));
  }

  QueryHandler<BaselineKV> baseline;

  for (int iter = 0; iter < 25; iter++) {
    int threads_n = 4;
    int queries_n = 3000 / threads_n;

    td::vector<td::vector<DbQuery>> queries(threads_n, td::vector<DbQuery>(queries_n));
    for (auto &qs : queries) {
      for (auto &q : qs) {
        int op = td::Random::fast(0, 10);
        const auto &key = rand_elem(keys);
        if (op == 0) {
          q.type = DbQuery::Type::Erase;
          q.key = key;
        } else if (op == 1) {
          q.type = DbQuery::Type::EraseBatch;
          q.erased_keys.resize(td::Random::fast(0, 3));
          for (auto &erased_key : q.erased_keys) {
            erased_key = rand_elem(keys);
          }
        } else if (op <= 6) {
          q.type = DbQuery::Type::Set;
          q.key = key;
          q.value = rand_elem(values);
        } else {
          q.type = DbQuery::Type::Get;
          q.key = key;
        }
      }
    }

    td::vector<td::vector<DbQuery>> res(threads_n);
    class Worker final : public td::Actor {
     public:
      Worker(td::ActorShared<> parent, std::shared_ptr<SeqQueryHandler<KeyValue>> kv,
             const td::vector<DbQuery> *queries, td::vector<DbQuery> *res)
          : parent_(std::move(parent)), kv_(std::move(kv)), queries_(queries), res_(res) {
      }
      void loop() final {
        for (auto q : *queries_) {
          kv_->do_query(q);
          res_->push_back(q);
        }
        stop();
      }

     private:
      td::ActorShared<> parent_;
      std::shared_ptr<SeqQueryHandler<KeyValue>> kv_;
      const td::vector<DbQuery> *queries_;
      td::vector<DbQuery> *res_;
    };
    class Main final : public td::Actor {
     public:
      Main(int threads_n, const td::vector<td::vector<DbQuery>> *queries, td::vector<td::vector<DbQuery>> *res)
          : threads_n_(threads_n), queries_(queries), res_(res), ref_cnt_(threads_n) {
      }

      void start_up() final {
        LOG(INFO) << "Start up";
        kv_->impl().init("test_pmc").ensure();
        for (int i = 0; i < threads_n_; i++) {
          td::create_actor_on_scheduler<Worker>("Worker", i + 1, actor_shared(this, 2), kv_, &queries_->at(i),
                                                &res_->at(i))
              .release();
        }
      }

      void tear_down() final {
        LOG(INFO) << "Tear down";
        // kv_->impl().close();
      }
      void hangup_shared() final {
        LOG(INFO) << "Hang up";
        ref_cnt_--;
        if (ref_cnt_ == 0) {
          kv_->impl().close();
          td::Scheduler::instance()->finish();
          stop();
        }
      }
      void hangup() final {
        LOG(ERROR) << "BAD HANGUP";
      }

     private:
      int threads_n_;
      const td::vector<td::vector<DbQuery>> *queries_;
      td::vector<td::vector<DbQuery>> *res_;

      std::shared_ptr<SeqQueryHandler<KeyValue>> kv_{new SeqQueryHandler<KeyValue>()};
      int ref_cnt_;
    };

    td::ConcurrentScheduler sched(threads_n, 0);
    sched.create_actor_unsafe<Main>(0, "Main", threads_n, &queries, &res).release();
    sched.start();
    while (sched.run_main(10)) {
      // empty
    }
    sched.finish();

    td::vector<std::size_t> pos(threads_n);
    while (true) {
      bool was = false;
      for (int i = 0; i < threads_n; i++) {
        auto p = pos[i];
        if (p == res[i].size()) {
          continue;
        }
        auto &q = res[i][p];
        if (q.tid == 0) {
          if (q.type == DbQuery::Type::Get) {
            auto nq = q;
            baseline.do_query(nq);
            if (nq.value == q.value) {
              was = true;
              pos[i]++;
            }
          } else {
            was = true;
            pos[i]++;
          }
        }
      }
      if (was) {
        continue;
      }
      LOG(DEBUG) << pos;

      int best = -1;
      SeqNo best_tid = 0;
      for (int i = 0; i < threads_n; i++) {
        auto p = pos[i];
        if (p == res[i].size()) {
          continue;
        }
        was = true;
        auto &q = res[i][p];
        LOG(DEBUG) << i << ' ' << p << ' ' << q;
        if (q.tid != 0) {
          if (best == -1 || q.tid < best_tid) {
            best = i;
            best_tid = q.tid;
          }
        }
      }
      if (!was) {
        break;
      }
      ASSERT_TRUE(best != -1);
      baseline.do_query(res[best][pos[best]]);
      pos[best]++;
    }
  }
  td::SqliteDb::destroy(path).ignore();
}
