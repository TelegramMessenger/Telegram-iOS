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
#pragma once
#include "common/refint.h"
#include "vm/cells.h"
#include "vm/cellslice.h"
#include "vm/cellparse.hpp"
#include <type_traits>

namespace vm {

namespace fmt {

// main idea: use cs >> i(32,x) >> ... or cs >> i32(x) to deserialize integers, instead of cs.write().fetch_long(32, true)
// and cb << i(32,x+y) or cb << i32(x+y) will serialize 32-bit integers

// i, u, i16, u16, i32, u32, ub=u1, ib=i1 for integers

template <bool S, class T, bool C = true>
class ConstInt {
  int bits;
  T value;

 public:
  ConstInt(int _bits, T _val) : bits(_bits), value(_val) {
  }
  bool serialize(CellBuilder& cb) const {
    if (C) {
      return (S ? cb.store_long_rchk_bool(value, bits) : cb.store_ulong_rchk_bool(value, bits));
    } else {
      return cb.store_long_bool(value, bits);
    }
  }
  bool deserialize(CellSlice& cs) const {
    if (S) {
      long long x;
      return cs.fetch_long_bool(bits, x) && x == value;
    } else {
      unsigned long long x;
      return cs.fetch_ulong_bool(bits, x) && x == value;
    }
  }
};

template <bool S, class T, bool C = true>
class Int {
  int bits;
  T& value;

 public:
  Int(int _bits, T& _val) : bits(_bits), value(_val) {
  }
  bool deserialize(CellSlice& cs) const {
    if (S) {
      long long x;
      if (cs.fetch_long_bool(bits, x)) {
        value = static_cast<T>(x);
        return true;
      }
    } else {
      unsigned long long x;
      if (cs.fetch_ulong_bool(bits, x)) {
        value = static_cast<T>(x);
        return true;
      }
    }
    return false;
  }
  bool serialize(CellBuilder& cb) const {
    if (C) {
      return S ? cb.store_long_rchk_bool(value, bits) : cb.store_ulong_rchk_bool(value, bits);
    } else {
      return cb.store_long_bool(value, bits);
    }
  }
};

template <bool S, class T>
class PrefetchInt {
  int bits;
  T& value;

 public:
  PrefetchInt(int _bits, T& _val) : bits(_bits), value(_val) {
  }
  bool deserialize(CellSlice& cs) const {
    if (S) {
      long long x;
      if (cs.prefetch_long_bool(bits, x)) {
        value = static_cast<T>(x);
        return true;
      }
    } else {
      unsigned long long x;
      if (cs.prefetch_ulong_bool(bits, x)) {
        value = static_cast<T>(x);
        return true;
      }
    }
    return false;
  }
};

template <bool S>
class ConstRefInt {
  int bits;
  const td::RefInt256& value;

 public:
  ConstRefInt(int _bits, const td::RefInt256& _val) : bits(_bits), value(_val) {
  }
  bool serialize(CellBuilder& cb) const {
    return value.not_null() && cb.store_int256_bool(*value, bits, S);
  }
};

template <bool S>
class ConstRefIntVal {
  int bits;
  td::RefInt256 value;

 public:
  ConstRefIntVal(int _bits, const td::RefInt256& _val) : bits(_bits), value(_val) {
  }
  ConstRefIntVal(int _bits, td::RefInt256&& _val) : bits(_bits), value(std::move(_val)) {
  }
  bool serialize(CellBuilder& cb) const {
    return value.not_null() && cb.store_int256_bool(*value, bits, S);
  }
};

template <bool S>
class ConstBigInt {
  int bits;
  const td::BigInt256& value;

 public:
  ConstBigInt(int _bits, const td::BigInt256& _val) : bits(_bits), value(_val) {
  }
  bool serialize(CellBuilder& cb) const {
    return cb.store_int256_bool(value, bits, S);
  }
};

template <bool S>
class RefInt {
  int bits;
  td::RefInt256& value;

