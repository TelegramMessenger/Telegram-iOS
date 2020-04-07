/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once
#include "common/refcnt.hpp"
#include "vm/db/StaticBagOfCellsDb.h"
#include "vm/dict.h"
#include "ton/ton-types.h"
#include "ton/ton-shard.h"
#include "common/bitstring.h"
#include "block.h"

#include <vector>
#include <limits>
#include <map>
#include <set>
#include <cstring>

namespace block {
using td::Ref;

struct ValidatorDescr {
  ton::Ed25519_PublicKey pubkey;
  td::Bits256 adnl_addr;
  td::uint64 weight;
  td::uint64 cum_weight;
  ValidatorDescr(const td::Bits256& _pubkey, td::uint64 _weight, td::uint64 _cum_weight)
      : pubkey(_pubkey), weight(_weight), cum_weight(_cum_weight) {
    adnl_addr.set_zero();
  }
  ValidatorDescr(const td::Bits256& _pubkey, td::uint64 _weight, td::uint64 _cum_weight, const td::Bits256& _adnl_addr)
      : pubkey(_pubkey), adnl_addr(_adnl_addr), weight(_weight), cum_weight(_cum_weight) {
  }
  ValidatorDescr(const ton::Ed25519_PublicKey& _pubkey, td::uint64 _weight, td::uint64 _cum_weight)
      : pubkey(_pubkey), weight(_weight), cum_weight(_cum_weight) {
    adnl_addr.set_zero();
  }
  bool operator<(td::uint64 wt_pos) const & {
    return cum_weight < wt_pos;
  }
};

struct ValidatorSet {
  unsigned utime_since;
  unsigned utime_until;
  int total;
  int main;
  td::uint64 total_weight;
  std::vector<ValidatorDescr> list;
  ValidatorSet() = default;
  ValidatorSet(unsigned _since, unsigned _until, int _total, int _main = 0)
      : utime_since(_since), utime_until(_until), total(_total), main(_main > 0 ? _main : _total), total_weight(0) {
  }
  const ValidatorDescr& operator[](unsigned i) const {
    return list[i];
  }
  const ValidatorDescr& at_weight(td::uint64 weight_pos) const;
  std::vector<ton::ValidatorDescr> export_validator_set() const;
};

#pragma pack(push, 1)
// this structure is hashed with SHA512 to produce pseudo-random bit stream in do_compute_validator_set()
// NB: all integers (including 256-bit seed) are actually big-endian
struct validator_set_descr {
  unsigned char seed[32];  // seed for validator set computation, set to zero if none
  td::uint64 shard;
  td::int32 workchain;
  td::uint32 cc_seqno;
  validator_set_descr() = default;
  validator_set_descr(ton::ShardIdFull shard_id, ton::CatchainSeqno cc_seqno_, bool flag)
      : shard(td::bswap64(shard_id.shard))
      , workchain(td::bswap32(shard_id.workchain))
      , cc_seqno(td::bswap32(cc_seqno_)) {
  }
  validator_set_descr(ton::ShardIdFull shard_id, ton::CatchainSeqno cc_seqno_)
      : validator_set_descr(shard_id, cc_seqno_, false) {
    std::memset(seed, 0, 32);
  }
  validator_set_descr(ton::ShardIdFull shard_id, ton::CatchainSeqno cc_seqno_, const unsigned char seed_[32])
      : validator_set_descr(shard_id, cc_seqno_, false) {
    std::memcpy(seed, seed_, 32);
  }
  validator_set_descr(ton::ShardIdFull shard_id, ton::CatchainSeqno cc_seqno_, td::ConstBitPtr seed_)
      : validator_set_descr(shard_id, cc_seqno_, false) {
    td::BitPtr{seed}.copy_from(seed_, 256);
  }
  validator_set_descr(ton::ShardIdFull shard_id, ton::CatchainSeqno cc_seqno_, const td::Bits256& seed_)
      : validator_set_descr(shard_id, cc_seqno_, false) {
    td::BitPtr{seed}.copy_from(seed_.cbits(), 256);
  }
  void incr_seed();
  void hash_to(unsigned char hash_buffer[64]) const;
};
#pragma pack(pop)

class ValidatorSetPRNG {
  validator_set_descr data;
  union {
    unsigned char hash[64];
    td::uint64 hash_longs[8];
  };
  int pos{0}, limit{0};

