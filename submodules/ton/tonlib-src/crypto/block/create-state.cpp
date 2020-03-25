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
#include <cassert>
#include <algorithm>
#include <string>
#include <vector>
#include <iostream>
#include <sstream>
#include <fstream>
#include <memory>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <map>
#include <functional>
#include <limits>
#include <getopt.h>

#include "vm/stack.hpp"
#include "vm/boc.h"

#include "fift/Fift.h"
#include "fift/Dictionary.h"
#include "fift/SourceLookup.h"
#include "fift/words.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Parser.h"
#include "td/utils/port/path.h"
#include "td/utils/port/signals.h"

#include "tonlib/keys/Mnemonic.h"

#include "block.h"
#include "block-parse.h"
#include "block-auto.h"
#include "mc-config.h"

#define PDO(__op) \
  if (!(__op)) {  \
    ok = false;   \
  }
#define THRERR(__msg)            \
  if (!ok) {                     \
    throw fift::IntError{__msg}; \
  }
#define RETERR    \
  if (!ok) {      \
    return false; \
  }

using td::Ref;

int verbosity;

enum { wc_master = -1, wc_base = 0 };
constexpr int wc_undef = std::numeric_limits<int>::min();

int workchain_id = wc_undef;
int global_id = 0;

typedef td::BitArray<256> hash_t;

struct SmcDescr {
  hash_t addr;
  int split_depth;
  bool preinit_only;
  td::RefInt256 gram_balance;
  Ref<vm::DataCell> state_init;  // StateInit
  Ref<vm::DataCell> account;     // Account
  SmcDescr(const hash_t& _addr) : addr(_addr), split_depth(0), preinit_only(false) {
  }
};

std::map<hash_t, SmcDescr> smart_contracts;
td::RefInt256 total_smc_balance{true, 0}, max_total_smc_balance;

struct PublicLibDescr {
  Ref<vm::Cell> root;
  std::set<hash_t> publishers;
  PublicLibDescr(Ref<vm::Cell> _root) : root(std::move(_root)) {
  }
};

std::map<hash_t, PublicLibDescr> public_libraries;

hash_t config_addr;
Ref<vm::Cell> config_param_root;
bool config_addr_set;
vm::Dictionary config_dict{32};

ton::UnixTime now;

bool set_config_smc(const SmcDescr& smc) {
  if (config_addr_set || smc.preinit_only || workchain_id != wc_master || smc.split_depth) {
    return false;
  }
  vm::CellSlice cs = load_cell_slice(smc.state_init);
  bool ok = true;
  PDO(block::gen::t_Maybe_natwidth_5.skip(cs) && block::gen::t_Maybe_TickTock.skip(cs) &&
      block::gen::t_Maybe_Ref_Cell.skip(cs));
  RETERR;
  Ref<vm::Cell> data;
  PDO(cs.fetch_ulong(1) == 1 && cs.fetch_ref_to(data));
  THRERR("config smart contract must have non-empty data");
  vm::CellSlice cs2 = load_cell_slice(data);
  PDO(cs2.fetch_ref_to(data));
  THRERR("first reference in config smart contract data must point to initial configuration");
  PDO(block::valid_config_data(data, smc.addr));
  THRERR("invalid smart contract configuration data");
  config_addr = smc.addr;
  config_param_root = std::move(data);
  config_addr_set = true;
  if (verbosity > 2) {
    std::cerr << "set smart contract " << config_addr << " as the configuration smart contract with configuration:\n";
    load_cell_slice(config_param_root).print_rec(std::cerr);
  }
  return true;
}

void interpret_set_workchain(vm::Stack& stack) {
  workchain_id = stack.pop_smallint_range(0x7fffffff, -0x7fffffff);
}

void interpret_get_workchain(vm::Stack& stack) {
  stack.push_smallint(workchain_id);
}

void interpret_set_global_id(vm::Stack& stack) {
  global_id = stack.pop_smallint_range(0x7fffffff, -0x7fffffff);
}

void interpret_get_global_id(vm::Stack& stack) {
  stack.push_smallint(global_id);
}

void interpret_get_verbosity(vm::Stack& stack) {
  stack.push_smallint(GET_VERBOSITY_LEVEL());
}

void interpret_set_verbosity(vm::Stack& stack) {
  int x = stack.pop_smallint_range(15);
  SET_VERBOSITY_LEVEL(x);
}

void interpret_set_config_smartcontract(vm::Stack& stack) {
  if (workchain_id != wc_master) {
    throw fift::IntError{"configuration smart contract may be selected in masterchain only"};
  }
  if (config_addr_set) {
    throw fift::IntError{"configuration smart contract already selected"};
  }
  td::RefInt256 int_addr = stack.pop_int_finite();
  hash_t addr;
  if (!int_addr->export_bits(addr.bits(), 256, false)) {
    throw fift::IntError{"not a valid smart-contract address"};
  }
  auto it = smart_contracts.find(addr);
  if (it == smart_contracts.end()) {
    throw fift::IntError{"unknown smart contract"};
  }
  const SmcDescr& smc = it->second;
  assert(smc.addr == addr);
  if (smc.preinit_only) {
    throw fift::IntError{"configuration smart contract must be completely initialized"};
  }
  if (!set_config_smc(smc)) {
    throw fift::IntError{"invalid configuration smart contract"};
  }
}

