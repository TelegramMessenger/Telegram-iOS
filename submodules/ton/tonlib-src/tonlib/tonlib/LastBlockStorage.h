#pragma once

#include "tonlib/LastBlock.h"

namespace tonlib {
class LastBlockStorage {
 public:
  td::Status set_directory(std::string directory);
  td::Result<LastBlockState> get_state(td::Slice name);
  void save_state(td::Slice name, LastBlockState state);

 private:
  std::string directory_;
  std::string get_file_name(td::Slice name);
};
}  // namespace tonlib
