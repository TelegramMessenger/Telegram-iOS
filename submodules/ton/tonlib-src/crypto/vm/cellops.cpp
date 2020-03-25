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
#include <functional>
#include "vm/cellops.h"
#include "vm/log.h"
#include "vm/opctable.h"
#include "vm/stack.hpp"
#include "vm/excno.hpp"
#include "vm/vmstate.h"
#include "vm/vm.h"
#include "common/bigint.hpp"
#include "common/refint.h"

namespace vm {

int exec_push_ref(VmState* st, CellSlice& cs, int mode, int pfx_bits) {
  if (!cs.have_refs(1)) {
    throw VmError{Excno::inv_opcode, "no references left for a PUSHREF instruction"};
  }
  cs.advance(pfx_bits);
  auto cell = cs.fetch_ref();
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PUSHREF" << (mode == 2 ? "CONT" : (mode == 1 ? "SLICE" : "")) << " ("
             << cell->get_hash().to_hex() << ")";
  switch (mode) {
    default:
    case 0:
      stack.push_cell(std::move(cell));
      break;
    case 1:
      stack.push_cellslice(load_cell_slice_ref(std::move(cell)));
      break;
    case 2:
      stack.push_cont(Ref<OrdCont>{true, load_cell_slice_ref(std::move(cell)), st->get_cp()});
      break;
  }
  return 0;
}

std::string dump_push_ref(CellSlice& cs, unsigned args, int pfx_bits, std::string name) {
  if (!cs.have_refs(1)) {
    return "";
  }
  cs.advance(pfx_bits);
  auto cell = cs.fetch_ref();
  return name + " (" + cell->get_hash().to_hex() + ")";
}

int compute_len_push_ref(const CellSlice& cs, unsigned args, int pfx_bits) {
  return cs.have_refs(1) ? (0x10000 + pfx_bits) : 0;
}

std::string dump_push_ref2(CellSlice& cs, unsigned args, int pfx_bits, std::string name) {
  if (!cs.have_refs(2)) {
    return "";
  }
  cs.advance(pfx_bits);
  auto cell1 = cs.fetch_ref(), cell2 = cs.fetch_ref();
  return name + " (" + cell1->get_hash().to_hex() + ") (" + cell2->get_hash().to_hex() + ")";
}

int compute_len_push_ref2(const CellSlice& cs, unsigned args, int pfx_bits) {
  return cs.have_refs(2) ? (0x20000 + pfx_bits) : 0;
}

int exec_push_slice_common(VmState* st, CellSlice& cs, unsigned data_bits, unsigned refs, int pfx_bits) {
  if (!cs.have(pfx_bits + data_bits)) {
    throw VmError{Excno::inv_opcode, "not enough data bits for a PUSHSLICE instruction"};
  }
  if (!cs.have_refs(refs)) {
    throw VmError{Excno::inv_opcode, "not enough references for a PUSHSLICE instruction"};
  }
  Stack& stack = st->get_stack();
  cs.advance(pfx_bits);
  auto slice = cs.fetch_subslice(data_bits, refs);
  slice.unique_write().remove_trailing();
  VM_LOG(st) << "execute PUSHSLICE " << slice;
  stack.push(std::move(slice));
  return 0;
}

std::string dump_push_slice_common(CellSlice& cs, unsigned data_bits, unsigned refs, int pfx_bits,
                                   const char* name = "PUSHSLICE ") {
  if (!cs.have(pfx_bits + data_bits) || !cs.have_refs(refs)) {
    return "";
  }
  cs.advance(pfx_bits);
  auto slice = cs.fetch_subslice(data_bits, refs);
  slice.unique_write().remove_trailing();
  std::ostringstream os{name};
  slice->dump_hex(os, 1, false);
  return os.str();
}

int compute_len_push_slice_common(const CellSlice& cs, unsigned data_bits, unsigned refs, int pfx_bits) {
  unsigned bits = pfx_bits + data_bits;
  return cs.have(bits) && cs.have_refs(refs) ? (refs << 16) + bits : 0;
}

int exec_push_slice(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  return exec_push_slice_common(st, cs, (args & 15) * 8 + 4, 0, pfx_bits);
}

std::string dump_push_slice(CellSlice& cs, unsigned args, int pfx_bits) {
  return dump_push_slice_common(cs, (args & 15) * 8 + 4, 0, pfx_bits);
}

int compute_len_push_slice(const CellSlice& cs, unsigned args, int pfx_bits) {
  return compute_len_push_slice_common(cs, (args & 15) * 8 + 4, 0, pfx_bits);
}

int exec_push_slice_r(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = ((args >> 5) & 3) + 1;
  unsigned data_bits = (args & 31) * 8 + 1;
  return exec_push_slice_common(st, cs, data_bits, refs, pfx_bits);
}

std::string dump_push_slice_r(CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = ((args >> 5) & 3) + 1;
  unsigned data_bits = (args & 31) * 8 + 1;
  return dump_push_slice_common(cs, data_bits, refs, pfx_bits);
}

int compute_len_push_slice_r(const CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = ((args >> 5) & 3) + 1;
  unsigned data_bits = (args & 31) * 8 + 1;
  return compute_len_push_slice_common(cs, data_bits, refs, pfx_bits);
}

int exec_push_slice_r2(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args >> 7) & 7;
  unsigned data_bits = (args & 127) * 8 + 6;
  return exec_push_slice_common(st, cs, data_bits, refs, pfx_bits);
}

std::string dump_push_slice_r2(CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args >> 7) & 7;
  unsigned data_bits = (args & 127) * 8 + 6;
  return dump_push_slice_common(cs, data_bits, refs, pfx_bits);
}

int compute_len_push_slice_r2(const CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args >> 7) & 7;
  unsigned data_bits = (args & 127) * 8 + 6;
  return compute_len_push_slice_common(cs, data_bits, refs, pfx_bits);
}

int exec_push_cont(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args >> 7) & 3;
  unsigned data_bits = (args & 127) * 8;
  if (!cs.have(pfx_bits + data_bits)) {
    throw VmError{Excno::inv_opcode, "not enough data bits for a PUSHCONT instruction"};
  }
  if (!cs.have_refs(refs)) {
    throw VmError{Excno::inv_opcode, "not enough references for a PUSHCONT instruction"};
  }
  Stack& stack = st->get_stack();
  cs.advance(pfx_bits);
  auto slice = cs.fetch_subslice(data_bits, refs);

  VM_LOG(st) << "execute PUSHCONT " << slice;

  stack.push_cont(Ref<OrdCont>{true, std::move(slice), st->get_cp()});
  return 0;
}

std::string dump_push_cont(CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args >> 7) & 3;
  unsigned data_bits = (args & 127) * 8;
  if (!cs.have(pfx_bits + data_bits) || !cs.have_refs(refs)) {
    return "";
  }
  cs.advance(pfx_bits);
  auto slice = cs.fetch_subslice(data_bits, refs);
  std::ostringstream os{"PUSHCONT "};
  slice->dump_hex(os, 1, false);
  return os.str();
}

int compute_len_push_cont(const CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args >> 7) & 3;
  unsigned data_bits = (args & 127) * 8;
  return compute_len_push_slice_common(cs, data_bits, refs, pfx_bits);
}

int exec_push_cont_simple(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned data_bits = (args & 15) * 8;
  if (!cs.have(pfx_bits + data_bits)) {
    throw VmError{Excno::inv_opcode, "not enough data bits for a PUSHCONT instruction"};
  }
  Stack& stack = st->get_stack();
  cs.advance(pfx_bits);
  auto slice = cs.fetch_subslice(data_bits);
  VM_LOG(st) << "execute PUSHCONT " << slice;
  stack.push_cont(Ref<OrdCont>{true, std::move(slice), st->get_cp()});
  return 0;
}

std::string dump_push_cont_simple(CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned data_bits = (args & 15) * 8;
  if (!cs.have(pfx_bits + data_bits)) {
    return "";
  }
  cs.advance(pfx_bits);
  auto slice = cs.fetch_subslice(data_bits);
  std::ostringstream os{"PUSHCONT "};
  slice->dump_hex(os, 1, false);
  return os.str();
}

