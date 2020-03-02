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

#include "crypto/common/bitstring.h"
#include "td/utils/buffer.h"
#include "td/utils/bits.h"
#include "td/utils/Slice.h"
#include "td/utils/UInt.h"
#include "td/utils/misc.h"

#include <cinttypes>

namespace ton {

using WorkchainId = td::int32;
constexpr WorkchainId workchainIdNotYet = (1U << 31);
using ShardId = td::uint64;  // prefix a of length l encoded as ((2 * a + 1) << (63 - l))
using AccountIdPrefix = td::uint64;
using BlockSeqno = td::uint32;      // usually >= 1; 0 used to indicate the initial state ("zerostate")
using Bits256 = td::BitArray<256>;  // was: td::UInt256
using BlockHash = Bits256;
using RootHash = Bits256;
using FileHash = Bits256;
using NodeIdShort = Bits256;    // compatible with adnl::AdnlNodeIdShort
using StdSmcAddress = Bits256;  // masterchain / base workchain smart-contract addresses
using UnixTime = td::uint32;
using LogicalTime = td::uint64;
using ValidatorWeight = td::uint64;  // was td::uint32 before
using CatchainSeqno = td::uint32;

using ValidatorSessionId = td::Bits256;

constexpr WorkchainId masterchainId = -1, basechainId = 0, workchainInvalid = 0x80000000;
constexpr ShardId shardIdAll = (1ULL << 63);

constexpr unsigned split_merge_delay = 100;        // prepare (delay) split/merge for 100 seconds
constexpr unsigned split_merge_interval = 100;     // split/merge is enabled during 60 second interval
constexpr unsigned min_split_merge_interval = 30;  // split/merge interval must be at least 30 seconds
constexpr unsigned max_split_merge_delay =
    1000;  // end of split/merge interval must be at most 1000 seconds in the future

enum GlobalCapabilities { capIhrEnabled = 1, capCreateStatsEnabled = 2 };

inline int shard_pfx_len(ShardId shard) {
  return shard ? 63 - td::count_trailing_zeroes_non_zero64(shard) : 0;
}

inline std::string shard_to_str(ShardId shard) {
  char buffer[64];
  return std::string{buffer, (unsigned)snprintf(buffer, 63, "%016llx", static_cast<unsigned long long>(shard))};
}

struct ShardIdFull {
  WorkchainId workchain;
  ShardId shard;
  ShardIdFull() : workchain(workchainInvalid) {
  }
  explicit ShardIdFull(WorkchainId workchain) : workchain(workchain), shard(shardIdAll) {
  }
  ShardIdFull(WorkchainId workchain, ShardId shard) : workchain(workchain), shard(shard) {
  }
  bool operator==(const ShardIdFull& other) const {
    return workchain == other.workchain && shard == other.shard;
  }
  bool operator!=(const ShardIdFull& other) const {
    return workchain != other.workchain || shard != other.shard;
  }
  bool operator<(const ShardIdFull& other) const {
    return workchain < other.workchain || (workchain == other.workchain && shard < other.shard);
  }
  bool is_valid() const {
    return workchain != workchainInvalid;
  }
  bool is_valid_ext() const {
    return is_valid() && shard;
  }
  bool is_masterchain() const {
    return workchain == masterchainId;
  }
  bool is_split() const {
    return shard != shardIdAll;
  }
  bool is_masterchain_ext() const {
    return is_masterchain() && shard == shardIdAll;
  }
  int pfx_len() const {
    return shard_pfx_len(shard);
  }
  ShardIdFull operator+(int delta) const {
    return ShardIdFull{workchain, shard + delta};
  }
  ShardIdFull operator-(int delta) const {
    return ShardIdFull{workchain, shard - delta};
  }
  std::string to_str() const {
    char buffer[64];
    return std::string{buffer, (unsigned)snprintf(buffer, 63, "(%d,%016llx)", workchain, (unsigned long long)shard)};
  }
};

struct AccountIdPrefixFull {
  WorkchainId workchain;
  AccountIdPrefix account_id_prefix;
  AccountIdPrefixFull() : workchain(workchainInvalid) {
  }
  AccountIdPrefixFull(WorkchainId workchain, AccountIdPrefix prefix) : workchain(workchain), account_id_prefix(prefix) {
  }
  bool operator==(const AccountIdPrefixFull& other) const {
    return workchain == other.workchain && account_id_prefix == other.account_id_prefix;
  }
  bool operator!=(const AccountIdPrefixFull& other) const {
    return workchain != other.workchain || account_id_prefix != other.account_id_prefix;
  }
  bool operator<(const AccountIdPrefixFull& other) const {
    return workchain < other.workchain || (workchain == other.workchain && account_id_prefix < other.account_id_prefix);
  }
  bool is_valid() const {
    return workchain != workchainInvalid;
  }
  bool is_masterchain() const {
    return workchain == masterchainId;
  }
  ShardIdFull as_leaf_shard() const {
    return ShardIdFull{workchain, account_id_prefix | 1};
  }
  std::string to_str() const {
    char buffer[64];
    return std::string{
        buffer, (unsigned)snprintf(buffer, 63, "(%d,%016llx)", workchain, static_cast<long long>(account_id_prefix))};
  }
};

struct BlockId {
  WorkchainId workchain;
  BlockSeqno seqno;
  ShardId shard;

