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
using namespace std::literals::string_literals;

/*
 *
 *   SYMBOL VALUES
 * 
 */

int glob_func_cnt, undef_func_cnt, glob_var_cnt;
std::vector<SymDef*> glob_func, glob_vars;

SymDef* predefine_builtin_func(std::string name, TypeExpr* func_type) {
  sym_idx_t name_idx = sym::symbols.lookup(name, 1);
  if (sym::symbols.is_keyword(name_idx)) {
    std::cerr << "fatal: global function `" << name << "` already defined as a keyword" << std::endl;
  }
  SymDef* def = sym::define_global_symbol(name_idx, true);
  if (!def) {
    std::cerr << "fatal: global function `" << name << "` already defined" << std::endl;
    std::exit(1);
  }
  return def;
}

template <typename T>
SymDef* define_builtin_func(std::string name, TypeExpr* func_type, const T& func, bool impure = false) {
  SymDef* def = predefine_builtin_func(name, func_type);
  def->value = new SymValAsmFunc{func_type, func, impure};
  return def;
}

template <typename T>
SymDef* define_builtin_func(std::string name, TypeExpr* func_type, const T& func, std::initializer_list<int> arg_order,
                            std::initializer_list<int> ret_order = {}, bool impure = false) {
  SymDef* def = predefine_builtin_func(name, func_type);
  def->value = new SymValAsmFunc{func_type, func, arg_order, ret_order, impure};
  return def;
}

SymDef* define_builtin_func(std::string name, TypeExpr* func_type, const AsmOp& macro,
                            std::initializer_list<int> arg_order, std::initializer_list<int> ret_order = {},
                            bool impure = false) {
  SymDef* def = predefine_builtin_func(name, func_type);
  def->value = new SymValAsmFunc{func_type, make_simple_compile(macro), arg_order, ret_order, impure};
  return def;
}

SymDef* force_autoapply(SymDef* def) {
  if (def) {
    auto val = dynamic_cast<SymVal*>(def->value);
    if (val) {
      val->auto_apply = true;
    }
  }
  return def;
}

template <typename... Args>
SymDef* define_builtin_const(std::string name, TypeExpr* const_type, Args&&... args) {
  return force_autoapply(
      define_builtin_func(name, TypeExpr::new_map(TypeExpr::new_unit(), const_type), std::forward<Args>(args)...));
}

bool SymValAsmFunc::compile(AsmOpList& dest, std::vector<VarDescr>& out, std::vector<VarDescr>& in) const {
  if (simple_compile) {
    return dest.append(simple_compile(out, in));
  } else if (ext_compile) {
    return ext_compile(dest, out, in);
  } else {
    return false;
  }
}

/*
 * 
 *   DEFINE BUILT-IN FUNCTIONS
 * 
 */

int emulate_negate(int a) {
  int f = VarDescr::_Pos | VarDescr::_Neg;
  if ((a & f) && (~a & f)) {
    a ^= f;
  }
  f = VarDescr::_Bit | VarDescr::_Bool;
  if ((a & f) && (~a & f)) {
    a ^= f;
  }
  return a;
}

int emulate_add(int a, int b) {
  if (b & VarDescr::_Zero) {
    return a;
  } else if (a & VarDescr::_Zero) {
    return b;
  }
  int u = a & b, v = a | b;
  int r = VarDescr::_Int;
  int t = u & (VarDescr::_Pos | VarDescr::_Neg);
  if (v & VarDescr::_Nan) {
    return r | VarDescr::_Nan;
  }
  // non-quiet addition always returns finite results!
  r |= t | VarDescr::_Finite;
  if (t) {
    r |= v & VarDescr::_NonZero;
  }
  r |= v & VarDescr::_Nan;
  if (u & (VarDescr::_Odd | VarDescr::_Even)) {
    r |= VarDescr::_Even;
  } else if (!(~v & (VarDescr::_Odd | VarDescr::_Even))) {
    r |= VarDescr::_Odd | VarDescr::_NonZero;
  }
  return r;
}

int emulate_sub(int a, int b) {
  return emulate_add(a, emulate_negate(b));
}

int emulate_mul(int a, int b) {
  if ((b & (VarDescr::_NonZero | VarDescr::_Bit)) == (VarDescr::_NonZero | VarDescr::_Bit)) {
    return a;
  } else if ((a & (VarDescr::_NonZero | VarDescr::_Bit)) == (VarDescr::_NonZero | VarDescr::_Bit)) {
    return b;
  }
  int u = a & b, v = a | b;
  int r = VarDescr::_Int;
  if (v & VarDescr::_Nan) {
    return r | VarDescr::_Nan;
  }
  // non-quiet multiplication always yields finite results, if any
  r |= VarDescr::_Finite;
  if (v & VarDescr::_Zero) {
    // non-quiet multiplication
    // the result is zero, if any result at all
    return VarDescr::ConstZero;
  }
  if (u & (VarDescr::_Pos | VarDescr::_Neg)) {
    r |= VarDescr::_Pos;
  } else if (!(~v & (VarDescr::_Pos | VarDescr::_Neg))) {
    r |= VarDescr::_Neg;
  }
  if (u & (VarDescr::_Bit | VarDescr::_Bool)) {
    r |= VarDescr::_Bit;
  } else if (!(~v & (VarDescr::_Bit | VarDescr::_Bool))) {
    r |= VarDescr::_Bool;
  }
  r |= v & VarDescr::_Even;
  r |= u & (VarDescr::_Odd | VarDescr::_NonZero);
  return r;
}

int emulate_lshift(int a, int b) {
  if (((a | b) & VarDescr::_Nan) || !(~b & (VarDescr::_Neg | VarDescr::_NonZero))) {
    return VarDescr::_Int | VarDescr::_Nan;
  }
  if (b & VarDescr::_Zero) {
    return a;
  }
  int t = ((b & VarDescr::_NonZero) ? VarDescr::_Even : 0);
  t |= b & VarDescr::_Finite;
  return emulate_mul(a, VarDescr::_Int | VarDescr::_Pos | VarDescr::_NonZero | VarDescr::_Even | t);
}

