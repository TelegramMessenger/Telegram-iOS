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
 *   PEEPHOLE OPTIMIZER
 * 
 */

void Optimizer::set_code(AsmOpConsList code) {
  code_ = std::move(code);
  unpack();
}

void Optimizer::unpack() {
  int i = 0, j = 0;
  for (AsmOpCons *p = code_.get(); p && i < n; p = p->cdr.get(), ++j) {
    if (p->car->is_very_custom()) {
      break;
    }
    if (p->car->is_comment()) {
      continue;
    }
    op_cons_[i] = p;
    op_[i] = std::move(p->car);
    offs_[i] = j;
    ++i;
  }
  l_ = i;
  indent_ = (i ? op_[0]->indent : 0);
}

void Optimizer::pack() {
  for (int i = 0; i < l_; i++) {
    op_cons_[i]->car = std::move(op_[i]);
    op_cons_[i] = nullptr;
  }
  l_ = 0;
}

void Optimizer::apply() {
  if (!p_ && !q_) {
    return;
  }
  assert(p_ > 0 && p_ <= l_ && q_ >= 0 && q_ <= n && l_ <= n);
  for (int i = p_; i < l_; i++) {
    assert(op_[i]);
    op_cons_[i]->car = std::move(op_[i]);
    op_cons_[i] = nullptr;
  }
  for (int c = offs_[p_ - 1]; c >= 0; --c) {
    code_ = std::move(code_->cdr);
  }
  for (int j = q_ - 1; j >= 0; j--) {
    assert(oq_[j]);
    oq_[j]->indent = indent_;
    code_ = AsmOpCons::cons(std::move(oq_[j]), std::move(code_));
  }
  l_ = 0;
}

AsmOpConsList Optimizer::extract_code() {
  pack();
  return std::move(code_);
}

void Optimizer::show_head() const {
  if (!debug_) {
    return;
  }
  std::cerr << "optimizing";
  for (int i = 0; i < l_; i++) {
    if (op_[i]) {
      std::cerr << ' ' << *op_[i] << ' ';
    } else {
      std::cerr << " (null) ";
    }
  }
  std::cerr << std::endl;
}

void Optimizer::show_left() const {
  if (!debug_) {
    return;
  }
  std::cerr << "// *** rewriting";
  for (int i = 0; i < p_; i++) {
    if (op_[i]) {
      std::cerr << ' ' << *op_[i] << ' ';
    } else {
      std::cerr << " (null) ";
    }
  }
}

void Optimizer::show_right() const {
  if (!debug_) {
    return;
  }
  std::cerr << "->";
  for (int i = 0; i < q_; i++) {
    if (oq_[i]) {
      std::cerr << ' ' << *oq_[i] << ' ';
    } else {
      std::cerr << " (null) ";
    }
  }
  std::cerr << std::endl;
}

bool Optimizer::say(std::string str) const {
  if (debug_) {
    std::cerr << str << std::endl;
  }
  return true;
}

bool Optimizer::find_const_op(int* op_idx, int cst) {
  for (int i = 0; i < l2_; i++) {
    if (op_[i]->is_gconst() && tr_[i].get(0) == cst) {
      *op_idx = i;
      return true;
    }
  }
  return false;
}

bool Optimizer::is_push_const(int* i, int* c) const {
  return pb_ >= 3 && pb_ <= l2_ && tr_[pb_ - 1].is_push_const(i, c);
}

// PUSHCONST c ; PUSH s(i+1) ; SWAP -> PUSH s(i) ; PUSHCONST c
bool Optimizer::rewrite_push_const(int i, int c) {
  p_ = pb_;
  q_ = 2;
  int idx = -1;
  if (!(p_ >= 2 && find_const_op(&idx, c) && idx < p_)) {
    return false;
  }
  show_left();
  oq_[1] = std::move(op_[idx]);
  oq_[0] = std::move(op_[!idx]);
  *oq_[0] = AsmOp::Push(i);
  show_right();
  return true;
}

bool Optimizer::is_const_rot(int* c) const {
  return pb_ >= 3 && pb_ <= l2_ && tr_[pb_ - 1].is_const_rot(c);
}

