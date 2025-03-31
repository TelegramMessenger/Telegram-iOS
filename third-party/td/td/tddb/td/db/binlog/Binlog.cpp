//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/binlog/Binlog.h"

#include "td/db/binlog/detail/BinlogEventsBuffer.h"
#include "td/db/binlog/detail/BinlogEventsProcessor.h"

#include "td/utils/buffer.h"
#include "td/utils/format.h"
#include "td/utils/misc.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/port/sleep.h"
#include "td/utils/port/Stat.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_parsers.h"

namespace td {
namespace detail {
struct AesCtrEncryptionEvent {
  static constexpr size_t min_salt_size() {
    return 16;  // 256 bits
  }
  static constexpr size_t default_salt_size() {
    return 32;  // 256 bits
  }
  static constexpr size_t key_size() {
    return 32;  // 256 bits
  }
  static constexpr size_t iv_size() {
    return 16;  // 128 bits
  }
  static constexpr size_t hash_size() {
    return 32;  // 256 bits
  }
  static constexpr size_t kdf_iteration_count() {
    return 60002;
  }
  static constexpr size_t kdf_fast_iteration_count() {
    return 2;
  }

  string key_salt_;
  string iv_;
  string key_hash_;

  string generate_key(const DbKey &db_key) const {
    CHECK(!db_key.is_empty());
    string key(key_size(), '\0');
    size_t iteration_count = kdf_iteration_count();
    if (db_key.is_raw_key()) {
      iteration_count = kdf_fast_iteration_count();
    }
    pbkdf2_sha256(db_key.data(), key_salt_, narrow_cast<int>(iteration_count), key);
    return key;
  }

  static string generate_hash(Slice key) {
    string hash(hash_size(), '\0');
    hmac_sha256(key, "cucumbers everywhere", hash);
    return hash;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    using td::store;
    BEGIN_STORE_FLAGS();
    END_STORE_FLAGS();
    store(key_salt_, storer);
    store(iv_, storer);
    store(key_hash_, storer);
  }
  template <class ParserT>
  void parse(ParserT &&parser) {
    using td::parse;
    BEGIN_PARSE_FLAGS();
    END_PARSE_FLAGS();
    parse(key_salt_, parser);
    parse(iv_, parser);
    parse(key_hash_, parser);
  }
};

class BinlogReader {
 public:
  explicit BinlogReader(ChainBufferReader *input) : input_(input) {
  }
  void set_input(ChainBufferReader *input, bool is_encrypted, int64 expected_size) {
    input_ = input;
    is_encrypted_ = is_encrypted;
    expected_size_ = expected_size;
  }

  ChainBufferReader *input() {
    return input_;
  }

  int64 offset() const {
    return offset_;
  }
  Result<size_t> read_next(BinlogEvent *event) {
    if (state_ == State::ReadLength) {
      if (input_->size() < 4) {
        return 4;
      }
      auto it = input_->clone();

      char buf[4];
      it.advance(4, MutableSlice(buf, 4));
      size_ = static_cast<size_t>(TlParser(Slice(buf, 4)).fetch_int());

      if (size_ > BinlogEvent::MAX_SIZE) {
        return Status::Error(PSLICE() << "Too big event " << tag("size", size_));
      }
      if (size_ < BinlogEvent::MIN_SIZE) {
        return Status::Error(PSLICE() << "Too small event " << tag("size", size_));
      }
      if (size_ % 4 != 0) {
        return Status::Error(-2, PSLICE() << "Event of size " << size_ << " at offset " << offset() << " out of "
                                          << expected_size_ << ' ' << tag("is_encrypted", is_encrypted_)
                                          << format::as_hex_dump<4>(Slice(input_->prepare_read().truncate(28))));
      }
      state_ = State::ReadEvent;
    }

    if (input_->size() < size_) {
      return size_;
    }

    event->debug_info_ = BinlogDebugInfo{__FILE__, __LINE__};
    auto buffer_slice = input_->cut_head(size_).move_as_buffer_slice();
    event->init(buffer_slice.as_slice().str());
    TRY_STATUS(event->validate());
    offset_ += size_;
    event->offset_ = offset_;
    state_ = State::ReadLength;
    return 0;
  }