int emulate_div(int a, int b) {
  if ((b & (VarDescr::_NonZero | VarDescr::_Bit)) == (VarDescr::_NonZero | VarDescr::_Bit)) {
    return a;
  } else if ((b & (VarDescr::_NonZero | VarDescr::_Bool)) == (VarDescr::_NonZero | VarDescr::_Bool)) {
    return emulate_negate(b);
  }
  if (b & VarDescr::_Zero) {
    return VarDescr::_Int | VarDescr::_Nan;
  }
  int u = a & b, v = a | b;
  int r = VarDescr::_Int;
  if (v & VarDescr::_Nan) {
    return r | VarDescr::_Nan;
  }
  // non-quiet division always yields finite results, if any
  r |= VarDescr::_Finite;
  if (a & VarDescr::_Zero) {
    // non-quiet division
    // the result is zero, if any result at all
    return VarDescr::ConstZero;
  }
  if (u & (VarDescr::_Pos | VarDescr::_Neg)) {
    r |= VarDescr::_Pos;
  } else if (!(~v & (VarDescr::_Pos | VarDescr::_Neg))) {
    r |= VarDescr::_Neg;
  }
  if (u & (VarDescr::_Bit | VarDescr::_Bool)) {
    r |= VarDescr::_Bit;
  } else if (!(~v & (VarDescr::_Bit | VarDescr::_Bool))) {
    r |= VarDescr::_Bool;
  }
  return r;
}

int emulate_rshift(int a, int b) {
  if (((a | b) & VarDescr::_Nan) || !(~b & (VarDescr::_Neg | VarDescr::_NonZero))) {
    return VarDescr::_Int | VarDescr::_Nan;
  }
  if (b & VarDescr::_Zero) {
    return a;
  }
  int t = ((b & VarDescr::_NonZero) ? VarDescr::_Even : 0);
  t |= b & VarDescr::_Finite;
  return emulate_div(a, VarDescr::_Int | VarDescr::_Pos | VarDescr::_NonZero | VarDescr::_Even | t);
}

int emulate_mod(int a, int b, int round_mode = -1) {
  if ((b & (VarDescr::_NonZero | VarDescr::_Bit)) == (VarDescr::_NonZero | VarDescr::_Bit)) {
    return VarDescr::ConstZero;
  } else if ((b & (VarDescr::_NonZero | VarDescr::_Bool)) == (VarDescr::_NonZero | VarDescr::_Bool)) {
    return VarDescr::ConstZero;
  }
  if (b & VarDescr::_Zero) {
    return VarDescr::_Int | VarDescr::_Nan;
  }
  int r = VarDescr::_Int;
  if ((a | b) & VarDescr::_Nan) {
    return r | VarDescr::_Nan;
  }
  // non-quiet division always yields finite results, if any
  r |= VarDescr::_Finite;
  if (a & VarDescr::_Zero) {
    // non-quiet division
    // the result is zero, if any result at all
    return VarDescr::ConstZero;
  }
  if (round_mode < 0) {
    r |= b & (VarDescr::_Pos | VarDescr::_Neg);
  } else if (round_mode > 0) {
    r |= emulate_negate(b) & (VarDescr::_Pos | VarDescr::_Neg);
  }
  if (a & (VarDescr::_Bit | VarDescr::_Bool)) {
    if (r & VarDescr::_Pos) {
      r |= VarDescr::_Bit;
    }
    if (r & VarDescr::_Neg) {
      r |= VarDescr::_Bool;
    }
  }
  if (b & VarDescr::_Even) {
    r |= a & (VarDescr::_Even | VarDescr::_Odd);
  }
  return r;
}

bool VarDescr::always_less(const VarDescr& other) const {
  if (is_int_const() && other.is_int_const()) {
    return int_const < other.int_const;
  }
  return (always_nonpos() && other.always_pos()) || (always_neg() && other.always_nonneg());
}

bool VarDescr::always_leq(const VarDescr& other) const {
  if (is_int_const() && other.is_int_const()) {
    return int_const <= other.int_const;
  }
  return always_nonpos() && other.always_nonneg();
}

bool VarDescr::always_greater(const VarDescr& other) const {
  return other.always_less(*this);
}

bool VarDescr::always_geq(const VarDescr& other) const {
  return other.always_leq(*this);
}

bool VarDescr::always_equal(const VarDescr& other) const {
  return is_int_const() && other.is_int_const() && *int_const == *other.int_const;
}

bool VarDescr::always_neq(const VarDescr& other) const {
  if (is_int_const() && other.is_int_const()) {
    return *int_const != *other.int_const;
  }
  return always_greater(other) || always_less(other) || (always_even() && other.always_odd()) ||
         (always_odd() && other.always_even());
}

AsmOp exec_op(std::string op) {
  return AsmOp::Custom(op);
}

AsmOp exec_op(std::string op, int args, int retv = 1) {
  return AsmOp::Custom(op, args, retv);
}

AsmOp exec_arg_op(std::string op, long long arg) {
  std::ostringstream os;
  os << arg << ' ' << op;
  return AsmOp::Custom(os.str());
}

AsmOp exec_arg_op(std::string op, long long arg, int args, int retv) {
  std::ostringstream os;
  os << arg << ' ' << op;
  return AsmOp::Custom(os.str(), args, retv);
}

AsmOp exec_arg_op(std::string op, td::RefInt256 arg) {
  std::ostringstream os;
  os << arg << ' ' << op;
  return AsmOp::Custom(os.str());
}

AsmOp exec_arg_op(std::string op, td::RefInt256 arg, int args, int retv) {
  std::ostringstream os;
  os << arg << ' ' << op;
  return AsmOp::Custom(os.str(), args, retv);
}