int compute_len_push_cont_simple(const CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned data_bits = (args & 15) * 8;
  return compute_len_push_slice_common(cs, data_bits, 0, pfx_bits);
}

void register_cell_const_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  cp0.insert(OpcodeInstr::mkext(0x88, 8, 0, std::bind(dump_push_ref, _1, _2, _3, "PUSHREF"),
                                std::bind(exec_push_ref, _1, _2, 0, _4), compute_len_push_ref))
      .insert(OpcodeInstr::mkext(0x89, 8, 0, std::bind(dump_push_ref, _1, _2, _3, "PUSHREFSLICE"),
                                 std::bind(exec_push_ref, _1, _2, 1, _4), compute_len_push_ref))
      .insert(OpcodeInstr::mkext(0x8a, 8, 0, std::bind(dump_push_ref, _1, _2, _3, "PUSHREFCONT"),
                                 std::bind(exec_push_ref, _1, _2, 2, _4), compute_len_push_ref))
      .insert(OpcodeInstr::mkext(0x8b, 8, 4, dump_push_slice, exec_push_slice, compute_len_push_slice))
      .insert(OpcodeInstr::mkext(0x8c, 8, 7, dump_push_slice_r, exec_push_slice_r, compute_len_push_slice_r))
      .insert(OpcodeInstr::mkextrange((0x8d * 8) << 7, (0x8d * 8 + 5) << 7, 18, 10, dump_push_slice_r2,
                                      exec_push_slice_r2, compute_len_push_slice_r2))
      .insert(OpcodeInstr::mkext(0x8e / 2, 7, 9, dump_push_cont, exec_push_cont, compute_len_push_cont))
      .insert(OpcodeInstr::mkext(9, 4, 4, dump_push_cont_simple, exec_push_cont_simple, compute_len_push_cont_simple));
}

int exec_un_cs_cmp(VmState* st, const char* name, const std::function<bool(Ref<CellSlice>)>& func) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(1);
  stack.push_smallint(func(stack.pop_cellslice()) ? -1 : 0);
  return 0;
}

int exec_iun_cs_cmp(VmState* st, const char* name, const std::function<int(Ref<CellSlice>)>& func) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(1);
  stack.push_smallint(func(stack.pop_cellslice()));
  return 0;
}

int exec_bin_cs_cmp(VmState* st, const char* name, const std::function<bool(Ref<CellSlice>, Ref<CellSlice>)>& func) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(2);
  auto cs2 = stack.pop_cellslice();
  auto cs1 = stack.pop_cellslice();
  stack.push_smallint(func(cs1, cs2) ? -1 : 0);
  return 0;
}

int exec_ibin_cs_cmp(VmState* st, const char* name, const std::function<int(Ref<CellSlice>, Ref<CellSlice>)>& func) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(2);
  auto cs2 = stack.pop_cellslice();
  auto cs1 = stack.pop_cellslice();
  stack.push_smallint(func(cs1, cs2));
  return 0;
}

namespace {

using namespace std::placeholders;

void reg_un_cs_cmp(OpcodeTable& cp, unsigned code, unsigned len, const char* name,
                   std::function<bool(Ref<CellSlice>)> func) {
  cp.insert(OpcodeInstr::mksimple(code, len, name, std::bind(exec_un_cs_cmp, _1, name, std::move(func))));
}

void reg_iun_cs_cmp(OpcodeTable& cp, unsigned code, unsigned len, const char* name,
                    std::function<int(Ref<CellSlice>)> func) {
  cp.insert(OpcodeInstr::mksimple(code, len, name, std::bind(exec_iun_cs_cmp, _1, name, std::move(func))));
}

void reg_bin_cs_cmp(OpcodeTable& cp, unsigned code, unsigned len, const char* name,
                    std::function<bool(Ref<CellSlice>, Ref<CellSlice>)> func) {
  cp.insert(OpcodeInstr::mksimple(code, len, name, std::bind(exec_bin_cs_cmp, _1, name, std::move(func))));
}

void reg_ibin_cs_cmp(OpcodeTable& cp, unsigned code, unsigned len, const char* name,
                     std::function<int(Ref<CellSlice>, Ref<CellSlice>)> func) {
  cp.insert(OpcodeInstr::mksimple(code, len, name, std::bind(exec_ibin_cs_cmp, _1, name, std::move(func))));
}

}  // namespace

void register_cell_cmp_ops(OpcodeTable& cp0) {
  reg_un_cs_cmp(cp0, 0xc700, 16, "SEMPTY", [](auto cs) { return cs->empty() && !cs->size_refs(); });
  reg_un_cs_cmp(cp0, 0xc701, 16, "SDEMPTY", [](auto cs) { return cs->empty(); });
  reg_un_cs_cmp(cp0, 0xc702, 16, "SREMPTY", [](auto cs) { return !cs->size_refs(); });
  reg_un_cs_cmp(cp0, 0xc703, 16, "SDFIRST", [](auto cs) { return cs->prefetch_long(1) == -1; });
  reg_ibin_cs_cmp(cp0, 0xc704, 16, "SDLEXCMP", [](auto cs1, auto cs2) { return cs1->lex_cmp(*cs2); });
  reg_bin_cs_cmp(cp0, 0xc705, 16, "SDEQ", [](auto cs1, auto cs2) { return !cs1->lex_cmp(*cs2); });
  reg_bin_cs_cmp(cp0, 0xc708, 16, "SDPFX", [](auto cs1, auto cs2) { return cs1->is_prefix_of(*cs2); });
  reg_bin_cs_cmp(cp0, 0xc709, 16, "SDPFXREV", [](auto cs1, auto cs2) { return cs2->is_prefix_of(*cs1); });
  reg_bin_cs_cmp(cp0, 0xc70a, 16, "SDPPFX", [](auto cs1, auto cs2) { return cs1->is_proper_prefix_of(*cs2); });
  reg_bin_cs_cmp(cp0, 0xc70b, 16, "SDPPFXREV", [](auto cs1, auto cs2) { return cs2->is_proper_prefix_of(*cs1); });
  reg_bin_cs_cmp(cp0, 0xc70c, 16, "SDSFX", [](auto cs1, auto cs2) { return cs1->is_suffix_of(*cs2); });
  reg_bin_cs_cmp(cp0, 0xc70d, 16, "SDSFXREV", [](auto cs1, auto cs2) { return cs2->is_suffix_of(*cs1); });
  reg_bin_cs_cmp(cp0, 0xc70e, 16, "SDPSFX", [](auto cs1, auto cs2) { return cs1->is_proper_suffix_of(*cs2); });
  reg_bin_cs_cmp(cp0, 0xc70f, 16, "SDPSFXREV", [](auto cs1, auto cs2) { return cs2->is_proper_suffix_of(*cs1); });
  reg_iun_cs_cmp(cp0, 0xc710, 16, "SDCNTLEAD0", [](auto cs) { return cs->count_leading(0); });
  reg_iun_cs_cmp(cp0, 0xc711, 16, "SDCNTLEAD1", [](auto cs) { return cs->count_leading(1); });
  reg_iun_cs_cmp(cp0, 0xc712, 16, "SDCNTTRAIL0", [](auto cs) { return cs->count_trailing(0); });
  reg_iun_cs_cmp(cp0, 0xc713, 16, "SDCNTTRAIL1", [](auto cs) { return cs->count_trailing(1); });
}

int exec_new_builder(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute NEWC";
  stack.push_builder(Ref<CellBuilder>{true});
  return 0;
}

int exec_builder_to_cell(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ENDC";
  stack.check_underflow(1);
  stack.push_cell(stack.pop_builder()->finalize_copy());
  return 0;
}

int exec_builder_to_special_cell(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ENDXC";
  stack.check_underflow(2);
  bool special = stack.pop_bool();
  stack.push_cell(stack.pop_builder()->finalize_copy(special));
  return 0;
}

inline void check_space(const CellBuilder& builder, unsigned bits, unsigned refs = 0) {
  if (!builder.can_extend_by(bits, refs)) {
    throw VmError{Excno::cell_ov};
  }
}

