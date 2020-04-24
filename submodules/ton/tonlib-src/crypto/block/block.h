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
#include "common/refcnt.hpp"
#include "vm/cells.h"
#include "vm/cellslice.h"
#include "vm/dict.h"
#include "vm/boc.h"
#include "vm/stack.hpp"
#include <ostream>
#include "tl/tlblib.hpp"
#include "td/utils/bits.h"
#include "td/utils/CancellationToken.h"
#include "td/utils/StringBuilder.h"
#include "ton/ton-types.h"

namespace block {

using td::Ref;

struct PublicKey {
  std::string key;

  static td::Result<PublicKey> from_bytes(td::Slice key);

  static td::Result<PublicKey> parse(td::Slice key);

  std::string serialize(bool base64_url = false);
};

struct StdAddress {
  ton::WorkchainId workchain{ton::workchainInvalid};
  bool bounceable{true};  // addresses must be bounceable by default
  bool testnet{false};
  ton::StdSmcAddress addr;
  StdAddress() = default;
  StdAddress(ton::WorkchainId _wc, const ton::StdSmcAddress& _addr, bool _bounce = true, bool _testnet = false)
      : workchain(_wc), bounceable(_bounce), testnet(_testnet), addr(_addr) {
  }
  StdAddress(ton::WorkchainId _wc, td::ConstBitPtr _addr, bool _bounce = true, bool _testnet = false)
      : workchain(_wc), bounceable(_bounce), testnet(_testnet), addr(_addr) {
  }
  explicit StdAddress(std::string serialized);
  explicit StdAddress(td::Slice from);
  bool is_valid() const {
    return workchain != ton::workchainInvalid;
  }
  bool invalidate() {
    workchain = ton::workchainInvalid;
    return false;
  }
  std::string rserialize(bool base64_url = false) const;
  bool rserialize_to(td::MutableSlice to, bool base64_url = false) const;
  bool rserialize_to(char to[48], bool base64_url = false) const;
  bool rdeserialize(td::Slice from);
  bool rdeserialize(std::string from);
  bool rdeserialize(const char from[48]);
  bool parse_addr(td::Slice acc_string);
  bool operator==(const StdAddress& other) const;

  static td::Result<StdAddress> parse(td::Slice acc_string);
};

inline td::StringBuilder& operator<<(td::StringBuilder& sb, const StdAddress& addr) {
  return sb << addr.workchain << " : " << addr.addr.to_hex();
}

bool parse_std_account_addr(td::Slice acc_string, ton::WorkchainId& wc, ton::StdSmcAddress& addr,
                            bool* bounceable = nullptr, bool* testnet_only = nullptr);

struct ShardId {
  ton::WorkchainId workchain_id;
  int shard_pfx_len;
  unsigned long long shard_pfx;
  ShardId(ton::WorkchainId wc_id = ton::workchainInvalid)
      : workchain_id(wc_id), shard_pfx_len(0), shard_pfx(1ULL << 63) {
  }
  ShardId(ton::WorkchainId wc_id, unsigned long long sh_pfx);
  ShardId(ton::ShardIdFull ton_shard);
  ShardId(ton::BlockId ton_block);
  ShardId(const ton::BlockIdExt& ton_block);
  ShardId(ton::WorkchainId wc_id, unsigned long long sh_pfx, int sh_pfx_len);
  ShardId(vm::CellSlice& cs) {
    deserialize(cs);
  }
  ShardId(Ref<vm::CellSlice> cs_ref) {
    vm::CellSlice cs{*cs_ref};
    deserialize(cs);
  }
  explicit operator ton::ShardIdFull() const {
    return ton::ShardIdFull{workchain_id, shard_pfx};
  }
  bool operator==(const ShardId& other) const {
    return workchain_id == other.workchain_id && shard_pfx == other.shard_pfx;
  }
  void invalidate() {
    workchain_id = ton::workchainInvalid;
    shard_pfx_len = 0;
  }
  bool is_valid() const {
    return workchain_id != ton::workchainInvalid;
  }
  void show(std::ostream& os) const;
  std::string to_str() const;
  bool serialize(vm::CellBuilder& cb) const;
  bool deserialize(vm::CellSlice& cs);

