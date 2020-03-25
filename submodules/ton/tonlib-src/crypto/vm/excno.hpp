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

#include "td/utils/Status.h"

namespace vm {

enum class Excno : int {
  none = 0,
  alt = 1,
  stk_und = 2,
  stk_ov = 3,
  int_ov = 4,
  range_chk = 5,
  inv_opcode = 6,
  type_chk = 7,
  cell_ov = 8,
  cell_und = 9,
  dict_err = 10,
  unknown = 11,
  fatal = 12,
  out_of_gas = 13,
  virt_err = 14,
  total
};

const char* get_exception_msg(Excno exc_no);

class VmError {
  Excno exc_no;
  bool msg_alloc = false;
  const char* msg;
  long long arg;

 public:
  VmError(Excno _excno, const char* _msg) : exc_no(_excno), msg(_msg), arg(0) {
  }
  VmError(Excno _excno) : exc_no(_excno), msg(0), arg(0) {
  }
  VmError(Excno _excno, const char* _msg, long long _arg) : exc_no(_excno), msg(_msg), arg(_arg) {
  }
  VmError(Excno _excno, std::string _msg, long long _arg = 0) : exc_no(_excno), msg_alloc(true), arg(_arg) {
    msg_alloc = true;
    char* p = (char*)malloc(_msg.size() + 1);
    memcpy(p, _msg.data(), _msg.size());
    p[_msg.size()] = 0;
    msg = p;
  }
  ~VmError() {
    if (msg_alloc) {
      free(const_cast<char*>(msg));
    }
  }
  int get_errno() const {
    return static_cast<int>(exc_no);
  }
  const char* get_msg() const {
    return msg ? msg : get_exception_msg(exc_no);
  }
  long long get_arg() const {
    return arg;
  }
};

struct VmNoGas {
  VmNoGas() = default;
  int get_errno() const {
    return static_cast<int>(Excno::out_of_gas);
  }
  const char* get_msg() const {
    return "out of gas";
  }
  operator VmError() const {
    return VmError{Excno::out_of_gas, "out of gas"};
  }
};

struct VmVirtError {
  int virtualization{0};
  VmVirtError() = default;
  VmVirtError(int virtualization) : virtualization(virtualization) {
  }
  int get_errno() const {
    return static_cast<int>(Excno::virt_err);
  }
  const char* get_msg() const {
    return "prunned branch";
  }
  operator VmError() const {
    return VmError{Excno::virt_err, "prunned branch", virtualization};
  }
};

struct VmFatal {};

template <class F>
auto try_f(F&& f) noexcept -> decltype(f()) {
  try {
    return f();
  } catch (vm::VmError error) {
    return td::Status::Error(PSLICE() << "Got a vm exception: " << error.get_msg());
  } catch (vm::VmVirtError error) {
    return td::Status::Error(PSLICE() << "Got a vm virtualization exception: " << error.get_msg());
  } catch (vm::VmNoGas error) {
    return td::Status::Error(PSLICE() << "Got a vm no gas exception: " << error.get_msg());
  }
}

#define TRY_VM(f) ::vm::try_f([&] { return f; })

}  // namespace vm
