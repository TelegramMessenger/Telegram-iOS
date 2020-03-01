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
 *   GENERIC STACK TRANSFORMATIONS
 * 
 */

StackTransform::StackTransform(std::initializer_list<int> list) {
  *this = list;
}

StackTransform &StackTransform::operator=(std::initializer_list<int> list) {
  if (list.size() > 255) {
    invalidate();
    return *this;
  }
  set_id();
  if (!list.size()) {
    return *this;
  }
  int m = (int)list.size();
  d = list.begin()[m - 1] - (m - 1);
  if (d >= 128 || d < -128) {
    invalidate();
    return *this;
  }
  for (int i = 0; i < m - 1; i++) {
    int x = d + i;
    int y = list.begin()[i];
    if (y != x) {
      if (x != (short)x || y != (short)y || n == max_n) {
        invalidate();
        return *this;
      }
      dp = std::max(dp, std::max(x, y) + 1);
      A[n++] = std::make_pair((short)x, (short)y);
    }
  }
  return *this;
}

bool StackTransform::assign(const StackTransform &other) {
  if (!other.is_valid() || (unsigned)other.n > max_n) {
    return invalidate();
  }
  d = other.d;
  n = other.n;
  dp = other.dp;
  c = other.c;
  invalid = false;
  for (int i = 0; i < n; i++) {
    A[i] = other.A[i];
  }
  return true;
}

int StackTransform::get(int x) const {
  if (!is_valid()) {
    return -1;
  }
  if (x <= c_start) {
    return x - c;
  }
  x += d;
  int i;
  for (i = 0; i < n && A[i].first < x; i++) {
  }
  if (i < n && A[i].first == x) {
    return A[i].second;
  } else {
    return x;
  }
}

bool StackTransform::set(int x, int y, bool relaxed) {
  if (!is_valid()) {
    return false;
  }
  if (x < 0) {
    return (relaxed && y == x + d) || invalidate();
  }
  if (!relaxed) {
    touch(x);
  }
  x += d;
  int i;
  for (i = 0; i < n && A[i].first < x; i++) {
  }
  if (i < n && A[i].first == x) {
    if (x != y) {
      if (y != (short)y) {
        return invalidate();
      }
      A[i].second = (short)y;
    } else {
      --n;
      for (; i < n; i++) {
        A[i] = A[i + 1];
      }
    }
  } else {
    if (x != y) {
      if (x != (short)x || y != (short)y || n == max_n) {
        return invalidate();
      }
      for (int j = n++; j > i; j--) {
        A[j] = A[j - 1];
      }
      A[i].first = (short)x;
      A[i].second = (short)y;
      touch(x - d);
      touch(y);
    }
  }
  return true;
}

// f(x') = x' + d for all x' >= x ?
bool StackTransform::is_trivial_after(int x) const {
  return is_valid() && (!n || A[n - 1].first < x + d);
}

// card f^{-1}(y)
int StackTransform::preimage_count(int y) const {
  if (!is_valid()) {
    return -1;
  }
  int count = (y >= d);
  for (const auto &pair : A) {
    if (pair.second == y) {
      ++count;
    } else if (pair.first == y) {
      --count;
    }
  }
  return count;
}

// f^{-1}(y)
std::vector<int> StackTransform::preimage(int y) const {
  if (!is_valid()) {
    return {};
  }
  std::vector<int> res;
  bool f = (y >= d);
  for (const auto &pair : A) {
    if (pair.first > y && f) {
      res.push_back(y - d);
      f = false;
    }
    if (pair.first == y) {
      f = false;
    } else if (pair.second == y) {
      res.push_back(pair.first - d);
    }
  }
  return res;
}

// is f:N->N bijective ?
bool StackTransform::is_permutation() const {
  if (!is_valid() || d) {
    return false;
  }
  assert(n <= max_n);
  std::array<int, max_n> X, Y;
  for (int i = 0; i < n; i++) {
    X[i] = A[i].first;
    Y[i] = A[i].second;
    if (Y[i] < 0) {
      return false;
    }
  }
  std::sort(Y.begin(), Y.begin() + n);
  for (int i = 0; i < n; i++) {
    if (X[i] != Y[i]) {
      return false;
    }
  }
  return true;
}

