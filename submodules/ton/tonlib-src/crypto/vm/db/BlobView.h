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
#include "td/utils/buffer.h"

namespace vm {
class BlobView {
 public:
  virtual ~BlobView() = default;
  td::Result<td::Slice> view(td::MutableSlice slice, td::uint64 offset);
  virtual td::uint64 size() = 0;

 private:
  virtual td::Result<td::Slice> view_impl(td::MutableSlice slice, td::uint64 offset) = 0;
};

class BufferSliceBlobView {
 public:
  static std::unique_ptr<BlobView> create(td::BufferSlice slice);
};
class FileBlobView {
 public:
  static td::Result<std::unique_ptr<BlobView>> create(td::CSlice file_path, td::uint64 file_size = 0);
};
class FileMemoryMappingBlobView {
 public:
  static td::Result<std::unique_ptr<BlobView>> create(td::CSlice file_path, td::uint64 file_size = 0);
};
}  // namespace vm