int store_int_common_fail(int code, Stack& stack, Ref<CellBuilder> builder, td::RefInt256 x, unsigned args) {
  if (!(args & 2)) {
    stack.push_int_quiet(std::move(x), true);
    stack.push_builder(std::move(builder));
  } else {
    stack.push_builder(std::move(builder));
    stack.push_int_quiet(std::move(x), true);
  }
  stack.push_smallint(code);
  return 0;
}

int exec_store_int_common(Stack& stack, unsigned bits, unsigned args) {
  bool sgnd = !(args & 1);
  Ref<CellBuilder> builder;
  td::RefInt256 x;
  if (!(args & 2)) {
    builder = stack.pop_builder();
    x = stack.pop_int();
  } else {
    x = stack.pop_int();
    builder = stack.pop_builder();
  }
  if (!builder->can_extend_by(bits)) {
    if (args & 4) {
      return store_int_common_fail(-1, stack, std::move(builder), std::move(x), args);
    }
    throw VmError{Excno::cell_ov};
  }
  if (!x->fits_bits(bits, sgnd)) {
    if (args & 4) {
      return store_int_common_fail(1, stack, std::move(builder), std::move(x), args);
    }
    throw VmError{Excno::range_chk};
  }
  builder.write().store_int256(*x, bits, sgnd);
  stack.push_builder(std::move(builder));
  if (args & 4) {
    stack.push_smallint(0);
  }
  return 0;
}

int exec_store_int(VmState* st, unsigned args, bool sgnd) {
  unsigned bits = (args & 0xff) + 1;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ST" << (sgnd ? 'I' : 'U') << ' ' << bits;
  stack.check_underflow(2);
  return exec_store_int_common(stack, bits, !sgnd);
}

int exec_store_ref(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute STREF" << (quiet ? "Q\n" : "\n");
  stack.check_underflow(2);
  auto builder = stack.pop_builder();
  auto cell = stack.pop_cell();
  if (!builder->can_extend_by(0, 1)) {
    if (!quiet) {
      throw VmError{Excno::cell_ov};
    }
    stack.push_cell(std::move(cell));
    stack.push_builder(std::move(builder));
    stack.push_smallint(-1);
    return 0;
  }
  builder.write().store_ref(std::move(cell));
  stack.push_builder(std::move(builder));
  if (quiet) {
    stack.push_smallint(0);
  }
  return 0;
}

int exec_store_ref_rev(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute STREFR" << (quiet ? "Q\n" : "\n");
  stack.check_underflow(2);
  auto cell = stack.pop_cell();
  auto builder = stack.pop_builder();
  if (!builder->can_extend_by(0, 1)) {
    if (!quiet) {
      throw VmError{Excno::cell_ov};
    }
    stack.push_builder(std::move(builder));
    stack.push_cell(std::move(cell));
    stack.push_smallint(-1);
    return 0;
  }
  builder.write().store_ref(std::move(cell));
  stack.push_builder(std::move(builder));
  if (quiet) {
    stack.push_smallint(0);
  }
  return 0;
}

int exec_store_builder_as_ref(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute STBREF\n";
  stack.check_underflow(2);
  auto builder = stack.pop_builder();
  auto builder2 = stack.pop_builder();
  if (!builder->can_extend_by(0, 1)) {
    if (!quiet) {
      throw VmError{Excno::cell_ov};
    }
    stack.push_builder(std::move(builder2));
    stack.push_builder(std::move(builder));
    stack.push_smallint(-1);
    return 0;
  }
  builder.write().store_ref(builder2->finalize_copy());
  stack.push_builder(std::move(builder));
  if (quiet) {
    stack.push_smallint(0);
  }
  return 0;
}

int exec_store_builder_as_ref_rev(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute STBREFR\n";
  stack.check_underflow(2);
  auto builder2 = stack.pop_builder();
  auto builder = stack.pop_builder();
  if (!builder->can_extend_by(0, 1)) {
    if (!quiet) {
      throw VmError{Excno::cell_ov};
    }
    stack.push_builder(std::move(builder));
    stack.push_builder(std::move(builder2));
    stack.push_smallint(-1);
    return 0;
  }
  builder.write().store_ref(builder2->finalize_copy());
  stack.push_builder(std::move(builder));
  if (quiet) {
    stack.push_smallint(0);
  }
  return 0;
}

int exec_store_slice(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute STSLICE\n";
  stack.check_underflow(2);
  auto builder = stack.pop_builder();
  auto cs = stack.pop_cellslice();
  if (!builder->can_extend_by(cs->size(), cs->size_refs())) {
    if (!quiet) {
      throw VmError{Excno::cell_ov};
    }
    stack.push_cellslice(std::move(cs));
    stack.push_builder(std::move(builder));
    stack.push_smallint(-1);
    return 0;
  }
  cell_builder_add_slice(builder.write(), *cs);
  stack.push_builder(std::move(builder));
  if (quiet) {
    stack.push_smallint(0);
  }
  return 0;
}

int exec_store_slice_rev(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute STSLICER\n";
  stack.check_underflow(2);
  auto cs = stack.pop_cellslice();
  auto builder = stack.pop_builder();
  if (!builder->can_extend_by(cs->size(), cs->size_refs())) {
    if (!quiet) {
      throw VmError{Excno::cell_ov};
    }
    stack.push_builder(std::move(builder));
    stack.push_cellslice(std::move(cs));
    stack.push_smallint(-1);
    return 0;
  }
  cell_builder_add_slice(builder.write(), *cs);
  stack.push_builder(std::move(builder));
  if (quiet) {
    stack.push_smallint(0);
  }
  return 0;
}

int exec_store_builder(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute STB\n";
  stack.check_underflow(2);
  auto builder = stack.pop_builder();
  auto cb2 = stack.pop_builder();
  if (!builder->can_extend_by(cb2->size(), cb2->size_refs())) {
    if (!quiet) {
      throw VmError{Excno::cell_ov};
    }
    stack.push_builder(std::move(cb2));
    stack.push_builder(std::move(builder));
    stack.push_smallint(-1);
    return 0;
  }
  builder.write().append_builder(std::move(cb2));
  stack.push_builder(std::move(builder));
  if (quiet) {
    stack.push_smallint(0);
  }
  return 0;
}

int exec_store_builder_rev(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute STBR\n";
  stack.check_underflow(2);
  auto cb2 = stack.pop_builder();
  auto builder = stack.pop_builder();
  if (!builder->can_extend_by(cb2->size(), cb2->size_refs())) {
    if (!quiet) {
      throw VmError{Excno::cell_ov};
    }
    stack.push_builder(std::move(builder));
    stack.push_builder(std::move(cb2));
    stack.push_smallint(-1);
    return 0;
  }
  builder.write().append_builder(std::move(cb2));
  stack.push_builder(std::move(builder));
  if (quiet) {
    stack.push_smallint(0);
  }
  return 0;
}

int exec_store_int_var(VmState* st, unsigned args) {
  bool sgnd = !(args & 1);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ST" << (sgnd ? 'I' : 'U') << 'X' << ((args & 2) ? "R" : "") << ((args & 4) ? "Q\n" : "\n");
  stack.check_underflow(3);
  unsigned bits = stack.pop_smallint_range(256 + sgnd);
  return exec_store_int_common(stack, bits, args);
}

std::string dump_store_int_var(CellSlice& cs, unsigned args) {
  bool sgnd = !(args & 1);
  std::string s = "ST";
  s += sgnd ? 'I' : 'U';
  s += 'X';
  if (args & 2) {
    s += 'R';
  }
  if (args & 4) {
    s += 'Q';
  }
  return s;
}

int exec_store_int_fixed(VmState* st, unsigned args) {
  unsigned bits = (args & 0xff) + 1;
  args >>= 8;
  bool sgnd = !(args & 1);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ST" << (sgnd ? 'I' : 'U') << ((args & 2) ? "R" : "") << ((args & 4) ? "Q " : " ") << bits;
  stack.check_underflow(2);
  return exec_store_int_common(stack, bits, args);
}

