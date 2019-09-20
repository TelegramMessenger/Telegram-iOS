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
#include "FileToStreamActor.h"

namespace td {
FileToStreamActor::FileToStreamActor(FileFd fd, StreamWriter writer, Options options)
    : fd_(std::move(fd)), writer_(std::move(writer)), options_(options) {
}

void FileToStreamActor::set_callback(td::unique_ptr<Callback> callback) {
  callback_ = std::move(callback);
  got_more();
}

void FileToStreamActor::got_more() {
  if (!callback_) {
    return;
  }
  callback_->got_more();
}
void FileToStreamActor::loop() {
  auto dest = writer_.prepare_write();
  if (options_.limit != -1) {
    if (static_cast<int64>(dest.size()) > options_.limit) {
      dest.truncate(narrow_cast<size_t>(options_.limit));
    }
  }
  if (dest.empty()) {
    //NB: Owner of CyclicBufer::Reader should notify this actor after each chunk is readed
    return;
  }

  auto r_size = fd_.read(dest);
  if (r_size.is_error()) {
    writer_.close_writer(r_size.move_as_error());
    got_more();
    return stop();
  }
  auto size = r_size.move_as_ok();
  writer_.confirm_write(size);
  got_more();
  if (options_.limit != -1) {
    options_.limit -= narrow_cast<int64>(size);
  }
  if (options_.limit == 0) {
    writer_.close_writer(td::Status::OK());
    got_more();
    return stop();
  }
  if (size == 0) {
    if (options_.read_tail_each < 0) {
      writer_.close_writer(td::Status::OK());
      got_more();
      return stop();
    }
    alarm_timestamp() = Timestamp::in(options_.read_tail_each);
    return;
  }
  yield();
}

}  // namespace td
