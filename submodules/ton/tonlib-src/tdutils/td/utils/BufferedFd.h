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
#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/IoSlice.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"

#include <limits>

namespace td {
// just reads from given reader and writes to given writer
template <class FdT>
class BufferedFdBase : public FdT {
 public:
  BufferedFdBase() = default;
  explicit BufferedFdBase(FdT &&fd_);
  // TODO: make move constructor and move assignment safer

  Result<size_t> flush_read(size_t max_read = std::numeric_limits<size_t>::max()) TD_WARN_UNUSED_RESULT;
  Result<size_t> flush_write() TD_WARN_UNUSED_RESULT;

  bool need_flush_write(size_t at_least = 0) {
    CHECK(write_);
    write_->sync_with_writer();
    return write_->size() > at_least;
  }
  size_t ready_for_flush_write() {
    CHECK(write_);
    write_->sync_with_writer();
    return write_->size();
  }
  void set_input_writer(ChainBufferWriter *read) {
    read_ = read;
  }
  void set_output_reader(ChainBufferReader *write) {
    write_ = write;
  }

 private:
  ChainBufferWriter *read_ = nullptr;
  ChainBufferReader *write_ = nullptr;
};

template <class FdT>
class BufferedFd : public BufferedFdBase<FdT> {
  using Parent = BufferedFdBase<FdT>;
  ChainBufferWriter input_writer_;
  ChainBufferReader input_reader_;
  ChainBufferWriter output_writer_;
  ChainBufferReader output_reader_;
  void init();
  void init_ptr();

 public:
  BufferedFd();
  explicit BufferedFd(FdT &&fd_);
  BufferedFd(BufferedFd &&);
  BufferedFd &operator=(BufferedFd &&);
  BufferedFd(const BufferedFd &) = delete;
  BufferedFd &operator=(const BufferedFd &) = delete;
  ~BufferedFd();

  void close();

  Result<size_t> flush_read(size_t max_read = std::numeric_limits<size_t>::max()) TD_WARN_UNUSED_RESULT;
  Result<size_t> flush_write() TD_WARN_UNUSED_RESULT;

  // Yep, direct access to buffers. It is IO interface too.
  ChainBufferReader &input_buffer();
  ChainBufferWriter &output_buffer();
};

// IMPLEMENTATION

/*** BufferedFd ***/
template <class FdT>
BufferedFdBase<FdT>::BufferedFdBase(FdT &&fd_) : FdT(std::move(fd_)) {
}

template <class FdT>
Result<size_t> BufferedFdBase<FdT>::flush_read(size_t max_read) {
  CHECK(read_);
  size_t result = 0;
  while (::td::can_read(*this) && max_read) {
    MutableSlice slice = read_->prepare_append().truncate(max_read);
    TRY_RESULT(x, FdT::read(slice));
    slice.truncate(x);
    read_->confirm_append(x);
    result += x;
    max_read -= x;
  }
  return result;
}

template <class FdT>
Result<size_t> BufferedFdBase<FdT>::flush_write() {
  // TODO: sync on demand
  write_->sync_with_writer();
  size_t result = 0;
  while (!write_->empty() && ::td::can_write(*this)) {
    constexpr size_t buf_size = 20;
    IoSlice buf[buf_size];

    auto it = write_->clone();
    size_t buf_i;
    for (buf_i = 0; buf_i < buf_size; buf_i++) {
      Slice slice = it.prepare_read();
      if (slice.empty()) {
        break;
      }
      buf[buf_i] = as_io_slice(slice);
      it.confirm_read(slice.size());
    }
    TRY_RESULT(x, FdT::writev(Span<IoSlice>(buf, buf_i)));
    write_->advance(x);
    result += x;
  }
  return result;
}

/*** BufferedFd ***/
template <class FdT>
void BufferedFd<FdT>::init() {
  input_reader_ = input_writer_.extract_reader();
  output_reader_ = output_writer_.extract_reader();
  init_ptr();
}

template <class FdT>
void BufferedFd<FdT>::init_ptr() {
  this->set_input_writer(&input_writer_);
  this->set_output_reader(&output_reader_);
}

template <class FdT>
BufferedFd<FdT>::BufferedFd() {
  init();
}

template <class FdT>
BufferedFd<FdT>::BufferedFd(FdT &&fd_) : Parent(std::move(fd_)) {
  init();
}

template <class FdT>
BufferedFd<FdT>::BufferedFd(BufferedFd &&from) {
  *this = std::move(from);
}

template <class FdT>
BufferedFd<FdT> &BufferedFd<FdT>::operator=(BufferedFd &&from) {
  FdT::operator=(std::move(static_cast<FdT &>(from)));
  input_reader_ = std::move(from.input_reader_);
  input_writer_ = std::move(from.input_writer_);
  output_reader_ = std::move(from.output_reader_);
  output_writer_ = std::move(from.output_writer_);
  init_ptr();
  return *this;
}

template <class FdT>
BufferedFd<FdT>::~BufferedFd() {
  close();
}

template <class FdT>
void BufferedFd<FdT>::close() {
  FdT::close();
  // TODO: clear buffers
}

template <class FdT>
Result<size_t> BufferedFd<FdT>::flush_read(size_t max_read) {
  TRY_RESULT(result, Parent::flush_read(max_read));
  if (result) {
    // TODO: faster sync is possible if you owns writer.
    input_reader_.sync_with_writer();
    LOG(DEBUG) << "Flush read: +" << format::as_size(result) << tag("total", format::as_size(input_reader_.size()));
  }
  return result;
}

template <class FdT>
Result<size_t> BufferedFd<FdT>::flush_write() {
  TRY_RESULT(result, Parent::flush_write());
  if (result) {
    LOG(DEBUG) << "Flush write: +" << format::as_size(result) << tag("left", format::as_size(output_reader_.size()));
  }
  return result;
}

// Yep, direct access to buffers. It is IO interface too.
template <class FdT>
ChainBufferReader &BufferedFd<FdT>::input_buffer() {
  return input_reader_;
}

template <class FdT>
ChainBufferWriter &BufferedFd<FdT>::output_buffer() {
  return output_writer_;
}

}  // namespace td
