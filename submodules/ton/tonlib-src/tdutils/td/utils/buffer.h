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

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Slice.h"

#include <atomic>
#include <limits>
#include <memory>

namespace td {

struct BufferRaw {
  explicit BufferRaw(size_t size) : data_size_(size) {
  }
  size_t data_size_;

  // Constant after first reader is created.
  // May be change by writer before it.
  // So writer may do prepends till there is no reader created.
  size_t begin_ = 0;

  // Write by writer.
  // Read by reader.
  std::atomic<size_t> end_{0};

  mutable std::atomic<int32> ref_cnt_{1};
  std::atomic<bool> has_writer_{true};
  bool was_reader_{false};

  alignas(4) unsigned char data_[1];
};

class BufferAllocator {
 public:
  class DeleteWriterPtr {
   public:
    void operator()(BufferRaw *ptr) {
      ptr->has_writer_.store(false, std::memory_order_release);
      dec_ref_cnt(ptr);
    }
  };
  class DeleteReaderPtr {
   public:
    void operator()(BufferRaw *ptr) {
      dec_ref_cnt(ptr);
    }
  };

  using WriterPtr = std::unique_ptr<BufferRaw, DeleteWriterPtr>;
  using ReaderPtr = std::unique_ptr<BufferRaw, DeleteReaderPtr>;

  static WriterPtr create_writer(size_t size);

  static WriterPtr create_writer(size_t size, size_t prepend, size_t append);

  static ReaderPtr create_reader(size_t size);

  static ReaderPtr create_reader(const WriterPtr &raw);

  static ReaderPtr create_reader(const ReaderPtr &raw);

  static size_t get_buffer_mem();

  static void clear_thread_local();

 private:
  static ReaderPtr create_reader_fast(size_t size);

  static WriterPtr create_writer_exact(size_t size);

  struct BufferRawDeleter {
    void operator()(BufferRaw *ptr) {
      dec_ref_cnt(ptr);
    }
  };
  struct BufferRawTls {
    std::unique_ptr<BufferRaw, BufferRawDeleter> buffer_raw;
  };

  static TD_THREAD_LOCAL BufferRawTls *buffer_raw_tls;

  static void dec_ref_cnt(BufferRaw *ptr);

  static BufferRaw *create_buffer_raw(size_t size);

  static std::atomic<size_t> buffer_mem;
};

using BufferWriterPtr = BufferAllocator::WriterPtr;
using BufferReaderPtr = BufferAllocator::ReaderPtr;

class BufferSlice {
 public:
  BufferSlice() = default;
  explicit BufferSlice(BufferReaderPtr buffer_ptr) : buffer_(std::move(buffer_ptr)) {
    if (is_null()) {
      return;
    }
    begin_ = buffer_->begin_;
    sync_with_writer();
  }
  BufferSlice(BufferReaderPtr buffer_ptr, size_t begin, size_t end)
      : buffer_(std::move(buffer_ptr)), begin_(begin), end_(end) {
  }

  explicit BufferSlice(size_t size) : buffer_(BufferAllocator::create_reader(size)) {
    end_ = buffer_->end_.load(std::memory_order_relaxed);
    begin_ = end_ - ((size + 7) & -8);
    end_ = begin_ + size;
  }

  explicit BufferSlice(Slice slice) : BufferSlice(slice.size()) {
    as_slice().copy_from(slice);
  }

  BufferSlice(const char *ptr, size_t size) : BufferSlice(Slice(ptr, size)) {
  }

  BufferSlice clone() const {
    if (is_null()) {
      return BufferSlice(BufferReaderPtr(), begin_, end_);
    }
    return BufferSlice(BufferAllocator::create_reader(buffer_), begin_, end_);
  }

  BufferSlice copy() const {
    if (is_null()) {
      return BufferSlice(BufferReaderPtr(), begin_, end_);
    }
    return BufferSlice(as_slice());
  }

  Slice as_slice() const {
    if (is_null()) {
      return Slice();
    }
    return Slice(buffer_->data_ + begin_, size());
  }

