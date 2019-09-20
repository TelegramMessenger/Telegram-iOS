#pragma once

#include "tonlib/LastBlock.h"

namespace tonlib {
class BlockchainInfoStorage {
  td::Status set_directory(std::string directory);
  td::Result<LastBlock::State> get_state(ZeroStateIdExt);
  void save_state(LastBlock::State state);
};
}  // namespace tonlib
