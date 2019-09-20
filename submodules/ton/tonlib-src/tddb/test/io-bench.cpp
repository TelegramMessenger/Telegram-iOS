/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "td/utils/OptionsParser.h"
#include "td/utils/filesystem.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/Timer.h"
#include "td/utils/crypto.h"
#include "td/utils/BufferedReader.h"
#include "td/utils/optional.h"
#include "td/actor/actor.h"

#include "td/db/utils/StreamInterface.h"
#include "td/db/utils/ChainBuffer.h"
#include "td/db/utils/CyclicBuffer.h"
#include "td/db/utils/FileSyncState.h"
#include "td/db/utils/StreamToFileActor.h"
#include "td/db/utils/FileToStreamActor.h"

#include <cmath>

namespace td {
class AsyncCyclicBufferReader : public td::actor::Actor {
 public:
  class Callback {
   public:
    virtual ~Callback() {
    }
    virtual void want_more() = 0;
    virtual Status process(Slice data) = 0;
    virtual void on_closed(Status status) = 0;
  };
  AsyncCyclicBufferReader(CyclicBuffer::Reader reader, td::unique_ptr<Callback> callback)
      : reader_(std::move(reader)), callback_(std::move(callback)) {
  }

 private:
  CyclicBuffer::Reader reader_;
  td::unique_ptr<Callback> callback_;

  void loop() override {
    while (true) {
      auto data = reader_.prepare_read();
      if (data.empty()) {
        if (reader_.is_writer_closed()) {
          callback_->on_closed(std::move(reader_.writer_status()));
          return stop();
        }
        callback_->want_more();
        return;
      }
      auto status = callback_->process(data);
      if (status.is_error()) {
        callback_->on_closed(std::move(status));
      }
      reader_.confirm_read(data.size());
      //TODO: better condition for want_more. May be reader should decide if it is ready for more writes
      callback_->want_more();
    }
  }
};

}  // namespace td

class Processor {
 public:
  void process(td::Slice slice) {
    res = crc32c_extend(res, slice);
    res2 = crc32c_extend(res2, slice);
  }
  auto result() {
    return res * res2;
  }

 private:
  td::uint32 res{0};
  td::uint32 res2{0};
};

void read_baseline(td::CSlice path) {
  LOG(ERROR) << "BASELINE";
  td::PerfWarningTimer timer("read file");
  auto data = td::read_file(path).move_as_ok();
  timer.reset();

  td::PerfWarningTimer process_timer("process file", 0);
  Processor processor;
  processor.process(data.as_slice());
  process_timer.reset();
  LOG(ERROR) << processor.result();
}

void read_buffered(td::CSlice path, size_t buffer_size) {
  LOG(ERROR) << "BufferedReader";
  auto fd = td::FileFd::open(path, td::FileFd::Read).move_as_ok();
  td::BufferedReader reader(fd, buffer_size);
  std::vector<char> buf(buffer_size);
  Processor processor;
  while (true) {
    auto slice = td::MutableSlice(&buf[0], buf.size());
    auto size = reader.read(slice).move_as_ok();
    if (size == 0) {
      break;
    }
    processor.process(slice.truncate(size));
  }
  LOG(ERROR) << processor.result();
}

void read_async(td::CSlice path, size_t buffer_size) {
  LOG(ERROR) << "Async";
  auto fd = td::FileFd::open(path, td::FileFd::Read).move_as_ok();
  td::actor::Scheduler scheduler({2});
  scheduler.run_in_context([&] {
    auto reader_writer = td::CyclicBuffer::create();
    //TODO: hide actor
    auto reader =
        td::actor::create_actor<td::FileToStreamActor>("Reader", std::move(fd), std::move(reader_writer.second));
    class Callback : public td::AsyncCyclicBufferReader::Callback {
     public:
      Callback(td::actor::ActorOwn<> reader) : reader_(std::move(reader)) {
      }
      void want_more() override {
        td::actor::send_signals_later(reader_, td::actor::ActorSignals::wakeup());
      }
      td::Status process(td::Slice data) override {
        processor.process(data);
        return td::Status::OK();
      }
      void on_closed(td::Status status) override {
        LOG(ERROR) << processor.result();
        td::actor::SchedulerContext::get()->stop();
      }

     private:
      td::actor::ActorOwn<> reader_;
      Processor processor;
    };
    auto reader_copy = reader.get();
    auto callback = td::make_unique<Callback>(std::move(reader));
    auto processor = td::actor::create_actor<td::AsyncCyclicBufferReader>(
        "BufferReader", std::move(reader_writer.first), std::move(callback));
    class ReaderCallback : public td::FileToStreamActor::Callback {
     public:
      ReaderCallback(td::actor::ActorId<> actor) : actor_(std::move(actor)) {
      }
      void got_more() override {
        td::actor::send_signals_later(actor_, td::actor::ActorSignals::wakeup());
      }

     private:
      td::actor::ActorId<> actor_;
    };
    send_closure(reader_copy, &td::FileToStreamActor::set_callback,
                 td::make_unique<ReaderCallback>(processor.release()));
  });
  scheduler.run();
}