std::string dump_store_int_fixed(CellSlice& cs, unsigned args) {
  unsigned bits = (args & 0xff) + 1;
  bool sgnd = !(args & 0x100);
  std::ostringstream s{"ST"};
  s << (sgnd ? 'I' : 'U');
  if (args & 0x200) {
    s << 'R';
  }
  if (args & 0x400) {
    s << 'Q';
  }
  s << ' ' << bits;
  return s.str();
}

int exec_store_const_ref(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args & 1) + 1;
  if (!cs.have_refs(refs)) {
    throw VmError{Excno::inv_opcode, "no references left for a STREFCONST instruction"};
  }
  cs.advance(pfx_bits);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute STREF" << refs << "CONST\n";
  stack.check_underflow(1);
  auto builder = stack.pop_builder();
  check_space(*builder, 0, refs);
  do {
    builder.write().store_ref(cs.fetch_ref());
  } while (--refs > 0);
  stack.push_builder(std::move(builder));
  return 0;
}

std::string dump_store_const_ref(CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args & 1) + 1;
  if (!cs.have_refs(refs)) {
    return "";
  }
  cs.advance(pfx_bits);
  cs.advance_refs(refs);
  return refs > 1 ? (std::string{"STREF"} + (char)('0' + refs) + "CONST") : "STREFCONST";
}

int compute_len_store_const_ref(const CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args & 1) + 1;
  return cs.have_refs(refs) ? ((refs << 16) + pfx_bits) : 0;
}

int exec_store_le_int(VmState* st, unsigned args) {
  unsigned bits = (args & 2) ? 64 : 32;
  bool sgnd = !(args & 1);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ST" << (sgnd ? 'I' : 'U') << "LE" << bits / 8;
  stack.check_underflow(2);
  auto builder = stack.pop_builder();
  auto x = stack.pop_int();
  check_space(*builder, bits);
  if (!(sgnd ? x->signed_fits_bits(bits) : x->unsigned_fits_bits(bits))) {
    throw VmError{Excno::range_chk};
  }
  unsigned char buff[8];
  st->ensure_throw(x->export_bytes_lsb(buff, bits >> 3, sgnd));
  builder.write().store_bytes(buff, bits >> 3);
  stack.push_builder(std::move(builder));
  return 0;
}

std::string dump_store_le_int(CellSlice& cs, unsigned args) {
  bool sgnd = !(args & 1);
  return std::string{"ST"} + (sgnd ? 'I' : 'U') + "LE" + ((args & 2) ? '8' : '4');
}

int exec_int_builder_func(VmState* st, std::string name, const std::function<int(Ref<CellBuilder>)>& func) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(1);
  stack.push_smallint(func(stack.pop_builder()));
  return 0;
}

int exec_2int_builder_func(VmState* st, std::string name,
                           const std::function<std::pair<int, int>(Ref<CellBuilder>)>& func) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(1);
  std::pair<int, int> res = func(stack.pop_builder());
  stack.push_smallint(res.first);
  stack.push_smallint(res.second);
  return 0;
}

int exec_builder_chk_bits(VmState* st, unsigned args, bool quiet) {
  unsigned bits = (args & 0xff) + 1;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute BCHKBITS" << (quiet ? "Q " : " ") << bits;
  stack.check_underflow(1);
  auto builder = stack.pop_builder();
  if (quiet) {
    stack.push_smallint(builder->can_extend_by(bits) ? -1 : 0);
  } else {
    check_space(*builder, bits);
  }
  return 0;
}

int exec_builder_chk_bits_refs(VmState* st, unsigned mode) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute BCHK" << ((mode & 1) ? "BIT" : "") << ((mode & 2) ? "REFS" : "S") << ((mode & 4) ? "Q" : "");
  stack.check_underflow(1 + (mode & 1) + ((mode & 2) >> 1));
  unsigned refs = (mode & 2) ? stack.pop_smallint_range(7) : 0;
  unsigned bits = (mode & 1) ? stack.pop_smallint_range(1023) : 0;
  auto builder = stack.pop_builder();
  if (mode & 4) {
    stack.push_smallint(builder->can_extend_by(bits, refs) ? -1 : 0);
  } else {
    check_space(*builder, bits, refs);
  }
  return 0;
}

int exec_store_same(VmState* st, const char* name, int val) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(2 + (val < 0));
  if (val < 0) {
    val = stack.pop_smallint_range(1);
  }
  unsigned bits = stack.pop_smallint_range(1023);
  auto builder = stack.pop_builder();
  check_space(*builder, bits);
  builder.write().reserve_slice(bits) = (bool)val;
  stack.push_builder(std::move(builder));
  return 0;
}

int exec_store_const_slice(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args >> 3) & 3;
  unsigned data_bits = (args & 7) * 8 + 2;
  if (!cs.have(pfx_bits + data_bits)) {
    throw VmError{Excno::inv_opcode, "not enough data bits for a STSLICECONST instruction"};
  }
  if (!cs.have_refs(refs)) {
    throw VmError{Excno::inv_opcode, "not enough references for a STSLICECONST instruction"};
  }
  Stack& stack = st->get_stack();
  cs.advance(pfx_bits);
  auto slice = cs.fetch_subslice(data_bits, refs);
  slice.unique_write().remove_trailing();
  VM_LOG(st) << "execute STSLICECONST " << slice;
  auto builder = stack.pop_builder();
  check_space(*builder, slice->size(), slice->size_refs());
  cell_builder_add_slice(builder.write(), *slice);
  stack.push_builder(std::move(builder));
  return 0;
}

std::string dump_store_const_slice(CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args >> 3) & 3;
  unsigned data_bits = (args & 7) * 8 + 2;
  return dump_push_slice_common(cs, data_bits, refs, pfx_bits, "STSLICECONST ");
}

int compute_len_store_const_slice(const CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned refs = (args >> 3) & 3;
  unsigned data_bits = (args & 7) * 8 + 2;
  return compute_len_push_slice_common(cs, data_bits, refs, pfx_bits);
}