  operator Slice() const {
    return as_slice();
  }

  MutableSlice as_slice() {
    if (is_null()) {
      return MutableSlice();
    }
    return MutableSlice(buffer_->data_ + begin_, size());
  }

  Slice prepare_read() const {
    return as_slice();
  }

  Slice after(size_t offset) const {
    auto full = as_slice();
    full.remove_prefix(offset);
    return full;
  }

  bool confirm_read(size_t size) {
    begin_ += size;
    CHECK(begin_ <= end_);
    return begin_ == end_;
  }

  void truncate(size_t limit) {
    if (size() > limit) {
      end_ = begin_ + limit;
    }
  }

  BufferSlice from_slice(Slice slice) const {
    auto res = BufferSlice(BufferAllocator::create_reader(buffer_));
    res.begin_ = static_cast<size_t>(slice.ubegin() - buffer_->data_);
    res.end_ = static_cast<size_t>(slice.uend() - buffer_->data_);
    CHECK(buffer_->begin_ <= res.begin_);
    CHECK(res.begin_ <= res.end_);
    CHECK(res.end_ <= buffer_->end_.load(std::memory_order_relaxed));
    return res;
  }

  // like in std::string
  char *data() {
    return as_slice().data();
  }
  const char *data() const {
    return as_slice().data();
  }
  char operator[](size_t at) const {
    return as_slice()[at];
  }

  bool empty() const {
    return size() == 0;
  }

  bool is_null() const {
    return !buffer_;
  }

  size_t size() const {
    if (is_null()) {
      return 0;
    }
    return end_ - begin_;
  }

  // like in std::string
  size_t length() const {
    return size();
  }

  // set end_ into writer's end_
  size_t sync_with_writer() {
    CHECK(!is_null());
    auto old_end = end_;
    end_ = buffer_->end_.load(std::memory_order_acquire);
    return end_ - old_end;
  }
  bool is_writer_alive() const {
    CHECK(!is_null());
    return buffer_->has_writer_.load(std::memory_order_acquire);
  }
  void clear() {
    begin_ = 0;
    end_ = 0;
    buffer_ = nullptr;
  }

 private:
  BufferReaderPtr buffer_;
  size_t begin_ = 0;
  size_t end_ = 0;
};

template <class StorerT>
void store(const BufferSlice &buffer_slice, StorerT &storer) {
  storer.store_string(buffer_slice);
}

template <class ParserT>
void parse(BufferSlice &buffer_slice, ParserT &parser) {
  buffer_slice = parser.template fetch_string<BufferSlice>();
}

class BufferWriter {
 public:
  BufferWriter() = default;
  explicit BufferWriter(size_t size) : BufferWriter(BufferAllocator::create_writer(size)) {
  }
  BufferWriter(size_t size, size_t prepend, size_t append)
      : BufferWriter(BufferAllocator::create_writer(size, prepend, append)) {
  }
  BufferWriter(Slice slice, size_t prepend, size_t append)
      : BufferWriter(BufferAllocator::create_writer(slice.size(), prepend, append)) {
    as_slice().copy_from(slice);
  }
  explicit BufferWriter(BufferWriterPtr buffer_ptr) : buffer_(std::move(buffer_ptr)) {
  }

  BufferSlice as_buffer_slice() const {
    return BufferSlice(BufferAllocator::create_reader(buffer_));
  }
  bool is_null() const {
    return !buffer_;
  }
  bool empty() const {
    return size() == 0;
  }
  size_t size() const {
    if (is_null()) {
      return 0;
    }
    return buffer_->end_.load(std::memory_order_relaxed) - buffer_->begin_;
  }
  MutableSlice as_slice() {
    auto end = buffer_->end_.load(std::memory_order_relaxed);
    return MutableSlice(buffer_->data_ + buffer_->begin_, buffer_->data_ + end);
  }
  Slice as_slice() const {
    auto end = buffer_->end_.load(std::memory_order_relaxed);
    return Slice(buffer_->data_ + buffer_->begin_, buffer_->data_ + end);
  }