bool StackTransform::remove_negative() {
  int s = 0;
  while (s < n && A[s].first < d) {
    ++s;
  }
  if (s) {
    n -= s;
    for (int i = 0; i < n; i++) {
      A[i] = A[i + s];
    }
  }
  return true;
}

int StackTransform::try_load(int &i, int offs) const {
  return i < n ? A[i++].first + offs : inf_x;
}

bool StackTransform::try_store(int x, int y) {
  if (x == y || x < d) {
    return true;
  }
  if (n == max_n || x != (short)x || y != (short)y) {
    return invalidate();
  }
  A[n].first = (short)x;
  A[n++].second = (short)y;
  return true;
}

// c := a * b
bool StackTransform::compose(const StackTransform &a, const StackTransform &b, StackTransform &c) {
  if (!a.is_valid() || !b.is_valid()) {
    return c.invalidate();
  }
  c.d = a.d + b.d;
  c.n = 0;
  c.dp = std::max(a.dp, b.dp + a.d);
  c.c = a.c + b.c;
  c.invalid = false;
  int i = 0, j = 0;
  int x1 = a.try_load(i);
  int x2 = b.try_load(j, a.d);
  while (true) {
    if (x1 < x2) {
      int y = a.A[i - 1].second;
      if (!c.try_store(x1, y)) {
        return false;
      }
      x1 = a.try_load(i);
    } else if (x2 < inf_x) {
      if (x1 == x2) {
        x1 = a.try_load(i);
      }
      int y = b.A[j - 1].second;
      if (!c.try_store(x2, a(y))) {
        return false;
      }
      x2 = b.try_load(j, a.d);
    } else {
      return true;
    }
  }
}

// this = this * other
bool StackTransform::apply(const StackTransform &other) {
  StackTransform res;
  if (!compose(*this, other, res)) {
    return invalidate();
  }
  return assign(res);
}

// this = other * this
bool StackTransform::preapply(const StackTransform &other) {
  StackTransform res;
  if (!compose(other, *this, res)) {
    return invalidate();
  }
  return assign(res);
}

StackTransform StackTransform::operator*(const StackTransform &b) const & {
  StackTransform res;
  compose(*this, b, res);
  return res;
}

// this = this * other
StackTransform &StackTransform::operator*=(const StackTransform &other) {
  StackTransform res;
  (compose(*this, other, res) && assign(res)) || invalidate();
  return *this;
}

bool StackTransform::apply_xchg(int i, int j, bool relaxed) {
  if (!is_valid() || i < 0 || j < 0) {
    return invalidate();
  }
  if (i == j) {
    return relaxed || touch(i);
  }
  int u = touch_get(i), v = touch_get(j);
  return set(i, v) && set(j, u);
}

bool StackTransform::apply_push(int i) {
  if (!is_valid() || i < 0) {
    return invalidate();
  }
  int u = touch_get(i);
  return shift(-1) && set(0, u);
}

bool StackTransform::apply_push_newconst() {
  if (!is_valid()) {
    return false;
  }
  return shift(-1) && set(0, c_start - c++);
}

bool StackTransform::apply_pop(int i) {
  if (!is_valid() || i < 0) {
    return invalidate();
  }
  if (!i) {
    return touch(0) && shift(1);
  } else {
    return set(i, get(0)) && shift(1);
  }
}

bool StackTransform::apply_blkpop(int k) {
  if (!is_valid() || k < 0) {
    return invalidate();
  }
  return !k || (touch(k - 1) && shift(k));
}

bool StackTransform::equal(const StackTransform &other, bool relaxed) const {
  if (!is_valid() || !other.is_valid()) {
    return false;
  }
  if (!(n == other.n && d == other.d)) {
    return false;
  }
  for (int i = 0; i < n; i++) {
    if (A[i] != other.A[i]) {
      return false;
    }
  }
  return relaxed || dp == other.dp;
}

