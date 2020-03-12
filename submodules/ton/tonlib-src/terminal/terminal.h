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

#include "td/actor/actor.h"
#include "td/utils/buffer.h"

#include <functional>
#include <ostream>

namespace td {

class TerminalIOOutputter {
 public:
  static const size_t BUFFER_SIZE = 128 * 1024;
  TerminalIOOutputter(bool is_err)
      : buffer_(new char[BUFFER_SIZE])
      , is_err_(is_err)
      , sb_(std::make_unique<StringBuilder>(td::MutableSlice{buffer_, BUFFER_SIZE}, true)) {
  }
  TerminalIOOutputter(TerminalIOOutputter &&X) = default;

  template <class T>
  TerminalIOOutputter &operator<<(const T &other) {
    *sb_ << other;
    return *this;
  }
  TerminalIOOutputter &operator<<(std::ostream &(*pManip)(std::ostream &)) {
    *sb_ << '\n';
    return *this;
  }

  auto &sb() {
    return *sb_;
  }

  MutableCSlice as_cslice() {
    return sb_->as_cslice();
  }
  bool is_error() const {
    return sb_->is_error();
  }
  void flush();
  ~TerminalIOOutputter();

 private:
  char *buffer_;
  bool is_err_;
  std::unique_ptr<StringBuilder> sb_;
};

class TerminalIO : public actor::Actor {
 public:
  class Callback {
   public:
    virtual ~Callback() = default;
    virtual void line_cb(td::BufferSlice line) = 0;
    //virtual std::vector<std::string> autocomplete_cb(std::string line) = 0;
  };

  virtual ~TerminalIO() = default;
  virtual void update_prompt(std::string new_prompt) = 0;
  virtual void update_callback(std::unique_ptr<Callback> callback) = 0;
  static void output(std::string line);
  static void output(td::Slice slice);
  static void output_stderr(std::string line);
  static void output_stderr(td::Slice slice);
  static void output_stdout(td::Slice line, double max_wait);
  static TerminalIOOutputter out() {
    return TerminalIOOutputter{false};
  }
  static TerminalIOOutputter err() {
    return TerminalIOOutputter{true};
  }
  virtual void output_line(std::string line) = 0;
  virtual void output_line_stderr(std::string line) = 0;
  virtual void set_log_interface() = 0;
  virtual bool readline_used() const = 0;

  static td::actor::ActorOwn<TerminalIO> create(std::string prompt, bool use_readline,
                                                std::unique_ptr<Callback> callback);
};

}  // namespace td
