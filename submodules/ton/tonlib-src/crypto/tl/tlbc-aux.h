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
#include <memory>
#include <ostream>

namespace tlbc {

static constexpr unsigned long long All = 1ULL << 63;

struct BitPfxCollection {
  std::vector<unsigned long long> pfx;
  void clear() {
    pfx.clear();
  }
  void all() {
    pfx.clear();
    pfx.push_back(All);
  }
  BitPfxCollection() = default;
  BitPfxCollection(unsigned long long one_pfx) {
    if (one_pfx) {
      pfx.push_back(one_pfx);
    }
  }
  bool empty() const {
    return pfx.empty();
  }
  unsigned long long min() const {
    return pfx.empty() ? 0 : pfx[0];
  }
  bool is_all() const {
    return pfx.size() == 1 && pfx[0] == All;
  }
  BitPfxCollection& operator*=(unsigned long long prepend);
  BitPfxCollection operator*(unsigned long long prepend) const;
  BitPfxCollection operator+(const BitPfxCollection& other) const;
  bool operator+=(const BitPfxCollection& other);
  bool operator==(const BitPfxCollection& other) const {
    return pfx == other.pfx;
  }
  bool operator!=(const BitPfxCollection& other) const {
    return pfx != other.pfx;
  }
  void merge_back(unsigned long long z);
  void show(std::ostream& os) const;
};

std::ostream& operator<<(std::ostream& os, const BitPfxCollection& p);

struct AdmissibilityInfo {
  enum { side = 4 };
  std::vector<bool> info;
  int dim;
  AdmissibilityInfo() : info(1, false), dim(0) {
  }
  void extend(int dim1);
  bool operator[](std::size_t i) {
    return info[i & (info.size() - 1)];
  }
  void operator|=(const AdmissibilityInfo& other);
  void set_all(bool val = true);
  void clear_all() {
    set_all(false);
  }
  void set_by_pattern(int pdim, int pattern[]);
  void show(std::ostream& os) const;
  bool is_set_all() const {
    return !dim && info[0];
  }
  bool extract1(char A[side], char tag, int p1) const;
  bool extract2(char A[side][side], char tag, int p1, int p2) const;
  bool extract3(char A[side][side][side], char tag, int p1, int p2, int p3) const;
  int conflicts_at(const AdmissibilityInfo& other) const;
  bool conflicts_with(const AdmissibilityInfo& other) const {
    return conflicts_at(other) >= 0;
  }
};

std::ostream& operator<<(std::ostream& os, const AdmissibilityInfo& p);

struct ConflictSet {
  unsigned long long x;
  explicit ConflictSet(unsigned long long _x = 0) : x(_x) {
  }
  bool operator[](int i) const {
    return (x >> i) & 1;
  }
  ConflictSet& operator|=(ConflictSet other) {
    x |= other.x;
    return *this;
  }
  int size() const {
    return td::count_bits64(x);
  }
  int min() const {
    return x ? td::count_trailing_zeroes_non_zero64(x) : 0x7fffffff;
  }
  int max() const {
    return x ? 63 - td::count_leading_zeroes_non_zero64(x) : -1;
  }
  void remove(int i) {
    x &= ~(1ULL << i);
  }
  void insert(int i) {
    x |= (1ULL << i);
  }
};

struct ConflictGraph {
  std::array<ConflictSet, 64> g;
  ConflictSet& operator[](int i) {
    return g[i];
  }
  const ConflictSet& operator[](int i) const {
    return g[i];
  }
  void set_clique(ConflictSet set);
};

struct BinTrie {
  std::unique_ptr<BinTrie> left, right;
  unsigned long long tag, down_tag;
  int useful_depth;
  BinTrie(unsigned long long _tag = 0, std::unique_ptr<BinTrie> _left = {}, std::unique_ptr<BinTrie> _right = {})
      : left(std::move(_left)), right(std::move(_right)), tag(_tag), down_tag(0), useful_depth(0) {
  }
  void ins_path(unsigned long long path, unsigned long long new_tag);
  unsigned long long lookup_tag(unsigned long long path) const;
  const BinTrie* lookup_node_const(unsigned long long path) const;
  BinTrie* lookup_node(unsigned long long path);
  bool is_unique() const {
    return !(down_tag & (down_tag - 1));
  }
  int unique_value() const {
    return down_tag ? td::count_trailing_zeroes_non_zero64(down_tag) : -1;
  }
  static std::unique_ptr<BinTrie> insert_path(std::unique_ptr<BinTrie> root, unsigned long long path,
                                              unsigned long long tag);
  static std::unique_ptr<BinTrie> insert_paths(std::unique_ptr<BinTrie> root, const BitPfxCollection& paths,
                                               unsigned long long tag);
  void set_conflict_graph(ConflictGraph& gr, unsigned long long colors = 0) const;
  int compute_useful_depth(unsigned long long colors = 0);
  unsigned long long find_conflict_path(unsigned long long colors = 0, unsigned long long mask = ~0ULL) const;
  unsigned long long build_submap_at(int depth, unsigned long long A[], unsigned long long pfx) const;
  unsigned long long build_submap(int depth, unsigned long long A[]) const;
  void show(std::ostream& os, unsigned long long pfx = 1ULL << 63) const;
};

std::ostream& operator<<(std::ostream& os, const BinTrie& bt);

struct MinMaxSize {
  enum : unsigned long long { Any = 0x7ff07, OneRef = 0x100000001ULL, Impossible = (0x7ff07ULL << 32) };
  unsigned long long minmax_size;
  unsigned min_size() const {
    return (unsigned)(minmax_size >> 32);
  }
  unsigned max_size() const {
    return (unsigned)(minmax_size & 0xffffffff);
  }
  unsigned long long get() const {
    return minmax_size;
  }
  bool is_fixed() const {
    return min_size() == max_size();
  }
  int fixed_bit_size() const {
    return is_fixed() && !(min_size() & 0xff) ? (min_size() >> 8) : -1;
  }
  bool fits_into_cell() const {
    return !((0x3ff04 - min_size()) & 0x80000080U);
  }
  bool is_possible() const {
    return !((max_size() - min_size()) & 0x80000080U);
  }
  void normalize();
  MinMaxSize& clear() {
    minmax_size = 0;
    return *this;
  }
  MinMaxSize& clear_min() {
    minmax_size &= (1ULL << 32) - 1;
    return *this;
  }
  MinMaxSize& infinite_max() {
    minmax_size |= 0x3ff07;
    return *this;
  }
  MinMaxSize(unsigned long long _size = Impossible, bool _normalize = false) : minmax_size(_size) {
    if (_normalize) {
      normalize();
    }
  }
  static unsigned convert_size(unsigned z) {
    return ((z & 0xff) << 16) | (z >> 8);
  }
  unsigned convert_min_size() const {
    return convert_size(min_size());
  }
  unsigned convert_max_size() const {
    return convert_size(max_size());
  }
  MinMaxSize operator+(MinMaxSize y) {
    return MinMaxSize(get() + y.get(), true);
  }
  MinMaxSize& operator+=(MinMaxSize y) {
    minmax_size += y.get();
    normalize();
    return *this;
  }
  MinMaxSize& operator|=(MinMaxSize y);
  bool operator==(MinMaxSize y) {
    return get() == y.get();
  }
  bool operator!=(MinMaxSize y) {
    return get() != y.get();
  }
  MinMaxSize& repeat(int count);
  MinMaxSize& repeat_at_least(int count);
  static MinMaxSize fixed_size(unsigned sz) {
    return MinMaxSize(sz * 0x10000000100ULL);
  }
  static MinMaxSize size_range(unsigned min_sz, unsigned max_sz) {
    return MinMaxSize((((unsigned long long)min_sz << 32) + max_sz) << 8);
  }
  void show(std::ostream& os) const;
  struct unpacked {
    unsigned min_bits, min_refs, max_bits, max_refs;
    unpacked(MinMaxSize val);
    MinMaxSize pack() const;
    void show(std::ostream& os) const;
  };

 private:
  void nrm(unsigned long long a, unsigned long long b) {
    if (minmax_size & a) {
      minmax_size = (minmax_size | (a | b)) - a;
    }
  }
};

std::ostream& operator<<(std::ostream& os, MinMaxSize t);

}  // namespace tlbc
