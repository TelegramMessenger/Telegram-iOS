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
#include "td/utils/tests.h"

#include "td/utils/as.h"
#include "td/utils/base64.h"
#include "td/utils/benchmark.h"
#include "td/utils/buffer.h"
#include "td/utils/crypto.h"
#include "td/utils/filesystem.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/misc.h"
#include "td/utils/overloaded.h"
#include "td/utils/optional.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/port/IoSlice.h"
#include "td/utils/UInt.h"
#include "td/utils/Variant.h"
#include "td/utils/VectorQueue.h"

#include "td/actor/actor.h"

#include "td/db/utils/StreamInterface.h"
#include "td/db/utils/ChainBuffer.h"
#include "td/db/utils/CyclicBuffer.h"
#include "td/db/binlog/BinlogReaderHelper.h"

#include "td/db/binlog/Binlog.h"

#include <ctime>

// Toy Binlog Implementation
using td::int64;
using td::MutableSlice;
using td::Result;
using td::Slice;
using td::Status;

using RootHash = td::UInt256;
using FileHash = td::UInt256;
struct BlockId {
  int workchain;
  unsigned seqno;
  unsigned long long shard;
};

template <class T>
Result<int64> memcpy_parse(Slice data, T* res) {
  if (data.size() < sizeof(T)) {
    return -static_cast<int64>(sizeof(T));
  }
  std::memcpy(res, data.data(), sizeof(T));
  if (res->tag_field != res->tag) {
    return Status::Error("Tag mismatch");
  }
  return sizeof(T);
}
template <class T>
int64 memcpy_serialize(MutableSlice data, const T& res) {
  if (data.size() < sizeof(T)) {
    return -static_cast<int64>(sizeof(T));
  }
  std::memcpy(data.data(), &res, sizeof(T));
  return sizeof(T);
}

#pragma pack(push, 4)
struct LogEventCrc32C {
  static constexpr unsigned tag = 0x473a830a;

  unsigned tag_field;
  td::uint32 crc32c;
  LogEventCrc32C() = default;
  LogEventCrc32C(td::uint32 crc32c) : tag_field(tag), crc32c(crc32c) {
  }
  static Result<int64> parse(Slice data, LogEventCrc32C* res) {
    return memcpy_parse(data, res);
  }
  int64 serialize(MutableSlice data) const {
    return memcpy_serialize(data, *this);
  }
  auto key() const {
    return crc32c;
  }
  bool operator==(const LogEventCrc32C& other) const {
    return key() == other.key();
  }
  bool operator!=(const LogEventCrc32C& other) const {
    return !(*this == other);
  }
};

struct LogEventStart {
  static constexpr unsigned tag = 0x0442446b;
  static constexpr unsigned log_type = 0x290100;
  unsigned tag_field;
  unsigned type_field;
  unsigned created_at;
  unsigned char zerostate_root_hash[32];
  LogEventStart() = default;
  LogEventStart(const RootHash& hash, unsigned _now = 0)
      : tag_field(tag), type_field(log_type), created_at(_now ? _now : (unsigned)std::time(nullptr)) {
    td::as<RootHash>(zerostate_root_hash) = hash;
  }
  static Result<int64> parse(Slice data, LogEventStart* res) {
    return memcpy_parse(data, res);
  }
  int64 serialize(MutableSlice data) const {
    return memcpy_serialize(data, *this);
  }
  auto key() const {
    return std::make_tuple(tag_field, type_field, created_at, Slice(zerostate_root_hash, 32));
  }
  bool operator==(const LogEventStart& other) const {
    return key() == other.key();
  }
  bool operator!=(const LogEventStart& other) const {
    return !(*this == other);
  }
};

struct LogEventSetZeroState {
  static constexpr unsigned tag = 0x63ab3cd9;
  unsigned tag_field;
  unsigned flags;
  long long file_size;
  unsigned char file_hash[32];
  unsigned char root_hash[32];
  LogEventSetZeroState() = default;
  LogEventSetZeroState(const RootHash& rhash, const FileHash& fhash, unsigned long long _fsize, unsigned _flags = 0)
      : tag_field(tag), flags(_flags), file_size(_fsize) {
    td::as<FileHash>(file_hash) = fhash;
    td::as<RootHash>(root_hash) = rhash;
  }
  static Result<int64> parse(Slice data, LogEventSetZeroState* res) {
    return memcpy_parse(data, res);
  }
  int64 serialize(MutableSlice data) const {
    return memcpy_serialize(data, *this);
  }
  auto key() const {
    return std::make_tuple(tag_field, flags, file_size, Slice(file_hash, 32), Slice(root_hash, 32));
  }
  bool operator==(const LogEventSetZeroState& other) const {
    return key() == other.key();
  }
  bool operator!=(const LogEventSetZeroState& other) const {
    return !(*this == other);
  }
};

