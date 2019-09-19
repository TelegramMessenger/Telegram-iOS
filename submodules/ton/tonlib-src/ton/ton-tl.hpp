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

#include "ton-types.h"
#include "auto/tl/ton_api.h"

namespace ton {

inline tl_object_ptr<ton_api::tonNode_blockIdExt> create_tl_block_id(const BlockIdExt &block_id) {
  return create_tl_object<ton_api::tonNode_blockIdExt>(block_id.id.workchain, block_id.id.shard, block_id.id.seqno,
                                                       block_id.root_hash, block_id.file_hash);
}

inline BlockIdExt create_block_id(const tl_object_ptr<ton_api::tonNode_blockIdExt> &B) {
  return BlockIdExt{B->workchain_, static_cast<td::uint64>(B->shard_), static_cast<BlockSeqno>(B->seqno_),
                    B->root_hash_, B->file_hash_};
}

inline tl_object_ptr<ton_api::tonNode_blockId> create_tl_block_id_simple(const BlockId &block_id) {
  return create_tl_object<ton_api::tonNode_blockId>(block_id.workchain, block_id.shard, block_id.seqno);
}

inline BlockId create_block_id_simple(const tl_object_ptr<ton_api::tonNode_blockId> &B) {
  return BlockId{B->workchain_, static_cast<td::uint64>(B->shard_), static_cast<BlockSeqno>(B->seqno_)};
}

inline BlockIdExt empty_block_id() {
  return BlockIdExt{workchainIdNotYet, 0, 0, RootHash::zero(), FileHash::zero()};
}

inline tl_object_ptr<ton_api::tonNode_zeroStateIdExt> create_tl_zero_state_id(const ZeroStateIdExt &id) {
  return create_tl_object<ton_api::tonNode_zeroStateIdExt>(id.workchain, id.root_hash, id.file_hash);
}

inline ZeroStateIdExt create_zero_state_id(tl_object_ptr<ton_api::tonNode_zeroStateIdExt> &B) {
  return ZeroStateIdExt{B->workchain_, B->root_hash_, B->file_hash_};
}

}  // namespace ton
