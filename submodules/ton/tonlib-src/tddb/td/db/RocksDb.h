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
#pragma once

#if !TDDB_USE_ROCKSDB
#error "RocksDb is not supported"
#endif

#include "td/db/KeyValue.h"
#include "td/utils/Status.h"

namespace rocksdb {
class OptimisticTransactionDB;
class Transaction;
class WriteBatch;
class Snapshot;
class Statistics;
}  // namespace rocksdb

namespace td {
class RocksDb : public KeyValue {
 public:
  static Status destroy(Slice path);
  RocksDb clone() const;
  static Result<RocksDb> open(std::string path);

  Result<GetStatus> get(Slice key, std::string &value) override;
  Status set(Slice key, Slice value) override;
  Status erase(Slice key) override;
  Result<size_t> count(Slice prefix) override;

  Status begin_transaction() override;
  Status commit_transaction() override;
  Status abort_transaction() override;
  Status flush() override;

  Status begin_snapshot();
  Status end_snapshot();

  std::unique_ptr<KeyValueReader> snapshot() override;
  std::string stats() const override;

  RocksDb(RocksDb &&);
  RocksDb &operator=(RocksDb &&);
  ~RocksDb();

 private:
  std::shared_ptr<rocksdb::OptimisticTransactionDB> db_;
  std::shared_ptr<rocksdb::Statistics> statistics_;

  std::unique_ptr<rocksdb::Transaction> transaction_;
  std::unique_ptr<rocksdb::WriteBatch> write_batch_;
  class UnreachableDeleter {
   public:
    template <class T>
    void operator()(T *) {
      UNREACHABLE();
    }
  };
  std::unique_ptr<const rocksdb::Snapshot, UnreachableDeleter> snapshot_;

  explicit RocksDb(std::shared_ptr<rocksdb::OptimisticTransactionDB> db,
                   std::shared_ptr<rocksdb::Statistics> statistics);
};
}  // namespace td