  MutableSlice prepare_prepend() {
    if (is_null()) {
      return MutableSlice();
    }
    CHECK(!buffer_->was_reader_);
    return MutableSlice(buffer_->data_, buffer_->begin_);
  }
  MutableSlice prepare_append() {
    if (is_null()) {
      return MutableSlice();
    }
    auto end = buffer_->end_.load(std::memory_order_relaxed);
    return MutableSlice(buffer_->data_ + end, buffer_->data_size_ - end);
  }
  void confirm_append(size_t size) {
    if (is_null()) {
      CHECK(size == 0);
      return;
    }
    auto new_end = buffer_->end_.load(std::memory_order_relaxed) + size;
    CHECK(new_end <= buffer_->data_size_);
    buffer_->end_.store(new_end, std::memory_order_release);
  }
  void confirm_prepend(size_t size) {
    if (is_null()) {
      CHECK(size == 0);
      return;
    }
    CHECK(buffer_->begin_ >= size);
    buffer_->begin_ -= size;
  }

 private:
  BufferWriterPtr buffer_;
};

struct ChainBufferNode {
  friend struct DeleteWriterPtr;
  struct DeleteWriterPtr {
    void operator()(ChainBufferNode *ptr) {
      ptr->has_writer_.store(false, std::memory_order_release);
      dec_ref_cnt(ptr);
    }
  };
  friend struct DeleteReaderPtr;
  struct DeleteReaderPtr {
    void operator()(ChainBufferNode *ptr) {
      dec_ref_cnt(ptr);
    }
  };
  using WriterPtr = std::unique_ptr<ChainBufferNode, DeleteWriterPtr>;
  using ReaderPtr = std::unique_ptr<ChainBufferNode, DeleteReaderPtr>;

  static WriterPtr make_writer_ptr(ChainBufferNode *ptr) {
    ptr->ref_cnt_.store(1, std::memory_order_relaxed);
    ptr->has_writer_.store(true, std::memory_order_relaxed);
    return WriterPtr(ptr);
  }
  static ReaderPtr make_reader_ptr(ChainBufferNode *ptr) {
    ptr->ref_cnt_.fetch_add(1, std::memory_order_acq_rel);
    return ReaderPtr(ptr);
  }

  bool has_writer() {
    return has_writer_.load(std::memory_order_acquire);
  }

  bool unique() {
    return ref_cnt_.load(std::memory_order_acquire) == 1;
  }

  ChainBufferNode(BufferSlice slice, bool sync_flag) : slice_(std::move(slice)), sync_flag_(sync_flag) {
  }

  // reader
  // There are two options
  // 1. Fixed slice of Buffer
  // 2. Slice with non-fixed right end
  // In each case slice_ is const. Reader should read it and use sync_with_writer on its own copy.
  const BufferSlice slice_;
  const bool sync_flag_{false};  // should we call slice_.sync_with_writer or not.

  // writer
  ReaderPtr next_{nullptr};

 private:
  std::atomic<int> ref_cnt_{0};
  std::atomic<bool> has_writer_{false};

