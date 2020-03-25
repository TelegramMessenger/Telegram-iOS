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
#include "td/utils/crypto.h"
#include "common/refint.h"
#include <fstream>

namespace sym {

int compute_symbol_subclass(std::string str) {
  using funC::IdSc;
  if (str.size() < 2) {
    return IdSc::undef;
  } else if (str[0] == '.') {
    return IdSc::dotid;
  } else if (str[0] == '~') {
    return IdSc::tildeid;
  } else {
    return IdSc::undef;
  }
}

}  // namespace sym

namespace funC {
using namespace std::literals::string_literals;
using src::Lexer;
using sym::symbols;
using td::Ref;

inline bool is_dot_ident(sym_idx_t idx) {
  return symbols.get_subclass(idx) == IdSc::dotid;
}

inline bool is_tilde_ident(sym_idx_t idx) {
  return symbols.get_subclass(idx) == IdSc::tildeid;
}

inline bool is_special_ident(sym_idx_t idx) {
  return symbols.get_subclass(idx) != IdSc::undef;
}

/*
 * 
 *   PARSE SOURCE
 * 
 */

// TE ::= TA | TA -> TE
// TA ::= int | ... | cont | var | _ | () | ( TE { , TE } )
TypeExpr* parse_type(Lexer& lex);

TypeExpr* parse_type1(Lexer& lex) {
  switch (lex.tp()) {
    case _Int:
      lex.next();
      return TypeExpr::new_atomic(_Int);
    case _Cell:
      lex.next();
      return TypeExpr::new_atomic(_Cell);
    case _Slice:
      lex.next();
      return TypeExpr::new_atomic(_Slice);
    case _Builder:
      lex.next();
      return TypeExpr::new_atomic(_Builder);
    case _Cont:
      lex.next();
      return TypeExpr::new_atomic(_Cont);
    case _Tuple:
      lex.next();
      return TypeExpr::new_atomic(_Tuple);
    case _Var:
    case '_':
      lex.next();
      return TypeExpr::new_hole();
    case _Ident: {
      auto sym = sym::lookup_symbol(lex.cur().val);
      if (sym && dynamic_cast<SymValType*>(sym->value)) {
        auto val = dynamic_cast<SymValType*>(sym->value);
        lex.next();
        return val->get_type();
      }
      lex.cur().error_at("`", "` is not a type identifier");
    }
  }
  int c;
  if (lex.tp() == '[') {
    lex.next();
    c = ']';
  } else {
    lex.expect('(');
    c = ')';
  }
  if (lex.tp() == c) {
    lex.next();
    return c == ')' ? TypeExpr::new_unit() : TypeExpr::new_tuple({});
  }
  auto t1 = parse_type(lex);
  if (lex.tp() != ',') {
    lex.expect(c);
    return t1;
  }
  std::vector<TypeExpr*> tlist{1, t1};
  while (lex.tp() == ',') {
    lex.next();
    tlist.push_back(parse_type(lex));
  }
  lex.expect(c);
  return c == ')' ? TypeExpr::new_tensor(std::move(tlist)) : TypeExpr::new_tuple(std::move(tlist));
}

TypeExpr* parse_type(Lexer& lex) {
  auto res = parse_type1(lex);
  if (lex.tp() == _Mapsto) {
    lex.next();
    auto to = parse_type(lex);
    return TypeExpr::new_map(res, to);
  } else {
    return res;
  }
}

FormalArg parse_formal_arg(Lexer& lex, int fa_idx) {
  TypeExpr* arg_type = 0;
  SrcLocation loc = lex.cur().loc;
  if (lex.tp() == '_') {
    lex.next();
    if (lex.tp() == ',' || lex.tp() == ')') {
      return std::make_tuple(TypeExpr::new_hole(), (SymDef*)nullptr, loc);
    }
    arg_type = TypeExpr::new_hole();
    loc = lex.cur().loc;
  } else if (lex.tp() != _Ident) {
    arg_type = parse_type(lex);
  } else {
    auto sym = sym::lookup_symbol(lex.cur().val);
    if (sym && dynamic_cast<SymValType*>(sym->value)) {
      auto val = dynamic_cast<SymValType*>(sym->value);
      lex.next();
      arg_type = val->get_type();
    } else {
      arg_type = TypeExpr::new_hole();
    }
  }
  if (lex.tp() == '_' || lex.tp() == ',' || lex.tp() == ')') {
    if (lex.tp() == '_') {
      loc = lex.cur().loc;
      lex.next();
    }
    return std::make_tuple(arg_type, (SymDef*)nullptr, loc);
  }
  if (lex.tp() != _Ident) {
    lex.expect(_Ident, "formal parameter name");
  }
  loc = lex.cur().loc;
  SymDef* new_sym_def = sym::define_symbol(lex.cur().val, true, loc);
  if (!new_sym_def) {
    lex.cur().error_at("cannot define symbol `", "`");
  }
  if (new_sym_def->value) {
    lex.cur().error_at("redefined formal parameter `", "`");
  }
  new_sym_def->value = new SymVal{SymVal::_Param, fa_idx, arg_type};
  lex.next();
  return std::make_tuple(arg_type, new_sym_def, loc);
}

void parse_global_var_decl(Lexer& lex) {
  TypeExpr* var_type = 0;
  SrcLocation loc = lex.cur().loc;
  if (lex.tp() == '_') {
    lex.next();
    var_type = TypeExpr::new_hole();
    loc = lex.cur().loc;
  } else if (lex.tp() != _Ident) {
    var_type = parse_type(lex);
  } else {
    auto sym = sym::lookup_symbol(lex.cur().val);
    if (sym && dynamic_cast<SymValType*>(sym->value)) {
      auto val = dynamic_cast<SymValType*>(sym->value);
      lex.next();
      var_type = val->get_type();
    } else {
      var_type = TypeExpr::new_hole();
    }
  }
  if (lex.tp() != _Ident) {
    lex.expect(_Ident, "global variable name");
  }
  loc = lex.cur().loc;
  SymDef* sym_def = sym::define_global_symbol(lex.cur().val, false, loc);
  if (!sym_def) {
    lex.cur().error_at("cannot define global symbol `", "`");
  }
  if (sym_def->value) {
    auto val = dynamic_cast<SymValGlobVar*>(sym_def->value);
    if (!val) {
      lex.cur().error_at("symbol `", "` cannot be redefined as a global variable");
    }
    try {
      unify(var_type, val->sym_type);
    } catch (UnifyError& ue) {
      std::ostringstream os;
      os << "cannot unify new type " << var_type << " of global variable `" << sym_def->name()
         << "` with its previous type " << val->sym_type << ": " << ue;
      lex.cur().error(os.str());
    }
  } else {
    sym_def->value = new SymValGlobVar{glob_var_cnt++, var_type};
    glob_vars.push_back(sym_def);
  }
  lex.next();
}

FormalArgList parse_formal_args(Lexer& lex) {
  FormalArgList args;
  lex.expect('(', "formal argument list");
  if (lex.tp() == ')') {
    lex.next();
    return args;
  }
  int fa_idx = 0;
  args.push_back(parse_formal_arg(lex, fa_idx++));
  while (lex.tp() == ',') {
    lex.next();
    args.push_back(parse_formal_arg(lex, fa_idx++));
  }
  lex.expect(')');
  return args;
}

TypeExpr* extract_total_arg_type(const FormalArgList& arg_list) {
  if (arg_list.empty()) {
    return TypeExpr::new_unit();
  }
  if (arg_list.size() == 1) {
    return std::get<0>(arg_list[0]);
  }
  std::vector<TypeExpr*> type_list;
  for (auto& x : arg_list) {
    type_list.push_back(std::get<0>(x));
  }
  return TypeExpr::new_tensor(std::move(type_list));
}

void parse_global_var_decls(Lexer& lex) {
  lex.expect(_Global);
  while (true) {
    parse_global_var_decl(lex);
    if (lex.tp() != ',') {
      break;
    }
    lex.expect(',');
  }
  lex.expect(';');
}

SymValCodeFunc* make_new_glob_func(SymDef* func_sym, TypeExpr* func_type, bool impure = false) {
  SymValCodeFunc* res = new SymValCodeFunc{glob_func_cnt, func_type, impure};
  func_sym->value = res;
  glob_func.push_back(func_sym);
  glob_func_cnt++;
  return res;
}

bool check_global_func(const Lexem& cur, sym_idx_t func_name = 0) {
  if (!func_name) {
    func_name = cur.val;
  }
  SymDef* def = sym::lookup_symbol(func_name);
  if (!def) {
    cur.loc.show_error(std::string{"undefined function `"} + symbols.get_name(func_name) +
                       "`, defining a global function of unknown type");
    def = sym::define_global_symbol(func_name, 0, cur.loc);
    assert(def && "cannot define global function");
    ++undef_func_cnt;
    make_new_glob_func(def, TypeExpr::new_hole());  // was: ... ::new_func()
    return true;
  }
  SymVal* val = dynamic_cast<SymVal*>(def->value);
  if (!val) {
    cur.error(std::string{"symbol `"} + symbols.get_name(func_name) + "` has no value and no type");
    return false;
  } else if (!val->get_type()) {
    cur.error(std::string{"symbol `"} + symbols.get_name(func_name) + "` has no type, possibly not a function");
    return false;
  } else {
    return true;
  }
}

Expr* make_func_apply(Expr* fun, Expr* x) {
  Expr* res;
  if (fun->cls == Expr::_Glob) {
    if (x->cls == Expr::_Tensor) {
      res = new Expr{Expr::_Apply, fun->sym, x->args};
    } else {
      res = new Expr{Expr::_Apply, fun->sym, {x}};
    }
    res->flags = Expr::_IsRvalue | (fun->flags & Expr::_IsImpure);
  } else {
    res = new Expr{Expr::_VarApply, {fun, x}};
    res->flags = Expr::_IsRvalue;
  }
  return res;
}

Expr* parse_expr(Lexer& lex, CodeBlob& code, bool nv = false);

// parse ( E { , E } ) | () | [ E { , E } ] | [] | id | num | _
Expr* parse_expr100(Lexer& lex, CodeBlob& code, bool nv) {
  if (lex.tp() == '(' || lex.tp() == '[') {
    bool tf = (lex.tp() == '[');
    int clbr = (tf ? ']' : ')');
    SrcLocation loc{lex.cur().loc};
    lex.next();
    if (lex.tp() == clbr) {
      lex.next();
      Expr* res = new Expr{Expr::_Tensor, {}};
      res->flags = Expr::_IsRvalue;
      res->here = loc;
      res->e_type = TypeExpr::new_unit();
      if (tf) {
        res = new Expr{Expr::_MkTuple, {res}};
        res->flags = Expr::_IsRvalue;
        res->here = loc;
        res->e_type = TypeExpr::new_tuple(res->args.at(0)->e_type);
      }
      return res;
    }
    Expr* res = parse_expr(lex, code, nv);
    if (lex.tp() != ',') {
      lex.expect(clbr);
      return res;
    }
    std::vector<TypeExpr*> type_list;
    type_list.push_back(res->e_type);
    int f = res->flags;
    res = new Expr{Expr::_Tensor, {res}};
    while (lex.tp() == ',') {
      lex.next();
      auto x = parse_expr(lex, code, nv);
      res->pb_arg(x);
      if ((f ^ x->flags) & Expr::_IsType) {
        lex.cur().error("mixing type and non-type expressions inside the same tuple");
      }
      f &= x->flags;
      type_list.push_back(x->e_type);
    }
    res->here = loc;
    res->flags = f;
    res->e_type = TypeExpr::new_tensor(std::move(type_list), !tf);
    if (tf) {
      res = new Expr{Expr::_MkTuple, {res}};
      res->flags = f;
      res->here = loc;
      res->e_type = TypeExpr::new_tuple(res->args.at(0)->e_type);
    }
    lex.expect(clbr);
    return res;
  }
  int t = lex.tp();
  if (t == Lexem::Number) {
    Expr* res = new Expr{Expr::_Const, lex.cur().loc};
    res->flags = Expr::_IsRvalue;
    res->intval = td::string_to_int256(lex.cur().str);
    if (res->intval.is_null()) {
      lex.cur().error_at("invalid integer constant `", "`");
    }
    res->e_type = TypeExpr::new_atomic(_Int);
    lex.next();
    return res;
  }
  if (t == '_') {
    Expr* res = new Expr{Expr::_Hole, lex.cur().loc};
    res->val = -1;
    res->flags = (Expr::_IsLvalue | Expr::_IsHole | Expr::_IsNewVar);
    res->e_type = TypeExpr::new_hole();
    lex.next();
    return res;
  }
  if (t == _Var) {
    Expr* res = new Expr{Expr::_Type, lex.cur().loc};
    res->flags = Expr::_IsType;
    res->e_type = TypeExpr::new_hole();
    lex.next();
    return res;
  }
  if (t == _Int || t == _Cell || t == _Slice || t == _Builder || t == _Cont || t == _Type || t == _Tuple) {
    Expr* res = new Expr{Expr::_Type, lex.cur().loc};
    res->flags = Expr::_IsType;
    res->e_type = TypeExpr::new_atomic(t);
    lex.next();
    return res;
  }
  if (t == _Ident) {
    auto sym = sym::lookup_symbol(lex.cur().val);
    if (sym && dynamic_cast<SymValType*>(sym->value)) {
      auto val = dynamic_cast<SymValType*>(sym->value);
      Expr* res = new Expr{Expr::_Type, lex.cur().loc};
      res->flags = Expr::_IsType;
      res->e_type = val->get_type();
      lex.next();
      return res;
    }
    if (sym && dynamic_cast<SymValGlobVar*>(sym->value)) {
      auto val = dynamic_cast<SymValGlobVar*>(sym->value);
      Expr* res = new Expr{Expr::_GlobVar, lex.cur().loc};
      res->e_type = val->get_type();
      res->sym = sym;
      res->flags = Expr::_IsLvalue | Expr::_IsRvalue | Expr::_IsImpure;
      lex.next();
      return res;
    }
    bool auto_apply = false;
    Expr* res = new Expr{Expr::_Var, lex.cur().loc};
    if (nv) {
      res->val = ~lex.cur().val;
      res->e_type = TypeExpr::new_hole();
      res->flags = Expr::_IsLvalue | Expr::_IsNewVar;
      // std::cerr << "defined new variable " << lex.cur().str << " : " << res->e_type << std::endl;
    } else {
      if (!sym) {
        check_global_func(lex.cur());
        sym = sym::lookup_symbol(lex.cur().val);
      }
      res->sym = sym;
      SymVal* val = nullptr;
      if (sym) {
        val = dynamic_cast<SymVal*>(sym->value);
      }
      if (!val) {
        lex.cur().error_at("undefined identifier `", "`");
      } else if (val->type == SymVal::_Func) {
        res->e_type = val->get_type();
        res->cls = Expr::_Glob;
        auto_apply = val->auto_apply;
      } else if (val->idx < 0) {
        lex.cur().error_at("accessing variable `", "` being defined");
      } else {
        res->val = val->idx;
        res->e_type = val->get_type();
        // std::cerr << "accessing variable " << lex.cur().str << " : " << res->e_type << std::endl;
      }
      // std::cerr << "accessing symbol " << lex.cur().str << " : " << res->e_type << (val->impure ? " (impure)" : " (pure)") << std::endl;
      res->flags = Expr::_IsLvalue | Expr::_IsRvalue | (val->impure ? Expr::_IsImpure : 0);
    }
    if (auto_apply) {
      int impure = res->flags & Expr::_IsImpure;
      delete res;
      res = new Expr{Expr::_Apply, sym, {}};
      res->flags = Expr::_IsRvalue | impure;
    }
    res->deduce_type(lex.cur());
    lex.next();
    return res;
  }
  lex.expect(Lexem::Ident);
  return nullptr;
}

// parse E { E }
Expr* parse_expr90(Lexer& lex, CodeBlob& code, bool nv) {
  Expr* res = parse_expr100(lex, code, nv);
  while (lex.tp() == '(' || lex.tp() == '[' || (lex.tp() == _Ident && !is_special_ident(lex.cur().val))) {
    if (res->is_type()) {
      Expr* x = parse_expr100(lex, code, true);
      x->chk_lvalue(lex.cur());  // chk_lrvalue() ?
      TypeExpr* tp = res->e_type;
      delete res;
      res = new Expr{Expr::_TypeApply, {x}};
      res->e_type = tp;
      res->here = lex.cur().loc;
      try {
        unify(res->e_type, x->e_type);
      } catch (UnifyError& ue) {
        std::ostringstream os;
        os << "cannot transform expression of type " << x->e_type << " to explicitly requested type " << res->e_type
           << ": " << ue;
        lex.cur().error(os.str());
      }
      res->flags = x->flags;
    } else {
      Expr* x = parse_expr100(lex, code, false);
      x->chk_rvalue(lex.cur());
      res = make_func_apply(res, x);
      res->here = lex.cur().loc;
      res->deduce_type(lex.cur());
    }
  }
  return res;
}

// parse E { .method E | ~method E }
Expr* parse_expr80(Lexer& lex, CodeBlob& code, bool nv) {
  Expr* res = parse_expr90(lex, code, nv);
  while (lex.tp() == _Ident && is_special_ident(lex.cur().val)) {
    auto modify = is_tilde_ident(lex.cur().val);
    auto obj = res;
    if (modify) {
      obj->chk_lvalue(lex.cur());
    } else {
      obj->chk_rvalue(lex.cur());
    }
    auto loc = lex.cur().loc;
    auto name = lex.cur().val;
    auto sym = sym::lookup_symbol(name);
    if (!sym || !dynamic_cast<SymValFunc*>(sym->value)) {
      auto name1 = symbols.lookup(lex.cur().str.substr(1));
      if (name1) {
        auto sym1 = sym::lookup_symbol(name1);
        if (sym1 && dynamic_cast<SymValFunc*>(sym1->value)) {
          name = name1;
          sym = sym1;
        }
      }
    }
    check_global_func(lex.cur(), name);
    if (verbosity >= 2) {
      std::cerr << "using symbol `" << symbols.get_name(name) << "` for method call of " << lex.cur().str << std::endl;
    }
    sym = sym::lookup_symbol(name);
    SymValFunc* val = sym ? dynamic_cast<SymValFunc*>(sym->value) : nullptr;
    if (!val) {
      lex.cur().error_at("undefined method identifier `", "`");
    }
    lex.next();
    auto x = parse_expr100(lex, code, false);
    x->chk_rvalue(lex.cur());
    if (x->cls == Expr::_Tensor) {
      res = new Expr{Expr::_Apply, name, {obj}};
      res->args.insert(res->args.end(), x->args.begin(), x->args.end());
    } else {
      res = new Expr{Expr::_Apply, name, {obj, x}};
    }
    res->here = loc;
    res->flags = Expr::_IsRvalue | (val->impure ? Expr::_IsImpure : 0);
    res->deduce_type(lex.cur());
    if (modify) {
      auto tmp = res;
      res = new Expr{Expr::_LetFirst, {obj->copy(), tmp}};
      res->here = loc;
      res->flags = tmp->flags;
      res->set_val(name);
      res->deduce_type(lex.cur());
    }
  }
  return res;
}

// parse [ ~ ] E
Expr* parse_expr75(Lexer& lex, CodeBlob& code, bool nv) {
  if (lex.tp() == '~') {
    sym_idx_t name = symbols.lookup_add("~_");
    check_global_func(lex.cur(), name);
    SrcLocation loc{lex.cur().loc};
    lex.next();
    auto x = parse_expr80(lex, code, false);
    x->chk_rvalue(lex.cur());
    auto res = new Expr{Expr::_Apply, name, {x}};
    res->here = loc;
    res->set_val('~');
    res->flags = Expr::_IsRvalue;
    res->deduce_type(lex.cur());
    return res;
  } else {
    return parse_expr80(lex, code, nv);
  }
}

// parse E { (* | / | % | /% ) E }
Expr* parse_expr30(Lexer& lex, CodeBlob& code, bool nv) {
  Expr* res = parse_expr75(lex, code, nv);
  while (lex.tp() == '*' || lex.tp() == '/' || lex.tp() == '%' || lex.tp() == _DivMod || lex.tp() == _DivC ||
         lex.tp() == _DivR || lex.tp() == _ModC || lex.tp() == _ModR || lex.tp() == '&') {
    res->chk_rvalue(lex.cur());
    int t = lex.tp();
    sym_idx_t name = symbols.lookup_add(std::string{"_"} + lex.cur().str + "_");
    SrcLocation loc{lex.cur().loc};
    check_global_func(lex.cur(), name);
    lex.next();
    auto x = parse_expr75(lex, code, false);
    x->chk_rvalue(lex.cur());
    res = new Expr{Expr::_Apply, name, {res, x}};
    res->here = loc;
    res->set_val(t);
    res->flags = Expr::_IsRvalue;
    res->deduce_type(lex.cur());
  }
  return res;
}

// parse [-] E { (+ | - | `|` | ^) E }
Expr* parse_expr20(Lexer& lex, CodeBlob& code, bool nv) {
  Expr* res;
  int t = lex.tp();
  if (t == '-') {
    sym_idx_t name = symbols.lookup_add("-_");
    check_global_func(lex.cur(), name);
    SrcLocation loc{lex.cur().loc};
    lex.next();
    auto x = parse_expr30(lex, code, false);
    x->chk_rvalue(lex.cur());
    res = new Expr{Expr::_Apply, name, {x}};
    res->here = loc;
    res->set_val(t);
    res->flags = Expr::_IsRvalue;
    res->deduce_type(lex.cur());
  } else {
    res = parse_expr30(lex, code, nv);
  }
  while (lex.tp() == '-' || lex.tp() == '+' || lex.tp() == '|' || lex.tp() == '^') {
    res->chk_rvalue(lex.cur());
    t = lex.tp();
    sym_idx_t name = symbols.lookup_add(std::string{"_"} + lex.cur().str + "_");
    check_global_func(lex.cur(), name);
    SrcLocation loc{lex.cur().loc};
    lex.next();
    auto x = parse_expr30(lex, code, false);
    x->chk_rvalue(lex.cur());
    res = new Expr{Expr::_Apply, name, {res, x}};
    res->here = loc;
    res->set_val(t);
    res->flags = Expr::_IsRvalue;
    res->deduce_type(lex.cur());
  }
  return res;
}

// parse E { ( << | >> | >>~ | >>^ ) E }
Expr* parse_expr17(Lexer& lex, CodeBlob& code, bool nv) {
  Expr* res = parse_expr20(lex, code, nv);
  while (lex.tp() == _Lshift || lex.tp() == _Rshift || lex.tp() == _RshiftC || lex.tp() == _RshiftR) {
    res->chk_rvalue(lex.cur());
    int t = lex.tp();
    sym_idx_t name = symbols.lookup_add(std::string{"_"} + lex.cur().str + "_");
    check_global_func(lex.cur(), name);
    SrcLocation loc{lex.cur().loc};
    lex.next();
    auto x = parse_expr20(lex, code, false);
    x->chk_rvalue(lex.cur());
    res = new Expr{Expr::_Apply, name, {res, x}};
    res->here = loc;
    res->set_val(t);
    res->flags = Expr::_IsRvalue;
    res->deduce_type(lex.cur());
  }
  return res;
}

// parse E [ (== | < | > | <= | >= | != | <=> ) E ]
Expr* parse_expr15(Lexer& lex, CodeBlob& code, bool nv) {
  Expr* res = parse_expr17(lex, code, nv);
  if (lex.tp() == _Eq || lex.tp() == '<' || lex.tp() == '>' || lex.tp() == _Leq || lex.tp() == _Geq ||
      lex.tp() == _Neq || lex.tp() == _Spaceship) {
    res->chk_rvalue(lex.cur());
    int t = lex.tp();
    sym_idx_t name = symbols.lookup_add(std::string{"_"} + lex.cur().str + "_");
    check_global_func(lex.cur(), name);
    SrcLocation loc{lex.cur().loc};
    lex.next();
    auto x = parse_expr17(lex, code, false);
    x->chk_rvalue(lex.cur());
    res = new Expr{Expr::_Apply, name, {res, x}};
    res->here = loc;
    res->set_val(t);
    res->flags = Expr::_IsRvalue;
    res->deduce_type(lex.cur());
  }
  return res;
}

// parse E [ ? E : E ]
Expr* parse_expr13(Lexer& lex, CodeBlob& code, bool nv) {
  Expr* res = parse_expr15(lex, code, nv);
  if (lex.tp() == '?') {
    res->chk_rvalue(lex.cur());
    SrcLocation loc{lex.cur().loc};
    lex.next();
    auto x = parse_expr(lex, code, false);
    x->chk_rvalue(lex.cur());
    lex.expect(':');
    auto y = parse_expr13(lex, code, false);
    y->chk_rvalue(lex.cur());
    res = new Expr{Expr::_CondExpr, {res, x, y}};
    res->here = loc;
    res->flags = Expr::_IsRvalue;
    res->deduce_type(lex.cur());
  }
  return res;
}

// parse LE1 (= | += | -= | ... ) E2
Expr* parse_expr10(Lexer& lex, CodeBlob& code, bool nv) {
  auto x = parse_expr13(lex, code, nv);
  int t = lex.tp();
  if (t == _PlusLet || t == _MinusLet || t == _TimesLet || t == _DivLet || t == _DivRLet || t == _DivCLet ||
      t == _ModLet || t == _ModCLet || t == _ModRLet || t == _LshiftLet || t == _RshiftLet || t == _RshiftCLet ||
      t == _RshiftRLet || t == _AndLet || t == _OrLet || t == _XorLet) {
    x->chk_lvalue(lex.cur());
    x->chk_rvalue(lex.cur());
    sym_idx_t name = symbols.lookup_add(std::string{"^_"} + lex.cur().str + "_");
    check_global_func(lex.cur(), name);
    SrcLocation loc{lex.cur().loc};
    lex.next();
    auto y = parse_expr10(lex, code, false);
    y->chk_rvalue(lex.cur());
    Expr* z = new Expr{Expr::_Apply, name, {x, y}};
    z->here = loc;
    z->set_val(t);
    z->flags = Expr::_IsRvalue;
    z->deduce_type(lex.cur());
    Expr* res = new Expr{Expr::_Letop, {x->copy(), z}};
    res->here = loc;
    res->flags = (x->flags & ~Expr::_IsType) | Expr::_IsRvalue;
    res->set_val(t);
    res->deduce_type(lex.cur());
    return res;
  } else if (t == '=') {
    x->chk_lvalue(lex.cur());
    SrcLocation loc{lex.cur().loc};
    lex.next();
    auto y = parse_expr10(lex, code, false);
    y->chk_rvalue(lex.cur());
    x->predefine_vars();
    x->define_new_vars(code);
    Expr* res = new Expr{Expr::_Letop, {x, y}};
    res->here = loc;
    res->flags = (x->flags & ~Expr::_IsType) | Expr::_IsRvalue;
    res->set_val(t);
    res->deduce_type(lex.cur());
    return res;
  } else {
    return x;
  }
}

Expr* parse_expr(Lexer& lex, CodeBlob& code, bool nv) {
  return parse_expr10(lex, code, nv);
}

namespace blk_fl {
enum { end = 1, ret = 2, empty = 4 };
typedef int val;
constexpr val init = end | empty;
void combine(val& x, const val y) {
  x |= y & ret;
  x &= y | ~(end | empty);
}
void combine_parallel(val& x, const val y) {
  x &= y | ~(ret | empty);
  x |= y & end;
}
}  // namespace blk_fl

blk_fl::val parse_return_stmt(Lexer& lex, CodeBlob& code) {
  auto expr = parse_expr(lex, code);
  expr->chk_rvalue(lex.cur());
  try {
    // std::cerr << "in return: ";
    unify(expr->e_type, code.ret_type);
  } catch (UnifyError& ue) {
    std::ostringstream os;
    os << "previous function return type " << code.ret_type
       << " cannot be unified with return statement expression type " << expr->e_type << ": " << ue;
    lex.cur().error(os.str());
  }
  std::vector<var_idx_t> tmp_vars = expr->pre_compile(code);
  code.emplace_back(lex.cur().loc, Op::_Return, std::move(tmp_vars));
  lex.expect(';');
  return blk_fl::ret;
}

blk_fl::val parse_implicit_ret_stmt(Lexer& lex, CodeBlob& code) {
  auto ret_type = TypeExpr::new_unit();
  try {
    // std::cerr << "in implicit return: ";
    unify(ret_type, code.ret_type);
  } catch (UnifyError& ue) {
    std::ostringstream os;
    os << "previous function return type " << code.ret_type
       << " cannot be unified with implicit end-of-block return type " << ret_type << ": " << ue;
    lex.cur().error(os.str());
  }
  code.emplace_back(lex.cur().loc, Op::_Return);
  return blk_fl::ret;
}

blk_fl::val parse_stmt(Lexer& lex, CodeBlob& code);

blk_fl::val parse_block_stmt(Lexer& lex, CodeBlob& code, bool no_new_scope = false) {
  lex.expect('{');
  if (!no_new_scope) {
    sym::open_scope(lex);
  }
  blk_fl::val res = blk_fl::init;
  bool warned = false;
  while (lex.tp() != '}') {
    if (!(res & blk_fl::end) && !warned) {
      lex.cur().loc.show_warning("unreachable code");
      warned = true;
    }
    blk_fl::combine(res, parse_stmt(lex, code));
  }
  if (!no_new_scope) {
    sym::close_scope(lex);
  }
  lex.expect('}');
  return res;
}

blk_fl::val parse_repeat_stmt(Lexer& lex, CodeBlob& code) {
  SrcLocation loc{lex.cur().loc};
  lex.expect(_Repeat);
  auto expr = parse_expr(lex, code);
  expr->chk_rvalue(lex.cur());
  auto cnt_type = TypeExpr::new_atomic(_Int);
  try {
    unify(expr->e_type, cnt_type);
  } catch (UnifyError& ue) {
    std::ostringstream os;
    os << "repeat count value of type " << expr->e_type << " is not an integer: " << ue;
    lex.cur().error(os.str());
  }
  std::vector<var_idx_t> tmp_vars = expr->pre_compile(code);
  if (tmp_vars.size() != 1) {
    lex.cur().error("repeat count value is not a singleton");
  }
  Op& repeat_op = code.emplace_back(loc, Op::_Repeat, tmp_vars);
  code.push_set_cur(repeat_op.block0);
  blk_fl::val res = parse_block_stmt(lex, code);
  code.close_pop_cur(lex.cur().loc);
  return res | blk_fl::end;
}

blk_fl::val parse_while_stmt(Lexer& lex, CodeBlob& code) {
  SrcLocation loc{lex.cur().loc};
  lex.expect(_While);
  auto expr = parse_expr(lex, code);
  expr->chk_rvalue(lex.cur());
  auto cnt_type = TypeExpr::new_atomic(_Int);
  try {
    unify(expr->e_type, cnt_type);
  } catch (UnifyError& ue) {
    std::ostringstream os;
    os << "while condition value of type " << expr->e_type << " is not an integer: " << ue;
    lex.cur().error(os.str());
  }
  Op& while_op = code.emplace_back(loc, Op::_While);
  code.push_set_cur(while_op.block0);
  while_op.left = expr->pre_compile(code);
  code.close_pop_cur(lex.cur().loc);
  if (while_op.left.size() != 1) {
    lex.cur().error("while condition value is not a singleton");
  }
  code.push_set_cur(while_op.block1);
  blk_fl::val res1 = parse_block_stmt(lex, code);
  code.close_pop_cur(lex.cur().loc);
  return res1 | blk_fl::end;
}

blk_fl::val parse_do_stmt(Lexer& lex, CodeBlob& code) {
  Op& while_op = code.emplace_back(lex.cur().loc, Op::_Until);
  lex.expect(_Do);
  code.push_set_cur(while_op.block0);
  sym::open_scope(lex);
  blk_fl::val res = parse_block_stmt(lex, code, true);
  lex.expect(_Until);
  auto expr = parse_expr(lex, code);
  expr->chk_rvalue(lex.cur());
  sym::close_scope(lex);
  auto cnt_type = TypeExpr::new_atomic(_Int);
  try {
    unify(expr->e_type, cnt_type);
  } catch (UnifyError& ue) {
    std::ostringstream os;
    os << "`until` condition value of type " << expr->e_type << " is not an integer: " << ue;
    lex.cur().error(os.str());
  }
  while_op.left = expr->pre_compile(code);
  code.close_pop_cur(lex.cur().loc);
  if (while_op.left.size() != 1) {
    lex.cur().error("`until` condition value is not a singleton");
  }
  return res & ~blk_fl::empty;
}

blk_fl::val parse_if_stmt(Lexer& lex, CodeBlob& code, int first_lex = _If) {
  SrcLocation loc{lex.cur().loc};
  lex.expect(first_lex);
  auto expr = parse_expr(lex, code);
  expr->chk_rvalue(lex.cur());
  auto flag_type = TypeExpr::new_atomic(_Int);
  try {
    unify(expr->e_type, flag_type);
  } catch (UnifyError& ue) {
    std::ostringstream os;
    os << "`if` condition value of type " << expr->e_type << " is not an integer: " << ue;
    lex.cur().error(os.str());
  }
  std::vector<var_idx_t> tmp_vars = expr->pre_compile(code);
  if (tmp_vars.size() != 1) {
    lex.cur().error("condition value is not a singleton");
  }
  Op& if_op = code.emplace_back(loc, Op::_If, tmp_vars);
  code.push_set_cur(if_op.block0);
  blk_fl::val res1 = parse_block_stmt(lex, code);
  blk_fl::val res2 = blk_fl::init;
  code.close_pop_cur(lex.cur().loc);
  if (lex.tp() == _Else) {
    lex.expect(_Else);
    code.push_set_cur(if_op.block1);
    res2 = parse_block_stmt(lex, code);
    code.close_pop_cur(lex.cur().loc);
  } else if (lex.tp() == _Elseif || lex.tp() == _Elseifnot) {
    code.push_set_cur(if_op.block1);
    res2 = parse_if_stmt(lex, code, lex.tp());
    code.close_pop_cur(lex.cur().loc);
  } else {
    if_op.block1 = std::make_unique<Op>(lex.cur().loc, Op::_Nop);
  }
  if (first_lex == _Ifnot || first_lex == _Elseifnot) {
    std::swap(if_op.block0, if_op.block1);
  }
  blk_fl::combine_parallel(res1, res2);
  return res1;
}

blk_fl::val parse_stmt(Lexer& lex, CodeBlob& code) {
  switch (lex.tp()) {
    case _Return: {
      lex.next();
      return parse_return_stmt(lex, code);
    }
    case '{': {
      return parse_block_stmt(lex, code);
    }
    case ';': {
      lex.next();
      return blk_fl::init;
    }
    case _Repeat:
      return parse_repeat_stmt(lex, code);
    case _If:
    case _Ifnot:
      return parse_if_stmt(lex, code, lex.tp());
    case _Do:
      return parse_do_stmt(lex, code);
    case _While:
      return parse_while_stmt(lex, code);
    default: {
      auto expr = parse_expr(lex, code);
      expr->chk_rvalue(lex.cur());
      expr->pre_compile(code);
      lex.expect(';');
      return blk_fl::end;
    }
  }
}

CodeBlob* parse_func_body(Lexer& lex, FormalArgList arg_list, TypeExpr* ret_type) {
  lex.expect('{');
  CodeBlob* blob = new CodeBlob{ret_type};
  blob->import_params(std::move(arg_list));
  blk_fl::val res = blk_fl::init;
  bool warned = false;
  while (lex.tp() != '}') {
    if (!(res & blk_fl::end) && !warned) {
      lex.cur().loc.show_warning("unreachable code");
      warned = true;
    }
    blk_fl::combine(res, parse_stmt(lex, *blob));
  }
  if (res & blk_fl::end) {
    parse_implicit_ret_stmt(lex, *blob);
  }
  blob->close_blk(lex.cur().loc);
  lex.expect('}');
  return blob;
}

SymValAsmFunc* parse_asm_func_body(Lexer& lex, TypeExpr* func_type, const FormalArgList& arg_list, TypeExpr* ret_type,
                                   bool impure = false) {
  auto loc = lex.cur().loc;
  lex.expect(_Asm);
  int cnt = (int)arg_list.size();
  int width = ret_type->get_width();
  if (width < 0 || width > 16) {
    throw src::ParseError{loc, "return type of an assembler built-in function must have a well-defined fixed width"};
  }
  if (arg_list.size() > 16) {
    throw src::ParseError{loc, "assembler built-in function must have at most 16 arguments"};
  }
  std::vector<int> cum_arg_width;
  cum_arg_width.push_back(0);
  int tot_width = 0;
  for (auto& arg : arg_list) {
    int arg_width = std::get<TypeExpr*>(arg)->get_width();
    if (arg_width < 0 || arg_width > 16) {
      throw src::ParseError{std::get<SrcLocation>(arg),
                            "parameters of an assembler built-in function must have a well-defined fixed width"};
    }
    cum_arg_width.push_back(tot_width += arg_width);
  }
  std::vector<AsmOp> asm_ops;
  std::vector<int> arg_order, ret_order;
  if (lex.tp() == '(') {
    lex.expect('(');
    if (lex.tp() != _Mapsto) {
      std::vector<bool> visited(cnt, false);
      for (int i = 0; i < cnt; i++) {
        if (lex.tp() != _Ident) {
          lex.expect(_Ident);
        }
        auto sym = sym::lookup_symbol(lex.cur().val);
        int j;
        for (j = 0; j < cnt; j++) {
          if (std::get<SymDef*>(arg_list[j]) == sym) {
            break;
          }
        }
        if (j == cnt) {
          lex.cur().error("formal argument name expected");
        }
        if (visited[j]) {
          lex.cur().error("formal argument listed twice");
        }
        visited[j] = true;
        int c1 = cum_arg_width[j], c2 = cum_arg_width[j + 1];
        while (c1 < c2) {
          arg_order.push_back(c1++);
        }
        lex.next();
      }
      assert(arg_order.size() == (unsigned)tot_width);
    }
    if (lex.tp() == _Mapsto) {
      lex.expect(_Mapsto);
      std::vector<bool> visited(width, false);
      for (int i = 0; i < width; i++) {
        if (lex.tp() != Lexem::Number || lex.cur().str.size() > 3) {
          lex.expect(Lexem::Number);
        }
        int j = atoi(lex.cur().str.c_str());
        if (j < 0 || j >= width || visited[j]) {
          lex.cur().error("expected integer return value index 0 .. width-1");
        }
        visited[j] = true;
        ret_order.push_back(j);
        lex.next();
      }
    }
    lex.expect(')');
  }
  while (lex.tp() == _String) {
    asm_ops.push_back(AsmOp::Parse(lex.cur().str, cnt, width));
    lex.next();
    if (asm_ops.back().is_custom()) {
      cnt = width;
    }
  }
  if (asm_ops.empty()) {
    throw src::ParseError{lex.cur().loc, "string with assembler instruction expected"};
  }
  lex.expect(';');
  auto res = new SymValAsmFunc{func_type, asm_ops, impure};
  res->arg_order = std::move(arg_order);
  res->ret_order = std::move(ret_order);
  return res;
}

std::vector<TypeExpr*> parse_type_var_list(Lexer& lex) {
  std::vector<TypeExpr*> res;
  lex.expect(_Forall);
  int idx = 0;
  while (true) {
    if (lex.tp() == _Type) {
      lex.next();
    }
    if (lex.tp() != _Ident) {
      throw src::ParseError{lex.cur().loc, "free type identifier expected"};
    }
    auto loc = lex.cur().loc;
    SymDef* new_sym_def = sym::define_symbol(lex.cur().val, true, loc);
    if (new_sym_def->value) {
      lex.cur().error_at("redefined type variable `", "`");
    }
    auto var = TypeExpr::new_var(idx);
    new_sym_def->value = new SymValType{SymVal::_Typename, idx++, var};
    res.push_back(var);
    lex.next();
    if (lex.tp() != ',') {
      break;
    }
    lex.next();
  }
  lex.expect(_Mapsto);
  return res;
}

void type_var_usage(TypeExpr* expr, const std::vector<TypeExpr*>& typevars, std::vector<bool>& used) {
  if (expr->constr != TypeExpr::te_Var) {
    for (auto arg : expr->args) {
      type_var_usage(arg, typevars, used);
    }
    return;
  }
  for (std::size_t i = 0; i < typevars.size(); i++) {
    if (typevars[i] == expr) {
      used.at(i) = true;
      return;
    }
  }
  return;
}

TypeExpr* compute_type_closure(TypeExpr* expr, const std::vector<TypeExpr*>& typevars) {
  if (typevars.empty()) {
    return expr;
  }
  std::vector<bool> used(typevars.size(), false);
  type_var_usage(expr, typevars, used);
  std::vector<TypeExpr*> used_vars;
  for (std::size_t i = 0; i < typevars.size(); i++) {
    if (used.at(i)) {
      used_vars.push_back(typevars[i]);
    }
  }
  if (!used_vars.empty()) {
    expr = TypeExpr::new_forall(std::move(used_vars), expr);
  }
  return expr;
}

void parse_func_def(Lexer& lex) {
  SrcLocation loc{lex.cur().loc};
  sym::open_scope(lex);
  std::vector<TypeExpr*> type_vars;
  if (lex.tp() == _Forall) {
    type_vars = parse_type_var_list(lex);
  }
  auto ret_type = parse_type(lex);
  if (lex.tp() != _Ident) {
    throw src::ParseError{lex.cur().loc, "function name identifier expected"};
  }
  Lexem func_name = lex.cur();
  lex.next();
  FormalArgList arg_list = parse_formal_args(lex);
  bool impure = (lex.tp() == _Impure);
  if (impure) {
    lex.next();
  }
  int f = 0;
  if (lex.tp() == _Inline || lex.tp() == _InlineRef) {
    f = (lex.tp() == _Inline) ? 1 : 2;
    lex.next();
  }
  td::RefInt256 method_id;
  std::string method_name;
  if (lex.tp() == _MethodId) {
    lex.next();
    if (lex.tp() == '(') {
      lex.expect('(');
      if (lex.tp() == Lexem::String) {
        method_name = lex.cur().str;
      } else if (lex.tp() == Lexem::Number) {
        method_name = lex.cur().str;
        method_id = td::string_to_int256(method_name);
        if (method_id.is_null()) {
          lex.cur().error_at("invalid integer constant `", "`");
        }
      } else {
        throw src::ParseError{lex.cur().loc, "integer or string method identifier expected"};
      }
      lex.next();
      lex.expect(')');
    } else {
      method_name = func_name.str;
    }
    if (method_id.is_null()) {
      unsigned crc = td::crc16(method_name);
      method_id = td::make_refint((crc & 0xffff) | 0x10000);
    }
  }
  if (lex.tp() != ';' && lex.tp() != '{' && lex.tp() != _Asm) {
    lex.expect('{', "function body block expected");
  }
  TypeExpr* func_type = TypeExpr::new_map(extract_total_arg_type(arg_list), ret_type);
  func_type = compute_type_closure(func_type, type_vars);
  if (verbosity >= 1) {
    std::cerr << "function " << func_name.str << " : " << func_type << std::endl;
  }
  SymDef* func_sym = sym::define_global_symbol(func_name.val, 0, loc);
  assert(func_sym);
  SymValFunc* func_sym_val = dynamic_cast<SymValFunc*>(func_sym->value);
  if (func_sym->value) {
    if (func_sym->value->type != SymVal::_Func || !func_sym_val) {
      lex.cur().error("was not defined as a function before");
    }
    try {
      unify(func_sym_val->sym_type, func_type);
    } catch (UnifyError& ue) {
      std::ostringstream os;
      os << "previous type of function " << func_name.str << " : " << func_sym_val->sym_type
         << " cannot be unified with new type " << func_type << ": " << ue;
      lex.cur().error(os.str());
    }
  }
  if (lex.tp() == ';') {
    make_new_glob_func(func_sym, func_type, impure);
    lex.next();
  } else if (lex.tp() == '{') {
    if (dynamic_cast<SymValAsmFunc*>(func_sym_val)) {
      lex.cur().error("function `"s + func_name.str + "` has been already defined as an assembler built-in");
    }
    SymValCodeFunc* func_sym_code;
    if (func_sym_val) {
      func_sym_code = dynamic_cast<SymValCodeFunc*>(func_sym_val);
      if (!func_sym_code) {
        lex.cur().error("function `"s + func_name.str + "` has been already defined in an yet-unknown way");
      }
    } else {
      func_sym_code = make_new_glob_func(func_sym, func_type, impure);
    }
    if (func_sym_code->code) {
      lex.cur().error("redefinition of function `"s + func_name.str + "`");
    }
    CodeBlob* code = parse_func_body(lex, arg_list, ret_type);
    code->name = func_name.str;
    code->loc = loc;
    // code->print(std::cerr);  // !!!DEBUG!!!
    func_sym_code->code = code;
  } else {
    if (func_sym_val) {
      if (dynamic_cast<SymValCodeFunc*>(func_sym_val)) {
        lex.cur().error("function `"s + func_name.str + "` was already declared as an ordinary function");
      }
      if (dynamic_cast<SymValAsmFunc*>(func_sym_val)) {
        lex.cur().error("redefinition of built-in assembler function `"s + func_name.str + "`");
      }
      lex.cur().error("redefinition of previously (somehow) defined function `"s + func_name.str + "`");
    }
    func_sym->value = parse_asm_func_body(lex, func_type, arg_list, ret_type, impure);
  }
  if (method_id.not_null()) {
    auto val = dynamic_cast<SymVal*>(func_sym->value);
    if (!val) {
      lex.cur().error("cannot set method id for unknown function `"s + func_name.str + "`");
    }
    if (val->method_id.is_null()) {
      val->method_id = std::move(method_id);
    } else if (td::cmp(val->method_id, method_id) != 0) {
      lex.cur().error("integer method identifier for `"s + func_name.str + "` changed from " +
                      val->method_id->to_dec_string() + " to a different value " + method_id->to_dec_string());
    }
  }
  if (f) {
    auto val = dynamic_cast<SymVal*>(func_sym->value);
    if (!val) {
      lex.cur().error("cannot set unknown function `"s + func_name.str + "` as an inline");
    }
    if (!(val->flags & 3)) {
      val->flags = (short)(val->flags | f);
    } else if ((val->flags & 3) != f) {
      lex.cur().error("inline mode for `"s + func_name.str + "` changed with respect to a previous declaration");
    }
  }
  if (verbosity >= 1) {
    std::cerr << "new type of function " << func_name.str << " : " << func_type << std::endl;
  }
  sym::close_scope(lex);
}

std::vector<const src::FileDescr*> source_fdescr;

bool parse_source(std::istream* is, src::FileDescr* fdescr) {
  src::SourceReader reader{is, fdescr};
  Lexer lex{reader, true, ";,()[] ~."};
  while (lex.tp() != _Eof) {
    if (lex.tp() == _Global) {
      parse_global_var_decls(lex);
    } else {
      parse_func_def(lex);
    }
  }
  return true;
}

bool parse_source_file(const char* filename) {
  if (!filename || !*filename) {
    throw src::Fatal{"source file name is an empty string"};
  }
  src::FileDescr* cur_source = new src::FileDescr{filename};
  source_fdescr.push_back(cur_source);
  std::ifstream ifs{filename};
  if (ifs.fail()) {
    throw src::Fatal{std::string{"cannot open source file `"} + filename + "`"};
  }
  return parse_source(&ifs, cur_source);
}

bool parse_source_stdin() {
  src::FileDescr* cur_source = new src::FileDescr{"stdin", true};
  source_fdescr.push_back(cur_source);
  return parse_source(&std::cin, cur_source);
}

}  // namespace funC
