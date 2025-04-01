//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/DbKey.h"

#include "td/utils/AesCtrByteFlow.h"
#include "td/utils/buffer.h"
#include "td/utils/BufferedFd.h"
#include "td/utils/ByteFlow.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/logging.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StorerBase.h"
#include "td/utils/UInt.h"

#include <functional>

namespace td {

extern int32 VERBOSITY_NAME(binlog);

struct BinlogInfo {
  bool was_created{false};
  uint64 last_event_id{0};
  bool is_encrypted{false};
  bool wrong_password{false};
  bool is_opened{false};
};

namespace detail {
class BinlogReader;
class BinlogEventsProcessor;
class BinlogEventsBuffer;
}  // namespace detail

class Binlog {
 public:
  enum class Error : int { WrongPassword = -1037284 };
  Binlog();
  Binlog(const Binlog &) = delete;
  Binlog &operator=(const Binlog &) = delete;
  Binlog(Binlog &&) = delete;
  Binlog &operator=(Binlog &&) = delete;
  ~Binlog();

  using Callback = std::function<void(const BinlogEvent &)>;
  Status init(string path, const Callback &callback, DbKey db_key = DbKey::empty(), DbKey old_db_key = DbKey::empty(),
              int32 dummy = -1, const Callback &debug_callback = Callback()) TD_WARN_UNUSED_RESULT;

  uint64 next_event_id() {
    return ++last_event_id_;
  }
  uint64 next_event_id(int32 shift) {
    auto res = last_event_id_ + 1;
    last_event_id_ += shift;
    return res;
  }
  uint64 peek_next_event_id() const {
    return last_event_id_ + 1;
  }

  bool empty() const {
    return fd_.empty();
  }

  uint64 add(int32 type, const Storer &storer) {
    auto event_id = next_event_id();
    add_raw_event(BinlogEvent::create_raw(event_id, type, 0, storer), {});
    return event_id;
  }

  uint64 rewrite(uint64 event_id, int32 type, const Storer &storer) {
    auto seq_no = next_event_id();
    add_raw_event(BinlogEvent::create_raw(event_id, type, BinlogEvent::Flags::Rewrite, storer), {});
    return seq_no;
  }

  uint64 erase(uint64 event_id) {
    auto seq_no = next_event_id();
    add_raw_event(
        BinlogEvent::create_raw(event_id, BinlogEvent::ServiceTypes::Empty, BinlogEvent::Flags::Rewrite, EmptyStorer()),
        {});
    return seq_no;
  }

  uint64 erase_batch(vector<uint64> event_ids) {
    if (event_ids.empty()) {
      return 0;
    }
    auto seq_no = next_event_id(0);
    for (auto event_id : event_ids) {
      erase(event_id);
    }
    return seq_no;
  }

  void add_raw_event(BufferSlice &&raw_event, BinlogDebugInfo info) {
    add_event(BinlogEvent(std::move(raw_event), info));
  }

  void add_event(BinlogEvent &&event);
  void sync(const char *source);
  void flush(const char *source);
  void lazy_flush();
  double need_flush_since() const {
    return need_flush_since_;
  }
  void change_key(DbKey new_db_key);

  Status close(bool need_sync = true) TD_WARN_UNUSED_RESULT;
  void close(Promise<> promise);
  Status close_and_destroy() TD_WARN_UNUSED_RESULT;
  static Status destroy(Slice path) TD_WARN_UNUSED_RESULT;

  CSlice get_path() const {
    return path_;
  }

  BinlogInfo get_info() const {  // works even after binlog was closed
    return info_;
  }

 private:
  BufferedFdBase<FileFd> fd_;
  ChainBufferWriter buffer_writer_;
  ChainBufferReader buffer_reader_;
  detail::BinlogReader *binlog_reader_ptr_ = nullptr;

  BinlogInfo info_;
  DbKey db_key_;
  bool db_key_used_ = false;
  DbKey old_db_key_;
  enum class EncryptionType { None, AesCtr } encryption_type_ = EncryptionType::None;

  // AesCtrEncryption
  string aes_ctr_key_salt_;
  UInt256 aes_ctr_key_;
  AesCtrState aes_ctr_state_;

  bool byte_flow_flag_ = false;
  ByteFlowSource byte_flow_source_;
  ByteFlowSink byte_flow_sink_;
  AesCtrByteFlow aes_xcode_byte_flow_;

  int64 fd_size_{0};
  uint64 fd_events_{0};
  string path_;
  vector<BinlogEvent> pending_events_;
  unique_ptr<detail::BinlogEventsProcessor> processor_;
  unique_ptr<detail::BinlogEventsBuffer> events_buffer_;
  bool in_flush_events_buffer_{false};
  uint64 last_event_id_{0};
  double need_flush_since_ = 0;
  double next_buffer_flush_time_ = 0;
  bool need_sync_{false};
  enum class State { Empty, Load, Reindex, Run } state_{State::Empty};

  static Result<FileFd> open_binlog(const string &path, int32 flags);
  size_t flush_events_buffer(bool force);
  void do_add_event(BinlogEvent &&event);
  void do_event(BinlogEvent &&event);
  Status load_binlog(const Callback &callback, const Callback &debug_callback = Callback()) TD_WARN_UNUSED_RESULT;
  void do_reindex();

  void update_encryption(Slice key, Slice iv);
  void reset_encryption();
  void update_read_encryption();
  void update_write_encryption();

  string debug_get_binlog_data(int64 begin_offset, int64 end_offset);
};

}  // namespace td