 public:
  ValidatorSetPRNG() = default;
  ValidatorSetPRNG(ton::ShardIdFull shard_id, ton::CatchainSeqno cc_seqno_) : data(shard_id, cc_seqno_) {
  }
  ValidatorSetPRNG(ton::ShardIdFull shard_id, ton::CatchainSeqno cc_seqno_, const unsigned char seed_[32])
      : data(shard_id, cc_seqno_, seed_) {
  }
  ValidatorSetPRNG(ton::ShardIdFull shard_id, ton::CatchainSeqno cc_seqno_, td::ConstBitPtr seed_)
      : data(shard_id, cc_seqno_, std::move(seed_)) {
  }
  ValidatorSetPRNG(ton::ShardIdFull shard_id, ton::CatchainSeqno cc_seqno_, const td::Bits256& seed_)
      : data(shard_id, cc_seqno_, seed_) {
  }
  td::uint64 next_ulong();
  td::uint64 next_ranged(td::uint64 range);  // integer in 0 .. range-1
  ValidatorSetPRNG& operator>>(td::uint64& x) {
    x = next_ulong();
    return *this;
  }
};

class McShardHashI : public td::CntObject {
 public:
  enum class FsmState { fsm_none, fsm_split, fsm_merge };
  virtual ton::BlockIdExt top_block_id() const = 0;
  virtual ton::LogicalTime start_lt() const = 0;
  virtual ton::LogicalTime end_lt() const = 0;
  virtual ton::UnixTime fsm_utime() const = 0;
  virtual FsmState fsm_state() const = 0;
  virtual ton::ShardIdFull shard() const = 0;
  virtual bool before_split() const = 0;
  virtual bool before_merge() const = 0;
};

struct McShardHash : public McShardHashI {
  ton::BlockIdExt blk_;
  ton::LogicalTime start_lt_, end_lt_;
  ton::UnixTime gen_utime_{0};
  ton::UnixTime fsm_utime_{0};
  ton::UnixTime fsm_interval_{0};
  ton::BlockSeqno min_ref_mc_seqno_{std::numeric_limits<ton::BlockSeqno>::max()};
  ton::BlockSeqno reg_mc_seqno_{std::numeric_limits<ton::BlockSeqno>::max()};
  FsmState fsm_{FsmState::fsm_none};
  bool disabled_{false};
  bool before_split_{false}, before_merge_{false}, want_split_{false}, want_merge_{false};
  ton::CatchainSeqno next_catchain_seqno_{std::numeric_limits<ton::CatchainSeqno>::max()};
  ton::ShardId next_validator_shard_{ton::shardIdAll};
  CurrencyCollection fees_collected_, funds_created_;
  McShardHash(const ton::BlockId& id, ton::LogicalTime start_lt, ton::LogicalTime end_lt, ton::UnixTime gen_utime,
              const ton::BlockHash& root_hash, const ton::FileHash& file_hash, CurrencyCollection fees_collected = {},
              CurrencyCollection funds_created = {},
              ton::BlockSeqno reg_mc_seqno = std::numeric_limits<ton::BlockSeqno>::max(),
              ton::BlockSeqno min_ref_mc_seqno = std::numeric_limits<ton::BlockSeqno>::max(),
              ton::CatchainSeqno cc_seqno = std::numeric_limits<ton::CatchainSeqno>::max(), ton::ShardId val_shard = 0,
              bool nx_cc_updated = false, bool before_split = false, bool before_merge = false, bool want_split = false,
              bool want_merge = false)
      : blk_(id, root_hash, file_hash)
      , start_lt_(start_lt)
      , end_lt_(end_lt)
      , gen_utime_(gen_utime)
      , min_ref_mc_seqno_(min_ref_mc_seqno)
      , reg_mc_seqno_(reg_mc_seqno)
      , before_split_(before_split)
      , before_merge_(before_merge)
      , want_split_(want_split)
      , want_merge_(want_merge)
      , next_catchain_seqno_(cc_seqno)
      , next_validator_shard_(val_shard ? val_shard : id.shard)
      , fees_collected_(fees_collected)
      , funds_created_(funds_created) {
  }
  McShardHash(const ton::BlockIdExt& blk, ton::LogicalTime start_lt, ton::LogicalTime end_lt)
      : blk_(blk), start_lt_(start_lt), end_lt_(end_lt) {
  }
  McShardHash(const McShardHash&) = default;
  bool is_valid() const {
    return blk_.is_valid();
  }
  ton::BlockIdExt top_block_id() const override final {
    return blk_;
  }
  //  ZeroStateIdExt zero_state() const override;
  ton::LogicalTime start_lt() const override final {
    return start_lt_;
  }
  ton::LogicalTime end_lt() const override final {
    return end_lt_;
  }
  ton::UnixTime fsm_utime() const override final {
    return fsm_utime_;
  }
  ton::UnixTime fsm_utime_end() const {
    return fsm_utime_ + fsm_interval_;
  }
  ton::UnixTime created_at() const {
    return gen_utime_;
  }
  FsmState fsm_state() const override final {
    return fsm_;
  }
  bool is_fsm_none() const {
    return fsm_ == FsmState::fsm_none;
  }
  bool is_fsm_split() const {
    return fsm_ == FsmState::fsm_split;
  }
  bool is_fsm_merge() const {
    return fsm_ == FsmState::fsm_merge;
  }
  ton::ShardIdFull shard() const override final {
    return ton::ShardIdFull(blk_);
  }
  ton::WorkchainId workchain() const {
    return blk_.id.workchain;
  }
  bool contains(const ton::AccountIdPrefixFull& pfx) const {
    return ton::shard_contains(shard(), pfx);
  }
  bool before_split() const override final {
    return before_split_;
  }
  bool before_merge() const override final {
    return before_merge_;
  }
  bool is_disabled() const {
    return disabled_;
  }
  void disable() {
    blk_.invalidate();
    disabled_ = true;
  }
  ton::BlockSeqno seqno() const {
    return blk_.id.seqno;
  }
  bool set_reg_mc_seqno(ton::BlockSeqno reg_mc_seqno) {
    reg_mc_seqno_ = reg_mc_seqno;
    return true;
  }
  // compares all fields except fsm*, before_merge_, nx_cc_updated_, next_catchain_seqno_, fees_collected_
  bool basic_info_equal(const McShardHash& other, bool compare_fees = false, bool compare_reg_seqno = true) const;
  void clear_fsm() {
    fsm_ = FsmState::fsm_none;
  }
  void set_fsm(FsmState fsm, ton::UnixTime fsm_utime, ton::UnixTime fsm_interval);
  void set_fsm_split(ton::UnixTime fsm_utime, ton::UnixTime fsm_interval) {
    set_fsm(FsmState::fsm_split, fsm_utime, fsm_interval);
  }
  void set_fsm_merge(ton::UnixTime fsm_utime, ton::UnixTime fsm_interval) {
    set_fsm(FsmState::fsm_merge, fsm_utime, fsm_interval);
  }
  bool fsm_equal(const McShardHash& other) const {
    return fsm_ == other.fsm_ &&
           (is_fsm_none() || (fsm_utime_ == other.fsm_utime_ && fsm_interval_ == other.fsm_interval_));
  }
  bool pack(vm::CellBuilder& cb) const;
  static Ref<McShardHash> unpack(vm::CellSlice& cs, ton::ShardIdFull id);
  static Ref<McShardHash> from_block(Ref<vm::Cell> block_root, const ton::FileHash& _fhash, bool init_fees = false);
  static bool extract_cc_seqno(vm::CellSlice& cs, ton::CatchainSeqno* cc);
  McShardHash* make_copy() const override {
    return new McShardHash(*this);
  }
};

struct McShardDescr final : public McShardHash {
  Ref<vm::Cell> block_root;
  Ref<vm::Cell> state_root;
  Ref<vm::Cell> outmsg_root;
  std::unique_ptr<vm::AugmentedDictionary> out_msg_queue;
  std::shared_ptr<block::MsgProcessedUptoCollection> processed_upto;
  McShardDescr(const ton::BlockId& id, ton::LogicalTime start_lt, ton::LogicalTime end_lt, ton::UnixTime gen_utime,
               const ton::BlockHash& root_hash, const ton::FileHash& file_hash, CurrencyCollection fees_collected = {},
               CurrencyCollection funds_created = {},
               ton::BlockSeqno reg_mc_seqno = std::numeric_limits<ton::BlockSeqno>::max(),
               ton::BlockSeqno min_ref_mc_seqno = std::numeric_limits<ton::BlockSeqno>::max(),
               ton::CatchainSeqno cc_seqno = std::numeric_limits<ton::CatchainSeqno>::max(),
               ton::ShardId val_shard = ton::shardIdAll, bool nx_cc_updated = false, bool before_split = false,
               bool before_merge = false, bool want_split = false, bool want_merge = false)
      : McShardHash(id, start_lt, end_lt, gen_utime, root_hash, file_hash, fees_collected, funds_created, reg_mc_seqno,
                    min_ref_mc_seqno, cc_seqno, val_shard, nx_cc_updated, before_split, before_merge, want_split,
                    want_merge) {
  }
  McShardDescr(const ton::BlockIdExt& blk, ton::LogicalTime start_lt, ton::LogicalTime end_lt)
      : McShardHash(blk, start_lt, end_lt) {
  }
  McShardDescr(const McShardHash& shard_hash) : McShardHash(shard_hash) {
  }
  McShardDescr(const McShardDescr& other);
  McShardDescr(McShardDescr&& other) = default;
  McShardDescr& operator=(const McShardDescr& other);
  McShardDescr& operator=(McShardDescr&& other) = default;
  bool set_queue_root(Ref<vm::Cell> queue_root);
  void disable();
  static Ref<McShardDescr> from_block(Ref<vm::Cell> block_root, Ref<vm::Cell> state_root, const ton::FileHash& _fhash,
                                      bool init_fees = false);
  static Ref<McShardDescr> from_state(ton::BlockIdExt blkid, Ref<vm::Cell> state_root);
};

struct StoragePrices {
  ton::UnixTime valid_since{0};
  td::uint64 bit_price{0};
  td::uint64 cell_price{0};
  td::uint64 mc_bit_price{0};
  td::uint64 mc_cell_price{0};
  StoragePrices() = default;
  StoragePrices(ton::UnixTime _valid_since, td::uint64 _bprice, td::uint64 _cprice, td::uint64 _mc_bprice,
                td::uint64 _mc_cprice)
      : valid_since(_valid_since)
      , bit_price(_bprice)
      , cell_price(_cprice)
      , mc_bit_price(_mc_bprice)
      , mc_cell_price(_mc_cprice) {
  }
  static td::RefInt256 compute_storage_fees(ton::UnixTime now, const std::vector<block::StoragePrices>& pricing,
                                            const vm::CellStorageStat& storage_stat, ton::UnixTime last_paid,
                                            bool is_special, bool is_masterchain);
};

struct GasLimitsPrices {
  td::uint64 flat_gas_limit{0};
  td::uint64 flat_gas_price{0};
  td::uint64 gas_price{0};
  td::uint64 special_gas_limit{0};
  td::uint64 gas_limit{0};
  td::uint64 gas_credit{0};
  td::uint64 block_gas_limit{0};
  td::uint64 freeze_due_limit{0};
  td::uint64 delete_due_limit{0};

