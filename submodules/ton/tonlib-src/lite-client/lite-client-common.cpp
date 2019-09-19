#include "lite-client-common.h"

#include "auto/tl/lite_api.hpp"
#include "tl-utils/lite-utils.hpp"
#include "ton/lite-tl.hpp"
#include "td/utils/overloaded.h"

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
}  // namespace liteclient
