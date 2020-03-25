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
#include "block/transaction.h"
#include "block/block.h"
#include "block/block-parse.h"
#include "block/block-auto.h"
#include "td/utils/bits.h"
#include "td/utils/uint128.h"
#include "ton/ton-shard.h"
#include "vm/vm.h"

namespace block {
using td::Ref;

Ref<vm::Cell> ComputePhaseConfig::lookup_library(td::ConstBitPtr key) const {
  return libraries ? vm::lookup_library_in(key, libraries->get_root_cell()) : Ref<vm::Cell>{};
}

/*
 * 
 *   ACCOUNTS
 * 
 */

bool Account::set_address(ton::WorkchainId wc, td::ConstBitPtr new_addr) {
  workchain = wc;
  addr = new_addr;
  return true;
}

bool Account::set_split_depth(int new_split_depth) {
  if (new_split_depth < 0 || new_split_depth > 30) {
    return false;  // invalid value for split_depth
  }
  if (split_depth_set_) {
    return split_depth_ == new_split_depth;
  } else {
    split_depth_ = (unsigned char)new_split_depth;
    split_depth_set_ = true;
    return true;
  }
}

bool Account::check_split_depth(int split_depth) const {
  return split_depth_set_ ? (split_depth == split_depth_) : (split_depth >= 0 && split_depth <= 30);
}

// initializes split_depth and addr_rewrite
bool Account::parse_maybe_anycast(vm::CellSlice& cs) {
  int t = (int)cs.fetch_ulong(1);
  if (t < 0) {
    return false;
  } else if (!t) {
    return set_split_depth(0);
  }
  int depth;
  return cs.fetch_uint_leq(30, depth)                     // anycast_info$_ depth:(#<= 30)
         && depth                                         // { depth >= 1 }
         && cs.fetch_bits_to(addr_rewrite.bits(), depth)  // rewrite_pfx:(bits depth)
         && set_split_depth(depth);
}

bool Account::store_maybe_anycast(vm::CellBuilder& cb) const {
  if (!split_depth_set_ || !split_depth_) {
    return cb.store_bool_bool(false);
  }
  return cb.store_bool_bool(true)                                    // just$1
         && cb.store_uint_leq(30, split_depth_)                      // depth:(#<= 30)
         && cb.store_bits_bool(addr_rewrite.cbits(), split_depth_);  // rewrite_pfx:(bits depth)
}

bool Account::unpack_address(vm::CellSlice& addr_cs) {
  int addr_tag = block::gen::t_MsgAddressInt.get_tag(addr_cs);
  int new_wc = ton::workchainInvalid;
  switch (addr_tag) {
    case block::gen::MsgAddressInt::addr_std:
      if (!(addr_cs.advance(2) && parse_maybe_anycast(addr_cs) && addr_cs.fetch_int_to(8, new_wc) &&
            addr_cs.fetch_bits_to(addr_orig.bits(), 256) && addr_cs.empty_ext())) {
        return false;
      }
      break;
    case block::gen::MsgAddressInt::addr_var:
      // cannot appear in masterchain / basechain
      return false;
    default:
      return false;
  }
  addr_cs.clear();
  if (new_wc == ton::workchainInvalid) {
    return false;
  }
  if (workchain == ton::workchainInvalid) {
    workchain = new_wc;
    addr = addr_orig;
    addr.bits().copy_from(addr_rewrite.cbits(), split_depth_);
  } else if (split_depth_) {
    ton::StdSmcAddress new_addr = addr_orig;
    new_addr.bits().copy_from(addr_rewrite.cbits(), split_depth_);
    if (new_addr != addr) {
      LOG(ERROR) << "error unpacking account " << workchain << ":" << addr.to_hex()
                 << " : account header contains different address " << new_addr.to_hex() << " (with splitting depth "
                 << (int)split_depth_ << ")";
      return false;
    }
  } else if (addr != addr_orig) {
    LOG(ERROR) << "error unpacking account " << workchain << ":" << addr.to_hex()
               << " : account header contains different address " << addr_orig.to_hex();
    return false;
  }
  if (workchain != new_wc) {
    LOG(ERROR) << "error unpacking account " << workchain << ":" << addr.to_hex()
               << " : account header contains different workchain " << new_wc;
    return false;
  }
  addr_rewrite = addr.bits();  // initialize all 32 bits of addr_rewrite
  if (!split_depth_) {
    my_addr_exact = my_addr;
  }
  return true;
}

bool Account::unpack_storage_info(vm::CellSlice& cs) {
  block::gen::StorageInfo::Record info;
  block::gen::StorageUsed::Record used;
  if (!tlb::unpack_exact(cs, info) || !tlb::csr_unpack(info.used, used)) {
    return false;
  }
  last_paid = info.last_paid;
  if (info.due_payment->prefetch_ulong(1) == 1) {
    vm::CellSlice& cs2 = info.due_payment.write();
    cs2.advance(1);
    due_payment = block::tlb::t_Grams.as_integer_skip(cs2);
    if (due_payment.is_null() || !cs2.empty_ext()) {
      return false;
    }
  } else {
    due_payment = td::zero_refint();
  }
  unsigned long long u = 0;
  u |= storage_stat.cells = block::tlb::t_VarUInteger_7.as_uint(*used.cells);
  u |= storage_stat.bits = block::tlb::t_VarUInteger_7.as_uint(*used.bits);
  u |= storage_stat.public_cells = block::tlb::t_VarUInteger_7.as_uint(*used.public_cells);
  LOG(DEBUG) << "last_paid=" << last_paid << "; cells=" << storage_stat.cells << " bits=" << storage_stat.bits
             << " public_cells=" << storage_stat.public_cells;
  return (u != std::numeric_limits<td::uint64>::max());
}

// initializes split_depth (from account state - StateInit)
bool Account::unpack_state(vm::CellSlice& cs) {
  block::gen::StateInit::Record state;
  if (!tlb::unpack_exact(cs, state)) {
    return false;
  }
  int sd = 0;
  if (state.split_depth->size() == 6) {
    sd = (int)state.split_depth->prefetch_ulong(6) - 32;
  }
  if (!set_split_depth(sd)) {
    return false;
  }
  if (state.special->size() > 1) {
    int z = (int)state.special->prefetch_ulong(3);
    if (z < 0) {
      return false;
    }
    tick = z & 2;
    tock = z & 1;
    LOG(DEBUG) << "tick=" << tick << ", tock=" << tock;
  }
  code = state.code->prefetch_ref();
  data = state.data->prefetch_ref();
  library = orig_library = state.library->prefetch_ref();
  return true;
}

bool Account::compute_my_addr(bool force) {
  if (!force && my_addr.not_null() && my_addr_exact.not_null()) {
    return true;
  }
  if (workchain == ton::workchainInvalid) {
    my_addr.clear();
    return false;
  }
  vm::CellBuilder cb;
  Ref<vm::Cell> cell, cell2;
  if (workchain >= -128 && workchain < 127) {
    if (!(cb.store_long_bool(2, 2)                             // addr_std$10
          && store_maybe_anycast(cb)                           // anycast:(Maybe Anycast)
          && cb.store_long_rchk_bool(workchain, 8)             // workchain_id:int8
          && cb.store_bits_bool(addr_orig)                     // addr:bits256
          && cb.finalize_to(cell) && cb.store_long_bool(4, 3)  // addr_std$10 anycast:(Maybe Anycast)
          && cb.store_long_rchk_bool(workchain, 8)             // workchain_id:int8
          && cb.store_bits_bool(addr)                          // addr:bits256
          && cb.finalize_to(cell2))) {
      return false;
    }
  } else {
    if (!(cb.store_long_bool(3, 2)                             // addr_var$11
          && store_maybe_anycast(cb)                           // anycast:(Maybe Anycast)
          && cb.store_long_bool(256, 9)                        // addr_len:(## 9)
          && cb.store_long_rchk_bool(workchain, 32)            // workchain_id:int32
          && cb.store_bits_bool(addr_orig)                     // addr:(bits addr_len)
          && cb.finalize_to(cell) && cb.store_long_bool(6, 3)  // addr_var$11 anycast:(Maybe Anycast)
          && cb.store_long_bool(256, 9)                        // addr_len:(## 9)
          && cb.store_long_rchk_bool(workchain, 32)            // workchain_id:int32
          && cb.store_bits_bool(addr)                          // addr:(bits addr_len)
          && cb.finalize_to(cell2))) {
      return false;
    }
  }
  my_addr = load_cell_slice_ref(std::move(cell));
  my_addr_exact = load_cell_slice_ref(std::move(cell2));
  return true;
}

bool Account::recompute_tmp_addr(Ref<vm::CellSlice>& tmp_addr, int split_depth,
                                 td::ConstBitPtr orig_addr_rewrite) const {
  if (!split_depth && my_addr_exact.not_null()) {
    tmp_addr = my_addr_exact;
    return true;
  }
  if (split_depth == split_depth_ && my_addr.not_null()) {
    tmp_addr = my_addr;
    return true;
  }
  if (split_depth < 0 || split_depth > 30) {
    return false;
  }
  vm::CellBuilder cb;
  bool std = (workchain >= -128 && workchain < 128);
  if (!cb.store_long_bool(std ? 2 : 3, 2)) {  // addr_std$10 or addr_var$11
    return false;
  }
  if (!split_depth) {
    if (!cb.store_bool_bool(false)) {  // anycast:(Maybe Anycast)
      return false;
    }
  } else if (!(cb.store_bool_bool(true)                             // just$1
               && cb.store_long_bool(split_depth, 5)                // depth:(#<= 30)
               && cb.store_bits_bool(addr.bits(), split_depth))) {  // rewrite_pfx:(bits depth)
    return false;
  }
  if (std) {
    if (!cb.store_long_rchk_bool(workchain, 8)) {  // workchain:int8
      return false;
    }
  } else if (!(cb.store_long_bool(256, 9)                // addr_len:(## 9)
               && cb.store_long_bool(workchain, 32))) {  // workchain:int32
    return false;
  }
  Ref<vm::Cell> cell;
  return cb.store_bits_bool(orig_addr_rewrite, split_depth)  // address:(bits addr_len) or bits256
         && cb.store_bits_bool(addr.bits() + split_depth, 256 - split_depth) && cb.finalize_to(cell) &&
         (tmp_addr = vm::load_cell_slice_ref(std::move(cell))).not_null();
}

bool Account::init_rewrite_addr(int split_depth, td::ConstBitPtr orig_addr_rewrite) {
  if (split_depth_set_ || !created || !set_split_depth(split_depth)) {
    return false;
  }
  addr_orig = addr;
  addr_rewrite = addr.bits();
  addr_orig.bits().copy_from(orig_addr_rewrite, split_depth);
  return compute_my_addr(true);
}

// used to unpack previously existing accounts
bool Account::unpack(Ref<vm::CellSlice> shard_account, Ref<vm::CellSlice> extra, ton::UnixTime now, bool special) {
  LOG(DEBUG) << "unpacking " << (special ? "special " : "") << "account " << addr.to_hex();
  if (shard_account.is_null()) {
    LOG(ERROR) << "account " << addr.to_hex() << " does not have a valid ShardAccount to unpack";
    return false;
  }
  if (verbosity > 2) {
    shard_account->print_rec(std::cerr, 2);
    block::gen::t_ShardAccount.print(std::cerr, *shard_account);
  }
  block::gen::ShardAccount::Record acc_info;
  if (!(block::gen::t_ShardAccount.validate_csr(shard_account) &&
        block::tlb::t_ShardAccount.validate_csr(shard_account) && tlb::unpack_exact(shard_account.write(), acc_info))) {
    LOG(ERROR) << "account " << addr.to_hex() << " state is invalid";
    return false;
  }
  last_trans_lt_ = acc_info.last_trans_lt;
  last_trans_hash_ = acc_info.last_trans_hash;
  now_ = now;
  auto account = std::move(acc_info.account);
  total_state = orig_total_state = account;
  auto acc_cs = load_cell_slice(std::move(account));
  if (block::gen::t_Account.get_tag(acc_cs) == block::gen::Account::account_none) {
    status = acc_nonexist;
    last_paid = 0;
    last_trans_end_lt_ = 0;
    is_special = special;
    if (workchain != ton::workchainInvalid) {
      addr_orig = addr;
      addr_rewrite = addr.cbits();
    }
    return compute_my_addr() && acc_cs.size_ext() == 1;
  }
  block::gen::Account::Record_account acc;
  block::gen::AccountStorage::Record storage;
  if (!(tlb::unpack_exact(acc_cs, acc) && (my_addr = acc.addr).not_null() && unpack_address(acc.addr.write()) &&
        compute_my_addr() && unpack_storage_info(acc.storage_stat.write()) &&
        tlb::csr_unpack(std::move(acc.storage), storage) &&
        std::max(storage.last_trans_lt, 1ULL) > acc_info.last_trans_lt && balance.unpack(std::move(storage.balance)))) {
    return false;
  }
  is_special = special;
  last_trans_end_lt_ = storage.last_trans_lt;
  switch (block::gen::t_AccountState.get_tag(*storage.state)) {
    case block::gen::AccountState::account_uninit:
      status = orig_status = acc_uninit;
      state_hash = addr;
      break;
    case block::gen::AccountState::account_frozen:
      status = orig_status = acc_frozen;
      if (!storage.state->have(2 + 256)) {
        return false;
      }
      state_hash = storage.state->data_bits() + 2;
      break;
    case block::gen::AccountState::account_active:
      status = orig_status = acc_active;
      if (storage.state.write().fetch_ulong(1) != 1) {
        return false;
      }
      inner_state = storage.state;
      if (!unpack_state(storage.state.write())) {
        return false;
      }
      state_hash.clear();
      break;
    default:
      return false;
  }
  LOG(DEBUG) << "end of Account.unpack() for " << workchain << ":" << addr.to_hex()
             << " (balance = " << balance.to_str() << " ; last_trans_lt = " << last_trans_lt_ << ".."
             << last_trans_end_lt_ << ")";
  return true;
}

// used to initialize new accounts
bool Account::init_new(ton::UnixTime now) {
  // only workchain and addr are initialized at this point
  if (workchain == ton::workchainInvalid) {
    return false;
  }
  addr_orig = addr;
  addr_rewrite = addr.cbits();
  last_trans_lt_ = last_trans_end_lt_ = 0;
  last_trans_hash_.set_zero();
  now_ = now;
  last_paid = 0;
  storage_stat.clear();
  due_payment = td::zero_refint();
  balance.set_zero();
  if (my_addr_exact.is_null()) {
    vm::CellBuilder cb;
    if (workchain >= -128 && workchain < 128) {
      CHECK(cb.store_long_bool(4, 3)                  // addr_std$10 anycast:(Maybe Anycast)
            && cb.store_long_rchk_bool(workchain, 8)  // workchain:int8
            && cb.store_bits_bool(addr));             // address:bits256
    } else {
      CHECK(cb.store_long_bool(0xd00, 12)              // addr_var$11 anycast:(Maybe Anycast) addr_len:(## 9)
            && cb.store_long_rchk_bool(workchain, 32)  // workchain:int32
            && cb.store_bits_bool(addr));              // address:(bits addr_len)
    }
    my_addr_exact = load_cell_slice_ref(cb.finalize());
  }
  if (my_addr.is_null()) {
    my_addr = my_addr_exact;
  }
  if (total_state.is_null()) {
    vm::CellBuilder cb;
    CHECK(cb.store_long_bool(0, 1)  // account_none$0 = Account
          && cb.finalize_to(total_state));
    orig_total_state = total_state;
  }
  state_hash = addr_orig;
  status = orig_status = acc_nonexist;
  created = true;
  return true;
}

bool Account::belongs_to_shard(ton::ShardIdFull shard) const {
  return workchain == shard.workchain && ton::shard_is_ancestor(shard.shard, addr);
}

void add_partial_storage_payment(td::BigInt256& payment, ton::UnixTime delta, const block::StoragePrices& prices,
                                 const vm::CellStorageStat& storage, bool is_mc) {
  td::BigInt256 c{(long long)storage.cells}, b{(long long)storage.bits};
  if (is_mc) {
    // storage.cells * prices.mc_cell_price + storage.bits * prices.mc_bit_price;
    c.mul_short(prices.mc_cell_price);
    b.mul_short(prices.mc_bit_price);
  } else {
    // storage.cells * prices.cell_price + storage.bits * prices.bit_price;
    c.mul_short(prices.cell_price);
    b.mul_short(prices.bit_price);
  }
  b += c;
  b.mul_short(delta);
  CHECK(b.sgn() >= 0);
  payment += b;
}

td::RefInt256 StoragePrices::compute_storage_fees(ton::UnixTime now, const std::vector<block::StoragePrices>& pricing,
                                                  const vm::CellStorageStat& storage_stat, ton::UnixTime last_paid,
                                                  bool is_special, bool is_masterchain) {
  if (now <= last_paid || !last_paid || is_special || pricing.empty() || now <= pricing[0].valid_since) {
    return {};
  }
  std::size_t n = pricing.size(), i = n;
  while (i && pricing[i - 1].valid_since > last_paid) {
    --i;
  }
  if (i) {
    --i;
  }
  ton::UnixTime upto = std::max(last_paid, pricing[0].valid_since);
  td::RefInt256 total{true, 0};
  for (; i < n && upto < now; i++) {
    ton::UnixTime valid_until = (i < n - 1 ? std::min(now, pricing[i + 1].valid_since) : now);
    if (upto < valid_until) {
      assert(upto >= pricing[i].valid_since);
      add_partial_storage_payment(total.unique_write(), valid_until - upto, pricing[i], storage_stat, is_masterchain);
    }
    upto = valid_until;
  }
  total.unique_write().rshift(16, 1);  // divide by 2^16 with ceil rounding to obtain nanograms
  return total;
}

td::RefInt256 Account::compute_storage_fees(ton::UnixTime now, const std::vector<block::StoragePrices>& pricing) const {
  return StoragePrices::compute_storage_fees(now, pricing, storage_stat, last_paid, is_special, is_masterchain());
}

Transaction::Transaction(const Account& _account, int ttype, ton::LogicalTime req_start_lt, ton::UnixTime _now,
                         Ref<vm::Cell> _inmsg)
    : trans_type(ttype)
    , is_first(_account.transactions.empty())
    , new_tick(_account.tick)
    , new_tock(_account.tock)
    , now(_now)
    , account(_account)
    , my_addr(_account.my_addr)
    , my_addr_exact(_account.my_addr_exact)
    , balance(_account.balance)
    , original_balance(_account.balance)
    , due_payment(_account.due_payment)
    , last_paid(_account.last_paid)
    , new_code(_account.code)
    , new_data(_account.data)
    , new_library(_account.library)
    , in_msg(std::move(_inmsg)) {
  start_lt = std::max(req_start_lt, account.last_trans_end_lt_);
  end_lt = start_lt + 1;
  acc_status = (account.status == Account::acc_nonexist ? Account::acc_uninit : account.status);
  if (acc_status == Account::acc_frozen) {
    frozen_hash = account.state_hash;
  }
}

bool Transaction::unpack_input_msg(bool ihr_delivered, const ActionPhaseConfig* cfg) {
  if (in_msg.is_null() || in_msg_type) {
    return false;
  }
  if (verbosity > 2) {
    fprintf(stderr, "unpacking inbound message for a new transaction: ");
    block::gen::t_Message_Any.print_ref(std::cerr, in_msg);
    load_cell_slice(in_msg).print_rec(std::cerr);
  }
  auto cs = vm::load_cell_slice(in_msg);
  int tag = block::gen::t_CommonMsgInfo.get_tag(cs);
  Ref<vm::CellSlice> src_addr, dest_addr;
  switch (tag) {
    case block::gen::CommonMsgInfo::int_msg_info: {
      block::gen::CommonMsgInfo::Record_int_msg_info info;
      if (!(tlb::unpack(cs, info) && msg_balance_remaining.unpack(std::move(info.value)))) {
        return false;
      }
      if (info.ihr_disabled && ihr_delivered) {
        return false;
      }
      bounce_enabled = info.bounce;
      src_addr = std::move(info.src);
      dest_addr = std::move(info.dest);
      in_msg_type = 1;
      td::RefInt256 ihr_fee = block::tlb::t_Grams.as_integer(std::move(info.ihr_fee));
      if (ihr_delivered) {
        in_fwd_fee = std::move(ihr_fee);
      } else {
        in_fwd_fee = td::zero_refint();
        msg_balance_remaining += std::move(ihr_fee);
      }
      if (info.created_lt >= start_lt) {
        start_lt = info.created_lt + 1;
        end_lt = start_lt + 1;
      }
      // ...
      break;
    }
    case block::gen::CommonMsgInfo::ext_in_msg_info: {
      block::gen::CommonMsgInfo::Record_ext_in_msg_info info;
      if (!tlb::unpack(cs, info)) {
        return false;
      }
      src_addr = std::move(info.src);
      dest_addr = std::move(info.dest);
      in_msg_type = 2;
      in_msg_extern = true;
      // compute forwarding fees for this external message
      vm::CellStorageStat sstat;       // for message size
      sstat.compute_used_storage(cs);  // message body
      sstat.bits -= cs.size();         // bits in the root cells are free
      sstat.cells--;                   // the root cell itself is not counted as a cell
      LOG(DEBUG) << "storage paid for a message: " << sstat.cells << " cells, " << sstat.bits << " bits";
      if (sstat.bits > max_msg_bits || sstat.cells > max_msg_cells) {
        LOG(DEBUG) << "inbound external message too large, invalid";
        return false;
      }
      // fetch message pricing info
      CHECK(cfg);
      const MsgPrices& msg_prices = cfg->fetch_msg_prices(account.is_masterchain());
      // compute forwarding fees
      auto fees_c = msg_prices.compute_fwd_ihr_fees(sstat.cells, sstat.bits, true);
      LOG(DEBUG) << "computed fwd fees = " << fees_c.first << " + " << fees_c.second;

      if (account.is_special) {
        LOG(DEBUG) << "computed fwd fees set to zero for special account";
        fees_c.first = fees_c.second = 0;
      }
      in_fwd_fee = td::make_refint(fees_c.first);
      if (balance.grams < in_fwd_fee) {
        LOG(DEBUG) << "cannot pay for importing this external message";
        return false;
      }
      // (tentatively) debit account for importing this external message
      balance -= in_fwd_fee;
      msg_balance_remaining.set_zero();  // external messages cannot carry value
      // ...
      break;
    }
    default:
      return false;
  }
  // init:(Maybe (Either StateInit ^StateInit))
  switch ((int)cs.prefetch_ulong(2)) {
    case 2: {  // (just$1 (left$0 _:StateInit ))
      Ref<vm::CellSlice> state_init;
      vm::CellBuilder cb;
      if (!(cs.advance(2) && block::gen::t_StateInit.fetch_to(cs, state_init) &&
            cb.append_cellslice_bool(std::move(state_init)) && cb.finalize_to(in_msg_state) &&
            block::gen::t_StateInit.validate_ref(in_msg_state))) {
        LOG(DEBUG) << "cannot parse StateInit in inbound message";
        return false;
      }
      break;
    }
    case 3: {  // (just$1 (right$1 _:^StateInit ))
      if (!(cs.advance(2) && cs.fetch_ref_to(in_msg_state) && block::gen::t_StateInit.validate_ref(in_msg_state))) {
        LOG(DEBUG) << "cannot parse ^StateInit in inbound message";
        return false;
      }
      break;
    }
    default:  // nothing$0
      if (!cs.advance(1)) {
        LOG(DEBUG) << "invalid init field in an inbound message";
        return false;
      }
  }
  // body:(Either X ^X)
  switch ((int)cs.fetch_ulong(1)) {
    case 0:  // left$0 _:X
      in_msg_body = Ref<vm::CellSlice>{true, cs};
      break;
    case 1:  // right$1 _:^X
      if (cs.size_ext() != 0x10000) {
        LOG(DEBUG) << "body of an inbound message is not represented by exactly one reference";
        return false;
      }
      in_msg_body = load_cell_slice_ref(cs.prefetch_ref());
      break;
    default:
      LOG(DEBUG) << "invalid body field in an inbound message";
      return false;
  }
  total_fees += in_fwd_fee;
  return true;
}

bool Transaction::prepare_storage_phase(const StoragePhaseConfig& cfg, bool force_collect) {
  if (now < account.last_paid) {
    return false;
  }
  auto to_pay = account.compute_storage_fees(now, *(cfg.pricing));
  if (to_pay.not_null() && sgn(to_pay) < 0) {
    return false;
  }
  auto res = std::make_unique<StoragePhase>();
  res->is_special = account.is_special;
  last_paid = res->last_paid_updated = (res->is_special ? 0 : now);
  if (to_pay.is_null() || sgn(to_pay) == 0) {
    res->fees_collected = res->fees_due = td::zero_refint();
  } else if (to_pay <= balance.grams) {
    res->fees_collected = to_pay;
    res->fees_due = td::zero_refint();
    balance -= std::move(to_pay);
  } else if (acc_status == Account::acc_frozen && !force_collect && to_pay + due_payment < cfg.delete_due_limit) {
    // do not collect fee
    res->last_paid_updated = (res->is_special ? 0 : account.last_paid);
    res->fees_collected = res->fees_due = td::zero_refint();
  } else {
    res->fees_collected = balance.grams;
    res->fees_due = std::move(to_pay) - std::move(balance.grams);
    balance.grams = td::zero_refint();
    if (!res->is_special) {
      auto total_due = res->fees_due + due_payment;
      switch (acc_status) {
        case Account::acc_uninit:
        case Account::acc_frozen:
          if (total_due > cfg.delete_due_limit) {
            res->deleted = true;
            acc_status = Account::acc_deleted;
            if (balance.extra.not_null()) {
              // collect extra currencies as a fee
              total_fees += block::CurrencyCollection{0, std::move(balance.extra)};
              balance.extra.clear();
            }
          }
          break;
        case Account::acc_active:
          if (total_due > cfg.freeze_due_limit) {
            res->frozen = true;
            was_frozen = true;
            acc_status = Account::acc_frozen;
          }
          break;
      }
    }
  }
  total_fees += res->fees_collected;
  storage_phase = std::move(res);
  return true;
}

bool Transaction::prepare_credit_phase() {
  credit_phase = std::make_unique<CreditPhase>();
  auto collected = std::min(msg_balance_remaining.grams, due_payment);
  credit_phase->due_fees_collected = collected;
  due_payment -= collected;
  credit_phase->credit = msg_balance_remaining -= collected;
  if (!msg_balance_remaining.is_valid()) {
    LOG(ERROR) << "cannot compute the amount to be credited in the credit phase of transaction";
    return false;
  }
  // NB: msg_balance_remaining may be deducted from balance later during bounce phase
  balance += msg_balance_remaining;
  if (!balance.is_valid()) {
    LOG(ERROR) << "cannot credit currency collection to account";
    return false;
  }
  total_fees += std::move(collected);
  return true;
}

bool ComputePhaseConfig::parse_GasLimitsPrices(Ref<vm::Cell> cell, td::RefInt256& freeze_due_limit,
                                               td::RefInt256& delete_due_limit) {
  return cell.not_null() &&
         parse_GasLimitsPrices(vm::load_cell_slice_ref(std::move(cell)), freeze_due_limit, delete_due_limit);
}

bool ComputePhaseConfig::parse_GasLimitsPrices(Ref<vm::CellSlice> cs, td::RefInt256& freeze_due_limit,
                                               td::RefInt256& delete_due_limit) {
  if (cs.is_null()) {
    return false;
  }
  block::gen::GasLimitsPrices::Record_gas_flat_pfx flat;
  if (tlb::csr_unpack(cs, flat)) {
    return parse_GasLimitsPrices_internal(std::move(flat.other), freeze_due_limit, delete_due_limit,
                                          flat.flat_gas_limit, flat.flat_gas_price);
  } else {
    return parse_GasLimitsPrices_internal(std::move(cs), freeze_due_limit, delete_due_limit);
  }
}

bool ComputePhaseConfig::parse_GasLimitsPrices_internal(Ref<vm::CellSlice> cs, td::RefInt256& freeze_due_limit,
                                                        td::RefInt256& delete_due_limit, td::uint64 _flat_gas_limit,
                                                        td::uint64 _flat_gas_price) {
  auto f = [&](const auto& r, td::uint64 spec_limit) {
    gas_limit = r.gas_limit;
    special_gas_limit = spec_limit;
    gas_credit = r.gas_credit;
    gas_price = r.gas_price;
    freeze_due_limit = td::make_refint(r.freeze_due_limit);
    delete_due_limit = td::make_refint(r.delete_due_limit);
  };
  block::gen::GasLimitsPrices::Record_gas_prices_ext rec;
  if (tlb::csr_unpack(cs, rec)) {
    f(rec, rec.special_gas_limit);
  } else {
    block::gen::GasLimitsPrices::Record_gas_prices rec0;
    if (tlb::csr_unpack(std::move(cs), rec0)) {
      f(rec0, rec0.gas_limit);
    } else {
      return false;
    }
  }
  flat_gas_limit = _flat_gas_limit;
  flat_gas_price = _flat_gas_price;
  compute_threshold();
  return true;
}

void ComputePhaseConfig::compute_threshold() {
  gas_price256 = td::make_refint(gas_price);
  if (gas_limit > flat_gas_limit) {
    max_gas_threshold =
        td::rshift(gas_price256 * (gas_limit - flat_gas_limit), 16, 1) + td::make_bigint(flat_gas_price);
  } else {
    max_gas_threshold = td::make_refint(flat_gas_price);
  }
}

td::uint64 ComputePhaseConfig::gas_bought_for(td::RefInt256 nanograms) const {
  if (nanograms.is_null() || sgn(nanograms) < 0) {
    return 0;
  }
  if (nanograms >= max_gas_threshold) {
    return gas_limit;
  }
  if (nanograms < flat_gas_price) {
    return 0;
  }
  auto res = td::div((std::move(nanograms) - flat_gas_price) << 16, gas_price256);
  return res->to_long() + flat_gas_limit;
}

td::RefInt256 ComputePhaseConfig::compute_gas_price(td::uint64 gas_used) const {
  return gas_used <= flat_gas_limit ? td::make_refint(flat_gas_price)
                                    : td::rshift(gas_price256 * (gas_used - flat_gas_limit), 16, 1) + flat_gas_price;
}

bool Transaction::compute_gas_limits(ComputePhase& cp, const ComputePhaseConfig& cfg) {
  // Compute gas limits
  if (account.is_special) {
    cp.gas_max = cfg.special_gas_limit;
  } else {
    cp.gas_max = cfg.gas_bought_for(balance.grams);
  }
  cp.gas_credit = 0;
  if (trans_type != tr_ord) {
    // may use all gas that can be bought using remaining balance
    cp.gas_limit = cp.gas_max;
  } else {
    // originally use only gas bought using remaining message balance
    // if the message is "accepted" by the smart contract, the gas limit will be set to gas_max
    cp.gas_limit = cfg.gas_bought_for(msg_balance_remaining.grams);
    if (!block::tlb::t_Message.is_internal(in_msg)) {
      // external messages carry no balance, give them some credit to check whether they are accepted
      cp.gas_credit = std::min(cfg.gas_credit, cp.gas_max);
    }
  }
  LOG(DEBUG) << "gas limits: max=" << cp.gas_max << ", limit=" << cp.gas_limit << ", credit=" << cp.gas_credit;
  return true;
}

Ref<vm::Stack> Transaction::prepare_vm_stack(ComputePhase& cp) {
  Ref<vm::Stack> stack_ref{true};
  td::RefInt256 acc_addr{true};
  CHECK(acc_addr.write().import_bits(account.addr.cbits(), 256));
  vm::Stack& stack = stack_ref.write();
  switch (trans_type) {
    case tr_tick:
    case tr_tock:
      stack.push_int(balance.grams);
      stack.push_int(std::move(acc_addr));
      stack.push_bool(trans_type == tr_tock);
      stack.push_smallint(-2);
      return stack_ref;
    case tr_ord:
      stack.push_int(balance.grams);
      stack.push_int(msg_balance_remaining.grams);
      stack.push_cell(in_msg);
      stack.push_cellslice(in_msg_body);
      stack.push_bool(in_msg_extern);
      return stack_ref;
    default:
      LOG(ERROR) << "cannot initialize stack for a transaction of type " << trans_type;
      return {};
  }
}

bool Transaction::prepare_rand_seed(td::BitArray<256>& rand_seed, const ComputePhaseConfig& cfg) const {
  // we might use SHA256(block_rand_seed . addr . trans_lt)
  // instead, we use SHA256(block_rand_seed . addr)
  // if the smart contract wants to randomize further, it can use RANDOMIZE instruction
  td::BitArray<256 + 256> data;
  data.bits().copy_from(cfg.block_rand_seed.cbits(), 256);
  (data.bits() + 256).copy_from(account.addr_rewrite.cbits(), 256);
  rand_seed.clear();
  data.compute_sha256(rand_seed);
  return true;
}

Ref<vm::Tuple> Transaction::prepare_vm_c7(const ComputePhaseConfig& cfg) const {
  td::BitArray<256> rand_seed;
  td::RefInt256 rand_seed_int{true};
  if (!(prepare_rand_seed(rand_seed, cfg) && rand_seed_int.unique_write().import_bits(rand_seed.cbits(), 256, false))) {
    LOG(ERROR) << "cannot compute rand_seed for transaction";
    throw CollatorError{"cannot generate valid SmartContractInfo"};
    return {};
  }
  auto tuple = vm::make_tuple_ref(
      td::make_refint(0x076ef1ea),                // [ magic:0x076ef1ea
      td::zero_refint(),                          //   actions:Integer
      td::zero_refint(),                          //   msgs_sent:Integer
      td::make_refint(now),                       //   unixtime:Integer
      td::make_refint(account.block_lt),          //   block_lt:Integer
      td::make_refint(start_lt),                  //   trans_lt:Integer
      std::move(rand_seed_int),                   //   rand_seed:Integer
      balance.as_vm_tuple(),                      //   balance_remaining:[Integer (Maybe Cell)]
      my_addr,                                    //  myself:MsgAddressInt
      vm::StackEntry::maybe(cfg.global_config));  //  global_config:(Maybe Cell) ] = SmartContractInfo;
  LOG(DEBUG) << "SmartContractInfo initialized with " << vm::StackEntry(tuple).to_string();
  return vm::make_tuple_ref(std::move(tuple));
}

int output_actions_count(Ref<vm::Cell> list) {
  int i = -1;
  do {
    ++i;
    list = load_cell_slice(std::move(list)).prefetch_ref();
  } while (list.not_null());
  return i;
}

bool Transaction::unpack_msg_state(bool lib_only) {
  block::gen::StateInit::Record state;
  if (in_msg_state.is_null() || !tlb::unpack_cell(in_msg_state, state)) {
    LOG(ERROR) << "cannot unpack StateInit from an inbound message";
    return false;
  }
  if (lib_only) {
    in_msg_library = state.library->prefetch_ref();
    return true;
  }
  if (state.split_depth->size() == 6) {
    new_split_depth = (signed char)(state.split_depth->prefetch_ulong(6) - 32);
  } else {
    new_split_depth = 0;
  }
  if (state.special->size() > 1) {
    int z = (int)state.special->prefetch_ulong(3);
    if (z < 0) {
      return false;
    }
    new_tick = z & 2;
    new_tock = z & 1;
    LOG(DEBUG) << "tick=" << new_tick << ", tock=" << new_tock;
  }
  new_code = state.code->prefetch_ref();
  new_data = state.data->prefetch_ref();
  new_library = state.library->prefetch_ref();
  return true;
}

std::vector<Ref<vm::Cell>> Transaction::compute_vm_libraries(const ComputePhaseConfig& cfg) {
  std::vector<Ref<vm::Cell>> lib_set;
  if (in_msg_library.not_null()) {
    lib_set.push_back(in_msg_library);
  }
  if (new_library.not_null()) {
    lib_set.push_back(new_library);
  }
  auto global_libs = cfg.get_lib_root();
  if (global_libs.not_null()) {
    lib_set.push_back(std::move(global_libs));
  }
  return lib_set;
}

bool Transaction::check_in_msg_state_hash() {
  CHECK(in_msg_state.not_null());
  CHECK(new_split_depth >= 0 && new_split_depth < 32);
  td::Bits256 in_state_hash = in_msg_state->get_hash().bits();
  int d = new_split_depth;
  if ((in_state_hash.bits() + d).compare(account.addr.bits() + d, 256 - d)) {
    return false;
  }
  orig_addr_rewrite = in_state_hash.bits();
  orig_addr_rewrite_set = true;
  return account.recompute_tmp_addr(my_addr, d, orig_addr_rewrite.bits());
}

bool Transaction::prepare_compute_phase(const ComputePhaseConfig& cfg) {
  // TODO: add more skip verifications + sometimes use state from in_msg to re-activate
  // ...
  compute_phase = std::make_unique<ComputePhase>();
  ComputePhase& cp = *(compute_phase.get());
  original_balance -= total_fees;
  if (td::sgn(balance.grams) <= 0) {
    // no gas
    cp.skip_reason = ComputePhase::sk_no_gas;
    return true;
  }
  // Compute gas limits
  if (!compute_gas_limits(cp, cfg)) {
    compute_phase.reset();
    return false;
  }
  if (!cp.gas_limit && !cp.gas_credit) {
    // no gas
    cp.skip_reason = ComputePhase::sk_no_gas;
    return true;
  }
  if (in_msg_state.not_null()) {
    LOG(DEBUG) << "HASH(in_msg_state) = " << in_msg_state->get_hash().bits().to_hex(256)
               << ", account_state_hash = " << account.state_hash.to_hex();
    // vm::load_cell_slice(in_msg_state).print_rec(std::cerr);
  } else {
    LOG(DEBUG) << "in_msg_state is null";
  }
  if (in_msg_state.not_null() &&
      (acc_status == Account::acc_uninit ||
       (acc_status == Account::acc_frozen && account.state_hash == in_msg_state->get_hash().bits()))) {
    use_msg_state = true;
    if (!(unpack_msg_state() && account.check_split_depth(new_split_depth))) {
      LOG(DEBUG) << "cannot unpack in_msg_state, or it has bad split_depth; cannot init account state";
      cp.skip_reason = ComputePhase::sk_bad_state;
      return true;
    }
    if (acc_status == Account::acc_uninit && !check_in_msg_state_hash()) {
      LOG(DEBUG) << "in_msg_state hash mismatch, cannot init account state";
      cp.skip_reason = ComputePhase::sk_bad_state;
      return true;
    }
  } else if (acc_status != Account::acc_active) {
    // no state, cannot perform transactions
    cp.skip_reason = in_msg_state.not_null() ? ComputePhase::sk_bad_state : ComputePhase::sk_no_state;
    return true;
  } else if (in_msg_state.not_null()) {
    unpack_msg_state(true);  // use only libraries
  }
  // initialize VM
  Ref<vm::Stack> stack = prepare_vm_stack(cp);
  if (stack.is_null()) {
    compute_phase.reset();
    return false;
  }
  // OstreamLogger ostream_logger(error_stream);
  // auto log = create_vm_log(error_stream ? &ostream_logger : nullptr);
  vm::GasLimits gas{(long long)cp.gas_limit, (long long)cp.gas_max, (long long)cp.gas_credit};
  LOG(DEBUG) << "creating VM";

  vm::VmState vm{new_code, std::move(stack), gas, 1, new_data, vm::VmLog(), compute_vm_libraries(cfg)};
  vm.set_c7(prepare_vm_c7(cfg));  // tuple with SmartContractInfo
  // vm.incr_stack_trace(1);    // enable stack dump after each step

  LOG(DEBUG) << "starting VM";
  cp.vm_init_state_hash = vm.get_state_hash();
  cp.exit_code = ~vm.run();
  LOG(DEBUG) << "VM terminated with exit code " << cp.exit_code;
  cp.out_of_gas = (cp.exit_code == ~(int)vm::Excno::out_of_gas);
  cp.vm_final_state_hash = vm.get_final_state_hash(cp.exit_code);
  stack = vm.get_stack_ref();
  cp.vm_steps = (int)vm.get_steps_count();
  gas = vm.get_gas_limits();
  cp.gas_used = std::min<long long>(gas.gas_consumed(), gas.gas_limit);
  cp.accepted = (gas.gas_credit == 0);
  cp.success = (cp.accepted && vm.committed());
  if (cp.accepted & use_msg_state) {
    was_activated = true;
    acc_status = Account::acc_active;
  }
  LOG(INFO) << "steps: " << vm.get_steps_count() << " gas: used=" << gas.gas_consumed() << ", max=" << gas.gas_max
            << ", limit=" << gas.gas_limit << ", credit=" << gas.gas_credit;
  LOG(INFO) << "out_of_gas=" << cp.out_of_gas << ", accepted=" << cp.accepted << ", success=" << cp.success;
  if (cp.success) {
    cp.new_data = vm.get_committed_state().c4;  // c4 -> persistent data
    cp.actions = vm.get_committed_state().c5;   // c5 -> action list
    int out_act_num = output_actions_count(cp.actions);
    if (verbosity > 2) {
      std::cerr << "new smart contract data: ";
      load_cell_slice(cp.new_data).print_rec(std::cerr);
      std::cerr << "output actions: ";
      block::gen::OutList{out_act_num}.print_ref(std::cerr, cp.actions);
    }
  }
  cp.mode = 0;
  cp.exit_arg = 0;
  if (!cp.success && stack->depth() > 0) {
    td::RefInt256 tos = stack->tos().as_int();
    if (tos.not_null() && tos->signed_fits_bits(32)) {
      cp.exit_arg = (int)tos->to_long();
    }
  }
  if (cp.accepted) {
    if (account.is_special) {
      cp.gas_fees = td::zero_refint();
    } else {
      cp.gas_fees = cfg.compute_gas_price(cp.gas_used);
      total_fees += cp.gas_fees;
      balance -= cp.gas_fees;
    }
    LOG(DEBUG) << "gas fees: " << cp.gas_fees->to_dec_string() << " = " << cfg.gas_price256->to_dec_string() << " * "
               << cp.gas_used << " /2^16 ; price=" << cfg.gas_price << "; flat rate=[" << cfg.flat_gas_price << " for "
               << cfg.flat_gas_limit << "]; remaining balance=" << balance.to_str();
    CHECK(td::sgn(balance.grams) >= 0);
  }
  return true;
}

bool Transaction::prepare_action_phase(const ActionPhaseConfig& cfg) {
  if (!compute_phase || !compute_phase->success) {
    return false;
  }
  action_phase = std::make_unique<ActionPhase>();
  ActionPhase& ap = *(action_phase.get());
  ap.result_code = -1;
  ap.result_arg = 0;
  ap.tot_actions = ap.spec_actions = ap.skipped_actions = ap.msgs_created = 0;
  Ref<vm::Cell> list = compute_phase->actions;
  assert(list.not_null());
  ap.action_list_hash = list->get_hash().bits();
  ap.remaining_balance = balance;
  ap.end_lt = end_lt;
  ap.total_fwd_fees = td::zero_refint();
  ap.total_action_fees = td::zero_refint();
  ap.reserved_balance.set_zero();

  int n = 0;
  while (true) {
    ap.action_list.push_back(list);
    auto cs = load_cell_slice(std::move(list));
    if (!cs.size_ext()) {
      break;
    }
    if (!cs.have_refs()) {
      ap.result_code = 32;  // action list invalid
      ap.result_arg = n;
      ap.action_list_invalid = true;
      LOG(DEBUG) << "action list invalid: entry found with data but no next reference";
      return true;
    }
    list = cs.prefetch_ref();
    n++;
    if (n > cfg.max_actions) {
      ap.result_code = 33;  // too many actions
      ap.result_arg = n;
      ap.action_list_invalid = true;
      LOG(DEBUG) << "action list too long: more than " << cfg.max_actions << " actions";
      return true;
    }
  }

  ap.tot_actions = n;
  ap.spec_actions = ap.skipped_actions = 0;
  for (int i = n - 1; i >= 0; --i) {
    ap.result_arg = n - 1 - i;
    if (!block::gen::t_OutListNode.validate_ref(ap.action_list[i])) {
      ap.result_code = 34;  // action #i invalid or unsupported
      ap.action_list_invalid = true;
      LOG(DEBUG) << "invalid action " << ap.result_arg << " found while preprocessing action list: error code "
                 << ap.result_code;
      return true;
    }
  }
  ap.valid = true;
  for (int i = n - 1; i >= 0; --i) {
    ap.result_arg = n - 1 - i;
    vm::CellSlice cs = load_cell_slice(ap.action_list[i]);
    CHECK(cs.fetch_ref().not_null());
    int tag = block::gen::t_OutAction.get_tag(cs);
    CHECK(tag >= 0);
    int err_code = 34;
    switch (tag) {
      case block::gen::OutAction::action_set_code:
        err_code = try_action_set_code(cs, ap, cfg);
        break;
      case block::gen::OutAction::action_send_msg:
        err_code = try_action_send_msg(cs, ap, cfg);
        if (err_code == -2) {
          err_code = try_action_send_msg(cs, ap, cfg, 1);
          if (err_code == -2) {
            err_code = try_action_send_msg(cs, ap, cfg, 2);
          }
        }
        break;
      case block::gen::OutAction::action_reserve_currency:
        err_code = try_action_reserve_currency(cs, ap, cfg);
        break;
      case block::gen::OutAction::action_change_library:
        err_code = try_action_change_library(cs, ap, cfg);
        break;
    }
    if (err_code) {
      ap.result_code = (err_code == -1 ? 34 : err_code);
      ap.end_lt = end_lt;
      if (err_code == -1 || err_code == 34) {
        ap.action_list_invalid = true;
      }
      if (err_code == 37 || err_code == 38) {
        ap.no_funds = true;
      }
      LOG(DEBUG) << "invalid action " << ap.result_arg << " in action list: error code " << ap.result_code;
      return true;
    }
  }
  ap.result_arg = 0;
  ap.result_code = 0;
  CHECK(ap.remaining_balance.grams->sgn() >= 0);
  CHECK(ap.reserved_balance.grams->sgn() >= 0);
  ap.remaining_balance += ap.reserved_balance;
  CHECK(ap.remaining_balance.is_valid());
  if (ap.acc_delete_req) {
    CHECK(ap.remaining_balance.is_zero());
    ap.acc_status_change = ActionPhase::acst_deleted;
    acc_status = Account::acc_deleted;
    was_deleted = true;
  }
  ap.success = true;
  end_lt = ap.end_lt;
  out_msgs = std::move(ap.out_msgs);
  if (ap.new_code.not_null()) {
    new_code = ap.new_code;
  }
  new_data = compute_phase->new_data;  // tentative persistent data update applied
  total_fees +=
      ap.total_action_fees;  // NB: forwarding fees are not accounted here (they are not collected by the validators in this transaction)
  balance = ap.remaining_balance;
  return true;
}

int Transaction::try_action_set_code(vm::CellSlice& cs, ActionPhase& ap, const ActionPhaseConfig& cfg) {
  block::gen::OutAction::Record_action_set_code rec;
  if (!tlb::unpack_exact(cs, rec)) {
    return -1;
  }
  ap.new_code = std::move(rec.new_code);
  ap.code_changed = true;
  ap.spec_actions++;
  return 0;
}

int Transaction::try_action_change_library(vm::CellSlice& cs, ActionPhase& ap, const ActionPhaseConfig& cfg) {
  block::gen::OutAction::Record_action_change_library rec;
  if (!tlb::unpack_exact(cs, rec)) {
    return -1;
  }
  // mode: +0 = remove library, +1 = add private library, +2 = add public library
  Ref<vm::Cell> lib_ref = rec.libref->prefetch_ref();
  ton::Bits256 hash;
  if (lib_ref.not_null()) {
    hash = lib_ref->get_hash().bits();
  } else {
    CHECK(rec.libref.write().fetch_ulong(1) == 0 && rec.libref.write().fetch_bits_to(hash));
  }
  try {
    vm::Dictionary dict{new_library, 256};
    if (!rec.mode) {
      // remove library
      dict.lookup_delete(hash);
      LOG(DEBUG) << "removed " << ((rec.mode >> 1) ? "public" : "private") << " library with hash " << hash.to_hex();
    } else {
      auto val = dict.lookup(hash);
      if (val.not_null()) {
        bool is_public = val->prefetch_ulong(1);
        auto ref = val->prefetch_ref();
        if (hash == ref->get_hash().bits()) {
          lib_ref = ref;
          if (is_public == (rec.mode >> 1)) {
            // library already in required state
            ap.spec_actions++;
            return 0;
          }
        }
      }
      if (lib_ref.is_null()) {
        // library code not found
        return 41;
      }
      vm::CellBuilder cb;
      CHECK(cb.store_bool_bool(rec.mode >> 1) && cb.store_ref_bool(std::move(lib_ref)));
      CHECK(dict.set_builder(hash, cb));
      LOG(DEBUG) << "added " << ((rec.mode >> 1) ? "public" : "private") << " library with hash " << hash.to_hex();
    }
    new_library = std::move(dict).extract_root_cell();
  } catch (vm::VmError& vme) {
    return 42;
  }
  ap.spec_actions++;
  return 0;
}

// msg_fwd_fees = (lump_price + ceil((bit_price * msg.bits + cell_price * msg.cells)/2^16)) nanograms
// ihr_fwd_fees = ceil((msg_fwd_fees * ihr_price_factor)/2^16) nanograms
// bits in the root cell of a message are not included in msg.bits (lump_price pays for them)
td::uint64 MsgPrices::compute_fwd_fees(td::uint64 cells, td::uint64 bits) const {
  return lump_price + td::uint128(bit_price)
                          .mult(bits)
                          .add(td::uint128(cell_price).mult(cells))
                          .add(td::uint128(0xffffu))
                          .shr(16)
                          .lo();
}

std::pair<td::uint64, td::uint64> MsgPrices::compute_fwd_ihr_fees(td::uint64 cells, td::uint64 bits,
                                                                  bool ihr_disabled) const {
  td::uint64 fwd = compute_fwd_fees(cells, bits);
  if (ihr_disabled) {
    return std::pair<td::uint64, td::uint64>(fwd, 0);
  }
  return std::pair<td::uint64, td::uint64>(fwd, td::uint128(fwd).mult(ihr_factor).shr(16).lo());
}

td::RefInt256 MsgPrices::get_first_part(td::RefInt256 total) const {
  return (std::move(total) * first_frac) >> 16;
}

td::uint64 MsgPrices::get_first_part(td::uint64 total) const {
  return td::uint128(total).mult(first_frac).shr(16).lo();
}

td::RefInt256 MsgPrices::get_next_part(td::RefInt256 total) const {
  return (std::move(total) * next_frac) >> 16;
}

bool Transaction::check_replace_src_addr(Ref<vm::CellSlice>& src_addr) const {
  int t = (int)src_addr->prefetch_ulong(2);
  if (!t && src_addr->size_ext() == 2) {
    // addr_none$00  --> replace with the address of current smart contract
    src_addr = my_addr;
    return true;
  }
  if (t != 2) {
    // invalid address (addr_extern and addr_var cannot be source addresses)
    return false;
  }
  if (src_addr->contents_equal(*my_addr) || src_addr->contents_equal(*my_addr_exact)) {
    // source address matches that of the current account
    return true;
  }
  // only one valid case remaining: rewritten source address used, replace with the complete one
  // (are we sure we want to allow this?)
  return false;
}

bool Transaction::check_rewrite_dest_addr(Ref<vm::CellSlice>& dest_addr, const ActionPhaseConfig& cfg,
                                          bool* is_mc) const {
  if (!dest_addr->prefetch_ulong(1)) {
    // all external addresses allowed
    if (is_mc) {
      *is_mc = false;
    }
    return true;
  }
  bool repack = false;
  int tag = block::gen::t_MsgAddressInt.get_tag(*dest_addr);

  block::gen::MsgAddressInt::Record_addr_var rec;

  if (tag == block::gen::MsgAddressInt::addr_var) {
    if (!tlb::csr_unpack(dest_addr, rec)) {
      // cannot unpack addr_var
      LOG(DEBUG) << "cannot unpack addr_var in a destination address";
      return false;
    }
    if (rec.addr_len == 256 && rec.workchain_id >= -128 && rec.workchain_id < 128) {
      LOG(DEBUG) << "destination address contains an addr_var to be repacked into addr_std";
      repack = true;
    }
  } else if (tag == block::gen::MsgAddressInt::addr_std) {
    block::gen::MsgAddressInt::Record_addr_std recs;
    if (!tlb::csr_unpack(dest_addr, recs)) {
      // cannot unpack addr_std
      LOG(DEBUG) << "cannot unpack addr_std in a destination address";
      return false;
    }
    rec.anycast = std::move(recs.anycast);
    rec.addr_len = 256;
    rec.workchain_id = recs.workchain_id;
    rec.address = td::make_bitstring_ref(recs.address);
  } else {
    // unknown address format (not a MsgAddressInt)
    LOG(DEBUG) << "destination address does not have a MsgAddressInt tag";
    return false;
  }
  if (rec.workchain_id != ton::masterchainId) {
    // recover destination workchain info from configuration
    auto it = cfg.workchains->find(rec.workchain_id);
    if (it == cfg.workchains->end()) {
      // undefined destination workchain
      LOG(DEBUG) << "destination address contains unknown workchain_id " << rec.workchain_id;
      return false;
    }
    if (!it->second->accept_msgs) {
      // workchain does not accept new messages
      LOG(DEBUG) << "destination address belongs to workchain " << rec.workchain_id << " not accepting new messages";
      return false;
    }
    if (!it->second->is_valid_addr_len(rec.addr_len)) {
      // invalid address length for specified workchain
      LOG(DEBUG) << "destination address has length " << rec.addr_len << " invalid for destination workchain "
                 << rec.workchain_id;
      return false;
    }
  }
  if (rec.anycast->size() > 1) {
    // destination address is an anycast
    if (rec.workchain_id == ton::masterchainId) {
      // anycast addresses disabled in masterchain
      LOG(DEBUG) << "masterchain destination address has an anycast field";
      return false;
    }
    vm::CellSlice cs{*rec.anycast};
    int d = (int)cs.fetch_ulong(6) - 32;
    if (d <= 0 || d > 30) {
      // invalid anycast prefix length
      return false;
    }
    unsigned pfx = (unsigned)cs.fetch_ulong(d);
    unsigned my_pfx = (unsigned)account.addr.cbits().get_uint(d);
    if (pfx != my_pfx) {
      // rewrite destination address
      vm::CellBuilder cb;
      CHECK(cb.store_long_bool(32 + d, 6)     // just$1 depth:(#<= 30)
            && cb.store_long_bool(my_pfx, d)  // rewrite_pfx:(bits depth)
            && (rec.anycast = load_cell_slice_ref(cb.finalize())).not_null());
      repack = true;
    }
  }
  if (is_mc) {
    *is_mc = (rec.workchain_id == ton::masterchainId);
  }
  if (!repack) {
    return true;
  }
  if (rec.addr_len == 256 && rec.workchain_id >= -128 && rec.workchain_id < 128) {
    // repack as an addr_std
    vm::CellBuilder cb;
    CHECK(cb.store_long_bool(2, 2)                             // addr_std$10
          && cb.append_cellslice_bool(std::move(rec.anycast))  // anycast:(Maybe Anycast) ...
          && cb.store_long_bool(rec.workchain_id, 8)           // workchain_id:int8
          && cb.append_bitstring(std::move(rec.address))       // address:bits256
          && (dest_addr = load_cell_slice_ref(cb.finalize())).not_null());
  } else {
    // repack as an addr_var
    CHECK(tlb::csr_pack(dest_addr, std::move(rec)));
  }
  CHECK(block::gen::t_MsgAddressInt.validate_csr(dest_addr));
  return true;
}

int Transaction::try_action_send_msg(const vm::CellSlice& cs0, ActionPhase& ap, const ActionPhaseConfig& cfg,
                                     int redoing) {
  block::gen::OutAction::Record_action_send_msg act_rec;
  // mode: +128 = attach all remaining balance, +64 = attach all remaining balance of the inbound message, +32 = delete smart contract if balance becomes zero, +1 = pay message fees, +2 = skip if message cannot be sent
  vm::CellSlice cs{cs0};
  if (!tlb::unpack_exact(cs, act_rec) || (act_rec.mode & ~0xe3) || (act_rec.mode & 0xc0) == 0xc0) {
    return -1;
  }
  bool skip_invalid = (act_rec.mode & 2);
  // try to parse suggested message in act_rec.out_msg
  td::RefInt256 fwd_fee, ihr_fee;
  block::gen::MessageRelaxed::Record msg;
  if (!tlb::type_unpack_cell(act_rec.out_msg, block::gen::t_MessageRelaxed_Any, msg)) {
    return -1;
  }
  if (redoing >= 1) {
    if (msg.init->size_refs() >= 2) {
      LOG(DEBUG) << "moving the StateInit of a suggested outbound message into a separate cell";
      // init:(Maybe (Either StateInit ^StateInit))
      // transform (just (left z:StateInit)) into (just (right z:^StateInit))
      CHECK(msg.init.write().fetch_ulong(2) == 2);
      vm::CellBuilder cb;
      Ref<vm::Cell> cell;
      CHECK(cb.append_cellslice_bool(std::move(msg.init))  // StateInit
            && cb.finalize_to(cell)                        // -> ^StateInit
            && cb.store_long_bool(3, 2)                    // (just (right ... ))
            && cb.store_ref_bool(std::move(cell))          // z:^StateInit
            && cb.finalize_to(cell));
      msg.init = vm::load_cell_slice_ref(std::move(cell));
    } else {
      redoing = 2;
    }
  }
  if (redoing >= 2 && msg.body->size_ext() > 1 && msg.body->prefetch_ulong(1) == 0) {
    LOG(DEBUG) << "moving the body of a suggested outbound message into a separate cell";
    // body:(Either X ^X)
    // transform (left x:X) into (right x:^X)
    CHECK(msg.body.write().fetch_ulong(1) == 0);
    vm::CellBuilder cb;
    Ref<vm::Cell> cell;
    CHECK(cb.append_cellslice_bool(std::move(msg.body))  // X
          && cb.finalize_to(cell)                        // -> ^X
          && cb.store_long_bool(1, 1)                    // (right ... )
          && cb.store_ref_bool(std::move(cell))          // x:^X
          && cb.finalize_to(cell));
    msg.body = vm::load_cell_slice_ref(std::move(cell));
  }

  block::gen::CommonMsgInfoRelaxed::Record_int_msg_info info;
  bool ext_msg = msg.info->prefetch_ulong(1);
  if (ext_msg) {
    // ext_out_msg_info$11 constructor of CommonMsgInfoRelaxed
    block::gen::CommonMsgInfoRelaxed::Record_ext_out_msg_info erec;
    if (!tlb::csr_unpack(msg.info, erec)) {
      return -1;
    }
    info.src = std::move(erec.src);
    info.dest = std::move(erec.dest);
    // created_lt and created_at are ignored
    info.ihr_disabled = true;
    info.bounce = false;
    info.bounced = false;
    fwd_fee = ihr_fee = td::zero_refint();
  } else {
    // int_msg_info$0 constructor
    if (!tlb::csr_unpack(msg.info, info) || !block::tlb::t_CurrencyCollection.validate_csr(info.value)) {
      return -1;
    }
    fwd_fee = block::tlb::t_Grams.as_integer(info.fwd_fee);
    ihr_fee = block::tlb::t_Grams.as_integer(info.ihr_fee);
  }
  // set created_at and created_lt to correct values
  info.created_at = now;
  info.created_lt = ap.end_lt;
  // always clear bounced flag
  info.bounced = false;
  // have to check source address
  // it must be either our source address, or empty
  if (!check_replace_src_addr(info.src)) {
    LOG(DEBUG) << "invalid source address in a proposed outbound message";
    return 35;  // invalid source address
  }
  bool to_mc = false;
  if (!check_rewrite_dest_addr(info.dest, cfg, &to_mc)) {
    LOG(DEBUG) << "invalid destination address in a proposed outbound message";
    return skip_invalid ? 0 : 36;  // invalid destination address
  }

  // fetch message pricing info
  const MsgPrices& msg_prices = cfg.fetch_msg_prices(to_mc || account.is_masterchain());
  // compute size of message
  vm::CellStorageStat sstat;  // for message size
  // preliminary storage estimation of the resulting message
  sstat.add_used_storage(msg.init, true, 3);  // message init
  sstat.add_used_storage(msg.body, true, 3);  // message body (the root cell itself is not counted)
  if (!ext_msg) {
    sstat.add_used_storage(info.value->prefetch_ref());
  }
  LOG(DEBUG) << "storage paid for a message: " << sstat.cells << " cells, " << sstat.bits << " bits";
  if (sstat.bits > max_msg_bits || sstat.cells > max_msg_cells) {
    LOG(DEBUG) << "message too large, invalid";
    return skip_invalid ? 0 : 40;
  }

  // compute forwarding fees
  auto fees_c = msg_prices.compute_fwd_ihr_fees(sstat.cells, sstat.bits, info.ihr_disabled);
  LOG(DEBUG) << "computed fwd fees = " << fees_c.first << " + " << fees_c.second;

  if (account.is_special) {
    LOG(DEBUG) << "computed fwd fees set to zero for special account";
    fees_c.first = fees_c.second = 0;
  }

  // set fees to computed values
  if (fwd_fee->unsigned_fits_bits(63) && fwd_fee->to_long() < (long long)fees_c.first) {
    fwd_fee = td::make_refint(fees_c.first);
  }
  if (fees_c.second && ihr_fee->unsigned_fits_bits(63) && ihr_fee->to_long() < (long long)fees_c.second) {
    ihr_fee = td::make_refint(fees_c.second);
  }

  Ref<vm::Cell> new_msg;
  td::RefInt256 fees_collected, fees_total;
  unsigned new_msg_bits;

  if (!ext_msg) {
    // Process outbound internal message
    // check value, check/compute ihr_fees, fwd_fees
    // ...
    if (!block::tlb::t_CurrencyCollection.validate_csr(info.value)) {
      LOG(DEBUG) << "invalid value:CurrencyCollection in proposed outbound message";
      return skip_invalid ? 0 : 37;
    }
    if (info.ihr_disabled) {
      // if IHR is disabled, IHR fees will be always zero
      ihr_fee = td::zero_refint();
    }
    // extract value to be carried by the message
    block::CurrencyCollection req;
    CHECK(req.unpack(info.value));
    CHECK(req.grams.not_null());

    if (act_rec.mode & 0x80) {
      // attach all remaining balance to this message
      req = ap.remaining_balance;
      act_rec.mode &= ~1;  // pay fees from attached value
    } else if (act_rec.mode & 0x40) {
      // attach all remaining balance of the inbound message (in addition to the original value)
      req += msg_balance_remaining;
      if (!(act_rec.mode & 1) && compute_phase) {
        req -= compute_phase->gas_fees;
        if (!req.is_valid()) {
          LOG(DEBUG)
              << "not enough value to transfer with the message: all of the inbound message value has been consumed";
          return skip_invalid ? 0 : 37;
        }
      }
    }

    // compute req_grams + fees
    td::RefInt256 req_grams_brutto = req.grams;
    fees_total = fwd_fee + ihr_fee;
    if (act_rec.mode & 1) {
      // we are going to pay the fees
      req_grams_brutto += fees_total;
    } else if (req.grams < fees_total) {
      // receiver pays the fees (but cannot)
      LOG(DEBUG) << "not enough value attached to the message to pay forwarding fees : have " << req.grams << ", need "
                 << fees_total;
      return skip_invalid ? 0 : 37;  // not enough grams
    } else {
      // decrease message value
      req.grams -= fees_total;
    }

    // check that we have at least the required value
    if (ap.remaining_balance.grams < req_grams_brutto) {
      LOG(DEBUG) << "not enough grams to transfer with the message : remaining balance is "
                 << ap.remaining_balance.to_str() << ", need " << req_grams_brutto << " (including forwarding fees)";
      return skip_invalid ? 0 : 37;  // not enough grams
    }

    Ref<vm::Cell> new_extra;

    if (!block::sub_extra_currency(ap.remaining_balance.extra, req.extra, new_extra)) {
      LOG(DEBUG) << "not enough extra currency to send with the message: "
                 << block::CurrencyCollection{0, req.extra}.to_str() << " required, only "
                 << block::CurrencyCollection{0, ap.remaining_balance.extra}.to_str() << " available";
      return skip_invalid ? 0 : 38;  // not enough (extra) funds
    }
    if (ap.remaining_balance.extra.not_null() || req.extra.not_null()) {
      LOG(DEBUG) << "subtracting extra currencies: "
                 << block::CurrencyCollection{0, ap.remaining_balance.extra}.to_str() << " minus "
                 << block::CurrencyCollection{0, req.extra}.to_str() << " equals "
                 << block::CurrencyCollection{0, new_extra}.to_str();
    }

    auto fwd_fee_mine = msg_prices.get_first_part(fwd_fee);
    auto fwd_fee_remain = fwd_fee - fwd_fee_mine;

    // re-pack message value
    CHECK(req.pack_to(info.value));
    CHECK(block::tlb::t_Grams.pack_integer(info.fwd_fee, fwd_fee_remain));
    CHECK(block::tlb::t_Grams.pack_integer(info.ihr_fee, ihr_fee));

    // serialize message
    CHECK(tlb::csr_pack(msg.info, info));
    vm::CellBuilder cb;
    if (!tlb::type_pack(cb, block::gen::t_MessageRelaxed_Any, msg)) {
      LOG(DEBUG) << "outbound message does not fit into a cell after rewriting";
      return redoing < 2 ? -2 : (skip_invalid ? 0 : 39);
    }

    new_msg_bits = cb.size();
    new_msg = cb.finalize();

    // clear msg_balance_remaining if it has been used
    if (act_rec.mode & 0xc0) {
      msg_balance_remaining.set_zero();
    }

    // update balance
    ap.remaining_balance -= req_grams_brutto;
    ap.remaining_balance.extra = std::move(new_extra);
    CHECK(ap.remaining_balance.is_valid());
    CHECK(ap.remaining_balance.grams->sgn() >= 0);
    fees_total = fwd_fee + ihr_fee;
    fees_collected = fwd_fee_mine;
  } else {
    // external messages also have forwarding fees
    if (ap.remaining_balance.grams < fwd_fee) {
      LOG(DEBUG) << "not enough funds to pay for an outbound external message";
      return skip_invalid ? 0 : 37;  // not enough grams
    }
    // repack message
    // ext_out_msg_info$11 constructor of CommonMsgInfo
    block::gen::CommonMsgInfo::Record_ext_out_msg_info erec;
    erec.src = info.src;
    erec.dest = info.dest;
    erec.created_at = info.created_at;
    erec.created_lt = info.created_lt;
    CHECK(tlb::csr_pack(msg.info, erec));
    vm::CellBuilder cb;
    if (!tlb::type_pack(cb, block::gen::t_MessageRelaxed_Any, msg)) {
      LOG(DEBUG) << "outbound message does not fit into a cell after rewriting";
      return redoing < 2 ? -2 : (skip_invalid ? 0 : 39);
    }

    new_msg_bits = cb.size();
    new_msg = cb.finalize();

    // update balance
    ap.remaining_balance -= fwd_fee;
    CHECK(ap.remaining_balance.is_valid());
    CHECK(td::sgn(ap.remaining_balance.grams) >= 0);
    fees_collected = fees_total = fwd_fee;
  }

  if (!block::tlb::t_Message.validate_ref(new_msg)) {
    LOG(ERROR) << "generated outbound message is not a valid (Message Any) according to hand-written check";
    return -1;
  }
  if (!block::gen::t_Message_Any.validate_ref(new_msg)) {
    LOG(ERROR) << "generated outbound message is not a valid (Message Any) according to automated check";
    block::gen::t_Message_Any.print_ref(std::cerr, new_msg);
    vm::load_cell_slice(new_msg).print_rec(std::cerr);
    return -1;
  }
  if (verbosity > 2) {
    std::cerr << "converted outbound message: ";
    block::gen::t_Message_Any.print_ref(std::cerr, new_msg);
  }

  ap.msgs_created++;
  ap.end_lt++;

  ap.out_msgs.push_back(std::move(new_msg));
  ap.total_action_fees += fees_collected;
  ap.total_fwd_fees += fees_total;

  if ((act_rec.mode & 0xa0) == 0xa0) {
    CHECK(ap.remaining_balance.is_zero());
    ap.acc_delete_req = ap.reserved_balance.is_zero();
  }

  ap.tot_msg_bits += sstat.bits + new_msg_bits;
  ap.tot_msg_cells += sstat.cells + 1;

  return 0;
}

int Transaction::try_action_reserve_currency(vm::CellSlice& cs, ActionPhase& ap, const ActionPhaseConfig& cfg) {
  block::gen::OutAction::Record_action_reserve_currency rec;
  if (!tlb::unpack_exact(cs, rec) || (rec.mode & ~15)) {
    return -1;
  }
  int mode = rec.mode;
  LOG(INFO) << "in try_action_reserve_currency(" << mode << ")";
  CurrencyCollection reserve, newc;
  if (!reserve.validate_unpack(std::move(rec.currency))) {
    LOG(DEBUG) << "cannot parse currency field in action_reserve_currency";
    return -1;
  }
  LOG(DEBUG) << "action_reserve_currency: mode=" << mode << ", reserve=" << reserve.to_str()
             << ", balance=" << ap.remaining_balance.to_str() << ", original balance=" << original_balance.to_str();
  if (mode & 4) {
    if (mode & 8) {
      reserve = original_balance - reserve;
    } else {
      reserve += original_balance;
    }
  } else if (mode & 8) {
    LOG(DEBUG) << "invalid reserve mode " << mode;
    return -1;
  }
  if (!reserve.is_valid() || td::sgn(reserve.grams) < 0) {
    LOG(DEBUG) << "cannot reserve a negative amount: " << reserve.to_str();
    return -1;
  }
  if (reserve.grams > ap.remaining_balance.grams) {
    if (mode & 2) {
      reserve.grams = ap.remaining_balance.grams;
    } else {
      LOG(DEBUG) << "cannot reserve " << reserve.grams << " nanograms : only " << ap.remaining_balance.grams
                 << " available";
      return 37;  // not enough grams
    }
  }
  if (!block::sub_extra_currency(ap.remaining_balance.extra, reserve.extra, newc.extra)) {
    LOG(DEBUG) << "not enough extra currency to reserve: " << block::CurrencyCollection{0, reserve.extra}.to_str()
               << " required, only " << block::CurrencyCollection{0, ap.remaining_balance.extra}.to_str()
               << " available";
    if (mode & 2) {
      // TODO: process (mode & 2) correctly by setting res_extra := inf (reserve.extra, ap.remaining_balance.extra)
    }
    return 38;  // not enough (extra) funds
  }
  newc.grams = ap.remaining_balance.grams - reserve.grams;
  if (mode & 1) {
    // leave only res_grams, reserve everything else
    std::swap(newc, reserve);
  }
  // set remaining_balance to new_grams and new_extra
  ap.remaining_balance = std::move(newc);
  // increase reserved_balance by res_grams and res_extra
  ap.reserved_balance += std::move(reserve);
  CHECK(ap.reserved_balance.is_valid());
  CHECK(ap.remaining_balance.is_valid());
  LOG(INFO) << "changed remaining balance to " << ap.remaining_balance.to_str() << ", reserved balance to "
            << ap.reserved_balance.to_str();
  ap.spec_actions++;
  return 0;
}

bool Transaction::prepare_bounce_phase(const ActionPhaseConfig& cfg) {
  if (in_msg.is_null() || !bounce_enabled) {
    return false;
  }
  bounce_phase = std::make_unique<BouncePhase>();
  BouncePhase& bp = *bounce_phase;
  block::gen::Message::Record msg;
  block::gen::CommonMsgInfo::Record_int_msg_info info;
  auto cs = vm::load_cell_slice(in_msg);
  if (!(tlb::unpack(cs, info) && gen::t_Maybe_Either_StateInit_Ref_StateInit.skip(cs) && cs.have(1) &&
        cs.have_refs((int)cs.prefetch_ulong(1)))) {
    bounce_phase.reset();
    return false;
  }
  if (cs.fetch_ulong(1)) {
    cs = vm::load_cell_slice(cs.prefetch_ref());
  }
  info.ihr_disabled = true;
  info.bounce = false;
  info.bounced = true;
  std::swap(info.src, info.dest);
  bool to_mc = false;
  if (!check_rewrite_dest_addr(info.dest, cfg, &to_mc)) {
    LOG(DEBUG) << "invalid destination address in a bounced message";
    bounce_phase.reset();
    return false;
  }
  // fetch message pricing info
  const MsgPrices& msg_prices = cfg.fetch_msg_prices(to_mc || account.is_masterchain());
  // compute size of message
  vm::CellStorageStat sstat;  // for message size
  // preliminary storage estimation of the resulting message
  sstat.compute_used_storage(info.value->prefetch_ref());
  bp.msg_bits = sstat.bits;
  bp.msg_cells = sstat.cells;
  // compute forwarding fees
  bp.fwd_fees = msg_prices.compute_fwd_fees(sstat.cells, sstat.bits);
  // check whether the message has enough funds
  auto msg_balance = msg_balance_remaining;
  if (compute_phase && compute_phase->gas_fees.not_null()) {
    msg_balance.grams -= compute_phase->gas_fees;
  }
  if ((msg_balance.grams < 0) ||
      (msg_balance.grams->signed_fits_bits(64) && msg_balance.grams->to_long() < (long long)bp.fwd_fees)) {
    // not enough funds
    bp.nofunds = true;
    return true;
  }
  // debit msg_balance_remaining from account's (tentative) balance
  balance -= msg_balance;
  CHECK(balance.is_valid());
  // debit total forwarding fees from the message's balance, then split forwarding fees into our part and remaining part
  msg_balance -= td::make_refint(bp.fwd_fees);
  bp.fwd_fees_collected = msg_prices.get_first_part(bp.fwd_fees);
  bp.fwd_fees -= bp.fwd_fees_collected;
  total_fees += td::make_refint(bp.fwd_fees_collected);
  // serialize outbound message
  info.created_lt = end_lt++;
  info.created_at = now;
  vm::CellBuilder cb;
  CHECK(cb.store_long_bool(5, 4)                            // int_msg_info$0 ihr_disabled:Bool bounce:Bool bounced:Bool
        && cb.append_cellslice_bool(info.src)               // src:MsgAddressInt
        && cb.append_cellslice_bool(info.dest)              // dest:MsgAddressInt
        && msg_balance.store(cb)                            // value:CurrencyCollection
        && block::tlb::t_Grams.store_long(cb, 0)            // ihr_fee:Grams
        && block::tlb::t_Grams.store_long(cb, bp.fwd_fees)  // fwd_fee:Grams
        && cb.store_long_bool(info.created_lt, 64)          // created_lt:uint64
        && cb.store_long_bool(info.created_at, 32)          // created_at:uint32
        && cb.store_bool_bool(false));                      // init:(Maybe ...)
  if (cfg.bounce_msg_body) {
    int body_bits = std::min((int)cs.size(), cfg.bounce_msg_body);
    if (cb.remaining_bits() >= body_bits + 33u) {
      CHECK(cb.store_bool_bool(false)                             // body:(Either X ^X) -> left X
            && cb.store_long_bool(-1, 32)                         // int = -1 ("message type")
            && cb.append_bitslice(cs.prefetch_bits(body_bits)));  // truncated message body
    } else {
      vm::CellBuilder cb2;
      CHECK(cb.store_bool_bool(true)                             // body:(Either X ^X) -> right ^X
            && cb2.store_long_bool(-1, 32)                       // int = -1 ("message type")
            && cb2.append_bitslice(cs.prefetch_bits(body_bits))  // truncated message body
            && cb.store_builder_ref_bool(std::move(cb2)));       // ^X
    }
  } else {
    CHECK(cb.store_bool_bool(false));  // body:(Either ..)
  }
  CHECK(cb.finalize_to(bp.out_msg));
  if (verbosity > 2) {
    LOG(INFO) << "generated bounced message: ";
    block::gen::t_Message_Any.print_ref(std::cerr, bp.out_msg);
  }
  out_msgs.push_back(bp.out_msg);
  bp.ok = true;
  return true;
}

/*
 * 
 *  SERIALIZE PREPARED TRANSACTION
 * 
 */

bool Account::store_acc_status(vm::CellBuilder& cb, int acc_status) const {
  int v;
  switch (acc_status) {
    case acc_nonexist:
    case acc_deleted:
      v = 3;  // acc_state_nonexist$11
      break;
    case acc_uninit:
      v = 0;  // acc_state_uninit$00
      break;
    case acc_frozen:
      v = 1;  // acc_state_frozen$01
      break;
    case acc_active:
      v = 2;  // acc_state_active$10
      break;
    default:
      return false;
  }
  return cb.store_long_bool(v, 2);
}

bool Transaction::compute_state() {
  if (new_total_state.not_null()) {
    return true;
  }
  if (acc_status == Account::acc_uninit && !was_activated && balance.is_zero()) {
    LOG(DEBUG) << "account is uninitialized and has zero balance, deleting it back";
    acc_status = Account::acc_nonexist;
    was_created = false;
  }
  if (acc_status == Account::acc_nonexist || acc_status == Account::acc_deleted) {
    CHECK(balance.is_zero());
    vm::CellBuilder cb;
    CHECK(cb.store_long_bool(0, 1)  // account_none$0
          && cb.finalize_to(new_total_state));
    return true;
  }
  vm::CellBuilder cb;
  CHECK(cb.store_long_bool(end_lt, 64)  // account_storage$_ last_trans_lt:uint64
        && balance.store(cb));          // balance:CurrencyCollection
  int ticktock = new_tick * 2 + new_tock;
  unsigned si_pos = 0;
  if (acc_status == Account::acc_uninit) {
    CHECK(cb.store_long_bool(0, 2));  // account_uninit$00 = AccountState
  } else if (acc_status == Account::acc_frozen) {
    if (was_frozen) {
      vm::CellBuilder cb2;
      CHECK(account.split_depth_ ? cb2.store_long_bool(account.split_depth_ + 32, 6)  // _ ... = StateInit
                                 : cb2.store_long_bool(0, 1));                        // ... split_depth:(Maybe (## 5))
      CHECK(ticktock ? cb2.store_long_bool(ticktock | 4, 3) : cb2.store_long_bool(0, 1));  // special:(Maybe TickTock)
      CHECK(cb2.store_maybe_ref(new_code) && cb2.store_maybe_ref(new_data) && cb2.store_maybe_ref(new_library));
      // code:(Maybe ^Cell) data:(Maybe ^Cell) library:(HashmapE 256 SimpleLib)
      auto frozen_state = cb2.finalize();
      frozen_hash = frozen_state->get_hash().bits();
      if (verbosity >= 3 * 1) {  // !!!DEBUG!!!
        std::cerr << "freezing state of smart contract: ";
        block::gen::t_StateInit.print_ref(std::cerr, frozen_state);
        CHECK(block::gen::t_StateInit.validate_ref(frozen_state));
        CHECK(block::tlb::t_StateInit.validate_ref(frozen_state));
        std::cerr << "with hash " << frozen_hash.to_hex() << std::endl;
      }
    }
    new_code.clear();
    new_data.clear();
    new_library.clear();
    if (frozen_hash == account.addr_orig) {
      // if frozen_hash equals account's "original" address (before rewriting), do not need storing hash
      CHECK(cb.store_long_bool(0, 2));  // account_uninit$00 = AccountState
    } else {
      CHECK(cb.store_long_bool(1, 2)              // account_frozen$01
            && cb.store_bits_bool(frozen_hash));  // state_hash:bits256
    }
  } else {
    CHECK(acc_status == Account::acc_active && !was_frozen && !was_deleted);
    si_pos = cb.size_ext() + 1;
    CHECK(account.split_depth_ ? cb.store_long_bool(account.split_depth_ + 96, 7)      // account_active$1 _:StateInit
                               : cb.store_long_bool(2, 2));                            // ... split_depth:(Maybe (## 5))
    CHECK(ticktock ? cb.store_long_bool(ticktock | 4, 3) : cb.store_long_bool(0, 1));  // special:(Maybe TickTock)
    CHECK(cb.store_maybe_ref(new_code) && cb.store_maybe_ref(new_data) && cb.store_maybe_ref(new_library));
    // code:(Maybe ^Cell) data:(Maybe ^Cell) library:(HashmapE 256 SimpleLib)
  }
  auto storage = cb.finalize();
  if (si_pos) {
    auto cs_ref = load_cell_slice_ref(storage);
    CHECK(cs_ref.unique_write().skip_ext(si_pos));
    new_inner_state = std::move(cs_ref);
  } else {
    new_inner_state.clear();
  }
  vm::CellStorageStat& stats = new_storage_stat;
  CHECK(stats.compute_used_storage(Ref<vm::Cell>(storage)));
  CHECK(cb.store_long_bool(1, 1)                       // account$1
        && cb.append_cellslice_bool(account.my_addr)   // addr:MsgAddressInt
        && block::store_UInt7(cb, stats.cells)         // storage_used$_ cells:(VarUInteger 7)
        && block::store_UInt7(cb, stats.bits)          //   bits:(VarUInteger 7)
        && block::store_UInt7(cb, stats.public_cells)  //   public_cells:(VarUInteger 7)
        && cb.store_long_bool(last_paid, 32));         // last_paid:uint32
  if (due_payment.not_null() && td::sgn(due_payment) != 0) {
    CHECK(cb.store_long_bool(1, 1) && block::tlb::t_Grams.store_integer_ref(cb, due_payment));
    // due_payment:(Maybe Grams)
  } else {
    CHECK(cb.store_long_bool(0, 1));
  }
  CHECK(cb.append_data_cell_bool(std::move(storage)));
  new_total_state = cb.finalize();
  if (verbosity > 2) {
    std::cerr << "new account state: ";
    block::gen::t_Account.print_ref(std::cerr, new_total_state);
  }
  CHECK(block::gen::t_Account.validate_ref(new_total_state));
  CHECK(block::tlb::t_Account.validate_ref(new_total_state));
  return true;
}

bool Transaction::serialize() {
  if (root.not_null()) {
    return true;
  }
  if (!compute_state()) {
    return false;
  }
  vm::Dictionary dict{15};
  for (unsigned i = 0; i < out_msgs.size(); i++) {
    td::BitArray<15> key{i};
    if (!dict.set_ref(key, out_msgs[i], vm::Dictionary::SetMode::Add)) {
      return false;
    }
  }
  vm::CellBuilder cb, cb2;
  if (!(cb.store_long_bool(7, 4)                                             // transaction$0111
        && cb.store_bits_bool(account.addr)                                  // account_addr:bits256
        && cb.store_long_bool(start_lt)                                      // lt:uint64
        && cb.store_bits_bool(account.last_trans_hash_)                      // prev_trans_hash:bits256
        && cb.store_long_bool(account.last_trans_lt_, 64)                    // prev_trans_lt:uint64
        && cb.store_long_bool(account.now_, 32)                              // now:uint32
        && cb.store_ulong_rchk_bool(out_msgs.size(), 15)                     // outmsg_cnt:uint15
        && account.store_acc_status(cb)                                      // orig_status:AccountStatus
        && account.store_acc_status(cb, acc_status)                          // end_status:AccountStatus
        && cb2.store_maybe_ref(in_msg)                                       // ^[ in_msg:(Maybe ^(Message Any)) ...
        && std::move(dict).append_dict_to_bool(cb2)                          //    out_msgs:(HashmapE 15 ^(Message Any))
        && cb.store_ref_bool(cb2.finalize())                                 // ]
        && total_fees.store(cb)                                              // total_fees:CurrencyCollection
        && cb2.store_long_bool(0x72, 8)                                      //   update_hashes#72
        && cb2.store_bits_bool(account.total_state->get_hash().bits(), 256)  //   old_hash:bits256
        && cb2.store_bits_bool(new_total_state->get_hash().bits(), 256)      //   new_hash:bits256
        && cb.store_ref_bool(cb2.finalize()))) {                             // state_update:^(HASH_UPDATE Account)
    return false;
  }

  switch (trans_type) {
    case tr_tick:  // fallthrough
    case tr_tock: {
      vm::CellBuilder cb3;
      bool act = compute_phase->success;
      bool act_ok = act && action_phase->success;
      CHECK(cb2.store_long_bool(trans_type == tr_tick ? 2 : 3, 4)  // trans_tick_tock$000 is_tock:Bool
            && serialize_storage_phase(cb2)                        // storage:TrStoragePhase
            && serialize_compute_phase(cb2)                        // compute_ph:TrComputePhase
            && cb2.store_bool_bool(act)                            // action:(Maybe
            && (!act || (serialize_action_phase(cb3)               //   ^TrActionPhase)
                         && cb2.store_ref_bool(cb3.finalize()))) &&
            cb2.store_bool_bool(!act_ok)         // aborted:Bool
            && cb2.store_bool_bool(was_deleted)  // destroyed:Bool
            && cb.store_ref_bool(cb2.finalize()) && cb.finalize_to(root));
      break;
    }
    case tr_ord: {
      vm::CellBuilder cb3;
      bool have_storage = (bool)storage_phase;
      bool have_credit = (bool)credit_phase;
      bool have_bounce = (bool)bounce_phase;
      bool act = compute_phase->success;
      bool act_ok = act && action_phase->success;
      CHECK(cb2.store_long_bool(0, 4)                           // trans_ord$0000
            && cb2.store_long_bool(!bounce_enabled, 1)          // credit_first:Bool
            && cb2.store_bool_bool(have_storage)                // storage_ph:(Maybe
            && (!have_storage || serialize_storage_phase(cb2))  //   TrStoragePhase)
            && cb2.store_bool_bool(have_credit)                 // credit_ph:(Maybe
            && (!have_credit || serialize_credit_phase(cb2))    //   TrCreditPhase)
            && serialize_compute_phase(cb2)                     // compute_ph:TrComputePhase
            && cb2.store_bool_bool(act)                         // action:(Maybe
            && (!act || (serialize_action_phase(cb3) && cb2.store_ref_bool(cb3.finalize())))  //   ^TrActionPhase)
            && cb2.store_bool_bool(!act_ok)                                                   // aborted:Bool
            && cb2.store_bool_bool(have_bounce)                                               // bounce:(Maybe
            && (!have_bounce || serialize_bounce_phase(cb2))                                  //   TrBouncePhase
            && cb2.store_bool_bool(was_deleted)                                               // destroyed:Bool
            && cb.store_ref_bool(cb2.finalize()) && cb.finalize_to(root));
      break;
    }
    default:
      return false;
  }
  if (verbosity >= 3 * 1) {
    std::cerr << "new transaction: ";
    block::gen::t_Transaction.print_ref(std::cerr, root);
    vm::load_cell_slice(root).print_rec(std::cerr);
  }

  if (!block::gen::t_Transaction.validate_ref(root)) {
    LOG(ERROR) << "newly-generated transaction failed to pass automated validation:";
    vm::load_cell_slice(root).print_rec(std::cerr);
    block::gen::t_Transaction.print_ref(std::cerr, root);
    root.clear();
    return false;
  }
  if (!block::tlb::t_Transaction.validate_ref(root)) {
    LOG(ERROR) << "newly-generated transaction failed to pass hand-written validation:";
    vm::load_cell_slice(root).print_rec(std::cerr);
    block::gen::t_Transaction.print_ref(std::cerr, root);
    root.clear();
    return false;
  }

  return true;
}

bool Transaction::serialize_storage_phase(vm::CellBuilder& cb) {
  if (!storage_phase) {
    return false;
  }
  StoragePhase& sp = *storage_phase;
  bool ok;
  // tr_phase_storage$_ storage_fees_collected:Grams
  if (sp.fees_collected.not_null()) {
    ok = block::tlb::t_Grams.store_integer_ref(cb, sp.fees_collected);
  } else {
    ok = block::tlb::t_Grams.null_value(cb);
  }
  // storage_fees_due:(Maybe Grams)
  ok &= block::store_Maybe_Grams_nz(cb, sp.fees_due);
  // status_change:AccStatusChange
  if (sp.deleted || sp.frozen) {
    ok &= cb.store_long_bool(sp.deleted ? 3 : 2, 2);  // acst_frozen$10 acst_deleted$11
  } else {
    ok &= cb.store_long_bool(0, 1);  // acst_unchanged$0 = AccStatusChange
  }
  return ok;
}

bool Transaction::serialize_credit_phase(vm::CellBuilder& cb) {
  if (!credit_phase) {
    return false;
  }
  CreditPhase& cp = *credit_phase;
  // tr_phase_credit$_ due_fees_collected:(Maybe Grams) credit:CurrencyCollection
  return block::store_Maybe_Grams_nz(cb, cp.due_fees_collected) && cp.credit.store(cb);
}

bool Transaction::serialize_compute_phase(vm::CellBuilder& cb) {
  if (!compute_phase) {
    return false;
  }
  ComputePhase& cp = *compute_phase;
  switch (cp.skip_reason) {
    // tr_compute_phase_skipped$0 reason:ComputeSkipReason;
    case ComputePhase::sk_no_state:
      return cb.store_long_bool(0, 3);  // cskip_no_state$00 = ComputeSkipReason;
    case ComputePhase::sk_bad_state:
      return cb.store_long_bool(1, 3);  // cskip_bad_state$01 = ComputeSkipReason;
    case ComputePhase::sk_no_gas:
      return cb.store_long_bool(2, 3);  // cskip_no_gas$10 = ComputeSkipReason;
    case ComputePhase::sk_none:
      break;
    default:
      return false;
  }
  vm::CellBuilder cb2;
  bool ok, credit = (cp.gas_credit != 0), exarg = (cp.exit_arg != 0);
  ok = cb.store_long_bool(1, 1)                                   // tr_phase_compute_vm$1
       && cb.store_long_bool(cp.success, 1)                       // success:Bool
       && cb.store_long_bool(cp.msg_state_used, 1)                // msg_state_used:Bool
       && cb.store_long_bool(cp.account_activated, 1)             // account_activated:Bool
       && block::tlb::t_Grams.store_integer_ref(cb, cp.gas_fees)  // gas_fees:Grams
       && block::store_UInt7(cb2, cp.gas_used)                    // ^[ gas_used:(VarUInteger 7)
       && block::store_UInt7(cb2, cp.gas_limit)                   //    gas_limit:(VarUInteger 7)
       && cb2.store_long_bool(credit, 1)                          //    gas_credit:(Maybe (VarUInteger 3))
       && (!credit || block::tlb::t_VarUInteger_3.store_long(cb2, cp.gas_credit)) &&
       cb2.store_long_rchk_bool(cp.mode, 8)      //    mode:int8
       && cb2.store_long_bool(cp.exit_code, 32)  //    exit_code:int32
       && cb2.store_long_bool(exarg, 1)          //    exit_arg:(Maybe int32)
       && (!exarg || cb2.store_long_bool(cp.exit_arg, 32)) &&
       cb2.store_ulong_rchk_bool(cp.vm_steps, 32)      //    vm_steps:uint32
       && cb2.store_bits_bool(cp.vm_init_state_hash)   //    vm_init_state_hash:bits256
       && cb2.store_bits_bool(cp.vm_final_state_hash)  //    vm_final_state_hash:bits256
       && cb.store_ref_bool(cb2.finalize());           // ] = TrComputePhase
  return ok;
}

bool Transaction::serialize_action_phase(vm::CellBuilder& cb) {
  if (!action_phase) {
    return false;
  }
  ActionPhase& ap = *action_phase;
  bool ok, arg = (ap.result_arg != 0);
  ok = cb.store_long_bool(ap.success, 1)                                             // tr_phase_action$_ success:Bool
       && cb.store_long_bool(ap.valid, 1)                                            // valid:Bool
       && cb.store_long_bool(ap.no_funds, 1)                                         // no_funds:Bool
       && cb.store_long_bool(ap.acc_status_change, (ap.acc_status_change >> 1) + 1)  // status_change:AccStatusChange
       && block::store_Maybe_Grams_nz(cb, ap.total_fwd_fees)                         // total_fwd_fees:(Maybe Grams)
       && block::store_Maybe_Grams_nz(cb, ap.total_action_fees)                      // total_action_fees:(Maybe Grams)
       && cb.store_long_bool(ap.result_code, 32)                                     // result_code:int32
       && cb.store_long_bool(arg, 1)                                                 // result_arg:(Maybe
       && (!arg || cb.store_long_bool(ap.result_arg, 32))                            //    uint32)
       && cb.store_ulong_rchk_bool(ap.tot_actions, 16)                               // tot_actions:uint16
       && cb.store_ulong_rchk_bool(ap.spec_actions, 16)                              // spec_actions:uint16
       && cb.store_ulong_rchk_bool(ap.skipped_actions, 16)                           // skipped_actions:uint16
       && cb.store_ulong_rchk_bool(ap.msgs_created, 16)                              // msgs_created:uint16
       && cb.store_bits_bool(ap.action_list_hash)                                    // action_list_hash:bits256
       && block::store_UInt7(cb, ap.tot_msg_cells, ap.tot_msg_bits);                 // tot_msg_size:StorageUsed
  return ok;
}

bool Transaction::serialize_bounce_phase(vm::CellBuilder& cb) {
  if (!bounce_phase) {
    return false;
  }
  BouncePhase& bp = *bounce_phase;
  if (!(bp.ok ^ bp.nofunds)) {
    return false;
  }
  if (bp.nofunds) {
    return cb.store_long_bool(1, 2)                              // tr_phase_bounce_nofunds$01
           && block::store_UInt7(cb, bp.msg_cells, bp.msg_bits)  // msg_size:StorageUsed
           && block::tlb::t_Grams.store_long(cb, bp.fwd_fees);   // req_fwd_fees:Grams
  } else {
    return cb.store_long_bool(1, 1)                                      // tr_phase_bounce_ok$1
           && block::store_UInt7(cb, bp.msg_cells, bp.msg_bits)          // msg_size:StorageUsed
           && block::tlb::t_Grams.store_long(cb, bp.fwd_fees_collected)  // msg_fees:Grams
           && block::tlb::t_Grams.store_long(cb, bp.fwd_fees);           // fwd_fees:Grams
  }
}

td::Result<vm::NewCellStorageStat::Stat> Transaction::estimate_block_storage_profile_incr(
    const vm::NewCellStorageStat& store_stat, const vm::CellUsageTree* usage_tree) const {
  if (root.is_null()) {
    return td::Status::Error("Cannot estimate the size profile of a transaction before it is serialized");
  }
  if (new_total_state.is_null()) {
    return td::Status::Error("Cannot estimate the size profile of a transaction before its new state is computed");
  }
  return store_stat.tentative_add_proof(new_total_state, usage_tree) + store_stat.tentative_add_cell(root);
}

bool Transaction::update_block_storage_profile(vm::NewCellStorageStat& store_stat,
                                               const vm::CellUsageTree* usage_tree) const {
  if (root.is_null() || new_total_state.is_null()) {
    return false;
  }
  store_stat.add_proof(new_total_state, usage_tree);
  store_stat.add_cell(root);
  return true;
}

bool Transaction::would_fit(unsigned cls, const block::BlockLimitStatus& blimst) const {
  auto res = estimate_block_storage_profile_incr(blimst.st_stat, blimst.limits.usage_tree);
  if (res.is_error()) {
    LOG(ERROR) << res.move_as_error();
    return false;
  }
  auto extra = res.move_as_ok();
  return blimst.would_fit(cls, end_lt, gas_used(), &extra);
}

bool Transaction::update_limits(block::BlockLimitStatus& blimst) const {
  return blimst.update_lt(end_lt) && blimst.update_gas(gas_used()) && blimst.add_proof(new_total_state) &&
         blimst.add_cell(root) && blimst.add_transaction() && blimst.add_account(is_first);
}

/*
 * 
 *  COMMIT TRANSACTION
 * 
 */

Ref<vm::Cell> Transaction::commit(Account& acc) {
  CHECK(account.last_trans_end_lt_ <= start_lt && start_lt < end_lt);
  CHECK(root.not_null());
  CHECK(new_total_state.not_null());
  CHECK((const void*)&acc == (const void*)&account);
  // export all fields modified by the Transaction into original account
  // NB: this is the only method that modifies account
  if (orig_addr_rewrite_set && new_split_depth >= 0 && acc.status == Account::acc_nonexist &&
      acc_status == Account::acc_active) {
    LOG(DEBUG) << "setting address rewriting info for newly-activated account " << acc.addr.to_hex()
               << " with split_depth=" << new_split_depth
               << ", orig_addr_rewrite=" << orig_addr_rewrite.bits().to_hex(new_split_depth);
    CHECK(acc.init_rewrite_addr(new_split_depth, orig_addr_rewrite.bits()));
  }
  acc.status = (acc_status == Account::acc_deleted ? Account::acc_nonexist : acc_status);
  acc.last_trans_lt_ = start_lt;
  acc.last_trans_end_lt_ = end_lt;
  acc.last_trans_hash_ = root->get_hash().bits();
  acc.last_paid = last_paid;
  acc.storage_stat = new_storage_stat;
  acc.balance = std::move(balance);
  acc.due_payment = std::move(due_payment);
  acc.total_state = std::move(new_total_state);
  acc.inner_state = std::move(new_inner_state);
  if (was_frozen) {
    acc.state_hash = frozen_hash;
  }
  acc.my_addr = std::move(my_addr);
  // acc.my_addr_exact = std::move(my_addr_exact);
  acc.code = std::move(new_code);
  acc.data = std::move(new_data);
  acc.library = std::move(new_library);
  if (acc.status == Account::acc_active) {
    acc.tick = new_tick;
    acc.tock = new_tock;
  } else {
    acc.tick = acc.tock = false;
  }
  end_lt = 0;
  acc.push_transaction(root, start_lt);
  return root;
}

LtCellRef Transaction::extract_out_msg(unsigned i) {
  return {start_lt + i + 1, std::move(out_msgs.at(i))};
}

NewOutMsg Transaction::extract_out_msg_ext(unsigned i) {
  return {start_lt + i + 1, std::move(out_msgs.at(i)), root};
}

void Transaction::extract_out_msgs(std::vector<LtCellRef>& list) {
  for (unsigned i = 0; i < out_msgs.size(); i++) {
    list.emplace_back(start_lt + i + 1, std::move(out_msgs[i]));
  }
}

void Account::push_transaction(Ref<vm::Cell> trans_root, ton::LogicalTime trans_lt) {
  transactions.emplace_back(trans_lt, std::move(trans_root));
}

bool Account::create_account_block(vm::CellBuilder& cb) {
  if (transactions.empty()) {
    return false;
  }
  if (!(cb.store_long_bool(5, 4)         // acc_trans#5
        && cb.store_bits_bool(addr))) {  // account_addr:bits256
    return false;
  }
  vm::AugmentedDictionary dict{64, block::tlb::aug_AccountTransactions};
  for (auto& z : transactions) {
    if (!dict.set_ref(td::BitArray<64>{(long long)z.first}, z.second, vm::Dictionary::SetMode::Add)) {
      LOG(ERROR) << "error creating the list of transactions for account " << addr.to_hex()
                 << " : cannot add transaction with lt=" << z.first;
      return false;
    }
  }
  Ref<vm::Cell> dict_root = std::move(dict).extract_root_cell();
  // transactions:(HashmapAug 64 ^Transaction Grams)
  if (dict_root.is_null() || !cb.append_cellslice_bool(vm::load_cell_slice(std::move(dict_root)))) {
    return false;
  }
  vm::CellBuilder cb2;
  return cb2.store_long_bool(0x72, 8)                                      // update_hashes#72
         && cb2.store_bits_bool(orig_total_state->get_hash().bits(), 256)  // old_hash:bits256
         && cb2.store_bits_bool(total_state->get_hash().bits(), 256)       // new_hash:bits256
         && cb.store_ref_bool(cb2.finalize());                             // state_update:^(HASH_UPDATE Account)
}

bool Account::libraries_changed() const {
  bool s = orig_library.not_null();
  bool t = library.not_null();
  if (s & t) {
    return orig_library->get_hash() != library->get_hash();
  } else {
    return s != t;
  }
}

}  // namespace block
