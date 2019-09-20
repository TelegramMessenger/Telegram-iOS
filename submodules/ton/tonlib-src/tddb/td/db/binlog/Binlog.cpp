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
#include "Binlog.h"

#include "BinlogReaderHelper.h"

#include "td/db/utils/StreamInterface.h"
#include "td/db/utils/ChainBuffer.h"
#include "td/db/utils/CyclicBuffer.h"
#include "td/db/utils/FileSyncState.h"
#include "td/db/utils/StreamToFileActor.h"
#include "td/db/utils/FileToStreamActor.h"

#include "td/actor/actor.h"

#include "td/utils/misc.h"
#include "td/utils/port/path.h"
#include "td/utils/VectorQueue.h"

namespace td {
namespace {
class BinlogReplayActor : public actor::Actor {
 public:
  BinlogReplayActor(StreamReader stream_reader, actor::ActorOwn<FileToStreamActor> file_to_stream,
                    std::shared_ptr<BinlogReaderInterface> binlog_reader, Promise<Unit> promise)
      : stream_reader_(std::move(stream_reader))
      , file_to_stream_(std::move(file_to_stream))
      , binlog_reader_(std::move(binlog_reader))
      , promise_(std::move(promise)) {
  }

 private:
  StreamReader stream_reader_;
  actor::ActorOwn<FileToStreamActor> file_to_stream_;
  std::shared_ptr<BinlogReaderInterface> binlog_reader_;
  Promise<Unit> promise_;

  bool is_writer_closed_{false};
  BinlogReaderHelper binlog_reader_helper_;

  unique_ptr<FileToStreamActor::Callback> create_callback() {
    class Callback : public FileToStreamActor::Callback {
     public:
      Callback(actor::ActorShared<> actor) : actor_(std::move(actor)) {
      }
      void got_more() override {
        send_signals_later(actor_, actor::ActorSignals::wakeup());
      }

     private:
      actor::ActorShared<> actor_;
    };
    return make_unique<Callback>(actor_shared(this));
  }

  void start_up() override {
    send_closure_later(file_to_stream_, &FileToStreamActor::set_callback, create_callback());
  }
  void notify_writer() {
    send_signals_later(file_to_stream_, actor::ActorSignals::wakeup());
  }

