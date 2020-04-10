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

#include "StreamInterface.h"

#include "td/actor/actor.h"
#include "td/utils/port/FileFd.h"

namespace td {
class FileToStreamActor : public td::actor::Actor {
 public:
  struct Options {
    Options() {
    }
    int64 limit{-1};
    double read_tail_each{-1};
  };
  class Callback {
   public:
    virtual ~Callback() {
    }
    virtual void got_more() = 0;
  };
  FileToStreamActor(FileFd fd, StreamWriter writer, Options options = {});

  void set_callback(td::unique_ptr<Callback> callback);

 private:
  void got_more();
  void loop() override;
  FileFd fd_;
  StreamWriter writer_;
  td::unique_ptr<Callback> callback_;
  Options options_;
};
}  // namespace td
