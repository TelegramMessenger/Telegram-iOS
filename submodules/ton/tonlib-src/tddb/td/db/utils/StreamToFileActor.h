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
#pragma once
#include "StreamInterface.h"
#include "FileSyncState.h"

#include "td/utils/Time.h"
#include "td/utils/port/FileFd.h"

#include "td/actor/actor.h"

namespace td {
class StreamToFileActor : public actor::Actor {
 public:
  struct Options {
    Options() {
    }
    double lazy_sync_delay = 10;
    double immediate_sync_delay = 0.001;
  };

  class Callback {
   public:
    virtual ~Callback() {
    }
    virtual void on_sync_state_changed() = 0;
  };

  StreamToFileActor(StreamReader reader, FileFd fd, FileSyncState::Writer sync_state, Options options = {});
  void set_callback(td::unique_ptr<Callback> callback);

 private:
  StreamReader reader_;
  FileFd fd_;
  Timestamp sync_at_;
  Options options_;
  FileSyncState::Writer sync_state_;
  unique_ptr<Callback> callback_;

  size_t flushed_size_{0};
  size_t synced_size_{0};

  TD_WARN_UNUSED_RESULT Result<bool> is_closed();

  Status do_flush_once();

  Status do_sync();

  void schedule_sync();

  TD_WARN_UNUSED_RESULT Result<bool> do_loop();

  void start_up() override;

  void loop() override;
};
}  // namespace td