 private:
  void init();
};

struct EnqueuedMsgDescr {
  ton::AccountIdPrefixFull src_prefix_, cur_prefix_, next_prefix_, dest_prefix_;
  ton::LogicalTime lt_;
  ton::LogicalTime enqueued_lt_;
  ton::Bits256 hash_;
  Ref<vm::Cell> msg_;
  Ref<vm::Cell> msg_env_;
  EnqueuedMsgDescr() = default;
  EnqueuedMsgDescr(ton::AccountIdPrefixFull cur_pfx, ton::AccountIdPrefixFull next_pfx, ton::LogicalTime lt,
                   ton::LogicalTime enqueued_lt, td::ConstBitPtr hash)
      : cur_prefix_(cur_pfx), next_prefix_(next_pfx), lt_(lt), enqueued_lt_(enqueued_lt), hash_(hash) {
  }
  bool is_valid() const {
    return next_prefix_.is_valid();
  }
  bool check_key(td::ConstBitPtr key) const;
  bool invalidate() {
    next_prefix_.workchain = cur_prefix_.workchain = ton::workchainInvalid;
    return false;
  }
  bool unpack(vm::CellSlice& cs);
  bool same_workchain() const {
    return cur_prefix_.workchain == next_prefix_.workchain;
  }
};

using compute_shard_end_lt_func_t = std::function<ton::LogicalTime(ton::AccountIdPrefixFull)>;

struct MsgProcessedUpto {
  ton::ShardId shard;
  ton::BlockSeqno mc_seqno;
  ton::LogicalTime last_inmsg_lt;
  ton::Bits256 last_inmsg_hash;
  compute_shard_end_lt_func_t compute_shard_end_lt;
  MsgProcessedUpto() = default;
  MsgProcessedUpto(ton::ShardId _shard, ton::BlockSeqno _mcseqno, ton::LogicalTime _lt, td::ConstBitPtr _hash)
      : shard(_shard), mc_seqno(_mcseqno), last_inmsg_lt(_lt), last_inmsg_hash(_hash) {
  }
  bool operator<(const MsgProcessedUpto& other) const& {
    return shard < other.shard || (shard == other.shard && mc_seqno < other.mc_seqno);
  }
  bool contains(const MsgProcessedUpto& other) const&;
  bool contains(ton::ShardId other_shard, ton::LogicalTime other_lt, td::ConstBitPtr other_hash,
                ton::BlockSeqno other_mc_seqno) const&;
  // NB: this is for checking whether we have already imported an internal message
  bool already_processed(const EnqueuedMsgDescr& msg) const;
  bool can_check_processed() const {
    return (bool)compute_shard_end_lt;
  }
  std::ostream& print(std::ostream& os) const;
  std::string to_str() const;
};

static inline std::ostream& operator<<(std::ostream& os, const MsgProcessedUpto& proc) {
  return proc.print(os);
}

struct MsgProcessedUptoCollection {
  ton::ShardIdFull owner;
  bool valid{false};
  std::vector<MsgProcessedUpto> list;
  MsgProcessedUptoCollection(ton::ShardIdFull _owner) : owner(_owner) {
  }
  MsgProcessedUptoCollection(ton::ShardIdFull _owner, Ref<vm::CellSlice> cs_ref);
  static std::unique_ptr<MsgProcessedUptoCollection> unpack(ton::ShardIdFull _owner, Ref<vm::CellSlice> cs_ref);
  bool is_valid() const {
    return valid;
  }
  bool insert(ton::BlockSeqno mc_seqno, ton::LogicalTime last_proc_lt, td::ConstBitPtr last_proc_hash);
  bool insert_infty(ton::BlockSeqno mc_seqno, ton::LogicalTime last_proc_lt = ~0ULL);
  bool compactify();
  bool pack(vm::CellBuilder& cb);
  bool is_reduced() const;
  bool contains(const MsgProcessedUpto& other) const;
  bool contains(const MsgProcessedUptoCollection& other) const;
  const MsgProcessedUpto* is_simple_update_of(const MsgProcessedUptoCollection& other, bool& ok) const;
  ton::BlockSeqno min_mc_seqno() const;
  bool split(ton::ShardIdFull new_owner);
  bool combine_with(const MsgProcessedUptoCollection& other);
  // NB: this is for checking whether we have already imported an internal message
  bool already_processed(const EnqueuedMsgDescr& msg) const;
  bool can_check_processed() const;
  bool for_each_mcseqno(std::function<bool(ton::BlockSeqno)>) const;
  std::ostream& print(std::ostream& os) const;
  std::string to_str() const;
};

static inline std::ostream& operator<<(std::ostream& os, const MsgProcessedUptoCollection& proc_coll) {
  return proc_coll.print(os);
}

struct ParamLimits {
  enum { limits_cnt = 4 };
  enum { cl_underload = 0, cl_normal = 1, cl_soft = 2, cl_medium = 3, cl_hard = 4 };
  ParamLimits() = default;
  ParamLimits(td::uint32 underload, td::uint32 soft_lim, td::uint32 hard_lim)
      : limits_{underload, soft_lim, (soft_lim + hard_lim) / 2, hard_lim} {
  }
  td::uint32 underload() const {
    return limits_[0];
  }
  td::uint32 soft() const {
    return limits_[1];
  }
  td::uint32 hard() const {
    return limits_[3];
  }
  bool compute_medium_limit() {
    limits_[2] = soft() + ((hard() - soft()) >> 1);
    return true;
  }
  bool deserialize(vm::CellSlice& cs);
  int classify(td::uint64 value) const;
  bool fits(unsigned cls, td::uint64 value) const;

