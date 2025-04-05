//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
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
vector<T> full_split(T s, char delimiter = ' ', size_t max_parts = std::numeric_limits<size_t>::max()) {
  vector<T> result;
  if (s.empty()) {
    return result;
  }
  while (result.size() + 1 < max_parts) {
    auto delimiter_pos = s.find(delimiter);
    if (delimiter_pos == string::npos) {
      break;
    }

    result.push_back(s.substr(0, delimiter_pos));
    s = s.substr(delimiter_pos + 1);
  }
  result.push_back(std::move(s));
  return result;
}

string implode(const vector<string> &v, char delimiter = ' ');

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

string lpad(string str, size_t size, char c);

string lpad0(string str, size_t size);

string rpad(string str, size_t size, char c);

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

namespace detail {
Status get_to_integer_safe_error(Slice str);
}  // namespace detail

template <class T>
Result<T> to_integer_safe(Slice str) {
  auto res = to_integer<T>(str);
  if ((PSLICE() << res) != str) {
    return detail::get_to_integer_safe_error(str);
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

template <class T>
Result<typename std::enable_if<std::is_unsigned<T>::value, T>::type> hex_to_integer_safe(Slice str) {
  T integer_value = 0;
  auto begin = str.begin();
  auto end = str.end();
  if (begin == end) {
    return Status::Error("String is empty");
  }
  while (begin != end) {
    T digit = hex_to_int(*begin++);
    if (digit == 16) {
      return Status::Error("String contains non-hex digit");
    }
    if (integer_value > std::numeric_limits<T>::max() / 16) {
      return Status::Error("String hex number overflows");
    }
    integer_value = integer_value * 16 + digit;
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

string hex_encode(Slice data);

string url_encode(Slice data);

size_t url_decode(Slice from, MutableSlice to, bool decode_plus_sign_as_space);

string url_decode(Slice from, bool decode_plus_sign_as_space);

MutableSlice url_decode_inplace(MutableSlice str, bool decode_plus_sign_as_space);

// run-time checked narrowing cast (type conversion):

namespace detail {
template <class T, class U>
struct is_same_signedness final
    : public std::integral_constant<bool, std::is_signed<T>::value == std::is_signed<U>::value> {};

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

string buffer_to_hex(Slice buffer);

string zero_encode(Slice data);

string zero_decode(Slice data);

string zero_one_encode(Slice data);

string zero_one_decode(Slice data);

}  // namespace td
