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
#pragma once
#include <vector>
#include <string>
#include <stack>
#include <utility>
#include <algorithm>
#include <iostream>
#include <functional>
#include "common/refcnt.hpp"
#include "common/bigint.hpp"
#include "common/refint.h"
#include "parser/srcread.h"
#include "parser/lexer.h"
#include "parser/symtable.h"

namespace funC {

extern int verbosity;
extern bool op_rewrite_comments;

constexpr int optimize_depth = 12;

enum Keyword {
  _Eof = -1,
  _Ident = 0,
  _Number,
  _Special,
  _String,
  _Return = 0x80,
  _Var,
  _Repeat,
  _Do,
  _While,
  _Until,
  _If,
  _Ifnot,
  _Then,
  _Else,
  _Elseif,
  _Elseifnot,
  _Eq,
  _Neq,
  _Leq,
  _Geq,
  _Spaceship,
  _Lshift,
  _Rshift,
  _RshiftR,
  _RshiftC,
  _DivR,
  _DivC,
  _DivMod,
  _PlusLet,
  _MinusLet,
  _TimesLet,
  _DivLet,
  _DivRLet,
  _DivCLet,
  _ModLet,
  _LshiftLet,
  _RshiftLet,
  _RshiftRLet,
  _RshiftCLet,
  _Int,
  _Cell,
  _Slice,
  _Builder,
  _Cont,
  _Tuple,
  _Type,
  _Mapsto,
  _Asm,
  _Impure,
  _Extern,
  _MethodId,
  _Operator,
  _Infix,
  _Infixl,
  _Infixr
};

void define_keywords();

class IdSc {
  int cls;