 public:
  RefInt(int _bits, td::RefInt256& _val) : bits(_bits), value(_val) {
  }
  bool deserialize(CellSlice& cs) const {
    value = cs.fetch_int256(bits, S);
    return value.not_null();
  }
  bool serialize(CellBuilder& cb) const {
    return value.not_null() && cb.store_int256_bool(*value, bits, S);
  }
};

inline ConstRefInt<true> i(int l, const td::RefInt256& val) {
  return {l, val};
}

inline ConstRefIntVal<true> i(int l, td::RefInt256&& val) {
  return {l, std::move(val)};
}

inline ConstBigInt<true> i(int l, const td::BigInt256& val) {
  return {l, val};
}

inline RefInt<true> i(int l, td::RefInt256& val) {
  return {l, val};
}

inline ConstRefInt<false> u(int l, const td::RefInt256& val) {
  return {l, val};
}

inline ConstRefIntVal<false> u(int l, td::RefInt256&& val) {
  return {l, std::move(val)};
}

inline ConstBigInt<false> u(int l, const td::BigInt256& val) {
  return {l, val};
}

inline RefInt<false> u(int l, td::RefInt256& val) {
  return {l, val};
}

template <class T>
const ConstInt<true, T> i(int l, const T& val) {
  return {l, val};
}

template <class T>
Int<true, T> i(int l, T& val) {
  return {l, val};
}

template <class T>
PrefetchInt<true, T> pi(int l, T& val) {
  return {l, val};
}

template <class T>
const ConstInt<false, T> u(int l, const T& val) {
  return {l, val};
}

template <class T>
Int<false, T> u(int l, T& val) {
  return {l, val};
}

template <class T>
PrefetchInt<false, T> pu(int l, T& val) {
  return {l, val};
}

template <class T>
const ConstInt<true, T, false> iw(int l, const T& val) {
  return {l, val};
}

template <class T>
Int<true, T, false> iw(int l, T& val) {
  return {l, val};
}

inline ConstInt<true, bool> ib(bool flag) {
  return {1, flag};
}

template <class T>
Int<true, T> ib(T& val) {
  return {1, val};
}

template <class T>
PrefetchInt<true, T> pib(T& val) {
  return {1, val};
}

inline ConstInt<false, bool> ub(bool flag) {
  return {1, flag};
}

template <class T>
Int<false, T> ub(T& val) {
  return {1, val};
}

template <class T>
PrefetchInt<false, T> pub(T& val) {
  return {1, val};
}

inline ConstInt<true, signed char> i8(signed char val) {
  return {8, val};
}

template <class T>
Int<true, T> i8(T& val) {
  return {8, val};
}

inline ConstInt<false, unsigned char> u8(unsigned char val) {
  return {8, val};
}

template <class T>
Int<false, T> u8(T& val) {
  return {8, val};
}

inline ConstInt<true, short> i16(short val) {
  return {16, val};
}

template <class T>
Int<true, T> i16(T& val) {
  static_assert(sizeof(T) >= 2, "i16 needs at least 16-bit integer variable as a result");
  return {16, val};
}

inline ConstInt<false, unsigned short> u16(unsigned short val) {
  return {16, val};
}

template <class T>
Int<false, T> u16(T& val) {
  static_assert(sizeof(T) >= 2, "u16 needs at least 16-bit integer variable as a result");
  return {16, val};
}

template <class T>
const ConstInt<true, T> i32(const T& val) {
  return {32, val};
}

template <class T>
Int<true, T> i32(T& val) {
  static_assert(sizeof(T) >= 4, "i32 needs at least 32-bit integer variable as a result");
  return {32, val};
}

template <class T>
PrefetchInt<true, T> pi32(T& val) {
  static_assert(sizeof(T) >= 4, "pi32 needs at least 32-bit integer variable as a result");
  return {32, val};
}

template <class T>
const ConstInt<false, unsigned> u32(const T& val) {
  return {32, val};
}

template <class T>
Int<false, T> u32(T& val) {
  static_assert(sizeof(T) >= 4, "u32 needs at least 32-bit integer variable as a result");
  return {32, val};
}

template <class T>
PrefetchInt<false, T> pu32(T& val) {
  static_assert(sizeof(T) >= 4, "pu32 needs at least 32-bit integer variable as a result");
  return {32, val};
}

template <class T>
const ConstInt<true, T> i64(const T& val) {
  return {64, val};
}

template <class T>
Int<true, T> i64(T& val) {
  static_assert(sizeof(T) >= 8, "i64 needs 64-bit integer variable as a result");
  return {64, val};
}

template <class T>
const ConstInt<false, T> u64(const T& val) {
  return {64, val};
}

template <class T>
Int<false, T> u64(T& val) {
  static_assert(sizeof(T) >= 8, "u64 needs 64-bit integer variable as a result");
  return {64, val};
}

/*
 * 
 *   non-integer types
 * 
 */

// cr(Ref<Cell>& cell_ref) for (de)serializing cell references

class ConstCellRef {
  const td::Ref<vm::Cell>& value;

