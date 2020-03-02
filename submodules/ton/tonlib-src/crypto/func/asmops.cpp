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
#include "parser/srcread.h"
#include "func.h"
#include <iostream>

namespace funC {

/*
 * 
 *   ASM-OP LIST FUNCTIONS
 * 
 */

int is_pos_pow2(td::RefInt256 x) {
  if (sgn(x) > 0 && !sgn(x & (x - 1))) {
    return x->bit_size(false) - 1;
  } else {
    return -1;
  }
}

int is_neg_pow2(td::RefInt256 x) {
  return sgn(x) < 0 ? is_pos_pow2(-x) : 0;
}

std::ostream& operator<<(std::ostream& os, AsmOp::SReg stack_reg) {
  int i = stack_reg.idx;
  if (i >= 0) {
    if (i < 16) {
      return os << 's' << i;
    } else {
      return os << i << " s()";
    }
  } else if (i >= -2) {
    return os << "s(" << i << ')';
  } else {
    return os << i << " s()";
  }
}

AsmOp AsmOp::Const(int arg, std::string push_op) {
  std::ostringstream os;
  os << arg << ' ' << push_op;
  return AsmOp::Const(os.str());
}

AsmOp AsmOp::make_stk2(int a, int b, const char* str, int delta) {
  std::ostringstream os;
  os << SReg(a) << ' ' << SReg(b) << ' ' << str;
  int c = std::max(a, b) + 1;
  return AsmOp::Custom(os.str(), c, c + delta);
}

AsmOp AsmOp::make_stk3(int a, int b, int c, const char* str, int delta) {
  std::ostringstream os;
  os << SReg(a) << ' ' << SReg(b) << ' ' << SReg(c) << ' ' << str;
  int m = std::max(a, std::max(b, c)) + 1;
  return AsmOp::Custom(os.str(), m, m + delta);
}

AsmOp AsmOp::BlkSwap(int a, int b) {
  std::ostringstream os;
  if (a == 1 && b == 1) {
    return AsmOp::Xchg(0, 1);
  } else if (a == 1) {
    if (b == 2) {
      os << "ROT";
    } else {
      os << b << " ROLL";
    }
  } else if (b == 1) {
    if (a == 2) {
      os << "-ROT";
    } else {
      os << a << " -ROLL";
    }
  } else {
    os << a << " " << b << " BLKSWAP";
  }
  return AsmOp::Custom(os.str(), a + b, a + b);
}

AsmOp AsmOp::BlkPush(int a, int b) {
  std::ostringstream os;
  if (a == 1) {
    return AsmOp::Push(b);
  } else if (a == 2 && b == 1) {
    os << "2DUP";
  } else {
    os << a << " " << b << " BLKPUSH";
  }
  return AsmOp::Custom(os.str(), b + 1, a + b + 1);
}

AsmOp AsmOp::BlkDrop(int a) {
  std::ostringstream os;
  if (a == 1) {
    return AsmOp::Pop();
  } else if (a == 2) {
    os << "2DROP";
  } else {
    os << a << " BLKDROP";
  }
  return AsmOp::Custom(os.str(), a, 0);
}

AsmOp AsmOp::BlkDrop2(int a, int b) {
  if (!b) {
    return BlkDrop(a);
  }
  std::ostringstream os;
  os << a << " " << b << " BLKDROP2";
  return AsmOp::Custom(os.str(), a + b, b);
}

AsmOp AsmOp::BlkReverse(int a, int b) {
  std::ostringstream os;
  os << a << " " << b << " REVERSE";
  return AsmOp::Custom(os.str(), a + b, a + b);
}

AsmOp AsmOp::Tuple(int a) {
  switch (a) {
    case 1:
      return AsmOp::Custom("SINGLE", 1, 1);
    case 2:
      return AsmOp::Custom("PAIR", 2, 1);
    case 3:
      return AsmOp::Custom("TRIPLE", 3, 1);
  }
  std::ostringstream os;
  os << a << " TUPLE";
  return AsmOp::Custom(os.str(), a, 1);
}

AsmOp AsmOp::UnTuple(int a) {
  switch (a) {
    case 1:
      return AsmOp::Custom("UNSINGLE", 1, 1);
    case 2:
      return AsmOp::Custom("UNPAIR", 1, 2);
    case 3:
      return AsmOp::Custom("UNTRIPLE", 1, 3);
  }
  std::ostringstream os;
  os << a << " UNTUPLE";
  return AsmOp::Custom(os.str(), 1, a);
}

AsmOp AsmOp::IntConst(td::RefInt256 x) {
  if (x->signed_fits_bits(8)) {
    return AsmOp::Const(dec_string(std::move(x)) + " PUSHINT");
  }
  if (!x->is_valid()) {
    return AsmOp::Const("PUSHNAN");
  }
  int k = is_pos_pow2(x);
  if (k >= 0) {
    return AsmOp::Const(k, "PUSHPOW2");
  }
  k = is_pos_pow2(x + 1);
  if (k >= 0) {
    return AsmOp::Const(k, "PUSHPOW2DEC");
  }
  k = is_pos_pow2(-x);
  if (k >= 0) {
    return AsmOp::Const(k, "PUSHNEGPOW2");
  }
  return AsmOp::Const(dec_string(std::move(x)) + " PUSHINT");
}

AsmOp AsmOp::BoolConst(bool f) {
  return AsmOp::Const(f ? "TRUE" : "FALSE");
}

AsmOp AsmOp::Parse(std::string custom_op) {
  if (custom_op == "NOP") {
    return AsmOp::Nop();
  } else if (custom_op == "SWAP") {
    return AsmOp::Xchg(1);
  } else if (custom_op == "DROP") {
    return AsmOp::Pop(0);
  } else if (custom_op == "NIP") {
    return AsmOp::Pop(1);
  } else if (custom_op == "DUP") {
    return AsmOp::Push(0);
  } else if (custom_op == "OVER") {
    return AsmOp::Push(1);
  } else {
    return AsmOp::Custom(custom_op);
  }
}

AsmOp AsmOp::Parse(std::string custom_op, int args, int retv) {
  auto res = Parse(custom_op);
  if (res.is_custom()) {
    res.a = args;
    res.b = retv;
  }
  return res;
}

void AsmOp::out(std::ostream& os) const {
  if (!op.empty()) {
    os << op;
    return;
  }
  switch (t) {
    case a_none:
      break;
    case a_xchg:
      if (!a && !(b & -2)) {
        os << (b ? "SWAP" : "NOP");
        break;
      }
      os << SReg(a) << ' ' << SReg(b) << " XCHG";
      break;
    case a_push:
      if (!(a & -2)) {
        os << (a ? "OVER" : "DUP");
        break;
      }
      os << SReg(a) << " PUSH";
      break;
    case a_pop:
      if (!(a & -2)) {
        os << (a ? "NIP" : "DROP");
        break;
      }
      os << SReg(a) << " POP";
      break;
    default:
      throw src::Fatal{"unknown assembler operation"};
  }
}

void AsmOp::out_indent_nl(std::ostream& os, bool no_eol) const {
  for (int i = 0; i < indent; i++) {
    os << "  ";
  }
  out(os);
  if (!no_eol) {
    os << std::endl;
  }
}

std::string AsmOp::to_string() const {
  if (!op.empty()) {
    return op;
  } else {
    std::ostringstream os;
    out(os);
    return os.str();
  }
}

bool AsmOpList::append(const std::vector<AsmOp>& ops) {
  for (const auto& op : ops) {
    if (!append(op)) {
      return false;
    }
  }
  return true;
}

const_idx_t AsmOpList::register_const(Const new_const) {
  if (new_const.is_null()) {
    return not_const;
  }
  unsigned idx;
  for (idx = 0; idx < constants_.size(); idx++) {
    if (!td::cmp(new_const, constants_[idx])) {
      return idx;
    }
  }
  constants_.push_back(std::move(new_const));
  return (const_idx_t)idx;
}

Const AsmOpList::get_const(const_idx_t idx) {
  if ((unsigned)idx < constants_.size()) {
    return constants_[idx];
  } else {
    return {};
  }
}

void AsmOpList::show_var(std::ostream& os, var_idx_t idx) const {
  if (!var_names_ || (unsigned)idx >= var_names_->size()) {
    os << '_' << idx;
  } else {
    var_names_->at(idx).show(os, 2);
  }
}

void AsmOpList::show_var_ext(std::ostream& os, std::pair<var_idx_t, const_idx_t> idx_pair) const {
  auto i = idx_pair.first;
  auto j = idx_pair.second;
  if (!var_names_ || (unsigned)i >= var_names_->size()) {
    os << '_' << i;
  } else {
    var_names_->at(i).show(os, 2);
  }
  if ((unsigned)j < constants_.size() && constants_[j].not_null()) {
    os << '=' << constants_[j];
  }
}

void AsmOpList::out(std::ostream& os, int mode) const {
  if (!(mode & 2)) {
    for (const auto& op : list_) {
      op.out_indent_nl(os);
    }
  } else {
    std::size_t n = list_.size();
    for (std::size_t i = 0; i < n; i++) {
      const auto& op = list_[i];
      if (!op.is_comment() && i + 1 < n && list_[i + 1].is_comment()) {
        op.out_indent_nl(os, true);
        os << '\t';
        do {
          i++;
        } while (i + 1 < n && list_[i + 1].is_comment());
        list_[i].out(os);
        os << std::endl;
      } else {
        op.out_indent_nl(os, false);
      }
    }
  }
}

bool apply_op(StackTransform& trans, const AsmOp& op) {
  if (!trans.is_valid()) {
    return false;
  }
  switch (op.t) {
    case AsmOp::a_none:
      return true;
    case AsmOp::a_xchg:
      return trans.apply_xchg(op.a, op.b, true);
    case AsmOp::a_push:
      return trans.apply_push(op.a);
    case AsmOp::a_pop:
      return trans.apply_pop(op.a);
    case AsmOp::a_const:
      return !op.a && op.b == 1 && trans.apply_push_newconst();
    case AsmOp::a_custom:
      return op.is_gconst() && trans.apply_push_newconst();
    default:
      return false;
  }
}

}  // namespace funC