bool Optimizer::rewrite_const_rot(int c) {
  p_ = pb_;
  q_ = 2;
  int idx = -1;
  if (!(p_ >= 2 && find_const_op(&idx, c) && idx < p_)) {
    return false;
  }
  show_left();
  oq_[0] = std::move(op_[idx]);
  oq_[1] = std::move(op_[!idx]);
  *oq_[1] = AsmOp::Custom("ROT", 3, 3);
  show_right();
  return true;
}

bool Optimizer::is_const_pop(int* c, int* i) const {
  return pb_ >= 3 && pb_ <= l2_ && tr_[pb_ - 1].is_const_pop(c, i);
}

bool Optimizer::rewrite_const_pop(int c, int i) {
  p_ = pb_;
  q_ = 2;
  int idx = -1;
  if (!(p_ >= 2 && find_const_op(&idx, c) && idx < p_)) {
    return false;
  }
  show_left();
  oq_[0] = std::move(op_[idx]);
  oq_[1] = std::move(op_[!idx]);
  *oq_[1] = AsmOp::Pop(i);
  show_right();
  return true;
}

bool Optimizer::is_const_push_xchgs() {
  if (!(pb_ >= 2 && pb_ <= l2_ && op_[0]->is_gconst())) {
    return false;
  }
  StackTransform t;
  int pos = 0, i;
  for (i = 1; i < pb_; i++) {
    int a, b;
    if (op_[i]->is_xchg(&a, &b)) {
      if (pos == a) {
        pos = b;
      } else if (pos == b) {
        pos = a;
      } else {
        t.apply_xchg(a - (a > pos), b - (b > pos));
      }
    } else if (op_[i]->is_push(&a)) {
      if (pos == a) {
        return false;
      }
      t.apply_push(a - (a > pos));
      ++pos;
    } else {
      return false;
    }
  }
  if (pos) {
    return false;
  }
  t.apply_push_newconst();
  if (t <= tr_[i - 1]) {
    p_ = i;
    return true;
  } else {
    return false;
  }
}

bool Optimizer::rewrite_const_push_xchgs() {
  if (!p_) {
    return false;
  }
  show_left();
  auto c_op = std::move(op_[0]);
  assert(c_op->is_gconst());
  StackTransform t;
  q_ = 0;
  int pos = 0;
  for (int i = 1; i < p_; i++) {
    int a, b;
    if (op_[i]->is_xchg(&a, &b)) {
      if (a == pos) {
        pos = b;
      } else if (b == pos) {
        pos = a;
      } else {
        oq_[q_] = std::move(op_[i]);
        if (a > pos) {
          oq_[q_]->a = a - 1;
        }
        if (b > pos) {
          oq_[q_]->b = b - 1;
        }
        assert(apply_op(t, *oq_[q_]));
        ++q_;
      }
    } else {
      assert(op_[i]->is_push(&a));
      assert(a != pos);
      oq_[q_] = std::move(op_[i]);
      if (a > pos) {
        oq_[q_]->a = a - 1;
      }
      assert(apply_op(t, *oq_[q_]));
      ++q_;
      ++pos;
    }
  }
  assert(!pos);
  t.apply_push_newconst();
  assert(t <= tr_[p_ - 1]);
  oq_[q_++] = std::move(c_op);
  show_right();
  return true;
}

bool Optimizer::rewrite(int p, AsmOp&& new_op) {
  assert(p > 0 && p <= l_);
  p_ = p;
  q_ = 1;
  show_left();
  oq_[0] = std::move(op_[0]);
  *oq_[0] = new_op;
  show_right();
  return true;
}

bool Optimizer::rewrite(int p, AsmOp&& new_op1, AsmOp&& new_op2) {
  assert(p > 1 && p <= l_);
  p_ = p;
  q_ = 2;
  show_left();
  oq_[0] = std::move(op_[0]);
  *oq_[0] = new_op1;
  oq_[1] = std::move(op_[1]);
  *oq_[1] = new_op2;
  show_right();
  return true;
}