static char o_direct_buf[100000000];
void read_o_direct(td::CSlice path, size_t buffer_size) {
  LOG(ERROR) << "Direct";
  auto fd = td::FileFd::open(path, td::FileFd::Read | td::FileFd::Direct).move_as_ok();
  size_t align = 4096;
  auto *ptr =
      reinterpret_cast<char *>((reinterpret_cast<std::uintptr_t>(o_direct_buf) + align - 1) & td::bits_negate64(align));

  td::BufferedReader reader(fd, buffer_size);
  Processor processor;
  while (true) {
    auto slice = td::MutableSlice(ptr, buffer_size);
    auto size = reader.read(slice).move_as_ok();
    if (size == 0) {
      break;
    }
    processor.process(slice.truncate(size));
  }
  LOG(ERROR) << processor.result();
}

class DataGenerator {
 public:
  operator bool() const {
    return generated_size < total_size;
  }

  td::string next() {
    auto res = words_[2];
    generated_size += res.size();
    return res;
  }

 private:
  std::vector<std::string> words_{"a", "fjdksalfdfs", std::string(20, 'b'), std::string(1000, 'a')};
  size_t total_size = (1 << 20) * 600;
  size_t generated_size = 0;
};

void write_baseline(td::CSlice path, size_t buffer_size) {
  LOG(ERROR) << "Baseline";
  auto fd = td::FileFd::open(path, td::FileFd::Flags::Create | td::FileFd::Flags::Truncate | td::FileFd::Flags::Write)
                .move_as_ok();
  std::vector<char> buf(buffer_size);

  DataGenerator generator;
  while (generator) {
    auto slice = generator.next();
    fd.write(slice).ensure();
  }
  fd.sync().ensure();
}
void write_buffered(td::CSlice path, size_t buffer_size) {
  LOG(ERROR) << "Buffered";
  auto fd = td::FileFd::open(path, td::FileFd::Flags::Create | td::FileFd::Flags::Truncate | td::FileFd::Flags::Write)
                .move_as_ok();
  std::vector<char> buf(buffer_size);
  size_t data_size{0};

  auto flush = [&]() {
    auto slice = td::Slice(buf.data(), data_size);
    fd.write(slice).ensure();
    //auto io_slice = as_io_slice(slice);
    //fd.writev({&io_slice, 1}).ensure();
    data_size = 0;
  };
  auto append = [&](td::Slice slice) {
    if (data_size + slice.size() > buffer_size) {
      flush();
    }

    td::MutableSlice(buf.data(), buffer_size).substr(data_size).copy_from(slice);
    data_size += slice.size();
  };

  DataGenerator generator;
  while (generator) {
    auto slice = generator.next();
    append(slice);
  }
  flush();
  fd.sync().ensure();
}

namespace td {

class FileWriter {
 public:
  FileWriter(FileFd fd, size_t buffer_size) : fd_(std::move(fd)), raw_buffer_(buffer_size) {
    reset();
    buffer_slices_.reserve(1024);
    strings_.reserve(1024);
    ios_slices_.reserve(1024);
  }