AsmOp exec_arg2_op(std::string op, long long imm1, long long imm2, int args, int retv) {
  std::ostringstream os;
  os << imm1 << ' ' << imm2 << ' ' << op;
  return AsmOp::Custom(os.str(), args, retv);
}

AsmOp push_const(td::RefInt256 x) {
  return AsmOp::IntConst(std::move(x));
}

AsmOp compile_add(std::vector<VarDescr>& res, std::vector<VarDescr>& args) {
  assert(res.size() == 1 && args.size() == 2);
  VarDescr &r = res[0], &x = args[0], &y = args[1];
  if (x.is_int_const() && y.is_int_const()) {
    r.set_const(x.int_const + y.int_const);
    x.unused();
    y.unused();
    return push_const(r.int_const);
  }
  r.val = emulate_add(x.val, y.val);
  if (y.is_int_const() && y.int_const->signed_fits_bits(8)) {
    y.unused();
    if (y.always_zero()) {
      return AsmOp::Nop();
    }
    if (*y.int_const == 1) {
      return exec_op("INC", 1);
    }
    if (*y.int_const == -1) {
      return exec_op("DEC", 1);
    }
    return exec_arg_op("ADDCONST", y.int_const, 1);
  }
  if (x.is_int_const() && x.int_const->signed_fits_bits(8)) {
    x.unused();
    if (x.always_zero()) {
      return AsmOp::Nop();
    }
    if (*x.int_const == 1) {
      return exec_op("INC", 1);
    }
    if (*x.int_const == -1) {
      return exec_op("DEC", 1);
    }
    return exec_arg_op("ADDCONST", x.int_const, 1);
  }
  return exec_op("ADD", 2);
}

AsmOp compile_sub(std::vector<VarDescr>& res, std::vector<VarDescr>& args) {
  assert(res.size() == 1 && args.size() == 2);
  VarDescr &r = res[0], &x = args[0], &y = args[1];
  if (x.is_int_const() && y.is_int_const()) {
    r.set_const(x.int_const - y.int_const);
    x.unused();
    y.unused();
    return push_const(r.int_const);
  }
  r.val = emulate_sub(x.val, y.val);
  if (y.is_int_const() && (-y.int_const)->signed_fits_bits(8)) {
    y.unused();
    if (y.always_zero()) {
      return {};
    }
    if (*y.int_const == 1) {
      return exec_op("DEC", 1);
    }
    if (*y.int_const == -1) {
      return exec_op("INC", 1);
    }
    return exec_arg_op("ADDCONST", -y.int_const, 1);
  }
  if (x.always_zero()) {
    x.unused();
    return exec_op("NEGATE", 1);
  }
  return exec_op("SUB", 2);
}

AsmOp compile_negate(std::vector<VarDescr>& res, std::vector<VarDescr>& args) {
  assert(res.size() == 1 && args.size() == 1);
  VarDescr &r = res[0], &x = args[0];
  if (x.is_int_const()) {
    r.set_const(-x.int_const);
    x.unused();
    return push_const(r.int_const);
  }
  r.val = emulate_negate(x.val);
  return exec_op("NEGATE", 1);
}

AsmOp compile_mul_internal(VarDescr& r, VarDescr& x, VarDescr& y) {
  if (x.is_int_const() && y.is_int_const()) {
    r.set_const(x.int_const * y.int_const);
    x.unused();
    y.unused();
    return push_const(r.int_const);
  }
  r.val = emulate_mul(x.val, y.val);
  if (y.is_int_const()) {
    int k = is_pos_pow2(y.int_const);
    if (y.int_const->signed_fits_bits(8) && k < 0) {
      y.unused();
      if (y.always_zero() && x.always_finite()) {
        // dubious optimization: NaN * 0 = ?
        r.set_const(y.int_const);
        return push_const(r.int_const);
      }
      if (*y.int_const == 1 && x.always_finite()) {
        return AsmOp::Nop();
      }
      if (*y.int_const == -1) {
        return exec_op("NEGATE", 1);
      }
      return exec_arg_op("MULCONST", y.int_const, 1);
    }
    if (k > 0) {
      y.unused();
      return exec_arg_op("LSHIFT#", k, 1);
    }
    if (k == 0) {
      y.unused();
      return AsmOp::Nop();
    }
  }
  if (x.is_int_const()) {
    int k = is_pos_pow2(x.int_const);
    if (x.int_const->signed_fits_bits(8) && k < 0) {
      x.unused();
      if (x.always_zero() && y.always_finite()) {
        // dubious optimization: NaN * 0 = ?
        r.set_const(x.int_const);
        return push_const(r.int_const);
      }
      if (*x.int_const == 1 && y.always_finite()) {
        return AsmOp::Nop();
      }
      if (*x.int_const == -1) {
        return exec_op("NEGATE", 1);
      }
      return exec_arg_op("MULCONST", x.int_const, 1);
    }
    if (k > 0) {
      x.unused();
      return exec_arg_op("LSHIFT#", k, 1);
    }
    if (k == 0) {
      x.unused();
      return AsmOp::Nop();
    }
  }
  return exec_op("MUL", 2);
}

AsmOp compile_mul(std::vector<VarDescr>& res, std::vector<VarDescr>& args) {
  assert(res.size() == 1 && args.size() == 2);
  return compile_mul_internal(res[0], args[0], args[1]);
}