 private:
  std::array<td::uint32, limits_cnt> limits_;
};

struct BlockLimits {
  ParamLimits bytes, gas, lt_delta;
  ton::LogicalTime start_lt{0};
  const vm::CellUsageTree* usage_tree{nullptr};
  bool deserialize(vm::CellSlice& cs);
  int classify_size(td::uint64 size) const;
  int classify_gas(td::uint64 gas) const;
  int classify_lt(ton::LogicalTime lt) const;
  int classify(td::uint64 size, td::uint64 gas, ton::LogicalTime lt) const;
  bool fits(unsigned cls, td::uint64 size, td::uint64 gas, ton::LogicalTime lt) const;
};

struct BlockLimitStatus {
  const BlockLimits& limits;
  ton::LogicalTime cur_lt;
  td::uint64 gas_used{};
  vm::NewCellStorageStat st_stat;
  unsigned accounts{}, transactions{};
  BlockLimitStatus(const BlockLimits& limits_, ton::LogicalTime lt = 0)
      : limits(limits_), cur_lt(std::max(limits_.start_lt, lt)) {
  }
  void reset() {
    cur_lt = limits.start_lt;
    st_stat.set_zero();
    transactions = accounts = 0;
    gas_used = 0;
  }
  td::uint64 estimate_block_size(const vm::NewCellStorageStat::Stat* extra = nullptr) const;
  int classify() const;
  bool fits(unsigned cls) const;
  bool would_fit(unsigned cls, ton::LogicalTime end_lt, td::uint64 more_gas,
                 const vm::NewCellStorageStat::Stat* extra = nullptr) const;
  bool add_cell(Ref<vm::Cell> cell) {
    st_stat.add_cell(std::move(cell));
    return true;
  }
  bool add_proof(Ref<vm::Cell> cell) {
    st_stat.add_proof(std::move(cell), limits.usage_tree);
    return true;
  }
  bool update_lt(ton::LogicalTime lt) {
    cur_lt = std::max(lt, cur_lt);
    return true;
  }
  bool update_gas(td::uint64 more_gas) {
    gas_used += more_gas;
    return true;
  }
  bool add_transaction(unsigned cnt = 1) {
    transactions += cnt;
    return true;
  }
  bool add_account(unsigned cnt = 1) {
    accounts += cnt;
    return true;
  }
};

namespace tlb {
struct CurrencyCollection;
}  // namespace tlb

struct CurrencyCollection {
  using type_class = block::tlb::CurrencyCollection;
  td::RefInt256 grams;
  Ref<vm::Cell> extra;
  CurrencyCollection() = default;
  explicit CurrencyCollection(td::RefInt256 _grams, Ref<vm::Cell> _extra = {})
      : grams(std::move(_grams)), extra(std::move(_extra)) {
  }
  explicit CurrencyCollection(long long _grams, Ref<vm::Cell> _extra = {})
      : grams(true, _grams), extra(std::move(_extra)) {
  }
  bool set_zero() {
    grams = td::RefInt256{true, 0};
    extra.clear();
    return true;
  }
  static CurrencyCollection zero() {
    return CurrencyCollection(td::RefInt256{true, 0});
  }
  bool is_valid() const {
    return grams.not_null();
  }
  bool is_zero() const {
    return is_valid() && extra.is_null() && !td::sgn(grams);
  }
  bool has_extra() const {
    return extra.not_null();
  }
  bool invalidate() {
    extra.clear();
    grams.clear();
    return false;
  }
  bool validate(int max_cells = 1024) const;
  bool validate_extra(int max_cells = 1024) const;
  bool operator==(const CurrencyCollection& other) const;
  bool operator!=(const CurrencyCollection& other) const {
    return !operator==(other);
  }
  bool operator==(td::RefInt256 other_grams) const {
    return is_valid() && !has_extra() && !td::cmp(grams, other_grams);
  }
  bool operator!=(td::RefInt256 other_grams) const {
    return !operator==(std::move(other_grams));
  }
  bool operator>=(const CurrencyCollection& other) const;
  bool operator<=(const CurrencyCollection& other) const {
    return other >= *this;
  }
  static bool add(const CurrencyCollection& a, const CurrencyCollection& b, CurrencyCollection& c);
  static bool add(const CurrencyCollection& a, CurrencyCollection&& b, CurrencyCollection& c);
  CurrencyCollection& operator+=(const CurrencyCollection& other);
  CurrencyCollection& operator+=(CurrencyCollection&& other);
  CurrencyCollection& operator+=(td::RefInt256 other_grams);
  CurrencyCollection operator+(const CurrencyCollection& other) const;
  CurrencyCollection operator+(CurrencyCollection&& other) const;
  CurrencyCollection operator+(td::RefInt256 other_grams);
  static bool sub(const CurrencyCollection& a, const CurrencyCollection& b, CurrencyCollection& c);
  static bool sub(const CurrencyCollection& a, CurrencyCollection&& b, CurrencyCollection& c);
  CurrencyCollection& operator-=(const CurrencyCollection& other);
  CurrencyCollection& operator-=(CurrencyCollection&& other);
  CurrencyCollection& operator-=(td::RefInt256 other_grams);
  CurrencyCollection operator-(const CurrencyCollection& other) const;
  CurrencyCollection operator-(CurrencyCollection&& other) const;
  CurrencyCollection operator-(td::RefInt256 other_grams) const;
  bool store(vm::CellBuilder& cb) const;
  bool store_or_zero(vm::CellBuilder& cb) const;
  bool fetch(vm::CellSlice& cs);
  bool fetch_exact(vm::CellSlice& cs);
  bool unpack(Ref<vm::CellSlice> csr);
  bool validate_unpack(Ref<vm::CellSlice> csr, int max_cells = 1024);
  Ref<vm::CellSlice> pack() const;
  bool pack_to(Ref<vm::CellSlice>& csr) const {
    return (csr = pack()).not_null();
  }
  Ref<vm::Tuple> as_vm_tuple() const {
    if (is_valid()) {
      return vm::make_tuple_ref(grams, vm::StackEntry::maybe(extra));
    } else {
      return {};
    }
  }
  bool show(std::ostream& os) const;
  std::string to_str() const;
};

std::ostream& operator<<(std::ostream& os, const CurrencyCollection& cc);

struct ShardState {
  enum { verbosity = 0 };
  ton::BlockIdExt id_;
  Ref<vm::Cell> root_;
  int global_id_;
  ton::UnixTime utime_;
  ton::LogicalTime lt_;
  ton::BlockSeqno mc_blk_seqno_, min_ref_mc_seqno_, vert_seqno_;
  ton::BlockIdExt mc_blk_ref_;
  ton::LogicalTime mc_blk_lt_;
  bool before_split_{false};
  std::unique_ptr<vm::AugmentedDictionary> account_dict_;
  std::unique_ptr<vm::Dictionary> shard_libraries_;
  Ref<vm::Cell> mc_state_extra_;
  td::uint64 overload_history_{0}, underload_history_{0};
  CurrencyCollection total_balance_, total_validator_fees_, global_balance_;
  std::unique_ptr<vm::AugmentedDictionary> out_msg_queue_;
  std::unique_ptr<vm::Dictionary> ihr_pending_;
  std::unique_ptr<vm::Dictionary> block_create_stats_;
  std::shared_ptr<block::MsgProcessedUptoCollection> processed_upto_;