  void append(std::string data) {
    cached_size_ += data.size();
    if (data.size() <= max_copy_size) {
      append_copy(data);
    } else {
      CHECK(strings_.size() < strings_.capacity());
      strings_.push_back(std::move(data));
      ios_slices_.push_back(as_io_slice(strings_.back()));
      should_merge_ = false;
    }
    try_flush();
  }

  void append(BufferSlice data) {
    cached_size_ += data.size();
    if (data.size() <= max_copy_size) {
      append_copy(data);
    } else {
      buffer_slices_.push_back(std::move(data));
      ios_slices_.push_back(as_io_slice(strings_.back()));
      should_merge_ = false;
    }
    try_flush();
  }

  void append(Slice data) {
    if (data.size() <= max_copy_size) {
      append_copy(data);
      try_flush();
    } else if (data.size() > min_immediate_write_size) {
      ios_slices_.push_back(as_io_slice(data));
      flush();
    } else {
      append(BufferSlice(data));
    }
  }

  void flush() {
    if (ios_slices_.empty()) {
      return;
    }
    flushed_size_ += cached_size_;
    fd_.writev(ios_slices_).ensure();
    reset();
  }

  void sync() {
    flush();
    synced_size_ = flushed_size_;
    fd_.sync().ensure();
  }

  bool may_flush() const {
    return cached_size_ != 0;
  }
  size_t total_size() const {
    return flushed_size() + cached_size_;
  }
  size_t flushed_size() const {
    return flushed_size_;
  }
  size_t synced_size() const {
    return synced_size_;
  }

 private:
  static constexpr size_t max_cached_size = 256 * (1 << 10);
  static constexpr size_t min_immediate_write_size = 32 * (1 << 10);

  FileFd fd_;

  std::vector<char> raw_buffer_;
  size_t max_copy_size = min(raw_buffer_.size() / 8, size_t(4096u));
  MutableSlice buffer_;
  bool should_merge_ = false;

  std::vector<BufferSlice> buffer_slices_;
  std::vector<std::string> strings_;
  std::vector<IoSlice> ios_slices_;
  size_t cached_size_{0};
  size_t flushed_size_{0};
  size_t synced_size_{0};

  void append_copy(Slice data) {
    buffer_.copy_from(data);
    if (should_merge_) {
      auto back = as_slice(ios_slices_.back());
      back = Slice(back.data(), back.size() + data.size());
      ios_slices_.back() = as_io_slice(back);
    } else {
      ios_slices_.push_back(as_io_slice(buffer_.substr(0, data.size())));
      should_merge_ = true;
    }
    buffer_ = buffer_.substr(data.size());
  }

  void reset() {
    buffer_ = MutableSlice(raw_buffer_.data(), raw_buffer_.size());
    buffer_slices_.clear();
    strings_.clear();
    ios_slices_.clear();
    should_merge_ = false;
    cached_size_ = 0;
  }

  bool must_flush() const {
    return buffer_.size() < max_copy_size || ios_slices_.size() == ios_slices_.capacity() ||
           cached_size_ >= max_cached_size;
  }
  void try_flush() {
    if (!must_flush()) {
      return;
    }
    flush();
  }
};

class AsyncFileWriterActor : public actor::Actor {
 public:
  AsyncFileWriterActor(FileSyncState::Reader state) : state_(std::move(state)) {
    io_slices_.reserve(100);
  }

 private:
  FileFd fd_;
  ChainBufferReader reader_;
  FileSyncState::Reader state_;
  std::vector<IoSlice> io_slices_;

  size_t flushed_size_{0};
  size_t synced_size_{0};

  void flush() {
    reader_.sync_with_writer();
    while (!reader_.empty()) {
      auto it = reader_.clone();
      size_t io_slices_size = 0;
      while (!it.empty() && io_slices_.size() < io_slices_.capacity()) {
        auto slice = it.prepare_read();
        io_slices_.push_back(as_io_slice(slice));
        io_slices_size += slice.size();
        it.confirm_read(slice.size());
      }
      if (!io_slices_.empty()) {
        auto r_written = fd_.writev(io_slices_);
        LOG_IF(FATAL, r_written.is_error()) << r_written.error();
        auto written = r_written.move_as_ok();
        CHECK(written == io_slices_size);
        flushed_size_ += written;
        io_slices_.clear();
      }
      reader_ = std::move(it);
    }
  }