  td::RefInt256 compute_gas_price(td::uint64 gas_used) const;
};

// msg_fwd_fees = (lump_price + ceil((bit_price * msg.bits + cell_price * msg.cells)/2^16)) nanograms
// ihr_fwd_fees = ceil((msg_fwd_fees * ihr_price_factor)/2^16) nanograms
// bits in the root cell of a message are not included in msg.bits (lump_price pays for them)

struct MsgPrices {
  td::uint64 lump_price;
  td::uint64 bit_price;
  td::uint64 cell_price;
  td::uint32 ihr_factor;
  td::uint32 first_frac;
  td::uint32 next_frac;
  td::uint64 compute_fwd_fees(td::uint64 cells, td::uint64 bits) const;
  std::pair<td::uint64, td::uint64> compute_fwd_ihr_fees(td::uint64 cells, td::uint64 bits,
                                                         bool ihr_disabled = false) const;
  MsgPrices() = default;
  MsgPrices(td::uint64 lump, td::uint64 bitp, td::uint64 cellp, td::uint32 ihrf, td::uint32 firstf, td::uint32 nextf)
      : lump_price(lump), bit_price(bitp), cell_price(cellp), ihr_factor(ihrf), first_frac(firstf), next_frac(nextf) {
  }
  td::RefInt256 get_first_part(td::RefInt256 total) const;
  td::uint64 get_first_part(td::uint64 total) const;
  td::RefInt256 get_next_part(td::RefInt256 total) const;
};

struct CatchainValidatorsConfig {
  td::uint32 mc_cc_lifetime, shard_cc_lifetime, shard_val_lifetime, shard_val_num;
  CatchainValidatorsConfig(td::uint32 mc_cc_lt_, td::uint32 sh_cc_lt_, td::uint32 sh_val_lt_, td::uint32 sh_val_num_)
      : mc_cc_lifetime(mc_cc_lt_)
      , shard_cc_lifetime(sh_cc_lt_)
      , shard_val_lifetime(sh_val_lt_)
      , shard_val_num(sh_val_num_) {
  }
};

struct WorkchainInfo : public td::CntObject {
  ton::WorkchainId workchain{ton::workchainInvalid};
  ton::UnixTime enabled_since;
  td::uint32 actual_min_split;
  td::uint32 min_split, max_split;
  bool basic;
  bool active;
  bool accept_msgs;
  int flags;
  td::uint32 version;
  ton::RootHash zerostate_root_hash;
  ton::FileHash zerostate_file_hash;
  int min_addr_len, max_addr_len, addr_len_step;
  bool is_valid() const {
    return workchain != ton::workchainInvalid;
  }
  bool is_valid_addr_len(int addr_len) const {
    return addr_len >= min_addr_len && addr_len <= max_addr_len &&
           (addr_len == min_addr_len || addr_len == max_addr_len ||
            (addr_len_step > 0 && !((addr_len - min_addr_len) % addr_len_step)));
  }
  bool unpack(ton::WorkchainId wc, vm::CellSlice& cs);
};

using WorkchainSet = std::map<td::int32, Ref<WorkchainInfo>>;

class ShardConfig {
  Ref<vm::Cell> shard_hashes_;
  Ref<McShardHash> mc_shard_hash_;
  std::unique_ptr<vm::Dictionary> shard_hashes_dict_;
  std::set<ton::ShardIdFull> shards_updated_;
  bool valid_{false};

