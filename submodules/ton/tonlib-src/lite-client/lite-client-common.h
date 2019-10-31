#pragma once

#include "crypto/block/block.h"

#include "auto/tl/lite_api.hpp"

namespace liteclient {
td::Result<std::unique_ptr<block::BlockProofChain>> deserialize_proof_chain(
    ton::lite_api::object_ptr<ton::lite_api::liteServer_partialBlockProof> f);

td::Ref<vm::Tuple> prepare_vm_c7(ton::UnixTime now, ton::LogicalTime lt, td::Ref<vm::CellSlice> my_addr,
                                 const block::CurrencyCollection& balance);
}  // namespace liteclient
