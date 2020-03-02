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

#include "common/refcnt.hpp"
#include "vm/cellslice.h"
#include "vm/stack.hpp"
#include "vm/vmstate.h"
#include "vm/log.h"

namespace vm {

using td::Ref;

class VmState;
class Continuation;
class DispatchTable;

struct ControlRegs {
  static constexpr int creg_num = 4, dreg_num = 2, dreg_idx = 4;
  Ref<Continuation> c[creg_num];  // c0..c3
  Ref<Cell> d[dreg_num];          // c4..c5
  Ref<Tuple> c7;                  // c7
  bool clear();
  Ref<Continuation> get_c(unsigned idx) const {
    return idx < creg_num ? c[idx] : Ref<Continuation>{};
  }
  Ref<Cell> get_d(unsigned idx) const {
    idx -= dreg_idx;
    return idx < dreg_num ? d[idx] : Ref<Cell>{};
  }
  Ref<Tuple> get_c7() const {
    return c7;
  }
  StackEntry get(unsigned idx) const;
  static bool valid_idx(unsigned idx) {
    return idx < creg_num || (idx >= dreg_idx && idx < dreg_idx + dreg_num) || idx == 7;
  }
  void set_c0(Ref<Continuation> cont) {
    c[0] = std::move(cont);
  }
  void set_c1(Ref<Continuation> cont) {
    c[1] = std::move(cont);
  }
  void set_c2(Ref<Continuation> cont) {
    c[2] = std::move(cont);
  }
  void set_c3(Ref<Continuation> cont) {
    c[3] = std::move(cont);
  }
  void set_c4(Ref<Cell> cell) {
    d[0] = std::move(cell);
  }
  bool set_c(unsigned idx, Ref<Continuation> cont) {
    if (idx < creg_num) {
      c[idx] = std::move(cont);
      return true;
    } else {
      return false;
    }
  }
  bool set_d(unsigned idx, Ref<Cell> cell) {
    idx -= dreg_idx;
    if (idx < dreg_num) {
      d[idx] = std::move(cell);
      return true;
    } else {
      return false;
    }
  }
  bool set_c7(Ref<Tuple> tuple) {
    c7 = std::move(tuple);
    return true;
  }
  bool set(unsigned idx, StackEntry value);
  void define_c0(Ref<Continuation> cont) {
    if (c[0].is_null()) {
      c[0] = std::move(cont);
    }
  }
  void define_c1(Ref<Continuation> cont) {
    if (c[1].is_null()) {
      c[1] = std::move(cont);
    }
  }
  void define_c2(Ref<Continuation> cont) {
    if (c[2].is_null()) {
      c[2] = std::move(cont);
    }
  }
  bool define_c(unsigned idx, Ref<Continuation> cont) {
    if (idx < creg_num && c[idx].is_null()) {
      c[idx] = std::move(cont);
      return true;
    } else {
      return false;
    }
  }
  bool define_d(unsigned idx, Ref<Cell> cell) {
    idx -= dreg_idx;
    if (idx < dreg_num && d[idx].is_null()) {
      d[idx] = std::move(cell);
      return true;
    } else {
      return false;
    }
  }
  void define_c4(Ref<Cell> cell) {
    if (d[0].is_null()) {
      d[0] = std::move(cell);
    }
  }
  bool define_c7(Ref<Tuple> tuple) {
    if (c7.is_null()) {
      c7 = std::move(tuple);
    }
    return true;
  }
  bool define(unsigned idx, StackEntry value);
  ControlRegs& operator&=(const ControlRegs& save);  // clears all c[i]'s which are present in save
  ControlRegs& operator^=(const ControlRegs& save);  // sets c[i]=save.c[i] for all save.c[i] != 0
  ControlRegs& operator^=(ControlRegs&& save);
  bool serialize(CellBuilder& cb) const;
  bool deserialize(CellSlice& cs, int mode = 0);
  bool deserialize(Ref<Cell> root, int mode = 0);
};

struct ControlData {
  Ref<Stack> stack;
  ControlRegs save;
  int nargs;
  int cp;
  ControlData() : nargs(-1), cp(-1) {
  }
  ControlData(int _cp) : nargs(-1), cp(_cp) {
  }
  ControlData(Ref<Stack> _stack) : stack(std::move(_stack)), nargs(-1), cp(-1) {
  }
  ControlData(int _cp, Ref<Stack> _stack, int _nargs = -1) : stack(std::move(_stack)), nargs(_nargs), cp(_cp) {
  }
  bool clear();
  bool serialize(CellBuilder& cb) const;
  bool deserialize(CellSlice& cs, int mode = 0);
};

class Continuation : public td::CntObject {
 public:
  virtual int jump(VmState* st) const & = 0;
  virtual int jump_w(VmState* st) &;
  virtual ControlData* get_cdata() {
    return 0;
  }
  virtual const ControlData* get_cdata() const {
    return 0;
  }
  bool has_c0() const;
  Continuation() {
  }
  Continuation(const Continuation&) = default;
  Continuation(Continuation&&) {
  }
  Continuation& operator=(const Continuation&) {
    return *this;
  }
  Continuation& operator=(Continuation&&) {
    return *this;
  }
  ~Continuation() override = default;
  virtual bool serialize(CellBuilder& cb) const {
    return false;
  }
  bool serialize_ref(CellBuilder& cb) const;
  static Ref<Continuation> deserialize(CellSlice& cs, int mode = 0);
  static bool deserialize_to(CellSlice& cs, Ref<Continuation>& cont, int mode = 0) {
    return (cont = deserialize(cs, mode)).not_null();
  }
  static bool deserialize_to(Ref<Cell> cell, Ref<Continuation>& cont, int mode = 0);
};

class QuitCont : public Continuation {
  int exit_code;