bool is_empty_cell(Ref<vm::Cell> cell) {
  bool is_special;
  auto cs = load_cell_slice_special(std::move(cell), is_special);
  return !is_special && cs.empty_ext();
}

bool add_public_library(hash_t lib_addr, hash_t smc_addr, Ref<vm::Cell> lib_root) {
  if (lib_root.is_null() || lib_root->get_hash().as_array() != lib_addr.as_array()) {
    return false;
  }
  auto ins = public_libraries.emplace(lib_addr, lib_root);
  PublicLibDescr& lib = ins.first->second;
  lib.publishers.insert(smc_addr);
  if (verbosity > 2) {
    std::cerr << "added " << (ins.second ? "new " : "") << "public library " << lib_addr << " with publisher "
              << smc_addr << std::endl;
  }
  return true;
}

td::RefInt256 create_smartcontract(td::RefInt256 smc_addr, Ref<vm::Cell> code, Ref<vm::Cell> data,
                                   Ref<vm::Cell> library, td::RefInt256 balance, int special, int split_depth,
                                   int mode) {
  if (is_empty_cell(code)) {
    code.clear();
  }
  if (is_empty_cell(data)) {
    data.clear();
  }
  if (is_empty_cell(library)) {
    library.clear();
  }
  bool ok = true;
  if (library.not_null()) {
    PDO(block::valid_library_collection(library, false));
    THRERR("not a valid library collection");
  }
  vm::CellBuilder cb;
  if (!split_depth) {
    PDO(cb.store_long_bool(0, 1));
  } else {
    PDO(cb.store_long_bool(1, 1) && cb.store_ulong_rchk_bool(split_depth, 5));
  }
  THRERR("invalid split_depth for a smart contract");
  if (!special) {
    PDO(cb.store_long_bool(0, 1));
  } else {
    PDO(cb.store_long_bool(1, 1) && cb.store_ulong_rchk_bool(special, 2));
  }
  THRERR("invalid special TickTock argument for a smart contract");
  PDO(cb.store_maybe_ref(std::move(code)) && cb.store_maybe_ref(std::move(data)) && cb.store_maybe_ref(library));
  THRERR("cannot store smart-contract code, data or library");
  Ref<vm::DataCell> state_init = cb.finalize();
  hash_t addr;
  if (smc_addr.is_null()) {
    addr = state_init->get_hash().as_array();
    smc_addr = td::RefInt256{true};
    PDO(smc_addr.write().import_bits(addr.data(), 0, 256, false));
  } else if (mode == 1) {
    throw fift::IntError{"cannot create uninitialized smart contracts with specified addresses"};
  } else {
    PDO(smc_addr->export_bits(addr.data(), 0, 256, false));
  }
  THRERR("cannot initialize smart-contract address");
  if (verbosity > 2) {
    std::cerr << "smart-contract address is ";
    std::cerr << addr << " = " << smc_addr << std::endl;
  }
  PDO(mode || !sgn(balance));
  THRERR("cannot set non-zero balance to smart contract unless it is initialized");
  PDO(sgn(balance) >= 0);
  THRERR("balance cannot be negative");
  if (!mode) {
    return smc_addr;  // compute address only
  }
  auto it = smart_contracts.find(addr);
  if (it != smart_contracts.end()) {
    std::cerr << "smart contract " << addr << " already defined\n";
    throw fift::IntError{"smart contract already exists"};
  }
  auto ins = smart_contracts.emplace(addr, addr);
  assert(ins.second);
  SmcDescr& smc = ins.first->second;
  smc.split_depth = split_depth;
  smc.preinit_only = (mode == 1);
  smc.gram_balance = balance;
  total_smc_balance += balance;
  if (mode > 1) {
    smc.state_init = std::move(state_init);
  }
  if (max_total_smc_balance.not_null() && total_smc_balance > max_total_smc_balance) {
    throw fift::IntError{"total smart-contract balance exceeds limit"};
  }
  cb.reset();
  PDO(cb.store_long_bool(0, 64)                                 // account_storage$_ last_trans_lt:uint64
      && block::tlb::t_Grams.store_integer_value(cb, *balance)  // balance.grams:Grams
      && cb.store_long_bool(0, 1));                             // balance.other:ExtraCurrencyCollection
  if (mode == 1) {
    PDO(block::gen::t_AccountState.pack_account_uninit(cb));
  } else {
    PDO(block::gen::t_AccountState.pack_account_active(cb, vm::load_cell_slice_ref(smc.state_init)));
  }
  THRERR("cannot create smart-contract AccountStorage");
  Ref<vm::DataCell> storage = cb.finalize();
  vm::CellStorageStat stats;
  PDO(stats.compute_used_storage(Ref<vm::Cell>(storage)));
  if (verbosity > 2) {
    std::cerr << "storage is:\n";
    vm::load_cell_slice(storage).print_rec(std::cerr);
    std::cerr << "stats: bits=" << stats.bits << ", cells=" << stats.cells << std::endl;
    std::cerr << "block::gen::AccountStorage.validate_ref() = " << block::gen::t_AccountStorage.validate_ref(storage)
              << std::endl;
    std::cerr << "block::tlb::AccountStorage.validate_ref() = " << block::tlb::t_AccountStorage.validate_ref(storage)
              << std::endl;
  }
  PDO(block::gen::t_AccountStorage.validate_ref(storage));
  THRERR("AccountStorage of created smart-contract is invalid (?)");
  cb.reset();                     // build Account
  PDO(cb.store_long_bool(1, 1));  // account$1
  int ctor = 3;                   // addr_var$11
  if (workchain_id >= -128 && workchain_id <= 127) {
    ctor = 2;  // addr_std$10
  }
  PDO(cb.store_long_bool(ctor, 2));  // addr_std$10 or addr_var$11
  if (split_depth) {
    PDO(cb.store_long_bool(1, 1)                            // just$1
        && cb.store_ulong_rchk_bool(split_depth, 5)         // depth:(## 5)
        && cb.store_bits_bool(addr.cbits(), split_depth));  // rewrite pfx:(depth * Bit)
  } else {
    PDO(cb.store_long_bool(0, 1));  // nothing$0
  }
  PDO(cb.store_long_rchk_bool(workchain_id, ctor == 2 ? 8 : 32) && cb.store_bits_bool(addr.cbits(), 256));
  THRERR("Cannot serialize addr:MsgAddressInt of the new smart contract");
  // storage_stat:StorageInfo -> storage_stat.used:StorageUsed
  PDO(block::store_UInt7(cb, stats.cells)              // cells:(VarUInteger 7)
      && block::store_UInt7(cb, stats.bits)            // bits:(VarUInteger 7)
      && block::store_UInt7(cb, stats.public_cells));  // public_cells:(VarUInteger 7)
  THRERR("Cannot serialize used:StorageUsed of the new smart contract");
  PDO(cb.store_long_bool(0, 33));          // last_paid:uint32 due_payment:(Maybe Grams)
  PDO(cb.append_data_cell_bool(storage));  // storage:AccountStorage
  THRERR("Cannot create Account of the new smart contract");
  smc.account = cb.finalize();
  if (verbosity > 2) {
    std::cerr << "account is:\n";
    vm::load_cell_slice(smc.account).print_rec(std::cerr);
    std::cerr << "block::gen::Account.validate_ref() = " << block::gen::t_Account.validate_ref(smc.account)
              << std::endl;
    std::cerr << "block::tlb::Account.validate_ref() = " << block::tlb::t_Account.validate_ref(smc.account)
              << std::endl;
  }
  PDO(block::gen::t_Account.validate_ref(smc.account));
  THRERR("Account of created smart contract is invalid (?)");
  if (library.not_null()) {
    vm::Dictionary dict{std::move(library), 256};
    ok &= dict.check_for_each([addr](Ref<vm::CellSlice> cs, td::ConstBitPtr key, int n) -> bool {
      return !cs->prefetch_ulong(1) || add_public_library(key, addr, cs->prefetch_ref());
    });
    THRERR("Error processing libraries published by new smart contract");
  }
  return smc_addr;
}