  BlockId(WorkchainId workchain, ShardId shard, BlockSeqno seqno) : workchain(workchain), seqno(seqno), shard(shard) {
  }
  BlockId(ShardIdFull shard, BlockSeqno seqno) : workchain(shard.workchain), seqno(seqno), shard(shard.shard) {
  }
  BlockId() : workchain(workchainInvalid) {
  }
  explicit operator ShardIdFull() const {
    return ShardIdFull{workchain, shard};
  }
  ShardIdFull shard_full() const {
    return ShardIdFull{workchain, shard};
  }
  bool is_valid() const {
    return workchain != workchainInvalid;
  }
  bool is_valid_ext() const {
    return is_valid() && shard;
  }
  bool is_masterchain() const {
    return workchain == masterchainId;
  }
  bool is_masterchain_ext() const {
    return is_masterchain() && shard == shardIdAll;
  }
  bool is_valid_full() const {
    return is_valid() && shard && !(shard & 7) && seqno <= 0x7fffffff && (!is_masterchain() || shard == shardIdAll);
  }
  bool invalidate() {
    workchain = workchainInvalid;
    return false;
  }
  bool invalidate_clear() {
    shard = 0;
    seqno = 0;
    return invalidate();
  }
  bool operator==(const BlockId& other) const {
    return workchain == other.workchain && seqno == other.seqno && shard == other.shard;
  }
  bool operator!=(const BlockId& other) const {
    return !(workchain == other.workchain && seqno == other.seqno && shard == other.shard);
  }
  bool operator<(const BlockId& other) const {
    return workchain < other.workchain ||
           (workchain == other.workchain && (seqno < other.seqno || (seqno == other.seqno && shard < other.shard)));
  }
  bool operator<(const ShardIdFull& other) const {
    return workchain < other.workchain || (workchain == other.workchain && shard < other.shard);
  }
  int pfx_len() const {
    return shard_pfx_len(shard);
  }
  std::string to_str() const {
    char buffer[64];
    return std::string{buffer, (unsigned)snprintf(buffer, 63, "(%d,%016llx,%u)", workchain,
                                                  static_cast<unsigned long long>(shard), seqno)};
  }
};

inline bool operator<(const ShardIdFull& x, const BlockId& y) {
  return x.workchain < y.workchain || (x.workchain == y.workchain && x.shard < y.shard);
}

struct BlockIdExt {
  BlockId id;
  RootHash root_hash;
  FileHash file_hash;
  BlockIdExt(WorkchainId workchain, ShardId shard, BlockSeqno seqno, const RootHash& root_hash,
             const FileHash& file_hash)
      : id{workchain, shard, seqno}, root_hash(root_hash), file_hash(file_hash) {
  }
  BlockIdExt(BlockId id, const RootHash& root_hash, const FileHash& file_hash)
      : id(id), root_hash(root_hash), file_hash(file_hash) {
  }
  BlockIdExt(BlockId id, const FileHash& file_hash) : id(id), file_hash(file_hash) {
    root_hash.set_zero();
  }
  explicit BlockIdExt(BlockId id) : id(id) {
    root_hash.set_zero();
    file_hash.set_zero();
  }
  BlockIdExt() : id(workchainIdNotYet, 0, 0) {
  }
  bool invalidate() {
    return id.invalidate();
  }
  bool invalidate_clear() {
    root_hash.set_zero();
    file_hash.set_zero();
    return id.invalidate_clear();
  }
  bool operator==(const BlockIdExt& b) const {
    return id == b.id && root_hash == b.root_hash && file_hash == b.file_hash;
  }
  bool operator!=(const BlockIdExt& b) const {
    return !(id == b.id && root_hash == b.root_hash && file_hash == b.file_hash);
  }
  bool operator<(const BlockIdExt& b) const {
    return id < b.id || (id == b.id && root_hash < b.root_hash) ||
           (id == b.id && root_hash == b.root_hash && file_hash < b.file_hash);
  }
  ShardIdFull shard_full() const {
    return ShardIdFull(id);
  }
  explicit operator ShardIdFull() const {
    return ShardIdFull(id);
  }
  BlockSeqno seqno() const {
    return id.seqno;
  }
  bool is_valid() const {
    return id.is_valid();
  }
  bool is_valid_ext() const {
    return id.is_valid_ext();
  }
  bool is_valid_full() const {
    return id.is_valid_full() && !root_hash.is_zero() && !file_hash.is_zero();
  }
  bool is_masterchain() const {
    return id.is_masterchain();
  }
  bool is_masterchain_ext() const {
    return id.is_masterchain_ext();
  }
  std::string to_str() const {
    return id.to_str() + ':' + root_hash.to_hex() + ':' + file_hash.to_hex();
  }
  static td::Result<BlockIdExt> from_str(td::CSlice s) {
    BlockIdExt v;
    char rh[65];
    char fh[65];
    auto r = sscanf(s.begin(), "(%d,%" SCNx64 ",%u):%64s:%64s", &v.id.workchain, &v.id.shard, &v.id.seqno, rh, fh);
    if (r < 5) {
      return td::Status::Error("failed to parse block id");
    }
    if (strlen(rh) != 64 || strlen(fh) != 64) {
      return td::Status::Error("failed to parse block id: bad roothash/filehash");
    }
    TRY_RESULT(re, td::hex_decode(td::Slice(rh, 64)));
    v.root_hash.as_slice().copy_from(td::Slice(re));
    TRY_RESULT(fe, td::hex_decode(td::Slice(fh, 64)));
    v.file_hash.as_slice().copy_from(td::Slice(fe));
    return v;
  }
};

struct ZeroStateIdExt {
  WorkchainId workchain{workchainInvalid};
  RootHash root_hash;
  FileHash file_hash;
  ZeroStateIdExt() = default;
  ZeroStateIdExt(WorkchainId wc, const RootHash& rhash, const FileHash& fhash)
      : workchain(wc), root_hash(rhash), file_hash(fhash) {
  }
  bool operator==(const ZeroStateIdExt& b) const {
    return workchain == b.workchain && root_hash == b.root_hash && file_hash == b.file_hash;
  }
  bool operator!=(const ZeroStateIdExt& b) const {
    return !(workchain == b.workchain && root_hash == b.root_hash && file_hash == b.file_hash);
  }
  bool operator<(const ZeroStateIdExt& b) const {
    return file_hash < b.file_hash;
  }
  bool is_valid() const {
    return workchain != workchainInvalid;
  }
  bool is_masterchain() const {
    return workchain == masterchainId;
  }
  bool is_valid_full() const {
    return is_valid() && !root_hash.is_zero() && !file_hash.is_zero();
  }
  std::string to_str() const {
    return PSTRING() << workchain << ':' << root_hash.to_hex() << ':' << file_hash.to_hex();
  }
};

//enum class BlockStatus { block_none, block_prevalidated, block_validated, block_applied };

struct BlockSignature {
  NodeIdShort node;
  td::BufferSlice signature;
  BlockSignature(const NodeIdShort& _node, td::BufferSlice _signature) : node(_node), signature(std::move(_signature)) {
  }
};

struct ReceivedBlock {
  BlockIdExt id;
  td::BufferSlice data;
};

struct BlockBroadcast {
  BlockIdExt block_id;
  std::vector<BlockSignature> signatures;
  CatchainSeqno catchain_seqno;
  td::uint32 validator_set_hash;
  td::BufferSlice data;
  td::BufferSlice proof;
};

struct Ed25519_PrivateKey {
  Bits256 _privkey;
  explicit Ed25519_PrivateKey(const Bits256& x) : _privkey(x) {
  }
  explicit Ed25519_PrivateKey(const td::ConstBitPtr x) : _privkey(x) {
  }
  explicit Ed25519_PrivateKey(const td::UInt256& x) : _privkey(x.raw) {
  }
  Bits256 as_bits256() const {
    return _privkey;
  }
  operator Bits256() const {
    return _privkey;
  }
};

struct Ed25519_PublicKey {
  Bits256 _pubkey;
  explicit Ed25519_PublicKey(const Bits256& x) : _pubkey(x) {
  }
  explicit Ed25519_PublicKey(const td::ConstBitPtr x) : _pubkey(x) {
  }
  explicit Ed25519_PublicKey(const td::UInt256& x) : _pubkey(x.raw) {
  }
  Bits256 as_bits256() const {
    return _pubkey;
  }
  operator Bits256() const {
    return _pubkey;
  }
  td::Slice as_slice() const {
    return _pubkey.as_slice();
  }
  bool operator==(const Ed25519_PublicKey& other) const {
    return _pubkey == other._pubkey;
  }
  bool clear() {
    _pubkey.set_zero();
    return true;
  }
  bool is_zero() const {
    return _pubkey.is_zero();
  }
  bool non_zero() const {
    return !is_zero();
  }
};

// represents (the contents of) a block
struct BlockCandidate {
  BlockCandidate(Ed25519_PublicKey pubkey, BlockIdExt id, FileHash collated_file_hash, td::BufferSlice data,
                 td::BufferSlice collated_data)
      : pubkey(pubkey)
      , id(id)
      , collated_file_hash(collated_file_hash)
      , data(std::move(data))
      , collated_data(std::move(collated_data)) {
  }
  Ed25519_PublicKey pubkey;
  BlockIdExt id;
  FileHash collated_file_hash;
  td::BufferSlice data;
  td::BufferSlice collated_data;