 public:
  ShardConfig() = default;
  ShardConfig(const ShardConfig& other);
  ShardConfig(ShardConfig&& other) = default;
  ShardConfig(Ref<vm::Cell> shard_hashes, Ref<McShardHash> mc_shard_hash = {})
      : shard_hashes_(std::move(shard_hashes)), mc_shard_hash_(std::move(mc_shard_hash)) {
    init();
  }
  bool is_valid() const {
    return valid_;
  }
  bool unpack(Ref<vm::Cell> shard_hashes, Ref<McShardHash> mc_shard_hash = {});
  bool unpack(Ref<vm::CellSlice> shard_hashes, Ref<McShardHash> mc_shard_hash = {});
  Ref<vm::CellSlice> get_root_csr() const;
  bool has_workchain(ton::WorkchainId workchain) const;
  std::vector<ton::WorkchainId> get_workchains() const;
  Ref<McShardHash> get_shard_hash(ton::ShardIdFull id, bool exact = true) const;
  bool contains(ton::BlockIdExt blkid) const;
  bool get_shard_hash_raw(vm::CellSlice& cs, ton::ShardIdFull id, ton::ShardIdFull& true_id, bool exact = true) const;
  ton::LogicalTime get_shard_end_lt(ton::AccountIdPrefixFull acc) const;
  ton::LogicalTime get_shard_end_lt_ext(ton::AccountIdPrefixFull acc, ton::ShardIdFull& actual_shard) const;
  static bool get_shard_hash_raw_from(vm::Dictionary& shard_hashes_dict, vm::CellSlice& cs, ton::ShardIdFull id,
                                      ton::ShardIdFull& true_id, bool exact = true, Ref<vm::Cell>* leaf = nullptr);
  std::vector<ton::BlockId> get_shard_hash_ids(bool skip_mc = false) const;
  std::vector<ton::BlockId> get_shard_hash_ids(const std::function<bool(ton::ShardIdFull, bool)>& filter) const;
  std::vector<ton::BlockId> get_intersecting_shard_hash_ids(ton::ShardIdFull myself) const;
  std::vector<ton::BlockId> get_neighbor_shard_hash_ids(ton::ShardIdFull myself) const;
  std::vector<ton::BlockId> get_proper_neighbor_shard_hash_ids(ton::ShardIdFull myself) const;
  static std::unique_ptr<vm::Dictionary> extract_shard_hashes_dict(Ref<vm::Cell> mc_state_root);
  bool process_shard_hashes(std::function<int(McShardHash&)> func);
  bool process_sibling_shard_hashes(std::function<int(McShardHash&, const McShardHash*)> func);
  // may become non-static const in the future
  static bool is_neighbor(ton::ShardIdFull x, ton::ShardIdFull y);
  Ref<McShardHash> get_mc_hash() const {
    return mc_shard_hash_;
  }
  void set_mc_hash(Ref<McShardHash> mc_shard_hash) {
    mc_shard_hash_ = std::move(mc_shard_hash);
  }
  ton::CatchainSeqno get_shard_cc_seqno(ton::ShardIdFull shard) const;
  block::compute_shard_end_lt_func_t get_compute_shard_end_lt_func() const {
    return std::bind(&ShardConfig::get_shard_end_lt, *this, std::placeholders::_1);
  }
  bool new_workchain(ton::WorkchainId workchain, ton::BlockSeqno reg_mc_seqno, const ton::RootHash& zerostate_root_hash,
                     const ton::FileHash& zerostate_file_hash);
  td::Result<bool> update_shard_block_info(Ref<McShardHash> new_info, const std::vector<ton::BlockIdExt>& old_blkids);
  td::Result<bool> update_shard_block_info2(Ref<McShardHash> new_info1, Ref<McShardHash> new_info2,
                                            const std::vector<ton::BlockIdExt>& old_blkids);
  td::Result<bool> may_update_shard_block_info(Ref<McShardHash> new_info,
                                               const std::vector<ton::BlockIdExt>& old_blkids,
                                               ton::LogicalTime lt_limit = std::numeric_limits<ton::LogicalTime>::max(),
                                               Ref<McShardHash>* ancestor = nullptr) const;

