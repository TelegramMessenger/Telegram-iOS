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
#include "td/utils/port/FileFd.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

class FileLog : public LogInterface {
  static constexpr int64 DEFAULT_ROTATE_THRESHOLD = 10 * (1 << 20);

 public:
  static Result<td::unique_ptr<LogInterface>> create(string path, int64 rotate_threshold = DEFAULT_ROTATE_THRESHOLD,
                                                     bool redirect_stderr = true);
  Status init(string path, int64 rotate_threshold = DEFAULT_ROTATE_THRESHOLD, bool redirect_stderr = true);

  Slice get_path() const;

  vector<string> get_file_paths() override;

  void set_rotate_threshold(int64 rotate_threshold);

  int64 get_rotate_threshold() const;

  void append(CSlice cslice, int log_level) override;

  void rotate() override;

 private:
  FileFd fd_;
  string path_;
  int64 size_ = 0;
  int64 rotate_threshold_ = 0;
  bool redirect_stderr_;

  void do_rotate();
};

}  // namespace td