  static void clear_nonrecursive(ReaderPtr ptr) {
    while (ptr && ptr->unique()) {
      ptr = std::move(ptr->next_);
    }
  }
  static void dec_ref_cnt(ChainBufferNode *ptr) {
    int left = --ptr->ref_cnt_;
    if (left == 0) {
      clear_nonrecursive(std::move(ptr->next_));
      // TODO(refact): move memory management into allocator (?)
      delete ptr;
    }
  }
};

using ChainBufferNodeWriterPtr = ChainBufferNode::WriterPtr;
using ChainBufferNodeReaderPtr = ChainBufferNode::ReaderPtr;

class ChainBufferNodeAllocator {
 public:
  static ChainBufferNodeWriterPtr create(BufferSlice slice, bool sync_flag) {
    auto *ptr = new ChainBufferNode(std::move(slice), sync_flag);
    return ChainBufferNode::make_writer_ptr(ptr);
  }
  static ChainBufferNodeReaderPtr clone(const ChainBufferNodeReaderPtr &ptr) {
    if (!ptr) {
      return ChainBufferNodeReaderPtr();
    }
    return ChainBufferNode::make_reader_ptr(ptr.get());
  }
  static ChainBufferNodeReaderPtr clone(ChainBufferNodeWriterPtr &ptr) {
    if (!ptr) {
      return ChainBufferNodeReaderPtr();
    }
    return ChainBufferNode::make_reader_ptr(ptr.get());
  }
};

class ChainBufferIterator {
 public:
  ChainBufferIterator() = default;
  explicit ChainBufferIterator(ChainBufferNodeReaderPtr head) : head_(std::move(head)) {
    load_head();
  }
  ChainBufferIterator clone() const {
    return ChainBufferIterator(ChainBufferNodeAllocator::clone(head_), reader_.clone(), need_sync_, offset_);
  }

  size_t offset() const {
    return offset_;
  }

  void clear() {
    *this = ChainBufferIterator();
  }

  Slice prepare_read() {
    if (!head_) {
      return Slice();
    }
    while (true) {
      auto res = reader_.prepare_read();
      if (!res.empty()) {
        return res;
      }
      auto has_writer = head_->has_writer();
      if (need_sync_) {
        reader_.sync_with_writer();
        res = reader_.prepare_read();
        if (!res.empty()) {
          return res;
        }
      }
      if (has_writer) {
        return Slice();
      }
      head_ = ChainBufferNodeAllocator::clone(head_->next_);
      if (!head_) {
        return Slice();
      }
      load_head();
    }
  }

  // returns only head
  BufferSlice read_as_buffer_slice(size_t limit) {
    prepare_read();
    auto res = reader_.clone();
    res.truncate(limit);
    confirm_read(res.size());
    return res;
  }

  const BufferSlice &head() const {
    return reader_;
  }

  void confirm_read(size_t size) {
    offset_ += size;
    reader_.confirm_read(size);
  }

  void advance_till_end() {
    while (true) {
      auto ready = prepare_read();
      if (ready.empty()) {
        break;
      }
      confirm_read(ready.size());
    }
  }

  size_t advance(size_t offset, MutableSlice dest = MutableSlice()) {
    size_t skipped = 0;
    while (offset != 0) {
      auto ready = prepare_read();
      if (ready.empty()) {
        break;
      }

      // read no more than offset
      ready.truncate(offset);
      offset -= ready.size();
      skipped += ready.size();

      // copy to dest if possible
      auto to_dest_size = min(ready.size(), dest.size());
      if (to_dest_size != 0) {
        dest.copy_from(ready.substr(0, to_dest_size));
        dest.remove_prefix(to_dest_size);
      }

      confirm_read(ready.size());
    }
    return skipped;
  }

 private:
  ChainBufferNodeReaderPtr head_;
  BufferSlice reader_;      // copy of head_->slice_
  bool need_sync_ = false;  // copy of head_->sync_flag_
  size_t offset_ = 0;       // position in the union of all nodes

  ChainBufferIterator(ChainBufferNodeReaderPtr head, BufferSlice reader, bool need_sync, size_t offset)
      : head_(std::move(head)), reader_(std::move(reader)), need_sync_(need_sync), offset_(offset) {
  }
  void load_head() {
    reader_ = head_->slice_.clone();
    need_sync_ = head_->sync_flag_;
  }
};

class ChainBufferReader {
 public:
  ChainBufferReader() = default;
  explicit ChainBufferReader(ChainBufferNodeReaderPtr head)
      : begin_(ChainBufferNodeAllocator::clone(head)), end_(std::move(head)) {
    end_.advance_till_end();
  }
  ChainBufferReader(ChainBufferIterator begin, ChainBufferIterator end, bool sync_flag)
      : begin_(std::move(begin)), end_(std::move(end)), sync_flag_(sync_flag) {
  }
  ChainBufferReader(ChainBufferNodeReaderPtr head, size_t size)
      : begin_(ChainBufferNodeAllocator::clone(head)), end_(std::move(head)) {
    auto advanced = end_.advance(size);
    CHECK(advanced == size);
  }
  ChainBufferReader(ChainBufferReader &&) = default;
  ChainBufferReader &operator=(ChainBufferReader &&) = default;
  ChainBufferReader(const ChainBufferReader &) = delete;
  ChainBufferReader &operator=(const ChainBufferReader &) = delete;
  ~ChainBufferReader() = default;

