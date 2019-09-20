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
#include "StreamToFileActor.h"

namespace td {
StreamToFileActor::StreamToFileActor(StreamReader reader, FileFd fd, FileSyncState::Writer sync_state, Options options)
    : reader_(std::move(reader)), fd_(std::move(fd)), sync_state_(std::move(sync_state)) {
}
void StreamToFileActor::set_callback(td::unique_ptr<Callback> callback) {
  callback_ = std::move(callback);
  callback_->on_sync_state_changed();
}

Result<bool> StreamToFileActor::is_closed() {
  if (!reader_.is_writer_closed()) {
    return false;
  }
  return reader_.writer_status().clone();
}

Status StreamToFileActor::do_flush_once() {
  auto size = reader_.reader_size();
  size_t total_written = 0;
  while (total_written < size) {
    auto io_slices = reader_.prepare_readv();
    TRY_RESULT(written, fd_.writev(io_slices));
    reader_.confirm_read(written);
    flushed_size_ += written;
    total_written += written;
  }
  return Status::OK();
}

Status StreamToFileActor::do_sync() {
  if (flushed_size_ == synced_size_) {
    return Status::OK();
  }
  TRY_STATUS(fd_.sync());
  synced_size_ = flushed_size_;
  return Status::OK();
}

void StreamToFileActor::schedule_sync() {
  if (synced_size_ == flushed_size_) {
    return;
  }
  if (sync_state_.get_requested_synced_size() > synced_size_) {
    sync_at_.relax(Timestamp::in(options_.immediate_sync_delay));
  } else {
    sync_at_.relax(Timestamp::in(options_.lazy_sync_delay));
  }
}

Result<bool> StreamToFileActor::do_loop() {
  // We must first check if writer is closed and then drain all data from reader
  // Otherwise there will be a race and some of data could be lost.
  // Also it could be useful to check error and stop immediately.
  TRY_RESULT(is_closed, is_closed());

  // Flush all data that is awailable on the at the beginning of loop
  TRY_STATUS(do_flush_once());

  if ((sync_at_ && sync_at_.is_in_past()) || is_closed) {
    TRY_STATUS(do_sync());
    sync_at_ = {};
  }

  bool need_update = sync_state_.set_synced_size(synced_size_) | sync_state_.set_flushed_size(flushed_size_);
  if (need_update && callback_) {
    callback_->on_sync_state_changed();
  }

  if (reader_.reader_size() == 0 && is_closed) {
    return true;
  }

  schedule_sync();
  return false;
}

void StreamToFileActor::start_up() {
  schedule_sync();
}

void StreamToFileActor::loop() {
  auto r_is_closed = do_loop();
  if (r_is_closed.is_error()) {
    reader_.close_reader(r_is_closed.move_as_error());
    return stop();
  } else if (r_is_closed.ok()) {
    reader_.close_reader(Status::OK());
    return stop();
  }
  alarm_timestamp() = sync_at_;
}
}  // namespace td