 public:
  enum { undef = 0, dotid = 1, tildeid = 2 };
  IdSc(int _cls = undef) : cls(_cls) {
  }
  operator int() {
    return cls;
  }
};

// symbol subclass:
// 1 = begins with . (a const method)
// 2 = begins with ~ (a non-const method)
// 0 = else

/*
 * 
 *   TYPE EXPRESSIONS
 * 
 */

struct TypeExpr {
  enum te_type { te_Unknown, te_Indirect, te_Atomic, te_Tensor, te_Map, te_Type, te_ForAll } constr;
  enum {
    _Int = Keyword::_Int,
    _Cell = Keyword::_Cell,
    _Slice = Keyword::_Slice,
    _Builder = Keyword::_Builder,
    _Cont = Keyword::_Cont,
    _Tuple = Keyword::_Tuple,
    _Type = Keyword::_Type
  };
  int value;
  int minw, maxw;
  static constexpr int w_inf = 1023;
  std::vector<TypeExpr*> args;
  TypeExpr(te_type _constr, int _val = 0) : constr(_constr), value(_val), minw(0), maxw(w_inf) {
  }
  TypeExpr(te_type _constr, int _val, int width) : constr(_constr), value(_val), minw(width), maxw(width) {
  }
  TypeExpr(te_type _constr, std::vector<TypeExpr*> list)
      : constr(_constr), value((int)list.size()), args(std::move(list)) {
    compute_width();
  }
  TypeExpr(te_type _constr, std::initializer_list<TypeExpr*> list)
      : constr(_constr), value((int)list.size()), args(std::move(list)) {
    compute_width();
  }
  TypeExpr(te_type _constr, TypeExpr* elem0, std::vector<TypeExpr*> list)
      : constr(_constr), value((int)list.size() + 1), args{elem0} {
    args.insert(args.end(), list.begin(), list.end());
    compute_width();
  }
  TypeExpr(te_type _constr, TypeExpr* elem0, std::initializer_list<TypeExpr*> list)
      : constr(_constr), value((int)list.size() + 1), args{elem0} {
    args.insert(args.end(), list.begin(), list.end());
    compute_width();
  }
  bool is_atomic() const {
    return constr == te_Atomic;
  }
  bool is_atomic(int v) const {
    return constr == te_Atomic && value == v;
  }
  bool is_int() const {
    return is_atomic(_Int);
  }
  bool has_fixed_width() const {
    return minw == maxw;
  }
  int get_width() const {
    return has_fixed_width() ? minw : -1;
  }
  void compute_width();
  bool recompute_width();
  void show_width(std::ostream& os);
  std::ostream& print(std::ostream& os, int prio = 0);
  void replace_with(TypeExpr* te2);
  int extract_components(std::vector<TypeExpr*>& comp_list);
  static int holes, type_vars;
  static TypeExpr* new_hole() {
    return new TypeExpr{te_Unknown, ++holes};
  }
  static TypeExpr* new_hole(int width) {
    return new TypeExpr{te_Unknown, ++holes, width};
  }
  static TypeExpr* new_unit() {
    return new TypeExpr{te_Tensor, 0, 0};
  }
  static TypeExpr* new_atomic(int value) {
    return new TypeExpr{te_Atomic, value, 1};
  }
  static TypeExpr* new_map(TypeExpr* from, TypeExpr* to);
  static TypeExpr* new_func() {
    return new_map(new_hole(), new_hole());
  }
  static TypeExpr* new_tensor(std::vector<TypeExpr*> list, bool red = true) {
    return red && list.size() == 1 ? list[0] : new TypeExpr{te_Tensor, std::move(list)};
  }
  static TypeExpr* new_tensor(std::initializer_list<TypeExpr*> list) {
    return new TypeExpr{te_Tensor, std::move(list)};
  }
  static TypeExpr* new_tensor(TypeExpr* te1, TypeExpr* te2) {
    return new_tensor({te1, te2});
  }
  static TypeExpr* new_tensor(TypeExpr* te1, TypeExpr* te2, TypeExpr* te3) {
    return new_tensor({te1, te2, te3});
  }
  static TypeExpr* new_var() {
    return new TypeExpr{te_Unknown, --type_vars, 1};
  }
  static TypeExpr* new_forall(std::vector<TypeExpr*> list, TypeExpr* body) {
    return new TypeExpr{te_ForAll, body, std::move(list)};
  }
  static TypeExpr* new_forall(std::initializer_list<TypeExpr*> list, TypeExpr* body) {
    return new TypeExpr{te_ForAll, body, std::move(list)};
  }
  static bool remove_indirect(TypeExpr*& te, TypeExpr* forbidden = nullptr);
  static bool remove_forall(TypeExpr*& te);
  static bool remove_forall_in(TypeExpr*& te, TypeExpr* te2, const std::vector<TypeExpr*>& new_vars);
};

std::ostream& operator<<(std::ostream& os, TypeExpr* type_expr);

struct UnifyError {
  TypeExpr* te1;
  TypeExpr* te2;
  std::string msg;
  UnifyError(TypeExpr* _te1, TypeExpr* _te2, std::string _msg = "") : te1(_te1), te2(_te2), msg(_msg) {
  }
  void print_message(std::ostream& os) const;
  std::string message() const;
};

std::ostream& operator<<(std::ostream& os, const UnifyError& ue);

void unify(TypeExpr*& te1, TypeExpr*& te2);

// extern int TypeExpr::holes;

/*
 * 
 *   ABSTRACT CODE
 * 
 */

using src::Lexem;
using src::SrcLocation;
using sym::SymDef;
using sym::sym_idx_t;
using sym::var_idx_t;
using const_idx_t = int;

struct TmpVar {
  TypeExpr* v_type;
  var_idx_t idx;
  enum { _In = 1, _Named = 2, _Tmp = 4, _UniqueName = 0x20 };
  int cls;
  sym_idx_t name;
  int coord;
  std::unique_ptr<SrcLocation> where;
  TmpVar(var_idx_t _idx, int _cls, TypeExpr* _type = 0, SymDef* sym = 0, const SrcLocation* loc = 0);
  void show(std::ostream& os, int omit_idx = 0) const;
  void dump(std::ostream& os) const;
  void set_location(const SrcLocation& loc);
};

struct VarDescr {
  var_idx_t idx;
  enum { _Last = 1, _Unused = 2 };
  int flags;
  enum {
    _Const = 16,
    _Int = 32,
    _Zero = 64,
    _NonZero = 128,
    _Pos = 256,
    _Neg = 512,
    _Bool = 1024,
    _Bit = 2048,
    _Finite = 4096,
    _Nan = 8192,
    _Even = 16384,
    _Odd = 32768,
    _Null = (1 << 16),
    _NotNull = (1 << 17)
  };
  static constexpr int ConstZero = _Int | _Zero | _Pos | _Neg | _Bool | _Bit | _Finite | _Even | _NotNull;
  static constexpr int ConstOne = _Int | _NonZero | _Pos | _Bit | _Finite | _Odd | _NotNull;
  static constexpr int ConstTrue = _Int | _NonZero | _Neg | _Bool | _Finite | _Odd | _NotNull;
  static constexpr int ValBit = ConstZero & ConstOne;
  static constexpr int ValBool = ConstZero & ConstTrue;
  static constexpr int FiniteInt = _Int | _Finite | _NotNull;
  static constexpr int FiniteUInt = FiniteInt | _Pos;
  int val;
  td::RefInt256 int_const;
  VarDescr(var_idx_t _idx = -1, int _flags = 0, int _val = 0) : idx(_idx), flags(_flags), val(_val) {
  }
  bool operator<(var_idx_t other_idx) const {
    return idx < other_idx;
  }
  bool is_unused() const {
    return flags & _Unused;
  }
  bool is_last() const {
    return flags & _Last;
  }
  bool always_true() const {
    return val & _NonZero;
  }
  bool always_false() const {
    return val & _Zero;
  }
  bool always_nonzero() const {
    return val & _NonZero;
  }
  bool always_zero() const {
    return val & _Zero;
  }
  bool always_even() const {
    return val & _Even;
  }
  bool always_odd() const {
    return val & _Odd;
  }
  bool always_null() const {
    return val & _Null;
  }
  bool always_not_null() const {
    return val & _NotNull;
  }
  bool is_const() const {
    return val & _Const;
  }
  bool is_int_const() const {
    return (val & (_Int | _Const)) == (_Int | _Const);
  }
  bool always_nonpos() const {
    return val & _Neg;
  }
  bool always_nonneg() const {
    return val & _Pos;
  }
  bool always_pos() const {
    return (val & (_Pos | _NonZero)) == (_Pos | _NonZero);
  }
  bool always_neg() const {
    return (val & (_Neg | _NonZero)) == (_Neg | _NonZero);
  }
  bool always_finite() const {
    return val & _Finite;
  }
  bool always_less(const VarDescr& other) const;
  bool always_leq(const VarDescr& other) const;
  bool always_greater(const VarDescr& other) const;
  bool always_geq(const VarDescr& other) const;
  bool always_equal(const VarDescr& other) const;
  bool always_neq(const VarDescr& other) const;
  void unused() {
    flags |= _Unused;
  }
  void clear_unused() {
    flags &= ~_Unused;
  }
  void set_const(long long value);
  void set_const(td::RefInt256 value);
  void set_const_nan();
  void operator+=(const VarDescr& y) {
    flags &= y.flags;
  }
  void operator|=(const VarDescr& y);
  void operator&=(const VarDescr& y);
  void set_value(const VarDescr& y);
  void set_value(VarDescr&& y);
  void set_value(const VarDescr* y) {
    if (y) {
      set_value(*y);
    }
  }
  void clear_value();
  void show_value(std::ostream& os) const;
  void show(std::ostream& os, const char* var_name = nullptr) const;
};

inline std::ostream& operator<<(std::ostream& os, const VarDescr& vd) {
  vd.show(os);
  return os;
}

struct VarDescrList {
  std::vector<VarDescr> list;
  VarDescrList() : list() {
  }
  VarDescrList(const std::vector<VarDescr>& _list) : list(_list) {
  }
  VarDescrList(std::vector<VarDescr>&& _list) : list(std::move(_list)) {
  }
  std::size_t size() const {
    return list.size();
  }
  VarDescr* operator[](var_idx_t idx);
  const VarDescr* operator[](var_idx_t idx) const;
  VarDescrList operator+(const VarDescrList& y) const;
  VarDescrList& operator+=(const VarDescrList& y);
  VarDescrList& clear_last();
  VarDescrList& operator+=(var_idx_t idx) {
    return add_var(idx);
  }
  VarDescrList& operator+=(const std::vector<var_idx_t>& idx_list) {
    return add_vars(idx_list);
  }
  VarDescrList& add_var(var_idx_t idx, bool unused = false);
  VarDescrList& add_vars(const std::vector<var_idx_t>& idx_list, bool unused = false);
  VarDescrList& operator-=(const std::vector<var_idx_t>& idx_list);
  VarDescrList& operator-=(var_idx_t idx);
  std::size_t count(const std::vector<var_idx_t> idx_list) const;
  std::size_t count_used(const std::vector<var_idx_t> idx_list) const;
  VarDescr& add(var_idx_t idx);
  VarDescr& add_newval(var_idx_t idx);
  VarDescrList& operator&=(const VarDescrList& values);
  VarDescrList& import_values(const VarDescrList& values);
  VarDescrList operator|(const VarDescrList& y) const;
  VarDescrList& operator|=(const VarDescrList& values);
  void show(std::ostream& os) const;
};

inline std::ostream& operator<<(std::ostream& os, const VarDescrList& values) {
  values.show(os);
  return os;
}

struct CodeBlob;

template <typename T>
class ListIterator {
  T* ptr;