 private:
  ChainBufferReader *input_;
  enum class State { ReadLength, ReadEvent };
  State state_ = State::ReadLength;
  size_t size_{0};
  int64 offset_{0};
  int64 expected_size_{0};
  bool is_encrypted_{false};
};

static int64 file_size(CSlice path) {
  auto r_stat = stat(path);
  if (r_stat.is_error()) {
    return 0;
  }
  return r_stat.ok().size_;
}
}  // namespace detail

int32 VERBOSITY_NAME(binlog) = VERBOSITY_NAME(DEBUG) + 8;

Binlog::Binlog() = default;

Binlog::~Binlog() {
  close().ignore();
}

Result<FileFd> Binlog::open_binlog(const string &path, int32 flags) {
  TRY_RESULT(fd, FileFd::open(path, flags));
  TRY_STATUS(fd.lock(FileFd::LockFlags::Write, path, 100));
  return std::move(fd);
}

Status Binlog::init(string path, const Callback &callback, DbKey db_key, DbKey old_db_key, int32 dummy,
                    const Callback &debug_callback) {
  close().ignore();

  db_key_ = std::move(db_key);
  old_db_key_ = std::move(old_db_key);

  processor_ = make_unique<detail::BinlogEventsProcessor>();
  // Turn off BinlogEventsBuffer
  // events_buffer_ = make_unique<detail::BinlogEventsBuffer>();

  // try to restore binlog from regenerated version
  if (stat(path).is_error()) {
    rename(PSLICE() << path << ".new", path).ignore();
  }

  info_ = BinlogInfo();
  info_.was_created = stat(path).is_error();

  TRY_RESULT(fd, open_binlog(path, FileFd::Flags::Read | FileFd::Flags::Write | FileFd::Flags::Create));
  fd_ = BufferedFdBase<FileFd>(std::move(fd));
  fd_size_ = 0;
  path_ = std::move(path);

  auto status = load_binlog(callback, debug_callback);
  if (status.is_error()) {
    close().ignore();
    return status;
  }
  info_.last_event_id = processor_->last_event_id();
  last_event_id_ = processor_->last_event_id();
  if (info_.wrong_password) {
    close().ignore();
    return Status::Error(static_cast<int>(Error::WrongPassword), "Wrong password");
  }

  if ((!db_key_.is_empty() && !db_key_used_) || (db_key_.is_empty() && encryption_type_ != EncryptionType::None)) {
    aes_ctr_key_salt_ = string();
    do_reindex();
  }

  info_.is_opened = true;
  return Status::OK();
}

void Binlog::add_event(BinlogEvent &&event) {
  if (event.size_ % 4 != 0) {
    LOG(FATAL) << "Trying to add event with bad size " << event.public_to_string();
  }

  if (!events_buffer_) {
    do_add_event(std::move(event));
  } else {
    events_buffer_->add_event(std::move(event));
  }
  lazy_flush();

  if (state_ == State::Run) {
    auto fd_size = fd_size_;
    if (events_buffer_) {
      fd_size += events_buffer_->size();
    }
    auto need_reindex = [&](int64 min_size, int rate) {
      return fd_size > min_size && fd_size / rate > processor_->total_raw_events_size();
    };
    if (need_reindex(50000, 5) || need_reindex(100000, 4) || need_reindex(300000, 3) || need_reindex(500000, 2)) {
      LOG(INFO) << tag("fd_size", format::as_size(fd_size))
                << tag("total events size", format::as_size(processor_->total_raw_events_size()));
      do_reindex();
    }
  }
}

size_t Binlog::flush_events_buffer(bool force) {
  if (!events_buffer_) {
    return 0;
  }
  if (!force && !events_buffer_->need_flush()) {
    return events_buffer_->size();
  }
  CHECK(!in_flush_events_buffer_);
  in_flush_events_buffer_ = true;
  events_buffer_->flush([&](BinlogEvent &&event) { this->do_add_event(std::move(event)); });
  in_flush_events_buffer_ = false;
  return 0;
}

void Binlog::do_add_event(BinlogEvent &&event) {
  if (event.flags_ & BinlogEvent::Flags::Partial) {
    event.flags_ &= ~BinlogEvent::Flags::Partial;
    pending_events_.emplace_back(std::move(event));
  } else {
    for (auto &pending_event : pending_events_) {
      do_event(std::move(pending_event));
    }
    pending_events_.clear();
    do_event(std::move(event));
  }
}

Status Binlog::close(bool need_sync) {
  if (fd_.empty()) {
    return Status::OK();
  }
  if (need_sync) {
    sync("close");
  } else {
    flush("close");
  }

  fd_.lock(FileFd::LockFlags::Unlock, path_, 1).ensure();
  fd_.close();
  path_.clear();
  info_.is_opened = false;
  need_sync_ = false;
  return Status::OK();
}

void Binlog::close(Promise<> promise) {
  TRY_STATUS_PROMISE(promise, close());
  promise.set_value({});
}

void Binlog::change_key(DbKey new_db_key) {
  db_key_ = std::move(new_db_key);
  aes_ctr_key_salt_ = string();
  do_reindex();
}

Status Binlog::close_and_destroy() {
  auto path = path_;
  auto close_status = close(false);
  destroy(path).ignore();
  return close_status;
}

Status Binlog::destroy(Slice path) {
  unlink(PSLICE() << path << ".new").ignore();  // delete regenerated version first to avoid it becoming main version
  unlink(PSLICE() << path).ignore();
  return Status::OK();
}

void Binlog::do_event(BinlogEvent &&event) {
  auto event_size = event.raw_event_.size();

  if (state_ == State::Run || state_ == State::Reindex) {
    auto validate_status = event.validate();
    if (validate_status.is_error()) {
      LOG(FATAL) << "Failed to validate binlog event " << validate_status << " "
                 << format::as_hex_dump<4>(as_slice(event.raw_event_).truncate(28));
    }
    VLOG(binlog) << "Write binlog event: " << format::cond(state_ == State::Reindex, "[reindex] ")
                 << event.public_to_string();
    buffer_writer_.append(as_slice(event.raw_event_));
  }

  if (event.type_ < 0) {
    if (event.type_ == BinlogEvent::ServiceTypes::AesCtrEncryption) {
      detail::AesCtrEncryptionEvent encryption_event;
      encryption_event.parse(TlParser(event.get_data()));

      string key;
      if (aes_ctr_key_salt_ == encryption_event.key_salt_) {
        key = as_slice(aes_ctr_key_).str();
      } else if (!db_key_.is_empty()) {
        key = encryption_event.generate_key(db_key_);
      }

      if (detail::AesCtrEncryptionEvent::generate_hash(key) != encryption_event.key_hash_) {
        CHECK(state_ == State::Load);
        if (!old_db_key_.is_empty()) {
          key = encryption_event.generate_key(old_db_key_);
          if (detail::AesCtrEncryptionEvent::generate_hash(key) != encryption_event.key_hash_) {
            info_.wrong_password = true;
          }
        } else {
          info_.wrong_password = true;
        }
      } else {
        db_key_used_ = true;
      }

      encryption_type_ = EncryptionType::AesCtr;

      aes_ctr_key_salt_ = encryption_event.key_salt_;
      update_encryption(key, encryption_event.iv_);

      if (state_ == State::Load) {
        update_read_encryption();
        LOG(INFO) << "Load: init encryption";
      } else {
        CHECK(state_ == State::Reindex);
        flush("do_event");
        update_write_encryption();
        //LOG(INFO) << format::cond(state_ == State::Run, "Run", "Reindex") << ": init encryption";
      }
    }
  }

  if (state_ != State::Reindex) {
    auto status = processor_->add_event(std::move(event));
    if (status.is_error()) {
      auto old_size = detail::file_size(path_);
      auto data = debug_get_binlog_data(fd_size_, old_size);
      if (state_ == State::Load) {
        fd_.seek(fd_size_).ensure();
        fd_.truncate_to_current_position(fd_size_).ensure();

        if (data.empty()) {
          return;
        }
      }

      LOG(FATAL) << "Truncate binlog \"" << path_ << "\" from size " << old_size << " to size " << fd_size_
                 << " in state " << static_cast<int32>(state_) << " due to error: " << status << " after reading "
                 << data;
    }
  }

  fd_events_++;
  fd_size_ += event_size;
}

void Binlog::sync(const char *source) {
  flush(source);
  if (need_sync_) {
    LOG(INFO) << "Sync binlog from " << source;
    auto status = fd_.sync();
    LOG_IF(FATAL, status.is_error()) << "Failed to sync binlog: " << status;
    need_sync_ = false;
  }
}

void Binlog::flush(const char *source) {
  if (state_ == State::Load) {
    return;
  }
  LOG(DEBUG) << "Flush binlog from " << source;
  flush_events_buffer(true);
  // NB: encryption happens during flush
  if (byte_flow_flag_) {
    byte_flow_source_.wakeup();
  }
  auto r_written = fd_.flush_write();
  r_written.ensure();
  auto written = r_written.ok();
  if (written > 0) {
    need_sync_ = true;
  }
  need_flush_since_ = 0;
  LOG_IF(FATAL, fd_.need_flush_write()) << "Failed to flush binlog";

  if (state_ == State::Run && Time::now() > next_buffer_flush_time_) {
    VLOG(binlog) << "Flush write buffer";
    buffer_writer_ = ChainBufferWriter();
    buffer_reader_ = buffer_writer_.extract_reader();
    if (encryption_type_ == EncryptionType::AesCtr) {
      aes_ctr_state_ = aes_xcode_byte_flow_.move_aes_ctr_state();
    }
    update_write_encryption();
    next_buffer_flush_time_ = Time::now() + 1.0;
  }
}

void Binlog::lazy_flush() {
  size_t events_buffer_size = flush_events_buffer(false /*force*/);
  buffer_reader_.sync_with_writer();
  auto size = buffer_reader_.size() + events_buffer_size;
  if (size > (1 << 14)) {
    flush("lazy_flush");
  } else if (size > 0 && need_flush_since_ == 0) {
    need_flush_since_ = Time::now_cached();
  }
}

void Binlog::update_read_encryption() {
  CHECK(binlog_reader_ptr_);
  switch (encryption_type_) {
    case EncryptionType::None: {
      auto r_file_size = fd_.get_size();
      r_file_size.ensure();
      binlog_reader_ptr_->set_input(&buffer_reader_, false, r_file_size.ok());
      byte_flow_flag_ = false;
      break;
    }
    case EncryptionType::AesCtr: {
      byte_flow_source_ = ByteFlowSource(&buffer_reader_);
      aes_xcode_byte_flow_ = AesCtrByteFlow();
      aes_xcode_byte_flow_.init(std::move(aes_ctr_state_));
      byte_flow_sink_ = ByteFlowSink();
      byte_flow_source_ >> aes_xcode_byte_flow_ >> byte_flow_sink_;
      byte_flow_flag_ = true;
      auto r_file_size = fd_.get_size();
      r_file_size.ensure();
      binlog_reader_ptr_->set_input(byte_flow_sink_.get_output(), true, r_file_size.ok());
      break;
    }
  }
}

void Binlog::update_write_encryption() {
  switch (encryption_type_) {
    case EncryptionType::None: {
      fd_.set_output_reader(&buffer_reader_);
      byte_flow_flag_ = false;
      break;
    }
    case EncryptionType::AesCtr: {
      byte_flow_source_ = ByteFlowSource(&buffer_reader_);
      aes_xcode_byte_flow_ = AesCtrByteFlow();
      aes_xcode_byte_flow_.init(std::move(aes_ctr_state_));
      byte_flow_sink_ = ByteFlowSink();
      byte_flow_source_ >> aes_xcode_byte_flow_ >> byte_flow_sink_;
      byte_flow_flag_ = true;
      fd_.set_output_reader(byte_flow_sink_.get_output());
      break;
    }
  }
}

Status Binlog::load_binlog(const Callback &callback, const Callback &debug_callback) {
  state_ = State::Load;

  buffer_writer_ = ChainBufferWriter();
  buffer_reader_ = buffer_writer_.extract_reader();
  fd_.set_input_writer(&buffer_writer_);
  detail::BinlogReader reader{nullptr};
  binlog_reader_ptr_ = &reader;

  update_read_encryption();

  fd_.get_poll_info().add_flags(PollFlags::Read());
  info_.wrong_password = false;
  while (true) {
    BinlogEvent event;
    auto r_need_size = reader.read_next(&event);
    if (r_need_size.is_error()) {
      if (r_need_size.error().code() == -2) {
        auto old_size = detail::file_size(path_);
        auto offset = reader.offset();
        auto data = debug_get_binlog_data(offset, old_size);
        fd_.seek(offset).ensure();
        fd_.truncate_to_current_position(offset).ensure();
        if (data.empty()) {
          break;
        }
        LOG(FATAL) << "Truncate binlog \"" << path_ << "\" from size " << old_size << " to size " << offset
                   << " due to error: " << r_need_size.error() << " after reading " << data;
      }
      LOG(ERROR) << r_need_size.error();
      break;
    }
    auto need_size = r_need_size.move_as_ok();
    // LOG(ERROR) << "Need size = " << need_size;
    if (need_size == 0) {
      if (debug_callback) {
        debug_callback(event);
      }
      do_add_event(std::move(event));
      if (info_.wrong_password) {
        return Status::OK();
      }
    } else {
      TRY_STATUS(fd_.flush_read(max(need_size, static_cast<size_t>(4096))));
      buffer_reader_.sync_with_writer();
      if (byte_flow_flag_) {
        byte_flow_source_.wakeup();
      }
      if (reader.input()->size() < need_size) {
        break;
      }
    }
  }

  auto offset = processor_->offset();
  CHECK(offset >= 0);
  processor_->for_each([&](BinlogEvent &event) {
    VLOG(binlog) << "Replay binlog event: " << event.public_to_string();
    if (callback) {
      callback(event);
    }
  });

  TRY_RESULT(fd_size, fd_.get_size());
  if (offset != fd_size) {
    LOG(ERROR) << "Truncate " << tag("path", path_) << tag("old_size", fd_size) << tag("new_size", offset);
    fd_.seek(offset).ensure();
    fd_.truncate_to_current_position(offset).ensure();
    db_key_used_ = false;  // force reindex
  }
  LOG_CHECK(fd_size_ == offset) << fd_size << " " << fd_size_ << " " << offset;
  binlog_reader_ptr_ = nullptr;
  state_ = State::Run;

  buffer_writer_ = ChainBufferWriter();
  buffer_reader_ = buffer_writer_.extract_reader();

  // reuse aes_ctr_state_
  if (encryption_type_ == EncryptionType::AesCtr) {
    aes_ctr_state_ = aes_xcode_byte_flow_.move_aes_ctr_state();
  }
  update_write_encryption();

  return Status::OK();
}

void Binlog::update_encryption(Slice key, Slice iv) {
  as_mutable_slice(aes_ctr_key_).copy_from(key);
  UInt128 aes_ctr_iv;
  as_mutable_slice(aes_ctr_iv).copy_from(iv);
  aes_ctr_state_.init(as_slice(aes_ctr_key_), as_slice(aes_ctr_iv));
}

void Binlog::reset_encryption() {
  if (db_key_.is_empty()) {
    encryption_type_ = EncryptionType::None;
    return;
  }

  using EncryptionEvent = detail::AesCtrEncryptionEvent;
  EncryptionEvent event;

  if (aes_ctr_key_salt_.empty()) {
    event.key_salt_.resize(EncryptionEvent::default_salt_size());
    Random::secure_bytes(event.key_salt_);
  } else {
    event.key_salt_ = aes_ctr_key_salt_;
  }
  event.iv_.resize(EncryptionEvent::iv_size());
  Random::secure_bytes(event.iv_);

  string key;
  if (aes_ctr_key_salt_ == event.key_salt_) {
    key = as_slice(aes_ctr_key_).str();
  } else {
    key = event.generate_key(db_key_);
  }

  event.key_hash_ = EncryptionEvent::generate_hash(key);

  do_event(BinlogEvent(
      BinlogEvent::create_raw(0, BinlogEvent::ServiceTypes::AesCtrEncryption, 0, create_default_storer(event)),
      BinlogDebugInfo{__FILE__, __LINE__}));
}

void Binlog::do_reindex() {
  flush_events_buffer(true);
  // start reindex
  CHECK(state_ == State::Run);
  state_ = State::Reindex;
  SCOPE_EXIT {
    state_ = State::Run;
  };

  auto start_time = Clocks::monotonic();
  auto start_size = detail::file_size(path_);
  auto start_events = fd_events_;

  string new_path = path_ + ".new";

  auto r_opened_file = open_binlog(new_path, FileFd::Flags::Write | FileFd::Flags::Create | FileFd::Truncate);
  if (r_opened_file.is_error()) {
    LOG(ERROR) << "Can't open new binlog for regenerate: " << r_opened_file.error();
    return;
  }
  auto old_fd = std::move(fd_);  // can't close fd_ now, because it will release file lock
  fd_ = BufferedFdBase<FileFd>(r_opened_file.move_as_ok());

  buffer_writer_ = ChainBufferWriter();
  buffer_reader_ = buffer_writer_.extract_reader();
  encryption_type_ = EncryptionType::None;
  update_write_encryption();

  // reindex
  fd_size_ = 0;
  fd_events_ = 0;
  reset_encryption();
  processor_->for_each([&](BinlogEvent &event) {
    do_event(std::move(event));  // NB: no move is actually happens
  });
  {
    flush("do_reindex");
    if (start_size != 0) {  // must sync creation of the file if it is non-empty
      auto status = fd_.sync_barrier();
      LOG_IF(FATAL, status.is_error()) << "Failed to sync binlog: " << status;
    }
    need_sync_ = false;
  }

  // finish_reindex
  auto status = unlink(path_);
  LOG_IF(FATAL, status.is_error()) << "Failed to unlink old binlog: " << status;
  old_fd.close();  // now we can close old file and release the system lock
  status = rename(new_path, path_);
  FileFd::remove_local_lock(new_path);  // now we can release local lock for temporary file
  LOG_IF(FATAL, status.is_error()) << "Failed to rename binlog: " << status;

  auto finish_time = Clocks::monotonic();
  auto finish_size = fd_size_;
  auto finish_events = fd_events_;
  for (int left_tries = 10; left_tries > 0; left_tries--) {
    auto r_stat = stat(path_);
    if (r_stat.is_error()) {
      if (left_tries != 1) {
        usleep_for(200000 / left_tries);
        continue;
      }
      LOG(FATAL) << "Failed to rename binlog of size " << fd_size_ << " to " << path_ << ": " << r_stat.error()
                 << ". Temp file size is " << detail::file_size(new_path) << ", new size " << detail::file_size(path_);
    }
    LOG_CHECK(fd_size_ == r_stat.ok().size_) << fd_size_ << ' ' << r_stat.ok().size_ << ' '
                                             << detail::file_size(new_path) << ' ' << fd_events_ << ' ' << path_;
    break;
  }

  auto ratio = static_cast<double>(start_size) / static_cast<double>(finish_size + 1);

  [&](Slice msg) {
    if (start_size > (10 << 20) || finish_time - start_time > 1) {
      LOG(WARNING) << "Slow " << msg;
    } else {
      LOG(INFO) << msg;
    }
  }(PSLICE() << "Regenerate index " << tag("name", path_) << tag("time", format::as_time(finish_time - start_time))
             << tag("before_size", format::as_size(start_size)) << tag("after_size", format::as_size(finish_size))
             << tag("ratio", ratio) << tag("before_events", start_events) << tag("after_events", finish_events));

  buffer_writer_ = ChainBufferWriter();
  buffer_reader_ = buffer_writer_.extract_reader();

  // reuse aes_ctr_state_
  if (encryption_type_ == EncryptionType::AesCtr) {
    aes_ctr_state_ = aes_xcode_byte_flow_.move_aes_ctr_state();
  }
  update_write_encryption();
}

string Binlog::debug_get_binlog_data(int64 begin_offset, int64 end_offset) {
  if (begin_offset > end_offset) {
    return "Begin offset is bigger than end_offset";
  }
  if (begin_offset == end_offset) {
    return string();
  }

  static int64 MAX_DATA_LENGTH = 512;
  if (end_offset - begin_offset > MAX_DATA_LENGTH) {
    end_offset = begin_offset + MAX_DATA_LENGTH;
  }

  auto r_fd = FileFd::open(path_, FileFd::Flags::Read);
  if (r_fd.is_error()) {
    return PSTRING() << "Failed to open binlog: " << r_fd.error();
  }
  auto fd = r_fd.move_as_ok();

  fd_.lock(FileFd::LockFlags::Unlock, path_, 1).ignore();
  SCOPE_EXIT {
    fd_.lock(FileFd::LockFlags::Write, path_, 1).ensure();
  };
  auto expected_data_length = narrow_cast<size_t>(end_offset - begin_offset);
  string data(expected_data_length, '\0');
  auto r_data_size = fd.pread(data, begin_offset);
  if (r_data_size.is_error()) {
    return PSTRING() << "Failed to read binlog: " << r_data_size.error();
  }

  if (r_data_size.ok() < expected_data_length) {
    data.resize(r_data_size.ok());
    data = PSTRING() << format::as_hex_dump<4>(Slice(data)) << " | with " << expected_data_length - r_data_size.ok()
                     << " missed bytes";
  } else {
    if (encryption_type_ == EncryptionType::AesCtr) {
      bool is_zero = true;
      for (auto &c : data) {
        if (c != '\0') {
          is_zero = false;
        }
      }
      // very often we have '\0' bytes written to disk instead of a real log event
      // this is clearly impossible content for a real encrypted log event, so just ignore it
      if (is_zero) {
        return string();
      }
    }

    data = PSTRING() << format::as_hex_dump<4>(Slice(data));
  }
  return data;
}

}  // namespace td
