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

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "mc-config.h"
#include "block/block.h"
#include "block/block-parse.h"
#include "block/block-auto.h"
#include "common/bitstring.h"
#include "vm/dict.h"
#include "td/utils/bits.h"
#include "td/utils/uint128.h"
#include "ton/ton-types.h"
#include "ton/ton-shard.h"
#include "openssl/digest.hpp"
#include <stack>
#include <algorithm>

namespace block {
using namespace std::literals::string_literals;
using td::Ref;

#define DBG(__n) dbg(__n)&&
#define DSTART int __dcnt = 0;
#define DEB DBG(++__dcnt)

static inline bool dbg(int c) TD_UNUSED;
static inline bool dbg(int c) {
  std::cerr << '[' << (char)('0' + c / 10) << (char)('0' + c % 10) << ']';
  return true;
}

Config::Config(Ref<vm::Cell> config_root, const td::Bits256& config_addr, int _mode)
    : mode(_mode), config_addr(config_addr), config_root(std::move(config_root)) {
}

td::Result<std::unique_ptr<Config>> Config::unpack_config(Ref<vm::Cell> config_root, const td::Bits256& config_addr,
                                                          int mode) {
  std::unique_ptr<Config> ptr{new Config(std::move(config_root), config_addr, mode)};
  TRY_STATUS(ptr->unpack_wrapped());
  return std::move(ptr);
}

td::Result<std::unique_ptr<Config>> Config::unpack_config(Ref<vm::CellSlice> config_csr, int mode) {
  std::unique_ptr<Config> ptr{new Config(mode)};
  TRY_STATUS(ptr->unpack_wrapped(std::move(config_csr)));
  return std::move(ptr);
}

td::Result<std::unique_ptr<Config>> Config::extract_from_key_block(Ref<vm::Cell> key_block_root, int mode) {
  block::gen::Block::Record blk;
  block::gen::BlockExtra::Record extra;
  block::gen::McBlockExtra::Record mc_extra;
  if (!(tlb::unpack_cell(key_block_root, blk) && tlb::unpack_cell(std::move(blk.extra), extra) &&
        tlb::unpack_cell(extra.custom->prefetch_ref(), mc_extra) && mc_extra.key_block && mc_extra.config.not_null())) {
    return td::Status::Error(-400, "cannot unpack extra header of key block to extract configuration");
  }
  return block::Config::unpack_config(std::move(mc_extra.config), mode);
}

td::Result<std::unique_ptr<Config>> Config::extract_from_state(Ref<vm::Cell> mc_state_root, int mode) {
  gen::ShardStateUnsplit::Record state;
  gen::McStateExtra::Record extra;
  if (!(tlb::unpack_cell(mc_state_root, state) && state.global_id &&
        tlb::unpack_cell(state.custom->prefetch_ref(), extra))) {
    return td::Status::Error("cannot extract configuration from masterchain state extra information");
  }
  return unpack_config(std::move(extra.config), mode);
}

td::Result<std::unique_ptr<ConfigInfo>> ConfigInfo::extract_config(std::shared_ptr<vm::StaticBagOfCellsDb> static_boc,
                                                                   int mode) {
  TRY_RESULT(rc, static_boc->get_root_count());
  if (rc != 1) {
    return td::Status::Error(-668, "Masterchain state BoC is invalid");
  }
  TRY_RESULT(root, static_boc->get_root_cell(0));
  return extract_config(std::move(root), mode);
}

td::Result<std::unique_ptr<ConfigInfo>> ConfigInfo::extract_config(Ref<vm::Cell> mc_state_root, int mode) {
  if (mc_state_root.is_null()) {
    return td::Status::Error("configuration state root cell is null");
  }
  auto config = std::unique_ptr<ConfigInfo>{new ConfigInfo(std::move(mc_state_root), mode)};
  TRY_STATUS(config->unpack_wrapped());
  return std::move(config);
}

ConfigInfo::ConfigInfo(Ref<vm::Cell> mc_state_root, int _mode) : Config(_mode), state_root(std::move(mc_state_root)) {
  block_id.root_hash.set_zero();
  block_id.file_hash.set_zero();
}

td::Status ConfigInfo::unpack_wrapped() {
  try {
    return unpack();
  } catch (vm::VmError& err) {
    return td::Status::Error(PSLICE() << "error unpacking block state header and configuration: " << err.get_msg());
  } catch (vm::VmVirtError& err) {
    return td::Status::Error(PSLICE() << "virtualization error while unpacking block state header and configuration: "
                                      << err.get_msg());
  }
}

td::Status ConfigInfo::unpack() {
  gen::ShardStateUnsplit::Record root_info;
  if (!tlb::unpack_cell(state_root, root_info) || !root_info.global_id) {
    return td::Status::Error("configuration state root cannot be deserialized");
  }
  global_id_ = root_info.global_id;
  block::ShardId shard_id{root_info.shard_id};
  block_id.id = ton::BlockId{ton::ShardIdFull(shard_id), (unsigned)root_info.seq_no};
  block_id.root_hash.set_zero();
  block_id.file_hash.set_zero();
  vert_seqno = root_info.vert_seq_no;
  utime = root_info.gen_utime;
  lt = root_info.gen_lt;
  min_ref_mc_seqno_ = root_info.min_ref_mc_seqno;
  if (!root_info.custom->size_refs()) {
    return td::Status::Error("state does not have a `custom` field with masterchain configuration");
  }
  if (mode & needLibraries) {
    lib_root_ = root_info.r1.libraries->prefetch_ref();
    libraries_dict_ = std::make_unique<vm::Dictionary>(lib_root_, 256);
  }
  if (mode & needAccountsRoot) {
    accounts_root = vm::load_cell_slice_ref(root_info.accounts);
    LOG(DEBUG) << "requested accounts dictionary";
    accounts_dict = std::make_unique<vm::AugmentedDictionary>(accounts_root, 256, block::tlb::aug_ShardAccounts);
    LOG(DEBUG) << "accounts dictionary created";
  }
  state_extra_root_ = root_info.custom->prefetch_ref();
  if (!is_masterchain()) {
    if (mode & (needShardHashes | needValidatorSet | needSpecialSmc | needPrevBlocks | needWorkchainInfo)) {
      return td::Status::Error("cannot extract masterchain-specific configuration data from a non-masterchain state");
    }
    cleanup();
    return td::Status::OK();
  }
  gen::McStateExtra::Record extra_info;
  if (!tlb::unpack_cell(state_extra_root_, extra_info)) {
    vm::load_cell_slice(state_extra_root_).print_rec(std::cerr);
    block::gen::t_McStateExtra.print_ref(std::cerr, state_extra_root_);
    return td::Status::Error("state extra information is invalid");
  }
  gen::ValidatorInfo::Record validator_info;
  if (!tlb::csr_unpack(extra_info.r1.validator_info, validator_info)) {
    return td::Status::Error("validator_info in state extra information is invalid");
  }
  cc_seqno_ = validator_info.catchain_seqno;
  nx_cc_updated = validator_info.nx_cc_updated;
  if ((mode & needShardHashes) && !ShardConfig::unpack(extra_info.shard_hashes)) {
    return td::Status::Error("cannot unpack Shard configuration");
  }
  is_key_state_ = extra_info.r1.after_key_block;
  if (extra_info.r1.last_key_block->size() > 1) {
    auto& cs = extra_info.r1.last_key_block.write();
    block::gen::ExtBlkRef::Record ext_ref;
    if (!(cs.advance(1) && tlb::unpack_exact(cs, ext_ref))) {
      return td::Status::Error("cannot unpack last_key_block from masterchain state");
    }
    last_key_block_.id = ton::BlockId{ton::masterchainId, ton::shardIdAll, ext_ref.seq_no};
    last_key_block_.root_hash = ext_ref.root_hash;
    last_key_block_.file_hash = ext_ref.file_hash;
    last_key_block_lt_ = ext_ref.end_lt;
  } else {
    last_key_block_.invalidate();
    last_key_block_.id.seqno = 0;
    last_key_block_lt_ = 0;
  }
  // unpack configuration
  TRY_STATUS(Config::unpack_wrapped(std::move(extra_info.config)));
  // unpack previous masterchain block collection
  std::unique_ptr<vm::AugmentedDictionary> prev_blocks_dict =
      std::make_unique<vm::AugmentedDictionary>(extra_info.r1.prev_blocks, 32, block::tlb::aug_OldMcBlocksInfo);
  if (block_id.id.seqno) {
    block::gen::ExtBlkRef::Record extref = {};
    auto ref = prev_blocks_dict->lookup(td::BitArray<32>::zero());
    if (!(ref.not_null() && ref.write().advance(1) && tlb::csr_unpack(ref, extref) && !extref.seq_no)) {
      return td::Status::Error("OldMcBlocks in masterchain state does not contain a valid zero state reference");
    }
    zerostate_id_.root_hash = extref.root_hash;
    zerostate_id_.file_hash = extref.file_hash;
  } else {
    zerostate_id_.root_hash.set_zero();
    zerostate_id_.file_hash.set_zero();
  }
  zerostate_id_.workchain = ton::masterchainId;
  if (mode & needPrevBlocks) {
    prev_blocks_dict_ = std::move(prev_blocks_dict);
  }
  // ...
  cleanup();
  return td::Status::OK();
}

td::Status Config::unpack_wrapped(Ref<vm::CellSlice> config_csr) {
  try {
    return unpack(std::move(config_csr));
  } catch (vm::VmError err) {
    return td::Status::Error(PSLICE() << "error unpacking masterchain configuration: " << err.get_msg());
  }
}

td::Status Config::unpack_wrapped() {
  try {
    return unpack();
  } catch (vm::VmError err) {
    return td::Status::Error(PSLICE() << "error unpacking masterchain configuration: " << err.get_msg());
  }
}

td::Status Config::unpack(Ref<vm::CellSlice> config_cs) {
  gen::ConfigParams::Record config_params;
  if (!tlb::csr_unpack(std::move(config_cs), config_params)) {
    return td::Status::Error("cannot unpack ConfigParams");
  }
  config_addr = config_params.config_addr;
  config_root = std::move(config_params.config);
  return unpack();
}

td::Status Config::unpack() {
  if (config_root.is_null()) {
    return td::Status::Error("configuration root not set");
  }
  config_dict = std::make_unique<vm::Dictionary>(config_root, 32);
  if (mode & needValidatorSet) {
    auto vset_res = unpack_validator_set(get_config_param(35, 34));
    if (vset_res.is_error()) {
      return vset_res.move_as_error();
    }
    cur_validators_ = vset_res.move_as_ok();
  }
  if (mode & needSpecialSmc) {
    LOG(DEBUG) << "needSpecialSmc flag set";
    auto param = get_config_param(31);
    if (param.is_null()) {
      special_smc_dict = std::make_unique<vm::Dictionary>(256);
    } else {
      special_smc_dict = std::make_unique<vm::Dictionary>(vm::load_cell_slice_ref(std::move(param)), 256);
      LOG(DEBUG) << "smc dictionary created";
    }
  }
  if (mode & needWorkchainInfo) {
    TRY_RESULT(pair, unpack_workchain_list_ext(get_config_param(12)));
    workchains_ = std::move(pair.first);
    workchains_dict_ = std::move(pair.second);
  }
  if (mode & needCapabilities) {
    auto cell = get_config_param(8);
    if (cell.is_null()) {
      version_ = 0;
      capabilities_ = 0;
    } else {
      block::gen::GlobalVersion::Record gv;
      if (!tlb::unpack_cell(std::move(cell), gv)) {
        return td::Status::Error(
            "cannot extract global blockchain version and capabilities from GlobalVersion in configuration parameter "
            "#8");
      }
      version_ = gv.version;
      capabilities_ = gv.capabilities;
    }
  }
  // ...
  return td::Status::OK();
}

td::Status Config::visit_validator_params() const {
  {
    // current validator set
    TRY_RESULT(vset, unpack_validator_set(get_config_param(34)));
  }
  for (int i = 32; i < 38; i++) {
    // prev/current/next persistent and temporary validator sets
    auto vs = get_config_param(i);
    if (vs.not_null()) {
      TRY_RESULT(vset, unpack_validator_set(std::move(vs)));
    }
  }
  get_catchain_validators_config();
  return td::Status::OK();
}

ton::ValidatorSessionConfig Config::get_consensus_config() const {
  auto cc = get_config_param(29);
  ton::ValidatorSessionConfig c;
  auto set = [&c](auto& r, bool new_cc_ids) {
    c.catchain_idle_timeout = r.consensus_timeout_ms * 0.001;
    c.catchain_max_deps = r.catchain_max_deps;
    c.round_candidates = r.round_candidates;
    c.next_candidate_delay = r.next_candidate_delay_ms * 0.001;
    c.round_attempt_duration = r.attempt_duration;
    c.max_round_attempts = r.fast_attempts;
    c.max_block_size = r.max_block_bytes;
    c.max_collated_data_size = r.max_collated_bytes;
    c.new_catchain_ids = new_cc_ids;
    return true;
  };
  if (cc.not_null()) {
    block::gen::ConsensusConfig::Record_consensus_config_new r1;
    block::gen::ConsensusConfig::Record_consensus_config r0;
    (tlb::unpack_cell(cc, r1) && set(r1, r1.new_catchain_ids)) || (tlb::unpack_cell(cc, r0) && set(r0, false));
  }
  return c;
}

bool Config::foreach_config_param(std::function<bool(int, Ref<vm::Cell>)> scan_func) const {
  if (!config_dict) {
    return false;
  }
  return config_dict->check_for_each([scan_func](Ref<vm::CellSlice> cs_ref, td::ConstBitPtr key, int n) {
    return n == 32 && cs_ref.not_null() && cs_ref->size_ext() == 0x10000 &&
           scan_func((int)key.get_int(n), cs_ref->prefetch_ref());
  });
}

std::unique_ptr<vm::Dictionary> ShardConfig::extract_shard_hashes_dict(Ref<vm::Cell> mc_state_root) {
  gen::ShardStateUnsplit::Record root_info;
  gen::McStateExtra::Record extra_info;
  if (mc_state_root.not_null()                       //
      && tlb::unpack_cell(mc_state_root, root_info)  //
      && tlb::unpack_cell(root_info.custom->prefetch_ref(), extra_info)) {
    return std::make_unique<vm::Dictionary>(std::move(extra_info.shard_hashes), 32);
  } else {
    return {};
  }
}

td::Result<std::vector<int>> Config::unpack_param_dict(vm::Dictionary& dict) {
  try {
    std::vector<int> vect;
    if (dict.check_for_each(
            [&vect](Ref<vm::CellSlice> value, td::ConstBitPtr key, int key_len) {
              bool ok = (key_len == 32 && value->empty_ext());
              if (ok) {
                vect.push_back((int)key.get_int(32));
              }
              return ok;
            },
            true)) {
      return std::move(vect);
    } else {
      return td::Status::Error("invalid parameter list dictionary");
    }
  } catch (vm::VmError& vme) {
    return td::Status::Error("error unpacking parameter list dictionary: "s + vme.get_msg());
  }
}

td::Result<std::vector<int>> Config::unpack_param_dict(Ref<vm::Cell> dict_root) {
  vm::Dictionary dict{std::move(dict_root), 32};
  return unpack_param_dict(dict);
}

std::unique_ptr<vm::Dictionary> Config::get_param_dict(int idx) const {
  return std::make_unique<vm::Dictionary>(get_config_param(idx), 32);
}

td::Result<std::vector<int>> Config::unpack_param_list(int idx) const {
  return unpack_param_dict(*get_param_dict(idx));
}

bool Config::all_mandatory_params_defined(int* bad_idx_ptr) const {
  auto res = get_mandatory_param_list();
  if (res.is_error()) {
    if (bad_idx_ptr) {
      *bad_idx_ptr = -1;
    }
    return false;
  }
  for (int x : res.move_as_ok()) {
    if (get_config_param(x).is_null()) {
      if (bad_idx_ptr) {
        *bad_idx_ptr = x;
      }
      return false;
    }
  }
  return true;
}

std::unique_ptr<vm::AugmentedDictionary> ConfigInfo::create_accounts_dict() const {
  if (mode & needAccountsRoot) {
    return std::make_unique<vm::AugmentedDictionary>(accounts_root, 256, block::tlb::aug_ShardAccounts);
  } else {
    return nullptr;
  }
}

const vm::AugmentedDictionary& ConfigInfo::get_accounts_dict() const {
  return *accounts_dict;
}

bool ConfigInfo::get_last_key_block(ton::BlockIdExt& blkid, ton::LogicalTime& blklt, bool strict) const {
  if (strict || !is_key_state_) {
    blkid = last_key_block_;
    blklt = last_key_block_lt_;
  } else {
    blkid = block_id;
    blklt = lt;
  }
  return blkid.is_valid();
}

td::Result<std::pair<WorkchainSet, std::unique_ptr<vm::Dictionary>>> Config::unpack_workchain_list_ext(
    Ref<vm::Cell> root) {
  if (root.is_null()) {
    LOG(DEBUG) << "workchain description dictionary is empty (no configuration parameter #12)";
    return std::make_pair(WorkchainSet{}, std::make_unique<vm::Dictionary>(32));
  } else {
    auto wc_dict = std::make_unique<vm::Dictionary>(vm::load_cell_slice_ref(std::move(root)), 32);
    WorkchainSet wc_list;
    LOG(DEBUG) << "workchain description dictionary created";
    if (!(wc_dict->check_for_each([&wc_list](Ref<vm::CellSlice> cs_ref, td::ConstBitPtr key, int n) -> bool {
          ton::WorkchainId wc = ton::WorkchainId(key.get_int(32));
          Ref<WorkchainInfo> wc_info{true};
          return wc_info.unique_write().unpack(wc, cs_ref.write()) && wc_list.emplace(wc, std::move(wc_info)).second;
        }))) {
      return td::Status::Error("cannot unpack WorkchainDescr from masterchain configuration");
    }
    return std::make_pair(std::move(wc_list), std::move(wc_dict));
  }
}

td::Result<WorkchainSet> Config::unpack_workchain_list(Ref<vm::Cell> root) {
  TRY_RESULT(pair, unpack_workchain_list_ext(std::move(root)));
  return std::move(pair.first);
}

td::Result<std::unique_ptr<ValidatorSet>> Config::unpack_validator_set(Ref<vm::Cell> vset_root) {
  if (vset_root.is_null()) {
    return td::Status::Error("validator set is absent");
  }
  gen::ValidatorSet::Record_validators_ext rec;
  Ref<vm::Cell> dict_root;
  if (!tlb::unpack_cell(vset_root, rec)) {
    gen::ValidatorSet::Record_validators rec0;
    if (!tlb::unpack_cell(std::move(vset_root), rec0)) {
      return td::Status::Error("validator set is invalid");
    }
    rec.utime_since = rec0.utime_since;
    rec.utime_until = rec0.utime_until;
    rec.total = rec0.total;
    rec.main = rec0.main;
    dict_root = vm::Dictionary::construct_root_from(*rec0.list);
    rec.total_weight = 0;
  } else if (rec.total_weight) {
    dict_root = rec.list->prefetch_ref();
  } else {
    return td::Status::Error("validator set cannot have zero total weight");
  }
  vm::Dictionary dict{std::move(dict_root), 16};
  td::BitArray<16> key_buffer;
  auto last = dict.get_minmax_key(key_buffer.bits(), 16, true);
  if (last.is_null() || (int)key_buffer.to_ulong() != rec.total - 1) {
    return td::Status::Error(
        "maximal index in a validator set dictionary must be one less than the total number of validators");
  }
  auto ptr = std::make_unique<ValidatorSet>(rec.utime_since, rec.utime_until, rec.total, rec.main);
  for (int i = 0; i < rec.total; i++) {
    key_buffer.store_ulong(i);
    auto descr_cs = dict.lookup(key_buffer.bits(), 16);
    if (descr_cs.is_null()) {
      return td::Status::Error("indices in a validator set dictionary must be integers 0..total-1");
    }
    gen::ValidatorDescr::Record_validator_addr descr;
    if (!tlb::csr_unpack(descr_cs, descr)) {
      descr.adnl_addr.set_zero();
      if (!(gen::t_ValidatorDescr.unpack_validator(descr_cs.write(), descr.public_key, descr.weight) &&
            descr_cs->empty_ext())) {
        return td::Status::Error(PSLICE() << "validator #" << i
                                          << " has an invalid ValidatorDescr record in the validator set dictionary");
      }
    }
    gen::SigPubKey::Record sig_pubkey;
    if (!tlb::csr_unpack(std::move(descr.public_key), sig_pubkey)) {
      return td::Status::Error(PSLICE() << "validator #" << i
                                        << " has no public key or its public key is in unsupported format");
    }
    if (!descr.weight) {
      return td::Status::Error(PSLICE() << "validator #" << i << " has zero weight");
    }
    if (descr.weight > ~(ptr->total_weight)) {
      return td::Status::Error("total weight of all validators in validator set exceeds 2^64");
    }
    ptr->list.emplace_back(sig_pubkey.pubkey, descr.weight, ptr->total_weight, descr.adnl_addr);
    ptr->total_weight += descr.weight;
  }
  if (rec.total_weight && rec.total_weight != ptr->total_weight) {
    return td::Status::Error("validator set declares incorrect total weight");
  }
  return std::move(ptr);
}

bool Config::set_block_id_ext(const ton::BlockIdExt& block_id_ext) {
  if (block_id.id == block_id_ext.id) {
    block_id = block_id_ext;
    return true;
  } else {
    return false;
  }
}

bool ConfigInfo::set_block_id_ext(const ton::BlockIdExt& block_id_ext) {
  if (!Config::set_block_id_ext(block_id_ext)) {
    return false;
  }
  if (!block_id.seqno()) {
    zerostate_id_.workchain = ton::masterchainId;
    zerostate_id_.root_hash = block_id_ext.root_hash;
    zerostate_id_.file_hash = block_id_ext.file_hash;
  }
  reset_mc_hash();
  return true;
}

void ConfigInfo::cleanup() {
  if (!(mode & needStateRoot)) {
    state_root.clear();
  }
  if (!(mode & needStateExtraRoot)) {
    state_extra_root_.clear();
  }
}

Ref<vm::Cell> Config::get_config_param(int idx) const {
  if (!config_dict) {
    return {};
  }
  return config_dict->lookup_ref(td::BitArray<32>{idx});
}

Ref<vm::Cell> Config::get_config_param(int idx, int idx2) const {
  if (!config_dict) {
    return {};
  }
  auto res = config_dict->lookup_ref(td::BitArray<32>{idx});
  if (res.not_null()) {
    return res;
  } else {
    return config_dict->lookup_ref(td::BitArray<32>{idx2});
  }
}

td::Result<std::unique_ptr<BlockLimits>> Config::get_block_limits(bool is_masterchain) const {
  int param = (is_masterchain ? 22 : 23);
  auto cell = get_config_param(param);
  if (cell.is_null()) {
    return td::Status::Error(PSTRING() << "configuration parameter " << param << " with block limits is absent");
  }
  auto cs = vm::load_cell_slice(std::move(cell));
  auto ptr = std::make_unique<BlockLimits>();
  if (!ptr->deserialize(cs) || cs.size_ext()) {
    return td::Status::Error(PSTRING() << "cannot deserialize BlockLimits obtained from configuration parameter "
                                       << param);
  }
  return std::move(ptr);
}

td::Result<std::vector<StoragePrices>> Config::get_storage_prices() const {
  auto cell = get_config_param(18);
  std::vector<StoragePrices> res;
  if (cell.is_null()) {
    return td::Status::Error("configuration parameter 18 with storage prices dictionary is absent");
  }
  vm::Dictionary dict{std::move(cell), 32};
  if (!dict.check_for_each([&res](Ref<vm::CellSlice> cs_ref, td::ConstBitPtr key, int n) -> bool {
        block::gen::StoragePrices::Record data;
        if (!tlb::csr_unpack(std::move(cs_ref), data) || data.utime_since != key.get_uint(n)) {
          return false;
        }
        res.emplace_back(data.utime_since, data.bit_price_ps, data.cell_price_ps, data.mc_bit_price_ps,
                         data.mc_cell_price_ps);
        return true;
      })) {
    return td::Status::Error("invalid storage prices dictionary in configuration parameter 18");
  }
  return std::move(res);
}

td::Result<GasLimitsPrices> Config::do_get_gas_limits_prices(td::Ref<vm::Cell> cell, int id) {
  GasLimitsPrices res;
  auto cs = vm::load_cell_slice(cell);
  block::gen::GasLimitsPrices::Record_gas_flat_pfx flat;
  if (tlb::unpack(cs, flat)) {
    cs = *flat.other;
    res.flat_gas_limit = flat.flat_gas_limit;
    res.flat_gas_price = flat.flat_gas_price;
  } else {
    cs = vm::load_cell_slice(cell);
  }
  auto f = [&](const auto& r, td::uint64 spec_limit) {
    res.gas_limit = r.gas_limit;
    res.special_gas_limit = spec_limit;
    res.gas_credit = r.gas_credit;
    res.gas_price = r.gas_price;
    res.freeze_due_limit = r.freeze_due_limit;
    res.delete_due_limit = r.delete_due_limit;
  };
  block::gen::GasLimitsPrices::Record_gas_prices_ext rec;
  if (tlb::unpack(cs, rec)) {
    f(rec, rec.special_gas_limit);
  } else {
    block::gen::GasLimitsPrices::Record_gas_prices rec0;
    if (tlb::unpack(cs, rec0)) {
      f(rec0, rec0.gas_limit);
    } else {
      return td::Status::Error(PSLICE() << "configuration parameter " << id
                                        << " with gas prices is invalid - can't parse");
    }
  }
  return res;
}

td::Result<ton::StdSmcAddress> Config::get_dns_root_addr() const {
  auto cell = get_config_param(4);
  if (cell.is_null()) {
    return td::Status::Error(PSLICE() << "configuration parameter " << 4 << " with dns root address is absent");
  }
  auto cs = vm::load_cell_slice(std::move(cell));
  if (cs.size() != 0x100) {
    return td::Status::Error(PSLICE() << "configuration parameter " << 4 << " with dns root address has wrong size");
  }
  ton::StdSmcAddress res;
  CHECK(cs.fetch_bits_to(res));
  return res;
}

td::Result<GasLimitsPrices> Config::get_gas_limits_prices(bool is_masterchain) const {
  auto id = is_masterchain ? 20 : 21;
  auto cell = get_config_param(id);
  if (cell.is_null()) {
    return td::Status::Error(PSLICE() << "configuration parameter " << id << " with gas prices is absent");
  }
  return do_get_gas_limits_prices(std::move(cell), id);
}

td::Result<MsgPrices> Config::get_msg_prices(bool is_masterchain) const {
  auto id = is_masterchain ? 24 : 25;
  auto cell = get_config_param(id);
  if (cell.is_null()) {
    return td::Status::Error(PSLICE() << "configuration parameter " << id << " with msg prices is absent");
  }
  auto cs = vm::load_cell_slice(std::move(cell));
  block::gen::MsgForwardPrices::Record rec;
  if (!tlb::unpack(cs, rec)) {
    return td::Status::Error(PSLICE() << "configuration parameter " << id
                                      << " with msg prices is invalid - can't parse");
  }
  return MsgPrices(rec.lump_price, rec.bit_price, rec.cell_price, rec.ihr_price_factor, rec.first_frac, rec.next_frac);
}

CatchainValidatorsConfig Config::unpack_catchain_validators_config(Ref<vm::Cell> cell) {
  if (cell.not_null()) {
    block::gen::CatchainConfig::Record_catchain_config cfg;
    if (tlb::unpack_cell(cell, cfg)) {
      return {cfg.mc_catchain_lifetime, cfg.shard_catchain_lifetime, cfg.shard_validators_lifetime,
              cfg.shard_validators_num};
    }
    block::gen::CatchainConfig::Record_catchain_config_new cfg2;
    if (tlb::unpack_cell(std::move(cell), cfg2)) {
      return {cfg2.mc_catchain_lifetime, cfg2.shard_catchain_lifetime, cfg2.shard_validators_lifetime,
              cfg2.shard_validators_num, cfg2.shuffle_mc_validators};
    }
  }
  return {default_mc_catchain_lifetime, default_shard_catchain_lifetime, default_shard_validators_lifetime,
          default_shard_validators_num};
}

CatchainValidatorsConfig Config::get_catchain_validators_config() const {
  return unpack_catchain_validators_config(get_config_param(28));
}

// compares all fields except fsm*, before_merge_, nx_cc_updated_, next_catchain_seqno_
bool McShardHash::basic_info_equal(const McShardHash& other, bool compare_fees, bool compare_reg_seqno) const {
  return blk_ == other.blk_ && start_lt_ == other.start_lt_ && end_lt_ == other.end_lt_ &&
         (!compare_reg_seqno || reg_mc_seqno_ == other.reg_mc_seqno_) && gen_utime_ == other.gen_utime_ &&
         min_ref_mc_seqno_ == other.min_ref_mc_seqno_ && before_split_ == other.before_split_ &&
         want_split_ == other.want_split_ && want_merge_ == other.want_merge_ &&
         (!compare_fees || (fees_collected_ == other.fees_collected_ && funds_created_ == other.funds_created_));
}

void McShardHash::set_fsm(FsmState fsm, ton::UnixTime fsm_utime, ton::UnixTime fsm_interval) {
  fsm_ = fsm;
  fsm_utime_ = fsm_utime;
  fsm_interval_ = fsm_interval;
}

Ref<McShardHash> McShardHash::unpack(vm::CellSlice& cs, ton::ShardIdFull id) {
  int tag = gen::t_ShardDescr.get_tag(cs);
  if (tag < 0) {
    return {};
  }
  auto create = [&id](auto& descr, Ref<vm::CellSlice> fees, Ref<vm::CellSlice> funds) {
    CurrencyCollection fees_collected, funds_created;
    if (!(fees_collected.unpack(std::move(fees)) && funds_created.unpack(std::move(funds)))) {
      return Ref<McShardHash>{};
    }
    return td::make_ref<McShardHash>(ton::BlockId{id, (unsigned)descr.seq_no}, descr.start_lt, descr.end_lt,
                                     descr.gen_utime, descr.root_hash, descr.file_hash, fees_collected, funds_created,
                                     descr.reg_mc_seqno, descr.min_ref_mc_seqno, descr.next_catchain_seqno,
                                     descr.next_validator_shard, /* descr.nx_cc_updated */ false, descr.before_split,
                                     descr.before_merge, descr.want_split, descr.want_merge);
  };
  Ref<McShardHash> res;
  Ref<vm::CellSlice> fsm_cs;
  if (tag == gen::ShardDescr::shard_descr) {
    gen::ShardDescr::Record_shard_descr descr;
    if (tlb::unpack_exact(cs, descr)) {
      fsm_cs = std::move(descr.split_merge_at);
      res = create(descr, std::move(descr.fees_collected), std::move(descr.funds_created));
    }
  } else {
    gen::ShardDescr::Record_shard_descr_new descr;
    if (tlb::unpack_exact(cs, descr)) {
      fsm_cs = std::move(descr.split_merge_at);
      res = create(descr, std::move(descr.r1.fees_collected), std::move(descr.r1.funds_created));
    }
  }
  if (res.is_null()) {
    return res;
  }
  McShardHash& sh = res.unique_write();
  switch (gen::t_FutureSplitMerge.get_tag(*fsm_cs)) {
    case gen::FutureSplitMerge::fsm_none:
      return res;
    case gen::FutureSplitMerge::fsm_split:
      if (gen::t_FutureSplitMerge.unpack_fsm_split(fsm_cs.write(), sh.fsm_utime_, sh.fsm_interval_)) {
        sh.fsm_ = FsmState::fsm_split;
        return res;
      }
      break;
    case gen::FutureSplitMerge::fsm_merge:
      if (gen::t_FutureSplitMerge.unpack_fsm_merge(fsm_cs.write(), sh.fsm_utime_, sh.fsm_interval_)) {
        sh.fsm_ = FsmState::fsm_merge;
        return res;
      }
      break;
    default:
      break;
  }
  return {};
}

bool McShardHash::pack(vm::CellBuilder& cb) const {
  if (!(is_valid()                                        // (validate)
        && cb.store_long_bool(10, 4)                      // shard_descr_new#a
        && cb.store_long_bool(blk_.id.seqno, 32)          // seq_no:uint32
        && cb.store_long_bool(reg_mc_seqno_, 32)          // reg_mc_seqno:uint32
        && cb.store_long_bool(start_lt_, 64)              // start_lt:uint64
        && cb.store_long_bool(end_lt_, 64)                // end_lt:uint64
        && cb.store_bits_bool(blk_.root_hash)             // root_hash:bits256
        && cb.store_bits_bool(blk_.file_hash)             // file_hash:bits256
        && cb.store_bool_bool(before_split_)              // before_split:Bool
        && cb.store_bool_bool(before_merge_)              // before_merge:Bool
        && cb.store_bool_bool(want_split_)                // want_split:Bool
        && cb.store_bool_bool(want_merge_)                // want_merge:Bool
        && cb.store_bool_bool(false)                      // nx_cc_updated:Bool
        && cb.store_long_bool(0, 3)                       // flags:(## 3) { flags = 0 }
        && cb.store_long_bool(next_catchain_seqno_, 32)   // next_catchain_seqno:uint32
        && cb.store_long_bool(next_validator_shard_, 64)  // next_validator_shard:uint64
        && cb.store_long_bool(min_ref_mc_seqno_, 32)      // min_ref_mc_seqno:uint32
        && cb.store_long_bool(gen_utime_, 32)             // gen_utime:uint32
        )) {
    return false;
  }
  bool ok;
  switch (fsm_) {  // split_merge_at:FutureSplitMerge
    case FsmState::fsm_none:
      ok = gen::t_FutureSplitMerge.pack_fsm_none(cb);
      break;
    case FsmState::fsm_split:
      ok = gen::t_FutureSplitMerge.pack_fsm_split(cb, fsm_utime_, fsm_interval_);
      break;
    case FsmState::fsm_merge:
      ok = gen::t_FutureSplitMerge.pack_fsm_merge(cb, fsm_utime_, fsm_interval_);
      break;
    default:
      return false;
  }
  vm::CellBuilder cb2;
  return ok                                             // split_merge_at:FutureSplitMerge
         && fees_collected_.store_or_zero(cb2)          // ^[ fees_collected:CurrencyCollection
         && funds_created_.store_or_zero(cb2)           //    funds_created:CurrencyCollection ]
         && cb.store_builder_ref_bool(std::move(cb2));  // = ShardDescr;
}

Ref<McShardHash> McShardHash::from_block(Ref<vm::Cell> block_root, const ton::FileHash& fhash, bool init_fees) {
  if (block_root.is_null()) {
    return {};
  }
  block::gen::Block::Record rec;
  block::gen::BlockInfo::Record info;
  block::ShardId shard;
  if (!(tlb::unpack_cell(block_root, rec) && tlb::unpack_cell(rec.info, info) &&
        shard.deserialize(info.shard.write()))) {
    return {};
  }
  ton::RootHash rhash = block_root->get_hash().bits();
  CurrencyCollection fees_collected, funds_created;
  if (init_fees) {
    block::gen::ValueFlow::Record flow;
    if (!(tlb::unpack_cell(rec.value_flow, flow) && fees_collected.unpack(flow.fees_collected) &&
          funds_created.unpack(flow.r2.created))) {
      return {};
    }
  }
  return Ref<McShardHash>(true, ton::BlockId{ton::ShardIdFull(shard), (unsigned)info.seq_no}, info.start_lt,
                          info.end_lt, info.gen_utime, rhash, fhash, fees_collected, funds_created, ~0U,
                          info.min_ref_mc_seqno, info.gen_catchain_seqno, shard.shard_pfx, false, info.before_split,
                          false, info.want_split, info.want_merge);
}

McShardDescr::McShardDescr(const McShardDescr& other)
    : McShardHash(other)
    , block_root(other.block_root)
    , state_root(other.state_root)
    , processed_upto(other.processed_upto) {
  set_queue_root(other.outmsg_root);
}

McShardDescr& McShardDescr::operator=(const McShardDescr& other) {
  McShardHash::operator=(other);
  block_root = other.block_root;
  outmsg_root = other.outmsg_root;
  processed_upto = other.processed_upto;
  set_queue_root(other.outmsg_root);
  return *this;
}

Ref<McShardDescr> McShardDescr::from_block(Ref<vm::Cell> block_root, Ref<vm::Cell> state_root,
                                           const ton::FileHash& fhash, bool init_fees) {
  if (block_root.is_null()) {
    return {};
  }
  block::gen::Block::Record rec;
  block::gen::BlockInfo::Record info;
  block::ShardId shard;
  if (!(tlb::unpack_cell(block_root, rec) && tlb::unpack_cell(rec.info, info) &&
        shard.deserialize(info.shard.write()))) {
    return {};
  }
  // TODO: use a suitable vm::MerkleUpdate method here
  vm::CellSlice cs(vm::NoVmSpec(), rec.state_update);
  if (!cs.is_valid() || cs.special_type() != vm::Cell::SpecialType::MerkleUpdate) {
    LOG(ERROR) << "state update in a block is not a Merkle update";
    return {};
  }
  if (cs.size_refs() != 2 || cs.prefetch_ref(1)->get_hash(0) != state_root->get_hash()) {
    LOG(ERROR) << "invalid Merkle update for block state : resulting state hash mismatch";
    return {};
  }
  ton::RootHash rhash = block_root->get_hash().bits();
  CurrencyCollection fees_collected, funds_created;
  if (init_fees) {
    block::gen::ValueFlow::Record flow;
    if (!(tlb::unpack_cell(rec.value_flow, flow) && fees_collected.unpack(flow.fees_collected) &&
          funds_created.unpack(flow.r2.created))) {
      return {};
    }
  }
  auto res = Ref<McShardDescr>(true, ton::BlockId{ton::ShardIdFull(shard), (unsigned)info.seq_no}, info.start_lt,
                               info.end_lt, info.gen_utime, rhash, fhash, fees_collected, funds_created, ~0U,
                               info.min_ref_mc_seqno, info.gen_catchain_seqno, shard.shard_pfx, false,
                               info.before_split, false, info.want_split, info.want_merge);
  auto& descr = res.unique_write();
  descr.block_root = std::move(block_root);
  descr.state_root = std::move(state_root);
  return res;
}

Ref<McShardDescr> McShardDescr::from_state(ton::BlockIdExt blkid, Ref<vm::Cell> state_root) {
  if (state_root.is_null()) {
    return {};
  }
  block::gen::ShardStateUnsplit::Record info;
  block::gen::OutMsgQueueInfo::Record qinfo;
  block::ShardId shard;
  if (!(tlb::unpack_cell(state_root, info) && shard.deserialize(info.shard_id.write()) &&
        tlb::unpack_cell(info.out_msg_queue_info, qinfo))) {
    LOG(DEBUG) << "cannot create McShardDescr from a shardchain state";
    return {};
  }
  if (ton::ShardIdFull(shard) != ton::ShardIdFull(blkid) || info.seq_no != blkid.seqno()) {
    LOG(DEBUG) << "shard id mismatch, cannot construct McShardDescr";
    return {};
  }
  auto res = Ref<McShardDescr>(true, blkid.id, info.gen_lt, info.gen_lt, info.gen_utime, blkid.root_hash,
                               blkid.file_hash, CurrencyCollection{}, CurrencyCollection{}, ~0U, info.min_ref_mc_seqno,
                               0, shard.shard_pfx, false, info.before_split);
  res.unique_write().state_root = state_root;
  res.unique_write().set_queue_root(qinfo.out_queue->prefetch_ref(0));
  return res;
}

bool McShardDescr::set_queue_root(Ref<vm::Cell> queue_root) {
  outmsg_root = std::move(queue_root);
  out_msg_queue = std::make_unique<vm::AugmentedDictionary>(outmsg_root, 352, block::tlb::aug_OutMsgQueue);
  return true;
}

void McShardDescr::disable() {
  block_root.clear();
  state_root.clear();
  outmsg_root.clear();
  out_msg_queue.reset();
  processed_upto.reset();
  McShardHash::disable();
}

void ConfigInfo::reset_mc_hash() {
  if (block_id.is_masterchain() && !block_id.root_hash.is_zero()) {
    // TODO: use block_start_lt instead of lt if available
    set_mc_hash(Ref<McShardHash>(true, block_id.id, lt, lt, utime, block_id.root_hash, block_id.file_hash));
  } else {
    set_mc_hash(Ref<McShardHash>{});
  }
}

Ref<vm::CellSlice> ShardConfig::get_root_csr() const {
  if (!shard_hashes_dict_) {
    return {};
  }
  return shard_hashes_dict_->get_root();
}

bool ShardConfig::unpack(Ref<vm::Cell> shard_hashes, Ref<McShardHash> mc_shard_hash) {
  shard_hashes_ = std::move(shard_hashes);
  mc_shard_hash_ = std::move(mc_shard_hash);
  return init();
}

bool ShardConfig::unpack(Ref<vm::CellSlice> shard_hashes, Ref<McShardHash> mc_shard_hash) {
  shard_hashes_ = shard_hashes->prefetch_ref();
  mc_shard_hash_ = std::move(mc_shard_hash);
  return init();
}

bool ShardConfig::init() {
  shard_hashes_dict_ = std::make_unique<vm::Dictionary>(shard_hashes_, 32);
  valid_ = true;
  return true;
}

ShardConfig::ShardConfig(const ShardConfig& other)
    : shard_hashes_(other.shard_hashes_), mc_shard_hash_(other.mc_shard_hash_) {
  init();
}

bool ShardConfig::get_shard_hash_raw_from(vm::Dictionary& dict, vm::CellSlice& cs, ton::ShardIdFull id,
                                          ton::ShardIdFull& true_id, bool exact, Ref<vm::Cell>* leaf) {
  if (id.is_masterchain() || !id.is_valid()) {
    return false;
  }
  auto root = dict.lookup_ref(td::BitArray<32>{id.workchain});
  if (root.is_null()) {
    return false;
  }
  unsigned long long z = id.shard, m = std::numeric_limits<unsigned long long>::max();
  int len = id.pfx_len();
  while (true) {
    cs.load(vm::NoVmOrd(), leaf ? root : std::move(root));
    int t = (int)cs.fetch_ulong(1);
    if (t < 0) {
      return false;  // throw DictError ?
    } else if (!t) {
      if (len && exact) {
        return false;
      }
      true_id = ton::ShardIdFull{id.workchain, (id.shard | m) - (m >> 1)};
      if (leaf) {
        *leaf = std::move(root);
      }
      return true;
    }
    if (!len || cs.size_ext() != 0x20000) {
      return false;  // throw DictError in the second case?
    }
    root = cs.prefetch_ref((unsigned)(z >> 63));
    z <<= 1;
    --len;
    m >>= 1;
  }
}

bool ShardConfig::get_shard_hash_raw(vm::CellSlice& cs, ton::ShardIdFull id, ton::ShardIdFull& true_id,
                                     bool exact) const {
  return shard_hashes_dict_ && get_shard_hash_raw_from(*shard_hashes_dict_, cs, id, true_id, exact);
}

Ref<McShardHash> ShardConfig::get_shard_hash(ton::ShardIdFull id, bool exact) const {
  if (id.is_masterchain()) {
    return (!exact || id.shard == ton::shardIdAll) ? get_mc_hash() : Ref<McShardHash>{};
  }
  ton::ShardIdFull true_id;
  vm::CellSlice cs;
  if (get_shard_hash_raw(cs, id, true_id, exact)) {
    // block::gen::t_ShardDescr.print(std::cerr, vm::CellSlice{cs});
    return McShardHash::unpack(cs, true_id);
  } else {
    return {};
  }
}

bool McShardHash::extract_cc_seqno(vm::CellSlice& cs, ton::CatchainSeqno* cc) {
  auto get = [&cs, cc](auto& rec) {
    if (tlb::unpack_exact(cs, rec)) {
      *cc = rec.next_catchain_seqno;
      return true;
    } else {
      *cc = std::numeric_limits<ton::CatchainSeqno>::max();
      return false;
    }
  };
  if (block::gen::t_ShardDescr.get_tag(cs) == block::gen::ShardDescr::shard_descr) {
    gen::ShardDescr::Record_shard_descr rec;
    return get(rec);
  } else {
    gen::ShardDescr::Record_shard_descr_new rec;
    return get(rec);
  }
}

ton::CatchainSeqno ShardConfig::get_shard_cc_seqno(ton::ShardIdFull shard) const {
  if (shard.is_masterchain() || !shard.is_valid()) {
    return std::numeric_limits<ton::CatchainSeqno>::max();
  }
  ton::ShardIdFull true_id;
  ton::CatchainSeqno cc_seqno, cc_seqno2;
  vm::CellSlice cs;
  if (!(get_shard_hash_raw(cs, shard - 1, true_id, false) &&
        (ton::shard_is_ancestor(true_id, shard) || ton::shard_is_parent(shard, true_id)) &&
        McShardHash::extract_cc_seqno(cs, &cc_seqno))) {
    return std::numeric_limits<ton::CatchainSeqno>::max();
  }
  if (ton::shard_is_ancestor(true_id, shard)) {
    return cc_seqno;
  }
  if (!(get_shard_hash_raw(cs, shard + 1, true_id, false) && ton::shard_is_parent(shard, true_id) &&
        McShardHash::extract_cc_seqno(cs, &cc_seqno2))) {
    return std::numeric_limits<ton::CatchainSeqno>::max();
  }
  return std::max(cc_seqno, cc_seqno2) + 1;
}

ton::LogicalTime ShardConfig::get_shard_end_lt_ext(ton::AccountIdPrefixFull acc, ton::ShardIdFull& actual_shard) const {
  if (!acc.is_valid()) {
    actual_shard.workchain = ton::workchainInvalid;
    return 0;
  }
  if (acc.is_masterchain()) {
    actual_shard = ton::ShardIdFull(ton::masterchainId);
    CHECK(mc_shard_hash_.not_null());
    return mc_shard_hash_->end_lt_;
  }
  vm::CellSlice cs;
  unsigned long long end_lt;
  return get_shard_hash_raw(cs, acc.as_leaf_shard(), actual_shard, false)  // lookup ShardDescr containing acc
                 && cs.advance(4 + 128)              // shard_descr#b seq_no:uint32 reg_mc_seqno:uint32 start_lt:uint64
                 && cs.fetch_ulong_bool(64, end_lt)  // end_lt:uint64
             ? end_lt
             : 0;
}

ton::LogicalTime ShardConfig::get_shard_end_lt(ton::AccountIdPrefixFull acc) const {
  ton::ShardIdFull tmp;
  return get_shard_end_lt_ext(acc, tmp);
}

bool ShardConfig::contains(ton::BlockIdExt blkid) const {
  auto entry = get_shard_hash(blkid.shard_full());
  return entry.not_null() && entry->blk_ == blkid;
}

static int process_workchain_shard_hashes(Ref<vm::Cell>& branch, ton::ShardIdFull shard,
                                          std::function<int(McShardHash&)>& func) {
  auto cs = vm::load_cell_slice(branch);
  int f = (int)cs.fetch_ulong(1);
  if (f == 1) {
    if ((shard.shard & 1) || cs.size_ext() != 0x20000) {
      return -1;
    }
    auto left = cs.prefetch_ref(0), right = cs.prefetch_ref(1);
    int r = process_workchain_shard_hashes(left, ton::shard_child(shard, true), func);
    if (r < 0) {
      return r;
    }
    r |= process_workchain_shard_hashes(right, ton::shard_child(shard, false), func);
    if (r <= 0) {
      return r;
    }
    vm::CellBuilder cb;
    return cb.store_bool_bool(true) && cb.store_ref_bool(std::move(left)) && cb.store_ref_bool(std::move(right)) &&
                   cb.finalize_to(branch)
               ? r
               : -1;
  } else if (!f) {
    auto shard_info = McShardHash::unpack(cs, shard);
    if (shard_info.is_null()) {
      return -1;
    }
    int r = func(shard_info.write());
    if (r <= 0) {
      return r;
    }
    vm::CellBuilder cb;
    return cb.store_bool_bool(false) && shard_info->pack(cb) && cb.finalize_to(branch) ? r : -1;
  } else {
    return -1;
  }
}

bool ShardConfig::process_shard_hashes(std::function<int(McShardHash&)> func) {
  if (!shard_hashes_dict_) {
    return false;
  }
  bool ok = true;
  shard_hashes_dict_->map(
      [&ok, &func](vm::CellBuilder& cb, Ref<vm::CellSlice> csr, td::ConstBitPtr key, int n) -> bool {
        Ref<vm::Cell> root;
        ok = ok && (n == 32) && csr->size_ext() == 0x10000 && std::move(csr)->prefetch_ref_to(root) &&
             process_workchain_shard_hashes(root, ton::ShardIdFull{(int)key.get_int(32)}, func) >= 0 &&
             cb.store_ref_bool(std::move(root));
        return true;
      });
  return ok;
}

static int process_workchain_sibling_shard_hashes(Ref<vm::Cell>& branch, Ref<vm::Cell> sibling, ton::ShardIdFull shard,
                                                  std::function<int(McShardHash&, const McShardHash*)>& func) {
  auto cs = vm::load_cell_slice(branch);
  int f = (int)cs.fetch_ulong(1);
  if (f == 1) {
    if ((shard.shard & 1) || cs.size_ext() != 0x20000) {
      return false;
    }
    auto left = cs.prefetch_ref(0), right = cs.prefetch_ref(1);
    auto orig_left = left;
    int r = process_workchain_sibling_shard_hashes(left, right, ton::shard_child(shard, true), func);
    if (r < 0) {
      return r;
    }
    r |= process_workchain_sibling_shard_hashes(right, std::move(orig_left), ton::shard_child(shard, false), func);
    if (r <= 0) {
      return r;
    }
    vm::CellBuilder cb;
    return cb.store_bool_bool(true) && cb.store_ref_bool(std::move(left)) && cb.store_ref_bool(std::move(right)) &&
                   cb.finalize_to(branch)
               ? r
               : -1;
  } else if (!f) {
    auto shard_info = McShardHash::unpack(cs, shard);
    if (shard_info.is_null()) {
      return -1;
    }
    Ref<McShardHash> sibling_info;
    if (sibling.not_null()) {
      auto cs2 = vm::load_cell_slice(sibling);
      if (!cs2.fetch_ulong(1)) {
        sibling_info = McShardHash::unpack(cs2, ton::shard_sibling(shard));
        if (sibling_info.is_null()) {
          return -1;
        }
      }
    }
    int r = func(shard_info.write(), sibling_info.get());
    if (r <= 0) {
      return r;
    }
    vm::CellBuilder cb;
    return cb.store_bool_bool(false) && shard_info->pack(cb) && cb.finalize_to(branch) ? r : -1;
  } else {
    return -1;
  }
}

bool ShardConfig::process_sibling_shard_hashes(std::function<int(McShardHash&, const McShardHash*)> func) {
  if (!shard_hashes_dict_) {
    return false;
  }
  bool ok = true;
  shard_hashes_dict_->map([&ok, &func](vm::CellBuilder& cb, Ref<vm::CellSlice> csr, td::ConstBitPtr key,
                                       int n) -> bool {
    Ref<vm::Cell> root;
    ok = ok && (n == 32) && csr->size_ext() == 0x10000 && std::move(csr)->prefetch_ref_to(root) &&
         process_workchain_sibling_shard_hashes(root, Ref<vm::Cell>{}, ton::ShardIdFull{(int)key.get_int(32)}, func) >=
             0;
    bool f = cb.store_ref_bool(std::move(root));
    ok &= f;
    return f;
  });
  return ok;
}

std::vector<ton::BlockId> ShardConfig::get_shard_hash_ids(
    const std::function<bool(ton::ShardIdFull, bool)>& filter) const {
  if (!shard_hashes_dict_) {
    return {};
  }
  std::vector<ton::BlockId> res;
  bool mcout = mc_shard_hash_.is_null() || !mc_shard_hash_->seqno();  // include masterchain as a shard if seqno > 0
  bool ok = shard_hashes_dict_->check_for_each(
      [&res, &mcout, mc_shard_hash_ = mc_shard_hash_, &filter](Ref<vm::CellSlice> cs_ref, td::ConstBitPtr key,
                                                               int n) -> bool {
        int workchain = (int)key.get_int(n);
        if (workchain >= 0 && !mcout) {
          if (filter(ton::ShardIdFull{ton::masterchainId}, true)) {
            res.emplace_back(mc_shard_hash_->blk_.id);
          }
          mcout = true;
        }
        if (!cs_ref->have_refs()) {
          return false;
        }
        std::stack<std::pair<Ref<vm::Cell>, unsigned long long>> stack;
        stack.emplace(cs_ref->prefetch_ref(), ton::shardIdAll);
        while (!stack.empty()) {
          vm::CellSlice cs{vm::NoVmOrd(), std::move(stack.top().first)};
          unsigned long long shard = stack.top().second;
          stack.pop();
          int t = (int)cs.fetch_ulong(1);
          if (t < 0) {
            return false;
          }
          if (!filter(ton::ShardIdFull{workchain, shard}, !t)) {
            continue;
          }
          if (!t) {
            if (!(cs.advance(4) && cs.have(32))) {
              return false;
            }
            res.emplace_back(workchain, shard, (int)cs.prefetch_ulong(32));
            continue;
          }
          unsigned long long delta = (td::lower_bit64(shard) >> 1);
          if (!delta || cs.size_ext() != 0x20000) {
            return false;
          }
          stack.emplace(cs.prefetch_ref(1), shard + delta);
          stack.emplace(cs.prefetch_ref(0), shard - delta);
        }
        return true;
      },
      true);
  if (!ok) {
    return {};
  }
  if (!mcout && filter(ton::ShardIdFull{ton::masterchainId}, true)) {
    res.emplace_back(mc_shard_hash_->blk_.id);
  }
  return res;
}

std::vector<ton::BlockId> ShardConfig::get_shard_hash_ids(bool skip_mc) const {
  return get_shard_hash_ids(
      [skip_mc](ton::ShardIdFull shard, bool) -> bool { return !(skip_mc && shard.is_masterchain()); });
}

std::vector<ton::BlockId> ShardConfig::get_intersecting_shard_hash_ids(ton::ShardIdFull myself) const {
  return get_shard_hash_ids(
      [myself](ton::ShardIdFull shard, bool) -> bool { return ton::shard_intersects(myself, shard); });
}

std::vector<ton::BlockId> ShardConfig::get_neighbor_shard_hash_ids(ton::ShardIdFull myself) const {
  return get_shard_hash_ids([myself](ton::ShardIdFull shard, bool) -> bool { return is_neighbor(myself, shard); });
}

std::vector<ton::BlockId> ShardConfig::get_proper_neighbor_shard_hash_ids(ton::ShardIdFull myself) const {
  return get_shard_hash_ids([myself](ton::ShardIdFull shard, bool leaf) -> bool {
    return is_neighbor(myself, shard) && !(leaf && ton::shard_intersects(myself, shard));
  });
}

bool ShardConfig::is_neighbor(ton::ShardIdFull x, ton::ShardIdFull y) {
  if (x.is_masterchain() || y.is_masterchain()) {
    return true;
  }
  unsigned long long xs = x.shard, ys = y.shard;
  unsigned long long xl = td::lower_bit64(xs), yl = td::lower_bit64(ys);
  unsigned long long z = (xs ^ ys) & td::bits_negate64(std::max(xl, yl) << 1);
  if (!z) {
    return true;
  }
  if (x.workchain != y.workchain) {
    return false;
  }
  int c1 = (td::count_leading_zeroes_non_zero64(z) >> 2);
  int c2 = (td::count_trailing_zeroes_non_zero64(z) >> 2);
  return c1 + c2 == 15;
}

bool ShardConfig::has_workchain(ton::WorkchainId workchain) const {
  return shard_hashes_dict_ && shard_hashes_dict_->key_exists(td::BitArray<32>{workchain});
}

std::vector<ton::WorkchainId> ShardConfig::get_workchains() const {
  if (!shard_hashes_dict_) {
    return {};
  }
  std::vector<ton::WorkchainId> res;
  if (!shard_hashes_dict_->check_for_each([&res](Ref<vm::CellSlice> val, td::ConstBitPtr key, int n) {
        CHECK(n == 32);
        ton::WorkchainId w = (int)key.get_int(32);
        res.push_back(w);
        return true;
      })) {
    return {};
  }
  return res;
}

bool ShardConfig::new_workchain(ton::WorkchainId workchain, ton::BlockSeqno reg_mc_seqno,
                                const ton::RootHash& zerostate_root_hash, const ton::FileHash& zerostate_file_hash) {
  if (!shard_hashes_dict_ || has_workchain(workchain)) {
    return false;
  }
  vm::CellBuilder cb;
  Ref<vm::Cell> cell;
  return cb.store_long_bool(11, 1 + 4)               // bt_leaf$0 ; shard_descr#b
         && cb.store_zeroes_bool(32)                 // seq_no:uint32
         && cb.store_long_bool(reg_mc_seqno, 32)     // reg_mc_seqno:uint32
         && cb.store_zeroes_bool(64 * 2)             // start_lt:uint64 end_lt:uint64
         && cb.store_bits_bool(zerostate_root_hash)  // root_hash:bits256
         && cb.store_bits_bool(zerostate_file_hash)  // file_hash:bits256
         && cb.store_long_bool(0, 8)                 // ... nx_cc_updated:Bool ...
         && cb.store_long_bool(0, 32)                // next_catchain_seqno:uint32
         && cb.store_long_bool(1ULL << 63, 64)       // next_validator_shard:uint64
         && cb.store_long_bool(~0U, 32)              // min_ref_mc_seqno:uint32
         && cb.store_long_bool(0, 32)                // gen_utime:uint32
         &&
         cb.store_zeroes_bool(
             1 + 5 +
             5)  // split_merge_at:FutureSplitMerge fees_collected:CurrencyCollection funds_created:CurrencyCollection
         && cb.finalize_to(cell) && block::gen::t_BinTree_ShardDescr.validate_ref(1024, cell) &&
         shard_hashes_dict_->set_ref(td::BitArray<32>{workchain}, std::move(cell), vm::Dictionary::SetMode::Add);
}

td::Result<bool> ShardConfig::may_update_shard_block_info(Ref<McShardHash> new_info,
                                                          const std::vector<ton::BlockIdExt>& old_blkids,
                                                          ton::LogicalTime lt_limit, Ref<McShardHash>* ancestor) const {
  if (!shard_hashes_dict_) {
    return td::Status::Error(-666, "no shard top block dictionary present");
  }
  if (new_info.is_null()) {
    return td::Status::Error(-666, "suggested new top shard block info is empty");
  }
  if (!new_info->is_valid()) {
    return td::Status::Error(-666, "new top shard block description is invalid");
  }
  auto wc = new_info->shard().workchain;
  if (wc == ton::workchainInvalid || wc == ton::masterchainId) {
    return td::Status::Error(-666, "new top shard block description belongs to an invalid workchain");
  }
  if (!has_workchain(wc)) {
    return td::Status::Error(-666, "new top shard block belongs to an unknown or disabled workchain");
  }
  if (old_blkids.size() != 1 && old_blkids.size() != 2) {
    return td::Status::Error(-666, "must have either one or two start blocks in a top shard block update");
  }
  bool before_split = ton::shard_is_parent(old_blkids[0].shard_full(), new_info->shard());
  bool before_merge = (old_blkids.size() == 2);
  if (before_merge) {
    if (!ton::shard_is_sibling(old_blkids[0].shard_full(), old_blkids[1].shard_full())) {
      return td::Status::Error(-666, "the two start blocks of a top shard block update must be siblings");
    }
    if (!ton::shard_is_parent(new_info->shard(), old_blkids[0].shard_full())) {
      return td::Status::Error(
          -666,
          std::string{"the two start blocks of a top shard block update do not merge into expected final shard "} +
              old_blkids[0].shard_full().to_str());
    }
  } else if (new_info->shard() != old_blkids[0].shard_full() && !before_split) {
    return td::Status::Error(
        -666, "the start block of a top shard block update must either coincide with the final shard or be its parent");
  }
  if (ancestor) {
    ancestor->clear();
  }
  ton::CatchainSeqno old_cc_seqno = 0;
  for (const auto& ob : old_blkids) {
    auto odef = get_shard_hash(ob.shard_full());
    if (odef.is_null() || odef->blk_ != ob) {
      return td::Status::Error(-666,
                               std::string{"the start block "} + ob.to_str() +
                                   " of a top shard block update is not contained in the previous shard configuration");
    }
    old_cc_seqno = std::max(old_cc_seqno, odef->next_catchain_seqno_);
    if (shards_updated_.find(ob.shard_full()) != shards_updated_.end()) {
      return td::Status::Error(
          -666, std::string{"the shard of the start block "} + ob.to_str() +
                    " of a top shard block update has been already updated in the current shard configuration");
    }
    if (odef->before_split_ != before_split) {
      return td::Status::Error(
          -666, PSTRING() << "the shard of the start block " << ob.to_str()
                          << " had before_split=" << odef->before_split_
                          << " but the top shard block update is valid only if before_split=" << before_split);
    }
    if (odef->before_merge_ != before_merge) {
      return td::Status::Error(
          -666, PSTRING() << "the shard of the start block " << ob.to_str()
                          << " had before_merge=" << odef->before_merge_
                          << " but the top shard block update is valid only if before_merge=" << before_merge);
    }
    if (new_info->before_split_) {
      if (before_merge || before_split) {
        return td::Status::Error(
            -666, PSTRING() << "cannot register a before-split block " << new_info->top_block_id().to_str()
                            << " at the end of a chain that itself starts with a split/merge event");
      }
      if (odef->fsm_state() != block::McShardHash::FsmState::fsm_split) {
        return td::Status::Error(-666, PSTRING() << "cannot register a before-split block "
                                                 << new_info->top_block_id().to_str()
                                                 << " because fsm_split state was not set for this shard beforehand");
      }
      if (new_info->gen_utime_ < odef->fsm_utime_ || new_info->gen_utime_ >= odef->fsm_utime_ + odef->fsm_interval_) {
        return td::Status::Error(-666, PSTRING() << "cannot register a before-split block "
                                                 << new_info->top_block_id().to_str()
                                                 << " because fsm_split state was enabled for unixtime "
                                                 << odef->fsm_utime_ << " .. " << odef->fsm_utime_ + odef->fsm_interval_
                                                 << " but the block is generated at " << new_info->gen_utime_);
      }
    }
    if (before_merge) {
      if (odef->fsm_state() != block::McShardHash::FsmState::fsm_merge) {
        return td::Status::Error(-666, PSTRING() << "cannot register merged block " << new_info->top_block_id().to_str()
                                                 << " because fsm_merge state was not set for shard "
                                                 << odef->top_block_id().shard_full().to_str() << " beforehand");
      }
      if (new_info->gen_utime_ < odef->fsm_utime_ || new_info->gen_utime_ >= odef->fsm_utime_ + odef->fsm_interval_) {
        return td::Status::Error(-666, PSTRING() << "cannot register merged block " << new_info->top_block_id().to_str()
                                                 << " because fsm_merge state was enabled for shard "
                                                 << odef->top_block_id().shard_full().to_str() << " for unixtime "
                                                 << odef->fsm_utime_ << " .. " << odef->fsm_utime_ + odef->fsm_interval_
                                                 << " but the block is generated at " << new_info->gen_utime_);
      }
    }
    if (ancestor && !before_merge && !before_split) {
      *ancestor = odef;
    }
  }
  if (old_cc_seqno + before_merge != new_info->next_catchain_seqno_) {
    return td::Status::Error(-666, PSTRING()
                                       << "the top shard block update is generated with catchain_seqno="
                                       << new_info->next_catchain_seqno_ << " but previous shard configuration expects "
                                       << old_cc_seqno + before_merge);
  }
  if (new_info->end_lt_ >= lt_limit) {
    return td::Status::Error(-666, PSTRING() << "the top shard block update has end_lt " << new_info->end_lt_
                                             << " which is larger than the current limit " << lt_limit);
  }
  return !before_split;
}

td::Result<bool> ShardConfig::update_shard_block_info(Ref<McShardHash> new_info,
                                                      const std::vector<ton::BlockIdExt>& old_blkids) {
  Ref<McShardHash> ancestor;
  auto res = may_update_shard_block_info(new_info, old_blkids, ~0ULL, &ancestor);
  if (res.is_error()) {
    return res;
  }
  if (!res.move_as_ok()) {
    return td::Status::Error(-666, std::string{"cannot apply the after-split update for "} + new_info->blk_.to_str() +
                                       " without a corresponding sibling update");
  }
  if (ancestor.not_null() && ancestor->fsm_ != McShardHash::FsmState::fsm_none) {
    new_info.write().set_fsm(ancestor->fsm_, ancestor->fsm_utime_, ancestor->fsm_interval_);
  }
  auto blk = new_info->blk_;
  bool ok = do_update_shard_info(std::move(new_info));
  if (!ok) {
    return td::Status::Error(
        -666,
        std::string{
            "unknown serialization error for (BinTree ShardDescr) while updating shard configuration to include "} +
            blk.to_str());
  } else {
    return true;
  }
}

td::Result<bool> ShardConfig::update_shard_block_info2(Ref<McShardHash> new_info1, Ref<McShardHash> new_info2,
                                                       const std::vector<ton::BlockIdExt>& old_blkids) {
  auto res1 = may_update_shard_block_info(new_info1, old_blkids);
  if (res1.is_error()) {
    return res1;
  }
  auto res2 = may_update_shard_block_info(new_info2, old_blkids);
  if (res2.is_error()) {
    return res2;
  }
  if (res1.move_as_ok() || res2.move_as_ok()) {
    return td::Status::Error(-666, "the two updates in update_shard_block_info2 must follow a shard split event");
  }
  if (new_info1->blk_.id.shard > new_info2->blk_.id.shard) {
    std::swap(new_info1, new_info2);
  }
  auto blk1 = new_info1->blk_, blk2 = new_info2->blk_;
  bool ok = do_update_shard_info2(std::move(new_info1), std::move(new_info2));
  if (!ok) {
    return td::Status::Error(
        -666,
        std::string{
            "unknown serialization error for (BinTree ShardDescr) while updating shard configuration to include "} +
            blk1.to_str() + " and " + blk2.to_str());
  } else {
    return true;
  }
}

bool ShardConfig::do_update_shard_info(Ref<McShardHash> new_info) {
  vm::CellBuilder cb;
  Ref<vm::Cell> ref;
  return new_info.not_null() && cb.store_bool_bool(false)  // bt_leaf$0
         && new_info->pack(cb)                             // leaf:ShardDescr
         && cb.finalize_to(ref) && set_shard_info(new_info->shard(), std::move(ref));
}

bool ShardConfig::do_update_shard_info2(Ref<McShardHash> new_info1, Ref<McShardHash> new_info2) {
  if (new_info1.is_null() || new_info2.is_null() || !ton::shard_is_sibling(new_info1->shard(), new_info2->shard())) {
    return false;
  }
  if (new_info1->blk_.id.shard > new_info2->blk_.id.shard) {
    std::swap(new_info1, new_info2);
  }
  vm::CellBuilder cb, cb1;
  Ref<vm::Cell> ref;
  return cb.store_bool_bool(true)              // bt_node$1
         && cb1.store_bool_bool(false)         // ( bt_leaf$0
         && new_info1->pack(cb1)               //   leaf:ShardDescr
         && cb1.finalize_to(ref)               // ) -> ref
         && cb.store_ref_bool(std::move(ref))  // left:^(BinTree ShardDescr)
         && cb1.store_bool_bool(false)         // ( bt_leaf$0
         && new_info2->pack(cb1)               //   leaf:ShardDescr
         && cb1.finalize_to(ref)               // ) -> ref
         && cb.store_ref_bool(std::move(ref))  // right:^(BinTree ShardDescr)
         && cb.finalize_to(ref) && set_shard_info(ton::shard_parent(new_info1->shard()), std::move(ref));
}

static bool btree_set(Ref<vm::Cell>& root, ton::ShardId shard, Ref<vm::Cell> value) {
  if (!shard) {
    return false;
  }
  if (shard == ton::shardIdAll) {
    root = value;
    return true;
  }
  auto cs = vm::load_cell_slice(std::move(root));
  if (cs.size_ext() != 0x20001 || cs.prefetch_ulong(1) != 1) {
    return false;  // branch does not exist
  }
  Ref<vm::Cell> left = cs.prefetch_ref(0), right = cs.prefetch_ref(1);
  if (!(btree_set(shard & (1ULL << 63) ? right : left, shard << 1, std::move(value)))) {
    return false;
  }
  vm::CellBuilder cb;
  return cb.store_bool_bool(true)                // bt_node$1
         && cb.store_ref_bool(std::move(left))   // left:^(BinTree ShardDescr)
         && cb.store_ref_bool(std::move(right))  // right:^(BinTree ShardDescr)
         && cb.finalize_to(root);                // = BinTree ShardDescr
}

bool ShardConfig::set_shard_info(ton::ShardIdFull shard, Ref<vm::Cell> value) {
  if (!gen::t_BinTree_ShardDescr.validate_ref(1024, value)) {
    LOG(ERROR) << "attempting to store an invalid (BinTree ShardDescr) at shard configuration position "
               << shard.to_str();
    gen::t_BinTree_ShardDescr.print_ref(std::cerr, value);
    vm::load_cell_slice(value).print_rec(std::cerr);
    return false;
  }
  auto root = shard_hashes_dict_->lookup_ref(td::BitArray<32>{shard.workchain});
  if (root.is_null()) {
    LOG(ERROR) << "attempting to store a new ShardDescr for shard " << shard.to_str() << " in an undefined workchain";
    return false;
  }
  if (!btree_set(root, shard.shard, value)) {
    LOG(ERROR) << "error while storing a new ShardDescr for shard " << shard.to_str() << " into shard configuration";
    return false;
  }
  if (!shard_hashes_dict_->set_ref(td::BitArray<32>{shard.workchain}, std::move(root),
                                   vm::Dictionary::SetMode::Replace)) {
    return false;
  }
  auto ins = shards_updated_.insert(shard);
  CHECK(ins.second);
  return true;
}

bool Config::is_special_smartcontract(const ton::StdSmcAddress& addr) const {
  CHECK(special_smc_dict);
  return special_smc_dict->lookup(addr).not_null() || addr == config_addr;
}

td::Result<std::vector<ton::StdSmcAddress>> Config::get_special_smartcontracts(bool without_config) const {
  if (!special_smc_dict) {
    return td::Status::Error(-666, "configuration loaded without fundamental smart contract list");
  }
  std::vector<ton::StdSmcAddress> res;
  if (!special_smc_dict->check_for_each([&res, &without_config, conf_addr = config_addr.bits()](
                                            Ref<vm::CellSlice> cs_ref, td::ConstBitPtr key, int n) {
        if (cs_ref->size_ext() || n != 256) {
          return false;
        }
        res.emplace_back(key);
        if (!without_config && key.equals(conf_addr, 256)) {
          without_config = true;
        }
        return true;
      })) {
    return td::Status::Error(-666, "invalid fundamental smart contract set in configuration parameter 31");
  }
  if (!without_config) {
    res.push_back(config_addr);
  }
  return std::move(res);
}

td::Result<std::vector<std::pair<ton::StdSmcAddress, int>>> ConfigInfo::get_special_ticktock_smartcontracts(
    int tick_tock) const {
  if (!special_smc_dict) {
    return td::Status::Error(-666, "configuration loaded without fundamental smart contract list");
  }
  if (!accounts_dict) {
    return td::Status::Error(-666, "state loaded without accounts information");
  }
  std::vector<std::pair<ton::StdSmcAddress, int>> res;
  if (!special_smc_dict->check_for_each(
          [this, &res, tick_tock](Ref<vm::CellSlice> cs_ref, td::ConstBitPtr key, int n) -> bool {
            if (cs_ref->size_ext() || n != 256) {
              return false;
            }
            int tt = get_smc_tick_tock(key);
            if (tt < -1) {
              return false;
            }
            if (tt >= 0 && (tt & tick_tock) != 0) {
              res.emplace_back(key, tt);
            }
            return true;
          })) {
    return td::Status::Error(-666,
                             "invalid fundamental smart contract set in configuration parameter 31, or unable to "
                             "recover tick-tock value from one of them");
  }
  return std::move(res);
}

int ConfigInfo::get_smc_tick_tock(td::ConstBitPtr smc_addr) const {
  if (!accounts_dict) {
    return -2;
  }
  auto acc_csr = accounts_dict->lookup(smc_addr, 256);
  Ref<vm::Cell> acc_cell;
  if (acc_csr.is_null() || !acc_csr->prefetch_ref_to(acc_cell)) {
    return -1;
  }
  auto acc_cs = vm::load_cell_slice(std::move(acc_cell));
  if (block::gen::t_Account.get_tag(acc_cs) == block::gen::Account::account_none) {
    return 0;
  }
  block::gen::Account::Record_account acc;
  block::gen::AccountStorage::Record storage;
  int ticktock;
  return (tlb::unpack_exact(acc_cs, acc) && tlb::csr_unpack(acc.storage, storage) &&
          block::tlb::t_AccountState.get_ticktock(storage.state.write(), ticktock))
             ? ticktock
             : -2;
}

ton::CatchainSeqno ConfigInfo::get_shard_cc_seqno(ton::ShardIdFull shard) const {
  return shard.is_masterchain() ? cc_seqno_ : ShardConfig::get_shard_cc_seqno(shard);
}

std::vector<ton::ValidatorDescr> Config::compute_validator_set(ton::ShardIdFull shard, const block::ValidatorSet& vset,
                                                               ton::UnixTime time, ton::CatchainSeqno cc_seqno) const {
  return do_compute_validator_set(get_catchain_validators_config(), shard, vset, time, cc_seqno);
}

std::vector<ton::ValidatorDescr> Config::compute_validator_set(ton::ShardIdFull shard, ton::UnixTime time,
                                                               ton::CatchainSeqno cc_seqno) const {
  if (!cur_validators_) {
    LOG(DEBUG) << "failed to compute validator set: cur_validators_ is empty";
    return {};
  } else {
    return compute_validator_set(shard, *cur_validators_, time, cc_seqno);
  }
}

std::vector<ton::ValidatorDescr> ConfigInfo::compute_validator_set_cc(ton::ShardIdFull shard,
                                                                      const block::ValidatorSet& vset,
                                                                      ton::UnixTime time,
                                                                      ton::CatchainSeqno* cc_seqno_delta) const {
  if (cc_seqno_delta && (*cc_seqno_delta & -2)) {
    return {};
  }
  ton::CatchainSeqno cc_seqno = get_shard_cc_seqno(shard);
  if (cc_seqno == ~0U) {
    return {};
  }
  if (cc_seqno_delta) {
    cc_seqno = *cc_seqno_delta += cc_seqno;
  }
  return do_compute_validator_set(get_catchain_validators_config(), shard, vset, time, cc_seqno);
}

std::vector<ton::ValidatorDescr> ConfigInfo::compute_validator_set_cc(ton::ShardIdFull shard, ton::UnixTime time,
                                                                      ton::CatchainSeqno* cc_seqno_delta) const {
  auto vset = get_cur_validator_set();
  if (!vset) {
    return {};
  } else {
    return compute_validator_set_cc(shard, *vset, time, cc_seqno_delta);
  }
}

void validator_set_descr::incr_seed() {
  for (int i = 31; i >= 0 && !++(seed[i]); --i) {
  }
}

void validator_set_descr::hash_to(unsigned char hash_buffer[64]) const {
  digest::hash_str<digest::SHA512>(hash_buffer, (const void*)this, sizeof(*this));
}

td::uint64 ValidatorSetPRNG::next_ulong() {
  if (pos < limit) {
    return td::bswap64(hash_longs[pos++]);
  }
  data.hash_to(hash);
  data.incr_seed();
  pos = 1;
  limit = 8;
  return td::bswap64(hash_longs[0]);
}

td::uint64 ValidatorSetPRNG::next_ranged(td::uint64 range) {
  td::uint64 y = next_ulong();
  return td::uint128(range).mult(y).hi();
}

inline bool operator<(td::uint64 pos, const ValidatorDescr& descr) {
  return pos < descr.cum_weight;
}

const ValidatorDescr& ValidatorSet::at_weight(td::uint64 weight_pos) const {
  CHECK(weight_pos < total_weight);
  auto it = std::upper_bound(list.begin(), list.end(), weight_pos);
  CHECK(it != list.begin());
  return *--it;
}

std::vector<ton::ValidatorDescr> ValidatorSet::export_validator_set() const {
  std::vector<ton::ValidatorDescr> l;
  l.reserve(list.size());
  for (const auto& node : list) {
    l.emplace_back(node.pubkey, node.weight, node.adnl_addr);
  }
  return l;
}

std::map<ton::Bits256, int> ValidatorSet::compute_validator_map() const {
  std::map<ton::Bits256, int> res;
  for (int i = 0; i < (int)list.size(); i++) {
    res.emplace(list[i].pubkey.as_bits256(), i);
  }
  return res;
}

std::vector<double> ValidatorSet::export_scaled_validator_weights() const {
  std::vector<double> res;
  for (const auto& node : list) {
    res.push_back((double)node.weight / (double)total_weight);
  }
  return res;
}

std::vector<ton::ValidatorDescr> Config::do_compute_validator_set(const block::CatchainValidatorsConfig& ccv_conf,
                                                                  ton::ShardIdFull shard,
                                                                  const block::ValidatorSet& vset, ton::UnixTime time,
                                                                  ton::CatchainSeqno cc_seqno) {
  // LOG(DEBUG) << "in Config::do_compute_validator_set() for " << shard.to_str() << " ; cc_seqno=" << cc_seqno;
  std::vector<ton::ValidatorDescr> nodes;
  bool is_mc = shard.is_masterchain();
  unsigned count = std::min<unsigned>(is_mc ? vset.main : ccv_conf.shard_val_num, vset.total);
  CHECK((unsigned)vset.total == vset.list.size());
  if (!count) {
    return {};  // no validators?
  }
  nodes.reserve(count);
  ValidatorSetPRNG gen{shard, cc_seqno};  // use zero seed (might use a non-trivial seed from ccv_conf in the future)
  if (is_mc) {
    if (ccv_conf.shuffle_mc_val) {
      // shuffle mc validators from the head of the list
      std::vector<unsigned> idx(count);
      CHECK(idx.size() == count);
      for (unsigned i = 0; i < count; i++) {
        unsigned j = (unsigned)gen.next_ranged(i + 1);  // number 0 .. i
        CHECK(j <= i);
        idx[i] = idx[j];
        idx[j] = i;
      }
      for (unsigned i = 0; i < count; i++) {
        const auto& v = vset.list[idx[i]];
        nodes.emplace_back(v.pubkey, v.weight, v.adnl_addr);
      }
    } else {
      // simply take needed number of validators from the head of the list
      for (unsigned i = 0; i < count; i++) {
        const auto& v = vset.list[i];
        nodes.emplace_back(v.pubkey, v.weight, v.adnl_addr);
      }
    }
    return nodes;
  }
  // this is the "true" algorithm for generating shardchain validator subgroups
  std::vector<std::pair<td::uint64, td::uint64>> holes;
  holes.reserve(count);
  td::uint64 total_wt = vset.total_weight;
  for (unsigned i = 0; i < count; i++) {
    CHECK(total_wt > 0);
    auto p = gen.next_ranged(total_wt);  // generate a pseudo-random number 0 .. total_wt-1
    // auto op = p;
    for (auto& hole : holes) {
      if (p < hole.first) {
        break;
      }
      p += hole.second;
    }
    auto& entry = vset.at_weight(p);
    // LOG(DEBUG) << "vset entry #" << i << ": rem_wt=" << total_wt << ", total_wt=" << vset.total_weight << ", op=" << op << ", p=" << p << "; entry.cum_wt=" << entry.cum_weight << ", entry.wt=" << entry.weight << " " << entry.cum_weight / entry.weight;
    nodes.emplace_back(entry.pubkey, 1, entry.adnl_addr);  // NB: shardchain validator lists have all weights = 1
    CHECK(total_wt >= entry.weight);
    total_wt -= entry.weight;
    std::pair<td::uint64, td::uint64> new_hole{entry.cum_weight, entry.weight};
    auto it = std::upper_bound(holes.begin(), holes.end(), new_hole);
    CHECK(it == holes.begin() || *(it - 1) < new_hole);
    holes.insert(it, new_hole);
  }
  return nodes;
}

std::vector<ton::ValidatorDescr> Config::compute_total_validator_set(int next) const {
  auto res = unpack_validator_set(get_config_param(next < 0 ? 32 : (next ? 36 : 34)));
  if (res.is_error()) {
    return {};
  }
  return res.move_as_ok()->export_validator_set();
}

td::Result<std::pair<ton::UnixTime, ton::UnixTime>> Config::unpack_validator_set_start_stop(Ref<vm::Cell> vset_root) {
  if (vset_root.is_null()) {
    return td::Status::Error("validator set absent");
  }
  gen::ValidatorSet::Record_validators_ext rec;
  if (tlb::unpack_cell(vset_root, rec)) {
    return std::pair<ton::UnixTime, ton::UnixTime>(rec.utime_since, rec.utime_until);
  }
  gen::ValidatorSet::Record_validators rec0;
  if (tlb::unpack_cell(std::move(vset_root), rec0)) {
    return std::pair<ton::UnixTime, ton::UnixTime>(rec0.utime_since, rec0.utime_until);
  }
  return td::Status::Error("validator set is invalid");
}

std::pair<ton::UnixTime, ton::UnixTime> Config::get_validator_set_start_stop(int next) const {
  auto res = unpack_validator_set_start_stop(get_config_param(next < 0 ? 32 : (next ? 36 : 34)));
  if (res.is_error()) {
    return {0, 0};
  } else {
    return res.move_as_ok();
  }
}

bool WorkchainInfo::unpack(ton::WorkchainId wc, vm::CellSlice& cs) {
  workchain = ton::workchainInvalid;
  if (wc == ton::workchainInvalid) {
    return false;
  }
  block::gen::WorkchainDescr::Record info;
  if (!tlb::unpack(cs, info)) {
    return false;
  }
  enabled_since = info.enabled_since;
  actual_min_split = info.actual_min_split;
  min_split = info.min_split;
  max_split = info.max_split;
  basic = info.basic;
  active = info.active;
  accept_msgs = info.accept_msgs;
  flags = info.flags;
  zerostate_root_hash = info.zerostate_root_hash;
  zerostate_file_hash = info.zerostate_file_hash;
  version = info.version;
  if (basic) {
    min_addr_len = max_addr_len = addr_len_step = 256;
  } else {
    block::gen::WorkchainFormat::Record_wfmt_ext ext;
    if (!tlb::type_unpack(cs, block::gen::WorkchainFormat{basic}, ext)) {
      return false;
    }
    min_addr_len = ext.min_addr_len;
    max_addr_len = ext.max_addr_len;
    addr_len_step = ext.addr_len_step;
  }
  workchain = wc;
  LOG(DEBUG) << "unpacked info for workchain " << wc << ": basic=" << basic << ", active=" << active
             << ", accept_msgs=" << accept_msgs << ", min_split=" << min_split << ", max_split=" << max_split;
  return true;
}

Ref<WorkchainInfo> Config::get_workchain_info(ton::WorkchainId workchain_id) const {
  if (!workchains_dict_) {
    return {};
  }
  auto it = workchains_.find(workchain_id);
  if (it == workchains_.end()) {
    return {};
  } else {
    return it->second;
  }
}

bool ConfigInfo::get_old_mc_block_id(ton::BlockSeqno seqno, ton::BlockIdExt& blkid, ton::LogicalTime* end_lt) const {
  if (block_id.is_valid() && seqno == block_id.id.seqno) {
    blkid = block_id;
    if (end_lt) {
      *end_lt = lt;
    }
    return true;
  } else {
    return block::get_old_mc_block_id(prev_blocks_dict_.get(), seqno, blkid, end_lt);
  }
}

bool ConfigInfo::check_old_mc_block_id(const ton::BlockIdExt& blkid, bool strict) const {
  return (!strict && blkid.id.seqno == block_id.id.seqno && block_id.is_valid())
             ? blkid == block_id
             : block::check_old_mc_block_id(prev_blocks_dict_.get(), blkid);
}

// returns block with min block.seqno and req_lt <= block.end_lt
bool ConfigInfo::get_mc_block_by_lt(ton::LogicalTime req_lt, ton::BlockIdExt& blkid, ton::LogicalTime* end_lt) const {
  if (req_lt > lt) {
    return false;
  }
  td::BitArray<32> key;
  auto found = prev_blocks_dict_->traverse_extra(
      key.bits(), 32,
      [req_lt](td::ConstBitPtr key_prefix, int key_pfx_len, Ref<vm::CellSlice> extra, Ref<vm::CellSlice> value) {
        unsigned long long found_lt;
        if (!(extra.write().advance(1) && extra.write().fetch_ulong_bool(64, found_lt))) {
          return -1;
        }
        if (found_lt < req_lt) {
          return 0;  // all leaves in subtree have end_lt <= found_lt < req_lt, skip
        }
        return 6;  // visit left subtree, then right subtree; for leaf: accept and return to the top
      });
  if (found.first.not_null()) {
    CHECK(unpack_old_mc_block_id(std::move(found.first), (unsigned)key.to_ulong(), blkid, end_lt));
    return true;
  }
  if (block_id.is_valid()) {
    blkid = block_id;
    if (end_lt) {
      *end_lt = lt;
    }
    return true;
  } else {
    return false;
  }
}

// returns key block with max block.seqno and block.seqno <= req_seqno
bool ConfigInfo::get_prev_key_block(ton::BlockSeqno req_seqno, ton::BlockIdExt& blkid, ton::LogicalTime* end_lt) const {
  if (block_id.is_valid() && is_key_state_ && block_id.seqno() <= req_seqno) {
    blkid = block_id;
    if (end_lt) {
      *end_lt = lt;
    }
    return true;
  }
  td::BitArray<32> key;
  auto found =
      prev_blocks_dict_->traverse_extra(key.bits(), 32,
                                        [req_seqno](td::ConstBitPtr key_prefix, int key_pfx_len,
                                                    Ref<vm::CellSlice> extra, Ref<vm::CellSlice> value) -> int {
                                          if (extra->prefetch_ulong(1) != 1) {
                                            return 0;  // no key blocks in subtree, skip
                                          }
                                          unsigned x = (unsigned)key_prefix.get_uint(key_pfx_len);
                                          unsigned d = 32 - key_pfx_len;
                                          if (!d) {
                                            return x <= req_seqno;
                                          }
                                          unsigned y = req_seqno >> (d - 1);
                                          if (y < 2 * x) {
                                            // (x << d) > req_seqno <=> x > (req_seqno >> d) = (y >> 1) <=> 2 * x > y
                                            return 0;  // all nodes in subtree have block.seqno > req_seqno => skip
                                          }
                                          return y == 2 * x ? 1 /* visit only left */ : 5 /* visit right, then left */;
                                        });
  if (found.first.not_null()) {
    CHECK(unpack_old_mc_block_id(std::move(found.first), (unsigned)key.to_ulong(), blkid, end_lt));
    CHECK(blkid.seqno() <= req_seqno);
    return true;
  } else {
    blkid.invalidate();
    return false;
  }
}

// returns key block with min block.seqno and block.seqno >= req_seqno
bool ConfigInfo::get_next_key_block(ton::BlockSeqno req_seqno, ton::BlockIdExt& blkid, ton::LogicalTime* end_lt) const {
  td::BitArray<32> key;
  auto found = prev_blocks_dict_->traverse_extra(
      key.bits(), 32,
      [req_seqno](td::ConstBitPtr key_prefix, int key_pfx_len, Ref<vm::CellSlice> extra,
                  Ref<vm::CellSlice> value) -> int {
        if (extra->prefetch_ulong(1) != 1) {
          return 0;  // no key blocks in subtree, skip
        }
        unsigned x = (unsigned)key_prefix.get_uint(key_pfx_len);
        unsigned d = 32 - key_pfx_len;
        if (!d) {
          return x >= req_seqno;
        }
        unsigned y = req_seqno >> (d - 1);
        if (y > 2 * x + 1) {
          // ((x + 1) << d) <= req_seqno <=> (x+1) <= (req_seqno >> d) = (y >> 1) <=> 2*x+2 <= y <=> y > 2*x+1
          return 0;  // all nodes in subtree have block.seqno < req_seqno => skip
        }
        return y == 2 * x + 1 ? 2 /* visit only right */ : 6 /* visit left, then right */;
      });
  if (found.first.not_null()) {
    CHECK(unpack_old_mc_block_id(std::move(found.first), (unsigned)key.to_ulong(), blkid, end_lt));
    CHECK(blkid.seqno() >= req_seqno);
    return true;
  }
  if (block_id.is_valid() && is_key_state_ && block_id.seqno() >= req_seqno) {
    blkid = block_id;
    if (end_lt) {
      *end_lt = lt;
    }
    return true;
  } else {
    blkid.invalidate();
    return false;
  }
}

Ref<vm::Cell> ConfigInfo::lookup_library(td::ConstBitPtr root_hash) const {
  if (!libraries_dict_) {
    return {};
  }
  auto csr = libraries_dict_->lookup(root_hash, 256);
  if (csr.is_null() || csr->prefetch_ulong(8) != 0 || !csr->have_refs()) {  // shared_lib_descr$00 lib:^Cell
    return {};
  }
  auto lib = csr->prefetch_ref();
  if (lib->get_hash().bits().compare(root_hash, 256)) {
    LOG(ERROR) << "public library hash mismatch: expected " << root_hash.to_hex(256) << " , found "
               << lib->get_hash().bits().to_hex(256);
    return {};
  }
  return lib;
}

}  // namespace block