struct LogEventNewBlock {
  static constexpr unsigned tag = 0x19f4bc63;
  unsigned tag_field;
  unsigned flags;  // lower 8 bits = authority
  int workchain;
  unsigned seqno;
  unsigned long long shard;
  long long file_size;
  unsigned char file_hash[32];
  unsigned char root_hash[32];
  unsigned char last_bytes[8];
  LogEventNewBlock() = default;
  LogEventNewBlock(const BlockId& block, const RootHash& rhash, const FileHash& fhash, unsigned long long _fsize,
                   unsigned _flags)
      : tag_field(tag)
      , flags(_flags)
      , workchain(block.workchain)
      , seqno(block.seqno)
      , shard(block.shard)
      , file_size(_fsize) {
    td::as<FileHash>(file_hash) = fhash;
    td::as<RootHash>(root_hash) = rhash;
    td::as<unsigned long long>(last_bytes) = 0;
  }
  static Result<int64> parse(Slice data, LogEventNewBlock* res) {
    return memcpy_parse(data, res);
  }
  int64 serialize(MutableSlice data) const {
    return memcpy_serialize(data, *this);
  }
  auto key() const {
    return std::make_tuple(tag_field, flags, workchain, seqno, shard, file_size, Slice(file_hash, 32),
                           Slice(root_hash, 32), Slice(last_bytes, 8));
  }
  bool operator==(const LogEventNewBlock& other) const {
    return key() == other.key();
  }
  bool operator!=(const LogEventNewBlock& other) const {
    return !(*this == other);
  }
};

struct LogEventNewState {
  static constexpr unsigned tag = 0x4190a21f;
  unsigned tag_field;
  unsigned flags;  // lower 8 bits = authority
  int workchain;
  unsigned seqno;
  unsigned long long shard;
  long long file_size;
  unsigned char file_hash[32];
  unsigned char root_hash[32];
  unsigned char last_bytes[8];
  LogEventNewState() = default;
  LogEventNewState(const BlockId& state, const RootHash& rhash, const FileHash& fhash, unsigned long long _fsize,
                   unsigned _flags)
      : tag_field(tag)
      , flags(_flags)
      , workchain(state.workchain)
      , seqno(state.seqno)
      , shard(state.shard)
      , file_size(_fsize) {
    td::as<FileHash>(file_hash) = fhash;
    td::as<RootHash>(root_hash) = rhash;
    td::as<unsigned long long>(last_bytes) = 0;
  }
  static Result<int64> parse(Slice data, LogEventNewState* res) {
    return memcpy_parse(data, res);
  }
  int64 serialize(MutableSlice data) const {
    return memcpy_serialize(data, *this);
  }
  auto key() const {
    return std::make_tuple(tag_field, flags, workchain, seqno, shard, file_size, Slice(file_hash, 32),
                           Slice(root_hash, 32), Slice(last_bytes, 8));
  }
  bool operator==(const LogEventNewState& other) const {
    return key() == other.key();
  }
  bool operator!=(const LogEventNewState& other) const {
    return !(*this == other);
  }
};
#pragma pack(pop)

struct LogEventString {
  static constexpr unsigned tag = 0xabcdabcd;

  std::string data;

  bool operator==(const LogEventString& other) const {
    return data == other.data;
  }
  bool operator!=(const LogEventString& other) const {
    return !(*this == other);
  }

  int64 serialize(MutableSlice dest) const {
    size_t need_size = 8 + data.size();
    if (dest.size() < need_size) {
      return -static_cast<int64>(need_size);
    }
    dest.truncate(need_size);
    td::as<unsigned>(dest.data()) = tag;
    td::as<int>(dest.data() + 4) = td::narrow_cast<int>(data.size());
    dest.substr(8).copy_from(data);
    return dest.size();
  }