 public:
  ListIterator() : ptr(nullptr) {
  }
  ListIterator(T* _ptr) : ptr(_ptr) {
  }
  ListIterator& operator++() {
    ptr = ptr->next.get();
    return *this;
  }
  ListIterator& operator++(int) {
    T* z = ptr;
    ptr = ptr->next.get();
    return ListIterator{z};
  }
  T& operator*() const {
    return *ptr;
  }
  T* operator->() const {
    return ptr;
  }
  bool operator==(const ListIterator& y) const {
    return ptr == y.ptr;
  }
  bool operator!=(const ListIterator& y) const {
    return ptr != y.ptr;
  }
};

struct Stack;

struct Op {
  enum {
    _Undef,
    _Nop,
    _Call,
    _CallInd,
    _Let,
    _IntConst,
    _GlobVar,
    _Import,
    _Return,
    _If,
    _While,
    _Until,
    _Repeat,
    _Again
  };
  int cl;
  enum { _Disabled = 1, _Reachable = 2, _NoReturn = 4, _ImpureR = 8, _ImpureW = 16, _Impure = 24 };
  int flags;
  std::unique_ptr<Op> next;
  SymDef* fun_ref;
  SrcLocation where;
  VarDescrList var_info;
  std::vector<VarDescr> args;
  std::vector<var_idx_t> left, right;
  std::unique_ptr<Op> block0, block1;
  td::RefInt256 int_const;
  Op(const SrcLocation& _where = {}, int _cl = _Undef) : cl(_cl), flags(0), fun_ref(nullptr), where(_where) {
  }
  Op(const SrcLocation& _where, int _cl, const std::vector<var_idx_t>& _left)
      : cl(_cl), flags(0), fun_ref(nullptr), where(_where), left(_left) {
  }
  Op(const SrcLocation& _where, int _cl, std::vector<var_idx_t>&& _left)
      : cl(_cl), flags(0), fun_ref(nullptr), where(_where), left(std::move(_left)) {
  }
  Op(const SrcLocation& _where, int _cl, const std::vector<var_idx_t>& _left, td::RefInt256 _const)
      : cl(_cl), flags(0), fun_ref(nullptr), where(_where), left(_left), int_const(_const) {
  }
  Op(const SrcLocation& _where, int _cl, const std::vector<var_idx_t>& _left, const std::vector<var_idx_t>& _right,
     SymDef* _fun = nullptr)
      : cl(_cl), flags(0), fun_ref(_fun), where(_where), left(_left), right(_right) {
  }
  Op(const SrcLocation& _where, int _cl, std::vector<var_idx_t>&& _left, std::vector<var_idx_t>&& _right,
     SymDef* _fun = nullptr)
      : cl(_cl), flags(0), fun_ref(_fun), where(_where), left(std::move(_left)), right(std::move(_right)) {
  }
  bool disabled() const {
    return flags & _Disabled;
  }
  bool enabled() const {
    return !disabled();
  }
  void disable() {
    flags |= _Disabled;
  }
  bool unreachable() {
    return !(flags & _Reachable);
  }
  void flags_set_clear(int set, int clear);
  void show(std::ostream& os, const std::vector<TmpVar>& vars, std::string pfx = "", int mode = 0) const;
  void show_var_list(std::ostream& os, const std::vector<var_idx_t>& idx_list, const std::vector<TmpVar>& vars) const;
  void show_var_list(std::ostream& os, const std::vector<VarDescr>& list, const std::vector<TmpVar>& vars) const;
  static void show_block(std::ostream& os, const Op* block, const std::vector<TmpVar>& vars, std::string pfx = "",
                         int mode = 0);
  void split_vars(const std::vector<TmpVar>& vars);
  static void split_var_list(std::vector<var_idx_t>& var_list, const std::vector<TmpVar>& vars);
  bool compute_used_vars(const CodeBlob& code, bool edit);
  bool std_compute_used_vars(bool disabled = false);
  bool set_var_info(const VarDescrList& new_var_info);
  bool set_var_info(VarDescrList&& new_var_info);
  bool set_var_info_except(const VarDescrList& new_var_info, const std::vector<var_idx_t>& var_list);
  bool set_var_info_except(VarDescrList&& new_var_info, const std::vector<var_idx_t>& var_list);
  void prepare_args(VarDescrList values);
  VarDescrList fwd_analyze(VarDescrList values);
  bool set_noreturn(bool nr);
  bool mark_noreturn();
  bool noreturn() const {
    return flags & _NoReturn;
  }
  bool is_empty() const {
    return cl == _Nop && !next;
  }
  bool is_pure() const {
    return !(flags & _Impure);
  }
  bool generate_code_step(Stack& stack);
  bool generate_code_all(Stack& stack);
  Op& last() {
    return next ? next->last() : *this;
  }
  const Op& last() const {
    return next ? next->last() : *this;
  }
  ListIterator<Op> begin() {
    return ListIterator<Op>{this};
  }
  ListIterator<Op> end() const {
    return ListIterator<Op>{};
  }
  ListIterator<const Op> cbegin() {
    return ListIterator<const Op>{this};
  }
  ListIterator<const Op> cend() const {
    return ListIterator<const Op>{};
  }
};

inline ListIterator<Op> begin(const std::unique_ptr<Op>& op_list) {
  return ListIterator<Op>{op_list.get()};
}

inline ListIterator<Op> end(const std::unique_ptr<Op>& op_list) {
  return ListIterator<Op>{};
}

inline ListIterator<const Op> cbegin(const Op* op_list) {
  return ListIterator<const Op>{op_list};
}

inline ListIterator<const Op> cend(const Op* op_list) {
  return ListIterator<const Op>{};
}

inline ListIterator<const Op> begin(const Op* op_list) {
  return ListIterator<const Op>{op_list};
}

inline ListIterator<const Op> end(const Op* op_list) {
  return ListIterator<const Op>{};
}

inline ListIterator<Op> begin(Op* op_list) {
  return ListIterator<Op>{op_list};
}

inline ListIterator<Op> end(Op* op_list) {
  return ListIterator<Op>{};
}

typedef std::tuple<TypeExpr*, SymDef*, SrcLocation> FormalArg;
typedef std::vector<FormalArg> FormalArgList;

struct AsmOpList;

struct CodeBlob {
  int var_cnt, in_var_cnt, op_cnt;
  TypeExpr* ret_type;
  std::string name;
  SrcLocation loc;
  std::vector<TmpVar> vars;
  std::unique_ptr<Op> ops;
  std::unique_ptr<Op>* cur_ops;
  std::stack<std::unique_ptr<Op>*> cur_ops_stack;
  CodeBlob(TypeExpr* ret = nullptr) : var_cnt(0), in_var_cnt(0), op_cnt(0), ret_type(ret), cur_ops(&ops) {
  }
  template <typename... Args>
  Op& emplace_back(const Args&... args) {
    Op& res = *(*cur_ops = std::make_unique<Op>(args...));
    cur_ops = &(res.next);
    return res;
  }
  bool import_params(FormalArgList arg_list);
  var_idx_t create_var(int cls, TypeExpr* var_type = 0, SymDef* sym = 0, const SrcLocation* loc = 0);
  int split_vars(bool strict = false);
  bool compute_used_code_vars();
  bool compute_used_code_vars(std::unique_ptr<Op>& ops, const VarDescrList& var_info, bool edit) const;
  void print(std::ostream& os, int flags = 0) const;
  void push_set_cur(std::unique_ptr<Op>& new_cur_ops) {
    cur_ops_stack.push(cur_ops);
    cur_ops = &new_cur_ops;
  }
  void close_blk(const SrcLocation& location) {
    *cur_ops = std::make_unique<Op>(location, Op::_Nop);
  }
  void pop_cur() {
    cur_ops = cur_ops_stack.top();
    cur_ops_stack.pop();
  }
  void close_pop_cur(const SrcLocation& location) {
    close_blk(location);
    pop_cur();
  }
  void simplify_var_types();
  void flags_set_clear(int set, int clear);
  void prune_unreachable_code();
  void fwd_analyze();
  void mark_noreturn();
  void generate_code(AsmOpList& out_list, int mode = 0);
  void generate_code(std::ostream& os, int mode = 0, int indent = 0);
};

/*
 *
 *   SYMBOL VALUES
 * 
 */

struct SymVal : sym::SymValBase {
  TypeExpr* sym_type;
  td::RefInt256 method_id;
  bool impure;
  SymVal(int _type, int _idx, TypeExpr* _stype = nullptr, bool _impure = false)
      : sym::SymValBase(_type, _idx), sym_type(_stype), impure(_impure) {
  }
  ~SymVal() override = default;
  TypeExpr* get_type() const {
    return sym_type;
  }
  virtual const std::vector<int>* get_arg_order() const {
    return nullptr;
  }
  virtual const std::vector<int>* get_ret_order() const {
    return nullptr;
  }
};

struct SymValFunc : SymVal {
  std::vector<int> arg_order, ret_order;
  ~SymValFunc() override = default;
  SymValFunc(int val, TypeExpr* _ft, bool _impure = false) : SymVal(_Func, val, _ft, _impure) {
  }
  SymValFunc(int val, TypeExpr* _ft, std::initializer_list<int> _arg_order, std::initializer_list<int> _ret_order = {},
             bool _impure = false)
      : SymVal(_Func, val, _ft, _impure), arg_order(_arg_order), ret_order(_ret_order) {
  }

