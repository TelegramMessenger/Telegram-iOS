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
#include <string>
#include <vector>

namespace tlbc {

using src::Lexem;
using src::Lexer;
using sym::sym_idx_t;

struct Type;
struct Constructor;

struct TypeExpr {
  enum {
    te_Unknown,
    te_Type,
    te_Param,
    te_Apply,
    te_Add,
    te_GetBit,
    te_MulConst,
    te_IntConst,
    te_Tuple,
    te_Ref,
    te_CondType
  };
  enum { max_const_expr = 100000, const_htable_size = 170239 };
  int tp;
  int value;
  Type* type_applied;
  bool is_nat;          // we keep integer expressions in 'TypeExpr' as well
  bool is_nat_subtype;  // this is # or a subtype of #
  bool negated;         // is it linearly negative
  bool tchk_only;       // type to be used as RHS of <field>:<type-expr> only
  int is_constexpr;     // if non-zero, it is an index in `const_type_expr`, the table of all constant type expressions
  src::SrcLocation where;
  std::vector<TypeExpr*> args;
  TypeExpr(const src::SrcLocation& loc, int _tp, int _value = 0, bool _pol = false)
      : tp(_tp)
      , value(_value)
      , type_applied(nullptr)
      , is_nat_subtype(false)
      , negated(_pol)
      , tchk_only(false)
      , is_constexpr(0)
      , where(loc) {
    init_is_nat();
  }
  TypeExpr(const src::SrcLocation& loc, int _tp, int _value, std::initializer_list<TypeExpr*> _arglist,
           bool _pol = false)
      : tp(_tp)
      , value(_value)
      , type_applied(nullptr)
      , is_nat_subtype(false)
      , negated(_pol)
      , tchk_only(false)
      , is_constexpr(0)
      , where(loc)
      , args(std::move(_arglist)) {
    init_is_nat();
  }
  TypeExpr(const src::SrcLocation& loc, int _tp, int _value, std::vector<TypeExpr*> _arglist, bool _pol = false)
      : tp(_tp)
      , value(_value)
      , type_applied(nullptr)
      , is_nat_subtype(false)
      , negated(_pol)
      , tchk_only(false)
      , is_constexpr(0)
      , where(loc)
      , args(std::move(_arglist)) {
    init_is_nat();
  }
  void check_mode(const src::SrcLocation& loc, int mode);
  bool no_tchk() const;
  bool close(const src::SrcLocation& loc);
  bool bind_value(bool value_negated, Constructor& cs, bool checking_type = false);
  int abstract_interpret_nat() const;
  MinMaxSize compute_size() const;
  bool compute_any_bits() const;
  bool detect_constexpr();
  int is_integer() const;
  bool is_anon() const;
  bool is_ref_to_anon() const;
  bool equal(const TypeExpr& other) const;
  void const_type_name(std::ostream& os) const;
  static TypeExpr* mk_intconst(const src::SrcLocation& loc, std::string int_const);
  static TypeExpr* mk_intconst(const src::SrcLocation& loc, unsigned int_const);
  static TypeExpr* mk_apply_gen(const src::SrcLocation& loc, TypeExpr* expr1, TypeExpr* expr2);
  static TypeExpr* mk_mulint(const src::SrcLocation& loc, TypeExpr* expr1, TypeExpr* expr2);
  static TypeExpr* mk_cellref(const src::SrcLocation& loc, TypeExpr* expr1);
  static TypeExpr* mk_apply(const src::SrcLocation& loc, int tp, TypeExpr* expr1, TypeExpr* expr2);
  static TypeExpr* mk_apply_empty(const src::SrcLocation& loc, sym_idx_t name, Type* type_applied);
  void show(std::ostream& os, const Constructor* cs = nullptr, int prio = 0, int mode = 0) const;

