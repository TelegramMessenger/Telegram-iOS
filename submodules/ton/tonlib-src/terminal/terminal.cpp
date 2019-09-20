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
#include "terminal.hpp"
#include "td/utils/port/StdStreams.h"

#ifdef USE_READLINE
#include <readline/readline.h>
#include <readline/history.h>
#endif

#include "td/utils/find_boundary.h"

namespace td {

void TerminalLogInterface::append(CSlice slice, int log_level) {
  auto instance_ = TerminalIOImpl::instance();
  if (!instance_) {
    default_log_interface->append(slice, log_level);
  } else {
    instance_->deactivate_readline();
    std::string color;
    if (log_level == 0 || log_level == 1) {
      color = TC_RED;
    } else if (log_level == 2) {
      color = TC_YELLOW;
    } else {
      color = TC_GREEN;
    }
    td::TsCerr() << color << slice << TC_EMPTY;
    instance_->reactivate_readline();
    if (log_level == VERBOSITY_NAME(FATAL)) {
      process_fatal_error(slice);
    }
  }
}

void TerminalIOImpl::deactivate_readline() {
  out_mutex_.lock();
#ifdef USE_READLINE
  if (use_readline_) {
    saved_point_ = rl_point;
    saved_line_ = std::string(rl_line_buffer, rl_end);

    rl_set_prompt("");
    rl_replace_line("", 0);
    rl_redisplay();
  }
#endif
}

void TerminalIOImpl::reactivate_readline() {
#ifdef USE_READLINE
  if (use_readline_) {
    rl_set_prompt(prompt_.c_str());
    rl_point = saved_point_;
    rl_replace_line(saved_line_.c_str(), 0);
    rl_redisplay();
  }
#endif
  out_mutex_.unlock();
}

void TerminalIOImpl::output_line(std::string line) {
  deactivate_readline();
  Stdout().write(line).ensure();
  reactivate_readline();
}

void TerminalIOImpl::start_up() {
  instance_ = this;
  self_ = actor_id(this);

#ifndef USE_READLINE
  if (use_readline_) {
    use_readline_ = false;
    LOG(WARNING) << "disabling readline";
  }
#endif

#ifdef USE_READLINE
  if (use_readline_) {
    deactivate_readline();
    rl_getc_function = s_stdin_getc;
    rl_callback_handler_install(prompt_.c_str(), s_line);
    //rl_attempted_completion_function = tg_cli_completion;
    reactivate_readline();
  }
#endif

  td::actor::SchedulerContext::get()->get_poll().subscribe(stdin_.get_poll_info().extract_pollable_fd(this),
                                                           td::PollFlags::Read());
  loop();
}

void TerminalIOImpl::tear_down() {
  log_interface = default_log_interface;
  td::actor::SchedulerContext::get()->get_poll().unsubscribe(stdin_.get_poll_info().get_pollable_fd_ref());
  out_mutex_.lock();
#ifdef USE_READLINE
  if (use_readline_) {
    //out_mutex_.lock();
    rl_callback_handler_remove();
    //out_mutex_.unlock();
  }
#endif
  instance_ = nullptr;
  out_mutex_.unlock();
  log_interface_.release();  // TODO: actually release memory
}

/*void TerminalIOImpl::read_line() {
  LOG(DEBUG) << "read line";
  while (can_read(stdin_)) {
    LOG(DEBUG) << "read line it";
    if (buf_end_ == buf_size) {
      if (buf_start_ == 0) {
        LOG(FATAL) << "too long command";
      } else {
        std::memmove(buf_, buf_ + buf_start_, buf_end_ - buf_start_);
      }
    }
    auto t = buf_end_;
    CHECK(buf_end_ != buf_size);
    {
      auto R = stdin_.read(td::MutableSlice(buf_ + buf_end_, buf_size - buf_end_)).move_as_ok();
      buf_end_ += static_cast<uint32>(R);
    }
    while (t < buf_end_) {
      while (t < buf_end_ && buf_[t] != '\n') {
        t++;
      }
      if (t < buf_end_) {
        td::BufferSlice d{t - buf_start_};
        d.as_slice().copy_from(td::Slice(buf_ + buf_start_, t - buf_start_));
        callback_->line_cb(std::move(d));
        t++;
        buf_start_ = t;
      }
    }
  }
}*/

void TerminalIOImpl::loop() {
  stdin_.flush_read().ignore();
#ifdef USE_READLINE
  if (use_readline_) {
    while (!stdin_.input_buffer().empty()) {
      rl_callback_read_char();
    }
  } else {
#else
  if (1) {
#endif
    while (true) {
      auto cmd = process_stdin(&stdin_.input_buffer());
      if (cmd.is_error()) {
        break;
      }
      cmd_queue_.push(cmd.move_as_ok());
    }
  }

  while (!cmd_queue_.empty()) {
    auto cmd = std::move(cmd_queue_.front());
    cmd_queue_.pop();
    callback_->line_cb(std::move(cmd));
  }
}

td::Result<td::BufferSlice> TerminalIOImpl::process_stdin(td::ChainBufferReader *buffer) {
  auto found = td::find_boundary(buffer->clone(), "\n", buffer_pos_);

  if (!found) {
    return Status::Error("End of line not found");
  }

  auto data = buffer->cut_head(buffer_pos_).move_as_buffer_slice();
  if (!data.empty() && data[data.size() - 1] == '\r') {
    data.truncate(data.size() - 1);
  }
  buffer->advance(1);
  buffer_pos_ = 0;
  return std::move(data);
}

void TerminalIOImpl::s_line(char *line) {
#ifdef USE_READLINE
  /* Can use ^D (stty eof) to exit. */
  if (line == nullptr) {
    LOG(FATAL) << "Closed";
    return;
  }
  CHECK(instance_);
  if (*line) {
    add_history(line);
  }
  instance_->line_cb(line);
  rl_free(line);
#endif
}

int TerminalIOImpl::s_stdin_getc(FILE *) {
  return instance_->stdin_getc();
}

void TerminalIOImpl::set_log_interface() {
  if (!log_interface_) {
    log_interface_ = std::make_unique<TerminalLogInterface>();
  }
  log_interface = log_interface_.get();
}

int TerminalIOImpl::stdin_getc() {
  auto slice = stdin_.input_buffer().prepare_read();
  if (slice.empty()) {
    return EOF;
  }
  int res = slice[0];
  stdin_.input_buffer().confirm_read(1);
  return res;
}

void TerminalIOImpl::line_cb(std::string cmd) {
  cmd_queue_.push(td::BufferSlice{std::move(cmd)});
}

void TerminalIO::output(std::string line) {
  auto instance_ = TerminalIOImpl::instance();
  if (!instance_) {
    std::cout << line;
  } else {
    instance_->deactivate_readline();
    td::TsCerr() << line;
    instance_->reactivate_readline();
  }
}

void TerminalIO::output(td::Slice line) {
  auto instance_ = TerminalIOImpl::instance();
  if (!instance_) {
    td::TsCerr() << line;
  } else {
    instance_->deactivate_readline();
    td::TsCerr() << line;
    instance_->reactivate_readline();
  }
}

TerminalIOOutputter::~TerminalIOOutputter() {
  if (buffer_) {
    CHECK(sb_);
    TerminalIO::output(sb_->as_cslice());
    delete[] buffer_;
  }
}

td::actor::ActorOwn<TerminalIO> TerminalIO::create(std::string prompt, bool use_readline,
                                                   std::unique_ptr<Callback> callback) {
  return actor::create_actor<TerminalIOImpl>(actor::ActorOptions().with_name("terminal io").with_poll(), prompt,
                                             use_readline, std::move(callback));
}

TerminalIOImpl *TerminalIOImpl::instance_ = nullptr;

}  // namespace td
