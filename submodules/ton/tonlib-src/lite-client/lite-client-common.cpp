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
#include "lite-client-common.h"

#include "auto/tl/lite_api.hpp"
#include "tl-utils/lite-utils.hpp"
#include "ton/lite-tl.hpp"
#include "td/utils/overloaded.h"
#include "td/utils/Random.h"

using namespace std::literals::string_literals;

namespace liteclient {

td::Result<std::unique_ptr<block::BlockProofChain>> deserialize_proof_chain(
    ton::lite_api::object_ptr<ton::lite_api::liteServer_partialBlockProof> f) {
  // deserialize proof chain
  auto chain = std::make_unique<block::BlockProofChain>(ton::create_block_id(f->from_), ton::create_block_id(f->to_));
  chain->complete = f->complete_;
  for (auto& s : f->steps_) {
    bool ok = false;
    td::BufferSlice dest_proof, proof, state_proof;
    ton::lite_api::downcast_call(
        *s,
        td::overloaded(
            [&](ton::lite_api::liteServer_blockLinkBack& s) {
              auto& link = chain->new_link(ton::create_block_id(s.from_), ton::create_block_id(s.to_), s.to_key_block_);
              link.is_fwd = false;
              // dest_proof:bytes state_proof:bytes proof:bytes
              dest_proof = std::move(s.dest_proof_);
              state_proof = std::move(s.state_proof_);
              proof = std::move(s.proof_);
              ok = true;
            },
            [&](ton::lite_api::liteServer_blockLinkForward& s) {
              auto& link = chain->new_link(ton::create_block_id(s.from_), ton::create_block_id(s.to_), s.to_key_block_);
              link.is_fwd = true;
              // dest_proof:bytes config_proof:bytes signatures:liteServer.SignatureSet
              dest_proof = std::move(s.dest_proof_);
              proof = std::move(s.config_proof_);
              link.cc_seqno = s.signatures_->catchain_seqno_;
              link.validator_set_hash = s.signatures_->validator_set_hash_;
              for (auto& sig : s.signatures_->signatures_) {
                link.signatures.emplace_back(std::move(sig->node_id_short_), std::move(sig->signature_));
              }
              ok = true;
            },
            [&](auto& obj) {}));
    if (!ok) {
      return td::Status::Error("unknown constructor of liteServer.BlockLink");
    }
    auto& link = chain->last_link();
    if (!dest_proof.empty()) {
      auto d_res = vm::std_boc_deserialize(std::move(dest_proof));
      if (d_res.is_error()) {
        return td::Status::Error("cannot deserialize dest_proof in a block proof link: "s +
                                 d_res.move_as_error().to_string());
      }
      link.dest_proof = d_res.move_as_ok();
    }
    auto d_res = vm::std_boc_deserialize(std::move(proof));
    if (d_res.is_error()) {
      return td::Status::Error("cannot deserialize proof in a block proof link: "s + d_res.move_as_error().to_string());
    }
    link.proof = d_res.move_as_ok();
    if (!link.is_fwd) {
      d_res = vm::std_boc_deserialize(std::move(state_proof));
      if (d_res.is_error()) {
        return td::Status::Error("cannot deserialize state_proof in a block proof link: "s +
                                 d_res.move_as_error().to_string());
      }
      link.state_proof = d_res.move_as_ok();
    }
    LOG(DEBUG) << "deserialized a " << (link.is_fwd ? "forward" : "backward") << " BlkProofLink from "
               << link.from.to_str() << " to " << link.to.to_str() << " with " << link.signatures.size()
               << " signatures";
  }
  LOG(DEBUG) << "deserialized a BlkProofChain of " << chain->link_count() << " links";
  return std::move(chain);
}

td::Ref<vm::Tuple> prepare_vm_c7(ton::UnixTime now, ton::LogicalTime lt, td::Ref<vm::CellSlice> my_addr,
                                 const block::CurrencyCollection& balance) {
  td::BitArray<256> rand_seed;
  td::RefInt256 rand_seed_int{true};
  td::Random::secure_bytes(rand_seed.as_slice());
  if (!rand_seed_int.unique_write().import_bits(rand_seed.cbits(), 256, false)) {
    return {};
  }
  auto tuple = vm::make_tuple_ref(td::make_refint(0x076ef1ea),  // [ magic:0x076ef1ea
                                  td::make_refint(0),           //   actions:Integer
                                  td::make_refint(0),           //   msgs_sent:Integer
                                  td::make_refint(now),         //   unixtime:Integer
                                  td::make_refint(lt),          //   block_lt:Integer
                                  td::make_refint(lt),          //   trans_lt:Integer
                                  std::move(rand_seed_int),     //   rand_seed:Integer
                                  balance.as_vm_tuple(),        //   balance_remaining:[Integer (Maybe Cell)]
                                  my_addr,                      //  myself:MsgAddressInt
                                  vm::StackEntry());            //  global_config:(Maybe Cell) ] = SmartContractInfo;
  LOG(DEBUG) << "SmartContractInfo initialized with " << vm::StackEntry(tuple).to_string();
  return vm::make_tuple_ref(std::move(tuple));
}

}  // namespace liteclient
