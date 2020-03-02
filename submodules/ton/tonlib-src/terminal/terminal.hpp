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

#include "terminal.h"
#include <iostream>
#include "td/utils/port/FileFd.h"
#include "td/utils/port/StdStreams.h"
#include <queue>

namespace td {

class TerminalLogInterface : public LogInterface {
 public:
  void append(CSlice slice, int log_level) override;
};

class TerminalIOImpl : public TerminalIO, td::ObserverBase {
 public:
  void refresh() {
  }
  void update_prompt(std::string new_prompt) override {
    prompt_ = new_prompt;
    refresh();
  };
  void update_callback(std::unique_ptr<Callback> callback) override {
    callback_ = std::move(callback);
  }
  void deactivate_readline();
  void reactivate_readline();
  void output_line(std::string line) override;
  void output_line_stderr(std::string line) override;
  bool readline_used() const override {
    return use_readline_;
  }
  void set_log_interface() override;
  //void read_line();
  void loop() override;
  void start_up() override;
  void tear_down() override;

  static TerminalIOImpl *instance() {
    return instance_;
  }

  void notify() override {
    // NB: Interface will be changed
    td::actor::send_closure_later(self_, &TerminalIOImpl::on_net);
  }
  void on_net() {
    loop();
  }
  TerminalIOImpl(std::string prompt, bool use_readline, std::unique_ptr<Callback> callback)
      : prompt_(prompt), use_readline_(use_readline), callback_(std::move(callback)) {
  }

  int stdin_getc();
  void line_cb(std::string line);
  static int s_stdin_getc(FILE *);
  static void s_line(char *line);

  td::Result<td::BufferSlice> process_stdin(td::ChainBufferReader *buffer);

 private:
  static constexpr td::uint32 buf_size = 1 << 20;
  td::BufferedStdin stdin_;

  std::string prompt_;
  bool use_readline_ = false;
  std::unique_ptr<Callback> callback_;
  std::mutex out_mutex_;

  char buf_[buf_size];
  td::uint32 buf_start_ = 0;
  td::uint32 buf_end_ = 0;

  static TerminalIOImpl *instance_;
  td::actor::ActorId<TerminalIOImpl> self_;
  std::unique_ptr<TerminalLogInterface> log_interface_;

  td::uint32 saved_point_;
  std::string saved_line_;
  size_t buffer_pos_ = 0;

  std::queue<td::BufferSlice> cmd_queue_;
};

}  // namespace td