StackTransform StackTransform::Xchg(int i, int j, bool relaxed) {
  StackTransform t;
  t.apply_xchg(i, j, relaxed);
  return t;
}

StackTransform StackTransform::Push(int i) {
  StackTransform t;
  t.apply_push(i);
  return t;
}

StackTransform StackTransform::Pop(int i) {
  StackTransform t;
  t.apply_pop(i);
  return t;
}

bool StackTransform::is_xchg(int i, int j) const {
  if (i == j) {
    return is_id();
  }
  return is_valid() && !d && n == 2 && i >= 0 && j >= 0 && get(i) == j && get(j) == i;
}

bool StackTransform::is_xchg(int *i, int *j) const {
  if (!is_valid() || d || n > 2 || !dp) {
    return false;
  }
  if (!n) {
    *i = *j = 0;
    return true;
  }
  if (n != 2) {
    return false;
  }
  int a = A[0].first, b = A[1].first;
  if (A[0].second != b || A[1].second != a) {
    return false;
  }
  *i = std::min(a, b);
  *j = std::max(a, b);
  return true;
}

bool StackTransform::is_xchg_xchg(int i, int j, int k, int l) const {
  if (is_valid() && !d && n <= 4 && (i | j | k | l) >= 0) {
    StackTransform t;
    return t.apply_xchg(i, j) && t.apply_xchg(k, l) && t <= *this;
  } else {
    return false;
  }
}

bool StackTransform::is_xchg_xchg(int *i, int *j, int *k, int *l) const {
  if (!is_valid() || d || n > 4 || !dp || !is_permutation()) {
    return false;
  }
  if (!n) {
    *i = *j = *k = *l = 0;
    return true;
  }
  if (n <= 2) {
    *k = *l = 0;
    return is_xchg(i, j);
  }
  if (n == 3) {
    // rotation: a -> b -> c -> a
    int a = A[0].first;
    int b = A[0].second;
    int s = (b == A[2].first ? 2 : 1);
    int c = A[s].second;
    if (b != A[s].first || c != A[3 - s].first || a != A[3 - s].second) {
      return false;
    }
    // implement as XCHG s(a),s(c) ; XCHG s(a),s(b)
    *i = *k = a;
    *j = c;
    *l = b;
    return is_xchg_xchg(*i, *j, *k, *l);
  }
  *i = A[0].first;
  *j = A[0].second;
  if (get(*j) != *i) {
    return false;
  }
  for (int s = 1; s < 4; s++) {
    if (A[s].first != *j) {
      *k = A[s].first;
      *l = A[s].second;
      return get(*l) == *k && is_xchg_xchg(*i, *j, *k, *l);
    }
  }
  return false;
}

bool StackTransform::is_push(int i) const {
  return is_valid() && d == -1 && n == 1 && A[0].first == -1 && A[0].second == i;
}

bool StackTransform::is_push(int *i) const {
  if (is_valid() && d == -1 && n == 1 && A[0].first == -1 && A[0].second >= 0) {
    *i = A[0].second;
    return true;
  } else {
    return false;
  }
}

// 1 2 3 4 .. = pop0
// 0 2 3 4 .. = pop1
// 1 0 3 4 .. = pop2
// 1 2 0 4 .. = pop3
// POP s(i) : 1 2 ... i-1 0 i+1 ... ; d=1, n=1, {(i,0)}
bool StackTransform::is_pop(int i) const {
  if (!is_valid() || d != 1 || n > 1 || i < 0) {
    return false;
  }
  if (!i) {
    return !n;
  }
  return n == 1 && A[0].first == i && !A[0].second;
}

bool StackTransform::is_pop(int *i) const {
  if (!is_valid() || d != 1 || n > 1) {
    return false;
  }
  if (!n) {
    *i = 0;
    return true;
  }
  if (n == 1 && !A[0].second) {
    *i = A[0].first;
    return true;
  }
  return false;
}