void register_cell_serialize_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  cp0.insert(OpcodeInstr::mksimple(0xc8, 8, "NEWC", exec_new_builder))
      .insert(OpcodeInstr::mksimple(0xc9, 8, "ENDC", exec_builder_to_cell))
      .insert(
          OpcodeInstr::mkfixed(0xca, 8, 8, instr::dump_1c_l_add(1, "STI "), std::bind(exec_store_int, _1, _2, true)))
      .insert(
          OpcodeInstr::mkfixed(0xcb, 8, 8, instr::dump_1c_l_add(1, "STU "), std::bind(exec_store_int, _1, _2, false)))
      .insert(OpcodeInstr::mksimple(0xcc, 8, "STREF", std::bind(exec_store_ref, _1, false)))
      .insert(OpcodeInstr::mksimple(0xcd, 8, "ENDCST", std::bind(exec_store_builder_as_ref_rev, _1, false)))
      .insert(OpcodeInstr::mksimple(0xce, 8, "STSLICE", std::bind(exec_store_slice, _1, false)))
      .insert(OpcodeInstr::mkfixed(0xcf00 >> 3, 13, 3, dump_store_int_var, exec_store_int_var))
      .insert(OpcodeInstr::mkfixed(0xcf08 >> 3, 13, 11, dump_store_int_fixed, exec_store_int_fixed))
      .insert(OpcodeInstr::mksimple(0xcf10, 16, "STREF", std::bind(exec_store_ref, _1, false)))
      .insert(OpcodeInstr::mksimple(0xcf11, 16, "STBREF", std::bind(exec_store_builder_as_ref, _1, false)))
      .insert(OpcodeInstr::mksimple(0xcf12, 16, "STSLICE", std::bind(exec_store_slice, _1, false)))
      .insert(OpcodeInstr::mksimple(0xcf13, 16, "STB", std::bind(exec_store_builder, _1, false)))
      .insert(OpcodeInstr::mksimple(0xcf14, 16, "STREFR", std::bind(exec_store_ref_rev, _1, false)))
      .insert(OpcodeInstr::mksimple(0xcf15, 16, "STBREFR", std::bind(exec_store_builder_as_ref_rev, _1, false)))
      .insert(OpcodeInstr::mksimple(0xcf16, 16, "STSLICER", std::bind(exec_store_slice_rev, _1, false)))
      .insert(OpcodeInstr::mksimple(0xcf17, 16, "STBR", std::bind(exec_store_builder_rev, _1, false)))
      .insert(OpcodeInstr::mksimple(0xcf18, 16, "STREFQ", std::bind(exec_store_ref, _1, true)))
      .insert(OpcodeInstr::mksimple(0xcf19, 16, "STBREFQ", std::bind(exec_store_builder_as_ref, _1, true)))
      .insert(OpcodeInstr::mksimple(0xcf1a, 16, "STSLICEQ", std::bind(exec_store_slice, _1, true)))
      .insert(OpcodeInstr::mksimple(0xcf1b, 16, "STBQ", std::bind(exec_store_builder, _1, true)))
      .insert(OpcodeInstr::mksimple(0xcf1c, 16, "STREFRQ", std::bind(exec_store_ref_rev, _1, true)))
      .insert(OpcodeInstr::mksimple(0xcf1d, 16, "STBREFRQ", std::bind(exec_store_builder_as_ref_rev, _1, true)))
      .insert(OpcodeInstr::mksimple(0xcf1e, 16, "STSLICERQ", std::bind(exec_store_slice_rev, _1, true)))
      .insert(OpcodeInstr::mksimple(0xcf1f, 16, "STBRQ", std::bind(exec_store_builder_rev, _1, true)))
      .insert(OpcodeInstr::mkextrange(0xcf20, 0xcf22, 16, 1, dump_store_const_ref, exec_store_const_ref,
                                      compute_len_store_const_ref))
      .insert(OpcodeInstr::mksimple(0xcf23, 16, "ENDXC", exec_builder_to_special_cell))
      .insert(OpcodeInstr::mkfixed(0xcf28 >> 2, 14, 2, dump_store_le_int, exec_store_le_int))
      .insert(OpcodeInstr::mksimple(
          0xcf30, 16, "BDEPTH",
          std::bind(exec_int_builder_func, _1, "BDEPTH", [](Ref<CellBuilder> b) { return b->get_depth(); })))
      .insert(OpcodeInstr::mksimple(
          0xcf31, 16, "BBITS",
          std::bind(exec_int_builder_func, _1, "BBITS", [](Ref<CellBuilder> b) { return b->size(); })))
      .insert(OpcodeInstr::mksimple(
          0xcf32, 16, "BREFS",
          std::bind(exec_int_builder_func, _1, "BREFS", [](Ref<CellBuilder> b) { return b->size_refs(); })))
      .insert(OpcodeInstr::mksimple(
          0xcf33, 16, "BBITREFS",
          std::bind(exec_2int_builder_func, _1, "BBITSREFS",
                    [](Ref<CellBuilder> b) { return std::make_pair(b->size(), b->size_refs()); })))
      .insert(OpcodeInstr::mksimple(
          0xcf35, 16, "BREMBITS",
          std::bind(exec_int_builder_func, _1, "BREMBITS", [](Ref<CellBuilder> b) { return b->remaining_bits(); })))
      .insert(OpcodeInstr::mksimple(
          0xcf36, 16, "BREMREFS",
          std::bind(exec_int_builder_func, _1, "BREMREFS", [](Ref<CellBuilder> b) { return b->remaining_refs(); })))
      .insert(OpcodeInstr::mksimple(
          0xcf37, 16, "BREMBITREFS",
          std::bind(exec_2int_builder_func, _1, "BREMBITSREFS",
                    [](Ref<CellBuilder> b) { return std::make_pair(b->remaining_bits(), b->remaining_refs()); })))
      .insert(OpcodeInstr::mkfixed(0xcf38, 16, 8, instr::dump_1c_l_add(1, "BCHKBITS "),
                                   std::bind(exec_builder_chk_bits, _1, _2, false)))
      .insert(OpcodeInstr::mksimple(0xcf39, 16, "BCHKBITS", std::bind(exec_builder_chk_bits_refs, _1, 1)))
      .insert(OpcodeInstr::mksimple(0xcf3a, 16, "BCHKREFS", std::bind(exec_builder_chk_bits_refs, _1, 2)))
      .insert(OpcodeInstr::mksimple(0xcf3b, 16, "BCHKBITREFS", std::bind(exec_builder_chk_bits_refs, _1, 3)))
      .insert(OpcodeInstr::mkfixed(0xcf3c, 16, 8, instr::dump_1c_l_add(1, "BCHKBITSQ "),
                                   std::bind(exec_builder_chk_bits, _1, _2, true)))
      .insert(OpcodeInstr::mksimple(0xcf3d, 16, "BCHKBITSQ", std::bind(exec_builder_chk_bits_refs, _1, 5)))
      .insert(OpcodeInstr::mksimple(0xcf3e, 16, "BCHKREFSQ", std::bind(exec_builder_chk_bits_refs, _1, 6)))
      .insert(OpcodeInstr::mksimple(0xcf3f, 16, "BCHKBITREFSQ", std::bind(exec_builder_chk_bits_refs, _1, 7)))
      .insert(OpcodeInstr::mksimple(0xcf40, 16, "STZEROES", std::bind(exec_store_same, _1, "STZEROES", 0)))
      .insert(OpcodeInstr::mksimple(0xcf41, 16, "STONES", std::bind(exec_store_same, _1, "STONES", 1)))
      .insert(OpcodeInstr::mksimple(0xcf42, 16, "STSAME", std::bind(exec_store_same, _1, "STSAME", -1)))
      .insert(OpcodeInstr::mkext(0xcf80 >> 7, 9, 5, dump_store_const_slice, exec_store_const_slice,
                                 compute_len_store_const_slice));
}

int exec_cell_to_slice(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute CTOS";
  auto cell = stack.pop_cell();
  stack.push_cellslice(load_cell_slice_ref(std::move(cell)));
  return 0;
}

int exec_cell_to_slice_maybe_special(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XCTOS";
  bool is_special;
  auto cell = stack.pop_cell();
  stack.push_cellslice(load_cell_slice_ref_special(std::move(cell), is_special));
  stack.push_bool(is_special);
  return 0;
}

int exec_load_special_cell(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute XLOAD" << (quiet ? "Q" : "");
  auto cell = stack.pop_cell();
  stack.push_cell(cell);
  if (quiet) {
    stack.push_bool(true);
  }
  return 0;
}

int exec_slice_chk_empty(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute ENDS";
  auto cs = stack.pop_cellslice();
  if (cs->size() || cs->size_refs()) {
    throw VmError{Excno::cell_und, "extra data remaining in deserialized cell"};
  }
  return 0;
}

int exec_load_int_common(Stack& stack, unsigned bits, unsigned mode) {
  auto cs = stack.pop_cellslice();
  if (!cs->have(bits)) {
    if (!(mode & 4)) {
      throw VmError{Excno::cell_und};
    }
    if (!(mode & 2)) {
      stack.push_cellslice(std::move(cs));
    }
    stack.push_smallint(0);
    return 0;
  }
  bool sgnd = !(mode & 1);
  if (mode & 2) {
    stack.push_int(cs->prefetch_int256(bits, sgnd));
  } else {
    stack.push_int(cs.write().fetch_int256(bits, sgnd));
    stack.push_cellslice(std::move(cs));
  }
  if (mode & 4) {
    stack.push_smallint(-1);
  }
  return 0;
}

int exec_load_int_fixed(VmState* st, unsigned args, unsigned mode) {
  unsigned bits = (args & 0xff) + 1;
  bool sgnd = !(mode & 1);
  VM_LOG(st) << "execute " << (mode & 2 ? "P" : "") << "LD" << (sgnd ? 'I' : 'U') << (mode & 4 ? "Q " : " ") << bits;
  return exec_load_int_common(st->get_stack(), bits, mode);
}

