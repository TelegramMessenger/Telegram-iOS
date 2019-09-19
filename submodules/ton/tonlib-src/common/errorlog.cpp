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

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "errorlog.h"
#include "checksum.h"

#include "td/utils/port/FileFd.h"
#include "td/utils/filesystem.h"
#include "td/utils/port/path.h"
#include "td/utils/Time.h"

#include <mutex>

namespace ton {

namespace errorlog {

td::FileFd fd;
std::mutex init_mutex_;
std::string files_path_;

void ErrorLog::create(std::string db_root) {
  init_mutex_.lock();
  if (!fd.empty()) {
    init_mutex_.unlock();
    return;
  }
  auto path = db_root + "/error";
  td::mkdir(path).ensure();
  files_path_ = path + "/files";
  td::mkdir(files_path_).ensure();
  auto R = td::FileFd::open(path + "/log.txt",
                            td::FileFd::Flags::Write | td::FileFd::Flags::Append | td::FileFd::Flags::Create);
  R.ensure();
  fd = R.move_as_ok();
  init_mutex_.unlock();
}

void ErrorLog::log(std::string error) {
  error = PSTRING() << "[" << td::Clocks::system() << "] " << error << "\n";
  CHECK(!fd.empty());
  auto s = td::Slice{error};
  while (s.size() > 0) {
    auto R = fd.write(s);
    R.ensure();
    s.remove_prefix(R.move_as_ok());
  }
}

void ErrorLog::log_file(td::BufferSlice data) {
  auto filename = sha256_bits256(data.as_slice());
  auto path = files_path_ + "/" + filename.to_hex();

  td::write_file(path, data.as_slice()).ensure();
}

}  // namespace errorlog

}  // namespace ton