bool Optimizer::rewrite(int p, AsmOp&& new_op1, AsmOp&& new_op2, AsmOp&& new_op3) {
  assert(p > 2 && p <= l_);
  p_ = p;
  q_ = 3;
  show_left();
  oq_[0] = std::move(op_[0]);
  *oq_[0] = new_op1;
  oq_[1] = std::move(op_[1]);
  *oq_[1] = new_op2;
  oq_[2] = std::move(op_[2]);
  *oq_[2] = new_op3;
  show_right();
  return true;
}

bool Optimizer::rewrite_nop() {
  assert(p_ > 0 && p_ <= l_);
  q_ = 0;
  show_left();
  show_right();
  return true;
}

bool Optimizer::is_pred(const std::function<bool(const StackTransform&)>& pred, int min_p) {
  min_p = std::max(min_p, pb_);
  for (int p = l2_; p >= min_p; p--) {
    if (pred(tr_[p - 1])) {
      p_ = p;
      return true;
    }
  }
  return false;
}

bool Optimizer::is_same_as(const StackTransform& trans, int min_p) {
  return is_pred([&trans](const auto& t) { return t >= trans; }, min_p);
}

// s1 s3 XCHG ; s0 s2 XCHG -> 2SWAP
bool Optimizer::is_2swap() {
  static const StackTransform t_2swap{2, 3, 0, 1, 4};
  return is_same_as(t_2swap);
}

// s3 PUSH ; s3 PUSH -> 2OVER
bool Optimizer::is_2over() {
  static const StackTransform t_2over{2, 3, 0};
  return is_same_as(t_2over);
}

bool Optimizer::is_2dup() {
  static const StackTransform t_2dup{0, 1, 0};
  return is_same_as(t_2dup);
}

bool Optimizer::is_tuck() {
  static const StackTransform t_tuck{0, 1, 0, 2};
  return is_same_as(t_tuck);
}

bool Optimizer::is_2drop() {
  static const StackTransform t_2drop{2};
  return is_same_as(t_2drop);
}

bool Optimizer::is_rot() {
  return is_pred([](const auto& t) { return t.is_rot(); });
}

bool Optimizer::is_rotrev() {
  return is_pred([](const auto& t) { return t.is_rotrev(); });
}

bool Optimizer::is_nop() {
  return is_pred([](const auto& t) { return t.is_id(); }, 1);
}

bool Optimizer::is_xchg(int* i, int* j) {
  return is_pred([i, j](const auto& t) { return t.is_xchg(i, j) && ((*i < 16 && *j < 16) || (!*i && *j < 256)); });
}

bool Optimizer::is_xchg_xchg(int* i, int* j, int* k, int* l) {
  return is_pred([i, j, k, l](const auto& t) {
           return t.is_xchg_xchg(i, j, k, l) && (*i < 2 && *j < (*i ? 16 : 256) && *k < 2 && *l < (*k ? 16 : 256));
         }) &&
         (!(p_ == 2 && op_[0]->is_xchg(*i, *j) && op_[1]->is_xchg(*k, *l)));
}

bool Optimizer::is_push(int* i) {
  return is_pred([i](const auto& t) { return t.is_push(i) && *i < 256; });
}

bool Optimizer::is_pop(int* i) {
  return is_pred([i](const auto& t) { return t.is_pop(i) && *i < 256; });
}

bool Optimizer::is_pop_pop(int* i, int* j) {
  return is_pred([i, j](const auto& t) { return t.is_pop_pop(i, j) && *i < 256 && *j < 256; }, 3);
}

bool Optimizer::is_push_rot(int* i) {
  return is_pred([i](const auto& t) { return t.is_push_rot(i) && *i < 16; }, 3);
}

bool Optimizer::is_push_rotrev(int* i) {
  return is_pred([i](const auto& t) { return t.is_push_rotrev(i) && *i < 16; }, 3);
}

bool Optimizer::is_push_xchg(int* i, int* j, int* k) {
  return is_pred([i, j, k](const auto& t) { return t.is_push_xchg(i, j, k) && *i < 16 && *j < 16 && *k < 16; }) &&
         !(p_ == 2 && op_[0]->is_push() && op_[1]->is_xchg());
}