// stores accounts:ShardAccounts
bool store_accounts(vm::CellBuilder& cb) {
  vm::AugmentedDictionary dict{256, block::tlb::aug_ShardAccounts};
  for (const auto& smc_pair : smart_contracts) {
    const SmcDescr& smc = smc_pair.second;
    CHECK(smc_pair.first == smc.addr);
    vm::CellBuilder cb;
    bool ok = cb.store_ref_bool(smc.account)     // account_descr$_ acc:^Account
              && cb.store_zeroes_bool(256 + 64)  // last_trans_hash:bits256 last_trans_lt:uint64
              && dict.set_builder(smc.addr.cbits(), 256, cb, vm::Dictionary::SetMode::Add);
    CHECK(ok);
  }
  return std::move(dict).append_dict_to_bool(cb);
}

// stores libraries:(HashmapE 256 LibDescr)
bool store_public_libraries(vm::CellBuilder& cb) {
  vm::Dictionary dict{256};
  bool ok = true;
  vm::CellBuilder empty_cb;
  for (const auto& lib_pair : public_libraries) {
    const PublicLibDescr pl = lib_pair.second;
    PDO(pl.root->get_hash().as_array() == lib_pair.first.as_array());
    vm::Dictionary publishers{256};
    for (const auto& publisher : pl.publishers) {
      PDO(publishers.set_builder(publisher.cbits(), 256, empty_cb, vm::Dictionary::SetMode::Add));
    }
    Ref<vm::Cell> root = std::move(publishers).extract_root_cell();
    PDO(root.not_null());
    THRERR("public library has an empty or invalid set of publishers");
    vm::CellBuilder value_cb;  // LibDescr
    PDO(value_cb.store_long_bool(0, 2) && value_cb.store_ref_bool(pl.root) &&
        value_cb.append_cellslice_bool(vm::load_cell_slice(std::move(root))));
    THRERR("cannot create LibDescr for a public library");
    PDO(dict.set_builder(lib_pair.first.cbits(), 256, value_cb, vm::Dictionary::SetMode::Add));
    THRERR("cannot insert LibDescr of a public library into the public library collection");
  }
  PDO(std::move(dict).append_dict_to_bool(cb));
  return ok;
}