 public:
  ConstCellRef(const td::Ref<vm::Cell>& _val) : value(_val) {
  }
  bool serialize(CellBuilder& cb) const {
    return cb.store_ref_bool(value);
  }
};

class ConstCellRefVal {
  td::Ref<vm::Cell> value;

 public:
  ConstCellRefVal(const td::Ref<vm::Cell>& _val) : value(_val) {
  }
  ConstCellRefVal(td::Ref<vm::Cell>&& _val) : value(std::move(_val)) {
  }
  bool serialize(CellBuilder& cb) const {
    return cb.store_ref_bool(std::move(value));
  }
};

class CellRefFmt {
  td::Ref<vm::Cell>& value;

 public:
  CellRefFmt(td::Ref<vm::Cell>& _val) : value(_val) {
  }
  bool deserialize(CellSlice& cs) const {
    value = cs.fetch_ref();
    return value.not_null();
  }
};

inline ConstCellRef cr(const td::Ref<vm::Cell>& val) {
  return {val};
}

inline ConstCellRefVal cr(td::Ref<vm::Cell>&& val) {
  return {std::move(val)};
}

inline CellRefFmt cr(td::Ref<vm::Cell>& val) {
  return {val};
}

// skip(n) will skip n bits

class SkipFmt {
  int bits;

 public:
  explicit SkipFmt(int _bits) : bits(_bits) {
  }
  bool deserialize(CellSlice& cs) const {
    return cs.advance(bits);
  }
};

inline SkipFmt skip(int bits) {
  return SkipFmt{bits};
}

// end will throw an exception if any bits or references remain, or if a previous operation failed
// ends similar, but checks only bits

class ChkEnd {
 public:
  explicit ChkEnd() = default;
  bool deserialize(CellSlice& cs) const {
    return (cs.empty() && !cs.size_refs());
  }
};

class ChkEndS {
 public:
  explicit ChkEndS() = default;
  bool deserialize(CellSlice& cs) const {
    return cs.empty();
  }
};

template <class Cond>
class Chk {
  Cond cond;

 public:
  template <typename... Args>
  explicit constexpr Chk(Args... args) : cond(args...){};
  bool deserialize_ext(CellSlice& cs, bool state) const {
    if (!state || !cond.deserialize(cs)) {
      cs.error();
    }
    return true;
  }
};

class ChkOk {
 public:
  explicit ChkOk() = default;
  bool deserialize_ext(CellSlice& cs, bool state) const {
    if (!state) {
      cs.error();
    }
    return true;
  }
};

constexpr ChkEnd end = ChkEnd{};
constexpr ChkEndS ends = ChkEndS{};
constexpr Chk<ChkEnd> okend = Chk<ChkEnd>{};
constexpr Chk<ChkEndS> okends = Chk<ChkEndS>{};
constexpr Chk<ChkEndS> oke = Chk<ChkEndS>{};
constexpr ChkOk ok = ChkOk{};

inline ::vm::CellParser parser(CellSlice& cs) {
  return ::vm::CellParser{cs};
}

}  // namespace fmt

}  // namespace vm