  bool is_valid() const {
    return id_.is_valid();
  }
  bool is_masterchain() const {
    return id_.is_masterchain();
  }
  bool invalidate() {
    id_.invalidate();
    return false;
  }
  td::Status unpack_state(ton::BlockIdExt id, Ref<vm::Cell> state_root);
  td::Status unpack_state_ext(ton::BlockIdExt id, Ref<vm::Cell> state_root, int global_id,
                              ton::BlockSeqno prev_mc_block_seqno, bool after_split, bool clear_history,
                              std::function<bool(ton::BlockSeqno)> for_each_mcseqno);
  td::Status merge_with(ShardState& sib);
  td::Result<std::unique_ptr<vm::AugmentedDictionary>> compute_split_out_msg_queue(ton::ShardIdFull subshard);
  td::Result<std::shared_ptr<block::MsgProcessedUptoCollection>> compute_split_processed_upto(
      ton::ShardIdFull subshard);
  td::Status split(ton::ShardIdFull subshard);
  td::Status unpack_out_msg_queue_info(Ref<vm::Cell> out_msg_queue_info);
  bool clear_load_history() {
    overload_history_ = underload_history_ = 0;
    return true;
  }
  bool clear_load_history_if(bool cond) {
    return !cond || clear_load_history();
  }
  td::Status check_before_split(bool before_split) const;
  td::Status check_global_id(int req_global_id) const;
  td::Status check_mc_blk_seqno(ton::BlockSeqno last_mc_block_seqno) const;
  bool update_prev_utime_lt(ton::UnixTime& prev_utime, ton::LogicalTime& prev_lt) const;