// stores config:ConfigParams
bool store_config_params(vm::CellBuilder& cb) {
  return config_addr_set && config_param_root.not_null() &&
         cb.store_bits_bool(config_addr.cbits(), 256)  // _ config_addr:bits256
         && cb.store_ref_bool(config_param_root);      // config:^(Hashmap 32 ^Cell)
}

// stores hash of initial masterchain validator set computed from configuration parameter 34
bool store_validator_list_hash(vm::CellBuilder& cb) {
  Ref<vm::Cell> vset_cell = config_dict.lookup_ref(td::BitArray<32>{34});
  auto res = block::Config::unpack_validator_set(std::move(vset_cell));
  if (res.is_error()) {
    LOG(ERROR) << "cannot unpack current validator set: " << res.move_as_error().to_string();
    return false;
  }
  auto vset = res.move_as_ok();
  LOG_CHECK(vset) << "unpacked validator set is empty";
  auto ccvc = block::Config::unpack_catchain_validators_config(config_dict.lookup_ref(td::BitArray<32>{28}));
  ton::ShardIdFull shard{ton::masterchainId};
  auto nodes = block::Config::do_compute_validator_set(ccvc, shard, *vset, now, 0);
  LOG_CHECK(!nodes.empty()) << "validator node list in unpacked validator set is empty";
  auto vset_hash = block::compute_validator_set_hash(0, shard, std::move(nodes));
  LOG(DEBUG) << "initial validator set hash is " << vset_hash;
  return cb.store_long_bool(vset_hash, 32);
}

// stores custom:(Maybe ^McStateExtra)
bool store_custom(vm::CellBuilder& cb) {
  if (workchain_id != wc_master) {
    return cb.store_long_bool(0, 1);  // nothing
  }
  vm::CellBuilder cb2, cb3;
  bool ok = true;
  PDO(cb2.store_long_bool(0xcc26, 16)        // masterchain_state_extra#cc26
      && cb2.store_long_bool(0, 1)           // shard_hashes:ShardHashes = (HashmapE 32 ^(BinTree ShardDescr))
      && store_config_params(cb2)            // config:ConfigParams
      && cb3.store_long_bool(0, 16)          // ^[ flags:(## 16) { flags = 0 }
      && store_validator_list_hash(cb3)      //   validator_list_hash_short:uint32
      && cb3.store_long_bool(0, 32)          //   catchain_seqno:uint32
      && cb3.store_bool_bool(true)           //   nx_cc_updated:Bool
      && cb3.store_zeroes_bool(1 + 65)       //   prev_blocks:OldMcBlocksInfo
      && cb3.store_long_bool(2, 1 + 1)       //   after_key_block:Bool last_key_block:(Maybe ...)
      && cb2.store_ref_bool(cb3.finalize())  // ]
      && block::CurrencyCollection{total_smc_balance}.store(cb2)  // global_balance:CurrencyCollection
      && cb.store_long_bool(1, 1)                                 // just
      && cb.store_ref_bool(cb2.finalize()));
  return ok;
}

