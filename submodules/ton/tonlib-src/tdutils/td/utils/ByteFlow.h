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

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

class ByteFlowInterface {
 public:
  virtual void close_input(Status status) = 0;
  virtual void wakeup() = 0;
  virtual void set_parent(ByteFlowInterface &other) = 0;
  virtual void set_input(ChainBufferReader *input) = 0;
  virtual size_t get_need_size() = 0;
  ByteFlowInterface() = default;
  ByteFlowInterface(const ByteFlowInterface &) = delete;
  ByteFlowInterface &operator=(const ByteFlowInterface &) = delete;
  ByteFlowInterface(ByteFlowInterface &&) = default;
  ByteFlowInterface &operator=(ByteFlowInterface &&) = default;
  virtual ~ByteFlowInterface() = default;
};

class ByteFlowBaseCommon : public ByteFlowInterface {
 public:
  ByteFlowBaseCommon() = default;

  void close_input(Status status) final {
    if (status.is_error()) {
      finish(std::move(status));
    } else {
      is_input_active_ = false;
      wakeup();
    }
  }

  void wakeup() final {
    if (stop_flag_) {
      return;
    }
    input_->sync_with_writer();
    if (waiting_flag_) {
      if (!is_input_active_) {
        finish(Status::OK());
      }
      return;
    }
    if (is_input_active_) {
      if (need_size_ != 0 && input_->size() < need_size_) {
        return;
      }
    }
    need_size_ = 0;
    loop();
  }

  size_t get_need_size() final {
    return need_size_;
  }

  virtual void loop() = 0;

 protected:
  bool waiting_flag_ = false;
  ChainBufferReader *input_ = nullptr;
  bool is_input_active_ = true;
  size_t need_size_ = 0;
  void finish(Status status) {
    stop_flag_ = true;
    need_size_ = 0;
    if (parent_) {
      parent_->close_input(std::move(status));
      parent_ = nullptr;
    }
  }

  void set_need_size(size_t need_size) {
    need_size_ = need_size;
  }

  void on_output_updated() {
    if (parent_) {
      parent_->wakeup();
    }
  }
  void consume_input() {
    waiting_flag_ = true;
    if (!is_input_active_) {
      finish(Status::OK());
    }
  }

 private:
  ByteFlowInterface *parent_ = nullptr;
  bool stop_flag_ = false;
  friend class ByteFlowBase;
  friend class ByteFlowInplaceBase;
};

class ByteFlowBase : public ByteFlowBaseCommon {
 public:
  ByteFlowBase() = default;

  void set_input(ChainBufferReader *input) final {
    input_ = input;
  }
  void set_parent(ByteFlowInterface &other) final {
    parent_ = &other;
    parent_->set_input(&output_reader_);
  }
  void loop() override = 0;

  // ChainBufferWriter &get_output() {
  // return output_;
  //}

 protected:
  ChainBufferWriter output_;
  ChainBufferReader output_reader_ = output_.extract_reader();
};

class ByteFlowInplaceBase : public ByteFlowBaseCommon {
 public:
  ByteFlowInplaceBase() = default;

  void set_input(ChainBufferReader *input) final {
    input_ = input;
    output_ = ChainBufferReader(input_->begin().clone(), input_->begin().clone(), false);
  }
  void set_parent(ByteFlowInterface &other) final {
    parent_ = &other;
    parent_->set_input(&output_);
  }
  void loop() override = 0;

  ChainBufferReader &get_output() {
    return output_;
  }

 protected:
  ChainBufferReader output_;
};

inline ByteFlowInterface &operator>>(ByteFlowInterface &from, ByteFlowInterface &to) {
  from.set_parent(to);
  return to;
}

class ByteFlowSource : public ByteFlowInterface {
 public:
  ByteFlowSource() = default;
  explicit ByteFlowSource(ChainBufferReader *buffer) : buffer_(buffer) {
  }
  ByteFlowSource(ByteFlowSource &&other) : buffer_(other.buffer_), parent_(other.parent_) {
    other.buffer_ = nullptr;
    other.parent_ = nullptr;
  }
  ByteFlowSource &operator=(ByteFlowSource &&other) {
    buffer_ = other.buffer_;
    parent_ = other.parent_;
    other.buffer_ = nullptr;
    other.parent_ = nullptr;
    return *this;
  }
  ByteFlowSource(const ByteFlowSource &) = delete;
  ByteFlowSource &operator=(const ByteFlowSource &) = delete;
  ~ByteFlowSource() override = default;

  void set_input(ChainBufferReader *) final {
    UNREACHABLE();
  }
  void set_parent(ByteFlowInterface &parent) final {
    CHECK(parent_ == nullptr);
    parent_ = &parent;
    parent_->set_input(buffer_);
  }
  void close_input(Status status) final {
    CHECK(parent_);
    parent_->close_input(std::move(status));
    parent_ = nullptr;
  }
  void wakeup() final {
    CHECK(parent_);
    parent_->wakeup();
  }
  size_t get_need_size() final {
    if (parent_ == nullptr) {
      return 0;
    }
    return parent_->get_need_size();
  }

 private:
  ChainBufferReader *buffer_ = nullptr;
  ByteFlowInterface *parent_ = nullptr;
};

class ByteFlowSink : public ByteFlowInterface {
 public:
  void set_input(ChainBufferReader *input) final {
    CHECK(buffer_ == nullptr);
    buffer_ = input;
  }
  void set_parent(ByteFlowInterface & /*parent*/) final {
    UNREACHABLE();
  }
  void close_input(Status status) final {
    CHECK(active_);
    active_ = false;
    status_ = std::move(status);
    buffer_->sync_with_writer();
  }
  void wakeup() final {
    buffer_->sync_with_writer();
  }
  size_t get_need_size() final {
    UNREACHABLE();
    return 0;
  }
  bool is_ready() {
    return !active_;
  }
  Status &status() {
    return status_;
  }
  ChainBufferReader *result() {
    CHECK(is_ready() && status().is_ok());
    return buffer_;
  }
  ChainBufferReader *get_output() {
    return buffer_;
  }

 private:
  bool active_ = true;
  Status status_;
  ChainBufferReader *buffer_ = nullptr;
};

class ByteFlowMoveSink : public ByteFlowInterface {
 public:
  ByteFlowMoveSink() = default;
  explicit ByteFlowMoveSink(ChainBufferWriter *output) {
    set_output(output);
  }
  void set_input(ChainBufferReader *input) final {
    CHECK(!input_);
    input_ = input;
  }
  void set_parent(ByteFlowInterface & /*parent*/) final {
    UNREACHABLE();
  }
  void close_input(Status status) final {
    CHECK(active_);
    active_ = false;
    status_ = std::move(status);
    wakeup();
  }
  void wakeup() final {
    input_->sync_with_writer();
    output_->append(*input_);
  }
  size_t get_need_size() final {
    UNREACHABLE();
    return 0;
  }
  void set_output(ChainBufferWriter *output) {
    CHECK(!output_);
    output_ = output;
  }

  bool is_ready() {
    return !active_;
  }
  Status &status() {
    return status_;
  }

 private:
  bool active_ = true;
  Status status_;
  ChainBufferReader *input_ = nullptr;
  ChainBufferWriter *output_ = nullptr;
};
}  // namespace td