 private:
  bool init();
  bool do_update_shard_info(Ref<McShardHash> new_info);
  bool do_update_shard_info2(Ref<McShardHash> new_info1, Ref<McShardHash> new_info2);
  bool set_shard_info(ton::ShardIdFull shard, Ref<vm::Cell> value);
};

class Config {
  enum {
    default_mc_catchain_lifetime = 200,
    default_shard_catchain_lifetime = 200,
    default_shard_validators_lifetime = 3000,
    default_shard_validators_num = 7
  };

 public:
  enum { needValidatorSet = 16, needSpecialSmc = 32, needWorkchainInfo = 256, needCapabilities = 512 };
  int mode{0};
  ton::BlockIdExt block_id;

 private:
  td::BitArray<256> config_addr;
  Ref<vm::Cell> config_root;
  std::unique_ptr<vm::Dictionary> config_dict;
  std::unique_ptr<ValidatorSet> cur_validators_;
  std::unique_ptr<vm::Dictionary> workchains_dict_;
  WorkchainSet workchains_;
  int version_{-1};
  long long capabilities_{-1};

 protected:
  std::unique_ptr<vm::Dictionary> special_smc_dict;

 public:
  static constexpr ton::LogicalTime get_lt_align() {
    return 1000000;
  }
  static constexpr ton::LogicalTime get_max_lt_growth() {
    return 10 * get_lt_align() - 1;
  }
  Ref<vm::Cell> get_config_param(int idx) const;
  Ref<vm::Cell> get_config_param(int idx, int idx2) const;
  Ref<vm::Cell> operator[](int idx) const {
    return get_config_param(idx);
  }
  Ref<vm::Cell> get_root_cell() const {
    return config_root;
  }
  bool is_masterchain() const {
    return block_id.is_masterchain();
  }
  bool has_capabilities() const {
    return capabilities_ >= 0;
  }
  long long get_capabilities() const {
    return capabilities_;
  }
  int get_global_version() const {
    return version_;
  }
  bool has_capability(long long cap_set) const {
    return has_capabilities() && (capabilities_ & cap_set) == cap_set;
  }
  bool ihr_enabled() const {
    return has_capability(ton::capIhrEnabled);
  }
  bool create_stats_enabled() const {
    return has_capability(ton::capCreateStatsEnabled);
  }
  std::unique_ptr<vm::Dictionary> get_param_dict(int idx) const;
  td::Result<std::vector<int>> unpack_param_list(int idx) const;
  std::unique_ptr<vm::Dictionary> get_mandatory_param_dict() const {
    return get_param_dict(9);
  }
  std::unique_ptr<vm::Dictionary> get_critical_param_dict() const {
    return get_param_dict(10);
  }
  td::Result<std::vector<int>> get_mandatory_param_list() const {
    return unpack_param_list(9);
  }
  td::Result<std::vector<int>> get_critical_param_list() const {
    return unpack_param_list(10);
  }
  bool all_mandatory_params_defined(int* bad_idx_ptr = nullptr) const;
  td::Result<ton::StdSmcAddress> get_dns_root_addr() const;
  bool set_block_id_ext(const ton::BlockIdExt& block_id_ext);
  td::Result<std::vector<ton::StdSmcAddress>> get_special_smartcontracts(bool without_config = false) const;
  bool is_special_smartcontract(const ton::StdSmcAddress& addr) const;
  static td::Result<std::unique_ptr<ValidatorSet>> unpack_validator_set(Ref<vm::Cell> valset_root);
  td::Result<std::vector<StoragePrices>> get_storage_prices() const;
  td::Result<GasLimitsPrices> get_gas_limits_prices(bool is_masterchain = false) const;
  static td::Result<GasLimitsPrices> do_get_gas_limits_prices(td::Ref<vm::Cell> cell, int id);
  td::Result<MsgPrices> get_msg_prices(bool is_masterchain = false) const;
  static CatchainValidatorsConfig unpack_catchain_validators_config(Ref<vm::Cell> cell);
  CatchainValidatorsConfig get_catchain_validators_config() const;
  td::Status visit_validator_params() const;
  td::Result<std::unique_ptr<BlockLimits>> get_block_limits(bool is_masterchain = false) const;
  auto get_mc_block_limits() const {
    return get_block_limits(true);
  }
  static td::Result<std::pair<WorkchainSet, std::unique_ptr<vm::Dictionary>>> unpack_workchain_list_ext(
      Ref<vm::Cell> cell);
  static td::Result<WorkchainSet> unpack_workchain_list(Ref<vm::Cell> cell);
  const WorkchainSet& get_workchain_list() const {
    return workchains_;
  }
  const ValidatorSet* get_cur_validator_set() const {
    return cur_validators_.get();
  }
  std::pair<ton::UnixTime, ton::UnixTime> get_validator_set_start_stop(int next = 0) const;
  ton::ValidatorSessionConfig get_consensus_config() const;
  bool foreach_config_param(std::function<bool(int, Ref<vm::Cell>)> scan_func) const;
  Ref<WorkchainInfo> get_workchain_info(ton::WorkchainId workchain_id) const;
  std::vector<ton::ValidatorDescr> compute_validator_set(ton::ShardIdFull shard, const block::ValidatorSet& vset,
                                                         ton::UnixTime time, ton::CatchainSeqno cc_seqno) const;
  std::vector<ton::ValidatorDescr> compute_validator_set(ton::ShardIdFull shard, ton::UnixTime time,
                                                         ton::CatchainSeqno cc_seqno) const;
  std::vector<ton::ValidatorDescr> compute_total_validator_set(int next) const;
  static std::vector<ton::ValidatorDescr> do_compute_validator_set(const block::CatchainValidatorsConfig& ccv_conf,
                                                                   ton::ShardIdFull shard,
                                                                   const block::ValidatorSet& vset, ton::UnixTime time,
                                                                   ton::CatchainSeqno cc_seqno);

