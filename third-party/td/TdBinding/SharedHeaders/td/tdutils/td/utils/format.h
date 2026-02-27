//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/invoke.h"
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
StringBuilder &operator<<(StringBuilder &string_builder, const HexDumpSize<size, is_reversed> &dump) {
  const unsigned char *ptr = dump.data;
  // TODO: append unsafe
  for (std::size_t i = 0; i < size; i++) {
    int xy = ptr[is_reversed ? size - 1 - i : i];
    int x = xy >> 4;
    int y = xy & 15;
    string_builder << hex_digit(x) << hex_digit(y);
  }
  return string_builder;
}

template <std::size_t align>
struct HexDumpSlice {
  Slice slice;
};

template <std::size_t align>
StringBuilder &operator<<(StringBuilder &string_builder, const HexDumpSlice<align> &dump) {
  const auto str = dump.slice;
  const auto size = str.size();

  string_builder << '\n';

  const std::size_t first_part_size = size % align;
  if (first_part_size) {
    string_builder << HexDumpSlice<1>{str.substr(0, first_part_size)} << '\n';
  }

  for (std::size_t i = first_part_size; i < size; i += align) {
    string_builder << HexDumpSize<align>{str.ubegin() + i};

    if (((i / align) & 15) == 15 || i + align >= size) {
      string_builder << '\n';
    } else {
      string_builder << ' ';
    }
  }

  return string_builder;
}

inline StringBuilder &operator<<(StringBuilder &string_builder, const HexDumpSlice<0> &dump) {
  auto size = dump.slice.size();
  const uint8 *ptr = dump.slice.ubegin();
  for (size_t i = 0; i < size; i++) {
    string_builder << HexDumpSize<1>{ptr + i};
  }
  return string_builder;
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
StringBuilder &operator<<(StringBuilder &string_builder, const Hex<T> &hex) {
  string_builder << "0x" << as_hex_dump(hex.value);
  return string_builder;
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
StringBuilder &operator<<(StringBuilder &string_builder, const Binary<T> &hex) {
  for (size_t i = 0; i < sizeof(T) * 8; i++) {
    string_builder << ((hex.value >> i) & 1 ? '1' : '0');
  }
  return string_builder;
}

/*** Escaped ***/
struct Escaped {
  Slice str;
};

inline StringBuilder &operator<<(StringBuilder &string_builder, const Escaped &escaped) {
  Slice str = escaped.str;
  for (unsigned char c : str) {
    if (c > 31 && c < 127 && c != '"' && c != '\\') {
      string_builder << static_cast<char>(c);
    } else {
      const char *oct = "01234567";
      string_builder << '\\' << oct[c >> 6] << oct[(c >> 3) & 7] << oct[c & 7];
    }
  }
  return string_builder;
}

inline Escaped escaped(Slice slice) {
  return Escaped{slice};
}

/*** Time to string ***/
struct Time {
  double seconds_;
};

inline StringBuilder &operator<<(StringBuilder &string_builder, Time t) {
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
  string_builder << StringBuilder::FixedDouble(t.seconds_ / durations[i].value, 1) << Slice(durations[i].name);
  return string_builder;
}

inline Time as_time(double seconds) {
  return Time{seconds};
}

/*** Size to string ***/
struct Size {
  uint64 size_;
};

inline StringBuilder &operator<<(StringBuilder &string_builder, Size t) {
  struct NamedValue {
    const char *name;
    uint64 value;
  };

  static constexpr NamedValue sizes[] = {{"B", 1}, {"KB", 1 << 10}, {"MB", 1 << 20}, {"GB", 1 << 30}};
  static constexpr size_t sizes_n = sizeof(sizes) / sizeof(NamedValue);

  size_t i = 0;
  while (i + 1 < sizes_n && t.size_ >= 100000 * sizes[i].value) {
    i++;
  }
  string_builder << t.size_ / sizes[i].value << Slice(sizes[i].name);
  return string_builder;
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
StringBuilder &operator<<(StringBuilder &string_builder, const Array<ArrayT> &array) {
  bool first = true;
  string_builder << '{';
  for (auto &x : array.ref) {
    if (!first) {
      string_builder << Slice(", ");
    }
    string_builder << x;
    first = false;
  }
  return string_builder << '}';
}

inline StringBuilder &operator<<(StringBuilder &string_builder, const Array<vector<bool>> &array) {
  return string_builder << array.ref;
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
StringBuilder &operator<<(StringBuilder &string_builder, const Tagged<ValueT> &tagged) {
  return string_builder << '[' << tagged.tag << ':' << tagged.ref << ']';
}

template <class ValueT>
Tagged<ValueT> tag(Slice tag, const ValueT &ref) {
  return Tagged<ValueT>{tag, ref};
}

/*** Cond ***/
inline StringBuilder &operator<<(StringBuilder &string_builder, Unit) {
  return string_builder;
}

template <class TrueT, class FalseT>
struct Cond {
  bool flag;
  const TrueT &on_true;
  const FalseT &on_false;
};

template <class TrueT, class FalseT>
StringBuilder &operator<<(StringBuilder &string_builder, const Cond<TrueT, FalseT> &cond) {
  if (cond.flag) {
    return string_builder << cond.on_true;
  } else {
    return string_builder << cond.on_false;
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
StringBuilder &operator<<(StringBuilder &string_builder, const Concat<T> &concat) {
  tuple_for_each(concat.args, [&string_builder](auto &x) { string_builder << x; });
  return string_builder;
}

template <class... ArgsT>
auto concat(const ArgsT &...args) {
  return Concat<decltype(std::tie(args...))>{std::tie(args...)};
}

}  // namespace format

using format::tag;

}  // namespace td