  static Result<int64> parse(Slice data, LogEventString* res) {
    if (data.size() < 4) {
      return -4;
    }
    unsigned got_tag = td::as<unsigned>(data.data());
    if (got_tag != tag) {
      return Status::Error(PSLICE() << "tag mismatch " << td::format::as_hex(got_tag));
    }
    data = data.substr(4);
    if (data.size() < 4) {
      return -8;
    }
    td::int64 length = td::as<td::uint32>(data.data());
    data = data.substr(4);
    if (static_cast<int64>(data.size()) < length) {
      return -length - 8;
    }
    res->data = data.substr(0, td::narrow_cast<std::size_t>(length)).str();
    return length + 8;
  }
};

struct LogEvent {
  td::Variant<LogEventCrc32C, LogEventStart, LogEventString, LogEventNewBlock, LogEventNewState, LogEventSetZeroState>
      event_{LogEventStart{}};

  bool operator==(const LogEvent& other) const {
    return event_ == other.event_;
  }
  bool operator!=(const LogEvent& other) const {
    return !(*this == other);
  }

  LogEvent() = default;
  LogEvent(LogEvent&& other) = default;
  template <class T>
  LogEvent(T&& e) : event_(std::forward<T>(e)) {
  }

  int64 serialize(MutableSlice data) const {
    int64 res;
    event_.visit([&](auto& e) { res = e.serialize(data); });
    return res;
  }

  static Result<int64> parse(Slice data, LogEvent* res) {
    if (data.size() < 4) {
      return -4;
    }
    //LOG(ERROR) << td::format::as_hex_dump<4>(data);
    unsigned got_tag = td::as<unsigned>(data.data());
    switch (got_tag) {
      case LogEventCrc32C::tag: {
        LogEventCrc32C e;
        TRY_RESULT(x, e.parse(data, &e));
        if (x >= 0) {
          res->event_ = e;
        }
        return x;
      }
      case LogEventStart::tag: {
        LogEventStart e;
        TRY_RESULT(x, e.parse(data, &e));
        if (x >= 0) {
          res->event_ = e;
        }
        return x;
      }
      case LogEventSetZeroState::tag: {
        LogEventSetZeroState e;
        TRY_RESULT(x, e.parse(data, &e));
        if (x >= 0) {
          res->event_ = e;
        }
        return x;
      }
      case LogEventNewBlock::tag: {
        LogEventNewBlock e;
        TRY_RESULT(x, e.parse(data, &e));
        if (x >= 0) {
          res->event_ = e;
        }
        return x;
      }
      case LogEventNewState::tag: {
        LogEventNewState e;
        TRY_RESULT(x, e.parse(data, &e));
        if (x >= 0) {
          res->event_ = e;
        }
        return x;
      }
      case LogEventString::tag: {
        LogEventString e;
        TRY_RESULT(x, e.parse(data, &e));
        if (x >= 0) {
          res->event_ = e;
        }
        return x;
      }
      default:
        return Status::Error(PSLICE() << "Unknown tag: " << td::format::as_hex(got_tag));
    }
  }
};

static td::CSlice test_binlog_path("test.binlog");

class BinlogReader : public td::BinlogReaderInterface {
 public:
  td::Span<LogEvent> logevents() const {
    return logevents_;
  }

  td::Result<td::int64> parse(td::Slice data) override {
    if (data.size() < 4) {
      return -4;
    }
    LogEvent res;
    TRY_RESULT(size, res.parse(data, &res));
    if (size > 0) {
      if (res.event_.get_offset() == res.event_.offset<LogEventCrc32C>()) {
        auto crc = res.event_.get<LogEventCrc32C>().crc32c;
        flush_crc();
        if (crc != crc_) {
          return Status::Error("Crc mismatch");
        }
      } else {
        logevents_.emplace_back(std::move(res));
      }
      lazy_crc_extend(data.substr(0, td::narrow_cast<std::size_t>(size)));
    }
    return size;
  }

  td::uint32 crc32c() {
    flush_crc();
    return crc_;
  }

  void flush() override {
    flush_crc();
  }

 private:
  std::vector<LogEvent> logevents_;
  td::uint32 crc_{0};
  td::Slice suffix_;