  const std::vector<int>* get_arg_order() const override {
    return arg_order.empty() ? nullptr : &arg_order;
  }
  const std::vector<int>* get_ret_order() const override {
    return ret_order.empty() ? nullptr : &ret_order;
  }
};

struct SymValCodeFunc : SymValFunc {
  CodeBlob* code;
  ~SymValCodeFunc() override = default;
  SymValCodeFunc(int val, TypeExpr* _ft, bool _impure = false) : SymValFunc(val, _ft, _impure), code(nullptr) {
  }
};

extern int glob_func_cnt, undef_func_cnt;
extern std::vector<SymDef*> glob_func;

/*
 * 
 *   PARSE SOURCE
 * 
 */

// defined in parse-func.cpp
bool parse_source(std::istream* is, const src::FileDescr* fdescr);
bool parse_source_file(const char* filename);
bool parse_source_stdin();

/*
 * 
 *   EXPRESSIONS
 * 
 */

struct Expr {
  enum {
    _None,
    _Apply,
    _VarApply,
    _TypeApply,
    _Tuple,
    _Const,
    _Var,
    _Glob,
    _Letop,
    _LetFirst,
    _Hole,
    _Type,
    _CondExpr
  };
  int cls;
  int val{0};
  enum { _IsType = 1, _IsRvalue = 2, _IsLvalue = 4, _IsHole = 8, _IsNewVar = 16, _IsImpure = 32 };
  int flags{0};
  SrcLocation here;
  td::RefInt256 intval;
  SymDef* sym{nullptr};
  TypeExpr* e_type{nullptr};
  std::vector<Expr*> args;
  Expr(int c = _None) : cls(c) {
  }
  Expr(int c, const SrcLocation& loc) : cls(c), here(loc) {
  }
  Expr(int c, std::vector<Expr*> _args) : cls(c), args(std::move(_args)) {
  }
  Expr(int c, std::initializer_list<Expr*> _arglist) : cls(c), args(std::move(_arglist)) {
  }
  Expr(int c, SymDef* _sym, std::initializer_list<Expr*> _arglist) : cls(c), sym(_sym), args(std::move(_arglist)) {
  }
  Expr(int c, SymDef* _sym, std::vector<Expr*> _arglist) : cls(c), sym(_sym), args(std::move(_arglist)) {
  }
  Expr(int c, sym_idx_t name_idx, std::initializer_list<Expr*> _arglist);
  ~Expr() {
    for (auto& arg_ptr : args) {
      delete arg_ptr;
    }
  }
  Expr* copy() const;
  void pb_arg(Expr* expr) {
    args.push_back(expr);
  }
  void set_val(int _val) {
    val = _val;
  }
  bool is_rvalue() const {
    return flags & _IsRvalue;
  }
  bool is_lvalue() const {
    return flags & _IsLvalue;
  }
  bool is_type() const {
    return flags & _IsType;
  }
  void chk_rvalue(const Lexem& lem) const;
  void chk_lvalue(const Lexem& lem) const;
  void chk_type(const Lexem& lem) const;
  bool deduce_type(const Lexem& lem);
  void set_location(const SrcLocation& loc) {
    here = loc;
  }
  const SrcLocation& get_location() const {
    return here;
  }
  int define_new_vars(CodeBlob& code);
  int predefine_vars();
  std::vector<var_idx_t> pre_compile(CodeBlob& code) const;
};

/*
 * 
 *   GENERATE CODE
 * 
 */

typedef std::vector<var_idx_t> StackLayout;
typedef std::pair<var_idx_t, const_idx_t> var_const_idx_t;
typedef std::vector<var_const_idx_t> StackLayoutExt;
constexpr const_idx_t not_const = -1;
using Const = td::RefInt256;

struct AsmOp {
  enum Type { a_none, a_xchg, a_push, a_pop, a_const, a_custom, a_magic };
  int t{a_none};
  int indent{0};
  int a, b, c;
  std::string op;
  struct SReg {
    int idx;
    SReg(int _idx) : idx(_idx) {
    }
  };
  AsmOp() = default;
  AsmOp(int _t) : t(_t) {
  }
  AsmOp(int _t, std::string _op) : t(_t), op(std::move(_op)) {
  }
  AsmOp(int _t, int _a) : t(_t), a(_a) {
  }
  AsmOp(int _t, int _a, std::string _op) : t(_t), a(_a), op(std::move(_op)) {
  }
  AsmOp(int _t, int _a, int _b) : t(_t), a(_a), b(_b) {
  }
  AsmOp(int _t, int _a, int _b, std::string _op) : t(_t), a(_a), b(_b), op(std::move(_op)) {
  }
  AsmOp(int _t, int _a, int _b, int _c) : t(_t), a(_a), b(_b), c(_c) {
  }
  AsmOp(int _t, int _a, int _b, int _c, std::string _op) : t(_t), a(_a), b(_b), c(_c), op(std::move(_op)) {
  }
  void out(std::ostream& os) const;
  void out_indent_nl(std::ostream& os, bool no_nl = false) const;
  std::string to_string() const;
  bool is_nop() const {
    return t == a_none && op.empty();
  }
  bool is_comment() const {
    return t == a_none && !op.empty();
  }
  bool is_custom() const {
    return t == a_custom;
  }
  bool is_very_custom() const {
    return is_custom() && a >= 255;
  }
  bool is_push() const {
    return t == a_push;
  }
  bool is_push(int x) const {
    return is_push() && a == x;
  }
  bool is_push(int* x) const {
    *x = a;
    return is_push();
  }
  bool is_pop() const {
    return t == a_pop;
  }
  bool is_pop(int x) const {
    return is_pop() && a == x;
  }
  bool is_xchg() const {
    return t == a_xchg;
  }
  bool is_xchg(int x, int y) const {
    return is_xchg() && b == y && a == x;
  }
  bool is_xchg(int* x, int* y) const {
    *x = a;
    *y = b;
    return is_xchg();
  }
  bool is_swap() const {
    return is_xchg(0, 1);
  }
  bool is_const() const {
    return t == a_const && !a && b == 1;
  }
  bool is_gconst() const {
    return (t == a_const || t == a_custom) && !a && b == 1;
  }
  static AsmOp Nop() {
    return AsmOp(a_none);
  }
  static AsmOp Xchg(int a, int b = 0) {
    return a == b ? AsmOp(a_none) : (a < b ? AsmOp(a_xchg, a, b) : AsmOp(a_xchg, b, a));
  }
  static AsmOp Push(int a) {
    return AsmOp(a_push, a);
  }
  static AsmOp Pop(int a = 0) {
    return AsmOp(a_pop, a);
  }
  static AsmOp Xchg2(int a, int b) {
    return make_stk2(a, b, "XCHG2", 0);
  }
  static AsmOp XcPu(int a, int b) {
    return make_stk2(a, b, "XCPU", 1);
  }
  static AsmOp PuXc(int a, int b) {
    return make_stk2(a, b, "PUXC", 1);
  }
  static AsmOp Push2(int a, int b) {
    return make_stk2(a, b, "PUSH2", 2);
  }
  static AsmOp Xchg3(int a, int b, int c) {
    return make_stk3(a, b, c, "XCHG3", 0);
  }
  static AsmOp Xc2Pu(int a, int b, int c) {
    return make_stk3(a, b, c, "XC2PU", 1);
  }
  static AsmOp XcPuXc(int a, int b, int c) {
    return make_stk3(a, b, c, "XCPUXC", 1);
  }
  static AsmOp XcPu2(int a, int b, int c) {
    return make_stk3(a, b, c, "XCPU2", 3);
  }
  static AsmOp PuXc2(int a, int b, int c) {
    return make_stk3(a, b, c, "PUXC2", 3);
  }
  static AsmOp PuXcPu(int a, int b, int c) {
    return make_stk3(a, b, c, "PUXCPU", 3);
  }
  static AsmOp Pu2Xc(int a, int b, int c) {
    return make_stk3(a, b, c, "PU2XC", 3);
  }
  static AsmOp Push3(int a, int b, int c) {
    return make_stk3(a, b, c, "PUSH3", 3);
  }
  static AsmOp BlkSwap(int a, int b);
  static AsmOp BlkPush(int a, int b);
  static AsmOp BlkDrop(int a);
  static AsmOp BlkReverse(int a, int b);
  static AsmOp make_stk2(int a, int b, const char* str, int delta);
  static AsmOp make_stk3(int a, int b, int c, const char* str, int delta);
  static AsmOp IntConst(td::RefInt256 value);
  static AsmOp BoolConst(bool f);
  static AsmOp Const(std::string push_op) {
    return AsmOp(a_const, 0, 1, std::move(push_op));
  }
  static AsmOp Const(int arg, std::string push_op);
  static AsmOp Comment(std::string comment) {
    return AsmOp(a_none, std::string{"// "} + comment);
  }
  static AsmOp Custom(std::string custom_op) {
    return AsmOp(a_custom, 255, 255, custom_op);
  }
  static AsmOp Parse(std::string custom_op);
  static AsmOp Custom(std::string custom_op, int args, int retv = 1) {
    return AsmOp(a_custom, args, retv, custom_op);
  }
  static AsmOp Parse(std::string custom_op, int args, int retv = 1);
};

inline std::ostream& operator<<(std::ostream& os, const AsmOp& op) {
  op.out(os);
  return os;
}

std::ostream& operator<<(std::ostream& os, AsmOp::SReg stack_reg);

struct AsmOpList {
  std::vector<AsmOp> list_;
  int indent_{0};
  const std::vector<TmpVar>* var_names_{nullptr};
  std::vector<Const> constants_;
  void out(std::ostream& os, int mode = 0) const;
  AsmOpList(int indent = 0, const std::vector<TmpVar>* var_names = nullptr) : indent_(indent), var_names_(var_names) {
  }
  template <typename... Args>
  AsmOpList& add(Args&&... args) {
    list_.emplace_back(std::forward<Args>(args)...);
    adjust_last();
    return *this;
  }
  bool append(const AsmOp& op) {
    list_.push_back(op);
    adjust_last();
    return true;
  }
  bool append(const std::vector<AsmOp>& ops);
  bool append(std::initializer_list<AsmOp> ops) {
    return append(std::vector<AsmOp>(std::move(ops)));
  }
  AsmOpList& operator<<(const AsmOp& op) {
    return add(op);
  }
  AsmOpList& operator<<(AsmOp&& op) {
    return add(std::move(op));
  }
  AsmOpList& operator<<(std::string str) {
    return add(AsmOp::Type::a_custom, 255, 255, str);
  }
  const_idx_t register_const(Const new_const);
  Const get_const(const_idx_t idx);
  void show_var(std::ostream& os, var_idx_t idx) const;
  void show_var_ext(std::ostream& os, std::pair<var_idx_t, const_idx_t> idx_pair) const;
  void adjust_last() {
    if (list_.back().is_nop()) {
      list_.pop_back();
    } else {
      list_.back().indent = indent_;
    }
  }
  void indent() {
    ++indent_;
  }
  void undent() {
    --indent_;
  }
  void set_indent(int new_indent) {
    indent_ = new_indent;
  }
};

inline std::ostream& operator<<(std::ostream& os, const AsmOpList& op_list) {
  op_list.out(os);
  return os;
}

class IndentGuard {
  AsmOpList& aol_;