// POP s(i) ; POP s(j) : 2 ... i-1 0 i+1 ... j 1 j+2 ... ; d=2, n=2, {(i,0),(j+1,1)} if i <> j+1
bool StackTransform::is_pop_pop(int i, int j) const {
  if (is_valid() && d == 2 && n <= 2 && i >= 0 && j >= 0) {
    StackTransform t;
    return t.apply_pop(i) && t.apply_pop(j) && t <= *this;
  } else {
    return false;
  }
}

bool StackTransform::is_pop_pop(int *i, int *j) const {
  if (!is_valid() || d != 2 || n > 2) {
    return false;
  }
  if (!n) {
    *i = *j = 0;  // 2DROP
  } else if (n == 2) {
    *i = A[0].first - A[0].second;
    *j = A[1].first - A[1].second;
    if (A[0].second > A[1].second) {
      std::swap(*i, *j);
    }
  } else if (!A[0].second) {
    *i = A[0].first;
    *j = 0;
  } else {
    *i = 0;
    *j = A[0].first - 1;
  }
  return is_pop_pop(*i, *j);
}

const StackTransform StackTransform::rot{2, 0, 1, 3};
const StackTransform StackTransform::rot_rev{1, 2, 0, 3};

bool StackTransform::is_rot() const {
  return equal(rot, true);
}

bool StackTransform::is_rotrev() const {
  return equal(rot_rev, true);
}

// PUSH i ; ROT == 1 i 0 2 3
bool StackTransform::is_push_rot(int i) const {
  return is_valid() && d == -1 && i >= 0 && is_trivial_after(3) && get(0) == 1 && get(1) == i && get(2) == 0;
}

bool StackTransform::is_push_rot(int *i) const {
  return is_valid() && (*i = get(1)) >= 0 && is_push_rot(*i);
}

// PUSH i ; -ROT == 0 1 i 2 3
bool StackTransform::is_push_rotrev(int i) const {
  return is_valid() && d == -1 && i >= 0 && is_trivial_after(3) && get(0) == 0 && get(1) == 1 && get(2) == i;
}

bool StackTransform::is_push_rotrev(int *i) const {
  return is_valid() && (*i = get(2)) >= 0 && is_push_rotrev(*i);
}

// PUSH s(i) ; XCHG s(j),s(k) --> i 0 1 .. i ..
// PUSH s(i) ; XCHG s(0),s(k) --> k-1 0 1 .. k-2 i k ..
bool StackTransform::is_push_xchg(int i, int j, int k) const {
  StackTransform t;
  return is_valid() && d == -1 && n <= 3 && t.apply_push(i) && t.apply_xchg(j, k) && t <= *this;
}

bool StackTransform::is_push_xchg(int *i, int *j, int *k) const {
  if (!(is_valid() && d == -1 && n <= 3 && n > 0)) {
    return false;
  }
  int s = get(0);
  if (s < 0) {
    return false;
  }
  *i = s;
  *j = 0;
  if (n == 1) {
    *k = 0;
  } else if (n == 2) {
    *k = s + 1;
    *i = get(s + 1);
  } else {
    *j = A[1].first + 1;
    *k = A[2].first + 1;
  }
  return is_push_xchg(*i, *j, *k);
}

// XCHG s1,s(i) ; XCHG s0,s(j)
bool StackTransform::is_xchg2(int i, int j) const {
  StackTransform t;
  return is_valid() && !d && t.apply_xchg(1, i) && t.apply_xchg(0, j) && t <= *this;
}

bool StackTransform::is_xchg2(int *i, int *j) const {
  if (!is_valid() || d || n > 4 || n == 1 || dp < 2) {
    return false;
  }
  *i = get(1);
  *j = get(0);
  if (!n) {
    return true;
  }
  if (*i < 0 || *j < 0) {
    return false;
  }
  if (n == 2 && !*i) {
    *j = *i;  // XCHG s0,s1 = XCHG2 s0,s0
  } else if (n == 3 && *i) {
    // XCHG2 s(i),s(i) = XCHG s1,s(i) ; XCHG s0,s(i) : 0->1, 1->i
    *j = *i;
  }  // XCHG2 s0,s(i) = XCHG s0,s1 ; XCHG s0,s(i) : 0->i, 1->0
  return is_xchg2(*i, *j);
}