  void flush_crc() {
    crc_ = td::crc32c_extend(crc_, suffix_);
    suffix_ = Slice();
  }
  void lazy_crc_extend(Slice slice) {
    if (suffix_.empty()) {
      suffix_ = slice;
      return;
    }
    if (suffix_.end() == slice.begin()) {
      suffix_ = Slice(suffix_.begin(), slice.end());
      return;
    }
    flush_crc();
    suffix_ = slice;
  }
};

class RandomBinlog {
 public:
  RandomBinlog() {
    size_t logevent_count = 1000;
    for (size_t i = 0; i < logevent_count; i++) {
      add_logevent(create_random_logevent());
    }
  }

  Slice data() const {
    return data_;
  }
  td::Span<LogEvent> logevents() const {
    return logevents_;
  }

 private:
  std::vector<LogEvent> logevents_;
  std::string data_;

  template <class T>
  void add_logevent(T event) {
    int64 size = -event.serialize({});
    std::string data(td::narrow_cast<std::size_t>(size), '\0');
    int64 new_size = event.serialize(data);
    CHECK(new_size == size);
    data_ += data;
    logevents_.emplace_back(std::move(event));
  }

  LogEvent create_random_logevent() {
    auto rand_uint256 = [] {
      td::UInt256 res;
      td::Random::secure_bytes(as_slice(res));
      return res;
    };
    auto rand_block_id = [] {
      BlockId res;
      res.workchain = td::Random::fast(0, 100);
      res.shard = td::Random::fast(0, 100);
      res.seqno = td::Random::fast(0, 100);
      return res;
    };

    auto type = td::Random::fast(0, 4);
    switch (type) {
      case 0: {
        auto size = td::Random::fast(0, 10);
        LogEventString event;
        event.data = td::rand_string('a', 'z', size);
        return event;
      }
      case 1: {
        return LogEventStart(rand_uint256(), 12);
      }
      case 2: {
        return LogEventSetZeroState(rand_uint256(), rand_uint256(), td::Random::fast(0, 1000),
                                    td::Random::fast(0, 1000));
      }
      case 3: {
        return LogEventNewBlock(rand_block_id(), rand_uint256(), rand_uint256(), 12, 17);
      }
      case 4: {
        return LogEventNewState(rand_block_id(), rand_uint256(), rand_uint256(), 12, 17);
      }
    }
    UNREACHABLE();
  }
};

void test_binlog(td::Slice data, td::optional<td::Span<LogEvent>> events = {}) {
  auto splitted_binlog = td::rand_split(data);

  std::string new_binlog_data;

  BinlogReader reader;
  td::BinlogReaderHelper reader_impl;
  for (auto& chunk : splitted_binlog) {
    reader_impl.parse(reader, chunk).ensure();
  }

  //Binlog write sync
  {
    td::Binlog::destroy(test_binlog_path);
    td::BinlogWriter binlog_writer(test_binlog_path.str());
    binlog_writer.open().ensure();

    BinlogReader new_reader;
    size_t i = 0;
    for (auto& logevent : reader.logevents()) {
      binlog_writer.write_event(logevent, &new_reader).ensure();
      i++;
      if (i % 10 == 0) {
        binlog_writer.write_event(LogEvent(LogEventCrc32C(new_reader.crc32c())), &new_reader).ensure();
      }
    }
    binlog_writer.sync();
    binlog_writer.close().ensure();

    auto file_data = read_file(test_binlog_path).move_as_ok();
    ASSERT_TRUE(reader.logevents() == new_reader.logevents());
    new_binlog_data = file_data.as_slice().str();
    data = new_binlog_data;
    //ASSERT_EQ(data, file_data);
  }

  //Binlog write async
  {
    td::Binlog::destroy(test_binlog_path);
    td::BinlogWriterAsync binlog_writer(test_binlog_path.str());

    td::actor::Scheduler scheduler({2});

    BinlogReader new_reader;
    scheduler.run_in_context([&]() mutable {
      binlog_writer.open().ensure();
      for (auto& logevent : reader.logevents()) {
        binlog_writer.write_event(logevent, &new_reader).ensure();
      }
      binlog_writer.sync([&](Result<td::Unit> res) {
        res.ensure();
        binlog_writer.close([&](Result<td::Unit> res) {
          res.ensure();
          td::actor::SchedulerContext::get()->stop();
        });
      });
    });

    scheduler.run();
    scheduler.stop();

    auto file_data = read_file(test_binlog_path).move_as_ok();
    ASSERT_TRUE(reader.logevents() == new_reader.logevents());
    //ASSERT_EQ(data, file_data);
  }

  ASSERT_TRUE(!events || events.value() == reader.logevents());

  std::string new_data;
  for (auto& event : reader.logevents()) {
    int64 size = -event.serialize({});
    std::string event_data(td::narrow_cast<std::size_t>(size), '\0');
    int64 new_size = event.serialize(event_data);
    CHECK(new_size == size);
    new_data += event_data;
  }
  //ASSERT_EQ(data, new_data);

  // Binlog::read_sync
  {
    td::CSlice path("test.binlog");
    td::Binlog::destroy(path);
    td::write_file(path, data).ensure();

    td::Binlog binlog(path.str());
    BinlogReader binlog_reader;
    binlog.replay_sync(binlog_reader).ensure();

    ASSERT_EQ(reader.logevents().size(), binlog_reader.logevents().size());
    ASSERT_TRUE(reader.logevents() == binlog_reader.logevents());
  }

  // Binlog::read_async
  {
    td::Binlog::destroy(test_binlog_path);
    td::write_file(test_binlog_path, data).ensure();

    td::Binlog binlog(test_binlog_path.str());
    auto binlog_reader = std::make_shared<BinlogReader>();

    td::actor::Scheduler scheduler({2});
    scheduler.run_in_context([&]() mutable {
      binlog.replay_async(binlog_reader, [](Result<td::Unit> res) {
        res.ensure();
        td::actor::SchedulerContext::get()->stop();
      });
    });

    scheduler.run();
    scheduler.stop();

    ASSERT_EQ(reader.logevents().size(), binlog_reader->logevents().size());
    ASSERT_TRUE(reader.logevents() == binlog_reader->logevents());
  }
}