  void loop() override {
    reader_.sync_with_writer();
    flush();
  }
};

}  // namespace td

void write_vector(td::CSlice path, size_t buffer_size) {
  LOG(ERROR) << "io vector";
  auto fd = td::FileFd::open(path, td::FileFd::Flags::Create | td::FileFd::Flags::Truncate | td::FileFd::Flags::Write)
                .move_as_ok();
  td::FileWriter writer(std::move(fd), buffer_size);

  DataGenerator generator;
  while (generator) {
    auto slice = generator.next();
    writer.append(std::move(slice));
  }
  writer.sync();
}

void write_async(td::CSlice path, size_t buffer_size) {
  LOG(ERROR) << "Async";
  auto fd = td::FileFd::open(path, td::FileFd::Flags::Create | td::FileFd::Flags::Truncate | td::FileFd::Flags::Write)
                .move_as_ok();
  td::actor::Scheduler scheduler({1});
  scheduler.run_in_context([&] {
    class Writer : public td::actor::Actor {
     public:
      Writer(td::FileFd fd, size_t buffer_size) : fd_(std::move(fd)), buffer_size_(buffer_size) {
      }
      class Callback : public td::StreamToFileActor::Callback {
       public:
        Callback(td::actor::ActorShared<> parent) : parent_(std::move(parent)) {
        }
        void on_sync_state_changed() override {
          td::actor::send_signals_later(parent_, td::actor::ActorSignals::wakeup());
        }

       private:
        td::actor::ActorShared<> parent_;
      };

      void start_up() override {
        auto buffer_reader_writer = td::ChainBuffer::create();
        buffer_writer_ = std::move(buffer_reader_writer.second);
        auto buffer_reader = std::move(buffer_reader_writer.first);

        auto sync_state_reader_writer = td::FileSyncState::create();
        fd_sync_state_ = std::move(sync_state_reader_writer.first);
        auto sync_state_writer = std::move(sync_state_reader_writer.second);
        auto options = td::StreamToFileActor::Options{};
        writer_ = td::actor::create_actor<td::StreamToFileActor>(td::actor::ActorOptions().with_name("FileWriterActor"),
                                                                 std::move(buffer_reader), std::move(fd_),
                                                                 std::move(sync_state_writer), options);
        send_closure(writer_, &td::StreamToFileActor::set_callback, td::make_unique<Callback>(actor_shared(this)));
        loop();
      }

     private:
      td::FileFd fd_;
      td::optional<td::ChainBuffer::Writer> buffer_writer_;
      td::optional<td::FileSyncState::Reader> fd_sync_state_;
      td::actor::ActorOwn<td::StreamToFileActor> writer_;
      size_t buffer_size_;
      DataGenerator generator_;
      size_t total_size_{0};
      bool was_sync_{false};

      void loop() override {
        auto flushed_size = fd_sync_state_.value().flushed_size();
        while (generator_ && total_size_ < flushed_size + buffer_size_ * 10) {
          auto str = generator_.next();
          total_size_ += str.size();
          buffer_writer_.value().append(str);
        }
        td::actor::send_signals_later(writer_, td::actor::ActorSignals::wakeup());
        if (generator_) {
          return;
        } else if (!was_sync_) {
          was_sync_ = true;
          fd_sync_state_.value().set_requested_sync_size(total_size_);
          td::actor::send_signals_later(writer_, td::actor::ActorSignals::wakeup());
        }
        if (fd_sync_state_.value().synced_size() == total_size_) {
          writer_.reset();
        }
      }
      void hangup_shared() override {
        td::actor::SchedulerContext::get()->stop();
        stop();
      }
    };
    td::actor::create_actor<Writer>("Writer", std::move(fd), buffer_size).release();
  });
  scheduler.run();
}

