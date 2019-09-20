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
#include <tl/tlblib.hpp>

namespace tlb {

const False t_False;
const True t_True;
const Unit t_Unit;

const Bool t_Bool;

const Int t_int8{8}, t_int16{16}, t_int24{24}, t_int32{32}, t_int64{64}, t_int128{128}, t_int256{256}, t_int257{257};
const UInt t_uint8{8}, t_uint16{16}, t_uint24{24}, t_uint32{32}, t_uint64{64}, t_uint128{128}, t_uint256{256};
const NatWidth t_Nat{32};

const Anything t_Anything;
const RefAnything t_RefCell;

bool Bool::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  int t = get_tag(cs);
  return cs.advance(1) && pp.out(t ? "bool_true" : "bool_false");
}

bool NatWidth::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  long long value = (long long)cs.fetch_ulong(32);
  return value >= 0 && pp.out_int(value);
}

bool NatLeq::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  long long value = (long long)as_uint(cs);
  return value >= 0 && skip(cs) && pp.out_int(value);
}

bool NatLess::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  long long value = (long long)as_uint(cs);
  return value >= 0 && skip(cs) && pp.out_int(value);
}

bool TupleT::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  pp.open("tuple ");
  pp.os << n << " [";
  pp.mode_nl();
  int i = n;
  for (; i > 0; --i) {
    if (!X.print_skip(pp, cs)) {
      return false;
    }
    pp.mode_nl();
  }
  return pp.close("]");
}

bool CondT::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  return (n > 0 ? X.print_skip(pp, cs) : (!n && pp.out("()")));
}

bool Int::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  if (n <= 64) {
    long long value;
    return cs.fetch_int_to(n, value) && pp.out_int(value);
  } else {
    return pp.out_integer(cs.fetch_int256(n, true));
  }
}

bool UInt::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  if (n <= 64) {
    unsigned long long value;
    return cs.fetch_uint_to(n, value) && pp.out_uint(value);
  } else {
    return pp.out_integer(cs.fetch_int256(n, false));
  }
}

bool Bits::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  if (cs.have(n)) {
    pp.os << 'x' << cs.fetch_bits(n).to_hex();
    return true;
  } else {
    return false;
  }
}

bool TupleT::skip(vm::CellSlice& cs) const {
  int i = n;
  for (; i > 0; --i) {
    if (!X.skip(cs)) {
      break;
    }
  }
  return !i;
}

bool TupleT::validate_skip(vm::CellSlice& cs, bool weak) const {
  int i = n;
  for (; i > 0; --i) {
    if (!X.validate_skip(cs, weak)) {
      break;
    }
  }
  return !i;
}

bool TLB::validate_ref_internal(Ref<vm::Cell> cell_ref, bool weak) const {
  bool is_special;
  auto cs = load_cell_slice_special(std::move(cell_ref), is_special);
  return always_special() ? is_special : (is_special ? weak : (validate_skip(cs) && cs.empty_ext()));
}

bool TLB::print_skip(PrettyPrinter& pp, vm::CellSlice& cs) const {
  pp.open("raw@");
  pp << *this << ' ';
  vm::CellSlice cs_copy{cs};
  if (!validate_skip(cs) || !cs_copy.cut_tail(cs)) {
    return pp.fail("invalid value");
  }
  pp.raw_nl();
  cs_copy.print_rec(pp.os, pp.indent);
  return pp.mkindent() && pp.close();
}

bool TLB::print_special(PrettyPrinter& pp, vm::CellSlice& cs) const {
  pp.open("raw@");
  pp << *this << ' ';
  pp.raw_nl();
  cs.print_rec(pp.os, pp.indent);
  return pp.mkindent() && pp.close();
}

bool TLB::print_ref(PrettyPrinter& pp, Ref<vm::Cell> cell_ref) const {
  if (cell_ref.is_null()) {
    return pp.fail("null cell reference");
  }
  bool is_special;
  auto cs = load_cell_slice_special(std::move(cell_ref), is_special);
  if (is_special) {
    return print_special(pp, cs);
  } else {
    return print_skip(pp, cs) && (cs.empty_ext() || pp.fail("extra data in cell"));
  }
}

bool TLB::print_skip(std::ostream& os, vm::CellSlice& cs, int indent) const {
  PrettyPrinter pp{os, indent};
  return pp.fail_unless(print_skip(pp, cs));
}

bool TLB::print(std::ostream& os, const vm::CellSlice& cs, int indent) const {
  PrettyPrinter pp{os, indent};
  return pp.fail_unless(print(pp, cs));
}