 public:
  IndentGuard(AsmOpList& aol) : aol_(aol) {
    aol.indent();
  }
  ~IndentGuard() {
    aol_.undent();
  }
};

struct AsmOpCons {
  std::unique_ptr<AsmOp> car;
  std::unique_ptr<AsmOpCons> cdr;
  AsmOpCons(std::unique_ptr<AsmOp> head, std::unique_ptr<AsmOpCons> tail) : car(std::move(head)), cdr(std::move(tail)) {
  }
  static std::unique_ptr<AsmOpCons> cons(std::unique_ptr<AsmOp> head, std::unique_ptr<AsmOpCons> tail) {
    return std::make_unique<AsmOpCons>(std::move(head), std::move(tail));
  }
};

using AsmOpConsList = std::unique_ptr<AsmOpCons>;

int is_pos_pow2(td::RefInt256 x);
int is_neg_pow2(td::RefInt256 x);

/*
 * 
 *  STACK TRANSFORMS
 * 
 */

/*
A stack transform is a map f:N={0,1,...} -> N, such that f(x) = x + d_f for almost all x:N and for a fixed d_f:N.
They form a monoid under composition: (fg)(x)=f(g(x)).
They act on stacks S on the right: Sf=S', such that S'[n]=S[f(n)].

A stack transform f is determined by d_f and the finite set A of all pairs (x,y), such that x>=d_f, f(x-d_f) = y and y<>x. They are listed in increasing order by x.
*/
struct StackTransform {
  enum { max_n = 16, inf_x = 0x7fffffff, c_start = -1000 };
  int d{0}, n{0}, dp{0}, c{0};
  bool invalid{false};
  std::array<std::pair<short, short>, max_n> A;
  StackTransform() = default;
  // list of f(0),f(1),...,f(s); assumes next values are f(s)+1,f(s)+2,...
  StackTransform(std::initializer_list<int> list);
  StackTransform& operator=(std::initializer_list<int> list);
  bool assign(const StackTransform& other);
  static StackTransform id() {
    return {};
  }
  bool invalidate() {
    invalid = true;
    return false;
  }
  bool is_valid() const {
    return !invalid;
  }
  bool set_id() {
    d = n = dp = c = 0;
    invalid = false;
    return true;
  }
  bool shift(int offs) {  // post-composes with x -> x + offs
    d += offs;
    return offs <= 0 || remove_negative();
  }
  bool remove_negative();
  bool touch(int i) {
    dp = std::max(dp, i + d + 1);
    return true;
  }
  bool is_permutation() const;         // is f:N->N bijective ?
  bool is_trivial_after(int x) const;  // f(x') = x' + d for all x' >= x
  int preimage_count(int y) const;     // card f^{-1}(y)
  std::vector<int> preimage(int y) const;
  bool apply_xchg(int i, int j, bool relaxed = false);
  bool apply_push(int i);
  bool apply_pop(int i = 0);
  bool apply_push_newconst();
  bool apply(const StackTransform& other);     // this = this * other
  bool preapply(const StackTransform& other);  // this = other * this
  // c := a * b
  static bool compose(const StackTransform& a, const StackTransform& b, StackTransform& c);
  StackTransform& operator*=(const StackTransform& other);
  StackTransform operator*(const StackTransform& b) const &;
  bool equal(const StackTransform& other, bool relaxed = false) const;
  bool almost_equal(const StackTransform& other) const {
    return equal(other, true);
  }
  bool operator==(const StackTransform& other) const {
    return dp == other.dp && almost_equal(other);
  }
  bool operator<=(const StackTransform& other) const {
    return dp <= other.dp && almost_equal(other);
  }
  bool operator>=(const StackTransform& other) const {
    return dp >= other.dp && almost_equal(other);
  }
  int get(int i) const;
  int touch_get(int i, bool relaxed = false) {
    if (!relaxed) {
      touch(i);
    }
    return get(i);
  }
  bool set(int i, int v, bool relaxed = false);
  int operator()(int i) const {
    return get(i);
  }
  class Pos {
    StackTransform& t_;
    int p_;