// XCHG s0,s(i) ; PUSH s(j)  = PUSH s(j') ; XCHG s1,s(i+1)
// j'=j if j!=0, j!=i
// j'=0 if j=i
// j'=i if j=0
bool StackTransform::is_xcpu(int i, int j) const {
  StackTransform t;
  return is_valid() && d == -1 && t.apply_xchg(0, i) && t.apply_push(j) && t <= *this;
}

bool StackTransform::is_xcpu(int *i, int *j) const {
  if (!is_valid() || d != -1 || n > 3 || dp < 1) {
    return false;
  }
  *i = get(1);
  *j = get(0);
  if (!*j) {
    *j = *i;
  } else if (*j == *i) {
    *j = 0;
  }
  return is_xcpu(*i, *j);
}

// PUSH s(i) ; XCHG s0, s1 ; XCHG s0, s(j+1)
bool StackTransform::is_puxc(int i, int j) const {
  StackTransform t;
  return is_valid() && d == -1 && t.apply_push(i) && t.apply_xchg(0, 1) && t.apply_xchg(0, j + 1) && t <= *this;
}

// j > 0 : 0 -> j, 1 -> i
// j = 0 : 0 -> i, 1 -> 0  ( PUSH s(i) )
// j = -1 : 0 -> 0, 1 -> i  ( PUSH s(i) ; XCHG s0, s1 )
bool StackTransform::is_puxc(int *i, int *j) const {
  if (!is_valid() || d != -1 || n > 3) {
    return false;
  }
  *i = get(1);
  *j = get(0);
  if (!*i && is_push(*j)) {
    std::swap(*i, *j);
    return is_puxc(*i, *j);
  }
  if (!*j) {
    --*j;
  }
  return is_puxc(*i, *j);
}

// PUSH s(i) ; PUSH s(j+1)
bool StackTransform::is_push2(int i, int j) const {
  StackTransform t;
  return is_valid() && d == -2 && t.apply_push(i) && t.apply_push(j + 1) && t <= *this;
}

bool StackTransform::is_push2(int *i, int *j) const {
  if (!is_valid() || d != -2 || n > 2) {
    return false;
  }
  *i = get(1);
  *j = get(0);
  return is_push2(*i, *j);
}

// XCHG s2,s(i) ; XCHG s1,s(j) ; XCHG s0,s(k)
bool StackTransform::is_xchg3(int *i, int *j, int *k) const {
  if (!is_valid() || d || dp < 3 || !is_permutation()) {
    return false;
  }
  for (int s = 2; s >= 0; s--) {
    *i = get(s);
    StackTransform t = Xchg(2, *i) * *this;
    if (t.is_xchg2(j, k)) {
      return true;
    }
  }
  return false;
}

// XCHG s1,s(i) ; XCHG s0,s(j) ; PUSH s(k)
bool StackTransform::is_xc2pu(int *i, int *j, int *k) const {
  if (!is_valid() || d != -1 || dp < 2) {
    return false;
  }
  for (int s = 2; s >= 1; s--) {
    *i = get(s);
    StackTransform t = Xchg(1, *i) * *this;
    if (t.is_xcpu(j, k)) {
      return true;
    }
  }
  return false;
}

// XCHG s1,s(i) ; PUSH s(j) ; XCHG s0,s1 ; XCHG s0,s(k+1)
bool StackTransform::is_xcpuxc(int *i, int *j, int *k) const {
  if (!is_valid() || d != -1 || dp < 2) {
    return false;
  }
  for (int s = 2; s >= 0; s--) {
    *i = get(s);
    StackTransform t = Xchg(1, *i) * *this;
    if (t.is_puxc(j, k)) {
      return true;
    }
  }
  return false;
}

// XCHG s0,s(i) ; PUSH s(j) ; PUSH s(k+1)
bool StackTransform::is_xcpu2(int *i, int *j, int *k) const {
  if (!is_valid() || d != -2 || dp < 1) {
    return false;
  }
  *i = get(2);
  StackTransform t = Xchg(0, *i) * *this;
  return t.is_push2(j, k);
}