AsmOp compile_lshift(std::vector<VarDescr>& res, std::vector<VarDescr>& args) {
  assert(res.size() == 1 && args.size() == 2);
  VarDescr &r = res[0], &x = args[0], &y = args[1];
  if (y.is_int_const()) {
    auto yv = y.int_const->to_long();
    if (yv < 0 || yv > 256) {
      r.set_const_nan();
      x.unused();
      y.unused();
      return push_const(r.int_const);
    } else if (x.is_int_const()) {
      r.set_const(x.int_const << (int)yv);
      x.unused();
      y.unused();
      return push_const(r.int_const);
    }
  }
  r.val = emulate_lshift(x.val, y.val);
  if (y.is_int_const()) {
    int k = (int)(y.int_const->to_long());
    if (!k /* && x.always_finite() */) {
      // dubious optimization: what if x=NaN ?
      y.unused();
      return AsmOp::Nop();
    }
    y.unused();
    return exec_arg_op("LSHIFT#", k, 1);
  }
  if (x.is_int_const()) {
    auto xv = x.int_const->to_long();
    if (xv == 1) {
      x.unused();
      return exec_op("POW2", 1);
    }
    if (xv == -1) {
      x.unused();
      return exec_op("NEGPOW2", 1);
    }
  }
  return exec_op("LSHIFT", 2);
}

AsmOp compile_rshift(std::vector<VarDescr>& res, std::vector<VarDescr>& args, int round_mode) {
  assert(res.size() == 1 && args.size() == 2);
  VarDescr &r = res[0], &x = args[0], &y = args[1];
  if (y.is_int_const()) {
    auto yv = y.int_const->to_long();
    if (yv < 0 || yv > 256) {
      r.set_const_nan();
      x.unused();
      y.unused();
      return push_const(r.int_const);
    } else if (x.is_int_const()) {
      r.set_const(td::rshift(x.int_const, (int)yv, round_mode));
      x.unused();
      y.unused();
      return push_const(r.int_const);
    }
  }
  r.val = emulate_rshift(x.val, y.val);
  std::string rshift = (round_mode < 0 ? "RSHIFT" : (round_mode ? "RSHIFTC" : "RSHIFTR"));
  if (y.is_int_const()) {
    int k = (int)(y.int_const->to_long());
    if (!k /* && x.always_finite() */) {
      // dubious optimization: what if x=NaN ?
      y.unused();
      return AsmOp::Nop();
    }
    y.unused();
    return exec_arg_op(rshift + "#", k, 1);
  }
  return exec_op(rshift, 2);
}

AsmOp compile_div_internal(VarDescr& r, VarDescr& x, VarDescr& y, int round_mode) {
  if (x.is_int_const() && y.is_int_const()) {
    r.set_const(div(x.int_const, y.int_const, round_mode));
    x.unused();
    y.unused();
    return push_const(r.int_const);
  }
  r.val = emulate_div(x.val, y.val);
  if (y.is_int_const()) {
    if (*y.int_const == 0) {
      x.unused();
      y.unused();
      r.set_const(div(y.int_const, y.int_const));
      return push_const(r.int_const);
    }
    if (*y.int_const == 1 && x.always_finite()) {
      y.unused();
      return AsmOp::Nop();
    }
    if (*y.int_const == -1) {
      y.unused();
      return exec_op("NEGATE", 1);
    }
    int k = is_pos_pow2(y.int_const);
    if (k > 0) {
      y.unused();
      std::string op = "RSHIFT";
      if (round_mode >= 0) {
        op += (round_mode > 0 ? 'C' : 'R');
      }
      return exec_arg_op(op + '#', k, 1);
    }
  }
  std::string op = "DIV";
  if (round_mode >= 0) {
    op += (round_mode > 0 ? 'C' : 'R');
  }
  return exec_op(op, 2);
}

AsmOp compile_div(std::vector<VarDescr>& res, std::vector<VarDescr>& args, int round_mode) {
  assert(res.size() == 1 && args.size() == 2);
  return compile_div_internal(res[0], args[0], args[1], round_mode);
}

AsmOp compile_mod(std::vector<VarDescr>& res, std::vector<VarDescr>& args, int round_mode) {
  assert(res.size() == 1 && args.size() == 2);
  VarDescr &r = res[0], &x = args[0], &y = args[1];
  if (x.is_int_const() && y.is_int_const()) {
    r.set_const(mod(x.int_const, y.int_const, round_mode));
    x.unused();
    y.unused();
    return push_const(r.int_const);
  }
  r.val = emulate_mod(x.val, y.val);
  if (y.is_int_const()) {
    if (*y.int_const == 0) {
      x.unused();
      y.unused();
      r.set_const(mod(y.int_const, y.int_const));
      return push_const(r.int_const);
    }
    if ((*y.int_const == 1 || *y.int_const == -1) && x.always_finite()) {
      x.unused();
      y.unused();
      r.set_const(td::zero_refint());
      return push_const(r.int_const);
    }
    int k = is_pos_pow2(y.int_const);
    if (k > 0) {
      y.unused();
      std::string op = "MODPOW2";
      if (round_mode >= 0) {
        op += (round_mode > 0 ? 'C' : 'R');
      }
      return exec_arg_op(op + '#', k, 1);
    }
  }
  std::string op = "MOD";
  if (round_mode >= 0) {
    op += (round_mode > 0 ? 'C' : 'R');
  }
  return exec_op(op, 2);
}

