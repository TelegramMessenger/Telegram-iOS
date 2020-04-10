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
#pragma once
#include <string>
#include <map>
#include "vm/cells.h"
#include "block/Binlog.h"
#include "block/block-db.h"
#include "block/block-binlog.h"

namespace block {
using td::Ref;

/*
 * 
 *   BLOCK DATABASE
 * 
 */

class BlockDbImpl;

class BlockBinlogCallback : public BinlogCallback {
  BlockDbImpl& db;
  td::Status init_new_binlog(BinlogBuffer& bb) override;
  int replay_log_event(BinlogBuffer& bb, const unsigned* ptr, std::size_t len, unsigned long long log_pos) override;
  int replay(const block::log::Start& lev, unsigned long long log_pos) const;
  int replay(const block::log::SetZeroState& lev, unsigned long long log_pos) const;
  int replay(const block::log::NewBlock& lev, unsigned long long log_pos) const;
  int replay(const block::log::NewState& lev, unsigned long long log_pos) const;
  template <typename T>
  inline int try_interpret(const unsigned* ptr, std::size_t len, unsigned long long log_pos);

 public:
  BlockBinlogCallback(BlockDbImpl& _db) : db(_db) {
  }
};

template <typename T>
inline int BlockBinlogCallback::try_interpret(const unsigned* ptr, std::size_t len, unsigned long long log_pos) {
  if (len < sizeof(T)) {
    return 0x80000000 + sizeof(T);
  } else {
    int res = replay(*reinterpret_cast<const T*>(ptr), log_pos);
    return res >= 0 ? sizeof(T) : res;
  }
}

class BlockDbImpl final : public BlockDb {
  int status;
  bool allow_uninit;
  bool created;
  int depth;
  std::unique_ptr<ZerostateInfo> zstate;
  std::string base_dir;
  std::string binlog_name;
  BinlogBuffer bb;
  ton::Bits256 zstate_rhash, zstate_fhash;
  unsigned created_at;
  std::map<ton::FileHash, td::BufferSlice> file_cache;
  std::map<ton::BlockId, Ref<FileInfo>> block_info;
  std::map<ton::BlockId, Ref<FileInfo>> state_info;
  //
  td::Result<int> do_init();

 public:
  enum FMode {
    chk_none = 0,
    chk_if_exists = 1,
    fail_if_exists = 2,
    overwrite = 4,
    chk_size_only = 16,
    chk_file_hash = 32
  };
  static constexpr const char* default_binlog_name = "blockdb";
  static constexpr const char* default_binlog_suffix = ".bin";
  static constexpr int default_depth = 4;
  BlockDbImpl(td::Result<int>& _res, std::string _base_dir, std::unique_ptr<ZerostateInfo> _zstate = nullptr,
              bool _allow_uninit = false, int _depth = 4, std::string _binlog_name = "");
  ~BlockDbImpl();
  bool ok() const {
    return status >= 0;
  }
  bool initialized() const {
    return status != 0;
  }
  bool init_ok() const {
    return status > 0;
  }

 protected:
  friend class BlockBinlogCallback;
  td::Ref<FileInfo> zerostate;
  td::Status init_from_zstate();
  td::Status update_block_info(Ref<FileInfo> blk_info);
  td::Status update_state_info(Ref<FileInfo> state);

 private:
  std::string compute_db_filename(const FileHash& file_hash) const;
  std::string compute_db_tmp_filename(const FileHash& file_hash, int i, bool makedirs) const;
  td::Status save_db_file(const FileHash& file_hash, const td::BufferSlice& data, int fmode = 0);
  td::Status load_data(FileInfo& file_info, bool force = false);
  // actor BlockDb implementation
  void get_top_block_id(ton::ShardIdFull shard, int authority, td::Promise<ton::BlockIdExt> promise) override;
  void get_top_block_state_id(ton::ShardIdFull shard, int authority, td::Promise<ton::BlockIdExt> promise) override;
  void get_block_by_id(ton::BlockId blk_id, bool need_data, td::Promise<td::Ref<FileInfo>> promise) override;
  void get_state_by_id(ton::BlockId blk_id, bool need_data, td::Promise<td::Ref<FileInfo>> promise) override;
  void get_out_queue_info_by_id(ton::BlockId blk_id, td::Promise<td::Ref<OutputQueueInfoDescr>> promise) override;
  void get_object_by_file_hash(FileHash file_hash, bool need_data, bool force_file_load,
                               td::Promise<td::Ref<FileInfo>> promise) override;
  void get_object_by_root_hash(RootHash root_hash, bool need_data, bool force_file_load,
                               td::Promise<td::Ref<FileInfo>> promise) override;
  void save_new_block(ton::BlockIdExt blk_id, td::BufferSlice data, int authority,
                      td::Promise<td::Unit> promise) override;
  void save_new_state(ton::BlockIdExt state_id, td::BufferSlice data, int authority,
                      td::Promise<td::Unit> promise) override;
  bool file_cache_insert(const FileHash& file_hash, const td::BufferSlice& data, int mode = 0);
};

}  // namespace block