void write_async2(td::CSlice path, size_t buffer_size) {
  LOG(ERROR) << "Async2";
  auto fd = td::FileFd::open(path, td::FileFd::Flags::Create | td::FileFd::Flags::Truncate | td::FileFd::Flags::Write)
                .move_as_ok();
  td::actor::Scheduler scheduler({1});
  scheduler.run_in_context([&] {
    class Worker : public td::actor::Actor {
     public:
      Worker(td::FileFd fd, td::ChainBufferReader reader, td::actor::ActorShared<> parent)
          : fd_(std::move(fd)), reader_(std::move(reader)), parent_(std::move(parent)) {
      }

     private:
      td::FileFd fd_;
      td::ChainBufferReader reader_;
      td::actor::ActorShared<> parent_;
      void loop() override {
        reader_.sync_with_writer();
        while (!reader_.empty()) {
          auto slice = reader_.prepare_read();
          fd_.write(slice).ensure();
          reader_.confirm_read(slice.size());
        }
      }
      void hangup() override {
        loop();
        fd_.sync().ensure();
        stop();
      }
    };
    class Writer : public td::actor::Actor {
     public:
      Writer(td::FileFd fd) : fd_(std::move(fd)) {
      }

     private:
      td::FileFd fd_;
      td::actor::ActorOwn<> worker_;
      td::ChainBufferWriter writer_;
      DataGenerator generator_;

      void start_up() override {
        worker_ =
            td::actor::create_actor<Worker>("Worker", std::move(fd_), writer_.extract_reader(), actor_shared(this));
        while (generator_) {
          writer_.append(generator_.next(), 65536);
          send_signals_later(worker_, td::actor::ActorSignals::wakeup());
        }
        worker_.reset();
      }
      void hangup_shared() override {
        td::actor::SchedulerContext::get()->stop();
        stop();
      }
    };
    td::actor::create_actor<Writer>(td::actor::ActorOptions().with_name("Writer").with_poll(), std::move(fd)).release();
  });
  scheduler.run();
}

int main(int argc, char **argv) {
  std::string from;
  enum Type { Read, Write };
  Type type{Write};
  enum Mode { Baseline, Buffered, Direct, Async, WriteV, Async2 };
  Mode mode = Baseline;
  size_t buffer_size = 1024;

  td::OptionsParser options_parser;
  options_parser.add_option('f', td::Slice("from"), td::Slice("read from file"), [&](td::Slice arg) -> td::Status {
    from = arg.str();
    return td::Status::OK();
  });
  options_parser.add_option('m', td::Slice("mode"), td::Slice("mode"), [&](td::Slice arg) -> td::Status {
    TRY_RESULT(x, td::to_integer_safe<int>(arg));
    switch (x) {
      case 0:
        mode = Baseline;
        return td::Status::OK();
      case 1:
        mode = Buffered;
        return td::Status::OK();
      case 2:
        mode = Direct;
        return td::Status::OK();
      case 3:
        mode = Async;
        return td::Status::OK();
      case 4:
        mode = WriteV;
        return td::Status::OK();
      case 5:
        mode = Async2;
        return td::Status::OK();
    }
    return td::Status::Error("unknown mode");
  });
  options_parser.add_option('b', td::Slice("buffer"), td::Slice("buffer size"), [&](td::Slice arg) -> td::Status {
    TRY_RESULT(x, td::to_integer_safe<size_t>(arg));
    buffer_size = x;
    return td::Status::OK();
  });

  auto status = options_parser.run(argc, argv);
  if (status.is_error()) {
    LOG(ERROR) << status.error() << "\n" << options_parser;
    return 0;
  }

  switch (type) {
    case Read:
      switch (mode) {
        case Baseline:
          read_baseline(from);
          break;
        case Buffered:
          read_buffered(from, buffer_size);
          break;
        case Direct:
          read_o_direct(from, buffer_size);
          break;
        case Async:
          read_async(from, buffer_size);
          break;
        case Async2:
        case WriteV:
          LOG(FATAL) << "Not supported mode for Read test";
      }
      break;
    case Write:
      switch (mode) {
        case Baseline:
          write_baseline(from, buffer_size);
          break;
        case Buffered:
          write_buffered(from, buffer_size);
          break;
        case WriteV:
          write_vector(from, buffer_size);
          break;
        case Async:
          write_async(from, buffer_size);
          break;
        case Async2:
          write_async2(from, buffer_size);
          break;
        case Direct:
          LOG(FATAL) << "Unimplemented";
      }
  }

  return 0;
}