  ChainBufferReader clone() {
    return ChainBufferReader(begin_.clone(), end_.clone(), sync_flag_);
  }

  Slice prepare_read() {
    auto res = begin_.prepare_read();
    res.truncate(size());
    return res;
  }

  void confirm_read(size_t size) {
    CHECK(size <= this->size());
    begin_.confirm_read(size);
  }

  size_t advance(size_t offset, MutableSlice dest = MutableSlice()) {
    CHECK(offset <= size());
    return begin_.advance(offset, dest);
  }

  size_t size() const {
    return end_.offset() - begin_.offset();
  }
  bool empty() const {
    return size() == 0;
  }

  void sync_with_writer() {
    if (sync_flag_) {
      end_.advance_till_end();
    }
  }
  void advance_end(size_t size) {
    end_.advance(size);
  }
  const ChainBufferIterator &begin() {
    return begin_;
  }
  const ChainBufferIterator &end() {
    return end_;
  }

  // Return [begin_, tail.begin_)
  // *this = tail
  ChainBufferReader cut_head(ChainBufferIterator pos) TD_WARN_UNUSED_RESULT {
    auto tmp = begin_.clone();
    begin_ = pos.clone();
    return ChainBufferReader(std::move(tmp), std::move(pos), false);
  }

  ChainBufferReader cut_head(size_t offset) TD_WARN_UNUSED_RESULT {
    LOG_CHECK(offset <= size()) << offset << " " << size();
    auto it = begin_.clone();
    it.advance(offset);
    return cut_head(std::move(it));
  }

  BufferSlice move_as_buffer_slice() {
    BufferSlice res;
    if (begin_.head().size() >= size()) {
      res = begin_.read_as_buffer_slice(size());
    } else {
      auto save_size = size();
      res = BufferSlice{save_size};
      advance(save_size, res.as_slice());
    }
    *this = ChainBufferReader();
    return res;
  }

  BufferSlice read_as_buffer_slice(size_t limit = std::numeric_limits<size_t>::max()) {
    return begin_.read_as_buffer_slice(min(limit, size()));
  }

 private:
  ChainBufferIterator begin_;  // use it for prepare_read. Fix result with size()
  ChainBufferIterator end_;    // keep end as far as we can. use it for size()
  bool sync_flag_ = true;      // auto sync of end_

  // 1. We have fixed size. Than end_ is useless.
  // 2. No fixed size. One has to sync end_ with end_.advance_till_end() in order to calculate size.
};

class ChainBufferWriter {
 public:
  ChainBufferWriter() {
    init();
  }

  void init(size_t size = 0) {
    writer_ = BufferWriter(size);
    tail_ = ChainBufferNodeAllocator::create(writer_.as_buffer_slice(), true);
    head_ = ChainBufferNodeAllocator::clone(tail_);
  }

