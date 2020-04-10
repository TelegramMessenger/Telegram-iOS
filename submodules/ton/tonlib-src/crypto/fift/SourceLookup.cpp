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
#include "SourceLookup.h"

#include "td/utils/PathView.h"
#include "td/utils/PathView.h"
#include "td/utils/port/path.h"
#include "td/utils/filesystem.h"

#include <fstream>

namespace fift {
td::Result<FileLoader::File> OsFileLoader::read_file(td::CSlice filename) {
  File res;
  TRY_RESULT(data, td::read_file_str(filename));
  res.data = std::move(data);
  TRY_RESULT(path, td::realpath(filename));
  res.path = std::move(path);
  return std::move(res);
}

td::Status OsFileLoader::write_file(td::CSlice filename, td::Slice data) {
  return td::write_file(filename, data);
}

td::Result<FileLoader::File> OsFileLoader::read_file_part(td::CSlice filename, td::int64 size, td::int64 offset) {
  File res;
  TRY_RESULT(data, td::read_file_str(filename, size, offset));
  res.data = std::move(data);
  TRY_RESULT(path, td::realpath(filename));
  res.path = std::move(path);
  return std::move(res);
}

bool OsFileLoader::is_file_exists(td::CSlice filename) {
  return td::stat(filename).is_ok();
}

void SourceLookup::add_include_path(td::string path) {
  if (path.empty()) {
    return;
  }
  if (!td::PathView(path).is_dir()) {
    path += TD_DIR_SLASH;
  }

  source_include_path_.push_back(std::move(path));
}

td::Result<FileLoader::File> SourceLookup::lookup_source(std::string filename, std::string current_dir) {
  CHECK(file_loader_);
  if (!current_dir.empty() && !td::PathView(current_dir).is_dir()) {
    current_dir += TD_DIR_SLASH;
  }
  if (td::PathView(filename).is_absolute()) {
    return read_file(filename);
  }
  if (!current_dir.empty()) {
    auto res = read_file(current_dir + filename);
    if (res.is_ok()) {
      return res;
    }
  }
  for (auto& dir : source_include_path_) {
    auto res = read_file(dir + filename);
    if (res.is_ok()) {
      return res;
    }
  }

  return td::Status::Error(PSLICE() << "failed to lookup file: " << filename);
}
}  // namespace fift
