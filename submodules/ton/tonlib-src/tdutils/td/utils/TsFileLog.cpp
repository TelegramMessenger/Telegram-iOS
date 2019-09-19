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
#include "TsFileLog.h"

#include <limits>

namespace td {
namespace detail {
class TsFileLog : public LogInterface {
 public:
  Status init(string path) {
    path_ = std::move(path);
    for (int i = 0; i < (int)logs_.size(); i++) {
      logs_[i].id = i;
    }
    return init_info(&logs_[0]);
  }

  vector<string> get_file_paths() override {
    vector<string> res;
    for (auto &log : logs_) {
      res.push_back(get_path(&log));
    }
    return res;
  }

  void append(CSlice cslice) override {
    return append(cslice, -1);
  }
  void append(CSlice cslice, int log_level) override {
    get_current_logger()->append(cslice, log_level);
  }

 private:
  struct Info {
    FileLog log;
    std::atomic<bool> is_inited{false};
    int id;
  };
  static constexpr int MAX_THREAD_ID = 128;
  std::string path_;
  std::array<Info, MAX_THREAD_ID> logs_;

  LogInterface *get_current_logger() {
    auto *info = get_current_info();
    if (!info->is_inited.load(std::memory_order_relaxed)) {
      CHECK(init_info(info).is_ok());
    }
    return &info->log;
  }

  Info *get_current_info() {
    return &logs_[get_thread_id()];
  }

  Status init_info(Info *info) {
    TRY_STATUS(info->log.init(get_path(info), std::numeric_limits<int64>::max(), info->id == 0));
    info->is_inited = true;
    return Status::OK();
  }

  string get_path(Info *info) {
    if (info->id == 0) {
      return path_;
    }
    return PSTRING() << path_ << ".thread" << info->id << ".log";
  }

  void rotate() override {
    for (auto &info : logs_) {
      if (info.is_inited.load(std::memory_order_consume)) {
        info.log.rotate();
      }
    }
  }
};
}  // namespace detail

Result<td::unique_ptr<LogInterface>> TsFileLog::create(string path) {
  auto res = td::make_unique<detail::TsFileLog>();
  TRY_STATUS(res->init(path));
  return std::move(res);
}
}  // namespace td
