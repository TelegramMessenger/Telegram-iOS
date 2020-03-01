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
 *   TYPE EXPRESSIONS
 * 
 */

int TypeExpr::holes = 0, TypeExpr::type_vars = 0;  // not thread safe, but it is ok for now

void TypeExpr::compute_width() {
  switch (constr) {
    case te_Atomic:
    case te_Map:
      minw = maxw = 1;
      break;
    case te_Tensor:
      minw = maxw = 0;
      for (TypeExpr* arg : args) {
        minw += arg->minw;
        maxw += arg->maxw;
      }
      if (minw > w_inf) {
        minw = w_inf;
      }
      if (maxw > w_inf) {
        maxw = w_inf;
      }
      break;
    case te_Tuple:
      minw = maxw = 1;
      for (TypeExpr* arg : args) {
        arg->compute_width();
      }
      break;
    case te_Indirect:
      minw = args[0]->minw;
      maxw = args[0]->maxw;
      break;
    default:
      minw = 0;
      maxw = w_inf;
      break;
  }
}

bool TypeExpr::recompute_width() {
  switch (constr) {
    case te_Tensor:
    case te_Indirect: {
      int min = 0, max = 0;
      for (TypeExpr* arg : args) {
        min += arg->minw;
        max += arg->maxw;
      }
      if (min > maxw || max < minw) {
        return false;
      }
      if (min > w_inf) {
        min = w_inf;
      }
      if (max > w_inf) {
        max = w_inf;
      }
      if (minw < min) {
        minw = min;
      }
      if (maxw > max) {
        maxw = max;
      }
      return true;
    }
    case te_Tuple: {
      for (TypeExpr* arg : args) {
        if (arg->minw > 1 || arg->maxw < 1 || arg->minw > arg->maxw) {
          return false;
        }
      }
      return true;
    }
    default:
      return false;
  }
}

int TypeExpr::extract_components(std::vector<TypeExpr*>& comp_list) {
  if (constr != te_Indirect && constr != te_Tensor) {
    comp_list.push_back(this);
    return 1;
  }
  int res = 0;
  for (TypeExpr* arg : args) {
    res += arg->extract_components(comp_list);
  }
  return res;
}

TypeExpr* TypeExpr::new_map(TypeExpr* from, TypeExpr* to) {
  return new TypeExpr{te_Map, std::vector<TypeExpr*>{from, to}};
}

void TypeExpr::replace_with(TypeExpr* te2) {
  if (te2 == this) {
    return;
  }
  constr = te_Indirect;
  value = 0;
  minw = te2->minw;
  maxw = te2->maxw;
  args.clear();
  args.push_back(te2);
}

bool TypeExpr::remove_indirect(TypeExpr*& te, TypeExpr* forbidden) {
  assert(te);
  while (te->constr == te_Indirect) {
    te = te->args[0];
  }
  if (te->constr == te_Unknown) {
    return te != forbidden;
  }
  bool res = true;
  for (auto& x : te->args) {
    res &= remove_indirect(x, forbidden);
  }
  return res;
}

bool TypeExpr::remove_forall(TypeExpr*& te) {
  assert(te);
  if (te->constr != te_ForAll) {
    return false;
  }
  assert(te->args.size() >= 1);
  std::vector<TypeExpr*> new_vars;
  for (std::size_t i = 1; i < te->args.size(); i++) {
    new_vars.push_back(new_hole(1));
  }
  TypeExpr* te2 = te;
  // std::cerr << "removing universal quantifier in " << te << std::endl;
  te = te->args[0];
  remove_forall_in(te, te2, new_vars);
  // std::cerr << "-> " << te << std::endl;
  return true;
}

bool TypeExpr::remove_forall_in(TypeExpr*& te, TypeExpr* te2, const std::vector<TypeExpr*>& new_vars) {
  assert(te);
  assert(te2 && te2->constr == te_ForAll);
  if (te->constr == te_Var) {
    for (std::size_t i = 0; i < new_vars.size(); i++) {
      if (te == te2->args[i + 1]) {
        te = new_vars[i];
        return true;
      }
    }
    return false;
  }
  if (te->constr == te_ForAll) {
    return false;
  }
  if (te->args.empty()) {
    return false;
  }
  auto te1 = new TypeExpr(*te);
  bool res = false;
  for (auto& arg : te1->args) {
    res |= remove_forall_in(arg, te2, new_vars);
  }
  if (res) {
    te = te1;
  } else {
    delete te1;
  }
  return res;
}

void TypeExpr::show_width(std::ostream& os) {
  os << minw;
  if (maxw != minw) {
    os << "..";
    if (maxw < w_inf) {
      os << maxw;
    }
  }
}

std::ostream& operator<<(std::ostream& os, TypeExpr* type_expr) {
  if (!type_expr) {
    return os << "(null-type-ptr)";
  }
  return type_expr->print(os);
}

