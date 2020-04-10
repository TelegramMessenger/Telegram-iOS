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

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "vm/db/TonDb.h"

#include "td/utils/tl_helpers.h"
#include "td/utils/Random.h"

#if TDDB_USE_ROCKSDB
#include "td/db/RocksDb.h"
#endif

namespace vm {

template <class StorerT>
void SmartContractMeta::store(StorerT &storer) const {
  using td::store;
  store(stats.cells_total_count, storer);
  store(stats.cells_total_size, storer);
  store(type, storer);
}
template <class ParserT>
void SmartContractMeta::parse(ParserT &parser) {
  using td::parse;
  parse(stats.cells_total_count, parser);
  parse(stats.cells_total_size, parser);
  parse(type, parser);
}

//
// SmartContractDbImpl
//
Ref<Cell> SmartContractDbImpl::get_root() {
  if (sync_root_with_db_ || !new_root_.is_null()) {
    return new_root_;
  }

  sync_root_with_db();
  return new_root_;
}

void SmartContractDbImpl::set_root(Ref<Cell> new_root) {
  CHECK(new_root.not_null());
  sync_root_with_db();
  if (is_dynamic()) {
    cell_db_->dec(new_root_);
  }
  new_root_ = std::move(new_root);
  if (is_dynamic()) {
    cell_db_->inc(new_root_);
  }
}

SmartContractDbImpl::SmartContractDbImpl(td::Slice hash, std::shared_ptr<KeyValueReader> kv)
    : hash_(hash.str()), kv_(std::move(kv)) {
  cell_db_ = DynamicBagOfCellsDb::create();
}

SmartContractMeta SmartContractDbImpl::get_meta() {
  sync_root_with_db();
  return meta_;
}
td::Status SmartContractDbImpl::validate_meta() {
  if (!is_dynamic()) {
    return td::Status::OK();
  }
  sync_root_with_db();
  TRY_RESULT(in_db, kv_->count({}));
  if (static_cast<td::int64>(in_db) != meta_.stats.cells_total_count + 2) {
    return td::Status::Error(PSLICE() << "Invalid meta " << td::tag("expected_count", in_db)
                                      << td::tag("meta_count", meta_.stats.cells_total_count + 2));
  }
  return td::Status::OK();
}

bool SmartContractDbImpl::is_dynamic() const {
  return meta_.type == SmartContractMeta::Dynamic;
}

bool SmartContractDbImpl::is_root_changed() const {
  return !new_root_.is_null() && (db_root_.is_null() || db_root_->get_hash() != new_root_->get_hash());
}

void SmartContractDbImpl::sync_root_with_db() {
  if (sync_root_with_db_) {
    return;
  }
  std::string root_hash;
  kv_->get("root", root_hash);
  std::string meta_serialized;
  kv_->get("meta", meta_serialized);
  // TODO: proper serialization
  td::unserialize(meta_, meta_serialized).ignore();
  sync_root_with_db_ = true;

  if (root_hash.empty()) {
    meta_.type = SmartContractMeta::Static;
    //meta_.type = SmartContractMeta::Dynamic;
  } else {
    if (is_dynamic()) {
      //FIXME: error handling
      db_root_ = cell_db_->load_cell(root_hash).move_as_ok();
    } else {
      std::string boc_serialized;
      kv_->get("boc", boc_serialized);
      BagOfCells boc;
      //TODO: check error
      boc.deserialize(boc_serialized);
      db_root_ = boc.get_root_cell();
    }
    CHECK(db_root_->get_hash().as_slice() == root_hash);
    new_root_ = db_root_;
  }
}

enum { boc_size = 2000 };
void SmartContractDbImpl::prepare_commit_dynamic(bool force) {
  if (!is_dynamic()) {
    CHECK(force);
    meta_.stats = {};
    cell_db_->inc(new_root_);
  }
  cell_db_->prepare_commit();
  meta_.stats.apply_diff(cell_db_->get_stats_diff());

  if (!force && meta_.stats.cells_total_size < boc_size) {
    //LOG(ERROR) << "DYNAMIC -> BOC";
    return prepare_commit_static(true);
  }
  is_dynamic_commit_ = true;
};

void SmartContractDbImpl::prepare_commit_static(bool force) {
  BagOfCells boc;
  boc.add_root(new_root_);
  boc.import_cells().ensure();  // FIXME
  if (!force && boc.estimate_serialized_size(15) > boc_size) {
    //LOG(ERROR) << "BOC -> DYNAMIC ";
    return prepare_commit_dynamic(true);
  }
  if (is_dynamic()) {
    cell_db_->dec(new_root_);
    cell_db_->prepare_commit();
    // stats is invalid now
  }
  is_dynamic_commit_ = false;
  boc_to_commit_ = boc.serialize_to_string(15);
  meta_.stats = {};
}

void SmartContractDbImpl::prepare_transaction() {
  sync_root_with_db();
  if (!is_root_changed()) {
    return;
  }

  if (is_dynamic()) {
    prepare_commit_dynamic(false);
  } else {
    prepare_commit_static(false);
  }
}

void SmartContractDbImpl::commit_transaction(KeyValue &kv) {
  if (!is_root_changed()) {
    return;
  }

  if (is_dynamic_commit_) {
    //LOG(ERROR) << "STORE DYNAMIC";
    if (!is_dynamic() && db_root_.not_null()) {
      kv.erase("boc");
    }
    CellStorer storer(kv);
    cell_db_->commit(storer);
    meta_.type = SmartContractMeta::Dynamic;
  } else {
    //LOG(ERROR) << "STORE BOC";
    if (is_dynamic() && db_root_.not_null()) {
      //LOG(ERROR) << "Clear Dynamic db";
      CellStorer storer(kv);
      cell_db_->commit(storer);
      cell_db_ = DynamicBagOfCellsDb::create();
    }
    meta_.type = SmartContractMeta::Static;
    kv.set("boc", boc_to_commit_);
    boc_to_commit_ = {};
  }

  kv.set("root", new_root_->get_hash().as_slice());
  kv.set("meta", td::serialize(meta_));
  db_root_ = new_root_;
}

void SmartContractDbImpl::set_reader(std::shared_ptr<KeyValueReader> reader) {
  kv_ = std::move(reader);
  cell_db_->set_loader(std::make_unique<CellLoader>(kv_));
}

//
// TonDbTransactionImpl
//
SmartContractDb TonDbTransactionImpl::begin_smartcontract(td::Slice hash) {
  SmartContractDb res;
  contracts_.apply(hash, [&](auto &info) {
    if (!info.is_inited) {
      info.is_inited = true;
      info.hash = hash.str();
      info.smart_contract_db = std::make_unique<SmartContractDbImpl>(hash, nullptr);
    }
    LOG_CHECK(info.generation_ != generation_) << "Cannot begin one smartcontract twice during the same transaction";
    CHECK(info.smart_contract_db);
    info.smart_contract_db->set_reader(std::make_shared<td::PrefixedKeyValueReader>(reader_, hash));
    res = std::move(info.smart_contract_db);
  });
  return res;
}

void TonDbTransactionImpl::commit_smartcontract(SmartContractDb txn) {
  commit_smartcontract(SmartContractDiff(std::move(txn)));
}
void TonDbTransactionImpl::commit_smartcontract(SmartContractDiff txn) {
  {
    td::PrefixedKeyValue kv(kv_, txn.hash());
    txn.commit_transaction(kv);
  }
  end_smartcontract(txn.extract_smartcontract());
}

void TonDbTransactionImpl::abort_smartcontract(SmartContractDb txn) {
  end_smartcontract(std::move(txn));
}
void TonDbTransactionImpl::abort_smartcontract(SmartContractDiff txn) {
  end_smartcontract(txn.extract_smartcontract());
}

TonDbTransactionImpl::TonDbTransactionImpl(std::shared_ptr<KeyValue> kv) : kv_(std::move(kv)) {
  CHECK(kv_ != nullptr);
  reader_.reset(kv_->snapshot().release());
}

void TonDbTransactionImpl::begin() {
  kv_->begin_transaction();
  generation_++;
}
void TonDbTransactionImpl::commit() {
  kv_->commit_transaction();
  reader_.reset(kv_->snapshot().release());
}
void TonDbTransactionImpl::abort() {
  kv_->abort_transaction();
}
void TonDbTransactionImpl::clear_cache() {
  contracts_ = {};
}

void TonDbTransactionImpl::end_smartcontract(SmartContractDb smart_contract) {
  contracts_.apply(smart_contract->hash(), [&](auto &info) {
    CHECK(info.hash == smart_contract->hash());
    CHECK(!info.smart_contract_db);
    info.smart_contract_db = std::move(smart_contract);
  });
}

//
// TonDbImpl
//
TonDbImpl::TonDbImpl(std::unique_ptr<KeyValue> kv)
    : kv_(std::move(kv)), transaction_(std::make_unique<TonDbTransactionImpl>(kv_)) {
}
TonDbImpl::~TonDbImpl() {
  CHECK(transaction_);
  kv_->flush();
}
TonDbTransaction TonDbImpl::begin_transaction() {
  CHECK(transaction_);
  transaction_->begin();
  return std::move(transaction_);
}
void TonDbImpl::commit_transaction(TonDbTransaction transaction) {
  CHECK(!transaction_);
  CHECK(&transaction->kv() == kv_.get());
  transaction_ = std::move(transaction);
  transaction_->commit();
}
void TonDbImpl::abort_transaction(TonDbTransaction transaction) {
  CHECK(!transaction_);
  CHECK(&transaction->kv() == kv_.get());
  transaction_ = std::move(transaction);
  transaction_->abort();
}
void TonDbImpl::clear_cache() {
  CHECK(transaction_);
  transaction_->clear_cache();
}

std::string TonDbImpl::stats() const {
  return kv_->stats();
}

td::Result<TonDb> TonDbImpl::open(td::Slice path) {
#if TDDB_USE_ROCKSDB
  TRY_RESULT(rocksdb, td::RocksDb::open(path.str()));
  return std::make_unique<TonDbImpl>(std::make_unique<td::RocksDb>(std::move(rocksdb)));
#else
  return td::Status::Error("TonDb is not supported in this build");
#endif
}

}  // namespace vm
