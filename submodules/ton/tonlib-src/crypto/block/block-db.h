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
#include "td/utils/int_types.h"
#include "td/utils/buffer.h"
#include "td/actor/actor.h"
#include "ton/ton-types.h"
#include "crypto/common/refcnt.hpp"
#include "crypto/vm/cells.h"

namespace block {

using FileHash = ton::Bits256;
using RootHash = ton::Bits256;
using td::Ref;

struct ZerostateInfo {
  td::BufferSlice data;
  std::string filename;
  FileHash file_hash;
  RootHash root_hash;
  ZerostateInfo() {
    file_hash.set_zero();
    root_hash.set_zero();
  }
  ZerostateInfo(RootHash hash, std::string _filename) : filename(_filename), root_hash(std::move(hash)) {
    file_hash.set_zero();
  }
  ZerostateInfo(std::string _filename) : filename(_filename) {
    file_hash.set_zero();
    root_hash.set_zero();
  }
  ZerostateInfo(RootHash hash, FileHash fhash) : file_hash(std::move(fhash)), root_hash(std::move(hash)) {
  }
  bool has_file_hash() const {
    return !file_hash.is_zero();
  }
  bool has_root_hash() const {
    return !root_hash.is_zero();
  }
  bool has_filename() const {
    return !filename.empty();
  }
  bool has_data() const {
    return !data.empty();
  }
  td::Status base_check();
};

enum class FileType {
  unknown = 0,
  unknown_boc = 1,
  block = 2,
  block_candidate = 3,
  collated_data = 4,
  block_signatures = 5,
  state = 6,
  out_queue = 7
};

struct FileInfo : public td::CntObject {
  ton::BlockIdExt blk;
  FileType type;
  int status;
  long long file_size;
  td::BufferSlice data;
  FileInfo() : type(FileType::unknown), status(0), file_size(-1) {
    blk.file_hash.set_zero();
    blk.root_hash.set_zero();
  }
  FileInfo(FileType _type, const ton::BlockId& _id, int _status, const FileHash& _fhash, long long _fsize = -1)
      : blk(_id, _fhash), type(_type), status(_status), file_size(_fsize) {
    blk.root_hash.set_zero();
  }
  FileInfo(FileType _type, const ton::BlockId& _id, int _status, const FileHash& _fhash, const RootHash& _rhash,
           long long _fsize = -1)
      : blk(_id, _rhash, _fhash), type(_type), status(_status), file_size(_fsize) {
  }
  FileInfo(FileType _type, const ton::BlockId& _id, int _status, const FileHash& _fhash, const RootHash& _rhash,
           td::BufferSlice _data)
      : blk(_id, _rhash, _fhash), type(_type), status(_status), file_size(_data.size()), data(std::move(_data)) {
  }
  FileInfo(FileInfo&& other) = default;
  FileInfo clone() const;
  FileInfo* make_copy() const override;

 private:
  FileInfo(const FileInfo& other);
};

struct OutputQueueInfoDescr : public td::CntObject {
  ton::BlockId id;
  RootHash block_hash;
  RootHash state_hash;
  RootHash output_queue_info_hash;
  td::Ref<vm::Cell> queue_info;
  OutputQueueInfoDescr(ton::BlockId _id, const RootHash& _bhash, const RootHash& _shash, Ref<vm::Cell> _qinfo)
      : id(_id)
      , block_hash(_bhash)
      , state_hash(_shash)
      , output_queue_info_hash(_qinfo->get_hash().bits())
      , queue_info(std::move(_qinfo)) {
  }
  OutputQueueInfoDescr(ton::BlockId _id, td::ConstBitPtr _bhash, td::ConstBitPtr _shash, Ref<vm::Cell> _qinfo)
      : id(_id)
      , block_hash(_bhash)
      , state_hash(_shash)
      , output_queue_info_hash(_qinfo->get_hash().bits())
      , queue_info(std::move(_qinfo)) {
  }
};

class BlockDb : public td::actor::Actor {
 public:
  BlockDb() = default;
  virtual ~BlockDb() = default;
  static td::Result<td::actor::ActorOwn<BlockDb>> create_block_db(std::string _base_dir,
                                                                  std::unique_ptr<ZerostateInfo> _zstate = nullptr,
                                                                  bool _allow_uninit = false, int _depth = 4,
                                                                  std::string _binlog_name = "");
  // authority: 0 = standard (inclusion in mc block), 1 = validator (by 2/3 validator signatures)
  virtual void get_top_block_id(ton::ShardIdFull shard, int authority, td::Promise<ton::BlockIdExt> promise) = 0;
  virtual void get_top_block_state_id(ton::ShardIdFull shard, int authority, td::Promise<ton::BlockIdExt> promise) = 0;
  virtual void get_block_by_id(ton::BlockId blk_id, bool need_data, td::Promise<td::Ref<FileInfo>> promise) = 0;
  virtual void get_state_by_id(ton::BlockId blk_id, bool need_data, td::Promise<td::Ref<FileInfo>> promise) = 0;
  virtual void get_out_queue_info_by_id(ton::BlockId blk_id, td::Promise<td::Ref<OutputQueueInfoDescr>> promise) = 0;
  virtual void get_object_by_file_hash(FileHash file_hash, bool need_data, bool force_file_load,
                                       td::Promise<td::Ref<FileInfo>> promise) = 0;
  virtual void get_object_by_root_hash(RootHash root_hash, bool need_data, bool force_file_load,
                                       td::Promise<td::Ref<FileInfo>> promise) = 0;
  virtual void save_new_block(ton::BlockIdExt blk_id, td::BufferSlice data, int authority,
                              td::Promise<td::Unit> promise) = 0;
  virtual void save_new_state(ton::BlockIdExt state_id, td::BufferSlice data, int authority,
                              td::Promise<td::Unit> promise) = 0;
};

bool parse_hash_string(std::string arg, RootHash& res);

FileHash compute_file_hash(const td::BufferSlice& data);
FileHash compute_file_hash(td::Slice data);
td::Result<td::BufferSlice> load_binary_file(std::string filename, td::int64 max_size = 0);
td::Status save_binary_file(std::string filename, const td::BufferSlice& data, unsigned long long max_size = 0);

std::string compute_db_filename(std::string base_dir, const FileHash& file_hash, int depth = 4);
std::string compute_db_tmp_filename(std::string base_dir, const FileHash& file_hash, int i = 0, bool makedirs = true,
                                    int depth = 4);

}  // namespace block