  void loop() override {
    auto status = do_loop();
    if (status.is_error()) {
      stream_reader_.close_reader(status.clone());
      promise_.set_error(std::move(status));
      return stop();
    }
    if (is_writer_closed_) {
      stream_reader_.close_reader(Status::OK());
      promise_.set_value(Unit());
      return stop();
    }
  }
  Status do_loop() {
    is_writer_closed_ = stream_reader_.is_writer_closed();
    if (is_writer_closed_) {
      TRY_STATUS(std::move(stream_reader_.writer_status()));
    }

    // TODO: watermark want_more/got_more logic
    int64 got_size = stream_reader_.reader_size();
    while (got_size > 0) {
      auto slice = stream_reader_.prepare_read();
      TRY_STATUS(binlog_reader_helper_.parse(*binlog_reader_, slice));
      stream_reader_.confirm_read(slice.size());
      got_size -= slice.size();
    }
    notify_writer();

    if (is_writer_closed_) {
      if (binlog_reader_helper_.unparsed_size() != 0) {
        return Status::Error(PSLICE() << "Got " << binlog_reader_helper_.unparsed_size()
                                      << " unparsed bytes in binlog");
      }
    }

    return Status::OK();
  }
};
}  // namespace
Binlog::Binlog(string path) : path_(std::move(path)) {
}

Status Binlog::replay_sync(BinlogReaderInterface& binlog_reader) {
  TRY_RESULT(fd, FileFd::open(path_, FileFd::Flags::Read));
  // No need to use Cyclic buffer, but CyclicBuffer is important for async version
  CyclicBuffer::Options options;
  options.chunk_size = 256;
  options.count = 1;
  auto reader_writer = CyclicBuffer::create(options);

  auto buf_reader = std::move(reader_writer.first);
  auto buf_writer = std::move(reader_writer.second);

  TRY_RESULT(fd_size, fd.get_size());

  BinlogReaderHelper helper;
  while (fd_size != 0) {
    auto read_to = buf_writer.prepare_write();
    if (static_cast<int64>(read_to.size()) > fd_size) {
      read_to.truncate(narrow_cast<size_t>(fd_size));
    }
    TRY_RESULT(read, fd.read(read_to));
    if (read == 0) {
      return Status::Error("Unexpected end of file");
    }
    fd_size -= read;
    buf_writer.confirm_write(read);

    auto data = buf_reader.prepare_read();
    CHECK(data.size() == read);
    TRY_STATUS(helper.parse(binlog_reader, data));
    buf_reader.confirm_read(data.size());
  }

  if (helper.unparsed_size() != 0) {
    return Status::Error(PSLICE() << "Got " << helper.unparsed_size() << " unparsed bytes in binlog");
  }

  //TODO: check crc32
  //TODO: allow binlog truncate
  return Status::OK();
}

void Binlog::replay_async(std::shared_ptr<BinlogReaderInterface> binlog_reader, Promise<Unit> promise) {
  auto r_fd = FileFd::open(path_, FileFd::Flags::Read);
  if (r_fd.is_error()) {
    promise.set_error(r_fd.move_as_error());
    return;
  }
  auto fd = r_fd.move_as_ok();
  CyclicBuffer::Options buf_options;
  buf_options.chunk_size = 256;
  auto reader_writer = CyclicBuffer::create(buf_options);

  auto buf_reader = std::move(reader_writer.first);
  auto buf_writer = std::move(reader_writer.second);

  auto r_fd_size = fd.get_size();
  if (r_fd_size.is_error()) {
    promise.set_error(r_fd_size.move_as_error());
  }
  auto options = FileToStreamActor::Options{};
  options.limit = r_fd_size.move_as_ok();
  auto file_to_stream =
      actor::create_actor<FileToStreamActor>("FileToStream", std::move(fd), std::move(buf_writer), options);
  auto stream_to_binlog = actor::create_actor<BinlogReplayActor>(
      "BinlogReplay", std::move(buf_reader), std::move(file_to_stream), std::move(binlog_reader), std::move(promise));
  stream_to_binlog.release();
}

void Binlog::destroy(CSlice path) {
  td::unlink(path).ignore();
}

void Binlog::destroy() {
  destroy(path_);
}

BinlogWriter::BinlogWriter(std::string path) : path_(std::move(path)) {
}

Status BinlogWriter::open() {
  TRY_RESULT(fd, FileFd::open(path_, FileFd::Flags::Write | FileFd::Flags::Append | FileFd::Create));
  fd_ = std::move(fd);
  ChainBuffer::Options buf_options;
  buf_options.max_io_slices = 128;
  buf_options.chunk_size = 256;
  auto reader_writer = ChainBuffer::create(buf_options);
  buf_reader_ = std::move(reader_writer.first);
  buf_writer_ = std::move(reader_writer.second);
  return Status::OK();
}

Status BinlogWriter::lazy_flush() {
  if (buf_reader_.reader_size() < 512) {
    return Status::OK();
  }
  return flush();
}

Status BinlogWriter::flush() {
  while (buf_reader_.reader_size() != 0) {
    TRY_RESULT(written, fd_.writev(buf_reader_.prepare_readv()));
    buf_reader_.confirm_read(written);
  }
  return Status::OK();
}
Status BinlogWriter::sync() {
  flush();
  return fd_.sync();
}

Status BinlogWriter::close() {
  sync();
  fd_.close();
  return Status::OK();
}

namespace detail {
class FlushHelperActor : public actor::Actor {
 public:
  FlushHelperActor(FileSyncState::Reader sync_state_reader, actor::ActorOwn<StreamToFileActor> actor)
      : sync_state_reader_(std::move(sync_state_reader)), actor_(std::move(actor)) {
  }
  void flush() {
    //TODO;
  }
  void sync(size_t position, Promise<Unit> promise) {
    sync_state_reader_.set_requested_sync_size(position);
    if (promise) {
      queries_.emplace(position, std::move(promise));
    }
    send_signals_later(actor_, actor::ActorSignals::wakeup());
  }

