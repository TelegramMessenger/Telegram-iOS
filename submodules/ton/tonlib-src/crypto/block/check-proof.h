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

#include "vm/cells.h"
#include "block/block.h"

namespace block {
using td::Ref;

td::Status check_block_header_proof(td::Ref<vm::Cell> root, ton::BlockIdExt blkid,
                                    ton::Bits256* store_shard_hash_to = nullptr, bool check_state_hash = false,
                                    td::uint32* save_utime = nullptr, ton::LogicalTime* save_lt = nullptr);
td::Status check_shard_proof(ton::BlockIdExt blk, ton::BlockIdExt shard_blk, td::Slice shard_proof);
td::Status check_account_proof(td::Slice proof, ton::BlockIdExt shard_blk, const block::StdAddress& addr,
                               td::Ref<vm::Cell> root, ton::LogicalTime* last_trans_lt = nullptr,
                               ton::Bits256* last_trans_hash = nullptr, td::uint32* save_utime = nullptr,
                               ton::LogicalTime* save_lt = nullptr);
td::Result<td::Bits256> check_state_proof(ton::BlockIdExt blkid, td::Slice proof);
td::Result<Ref<vm::Cell>> check_extract_state_proof(ton::BlockIdExt blkid, td::Slice proof, td::Slice data);

td::Status check_block_signatures(const std::vector<ton::ValidatorDescr>& nodes,
                                  const std::vector<ton::BlockSignature>& signatures, const ton::BlockIdExt& blkid);

struct AccountState {
  ton::BlockIdExt blk;
  ton::BlockIdExt shard_blk;
  td::BufferSlice shard_proof;
  td::BufferSlice proof;
  td::BufferSlice state;

  struct Info {
    td::Ref<vm::Cell> root;
    ton::LogicalTime last_trans_lt = 0;
    ton::Bits256 last_trans_hash;
    ton::LogicalTime gen_lt{0};
    td::uint32 gen_utime{0};
  };

  td::Result<Info> validate(ton::BlockIdExt ref_blk, block::StdAddress addr) const;
};

struct Transaction {
  ton::BlockIdExt blkid;
  ton::LogicalTime lt;
  ton::Bits256 hash;
  td::Ref<vm::Cell> root;

  struct Info {
    ton::BlockIdExt blkid;
    td::uint32 now;
    ton::LogicalTime prev_trans_lt;
    ton::Bits256 prev_trans_hash;
    td::Ref<vm::Cell> transaction;
  };
  td::Result<Info> validate();
};

struct TransactionList {
  ton::LogicalTime lt;
  ton::Bits256 hash;
  std::vector<ton::BlockIdExt> blkids;
  td::BufferSlice transactions_boc;

  struct Info {
    ton::LogicalTime lt;
    ton::Bits256 hash;
    std::vector<Transaction::Info> transactions;
  };

  td::Result<Info> validate() const;
};

}  // namespace block
