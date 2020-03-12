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
 *   GENERATE TVM STACK CODE
 * 
 */

StackLayout Stack::vars() const {
  StackLayout res;
  res.reserve(s.size());
  for (auto x : s) {
    res.push_back(x.first);
  }
  return res;
}

int Stack::find(var_idx_t var, int from) const {
  for (int i = from; i < depth(); i++) {
    if (at(i).first == var) {
      return i;
    }
  }
  return -1;
}

// finds var in [from .. to)
int Stack::find(var_idx_t var, int from, int to) const {
  for (int i = from; i < depth() && i < to; i++) {
    if (at(i).first == var) {
      return i;
    }
  }
  return -1;
}

// finds var outside [from .. to)
int Stack::find_outside(var_idx_t var, int from, int to) const {
  from = std::max(from, 0);
  if (from >= to) {
    return find(var);
  } else {
    int t = find(var, 0, from);
    return t >= 0 ? t : find(var, to);
  }
}

int Stack::find_const(const_idx_t cst, int from) const {
  for (int i = from; i < depth(); i++) {
    if (at(i).second == cst) {
      return i;
    }
  }
  return -1;
}

void Stack::forget_const() {
  for (auto& vc : s) {
    if (vc.second != not_const) {
      vc.second = not_const;
    }
  }
}

void Stack::issue_pop(int i) {
  validate(i);
  if (output_enabled()) {
    o << AsmOp::Pop(i);
  }
  at(i) = get(0);
  s.pop_back();
  modified();
}

void Stack::issue_push(int i) {
  validate(i);
  if (output_enabled()) {
    o << AsmOp::Push(i);
  }
  s.push_back(get(i));
  modified();
}

void Stack::issue_xchg(int i, int j) {
  validate(i);
  validate(j);
  if (i != j && get(i) != get(j)) {
    if (output_enabled()) {
      o << AsmOp::Xchg(i, j);
    }
    std::swap(at(i), at(j));
    modified();
  }
}

int Stack::drop_vars_except(const VarDescrList& var_info, int excl_var) {
  int dropped = 0, changes;
  do {
    changes = 0;
    int n = depth();
    for (int i = 0; i < n; i++) {
      var_idx_t idx = at(i).first;
      if (((!var_info[idx] || var_info[idx]->is_unused()) && idx != excl_var) || find(idx, 0, i - 1) >= 0) {
        // unneeded
        issue_pop(i);
        changes = 1;
        break;
      }
    }
    dropped += changes;
  } while (changes);
  return dropped;
}

void Stack::show(int flags) {
  std::ostringstream os;
  for (auto i : s) {
    os << ' ';
    o.show_var_ext(os, i);
  }
  o << AsmOp::Comment(os.str());
  mode |= _Shown;
}

void Stack::forget_var(var_idx_t idx) {
  for (auto& x : s) {
    if (x.first == idx) {
      x = std::make_pair(_Garbage, not_const);
      modified();
    }
  }
}

void Stack::push_new_var(var_idx_t idx) {
  forget_var(idx);
  s.emplace_back(idx, not_const);
  modified();
}

void Stack::push_new_const(var_idx_t idx, const_idx_t cidx) {
  forget_var(idx);
  s.emplace_back(idx, cidx);
  modified();
}

void Stack::assign_var(var_idx_t new_idx, var_idx_t old_idx) {
  int i = find(old_idx);
  assert(i >= 0 && "variable not found in stack");
  if (new_idx != old_idx) {
    at(i).first = new_idx;
    modified();
  }
}

void Stack::do_copy_var(var_idx_t new_idx, var_idx_t old_idx) {
  int i = find(old_idx);
  assert(i >= 0 && "variable not found in stack");
  if (find(old_idx, i + 1) < 0) {
    issue_push(i);
    assert(at(0).first == old_idx);
  }
  assign_var(new_idx, old_idx);
}