AsmOp compile_muldiv(std::vector<VarDescr>& res, std::vector<VarDescr>& args, int round_mode) {
  assert(res.size() == 1 && args.size() == 3);
  VarDescr &r = res[0], &x = args[0], &y = args[1], &z = args[2];
  if (x.is_int_const() && y.is_int_const() && z.is_int_const()) {
    r.set_const(muldiv(x.int_const, y.int_const, z.int_const, round_mode));
    x.unused();
    y.unused();
    z.unused();
    return push_const(r.int_const);
  }
  if (x.always_zero() || y.always_zero()) {
    // dubious optimization for z=0...
    x.unused();
    y.unused();
    z.unused();
    r.set_const(td::make_refint(0));
    return push_const(r.int_const);
  }
  char c = (round_mode < 0) ? 0 : (round_mode > 0 ? 'C' : 'R');
  r.val = emulate_div(emulate_mul(x.val, y.val), z.val);
  if (z.is_int_const()) {
    if (*z.int_const == 0) {
      x.unused();
      y.unused();
      z.unused();
      r.set_const(div(z.int_const, z.int_const));
      return push_const(r.int_const);
    }
    if (*z.int_const == 1) {
      z.unused();
      return compile_mul_internal(r, x, y);
    }
  }
  if (y.is_int_const() && *y.int_const == 1) {
    y.unused();
    return compile_div_internal(r, x, z, round_mode);
  }
  if (x.is_int_const() && *x.int_const == 1) {
    x.unused();
    return compile_div_internal(r, y, z, round_mode);
  }
  if (z.is_int_const()) {
    int k = is_pos_pow2(z.int_const);
    if (k > 0) {
      z.unused();
      std::string op = "MULRSHIFT";
      if (c) {
        op += c;
      }
      return exec_arg_op(op + '#', k, 2);
    }
  }
  if (y.is_int_const()) {
    int k = is_pos_pow2(y.int_const);
    if (k > 0) {
      y.unused();
      std::string op = "LSHIFT#DIV";
      if (c) {
        op += c;
      }
      return exec_arg_op(op, k, 2);
    }
  }
  if (x.is_int_const()) {
    int k = is_pos_pow2(x.int_const);
    if (k > 0) {
      x.unused();
      std::string op = "LSHIFT#DIV";
      if (c) {
        op += c;
      }
      return exec_arg_op(op, k, 2);
    }
  }
  std::string op = "MULDIV";
  if (c) {
    op += c;
  }
  return exec_op(op, 3);
}

int compute_compare(td::RefInt256 x, td::RefInt256 y, int mode) {
  int s = td::cmp(x, y);
  if (mode == 7) {
    return s;
  } else {
    return -((mode >> (1 - s)) & 1);
  }
}

// return value:
// 4 -> constant 1
// 2 -> constant 0
// 1 -> constant -1
// 3 -> 0 or -1
int compute_compare(const VarDescr& x, const VarDescr& y, int mode) {
  switch (mode) {
    case 1:  // >
      return x.always_greater(y) ? 1 : (x.always_leq(y) ? 2 : 3);
    case 2:  // =
      return x.always_equal(y) ? 1 : (x.always_neq(y) ? 2 : 3);
    case 3:  // >=
      return x.always_geq(y) ? 1 : (x.always_less(y) ? 2 : 3);
    case 4:  // <
      return x.always_less(y) ? 1 : (x.always_geq(y) ? 2 : 3);
    case 5:  // <>
      return x.always_neq(y) ? 1 : (x.always_equal(y) ? 2 : 3);
    case 6:  // <=
      return x.always_leq(y) ? 1 : (x.always_greater(y) ? 2 : 3);
    case 7:  // <=>
      return x.always_less(y)
                 ? 1
                 : (x.always_equal(y)
                        ? 2
                        : (x.always_greater(y)
                               ? 4
                               : (x.always_leq(y) ? 3 : (x.always_geq(y) ? 6 : (x.always_neq(y) ? 5 : 7)))));
    default:
      return 7;
  }
}

AsmOp compile_cmp_int(std::vector<VarDescr>& res, std::vector<VarDescr>& args, int mode) {
  assert(mode >= 1 && mode <= 7);
  assert(res.size() == 1 && args.size() == 2);
  VarDescr &r = res[0], &x = args[0], &y = args[1];
  if (x.is_int_const() && y.is_int_const()) {
    int v = compute_compare(x.int_const, y.int_const, mode);
    r.set_const(v);
    x.unused();
    y.unused();
    return mode == 7 ? push_const(r.int_const) : AsmOp::BoolConst(v != 0);
  }
  int v = compute_compare(x, y, mode);
  // std::cerr << "compute_compare(" << x << ", " << y << ", " << mode << ") = " << v << std::endl;
  assert(v);
  if (!(v & (v - 1))) {
    r.set_const(v - (v >> 2) - 2);
    x.unused();
    y.unused();
    return mode == 7 ? push_const(r.int_const) : AsmOp::BoolConst(v & 1);
  }
  r.val = ~0;
  if (v & 1) {
    r.val &= VarDescr::ConstTrue;
  }
  if (v & 2) {
    r.val &= VarDescr::ConstZero;
  }
  if (v & 4) {
    r.val &= VarDescr::ConstOne;
  }
  // std::cerr << "result: " << r << std::endl;
  static const char* cmp_int_names[] = {"", "GTINT", "EQINT", "GTINT", "LESSINT", "NEQINT", "LESSINT"};
  static const char* cmp_names[] = {"", "GREATER", "EQUAL", "GEQ", "LESS", "NEQ", "LEQ", "CMP"};
  static int cmp_int_delta[] = {0, 0, 0, -1, 0, 0, 1};
  if (mode != 7) {
    if (y.is_int_const() && y.int_const >= -128 && y.int_const <= 127) {
      y.unused();
      return exec_arg_op(cmp_int_names[mode], y.int_const + cmp_int_delta[mode], 1);
    }
    if (x.is_int_const() && x.int_const >= -128 && x.int_const <= 127) {
      x.unused();
      mode = ((mode & 4) >> 2) | (mode & 2) | ((mode & 1) << 2);
      return exec_arg_op(cmp_int_names[mode], x.int_const + cmp_int_delta[mode], 1);
    }
  }
  return exec_op(cmp_names[mode], 2);
}

AsmOp compile_throw(std::vector<VarDescr>& res, std::vector<VarDescr>& args) {
  assert(res.empty() && args.size() == 1);
  VarDescr& x = args[0];
  if (x.is_int_const() && x.int_const->unsigned_fits_bits(11)) {
    x.unused();
    return exec_arg_op("THROW", x.int_const, 0, 0);
  } else {
    return exec_op("THROWANY", 1, 0);
  }
}