Ref<vm::Cell> create_state() {
  vm::CellBuilder cb, cb2;
  now = static_cast<ton::UnixTime>(time(0));
  bool ok = true;
  PDO(workchain_id != wc_undef);
  THRERR("workchain_id is unset, cannot generate state");
  PDO(workchain_id != wc_master || config_addr_set);
  THRERR("configuration smart contract must be selected");
  PDO(cb.store_long_bool(0x9023afe2, 32)      // shard_state#9023afe2
      && cb.store_long_bool(global_id, 32));  // global_id:int32
  PDO(cb.store_long_bool(0, 8) && cb.store_long_bool(workchain_id, 32) &&
      cb.store_long_bool(0, 64)                                   // shard_id:ShardIdent
      && cb.store_long_bool(0, 32)                                // seq_no:#
      && cb.store_zeroes_bool(32)                                 // vert_seq_no:#
      && cb.store_long_bool(now, 32)                              // gen_utime:uint32
      && cb.store_zeroes_bool(64)                                 // gen_lt:uint64
      && cb.store_ones_bool(32)                                   // min_ref_mc_seqno:uint32
      && cb2.store_zeroes_bool(1 + 64 + 2)                        // OutMsgQueueInfo
      && cb.store_ref_bool(cb2.finalize())                        // out_msg_queue_info:^OutMsgQueueInfo
      && cb.store_long_bool(0, 1)                                 // before_split:Bool
      && store_accounts(cb2)                                      // accounts:^ShardAccounts
      && cb.store_ref_bool(cb2.finalize())                        // ...
      && cb2.store_zeroes_bool(128)                               // ^[ overload_history:uint64 underload_history:uint64
      && block::CurrencyCollection{total_smc_balance}.store(cb2)  //   total_balance:CurrencyCollection
      && block::tlb::t_CurrencyCollection.null_value(cb2)         //   total_validator_fees:CurrencyCollection
      && store_public_libraries(cb2)                              //   libraries:(Hashmap 256 LibDescr)
      && cb2.store_long_bool(0, 1)                                //   master_ref:(Maybe BlkMasterInfo)
      && cb.store_ref_bool(cb2.finalize())                        // ]
      && store_custom(cb));                                       // custom:(Maybe ^McStateExtra)
  THRERR("cannot create blockchain state");
  Ref<vm::Cell> cell = cb.finalize();
  if (verbosity > 2) {
    std::cerr << "shard_state is:\n";
    vm::load_cell_slice(cell).print_rec(std::cerr);
    std::cerr << "pretty-printed shard_state is:\n";
    block::gen::t_ShardState.print_ref(std::cerr, cell);
    std::cerr << "\n";
    std::cerr << "block::gen::ShardState.validate_ref() = " << block::gen::t_ShardState.validate_ref(cell) << std::endl;
    std::cerr << "block::tlb::ShardState.validate_ref() = " << block::tlb::t_ShardState.validate_ref(cell) << std::endl;
    block::gen::ShardStateUnsplit::Record data;
    bool ok1 = tlb::unpack_cell(cell, data);
    std::cerr << "block::gen::ShardState.unpack_cell() = " << ok1 << std::endl;
    if (ok1) {
      std::cerr << "shard_id = " << data.shard_id
                << "; out_msg_queue_info = " << load_cell_slice(data.out_msg_queue_info)
                << "; total_balance = " << data.r1.total_balance << std::endl;
    }
  }
  PDO(block::gen::t_ShardState.validate_ref(cell));
  PDO(block::tlb::t_ShardState.validate_ref(cell));
  THRERR("created an invalid ShardState record");
  return cell;
}

// code (cell)
// data (cell)
// library (cell)
// balance (int)
// split_depth (int 0..32)
// special (int 0..3, +2 = tick, +1 = tock)
// [ address (uint256) ]
// mode (0 = compute address only, 1 = create uninit, 2 = create complete; +4 = with specified address)
// --> 256-bit address
void interpret_register_smartcontract(vm::Stack& stack) {
  if (workchain_id == wc_undef) {
    throw fift::IntError{"cannot register a smartcontract unless the workchain is specified first"};
  }
  td::RefInt256 spec_addr;
  int mode = stack.pop_smallint_range(2 + 4);  // allowed modes: 0 1 2 4 5 6
  if (mode == 3) {
    throw fift::IntError{"invalid mode"};
  }
  if (mode & 4) {
    spec_addr = stack.pop_int_finite();
    mode &= ~4;
  }
  int special = stack.pop_smallint_range(3);
  if (special && workchain_id != wc_master) {
    throw fift::IntError{"cannot create special smartcontracts outside of the masterchain"};
  }
  int split_depth = stack.pop_smallint_range(32);
  td::RefInt256 balance = stack.pop_int_finite();
  if (sgn(balance) < 0) {
    throw fift::IntError{"initial balance of a smartcontract cannot be negative"};
  }
  if (sgn(balance) > 0 && !mode) {
    throw fift::IntError{"cannot set non-zero balance if an account is not created"};
  }
  Ref<vm::Cell> library = stack.pop_cell();
  Ref<vm::Cell> data = stack.pop_cell();
  Ref<vm::Cell> code = stack.pop_cell();
  td::RefInt256 addr = create_smartcontract(std::move(spec_addr), std::move(code), std::move(data), std::move(library),
                                            std::move(balance), special, split_depth, mode);
  if (addr.is_null()) {
    throw fift::IntError{"internal error while creating smartcontract"};
  }
  stack.push(std::move(addr));
}

