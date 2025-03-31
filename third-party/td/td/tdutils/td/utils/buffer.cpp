//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/buffer.h"

#include "td/utils/logging.h"
#include "td/utils/port/thread_local.h"

#include <cstddef>
#include <new>

// fixes https://bugs.llvm.org/show_bug.cgi?id=33723 for clang >= 3.6 + c++11 + libc++
#if TD_CLANG && _LIBCPP_VERSION
#define TD_OFFSETOF __builtin_offsetof
#else
#define TD_OFFSETOF offsetof
#endif

namespace td {

TD_THREAD_LOCAL BufferAllocator::BufferRawTls *BufferAllocator::buffer_raw_tls;  // static zero-initialized

std::atomic<size_t> BufferAllocator::buffer_mem;

int64 BufferAllocator::get_buffer_slice_size() {
  return 0;
}

size_t BufferAllocator::get_buffer_mem() {
  return buffer_mem;
}

BufferAllocator::WriterPtr BufferAllocator::create_writer(size_t size) {
  if (size < 512) {
    size = 512;
  }
  return create_writer_exact(size);
}

BufferAllocator::WriterPtr BufferAllocator::create_writer_exact(size_t size) {
  return WriterPtr(create_buffer_raw(size));
}

BufferAllocator::WriterPtr BufferAllocator::create_writer(size_t size, size_t prepend, size_t append) {
  auto ptr = create_writer(size + prepend + append);
  ptr->begin_ += prepend;
  ptr->end_ += prepend + size;
  return ptr;
}

BufferAllocator::ReaderPtr BufferAllocator::create_reader(size_t size) {
  if (size < 512) {
    return create_reader_fast(size);
  }
  auto ptr = create_writer_exact(size);
  ptr->end_ += (size + 7) & -8;
  return create_reader(ptr);
}

BufferAllocator::ReaderPtr BufferAllocator::create_reader_fast(size_t size) {
  size = (size + 7) & -8;

  init_thread_local<BufferRawTls>(buffer_raw_tls);

  auto buffer_raw = buffer_raw_tls->buffer_raw.get();
  if (buffer_raw == nullptr || buffer_raw->data_size_ - buffer_raw->end_.load(std::memory_order_relaxed) < size) {
    buffer_raw = create_buffer_raw(4096 * 4);
    buffer_raw_tls->buffer_raw = std::unique_ptr<BufferRaw, BufferAllocator::BufferRawDeleter>(buffer_raw);
  }
  buffer_raw->end_.fetch_add(size, std::memory_order_relaxed);
  buffer_raw->ref_cnt_.fetch_add(1, std::memory_order_acq_rel);
  return ReaderPtr(buffer_raw);
}

BufferAllocator::ReaderPtr BufferAllocator::create_reader(const WriterPtr &raw) {
  raw->was_reader_ = true;
  raw->ref_cnt_.fetch_add(1, std::memory_order_acq_rel);
  return ReaderPtr(raw.get());
}

BufferAllocator::ReaderPtr BufferAllocator::create_reader(const ReaderPtr &raw) {
  raw->ref_cnt_.fetch_add(1, std::memory_order_acq_rel);
  return ReaderPtr(raw.get());
}

void BufferAllocator::dec_ref_cnt(BufferRaw *ptr) {
  int left = ptr->ref_cnt_.fetch_sub(1, std::memory_order_acq_rel);
  if (left == 1) {
    auto buf_size = max(sizeof(BufferRaw), TD_OFFSETOF(BufferRaw, data_) + ptr->data_size_);
    buffer_mem -= buf_size;
    ptr->~BufferRaw();
    delete[] ptr;
  }
}

size_t ChainBufferReader::advance(size_t offset, MutableSlice dest) {
  LOG_CHECK(offset <= size()) << offset << " " << size() << " " << end_.offset() << " " << begin_.offset() << " "
                              << sync_flag_ << " " << dest.size();
  return begin_.advance(offset, dest);
}

BufferRaw *BufferAllocator::create_buffer_raw(size_t size) {
  size = (size + 7) & -8;

  auto buf_size = TD_OFFSETOF(BufferRaw, data_) + size;
  if (buf_size < sizeof(BufferRaw)) {
    buf_size = sizeof(BufferRaw);
  }
  buffer_mem += buf_size;
  auto *buffer_raw = reinterpret_cast<BufferRaw *>(new char[buf_size]);
  return new (buffer_raw) BufferRaw(size);
}

void BufferBuilder::append(BufferSlice slice) {
  if (append_inplace(slice.as_slice())) {
    return;
  }
  append_slow(std::move(slice));
}

void BufferBuilder::append(Slice slice) {
  if (append_inplace(slice)) {
    return;
  }
  append_slow(BufferSlice(slice));
}

void BufferBuilder::prepend(BufferSlice slice) {
  if (prepend_inplace(slice.as_slice())) {
    return;
  }
  prepend_slow(std::move(slice));
}

void BufferBuilder::prepend(Slice slice) {
  if (prepend_inplace(slice)) {
    return;
  }
  prepend_slow(BufferSlice(slice));
}

BufferSlice BufferBuilder::extract() {
  if (to_append_.empty() && to_prepend_.empty()) {
    return buffer_writer_.as_buffer_slice();
  }
  size_t total_size = size();
  BufferWriter writer(0, 0, total_size);
  std::move(*this).for_each([&](auto &&slice) {
    writer.prepare_append().truncate(slice.size()).copy_from(slice.as_slice());
    writer.confirm_append(slice.size());
  });
  *this = {};
  return writer.as_buffer_slice();
}

size_t BufferBuilder::size() const {
  size_t total_size = 0;
  for_each([&](auto &&slice) { total_size += slice.size(); });
  return total_size;
}

bool BufferBuilder::append_inplace(Slice slice) {
  if (!to_append_.empty()) {
    return false;
  }
  auto dest = buffer_writer_.prepare_append();
  if (dest.size() < slice.size()) {
    return false;
  }
  dest.remove_suffix(dest.size() - slice.size());
  dest.copy_from(slice);
  buffer_writer_.confirm_append(slice.size());
  return true;
}

void BufferBuilder::append_slow(BufferSlice slice) {
  to_append_.push_back(std::move(slice));
}

bool BufferBuilder::prepend_inplace(Slice slice) {
  if (!to_prepend_.empty()) {
    return false;
  }
  auto dest = buffer_writer_.prepare_prepend();
  if (dest.size() < slice.size()) {
    return false;
  }
  dest.remove_prefix(dest.size() - slice.size());
  dest.copy_from(slice);
  buffer_writer_.confirm_prepend(slice.size());
  return true;
}

void BufferBuilder::prepend_slow(BufferSlice slice) {
  to_prepend_.push_back(std::move(slice));
}

}  // namespace td