// PUSH s(i) ; XCHG s0,s2 ; XCHG s1,s(j+1) ; XCHG s0,s(k+1)
// 0 -> i or 1 -> i or 2 -> i ; i has two preimages
// 0 -> k if k >= 2, k != j
// 1 -> j=k if j = k >= 2
// 1 -> j if j >= 2, k != 0
// 0 -> j if j >= 2, k = 0
// => i in {f(0), f(1), f(2)} ; j in {-1, 0, 1, f(0), f(1)} ; k in {-1, 0, 1, f(0), f(1)}
bool StackTransform::is_puxc2(int *i, int *j, int *k) const {
  if (!is_valid() || d != -1 || dp < 2) {
    return false;
  }
  for (int s = 2; s >= 0; s--) {
    *i = get(s);
    if (preimage_count(*i) != 2) {
      continue;
    }
    for (int u = -1; u <= 3; u++) {
      *j = (u >= 2 ? get(u - 2) : u);
      for (int v = -1; v <= 3; v++) {
        *k = (v >= 2 ? get(v - 2) : v);
        if (is_puxc2(*i, *j, *k)) {
          return true;
        }
      }
    }
  }
  return false;
}

// PUSH s(i) ; XCHG s0,s2 ; XCHG s1,s(j+1) ; XCHG s0,s(k+1)
bool StackTransform::is_puxc2(int i, int j, int k) const {
  StackTransform t;
  return is_valid() && d == -1 && dp >= 2          // basic checks
         && t.apply_push(i) && t.apply_xchg(0, 2)  // PUSH s(i) ; XCHG s0,s2
         && t.apply_xchg(1, j + 1)                 // XCHG s1,s(j+1)
         && t.apply_xchg(0, k + 1) && t <= *this;  // XCHG s0,s(k+2)
}

// PUSH s(i) ; XCHG s0,s1 ; XCHG s0,s(j+1) ; PUSH s(k+1)
bool StackTransform::is_puxcpu(int *i, int *j, int *k) const {
  if (!is_valid() || d != -2 || dp < 1) {
    return false;
  }
  StackTransform t = *this;
  if (t.apply_pop() && t.is_puxc(i, j)) {
    int y = get(0);
    auto v = t.preimage(y);
    if (!v.empty()) {
      *k = v[0] - 1;
      t.apply_push(*k + 1);
      return t <= *this;
    }
  }
  return false;
}

// PUSH s(i) ; XCHG s0,s1 ; PUSH s(j+1) ; XCHG s0,s1 ; XCHG s0,s(k+2)
// 2 -> i;  1 -> j (if j >= 1, k != -1), 1 -> i (if j = 0, k != -1), 1 -> 0 (if j = -1, k != -1)
// 0 -> k (if k >= 1), 0 -> i (if k = 0), 0 -> j (if k = -1, j >= 1)
bool StackTransform::is_pu2xc(int *i, int *j, int *k) const {
  if (!is_valid() || d != -2 || dp < 1) {
    return false;
  }
  *i = get(2);
  for (int v = -2; v <= 1; v++) {
    *k = (v <= 0 ? v : get(0));  // one of -2, -1, 0, get(0)
    for (int u = -1; u <= 1; u++) {
      *j = (u <= 0 ? u : get(v != -1));  // one of -1, 0, get(0), get(1)
      if (is_pu2xc(*i, *j, *k)) {
        return true;
      }
    }
  }
  return false;
}

bool StackTransform::is_pu2xc(int i, int j, int k) const {
  StackTransform t;
  return is_valid() && d == -2 && dp >= 1              // basic checks
         && t.apply_push(i) && t.apply_xchg(0, 1)      // PUSH s(i) ; XCHG s0,s1
         && t.apply_push(j + 1) && t.apply_xchg(0, 1)  // PUSH s(j+1) ; XCHG s0,s1
         && t.apply_xchg(0, k + 2) && t <= *this;      // XCHG s0,s(k+2)
}