TEST(Binlog, Reader) {
  RandomBinlog binlog;
  test_binlog(binlog.data(), binlog.logevents());
}

TEST(Binlog, Hands) {
  std::string binlog = td::base64_decode(
                           "a0RCBAABKQCRMn1c2DaJhwrptxburpRtrWI2sjGhVbG29bFO0r8DDtAAExjZPKtjAAAAALwGAAAA"
                           "AAAAFvJq3qfzFCDWap+LUrgBI8sWFayIOQSxkBjV3CWgizHYNomHCum3Fu6ulG2tYjayMaFVsbb1"
                           "sU7SvwMO0AATGGO89BmAAAAA/////wEAAAAAAAAAAAAAgN4RAAAAAAAAa53L4ziGleZ7K+StAsBd"
                           "txMxbHHfuB9SJRFp+BMzXfnGnt8TsgFnig7j/xVRjtIsYUVw0rQZJUC0sWQROj0SHvplIkBV9vMp")
                           .move_as_ok();
  test_binlog(binlog);
}

TEST(Buffers, CyclicBufferSimple) {
  {
    auto reader_writer = td::CyclicBuffer::create();
    auto reader = std::move(reader_writer.first);
    auto writer = std::move(reader_writer.second);

    ASSERT_TRUE(!writer.is_reader_closed());
    reader.close_reader(td::Status::Error(2));
    ASSERT_TRUE(!reader.is_writer_closed());
    ASSERT_TRUE(writer.is_reader_closed());
    ASSERT_EQ(2, writer.reader_status().code());
  }
  {
    auto reader_writer = td::CyclicBuffer::create();
    auto reader = std::move(reader_writer.first);
    auto writer = std::move(reader_writer.second);

    ASSERT_TRUE(!reader.is_writer_closed());
    writer.close_writer(td::Status::Error(2));
    ASSERT_TRUE(!writer.is_reader_closed());
    ASSERT_TRUE(reader.is_writer_closed());
    ASSERT_EQ(2, reader.writer_status().code());
  }
  {
    td::CyclicBuffer::Options options;
    options.chunk_size = 14;
    options.count = 10;
    options.alignment = 7;
    auto reader_writer = td::CyclicBuffer::create(options);
    auto reader = std::move(reader_writer.first);
    auto writer = std::move(reader_writer.second);

    auto data = td::rand_string('a', 'z', 100001);
    td::Slice write_slice = data;
    td::Slice read_slice = data;
    for (size_t i = 1; i < options.count; i++) {
      ASSERT_EQ((i - 1) * options.chunk_size, reader.reader_size());
      ASSERT_EQ((i - 1) * options.chunk_size, writer.writer_size());
      auto slice = writer.prepare_write();
      ASSERT_EQ(0u, reinterpret_cast<td::uint64>(slice.data()) % options.alignment);
      auto to_copy = write_slice;
      to_copy.truncate(options.chunk_size);
      slice.copy_from(to_copy);
      write_slice = write_slice.substr(to_copy.size());
      writer.confirm_write(to_copy.size());
      ASSERT_EQ(i * options.chunk_size, reader.reader_size());
      ASSERT_EQ(i * options.chunk_size, writer.writer_size());
    }
    bool is_writer_closed = false;
    while (true) {
      {
        bool is_closed = reader.is_writer_closed();
        auto slice = reader.prepare_read();
        ASSERT_EQ(read_slice.substr(0, slice.size()), slice);
        read_slice = read_slice.substr(slice.size());
        reader.confirm_read(slice.size());
        if (is_closed && slice.empty()) {
          break;
        }
      }

      if (!is_writer_closed) {
        auto slice = writer.prepare_write();
        auto to_copy = write_slice;
        to_copy.truncate(options.chunk_size);
        if (to_copy.empty()) {
          writer.close_writer(td::Status::OK());
          is_writer_closed = true;
        } else {
          slice.copy_from(to_copy);
          write_slice = write_slice.substr(to_copy.size());
          writer.confirm_write(to_copy.size());
        }
      }
    }
    ASSERT_EQ(0u, write_slice.size());
    ASSERT_EQ(0u, read_slice.size());
  }
}

