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
#pragma once
#include "td/utils/buffer.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/port/IoSlice.h"

namespace td {
// Generic stream interface
// Will to hide implementations details.
// CyclicBuffer, ChainBuffer, Bounded ChainBuffer, some clever writers. They all should be interchangable
// Most implementaions will assume that reading and writing may happen concurrently

class StreamReaderInterface {
 public:
  virtual ~StreamReaderInterface() {
  }
  virtual size_t reader_size() = 0;
  virtual Slice prepare_read() = 0;
  virtual Span<IoSlice> prepare_readv() = 0;
  virtual void confirm_read(size_t size) = 0;

  virtual void close_reader(Status error) = 0;
  virtual bool is_writer_closed() const = 0;
  virtual Status &writer_status() = 0;
};

class StreamWriterInterface {
 public:
  virtual ~StreamWriterInterface() {
  }
  virtual size_t writer_size() = 0;
  virtual MutableSlice prepare_write() = 0;
  virtual MutableSlice prepare_write_at_least(size_t size) = 0;
  virtual void confirm_write(size_t size) = 0;
  virtual void append(Slice data) = 0;
  virtual void append(BufferSlice data) {
    append(data.as_slice());
  }
  virtual void append(std::string data) {
    append(Slice(data));
  }

  virtual void close_writer(Status error) = 0;
  virtual bool is_reader_closed() const = 0;
  virtual Status &reader_status() = 0;
};

// Hide shared_ptr
class StreamReader : public StreamReaderInterface {
 public:
  StreamReader() = default;
  StreamReader(std::shared_ptr<StreamReaderInterface> self);
  size_t reader_size() override;
  Slice prepare_read() override;
  Span<IoSlice> prepare_readv() override;
  void confirm_read(size_t size) override;
  void close_reader(Status error) override;
  bool is_writer_closed() const override;
  Status &writer_status() override;

 private:
  std::shared_ptr<StreamReaderInterface> self;
};

class StreamWriter : public StreamWriterInterface {
 public:
  StreamWriter() = default;
  StreamWriter(std::shared_ptr<StreamWriterInterface> self);
  size_t writer_size() override;
  MutableSlice prepare_write() override;
  MutableSlice prepare_write_at_least(size_t size) override;
  void confirm_write(size_t size) override;
  void append(Slice data) override;
  void append(BufferSlice data) override;
  void append(std::string data) override;
  void close_writer(Status error) override;
  bool is_reader_closed() const override;
  Status &reader_status() override;

 private:
  std::shared_ptr<StreamWriterInterface> self;
};

}  // namespace td
