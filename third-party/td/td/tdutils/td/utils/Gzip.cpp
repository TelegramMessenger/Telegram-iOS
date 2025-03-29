//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/Gzip.h"

char disable_linker_warning_about_empty_file_gzip_cpp TD_UNUSED;

#if TD_HAVE_ZLIB
#include "td/utils/SliceBuilder.h"

#include <cstring>
#include <limits>
#include <utility>

#include <zlib.h>

namespace td {

class Gzip::Impl {
 public:
  z_stream stream_;

  // z_stream is not copyable nor movable
  Impl() = default;
  Impl(const Impl &) = delete;
  Impl &operator=(const Impl &) = delete;
  Impl(Impl &&) = delete;
  Impl &operator=(Impl &&) = delete;
  ~Impl() = default;
};

Status Gzip::init_encode() {
  CHECK(mode_ == Mode::Empty);
  init_common();
  mode_ = Mode::Encode;
  int ret = deflateInit2(&impl_->stream_, 6, Z_DEFLATED, 15, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY);
  if (ret != Z_OK) {
    return Status::Error(PSLICE() << "zlib deflate init failed: " << ret);
  }
  return Status::OK();
}

Status Gzip::init_decode() {
  CHECK(mode_ == Mode::Empty);
  init_common();
  mode_ = Mode::Decode;
  int ret = inflateInit2(&impl_->stream_, MAX_WBITS + 32);
  if (ret != Z_OK) {
    return Status::Error(PSLICE() << "zlib inflate init failed: " << ret);
  }
  return Status::OK();
}

void Gzip::set_input(Slice input) {
  CHECK(input_size_ == 0);
  CHECK(!close_input_flag_);
  CHECK(input.size() <= std::numeric_limits<uInt>::max());
  CHECK(impl_->stream_.avail_in == 0);
  input_size_ = input.size();
  impl_->stream_.avail_in = static_cast<uInt>(input.size());
  impl_->stream_.next_in = reinterpret_cast<Bytef *>(const_cast<char *>(input.data()));
}

void Gzip::set_output(MutableSlice output) {
  CHECK(output_size_ == 0);
  CHECK(output.size() <= std::numeric_limits<uInt>::max());
  CHECK(impl_->stream_.avail_out == 0);
  output_size_ = output.size();
  impl_->stream_.avail_out = static_cast<uInt>(output.size());
  impl_->stream_.next_out = reinterpret_cast<Bytef *>(output.data());
}

Result<Gzip::State> Gzip::run() {
  while (true) {
    int ret;
    if (mode_ == Mode::Decode) {
      ret = inflate(&impl_->stream_, Z_NO_FLUSH);
    } else {
      ret = deflate(&impl_->stream_, close_input_flag_ ? Z_FINISH : Z_NO_FLUSH);
    }

    if (ret == Z_OK) {
      return State::Running;
    }
    if (ret == Z_STREAM_END) {
      // TODO(now): fail if input is not empty;
      clear();
      return State::Done;
    }
    clear();
    return Status::Error(PSLICE() << "zlib error " << ret);
  }
}

size_t Gzip::left_input() const {
  return impl_->stream_.avail_in;
}
size_t Gzip::left_output() const {
  return impl_->stream_.avail_out;
}

void Gzip::init_common() {
  std::memset(&impl_->stream_, 0, sizeof(impl_->stream_));
  impl_->stream_.zalloc = Z_NULL;
  impl_->stream_.zfree = Z_NULL;
  impl_->stream_.opaque = Z_NULL;
  impl_->stream_.avail_in = 0;
  impl_->stream_.next_in = nullptr;
  impl_->stream_.avail_out = 0;
  impl_->stream_.next_out = nullptr;

  input_size_ = 0;
  output_size_ = 0;

  close_input_flag_ = false;
}

void Gzip::clear() {
  if (mode_ == Mode::Decode) {
    inflateEnd(&impl_->stream_);
  } else if (mode_ == Mode::Encode) {
    deflateEnd(&impl_->stream_);
  }
  mode_ = Mode::Empty;
}

Gzip::Gzip() : impl_(make_unique<Impl>()) {
}

Gzip::Gzip(Gzip &&other) noexcept : Gzip() {
  swap(other);
}

Gzip &Gzip::operator=(Gzip &&other) noexcept {
  CHECK(this != &other);
  clear();
  swap(other);
  return *this;
}

void Gzip::swap(Gzip &other) {
  using std::swap;
  swap(impl_, other.impl_);
  swap(input_size_, other.input_size_);
  swap(output_size_, other.output_size_);
  swap(close_input_flag_, other.close_input_flag_);
  swap(mode_, other.mode_);
}

Gzip::~Gzip() {
  clear();
}

BufferSlice gzdecode(Slice s) {
  Gzip gzip;
  gzip.init_decode().ensure();
  ChainBufferWriter message;
  gzip.set_input(s);
  gzip.close_input();
  double k = 2;
  gzip.set_output(message.prepare_append(static_cast<size_t>(static_cast<double>(s.size()) * k)));
  while (true) {
    auto r_state = gzip.run();
    if (r_state.is_error()) {
      return BufferSlice();
    }
    auto state = r_state.ok();
    if (state == Gzip::State::Done) {
      message.confirm_append(gzip.flush_output());
      break;
    }
    if (gzip.need_input()) {
      return BufferSlice();
    }
    if (gzip.need_output()) {
      message.confirm_append(gzip.flush_output());
      k *= 1.5;
      gzip.set_output(message.prepare_append(static_cast<size_t>(static_cast<double>(gzip.left_input()) * k)));
    }
  }
  return message.extract_reader().move_as_buffer_slice();
}

BufferSlice gzencode(Slice s, double max_compression_ratio) {
  Gzip gzip;
  gzip.init_encode().ensure();
  gzip.set_input(s);
  gzip.close_input();
  auto max_size = static_cast<size_t>(static_cast<double>(s.size()) * max_compression_ratio);
  BufferWriter message{max_size};
  gzip.set_output(message.prepare_append());
  auto r_state = gzip.run();
  if (r_state.is_error()) {
    return BufferSlice();
  }
  auto state = r_state.ok();
  if (state != Gzip::State::Done) {
    return BufferSlice();
  }
  message.confirm_append(gzip.flush_output());
  return message.as_buffer_slice();
}

}  // namespace td
#endif