 public:
  QuitCont(int _code = 0) : exit_code(_code) {
  }
  ~QuitCont() override = default;
  int jump(VmState* st) const & override {
    return ~exit_code;
  }
  bool serialize(CellBuilder& cb) const override;
  static Ref<QuitCont> deserialize(CellSlice& cs, int mode = 0);
};

class ExcQuitCont : public Continuation {
 public:
  ExcQuitCont() = default;
  ~ExcQuitCont() override = default;
  int jump(VmState* st) const & override;
  bool serialize(CellBuilder& cb) const override;
  static Ref<ExcQuitCont> deserialize(CellSlice& cs, int mode = 0);
};

class PushIntCont : public Continuation {
  int push_val;
  Ref<Continuation> next;

 public:
  PushIntCont(int val, Ref<Continuation> _next) : push_val(val), next(_next) {
  }
  ~PushIntCont() override = default;
  int jump(VmState* st) const & override;
  int jump_w(VmState* st) & override;
  bool serialize(CellBuilder& cb) const override;
  static Ref<PushIntCont> deserialize(CellSlice& cs, int mode = 0);
};

class RepeatCont : public Continuation {
  Ref<Continuation> body, after;
  long long count;

 public:
  RepeatCont(Ref<Continuation> _body, Ref<Continuation> _after, long long _count)
      : body(std::move(_body)), after(std::move(_after)), count(_count) {
  }
  ~RepeatCont() override = default;
  int jump(VmState* st) const & override;
  int jump_w(VmState* st) & override;
  bool serialize(CellBuilder& cb) const override;
  static Ref<RepeatCont> deserialize(CellSlice& cs, int mode = 0);
};

class AgainCont : public Continuation {
  Ref<Continuation> body;

 public:
  AgainCont(Ref<Continuation> _body) : body(std::move(_body)) {
  }
  ~AgainCont() override = default;
  int jump(VmState* st) const & override;
  int jump_w(VmState* st) & override;
  bool serialize(CellBuilder& cb) const override;
  static Ref<AgainCont> deserialize(CellSlice& cs, int mode = 0);
};

class UntilCont : public Continuation {
  Ref<Continuation> body, after;

 public:
  UntilCont(Ref<Continuation> _body, Ref<Continuation> _after) : body(std::move(_body)), after(std::move(_after)) {
  }
  ~UntilCont() override = default;
  int jump(VmState* st) const & override;
  int jump_w(VmState* st) & override;
  bool serialize(CellBuilder& cb) const override;
  static Ref<UntilCont> deserialize(CellSlice& cs, int mode = 0);
};

class WhileCont : public Continuation {
  Ref<Continuation> cond, body, after;
  bool chkcond;