TEST(Buffers, CyclicBuffer) {
  for (int t = 0; t < 20; t++) {
    td::CyclicBuffer::Options options;
    options.chunk_size = 14;
    options.count = 10;
    options.alignment = 7;
    auto reader_writer = td::CyclicBuffer::create(options);
    auto reader = std::move(reader_writer.first);
    auto writer = std::move(reader_writer.second);
    auto data = td::rand_string('a', 'z', 100001);
    auto chunks = td::rand_split(data);

    size_t chunk_i = 0;
    std::string res;
    while (true) {
      if (td::Random::fast(0, 1) == 0) {
        bool is_closed = reader.is_writer_closed();
        auto slice = reader.prepare_read();
        res += slice.str();
        reader.confirm_read(slice.size());
        if (slice.empty() && is_closed) {
          reader.writer_status().ensure();
          break;
        }
      }
      if (chunk_i < chunks.size() && td::Random::fast(0, 1) == 0) {
        auto slice = writer.prepare_write();
        auto from = Slice(chunks[chunk_i]);
        auto copy = from.substr(0, slice.size());
        slice.copy_from(copy);
        writer.confirm_write(copy.size());
        auto left = from.substr(copy.size());
        if (!left.empty()) {
          chunks[chunk_i] = left.str();
        } else {
          chunk_i++;
          if (chunk_i == chunks.size()) {
            writer.close_writer(td::Status::OK());
          }
        }
      }
    }
    ASSERT_EQ(data, res);
  }
}

TEST(Buffers, ChainBuffer) {
  for (int t = 0; t < 20; t++) {
    td::ChainBuffer::Options options;
    options.chunk_size = 14;
    auto reader_writer = td::ChainBuffer::create(options);
    auto reader = std::move(reader_writer.first);
    auto writer = std::move(reader_writer.second);
    auto data = td::rand_string('a', 'z', 100001);
    auto chunks = td::rand_split(data);

    size_t chunk_i = 0;
    std::string res;
    while (true) {
      if (td::Random::fast(0, 1) == 0) {
        bool is_closed = reader.is_writer_closed();
        Slice slice;
        if (reader.reader_size() != 0) {
          slice = reader.prepare_read();
          res += slice.str();
          reader.confirm_read(slice.size());
        }
        if (slice.empty() && is_closed) {
          reader.writer_status().ensure();
          break;
        }
      }
      if (chunk_i < chunks.size() && td::Random::fast(0, 1) == 0) {
        writer.append(chunks[chunk_i]);
        chunk_i++;
        if (chunk_i == chunks.size()) {
          writer.close_writer(td::Status::OK());
        }
      }
    }
    ASSERT_EQ(data.size(), res.size());
    ASSERT_EQ(data, res);
  }
}
