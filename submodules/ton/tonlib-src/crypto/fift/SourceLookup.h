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
#pragma once
#include <iostream>

#include "td/utils/Status.h"
#include "td/utils/Time.h"

namespace fift {
class FileLoader {
 public:
  virtual ~FileLoader() = default;
  struct File {
    std::string data;
    std::string path;
  };
  virtual td::Result<File> read_file(td::CSlice filename) = 0;
  virtual td::Status write_file(td::CSlice filename, td::Slice data) = 0;
  virtual td::Result<File> read_file_part(td::CSlice filename, td::int64 size, td::int64 offset) = 0;
  virtual bool is_file_exists(td::CSlice filename) = 0;
};

class OsFileLoader : public FileLoader {
 public:
  td::Result<File> read_file(td::CSlice filename) override;
  td::Status write_file(td::CSlice filename, td::Slice data) override;
  td::Result<File> read_file_part(td::CSlice filename, td::int64 size, td::int64 offset) override;
  bool is_file_exists(td::CSlice filename) override;
};

class OsTime {
 public:
  virtual ~OsTime() = default;
  virtual td::uint32 now() = 0;
};

//TODO: rename SourceLookup
class SourceLookup {
 public:
  SourceLookup() = default;
  explicit SourceLookup(std::unique_ptr<FileLoader> file_loader, std::unique_ptr<OsTime> os_time = {})
      : file_loader_(std::move(file_loader)), os_time_(std::move(os_time)) {
  }
  void set_os_time(std::unique_ptr<OsTime> os_time) {
    os_time_ = std::move(os_time);
  }
  void add_include_path(td::string path);
  td::Result<FileLoader::File> lookup_source(std::string filename, std::string current_dir);

  td::Result<FileLoader::File> read_file(td::CSlice path) {
    return file_loader_->read_file(path);
  }
  td::Status write_file(td::CSlice path, td::Slice data) {
    return file_loader_->write_file(path, data);
  }
  td::Result<FileLoader::File> read_file_part(td::CSlice filename, td::int64 size, td::int64 offset) {
    return file_loader_->read_file_part(filename, size, offset);
  }
  bool is_file_exists(td::CSlice filename) {
    return file_loader_->is_file_exists(filename);
  }
  td::uint32 now() {
    if (os_time_) {
      return os_time_->now();
    }
    return static_cast<td::uint32>(td::Clocks::system());
  }

 protected:
  std::unique_ptr<FileLoader> file_loader_;
  std::unique_ptr<OsTime> os_time_;
  std::vector<std::string> source_include_path_;
};
}  // namespace fift