  void close(Promise<> promise) {
    close_promise_ = std::move(promise);
    actor_.reset();
  }

 private:
  FileSyncState::Reader sync_state_reader_;
  actor::ActorOwn<StreamToFileActor> actor_;
  Promise<> close_promise_;

  struct Query {
    Query(size_t position, Promise<Unit> promise) : position(position), promise(std::move(promise)) {
    }
    size_t position;
    Promise<Unit> promise;
  };
  VectorQueue<Query> queries_;

  unique_ptr<StreamToFileActor::Callback> create_callback() {
    class Callback : public StreamToFileActor::Callback {
     public:
      Callback(actor::ActorShared<> actor) : actor_(std::move(actor)) {
      }
      void on_sync_state_changed() override {
        send_signals_later(actor_, actor::ActorSignals::wakeup());
      }

     private:
      actor::ActorShared<> actor_;
    };
    return make_unique<Callback>(actor_shared(this));
  }

  void start_up() override {
    send_closure_later(actor_, &StreamToFileActor::set_callback, create_callback());
  }

  void loop() override {
    auto synced_position = sync_state_reader_.synced_size();
    while (!queries_.empty() && queries_.front().position <= synced_position) {
      queries_.front().promise.set_value(Unit());
      queries_.pop();
    }
  }

  void hangup_shared() override {
    stop();
  }
  void tear_down() override {
    if (close_promise_) {
      close_promise_.set_value(Unit());
    }
  }
};
}  // namespace detail
BinlogWriterAsync::BinlogWriterAsync(std::string path) : path_(std::move(path)) {
}
BinlogWriterAsync::~BinlogWriterAsync() = default;

Status BinlogWriterAsync::open() {
  TRY_RESULT(fd, FileFd::open(path_, FileFd::Flags::Write | FileFd::Flags::Append | FileFd::Create));
  ChainBuffer::Options buf_options;
  buf_options.max_io_slices = 128;
  buf_options.chunk_size = 256;
  auto reader_writer = ChainBuffer::create(buf_options);
  buf_writer_ = std::move(reader_writer.second);

  auto sync_state_reader_writer = td::FileSyncState::create();
  auto writer_actor = actor::create_actor<StreamToFileActor>("StreamToFile", std::move(reader_writer.first),
                                                             std::move(fd), std::move(sync_state_reader_writer.second));
  writer_actor_ = writer_actor.get();
  sync_state_reader_ = std::move(sync_state_reader_writer.first);

  flush_helper_actor_ =
      actor::create_actor<detail::FlushHelperActor>("FlushHelperActor", sync_state_reader_, std::move(writer_actor));

  return Status::OK();
}

void BinlogWriterAsync::close(Promise<> promise) {
  send_closure(std::move(flush_helper_actor_), &detail::FlushHelperActor::close, std::move(promise));
  writer_actor_ = {};
}
void BinlogWriterAsync::lazy_flush() {
  send_signals_later(writer_actor_, actor::ActorSignals::wakeup());
}

void BinlogWriterAsync::flush() {
  send_closure(flush_helper_actor_, &detail::FlushHelperActor::flush);
}
void BinlogWriterAsync::sync(Promise<Unit> promise) {
  send_closure(flush_helper_actor_, &detail::FlushHelperActor::sync, buf_writer_.writer_size(), std::move(promise));
}

}  // namespace td