   public:
    Pos(StackTransform& t, int p) : t_(t), p_(p) {
    }
    Pos& operator=(const Pos& other) = delete;
    operator int() const {
      return t_.get(p_);
    }
    const Pos& operator=(int v) const {
      t_.set(p_, v);
      return *this;
    }
  };
  Pos operator[](int i) {
    return Pos(*this, i);
  }
  static const StackTransform rot;
  static const StackTransform rot_rev;
  bool is_id() const {
    return is_valid() && !d && !n;
  }
  bool is_xchg(int i, int j) const;
  bool is_xchg(int* i, int* j) const;
  bool is_push(int i) const;
  bool is_push(int* i) const;
  bool is_pop(int i) const;
  bool is_pop(int* i) const;
  bool is_rot() const;
  bool is_rotrev() const;
  bool is_xchg2(int i, int j) const;
  bool is_xchg2(int* i, int* j) const;
  bool is_xcpu(int i, int j) const;
  bool is_xcpu(int* i, int* j) const;
  bool is_puxc(int i, int j) const;
  bool is_puxc(int* i, int* j) const;
  bool is_push2(int i, int j) const;
  bool is_push2(int* i, int* j) const;
  bool is_xchg3(int* i, int* j, int* k) const;
  bool is_xc2pu(int* i, int* j, int* k) const;
  bool is_xcpuxc(int* i, int* j, int* k) const;
  bool is_xcpu2(int* i, int* j, int* k) const;
  bool is_puxc2(int i, int j, int k) const;
  bool is_puxc2(int* i, int* j, int* k) const;
  bool is_puxcpu(int* i, int* j, int* k) const;
  bool is_pu2xc(int i, int j, int k) const;
  bool is_pu2xc(int* i, int* j, int* k) const;
  bool is_push3(int i, int j, int k) const;
  bool is_push3(int* i, int* j, int* k) const;
  bool is_blkswap(int i, int j) const;
  bool is_blkswap(int* i, int* j) const;
  bool is_blkpush(int i, int j) const;
  bool is_blkpush(int* i, int* j) const;
  bool is_blkdrop(int* i) const;
  bool is_reverse(int i, int j) const;
  bool is_reverse(int* i, int* j) const;
  bool is_nip_seq(int i, int j = 0) const;
  bool is_nip_seq(int* i) const;
  bool is_nip_seq(int* i, int* j) const;