int exec_preload_ref_fixed(VmState* st, unsigned args) {
  unsigned idx = args & 3;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PLDREFIDX " << idx;
  auto cs = stack.pop_cellslice();
  if (!cs->have_refs(idx + 1)) {
    throw VmError{Excno::cell_und};
  }
  stack.push_cell(cs->prefetch_ref(idx));
  return 0;
}

int exec_preload_ref(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PLDREFVAR";
  stack.check_underflow(2);
  unsigned idx = stack.pop_smallint_range(3);
  auto cs = stack.pop_cellslice();
  if (!cs->have_refs(idx + 1)) {
    throw VmError{Excno::cell_und};
  }
  stack.push_cell(cs->prefetch_ref(idx));
  return 0;
}

int exec_load_ref(VmState* st, unsigned mode) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << (mode & 2 ? "P" : "") << "LDREF" << (mode & 4 ? "Q" : "");
  auto cs = stack.pop_cellslice();
  if (!cs->have_refs()) {
    if (!(mode & 4)) {
      throw VmError{Excno::cell_und};
    }
    stack.push_smallint(0);
    return 0;
  }
  if (mode & 2) {
    stack.push_cell(cs->prefetch_ref());
  } else {
    stack.push_cell(cs.write().fetch_ref());
    stack.push_cellslice(std::move(cs));
  }
  if (mode & 4) {
    stack.push_smallint(-1);
  }
  return 0;
}

int exec_load_ref_rev_to_slice(VmState* st, unsigned mode) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << (mode & 2 ? "P" : "") << "LDREFRTOS" << (mode & 4 ? "Q" : "");
  auto cs = stack.pop_cellslice();
  if (!cs->have_refs()) {
    if (!(mode & 4)) {
      throw VmError{Excno::cell_und};
    }
    stack.push_smallint(0);
    return 0;
  }
  if (mode & 2) {
    stack.push_cellslice(load_cell_slice_ref(cs->prefetch_ref()));
  } else {
    auto cell = cs.write().fetch_ref();
    stack.push_cellslice(std::move(cs));
    stack.push_cellslice(load_cell_slice_ref(std::move(cell)));
  }
  if (mode & 4) {
    stack.push_smallint(-1);
  }
  return 0;
}

int exec_load_slice_common(Stack& stack, unsigned bits, unsigned mode) {
  auto cs = stack.pop_cellslice();
  if (!cs->have(bits)) {
    if (!(mode & 2)) {
      throw VmError{Excno::cell_und};
    }
    if (!(mode & 1)) {
      stack.push_cellslice(std::move(cs));
    }
    stack.push_smallint(0);
    return 0;
  }
  if (mode & 1) {
    stack.push_cellslice(cs->prefetch_subslice(bits));
  } else {
    stack.push_cellslice(cs.write().fetch_subslice(bits));
    stack.push_cellslice(std::move(cs));
  }
  if (mode & 2) {
    stack.push_smallint(-1);
  }
  return 0;
}

int exec_load_slice_fixed(VmState* st, unsigned args) {
  unsigned bits = (args & 0xff) + 1;
  VM_LOG(st) << "execute LDSLICE " << bits;
  return exec_load_slice_common(st->get_stack(), bits, 0);
}

int exec_load_int_var(VmState* st, unsigned args) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << (args & 2 ? "PLD" : "LD") << (args & 1 ? "UX" : "IX") << (args & 4 ? "Q\n" : "\n");
  stack.check_underflow(2);
  unsigned bits = stack.pop_smallint_range(257 - (args & 1));
  return exec_load_int_common(stack, bits, args & 7);
}

std::string dump_load_int_var(CellSlice&, unsigned args) {
  return (args & 2 ? std::string{"PLD"} : std::string{"LD"}) + (args & 1 ? "UX" : "IX") + (args & 4 ? "Q" : "");
}

int exec_load_int_fixed2(VmState* st, unsigned args) {
  unsigned bits = (args & 0xff) + 1;
  args >>= 8;
  VM_LOG(st) << "execute " << (args & 2 ? "PLD" : "LD") << (args & 1 ? "U" : "I") << (args & 4 ? "Q " : " ") << bits;
  return exec_load_int_common(st->get_stack(), bits, args & 7);
}

std::string dump_load_int_fixed2(CellSlice&, unsigned args) {
  std::ostringstream os{args & 0x200 ? "PLD" : "LD"};
  os << (args & 0x100 ? 'U' : 'I');
  if (args & 0x400) {
    os << 'Q';
  }
  os << ' ' << ((args & 0xff) + 1);
  return os.str();
}

int exec_preload_uint_fixed_0e(VmState* st, unsigned args) {
  unsigned bits = ((args & 7) + 1) << 5;
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute PLDUZ " << bits;
  auto cs = stack.pop_cellslice();
  auto x = cs->prefetch_int256_zeroext(bits, false);
  stack.push_cellslice(std::move(cs));
  stack.push_int(std::move(x));
  return 0;
}

std::string dump_preload_uint_fixed_0e(CellSlice&, unsigned args) {
  std::ostringstream os{"PLDUZ "};
  unsigned bits = ((args & 7) + 1) << 5;
  os << bits;
  return os.str();
}

int exec_load_slice(VmState* st, unsigned args) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << (args & 1 ? "PLDSLICEX" : "LDSLICEX") << (args & 2 ? "Q\n" : "\n");
  stack.check_underflow(2);
  unsigned bits = stack.pop_smallint_range(1023);
  return exec_load_slice_common(stack, bits, args);
}

std::string dump_load_slice(CellSlice&, unsigned args) {
  return std::string{args & 1 ? "P" : ""} + "LDSLICEX" + (args & 2 ? "Q" : "");
}

int exec_load_slice_fixed2(VmState* st, unsigned args) {
  unsigned bits = (args & 0xff) + 1;
  args >>= 8;
  VM_LOG(st) << "execute " << (args & 1 ? "PLDSLICE" : "LDSLICE") << (args & 2 ? "Q " : " ") << bits;
  return exec_load_slice_common(st->get_stack(), bits, args);
}

std::string dump_load_slice_fixed2(CellSlice&, unsigned args) {
  unsigned bits = (args & 0xff) + 1;
  std::ostringstream os{args & 0x100 ? "PLDSLICE" : "LDSLICE"};
  if (args & 0x200) {
    os << 'Q';
  }
  os << ' ' << bits;
  return os.str();
}

int exec_slice_op_args(VmState* st, const char* name, unsigned max_arg1,
                       const std::function<bool(CellSlice&, unsigned)>& func) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(2);
  unsigned x = stack.pop_smallint_range(max_arg1);
  auto cs = stack.pop_cellslice();
  if (!func(cs.write(), x)) {
    throw VmError{Excno::cell_und};
  }
  stack.push_cellslice(std::move(cs));
  return 0;
}

int exec_slice_op_args2(VmState* st, const char* name, unsigned max_arg1, unsigned max_arg2,
                        const std::function<bool(CellSlice&, unsigned, unsigned)>& func) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(3);
  unsigned y = stack.pop_smallint_range(max_arg2);
  unsigned x = stack.pop_smallint_range(max_arg1);
  auto cs = stack.pop_cellslice();
  if (!func(cs.write(), x, y)) {
    throw VmError{Excno::cell_und};
  }
  stack.push_cellslice(std::move(cs));
  return 0;
}

int exec_slice_begins_with_common(VmState* st, Ref<CellSlice> cs2, bool quiet) {
  Stack& stack = st->get_stack();
  auto cs = stack.pop_cellslice();
  if (!cs->has_prefix(*cs2)) {
    if (!quiet) {
      throw VmError{Excno::cell_und, "slice does not begin with expected data bits"};
    }
    stack.push_cellslice(std::move(cs));
    stack.push_smallint(0);
    return 0;
  }
  cs.write().advance(cs2->size());
  stack.push_cellslice(std::move(cs));
  if (quiet) {
    stack.push_smallint(-1);
  }
  return 0;
}

int exec_slice_begins_with(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute SDBEGINSX" << (quiet ? "Q\n" : "\n");
  stack.check_underflow(2);
  return exec_slice_begins_with_common(st, stack.pop_cellslice(), quiet);
}