  bool for_each_mcseqno(std::function<bool(ton::BlockSeqno)> func) const {
    return processed_upto_ && processed_upto_->for_each_mcseqno(std::move(func));
  }
};

struct ValueFlow {
  struct SetZero {};
  CurrencyCollection from_prev_blk, to_next_blk, imported, exported, fees_collected, fees_imported, recovered, created,
      minted;
  ValueFlow() = default;
  ValueFlow(SetZero)
      : from_prev_blk{0}
      , to_next_blk{0}
      , imported{0}
      , exported{0}
      , fees_collected{0}
      , fees_imported{0}
      , recovered{0}
      , created{0}
      , minted{0} {
  }
  bool is_valid() const {
    return from_prev_blk.is_valid() && minted.is_valid();
  }
  bool validate() const;
  bool invalidate() {
    return from_prev_blk.invalidate();
  }
  bool set_zero();
  bool store(vm::CellBuilder& cb) const;
  bool fetch(vm::CellSlice& cs);
  bool unpack(Ref<vm::CellSlice> csr);
  bool show(std::ostream& os) const;
  std::string to_str() const;

 private:
  bool show_one(std::ostream& os, const char* str, const CurrencyCollection& cc) const;
};

std::ostream& operator<<(std::ostream& os, const ValueFlow& vflow);

struct DiscountedCounter {
  struct SetZero {};
  bool valid;
  ton::UnixTime last_updated;
  td::uint64 total;
  td::uint64 cnt2048;
  td::uint64 cnt65536;
  DiscountedCounter() : valid(false) {
  }
  DiscountedCounter(SetZero) : valid(true), last_updated(0), total(0), cnt2048(0), cnt65536(0) {
  }
  DiscountedCounter(ton::UnixTime _lastupd, td::uint64 _total, td::uint64 _cnt2048, td::uint64 _cnt65536)
      : valid(true), last_updated(_lastupd), total(_total), cnt2048(_cnt2048), cnt65536(_cnt65536) {
  }
  static DiscountedCounter Zero() {
    return SetZero();
  }
  bool is_valid() const {
    return valid;
  }
  bool invalidate() {
    return (valid = false);
  }
  bool set_zero() {
    last_updated = 0;
    total = cnt2048 = cnt65536 = 0;
    return (valid = true);
  }
  bool is_zero() const {
    return !total;
  }
  bool almost_zero() const {
    return (cnt2048 | cnt65536) <= 1;
  }
  bool operator==(const DiscountedCounter& other) const {
    return last_updated == other.last_updated && total == other.total && cnt2048 == other.cnt2048 &&
           cnt65536 == other.cnt65536;
  }
  bool almost_equals(const DiscountedCounter& other) const {
    return last_updated == other.last_updated && total == other.total && cnt2048 <= other.cnt2048 + 1 &&
           other.cnt2048 <= cnt2048 + 1 && cnt65536 <= other.cnt65536 + 1 && other.cnt65536 <= cnt65536 + 1;
  }
  bool modified_since(ton::UnixTime utime) const {
    return last_updated >= utime;
  }
  bool validate();
  bool increase_by(unsigned count, ton::UnixTime now);
  bool fetch(vm::CellSlice& cs);
  bool unpack(Ref<vm::CellSlice> csr);
  bool store(vm::CellBuilder& cb) const;
  Ref<vm::CellSlice> pack() const;
  bool show(std::ostream& os) const;
  std::string to_str() const;
};

static inline std::ostream& operator<<(std::ostream& os, const DiscountedCounter& dcount) {
  dcount.show(os);
  return os;
}

bool fetch_CreatorStats(vm::CellSlice& cs, DiscountedCounter& mc_cnt, DiscountedCounter& shard_cnt);
bool store_CreatorStats(vm::CellBuilder& cb, const DiscountedCounter& mc_cnt, const DiscountedCounter& shard_cnt);
bool unpack_CreatorStats(Ref<vm::CellSlice> cs, DiscountedCounter& mc_cnt, DiscountedCounter& shard_cnt);

struct BlockProofLink {
  ton::BlockIdExt from, to;
  bool is_key{false}, is_fwd{false};
  Ref<vm::Cell> dest_proof, state_proof, proof;
  ton::CatchainSeqno cc_seqno{0};
  td::uint32 validator_set_hash{0};
  std::vector<ton::BlockSignature> signatures;
  BlockProofLink(ton::BlockIdExt _from, ton::BlockIdExt _to, bool _iskey = false)
      : from(_from), to(_to), is_key(_iskey), is_fwd(to.seqno() > from.seqno()) {
  }
  bool incomplete() const {
    return dest_proof.is_null();
  }
  td::Status validate(td::uint32* save_utime = nullptr) const;
};

struct BlockProofChain {
  ton::BlockIdExt from, to;
  int mode;
  td::uint32 last_utime{0};
  bool complete{false}, has_key_block{false}, has_utime{false}, valid{false};
  ton::BlockIdExt key_blkid;
  std::vector<BlockProofLink> links;
  std::size_t link_count() const {
    return links.size();
  }
  BlockProofChain(ton::BlockIdExt _from, ton::BlockIdExt _to, int _mode = 0) : from(_from), to(_to), mode(_mode) {
  }
  BlockProofLink& new_link(const ton::BlockIdExt& cur, const ton::BlockIdExt& next, bool iskey = false) {
    links.emplace_back(cur, next, iskey);
    return links.back();
  }
  const BlockProofLink& last_link() const {
    return links.back();
  }
  BlockProofLink& last_link() {
    return links.back();
  }
  bool last_link_incomplete() const {
    return !links.empty() && last_link().incomplete();
  }
  td::Status validate(td::CancellationToken cancellation_token = {});
};

// compute the share of shardchain blocks generated by each validator using Monte Carlo method
class MtCarloComputeShare {
  int K, N;
  long long iterations;
  std::vector<double> W;
  std::vector<double> CW, RW;
  std::vector<std::pair<double, double>> H;
  std::vector<int> A;
  double R0;
  bool ok;