// PUSH s(i) ; PUSH s(j+1) ; PUSH s(k+2)
bool StackTransform::is_push3(int i, int j, int k) const {
  StackTransform t;
  return is_valid() && d == -3 && t.apply_push(i) && t.apply_push(j + 1) && t.apply_push(k + 2) && t <= *this;
}

bool StackTransform::is_push3(int *i, int *j, int *k) const {
  if (!is_valid() || d != -3 || n > 3) {
    return false;
  }
  *i = get(2);
  *j = get(1);
  *k = get(0);
  return is_push3(*i, *j, *k);
}

bool StackTransform::is_blkswap(int *i, int *j) const {
  if (!is_valid() || d || !is_permutation()) {
    return false;
  }
  *j = get(0);
  if (*j <= 0) {
    return false;
  }
  auto v = preimage(0);
  if (v.size() != 1) {
    return false;
  }
  *i = v[0];
  return *i > 0 && is_blkswap(*i, *j);
}

bool StackTransform::is_blkswap(int i, int j) const {
  if (!is_valid() || d || i <= 0 || j <= 0 || dp < i + j || !is_trivial_after(i + j)) {
    return false;
  }
  for (int s = 0; s < i; s++) {
    if (get(s) != s + j) {
      return false;
    }
  }
  for (int s = 0; s < j; s++) {
    if (get(s + i) != s) {
      return false;
    }
  }
  return true;
}

// equivalent to i times DROP
bool StackTransform::is_blkdrop(int *i) const {
  if (is_valid() && d > 0 && !n) {
    *i = d;
    return true;
  }
  return false;
}

// 0 1 .. j-1 j+i j+i+1 ...
bool StackTransform::is_blkdrop2(int i, int j) const {
  if (!is_valid() || d != i || i <= 0 || j < 0 || dp < i + j || n != j || !is_trivial_after(j)) {
    return false;
  }
  for (int s = 0; s < j; s++) {
    if (get(s) != s) {
      return false;
    }
  }
  return true;
}

bool StackTransform::is_blkdrop2(int *i, int *j) const {
  if (is_valid() && is_blkdrop2(d, n)) {
    *i = d;
    *j = n;
    return true;
  }
  return false;
}

// equivalent to i times PUSH s(j)
bool StackTransform::is_blkpush(int *i, int *j) const {
  if (!is_valid() || d >= 0) {
    return false;
  }
  *i = -d;
  *j = get(*i - 1);
  return is_blkpush(*i, *j);
}

bool StackTransform::is_blkpush(int i, int j) const {
  if (!is_valid() || d >= 0 || d != -i || j < 0 || dp < i + j || !is_trivial_after(i)) {
    return false;
  }
  StackTransform t;
  for (int s = 0; s < i; s++) {
    if (!t.apply_push(j)) {
      return false;
    }
  }
  return t <= *this;
}

bool StackTransform::is_reverse(int *i, int *j) const {
  if (!is_valid() || d || !is_permutation() || n < 2) {
    return false;
  }
  *j = A[0].first;
  *i = A[n - 1].first - A[0].first + 1;
  return is_reverse(*i, *j);
}

bool StackTransform::is_reverse(int i, int j) const {
  if (!is_valid() || d || !is_trivial_after(i + j) || n < 2 || A[0].first != j || A[n - 1].first != j + i - 1) {
    return false;
  }
  for (int s = 0; s < i; s++) {
    if (get(j + s) != j + i - 1 - s) {
      return false;
    }
  }
  return true;
}

// 0 i+1 i+2 ... == i*NIP
// j i+1 i+2 ... == XCHG s(i),s(j) ; BLKDROP i
bool StackTransform::is_nip_seq(int i, int j) const {
  return is_valid() && d == i && i > j && j >= 0 && n == 1 && A[0].first == i && A[0].second == j;
}

bool StackTransform::is_nip_seq(int *i) const {
  *i = d;
  return is_nip_seq(*i);
}

