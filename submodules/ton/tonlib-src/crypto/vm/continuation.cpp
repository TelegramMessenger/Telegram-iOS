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
#include "vm/dispatch.h"
#include "vm/continuation.h"
#include "vm/dict.h"
#include "vm/log.h"
#include "vm/vm.h"
#include "vm/vmstate.h"

namespace vm {

int Continuation::jump_w(VmState* st) & {
  return static_cast<const Continuation*>(this)->jump(st);
}

bool Continuation::has_c0() const {
  const ControlData* cont_data = get_cdata();
  return cont_data && cont_data->save.c[0].not_null();
}

bool ControlRegs::clear() {
  for (unsigned i = 0; i < creg_num; i++) {
    c[i].clear();
  }
  for (unsigned i = 0; i < dreg_num; i++) {
    d[i].clear();
  }
  c7.clear();
  return true;
}

StackEntry ControlRegs::get(unsigned idx) const {
  if (idx < creg_num) {
    return get_c(idx);
  } else if (idx >= dreg_idx && idx < dreg_idx + dreg_num) {
    return get_d(idx);
  } else if (idx == 7) {
    return c7;
  } else {
    return {};
  }
}

bool ControlRegs::set(unsigned idx, StackEntry value) {
  if (idx < creg_num) {
    auto v = std::move(value).as_cont();
    return v.not_null() && set_c(idx, std::move(v));
  } else if (idx >= dreg_idx && idx < dreg_idx + dreg_num) {
    auto v = std::move(value).as_cell();
    return v.not_null() && set_d(idx, std::move(v));
  } else if (idx == 7) {
    auto v = std::move(value).as_tuple();
    return v.not_null() && set_c7(std::move(v));
  } else {
    return false;
  }
}

bool ControlRegs::define(unsigned idx, StackEntry value) {
  if (idx < creg_num) {
    auto v = std::move(value).as_cont();
    return v.not_null() && define_c(idx, std::move(v));
  } else if (idx >= dreg_idx && idx < dreg_idx + dreg_num) {
    auto v = std::move(value).as_cell();
    return v.not_null() && define_d(idx, std::move(v));
  } else if (idx == 7) {
    auto v = std::move(value).as_tuple();
    return v.not_null() && define_c7(std::move(v));
  } else {
    return false;
  }
}

ControlRegs& ControlRegs::operator^=(const ControlRegs& save) {
  for (int i = 0; i < creg_num; i++) {
    c[i] ^= save.c[i];
  }
  for (int i = 0; i < dreg_num; i++) {
    d[i] ^= save.d[i];
  }
  c7 ^= save.c7;
  return *this;
}

ControlRegs& ControlRegs::operator^=(ControlRegs&& save) {
  for (int i = 0; i < creg_num; i++) {
    c[i] ^= std::move(save.c[i]);
  }
  for (int i = 0; i < dreg_num; i++) {
    d[i] ^= std::move(save.d[i]);
  }
  c7 ^= std::move(save.c7);
  return *this;
}

ControlRegs& ControlRegs::operator&=(const ControlRegs& save) {
  for (int i = 0; i < creg_num; i++) {
    c[i] &= save.c[i].is_null();
  }
  for (int i = 0; i < dreg_num; i++) {
    d[i] &= save.d[i].is_null();
  }
  c7 &= save.c7.is_null();
  return *this;
}

bool ControlRegs::serialize(CellBuilder& cb) const {
  // _ cregs:(HashmapE 4 VmStackValue) = VmSaveList;
  Dictionary dict{4};
  CellBuilder cb2;
  for (int i = 0; i < creg_num; i++) {
    if (c[i].not_null() &&
        !(StackEntry{c[i]}.serialize(cb2) && dict.set_builder(td::BitArray<4>(i), cb2) && cb2.reset_bool())) {
      return false;
    }
  }
  for (int i = 0; i < dreg_num; i++) {
    if (d[i].not_null() && !(StackEntry{d[i]}.serialize(cb2) && dict.set_builder(td::BitArray<4>(dreg_idx + i), cb2) &&
                             cb2.reset_bool())) {
      return false;
    }
  }
  return (c7.is_null() || (StackEntry{c7}.serialize(cb2) && dict.set_builder(td::BitArray<4>(7), cb2))) &&
         std::move(dict).append_dict_to_bool(cb);
}

bool ControlRegs::deserialize(CellSlice& cs, int mode) {
  // _ cregs:(HashmapE 4 VmStackValue) = VmSaveList;
  Ref<Cell> root;
  return cs.fetch_maybe_ref(root) && deserialize(std::move(root), mode);
}

bool ControlRegs::deserialize(Ref<Cell> root, int mode) {
  try {
    clear();
    Dictionary dict{std::move(root), 4};
    return dict.check_for_each([this, mode](Ref<CellSlice> val, td::ConstBitPtr key, int n) {
      StackEntry value;
      return value.deserialize(val.write(), mode) && val->empty_ext() && set((int)key.get_uint(4), std::move(value));
    });
  } catch (VmError&) {
    return false;
  }
}

bool ControlData::clear() {
  stack.clear();
  save.clear();
  nargs = cp = -1;
  return true;
}

bool ControlData::serialize(CellBuilder& cb) const {
  // vm_ctl_data$_ nargs:(Maybe uint13) stack:(Maybe VmStack) save:VmSaveList
  // cp:(Maybe int16) = VmControlData;
  return cb.store_bool_bool(nargs >= 0)                   // vm_ctl_data$_ nargs:(Maybe ...
         && (nargs < 0 || cb.store_long_bool(nargs, 13))  // ... int13)
         && cb.store_bool_bool(stack.not_null())          // stack:(Maybe ...
         && (stack.is_null() || stack->serialize(cb))     // ... VmStack)
         && save.serialize(cb)                            // save:VmSaveList
         && cb.store_bool_bool(cp != -1)                  // cp:(Maybe ...
         && (cp == -1 || cb.store_long_bool(cp, 16));     // ... int16)
}

bool ControlData::deserialize(CellSlice& cs, int mode) {
  // vm_ctl_data$_ nargs:(Maybe uint13) stack:(Maybe VmStack) save:VmSaveList
  // cp:(Maybe int16) = VmControlData;
  nargs = cp = -1;
  stack.clear();
  bool f;
  return cs.fetch_bool_to(f) && (!f || cs.fetch_uint_to(13, nargs))                // nargs:(Maybe uint13)
         && cs.fetch_bool_to(f) && (!f || Stack::deserialize_to(cs, stack, mode))  // stack:(Maybe VmStack)
         && save.deserialize(cs, mode)                                             // save:VmSaveList
         && cs.fetch_bool_to(f) && (!f || (cs.fetch_int_to(16, cp) && cp != -1));  // cp:(Maybe int16)
}

bool Continuation::serialize_ref(CellBuilder& cb) const {
  auto* vsi = VmStateInterface::get();
  if (vsi && !vsi->register_op()) {
    return false;
  }
  vm::CellBuilder cb2;
  return serialize(cb2) && cb.store_ref_bool(cb2.finalize());
}

Ref<Continuation> Continuation::deserialize(CellSlice& cs, int mode) {
  if (mode & 0x1002) {
    return {};
  }
  auto* vsi = VmStateInterface::get();
  if (vsi && !vsi->register_op()) {
    return {};
  }

  mode |= 0x1000;
  switch (cs.bselect_ext(6, 0x100f011100010001ULL)) {
    case 0:
      // vmc_std$00 cdata:VmControlData code:VmCellSlice = VmCont;
      return OrdCont::deserialize(cs, mode);
    case 1:
      // vmc_envelope$01 cdata:VmControlData next:^VmCont = VmCont;
      return ArgContExt::deserialize(cs, mode);
    case 2:
      // vmc_quit$1000 exit_code:int32 = VmCont;
      return QuitCont::deserialize(cs, mode);
    case 3:
      // vmc_quit_exc$1001 = VmCont;
      return ExcQuitCont::deserialize(cs, mode);
    case 4:
      // vmc_repeat$10100 count:uint63 body:^VmCont after:^VmCont = VmCont;
      return RepeatCont::deserialize(cs, mode);
    case 5:
      // vmc_until$110000 body:^VmCont after:^VmCont = VmCont;
      return UntilCont::deserialize(cs, mode);
    case 6:
      // vmc_again$110001 body:^VmCont = VmCont;
      return AgainCont::deserialize(cs, mode);
    case 7:
      // vmc_while_cond$110010 cond:^VmCont body:^VmCont after:^VmCont = VmCont;
      return WhileCont::deserialize(cs, mode | 0x2000);
    case 8:
      // vmc_while_body$110011 cond:^VmCont body:^VmCont after:^VmCont = VmCont;
      return WhileCont::deserialize(cs, mode & ~0x2000);
    case 9:
      // vmc_pushint$1111 value:int32 next:^VmCont = VmCont;
      return PushIntCont::deserialize(cs, mode);
    default:
      return {};
  }
}

bool Continuation::deserialize_to(Ref<Cell> cell, Ref<Continuation>& cont, int mode) {
  if (cell.is_null()) {
    cont.clear();
    return false;
  }
  CellSlice cs = load_cell_slice(std::move(cell));
  return deserialize_to(cs, cont, mode & ~0x1000) && cs.empty_ext();
}

bool QuitCont::serialize(CellBuilder& cb) const {
  // vmc_quit$1000 exit_code:int32 = VmCont;
  return cb.store_long_bool(8, 4) && cb.store_long_bool(exit_code, 32);
}

Ref<QuitCont> QuitCont::deserialize(CellSlice& cs, int mode) {
  // vmc_quit$1000 exit_code:int32 = VmCont;
  int exit_code;
  if (cs.fetch_ulong(4) == 8 && cs.fetch_int_to(32, exit_code)) {
    return Ref<QuitCont>{true, exit_code};
  } else {
    return {};
  }
}

int ExcQuitCont::jump(VmState* st) const & {
  int n = 0;
  try {
    n = st->get_stack().pop_smallint_range(0xffff);
  } catch (const VmError& vme) {
    n = vme.get_errno();
  }
  VM_LOG(st) << "default exception handler, terminating vm with exit code " << n;
  return ~n;
}

bool ExcQuitCont::serialize(CellBuilder& cb) const {
  // vmc_quit_exc$1001 = VmCont;
  return cb.store_long_bool(9, 4);
}

Ref<ExcQuitCont> ExcQuitCont::deserialize(CellSlice& cs, int mode) {
  // vmc_quit_exc$1001 = VmCont;
  return cs.fetch_ulong(4) == 9 ? Ref<ExcQuitCont>{true} : Ref<ExcQuitCont>{};
}

int PushIntCont::jump(VmState* st) const & {
  VM_LOG(st) << "execute implicit PUSH " << push_val << " (slow)";
  st->get_stack().push_smallint(push_val);
  return st->jump(next);
}

int PushIntCont::jump_w(VmState* st) & {
  VM_LOG(st) << "execute implicit PUSH " << push_val;
  st->get_stack().push_smallint(push_val);
  return st->jump(std::move(next));
}

bool PushIntCont::serialize(CellBuilder& cb) const {
  // vmc_pushint$1111 value:int32 next:^VmCont = VmCont;
  return cb.store_long_bool(15, 4) && cb.store_long_bool(push_val, 32) && next->serialize_ref(cb);
}

Ref<PushIntCont> PushIntCont::deserialize(CellSlice& cs, int mode) {
  // vmc_pushint$1111 value:int32 next:^VmCont = VmCont;
  int value;
  Ref<Cell> ref;
  Ref<Continuation> next;
  if (cs.fetch_ulong(4) == 15 && cs.fetch_int_to(32, value) && cs.fetch_ref_to(ref) &&
      deserialize_to(std::move(ref), next, mode)) {
    return Ref<PushIntCont>{true, value, std::move(next)};
  } else {
    return {};
  }
}

int ArgContExt::jump(VmState* st) const & {
  st->adjust_cr(data.save);
  if (data.cp != -1) {
    st->force_cp(data.cp);
  }
  return ext->jump(st);
}

int ArgContExt::jump_w(VmState* st) & {
  st->adjust_cr(std::move(data.save));
  if (data.cp != -1) {
    st->force_cp(data.cp);
  }
  return st->jump_to(std::move(ext));
}

bool ArgContExt::serialize(CellBuilder& cb) const {
  // vmc_envelope$01 cdata:VmControlData next:^VmCont = VmCont;
  return cb.store_long_bool(1, 2) && data.serialize(cb) && ext->serialize_ref(cb);
}

Ref<ArgContExt> ArgContExt::deserialize(CellSlice& cs, int mode) {
  // vmc_envelope$01 cdata:VmControlData next:^VmCont = VmCont;
  ControlData cdata;
  Ref<Cell> ref;
  Ref<Continuation> next;
  mode &= ~0x1000;
  return cs.fetch_ulong(2) == 1 && cdata.deserialize(cs, mode) && cs.fetch_ref_to(ref) &&
                 deserialize_to(std::move(ref), next, mode)
             ? Ref<ArgContExt>{true, std::move(next), std::move(cdata)}
             : Ref<ArgContExt>{};
}

int RepeatCont::jump(VmState* st) const & {
  VM_LOG(st) << "repeat " << count << " more times (slow)\n";
  if (count <= 0) {
    return st->jump(after);
  }
  if (body->has_c0()) {
    return st->jump(body);
  }
  st->set_c0(Ref<RepeatCont>{true, body, after, count - 1});
  return st->jump(body);
}

int RepeatCont::jump_w(VmState* st) & {
  VM_LOG(st) << "repeat " << count << " more times\n";
  if (count <= 0) {
    body.clear();
    return st->jump(std::move(after));
  }
  if (body->has_c0()) {
    after.clear();
    return st->jump(std::move(body));
  }
  // optimization: since this is unique, reuse *this instead of creating new object
  --count;
  st->set_c0(Ref<RepeatCont>{this});
  return st->jump(body);
}

bool RepeatCont::serialize(CellBuilder& cb) const {
  // vmc_repeat$10100 count:uint63 body:^VmCont after:^VmCont = VmCont;
  return cb.store_long_bool(0x14, 5) && cb.store_long_bool(count, 63) && body->serialize_ref(cb) &&
         after->serialize_ref(cb);
}

Ref<RepeatCont> RepeatCont::deserialize(CellSlice& cs, int mode) {
  // vmc_repeat$10100 count:uint63 body:^VmCont after:^VmCont = VmCont;
  long long count;
  Ref<Cell> ref;
  Ref<Continuation> body, after;
  if (cs.fetch_ulong(5) == 0x14 && cs.fetch_uint_to(63, count) && cs.fetch_ref_to(ref) &&
      deserialize_to(std::move(ref), body, mode) && cs.fetch_ref_to(ref) &&
      deserialize_to(std::move(ref), after, mode)) {
    return Ref<RepeatCont>{true, std::move(body), std::move(after), count};
  } else {
    return {};
  }
}

int VmState::repeat(Ref<Continuation> body, Ref<Continuation> after, long long count) {
  if (count <= 0) {
    body.clear();
    return jump(std::move(after));
  } else {
    return jump(Ref<RepeatCont>{true, std::move(body), std::move(after), count});
  }
}

int AgainCont::jump(VmState* st) const & {
  VM_LOG(st) << "again an infinite loop iteration (slow)\n";
  if (!body->has_c0()) {
    st->set_c0(Ref<AgainCont>{this});
  }
  return st->jump(body);
}

int AgainCont::jump_w(VmState* st) & {
  VM_LOG(st) << "again an infinite loop iteration\n";
  if (!body->has_c0()) {
    st->set_c0(Ref<AgainCont>{this});
    return st->jump(body);
  } else {
    return st->jump(std::move(body));
  }
}

bool AgainCont::serialize(CellBuilder& cb) const {
  // vmc_again$110001 body:^VmCont = VmCont;
  return cb.store_long_bool(0x31, 6) && body->serialize_ref(cb);
}

Ref<AgainCont> AgainCont::deserialize(CellSlice& cs, int mode) {
  // vmc_again$110001 body:^VmCont = VmCont;
  Ref<Cell> ref;
  Ref<Continuation> body;
  if (cs.fetch_ulong(6) == 0x31 && cs.fetch_ref_to(ref) && deserialize_to(std::move(ref), body, mode)) {
    return Ref<AgainCont>{true, std::move(body)};
  } else {
    return {};
  }
}

int VmState::again(Ref<Continuation> body) {
  return jump(Ref<AgainCont>{true, std::move(body)});
}

int UntilCont::jump(VmState* st) const & {
  VM_LOG(st) << "until loop body end (slow)\n";
  if (st->get_stack().pop_bool()) {
    VM_LOG(st) << "until loop terminated\n";
    return st->jump(after);
  }
  if (!body->has_c0()) {
    st->set_c0(Ref<UntilCont>{this});
  }
  return st->jump(body);
}

int UntilCont::jump_w(VmState* st) & {
  VM_LOG(st) << "until loop body end\n";
  if (st->get_stack().pop_bool()) {
    VM_LOG(st) << "until loop terminated\n";
    body.clear();
    return st->jump(std::move(after));
  }
  if (!body->has_c0()) {
    st->set_c0(Ref<UntilCont>{this});
    return st->jump(body);
  } else {
    after.clear();
    return st->jump(std::move(body));
  }
}

bool UntilCont::serialize(CellBuilder& cb) const {
  // vmc_until$110000 body:^VmCont after:^VmCont = VmCont;
  return cb.store_long_bool(0x30, 6) && body->serialize_ref(cb) && after->serialize_ref(cb);
}

Ref<UntilCont> UntilCont::deserialize(CellSlice& cs, int mode) {
  // vmc_until$110000 body:^VmCont after:^VmCont = VmCont;
  Ref<Cell> ref;
  Ref<Continuation> body, after;
  if (cs.fetch_ulong(6) == 0x30 && cs.fetch_ref_to(ref) && deserialize_to(std::move(ref), body, mode) &&
      cs.fetch_ref_to(ref) && deserialize_to(std::move(ref), after, mode)) {
    return Ref<UntilCont>{true, std::move(body), std::move(after)};
  } else {
    return {};
  }
}

int VmState::until(Ref<Continuation> body, Ref<Continuation> after) {
  if (!body->has_c0()) {
    set_c0(Ref<UntilCont>{true, body, std::move(after)});
  }
  return jump(std::move(body));
}

int WhileCont::jump(VmState* st) const & {
  if (chkcond) {
    VM_LOG(st) << "while loop condition end (slow)\n";
    if (!st->get_stack().pop_bool()) {
      VM_LOG(st) << "while loop terminated\n";
      return st->jump(after);
    }
    if (!body->has_c0()) {
      st->set_c0(Ref<WhileCont>{true, cond, body, after, false});
    }
    return st->jump(body);
  } else {
    VM_LOG(st) << "while loop body end (slow)\n";
    if (!cond->has_c0()) {
      st->set_c0(Ref<WhileCont>{true, cond, body, after, true});
    }
    return st->jump(cond);
  }
}

int WhileCont::jump_w(VmState* st) & {
  if (chkcond) {
    VM_LOG(st) << "while loop condition end\n";
    if (!st->get_stack().pop_bool()) {
      VM_LOG(st) << "while loop terminated\n";
      cond.clear();
      body.clear();
      return st->jump(std::move(after));
    }
    if (!body->has_c0()) {
      chkcond = false;  // re-use current object since we hold the unique pointer to it
      st->set_c0(Ref<WhileCont>{this});
      return st->jump(body);
    } else {
      cond.clear();
      after.clear();
      return st->jump(std::move(body));
    }
  } else {
    VM_LOG(st) << "while loop body end\n";
    if (!cond->has_c0()) {
      chkcond = true;  // re-use current object
      st->set_c0(Ref<WhileCont>{this});
      return st->jump(cond);
    } else {
      body.clear();
      after.clear();
      return st->jump(std::move(cond));
    }
  }
}

bool WhileCont::serialize(CellBuilder& cb) const {
  // vmc_while_cond$110010 cond:^VmCont body:^VmCont after:^VmCont = VmCont;
  // vmc_while_body$110011 cond:^VmCont body:^VmCont after:^VmCont = VmCont;
  return cb.store_long_bool(0x19, 5) && cb.store_bool_bool(!chkcond) && cond->serialize_ref(cb) &&
         body->serialize_ref(cb) && after->serialize_ref(cb);
}

Ref<WhileCont> WhileCont::deserialize(CellSlice& cs, int mode) {
  // vmc_while_cond$110010 cond:^VmCont body:^VmCont after:^VmCont = VmCont;
  // vmc_while_body$110011 cond:^VmCont body:^VmCont after:^VmCont = VmCont;
  bool at_body;
  Ref<Cell> ref;
  Ref<Continuation> cond, body, after;
  if (cs.fetch_ulong(5) == 0x19 && cs.fetch_bool_to(at_body) && cs.fetch_ref_to(ref) &&
      deserialize_to(std::move(ref), cond, mode) && cs.fetch_ref_to(ref) &&
      deserialize_to(std::move(ref), body, mode) && cs.fetch_ref_to(ref) &&
      deserialize_to(std::move(ref), after, mode)) {
    return Ref<WhileCont>{true, std::move(cond), std::move(body), std::move(after), !at_body};
  } else {
    return {};
  }
}

int VmState::loop_while(Ref<Continuation> cond, Ref<Continuation> body, Ref<Continuation> after) {
  if (!cond->has_c0()) {
    set_c0(Ref<WhileCont>{true, cond, std::move(body), std::move(after), true});
  }
  return jump(std::move(cond));
}

int OrdCont::jump(VmState* st) const & {
  st->adjust_cr(data.save);
  st->set_code(code, data.cp);
  return 0;
}

int OrdCont::jump_w(VmState* st) & {
  st->adjust_cr(std::move(data.save));
  st->set_code(std::move(code), data.cp);
  return 0;
}

bool OrdCont::serialize(CellBuilder& cb) const {
  // vmc_std$00 cdata:VmControlData code:VmCellSlice = VmCont;
  return cb.store_long_bool(0, 2) && data.serialize(cb) && StackEntry{code}.serialize(cb, 0x1000);
}

Ref<OrdCont> OrdCont::deserialize(CellSlice& cs, int mode) {
  // vmc_std$00 cdata:VmControlData code:VmCellSlice = VmCont;
  ControlData cdata;
  StackEntry val;
  mode &= ~0x1000;
  return cs.fetch_ulong(2) == 0 && cdata.deserialize(cs, mode) && val.deserialize(cs, 0x4000) &&
                 val.is(StackEntry::t_slice)
             ? Ref<OrdCont>{true, std::move(val).as_slice(), std::move(cdata)}
             : Ref<OrdCont>{};
}

}  // namespace vm
