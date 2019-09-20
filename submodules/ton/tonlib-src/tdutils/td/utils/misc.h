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

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

#include <cstdint>
#include <limits>
#include <type_traits>
#include <utility>

namespace td {

char *str_dup(Slice str);

template <class T>
std::pair<T, T> split(T s, char delimiter = ' ') {
  auto delimiter_pos = s.find(delimiter);
  if (delimiter_pos == string::npos) {
    return {std::move(s), T()};
  } else {
    return {s.substr(0, delimiter_pos), s.substr(delimiter_pos + 1)};
  }
}

template <class T>
vector<T> full_split(T s, char delimiter = ' ') {
  vector<T> result;
  if (s.empty()) {
    return result;
  }
  while (true) {
    auto delimiter_pos = s.find(delimiter);
    if (delimiter_pos == string::npos) {
      result.push_back(std::move(s));
      return result;
    } else {
      result.push_back(s.substr(0, delimiter_pos));
      s = s.substr(delimiter_pos + 1);
    }
  }
}

string implode(const vector<string> &v, char delimiter = ' ');

namespace detail {

template <typename T>
struct transform_helper {
  template <class Func>
  auto transform(const T &v, const Func &f) {
    vector<decltype(f(*v.begin()))> result;
    result.reserve(v.size());
    for (auto &x : v) {
      result.push_back(f(x));
    }
    return result;
  }

  template <class Func>
  auto transform(T &&v, const Func &f) {
    vector<decltype(f(std::move(*v.begin())))> result;
    result.reserve(v.size());
    for (auto &x : v) {
      result.push_back(f(std::move(x)));
    }
    return result;
  }
};

}  // namespace detail

template <class T, class Func>
auto transform(T &&v, const Func &f) {
  return detail::transform_helper<std::decay_t<T>>().transform(std::forward<T>(v), f);
}

template <class T>
void reset_to_empty(T &value) {
  using std::swap;
  std::decay_t<T> tmp;
  swap(tmp, value);
}

template <class T>
void append(vector<T> &destination, const vector<T> &source) {
  destination.insert(destination.end(), source.begin(), source.end());
}

template <class T>
void append(vector<T> &destination, vector<T> &&source) {
  if (destination.empty()) {
    destination.swap(source);
    return;
  }
  destination.reserve(destination.size() + source.size());
  for (auto &elem : source) {
    destination.push_back(std::move(elem));
  }
  reset_to_empty(source);
}

template <class T>
void combine(vector<T> &destination, const vector<T> &source) {
  append(destination, source);
}

template <class T>
void combine(vector<T> &destination, vector<T> &&source) {
  if (destination.size() < source.size()) {
    destination.swap(source);
  }
  destination.reserve(destination.size() + source.size());
  for (auto &elem : source) {
    destination.push_back(std::move(elem));
  }
  reset_to_empty(source);
}

inline bool begins_with(Slice str, Slice prefix) {
  return prefix.size() <= str.size() && prefix == Slice(str.data(), prefix.size());
}

inline bool ends_with(Slice str, Slice suffix) {
  return suffix.size() <= str.size() && suffix == Slice(str.data() + str.size() - suffix.size(), suffix.size());
}

inline char to_lower(char c) {
  if ('A' <= c && c <= 'Z') {
    return static_cast<char>(c - 'A' + 'a');
  }

  return c;
}

inline MutableSlice to_lower_inplace(MutableSlice slice) {
  for (auto &c : slice) {
    c = to_lower(c);
  }
  return slice;
}

inline string to_lower(Slice slice) {
  auto result = slice.str();
  to_lower_inplace(result);
  return result;
}

inline char to_upper(char c) {
  if ('a' <= c && c <= 'z') {
    return static_cast<char>(c - 'a' + 'A');
  }

  return c;
}

inline void to_upper_inplace(MutableSlice slice) {
  for (auto &c : slice) {
    c = to_upper(c);
  }
}

inline string to_upper(Slice slice) {
  auto result = slice.str();
  to_upper_inplace(result);
  return result;
}

inline bool is_space(char c) {
  return c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '\0' || c == '\v';
}

inline bool is_alpha(char c) {
  c |= 0x20;
  return 'a' <= c && c <= 'z';
}

inline bool is_digit(char c) {
  return '0' <= c && c <= '9';
}

inline bool is_alnum(char c) {
  return is_alpha(c) || is_digit(c);
}

inline bool is_hex_digit(char c) {
  if (is_digit(c)) {
    return true;
  }
  c |= 0x20;
  return 'a' <= c && c <= 'f';
}

template <class T>
T trim(T str) {
  auto begin = str.data();
  auto end = begin + str.size();
  while (begin < end && is_space(*begin)) {
    begin++;
  }
  while (begin < end && is_space(end[-1])) {
    end--;
  }
  if (static_cast<size_t>(end - begin) == str.size()) {
    return std::move(str);
  }
  return T(begin, end);
}

string lpad0(string str, size_t size);

string oneline(Slice str);

template <class T>
std::enable_if_t<std::is_signed<T>::value, T> to_integer(Slice str) {
  using unsigned_T = typename std::make_unsigned<T>::type;
  unsigned_T integer_value = 0;
  auto begin = str.begin();
  auto end = str.end();
  bool is_negative = false;
  if (begin != end && *begin == '-') {
    is_negative = true;
    begin++;
  }
  while (begin != end && is_digit(*begin)) {
    integer_value = static_cast<unsigned_T>(integer_value * 10 + static_cast<unsigned_T>(*begin++ - '0'));
  }
  if (integer_value > static_cast<unsigned_T>(std::numeric_limits<T>::max())) {
    static_assert(~0 + 1 == 0, "Two's complement");
    // Use ~x + 1 instead of -x to suppress Visual Studio warning.
    integer_value = static_cast<unsigned_T>(~integer_value + 1);
    is_negative = !is_negative;

    if (integer_value > static_cast<unsigned_T>(std::numeric_limits<T>::max())) {
      return std::numeric_limits<T>::min();
    }
  }

  return is_negative ? static_cast<T>(-static_cast<T>(integer_value)) : static_cast<T>(integer_value);
}

template <class T>
std::enable_if_t<std::is_unsigned<T>::value, T> to_integer(Slice str) {
  T integer_value = 0;
  auto begin = str.begin();
  auto end = str.end();
  while (begin != end && is_digit(*begin)) {
    integer_value = static_cast<T>(integer_value * 10 + static_cast<T>(*begin++ - '0'));
  }
  return integer_value;
}

template <class T>
Result<T> to_integer_safe(Slice str) {
  auto res = to_integer<T>(str);
  if ((PSLICE() << res) != str) {
    return Status::Error(PSLICE() << "Can't parse \"" << str << "\" as number");
  }
  return res;
}

inline int hex_to_int(char c) {
  if (is_digit(c)) {
    return c - '0';
  }
  c |= 0x20;
  if ('a' <= c && c <= 'f') {
    return c - 'a' + 10;
  }
  return 16;
}

template <class T>
typename std::enable_if<std::is_unsigned<T>::value, T>::type hex_to_integer(Slice str) {
  T integer_value = 0;
  auto begin = str.begin();
  auto end = str.end();
  while (begin != end && is_hex_digit(*begin)) {
    integer_value = static_cast<T>(integer_value * 16 + hex_to_int(*begin++));
  }
  return integer_value;
}

double to_double(Slice str);

template <class T>
T clamp(T value, T min_value, T max_value) {
  if (value < min_value) {
    return min_value;
  }
  if (value > max_value) {
    return max_value;
  }
  return value;
}

Result<string> hex_decode(Slice hex);

string url_encode(Slice str);

// run-time checked narrowing cast (type conversion):

namespace detail {
template <class T, class U>
struct is_same_signedness : public std::integral_constant<bool, std::is_signed<T>::value == std::is_signed<U>::value> {
};

template <class T, class Enable = void>
struct safe_undeflying_type {
  using type = T;
};

template <class T>
struct safe_undeflying_type<T, std::enable_if_t<std::is_enum<T>::value>> {
  using type = std::underlying_type_t<T>;
};

class NarrowCast {
  const char *file_;
  int line_;

