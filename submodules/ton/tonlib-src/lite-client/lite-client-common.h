#pragma once

#include "crypto/block/block.h"

#include "auto/tl/lite_api.hpp"

namespace liteclient {
td::Result<std::unique_ptr<block::BlockProofChain>> deserialize_proof_chain(
    ton::lite_api::object_ptr<ton::lite_api::liteServer_partialBlockProof> f);
}