  BlockCandidate clone() const {
    return BlockCandidate{pubkey, id, collated_file_hash, data.clone(), collated_data.clone()};
  }
};

struct ValidatorDescr {
  /* ton::validator::ValidatorFullId */ Ed25519_PublicKey key;
  ValidatorWeight weight;
  /* adnl::AdnlNodeIdShort */ Bits256 addr;
  ValidatorDescr(const Ed25519_PublicKey& key_, ValidatorWeight weight_) : key(key_), weight(weight_) {
    addr.set_zero();
  }
  ValidatorDescr(const Ed25519_PublicKey& key_, ValidatorWeight weight_, const Bits256& addr_)
      : key(key_), weight(weight_), addr(addr_) {
  }
  bool operator==(const ValidatorDescr& other) const {
    return key == other.key && weight == other.weight && addr == other.addr;
  }
  bool operator!=(const ValidatorDescr& other) const {
    return !(operator==(other));
  }
};

struct ValidatorSessionConfig {
  td::uint32 proto_version = 0;

  /* td::Clocks::Duration */ double catchain_idle_timeout = 16.0;
  td::uint32 catchain_max_deps = 4;

  td::uint32 round_candidates = 3;
  /* td::Clocks::Duration */ double next_candidate_delay = 2.0;
  td::uint32 round_attempt_duration = 16;
  td::uint32 max_round_attempts = 4;

  td::uint32 max_block_size = (4 << 20);
  td::uint32 max_collated_data_size = (4 << 20);
};

}  // namespace ton