std::ostream& TypeExpr::print(std::ostream& os, int lex_level) {
  switch (constr) {
    case te_Unknown:
      return os << "??" << value;
    case te_Var:
      if (value >= -26 && value < 0) {
        return os << "_" << (char)(91 + value);
      } else if (value >= 0 && value < 26) {
        return os << (char)(65 + value);
      } else {
        return os << "TVAR" << value;
      }
    case te_Indirect:
      return os << args[0];
    case te_Atomic: {
      switch (value) {
        case _Int:
          return os << "int";
        case _Cell:
          return os << "cell";
        case _Slice:
          return os << "slice";
        case _Builder:
          return os << "builder";
        case _Cont:
          return os << "cont";
        case _Tuple:
          return os << "tuple";
        case _Type:
          return os << "type";
        default:
          return os << "atomic-type-" << value;
      }
    }
    case te_Tensor: {
      if (lex_level > -127) {
        os << "(";
      }
      auto c = args.size();
      if (c) {
        for (const auto& x : args) {
          x->print(os);
          if (--c) {
            os << ", ";
          }
        }
      }
      if (lex_level > -127) {
        os << ")";
      }
      return os;
    }
    case te_Tuple: {
      os << "[";
      auto c = args.size();
      if (c == 1 && args[0]->constr == te_Tensor) {
        args[0]->print(os, -127);
      } else if (c) {
        for (const auto& x : args) {
          x->print(os);
          if (--c) {
            os << ", ";
          }
        }
      }
      return os << "]";
    }
    case te_Map: {
      assert(args.size() == 2);
      if (lex_level > 0) {
        os << "(";
      }
      args[0]->print(os, 1);
      os << " -> ";
      args[1]->print(os);
      if (lex_level > 0) {
        os << ")";
      }
      return os;
    }
    case te_ForAll: {
      assert(args.size() >= 1);
      if (lex_level > 0) {
        os << '(';
      }
      os << "Forall ";
      for (std::size_t i = 1; i < args.size(); i++) {
        os << (i > 1 ? ' ' : '(');
        args[i]->print(os);
      }
      os << ") ";
      args[0]->print(os);
      if (lex_level > 0) {
        os << ')';
      }
      return os;
    }
    default:
      return os << "unknown-type-expr-" << constr;
  }
}

void UnifyError::print_message(std::ostream& os) const {
  os << "cannot unify type " << te1 << " with " << te2;
  if (!msg.empty()) {
    os << ": " << msg;
  }
}

std::ostream& operator<<(std::ostream& os, const UnifyError& ue) {
  ue.print_message(os);
  return os;
}

std::string UnifyError::message() const {
  std::ostringstream os;
  UnifyError::print_message(os);
  return os.str();
}

void check_width_compat(TypeExpr* te1, TypeExpr* te2) {
  if (te1->minw > te2->maxw || te2->minw > te1->maxw) {
    std::ostringstream os{"cannot unify types of widths "};
    te1->show_width(os);
    os << " and ";
    te2->show_width(os);
    throw UnifyError{te1, te2, os.str()};
  }
}

void check_update_widths(TypeExpr* te1, TypeExpr* te2) {
  check_width_compat(te1, te2);
  te1->minw = te2->minw = std::max(te1->minw, te2->minw);
  te1->maxw = te2->maxw = std::min(te1->maxw, te2->maxw);
  assert(te1->minw <= te1->maxw);
}

void unify(TypeExpr*& te1, TypeExpr*& te2) {
  assert(te1 && te2);
  // std::cerr << "unify( " << te1 << " , " << te2 << " )\n";
  while (te1->constr == TypeExpr::te_Indirect) {
    te1 = te1->args[0];
  }
  while (te2->constr == TypeExpr::te_Indirect) {
    te2 = te2->args[0];
  }
  if (te1 == te2) {
    return;
  }
  if (te1->constr == TypeExpr::te_ForAll) {
    TypeExpr* te = te1;
    if (!TypeExpr::remove_forall(te)) {
      throw UnifyError{te1, te2, "cannot remove universal type quantifier while performing type unification"};
    }
    unify(te, te2);
    return;
  }
  if (te2->constr == TypeExpr::te_ForAll) {
    TypeExpr* te = te2;
    if (!TypeExpr::remove_forall(te)) {
      throw UnifyError{te2, te1, "cannot remove universal type quantifier while performing type unification"};
    }
    unify(te1, te);
    return;
  }
  if (te1->constr == TypeExpr::te_Unknown) {
    if (te2->constr == TypeExpr::te_Unknown) {
      assert(te1->value != te2->value);
    }
    if (!TypeExpr::remove_indirect(te2, te1)) {
      throw UnifyError{te1, te2, "type unification results in an infinite cyclic type"};
    }
    check_update_widths(te1, te2);
    te1->replace_with(te2);
    te1 = te2;
    return;
  }
  if (te2->constr == TypeExpr::te_Unknown) {
    if (!TypeExpr::remove_indirect(te1, te2)) {
      throw UnifyError{te2, te1, "type unification results in an infinite cyclic type"};
    }
    check_update_widths(te2, te1);
    te2->replace_with(te1);
    te2 = te1;
    return;
  }
  if (te1->constr != te2->constr || te1->value != te2->value || te1->args.size() != te2->args.size()) {
    throw UnifyError{te1, te2};
  }
  for (std::size_t i = 0; i < te1->args.size(); i++) {
    unify(te1->args[i], te2->args[i]);
  }
  if (te1->constr == TypeExpr::te_Tensor) {
    if (!te1->recompute_width()) {
      throw UnifyError{te1, te2, "type unification incompatible with known width of first type"};
    }
    if (!te2->recompute_width()) {
      throw UnifyError{te2, te1, "type unification incompatible with known width of first type"};
    }
    check_update_widths(te1, te2);
  }
  te1->replace_with(te2);
  te1 = te2;
}

}  // namespace funC
