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
#include "ChainBuffer.h"

#include "td/utils/buffer.h"
#include "td/db/utils/StreamInterface.h"

namespace td {
namespace detail {
class ChainBuffer : public StreamWriterInterface, public StreamReaderInterface {
 public:
  using Options = ::td::ChainBuffer::Options;

  ChainBuffer(Options options) {
    shared_.options_ = options;
    reader_.io_slices_.reserve(options.max_io_slices);
    reader_.buf_ = writer_.buf_.extract_reader();
  }

  // StreamReaderInterface
  size_t reader_size() override {
    reader_.buf_.sync_with_writer();
    return reader_.buf_.size();
  }

  Slice prepare_read() override {
    return reader_.buf_.prepare_read();
  }
  Span<IoSlice> prepare_readv() override {
    reader_.io_slices_.clear();
    auto it = reader_.buf_.clone();
    while (!it.empty() && reader_.io_slices_.size() < reader_.io_slices_.capacity()) {
      auto slice = it.prepare_read();
      reader_.io_slices_.push_back(as_io_slice(slice));
      it.confirm_read(slice.size());
    }
    return reader_.io_slices_;
  }
  void confirm_read(size_t size) override {
    reader_.buf_.advance(size);
  }

  void close_reader(Status error) override {
    CHECK(!reader_.is_closed_);
    reader_.status_ = std::move(error);
    reader_.is_closed_.store(true, std::memory_order_release);
  }
  bool is_writer_closed() const override {
    return writer_.is_closed_.load(std::memory_order_acquire);
  }
  Status &writer_status() override {
    CHECK(is_writer_closed());
    return writer_.status_;
  }

  // StreamWriterInterface
  size_t writer_size() override {
    return writer_.size_;
  }
  MutableSlice prepare_write() override {
    return writer_.buf_.prepare_append(shared_.options_.chunk_size);
  }
  MutableSlice prepare_write_at_least(size_t size) override {
    return writer_.buf_.prepare_append_at_least(size);
  }
  void confirm_write(size_t size) override {
    writer_.buf_.confirm_append(size);
    writer_.size_ += size;
  }
  void append(Slice data) override {
    writer_.buf_.append(data, shared_.options_.chunk_size);
    writer_.size_ += data.size();
  }
  void append(BufferSlice data) override {
    writer_.size_ += data.size();
    writer_.buf_.append(std::move(data));
  }
  void append(std::string data) override {
    append(Slice(data));
  }
  void close_writer(Status error) override {
    CHECK(!writer_.is_closed_);
    writer_.status_ = std::move(error);
    writer_.is_closed_.store(true, std::memory_order_release);
  }
  bool is_reader_closed() const override {
    return reader_.is_closed_.load(std::memory_order_acquire);
  }
  Status &reader_status() override {
    CHECK(is_reader_closed());
    return reader_.status_;
  }

 private:
  struct SharedData {
    Options options_;
  } shared_;

  char pad1[128];

  struct ReaderData {
    ChainBufferReader buf_;
    std::atomic<bool> is_closed_{false};
    Status status_;
    std::vector<IoSlice> io_slices_;
  } reader_;

  char pad2[128];

  struct WriterData {
    ChainBufferWriter buf_;
    std::atomic<bool> is_closed_{false};
    Status status_;
    size_t size_{0};
  } writer_;
};
}  // namespace detail

std::pair<ChainBuffer::Reader, ChainBuffer::Writer> ChainBuffer::create(Options options) {
  auto impl = std::make_shared<detail::ChainBuffer>(options);
  return {Reader(impl), Writer(impl)};
}
}  // namespace td
