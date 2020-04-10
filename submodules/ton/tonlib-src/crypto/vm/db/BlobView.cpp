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
#include "vm/db/BlobView.h"

#include "td/utils/port/FileFd.h"
#include "td/utils/HashMap.h"

#include "td/utils/format.h"
#include "td/utils/port/RwMutex.h"
#include "td/utils/port/MemoryMapping.h"

#include <limits>
#include <mutex>

namespace vm {
td::Result<td::Slice> BlobView::view(td::MutableSlice slice, td::uint64 offset) {
  if (offset > size() || slice.size() > size() - offset) {
    return td::Status::Error(PSLICE() << "BlobView: invalid range requested " << td::tag("slice offset", offset)
                                      << td::tag("slice size", slice.size()) << td::tag("blob size", size()));
  }
  return view_impl(slice, offset);
}
namespace {
class BufferSliceBlobViewImpl : public BlobView {
 public:
  BufferSliceBlobViewImpl(td::BufferSlice slice) : slice_(std::move(slice)) {
  }
  td::Result<td::Slice> view_impl(td::MutableSlice slice, td::uint64 offset) override {
    // optimize anyway
    if (offset > std::numeric_limits<std::size_t>::max()) {
      return td::Slice();
    }
    return slice_.as_slice().substr(static_cast<std::size_t>(offset), slice.size());
  }
  td::uint64 size() override {
    return slice_.size();
  }

 private:
  td::BufferSlice slice_;
};
}  // namespace

std::unique_ptr<BlobView> BufferSliceBlobView::create(td::BufferSlice slice) {
  return std::make_unique<BufferSliceBlobViewImpl>(std::move(slice));
}

class FileBlobViewImpl : public BlobView {
 public:
  FileBlobViewImpl(td::FileFd fd, td::uint64 file_size) : fd_(std::move(fd)), file_size_(file_size) {
  }

  td::uint64 size() override {
    return file_size_;
  }
  td::Result<td::Slice> view_impl(td::MutableSlice slice, td::uint64 offset) override {
    CHECK(offset < size());
    CHECK(size() - offset >= slice.size());
    slice.truncate(file_size_ - offset);
    auto first_page = offset / page_size;
    auto last_page = (offset + slice.size() - 1) / page_size;
    td::uint64 res_offset = 0;
    for (auto page_i = first_page; page_i <= last_page; page_i++) {
      auto page_offset = page_i * page_size;
      auto from = td::max(page_offset, offset);
      auto till = td::min(page_offset + page_size, offset + slice.size());
      CHECK(from < till);
      TRY_RESULT(page, load_page(page_i));
      auto len = till - from;
      slice.substr(res_offset, len).copy_from(page.substr(from - page_offset, len));
      res_offset += len;
    }
    CHECK(slice.size() == res_offset);
    total_view_size_ += slice.size();
    return slice;
  }
  ~FileBlobViewImpl() {
    //LOG(ERROR) << "LOADED " << pages_.size() << " " << total_view_size_;
  }

 private:
  td::FileFd fd_;
  td::uint64 file_size_;
  const td::uint64 page_size = 4096;
  td::uint64 total_view_size_{0};

  td::RwMutex pages_rw_mutex_;
  td::HashMap<td::uint64, td::BufferSlice> pages_;

  std::mutex fd_mutex_;

  td::Result<td::Slice> load_page(td::uint64 page_i) {
    {
      auto pages_guard = pages_rw_mutex_.lock_read();
      auto it = pages_.find(page_i);
      if (it != pages_.end()) {
        return it->second.as_slice();
      }
    }

    std::lock_guard<std::mutex> fd_guard(fd_mutex_);
    {
      auto pages_guard = pages_rw_mutex_.lock_read();
      auto it = pages_.find(page_i);
      if (it != pages_.end()) {
        return it->second.as_slice();
      }
    }
    auto offset = page_i * page_size;

    auto size = td::min(file_size_ - offset, page_size);
    auto buffer_slice = td::BufferSlice(size);
    TRY_RESULT(read_size, fd_.pread(buffer_slice.as_slice(), offset));
    if (read_size != buffer_slice.size()) {
      return td::Status::Error("not enough data in file");
    }

    auto pages_guard = pages_rw_mutex_.lock_write();
    auto &res = pages_[page_i];
    res = std::move(buffer_slice);
    return res.as_slice();
  }
};
td::Result<std::unique_ptr<BlobView>> FileBlobView::create(td::CSlice file_path, td::uint64 file_size) {
  TRY_RESULT(fd, td::FileFd::open(file_path, td::FileFd::Flags::Read));
  TRY_RESULT(stat, fd.stat());
  if (file_size == 0) {
    file_size = stat.size_;
  } else if (file_size != (td::uint64)stat.size_) {
    return td::Status::Error("Wrong file size");
  }
  return std::make_unique<FileBlobViewImpl>(std::move(fd), file_size);
}

class FileMemoryMappingBlobViewImpl : public BlobView {
 public:
  FileMemoryMappingBlobViewImpl(td::MemoryMapping mapping) : mapping_(std::move(mapping)) {
  }
  td::Result<td::Slice> view_impl(td::MutableSlice slice, td::uint64 offset) override {
    // optimize anyway
    return mapping_.as_slice().substr(offset, slice.size());
  }
  td::uint64 size() override {
    return mapping_.as_slice().size();
  }

 private:
  td::MemoryMapping mapping_;
};

td::Result<std::unique_ptr<BlobView>> FileMemoryMappingBlobView::create(td::CSlice file_path, td::uint64 file_size) {
  TRY_RESULT(fd, td::FileFd::open(file_path, td::FileFd::Flags::Read));
  TRY_RESULT(stat, fd.stat());
  if (file_size == 0) {
    file_size = stat.size_;
  } else if (file_size != (td::uint64)stat.size_) {
    return td::Status::Error("Wrong file size");
  }

  TRY_RESULT(mapping, td::MemoryMapping::create_from_file(fd));

  return std::make_unique<FileMemoryMappingBlobViewImpl>(std::move(mapping));
}

}  // namespace vm
