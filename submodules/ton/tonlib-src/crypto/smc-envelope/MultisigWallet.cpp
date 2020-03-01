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

    Copyright 2019-2020 Telegram Systems LLP
*/
#include "MultisigWallet.h"

#include "SmartContractCode.h"

#include "vm/dict.h"

#include "td/utils/misc.h"

namespace ton {

MultisigWallet::QueryBuilder::QueryBuilder(td::uint32 wallet_id, td::int64 query_id, td::Ref<vm::Cell> msg, int mode) {
  msg_ = vm::CellBuilder()
             .store_long(wallet_id, 32)
             .store_long(query_id, 64)
             .store_long(mode, 8)
             .store_ref(std::move(msg))
             .finalize();
}
void MultisigWallet::QueryBuilder::sign(td::int32 id, td::Ed25519::PrivateKey& pk) {
  CHECK(id < td::narrow_cast<td::int32>(mask_.size()));
  auto signature = pk.sign(msg_->get_hash().as_slice()).move_as_ok();
  mask_.set(id);
  vm::CellBuilder cb;
  cb.store_bytes(signature.as_slice());
  cb.store_long(id, 8);
  cb.ensure_throw(cb.store_maybe_ref(std::move(dict_)));
  dict_ = cb.finalize();
}

td::Ref<vm::Cell> MultisigWallet::QueryBuilder::create_inner() const {
  vm::CellBuilder cb;
  cb.ensure_throw(cb.store_maybe_ref(dict_));
  return cb.append_cellslice(vm::load_cell_slice(msg_)).finalize();
}

td::Ref<vm::Cell> MultisigWallet::QueryBuilder::create(td::int32 id, td::Ed25519::PrivateKey& pk) const {
  auto cell = create_inner();
  vm::CellBuilder cb;
  cb.store_long(id, 8);
  cb.append_cellslice(vm::load_cell_slice(cell));
  cell = cb.finalize();

  auto signature = pk.sign(cell->get_hash().as_slice()).move_as_ok();
  vm::CellBuilder cb2;
  cb2.store_bytes(signature.as_slice());
  cb2.append_cellslice(vm::load_cell_slice(cell));
  return cb2.finalize();
}

td::Ref<MultisigWallet> MultisigWallet::create(td::Ref<vm::Cell> data) {
  return td::Ref<MultisigWallet>(
      true, State{ton::SmartContractCode::get_code(ton::SmartContractCode::Multisig), std::move(data)});
}

int MultisigWallet::processed(td::uint64 query_id) const {
  auto res = run_get_method("processed?", {td::make_refint(query_id)});
  return res.stack.write().pop_smallint_range(1, -1);
}

MultisigWallet::QueryState MultisigWallet::get_query_state(td::uint64 query_id) const {
  auto ans = run_get_method("get_query_state", {td::make_refint(query_id)});

  auto mask = ans.stack.write().pop_int();
  auto state = ans.stack.write().pop_smallint_range(1, -1);

  QueryState res;
  if (state == 1) {
    res.state = QueryState::Unknown;
  } else if (state == 0) {
    res.state = QueryState::NotReady;
    for (size_t i = 0; i < res.mask.size(); i++) {
      if (mask->get_bit(static_cast<int>(i))) {
        res.mask.set(i);
      }
    }
  } else {
    res.state = QueryState::Sent;
  }
  return res;
}

std::vector<td::SecureString> MultisigWallet::get_public_keys() const {
  auto ans = run_get_method("get_public_keys");
  auto dict_root = ans.stack.write().pop_cell();
  vm::Dictionary dict(std::move(dict_root), 8);
  std::vector<td::SecureString> res;
  dict.check_for_each([&](auto cs, auto x, auto y) {
    td::SecureString key(32);
    cs->prefetch_bytes(key.as_mutable_slice().ubegin(), td::narrow_cast<int>(key.size()));
    res.push_back(std::move(key));
    return true;
  });
  return res;
}

td::Ref<vm::Cell> MultisigWallet::create_init_data(td::uint32 wallet_id, std::vector<td::SecureString> public_keys,
                                                   int k) const {
  vm::Dictionary pk(8);
  for (size_t i = 0; i < public_keys.size(); i++) {
    auto key = pk.integer_key(td::make_refint(i), 8, false);
    pk.set_builder(key.bits(), 8, vm::CellBuilder().store_bytes(public_keys[i].as_slice()).store_long(0, 8));
  }
  auto res = run_get_method("create_init_state", {td::make_refint(wallet_id), td::make_refint(public_keys.size()),
                                                  td::make_refint(k), pk.get_root_cell()});
  CHECK(res.code == 0);
  return res.stack.write().pop_cell();
}

td::Ref<vm::Cell> MultisigWallet::create_init_data_fast(td::uint32 wallet_id, std::vector<td::SecureString> public_keys,
                                                        int k) {
  vm::Dictionary pk(8);
  for (size_t i = 0; i < public_keys.size(); i++) {
    auto key = pk.integer_key(td::make_refint(i), 8, false);
    pk.set_builder(key.bits(), 8, vm::CellBuilder().store_bytes(public_keys[i].as_slice()).store_long(0, 8));
  }

  vm::CellBuilder cb;
  cb.store_long(wallet_id, 32);
  cb.store_long(public_keys.size(), 8).store_long(k, 8).store_long(0, 64);
  cb.ensure_throw(cb.store_maybe_ref(pk.get_root_cell()));
  cb.ensure_throw(cb.store_maybe_ref({}));
  return cb.finalize();
}

td::Ref<vm::Cell> MultisigWallet::merge_queries(td::Ref<vm::Cell> a, td::Ref<vm::Cell> b) const {
  auto res = run_get_method("merge_queries", {a, b});
  return res.stack.write().pop_cell();
}

MultisigWallet::Mask MultisigWallet::to_mask(td::RefInt256 mask) const {
  Mask res_mask;
  for (size_t i = 0; i < res_mask.size(); i++) {
    if (mask->get_bit(static_cast<int>(i))) {
      res_mask.set(i);
    }
  }
  return res_mask;
}

std::pair<int, MultisigWallet::Mask> MultisigWallet::check_query_signatures(td::Ref<vm::Cell> a) const {
  auto ans = run_get_method("check_query_signatures", {a});

  auto mask = ans.stack.write().pop_int();
  auto cnt = ans.stack.write().pop_smallint_range(128);
  return std::make_pair(cnt, to_mask(mask));
}

std::pair<int, int> MultisigWallet::get_n_k() const {
  auto ans = run_get_method("get_n_k");
  auto k = ans.stack.write().pop_smallint_range(128);
  auto n = ans.stack.write().pop_smallint_range(128);
  return std::make_pair(n, k);
}

std::vector<MultisigWallet::Message> MultisigWallet::get_unsigned_messaged(int id) const {
  SmartContract::Answer ans;
  if (id == -1) {
    ans = run_get_method("get_messages_unsigned");
  } else {
    ans = run_get_method("get_messages_unsigned_by_id", {td::make_refint(id)});
  }
  auto n_k = get_n_k();

  auto cell = ans.stack.write().pop_maybe_cell();
  vm::Dictionary dict(std::move(cell), 64);
  std::vector<Message> res;
  dict.check_for_each([&](auto cs, auto ptr, auto ptr_bits) {
    cs.write().skip_first(8 + 8);
    Message message;
    td::BigInt256 query_id;
    query_id.import_bits(ptr, ptr_bits, false);
    message.query_id = static_cast<td::uint64>(query_id.to_long());
    message.signed_by = to_mask(cs.write().fetch_int256(n_k.first, false));
    message.message = cs.write().fetch_ref();
    res.push_back(std::move(message));
    return true;
  });
  return res;
}
}  // namespace ton