 public:
  WhileCont(Ref<Continuation> _cond, Ref<Continuation> _body, Ref<Continuation> _after, bool _chk = true)
      : cond(std::move(_cond)), body(std::move(_body)), after(std::move(_after)), chkcond(_chk) {
  }
  ~WhileCont() override = default;
  int jump(VmState* st) const & override;
  int jump_w(VmState* st) & override;
  bool serialize(CellBuilder& cb) const override;
  static Ref<WhileCont> deserialize(CellSlice& cs, int mode = 0);
};

class ArgContExt : public Continuation {
  ControlData data;
  Ref<Continuation> ext;

 public:
  ArgContExt(Ref<Continuation> _ext) : data(), ext(std::move(_ext)) {
  }
  ArgContExt(Ref<Continuation> _ext, Ref<Stack> _stack) : data(std::move(_stack)), ext(std::move(_ext)) {
  }
  ArgContExt(Ref<Continuation> _ext, const ControlData& _cdata) : data(_cdata), ext(std::move(_ext)) {
  }
  ArgContExt(Ref<Continuation> _ext, ControlData&& _cdata) : data(std::move(_cdata)), ext(std::move(_ext)) {
  }
  ArgContExt(const ArgContExt&) = default;
  ArgContExt(ArgContExt&&) = default;
  ~ArgContExt() override = default;
  int jump(VmState* st) const & override;
  int jump_w(VmState* st) & override;
  ControlData* get_cdata() override {
    return &data;
  }
  const ControlData* get_cdata() const override {
    return &data;
  }
  td::CntObject* make_copy() const override {
    return new ArgContExt{*this};
  }
  bool serialize(CellBuilder& cb) const override;
  static Ref<ArgContExt> deserialize(CellSlice& cs, int mode = 0);
};

class OrdCont : public Continuation {
  ControlData data;
  Ref<CellSlice> code;
  friend class VmState;

 public:
  OrdCont() : data(), code() {
  }
  //OrdCont(Ref<CellSlice> _code) : data(), code(std::move(_code)) {}
  OrdCont(Ref<CellSlice> _code, int _cp) : data(_cp), code(std::move(_code)) {
  }
  //OrdCont(Ref<CellSlice> _code, Ref<Stack> _stack) : data(std::move(_stack)), code(std::move(_code)) {}
  OrdCont(Ref<CellSlice> _code, int _cp, Ref<Stack> _stack, int nargs = -1)
      : data(_cp, std::move(_stack), nargs), code(std::move(_code)) {
  }
  OrdCont(Ref<CellSlice> _code, const ControlData& _cdata) : data(_cdata), code(std::move(_code)) {
  }
  OrdCont(Ref<CellSlice> _code, ControlData&& _cdata) : data(std::move(_cdata)), code(std::move(_code)) {
  }
  OrdCont(const OrdCont&) = default;
  OrdCont(OrdCont&&) = default;
  ~OrdCont() override = default;

  td::CntObject* make_copy() const override {
    return new OrdCont{*this};
  }
  int jump(VmState* st) const & override;
  int jump_w(VmState* st) & override;

  ControlData* get_cdata() override {
    return &data;
  }
  const ControlData* get_cdata() const override {
    return &data;
  }
  Stack& get_stack() {
    return data.stack.write();
  }
  const Stack& get_stack_const() const {
    return *(data.stack);
  }
  Ref<Stack> get_stack_ref() const {
    return data.stack;
  }
  Ref<OrdCont> copy_ord() const & {
    return Ref<OrdCont>{true, *this};
  }
  Ref<OrdCont> copy_ord() && {
    return Ref<OrdCont>{true, *this};
  }
  bool serialize(CellBuilder& cb) const override;
  static Ref<OrdCont> deserialize(CellSlice& cs, int mode = 0);
};

ControlData* force_cdata(Ref<Continuation>& cont);
ControlRegs* force_cregs(Ref<Continuation>& cont);

}  // namespace vm