 private:
  void init_is_nat() {
    is_nat = (tp >= te_Add && tp <= te_IntConst);
  }
  unsigned long long compute_hash() const;
  static TypeExpr* const_htable[const_htable_size];
};

// extern TypeExpr* TypeExpr::const_htable[TypeExpr::const_htable_size];
extern TypeExpr* const_type_expr[TypeExpr::max_const_expr];
extern int const_type_expr_num;

std::ostream& operator<<(std::ostream& os, const TypeExpr* te);

struct Field {
  int field_idx;
  bool implicit;
  bool known;
  bool constraint;
  bool used;
  bool subrec;
  sym_idx_t name;
  TypeExpr* type;
  const src::SrcLocation loc;
  Field(const src::SrcLocation& where, bool impl, int idx, sym_idx_t fname = 0, TypeExpr* ftype = nullptr)
      : field_idx(idx)
      , implicit(impl)
      , known(false)
      , constraint(false)
      , used(false)
      , subrec(false)
      , name(fname)
      , type(ftype)
      , loc(where) {
  }
  void register_sym() const;
  std::string get_name() const;
  bool isomorphic_to(const Field& f, bool allow_other_names = true) const;
};

struct Constructor {
  sym_idx_t constr_name;
  sym_idx_t type_name;
  Type* type_defined;
  src::SrcLocation where;
  unsigned long long tag;
  int tag_bits;
  int fields_num;
  int type_arity;
  bool is_fwd;
  bool is_enum;
  bool is_simple_enum;
  bool is_special;
  bool has_fixed_size;
  bool any_bits;
  MinMaxSize size;
  BitPfxCollection begins_with;
  std::vector<Field> fields;
  std::vector<TypeExpr*> params;
  std::vector<bool> param_negated;
  std::vector<int> param_const_val;  // -1 -- not integer or not constant
  AdmissibilityInfo admissible_params;
  void set_tag(unsigned long long new_tag) {
    tag = new_tag;
    tag_bits = (tag ? 63 - td::count_trailing_zeroes_non_zero64(tag) : -1);
  }
  Constructor(const src::SrcLocation& _loc = {}, sym_idx_t cname = 0, sym_idx_t tname = 0, unsigned long long _tag = 0,
              Type* type = nullptr)
      : constr_name(cname)
      , type_name(tname)
      , type_defined(type)
      , where(_loc)
      , fields_num(0)
      , type_arity(0)
      , is_fwd(false)
      , is_enum(false)
      , is_simple_enum(false)
      , is_special(false)
      , has_fixed_size(false)
      , any_bits(false) {
    set_tag(_tag);
  }
  Field& new_field(const src::SrcLocation& where, bool implicit, sym_idx_t name);
  void show(std::ostream& os, int mode = 0) const;
  std::string get_name() const;
  std::string get_qualified_name() const;
  bool isomorphic_to(const Constructor& cs, bool allow_other_names) const;
  unsigned long long compute_tag() const;
  void check_assign_tag();
  bool compute_is_fwd();
  bool recompute_begins_with();
  bool recompute_minmax_size();
  bool recompute_any_bits();
  bool compute_admissible_params();
  int get_const_param(unsigned idx) const {
    return idx < param_const_val.size() ? param_const_val[idx] : -1;
  }
};

std::ostream& operator<<(std::ostream& os, const Constructor& cs);

struct Type {
  enum { _IsType = 1, _IsNat = 2, _IsPos = 4, _IsNeg = 8, _NonConst = 16 };
  sym_idx_t type_name;
  int type_idx;
  int parent_type_idx;
  int constr_num;
  int arity;
  int used;
  int last_declared;
  static int last_declared_counter;
  bool produces_nat;
  bool is_final;
  bool is_builtin;
  bool is_enum;
  bool is_simple_enum;
  bool is_special;
  bool is_pfx_determ;
  bool is_param_determ;
  bool is_const_param_determ;
  bool is_const_param_pfx_determ;
  bool is_param_pfx_determ;
  bool is_determ;
  bool has_fixed_size;
  bool any_bits;
  bool is_auto;
  bool is_anon;
  bool is_unit;
  bool is_bool;
  signed char is_integer;
  int useful_depth;
  int const_param_idx;
  int conflict1, conflict2;
  MinMaxSize size;
  std::vector<Constructor*> constructors;
  std::vector<int> args;
  BitPfxCollection begins_with;
  AdmissibilityInfo admissible_params;
  std::unique_ptr<BinTrie> cs_trie;

  Type(int idx, sym_idx_t _tname = 0, bool pnat = false, int _arity = -1, bool _final = false, bool _nonempty = false)
      : type_name(_tname)
      , type_idx(idx)
      , parent_type_idx(-1)
      , constr_num(0)
      , arity(_arity)
      , used(0)
      , last_declared(0)
      , produces_nat(pnat)
      , is_final(_final)
      , is_builtin(_final)
      , is_enum(!_final)
      , is_simple_enum(!_final)
      , is_special(false)
      , is_pfx_determ(false)
      , is_param_determ(false)
      , is_const_param_determ(false)
      , is_const_param_pfx_determ(false)
      , is_param_pfx_determ(false)
      , is_determ(false)
      , has_fixed_size(false)
      , any_bits(false)
      , is_auto(false)
      , is_anon(false)
      , is_unit(false)
      , is_bool(false)
      , is_integer(pnat)
      , useful_depth(-1)
      , const_param_idx(-1)
      , conflict1(-1)
      , conflict2(-1) {
    if (arity > 0) {
      args.resize(arity, 0);
    }
    if (_nonempty) {
      begins_with.all();
    }
  }
  void bind_constructor(const src::SrcLocation& loc, Constructor* cs);
  bool unique_constructor_equals(const Constructor& cs, bool allow_other_names = false) const;
  void print_name(std::ostream& os) const;
  std::string get_name() const;
  bool recompute_begins_with();
  bool recompute_minmax_size();
  bool recompute_any_bits();
  bool compute_admissible_params();
  void compute_constructor_trie();
  int detect_const_params();
  bool check_conflicts();
  void show_constructor_conflict();
  void detect_basic_types();
  bool cons_all_exact() const;
  int cons_common_len() const;
  bool is_const_arg(int p) const;
  std::vector<int> get_all_param_values(int p) const;
  std::vector<int> get_constr_by_param_value(int p, int pv) const;
  void renew_last_declared() {
    last_declared = ++last_declared_counter;
  }
};

extern TypeExpr type_Type;

struct SymVal : sym::SymValBase {
  TypeExpr* sym_type;
  SymVal(int _type, int _idx, TypeExpr* _stype = nullptr) : sym::SymValBase(_type, _idx), sym_type(_stype) {
  }
  TypeExpr* get_type() const {
    return sym_type;
  }
};

struct SymValType : SymVal {
  Type* type_ref;
  explicit SymValType(Type* _type = nullptr) : SymVal(sym::SymValBase::_Typename, 0, &type_Type), type_ref(_type) {
  }
};

extern sym_idx_t Nat_name, Eq_name, Less_name, Leq_name;
extern Type *Nat_type, *Eq_type;
extern Type *NatWidth_type, *NatLess_type, *NatLeq_type, *Int_type, *UInt_type;

extern int types_num, builtin_types_num;
extern std::vector<Type> types;

}  // namespace tlbc