void interpret_create_state(vm::Stack& stack) {
  if (!global_id) {
    throw fift::IntError{
        "(global) blockchain id must be set to a non-zero value: negative for test chains, positive for production"};
  }
  Ref<vm::Cell> state = create_state();
  if (state.is_null()) {
    throw fift::IntError{"could not create blockchain state"};
  }
  stack.push(std::move(state));
}

void interpret_get_config_dict(vm::Stack& stack) {
  Ref<vm::Cell> value = config_dict.get_root_cell();
  if (value.is_null()) {
    stack.push_bool(false);
  } else {
    stack.push_cell(std::move(value));
    stack.push_bool(true);
  }
}

void interpret_get_config_param(vm::Stack& stack) {
  int x = stack.pop_smallint_range(0x7fffffff, 0x80000000);
  Ref<vm::Cell> value = config_dict.lookup_ref(td::BitArray<32>{x});
  if (value.is_null()) {
    stack.push_bool(false);
  } else {
    stack.push_cell(std::move(value));
    stack.push_bool(true);
  }
}

void interpret_set_config_param(vm::Stack& stack) {
  int x = stack.pop_smallint_range(0x7fffffff, 0x80000000);
  Ref<vm::Cell> value = stack.pop_cell();
  if (verbosity > 2 && x >= 0) {
    std::cerr << "setting configuration parameter #" << x << " to ";
    // vm::load_cell_slice(value).print_rec(std::cerr);
    block::gen::ConfigParam{x}.print_ref(std::cerr, value);
    std::cerr << std::endl;
  }
  if (x >= 0 && !block::gen::ConfigParam{x}.validate_ref(value)) {
    throw fift::IntError{"invalid value for indicated configuration parameter"};
  }
  if (!config_dict.set_ref(td::BitArray<32>{x}, std::move(value))) {
    throw fift::IntError{"cannot set value of configuration parameter (value too long?)"};
  }
}

void interpret_is_shard_state(vm::Stack& stack) {
  Ref<vm::Cell> cell = stack.pop_cell();
  if (verbosity > 4) {
    std::cerr << "custom shard state is:\n";
    vm::load_cell_slice(cell).print_rec(std::cerr);
    std::cerr << "pretty-printed custom shard state is:\n";
    block::gen::t_ShardState.print_ref(std::cerr, cell);
  }
  stack.push_bool(block::gen::t_ShardState.validate_ref(std::move(cell)));
}

void interpret_is_workchain_descr(vm::Stack& stack) {
  Ref<vm::Cell> cell = stack.pop_cell();
  if (verbosity > 4) {
    std::cerr << "WorkchainDescr is:\n";
    vm::load_cell_slice(cell).print_rec(std::cerr);
    std::cerr << "pretty-printed WorkchainDescr is:\n";
    block::gen::t_WorkchainDescr.print_ref(std::cerr, cell);
  }
  stack.push_bool(block::gen::t_WorkchainDescr.validate_ref(std::move(cell)));
}

void interpret_add_extra_currencies(vm::Stack& stack) {
  Ref<vm::Cell> y = stack.pop_maybe_cell(), x = stack.pop_maybe_cell(), res;
  bool ok = block::add_extra_currency(std::move(x), std::move(y), res);
  if (ok) {
    stack.push_maybe_cell(std::move(res));
  }
  stack.push_bool(ok);
}

void interpret_sub_extra_currencies(vm::Stack& stack) {
  Ref<vm::Cell> y = stack.pop_maybe_cell(), x = stack.pop_maybe_cell(), res;
  bool ok = block::sub_extra_currency(std::move(x), std::move(y), res);
  if (ok) {
    stack.push_maybe_cell(std::move(res));
  }
  stack.push_bool(ok);
}

void interpret_mnemonic_to_privkey(vm::Stack& stack, int mode) {
  td::SecureString str{td::Slice{stack.pop_string()}};
  auto res = tonlib::Mnemonic::create(std::move(str), td::SecureString());
  if (res.is_error()) {
    throw fift::IntError{res.move_as_error().to_string()};
  }
  auto privkey = res.move_as_ok().to_private_key();
  td::SecureString key;
  if (mode & 1) {
    auto pub = privkey.get_public_key();
    key = pub.move_as_ok().as_octet_string();
  } else {
    key = privkey.as_octet_string();
  }
  stack.push_bytes(key.as_slice());
}

