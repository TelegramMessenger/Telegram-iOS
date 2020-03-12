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
#include "func.h"

namespace funC {

/*
 * 
 *   ABSTRACT CODE
 * 
 */

TmpVar::TmpVar(var_idx_t _idx, int _cls, TypeExpr* _type, SymDef* sym, const SrcLocation* loc)
    : v_type(_type), idx(_idx), cls(_cls), coord(0) {
  if (sym) {
    name = sym->sym_idx;
    sym->value->idx = _idx;
  }
  if (loc) {
    where = std::make_unique<SrcLocation>(*loc);
  }
  if (!_type) {
    v_type = TypeExpr::new_hole();
  }
}

void TmpVar::set_location(const SrcLocation& loc) {
  if (where) {
    *where = loc;
  } else {
    where = std::make_unique<SrcLocation>(loc);
  }
}

void TmpVar::dump(std::ostream& os) const {
  show(os);
  os << " : " << v_type << " (width ";
  v_type->show_width(os);
  os << ")";
  if (coord > 0) {
    os << " = _" << (coord >> 8) << '.' << (coord & 255);
  } else if (coord < 0) {
    int n = (~coord >> 8), k = (~coord & 0xff);
    if (k) {
      os << " = (_" << n << ".._" << (n + k - 1) << ")";
    } else {
      os << " = ()";
    }
  }
  os << std::endl;
}

void TmpVar::show(std::ostream& os, int omit_idx) const {
  if (cls & _Named) {
    os << sym::symbols.get_name(name);
    if (omit_idx && (omit_idx >= 2 || (cls & _UniqueName))) {
      return;
    }
  }
  os << '_' << idx;
}

std::ostream& operator<<(std::ostream& os, const TmpVar& var) {
  var.show(os);
  return os;
}

void VarDescr::show_value(std::ostream& os) const {
  if (val & _Int) {
    os << 'i';
  }
  if (val & _Const) {
    os << 'c';
  }
  if (val & _Zero) {
    os << '0';
  }
  if (val & _NonZero) {
    os << '!';
  }
  if (val & _Pos) {
    os << '>';
  }
  if (val & _Neg) {
    os << '<';
  }
  if (val & _Bool) {
    os << 'B';
  }
  if (val & _Bit) {
    os << 'b';
  }
  if (val & _Even) {
    os << 'E';
  }
  if (val & _Odd) {
    os << 'O';
  }
  if (val & _Finite) {
    os << 'f';
  }
  if (val & _Nan) {
    os << 'N';
  }
  if (int_const.not_null()) {
    os << '=' << int_const;
  }
}

void VarDescr::show(std::ostream& os, const char* name) const {
  if (flags & _Last) {
    os << '*';
  }
  if (flags & _Unused) {
    os << '?';
  }
  if (name) {
    os << name;
  }
  os << '_' << idx;
  show_value(os);
}

void VarDescr::set_const(long long value) {
  return set_const(td::make_refint(value));
}

void VarDescr::set_const(td::RefInt256 value) {
  int_const = std::move(value);
  if (!int_const->signed_fits_bits(257)) {
    int_const.write().invalidate();
  }
  val = _Const | _Int;
  int s = sgn(int_const);
  if (s < -1) {
    val |= _Nan | _NonZero;
  } else if (s < 0) {
    val |= _NonZero | _Neg | _Finite;
    if (*int_const == -1) {
      val |= _Bool;
    }
  } else if (s > 0) {
    val |= _NonZero | _Pos | _Finite;
  } else if (!s) {
    if (*int_const == 1) {
      val |= _Bit;
    }
    val |= _Zero | _Neg | _Pos | _Finite | _Bool | _Bit;
  }
  if (val & _Finite) {
    val |= int_const->get_bit(0) ? _Odd : _Even;
  }
}

void VarDescr::set_const_nan() {
  set_const(td::make_refint());
}

void VarDescr::operator|=(const VarDescr& y) {
  val &= y.val;
  if (is_int_const() && cmp(int_const, y.int_const) != 0) {
    val &= ~_Const;
  }
  if (!(val & _Const)) {
    int_const.clear();
  }
}

void VarDescr::operator&=(const VarDescr& y) {
  val |= y.val;
  if (y.int_const.not_null() && int_const.is_null()) {
    int_const = y.int_const;
  }
}

void VarDescr::set_value(const VarDescr& y) {
  val = y.val;
  int_const = y.int_const;
}

void VarDescr::set_value(VarDescr&& y) {
  val = y.val;
  int_const = std::move(y.int_const);
}

void VarDescr::clear_value() {
  val = 0;
  int_const.clear();
}

void VarDescrList::show(std::ostream& os) const {
  if (unreachable) {
    os << "<unreachable> ";
  }
  os << "[";
  for (const auto& v : list) {
    os << ' ' << v;
  }
  os << " ]\n";
}

void Op::flags_set_clear(int set, int clear) {
  flags = (flags | set) & ~clear;
  for (auto& op : block0) {
    op.flags_set_clear(set, clear);
  }
  for (auto& op : block1) {
    op.flags_set_clear(set, clear);
  }
}
void Op::split_vars(const std::vector<TmpVar>& vars) {
  split_var_list(left, vars);
  split_var_list(right, vars);
  for (auto& op : block0) {
    op.split_vars(vars);
  }
  for (auto& op : block1) {
    op.split_vars(vars);
  }
}

void Op::split_var_list(std::vector<var_idx_t>& var_list, const std::vector<TmpVar>& vars) {
  int new_size = 0, changes = 0;
  for (var_idx_t v : var_list) {
    int c = vars.at(v).coord;
    if (c < 0) {
      ++changes;
      new_size += (~c & 0xff);
    } else {
      ++new_size;
    }
  }
  if (!changes) {
    return;
  }
  std::vector<var_idx_t> new_var_list;
  new_var_list.reserve(new_size);
  for (var_idx_t v : var_list) {
    int c = vars.at(v).coord;
    if (c < 0) {
      int n = (~c >> 8), k = (~c & 0xff);
      while (k-- > 0) {
        new_var_list.push_back(n++);
      }
    } else {
      new_var_list.push_back(v);
    }
  }
  var_list = std::move(new_var_list);
}

void Op::show(std::ostream& os, const std::vector<TmpVar>& vars, std::string pfx, int mode) const {
  if (mode & 2) {
    os << pfx << " [";
    for (const auto& v : var_info.list) {
      os << ' ';
      if (v.flags & VarDescr::_Last) {
        os << '*';
      }
      if (v.flags & VarDescr::_Unused) {
        os << '?';
      }
      os << vars[v.idx];
      if (mode & 4) {
        os << ':';
        v.show_value(os);
      }
    }
    os << " ]\n";
  }
  std::string dis = disabled() ? "<disabled> " : "";
  if (noreturn()) {
    dis += "<noret> ";
  }
  if (!is_pure()) {
    dis += "<impure> ";
  }
  switch (cl) {
    case _Undef:
      os << pfx << dis << "???\n";
      break;
    case _Nop:
      os << pfx << dis << "NOP\n";
      break;
    case _Call:
      os << pfx << dis << "CALL: ";
      show_var_list(os, left, vars);
      os << " := " << (fun_ref ? fun_ref->name() : "(null)") << " ";
      if ((mode & 4) && args.size() == right.size()) {
        show_var_list(os, args, vars);
      } else {
        show_var_list(os, right, vars);
      }
      os << std::endl;
      break;
    case _CallInd:
      os << pfx << dis << "CALLIND: ";
      show_var_list(os, left, vars);
      os << " := EXEC ";
      show_var_list(os, right, vars);
      os << std::endl;
      break;
    case _Let:
      os << pfx << dis << "LET ";
      show_var_list(os, left, vars);
      os << " := ";
      show_var_list(os, right, vars);
      os << std::endl;
      break;
    case _Tuple:
      os << pfx << dis << "MKTUPLE ";
      show_var_list(os, left, vars);
      os << " := ";
      show_var_list(os, right, vars);
      os << std::endl;
      break;
    case _UnTuple:
      os << pfx << dis << "UNTUPLE ";
      show_var_list(os, left, vars);
      os << " := ";
      show_var_list(os, right, vars);
      os << std::endl;
      break;
    case _IntConst:
      os << pfx << dis << "CONST ";
      show_var_list(os, left, vars);
      os << " := " << int_const << std::endl;
      break;
    case _Import:
      os << pfx << dis << "IMPORT ";
      show_var_list(os, left, vars);
      os << std::endl;
      break;
    case _Return:
      os << pfx << dis << "RETURN ";
      show_var_list(os, left, vars);
      os << std::endl;
      break;
    case _GlobVar:
      os << pfx << dis << "GLOBVAR ";
      show_var_list(os, left, vars);
      os << " := " << (fun_ref ? fun_ref->name() : "(null)") << std::endl;
      break;
    case _SetGlob:
      os << pfx << dis << "SETGLOB ";
      os << (fun_ref ? fun_ref->name() : "(null)") << " := ";
      show_var_list(os, right, vars);
      os << std::endl;
      break;
    case _Repeat:
      os << pfx << dis << "REPEAT ";
      show_var_list(os, left, vars);
      os << ' ';
      show_block(os, block0.get(), vars, pfx, mode);
      os << std::endl;
      break;
    case _If:
      os << pfx << dis << "IF ";
      show_var_list(os, left, vars);
      os << ' ';
      show_block(os, block0.get(), vars, pfx, mode);
      os << " ELSE ";
      show_block(os, block1.get(), vars, pfx, mode);
      os << std::endl;
      break;
    case _While:
      os << pfx << dis << "WHILE ";
      show_var_list(os, left, vars);
      os << ' ';
      show_block(os, block0.get(), vars, pfx, mode);
      os << " DO ";
      show_block(os, block1.get(), vars, pfx, mode);
      os << std::endl;
      break;
    case _Until:
      os << pfx << dis << "UNTIL ";
      show_var_list(os, left, vars);
      os << ' ';
      show_block(os, block0.get(), vars, pfx, mode);
      os << std::endl;
      break;
    case _Again:
      os << pfx << dis << "AGAIN ";
      show_var_list(os, left, vars);
      os << ' ';
      show_block(os, block0.get(), vars, pfx, mode);
      os << std::endl;
      break;
    default:
      os << pfx << dis << "<???" << cl << "> ";
      show_var_list(os, left, vars);
      os << " -- ";
      show_var_list(os, right, vars);
      os << std::endl;
      break;
  }
}

void Op::show_var_list(std::ostream& os, const std::vector<var_idx_t>& idx_list,
                       const std::vector<TmpVar>& vars) const {
  if (!idx_list.size()) {
    os << "()";
  } else if (idx_list.size() == 1) {
    os << vars.at(idx_list[0]);
  } else {
    os << "(" << vars.at(idx_list[0]);
    for (std::size_t i = 1; i < idx_list.size(); i++) {
      os << "," << vars.at(idx_list[i]);
    }
    os << ")";
  }
}

void Op::show_var_list(std::ostream& os, const std::vector<VarDescr>& list, const std::vector<TmpVar>& vars) const {
  auto n = list.size();
  if (!n) {
    os << "()";
  } else {
    os << "( ";
    for (std::size_t i = 0; i < list.size(); i++) {
      if (i) {
        os << ", ";
      }
      if (list[i].is_unused()) {
        os << '?';
      }
      os << vars.at(list[i].idx) << ':';
      list[i].show_value(os);
    }
    os << " )";
  }
}

void Op::show_block(std::ostream& os, const Op* block, const std::vector<TmpVar>& vars, std::string pfx, int mode) {
  os << "{" << std::endl;
  std::string pfx2 = pfx + "  ";
  for (const Op& op : block) {
    op.show(os, vars, pfx2, mode);
  }
  os << pfx << "}";
}

void CodeBlob::flags_set_clear(int set, int clear) {
  for (auto& op : ops) {
    op.flags_set_clear(set, clear);
  }
}

std::ostream& operator<<(std::ostream& os, const CodeBlob& code) {
  code.print(os);
  return os;
}

// flags: +1 = show variable definition locations; +2 = show vars after each op; +4 = show var abstract value info after each op; +8 = show all variables at start
void CodeBlob::print(std::ostream& os, int flags) const {
  os << "CODE BLOB: " << var_cnt << " variables, " << in_var_cnt << " input\n";
  if ((flags & 8) != 0) {
    for (const auto& var : vars) {
      var.dump(os);
      if (var.where && (flags & 1) != 0) {
        var.where->show(os);
        os << " defined here:\n";
        var.where->show_context(os);
      }
    }
  }
  os << "------- BEGIN --------\n";
  for (const auto& op : ops) {
    op.show(os, vars, "", flags);
  }
  os << "-------- END ---------\n\n";
}

var_idx_t CodeBlob::create_var(int cls, TypeExpr* var_type, SymDef* sym, const SrcLocation* location) {
  vars.emplace_back(var_cnt, cls, var_type, sym, location);
  if (sym) {
    sym->value->idx = var_cnt;
  }
  return var_cnt++;
}

bool CodeBlob::import_params(FormalArgList arg_list) {
  if (var_cnt || in_var_cnt || op_cnt) {
    return false;
  }
  std::vector<var_idx_t> list;
  for (const auto& par : arg_list) {
    TypeExpr* arg_type;
    SymDef* arg_sym;
    SrcLocation arg_loc;
    std::tie(arg_type, arg_sym, arg_loc) = par;
    list.push_back(create_var(arg_sym ? (TmpVar::_In | TmpVar::_Named) : TmpVar::_In, arg_type, arg_sym, &arg_loc));
  }
  emplace_back(loc, Op::_Import, list);
  in_var_cnt = var_cnt;
  return true;
}

}  // namespace funC
