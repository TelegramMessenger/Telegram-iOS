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

#include "td/utils/common.h"
#include "td/utils/invoke.h"  // for tuple_for_each
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"

#include <tuple>
#include <utility>

namespace td {
namespace format {
/*** HexDump ***/
template <std::size_t size, bool is_reversed = true>
struct HexDumpSize {
  const unsigned char *data;
};

inline char hex_digit(int x) {
  return "0123456789abcdef"[x];
}

template <std::size_t size, bool is_reversed>
StringBuilder &operator<<(StringBuilder &builder, const HexDumpSize<size, is_reversed> &dump) {
  const unsigned char *ptr = dump.data;
  // TODO: append unsafe
  for (std::size_t i = 0; i < size; i++) {
    int xy = ptr[is_reversed ? size - 1 - i : i];
    int x = xy >> 4;
    int y = xy & 15;
    builder << hex_digit(x) << hex_digit(y);
  }
  return builder;
}

template <std::size_t align>
struct HexDumpSlice {
  Slice slice;
};

template <std::size_t align>
StringBuilder &operator<<(StringBuilder &builder, const HexDumpSlice<align> &dump) {
  const auto str = dump.slice;
  const auto size = str.size();

  builder << '\n';

  const std::size_t first_part_size = size % align;
  if (first_part_size) {
    builder << HexDumpSlice<1>{str.substr(0, first_part_size)} << '\n';
  }

  for (std::size_t i = first_part_size; i < size; i += align) {
    builder << HexDumpSize<align>{str.ubegin() + i};

    if (((i / align) & 15) == 15 || i + align >= size) {
      builder << '\n';
    } else {
      builder << ' ';
    }
  }

  return builder;
}

inline StringBuilder &operator<<(StringBuilder &builder, const HexDumpSlice<0> &dump) {
  auto size = dump.slice.size();
  const uint8 *ptr = dump.slice.ubegin();
  for (size_t i = 0; i < size; i++) {
    builder << HexDumpSize<1>{ptr + i};
  }
  return builder;
}

template <std::size_t align>
HexDumpSlice<align> as_hex_dump(Slice slice) {
  return HexDumpSlice<align>{slice};
}

template <std::size_t align>
HexDumpSlice<align> as_hex_dump(MutableSlice slice) {
  return HexDumpSlice<align>{slice};
}

template <std::size_t align, class T>
HexDumpSlice<align> as_hex_dump(const T &value) {
  return HexDumpSlice<align>{Slice(&value, sizeof(value))};
}
template <class T>
HexDumpSize<sizeof(T), true> as_hex_dump(const T &value) {
  return HexDumpSize<sizeof(T), true>{reinterpret_cast<const unsigned char *>(&value)};
}

/*** Hex ***/
template <class T>
struct Hex {
  const T &value;
};

template <class T>
Hex<T> as_hex(const T &value) {
  return Hex<T>{value};
}

template <class T>
StringBuilder &operator<<(StringBuilder &builder, const Hex<T> &hex) {
  builder << "0x" << as_hex_dump(hex.value);
  return builder;
}

/*** Binary ***/
template <class T>
struct Binary {
  const T &value;
};

template <class T>
Binary<T> as_binary(const T &value) {
  return Binary<T>{value};
}

template <class T>
StringBuilder &operator<<(StringBuilder &builder, const Binary<T> &hex) {
  for (size_t i = 0; i < sizeof(T) * 8; i++) {
    builder << ((hex.value >> i) & 1 ? '1' : '0');
  }
  return builder;
}

/*** Escaped ***/
struct Escaped {
  Slice str;
};

inline StringBuilder &operator<<(StringBuilder &builder, const Escaped &escaped) {
  Slice str = escaped.str;
  for (unsigned char c : str) {
    if (c > 31 && c < 127 && c != '"' && c != '\\') {
      builder << static_cast<char>(c);
    } else {
      const char *oct = "01234567";
      builder << '\\' << oct[c >> 6] << oct[(c >> 3) & 7] << oct[c & 7];
    }
  }
  return builder;
}

inline Escaped escaped(Slice slice) {
  return Escaped{slice};
}

/*** Time to string ***/
struct Time {
  double seconds_;
};

inline StringBuilder &operator<<(StringBuilder &logger, Time t) {
  struct NamedValue {
    const char *name;
    double value;
  };

  static constexpr NamedValue durations[] = {{"ns", 1e-9}, {"us", 1e-6}, {"ms", 1e-3}, {"s", 1}};
  static constexpr size_t durations_n = sizeof(durations) / sizeof(NamedValue);

  size_t i = 0;
  while (i + 1 < durations_n && t.seconds_ > 10 * durations[i + 1].value) {
    i++;
  }
  logger << StringBuilder::FixedDouble(t.seconds_ / durations[i].value, 1) << durations[i].name;
  return logger;
}

inline Time as_time(double seconds) {
  return Time{seconds};
}

/*** Size to string ***/
struct Size {
  uint64 size_;
};

inline StringBuilder &operator<<(StringBuilder &logger, Size t) {
  struct NamedValue {
    const char *name;
    uint64 value;
  };

  static constexpr NamedValue sizes[] = {{"B", 1}, {"kB", 1 << 10}, {"MB", 1 << 20}, {"GB", 1 << 30}};
  static constexpr size_t sizes_n = sizeof(sizes) / sizeof(NamedValue);

  size_t i = 0;
  while (i + 1 < sizes_n && t.size_ > 10 * sizes[i + 1].value) {
    i++;
  }
  logger << t.size_ / sizes[i].value << sizes[i].name;
  return logger;
}

inline Size as_size(uint64 size) {
  return Size{size};
}

/*** Array to string ***/
template <class ArrayT>
struct Array {
  const ArrayT &ref;
};

template <class ArrayT>
StringBuilder &operator<<(StringBuilder &stream, const Array<ArrayT> &array) {
  bool first = true;
  stream << Slice("{");
  for (auto &x : array.ref) {
    if (!first) {
      stream << Slice(", ");
    }
    stream << x;
    first = false;
  }
  return stream << Slice("}");
}

template <class ArrayT>
Array<ArrayT> as_array(const ArrayT &array) {
  return Array<ArrayT>{array};
}

/*** Tagged ***/
template <class ValueT>
struct Tagged {
  Slice tag;
  const ValueT &ref;
};

template <class ValueT>
StringBuilder &operator<<(StringBuilder &stream, const Tagged<ValueT> &tagged) {
  return stream << "[" << tagged.tag << ":" << tagged.ref << "]";
}

template <class ValueT>
Tagged<ValueT> tag(Slice tag, const ValueT &ref) {
  return Tagged<ValueT>{tag, ref};
}

/*** Cond ***/
inline StringBuilder &operator<<(StringBuilder &sb, Unit) {
  return sb;
}

template <class TrueT, class FalseT>
struct Cond {
  bool flag;
  const TrueT &on_true;
  const FalseT &on_false;
};

template <class TrueT, class FalseT>
StringBuilder &operator<<(StringBuilder &sb, const Cond<TrueT, FalseT> &cond) {
  if (cond.flag) {
    return sb << cond.on_true;
  } else {
    return sb << cond.on_false;
  }
}

template <class TrueT, class FalseT = Unit>
Cond<TrueT, FalseT> cond(bool flag, const TrueT &on_true, const FalseT &on_false = FalseT()) {
  return Cond<TrueT, FalseT>{flag, on_true, on_false};
}

/*** Concat ***/
template <class T>
struct Concat {
  T args;
};

template <class T>
StringBuilder &operator<<(StringBuilder &sb, const Concat<T> &concat) {
  tuple_for_each(concat.args, [&sb](auto &x) { sb << x; });
  return sb;
}

template <class... ArgsT>
auto concat(const ArgsT &... args) {
  return Concat<decltype(std::tie(args...))>{std::tie(args...)};
}

template <class F>
struct Lambda {
  const F &f;
};

template <class F>
StringBuilder &operator<<(StringBuilder &sb, const Lambda<F> &f) {
  f.f(sb);
  return sb;
}

template <class LambdaT>
Lambda<LambdaT> lambda(const LambdaT &lambda) {
  return Lambda<LambdaT>{lambda};
}

}  // namespace format

using format::tag;

template <class A, class B>
StringBuilder &operator<<(StringBuilder &sb, const std::pair<A, B> &p) {
  return sb << "[" << p.first << ";" << p.second << "]";
}

template <class T>
StringBuilder &operator<<(StringBuilder &stream, const vector<T> &vec) {
  return stream << format::as_array(vec);
}

}  // namespace td