void init_words_custom(fift::Dictionary& d) {
  using namespace std::placeholders;
  d.def_stack_word("verb@ ", interpret_get_verbosity);
  d.def_stack_word("verb! ", interpret_set_verbosity);
  d.def_stack_word("wcid@ ", interpret_get_workchain);
  d.def_stack_word("wcid! ", interpret_set_workchain);
  d.def_stack_word("globalid@ ", interpret_get_global_id);
  d.def_stack_word("globalid! ", interpret_set_global_id);
  d.def_stack_word("config@ ", interpret_get_config_param);
  d.def_stack_word("config! ", interpret_set_config_param);
  d.def_stack_word("(configdict) ", interpret_get_config_dict);
  d.def_stack_word("register_smc ", interpret_register_smartcontract);
  d.def_stack_word("set_config_smc ", interpret_set_config_smartcontract);
  d.def_stack_word("create_state ", interpret_create_state);
  d.def_stack_word("isShardState? ", interpret_is_shard_state);
  d.def_stack_word("isWorkchainDescr? ", interpret_is_workchain_descr);
  d.def_stack_word("CC+? ", interpret_add_extra_currencies);
  d.def_stack_word("CC-? ", interpret_sub_extra_currencies);
  d.def_stack_word("mnemo>priv ", std::bind(interpret_mnemonic_to_privkey, _1, 0));
  d.def_stack_word("mnemo>pub ", std::bind(interpret_mnemonic_to_privkey, _1, 1));
}

tlb::TypenameLookup tlb_dict;

// ( S -- T -1 or 0 )  Looks up TLB type by name
void interpret_tlb_type_lookup(vm::Stack& stack) {
  auto ptr = tlb_dict.lookup(stack.pop_string());
  if (ptr) {
    stack.push_make_object<tlb::TlbTypeHolder>(ptr);
  }
  stack.push_bool(ptr);
}

td::Ref<tlb::TlbTypeHolder> pop_tlb_type(vm::Stack& stack) {
  auto res = stack.pop_object<tlb::TlbTypeHolder>();
  if (res.is_null()) {
    throw vm::VmError{vm::Excno::type_chk, "not a TLB type"};
  }
  return res;
}

// ( T -- S )  Gets TLB type name
void interpret_tlb_type_name(vm::Stack& stack) {
  stack.push_string((*pop_tlb_type(stack))->get_type_name());
}

// ( T -- )  Prints TLB type name
void interpret_print_tlb_type(vm::Stack& stack) {
  std::cout << (*pop_tlb_type(stack))->get_type_name();
}

// ( s T -- )  Dumps (part of) slice s as a value of TLB type T
void interpret_tlb_dump_as(vm::Stack& stack) {
  auto tp = pop_tlb_type(stack);
  (*tp)->print(std::cout, stack.pop_cellslice());
}

// ( s T -- s' S -1 or 0 )
// Detects prefix of slice s that is a value of TLB type T, returns the remainder as s', and prints the value into String S.
void interpret_tlb_dump_to_str(vm::Stack& stack) {
  auto tp = pop_tlb_type(stack);
  auto cs = stack.pop_cellslice();
  std::ostringstream os;
  bool ok = (*tp)->print_skip(os, cs.write());
  if (ok) {
    stack.push(std::move(cs));
    stack.push_string(os.str());
  }
  stack.push_bool(ok);
}

// ( s T -- s' -1 or 0 )   Skips the only prefix of slice s that can be a value of TLB type T
void interpret_tlb_skip(vm::Stack& stack) {
  auto tp = pop_tlb_type(stack);
  auto cs = stack.pop_cellslice();
  bool ok = (*tp)->skip(cs.write());
  if (ok) {
    stack.push(std::move(cs));
  }
  stack.push_bool(ok);
}

// ( s T -- s' -1 or 0 )  Checks whether a prefix of slice s is a valid value of TLB type T, and skips it
void interpret_tlb_validate_skip(vm::Stack& stack) {
  auto tp = pop_tlb_type(stack);
  auto cs = stack.pop_cellslice();
  bool ok = (*tp)->validate_skip_upto(1048576, cs.write());
  if (ok) {
    stack.push(std::move(cs));
  }
  stack.push_bool(ok);
}

void interpret_tlb_type_const(vm::Stack& stack, const tlb::TLB* ptr) {
  stack.push_make_object<tlb::TlbTypeHolder>(ptr);
}

void init_words_tlb(fift::Dictionary& d) {
  using namespace std::placeholders;
  tlb_dict.register_types(block::gen::register_simple_types);
  d.def_stack_word("tlb-type-lookup ", interpret_tlb_type_lookup);
  d.def_stack_word("tlb-type-name ", interpret_tlb_type_name);
  d.def_stack_word("tlb. ", interpret_print_tlb_type);
  d.def_stack_word("tlb-dump-as ", interpret_tlb_dump_as);
  d.def_stack_word("(tlb-dump-str?) ", interpret_tlb_dump_to_str);
  d.def_stack_word("tlb-skip ", interpret_tlb_skip);
  d.def_stack_word("tlb-validate-skip ", interpret_tlb_validate_skip);
  d.def_stack_word("ExtraCurrencyCollection",
                   std::bind(interpret_tlb_type_const, _1, &block::tlb::t_ExtraCurrencyCollection));
}

