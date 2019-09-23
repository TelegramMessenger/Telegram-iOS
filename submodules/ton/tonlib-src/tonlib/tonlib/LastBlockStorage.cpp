#include "LastBlockStorage.h"

#include "td/utils/as.h"
#include "td/utils/filesystem.h"
#include "td/utils/port/path.h"
#include "td/utils/tl_helpers.h"

namespace tonlib {

td::Status LastBlockStorage::set_directory(std::string directory) {
  TRY_RESULT(path, td::realpath(directory));
  TRY_RESULT(stat, td::stat(path));
  if (!stat.is_dir_) {
    return td::Status::Error("not a directory");
  }
  directory_ = std::move(path);
  return td::Status::OK();
}

std::string LastBlockStorage::get_file_name(td::Slice name) {
  return directory_ + TD_DIR_SLASH + td::buffer_to_hex(name) + ".blkstate";
}

td::Result<LastBlockState> LastBlockStorage::get_state(td::Slice name) {
  TRY_RESULT(data, td::read_file(get_file_name(name)));
  if (data.size() < 8) {
    return td::Status::Error("too short");
  }
  if (td::as<td::uint64>(data.data()) != td::crc64(td::Slice(data).substr(8))) {
    return td::Status::Error("crc64 mismatch");
  }
  LastBlockState res;
  TRY_STATUS(td::unserialize(res, td::Slice(data).substr(8)));
  return res;
}

void LastBlockStorage::save_state(td::Slice name, LastBlockState state) {
  auto x = td::serialize(state);
  std::string y(x.size() + 8, 0);
  td::MutableSlice(y).substr(8).copy_from(x);
  td::as<td::uint64>(td::MutableSlice(y).data()) = td::crc64(x);
  td::atomic_write_file(get_file_name(name), y);
}
}  // namespace tonlib