AsmOp compile_cond_throw(std::vector<VarDescr>& res, std::vector<VarDescr>& args, bool mode) {
  assert(res.empty() && args.size() == 2);
  VarDescr &x = args[0], &y = args[1];
  std::string suff = (mode ? "IF" : "IFNOT");
  bool skip_cond = false;
  if (y.always_true() || y.always_false()) {
    y.unused();
    skip_cond = true;
    if (y.always_true() != mode) {
      x.unused();
      return AsmOp::Nop();
    }
  }
  if (x.is_int_const() && x.int_const->unsigned_fits_bits(11)) {
    x.unused();
    return skip_cond ? exec_arg_op("THROW", x.int_const, 0, 0) : exec_arg_op("THROW"s + suff, x.int_const, 1, 0);
  } else {
    return skip_cond ? exec_op("THROWANY", 1, 0) : exec_op("THROWANY"s + suff, 2, 0);
  }
}

AsmOp compile_bool_const(std::vector<VarDescr>& res, std::vector<VarDescr>& args, bool val) {
  assert(res.size() == 1 && args.empty());
  VarDescr& r = res[0];
  r.set_const(val ? -1 : 0);
  return AsmOp::Const(val ? "TRUE" : "FALSE");
}

// (slice, int) load_int(slice s, int len) asm(s len -> 1 0) "LDIX";
// (slice, int) load_uint(slice s, int len) asm( -> 1 0) "LDUX";
// int preload_int(slice s, int len) asm "PLDIX";
// int preload_uint(slice s, int len) asm "PLDUX";
AsmOp compile_fetch_int(std::vector<VarDescr>& res, std::vector<VarDescr>& args, bool fetch, bool sgnd) {
  assert(args.size() == 2 && res.size() == 1 + (unsigned)fetch);
  auto &y = args[1], &r = res.back();
  r.val = (sgnd ? VarDescr::FiniteInt : VarDescr::FiniteUInt);
  int v = -1;
  if (y.is_int_const() && y.int_const >= 0 && y.int_const <= 256) {
    v = (int)y.int_const->to_long();
    if (!v) {
      r.val = VarDescr::ConstZero;
    }
    if (v == 1) {
      r.val = (sgnd ? VarDescr::ValBool : VarDescr::ValBit);
    }
    if (v > 0) {
      y.unused();
      return exec_arg_op((fetch ? "LD"s : "PLD"s) + (sgnd ? 'I' : 'U'), v, 1, 1 + (unsigned)fetch);
    }
  }
  return exec_op((fetch ? "LD"s : "PLD"s) + (sgnd ? "IX" : "UX"), 2, 1 + (unsigned)fetch);
}

// builder store_uint(builder b, int x, int len) asm(x b len) "STUX";
// builder store_int(builder b, int x, int len) asm(x b len) "STIX";
AsmOp compile_store_int(std::vector<VarDescr>& res, std::vector<VarDescr>& args, bool sgnd) {
  assert(args.size() == 3 && res.size() == 1);
  auto& z = args[2];
  if (z.is_int_const() && z.int_const > 0 && z.int_const <= 256) {
    z.unused();
    return exec_arg_op("ST"s + (sgnd ? 'I' : 'U'), z.int_const, 2, 1);
  }
  return exec_op("ST"s + (sgnd ? "IX" : "UX"), 3, 1);
}

AsmOp compile_fetch_slice(std::vector<VarDescr>& res, std::vector<VarDescr>& args, bool fetch) {
  assert(args.size() == 2 && res.size() == 1 + (unsigned)fetch);
  auto& y = args[1];
  int v = -1;
  if (y.is_int_const() && y.int_const > 0 && y.int_const <= 256) {
    v = (int)y.int_const->to_long();
    if (v > 0) {
      y.unused();
      return exec_arg_op(fetch ? "LDSLICE" : "PLDSLICE", v, 1, 1 + (unsigned)fetch);
    }
  }
  return exec_op(fetch ? "LDSLICEX" : "PLDSLICEX", 2, 1 + (unsigned)fetch);
}

// <type> <type>_at(tuple t, int index) asm "INDEXVAR";
AsmOp compile_tuple_at(std::vector<VarDescr>& res, std::vector<VarDescr>& args) {
  assert(args.size() == 2 && res.size() == 1);
  auto& y = args[1];
  if (y.is_int_const() && y.int_const >= 0 && y.int_const < 16) {
    y.unused();
    return exec_arg_op("INDEX", y.int_const, 1, 1);
  }
  return exec_op("INDEXVAR", 2, 1);
}

// int null?(X arg)
AsmOp compile_is_null(std::vector<VarDescr>& res, std::vector<VarDescr>& args) {
  assert(args.size() == 1 && res.size() == 1);
  auto &x = args[0], &r = res[0];
  if (x.always_null() || x.always_not_null()) {
    x.unused();
    r.set_const(x.always_null() ? -1 : 0);
    return push_const(r.int_const);
  }
  res[0].val = VarDescr::ValBool;
  return exec_op("ISNULL", 1, 1);
}

bool compile_run_method(AsmOpList& code, std::vector<VarDescr>& res, std::vector<VarDescr>& args, int n,
                        bool has_value) {
  assert(args.size() == (unsigned)n + 1 && res.size() == (unsigned)has_value);
  auto& x = args[0];
  if (x.is_int_const() && x.int_const->unsigned_fits_bits(14)) {
    x.unused();
    code << exec_arg_op("PREPAREDICT", x.int_const, 0, 2);
  } else {
    code << exec_op("c3 PUSH", 0, 1);
  }
  code << exec_arg_op(has_value ? "1 CALLXARGS" : "0 CALLXARGS", n, n + 2, (unsigned)has_value);
  return true;
}