int exec_slice_begins_with_const(VmState* st, CellSlice& cs, unsigned args, int pfx_bits) {
  bool quiet = args & 128;
  unsigned data_bits = (args & 127) * 8 + 3;
  if (!cs.have(pfx_bits + data_bits)) {
    throw VmError{Excno::inv_opcode, "not enough data bits for a SDBEGINS instruction"};
  }
  cs.advance(pfx_bits);
  auto slice = cs.fetch_subslice(data_bits);
  slice.unique_write().remove_trailing();
  VM_LOG(st) << "execute SDBEGINS" << (quiet ? "Q " : " ") << slice;
  return exec_slice_begins_with_common(st, slice, quiet);
}

std::string dump_slice_begins_with_const(CellSlice& cs, unsigned args, int pfx_bits) {
  bool quiet = args & 128;
  unsigned data_bits = (args & 127) * 8 + 3;
  return dump_push_slice_common(cs, data_bits, 0, pfx_bits, quiet ? "SDBEGINSQ " : "SDBEGINS ");
}

int compute_len_slice_begins_with_const(const CellSlice& cs, unsigned args, int pfx_bits) {
  unsigned data_bits = (args & 127) * 8 + 3;
  return compute_len_push_slice_common(cs, data_bits, 0, pfx_bits);
}

int exec_subslice(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute SUBSLICE\n";
  stack.check_underflow(5);
  unsigned r2 = stack.pop_smallint_range(4), l2 = stack.pop_smallint_range(1023);
  unsigned r1 = stack.pop_smallint_range(4), l1 = stack.pop_smallint_range(1023);
  auto cs = stack.pop_cellslice();
  if (!cs.write().skip_first(l1, r1) || !cs.unique_write().only_first(l2, r2)) {
    throw VmError{Excno::cell_und};
  }
  stack.push_cellslice(std::move(cs));
  return 0;
}

int exec_split(VmState* st, bool quiet) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute SPLIT" << (quiet ? "Q\n" : "\n");
  stack.check_underflow(3);
  unsigned refs = stack.pop_smallint_range(4), bits = stack.pop_smallint_range(1023);
  auto cs = stack.pop_cellslice();
  if (!cs->have(bits) || !cs->have_refs(refs)) {
    if (!quiet) {
      throw VmError{Excno::cell_und};
    }
    stack.push_cellslice(std::move(cs));
    stack.push_smallint(0);
    return 0;
  }
  auto cs2 = cs;
  cs2.write().only_first(bits, refs);
  cs.write().skip_first(bits, refs);
  stack.push_cellslice(std::move(cs2));
  stack.push_cellslice(std::move(cs));
  if (quiet) {
    stack.push_smallint(-1);
  }
  return 0;
}

int exec_slice_chk_op_args(VmState* st, const char* name, unsigned max_arg1, bool quiet,
                           const std::function<bool(const CellSlice&, unsigned)>& func) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(2);
  unsigned x = stack.pop_smallint_range(max_arg1);
  auto cs = stack.pop_cellslice();
  bool res = func(*cs, x);
  if (quiet) {
    stack.push_smallint(res ? -1 : 0);
  } else if (!res) {
    throw VmError{Excno::cell_und};
  }
  return 0;
}

int exec_slice_chk_op_args2(VmState* st, const char* name, unsigned max_arg1, unsigned max_arg2, bool quiet,
                            const std::function<bool(const CellSlice&, unsigned, unsigned)>& func) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(3);
  unsigned y = stack.pop_smallint_range(max_arg2);
  unsigned x = stack.pop_smallint_range(max_arg1);
  auto cs = stack.pop_cellslice();
  bool res = func(*cs, x, y);
  if (quiet) {
    stack.push_smallint(res ? -1 : 0);
  } else if (!res) {
    throw VmError{Excno::cell_und};
  }
  return 0;
}

int exec_slice_bits_refs(VmState* st, unsigned mode) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute S" << (mode & 1 ? "BIT" : "") << (mode & 2 ? "REF" : "") << "S\n";
  stack.check_underflow(1);
  auto cs = stack.pop_cellslice();
  if (mode & 1) {
    stack.push_smallint(cs->size());
  }
  if (mode & 2) {
    stack.push_smallint(cs->size_refs());
  }
  return 0;
}

int exec_load_le_int(VmState* st, unsigned args) {
  unsigned len = (args & 2) ? 8 : 4;
  bool sgnd = !(args & 1);
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << (args & 4 ? "PLD" : "LD") << (sgnd ? 'I' : 'U') << "LE" << len
             << (args & 8 ? "Q\n" : "\n");
  stack.check_underflow(1);
  auto cs = stack.pop_cellslice();
  if (!cs->have(len << 3)) {
    if (args & 8) {
      if (!(args & 4)) {
        stack.push_cellslice(std::move(cs));
      }
      stack.push_smallint(0);
      return 0;
    }
    throw VmError{Excno::cell_und};
  }
  unsigned char buff[8];
  st->ensure_throw(cs->prefetch_bytes(buff, len));
  td::RefInt256 x{true};
  st->ensure_throw(x.unique_write().import_bytes_lsb(buff, len, sgnd));
  stack.push_int(std::move(x));
  if (!(args & 4)) {
    st->ensure_throw(cs.write().advance(len << 3));
    stack.push_cellslice(std::move(cs));
  }
  if (args & 8) {
    stack.push_smallint(-1);
  }
  return 0;
}

std::string dump_load_le_int(CellSlice& cs, unsigned args) {
  bool sgnd = !(args & 1);
  return std::string{args & 4 ? "P" : ""} + "LD" + (sgnd ? 'I' : 'U') + "LE" + ((args & 2) ? '8' : '4') +
         (args & 8 ? "Q" : "");
}

int exec_load_same(VmState* st, const char* name, int x) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute " << name;
  stack.check_underflow(1 + (x < 0));
  if (x < 0) {
    x = stack.pop_smallint_range(1);
  }
  auto cs = stack.pop_cellslice();
  unsigned n = cs->count_leading(x);
  if (n > 0) {
    cs.write().advance(n);
  }
  stack.push_smallint(n);
  stack.push_cellslice(std::move(cs));
  return 0;
}

int exec_cell_depth(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute CDEPTH";
  auto cell = stack.pop_maybe_cell();
  stack.push_smallint(cell.not_null() ? cell->get_depth() : 0);
  return 0;
}

int exec_slice_depth(VmState* st) {
  Stack& stack = st->get_stack();
  VM_LOG(st) << "execute SDEPTH";
  auto cs = stack.pop_cellslice();
  stack.push_smallint(cs->get_depth());
  return 0;
}