  void show(std::ostream& os, int mode = 0) const;

  static StackTransform Xchg(int i, int j, bool relaxed = false);
  static StackTransform Push(int i);
  static StackTransform Pop(int i);

 private:
  int try_load(int& i, int offs = 0) const;  // returns A[i++].first + offs or inf_x
  bool try_store(int x, int y);              // appends (x,y) to A
};

//extern const StackTransform StackTransform::rot, StackTransform::rot_rev;

inline std::ostream& operator<<(std::ostream& os, const StackTransform& trans) {
  trans.show(os);
  return os;
}

bool apply_op(StackTransform& trans, const AsmOp& op);

/*
 * 
 *   STACK OPERATION OPTIMIZER
 * 
 */

struct Optimizer {
  enum { n = optimize_depth };
  AsmOpConsList code_;
  int l_{0}, l2_{0}, p_, pb_, q_, indent_;
  bool debug_{false};
  std::unique_ptr<AsmOp> op_[n], oq_[n];
  AsmOpCons* op_cons_[n];
  int offs_[n];
  StackTransform tr_[n];
  Optimizer() {
  }
  Optimizer(bool debug) : debug_(debug) {
  }
  Optimizer(AsmOpConsList code, bool debug = false) : Optimizer(debug) {
    set_code(std::move(code));
  }
  void set_code(AsmOpConsList code_);
  void unpack();
  void pack();
  void apply();
  bool find_at_least(int pb);
  bool find();
  bool optimize();
  bool compute_stack_transforms();
  bool say(std::string str) const;
  bool show_stack_transforms() const;
  void show_head() const;
  void show_left() const;
  void show_right() const;
  bool is_const_push_swap() const;
  bool rewrite_const_push_swap();
  bool is_const_push_xchgs();
  bool rewrite_const_push_xchgs();
  bool simple_rewrite(int p, AsmOp&& new_op);
  bool simple_rewrite(int p, AsmOp&& new_op1, AsmOp&& new_op2);
  bool simple_rewrite(AsmOp&& new_op) {
    return simple_rewrite(p_, std::move(new_op));
  }
  bool simple_rewrite(AsmOp&& new_op1, AsmOp&& new_op2) {
    return simple_rewrite(p_, std::move(new_op1), std::move(new_op2));
  }
  bool simple_rewrite_nop();
  bool is_pred(const std::function<bool(const StackTransform&)>& pred, int min_p = 2);
  bool is_same_as(const StackTransform& trans, int min_p = 2);
  bool is_rot();
  bool is_rotrev();
  bool is_tuck();
  bool is_2dup();
  bool is_2drop();
  bool is_2swap();
  bool is_2over();
  bool is_xchg(int* i, int* j);
  bool is_push(int* i);
  bool is_pop(int* i);
  bool is_nop();
  bool is_xchg2(int* i, int* j);
  bool is_xcpu(int* i, int* j);
  bool is_puxc(int* i, int* j);
  bool is_push2(int* i, int* j);
  bool is_xchg3(int* i, int* j, int* k);
  bool is_xc2pu(int* i, int* j, int* k);
  bool is_xcpuxc(int* i, int* j, int* k);
  bool is_xcpu2(int* i, int* j, int* k);
  bool is_puxc2(int* i, int* j, int* k);
  bool is_puxcpu(int* i, int* j, int* k);
  bool is_pu2xc(int* i, int* j, int* k);
  bool is_push3(int* i, int* j, int* k);
  bool is_blkswap(int* i, int* j);
  bool is_blkpush(int* i, int* j);
  bool is_blkdrop(int* i);
  bool is_reverse(int* i, int* j);
  bool is_nip_seq(int* i, int* j);
  AsmOpConsList extract_code();
};

AsmOpConsList optimize_code_head(AsmOpConsList op_list);
AsmOpConsList optimize_code(AsmOpConsList op_list);
void optimize_code(AsmOpList& ops);

struct Stack {
  StackLayoutExt s;
  AsmOpList& o;
  enum { _StkCmt = 1, _CptStkCmt = 2, _DisableOpt = 4, _Shown = 256, _Garbage = -0x10000 };
  int mode;
  Stack(AsmOpList& _o, int _mode = 0) : o(_o), mode(_mode) {
  }
  Stack(AsmOpList& _o, const StackLayoutExt& _s, int _mode = 0) : s(_s), o(_o), mode(_mode) {
  }
  Stack(AsmOpList& _o, StackLayoutExt&& _s, int _mode = 0) : s(std::move(_s)), o(_o), mode(_mode) {
  }
  int depth() const {
    return (int)s.size();
  }
  var_idx_t operator[](int i) const {
    validate(i);
    return s[depth() - i - 1].first;
  }
  var_const_idx_t& at(int i) {
    validate(i);
    return s[depth() - i - 1];
  }
  var_const_idx_t at(int i) const {
    validate(i);
    return s[depth() - i - 1];
  }
  var_const_idx_t get(int i) const {
    return at(i);
  }
  StackLayout vars() const;
  int find(var_idx_t var, int from = 0) const;
  int find(var_idx_t var, int from, int to) const;
  int find_const(const_idx_t cst, int from = 0) const;
  int find_outside(var_idx_t var, int from, int to) const;
  void forget_const();
  void validate(int i) const {
    assert(i >= 0 && i < depth() && "invalid stack reference");
  }
  void modified() {
    mode &= ~_Shown;
  }
  void issue_pop(int i);
  void issue_push(int i);
  void issue_xchg(int i, int j);
  int drop_vars_except(const VarDescrList& var_info, int excl_var = 0x80000000);
  void forget_var(var_idx_t idx);
  void push_new_var(var_idx_t idx);
  void push_new_const(var_idx_t idx, const_idx_t cidx);
  void assign_var(var_idx_t new_idx, var_idx_t old_idx);
  void do_copy_var(var_idx_t new_idx, var_idx_t old_idx);
  void enforce_state(const StackLayout& req_stack);
  void rearrange_top(const StackLayout& top, std::vector<bool> last);
  void rearrange_top(var_idx_t top, bool last);
  void merge_const(const Stack& req_stack);
  void merge_state(const Stack& req_stack);
  void show(int _mode);
  void show() {
    show(mode);
  }
  void opt_show() {
    if ((mode & (_StkCmt | _Shown)) == _StkCmt) {
      show(mode);
    }
  }
  bool operator==(const Stack& y) const & {
    return s == y.s;
  }
};

/*
 *
 *   SPECIFIC SYMBOL VALUES,
 *   BUILT-IN FUNCTIONS AND OPERATIONS
 * 
 */

typedef std::function<AsmOp(std::vector<VarDescr>&, std::vector<VarDescr>&)> simple_compile_func_t;
typedef std::function<bool(AsmOpList&, std::vector<VarDescr>&, std::vector<VarDescr>&)> compile_func_t;

inline simple_compile_func_t make_simple_compile(AsmOp op) {
  return [op](std::vector<VarDescr>& out, std::vector<VarDescr>& in) -> AsmOp { return op; };
}

inline compile_func_t make_ext_compile(std::vector<AsmOp> ops) {
  return [ops = std::move(ops)](AsmOpList & dest, std::vector<VarDescr> & out, std::vector<VarDescr> & in)->bool {
    return dest.append(ops);
  };
}

inline compile_func_t make_ext_compile(AsmOp op) {
  return
      [op](AsmOpList& dest, std::vector<VarDescr>& out, std::vector<VarDescr>& in) -> bool { return dest.append(op); };
}

struct SymValAsmFunc : SymValFunc {
  simple_compile_func_t simple_compile;
  compile_func_t ext_compile;
  ~SymValAsmFunc() override = default;
  SymValAsmFunc(TypeExpr* ft, const AsmOp& _macro, bool impure = false)
      : SymValFunc(-1, ft, impure), simple_compile(make_simple_compile(_macro)) {
  }
  SymValAsmFunc(TypeExpr* ft, std::vector<AsmOp> _macro, bool impure = false)
      : SymValFunc(-1, ft, impure), ext_compile(make_ext_compile(std::move(_macro))) {
  }
  SymValAsmFunc(TypeExpr* ft, simple_compile_func_t _compile, bool impure = false)
      : SymValFunc(-1, ft, impure), simple_compile(std::move(_compile)) {
  }
  SymValAsmFunc(TypeExpr* ft, compile_func_t _compile, bool impure = false)
      : SymValFunc(-1, ft, impure), ext_compile(std::move(_compile)) {
  }
  SymValAsmFunc(TypeExpr* ft, simple_compile_func_t _compile, std::initializer_list<int> arg_order,
                std::initializer_list<int> ret_order = {}, bool impure = false)
      : SymValFunc(-1, ft, arg_order, ret_order, impure), simple_compile(std::move(_compile)) {
  }
  SymValAsmFunc(TypeExpr* ft, compile_func_t _compile, std::initializer_list<int> arg_order,
                std::initializer_list<int> ret_order = {}, bool impure = false)
      : SymValFunc(-1, ft, arg_order, ret_order, impure), ext_compile(std::move(_compile)) {
  }
  bool compile(AsmOpList& dest, std::vector<VarDescr>& in, std::vector<VarDescr>& out) const;
};

// defined in builtins.cpp
AsmOp exec_arg_op(std::string op, long long arg);
AsmOp exec_arg_op(std::string op, long long arg, int args, int retv = 1);
AsmOp exec_arg_op(std::string op, td::RefInt256 arg);
AsmOp exec_arg_op(std::string op, td::RefInt256 arg, int args, int retv = 1);
AsmOp push_const(td::RefInt256 x);

void define_builtins();

}  // namespace funC
