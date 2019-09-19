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
#include "block-db.h"
#include "block-db-impl.h"
#include "block-binlog.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/misc.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/filesystem.h"
#include "vm/cellslice.h"
#include "vm/boc.h"
#include "vm/db/StaticBagOfCellsDb.h"

#include <limits>

namespace block {

//static constexpr std::string default_binlog_name = "blockdb";
//static constexpr std::string default_binlog_suffix = ".bin";

bool parse_hash_string(std::string arg, RootHash& res) {
  if (arg.size() != 64) {
    res.set_zero();
    return false;
  }
  int f = 1;
  unsigned char* ptr = res.data();
  for (char c : arg) {
    f <<= 4;
    if (c >= '0' && c <= '9') {
      f += c - '0';
    } else {
      c |= 0x20;
      if (c >= 'a' && c <= 'f') {
        f += c - ('a' - 10);
      } else {
        res.set_zero();
        return false;
      }
    }
    if (f >= 0x100) {
      *ptr++ = (unsigned char)f;
      f = 1;
    }
  }
  return true;
}

td::Result<td::BufferSlice> load_binary_file(std::string filename, td::int64 max_size) {
  //TODO: use td::read_file
  auto res = [&]() -> td::Result<td::BufferSlice> {
    TRY_RESULT(fd, td::FileFd::open(filename, td::FileFd::Read));
    TRY_RESULT(stat, fd.stat());
    if (!stat.is_reg_) {
      return td::Status::Error("file is not regular");
    }
    td::int64 size = stat.size_;
    if (!size) {
      return td::Status::Error("file is empty");
    }
    if ((max_size && size > max_size) || static_cast<td::uint64>(size) > std::numeric_limits<std::size_t>::max()) {
      return td::Status::Error("file is too long");
    }
    td::BufferSlice res(td::narrow_cast<std::size_t>(size));
    TRY_RESULT(r, fd.read(res.as_slice()));
    if (r != static_cast<td::uint64>(size)) {
      return td::Status::Error(PSLICE() << "read " << r << " bytes out of " << size);
    }
    return std::move(res);
  }();
  LOG_IF(ERROR, res.is_error()) << "error reading file `" << filename << "` : " << res.error();
  return res;
}

td::Status save_binary_file(std::string filename, const td::BufferSlice& data, unsigned long long max_size) {
  //TODO: use td::write_file
  auto status = [&]() {
    if (max_size && data.size() > max_size) {
      return td::Status::Error("contents too long");
    }
    auto size = data.size();
    TRY_RESULT(to_file, td::FileFd::open(filename, td::FileFd::CreateNew | td::FileFd::Write));
    TRY_RESULT(written, to_file.write(data));
    if (written != static_cast<size_t>(size)) {
      return td::Status::Error(PSLICE() << "written " << written << " bytes instead of " << size);
    }
    to_file.close();
    return td::Status::OK();
  }();
  LOG_IF(ERROR, status.is_error()) << "error writing new file `" << filename << "` : " << status;
  return status;
}

FileHash compute_file_hash(const td::BufferSlice& data) {
  ton::Bits256 data_hash;
  td::sha256(data, td::MutableSlice{data_hash.data(), 32});
  return data_hash;
}

FileHash compute_file_hash(td::Slice data) {
  ton::Bits256 data_hash;
  td::sha256(data, td::MutableSlice{data_hash.data(), 32});
  return data_hash;
}

/*
 * 
 *   ZEROSTATE CONFIGURATION
 * 
 */

td::Status ZerostateInfo::base_check() {
  if (!has_data()) {
    return td::Status::OK();
  }
  auto data_hash = compute_file_hash(data);
  if (!has_file_hash()) {
    file_hash = data_hash;
  } else if (file_hash != data_hash) {
    return td::Status::Error("zerostate file hash mismatch");
  }
  vm::BagOfCells boc;
  auto res = boc.deserialize(data);
  if (!res.is_ok() || boc.get_root_count() != 1) {
    return td::Status::Error("zerostate is not a valid bag of cells");  // not a valid bag-of-Cells
  }
  data_hash = boc.get_root_cell()->get_hash().bits();
  if (!has_root_hash()) {
    root_hash = data_hash;
  } else if (root_hash != data_hash) {
    return td::Status::Error("zerostate root hash mismatch");
  }
  return td::Status::OK();
}

/*
 * 
 *   BLOCK DATABASE 
 * 
 */

std::string compute_db_filename(std::string base_dir, const FileHash& file_hash, int depth) {
  static const char hex_digits[] = "0123456789ABCDEF";
  assert(depth >= 0 && depth <= 8);
  std::string res = std::move(base_dir);
  res.reserve(res.size() + 32 + depth * 3 + 4);
  for (int i = 0; i < depth; i++) {
    unsigned u = file_hash.data()[i];
    res.push_back(hex_digits[u >> 4]);
    res.push_back(hex_digits[u & 15]);
    res.push_back('/');
  }
  for (int i = 0; i < 32; i++) {
    unsigned u = file_hash.data()[i];
    res.push_back(hex_digits[u >> 4]);
    res.push_back(hex_digits[u & 15]);
  }
  res += ".boc";
  return res;
}

std::string BlockDbImpl::compute_db_filename(const FileHash& file_hash) const {
  return block::compute_db_filename(base_dir, file_hash, depth);
}

std::string compute_db_tmp_filename(std::string base_dir, const FileHash& file_hash, int i, bool makedirs, int depth) {
  static const char hex_digits[] = "0123456789ABCDEF";
  assert(depth >= 0 && depth <= 8);
  std::string res = std::move(base_dir);
  res.reserve(res.size() + 32 + depth * 3 + 4);
  for (int j = 0; j < depth; j++) {
    unsigned u = file_hash.data()[j];
    res.push_back(hex_digits[u >> 4]);
    res.push_back(hex_digits[u & 15]);
    res.push_back('/');
    if (makedirs) {
      td::mkdir(res, 0755).ignore();
    }
  }
  for (int j = 0; j < 32; j++) {
    unsigned u = file_hash.data()[j];
    res.push_back(hex_digits[u >> 4]);
    res.push_back(hex_digits[u & 15]);
  }
  res += ".tmp";
  if (i > 0) {
    if (i < 10) {
      res.push_back((char)('0' + i));
    } else {
      res.push_back((char)('0' + i / 10));
      res.push_back((char)('0' + i % 10));
    }
  }
  return res;
}

std::string BlockDbImpl::compute_db_tmp_filename(const FileHash& file_hash, int i, bool makedirs) const {
  return block::compute_db_tmp_filename(base_dir, file_hash, i, makedirs, depth);
}

bool BlockDbImpl::file_cache_insert(const FileHash& file_hash, const td::BufferSlice& data, int mode) {
  auto it = file_cache.find(file_hash);
  if (it != file_cache.end()) {
    // found
    return true;
  }
  auto res = file_cache.emplace(file_hash, data.clone());
  return res.second;
}

td::Status BlockDbImpl::save_db_file(const FileHash& file_hash, const td::BufferSlice& data, int fmode) {
  if (fmode & FMode::chk_file_hash && file_hash != compute_file_hash(data)) {
    return td::Status::Error("file hash passed for creation of a new file does not match contents");
  }
  std::string filename = compute_db_filename(file_hash);
  bool overwrite = false;
  auto r_stat = td::stat(filename);
  if (r_stat.is_ok()) {
    auto stat = r_stat.move_as_ok();
    // file exists
    if (fmode & FMode::fail_if_exists) {
      return td::Status::Error(PSLICE() << "file " << filename << " cannot be created, it already exists");
    }
    if (!(fmode & (FMode::chk_if_exists | FMode::overwrite))) {
      file_cache_insert(file_hash, data);
      return td::Status::OK();
    }
    if (fmode & FMode::chk_if_exists) {
      if (stat.size_ != (long long)data.size()) {
        LOG(ERROR) << "file " << filename << " already exists with wrong content";
        if (!(fmode & FMode::overwrite)) {
          return td::Status::Error(PSLICE() << "file " << filename << " already exists with wrong content");
        }
      } else if (fmode & FMode::chk_size_only) {
        file_cache_insert(file_hash, data);
        return td::Status::OK();
      } else {
        auto res = load_binary_file(filename);
        if (res.is_error()) {
          return res.move_as_error();
        }
        auto old_contents = res.move_as_ok();
        if (old_contents.size() != data.size() || old_contents.as_slice() != data.as_slice()) {
          LOG(ERROR) << "file " << filename << " already exists with wrong content";
          if (!(fmode & FMode::overwrite)) {
            return td::Status::Error(PSLICE() << "file " << filename << " already exists with wrong content");
          }
        } else {
          file_cache_insert(file_hash, data);
          return td::Status::OK();
        }
      }
    }
    overwrite = true;
  }
  std::string tmp_filename;
  for (int i = 0; i < 10; i++) {
    tmp_filename = compute_db_tmp_filename(file_hash, i, true);
    auto res = save_binary_file(tmp_filename, data);
    if (res.is_ok()) {
      break;
    }
    if (i == 9) {
      return res;
    }
  }
  auto rename_status = td::rename(tmp_filename, filename);
  if (rename_status.is_error()) {
    td::unlink(tmp_filename).ignore();
    LOG(ERROR) << rename_status;
    return rename_status;
  }
  if (overwrite) {
    LOG(DEBUG) << "database file `" << filename << "` overwritten, " << data.size() << " bytes";
  } else {
    LOG(DEBUG) << "new database file `" << filename << "` created, " << data.size() << " bytes";
  }
  file_cache_insert(file_hash, data);
  return td::Status::OK();
}

td::Result<td::actor::ActorOwn<BlockDb>> BlockDb::create_block_db(std::string base_dir,
                                                                  std::unique_ptr<ZerostateInfo> zstate,
                                                                  bool allow_uninit, int depth,
                                                                  std::string binlog_name) {
  using td::actor::ActorId;
  using td::actor::ActorOwn;
  td::Result<int> res;
  ActorOwn<BlockDbImpl> actor =
      td::actor::create_actor<BlockDbImpl>(td::actor::ActorOptions().with_name("BlockDB"), res, base_dir,
                                           std::move(zstate), allow_uninit, depth, binlog_name);
  if (res.is_error()) {
    return std::move(res).move_as_error();
  } else {
    return std::move(actor);
  }
}

BlockDbImpl::BlockDbImpl(td::Result<int>& _res, std::string _base_dir, std::unique_ptr<ZerostateInfo> _zstate,
                         bool _allow_uninit, int _depth, std::string _binlog_name)
    : status(0)
    , allow_uninit(_allow_uninit)
    , created(false)
    , depth(_depth)
    , zstate(std::move(_zstate))
    , base_dir(_base_dir)
    , binlog_name(_binlog_name)
    , bb(std::unique_ptr<BinlogCallback>(new BlockBinlogCallback(*this)))
    , created_at(0) {
  auto res = do_init();
  status = (res.is_ok() && res.ok() > 0 ? res.ok() : -1);
  if (res.is_error()) {
    _res = std::move(res);
  } else {
    _res = res.move_as_ok();
  }
}

td::Result<int> BlockDbImpl::do_init() {
  if (base_dir.empty()) {
    return td::Status::Error("block database cannot have empty base directory");
  }
  if (depth < 0 || depth >= 8) {
    return td::Status::Error("block database directory tree depth must be in range 0..8");
  }
  if (base_dir.back() != '/') {
    base_dir.push_back('/');
  }
  if (binlog_name.empty()) {
    binlog_name = default_binlog_name;
  }
  bool f = true;
  for (char c : binlog_name) {
    if (c == '.') {
      f = false;
    } else if (c == '/') {
      f = true;
    }
  }
  if (f) {
    binlog_name += default_binlog_suffix;
  }
  if (binlog_name.at(0) != '/') {
    binlog_name = base_dir + binlog_name;
  }
  if (zstate) {
    if (!zstate->has_data() && zstate->has_filename()) {
      auto data = load_binary_file(zstate->filename, 1 << 20);
      if (data.is_error()) {
        return data.move_as_error();
      }
      zstate->data = data.move_as_ok();
    }
    auto res = zstate->base_check();
    if (res.is_error()) {
      return res;
    }
  }
  try {
    auto res = bb.set_binlog(binlog_name, allow_uninit ? 3 : 1);
    if (res.is_error()) {
      return res;
    }
  } catch (BinlogBuffer::BinlogError& err) {
    return td::Status::Error(-2, std::string{"error while initializing block database binlog: "} + err.msg);
  } catch (BinlogBuffer::InterpretError& err) {
    return td::Status::Error(-3, std::string{"error while interpreting block database binlog: "} + err.msg);
  }
  return created;
}

BlockDbImpl::~BlockDbImpl() {
}

td::Status BlockDbImpl::init_from_zstate() {
  if (!zstate) {
    return td::Status::Error("no zero state provided, cannot initialize from scratch");
  }
  if (!zstate->has_data()) {
    if (zstate->has_filename() || zstate->has_file_hash()) {
      if (!zstate->has_filename()) {
        zstate->filename = compute_db_filename(zstate->file_hash);
      }
      auto res = load_binary_file(zstate->filename, 1 << 20);
      if (res.is_error()) {
        return res.move_as_error();
      }
      zstate->data = res.move_as_ok();
    } else {
      return td::Status::Error("cannot load zero state for block DB creation");
    }
  }
  auto res = zstate->base_check();
  if (res.is_error()) {
    return res;
  }
  assert(zstate->has_file_hash() && zstate->has_root_hash());
  res = save_db_file(zstate->file_hash, zstate->data, FMode::chk_if_exists | FMode::chk_file_hash);
  if (res.is_error()) {
    return res;
  }
  return res;
}

td::Status BlockBinlogCallback::init_new_binlog(BinlogBuffer& bb) {
  auto res = db.init_from_zstate();
  if (res.is_error()) {
    return res;
  }
  auto lev = bb.alloc<log::Start>(db.zstate->root_hash);
  assert(!lev.get_log_pos());
  auto lev2 = bb.alloc<log::SetZeroState>(db.zstate->root_hash, db.zstate->file_hash, db.zstate->data.size());
  lev.commit();
  lev2.commit();  // TODO: introduce multi-commit bb.commit(lev, lev2)
  bb.flush(3);
  db.created = true;
  return td::Status::OK();
}

#define REPLAY_CASE(__T) \
  case __T::tag:         \
    return try_interpret<__T>(ptr, len, log_pos);

int BlockBinlogCallback::replay_log_event(BinlogBuffer& bb, const unsigned* ptr, std::size_t len,
                                          unsigned long long log_pos) {
  assert(len >= 4);
  LOG(DEBUG) << "replay_log_event(" << len << ", " << log_pos << ", " << *ptr << ")";
  switch (*ptr) {
    REPLAY_CASE(log::Start);
    REPLAY_CASE(log::SetZeroState);
    REPLAY_CASE(log::NewBlock);
    REPLAY_CASE(log::NewState);
  }
  std::ostringstream ss;
  ss << "unknown binlog event 0x" << std::hex << *ptr << std::dec;
  LOG(ERROR) << ss.str() << " at position " << log_pos;
  throw BinlogBuffer::InterpretError{ss.str()};
}

#undef REPLAY_CASE

int BlockBinlogCallback::replay(const log::Start& lev, unsigned long long log_pos) const {
  LOG(DEBUG) << "in replay(Start{" << lev.tag_field << ", " << lev.type_field << ", " << lev.created_at << "})";
  if (lev.type_field != lev.log_type) {
    throw BinlogBuffer::InterpretError{(PSLICE() << "unsupported binlog type " << lev.type_field).str()};
  }
  if (log_pos) {
    throw BinlogBuffer::InterpretError{"LEV_START can only be the very first record in a binlog"};
  }
  db.zstate_rhash = lev.zerostate_root_hash;
  db.created_at = lev.created_at;
  if (db.zstate) {
    if (!db.zstate->has_root_hash()) {
      db.zstate->root_hash = db.zstate_rhash;
    } else if (db.zstate->root_hash != db.zstate_rhash) {
      throw BinlogBuffer::InterpretError{PSTRING() << "zerostate hash mismatch: in binlog " << db.zstate_rhash.to_hex()
                                                   << ", required " << db.zstate->root_hash.to_hex()};
    }
  }
  return 0;  // ok
}

int BlockBinlogCallback::replay(const log::SetZeroState& lev, unsigned long long log_pos) const {
  LOG(DEBUG) << "in replay(SetZeroState)";
  // LOG(DEBUG) << "db.zstate_rhash = " << db.zstate_rhash.to_hex();
  if (db.zstate_rhash != td::ConstBitPtr{lev.root_hash}) {
    throw BinlogBuffer::InterpretError{std::string{"SetZeroState: zerostate root hash mismatch: in binlog "} +
                                       ton::Bits256{lev.root_hash}.to_hex() + ", required " + db.zstate_rhash.to_hex()};
  }
  db.zerostate = td::Ref<FileInfo>{true,
                                   FileType::state,
                                   ton::BlockId{ton::masterchainId, 1ULL << 63, 0},
                                   0,
                                   td::as<FileHash>(lev.file_hash),
                                   td::as<RootHash>(lev.root_hash),
                                   lev.file_size};
  return 0;  // ok
}

int BlockBinlogCallback::replay(const log::NewBlock& lev, unsigned long long log_pos) const {
  LOG(DEBUG) << "in replay(NewBlock)";
  if (!lev.seqno || lev.workchain == ton::workchainInvalid) {
    return -1;
  }
  ton::BlockId blkid{lev.workchain, lev.shard, lev.seqno};
  auto blk_info = td::Ref<FileInfo>{true,
                                    FileType::block,
                                    blkid,
                                    lev.flags & 0xff,
                                    td::as<FileHash>(lev.file_hash),
                                    td::as<RootHash>(lev.root_hash),
                                    lev.file_size};
  auto res = db.update_block_info(blk_info);
  if (res.is_error()) {
    LOG(ERROR) << "cannot update block information in the local DB: " << res.to_string();
    return -1;
  } else {
    return 0;  // ok
  }
}

int BlockBinlogCallback::replay(const log::NewState& lev, unsigned long long log_pos) const {
  LOG(DEBUG) << "in replay(NewState)";
  if (!lev.seqno || lev.workchain == ton::workchainInvalid) {
    return -1;
  }
  ton::BlockId id{lev.workchain, lev.shard, lev.seqno};
  auto state_info = td::Ref<FileInfo>{true,
                                      FileType::state,
                                      id,
                                      lev.flags & 0xff,
                                      td::as<FileHash>(lev.file_hash),
                                      td::as<RootHash>(lev.root_hash),
                                      lev.file_size};
  auto res = db.update_state_info(state_info);
  if (res.is_error()) {
    LOG(ERROR) << "cannot update shardchain state information in the local DB: " << res.to_string();
    return -1;
  } else {
    return 0;  // ok
  }
}

td::Status BlockDbImpl::update_block_info(Ref<FileInfo> blk_info) {
  auto it = block_info.find(blk_info->blk.id);
  if (it != block_info.end()) {
    // already exists
    if (it->second->blk.file_hash != blk_info->blk.file_hash || it->second->blk.root_hash != blk_info->blk.root_hash) {
      return td::Status::Error(-666, std::string{"fatal error in block DB: block "} + blk_info->blk.id.to_str() +
                                         " has two records with different file or root hashes");
    } else {
      return td::Status::OK();
    }
  } else {
    auto id = blk_info->blk.id;
    auto res = block_info.emplace(std::move(id), std::move(blk_info));
    if (res.second) {
      return td::Status::OK();
    } else {
      return td::Status::Error(-666, "cannot insert block information into DB");
    }
  }
}

td::Status BlockDbImpl::update_state_info(Ref<FileInfo> state) {
  auto it = state_info.find(state->blk.id);
  if (it != state_info.end()) {
    // already exists
    if (it->second->blk.root_hash != state->blk.root_hash) {
      return td::Status::Error(-666, std::string{"fatal error in block DB: state for block "} + state->blk.id.to_str() +
                                         " has two records with different root hashes");
    } else {
      return td::Status::OK();
    }
  } else {
    auto id = state->blk.id;
    auto res = state_info.emplace(std::move(id), std::move(state));
    if (res.second) {
      return td::Status::OK();
    } else {
      return td::Status::Error(-666, "cannot insert state information into DB");
    }
  }
}

void BlockDbImpl::get_top_block_id(ton::ShardIdFull shard, int authority, td::Promise<ton::BlockIdExt> promise) {
  LOG(DEBUG) << "in BlockDb::get_top_block_id()";
  auto it = block_info.upper_bound(ton::BlockId{shard, std::numeric_limits<td::uint32>::max()});
  if (it != block_info.begin() && ton::ShardIdFull{(--it)->first} == shard) {
    promise(it->second->blk);
    return;
  }
  if (shard.is_masterchain()) {
    promise(ton::BlockIdExt{ton::BlockId{ton::masterchainId, 1ULL << 63, 0}});
    return;
  }
  promise(td::Status::Error(-666));
}

void BlockDbImpl::get_top_block_state_id(ton::ShardIdFull shard, int authority, td::Promise<ton::BlockIdExt> promise) {
  LOG(DEBUG) << "in BlockDb::get_top_block_state_id()";
  auto it = state_info.upper_bound(ton::BlockId{shard, std::numeric_limits<td::uint32>::max()});
  if (it != state_info.begin() && ton::ShardIdFull{(--it)->first} == shard) {
    promise(it->second->blk);
    return;
  }
  if (shard.is_masterchain() && zerostate.not_null()) {
    promise(zerostate->blk);
    return;
  }
  promise(td::Status::Error(-666, "no state for given workchain found in database"));
}

void BlockDbImpl::get_block_by_id(ton::BlockId blk_id, bool need_data, td::Promise<td::Ref<FileInfo>> promise) {
  LOG(DEBUG) << "in BlockDb::get_block_by_id({" << blk_id.workchain << ", " << blk_id.shard << ", " << blk_id.seqno
             << "}, " << need_data << ")";
  auto it = block_info.find(blk_id);
  if (it != block_info.end()) {
    if (need_data && it->second->data.is_null()) {
      LOG(DEBUG) << "loading data for block " << blk_id.to_str();
      auto res = load_data(it->second.write());
      if (res.is_error()) {
        promise(std::move(res));
        return;
      }
    }
    promise(it->second);
  }
  promise(td::Status::Error(-666, "block not found in database"));
}

void BlockDbImpl::get_state_by_id(ton::BlockId blk_id, bool need_data, td::Promise<td::Ref<FileInfo>> promise) {
  LOG(DEBUG) << "in BlockDb::get_state_by_id({" << blk_id.workchain << ", " << blk_id.shard << ", " << blk_id.seqno
             << "}, " << need_data << ")";
  auto it = state_info.find(blk_id);
  if (it != state_info.end()) {
    if (need_data && it->second->data.is_null()) {
      LOG(DEBUG) << "loading data for state " << blk_id.to_str();
      auto res = load_data(it->second.write());
      if (res.is_error()) {
        promise(std::move(res));
        return;
      }
    }
    promise(it->second);
  }
  if (zerostate.not_null() && blk_id == zerostate->blk.id) {
    LOG(DEBUG) << "get_state_by_id(): zerostate requested";
    if (need_data && zerostate->data.is_null()) {
      LOG(DEBUG) << "loading data for zerostate";
      auto res = load_data(zerostate.write());
      if (res.is_error()) {
        promise(std::move(res));
        return;
      }
    }
    promise(zerostate);
    return;
  }
  promise(td::Status::Error(-666, "requested state not found in database"));
}

void BlockDbImpl::get_out_queue_info_by_id(ton::BlockId blk_id, td::Promise<td::Ref<OutputQueueInfoDescr>> promise) {
  LOG(DEBUG) << "in BlockDb::get_out_queue_info_by_id({" << blk_id.workchain << ", " << blk_id.shard << ", "
             << blk_id.seqno << ")";
  auto it = state_info.find(blk_id);
  if (it == state_info.end()) {
    promise(td::Status::Error(
        -666, std::string{"cannot obtain output queue info for block "} + blk_id.to_str() + " : cannot load state"));
  }
  if (it->second->data.is_null()) {
    LOG(DEBUG) << "loading data for state " << blk_id.to_str();
    auto res = load_data(it->second.write());
    if (res.is_error()) {
      promise(std::move(res));
      return;
    }
  }
  auto it2 = block_info.find(blk_id);
  if (it2 == block_info.end()) {
    promise(td::Status::Error(-666, std::string{"cannot obtain output queue info for block "} + blk_id.to_str() +
                                        " : cannot load block description"));
  }
  vm::StaticBagOfCellsDbLazy::Options options;
  auto res = vm::StaticBagOfCellsDbLazy::create(it->second->data.clone(), options);
  if (res.is_error()) {
    td::Status err = res.move_as_error();
    LOG(ERROR) << "cannot deserialize state for block " << blk_id.to_str() << " : " << err.to_string();
    promise(std::move(err));
    return;
  }
  auto static_boc = res.move_as_ok();
  auto rc = static_boc->get_root_count();
  if (rc.is_error()) {
    promise(rc.move_as_error());
    return;
  }
  if (rc.move_as_ok() != 1) {
    promise(td::Status::Error(-668, std::string{"state for block "} + blk_id.to_str() + " is invalid"));
    return;
  }
  auto res3 = static_boc->get_root_cell(0);
  if (res3.is_error()) {
    promise(res3.move_as_error());
    return;
  }
  auto state_root = res3.move_as_ok();
  if (it->second->blk.root_hash != state_root->get_hash().bits()) {
    promise(td::Status::Error(
        -668, std::string{"state for block "} + blk_id.to_str() + " is invalid : state root hash mismatch"));
  }
  vm::CellSlice cs = vm::load_cell_slice(state_root);
  if (!cs.have(64, 1) || cs.prefetch_ulong(32) != 0x9023afde) {
    promise(td::Status::Error(-668, std::string{"state for block "} + blk_id.to_str() + " is invalid"));
  }
  auto out_queue_info = cs.prefetch_ref();
  promise(Ref<OutputQueueInfoDescr>{true, blk_id, it2->second->blk.root_hash.cbits(), state_root->get_hash().bits(),
                                    std::move(out_queue_info)});
}

void BlockDbImpl::get_object_by_file_hash(FileHash file_hash, bool need_data, bool force_file_load,
                                          td::Promise<td::Ref<FileInfo>> promise) {
  if (zerostate.not_null() && zerostate->blk.file_hash == file_hash) {
    if (need_data && zerostate->data.is_null()) {
      auto res = load_data(zerostate.write());
      if (res.is_error()) {
        promise(std::move(res));
        return;
      }
    }
    promise(zerostate);
    return;
  }
  promise(td::Status::Error(-666));
}

void BlockDbImpl::get_object_by_root_hash(RootHash root_hash, bool need_data, bool force_file_load,
                                          td::Promise<td::Ref<FileInfo>> promise) {
  if (zerostate.not_null() && zerostate->blk.root_hash == root_hash) {
    if (need_data && zerostate->data.is_null()) {
      auto res = load_data(zerostate.write());
      if (res.is_error()) {
        promise(std::move(res));
        return;
      }
    }
    promise(zerostate);
    return;
  }
  promise(td::Status::Error(-666));
}

void BlockDbImpl::save_new_block(ton::BlockIdExt id, td::BufferSlice data, int authority,
                                 td::Promise<td::Unit> promise) {
  // TODO: add verification that data is a BoC with correct root hash, and that it is a Block corresponding to blk_id
  // ...
  // TODO: check whether we already have a block with blk_id
  // ...
  auto save_res = save_db_file(id.file_hash, data, FMode::chk_if_exists | FMode::overwrite | FMode::chk_file_hash);
  if (save_res.is_error()) {
    promise(std::move(save_res));
  }
  auto sz = data.size();
  auto lev = bb.alloc<log::NewBlock>(id.id, id.root_hash, id.file_hash, data.size(), authority & 0xff);
  if (sz <= 8) {
    std::memcpy(lev->last_bytes, data.data(), sz);
  } else {
    std::memcpy(lev->last_bytes, data.data() + sz - 8, 8);
  }
  lev.commit();
  bb.flush();
  promise(td::Unit{});
}

void BlockDbImpl::save_new_state(ton::BlockIdExt id, td::BufferSlice data, int authority,
                                 td::Promise<td::Unit> promise) {
  // TODO: add verification that data is a BoC with correct root hash, and that it is a Block corresponding to blk_id
  // ...
  // TODO: check whether we already have a block with blk_id
  // ...
  auto save_res = save_db_file(id.file_hash, data, FMode::chk_if_exists | FMode::overwrite | FMode::chk_file_hash);
  if (save_res.is_error()) {
    promise(std::move(save_res));
  }
  auto sz = data.size();
  auto lev = bb.alloc<log::NewState>(id.id, id.root_hash, id.file_hash, data.size(), authority & 0xff);
  if (sz <= 8) {
    std::memcpy(lev->last_bytes, data.data(), sz);
  } else {
    std::memcpy(lev->last_bytes, data.data() + sz - 8, 8);
  }
  lev.commit();
  bb.flush();
  promise(td::Unit{});
}

td::Status BlockDbImpl::load_data(FileInfo& file_info, bool force) {
  if (!file_info.data.is_null() && !force) {
    return td::Status::OK();
  }
  if (file_info.blk.file_hash.is_zero()) {
    return td::Status::Error("cannot load a block file without knowing its file hash");
  }
  auto it = file_cache.find(file_info.blk.file_hash);
  if (it != file_cache.end() && !force) {
    file_info.data = it->second.clone();
    return td::Status::OK();
  }
  std::string filename = compute_db_filename(file_info.blk.file_hash);
  auto res = load_binary_file(filename);
  if (res.is_error()) {
    return res.move_as_error();
  }
  file_info.data = res.move_as_ok();
  file_cache_insert(file_info.blk.file_hash, file_info.data);
  return td::Status::OK();
}

FileInfo FileInfo::clone() const {
  return FileInfo{*this};
}

FileInfo::FileInfo(const FileInfo& other)
    : td::CntObject()
    , blk(other.blk)
    , type(other.type)
    , status(other.status)
    , file_size(other.file_size)
    , data(other.data.clone()) {
}

FileInfo* FileInfo::make_copy() const {
  return new FileInfo(*this);
}

}  // namespace block