bool Optimizer::is_xchg2(int* i, int* j) {
  return is_pred([i, j](const auto& t) { return t.is_xchg2(i, j) && *i < 16 && *j < 16; });
}

bool Optimizer::is_xcpu(int* i, int* j) {
  return is_pred([i, j](const auto& t) { return t.is_xcpu(i, j) && *i < 16 && *j < 16; });
}

bool Optimizer::is_puxc(int* i, int* j) {
  return is_pred([i, j](const auto& t) { return t.is_puxc(i, j) && *i < 16 && *j < 15; });
}

bool Optimizer::is_push2(int* i, int* j) {
  return is_pred([i, j](const auto& t) { return t.is_push2(i, j) && *i < 16 && *j < 16; });
}

bool Optimizer::is_xchg3(int* i, int* j, int* k) {
  return is_pred([i, j, k](const auto& t) { return t.is_xchg3(i, j, k) && *i < 16 && *j < 16 && *k < 16; });
}

bool Optimizer::is_xc2pu(int* i, int* j, int* k) {
  return is_pred([i, j, k](const auto& t) { return t.is_xc2pu(i, j, k) && *i < 16 && *j < 16 && *k < 16; });
}

bool Optimizer::is_xcpuxc(int* i, int* j, int* k) {
  return is_pred([i, j, k](const auto& t) { return t.is_xcpuxc(i, j, k) && *i < 16 && *j < 16 && *k < 15; });
}

bool Optimizer::is_xcpu2(int* i, int* j, int* k) {
  return is_pred([i, j, k](const auto& t) { return t.is_xcpu2(i, j, k) && *i < 16 && *j < 16 && *k < 16; });
}

bool Optimizer::is_puxc2(int* i, int* j, int* k) {
  return is_pred(
      [i, j, k](const auto& t) { return t.is_puxc2(i, j, k) && *i < 16 && *j < 15 && *k < 15 && *j + *k != -1; });
}

bool Optimizer::is_puxcpu(int* i, int* j, int* k) {
  return is_pred([i, j, k](const auto& t) { return t.is_puxcpu(i, j, k) && *i < 16 && *j < 15 && *k < 15; });
}

bool Optimizer::is_pu2xc(int* i, int* j, int* k) {
  return is_pred([i, j, k](const auto& t) { return t.is_pu2xc(i, j, k) && *i < 16 && *j < 15 && *k < 14; });
}

bool Optimizer::is_push3(int* i, int* j, int* k) {
  return is_pred([i, j, k](const auto& t) { return t.is_push3(i, j, k) && *i < 16 && *j < 16 && *k < 16; });
}

bool Optimizer::is_blkswap(int* i, int* j) {
  return is_pred([i, j](const auto& t) { return t.is_blkswap(i, j) && *i > 0 && *j > 0 && *i <= 16 && *j <= 16; });
}

bool Optimizer::is_blkpush(int* i, int* j) {
  return is_pred([i, j](const auto& t) { return t.is_blkpush(i, j) && *i > 0 && *i < 16 && *j < 16; });
}

bool Optimizer::is_blkdrop(int* i) {
  return is_pred([i](const auto& t) { return t.is_blkdrop(i) && *i > 0 && *i < 16; });
}

bool Optimizer::is_blkdrop2(int* i, int* j) {
  return is_pred([i, j](const auto& t) { return t.is_blkdrop2(i, j) && *i > 0 && *i < 16 && *j > 0 && *j < 16; });
}

bool Optimizer::is_reverse(int* i, int* j) {
  return is_pred([i, j](const auto& t) { return t.is_reverse(i, j) && *i >= 2 && *i <= 17 && *j < 16; });
}

bool Optimizer::is_nip_seq(int* i, int* j) {
  return is_pred([i, j](const auto& t) { return t.is_nip_seq(i, j) && *i >= 3 && *i <= 15; });
}