void Stack::enforce_state(const StackLayout& req_stack) {
  int k = (int)req_stack.size();
  for (int i = 0; i < k; i++) {
    var_idx_t x = req_stack[i];
    if (i < depth() && s[i].first == x) {
      continue;
    }
    while (depth() > 0 && std::find(req_stack.cbegin(), req_stack.cend(), get(0).first) == req_stack.cend()) {
      // current TOS entry is unused in req_stack, drop it
      issue_pop(0);
    }
    int j = find(x);
    if (j >= depth() - i) {
      issue_push(j);
      j = 0;
    }
    issue_xchg(j, depth() - i - 1);
    assert(s[i].first == x);
  }
  while (depth() > k) {
    issue_pop(0);
  }
  assert(depth() == k);
  for (int i = 0; i < k; i++) {
    assert(s[i].first == req_stack[i]);
  }
}

void Stack::merge_const(const Stack& req_stack) {
  assert(s.size() == req_stack.s.size());
  for (std::size_t i = 0; i < s.size(); i++) {
    assert(s[i].first == req_stack.s[i].first);
    if (s[i].second != req_stack.s[i].second) {
      s[i].second = not_const;
    }
  }
}

void Stack::merge_state(const Stack& req_stack) {
  enforce_state(req_stack.vars());
  merge_const(req_stack);
}

void Stack::rearrange_top(const StackLayout& top, std::vector<bool> last) {
  while (last.size() < top.size()) {
    last.push_back(false);
  }
  int k = (int)top.size();
  for (int i = 0; i < k; i++) {
    for (int j = i + 1; j < k; j++) {
      if (top[i] == top[j]) {
        last[i] = false;
        break;
      }
    }
  }
  int ss = 0;
  for (int i = 0; i < k; i++) {
    if (last[i]) {
      ++ss;
    }
  }
  for (int i = 0; i < k; i++) {
    var_idx_t x = top[i];
    // find s(j) containing x with j not in [ss, ss+i)
    int j = find_outside(x, ss, ss + i);
    if (last[i]) {
      // rearrange x to be at s(ss-1)
      issue_xchg(--ss, j);
      assert(get(ss).first == x);
    } else {
      // create a new copy of x
      issue_push(j);
      issue_xchg(0, ss);
      assert(get(ss).first == x);
    }
  }
  assert(!ss);
}

void Stack::rearrange_top(var_idx_t top, bool last) {
  int i = find(top);
  if (last) {
    issue_xchg(0, i);
  } else {
    issue_push(i);
  }
  assert(get(0).first == top);
}