  MutableSlice prepare_append(size_t hint = 0) {
    CHECK(!empty());
    auto res = prepare_append_inplace();
    if (res.empty()) {
      return prepare_append_alloc(hint);
    }
    return res;
  }
  MutableSlice prepare_append_at_least(size_t size) {
    CHECK(!empty());
    auto res = prepare_append_inplace();
    if (res.size() < size) {
      return prepare_append_alloc(size);
    }
    return res;
  }
  MutableSlice prepare_append_inplace() {
    CHECK(!empty());
    return writer_.prepare_append();
  }
  MutableSlice prepare_append_alloc(size_t hint = 0) {
    CHECK(!empty());
    if (hint < (1 << 10)) {
      hint = 1 << 12;
    }
    BufferWriter new_writer(hint);
    auto new_tail = ChainBufferNodeAllocator::create(new_writer.as_buffer_slice(), true);
    tail_->next_ = ChainBufferNodeAllocator::clone(new_tail);
    writer_ = std::move(new_writer);
    tail_ = std::move(new_tail);  // release tail_
    return writer_.prepare_append();
  }
  void confirm_append(size_t size) {
    CHECK(!empty());
    writer_.confirm_append(size);
  }

  void append(Slice slice, size_t hint = 0) {
    while (!slice.empty()) {
      auto ready = prepare_append(td::max(slice.size(), hint));
      auto shift = min(ready.size(), slice.size());
      ready.copy_from(slice.substr(0, shift));
      confirm_append(shift);
      slice.remove_prefix(shift);
    }
  }

  void append(BufferSlice slice) {
    auto ready = prepare_append_inplace();
    // TODO(perf): we have to store some stats in ChainBufferWriter
    // for better append logic
    if (slice.size() < (1 << 8) || ready.size() >= slice.size()) {
      return append(slice.as_slice());
    }

    auto new_tail = ChainBufferNodeAllocator::create(std::move(slice), false);
    tail_->next_ = ChainBufferNodeAllocator::clone(new_tail);
    writer_ = BufferWriter();
    tail_ = std::move(new_tail);  // release tail_
  }

  void append(ChainBufferReader &&reader) {
    while (!reader.empty()) {
      append(reader.read_as_buffer_slice());
    }
  }
  void append(ChainBufferReader &reader) {
    while (!reader.empty()) {
      append(reader.read_as_buffer_slice());
    }
  }

  ChainBufferReader extract_reader() {
    CHECK(head_);
    return ChainBufferReader(std::move(head_));
  }

 private:
  bool empty() const {
    return !tail_;
  }

  ChainBufferNodeReaderPtr head_;
  ChainBufferNodeWriterPtr tail_;
  BufferWriter writer_;
};

class BufferBuilder {
 public:
  BufferBuilder() = default;
  BufferBuilder(Slice slice, size_t prepend_size, size_t append_size)
      : buffer_writer_(slice, prepend_size, append_size) {
  }
  explicit BufferBuilder(BufferWriter &&buffer_writer) : buffer_writer_(std::move(buffer_writer)) {
  }

  void append(BufferSlice slice);
  void append(Slice slice);

  void prepend(BufferSlice slice);
  void prepend(Slice slice);

  template <class F>
  void for_each(F &&f) const & {
    for (auto &slice : reversed(to_prepend_)) {
      f(slice.as_slice());
    }
    if (!buffer_writer_.empty()) {
      f(buffer_writer_.as_slice());
    }
    for (auto &slice : to_append_) {
      f(slice.as_slice());
    }
  }
  template <class F>
  void for_each(F &&f) && {
    for (auto &slice : reversed(to_prepend_)) {
      f(std::move(slice));
    }
    if (!buffer_writer_.empty()) {
      f(buffer_writer_.as_buffer_slice());
    }
    for (auto &slice : to_append_) {
      f(std::move(slice));
    }
  }
  size_t size() const;

  BufferSlice extract();

 private:
  BufferWriter buffer_writer_;
  std::vector<BufferSlice> to_append_;
  std::vector<BufferSlice> to_prepend_;

  bool append_inplace(Slice slice);
  void append_slow(BufferSlice slice);
  bool prepend_inplace(Slice slice);
  void prepend_slow(BufferSlice slice);
};

inline Slice as_slice(const BufferSlice &value) {
  return value.as_slice();
}
inline MutableSlice as_slice(BufferSlice &value) {
  return value.as_slice();
}
inline MutableSlice as_mutable_slice(BufferSlice &value) {
  return value.as_slice();
}

}  // namespace td