 public:
  MtCarloComputeShare(int subset_size, const std::vector<double>& weights, long long iteration_count = 1000000)
      : K(subset_size), N((int)weights.size()), iterations(iteration_count), W(weights), ok(false) {
    compute();
  }
  MtCarloComputeShare(int subset_size, int set_size, const double* weights, long long iteration_count = 1000000)
      : K(subset_size), N(set_size), iterations(iteration_count), W(weights, weights + set_size), ok(false) {
    compute();
  }
  bool is_ok() const {
    return ok;
  }
  const double* share_array() const {
    return ok ? RW.data() : nullptr;
  }
  const double* weights_array() const {
    return ok ? W.data() : nullptr;
  }
  double operator[](int i) const {
    return ok ? RW.at(i) : -1.;
  }
  double share(int i) const {
    return ok ? RW.at(i) : -1.;
  }
  double weight(int i) const {
    return ok ? W.at(i) : -1.;
  }
  int size() const {
    return N;
  }
  int subset_size() const {
    return K;
  }
  long long performed_iterations() const {
    return iterations;
  }

 private:
  bool set_error() {
    return ok = false;
  }
  bool compute();
  void gen_vset();
};

int filter_out_msg_queue(vm::AugmentedDictionary& out_queue, ton::ShardIdFull old_shard, ton::ShardIdFull subshard);

std::ostream& operator<<(std::ostream& os, const ShardId& shard_id);

bool pack_std_smc_addr_to(char result[48], bool base64_url, ton::WorkchainId wc, const ton::StdSmcAddress& addr,
                          bool bounceable, bool testnet);
std::string pack_std_smc_addr(bool base64_url, ton::WorkchainId wc, const ton::StdSmcAddress& addr, bool bounceable,
                              bool testnet);
bool unpack_std_smc_addr(const char packed[48], ton::WorkchainId& wc, ton::StdSmcAddress& addr, bool& bounceable,
                         bool& testnet);
bool unpack_std_smc_addr(td::Slice packed, ton::WorkchainId& wc, ton::StdSmcAddress& addr, bool& bounceable,
                         bool& testnet);
bool unpack_std_smc_addr(std::string packed, ton::WorkchainId& wc, ton::StdSmcAddress& addr, bool& bounceable,
                         bool& testnet);

bool store_UInt7(vm::CellBuilder& cb, unsigned long long value);
bool store_UInt7(vm::CellBuilder& cb, unsigned long long value1, unsigned long long value2);
bool store_Maybe_Grams(vm::CellBuilder& cb, td::RefInt256 value);
bool store_Maybe_Grams_nz(vm::CellBuilder& cb, td::RefInt256 value);
bool store_CurrencyCollection(vm::CellBuilder& cb, td::RefInt256 value, Ref<vm::Cell> extra);
bool fetch_CurrencyCollection(vm::CellSlice& cs, td::RefInt256& value, Ref<vm::Cell>& extra, bool inexact = false);
bool unpack_CurrencyCollection(Ref<vm::CellSlice> csr, td::RefInt256& value, Ref<vm::Cell>& extra);

bool valid_library_collection(Ref<vm::Cell> cell, bool catch_errors = true);

bool valid_config_data(Ref<vm::Cell> cell, const td::BitArray<256>& addr, bool catch_errors = true,
                       bool relax_par0 = false, Ref<vm::Cell> old_mparams = {});
bool config_params_present(vm::Dictionary& dict, Ref<vm::Cell> param_dict_root);

bool add_extra_currency(Ref<vm::Cell> extra1, Ref<vm::Cell> extra2, Ref<vm::Cell>& res);
bool sub_extra_currency(Ref<vm::Cell> extra1, Ref<vm::Cell> extra2, Ref<vm::Cell>& res);

ton::AccountIdPrefixFull interpolate_addr(const ton::AccountIdPrefixFull& src, const ton::AccountIdPrefixFull& dest,
                                          int used_dest_bits);
bool interpolate_addr_to(const ton::AccountIdPrefixFull& src, const ton::AccountIdPrefixFull& dest, int used_dest_bits,
                         ton::AccountIdPrefixFull& res);
// result: (transit_addr_dest_bits, nh_addr_dest_bits)
std::pair<int, int> perform_hypercube_routing(ton::AccountIdPrefixFull src, ton::AccountIdPrefixFull dest,
                                              ton::ShardIdFull cur, int used_dest_bits = 0);

bool compute_out_msg_queue_key(Ref<vm::Cell> msg_env, td::BitArray<352>& key);

bool unpack_block_prev_blk(Ref<vm::Cell> block_root, const ton::BlockIdExt& id, std::vector<ton::BlockIdExt>& prev,
                           ton::BlockIdExt& mc_blkid, bool& after_split, ton::BlockIdExt* fetch_blkid = nullptr);
td::Status unpack_block_prev_blk_ext(Ref<vm::Cell> block_root, const ton::BlockIdExt& id,
                                     std::vector<ton::BlockIdExt>& prev, ton::BlockIdExt& mc_blkid, bool& after_split,
                                     ton::BlockIdExt* fetch_blkid = nullptr);
td::Status unpack_block_prev_blk_try(Ref<vm::Cell> block_root, const ton::BlockIdExt& id,
                                     std::vector<ton::BlockIdExt>& prev, ton::BlockIdExt& mc_blkid, bool& after_split,
                                     ton::BlockIdExt* fetch_blkid = nullptr);
td::Status check_block_header(Ref<vm::Cell> block_root, const ton::BlockIdExt& id,
                              ton::Bits256* store_shard_hash_to = nullptr);

std::unique_ptr<vm::Dictionary> get_block_create_stats_dict(Ref<vm::Cell> state_root);

std::unique_ptr<vm::AugmentedDictionary> get_prev_blocks_dict(Ref<vm::Cell> state_root);
bool get_old_mc_block_id(vm::AugmentedDictionary* prev_blocks_dict, ton::BlockSeqno seqno, ton::BlockIdExt& blkid,
                         ton::LogicalTime* end_lt = nullptr);
bool get_old_mc_block_id(vm::AugmentedDictionary& prev_blocks_dict, ton::BlockSeqno seqno, ton::BlockIdExt& blkid,
                         ton::LogicalTime* end_lt = nullptr);
bool unpack_old_mc_block_id(Ref<vm::CellSlice> old_blk_info, ton::BlockSeqno seqno, ton::BlockIdExt& blkid,
                            ton::LogicalTime* end_lt = nullptr);
bool check_old_mc_block_id(vm::AugmentedDictionary* prev_blocks_dict, const ton::BlockIdExt& blkid);
bool check_old_mc_block_id(vm::AugmentedDictionary& prev_blocks_dict, const ton::BlockIdExt& blkid);

td::Result<Ref<vm::Cell>> get_block_transaction(Ref<vm::Cell> block_root, ton::WorkchainId workchain,
                                                const ton::StdSmcAddress& addr, ton::LogicalTime lt);
td::Result<Ref<vm::Cell>> get_block_transaction_try(Ref<vm::Cell> block_root, ton::WorkchainId workchain,
                                                    const ton::StdSmcAddress& addr, ton::LogicalTime lt);

bool get_transaction_in_msg(Ref<vm::Cell> trans_ref, Ref<vm::Cell>& in_msg);
bool is_transaction_in_msg(Ref<vm::Cell> trans_ref, Ref<vm::Cell> msg);
bool is_transaction_out_msg(Ref<vm::Cell> trans_ref, Ref<vm::Cell> msg);
bool get_transaction_id(Ref<vm::Cell> trans_ref, ton::StdSmcAddress& account_addr, ton::LogicalTime& lt);
bool get_transaction_owner(Ref<vm::Cell> trans_ref, ton::StdSmcAddress& addr);

td::uint32 compute_validator_set_hash(ton::CatchainSeqno cc_seqno, ton::ShardIdFull from,
                                      const std::vector<ton::ValidatorDescr>& nodes);

td::Result<Ref<vm::Cell>> get_config_data_from_smc(Ref<vm::Cell> acc_root);
td::Result<Ref<vm::Cell>> get_config_data_from_smc(Ref<vm::CellSlice> acc_csr);
bool important_config_parameters_changed(Ref<vm::Cell> old_cfg_root, Ref<vm::Cell> new_cfg_root, bool coarse = false);

bool is_public_library(td::ConstBitPtr key, Ref<vm::CellSlice> val);

bool parse_hex_hash(const char* str, const char* end, td::Bits256& hash);
bool parse_hex_hash(td::Slice str, td::Bits256& hash);

bool parse_block_id_ext(const char* str, const char* end, ton::BlockIdExt& blkid);
bool parse_block_id_ext(td::Slice str, ton::BlockIdExt& blkid);

}  // namespace block