void define_builtins() {
  using namespace std::placeholders;
  auto Unit = TypeExpr::new_unit();
  auto Int = TypeExpr::new_atomic(_Int);
  auto Cell = TypeExpr::new_atomic(_Cell);
  auto Slice = TypeExpr::new_atomic(_Slice);
  auto Builder = TypeExpr::new_atomic(_Builder);
  // auto Null = TypeExpr::new_atomic(_Null);
  auto Tuple = TypeExpr::new_atomic(_Tuple);
  auto Int2 = TypeExpr::new_tensor({Int, Int});
  auto Int3 = TypeExpr::new_tensor({Int, Int, Int});
  auto TupleInt = TypeExpr::new_tensor({Tuple, Int});
  auto SliceInt = TypeExpr::new_tensor({Slice, Int});
  auto X = TypeExpr::new_var();
  auto Y = TypeExpr::new_var();
  auto Z = TypeExpr::new_var();
  auto XY = TypeExpr::new_tensor({X, Y});
  auto arith_bin_op = TypeExpr::new_map(Int2, Int);
  auto arith_un_op = TypeExpr::new_map(Int, Int);
  auto impure_bin_op = TypeExpr::new_map(Int2, Unit);
  auto impure_un_op = TypeExpr::new_map(Int, Unit);
  auto fetch_int_op = TypeExpr::new_map(SliceInt, SliceInt);
  auto prefetch_int_op = TypeExpr::new_map(SliceInt, Int);
  auto store_int_op = TypeExpr::new_map(TypeExpr::new_tensor({Builder, Int, Int}), Builder);
  auto store_int_method =
      TypeExpr::new_map(TypeExpr::new_tensor({Builder, Int, Int}), TypeExpr::new_tensor({Builder, Unit}));
  auto fetch_slice_op = TypeExpr::new_map(SliceInt, TypeExpr::new_tensor({Slice, Slice}));
  auto prefetch_slice_op = TypeExpr::new_map(SliceInt, Slice);
  //auto arith_null_op = TypeExpr::new_map(TypeExpr::new_unit(), Int);
  define_builtin_func("_+_", arith_bin_op, compile_add);
  define_builtin_func("_-_", arith_bin_op, compile_sub);
  define_builtin_func("-_", arith_un_op, compile_negate);
  define_builtin_func("_*_", arith_bin_op, compile_mul);
  define_builtin_func("_/_", arith_bin_op, std::bind(compile_div, _1, _2, -1));
  define_builtin_func("_~/_", arith_bin_op, std::bind(compile_div, _1, _2, 0));
  define_builtin_func("_^/_", arith_bin_op, std::bind(compile_div, _1, _2, 1));
  define_builtin_func("_%_", arith_bin_op, std::bind(compile_mod, _1, _2, -1));
  define_builtin_func("_~%_", arith_bin_op, std::bind(compile_mod, _1, _2, 0));
  define_builtin_func("_^%_", arith_bin_op, std::bind(compile_mod, _1, _2, 1));
  define_builtin_func("_/%_", TypeExpr::new_map(Int2, Int2), AsmOp::Custom("DIVMOD", 2, 2));
  define_builtin_func("divmod", TypeExpr::new_map(Int2, Int2), AsmOp::Custom("DIVMOD", 2, 2));
  define_builtin_func("~divmod", TypeExpr::new_map(Int2, Int2), AsmOp::Custom("DIVMOD", 2, 2));
  define_builtin_func("moddiv", TypeExpr::new_map(Int2, Int2), AsmOp::Custom("DIVMOD", 2, 2), {}, {1, 0});
  define_builtin_func("~moddiv", TypeExpr::new_map(Int2, Int2), AsmOp::Custom("DIVMOD", 2, 2), {}, {1, 0});
  define_builtin_func("_<<_", arith_bin_op, compile_lshift);
  define_builtin_func("_>>_", arith_bin_op, std::bind(compile_rshift, _1, _2, -1));
  define_builtin_func("_~>>_", arith_bin_op, std::bind(compile_rshift, _1, _2, 0));
  define_builtin_func("_^>>_", arith_bin_op, std::bind(compile_rshift, _1, _2, 1));
  define_builtin_func("_&_", arith_bin_op, AsmOp::Custom("AND", 2));
  define_builtin_func("_|_", arith_bin_op, AsmOp::Custom("OR", 2));
  define_builtin_func("_^_", arith_bin_op, AsmOp::Custom("XOR", 2));
  define_builtin_func("~_", arith_un_op, AsmOp::Custom("NOT", 1));
  define_builtin_func("^_+=_", arith_bin_op, compile_add);
  define_builtin_func("^_-=_", arith_bin_op, compile_sub);
  define_builtin_func("^_*=_", arith_bin_op, compile_mul);
  define_builtin_func("^_/=_", arith_bin_op, std::bind(compile_div, _1, _2, -1));
  define_builtin_func("^_~/=_", arith_bin_op, std::bind(compile_div, _1, _2, 0));
  define_builtin_func("^_^/=_", arith_bin_op, std::bind(compile_div, _1, _2, 1));
  define_builtin_func("^_%=_", arith_bin_op, std::bind(compile_mod, _1, _2, -1));
  define_builtin_func("^_~%=_", arith_bin_op, std::bind(compile_mod, _1, _2, 0));
  define_builtin_func("^_^%=_", arith_bin_op, std::bind(compile_mod, _1, _2, 1));
  define_builtin_func("^_<<=_", arith_bin_op, compile_lshift);
  define_builtin_func("^_>>=_", arith_bin_op, std::bind(compile_rshift, _1, _2, -1));
  define_builtin_func("^_~>>=_", arith_bin_op, std::bind(compile_rshift, _1, _2, 0));
  define_builtin_func("^_^>>=_", arith_bin_op, std::bind(compile_rshift, _1, _2, 1));
  define_builtin_func("^_&=_", arith_bin_op, AsmOp::Custom("AND", 2));
  define_builtin_func("^_|=_", arith_bin_op, AsmOp::Custom("OR", 2));
  define_builtin_func("^_^=_", arith_bin_op, AsmOp::Custom("XOR", 2));
  define_builtin_func("muldiv", TypeExpr::new_map(Int3, Int), std::bind(compile_muldiv, _1, _2, -1));
  define_builtin_func("muldivr", TypeExpr::new_map(Int3, Int), std::bind(compile_muldiv, _1, _2, 0));
  define_builtin_func("muldivc", TypeExpr::new_map(Int3, Int), std::bind(compile_muldiv, _1, _2, 1));
  define_builtin_func("muldivmod", TypeExpr::new_map(Int3, Int2), AsmOp::Custom("MULDIVMOD", 3, 2));
  define_builtin_func("_==_", arith_bin_op, std::bind(compile_cmp_int, _1, _2, 2));
  define_builtin_func("_!=_", arith_bin_op, std::bind(compile_cmp_int, _1, _2, 5));
  define_builtin_func("_<_", arith_bin_op, std::bind(compile_cmp_int, _1, _2, 4));
  define_builtin_func("_>_", arith_bin_op, std::bind(compile_cmp_int, _1, _2, 1));
  define_builtin_func("_<=_", arith_bin_op, std::bind(compile_cmp_int, _1, _2, 6));
  define_builtin_func("_>=_", arith_bin_op, std::bind(compile_cmp_int, _1, _2, 3));
  define_builtin_func("_<=>_", arith_bin_op, std::bind(compile_cmp_int, _1, _2, 7));
  define_builtin_const("true", Int, /* AsmOp::Const("TRUE") */ std::bind(compile_bool_const, _1, _2, true));
  define_builtin_const("false", Int, /* AsmOp::Const("FALSE") */ std::bind(compile_bool_const, _1, _2, false));
  // define_builtin_func("null", Null, AsmOp::Const("PUSHNULL"));
  define_builtin_const("nil", Tuple, AsmOp::Const("PUSHNULL"));
  define_builtin_const("Nil", Tuple, AsmOp::Const("NIL"));
  define_builtin_func("null?", TypeExpr::new_forall({X}, TypeExpr::new_map(X, Int)), compile_is_null);
  define_builtin_func("throw", impure_un_op, compile_throw, true);
  define_builtin_func("throw_if", impure_bin_op, std::bind(compile_cond_throw, _1, _2, true), true);
  define_builtin_func("throw_unless", impure_bin_op, std::bind(compile_cond_throw, _1, _2, false), true);
  define_builtin_func("load_int", fetch_int_op, std::bind(compile_fetch_int, _1, _2, true, true), {}, {1, 0});
  define_builtin_func("load_uint", fetch_int_op, std::bind(compile_fetch_int, _1, _2, true, false), {}, {1, 0});
  define_builtin_func("preload_int", prefetch_int_op, std::bind(compile_fetch_int, _1, _2, false, true));
  define_builtin_func("preload_uint", prefetch_int_op, std::bind(compile_fetch_int, _1, _2, false, false));
  define_builtin_func("store_int", store_int_op, std::bind(compile_store_int, _1, _2, true), {1, 0, 2});
  define_builtin_func("store_uint", store_int_op, std::bind(compile_store_int, _1, _2, false), {1, 0, 2});
  define_builtin_func("~store_int", store_int_method, std::bind(compile_store_int, _1, _2, true), {1, 0, 2});
  define_builtin_func("~store_uint", store_int_method, std::bind(compile_store_int, _1, _2, false), {1, 0, 2});
  define_builtin_func("load_bits", fetch_slice_op, std::bind(compile_fetch_slice, _1, _2, true), {}, {1, 0});
  define_builtin_func("preload_bits", prefetch_slice_op, std::bind(compile_fetch_slice, _1, _2, false));
  define_builtin_func("int_at", TypeExpr::new_map(TupleInt, Int), compile_tuple_at);
  define_builtin_func("cell_at", TypeExpr::new_map(TupleInt, Cell), compile_tuple_at);
  define_builtin_func("slice_at", TypeExpr::new_map(TupleInt, Slice), compile_tuple_at);
  define_builtin_func("tuple_at", TypeExpr::new_map(TupleInt, Tuple), compile_tuple_at);
  define_builtin_func("at", TypeExpr::new_forall({X}, TypeExpr::new_map(TupleInt, X)), compile_tuple_at);
  define_builtin_func("touch", TypeExpr::new_forall({X}, TypeExpr::new_map(X, X)), AsmOp::Nop());
  define_builtin_func("~touch", TypeExpr::new_forall({X}, TypeExpr::new_map(X, TypeExpr::new_tensor({X, Unit}))),
                      AsmOp::Nop());
  define_builtin_func("touch2", TypeExpr::new_forall({X, Y}, TypeExpr::new_map(XY, XY)), AsmOp::Nop());
  define_builtin_func("~touch2", TypeExpr::new_forall({X, Y}, TypeExpr::new_map(XY, TypeExpr::new_tensor({XY, Unit}))),
                      AsmOp::Nop());
  define_builtin_func("~dump", TypeExpr::new_forall({X}, TypeExpr::new_map(X, TypeExpr::new_tensor({X, Unit}))),
                      AsmOp::Custom("s0 DUMP", 1, 1), true);
  define_builtin_func("run_method0", TypeExpr::new_map(Int, Unit),
                      [](auto a, auto b, auto c) { return compile_run_method(a, b, c, 0, false); }, true);
  define_builtin_func("run_method1", TypeExpr::new_forall({X}, TypeExpr::new_map(TypeExpr::new_tensor({Int, X}), Unit)),
                      [](auto a, auto b, auto c) { return compile_run_method(a, b, c, 1, false); }, {1, 0}, {}, true);
  define_builtin_func(
      "run_method2", TypeExpr::new_forall({X, Y}, TypeExpr::new_map(TypeExpr::new_tensor({Int, X, Y}), Unit)),
      [](auto a, auto b, auto c) { return compile_run_method(a, b, c, 2, false); }, {1, 2, 0}, {}, true);
  define_builtin_func(
      "run_method3", TypeExpr::new_forall({X, Y, Z}, TypeExpr::new_map(TypeExpr::new_tensor({Int, X, Y, Z}), Unit)),
      [](auto a, auto b, auto c) { return compile_run_method(a, b, c, 3, false); }, {1, 2, 3, 0}, {}, true);
}

}  // namespace funC