void usage(const char* progname) {
  std::cerr
      << "Creates initial state for a TON blockchain, using configuration defined by Fift-language source files\n";
  std::cerr
      << "usage: " << progname
      << " [-i] [-n] [-I <source-include-path>] {-L <library-fif-file>} <source-file1-fif> <source-file2-fif> ...\n";
  std::cerr << "\t-n\tDo not preload preamble files `Fift.fif` and `CreateState.fif`\n"
               "\t-i\tForce interactive mode even if explicit source file names are indicated\n"
               "\t-I<source-search-path>\tSets colon-separated library source include path. If not indicated, "
               "$FIFTPATH is used instead.\n"
               "\t-L<library-fif-file>\tPre-loads a library source file\n"
               "\t-v<verbosity-level>\tSet verbosity level\n";
  std::exit(2);
}

void parse_include_path_set(std::string include_path_set, std::vector<std::string>& res) {
  td::Parser parser(include_path_set);
  while (!parser.empty()) {
    auto path = parser.read_till_nofail(':');
    if (!path.empty()) {
      res.push_back(path.str());
    }
    parser.skip_nofail(':');
  }
}

void preload_preamble(fift::Fift& fift, std::string filename, bool standard = true) {
  auto status = fift.interpret_file(filename, "");
  if (status.is_error()) {
    LOG(ERROR) << "Error interpreting " << (standard ? "standard" : "application-specific") << " preamble file `"
               << filename << "`: " << status.error().message()
               << "\nCheck that correct include path is set by -I or by FIFTPATH environment variable, or disable "
                  "standard preamble by -n.\n";
    std::exit(2);
  }
}

int main(int argc, char* const argv[]) {
  td::set_default_failure_signal_handler().ensure();
  bool interactive = false;
  bool fift_preload = true, no_env = false, script_mode = false;
  std::vector<std::string> library_source_files, source_list;
  std::vector<std::string> source_include_path;
  std::string ton_db_path;

  fift::Fift::Config config;

  int i;
  int new_verbosity_level = VERBOSITY_NAME(INFO);
  while (!script_mode && (i = getopt(argc, argv, "hinsI:L:v:")) != -1) {
    switch (i) {
      case 'i':
        interactive = true;
        break;
      case 'n':
        fift_preload = false;
        break;
      case 'I':
        LOG(ERROR) << source_include_path;
        parse_include_path_set(optarg, source_include_path);
        no_env = true;
        break;
      case 's':
        script_mode = true;
        break;
      case 'L':
        library_source_files.emplace_back(optarg);
        break;
      case 'v':
        new_verbosity_level = VERBOSITY_NAME(FATAL) + (verbosity = td::to_integer<int>(td::Slice(optarg)));
        break;
      case 'h':
      default:
        usage(argv[0]);
    }
  }
  SET_VERBOSITY_LEVEL(new_verbosity_level);

  while (optind < argc) {
    source_list.emplace_back(argv[optind++]);
    if (script_mode) {
      break;
    }
  }

  if (!no_env) {
    const char* path = std::getenv("FIFTPATH");
    if (path) {
      parse_include_path_set(path ? path : "/usr/lib/fift", source_include_path);
    }
  }
  std::string current_dir;
  auto r_current_dir = td::realpath(".");
  if (r_current_dir.is_ok()) {
    current_dir = r_current_dir.move_as_ok();
    source_include_path.push_back(current_dir);
  }
  config.source_lookup = fift::SourceLookup(std::make_unique<fift::OsFileLoader>());
  for (auto& path : source_include_path) {
    config.source_lookup.add_include_path(path);
  }

  fift::init_words_common(config.dictionary);
  fift::init_words_vm(config.dictionary);
  fift::init_words_ton(config.dictionary);
  init_words_custom(config.dictionary);
  init_words_tlb(config.dictionary);

  if (script_mode) {
    fift::import_cmdline_args(config.dictionary, source_list.empty() ? "" : source_list[0], argc - optind,
                              argv + optind);
  }

  fift::Fift fift(std::move(config));

  if (fift_preload) {
    preload_preamble(fift, "Fift.fif", true);
    preload_preamble(fift, "CreateState.fif", false);
  }

  for (auto source : library_source_files) {
    auto status = fift.interpret_file(source, "");
    if (status.is_error()) {
      std::cerr << "Error interpreting preloaded file `" << source << "`: " << status.error().to_string() << std::endl;
      std::exit(2);
    }
  }

  if (source_list.empty() && !interactive) {
    std::cerr << "No Fift source files specified" << std::endl;
    std::exit(2);
  }

  for (const auto& source : source_list) {
    auto status = fift.interpret_file(source, current_dir);
    if (status.is_error()) {
      std::cerr << "Error interpreting file `" << source << "`: " << status.error().to_string() << std::endl;
      std::exit(2);
    }
  }

  if (interactive) {
    fift.interpret_istream(std::cin, current_dir).ensure();
  }
  // show_total_cells();
}