bool Optimizer::is_pop_blkdrop(int* i, int* k) {
  return is_pred([i, k](const auto& t) { return t.is_pop_blkdrop(i, k) && *i >= *k && *k >= 2 && *k <= 15; }, 3);
}

bool Optimizer::is_2pop_blkdrop(int* i, int* j, int* k) {
  return is_pred(
      [i, j, k](const auto& t) { return t.is_2pop_blkdrop(i, j, k) && *i >= *k && *j >= *k && *k >= 2 && *k <= 15; },
      3);
}

bool Optimizer::compute_stack_transforms() {
  StackTransform trans;
  for (int i = 0; i < l_; i++) {
    if (!apply_op(trans, *op_[i])) {
      l2_ = i;
      return true;
    }
    tr_[i] = trans;
  }
  l2_ = l_;
  return true;
}

bool Optimizer::show_stack_transforms() const {
  show_head();
  // slow version
  /*
  StackTransform trans2;
  std::cerr << "id = " << trans2 << std::endl;
  for (int i = 0; i < l_; i++) {
    StackTransform op;
    if (!apply_op(op, *op_[i])) {
      std::cerr << "* (" << *op_[i] << " = invalid)\n";
      break;
    }
    trans2 *= op;
    std::cerr << "* " << *op_[i] << " = " << op << " -> " << trans2 << std::endl;
  }
  */
  // fast version
  StackTransform trans;
  for (int i = 0; i < l_; i++) {
    std::cerr << trans << std::endl << *op_[i] << " -> ";
    if (!apply_op(trans, *op_[i])) {
      std::cerr << " <not-applicable>" << std::endl;
      return true;
    }
  }
  std::cerr << trans << std::endl;
  return true;
}

bool Optimizer::find_at_least(int pb) {
  p_ = q_ = 0;
  pb_ = pb;
  // show_stack_transforms();
  int i, j, k, l, c;
  return (is_push_const(&i, &c) && rewrite_push_const(i, c)) || (is_nop() && rewrite_nop()) ||
         (!(mode_ & 1) && is_const_rot(&c) && rewrite_const_rot(c)) ||
         (is_const_push_xchgs() && rewrite_const_push_xchgs()) || (is_const_pop(&c, &i) && rewrite_const_pop(c, i)) ||
         (is_xchg(&i, &j) && rewrite(AsmOp::Xchg(i, j))) || (is_push(&i) && rewrite(AsmOp::Push(i))) ||
         (is_pop(&i) && rewrite(AsmOp::Pop(i))) || (is_pop_pop(&i, &j) && rewrite(AsmOp::Pop(i), AsmOp::Pop(j))) ||
         (is_xchg_xchg(&i, &j, &k, &l) && rewrite(AsmOp::Xchg(i, j), AsmOp::Xchg(k, l))) ||
         (!(mode_ & 1) &&
          ((is_rot() && rewrite(AsmOp::Custom("ROT", 3, 3))) || (is_rotrev() && rewrite(AsmOp::Custom("-ROT", 3, 3))) ||
           (is_2dup() && rewrite(AsmOp::Custom("2DUP", 2, 4))) ||
           (is_2swap() && rewrite(AsmOp::Custom("2SWAP", 2, 4))) ||
           (is_2over() && rewrite(AsmOp::Custom("2OVER", 2, 4))) ||
           (is_tuck() && rewrite(AsmOp::Custom("TUCK", 2, 3))) ||
           (is_2drop() && rewrite(AsmOp::Custom("2DROP", 2, 0))) || (is_xchg2(&i, &j) && rewrite(AsmOp::Xchg2(i, j))) ||
           (is_xcpu(&i, &j) && rewrite(AsmOp::XcPu(i, j))) || (is_puxc(&i, &j) && rewrite(AsmOp::PuXc(i, j))) ||
           (is_push2(&i, &j) && rewrite(AsmOp::Push2(i, j))) || (is_blkswap(&i, &j) && rewrite(AsmOp::BlkSwap(i, j))) ||
           (is_blkpush(&i, &j) && rewrite(AsmOp::BlkPush(i, j))) || (is_blkdrop(&i) && rewrite(AsmOp::BlkDrop(i))) ||
           (is_push_rot(&i) && rewrite(AsmOp::Push(i), AsmOp::Custom("ROT"))) ||
           (is_push_rotrev(&i) && rewrite(AsmOp::Push(i), AsmOp::Custom("-ROT"))) ||
           (is_push_xchg(&i, &j, &k) && rewrite(AsmOp::Push(i), AsmOp::Xchg(j, k))) ||
           (is_reverse(&i, &j) && rewrite(AsmOp::BlkReverse(i, j))) ||
           (is_blkdrop2(&i, &j) && rewrite(AsmOp::BlkDrop2(i, j))) ||
           (is_nip_seq(&i, &j) && rewrite(AsmOp::Xchg(i, j), AsmOp::BlkDrop(i))) ||
           (is_pop_blkdrop(&i, &k) && rewrite(AsmOp::Pop(i), AsmOp::BlkDrop(k))) ||
           (is_2pop_blkdrop(&i, &j, &k) && (k >= 3 && k <= 13 && i != j + 1 && i <= 15 && j <= 14
                                                ? rewrite(AsmOp::Xchg2(j + 1, i), AsmOp::BlkDrop(k + 2))
                                                : rewrite(AsmOp::Pop(i), AsmOp::Pop(j), AsmOp::BlkDrop(k)))) ||
           (is_xchg3(&i, &j, &k) && rewrite(AsmOp::Xchg3(i, j, k))) ||
           (is_xc2pu(&i, &j, &k) && rewrite(AsmOp::Xc2Pu(i, j, k))) ||
           (is_xcpuxc(&i, &j, &k) && rewrite(AsmOp::XcPuXc(i, j, k))) ||
           (is_xcpu2(&i, &j, &k) && rewrite(AsmOp::XcPu2(i, j, k))) ||
           (is_puxc2(&i, &j, &k) && rewrite(AsmOp::PuXc2(i, j, k))) ||
           (is_puxcpu(&i, &j, &k) && rewrite(AsmOp::PuXcPu(i, j, k))) ||
           (is_pu2xc(&i, &j, &k) && rewrite(AsmOp::Pu2Xc(i, j, k))) ||
           (is_push3(&i, &j, &k) && rewrite(AsmOp::Push3(i, j, k)))));
}