  static td::Result<std::unique_ptr<Config>> unpack_config(Ref<vm::Cell> config_root,
                                                           const td::Bits256& config_addr = td::Bits256::zero(),
                                                           int mode = 0);
  static td::Result<std::unique_ptr<Config>> unpack_config(Ref<vm::CellSlice> config_csr, int mode = 0);
  static td::Result<std::unique_ptr<Config>> extract_from_state(Ref<vm::Cell> mc_state_root, int mode = 0);
  static td::Result<std::unique_ptr<Config>> extract_from_key_block(Ref<vm::Cell> key_block_root, int mode = 0);
  static td::Result<std::pair<ton::UnixTime, ton::UnixTime>> unpack_validator_set_start_stop(Ref<vm::Cell> root);
  static td::Result<std::vector<int>> unpack_param_dict(vm::Dictionary& dict);
  static td::Result<std::vector<int>> unpack_param_dict(Ref<vm::Cell> dict_root);

 protected:
  Config(int _mode) : mode(_mode) {
    config_addr.set_zero();
  }
  Config(Ref<vm::Cell> config_root, const td::Bits256& config_addr = td::Bits256::zero(), int _mode = 0);
  td::Status unpack_wrapped(Ref<vm::CellSlice> config_csr);
  td::Status unpack(Ref<vm::CellSlice> config_csr);
  td::Status unpack_wrapped();
  td::Status unpack();
};

class ConfigInfo : public Config, public ShardConfig {
 public:
  enum {
    needStateRoot = 1,
    needLibraries = 2,
    needStateExtraRoot = 4,
    needShardHashes = 8,
    needAccountsRoot = 64,
    needPrevBlocks = 128
  };
  ton::BlockSeqno vert_seqno{~0U};
  int global_id_{0};
  ton::UnixTime utime{0};
  ton::LogicalTime lt{0};
  ton::BlockSeqno min_ref_mc_seqno_{std::numeric_limits<ton::BlockSeqno>::max()};
  ton::CatchainSeqno cc_seqno_{std::numeric_limits<ton::CatchainSeqno>::max()};
  int shard_cc_updated{-1};
  bool nx_cc_updated;
  bool is_key_state_{false};