bool TLB::print_ref(std::ostream& os, Ref<vm::Cell> cell_ref, int indent) const {
  PrettyPrinter pp{os, indent};
  return pp.fail_unless(print_ref(pp, std::move(cell_ref)));
}

std::string TLB::as_string_skip(vm::CellSlice& cs, int indent) const {
  std::ostringstream os;
  print_skip(os, cs, indent);
  return os.str();
}

std::string TLB::as_string(const vm::CellSlice& cs, int indent) const {
  std::ostringstream os;
  print(os, cs, indent);
  return os.str();
}

std::string TLB::as_string_ref(Ref<vm::Cell> cell_ref, int indent) const {
  std::ostringstream os;
  print_ref(os, std::move(cell_ref), indent);
  return os.str();
}

PrettyPrinter::~PrettyPrinter() {
  if (failed || level) {
    if (nl_used) {
      nl(-2 * level);
    }
    os << "PRINTING FAILED";
    while (level > 0) {
      os << ')';
      --level;
    }
  }
  if (nl_used) {
    os << std::endl;
  }
}

bool PrettyPrinter::fail(std::string msg) {
  os << "<FATAL: " << msg << ">";
  failed = true;
  return false;
}

bool PrettyPrinter::mkindent(int delta) {
  indent += delta;
  for (int i = 0; i < indent; i++) {
    os << ' ';
  }
  nl_used = true;
  return true;
}

bool PrettyPrinter::nl(int delta) {
  os << std::endl;
  return mkindent(delta);
}
bool PrettyPrinter::raw_nl(int delta) {
  os << std::endl;
  indent += delta;
  nl_used = true;
  return true;
}

bool PrettyPrinter::open(std::string msg) {
  os << "(" << msg;
  indent += 2;
  level++;
  return true;
}

bool PrettyPrinter::close() {
  return close("");
}

bool PrettyPrinter::close(std::string msg) {
  if (level <= 0) {
    return fail("cannot close scope");
  }
  indent -= 2;
  --level;
  os << msg << ")";
  return true;
}

bool PrettyPrinter::mode_nl() {
  if (mode & 1) {
    return nl();
  } else {
    os << ' ';
    return true;
  }
}

bool PrettyPrinter::field(std::string name) {
  mode_nl();
  os << name << ':';
  return true;
}

bool PrettyPrinter::field() {
  mode_nl();
  return true;
}

bool PrettyPrinter::field_int(long long x, std::string name) {
  os << ' ' << name << ':' << x;
  return true;
}

bool PrettyPrinter::field_int(long long x) {
  os << ' ' << x;
  return true;
}

bool PrettyPrinter::field_uint(unsigned long long x, std::string name) {
  os << ' ' << name << ':' << x;
  return true;
}

bool PrettyPrinter::field_uint(unsigned long long x) {
  os << ' ' << x;
  return true;
}

bool PrettyPrinter::fetch_bits_field(vm::CellSlice& cs, int n) {
  os << " x";
  return cs.have(n) && out(cs.fetch_bits(n).to_hex());
}

bool PrettyPrinter::fetch_bits_field(vm::CellSlice& cs, int n, std::string name) {
  os << ' ' << name << ":x";
  return cs.have(n) && out(cs.fetch_bits(n).to_hex());
}

bool PrettyPrinter::fetch_int_field(vm::CellSlice& cs, int n) {
  return cs.have(n) && field_int(cs.fetch_long(n));
}

bool PrettyPrinter::fetch_int_field(vm::CellSlice& cs, int n, std::string name) {
  return cs.have(n) && field_int(cs.fetch_long(n), name);
}

bool PrettyPrinter::fetch_uint_field(vm::CellSlice& cs, int n) {
  return cs.have(n) && field_uint(cs.fetch_ulong(n));
}

bool PrettyPrinter::fetch_uint_field(vm::CellSlice& cs, int n, std::string name) {
  return cs.have(n) && field_uint(cs.fetch_ulong(n), name);
}

bool PrettyPrinter::fetch_int256_field(vm::CellSlice& cs, int n) {
  os << ' ';
  return out_integer(cs.fetch_int256(n, true));
}

bool PrettyPrinter::fetch_int256_field(vm::CellSlice& cs, int n, std::string name) {
  os << ' ' << name << ':';
  return out_integer(cs.fetch_int256(n, true));
}

bool PrettyPrinter::fetch_uint256_field(vm::CellSlice& cs, int n) {
  os << ' ';
  return out_integer(cs.fetch_int256(n, false));
}

bool PrettyPrinter::fetch_uint256_field(vm::CellSlice& cs, int n, std::string name) {
  os << ' ' << name << ':';
  return out_integer(cs.fetch_int256(n, false));
}

}  // namespace tlb