bool StackTransform::is_nip_seq(int *i, int *j) const {
  if (is_valid() && n > 0) {
    *i = d;
    *j = A[0].second;
    return is_nip_seq(*i, *j);
  } else {
    return false;
  }
}

// POP s(i); BLKDROP k  (usually for i >= k >= 0)
bool StackTransform::is_pop_blkdrop(int i, int k) const {
  StackTransform t;
  return is_valid() && d == k + 1 && t.apply_pop(i) && t.apply_blkpop(k) && t <= *this;
}

// POP s(i); BLKDROP k == XCHG s0,s(i); BLKDROP k+1  for i >= k >= 0
// k+1 k+2 .. i-1 0 i+1 ..
bool StackTransform::is_pop_blkdrop(int *i, int *k) const {
  if (is_valid() && n == 1 && d > 0 && !A[0].second) {
    *k = d - 1;
    *i = A[0].first;
    return is_pop_blkdrop(*i, *k);
  } else {
    return false;
  }
}

// POP s(i); POP s(j); BLKDROP k  (usually for i<>j >= k >= 0)
bool StackTransform::is_2pop_blkdrop(int i, int j, int k) const {
  StackTransform t;
  return is_valid() && d == k + 2 && t.apply_pop(i) && t.apply_pop(j) && t.apply_blkpop(k) && t <= *this;
}

// POP s(i); POP s(j); BLKDROP k == XCHG s0,s(i); XCHG s1,s(j+1); BLKDROP k+2 (usually for i<>j >= k >= 2)
// k+2 k+3 .. i-1 0 i+1 ... j 1 j+2 ...
bool StackTransform::is_2pop_blkdrop(int *i, int *j, int *k) const {
  if (is_valid() && n == 2 && d >= 2 && A[0].second + A[1].second == 1) {
    *k = d - 2;
    int t = (A[0].second > 0);
    *i = A[t].first;
    *j = A[1 - t].first - 1;
    return is_2pop_blkdrop(*i, *j, *k);
  } else {
    return false;
  }
}

// PUSHCONST c ; ROT == 1 -1000 0 2 3
bool StackTransform::is_const_rot(int c) const {
  return is_valid() && d == -1 && is_trivial_after(3) && get(0) == 1 && c <= c_start && get(1) == c && get(2) == 0;
}

bool StackTransform::is_const_rot(int *c) const {
  return is_valid() && (*c = get(1)) <= c_start && is_const_rot(*c);
}

// PUSHCONST c ; POP s(i) == 0 1 .. i-1 -1000 i+1 ...
bool StackTransform::is_const_pop(int c, int i) const {
  return is_valid() && !d && n == 1 && i > 0 && c <= c_start && get(i - 1) == c;
}

bool StackTransform::is_const_pop(int *c, int *i) const {
  if (is_valid() && !d && n == 1 && A[0].second <= c_start) {
    *i = A[0].first + 1;
    *c = A[0].second;
    return is_const_pop(*c, *i);
  } else {
    return false;
  }
}

// PUSH i ; PUSHCONST c == c i 0 1 2 ...
bool StackTransform::is_push_const(int i, int c) const {
  return is_valid() && d == -2 && c <= c_start && i >= 0 && is_trivial_after(2) && get(0) == c && get(1) == i;
}

bool StackTransform::is_push_const(int *i, int *c) const {
  return is_valid() && d == -2 && n == 2 && is_push_const(*i = get(1), *c = get(0));
}

void StackTransform::show(std::ostream &os, int mode) const {
  if (!is_valid()) {
    os << "<invalid>";
    return;
  }
  int mi = 0, ma = 0;
  if (n > 0 && A[0].first < d) {
    mi = A[0].first - d;
  }
  if (n > 0) {
    ma = std::max(ma, A[n - 1].first - d + 1);
  }
  ma = std::max(ma + 1, dp - d);
  os << '{';
  if (dp == d) {
    os << '|';
  }
  for (int i = mi; i < ma; i++) {
    os << get(i) << (i == -1 ? '?' : (i == dp - d - 1 ? '|' : ' '));
  }
  os << get(ma) << "..}";
}

}  // namespace funC