 private:
  Ref<vm::Cell> state_root;
  Ref<vm::Cell> lib_root_;
  Ref<vm::Cell> state_extra_root_;
  Ref<vm::CellSlice> accounts_root;
  ton::ZeroStateIdExt zerostate_id_;
  ton::BlockIdExt last_key_block_;
  ton::LogicalTime last_key_block_lt_;
  Ref<vm::Cell> shard_hashes;
  std::unique_ptr<vm::Dictionary> shard_hashes_dict;
  std::unique_ptr<vm::AugmentedDictionary> accounts_dict;
  std::unique_ptr<vm::AugmentedDictionary> prev_blocks_dict_;
  std::unique_ptr<vm::Dictionary> libraries_dict_;

 public:
  bool set_block_id_ext(const ton::BlockIdExt& block_id_ext);
  bool rotated_all_shards() const {
    return nx_cc_updated;
  }
  int get_global_blockchain_id() const {
    return global_id_;
  }
  ton::ZeroStateIdExt get_zerostate_id() const {
    return zerostate_id_;
  }
  Ref<vm::Cell> lookup_library(const ton::Bits256& root_hash) const {
    return lookup_library(root_hash.bits());
  }
  Ref<vm::Cell> lookup_library(td::ConstBitPtr root_hash) const;
  Ref<vm::Cell> get_libraries_root() const {
    return lib_root_;
  }
  bool is_key_state() const {
    return is_key_state_;
  }
  Ref<vm::Cell> get_state_extra_root() const {
    return state_extra_root_;
  }
  ton::BlockSeqno get_vert_seqno() const {
    return vert_seqno;
  }
  ton::CatchainSeqno get_shard_cc_seqno(ton::ShardIdFull shard) const;
  bool get_last_key_block(ton::BlockIdExt& blkid, ton::LogicalTime& blklt, bool strict = false) const;
  bool get_old_mc_block_id(ton::BlockSeqno seqno, ton::BlockIdExt& blkid, ton::LogicalTime* end_lt = nullptr) const;
  bool check_old_mc_block_id(const ton::BlockIdExt& blkid, bool strict = false) const;
  // returns block with min seqno and req_lt <= block.end_lt
  bool get_mc_block_by_lt(ton::LogicalTime lt, ton::BlockIdExt& blkid, ton::LogicalTime* end_lt = nullptr) const;
  bool get_prev_key_block(ton::BlockSeqno req_seqno, ton::BlockIdExt& blkid, ton::LogicalTime* end_lt = nullptr) const;
  bool get_next_key_block(ton::BlockSeqno req_seqno, ton::BlockIdExt& blkid, ton::LogicalTime* end_lt = nullptr) const;
  td::Result<std::vector<std::pair<ton::StdSmcAddress, int>>> get_special_ticktock_smartcontracts(
      int tick_tock = 3) const;
  int get_smc_tick_tock(td::ConstBitPtr smc_addr) const;
  std::unique_ptr<vm::AugmentedDictionary> create_accounts_dict() const;
  const vm::AugmentedDictionary& get_accounts_dict() const;
  std::vector<ton::ValidatorDescr> compute_validator_set_cc(ton::ShardIdFull shard, const block::ValidatorSet& vset,
                                                            ton::UnixTime time,
                                                            ton::CatchainSeqno* cc_seqno_delta = nullptr) const;
  std::vector<ton::ValidatorDescr> compute_validator_set_cc(ton::ShardIdFull shard, ton::UnixTime time,
                                                            ton::CatchainSeqno* cc_seqno_delta = nullptr) const;
  static td::Result<std::unique_ptr<ConfigInfo>> extract_config(std::shared_ptr<vm::StaticBagOfCellsDb> static_boc,
                                                                int mode = 0);
  static td::Result<std::unique_ptr<ConfigInfo>> extract_config(Ref<vm::Cell> mc_state_root, int mode = 0);

 private:
  ConfigInfo(Ref<vm::Cell> mc_state_root, int _mode = 0);
  td::Status unpack_wrapped();
  td::Status unpack();
  void reset_mc_hash();
  void cleanup();
};

}  // namespace block