bool Optimizer::find() {
  if (!compute_stack_transforms()) {
    return false;
  }
  for (int pb = l_; pb > 0; --pb) {
    if (find_at_least(pb)) {
      return true;
    }
  }
  return false;
}

bool Optimizer::optimize() {
  bool f = false;
  while (find()) {
    f = true;
    apply();
    unpack();
  }
  return f;
}

AsmOpConsList optimize_code_head(AsmOpConsList op_list, int mode) {
  Optimizer opt(std::move(op_list), op_rewrite_comments, mode);
  opt.optimize();
  return opt.extract_code();
}

AsmOpConsList optimize_code(AsmOpConsList op_list, int mode) {
  std::vector<std::unique_ptr<AsmOp>> v;
  while (op_list) {
    if (!op_list->car->is_comment()) {
      op_list = optimize_code_head(std::move(op_list), mode);
    }
    if (op_list) {
      v.push_back(std::move(op_list->car));
      op_list = std::move(op_list->cdr);
    }
  }
  for (auto it = v.rbegin(); it < v.rend(); ++it) {
    op_list = AsmOpCons::cons(std::move(*it), std::move(op_list));
  }
  return std::move(op_list);
}

void optimize_code(AsmOpList& ops) {
  AsmOpConsList op_list;
  for (auto it = ops.list_.rbegin(); it < ops.list_.rend(); ++it) {
    op_list = AsmOpCons::cons(std::make_unique<AsmOp>(std::move(*it)), std::move(op_list));
  }
  for (int mode : {1, 1, 1, 1, 0, 0, 0, 0}) {
    op_list = optimize_code(std::move(op_list), mode);
  }
  ops.list_.clear();
  while (op_list) {
    ops.list_.push_back(std::move(*(op_list->car)));
    op_list = std::move(op_list->cdr);
  }
}

}  // namespace funC
