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

#include "vm/cells.h"
#include "vm/stack.hpp"
#include "vm/vm.h"

#include "td/utils/optional.h"
#include "td/utils/crypto.h"

#include "block/block.h"

namespace ton {
class SmartContract : public td::CntObject {
  static td::Ref<vm::CellSlice> empty_slice();

 public:
  struct State {
    td::Ref<vm::Cell> code;
    td::Ref<vm::Cell> data;
  };

  SmartContract(State state) : state_(std::move(state)) {
  }

  struct Answer {
    SmartContract::State new_state;
    bool accepted;
    bool success;
    td::Ref<vm::Stack> stack;
    td::Ref<vm::Cell> actions;
    td::int32 code;
    td::int64 gas_used;
  };

  struct Args {
    td::optional<td::int32> method_id;
    td::optional<vm::GasLimits> limits;
    td::optional<td::Ref<vm::Tuple>> c7;
    td::optional<td::Ref<vm::Stack>> stack;
    td::optional<td::int32> now;
    bool ignore_chksig{false};

    Args() {
    }
    Args(std::initializer_list<vm::StackEntry> stack)
        : stack(td::Ref<vm::Stack>(true, std::vector<vm::StackEntry>(std::move(stack)))) {
    }
    Args&& set_now(int now) {
      this->now = now;
      return std::move(*this);
    }
    Args&& set_method_id(td::Slice method_name) {
      unsigned crc = td::crc16(method_name);
      return set_method_id((crc & 0xffff) | 0x10000);
    }
    Args&& set_method_id(td::int32 method_id) {
      this->method_id = method_id;
      return std::move(*this);
    }
    Args&& set_limits(vm::GasLimits limits) {
      this->limits = std::move(limits);
      return std::move(*this);
    }
    Args&& set_c7(td::Ref<vm::Tuple> c7) {
      this->c7 = std::move(c7);
      return std::move(*this);
    }
    Args&& set_stack(std::vector<vm::StackEntry> stack) {
      this->stack = td::Ref<vm::Stack>(true, std::move(stack));
      return std::move(*this);
    }
    Args&& set_stack(td::Ref<vm::Stack> stack) {
      this->stack = std::move(stack);
      return std::move(*this);
    }
    Args&& set_ignore_chksig(bool ignore_chksig) {
      this->ignore_chksig = ignore_chksig;
      return std::move(*this);
    }

    td::Result<td::int32> get_method_id() const {
      if (!method_id) {
        return td::Status::Error("Args has no method id");
      }
      return method_id.value();
    }
    td::Result<td::BufferSlice> get_serialized_stack();
  };

  Answer run_method(Args args = {});
  Answer run_get_method(Args args = {}) const;
  Answer run_get_method(td::Slice method, Args args = {}) const;
  Answer send_external_message(td::Ref<vm::Cell> cell, Args args = {});

  size_t code_size() const;
  size_t data_size() const;
  static td::Ref<SmartContract> create(State state) {
    return td::Ref<SmartContract>{true, std::move(state)};
  }

  block::StdAddress get_address(WorkchainId workchain_id = basechainId) const;
  td::Ref<vm::Cell> get_init_state() const;

  const State& get_state() const {
    return state_;
  }

 protected:
  State state_;
};
}  // namespace ton