void register_cell_deserialize_ops(OpcodeTable& cp0) {
  using namespace std::placeholders;
  cp0.insert(OpcodeInstr::mksimple(0xd0, 8, "CTOS", exec_cell_to_slice))
      .insert(OpcodeInstr::mksimple(0xd1, 8, "ENDS", exec_slice_chk_empty))
      .insert(
          OpcodeInstr::mkfixed(0xd2, 8, 8, instr::dump_1c_l_add(1, "LDI "), std::bind(exec_load_int_fixed, _1, _2, 0)))
      .insert(
          OpcodeInstr::mkfixed(0xd3, 8, 8, instr::dump_1c_l_add(1, "LDU "), std::bind(exec_load_int_fixed, _1, _2, 1)))
      .insert(OpcodeInstr::mksimple(0xd4, 8, "LDREF", std::bind(exec_load_ref, _1, 0)))
      .insert(OpcodeInstr::mksimple(0xd5, 8, "LDREFRTOS", std::bind(exec_load_ref_rev_to_slice, _1, 0)))
      .insert(OpcodeInstr::mkfixed(0xd6, 8, 8, instr::dump_1c_l_add(1, "LDSLICE "), exec_load_slice_fixed))
      .insert(OpcodeInstr::mkfixed(0xd700 >> 3, 13, 3, dump_load_int_var, exec_load_int_var))
      .insert(OpcodeInstr::mkfixed(0xd708 >> 3, 13, 11, dump_load_int_fixed2, exec_load_int_fixed2))
      .insert(OpcodeInstr::mkfixed(0xd710 >> 3, 13, 3, dump_preload_uint_fixed_0e, exec_preload_uint_fixed_0e))
      .insert(OpcodeInstr::mkfixed(0xd718 >> 2, 14, 2, dump_load_slice, exec_load_slice))
      .insert(OpcodeInstr::mkfixed(0xd71c >> 2, 14, 10, dump_load_slice_fixed2, exec_load_slice_fixed2))
      .insert(OpcodeInstr::mksimple(0xd720, 16, "SDCUTFIRST",
                                    std::bind(exec_slice_op_args, _1, "SDCUTFIRST", 1023,
                                              [](auto& cs, unsigned bits) { return cs.only_first(bits); })))
      .insert(OpcodeInstr::mksimple(0xd721, 16, "SDSKIPFIRST",
                                    std::bind(exec_slice_op_args, _1, "SDSKIPFIRST", 1023,
                                              [](auto& cs, unsigned bits) { return cs.skip_first(bits); })))
      .insert(OpcodeInstr::mksimple(0xd722, 16, "SDCUTLAST",
                                    std::bind(exec_slice_op_args, _1, "SDCUTLAST", 1023,
                                              [](auto& cs, unsigned bits) { return cs.only_last(bits); })))
      .insert(OpcodeInstr::mksimple(0xd723, 16, "SDSKIPLAST",
                                    std::bind(exec_slice_op_args, _1, "SDSKIPLAST", 1023,
                                              [](auto& cs, unsigned bits) { return cs.skip_last(bits); })))
      .insert(OpcodeInstr::mksimple(
          0xd724, 16, "SDSUBSTR",
          std::bind(exec_slice_op_args2, _1, "SDSUBSTR", 1023, 1023,
                    [](auto& cs, unsigned offs, unsigned bits) { return cs.skip_first(offs) && cs.only_first(bits); })))
      .insert(OpcodeInstr::mksimple(0xd726, 16, "SDBEGINSX", std::bind(exec_slice_begins_with, _1, false)))
      .insert(OpcodeInstr::mksimple(0xd727, 16, "SDBEGINSXQ", std::bind(exec_slice_begins_with, _1, true)))
      .insert(OpcodeInstr::mkext(0xd728 >> 3, 13, 8, dump_slice_begins_with_const, exec_slice_begins_with_const,
                                 compute_len_slice_begins_with_const))
      .insert(OpcodeInstr::mksimple(
          0xd730, 16, "SCUTFIRST",
          std::bind(exec_slice_op_args2, _1, "SCUTFIRST", 1023, 4,
                    [](auto& cs, unsigned bits, unsigned refs) { return cs.only_first(bits, refs); })))
      .insert(OpcodeInstr::mksimple(
          0xd731, 16, "SSKIPFIRST",
          std::bind(exec_slice_op_args2, _1, "SSKIPFIRST", 1023, 4,
                    [](auto& cs, unsigned bits, unsigned refs) { return cs.skip_first(bits, refs); })))
      .insert(OpcodeInstr::mksimple(
          0xd732, 16, "SCUTLAST",
          std::bind(exec_slice_op_args2, _1, "SCUTLAST", 1023, 4,
                    [](auto& cs, unsigned bits, unsigned refs) { return cs.only_last(bits, refs); })))
      .insert(OpcodeInstr::mksimple(
          0xd733, 16, "SSKIPLAST",
          std::bind(exec_slice_op_args2, _1, "SSKIPLAST", 1023, 4,
                    [](auto& cs, unsigned bits, unsigned refs) { return cs.skip_last(bits, refs); })))
      .insert(OpcodeInstr::mksimple(0xd734, 16, "SUBSLICE", exec_subslice))
      .insert(OpcodeInstr::mksimple(0xd736, 16, "SPLIT", std::bind(exec_split, _1, false)))
      .insert(OpcodeInstr::mksimple(0xd737, 16, "SPLITQ", std::bind(exec_split, _1, true)))
      .insert(OpcodeInstr::mksimple(0xd739, 16, "XCTOS", exec_cell_to_slice_maybe_special))
      .insert(OpcodeInstr::mksimple(0xd73a, 16, "XLOAD", std::bind(exec_load_special_cell, _1, false)))
      .insert(OpcodeInstr::mksimple(0xd73b, 16, "XLOADQ", std::bind(exec_load_special_cell, _1, true)))
      .insert(OpcodeInstr::mksimple(0xd741, 16, "SCHKBITS",
                                    std::bind(exec_slice_chk_op_args, _1, "SCHKBITS", 1023, false,
                                              [](auto cs, unsigned bits) { return cs.have(bits); })))
      .insert(OpcodeInstr::mksimple(0xd742, 16, "SCHKREFS",
                                    std::bind(exec_slice_chk_op_args, _1, "SCHKREFS", 1023, false,
                                              [](auto cs, unsigned refs) { return cs.have_refs(refs); })))
      .insert(OpcodeInstr::mksimple(
          0xd743, 16, "SCHKBITREFS",
          std::bind(exec_slice_chk_op_args2, _1, "SCHKBITREFS", 1023, 4, false,
                    [](auto cs, unsigned bits, unsigned refs) { return cs.have(bits) && cs.have_refs(refs); })))
      .insert(OpcodeInstr::mksimple(0xd745, 16, "SCHKBITSQ",
                                    std::bind(exec_slice_chk_op_args, _1, "SCHKBITSQ", 1023, true,
                                              [](auto cs, unsigned bits) { return cs.have(bits); })))
      .insert(OpcodeInstr::mksimple(0xd746, 16, "SCHKREFSQ",
                                    std::bind(exec_slice_chk_op_args, _1, "SCHKREFSQ", 1023, true,
                                              [](auto cs, unsigned refs) { return cs.have_refs(refs); })))
      .insert(OpcodeInstr::mksimple(
          0xd747, 16, "SCHKBITREFSQ",
          std::bind(exec_slice_chk_op_args2, _1, "SCHKBITREFSQ", 1023, 4, true,
                    [](auto cs, unsigned bits, unsigned refs) { return cs.have(bits) && cs.have_refs(refs); })))
      .insert(OpcodeInstr::mksimple(0xd748, 16, "PLDREFVAR", exec_preload_ref))
      .insert(OpcodeInstr::mksimple(0xd749, 16, "SBITS", std::bind(exec_slice_bits_refs, _1, 1)))
      .insert(OpcodeInstr::mksimple(0xd74a, 16, "SREFS", std::bind(exec_slice_bits_refs, _1, 2)))
      .insert(OpcodeInstr::mksimple(0xd74b, 16, "SBITREFS", std::bind(exec_slice_bits_refs, _1, 3)))
      .insert(OpcodeInstr::mkfixed(0xd74c >> 2, 14, 2, instr::dump_1c_and(3, "PLDREFIDX "), exec_preload_ref_fixed))
      .insert(OpcodeInstr::mkfixed(0xd75, 12, 4, dump_load_le_int, exec_load_le_int))
      .insert(OpcodeInstr::mksimple(0xd760, 16, "LDZEROES", std::bind(exec_load_same, _1, "LDZEROES", 0)))
      .insert(OpcodeInstr::mksimple(0xd761, 16, "LDONES", std::bind(exec_load_same, _1, "LDONES", 1)))
      .insert(OpcodeInstr::mksimple(0xd762, 16, "LDSAME", std::bind(exec_load_same, _1, "LDSAME", -1)))
      .insert(OpcodeInstr::mksimple(0xd764, 16, "SDEPTH", exec_slice_depth))
      .insert(OpcodeInstr::mksimple(0xd765, 16, "CDEPTH", exec_cell_depth));
}

void register_cell_ops(OpcodeTable& cp0) {
  register_cell_const_ops(cp0);
  register_cell_cmp_ops(cp0);
  register_cell_serialize_ops(cp0);
  register_cell_deserialize_ops(cp0);
}

}  // namespace vm