bool Op::generate_code_step(Stack& stack) {
  stack.opt_show();
  stack.drop_vars_except(var_info);
  stack.opt_show();
  const auto& next_var_info = next->var_info;
  switch (cl) {
    case _Nop:
    case _Import:
      return true;
    case _Return: {
      stack.enforce_state(left);
      stack.opt_show();
      return false;
    }
    case _IntConst: {
      auto p = next_var_info[left[0]];
      if (!p || p->is_unused()) {
        return true;
      }
      auto cidx = stack.o.register_const(int_const);
      int i = stack.find_const(cidx);
      if (i < 0) {
        stack.o << push_const(int_const);
        stack.push_new_const(left[0], cidx);
      } else {
        assert(stack.at(i).second == cidx);
        stack.do_copy_var(left[0], stack[i]);
      }
      return true;
    }
    case _GlobVar:
      if (dynamic_cast<const SymValGlobVar*>(fun_ref->value)) {
        bool used = false;
        for (auto i : left) {
          auto p = next_var_info[i];
          if (p && !p->is_unused()) {
            used = true;
          }
        }
        if (!used || disabled()) {
          return true;
        }
        std::string name = sym::symbols.get_name(fun_ref->sym_idx);
        stack.o << AsmOp::Custom(name + " GETGLOB", 0, 1);
        if (left.size() != 1) {
          assert(left.size() <= 15);
          stack.o << AsmOp::UnTuple((int)left.size());
        }
        for (auto i : left) {
          stack.push_new_var(i);
        }
        return true;
      } else {
        assert(left.size() == 1);
        auto p = next_var_info[left[0]];
        if (!p || p->is_unused() || disabled()) {
          return true;
        }
        stack.o << "CONT:<{";
        stack.o.indent();
        auto func = dynamic_cast<SymValAsmFunc*>(fun_ref->value);
        if (func) {
          // TODO: create and compile a true lambda instead of this (so that arg_order and ret_order would work correctly)
          std::vector<VarDescr> args0, res;
          TypeExpr::remove_indirect(func->sym_type);
          assert(func->get_type()->is_map());
          auto wr = func->get_type()->args.at(0)->get_width();
          auto wl = func->get_type()->args.at(1)->get_width();
          assert(wl >= 0 && wr >= 0);
          for (int i = 0; i < wl; i++) {
            res.emplace_back(0);
          }
          for (int i = 0; i < wr; i++) {
            args0.emplace_back(0);
          }
          func->compile(stack.o, res, args0);  // compile res := f (args0)
        } else {
          std::string name = sym::symbols.get_name(fun_ref->sym_idx);
          stack.o << AsmOp::Custom(name + " CALLDICT", (int)right.size(), (int)left.size());
        }
        stack.o.undent();
        stack.o << "}>";
        stack.push_new_var(left.at(0));
        return true;
      }
    case _Let: {
      assert(left.size() == right.size());
      int i = 0;
      std::vector<bool> active;
      active.reserve(left.size());
      for (std::size_t k = 0; k < left.size(); k++) {
        var_idx_t y = left[k];  // "y" = "x"
        auto p = next_var_info[y];
        active.push_back(p && !p->is_unused());
      }
      for (std::size_t k = 0; k < left.size(); k++) {
        if (!active[k]) {
          continue;
        }
        var_idx_t x = right[k];  // "y" = "x"
        bool is_last = true;
        for (std::size_t l = k + 1; l < right.size(); l++) {
          if (right[l] == x && active[l]) {
            is_last = false;
          }
        }
        if (is_last) {
          auto info = var_info[x];
          is_last = (info && info->is_last());
        }
        if (is_last) {
          stack.assign_var(--i, x);
        } else {
          stack.do_copy_var(--i, x);
        }
      }
      i = 0;
      for (std::size_t k = 0; k < left.size(); k++) {
        if (active[k]) {
          stack.assign_var(left[k], --i);
        }
      }
      return true;
    }
    case _Tuple:
    case _UnTuple: {
      if (disabled()) {
        return true;
      }
      std::vector<bool> last;
      for (var_idx_t x : right) {
        last.push_back(var_info[x] && var_info[x]->is_last());
      }
      stack.rearrange_top(right, std::move(last));
      stack.opt_show();
      int k = (int)stack.depth() - (int)right.size();
      assert(k >= 0);
      if (cl == _Tuple) {
        stack.o << AsmOp::Tuple((int)right.size());
        assert(left.size() == 1);
      } else {
        stack.o << AsmOp::UnTuple((int)left.size());
        assert(right.size() == 1);
      }
      stack.s.resize(k);
      for (int i = 0; i < (int)left.size(); i++) {
        stack.push_new_var(left.at(i));
      }
      return true;
    }
    case _Call:
    case _CallInd: {
      if (disabled()) {
        return true;
      }
      SymValFunc* func = (fun_ref ? dynamic_cast<SymValFunc*>(fun_ref->value) : nullptr);
      auto arg_order = (func ? func->get_arg_order() : nullptr);
      auto ret_order = (func ? func->get_ret_order() : nullptr);
      assert(!arg_order || arg_order->size() == right.size());
      assert(!ret_order || ret_order->size() == left.size());
      std::vector<var_idx_t> right1;
      if (args.size()) {
        assert(args.size() == right.size());
        for (int i = 0; i < (int)right.size(); i++) {
          int j = arg_order ? arg_order->at(i) : i;
          const VarDescr& arg = args.at(j);
          if (!arg.is_unused()) {
            assert(var_info[arg.idx] && !var_info[arg.idx]->is_unused());
            right1.push_back(arg.idx);
          }
        }
      } else if (arg_order) {
        for (int i = 0; i < (int)right.size(); i++) {
          right1.push_back(right.at(arg_order->at(i)));
        }
      } else {
        right1 = right;
      }
      std::vector<bool> last;
      for (var_idx_t x : right1) {
        last.push_back(var_info[x] && var_info[x]->is_last());
      }
      stack.rearrange_top(right1, std::move(last));
      stack.opt_show();
      int k = (int)stack.depth() - (int)right1.size();
      assert(k >= 0);
      for (int i = 0; i < (int)right1.size(); i++) {
        if (stack.s[k + i].first != right1[i]) {
          std::cerr << stack.o;
        }
        assert(stack.s[k + i].first == right1[i]);
      }
      if (cl == _CallInd) {
        // TODO: replace with exec_arg2_op()
        stack.o << exec_arg2_op("CALLXARGS", (int)right.size() - 1, (int)left.size(), (int)right.size(),
                                (int)left.size());
      } else {
        auto func = dynamic_cast<const SymValAsmFunc*>(fun_ref->value);
        if (func) {
          std::vector<VarDescr> res;
          res.reserve(left.size());
          for (var_idx_t i : left) {
            res.emplace_back(i);
          }
          func->compile(stack.o, res, args);  // compile res := f (args)
        } else {
          auto fv = dynamic_cast<const SymValCodeFunc*>(fun_ref->value);
          std::string name = sym::symbols.get_name(fun_ref->sym_idx);
          bool is_inline = (fv && (fv->flags & 3));
          stack.o << AsmOp::Custom(name + (is_inline ? " INLINECALLDICT" : " CALLDICT"), (int)right.size(),
                                   (int)left.size());
        }
      }
      stack.s.resize(k);
      for (int i = 0; i < (int)left.size(); i++) {
        int j = ret_order ? ret_order->at(i) : i;
        stack.push_new_var(left.at(j));
      }
      return true;
    }
    case _SetGlob: {
      assert(fun_ref && dynamic_cast<const SymValGlobVar*>(fun_ref->value));
      std::vector<bool> last;
      for (var_idx_t x : right) {
        last.push_back(var_info[x] && var_info[x]->is_last());
      }
      stack.rearrange_top(right, std::move(last));
      stack.opt_show();
      int k = (int)stack.depth() - (int)right.size();
      assert(k >= 0);
      for (int i = 0; i < (int)right.size(); i++) {
        if (stack.s[k + i].first != right[i]) {
          std::cerr << stack.o;
        }
        assert(stack.s[k + i].first == right[i]);
      }
      if (right.size() > 1) {
        stack.o << AsmOp::Tuple((int)right.size());
      }
      if (!right.empty()) {
        std::string name = sym::symbols.get_name(fun_ref->sym_idx);
        stack.o << AsmOp::Custom(name + " SETGLOB", 1, 0);
      }
      stack.s.resize(k);
      return true;
    }
    case _If: {
      if (block0->is_empty() && block1->is_empty()) {
        return true;
      }
      if (!next->noreturn() && (block0->noreturn() != block1->noreturn())) {
        // simple fix of unbalanced returns in if/else branches
        // (to be replaced with a finer condition working in loop bodies)
        throw src::ParseError{where, "`if` and `else` branches should both return or both not return"};
      }
      var_idx_t x = left[0];
      stack.rearrange_top(x, var_info[x] && var_info[x]->is_last());
      assert(stack[0] == x);
      stack.opt_show();
      stack.s.pop_back();
      stack.modified();
      if (block1->is_empty()) {
        // if (left) block0; ...
        if (block0->noreturn()) {
          stack.o << "IFJMP:<{";
          stack.o.indent();
          Stack stack_copy{stack};
          block0->generate_code_all(stack_copy);
          stack.o.undent();
          stack.o << "}>";
          return true;
        }
        stack.o << "IF:<{";
        stack.o.indent();
        Stack stack_copy{stack}, stack_target{stack};
        stack_target.disable_output();
        stack_target.drop_vars_except(next->var_info);
        block0->generate_code_all(stack_copy);
        stack_copy.drop_vars_except(var_info);
        stack_copy.opt_show();
        if (stack_copy == stack) {
          stack.o.undent();
          stack.o << "}>";
          return true;
        }
        // stack_copy.drop_vars_except(next->var_info);
        stack_copy.enforce_state(stack_target.vars());
        stack_copy.opt_show();
        if (stack_copy.vars() == stack.vars()) {
          stack.o.undent();
          stack.o << "}>";
          stack.merge_const(stack_copy);
          return true;
        }
        stack.o.undent();
        stack.o << "}>ELSE<{";
        stack.o.indent();
        stack.merge_state(stack_copy);
        stack.opt_show();
        stack.o.undent();
        stack.o << "}>";
        return true;
      }
      if (block0->is_empty()) {
        // if (!left) block1; ...
        if (block1->noreturn()) {
          stack.o << "IFNOTJMP:<{";
          stack.o.indent();
          Stack stack_copy{stack};
          block1->generate_code_all(stack_copy);
          stack.o.undent();
          stack.o << "}>";
          return true;
        }
        stack.o << "IFNOT:<{";
        stack.o.indent();
        Stack stack_copy{stack}, stack_target{stack};
        stack_target.disable_output();
        stack_target.drop_vars_except(next->var_info);
        block1->generate_code_all(stack_copy);
        stack_copy.drop_vars_except(var_info);
        stack_copy.opt_show();
        if (stack_copy.vars() == stack.vars()) {
          stack.o.undent();
          stack.o << "}>";
          stack.merge_const(stack_copy);
          return true;
        }
        // stack_copy.drop_vars_except(next->var_info);
        stack_copy.enforce_state(stack_target.vars());
        stack_copy.opt_show();
        if (stack_copy.vars() == stack.vars()) {
          stack.o.undent();
          stack.o << "}>";
          stack.merge_const(stack_copy);
          return true;
        }
        stack.o.undent();
        stack.o << "}>ELSE<{";
        stack.o.indent();
        stack.merge_state(stack_copy);
        stack.opt_show();
        stack.o.undent();
        stack.o << "}>";
        return true;
      }
      if (block0->noreturn()) {
        stack.o << "IFJMP:<{";
        stack.o.indent();
        Stack stack_copy{stack};
        block0->generate_code_all(stack_copy);
        stack.o.undent();
        stack.o << "}>";
        return block1->generate_code_all(stack);
      }
      if (block1->noreturn()) {
        stack.o << "IFNOTJMP:<{";
        stack.o.indent();
        Stack stack_copy{stack};
        block1->generate_code_all(stack_copy);
        stack.o.undent();
        stack.o << "}>";
        return block0->generate_code_all(stack);
      }
      stack.o << "IF:<{";
      stack.o.indent();
      Stack stack_copy{stack};
      block0->generate_code_all(stack_copy);
      stack_copy.drop_vars_except(next->var_info);
      stack_copy.opt_show();
      stack.o.undent();
      stack.o << "}>ELSE<{";
      stack.o.indent();
      block1->generate_code_all(stack);
      stack.merge_state(stack_copy);
      stack.opt_show();
      stack.o.undent();
      stack.o << "}>";
      return true;
    }
    case _Repeat: {
      var_idx_t x = left[0];
      //stack.drop_vars_except(block0->var_info, x);
      stack.rearrange_top(x, var_info[x] && var_info[x]->is_last());
      assert(stack[0] == x);
      stack.opt_show();
      stack.s.pop_back();
      stack.modified();
      if (true || !next->is_empty()) {
        stack.o << "REPEAT:<{";
        stack.o.indent();
        stack.forget_const();
        StackLayout layout1 = stack.vars();
        block0->generate_code_all(stack);
        stack.enforce_state(std::move(layout1));
        stack.opt_show();
        stack.o.undent();
        stack.o << "}>";
        return true;
      } else {
        stack.o << "REPEATEND";
        stack.forget_const();
        StackLayout layout1 = stack.vars();
        block0->generate_code_all(stack);
        stack.enforce_state(std::move(layout1));
        stack.opt_show();
        return false;
      }
    }
    case _Again: {
      stack.drop_vars_except(block0->var_info);
      stack.opt_show();
      if (!next->is_empty()) {
        stack.o << "AGAIN:<{";
        stack.o.indent();
        stack.forget_const();
        StackLayout layout1 = stack.vars();
        block0->generate_code_all(stack);
        stack.enforce_state(std::move(layout1));
        stack.opt_show();
        stack.o.undent();
        stack.o << "}>";
        return true;
      } else {
        stack.o << "AGAINEND";
        stack.forget_const();
        StackLayout layout1 = stack.vars();
        block0->generate_code_all(stack);
        stack.enforce_state(std::move(layout1));
        stack.opt_show();
        return false;
      }
    }
    case _Until: {
      // stack.drop_vars_except(block0->var_info);
      // stack.opt_show();
      if (true || !next->is_empty()) {
        stack.o << "UNTIL:<{";
        stack.o.indent();
        stack.forget_const();
        auto layout1 = stack.vars();
        block0->generate_code_all(stack);
        layout1.push_back(left[0]);
        stack.enforce_state(std::move(layout1));
        stack.opt_show();
        stack.o.undent();
        stack.o << "}>";
        stack.s.pop_back();
        stack.modified();
        return true;
      } else {
        stack.o << "UNTILEND";
        stack.forget_const();
        StackLayout layout1 = stack.vars();
        block0->generate_code_all(stack);
        layout1.push_back(left[0]);
        stack.enforce_state(std::move(layout1));
        stack.opt_show();
        return false;
      }
    }
    case _While: {
      // while (block0 | left) block1; ...next
      var_idx_t x = left[0];
      stack.drop_vars_except(block0->var_info);
      stack.opt_show();
      StackLayout layout1 = stack.vars();
      bool next_empty = false && next->is_empty();
      stack.o << "WHILE:<{";
      stack.o.indent();
      stack.forget_const();
      block0->generate_code_all(stack);
      stack.rearrange_top(x, !next->var_info[x] && !block1->var_info[x]);
      stack.opt_show();
      stack.s.pop_back();
      stack.modified();
      stack.o.undent();
      Stack stack_copy{stack};
      stack.o << (next_empty ? "}>DO:" : "}>DO<{");
      if (!next_empty) {
        stack.o.indent();
      }
      stack_copy.opt_show();
      block1->generate_code_all(stack_copy);
      stack_copy.enforce_state(std::move(layout1));
      stack_copy.opt_show();
      if (!next_empty) {
        stack.o.undent();
        stack.o << "}>";
        return true;
      } else {
        return false;
      }
    }
    default:
      std::cerr << "fatal: unknown operation <??" << cl << ">\n";
      throw src::ParseError{where, "unknown operation in generate_code()"};
  }
}

bool Op::generate_code_all(Stack& stack) {
  if (generate_code_step(stack) && next) {
    return next->generate_code_all(stack);
  } else {
    return false;
  }
}

void CodeBlob::generate_code(AsmOpList& out, int mode) {
  Stack stack{out, mode};
  assert(ops && ops->cl == Op::_Import);
  for (var_idx_t x : ops->left) {
    stack.push_new_var(x);
  }
  ops->generate_code_all(stack);
  if (!(mode & Stack::_DisableOpt)) {
    optimize_code(out);
  }
}

void CodeBlob::generate_code(std::ostream& os, int mode, int indent) {
  AsmOpList out_list(indent, &vars);
  generate_code(out_list, mode);
  out_list.out(os, mode);
}

}  // namespace funC