 public:
  NarrowCast(const char *file, int line) : file_(file), line_(line) {
  }

  template <class R, class A>
  R cast(const A &a) {
    using RT = typename safe_undeflying_type<R>::type;
    using AT = typename safe_undeflying_type<A>::type;

    static_assert(std::is_integral<RT>::value, "expected integral type to cast to");
    static_assert(std::is_integral<AT>::value, "expected integral type to cast from");

    auto r = R(a);
    LOG_CHECK(A(r) == a) << static_cast<AT>(a) << " " << static_cast<RT>(r) << " " << file_ << " " << line_;
    LOG_CHECK((is_same_signedness<RT, AT>::value) || ((static_cast<RT>(r) < RT{}) == (static_cast<AT>(a) < AT{})))
        << static_cast<AT>(a) << " " << static_cast<RT>(r) << " " << file_ << " " << line_;

    return r;
  }
};
}  // namespace detail

#define narrow_cast detail::NarrowCast(__FILE__, __LINE__).cast

template <class R, class A>
Result<R> narrow_cast_safe(const A &a) {
  using RT = typename detail::safe_undeflying_type<R>::type;
  using AT = typename detail::safe_undeflying_type<A>::type;

  static_assert(std::is_integral<RT>::value, "expected integral type to cast to");
  static_assert(std::is_integral<AT>::value, "expected integral type to cast from");

  auto r = R(a);
  if (!(A(r) == a)) {
    return Status::Error("Narrow cast failed");
  }
  if (!((detail::is_same_signedness<RT, AT>::value) || ((static_cast<RT>(r) < RT{}) == (static_cast<AT>(a) < AT{})))) {
    return Status::Error("Narrow cast failed");
  }

  return r;
}

template <int Alignment, class T>
bool is_aligned_pointer(const T *pointer) {
  static_assert(Alignment > 0 && (Alignment & (Alignment - 1)) == 0, "Wrong alignment");
  return (reinterpret_cast<std::uintptr_t>(static_cast<const void *>(pointer)) & (Alignment - 1)) == 0;
}

namespace detail {
template <typename T>
struct reversion_wrapper {
  T &iterable;
};

template <typename T>
auto begin(reversion_wrapper<T> w) {
  return w.iterable.rbegin();
}

template <typename T>
auto end(reversion_wrapper<T> w) {
  return w.iterable.rend();
}
}  // namespace detail

template <typename T>
detail::reversion_wrapper<T> reversed(T &iterable) {
  return {iterable};
}

string buffer_to_hex(Slice buffer);

string zero_encode(Slice data);

string zero_decode(Slice data);

string zero_one_encode(Slice data);

string zero_one_decode(Slice data);

}  // namespace td
