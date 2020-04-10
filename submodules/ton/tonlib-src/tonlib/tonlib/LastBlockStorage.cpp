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
#include "LastBlockStorage.h"

#include "tonlib/utils.h"

#include "td/utils/as.h"
#include "td/utils/filesystem.h"
#include "td/utils/port/path.h"
#include "td/utils/tl_helpers.h"

namespace tonlib {

void LastBlockStorage::set_key_value(std::shared_ptr<KeyValue> kv) {
  kv_ = std::move(kv);
}

namespace {
std::string get_file_name(td::Slice name) {
  return td::buffer_to_hex(name) + ".blkstate";
}
}  // namespace

td::Result<LastBlockState> LastBlockStorage::get_state(td::Slice name) {
  TRY_RESULT(data, kv_->get(get_file_name(name)));
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
  VLOG(last_block) << "Save to cache: " << state;
  auto x = td::serialize(state);
  std::string y(x.size() + 8, 0);
  td::MutableSlice(y).substr(8).copy_from(x);
  td::as<td::uint64>(td::MutableSlice(y).data()) = td::crc64(x);
  kv_->set(get_file_name(name), y);
}
}  // namespace tonlib
